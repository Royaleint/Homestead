--[[
    Homestead - VendorScanner
    Automatically scans vendors for housing decor items when merchant window is opened

    This module hooks into the MERCHANT_SHOW event to scan vendor inventory
    for housing decor items, then stores the data for community sharing.

    The scanner is designed to be lightweight and non-intrusive:
    - Only scans once per vendor per session
    - Uses throttling to prevent lag
    - Stores data in SavedVariables for persistence
]]

local addonName, HA = ...

-- Create VendorScanner module
local VendorScanner = {}
HA.VendorScanner = VendorScanner

-- Local references for performance
-- Note: Some merchant APIs may be nil at load time, accessed via _G at runtime
-- Note: Do NOT cache C_HousingCatalog at load time — it may not exist yet
local UnitGUID = UnitGUID
local UnitName = UnitName
local C_Map = C_Map

-- Scanner state
local scannedVendorsThisSession = {}
local scanQueue = {}
local isScanning = false
local scanFrame = nil
local pendingScanNpcID = nil      -- NPC ID waiting for MERCHANT_UPDATE
local pendingScanRetries = 0      -- Retry counter for data loading

-- Configuration
local SCAN_BATCH_SIZE = 5      -- Items to scan per frame
local SCAN_DELAY = 0.01        -- Seconds between batches (10ms)
local MAX_ITEMS_TO_SCAN = 200  -- Safety limit

-- Continent mapID → expansion (derived from VendorDatabase.ContinentNames)
-- Note: EK (13) and Kalimdor (12) default to "Classic" but may contain
-- TBC/Cataclysm vendors — this is best-effort. Static DB expansion is authoritative.
local ContinentToExpansion = {
    [12]   = "Classic",              -- Kalimdor
    [13]   = "Classic",              -- Eastern Kingdoms
    [113]  = "Wrath of the Lich King", -- Northrend
    [424]  = "Mists of Pandaria",    -- Pandaria
    [572]  = "Warlords of Draenor",  -- Draenor
    [619]  = "Legion",               -- Broken Isles
    [875]  = "Battle for Azeroth",   -- Zandalar
    [876]  = "Battle for Azeroth",   -- Kul Tiras
    [1550] = "Shadowlands",          -- Shadowlands
    [1978] = "Dragonflight",         -- Dragon Isles
    [2274] = "The War Within",       -- Khaz Algar
}

-- Locale-keyed requirement patterns for tooltip scraping (experimental).
-- Only enUS is populated. Future locales: deDE, frFR, esES, ptBR, ruRU, koKR, zhCN, zhTW
local RequirementPatterns = {
    enUS = {
        {
            -- "Requires The Undying Army - Honored"
            pattern = "^Requires (.+) %- (.+)$",
            build = function(c) return { type = "reputation", faction = c[1], standing = c[2] } end,
        },
        {
            -- "Requires: Completion of quest 'Example'" or "Requires: Something"
            pattern = "^Requires: (.+)$",
            build = function(c) return { type = "quest", name = c[1] } end,
        },
        {
            -- "Requires Raise an Army (12345)" — achievement with ID
            pattern = "^Requires (.+) %((%d+)%)$",
            build = function(c) return { type = "achievement", name = c[1], id = tonumber(c[2]) } end,
        },
        {
            -- "Requires Level 70"
            pattern = "^Requires Level (%d+)$",
            build = function(c) return { type = "level", level = tonumber(c[1]) } end,
        },
    },
    -- deDE = { ... },
    -- frFR = { ... },
}

-- Hidden scanning tooltip for requirement scraping (created once, reused)
-- Do NOT use GameTooltip — that would interfere with the player's visible tooltips.
-- Unnamed frame to avoid global namespace pollution. Font strings registered manually.
-- SetOwner is called before each use in ScrapeItemRequirements(), not here at load time.
local scanTooltip = CreateFrame("GameTooltip", nil, UIParent)
local scanTooltipLeftText = {}
for i = 1, 30 do
    local left = scanTooltip:CreateFontString(nil, "ARTWORK", "GameTooltipText")
    local right = scanTooltip:CreateFontString(nil, "ARTWORK", "GameTooltipText")
    scanTooltip:AddFontStrings(left, right)
    scanTooltipLeftText[i] = left
end

-- Scrape item requirements from hidden tooltip (experimental).
-- Returns: nil (could not check), {} (no requirements), or table of requirements.
local function ScrapeItemRequirements(slotIndex)
    -- Debug: log every call
    local db = HA.Addon and HA.Addon.db and HA.Addon.db.global
    local locale = GetLocale()
    local enabled = db and (db.enableRequirementScraping ~= false) or false
    if HA.Addon then
        HA.Addon:Debug(string.format("ScrapeRequirements: slot %d, enabled=%s, locale=%s",
            slotIndex, tostring(enabled), tostring(locale)))
    end

    -- Check if scraping is enabled
    if not db or db.enableRequirementScraping == false then
        return nil  -- nil = "could not check" (feature disabled)
    end

    -- Check locale support
    if not RequirementPatterns[locale] then
        if HA.Addon then
            HA.Addon:Debug("ScrapeRequirements: no patterns for locale " .. tostring(locale))
        end
        return nil  -- nil = "could not check" (unsupported locale)
    end

    local ok, requirements = pcall(function()
        scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        scanTooltip:ClearLines()
        scanTooltip:SetMerchantItem(slotIndex)

        local numLines = scanTooltip:NumLines()
        if HA.Addon then
            HA.Addon:Debug(string.format("ScrapeRequirements: tooltip has %d lines", numLines))
        end
        if numLines == 0 then
            return nil  -- tooltip failed to populate
        end

        local reqs = {}
        local patterns = RequirementPatterns[locale]

        for i = 1, numLines do
            local line = scanTooltipLeftText[i]
            if line then
                local text = line:GetText()
                local r, g, b = line:GetTextColor()

                -- Red text indicates unmet requirements (r > 0.9, g < 0.2, b < 0.2)
                if text and r and r > 0.9 and g < 0.2 and b < 0.2 then
                    if HA.Addon then
                        HA.Addon:Debug(string.format("ScrapeRequirements: RED line %d: '%s' (%.2f,%.2f,%.2f)",
                            i, text, r, g, b))
                    end
                    local matched = false

                    -- Try each pattern type
                    for _, patternDef in ipairs(patterns) do
                        local captures = { text:match(patternDef.pattern) }
                        if #captures > 0 then
                            local req = patternDef.build(captures)
                            if req then
                                table.insert(reqs, req)
                                matched = true
                                break
                            end
                        end
                    end

                    -- Unrecognized red text — store raw for developer review
                    if not matched then
                        table.insert(reqs, { type = "unknown", text = text })
                    end
                end
            end
        end

        return reqs  -- {} = "checked, found none"; populated = requirements found
    end)

    -- Debug: log result
    local resultStr = "nil"
    if ok and requirements then
        resultStr = (#requirements == 0) and "empty({})" or tostring(#requirements) .. " reqs"
    elseif not ok then
        resultStr = "pcall_error: " .. tostring(requirements)
    end
    if HA.Addon then
        HA.Addon:Debug(string.format("ScrapeRequirements result: %s", resultStr))
    end

    if ok then
        return requirements
    else
        return nil  -- pcall failed — treat as "could not check"
    end
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function VendorScanner:Initialize()
    -- Create frame for OnUpdate scanning
    scanFrame = CreateFrame("Frame")
    scanFrame:Hide()
    scanFrame.elapsed = 0

    scanFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= SCAN_DELAY then
            self.elapsed = 0
            VendorScanner:ProcessScanQueue()
        end
    end)

    -- Register for WoW merchant events directly (not through custom Events system)
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:RegisterEvent("MERCHANT_UPDATE")
    eventFrame:RegisterEvent("MERCHANT_CLOSED")
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "MERCHANT_SHOW" then
            VendorScanner:OnMerchantShow()
        elseif event == "MERCHANT_UPDATE" then
            VendorScanner:OnMerchantUpdate()
        elseif event == "MERCHANT_CLOSED" then
            VendorScanner:OnMerchantClosed()
        end
    end)

    if HA.Addon then
        HA.Addon:Debug("VendorScanner initialized with direct event registration")
    end
end

-------------------------------------------------------------------------------
-- Merchant Event Handlers
-------------------------------------------------------------------------------

function VendorScanner:OnMerchantShow()
    if HA.Addon then
        HA.Addon:Debug("MERCHANT_SHOW event received")
    end

    local npcGUID = UnitGUID("npc")
    if not npcGUID then
        if HA.Addon then
            HA.Addon:Debug("No NPC GUID found")
        end
        return
    end

    -- Extract NPC ID from GUID
    local npcID = self:GetNPCIDFromGUID(npcGUID)
    if not npcID then
        if HA.Addon then
            HA.Addon:Debug("Could not extract NPC ID from GUID:", npcGUID)
        end
        return
    end

    local vendorName = UnitName("npc") or "Unknown Vendor"

    if HA.Addon then
        HA.Addon:Debug("Merchant NPC ID:", npcID, "Name:", vendorName)
    end

    -- Verify NPC ID matches database entry (and correct if mismatched)
    local verification = self:VerifyAndUpdateDatabaseEntry(npcID, vendorName)
    if verification and verification.corrected then
        HA.Addon:Debug("Corrected NPC ID for", vendorName, "from", verification.oldID, "to", verification.newID)
    end

    -- Check if we've already scanned this vendor this session
    if scannedVendorsThisSession[npcID] then
        if HA.Addon then
            HA.Addon:Debug("Vendor " .. npcID .. " already scanned this session")
        end
        return
    end

    -- Mark as scanned for this session
    scannedVendorsThisSession[npcID] = true

    -- Queue the scan - wait for MERCHANT_UPDATE to ensure data is loaded
    pendingScanNpcID = npcID
    pendingScanRetries = 0

    -- Also set a fallback timer in case MERCHANT_UPDATE doesn't fire
    C_Timer.After(0.2, function()
        if pendingScanNpcID == npcID then
            self:TryStartScan(npcID, "timer_fallback")
        end
    end)
end

function VendorScanner:OnMerchantUpdate()
    if HA.Addon then
        HA.Addon:Debug("MERCHANT_UPDATE event received")
    end

    -- If we have a pending scan, try to start it now
    if pendingScanNpcID then
        self:TryStartScan(pendingScanNpcID, "merchant_update")
    end
end

function VendorScanner:TryStartScan(npcID, source)
    -- Check if merchant data is ready
    local numItems = _G.GetMerchantNumItems and _G.GetMerchantNumItems() or 0

    if numItems == 0 then
        pendingScanRetries = pendingScanRetries + 1
        if pendingScanRetries < 5 then
            if HA.Addon then
                HA.Addon:Debug("Merchant data not ready (attempt", pendingScanRetries, "), retrying...")
            end
            -- Retry after a short delay
            C_Timer.After(0.1, function()
                if pendingScanNpcID == npcID then
                    self:TryStartScan(npcID, "retry")
                end
            end)
            return
        else
            if HA.Addon then
                HA.Addon:Debug("Merchant data still not ready after 5 attempts, giving up")
            end
            scannedVendorsThisSession[npcID] = nil
            pendingScanNpcID = nil
            return
        end
    end

    -- Data is ready, start the scan
    if HA.Addon then
        HA.Addon:Debug("Starting scan from", source, "- found", numItems, "items")
    end
    pendingScanNpcID = nil
    self:StartScan(npcID)
end

function VendorScanner:OnMerchantClosed()
    -- Clear pending scan
    pendingScanNpcID = nil
    pendingScanRetries = 0

    -- Stop any in-progress scan
    self:StopScan()
end

-------------------------------------------------------------------------------
-- Scanning Logic
-------------------------------------------------------------------------------

function VendorScanner:StartScan(npcID)
    if isScanning then
        HA.Addon:Debug("Scan already in progress, skipping")
        return
    end

    local numItems = _G.GetMerchantNumItems and _G.GetMerchantNumItems() or 0
    if numItems == 0 then return end

    -- Cap items to prevent issues with massive vendors
    numItems = math.min(numItems, MAX_ITEMS_TO_SCAN)

    -- Get vendor info
    local vendorName = UnitName("npc") or "Unknown Vendor"
    local mapID = C_Map.GetBestMapForUnit("player")
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player") or nil

    -- Get NPC faction for vendor classification
    local faction = UnitFactionGroup("npc") or "Neutral"

    -- Get location context (called inline — NOT cached at file load time)
    local mapInfo = mapID and C_Map.GetMapInfo(mapID) or nil
    local zoneName = mapInfo and mapInfo.name or nil
    local parentMapID = mapInfo and mapInfo.parentMapID or nil
    local subZone = GetSubZoneText() or nil    -- Global WoW API, do NOT upvalue
    local realZone = GetRealZoneText() or nil  -- Global WoW API, do NOT upvalue

    -- Infer expansion from continent
    local expansion = nil
    if parentMapID then
        expansion = ContinentToExpansion[parentMapID]
    end
    if not expansion and mapID and HA.VendorDatabase and HA.VendorDatabase.ZoneToContinentMap then
        local continentID = HA.VendorDatabase.ZoneToContinentMap[mapID]
        if continentID then
            expansion = ContinentToExpansion[continentID]
        end
    end

    -- Initialize scan state
    scanQueue = {
        npcID = npcID,
        vendorName = vendorName,
        mapID = mapID,
        coords = position and { x = position.x, y = position.y } or { x = 0.5, y = 0.5 },
        faction = faction,
        zone = zoneName,
        subZone = subZone,
        realZone = realZone,
        parentMapID = parentMapID,
        expansion = expansion,
        currentIndex = 1,
        totalItems = numItems,
        decorItems = {},
        allItems = {},  -- Track all items for itemCount
    }

    isScanning = true
    scanFrame:Show()

    HA.Addon:Debug("Starting vendor scan: " .. vendorName .. " (NPC ID: " .. npcID .. "), " .. numItems .. " items, faction: " .. faction)
end

function VendorScanner:StopScan()
    if not isScanning then return end

    scanFrame:Hide()
    isScanning = false

    if scanQueue and scanQueue.npcID then
        if scanQueue.scanComplete then
            -- Full scan finished — save as authoritative data
            self:SaveVendorData(scanQueue)
        else
            -- Merchant closed before scan finished — discard partial data
            -- Clear session lock so vendor can be re-scanned this session
            scannedVendorsThisSession[scanQueue.npcID] = nil
            if HA.Addon then
                HA.Addon:Debug("Scan aborted for " .. (scanQueue.vendorName or "Unknown") .. " — partial data discarded")
            end
        end
    end

    scanQueue = {}
end

function VendorScanner:ProcessScanQueue()
    if not isScanning or not scanQueue then return end

    local startIndex = scanQueue.currentIndex
    local endIndex = math.min(startIndex + SCAN_BATCH_SIZE - 1, scanQueue.totalItems)

    for i = startIndex, endIndex do
        local itemLink = _G.GetMerchantItemLink and _G.GetMerchantItemLink(i)
        if not itemLink then
            -- Merchant slot exists but item data hasn't loaded (slow connection, server lag)
            scanQueue.hadNilSlots = true
        end
        if itemLink then
            local itemID = _G.GetMerchantItemID and _G.GetMerchantItemID(i)

            -- Get full merchant item info using new C_MerchantFrame API (11.0+)
            -- Returns a table instead of multiple values
            local name, texture, price, stackCount, numAvailable, isPurchasable, isUsable, extendedCost, currencyID, spellID
            if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
                local info = C_MerchantFrame.GetItemInfo(i)
                if info then
                    name = info.name
                    texture = info.texture
                    price = info.price
                    stackCount = info.stackCount
                    numAvailable = info.numAvailable
                    isPurchasable = info.isPurchasable
                    isUsable = info.isUsable
                    extendedCost = info.hasExtendedCost
                    currencyID = info.currencyID
                    spellID = info.spellID
                else
                    -- C_MerchantFrame.GetItemInfo returned nil for this slot
                    scanQueue.hadNilSlots = true
                end
            end

            -- Extract all cost components (items and currencies) if extendedCost is true
            local currencies = {}
            local itemCosts = {}
            if extendedCost and _G.GetMerchantItemCostInfo then
                local itemCostCount, currencyCount = _G.GetMerchantItemCostInfo(i)
                local totalCosts = (itemCostCount or 0) + (currencyCount or 0)

                -- Iterate through ALL cost components
                for c = 1, totalCosts do
                    if _G.GetMerchantItemCostItem then
                        local tex, amount, link, costName = _G.GetMerchantItemCostItem(i, c)
                        if link and amount then
                            -- Check if it's a currency link
                            local currID = link:match("currency:(%d+)")
                            if currID then
                                table.insert(currencies, {
                                    currencyID = tonumber(currID),
                                    amount = amount,
                                    name = costName,
                                })
                            else
                                -- It's an item cost (tokens, reagents, etc.)
                                local costItemID = link:match("item:(%d+)")
                                if costItemID then
                                    table.insert(itemCosts, {
                                        itemID = tonumber(costItemID),
                                        amount = amount,
                                        name = costName,
                                    })
                                end
                            end
                        elseif not link and costName and amount and amount > 0 then
                            -- Currency with nil link — API returns name instead
                            -- Try to find currencyID by searching known currencies
                            local inferredID = nil
                            if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyIDFromLink then
                                -- Not available without a link, but future-proof
                            end
                            table.insert(currencies, {
                                currencyID = inferredID,
                                amount = amount,
                                name = costName,
                            })
                        end
                    end
                end
            end

            -- Check if this is a housing decor item
            local isDecor, decorInfo = self:CheckIfDecorItem(itemLink)

            -- Track all items for itemCount
            table.insert(scanQueue.allItems, {
                itemID = itemID or GetItemInfoInstant(itemLink),
                name = name,
                isDecor = isDecor,
            })

            -- Store decor items with full data
            if isDecor then
                -- Scrape requirements only for decor items (experimental)
                local requirements = ScrapeItemRequirements(i)

                -- Debug: log requirements result per item
                if HA.Addon then
                    local reqStr = "nil"
                    if requirements then
                        reqStr = (#requirements == 0) and "none" or tostring(#requirements) .. " found"
                    end
                    HA.Addon:Debug(string.format("Item %d (%s): requirements=%s",
                        itemID or 0, name or "?", reqStr))
                end

                table.insert(scanQueue.decorItems, {
                    itemLink = itemLink,
                    itemID = itemID or (decorInfo and decorInfo.itemID) or GetItemInfoInstant(itemLink),
                    name = name or (decorInfo and decorInfo.name) or "Unknown",
                    price = price,
                    stackCount = stackCount,
                    isPurchasable = isPurchasable,
                    isUsable = isUsable,    -- Whether player can use/buy this
                    spellID = spellID,      -- Associated spell if any
                    requirements = requirements, -- Experimental: tooltip-scraped requirements
                    currencies = (#currencies > 0) and currencies or nil,
                    itemCosts = (#itemCosts > 0) and itemCosts or nil,
                    merchantSlot = i,
                })
            end
        end
    end

    scanQueue.currentIndex = endIndex + 1

    -- Check if scan is complete
    if scanQueue.currentIndex > scanQueue.totalItems then
        local decorCount = #scanQueue.decorItems
        local itemCount = #scanQueue.allItems
        if HA.Addon then
            HA.Addon:Debug("Scan complete: " .. itemCount .. " total items, " .. decorCount .. " decor items")
            -- Show user-visible message when decor items are found
            if decorCount > 0 then
                HA.Addon:Print("Scanned vendor: " .. (scanQueue.vendorName or "Unknown") .. " - " .. decorCount .. "/" .. itemCount .. " decor item(s)")
            end
        end
        scanQueue.scanComplete = true
        self:StopScan()
    end
end

-------------------------------------------------------------------------------
-- Decor Detection
-------------------------------------------------------------------------------

function VendorScanner:CheckIfDecorItem(itemLink)
    local CHC = _G.C_HousingCatalog
    if not itemLink or not CHC or not CHC.GetCatalogEntryInfoByItem then
        return false, nil
    end

    -- Use the Housing Catalog API to check if this item is decor
    local ok, catalogInfo = pcall(CHC.GetCatalogEntryInfoByItem, itemLink, true)
    if ok and catalogInfo then
        -- Extract item ID from link
        local itemID = GetItemInfoInstant(itemLink)
        return true, {
            itemID = itemID,
            entryID = catalogInfo.entryID,
            name = catalogInfo.name,
            isOwned = catalogInfo.isOwned,
            quantityOwned = catalogInfo.quantityOwned,
        }
    end

    return false, nil
end

-------------------------------------------------------------------------------
-- Database Verification & Correction
-- NOTE: This section is temporary and will be removed once all vendor
-- NPC IDs in VendorDatabase.lua have been verified as correct.
-------------------------------------------------------------------------------

-- Check if the scanned vendor matches a database entry by name and update NPC ID/coords if mismatched
function VendorScanner:VerifyAndUpdateDatabaseEntry(npcID, vendorName)
    if not HA.VendorDatabase then return nil end

    -- Get current player position for coordinate update
    local mapID = C_Map.GetBestMapForUnit("player")
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player") or nil
    local currentCoords = position and { x = position.x, y = position.y } or nil

    -- Search all vendors in the database for a name match
    local allVendors = HA.VendorDatabase:GetAllVendors()
    for _, vendor in ipairs(allVendors) do
        -- Case-insensitive name comparison
        if vendor.name and vendor.name:lower() == vendorName:lower() then
            local result = {
                vendor = vendor,
                corrected = false,
                coordsUpdated = false,
            }

            -- Check NPC ID mismatch
            if vendor.npcID ~= npcID then
                local oldID = vendor.npcID
                HA.Addon:Print(string.format(
                    "|cffff9900NPC ID Mismatch:|r %s - Database has %d, actual is %d. Updating...",
                    vendorName, oldID, npcID
                ))

                -- Store the correction in SavedVariables for persistence
                if not HA.Addon.db.global.npcIDCorrections then
                    HA.Addon.db.global.npcIDCorrections = {}
                end
                HA.Addon.db.global.npcIDCorrections[vendorName] = {
                    oldID = oldID,
                    newID = npcID,
                    correctedAt = time(),
                }

                -- Update the vendor entry in memory (this won't persist to the Lua file)
                vendor.npcID = npcID

                result.oldID = oldID
                result.newID = npcID
                result.corrected = true
            end

            -- Check if coords need updating (placeholder coords or missing)
            if currentCoords and currentCoords.x ~= 0.5 and currentCoords.y ~= 0.5 then
                local needsCoordsUpdate = false

                -- Get existing coords (handles both old coords.x/y and new x/y formats)
                local existingX = vendor.x or (vendor.coords and vendor.coords.x)
                local existingY = vendor.y or (vendor.coords and vendor.coords.y)

                -- Check if database has placeholder coords (0.50, 0.50) or no coords
                if not existingX or not existingY then
                    needsCoordsUpdate = true
                elseif existingX == 0.50 and existingY == 0.50 then
                    needsCoordsUpdate = true
                elseif existingX == 0.5 and existingY == 0.5 then
                    needsCoordsUpdate = true
                end

                if needsCoordsUpdate then
                    -- Store coordinate update in SavedVariables
                    if not HA.Addon.db.global.coordsUpdates then
                        HA.Addon.db.global.coordsUpdates = {}
                    end
                    HA.Addon.db.global.coordsUpdates[vendorName] = {
                        mapID = mapID,
                        x = currentCoords.x,
                        y = currentCoords.y,
                        updatedAt = time(),
                    }

                    -- Update in memory (use new format)
                    vendor.x = currentCoords.x
                    vendor.y = currentCoords.y
                    vendor.mapID = mapID

                    HA.Addon:Debug(string.format(
                        "Coords updated for %s: %.3f, %.3f (map %d)",
                        vendorName, currentCoords.x, currentCoords.y, mapID
                    ))

                    result.coordsUpdated = true
                end
            end

            return result
        end
    end

    -- No matching vendor found in database - this is a new vendor
    return nil
end

-- Get the corrected NPC ID for a vendor name (used at runtime)
function VendorScanner:GetCorrectedNPCID(vendorName)
    if HA.Addon.db and HA.Addon.db.global.npcIDCorrections then
        local correction = HA.Addon.db.global.npcIDCorrections[vendorName]
        if correction then
            return correction.newID
        end
    end
    return nil
end

-- Export NPC ID corrections for manual database updates
function VendorScanner:ExportNPCIDCorrections()
    if not HA.Addon.db or not HA.Addon.db.global.npcIDCorrections then
        HA.Addon:Print("No NPC ID corrections recorded.")
        return ""
    end

    local output = "-- Homestead NPC ID Corrections\n"
    output = output .. "-- Generated: " .. date("%Y-%m-%d %H:%M:%S") .. "\n\n"

    local count = 0
    for name, correction in pairs(HA.Addon.db.global.npcIDCorrections) do
        output = output .. string.format("-- %s: %d -> %d\n", name, correction.oldID, correction.newID)
        count = count + 1
    end

    if count == 0 then
        HA.Addon:Print("No NPC ID corrections recorded.")
        return ""
    end

    HA.Addon:Print("Found " .. count .. " NPC ID correction(s). Copy from chat or use /hs exportcorrections")
    return output
end

-------------------------------------------------------------------------------
-- Data Storage
-------------------------------------------------------------------------------

function VendorScanner:SaveVendorData(scanData)
    -- Ensure SavedVariables structure exists
    if not HA.Addon.db or not HA.Addon.db.global then
        HA.Addon:Debug("SavedVariables not ready, cannot save vendor data")
        return
    end

    -- Initialize scanned vendors storage
    if not HA.Addon.db.global.scannedVendors then
        HA.Addon.db.global.scannedVendors = {}
    end

    local existingData = HA.Addon.db.global.scannedVendors[scanData.npcID]

    -- Build vendor record with enhanced data
    local decorCount = scanData.decorItems and #scanData.decorItems or 0
    local itemCount = scanData.allItems and #scanData.allItems or scanData.totalItems or 0

    local vendorRecord = {
        npcID = scanData.npcID,
        name = scanData.vendorName,
        mapID = scanData.mapID,
        coords = scanData.coords,
        faction = scanData.faction or "Neutral",
        zone = scanData.zone,
        subZone = scanData.subZone,
        realZone = scanData.realZone,
        parentMapID = scanData.parentMapID,
        lastScanned = time(),
        itemCount = itemCount,      -- Total items at vendor
        decorCount = decorCount,    -- Housing decor items
        hasDecor = decorCount > 0,  -- Flag to identify if vendor sells housing decor
        items = {},                 -- Enhanced item data (replaces 'decor')
    }

    -- Add decor items with full enhanced data
    for _, item in ipairs(scanData.decorItems or {}) do
        local itemRecord = {
            itemID = item.itemID,
            name = item.name,
            price = item.price,
            stackCount = item.stackCount,
            isPurchasable = item.isPurchasable,
            isUsable = item.isUsable,
            spellID = item.spellID,
            requirements = item.requirements,
            isDecor = true,
        }

        -- Add currency data if present
        if item.currencies and #item.currencies > 0 then
            itemRecord.currencies = item.currencies
        end

        -- Add item cost data if present (tokens, reagents, etc.)
        if item.itemCosts and #item.itemCosts > 0 then
            itemRecord.itemCosts = item.itemCosts
        end

        table.insert(vendorRecord.items, itemRecord)
    end

    -- Infer primary currency from item cost data
    local currencyCounts = {}
    for _, item in ipairs(vendorRecord.items) do
        if item.currencies then
            for _, c in ipairs(item.currencies) do
                local key = c.name or ("Currency " .. tostring(c.currencyID or "?"))
                currencyCounts[key] = (currencyCounts[key] or 0) + 1
            end
        end
    end
    local maxCount, primaryCurrency = 0, nil
    for name, count in pairs(currencyCounts) do
        if count > maxCount then
            maxCount = count
            primaryCurrency = name
        end
    end
    vendorRecord.currency = primaryCurrency
    vendorRecord.expansion = scanData.expansion

    -- Merge with existing data if present (keep more complete record)
    if existingData then
        -- Use newer coords if available
        if scanData.coords.x ~= 0.5 and scanData.coords.y ~= 0.5 then
            vendorRecord.coords = scanData.coords
        elseif existingData.coords then
            vendorRecord.coords = existingData.coords
        end

        -- Preserve faction from existing data if current scan didn't capture it
        if not vendorRecord.faction or vendorRecord.faction == "Neutral" then
            if existingData.faction and existingData.faction ~= "Neutral" then
                vendorRecord.faction = existingData.faction
            end
        end

        -- Preserve metadata when new scan has nil (don't overwrite good data)
        vendorRecord.zone = vendorRecord.zone or existingData.zone
        vendorRecord.subZone = vendorRecord.subZone or existingData.subZone
        vendorRecord.realZone = vendorRecord.realZone or existingData.realZone
        vendorRecord.parentMapID = vendorRecord.parentMapID or existingData.parentMapID
        vendorRecord.expansion = vendorRecord.expansion or existingData.expansion
        vendorRecord.currency = vendorRecord.currency or existingData.currency

        -- DON'T merge item lists - use the current scan as authoritative
        -- The current scan is the source of truth for what the vendor sells NOW
    end

    -- Recalculate counts based on final data
    vendorRecord.decorCount = #vendorRecord.items
    vendorRecord.hasDecor = vendorRecord.decorCount > 0

    -- Save the record
    HA.Addon.db.global.scannedVendors[scanData.npcID] = vendorRecord

    HA.Addon:Debug("Saved vendor data for " .. scanData.vendorName ..
        " - " .. vendorRecord.decorCount .. "/" .. vendorRecord.itemCount ..
        " decor items, faction: " .. vendorRecord.faction)

    -- Maintain persistent no-decor tracking (survives ClearScannedData)
    if not HA.Addon.db.global.noDecorVendors then
        HA.Addon.db.global.noDecorVendors = {}
    end

    -- Determine scan confidence: "confirmed" only if scan completed AND all item
    -- slots returned valid data. "unknown" if scan completed but any
    -- GetMerchantItemInfo() call returned nil during ProcessScanQueue().
    local scanConfidence = "unknown"
    if scanData.scanComplete and not scanData.hadNilSlots then
        scanConfidence = "confirmed"
    end

    if vendorRecord.hasDecor == false and scanConfidence == "confirmed" then
        -- Only flag when scan is fully confirmed (no interruption, no nil slots)
        local existing = HA.Addon.db.global.noDecorVendors[scanData.npcID]
        local confirmCount = (existing and existing.confirmCount or 0) + 1
        local inStaticDB = HA.VendorDatabase and HA.VendorDatabase:HasVendor(scanData.npcID)
        HA.Addon.db.global.noDecorVendors[scanData.npcID] = {
            name = vendorRecord.name,
            confirmedAt = time(),
            itemCount = vendorRecord.itemCount,
            inDatabase = inStaticDB,       -- snapshot; /hs nodecor uses live check
            scanConfidence = "confirmed",  -- tri-state: "confirmed" or "unknown"
            confirmCount = confirmCount,   -- must reach 2 before inDatabase is actionable
        }
        if inStaticDB and confirmCount >= 2 then
            HA.Addon:Print(string.format(
                "|cffff9900No-Decor:|r %s (NPC %d) has %d items but 0 decor. Flagged for removal (confirmed %dx).",
                vendorRecord.name, scanData.npcID, vendorRecord.itemCount, confirmCount
            ))
        elseif inStaticDB then
            HA.Addon:Print(string.format(
                "|cffff9900No-Decor:|r %s (NPC %d) has %d items but 0 decor. Needs 1 more scan to flag for removal.",
                vendorRecord.name, scanData.npcID, vendorRecord.itemCount
            ))
        end
    elseif vendorRecord.hasDecor == true then
        -- Re-scan found decor: unhide vendor
        HA.Addon.db.global.noDecorVendors[scanData.npcID] = nil
    end

    -- Track vendor scan
    if HA.Analytics then
        HA.Analytics:IncrementCounter("VendorScans")
    end

    -- Invalidate cached vendor list (new scan data may affect results)
    if HA.VendorDatabase and HA.VendorDatabase.InvalidateVendorCache then
        HA.VendorDatabase:InvalidateVendorCache()
    end

    -- Fire callback for other modules
    if HA.Events then
        HA.Events:Fire("VENDOR_SCANNED", vendorRecord)
    end
end

-------------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------------

function VendorScanner:GetNPCIDFromGUID(guid)
    if not guid then return nil end

    -- GUID format: Creature-0-XXXX-XXXX-XXXX-XXXXXXXX
    -- or: Creature-0-XXXX-XXXX-XXXX-XXXXXXXX-XXXXX
    local npcID = select(6, strsplit("-", guid))
    return npcID and tonumber(npcID) or nil
end

function VendorScanner:GetScannedVendors()
    if HA.Addon.db and HA.Addon.db.global and HA.Addon.db.global.scannedVendors then
        return HA.Addon.db.global.scannedVendors
    end
    return {}
end

function VendorScanner:GetScannedVendor(npcID)
    local vendors = self:GetScannedVendors()
    return vendors[npcID]
end

function VendorScanner:ClearScannedData()
    if not HA.Addon.db or not HA.Addon.db.global then return end

    local count = 0
    if HA.Addon.db.global.scannedVendors then
        for _ in pairs(HA.Addon.db.global.scannedVendors) do count = count + 1 end
    end

    HA.Addon.db.global.scannedVendors = {}
    -- noDecorVendors intentionally preserved
    HA.Addon.db.global.lastExportTimestamp = nil
    scannedVendorsThisSession = {}

    -- Rebuild indexes and refresh map pins
    if HA.VendorData then
        HA.VendorData:BuildScannedIndex()
    end
    if HA.VendorMapPins then
        HA.VendorMapPins:InvalidateAllCaches()
        if WorldMapFrame and WorldMapFrame:IsShown() then
            HA.VendorMapPins:RefreshPins()
        end
        HA.VendorMapPins:RefreshMinimapPins()
    end

    HA.Addon:Print(string.format("Cleared %d scanned vendor(s). No-decor flags preserved.", count))
end

function VendorScanner:ClearNoDecorData()
    local count = 0
    if HA.Addon.db and HA.Addon.db.global and HA.Addon.db.global.noDecorVendors then
        for _ in pairs(HA.Addon.db.global.noDecorVendors) do count = count + 1 end
        HA.Addon.db.global.noDecorVendors = {}
    end
    if HA.VendorMapPins then
        HA.VendorMapPins:InvalidateAllCaches()
        if WorldMapFrame and WorldMapFrame:IsShown() then
            HA.VendorMapPins:RefreshPins()
        end
        HA.VendorMapPins:RefreshMinimapPins()
    end
    HA.Addon:Print(string.format("Cleared %d no-decor flag(s). Hidden vendors will reappear.", count))
end

function VendorScanner:ClearAllData()
    if not HA.Addon.db or not HA.Addon.db.global then return end

    HA.Addon.db.global.scannedVendors = {}
    HA.Addon.db.global.noDecorVendors = {}
    HA.Addon.db.global.lastExportTimestamp = nil
    scannedVendorsThisSession = {}

    -- Rebuild indexes and refresh map pins
    if HA.VendorData then
        HA.VendorData:BuildScannedIndex()
    end
    if HA.VendorMapPins then
        HA.VendorMapPins:InvalidateAllCaches()
        if WorldMapFrame and WorldMapFrame:IsShown() then
            HA.VendorMapPins:RefreshPins()
        end
        HA.VendorMapPins:RefreshMinimapPins()
    end

    HA.Addon:Print("Cleared ALL vendor data including no-decor flags.")
end

-------------------------------------------------------------------------------
-- Export Scanned Data
-------------------------------------------------------------------------------

function VendorScanner:ExportScannedData()
    local vendors = self:GetScannedVendors()
    local export = {
        version = 1,
        timestamp = time(),
        vendors = {},
    }

    for npcID, data in pairs(vendors) do
        table.insert(export.vendors, {
            npcID = data.npcID,
            name = data.name,
            mapID = data.mapID,
            coords = data.coords,
            items = data.items or data.decor,
        })
    end

    -- Convert to Lua table format string
    local output = "-- Homestead Vendor Scanner Export\n"
    output = output .. "-- Generated: " .. date("%Y-%m-%d %H:%M:%S") .. "\n"
    output = output .. "-- Vendors: " .. #export.vendors .. "\n\n"

    for _, vendor in ipairs(export.vendors) do
        output = output .. "-- " .. vendor.name .. " (NPC ID: " .. vendor.npcID .. ")\n"
        output = output .. "{\n"
        output = output .. "    npcID = " .. vendor.npcID .. ",\n"
        output = output .. "    name = \"" .. (vendor.name or "") .. "\",\n"
        output = output .. "    mapID = " .. (vendor.mapID or 0) .. ",\n"
        output = output .. "    coords = { x = " .. string.format("%.3f", vendor.coords.x) .. ", y = " .. string.format("%.3f", vendor.coords.y) .. " },\n"
        output = output .. "    items = {\n"
        for _, item in ipairs(vendor.items or {}) do
            output = output .. "        { itemID = " .. (item.itemID or 0) .. ", name = \"" .. (item.name or "") .. "\" },\n"
        end
        output = output .. "    },\n"
        output = output .. "},\n\n"
    end

    return output
end

-------------------------------------------------------------------------------
-- Debug / Testing
-------------------------------------------------------------------------------

function VendorScanner:GetStatus()
    local vendors = self:GetScannedVendors()
    local count = 0
    for _ in pairs(vendors) do count = count + 1 end

    return {
        isScanning = isScanning,
        scannedThisSession = next(scannedVendorsThisSession) and true or false,
        totalVendorsScanned = count,
        currentQueueSize = scanQueue and scanQueue.totalItems or 0,
    }
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("VendorScanner", VendorScanner)
end

