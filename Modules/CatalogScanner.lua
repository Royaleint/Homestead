--[[
    Homestead - CatalogScanner Module
    Scans known decor items to populate ownership cache

    This module scans items from the vendor database using GetCatalogEntryInfoByItem.
    This works around Blizzard API limitations where:
    - Category/subcategory enumeration doesn't expose entry data
    - CreateCatalogSearcher is internal-only
    - firstAcquisitionBonus == 0 handles stale qty/placed data post-reload

    Strategy: Scan all known item IDs from VendorDatabase and scannedVendors,
    using the same API that tooltips use (GetCatalogEntryInfoByItem).
]]

local _, HA = ...

-- Create CatalogScanner module
local CatalogScanner = {}
HA.CatalogScanner = CatalogScanner

-- Local state
local isInitialized = false
local isScanning = false
local lastScanTime = 0
local SCAN_COOLDOWN = 5 -- Minimum seconds between scans
local pendingScanTimer = nil
local scanRequestedDuringActive = false

-- Batching settings to prevent frame hitches
local ITEMS_PER_BATCH = 20
local BATCH_DELAY = 0.01 -- seconds between batches

-------------------------------------------------------------------------------
-- Ownership Detection
-------------------------------------------------------------------------------

-- Check if an item info table indicates ownership
local function IsOwned(info)
    if not info then return false end

    -- Check quantity indicators
    local quantity = info.quantity or 0
    local numPlaced = info.numPlaced or 0
    local remainingRedeemable = info.remainingRedeemable or 0
    local firstAcquisitionBonus = info.firstAcquisitionBonus

    -- firstAcquisitionBonus == 0 reliably detects ownership even when qty/placed are stale (post-reload)
    if quantity > 0 or numPlaced > 0 or remainingRedeemable > 0 or firstAcquisitionBonus == 0 then
        return true
    end

    -- Check entrySubtype (top-level first, then nested in entryID)
    -- Enum.HousingCatalogEntrySubtype: Invalid=0, Unowned=1, OwnedModifiedStack=2, OwnedUnmodifiedStack=3
    local entrySubtype = info.entrySubtype
    if not entrySubtype and info.entryID and type(info.entryID) == "table" then
        entrySubtype = info.entryID.entrySubtype
        if not entrySubtype then
            for k, v in pairs(info.entryID) do
                if k == "entrySubtype" then
                    entrySubtype = v
                    break
                end
            end
        end
    end

    if entrySubtype and entrySubtype >= 2 then
        return true
    end

    -- Check isOwned field if present
    if info.isOwned then
        return true
    end

    return false
end

-------------------------------------------------------------------------------
-- Ownership Cache Management (Phase 2: writes go through CatalogStore)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Item Collection
-------------------------------------------------------------------------------

-- Gather all unique item IDs from vendor database and scanned vendors
local function CollectAllKnownItemIDs()
    local itemIDs = {}
    local seen = {}

    -- Collect from static vendor database
    -- New format: items can be plain integers OR tables with cost data
    if HA.VendorData and HA.VendorData.GetAllVendors then
        local allVendors = HA.VendorData:GetAllVendors()
        for _, vendor in ipairs(allVendors) do
            if vendor.items then
                for _, item in ipairs(vendor.items) do
                    -- Handle both formats: plain number or table with cost
                    local itemID = HA.VendorData:GetItemID(item)
                    if itemID and not seen[itemID] then
                        seen[itemID] = true
                        table.insert(itemIDs, {
                            itemID = itemID,
                            name = nil,  -- Will be fetched by GetItemInfo later
                        })
                    end
                end
            end
        end
    end

    -- Collect from scanned vendors (dynamic data)
    if HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
        for npcID, vendorData in pairs(HA.Addon.db.global.scannedVendors) do
            local scannedItems = vendorData.items
            if scannedItems then
                for _, item in ipairs(scannedItems) do
                    if item.itemID and not seen[item.itemID] then
                        seen[item.itemID] = true
                        table.insert(itemIDs, {
                            itemID = item.itemID,
                            name = item.name,
                        })
                    end
                end
            end
        end
    end

    return itemIDs
end

-------------------------------------------------------------------------------
-- Catalog Scanning
-------------------------------------------------------------------------------

-- Scan a single item by itemID
local function ScanItem(itemID)
    if not itemID or type(itemID) ~= "number" then return nil end
    if not C_HousingCatalog or not C_HousingCatalog.GetCatalogEntryInfoByItem then
        return nil
    end

    local itemLink = "item:" .. tostring(itemID)
    local success, info = pcall(function()
        return C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, true)
    end)

    if not success or not info then
        return nil
    end

    -- Extract recordID from entryID table (defensive against partial/non-table entryID)
    local recordID = nil
    if info.entryID and type(info.entryID) == "table" then
        recordID = info.entryID.recordID
        if not recordID then
            for k, v in pairs(info.entryID) do
                if k == "recordID" then recordID = v; break end
            end
        end
    end

    return {
        itemID = itemID,
        name = info.name,
        isOwned = IsOwned(info),
        quantity = info.quantity or 0,
        numPlaced = info.numPlaced or 0,
        sourceText = info.sourceText,
        recordID = recordID,
    }
end

-- Debounced scan request — coalesces rapid housing events into a single scan
-- Forward-declared here so ScanFullCatalog's ProcessBatch can reference it
local function RequestScan()
    if pendingScanTimer then
        pendingScanTimer:Cancel()
    end
    pendingScanTimer = C_Timer.NewTimer(1.0, function()
        pendingScanTimer = nil
        if isScanning then
            -- Scan in progress — flag for rescan when it finishes
            scanRequestedDuringActive = true
        else
            CatalogScanner:ScanFullCatalog()
        end
    end)
end

-- Perform a full scan of all known items (batched for performance)
function CatalogScanner:ScanFullCatalog(callback)
    if isScanning then
        HA.Addon:Debug("Catalog scan already in progress")
        return
    end

    local currentTime = GetTime()
    if currentTime - lastScanTime < SCAN_COOLDOWN then
        HA.Addon:Debug("Catalog scan on cooldown")
        return
    end

    if not C_HousingCatalog then
        HA.Addon:Debug("C_HousingCatalog not available")
        return
    end

    isScanning = true
    lastScanTime = currentTime

    -- Begin batch mode on CatalogStore to suppress per-item events
    if HA.CatalogStore then
        HA.CatalogStore:BeginBatch()
    end

    HA.Addon:Debug("Starting catalog scan (item-by-item method)...")

    -- Collect all known item IDs
    local itemList = CollectAllKnownItemIDs()
    local totalItems = #itemList
    local currentIndex = 1
    local ownedCount = 0
    local checkedCount = 0

    HA.Addon:Debug("Found", totalItems, "unique items to scan")

    if totalItems == 0 then
        isScanning = false
        if HA.CatalogStore then
            HA.CatalogStore:EndBatch()
        end
        HA.Addon:Debug("No items to scan - vendor database may be empty")
        if callback then callback(0, 0) end
        return
    end

    -- Process items in batches to prevent frame hitches
    local function ProcessBatch()
        local batchEnd = math.min(currentIndex + ITEMS_PER_BATCH - 1, totalItems)

        for i = currentIndex, batchEnd do
            local itemData = itemList[i]
            if itemData and itemData.itemID then
                local result = ScanItem(itemData.itemID)
                if result then
                    checkedCount = checkedCount + 1
                    if result.isOwned then
                        ownedCount = ownedCount + 1
                    end

                    -- Write to CatalogStore (handles dual-write to ownedDecor internally)
                    if HA.CatalogStore then
                        if result.isOwned then
                            -- Full path for owned items
                            HA.CatalogStore:SetOwned(result.itemID, result.name or itemData.name, result.recordID)
                            HA.CatalogStore:Save(result.itemID, {
                                lastScanned = time(),
                            })
                        else
                            -- Minimal fields for unowned items
                            HA.CatalogStore:Save(result.itemID, {
                                decorID = result.recordID,
                                name = result.name or itemData.name,
                                lastScanned = time(),
                            })
                        end
                    end

                    -- Forward sourceText to SourceTextScanner for parsing
                    if result.sourceText and HA.SourceTextScanner then
                        HA.SourceTextScanner:ProcessScannedItem(result)
                    end
                end
            end
        end

        currentIndex = batchEnd + 1

        -- Continue with next batch or finish
        if currentIndex <= totalItems then
            C_Timer.After(BATCH_DELAY, ProcessBatch)
        else
            -- Scan complete
            isScanning = false

            -- End batch mode on CatalogStore (fires single OWNERSHIP_UPDATED + CATALOG_ITEM_UPDATED)
            if HA.CatalogStore then
                HA.CatalogStore:EndBatch()
            end

            HA.Addon:Debug("Catalog scan complete. Checked:", checkedCount, "Owned:", ownedCount)

            -- Fire event so other modules know ownership data is updated
            if HA.Events and HA.Events.TriggerEvent then
				HA.Events:Fire("OWNERSHIP_UPDATED")
			elseif HA.Events and HA.Events.FireEvent then
				HA.Events:FireEvent("OWNERSHIP_UPDATED")
			elseif HA.Events and HA.Events.Fire then
				HA.Events:Fire("OWNERSHIP_UPDATED")
			end

            if callback then
                callback(ownedCount, checkedCount)
            end

            -- If a scan was requested while we were running, schedule another
            if scanRequestedDuringActive then
                scanRequestedDuringActive = false
                RequestScan()
            end
        end
    end

    -- Start the first batch
    ProcessBatch()
end

-- Synchronous scan (for debugging - may cause frame hitch with large databases)
function CatalogScanner:ScanFullCatalogSync()
    if not C_HousingCatalog then
        return 0, 0
    end

    local itemList = CollectAllKnownItemIDs()
    local ownedCount = 0
    local checkedCount = 0

    for _, itemData in ipairs(itemList) do
        if itemData.itemID then
            local result = ScanItem(itemData.itemID)
            if result then
                checkedCount = checkedCount + 1
                if result.isOwned then
                    if HA.CatalogStore then
                        HA.CatalogStore:SetOwned(result.itemID, result.name or itemData.name, result.recordID)
                    end
                    ownedCount = ownedCount + 1
                end
            end
        end
    end

    return ownedCount, checkedCount
end

-------------------------------------------------------------------------------
-- Event-Based Scanning
-------------------------------------------------------------------------------

local function SetupEventScanning()
    local eventFrame = CreateFrame("Frame")

    -- Register for housing-related events
    eventFrame:RegisterEvent("ADDON_LOADED")

    -- These events indicate ownership may have changed
    local housingEvents = {
        "HOUSING_STORAGE_UPDATED",
        "NEW_HOUSING_ITEM_ACQUIRED",
        "HOUSING_DECOR_PLACE_SUCCESS",
        "HOUSING_DECOR_REMOVED",
    }

    for _, event in ipairs(housingEvents) do
        pcall(function()
            eventFrame:RegisterEvent(event)
        end)
    end

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "ADDON_LOADED" then
            local loadedAddon = ...
            -- Check if a Blizzard housing UI addon loaded
            if loadedAddon and loadedAddon:match("^Blizzard_Housing") then
                HA.Addon:Debug("Housing addon loaded:", loadedAddon)
                -- One-time startup scan — direct call, not debounced
                C_Timer.After(1, function()
                    CatalogScanner:ScanFullCatalog()
                end)
            end
        else
            -- All housing events coalesce into a single debounced scan
            HA.Addon:Debug(event, "fired — requesting scan")
            RequestScan()
        end
    end)
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function CatalogScanner:Initialize()
    if isInitialized then return end

    -- Set up event-based scanning
    SetupEventScanning()

    -- Do an initial scan after a delay
    C_Timer.After(3, function()
        if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
            HA.Addon:Debug("Attempting initial catalog scan...")
            CatalogScanner:ScanFullCatalog()
        end
    end)

    isInitialized = true
    HA.Addon:Debug("CatalogScanner initialized (item-by-item method)")
end

-------------------------------------------------------------------------------
-- Manual Commands
-------------------------------------------------------------------------------

-- Manual scan command
function CatalogScanner:ManualScan()
    self:ScanFullCatalog(function(owned, checked)
        HA.Addon:Print("Catalog scan complete.")
        HA.Addon:Print("  Items checked:", checked)
        HA.Addon:Print("  Items owned:", owned)

        -- Show API total for comparison
        if C_HousingCatalog and C_HousingCatalog.GetDecorTotalOwnedCount then
            local apiTotal = C_HousingCatalog.GetDecorTotalOwnedCount()
            HA.Addon:Print("  API reports total owned:", apiTotal)
            if owned < apiTotal then
                HA.Addon:Print("  Note: You own items not in the vendor database.")
                HA.Addon:Print("  These may be from quests, achievements, or drops.")
            end
        end

        if checked == 0 then
            HA.Addon:Print("  Warning: No items found in vendor database.")
            HA.Addon:Print("  Visit vendors to scan their inventory.")
        end
    end)
end

-- Debug scan to show raw API data for sample items
function CatalogScanner:DebugScan()
    if not C_HousingCatalog then
        HA.Addon:Debug("C_HousingCatalog not available")
        return
    end

    HA.Addon:Debug("=== Debug Catalog Scan ===")

    -- Show API totals
    local totalOwned = C_HousingCatalog.GetDecorTotalOwnedCount and C_HousingCatalog.GetDecorTotalOwnedCount() or "N/A"
    local maxOwned = C_HousingCatalog.GetDecorMaxOwnedCount and C_HousingCatalog.GetDecorMaxOwnedCount() or "N/A"
    HA.Addon:Debug("API Total Owned:", totalOwned)
    HA.Addon:Debug("API Max Owned:", maxOwned)

    -- Show known item count
    local itemList = CollectAllKnownItemIDs()
    HA.Addon:Debug("Known items in database:", #itemList)

    -- Show cache size
    local cacheSize = HA.CatalogStore and HA.CatalogStore:GetOwnedCount() or 0
    HA.Addon:Debug("Items in ownership cache:", cacheSize)

    -- Test a few items
    HA.Addon:Debug("--- Sample Item Checks ---")
    local sampleCount = 0
    for _, itemData in ipairs(itemList) do
        if sampleCount >= 5 then break end
        if itemData.itemID then
            local itemLink = "item:" .. itemData.itemID
            local info = C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, true)
            if info then
                sampleCount = sampleCount + 1
                local owned = IsOwned(info) and "YES" or "NO"
                HA.Addon:Debug(string.format("  %d: %s - Owned: %s (qty:%d placed:%d)",
                    itemData.itemID,
                    info.name or "Unknown",
                    owned,
                    info.quantity or 0,
                    info.numPlaced or 0
                ))
            end
        end
    end

    if sampleCount == 0 then
        HA.Addon:Debug("  No items could be checked. Visit vendors to populate database.")
    end
end

-- Get current scan stats
function CatalogScanner:GetStats()
    local itemList = CollectAllKnownItemIDs()
    local cacheSize = HA.CatalogStore and HA.CatalogStore:GetOwnedCount() or 0

    local apiTotal = 0
    if C_HousingCatalog and C_HousingCatalog.GetDecorTotalOwnedCount then
        apiTotal = C_HousingCatalog.GetDecorTotalOwnedCount()
    end

    return {
        knownItems = #itemList,
        cachedOwned = cacheSize,
        apiTotalOwned = apiTotal,
        isScanning = isScanning,
    }
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

-- Register with main addon when it's ready
if HA.Addon then
    HA.Addon:RegisterModule("CatalogScanner", CatalogScanner)
end
