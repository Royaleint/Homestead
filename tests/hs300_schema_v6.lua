-- luacheck: globals assert loadfile print time Foundry_1_0

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-- HS-300: same deterministic-clock stub as hs205_sv_dedup.lua -- distinct
-- timestamps per call so a same-value coincidence can't mask a real bug.
local fakeClock = 1000
time = function()
    fakeClock = fakeClock + 1
    return fakeClock
end

-- HS-300: F:RaiseDevError must be stubbed BEFORE any CatalogStore.lua chunk
-- loads -- `local F = _G.Foundry_1_0` is captured once at file-load time, so
-- setting _G.Foundry_1_0 after a loadfile() call would leave that chunk's F
-- nil. Records every call so case 5 can assert exactly one fired.
local raiseDevErrorCalls = {}
Foundry_1_0 = {
    RaiseDevError = function(_, msg)
        table.insert(raiseDevErrorCalls, msg)
    end,
}

-- The five keys the v6 migration destroys (mirrors CatalogStore.lua's
-- file-local V6_DROPPED_KEYS -- kept in sync here by hand since that list
-- isn't exported).
local DROPPED_KEYS = { "vendorVisited", "dyeRecipesKnown", "discoveredAliases",
                       "decorIDValidation", "enableRequirementScraping" }

local function seededKeys()
    return {
        vendorVisited = { [1001] = true, [1002] = true },
        dyeRecipesKnown = { [55] = true },
        discoveredAliases = { [777] = { canonical = 888, confirmed = true, encounters = 3 } },
        decorIDValidation = { scannedAt = 42, totalConfirmed = 5, notDecor = {} },
        enableRequirementScraping = true,
    }
end

-- Minimal recursive equality -- enough to prove the backup is a real deep
-- copy of the seeded values (not a reference alias, and not a partial one).
local function deepEqual(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local function FreshCatalogStoreHA()
    local freshHA = {
        Addon = { db = { global = {} }, Debug = function() end, RegisterModule = function() end },
        Constants = { VERSION = "hs300-test" },
        Events = { Fire = function() end },
        DecorMapping = {},
    }
    assert(loadfile(root .. "/Data/CatalogStore.lua"))("Homestead", freshHA)
    return freshHA
end

local function seedGlobal(g, keys)
    for k, v in pairs(keys) do
        g[k] = v
    end
end

-------------------------------------------------------------------------------
-- Case 1: fresh v5 db carrying all five dropped keys -- after Initialize():
-- keys nil, schemaVersion == 6, __v5Backup.keys deep-equal the seeded
-- values, fromVersion == 5, metadata present.
-------------------------------------------------------------------------------

local Case1 = FreshCatalogStoreHA()
local g1 = Case1.Addon.db.global
g1.schemaVersion = 5
g1.catalogItems = {}
local seeded1 = seededKeys()
seedGlobal(g1, seeded1)

Case1.CatalogStore:Initialize()

assert(g1.schemaVersion == 6, "expected the v5->v6 migration to stamp schemaVersion 6")
for _, k in ipairs(DROPPED_KEYS) do
    assert(g1[k] == nil, "expected " .. k .. " to be nil'd by the v6 migration")
end

local backup1 = g1.__v5Backup
assert(backup1 ~= nil, "expected a __v5Backup to be written")
assert(backup1.fromVersion == 5, "expected fromVersion to record the pre-migration stamp")
assert(type(backup1.savedAt) == "number", "expected savedAt metadata")
assert(backup1.addonVersion == "hs300-test", "expected addonVersion metadata")
assert(deepEqual(backup1.keys, seeded1), "expected the backup to deep-equal the seeded values")

-- Deep-copy check (Argus HS-300 fix round item 1): the backup must be a
-- real copy of the seeded values, not a reference alias -- an aliased
-- backup would deep-equal the seeded values in every other assertion here
-- while still being silently corruptible by a later mutation of the source
-- table. Mutate the seeded table AFTER the backup was taken and assert the
-- backup is unaffected, then restore the mutation -- case 2 below reuses
-- seeded1 and expects it untouched.
seeded1.vendorVisited[1001] = nil
assert(backup1.keys.vendorVisited[1001] == true,
    "expected the backup to be a deep copy -- mutating the seeded source table must not reach it")
seeded1.vendorVisited[1001] = true

print("hs300_schema_v6: case 1 (fresh v5 -> v6, backup captured) ok")

-------------------------------------------------------------------------------
-- Case 2: replay -- reset the stamp to 5, seed a DIFFERENT value into one
-- key, Initialize() again. Only-if-absent means the backup must still hold
-- the ORIGINAL values, not the replay's.
-------------------------------------------------------------------------------

g1.schemaVersion = 5
g1.vendorVisited = { [9999] = true }  -- deliberately different from seeded1.vendorVisited

Case1.CatalogStore:Initialize()

assert(g1.schemaVersion == 6)
assert(g1.vendorVisited == nil, "the replay's migration must still nil the key")
assert(deepEqual(g1.__v5Backup.keys, seeded1),
    "a replay must not overwrite an existing backup with post-migration/replay data")

print("hs300_schema_v6: case 2 (replay does not clobber an existing backup) ok")

-------------------------------------------------------------------------------
-- Case 3: corrupt-stamp path -- a v1-shaped db (parsedSources carrying the
-- old .sources payload, mirrors hs205's seed) plus the five keys, with
-- schemaVersion = "corrupt". The backup must hold the PRE-1->5 values (not
-- values already transformed by an earlier migration in the replayed
-- chain), and the chain must complete to 6.
-------------------------------------------------------------------------------

local Case3 = FreshCatalogStoreHA()
local g3 = Case3.Addon.db.global
g3.schemaVersion = "corrupt"
g3.catalogItems = {}
g3.parsedSources = {
    [100] = {
        sources = { { sourceType = "vendor", name = "Old Vendor" } },
        recordID = 999,
        lastParsed = 1000,
        sourceHash = 555,
        raw = "raw sourceText",
    },
}
local seeded3 = seededKeys()
seedGlobal(g3, seeded3)

local ok3, err3 = pcall(function() Case3.CatalogStore:Initialize() end)
assert(ok3, "Initialize() must not throw on a corrupt schemaVersion: " .. tostring(err3))

assert(g3.schemaVersion == 6, "expected the corrupt-stamp replay to complete the whole chain to 6")
for _, k in ipairs(DROPPED_KEYS) do
    assert(g3[k] == nil, "expected " .. k .. " to be nil'd after the replayed chain")
end

local backup3 = g3.__v5Backup
assert(backup3 ~= nil)
assert(backup3.fromVersion == 1, "a corrupt stamp repairs to 1 before the backup is taken")
assert(deepEqual(backup3.keys, seeded3),
    "the backup must hold the pre-migration values, not values transformed by 1->5")

print("hs300_schema_v6: case 3 (corrupt-stamp replay backs up pre-migration values) ok")

-------------------------------------------------------------------------------
-- Case 4: catalogItems table identity must survive the v6 migration -- the
-- `ci` upvalue is bound to it before RunMigrations runs; a table swap here
-- would strand every later read against the old table.
-------------------------------------------------------------------------------

local Case4 = FreshCatalogStoreHA()
local g4 = Case4.Addon.db.global
g4.schemaVersion = 5
local before4 = { [1] = "sentinel" }
g4.catalogItems = before4

Case4.CatalogStore:Initialize()

assert(before4 == g4.catalogItems, "expected catalogItems table identity to survive the v6 migration")

print("hs300_schema_v6: case 4 (catalogItems identity preserved) ok")

-------------------------------------------------------------------------------
-- Case 5: a stamp newer than this build supports (7) must fail loud via
-- F:RaiseDevError and skip migrations entirely -- no key nil'd, no backup
-- written, stamp left untouched.
-------------------------------------------------------------------------------

local Case5 = FreshCatalogStoreHA()
local g5 = Case5.Addon.db.global
g5.schemaVersion = 7
g5.catalogItems = {}
local seeded5 = seededKeys()
seedGlobal(g5, seeded5)

raiseDevErrorCalls = {}
Case5.CatalogStore:Initialize()

assert(#raiseDevErrorCalls == 1, "expected exactly one RaiseDevError call for a too-new stamp")
assert(g5.schemaVersion == 7, "expected the stamp to be left untouched")
for _, k in ipairs(DROPPED_KEYS) do
    assert(deepEqual(g5[k], seeded5[k]), "expected " .. k .. " to be untouched -- no migration should have run")
end
assert(g5.__v5Backup == nil, "expected no backup to be written when migrations are skipped")

print("hs300_schema_v6: case 5 (v7+ stamp fails loud, no migration runs) ok")

-------------------------------------------------------------------------------
-- Case 6: v5 db with NONE of the five keys present -- must not error on
-- absence; __v5Backup.keys is an empty table, metadata still present, stamp
-- still advances to 6.
-------------------------------------------------------------------------------

local Case6 = FreshCatalogStoreHA()
local g6 = Case6.Addon.db.global
g6.schemaVersion = 5
g6.catalogItems = {}

Case6.CatalogStore:Initialize()

assert(g6.schemaVersion == 6)
local backup6 = g6.__v5Backup
assert(backup6 ~= nil, "expected a backup even when no dropped key was present")
assert(next(backup6.keys) == nil, "expected an empty keys table when none of the five keys existed")
assert(backup6.fromVersion == 5)
assert(type(backup6.savedAt) == "number")
assert(backup6.addonVersion == "hs300-test")

print("hs300_schema_v6: case 6 (absent keys -> empty backup, metadata present) ok")

-------------------------------------------------------------------------------
-- Case 7: restore round-trip -- after a v5->v6 migration, CatalogStore:
-- RestoreV5Backup() must put the keys back and reset the stamp to 5 (and
-- leave the backup in place, so a second restore still works); a subsequent
-- Initialize() must re-migrate to 6 without disturbing the backup.
-------------------------------------------------------------------------------

local Case7 = FreshCatalogStoreHA()
local g7 = Case7.Addon.db.global
g7.schemaVersion = 5
g7.catalogItems = {}
local seeded7 = seededKeys()
seedGlobal(g7, seeded7)

Case7.CatalogStore:Initialize()
assert(g7.schemaVersion == 6)

local restoreOk, restoredCount, savedAt, addonVersion = Case7.CatalogStore:RestoreV5Backup()
assert(restoreOk == true, "expected RestoreV5Backup to succeed with a backup present")
assert(restoredCount == 5, "expected all five dropped keys to be restored")
assert(type(savedAt) == "number")
assert(addonVersion == "hs300-test")

assert(g7.schemaVersion == 5, "expected the restore to reset schemaVersion to 5")
for _, k in ipairs(DROPPED_KEYS) do
    assert(deepEqual(g7[k], seeded7[k]), "expected " .. k .. " to be restored to its backed-up value")
end
assert(g7.__v5Backup ~= nil, "expected the restore to leave the backup in place for a second restore")

-- Deep-copy check, restore side (mirrors case 1): RestoreV5Backup must copy
-- backup.keys into db.global, not alias it -- otherwise mutating the
-- restored table would corrupt the backup that produced it.
g7.vendorVisited[1001] = nil
assert(g7.__v5Backup.keys.vendorVisited[1001] == true,
    "expected the restore to be a deep copy -- mutating the restored table must not affect the backup")

Case7.CatalogStore:Initialize()
assert(g7.schemaVersion == 6, "expected re-Initialize() to re-migrate to 6")
for _, k in ipairs(DROPPED_KEYS) do
    assert(g7[k] == nil, "expected the re-run migration to nil the restored keys again")
end
assert(deepEqual(g7.__v5Backup.keys, seeded7),
    "expected the backup to remain unchanged (still the original seeded values) after the round-trip")

print("hs300_schema_v6: case 7 (restore round-trip: restore, re-migrate, backup unchanged) ok")

print("hs300_schema_v6: all cases ok")
