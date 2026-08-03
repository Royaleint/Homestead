-- luacheck: globals assert loadfile print io time os loadstring C_Timer MapSidePanel Enum

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-- WoW exposes `time` as a bare global (mirrors os.time); ScanPersistence calls
-- it unqualified. Stubbed as an incrementing counter (not real os.time) so
-- every SaveVendorData call in this file gets a DISTINCT, deterministic
-- timestamp — a real-clock stub could land two calls in the same wall-clock
-- second and hide a lastScanned-laundering regression behind a same-value
-- coincidence.
local fakeClock = 1000
time = function()
    fakeClock = fakeClock + 1
    return fakeClock
end

-- HS-249: ScanPersistence now separates decor from the wider housing item
-- class, so it reads the subclass enum. WoW provides `Enum` as a bare global;
-- this harness stubs only the members ScanPersistence actually indexes.
Enum = {
    ItemHousingSubclass = {
        Decor = 0,
        Dye = 1,
        Room = 2,
        RoomCustomization = 3,
        ExteriorCustomization = 4,
        ServiceItem = 5,
    },
}

-------------------------------------------------------------------------------
-- HS-210 (M10b): an unconfirmed (laggy/partial) scan must not clobber a
-- larger, cleaner existing record. scanConfidence is now computed BEFORE the
-- save decision instead of after it (the ordering bug), and a scan with fewer
-- decor items than the existing record is rejected unless it's confirmed.
-------------------------------------------------------------------------------

local ScanHA = {
    Addon = {
        db = { global = {} },
        Debug = function() end,
    },
    VendorData = {
        HasVendor = function() return false end,
        BuildScannedIndex = function() end,
        InvalidateVendorCaches = function() end,
    },
    CatalogStore = {
        SetRequirements = function() end,
        Save = function() end,
    },
    Events = {
        Fire = function() end,
    },
    DevAddon = true,
}

assert(loadfile(root .. "/Modules/ScanPersistence.lua"))("Homestead", ScanHA)

local function MakeDecorItems(count)
    local items = {}
    for i = 1, count do
        items[i] = {
            itemID = 4000 + i,
            name = "Test Decor " .. i,
            decorID = 5000 + i,
            subclassID = Enum.ItemHousingSubclass.Decor,
            price = 100,
            merchantSlot = i,
        }
    end
    return items
end

-- First scan: complete, confirmed, 3 decor items. Establishes the baseline.
ScanHA.ScanPersistence:SaveVendorData({
    npcID = 8001,
    vendorName = "Test Vendor",
    mapID = 1,
    coords = { x = 0.5, y = 0.5 },
    faction = "Neutral",
    housingItems = MakeDecorItems(3),
    scanComplete = true,
    hadNilSlots = false,
})

local stored = ScanHA.Addon.db.global.scannedVendors[8001]
assert(stored ~= nil, "expected the first (confirmed) scan to persist")
assert(#stored.items == 3, "expected 3 items from the first scan")
assert(stored.scanConfidence == "confirmed")
local originalLastScanned = stored.lastScanned

-- Second scan: same vendor, UNCONFIRMED (nil merchant slots skipped, no
-- retry), only 1 decor item — fewer than the existing 3. Must NOT replace
-- the existing (larger, confirmed) record.
ScanHA.ScanPersistence:SaveVendorData({
    npcID = 8001,
    vendorName = "Test Vendor",
    mapID = 1,
    coords = { x = 0.5, y = 0.5 },
    faction = "Neutral",
    housingItems = MakeDecorItems(1),
    scanComplete = true,
    hadNilSlots = true, -- unconfirmed
})

local afterPartialScan = ScanHA.Addon.db.global.scannedVendors[8001]
assert(afterPartialScan ~= nil, "existing record must survive an unconfirmed partial scan")
assert(#afterPartialScan.items == 3,
    "an unconfirmed scan with fewer items must not clobber the existing 3-item record")

-- Argus cycle 1 CRITICAL: rejecting the scan must not re-date the preserved
-- record. lastScanned means "these items were observed at this time" — this
-- attempt observed neither the full item set nor confirmed data, so
-- lastScanned must be untouched. The attempt itself is recorded separately.
assert(afterPartialScan.lastScanned == originalLastScanned,
    "a rejected (unconfirmed, smaller) scan must NOT update lastScanned on the preserved record")
assert(afterPartialScan.lastScanAttempt ~= nil and afterPartialScan.lastScanAttempt ~= originalLastScanned,
    "the rejected attempt must still be recorded, but on lastScanAttempt, not lastScanned")

-- Third scan: same vendor, CONFIRMED, only 1 decor item. A confirmed scan
-- finding fewer items is real data, not a lag artifact — it MUST replace.
ScanHA.ScanPersistence:SaveVendorData({
    npcID = 8001,
    vendorName = "Test Vendor",
    mapID = 1,
    coords = { x = 0.5, y = 0.5 },
    faction = "Neutral",
    housingItems = MakeDecorItems(1),
    scanComplete = true,
    hadNilSlots = false, -- confirmed
})

local afterConfirmedScan = ScanHA.Addon.db.global.scannedVendors[8001]
assert(afterConfirmedScan ~= nil)
assert(#afterConfirmedScan.items == 1,
    "a confirmed scan with fewer items must replace the existing record")

print("hs210_guards: M10b partial-scan-does-not-clobber ok")

-------------------------------------------------------------------------------
-- HS-249 (Argus cycle 1 CRITICAL): the same protection must hold for records
-- written BEFORE the housing gate existed. Those carry decorCount/hasDecor and
-- no housingCount, so a guard reading `existingData.housingCount or 0` degrades
-- to `0 > n` — never true — and the first laggy rescan after an update destroys
-- a record it was supposed to defend. That is every existing user's saved data,
-- not an edge case.
--
-- The fixture below is seeded DIRECTLY into the DB in the legacy shape rather
-- than through SaveVendorData, which is the whole point: every other fixture in
-- this file builds its baseline with current code, so `housingCount` is always
-- present and the legacy path is never exercised. That gap is what let the bug
-- through Gate 1 cycle 1.
-------------------------------------------------------------------------------

local function MakeLegacyItems(count)
    local items = {}
    for i = 1, count do
        items[i] = {
            itemID = 4000 + i,
            name = "Legacy Decor " .. i,
            decorID = 5000 + i,
            -- No subclassID: pre-HS-249 records predate the field entirely.
            price = 100,
            merchantSlot = i,
        }
    end
    return items
end

ScanHA.Addon.db.global.scannedVendors[8002] = {
    npcID = 8002,
    vendorName = "Legacy Vendor",
    mapID = 1,
    coords = { x = 0.5, y = 0.5 },
    faction = "Neutral",
    items = MakeLegacyItems(10),
    decorCount = 10,
    hasDecor = true,
    itemCount = 10,
    lastScanned = 500,
    scanConfidence = "confirmed",
    -- housingCount / hasHousing deliberately absent — the legacy shape.
}

ScanHA.ScanPersistence:SaveVendorData({
    npcID = 8002,
    vendorName = "Legacy Vendor",
    mapID = 1,
    coords = { x = 0.5, y = 0.5 },
    faction = "Neutral",
    housingItems = MakeDecorItems(2), -- laggy scan saw 2 of the 10
    scanComplete = true,
    hadNilSlots = true,               -- unconfirmed
})

local afterLegacyPartial = ScanHA.Addon.db.global.scannedVendors[8002]
assert(afterLegacyPartial ~= nil,
    "a pre-HS-249 record must survive an unconfirmed partial rescan")
assert(#afterLegacyPartial.items == 10,
    "an unconfirmed scan finding 2 items must not clobber a legacy 10-item record")
assert(afterLegacyPartial.lastScanned == 500,
    "a rejected scan must not re-date a legacy record's lastScanned")
assert(afterLegacyPartial.lastScanAttempt ~= nil,
    "the rejected attempt must still be recorded on the legacy record")

print("hs210_guards: HS-249 legacy-record partial-scan protection ok")

-------------------------------------------------------------------------------
-- HS-249 (Argus cycle 1): a cold housing catalog must not strip decorIDs off
-- a good record. decorID now comes from an enrichment step rather than from
-- the capture test, so a decor item scanned while the catalog is cold is still
-- captured but carries no decorID. The housing counts then match, the
-- partial-scan guard above does not fire, and the good rows would be replaced
-- by rows that lost their decorID — a decor-side regression, which is exactly
-- the invariant this phase must not break.
-------------------------------------------------------------------------------

ScanHA.Addon.db.global.scannedVendors[8003] = {
    npcID = 8003,
    vendorName = "Cold Catalog Vendor",
    mapID = 1,
    coords = { x = 0.5, y = 0.5 },
    faction = "Neutral",
    items = {
        { itemID = 4001, name = "Decor 1", decorID = 5001, subclassID = 0 },
        { itemID = 4002, name = "Decor 2", decorID = 5002, subclassID = 0 },
    },
    decorCount = 2,
    hasDecor = true,
    housingCount = 2,
    hasHousing = true,
    itemCount = 2,
    lastScanned = 600,
    scanConfidence = "confirmed",
}

-- Same two items, confirmed scan, but the catalog was cold so neither resolved
-- a decorID. Counts are equal, so nothing upstream rejects this scan.
ScanHA.ScanPersistence:SaveVendorData({
    npcID = 8003,
    vendorName = "Cold Catalog Vendor",
    mapID = 1,
    coords = { x = 0.5, y = 0.5 },
    faction = "Neutral",
    housingItems = {
        { itemID = 4001, name = "Decor 1", decorID = nil, subclassID = 0, merchantSlot = 1 },
        { itemID = 4002, name = "Decor 2", decorID = nil, subclassID = 0, merchantSlot = 2 },
    },
    scanComplete = true,
    hadNilSlots = false,
})

local afterColdScan = ScanHA.Addon.db.global.scannedVendors[8003]
assert(afterColdScan ~= nil, "the cold-catalog rescan must still persist")
assert(#afterColdScan.items == 2, "expected both items after the rescan")
for _, item in ipairs(afterColdScan.items) do
    assert(item.decorID ~= nil,
        "a cold-catalog rescan must not strip the decorID off a known decor item")
end
assert(afterColdScan.items[1].decorID == 5001 and afterColdScan.items[2].decorID == 5002,
    "the preserved decorIDs must match the ones already on record")

print("hs210_guards: HS-249 cold-catalog decorID preservation ok")

-------------------------------------------------------------------------------
-- HS-210 (M9): the preview click's GetCatalogEntryInfoByItem call is now
-- pcall-guarded and falls through to a byRecordID probe (via CatalogStore's
-- decorID reverse index) when byItem fails or returns nil, mirroring
-- CatalogStore:IsOwnedFresh's readOnly branch. MapSidePanel.lua pulls in the
-- full addon dependency graph, so this is a source-text assertion (same
-- technique as hs200_map_badge_probes.lua's fallback-shape checks) rather
-- than a loaded/executed probe.
-------------------------------------------------------------------------------

local mapSidePanelSource = assert(io.open(root .. "/UI/MapSidePanel.lua", "r")):read("*a")

assert(mapSidePanelSource:find(
    'local ok, info = pcall%(C_HousingCatalog%.GetCatalogEntryInfoByItem, itemID, true%)', 1) ~= nil,
    "expected the preview-click byItem call to be pcall-guarded")

assert(mapSidePanelSource:find('if not ok then info = nil end', 1) ~= nil,
    "expected the pcall failure path to clear info")

assert(mapSidePanelSource:find(
    'HA%.CatalogStore:GetDecorIDFromItemID%(itemID%)', 1) ~= nil,
    "expected the byRecordID fallback to resolve decorID via CatalogStore:GetDecorIDFromItemID")

assert(mapSidePanelSource:find(
    'pcall%(C_HousingCatalog%.GetCatalogEntryInfoByRecordID, 1, decorID, true%)', 1) ~= nil,
    "expected a pcall-guarded byRecordID probe in the fallback")

print("hs210_guards: M9 preview-click guard + fallback ok")

-------------------------------------------------------------------------------
-- HS-210 (M1/M5, Argus cycle 1 correction): OWNERSHIP_UPDATED, VENDOR_SCANNED,
-- ACTIVE_ENDEAVOR_CHANGED, and SOURCE_CACHES_INVALIDATED must all route
-- through the SAME debounced ScheduleContentRefresh, not four independent
-- C_Timer.After(0.1, ...) calls — a burst of any one of them (e.g.
-- UPDATE_FACTION firing SOURCE_CACHES_INVALIDATED repeatedly in one frame)
-- must collapse into exactly one RefreshContent, not N refreshes 0.1s later.
-------------------------------------------------------------------------------

-- All four listeners must be wired directly to the shared scheduler (not an
-- inline per-listener C_Timer.After wrapper — that was cycle 1's shape).
for _, eventName in ipairs({
    "OWNERSHIP_UPDATED", "VENDOR_SCANNED", "ACTIVE_ENDEAVOR_CHANGED", "SOURCE_CACHES_INVALIDATED",
}) do
    assert(mapSidePanelSource:find(
        'RegisterCallback%("' .. eventName .. '", ScheduleContentRefresh%)', 1) ~= nil,
        "expected " .. eventName .. " to be wired to the shared ScheduleContentRefresh")
end

-- Behavioral test: extract ScheduleContentRefresh and prove a burst of calls
-- collapses to exactly one RefreshContent once the (single, shared) pending
-- timer fires. MapSidePanel.lua pulls in the full addon dependency graph, so
-- this uses the same extract-and-load technique as hs208's threshold-math
-- test rather than loading the whole file.
local schedulerText = mapSidePanelSource:match(
    '(local function ScheduleContentRefresh%(%).-\nend)')
assert(schedulerText ~= nil, "could not extract ScheduleContentRefresh from MapSidePanel.lua")

local refreshCalls = 0
local capturedTimerCallback = nil
C_Timer = {
    After = function(_, callback)
        capturedTimerCallback = callback
    end,
}
MapSidePanel = {
    RefreshContent = function()
        refreshCalls = refreshCalls + 1
    end,
}

local schedulerChunk = "local pendingContentRefresh = false\n"
    .. schedulerText
    .. "\nreturn ScheduleContentRefresh"
local ScheduleContentRefresh = assert(loadstring(schedulerChunk, "ScheduleContentRefresh-extract"))()

-- Simulate an UPDATE_FACTION-style burst: several fires in one pass, BEFORE
-- the 0.1s timer ever fires.
ScheduleContentRefresh()
ScheduleContentRefresh()
ScheduleContentRefresh()
assert(refreshCalls == 0, "RefreshContent must not run before the deferred timer fires")

-- Now let the (single, coalesced) timer fire.
assert(capturedTimerCallback ~= nil, "expected exactly one C_Timer.After to have been scheduled")
capturedTimerCallback()
assert(refreshCalls == 1,
    "a burst of N ScheduleContentRefresh calls must produce exactly ONE RefreshContent, got " .. refreshCalls)

-- And the flag must have reset, so a NEW burst after the pump schedules again.
capturedTimerCallback = nil
ScheduleContentRefresh()
assert(capturedTimerCallback ~= nil, "expected a new timer to be schedulable after the previous one fired")
capturedTimerCallback()
assert(refreshCalls == 2, "a second, later burst must still produce its own refresh")

print("hs210_guards: M1/M5 deferred + coalesced refresh contract ok")
