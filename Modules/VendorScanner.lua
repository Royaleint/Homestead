--[[
    Homestead - VendorScanner
    Automatically scans vendors for housing decor items when merchant window is opened

    This module hooks into the MERCHANT_SHOW event to scan vendor inventory
    for housing decor items, then stores the data for community sharing.

    The scanner is designed to be lightweight and non-intrusive:
    - Scans each vendor once per session, unless a scan finished with empty
      merchant slots (up to 3 times per session), in which case the next visit
      scans it again
    - Reads slots that returned no data again a bounded number of times,
      after a short wait, before the scan is saved
    - Uses throttling to prevent lag
    - Stores data in SavedVariables for persistence
]]

local _, HA = ...

-- Create VendorScanner module
local VendorScanner = {}
HA.VendorScanner = VendorScanner

-- Classification module (housing item detection)
local DC = HA.DecorClassifier
local ClassifyHousingItem = DC.ClassifyHousingItem

-- Persistence module (data storage, retrieval, clearing, export)
local SP = HA.ScanPersistence

-- Note: Some merchant APIs may be nil at load time, accessed via _G at runtime
-- Note: Do NOT cache C_HousingCatalog at load time — it may not exist yet
-- Note: WoW API (UnitGUID, UnitName, C_Map) called directly at runtime per project rules

-- Scanner state
local scannedVendorsThisSession = {}
local emptySlotScansThisSession = {}  -- npcID -> completed scans that had empty slots
local scanQueue = {}
local isScanning = false
local scanFrame = nil
local pendingScanNpcID = nil      -- NPC ID waiting for MERCHANT_UPDATE
local pendingScanRetries = 0      -- Retry counter for data loading

-- Configuration
local SCAN_BATCH_SIZE = 5      -- Items to scan per frame
local SCAN_DELAY = 0.01        -- Seconds between batches (10ms)
local MAX_ITEMS_TO_SCAN = 200  -- Safety limit
local MAX_EMPTY_SLOT_SCANS_PER_SESSION = 3  -- Scans that may end with empty slots, per vendor, before rescans stop
local REREAD_MAX_PASSES = 6    -- Re-read passes over slots that returned no data
local REREAD_WAIT = 0.5        -- Seconds before each re-read pass
local REREAD_LIST_MAX = 10     -- Slot entries named in the scan line
local PHASE_WALK, PHASE_WAIT, PHASE_PASS = "walk", "wait", "pass"

-- Geography lookups from canonical constants.
-- Note: EK (13) and Kalimdor (12) default to "Classic" but may contain
-- TBC/Cataclysm vendors; this is best-effort. Static DB expansion is authoritative.
local Constants = HA.Constants or {}
local ZoneToContinentMap = Constants.ZoneToContinentMap or {}
local ContinentToExpansion = Constants.ContinentToExpansion or {}

-- Note: Requirement scraping (ScrapeItemRequirements, scanTooltip,
-- RequirementPatterns) was removed — it caused GameTooltipMoneyFrame taint
-- via SetMerchantItem. sourceText parsing in SourceTextParser.lua supersedes it.

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function VendorScanner:Initialize()
    -- Create frame for OnUpdate scanning
    scanFrame = CreateFrame("Frame")
    scanFrame:Hide()
    scanFrame.elapsed = 0

    scanFrame:SetScript("OnUpdate", function(self, elapsed) -- luacheck: ignore 432
        -- Waits count every frame; behind the throttle they would run long above 100 fps
        if scanQueue.phase == PHASE_WAIT then
            VendorScanner:AdvanceRereadWait(elapsed)
            return
        end
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
    eventFrame:SetScript("OnEvent", function(self, event, ...) -- luacheck: ignore 432
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
    -- A new open ends a running scan and drops one still waiting to start
    self:StopScan("new merchant opened")
    if pendingScanNpcID then
        scannedVendorsThisSession[pendingScanNpcID] = nil
    end
    pendingScanNpcID = nil
    pendingScanRetries = 0

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
            -- GUID may be a restricted "secret" value in some instance contexts.
            -- Avoid logging it directly to prevent conversion errors.
            HA.Addon:Debug("Could not extract NPC ID from GUID (possibly restricted value)")
        end
        return
    end

    local vendorName = UnitName("npc") or "Unknown Vendor"

    if HA.DevAddon then
        HA.Addon:Debug("Merchant NPC ID:", npcID, "Name:", vendorName)
    end

    -- Resolve NPC ID aliases to canonical ID (e.g., phased variants -> main entry)
    if HA.VendorData and HA.VendorData.ResolveAlias then
        local canonicalID = HA.VendorData:ResolveAlias(npcID)
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
    -- Closed before the scan started: the open set the session lock but no
    -- scan ran, so release it and let the next open try again
    if pendingScanNpcID then
        scannedVendorsThisSession[pendingScanNpcID] = nil
    end

    -- Clear pending scan
    pendingScanNpcID = nil
    pendingScanRetries = 0

    -- Stop any in-progress scan
    self:StopScan("merchant closed")
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

    -- Build map ancestry chain (zone → region → continent → world → cosmic)
    -- and identify the continent-level map for reliable expansion inference.
    local mapChain = {}
    local continentMapID = nil
    if mapID then
        local walkID = mapID
        while walkID and walkID > 0 do
            table.insert(mapChain, walkID)
            local walkInfo = C_Map.GetMapInfo(walkID)
            if not walkInfo then break end
            if not continentMapID
                and walkInfo.mapType == Enum.UIMapType.Continent then
                continentMapID = walkID
            end
            walkID = walkInfo.parentMapID
        end
    end
    -- Fallback: use static lookup if chain walk didn't find a continent
    if not continentMapID and mapID then
        continentMapID = ZoneToContinentMap[mapID]
    end

    -- Infer expansion from continent (prefer the resolved continentMapID)
    local expansion = nil
    if continentMapID then
        expansion = ContinentToExpansion[continentMapID]
    end
    if not expansion and parentMapID then
        expansion = ContinentToExpansion[parentMapID]
    end
    if not expansion and mapID then
        local continentID = ZoneToContinentMap[mapID]
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
        mapChain = mapChain,
        continentMapID = continentMapID,
        expansion = expansion,
        currentIndex = 1,
        totalItems = numItems,
        housingItems = {},
        allItems = {},  -- Track all items for itemCount
        phase = PHASE_WALK,
    }

    isScanning = true
    scanFrame:Show()

    if HA.DevAddon then
        HA.Addon:Debug("Starting vendor scan: " .. vendorName .. " (NPC ID: " .. npcID .. "), " .. numItems .. " items, faction: " .. faction)
    end
end

local function CurrentSlotTotal()
    local total = _G.GetMerchantNumItems and _G.GetMerchantNumItems() or 0
    return math.min(total, MAX_ITEMS_TO_SCAN)
end

-- Ascending slot numbers as "1, 3-5, 9"; entries past REREAD_LIST_MAX are counted.
local function FormatSlotRanges(slots)
    local parts = {}
    local i, n = 1, #slots
    while i <= n and #parts < REREAD_LIST_MAX do
        local first = slots[i]
        local last = first
        while i < n and slots[i + 1] == last + 1 do
            i = i + 1
            last = slots[i]
        end
        parts[#parts + 1] = (first == last) and tostring(first) or (first .. "-" .. last)
        i = i + 1
    end
    local text = table.concat(parts, ", ")
    if i <= n then
        text = text .. ", +" .. (n - i + 1) .. " more"
    end
    return text
end

-- Reads one merchant slot into the rows the scan records. Returns nothing when
-- the slot has no link; the third value says whether item info came with it.
local function ReadMerchantSlot(i)
    local itemLink = _G.GetMerchantItemLink and _G.GetMerchantItemLink(i)
    if not itemLink then return nil end
    local itemID = _G.GetMerchantItemID and _G.GetMerchantItemID(i)

    -- Get full merchant item info via C_MerchantFrame API (12.0.1+)
    local name, price, stackCount, isPurchasable, isUsable, extendedCost, spellID
    local info = C_MerchantFrame.GetItemInfo(i)
    if info then
        name = info.name
        price = info.price
        stackCount = info.stackCount
        isPurchasable = info.isPurchasable
        isUsable = info.isUsable
        extendedCost = info.hasExtendedCost
        spellID = info.spellID
    end

    -- Extract all cost components (items and currencies) if extendedCost is true
    local currencies = {}
    local itemCosts = {}
    if extendedCost and _G.GetMerchantItemCostInfo then
        local totalCosts = _G.GetMerchantItemCostInfo(i) or 0

        -- Iterate through ALL cost components
        for c = 1, totalCosts do
            if _G.GetMerchantItemCostItem then
                local _, amount, link, costName = _G.GetMerchantItemCostItem(i, c)
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
                    local inferredID = nil
                    -- No link available here; keep currencyID nil and persist name-based cost.
                    table.insert(currencies, {
                        currencyID = inferredID,
                        amount = amount,
                        name = costName,
                    })
                end
            end
        end
    end

    -- Classify item: any housing subclass, or not housing at all.
    -- decorInfo is only ever populated for subclass 0 (Decor) — see
    -- DecorClassifier.
    local isHousing, subclassID, decorInfo = ClassifyHousingItem(itemLink)
    local allRow = {
        itemID = itemID or C_Item.GetItemInfoInstant(itemLink),
        name = name,
    }

    local housingRow = nil
    if isHousing then
        -- Extract decorID (recordID) from catalog entryID if available
        local decorID = nil
        if decorInfo and decorInfo.entryID and type(decorInfo.entryID) == "table" then
            decorID = decorInfo.entryID.recordID
        end

        housingRow = {
            itemLink = itemLink,
            itemID = itemID or (decorInfo and decorInfo.itemID) or C_Item.GetItemInfoInstant(itemLink),
            name = name or (decorInfo and decorInfo.name) or "Unknown",
            subclassID = subclassID,
            decorID = decorID,
            price = price,
            stackCount = stackCount,
            isPurchasable = isPurchasable,
            isUsable = isUsable,    -- Whether player can use/buy this
            spellID = spellID,      -- Associated spell if any
            currencies = (#currencies > 0) and currencies or nil,
            itemCosts = (#itemCosts > 0) and itemCosts or nil,
            merchantSlot = i,
            hasExtendedCost = extendedCost,
        }
    end

    return allRow, housingRow, info ~= nil
end

-- A scan still in its slot walk is discarded; once the walk is done it ends
-- short with the rows it has.
function VendorScanner:StopScan(endReason)
    if not isScanning then return end
    if scanQueue.phase ~= PHASE_WALK then
        self:CompleteScan(endReason)
        return
    end

    scanFrame:Hide()
    isScanning = false

    if scanQueue and scanQueue.npcID then
        -- Scan ended during its slot walk — discard partial data
        -- Clear session lock so vendor can be re-scanned this session
        scannedVendorsThisSession[scanQueue.npcID] = nil
        if HA.DevAddon then
            HA.Addon:Debug("Scan aborted for " .. (scanQueue.vendorName or "Unknown") .. " — partial data discarded")
        end
    end

    scanQueue = {}
end

function VendorScanner:ProcessScanQueue()
    if not isScanning or not scanQueue then return end
    if scanQueue.phase == PHASE_PASS then
        self:ProcessRereadBatch()
        return
    end
    if scanQueue.phase ~= PHASE_WALK then return end

    local startIndex = scanQueue.currentIndex
    local endIndex = math.min(startIndex + SCAN_BATCH_SIZE - 1, scanQueue.totalItems)

    for i = startIndex, endIndex do
        local allRow, housingRow, hasInfo = ReadMerchantSlot(i)
        if allRow then
            table.insert(scanQueue.allItems, allRow)
            if housingRow then
                table.insert(scanQueue.housingItems, housingRow)
            end
        end
        if not (allRow and hasInfo) then
            local incomplete = scanQueue.incomplete
            if not incomplete then
                incomplete = {}
                scanQueue.incomplete = incomplete
            end
            incomplete[#incomplete + 1] = {
                slot = i,
                itemID = allRow and allRow.itemID,
                allIndex = allRow and #scanQueue.allItems,
                housingIndex = housingRow and #scanQueue.housingItems,
            }
        end
    end

    scanQueue.currentIndex = endIndex + 1

    if scanQueue.currentIndex > scanQueue.totalItems then
        if scanQueue.incomplete then
            scanQueue.phase = PHASE_WAIT
            scanQueue.waitRemaining = REREAD_WAIT
            scanQueue.rereadPass = 0
            scanQueue.recovered = 0
        else
            self:CompleteScan()
        end
    end
end

-- Counts down the wait on the scan frame; no timer outlives the scan.
function VendorScanner:AdvanceRereadWait(elapsed)
    local q = scanQueue
    q.waitRemaining = q.waitRemaining - elapsed
    if q.waitRemaining > 0 then return end

    local total = CurrentSlotTotal()
    if total ~= q.totalItems then
        self:CompleteScan("slot total changed", total)
        return
    end
    q.rereadPass = q.rereadPass + 1
    q.rereadCursor = 1
    q.phase = PHASE_PASS
    self:ProcessRereadBatch()
end

-- One batch of the current pass over the slots still not complete.
function VendorScanner:ProcessRereadBatch()
    local q = scanQueue
    local incomplete = q.incomplete
    local startIndex = q.rereadCursor
    local endIndex = math.min(startIndex + SCAN_BATCH_SIZE - 1, #incomplete)
    for n = startIndex, endIndex do
        local entry = incomplete[n]
        local allRow, housingRow, hasInfo = ReadMerchantSlot(entry.slot)
        if not allRow then
            entry.done = false
        elseif not entry.allIndex then
            table.insert(q.allItems, allRow)
            entry.allIndex = #q.allItems
            entry.itemID = allRow.itemID
            if housingRow then
                table.insert(q.housingItems, housingRow)
                entry.housingIndex = #q.housingItems
            end
            entry.done = hasInfo
        elseif entry.itemChanged or allRow.itemID ~= entry.itemID
                or (housingRow ~= nil) ~= (entry.housingIndex ~= nil) then
            -- A different item than the walk recorded: leave its rows alone and
            -- never mark the slot complete
            entry.itemChanged = true
        elseif hasInfo then
            q.allItems[entry.allIndex] = allRow
            if entry.housingIndex then
                q.housingItems[entry.housingIndex] = housingRow
            end
            entry.done = true
        end
        if entry.done then
            q.recovered = q.recovered + 1
        end
    end
    q.rereadCursor = endIndex + 1
    if q.rereadCursor <= #incomplete then return end

    local remaining = {}
    for _, entry in ipairs(incomplete) do
        if not entry.done then
            remaining[#remaining + 1] = entry
        end
    end
    q.incomplete = remaining

    if #remaining == 0 or q.rereadPass >= REREAD_MAX_PASSES then
        local total = CurrentSlotTotal()
        if total ~= q.totalItems then
            self:CompleteScan("slot total changed", total)
        elseif #remaining == 0 then
            self:CompleteScan()
        else
            self:CompleteScan("bound reached")
        end
        return
    end
    q.phase = PHASE_WAIT
    q.waitRemaining = REREAD_WAIT
end

-- The only place a scan whose slot walk finished ends: saves once, releases the
-- session lock when the record is unconfirmed and, in a dev build, says so.
-- endReason is set when the scan ended before its re-reads were done.
function VendorScanner:CompleteScan(endReason, newTotal)
    local q = scanQueue
    scanFrame:Hide()
    isScanning = false
    scanQueue = {}

    local notComplete = {}
    if q.incomplete then
        for _, entry in ipairs(q.incomplete) do
            if not entry.done then
                notComplete[#notComplete + 1] = entry.slot
            end
        end
    end
    local reread = q.phase ~= PHASE_WALK
    if reread then
        table.sort(q.housingItems, function(a, b) return a.merchantSlot < b.merchantSlot end)
    end

    local nilSlotCount = #notComplete
    local short = nilSlotCount > 0 or endReason ~= nil
    q.hadNilSlots = short
    q.scanComplete = true

    local housingCount = #q.housingItems
    local itemCount = #q.allItems
    if short then
        local count = (emptySlotScansThisSession[q.npcID] or 0) + 1
        emptySlotScansThisSession[q.npcID] = count
        q.rescanStopped = count >= MAX_EMPTY_SLOT_SCANS_PER_SESSION
    end
    if HA.Addon then
        local msg = "Scan complete: " .. itemCount .. "/" .. q.totalItems
            .. " slots recorded, " .. housingCount .. " housing items"
        if nilSlotCount > 0 then
            msg = msg .. ", " .. nilSlotCount .. " slot(s) returned no data"
        end
        if short then
            msg = msg .. (q.rescanStopped and "; rescanning stopped for this session" or "; will rescan on reopen")
        end
        if reread then
            msg = msg .. "; " .. q.rereadPass .. " re-read pass(es), " .. q.recovered .. " slot(s) recovered"
            if nilSlotCount > 0 then
                msg = msg .. "; not complete: " .. FormatSlotRanges(notComplete)
            end
            if endReason then
                msg = msg .. "; ended: " .. endReason
                if newTotal then
                    msg = msg .. " (" .. q.totalItems .. " -> " .. newTotal .. ")"
                end
            end
        end
        HA.Addon:Debug(msg)
        if housingCount > 0 then
            HA.Addon:Debug("Scanned vendor: " .. (q.vendorName or "Unknown") .. " - " .. housingCount .. "/" .. itemCount .. " housing item(s)")
        end
    end

    SP:SaveVendorData(q)

    -- Empty slots mean the record is unconfirmed: unlock so reopening
    -- rescans, until the per-session rescan cap is reached
    if short and not q.rescanStopped then
        scannedVendorsThisSession[q.npcID] = nil
    end

    if short and HA.DevAddon then
        local detail = (q.totalItems - nilSlotCount) .. " of " .. q.totalItems .. " slots complete"
        if newTotal then
            detail = detail .. "; slot total changed " .. q.totalItems .. " -> " .. newTotal
        end
        HA.Addon:Print((q.vendorName or "Unknown") .. " scan incomplete (" .. detail .. "). "
            .. (q.rescanStopped and "Rescans stopped for this session; /reload to scan again."
                or "Reopen the vendor to finish."))
    end
end

-- Note: ClassifyHousingItem is now in DecorClassifier.lua
-- (imported as local upvalue above).

-------------------------------------------------------------------------------
-- Database Verification & Correction
-- Detects when a scanned vendor's live NPC ID differs from the one stored in
-- VendorIdentity (phased zones, instances, beta builds). Detected corrections
-- persist to SavedVariables (db.global.npcIDCorrections); ScanPersistence looks
-- them up and Data/VendorData.lua applies them at query time via
-- VendorScanner:GetCorrectedNPCID. The dev addon displays them.
--
-- HS-374 removed the player-facing /hs corrections command, which printed
-- data-entry instructions for a file that no longer loads. Be precise about what
-- that cost: the persisted table above survives untouched, but the command also
-- ran a live name-vs-ID mismatch pass that was computed on demand, stored
-- nowhere, and has no successor anywhere. That diagnostic is gone, not moved.
-------------------------------------------------------------------------------

-- Check if the scanned vendor matches a database entry by name and update NPC ID/coords if mismatched
function VendorScanner:VerifyAndUpdateDatabaseEntry(npcID, vendorName)
    if not HA.VendorData or not HA.VendorData.GetAllVendors then return nil end

    -- Get current player position for coordinate update
    local mapID = C_Map.GetBestMapForUnit("player")
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player") or nil
    local currentCoords = position and { x = position.x, y = position.y } or nil

    -- Search all known vendors for a name match
    local allVendors = HA.VendorData:GetAllVendors()
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

                -- Stamp the corrected ID on this session's projected copy only;
                -- the durable record is npcIDCorrections above.
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
-- GetScannedVendors, GetScannedVendor, and Clear*
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
    emptySlotScansThisSession = {}
end

function VendorScanner:ClearNoDecorData()
    SP:ClearNoDecorData()
end

function VendorScanner:ClearAllData()
    SP:ClearAllData()
    scannedVendorsThisSession = {}
    emptySlotScansThisSession = {}
end

-------------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------------

function VendorScanner:GetNPCIDFromGUID(guid)
    if not guid then return nil end

    -- GUID format: Creature-0-XXXX-XXXX-XXXX-XXXXXXXX
    -- UnitGUID can return a restricted "secret string" in instanced content.
    -- Guard parsing with pcall so matching does not hard-error on restricted values.
    local ok, npcID = pcall(string.match, guid, "^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if not ok then
        return nil
    end

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

