--[[
    Homestead - CatalogScanner Module
    Scans known decor items to populate ownership cache

    This module scans items from the vendor database using GetCatalogEntryInfoByItem.
    This works around Blizzard API limitations where:
    - Category/subcategory enumeration doesn't expose entry data
    - CreateCatalogSearcher's own results are unusable from addon code (its Set*
      filter methods are tainted); but calling it + RunSearch() DOES force-load
      housing storage as a side effect (used below by the login-force-load path
      to warm data at login with no housing UI ever opened).

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

-- HS-273 R1: SEPARATE, weaker one-shot -- true as soon as storage data exists
-- at all (GetDecorMaxOwnedCount > 0), which is NOT the same claim as dataLoaded
-- above (per-item counts are live and safe to erase against). This is a
-- PREWARM SIGNAL only; it must never gate SetUnowned. See SetupEventScanning.
local storageResponded = false

-- HS-276: one-shot login force-load state. loginForceLoadAttempted guards the
-- PLAYER_ENTERING_WORLD deferred action (PEW fires every loading screen per
-- HS-218, not just initial login -- see SetupLoginForceLoad). pendingSearcher
-- holds the searcher object as GC insurance against the C++-side RunSearch()
-- side effect being collected before it completes; cleared once EITHER warm
-- flag latches (TryLatchWarmFromCounts), which covers the normal case (the
-- searcher's own RunSearch() forces the real HOUSING_STORAGE_UPDATED that
-- releases it) and a build where only dataLoaded ever latches.
local loginForceLoadAttempted = false
local loginForceLoadPendingCombat = false
local LOGIN_FORCE_LOAD_DELAY = 5 -- seconds; settle past loading-screen noise. Gate-2-tunable.
-- Write-only by design: its only job is to hold a reference, never to be read.
local pendingSearcher = nil -- luacheck: ignore 231

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

-- Shared warm-latch check. Sole caller is the HOUSING_STORAGE_UPDATED handler
-- below (HS-276 Gate 2, cycle 2: an earlier draft also called this from the
-- login-force-load path off a speculative pre-check; that path was removed
-- entirely -- see RunLoginStorageForceLoad's own comment -- so this is once
-- again the single latch site it was under HS-273). Body is copied VERBATIM
-- from the original HOUSING_STORAGE_UPDATED-only handler (HS-273) --
-- conditions and fire sites are pinned byte-identical by
-- tests/hs273_cold_prewarm_and_memo.lua; do not paraphrase.
-- Returns nothing on purpose: callers must decide on the CURRENT value of
-- dataLoaded/storageResponded, never on whether an edge flipped THIS call.
-- (Argus cycle 1: a this-call-edge decision on the login path created a
-- searcher against storage that was already warm, and dangled pendingSearcher.)
local function TryLatchWarmFromCounts()
    -- HS-273 R1: captured before the latch below runs, so the edge-fire
    -- guard just below can tell whether THIS call is dataLoaded's own
    -- false->true transition (this SITE fires at most once per session).
    -- EVENT CONTRACT (Argus cycle-2 SF2): across BOTH fire sites in this
    -- handler, HS_CATALOG_TRUE_WARM fires at least once and at most
    -- twice per session — a decor-owning player's first fully-loaded
    -- storage event trips both edges in one dispatch. Listeners must be
    -- idempotent/debounced (the sole current listener is a 1s
    -- cancel-and-restart debounce).
    local dataLoadedBefore = dataLoaded

    -- HOUSING_STORAGE_UPDATED is the signal that storage/ownership data
    -- has loaded for this session. Latch the warm-gate so SetUnowned may
    -- run — count fields are now authoritative, not stale-0. Corroborate
    -- with GetDecorTotalOwnedCount() > 0 before latching: a bare event
    -- can fire while counts are still stale-0, which would let SetUnowned
    -- wrongly clear ownership. A 0-decor character never latches, but
    -- SetUnowned is moot there anyway. (Plan design #2.)
    if (C_HousingCatalog.GetDecorTotalOwnedCount and C_HousingCatalog.GetDecorTotalOwnedCount() or 0) > 0 then
        dataLoaded = true
    end

    -- HS-273 R1: dataLoaded's own false->true edge is a true-warm signal
    -- in its own right, on top of storageResponded below — keeps the
    -- re-warm-on-true-warm requirement (Gate 0 finding 2) covered even
    -- for a session where dataLoaded latches without storageResponded
    -- ever firing (e.g. GetDecorMaxOwnedCount unavailable this build).
    if dataLoaded and not dataLoadedBefore and HA.Events then
        HA.Events:Fire("HS_CATALOG_TRUE_WARM")
    end

    -- HS-273 R1: storageResponded is a SEPARATE, weaker one-shot — proves
    -- storage data exists (Blizzard's own guard,
    -- Blizzard_HouseEditorStorageFrame.lua:9-14: GetDecorMaxOwnedCount is a
    -- static cap, non-zero the instant storage loads, ownership-independent)
    -- but NOT that per-item counts are live, so this is a PREWARM SIGNAL
    -- only — it must never gate SetUnowned's erase authorization, which
    -- stays on dataLoaded above exactly as pre-HS-273. Zero-decor players
    -- (whose dataLoaded never latches, Amendment A) still get this fire.
    if not storageResponded
            and (C_HousingCatalog.GetDecorMaxOwnedCount and C_HousingCatalog.GetDecorMaxOwnedCount() or 0) > 0 then
        storageResponded = true
        if HA.Events then
            HA.Events:Fire("HS_CATALOG_TRUE_WARM")
        end
    end

    -- HS-276: storage has now answered -- release the GC-insurance hold (if
    -- any) on a pending login-force-load searcher object. A searcher is held
    -- on EVERY login (Gate 2, cycle 2: the pre-check that used to skip it was
    -- removed), so this function's own latch here is exactly what proves the
    -- HOUSING_STORAGE_UPDATED that searcher's RunSearch() forced has now
    -- dispatched -- this IS that event's handler. Gated on EITHER flag:
    -- gating on storageResponded alone stranded the hold for the whole
    -- session on a build where GetDecorMaxOwnedCount is unavailable and only
    -- dataLoaded can latch (Argus cycle 3, pre-dates this redesign but still
    -- applies). Written on current state rather than a latch edge --
    -- assigning nil over nil is a no-op, so no edge tracking is needed.
    if storageResponded or dataLoaded then
        pendingSearcher = nil
    end
end

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
                -- HS-220: routed through RequestScan() instead of a direct,
                -- separately-timed ScanFullCatalog() call. RequestScan's own
                -- 1.0s debounce (below) already provides the same "let the
                -- housing UI settle" delay the old outer C_Timer.After(1,...)
                -- existed for, so this isn't losing that settle time — it's
                -- just not ALSO stacking a redundant second delay on top of
                -- it. This also means a HOUSING_STORAGE_UPDATED arriving
                -- around the same moment coalesces into the SAME debounced
                -- scan instead of two separate ones.
                RequestScan()
            end
        else
            if event == "HOUSING_STORAGE_UPDATED" then
                -- HS-276: latch logic lives in the shared TryLatchWarmFromCounts()
                -- (see above) -- this is its sole caller (Gate 2, cycle 2). This
                -- handler still unconditionally requests a scan below, exactly as
                -- before the extraction.
                TryLatchWarmFromCounts()
            end

            -- All housing events coalesce into a single debounced scan
            HA.Addon:Debug(event, "fired — requesting scan")
            RequestScan()
        end
    end)
end

-- HS-276: one-shot login force-load. Runs the actual force-load attempt --
-- unconditionally calls CreateCatalogSearcher():RunSearch() to force housing
-- storage to load with no housing UI ever opened (HS-273 Gate 2 searcher
-- probe finding), whether or not storage already looks warm (Gate 2, see
-- below for why no pre-check short-circuits this). Reschedules itself past
-- combat rather than firing into it, matching the established project
-- convention (UI/BadgeCalculation.lua's ProcessBatch combat-retry).
local function RunLoginStorageForceLoad()
    if _G.InCombatLockdown() then
        loginForceLoadPendingCombat = true
        return
    end

    -- Unlike the HOUSING_STORAGE_UPDATED handler, this path runs off an
    -- unconditional login timer, so the namespace's existence is not implied
    -- by an event having fired -- guard it before anything below dereferences it.
    if not C_HousingCatalog then
        HA.Addon:Debug("Login storage force-load skipped: C_HousingCatalog unavailable")
        return
    end

    -- No pre-check short-circuit (HS-276 Gate 2, second finding): an earlier
    -- draft skipped the searcher here whenever GetDecorTotalOwnedCount/
    -- GetDecorMaxOwnedCount already read nonzero, treating that as proof
    -- storage was fully warm. Gate 2 testing proved that's false -- those
    -- aggregate counters can read nonzero while GetCatalogEntryInfoByItem is
    -- still stale-0 (a warm /reload reproduced this: Owned read 995 right
    -- after a cold login, then 0 on the very next reload), and confirmed
    -- HOUSING_STORAGE_UPDATED never fires on its own on a warm reload -- so
    -- the short-circuit's "parity rescan" ran with untrustworthy per-item
    -- data and, because dataLoaded was already (wrongly) latched, erased
    -- real ownership. A follow-up patch (skipErasure) suppressed the erasure
    -- on that one call site but left five other dataLoaded readers exposed
    -- to the same premature latch -- the next ordinary housing event
    -- (NEW_HOUSING_ITEM_ACQUIRED etc.) reproduced the wipe through the
    -- unmodified live path.
    --
    -- Verified instead (live, 2026-08-09): calling CreateCatalogSearcher():
    -- RunSearch() when the aggregate counters already read warm is safe (no
    -- error) and DOES force a real HOUSING_STORAGE_UPDATED to fire, which
    -- then correctly reports the true owned count. So the searcher is now
    -- created unconditionally every time -- dataLoaded/storageResponded are
    -- latched ONLY by the real event handler (SetupEventScanning), exactly
    -- as before this ticket existed. That's what keeps erasure-authorization
    -- trustworthy: it can never fire on anything but a genuine engine signal.
    if type(C_HousingCatalog.CreateCatalogSearcher) ~= "function" then
        HA.Addon:Debug("Login storage force-load skipped: CreateCatalogSearcher unavailable")
        return
    end

    -- No Set* filter calls on the searcher -- RunSearch() unconfigured is the
    -- safe/untainted call (every Set* method carries
    -- SecretArguments="AllowedWhenUntainted"; RunSearch() carries none).
    local createOk, searcher = pcall(C_HousingCatalog.CreateCatalogSearcher)
    if not createOk or not searcher then
        HA.Addon:Debug("Login storage force-load: CreateCatalogSearcher failed:", searcher)
        return
    end

    local runOk, runErr = pcall(searcher.RunSearch, searcher)
    if not runOk then
        HA.Addon:Debug("Login storage force-load: RunSearch failed:", runErr)
        return
    end

    -- GC insurance against the C++-side effect being collected before it
    -- completes. Cleared inside TryLatchWarmFromCounts once either flag
    -- latches (the HOUSING_STORAGE_UPDATED this RunSearch() call triggers) --
    -- no separate timeout timer needed.
    pendingSearcher = searcher
end

-- Registers a SEPARATE frame from SetupEventScanning's -- that frame's
-- OnEvent treats every non-ADDON_LOADED event as "housing event, request a
-- scan" (see above), so adding PLAYER_ENTERING_WORLD/PLAYER_REGEN_ENABLED to
-- it would wrongly fire RequestScan() on every ordinary loading screen, not
-- just initial login. Shape copied from CalendarDetector:Initialize (own
-- frame, session-scoped one-shot guard for PEW firing every loading screen
-- per HS-218).
local function SetupLoginForceLoad()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            if loginForceLoadAttempted then return end
            loginForceLoadAttempted = true
            C_Timer.After(LOGIN_FORCE_LOAD_DELAY, RunLoginStorageForceLoad)
        elseif event == "PLAYER_REGEN_ENABLED" then
            if loginForceLoadPendingCombat then
                loginForceLoadPendingCombat = false
                RunLoginStorageForceLoad()
            end
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

-- HS-273 (Gate 1 closure): whether storage answered AT ALL this session —
-- the weak half of R1's two-flag split, exposed for consumers that need to
-- distinguish "storage answered and the live total is zero" (a zero-decor
-- player's CONFIRMED-true zero) from "storage never answered" (unknown).
-- Never an erase authorization — that stays on IsWarm/dataLoaded above.
function CatalogScanner:HasStorageResponded()
    return storageResponded
end

function CatalogScanner:Initialize()
    if isInitialized then return end

    -- Set up event-based scanning
    SetupEventScanning()

    -- HS-276: set up the one-shot login force-load (searcher side effect)
    SetupLoginForceLoad()

    -- Do an initial scan after a delay
    C_Timer.After(3, function()
        if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
            -- HS-216: don't scan cold — before dataLoaded latches, count fields
            -- read stale-0, so this would burn ~1,600 API calls for zero learned
            -- data (observed live: "Checked: 1624 Owned: 0"); the existing
            -- HOUSING_STORAGE_UPDATED handler below already re-requests a full
            -- scan the moment it latches, so skipping here loses no coverage.
            -- Zero-decor accounts (HS-180) never latch dataLoaded and so never
            -- get an initial scan either, but that's a no-op regardless — the
            -- cache stays empty because nothing was ever going to be found.
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
