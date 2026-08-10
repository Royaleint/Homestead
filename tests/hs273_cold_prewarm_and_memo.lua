-- luacheck: globals assert loadfile print io CreateFrame

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-- SourceManager:Initialize() wires a couple of housekeeping frames
-- (combat-deferral, completion-cache invalidation) unrelated to what this
-- test exercises -- a minimal stub is enough for it to load without error.
CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript() end
    return frame
end

-------------------------------------------------------------------------------
-- HS-273 (Gate 1 cycle 1, R1-R3, R5): pins the mechanisms Argus/Sage's
-- REJECT rulings require, so a future edit can't silently re-widen the
-- ownership-erase authorization or drop the memo's invalidation coverage.
--
-- Part 1: source-pattern pins (the erase-sentinel text, the two one-shot
--   HS_CATALOG_TRUE_WARM fire sites, the BadgeCalculation HasPersistedData
--   gate, the ScanPersistence/RefreshMapPins memo call sites).
-- Part 2: functional exercise of the GetAllSources memo (hit returns the
--   SAME table, both the narrow and full invalidations clear it).
--
-- Part 1's pins below are source-text only, so they prove the latch CODE
-- exists, not that the HOUSING_STORAGE_UPDATED handler still calls it (HS-276
-- extracted that body into TryLatchWarmFromCounts, and these pins stayed green
-- through a mutation that deleted the call). That reachability proof lives in
-- tests/hs276_login_force_load.lua, scenario A -- keep it in step with any
-- further restructuring of the latch.
-------------------------------------------------------------------------------

local function readFile(path)
    local f = assert(io.open(path, "r"))
    local content = f:read("*a")
    f:close()
    return content
end

-------------------------------------------------------------------------------
-- Part 1a: CatalogScanner.lua — the erase-authorization sentinel (R1)
-------------------------------------------------------------------------------

local scannerSource = readFile(root .. "/Modules/CatalogScanner.lua")

-- dataLoaded's own latch condition must still read GetDecorTotalOwnedCount
-- (R1 REVERT) — the erase-authorization gate never moved to the weaker
-- max-owned sentinel; only the separate storageResponded signal did.
assert(scannerSource:find("if %(C_HousingCatalog%.GetDecorTotalOwnedCount and C_HousingCatalog%.GetDecorTotalOwnedCount%(%) or 0%) > 0 then%s+dataLoaded = true") ~= nil,
    "dataLoaded's latch must corroborate on GetDecorTotalOwnedCount, unchanged from pre-HS-273")

-- storageResponded is the separate, weaker one-shot on the max sentinel.
assert(scannerSource:find("local storageResponded = false") ~= nil,
    "storageResponded one-shot local must exist, separate from dataLoaded")
assert(scannerSource:find("not storageResponded%s+and %(C_HousingCatalog%.GetDecorMaxOwnedCount") ~= nil,
    "storageResponded must corroborate on GetDecorMaxOwnedCount, not GetDecorTotalOwnedCount")

-- The edge capture must precede the latch (Argus cycle-2 SF1): if
-- `local dataLoadedBefore = dataLoaded` ever moves below the latch write,
-- the dataLoaded-edge fire site becomes unreachable dead code and the
-- suite would otherwise stay green (the fire-site COUNT below cannot see
-- reachability).
local capturePos = scannerSource:find("local dataLoadedBefore = dataLoaded", 1, true)
local latchPos = scannerSource:find("dataLoaded = true", 1, true)
assert(capturePos and latchPos and capturePos < latchPos,
    "dataLoadedBefore must be captured BEFORE the dataLoaded latch writes")

-- HS_CATALOG_TRUE_WARM must fire from exactly two one-shot edges in this
-- file: dataLoaded's own false->true transition, and storageResponded's.
-- A count of anything other than 2 means an edge was dropped or duplicated.
local fireCount = 0
for _ in scannerSource:gmatch('HA%.Events:Fire%("HS_CATALOG_TRUE_WARM"%)') do
    fireCount = fireCount + 1
end
assert(fireCount == 2,
    "expected exactly 2 HS_CATALOG_TRUE_WARM fire sites in CatalogScanner.lua, got " .. fireCount)

-------------------------------------------------------------------------------
-- Part 1b: BadgeCalculation.lua — HasPersistedData gate (R3)
-------------------------------------------------------------------------------

local badgeSource = readFile(root .. "/UI/BadgeCalculation.lua")

assert(badgeSource:find("not HA%.CatalogStore or not HA%.CatalogStore%.HasPersistedData or not HA%.CatalogStore:HasPersistedData%(%)") ~= nil,
    "StartPrewarmPass must gate on CatalogStore:HasPersistedData, not IsInitialized/IsWarm")
assert(badgeSource:find("HA%.CatalogStore and HA%.CatalogStore%.HasPersistedData and HA%.CatalogStore:HasPersistedData%(%)") ~= nil,
    "the login ticker must poll CatalogStore:HasPersistedData, not IsInitialized/IsWarm")
assert(badgeSource:find("HA%.CatalogStore:IsInitialized") == nil
    and badgeSource:find("HA%.CatalogStore%.IsInitialized") == nil,
    "no remaining reference to the removed CatalogStore:IsInitialized")

-------------------------------------------------------------------------------
-- Part 1c: CatalogStore.lua — IsInitialized removed, HasPersistedData present
-------------------------------------------------------------------------------

local storeSource = readFile(root .. "/Data/CatalogStore.lua")
assert(storeSource:find("function CatalogStore:HasPersistedData%(%)") ~= nil,
    "CatalogStore:HasPersistedData must be defined")
assert(storeSource:find("function CatalogStore:IsInitialized%(%)") == nil,
    "CatalogStore:IsInitialized must be removed (R3 — nothing else consumes it)")

-- Pin the PREDICATE, not just the function's existence (Argus cycle-2 C1 /
-- Sage cycle-2 mutation probe: weakening the body back to `ci ~= nil`
-- silently restored the confident-wrong-0/N defect while the suite stayed
-- green). Record presence is not an ownership signal: ownedCount > 0 is,
-- with the storage-responded-AND-not-warm hatch admitting the genuine
-- zero-decor player (whose zero is confirmed true by a live zero total).
local hasDataBody = storeSource:match("function CatalogStore:HasPersistedData%(%)(.-)\nend")
assert(hasDataBody, "HasPersistedData body not found")
assert(hasDataBody:find("ownedCount > 0", 1, true) ~= nil,
    "HasPersistedData must require ownedCount > 0 (record presence is not an ownership signal)")
-- The hatch's SHAPE matters, not the substring (Argus closure finding: an
-- "IsWarm or" polarity passes a substring check while being unreachable for
-- the zero-decor player and open in the wrong window). Pin the discriminator:
-- storage responded AND NOT warm.
assert(hasDataBody:find("HasStorageResponded", 1, true) ~= nil,
    "HasPersistedData's hatch must consult CatalogScanner:HasStorageResponded")
assert(hasDataBody:find("not scanner:IsWarm()", 1, true) ~= nil,
    "HasPersistedData's hatch must require NOT IsWarm (zero confirmed true, not mid-scan)")
assert(scannerSource:find("function CatalogScanner:HasStorageResponded%(%)") ~= nil,
    "CatalogScanner must expose HasStorageResponded (R1's weak flag, accessor form)")
local storageAccessorBody = scannerSource:match("function CatalogScanner:HasStorageResponded%(%)(.-)\nend")
assert(storageAccessorBody and storageAccessorBody:find("return storageResponded", 1, true) ~= nil,
    "HasStorageResponded must return storageResponded (returning dataLoaded would collapse the hatch to permanently-false)")

-------------------------------------------------------------------------------
-- Part 1d: ScanPersistence.lua — narrow memo invalidation call sites (R2)
-------------------------------------------------------------------------------

local scanPersistSource = readFile(root .. "/Modules/ScanPersistence.lua")

-- SaveVendorData: narrow call, gated on hasDecor.
assert(scanPersistSource:find("vendorRecord%.hasDecor and HA%.SourceManager and HA%.SourceManager%.InvalidateSourcesMemo") ~= nil,
    "SaveVendorData must call the narrow InvalidateSourcesMemo, gated on vendorRecord.hasDecor")
assert(scanPersistSource:find("HA%.SourceManager:InvalidateAllSourceCaches") == nil,
    "ScanPersistence must not call the full, broadcasting InvalidateAllSourceCaches")

-- RefreshMapPins: same narrow call, unconditional (covers all three clear paths).
local refreshMapPinsBody = scanPersistSource:match("local function RefreshMapPins%(%)(.-)\nend")
assert(refreshMapPinsBody, "RefreshMapPins body not found")
assert(refreshMapPinsBody:find("HA%.SourceManager%.InvalidateSourcesMemo") ~= nil,
    "RefreshMapPins must also wipe the GetAllSources memo (ClearScannedData/ClearNoDecorData/ClearAllData all route through it)")

-------------------------------------------------------------------------------
-- Part 2: functional exercise of the GetAllSources memo
-------------------------------------------------------------------------------

local HA = {
    Constants = { Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
    Addon = {
        db = { profile = {}, global = { parsedSources = {} } },
        RegisterModule = function() end,
        Debug = function() end,
    },
    Events = {
        RegisterCallback = function() end,
        Fire = function() end,
    },
    QuestSources = {
        [12345] = { questID = 900, questName = "Test Quest" },
    },
}

assert(loadfile(root .. "/Data/SourceManager.lua"))("Homestead", HA)
HA.SourceManager:Initialize()

-- HS-279: GetSourcesMemoEntryCount is a read-only diagnostic accessor feeding
-- /hs debug memallsources -- must never mutate the memo, and must track its
-- population accurately across hits/misses/invalidation.
assert(HA.SourceManager:GetSourcesMemoEntryCount() == 0,
    "entry count must start at 0 before any GetAllSources call")

-- Hit: two calls for the same itemID must return the identical table object
-- (not just equal contents) -- callers that store the reference and expect
-- later writes elsewhere to be invisible depend on this.
local first = HA.SourceManager:GetAllSources(12345)
assert(HA.SourceManager:GetSourcesMemoEntryCount() == 1,
    "entry count must be 1 after the first GetAllSources call populates the memo")
local second = HA.SourceManager:GetAllSources(12345)
assert(first == second, "GetAllSources must return the SAME cached table on a hit")
assert(#first == 1 and first[1].type == "quest", "sanity: the quest provider result must be present")
assert(HA.SourceManager:GetSourcesMemoEntryCount() == 1,
    "a cache hit must not change the entry count (read-only, no re-insert)")

-- The nil-itemID guard stays outside the cache (no crash, no caching of {}).
assert(#HA.SourceManager:GetAllSources(nil) == 0, "GetAllSources(nil) must return an empty table")
assert(HA.SourceManager:GetSourcesMemoEntryCount() == 1,
    "a nil itemID must never add an entry to the memo")

-- Narrow invalidation (InvalidateSourcesMemo) must clear the memo:
-- a subsequent call recomputes, returning a NEW table object.
HA.SourceManager:InvalidateSourcesMemo()
assert(HA.SourceManager:GetSourcesMemoEntryCount() == 0,
    "InvalidateSourcesMemo must reset the entry count to 0")
local third = HA.SourceManager:GetAllSources(12345)
assert(third ~= first, "InvalidateSourcesMemo must force recomputation (new table object)")
assert(third[1].type == "quest", "recomputed result must still be correct")
assert(HA.SourceManager:GetSourcesMemoEntryCount() == 1,
    "entry count must reflect the recomputed entry after invalidation")

-- Full invalidation (InvalidateAllSourceCaches) must ALSO clear the memo.
local fourth = HA.SourceManager:GetAllSources(12345)
assert(fourth == third, "unchanged cache between calls must still hit")
HA.SourceManager:InvalidateAllSourceCaches()
assert(HA.SourceManager:GetSourcesMemoEntryCount() == 0,
    "InvalidateAllSourceCaches must also reset the entry count to 0")
local fifth = HA.SourceManager:GetAllSources(12345)
assert(fifth ~= fourth, "InvalidateAllSourceCaches must also force recomputation (new table object)")
assert(HA.SourceManager:GetSourcesMemoEntryCount() == 1,
    "entry count must reflect the recomputed entry after full invalidation")

print("hs273_cold_prewarm_and_memo: ok")
