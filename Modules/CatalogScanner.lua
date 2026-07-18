--[[
    Homestead - CatalogScanner Module
    Scans known decor items to populate ownership cache

    This module scans items from the vendor database using GetCatalogEntryInfoByItem.
    This works around Blizzard API limitations where:
    - Category/subcategory enumeration doesn't expose entry data
    - CreateCatalogSearcher is internal-only

    Ownership is derived from Blizzard's GetEntryTotalOwned contract
    (totalNumStored + remainingRedeemable + totalNumPlaced > 0) via
    CatalogStore:ComputeOwnedFromInfo. Those count fields are stale-0 cold
    (before storage data loads), so SetUnowned is warm-gated on dataLoaded —
    the scanner never erases ownership from a cold read.

    Strategy: Scan all known item IDs from VendorDatabase and scannedVendors,
    using the same API that tooltips use (GetCatalogEntryInfoByItem).
]]

local _, HA = ...

local CatalogScanner = {}
HA.CatalogScanner = CatalogScanner

-- Local state
local isInitialized = false
local isScanning = false
local lastScanTime = 0
local SCAN_COOLDOWN = 5 -- Minimum seconds between scans
local pendingScanTimer = nil
local scanRequestedDuringActive = false

-- Warm-gate for ownership erasure. The catalog count fields (totalNumStored etc.)
-- are stale-0 until storage data loads, so a cold scan reads every owned item as
-- not-owned. SetUnowned must therefore run ONLY once storage data is known loaded.
-- Set true on the first HOUSING_STORAGE_UPDATED of the session. SetOwned needs no
-- gate (counts are only > 0 warm, so it never false-positives cold).
local dataLoaded = false

-- Batching settings to prevent frame hitches
local ITEMS_PER_BATCH = 20
local BATCH_DELAY = 0.01 -- seconds between batches

-------------------------------------------------------------------------------
-- Ownership Detection
-------------------------------------------------------------------------------

-- Check if an item info table indicates ownership.
-- Delegates to CatalogStore:ComputeOwnedFromInfo — Blizzard's GetEntryTotalOwned
-- contract (totalNumStored + remainingRedeemable + totalNumPlaced > 0). This is
-- the single source of truth for ownership derivation. These count fields are
-- stale-0 cold (before storage data loads), which is why the scanner warm-gates
-- the SetUnowned branches below.
local function IsOwned(info)
    if not info then return false end
    if HA.CatalogStore then
        return HA.CatalogStore:ComputeOwnedFromInfo(info)
    end
    -- Fallback if CatalogStore is unavailable (should not happen given load order):
    -- replicate the count formula directly. quantity/numPlaced are aliases of
    -- totalNumStored/totalNumPlaced.
    local totalNumStored = info.totalNumStored or info.quantity or 0
    local totalNumPlaced = info.totalNumPlaced or info.numPlaced or 0
    local remainingRedeemable = info.remainingRedeemable or 0
    return (totalNumStored + remainingRedeemable + totalNumPlaced) > 0
end

local function ExtractRecordID(info)
    if not info or not info.entryID or type(info.entryID) ~= "table" then
        return nil
    end

    local recordID = info.entryID.recordID
    if recordID then
        return recordID
    end

    for k, v in pairs(info.entryID) do
        if k == "recordID" then
            return v
        end
    end

    return nil
end

local function BuildScanResult(itemID, info, fallbackRecordID)
    if not itemID or not info then return nil end

    local recordID = ExtractRecordID(info) or fallbackRecordID
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

    -- Collect from static vendor accessors.
    if HA.VendorData and HA.VendorData.GetAllVendors and HA.VendorData.GetItemsForVendor then
        local allVendors = HA.VendorData:GetAllVendors()
        for _, vendor in ipairs(allVendors) do
            local vendorItems = HA.VendorData:GetItemsForVendor(vendor)
            for _, item in ipairs(vendorItems) do
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

    -- Collect craft-only décor itemIDs (HS-024). ProfessionSources is keyed by
    -- catalog itemID and is the exact domain ShouldBadgeRecipe reads via
    -- cache-only IsOwned; it also backs GetOwnedCount / GetOwnedItemsBySourceType.
    -- Shares the `seen` table with the vendor blocks above, so any itemID a vendor
    -- already inserted is skipped here — vendor records (with vendor name) win,
    -- and the craft block adds only the genuinely net-new itemIDs.
    if HA.ProfessionSources then
        for craftItemID in pairs(HA.ProfessionSources) do
            if type(craftItemID) == "number" and not seen[craftItemID] then
                seen[craftItemID] = true
                table.insert(itemIDs, {
                    itemID = craftItemID,
                    name = nil,  -- fetched during ScanItem like vendor items
                })
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
    if not C_HousingCatalog then
        return nil
    end

    local byItemResult = nil

    if C_HousingCatalog.GetCatalogEntryInfoByItem then
        local itemLink = "item:" .. tostring(itemID)
        local success, info = pcall(function()
            return C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, true)
        end)

        if success and info then
            if IsOwned(info) then
                return BuildScanResult(itemID, info)
            end
            -- byItem returned info with 0 counts — save result but fall through to
            -- RecordID probe. Some items (e.g. 244778, HS-059) return stale-0 via
            -- byItem even when owned; RecordID is authoritative for those.
            byItemResult = BuildScanResult(itemID, info)
        end
    end

    local catalogStore = HA.CatalogStore
    if catalogStore and catalogStore.GetDecorIDFromItemID and catalogStore.ProbeByDecorID then
        local decorID = catalogStore:GetDecorIDFromItemID(itemID)
        if decorID then
            local info = catalogStore:ProbeByDecorID(decorID)
            if info then
                return BuildScanResult(itemID, info, decorID)
            end
        end
    end

    return byItemResult
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

                    -- Write to CatalogStore, the canonical ownership store.
                    if HA.CatalogStore then
                        if result.isOwned then
                            -- Full path for owned items
                            HA.CatalogStore:SetOwned(result.itemID, result.name or itemData.name, result.recordID)
                            HA.CatalogStore:Save(result.itemID, {
                                lastScanned = time(),
                            })
                        else
                            -- Warm-gate: only erase ownership once storage data is
                            -- loaded. Cold reads are stale-0 and would wrongly clear
                            -- owned items; the persistent cache serves them instead.
                            if dataLoaded and HA.CatalogStore:IsOwned(result.itemID) then
                                HA.CatalogStore:SetUnowned(result.itemID)
                            end
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

            -- HS-209 M3: removed an unconditional OWNERSHIP_UPDATED fire that
            -- lived here — it checked HA.Events.TriggerEvent/.FireEvent (methods
            -- that don't exist on Events), so both `if`/`elseif` conditions were
            -- always false and it always fell through to the final branch,
            -- firing on every scan regardless of whether anything actually
            -- changed, and double-firing on real changes since EndBatch above
            -- already fires OWNERSHIP_UPDATED conditionally on
            -- batchOwnershipChanged. EndBatch is the sole owner of this fire.

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
                        HA.CatalogStore:Save(result.itemID, {
                            lastScanned = time(),
                        })
                    end
                    ownedCount = ownedCount + 1
                elseif HA.CatalogStore then
                    -- Warm-gate: only erase ownership once storage data is loaded
                    -- (see ProcessBatch above and the dataLoaded comment).
                    if dataLoaded and HA.CatalogStore:IsOwned(result.itemID) then
                        HA.CatalogStore:SetUnowned(result.itemID)
                    end
                    HA.CatalogStore:Save(result.itemID, {
                        decorID = result.recordID,
                        name = result.name or itemData.name,
                        lastScanned = time(),
                    })
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
            -- HOUSING_STORAGE_UPDATED is the signal that storage/ownership data
            -- has loaded for this session. Latch the warm-gate so SetUnowned may
            -- run — count fields are now authoritative, not stale-0. Corroborate
            -- with GetDecorTotalOwnedCount() > 0 before latching: a bare event
            -- can fire while counts are still stale-0, which would let SetUnowned
            -- wrongly clear ownership. A 0-decor character never latches, but
            -- SetUnowned is moot there anyway. (Plan design #2.)
            if event == "HOUSING_STORAGE_UPDATED"
                and (C_HousingCatalog.GetDecorTotalOwnedCount and C_HousingCatalog.GetDecorTotalOwnedCount() or 0) > 0 then
                dataLoaded = true
            end
            -- All housing events coalesce into a single debounced scan
            HA.Addon:Debug(event, "fired — requesting scan")
            RequestScan()
        end
    end)
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

-- Whether storage/ownership data has loaded for this session (see the
-- dataLoaded warm-gate above). Exposed so other modules can gate their own
-- session-only negative-caching decisions on the same single source of
-- truth CatalogScanner already tracks, instead of re-deriving warmness.
function CatalogScanner:IsWarm()
    return dataLoaded
end

function CatalogScanner:Initialize()
    if isInitialized then return end

    -- Set up event-based scanning
    SetupEventScanning()

    -- Do an initial scan after a delay
    C_Timer.After(3, function()
        if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
            -- HS-216: don't scan cold. Before HOUSING_STORAGE_UPDATED latches
            -- dataLoaded (see IsWarm above), every item's count fields read
            -- stale-0 — the warm-gate on SetUnowned correctly stops that from
            -- erasing ownership, but the scan itself still burns ~1,600
            -- Housing API calls in the login window for zero learned data
            -- (observed live: "Checked: 1624 Owned: 0"). The existing
            -- HOUSING_STORAGE_UPDATED handler below already calls
            -- RequestScan() unconditionally the moment it latches warm, and
            -- RequestScan debounces into CatalogScanner:ScanFullCatalog() —
            -- a FULL scan, not incremental — so skipping here loses no
            -- coverage; the real scan still happens once data is warm.
            --
            -- Zero-decor accounts (HS-180's known limitation: dataLoaded
            -- never latches without at least one owned decor item to
            -- corroborate GetDecorTotalOwnedCount() > 0) now run NO initial
            -- scan instead of a cold, useless one. This degrades identically
            -- from the player's perspective: the ownership cache starts and
            -- stays empty either way (nothing was ever going to be found),
            -- and every other scan trigger — vendor visits, the
            -- ADDON_LOADED Blizzard_Housing one-shot below, manual /commands
            -- — is untouched and still fires normally.
            if not CatalogScanner:IsWarm() then
                HA.Addon:Debug("Initial catalog scan skipped — not warm yet; "
                    .. "HOUSING_STORAGE_UPDATED will trigger the real scan once data loads")
                return
            end
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
