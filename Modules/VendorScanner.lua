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

-- Classification module (decor detection + requirement scraping)
local DC = HA.DecorClassifier
local CheckIfDecorItem = DC.CheckIfDecorItem
local ScrapeItemRequirements = DC.ScrapeItemRequirements

-- Persistence module (data storage, retrieval, clearing, export)
local SP = HA.ScanPersistence

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
    [101]  = "The Burning Crusade",  -- Outland
    [113]  = "Wrath of the Lich King", -- Northrend
    [424]  = "Mists of Pandaria",    -- Pandaria
    [572]  = "Warlords of Draenor",  -- Draenor
    [619]  = "Legion",               -- Broken Isles
    [905]  = "Legion",               -- Argus
    [875]  = "Battle for Azeroth",   -- Zandalar
    [876]  = "Battle for Azeroth",   -- Kul Tiras
    [1550] = "Shadowlands",          -- Shadowlands
    [1978] = "Dragonflight",         -- Dragon Isles
    [2274] = "The War Within",       -- Khaz Algar
}

-- Note: RequirementPatterns, scanTooltip, and ScrapeItemRequirements
-- are now in DecorClassifier.lua (imported as local upvalues above).

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
    -- Check if vendor scanning is enabled
    if HA.Addon and HA.Addon.db and not HA.Addon.db.profile.vendorScanning.enabled then
        return
    end

    if HA.DevAddon then
        HA.Addon:Debug("MERCHANT_SHOW event received")
    end

    local npcGUID = UnitGUID("npc")
    if not npcGUID then
        if HA.DevAddon then
            HA.Addon:Debug("No NPC GUID found")
        end
        return
    end

    -- Extract NPC ID from GUID
    local npcID = self:GetNPCIDFromGUID(npcGUID)
    if not npcID then
        if HA.DevAddon then
            HA.Addon:Debug("Could not extract NPC ID from GUID:", npcGUID)
        end
        return
    end

    local vendorName = UnitName("npc") or "Unknown Vendor"

    if HA.DevAddon then
        HA.Addon:Debug("Merchant NPC ID:", npcID, "Name:", vendorName)
    end

    -- Resolve NPC ID aliases to canonical ID (e.g., phased variants → main entry)
    if HA.VendorDatabase and HA.VendorDatabase.Aliases then
        local canonicalID = HA.VendorDatabase.Aliases[npcID]
        if canonicalID then
            if HA.DevAddon then
                HA.Addon:Debug("Alias resolved:", npcID, "->", canonicalID)
            end
            npcID = canonicalID
        end
    end

    -- Store locale vendor name for cross-reference (runs every visit, not gated by session dedup)
    if HA.Addon and HA.Addon.db then
        local locale = GetLocale()
        local normalized = vendorName:lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
        local byLocale = HA.Addon.db.global.vendorNameByLocale
        if not byLocale[locale] then byLocale[locale] = {} end
        local entry = byLocale[locale][normalized]
        if entry and entry.npcID == npcID then
            entry.scanCount = entry.scanCount + 1
            entry.lastSeen = time()
        else
            byLocale[locale][normalized] = { npcID = npcID, scanCount = 1, lastSeen = time() }
        end
    end

    -- Verify NPC ID matches database entry (and correct if mismatched)
    local verification = self:VerifyAndUpdateDatabaseEntry(npcID, vendorName)
    if verification and verification.corrected and HA.DevAddon then
        HA.Addon:Debug("Corrected NPC ID for", vendorName, "from", verification.oldID, "to", verification.newID)
    end

    -- Check if we've already scanned this vendor this session
    if scannedVendorsThisSession[npcID] then
        if HA.DevAddon then
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
    if HA.Addon and HA.Addon.db and not HA.Addon.db.profile.vendorScanning.enabled then
        return
    end

    if HA.DevAddon then
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
            if HA.DevAddon then
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
            if HA.DevAddon then
                HA.Addon:Debug("Merchant data still not ready after 5 attempts, giving up")
            end
            scannedVendorsThisSession[npcID] = nil
            pendingScanNpcID = nil
            return
        end
    end

    -- Data is ready, start the scan
    if HA.DevAddon then
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
        if HA.DevAddon then HA.Addon:Debug("Scan already in progress, skipping") end
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

    if HA.DevAddon then
        HA.Addon:Debug("Starting vendor scan: " .. vendorName .. " (NPC ID: " .. npcID .. "), " .. numItems .. " items, faction: " .. faction)
    end
end

function VendorScanner:StopScan()
    if not isScanning then return end

    scanFrame:Hide()
    isScanning = false

    if scanQueue and scanQueue.npcID then
        if scanQueue.scanComplete then
            -- Full scan finished — save as authoritative data
            SP:SaveVendorData(scanQueue)
        else
            -- Merchant closed before scan finished — discard partial data
            -- Clear session lock so vendor can be re-scanned this session
            scannedVendorsThisSession[scanQueue.npcID] = nil
            if HA.DevAddon then
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

            -- Get full merchant item info via C_MerchantFrame API (12.0.1+)
            local name, texture, price, stackCount, numAvailable, isPurchasable, isUsable, extendedCost, currencyID, spellID
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
            local isDecor, decorInfo = CheckIfDecorItem(itemLink, i)

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

                -- Debug: log requirements result per item (verbose, dev only)
                if HA.DevAddon then
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
            -- Show debug message when decor items are found
            if decorCount > 0 then
                HA.Addon:Debug("Scanned vendor: " .. (scanQueue.vendorName or "Unknown") .. " - " .. decorCount .. "/" .. itemCount .. " decor item(s)")
            end
        end
        scanQueue.scanComplete = true
        self:StopScan()
    end
end

-- Note: CheckIfDecorItem is now in DecorClassifier.lua
-- (imported as local upvalue above).

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
                if HA.DevAddon then
                    HA.Addon:Debug(string.format(
                        "NPC ID Mismatch: %s - Database has %d, actual is %d. Updating...",
                        vendorName, oldID, npcID
                    ))
                end

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

                    if HA.DevAddon then
                        HA.Addon:Debug(string.format(
                            "Coords updated for %s: %.3f, %.3f (map %d)",
                            vendorName, currentCoords.x, currentCoords.y, mapID
                        ))
                    end

                    result.coordsUpdated = true
                end
            end

            return result
        end
    end

    -- No matching vendor found in database - this is a new vendor
    return nil
end

-- Note: GetCorrectedNPCID, ExportNPCIDCorrections, SaveVendorData,
-- GetScannedVendors, GetScannedVendor, Clear*, and ExportScannedData
-- are now in ScanPersistence.lua (imported as SP above).

-- Delegation wrappers for external callers
function VendorScanner:GetCorrectedNPCID(vendorName)
    return SP:GetCorrectedNPCID(vendorName)
end

function VendorScanner:ExportNPCIDCorrections()
    return SP:ExportNPCIDCorrections()
end

function VendorScanner:GetScannedVendors()
    return SP:GetScannedVendors()
end

function VendorScanner:GetScannedVendor(npcID)
    return SP:GetScannedVendor(npcID)
end

function VendorScanner:ClearScannedData()
    SP:ClearScannedData()
    scannedVendorsThisSession = {}
end

function VendorScanner:ClearNoDecorData()
    SP:ClearNoDecorData()
end

function VendorScanner:ClearAllData()
    SP:ClearAllData()
    scannedVendorsThisSession = {}
end

function VendorScanner:ExportScannedData()
    return SP:ExportScannedData()
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

