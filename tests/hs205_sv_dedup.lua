-- luacheck: globals assert loadfile print io time GetLocale

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-- WoW exposes `time` as a bare global; stubbed as an incrementing counter so
-- every write in this file gets a DISTINCT, deterministic timestamp (a
-- real-clock stub could land two calls in the same wall-clock second and
-- hide a newer-wins migration bug behind a same-value coincidence).
local fakeClock = 1000
time = function()
    fakeClock = fakeClock + 1
    return fakeClock
end

GetLocale = function() return "enUS" end

-------------------------------------------------------------------------------
-- HS-205 Part 1: a parse writes ONE payload (catalogItems) + one stamp
-- (parsedSources), and change-detection still triggers a reparse on changed
-- sourceText while skipping unchanged. Loads the REAL CatalogStore.lua and
-- SourceTextScanner.lua modules together (both are self-contained enough to
-- load standalone with a minimal HA stub), with a fake SourceTextParser so
-- the test isolates the dedup/change-detection behavior from parser
-- correctness (covered elsewhere).
-------------------------------------------------------------------------------

local parseCalls = 0

local HA = {
    Addon = {
        db = { global = { parsedSources = {}, catalogItems = {} } },
        Debug = function() end,
        RegisterModule = function() end,
    },
    Events = { Fire = function() end },
    DecorMapping = {},
    SourceTextParser = {
        ParseSourceText = function(_, sourceText)
            parseCalls = parseCalls + 1
            if sourceText:find("VendorB") then
                return { sources = { { sourceType = "vendor", name = "Vendor B", zone = "Zone B" } } }
            end
            return { sources = { { sourceType = "vendor", name = "Vendor A", zone = "Zone A" } } }
        end,
    },
}

assert(loadfile(root .. "/Data/CatalogStore.lua"))("Homestead", HA)
HA.CatalogStore:Initialize()
assert(HA.Addon.db.global.schemaVersion == 5, "expected a fresh db to land on schemaVersion 5")

assert(loadfile(root .. "/Modules/SourceTextScanner.lua"))("Homestead", HA)

HA.SourceTextScanner:ProcessScannedItem({ itemID = 123, sourceText = "Sold by VendorA", recordID = 456 })

local stamp = HA.Addon.db.global.parsedSources[123]
assert(stamp ~= nil, "expected a parsedSources stamp to be written")
assert(stamp.sources == nil, "parsedSources must be stamp-only — no .sources field")
assert(stamp.recordID == nil, "parsedSources must be stamp-only — no .recordID field")
assert(stamp.raw == nil, "parsedSources must be stamp-only — no .raw field")
assert(type(stamp.sourceHash) == "number" and type(stamp.lastParsed) == "number",
    "expected the stamp to carry exactly sourceHash + lastParsed")

local record = HA.CatalogStore:Get(123)
assert(record ~= nil and record.sources ~= nil, "expected catalogItems to hold the full parsed payload")
assert(record.sources[1].name == "Vendor A")
assert(record.sourceHash == stamp.sourceHash, "catalogItems and the parsedSources stamp must agree on the hash")
assert(parseCalls == 1)

-- Re-parse the SAME sourceText: change-detection must skip re-parsing AND
-- re-writing entirely (hash matches the stamp).
HA.SourceTextScanner:ProcessScannedItem({ itemID = 123, sourceText = "Sold by VendorA", recordID = 456 })
assert(parseCalls == 1, "an unchanged sourceText must not trigger a reparse")

-- Change the sourceText: change-detection must trigger a reparse, and BOTH
-- the stamp and the catalogItems payload must update together.
HA.SourceTextScanner:ProcessScannedItem({ itemID = 123, sourceText = "Sold by VendorB", recordID = 456 })
assert(parseCalls == 2, "a changed sourceText must trigger a reparse")
local newStamp = HA.Addon.db.global.parsedSources[123]
local newRecord = HA.CatalogStore:Get(123)
assert(newStamp.sourceHash ~= stamp.sourceHash, "the stamp's hash must change when sourceText changes")
assert(newRecord.sourceHash == newStamp.sourceHash)
assert(newRecord.sources[1].name == "Vendor B", "catalogItems must hold the NEW parsed payload after a reparse")

print("hs205_sv_dedup: Part 1 single-payload write + change-detection ok")

-------------------------------------------------------------------------------
-- HS-205 Part 1b: SourceTextScanner:GetParsedSource (the accessor every
-- reader funnels through) returns the same shape callers always got, sourced
-- from catalogItems instead of the raw parsedSources table.
-------------------------------------------------------------------------------

local parsed = HA.SourceTextScanner:GetParsedSource(123)
assert(parsed ~= nil)
assert(parsed.sources[1].name == "Vendor B")
assert(parsed.sourceHash == newStamp.sourceHash)
assert(parsed.lastParsed == newRecord.lastParsed)
assert(parsed.raw == nil, "HA.DevAddon was never set — raw must be nil, matching prior behavior")

-- Never-parsed item must still return nil (no stamp, no record).
assert(HA.SourceTextScanner:GetParsedSource(99999) == nil)

print("hs205_sv_dedup: Part 1b GetParsedSource reader end-to-end ok")

-------------------------------------------------------------------------------
-- HS-205 Part 2: schemaVersion 4→5 migration. Mocks a v4 db with the OLD
-- dual-write shape (parsedSources carrying the full payload) and verifies
-- the migration moves it into catalogItems, rewrites parsedSources to the
-- stamp-only shape, and is idempotent (identical result on a second run).
-------------------------------------------------------------------------------

local function FreshCatalogStoreHA()
    local freshHA = {
        Addon = { db = { global = {} }, Debug = function() end, RegisterModule = function() end },
        Events = { Fire = function() end },
        DecorMapping = {},
    }
    assert(loadfile(root .. "/Data/CatalogStore.lua"))("Homestead", freshHA)
    return freshHA
end

-- Case A: item only ever known via parsedSources (catalogItems has no record
-- at all) — the historical pre-dual-write residue case.
local MigHA = FreshCatalogStoreHA()
MigHA.Addon.db.global.schemaVersion = 4
MigHA.Addon.db.global.catalogItems = {}
MigHA.Addon.db.global.parsedSources = {
    [100] = {
        sources = { { sourceType = "vendor", name = "Old Vendor" } },
        recordID = 999,
        lastParsed = 1000,
        sourceHash = 555,
        raw = "raw sourceText",
    },
}
MigHA.CatalogStore:Initialize()

assert(MigHA.Addon.db.global.schemaVersion == 5)
local migratedRecord = MigHA.CatalogStore:Get(100)
assert(migratedRecord ~= nil, "expected the migration to create a catalogItems record")
assert(migratedRecord.sources[1].name == "Old Vendor")
assert(migratedRecord.sourceHash == 555)
assert(migratedRecord.lastParsed == 1000)
assert(migratedRecord.decorID == 999, "expected recordID to migrate to decorID (mirrors Migration_1_to_2)")
assert(migratedRecord.rawSourceText == "raw sourceText")

local migratedStamp = MigHA.Addon.db.global.parsedSources[100]
assert(migratedStamp.sourceHash == 555 and migratedStamp.lastParsed == 1000)
assert(migratedStamp.sources == nil, "parsedSources must be rewritten to stamp-only after migration")
assert(migratedStamp.recordID == nil)
assert(migratedStamp.raw == nil)

-- Idempotence: re-run migrations on the SAME db. Nothing should change —
-- schemaVersion < 5 is now false, so Migration_4_to_5 shouldn't even fire,
-- but call RunMigrations directly to prove it either way.
MigHA.CatalogStore:RunMigrations()
local migratedRecordAgain = MigHA.CatalogStore:Get(100)
assert(migratedRecordAgain.sources[1].name == "Old Vendor")
assert(migratedRecordAgain.sourceHash == 555)
assert(migratedRecordAgain.decorID == 999)
local migratedStampAgain = MigHA.Addon.db.global.parsedSources[100]
assert(migratedStampAgain.sourceHash == 555 and migratedStampAgain.lastParsed == 1000)
assert(migratedStampAgain.sources == nil)

print("hs205_sv_dedup: Part 2a migration (residue case) + idempotence ok")

-------------------------------------------------------------------------------
-- HS-205 Part 2b: newer-wins when catalogItems and parsedSources both have
-- data and disagree. Verified empirically that the CURRENT write path writes
-- both atomically together, so this only matters for historical divergence —
-- the migration compares lastParsed timestamps rather than assuming a fixed
-- direction.
-------------------------------------------------------------------------------

-- Sub-case: parsedSources is NEWER than catalogItems — parsedSources' payload
-- must win.
local NewerParsedHA = FreshCatalogStoreHA()
NewerParsedHA.Addon.db.global.schemaVersion = 4
NewerParsedHA.Addon.db.global.catalogItems = {
    [200] = { sources = { { sourceType = "vendor", name = "Stale Vendor" } }, sourceHash = 111, lastParsed = 5000 },
}
NewerParsedHA.Addon.db.global.parsedSources = {
    [200] = { sources = { { sourceType = "vendor", name = "Fresh Vendor" } }, sourceHash = 222, lastParsed = 6000 },
}
NewerParsedHA.CatalogStore:Initialize()
local wonRecord = NewerParsedHA.CatalogStore:Get(200)
assert(wonRecord.sources[1].name == "Fresh Vendor", "the NEWER (parsedSources) payload must win on disagreement")
assert(wonRecord.sourceHash == 222)

-- Sub-case: catalogItems is NEWER than parsedSources — catalogItems must be
-- left alone (parsedSources' older/stale payload must NOT overwrite it).
local NewerCatalogHA = FreshCatalogStoreHA()
NewerCatalogHA.Addon.db.global.schemaVersion = 4
NewerCatalogHA.Addon.db.global.catalogItems = {
    [300] = { sources = { { sourceType = "vendor", name = "Current Vendor" } }, sourceHash = 333, lastParsed = 9000 },
}
NewerCatalogHA.Addon.db.global.parsedSources = {
    [300] = { sources = { { sourceType = "vendor", name = "Stale Vendor" } }, sourceHash = 444, lastParsed = 2000 },
}
NewerCatalogHA.CatalogStore:Initialize()
local keptRecord = NewerCatalogHA.CatalogStore:Get(300)
assert(keptRecord.sources[1].name == "Current Vendor", "the NEWER (catalogItems) payload must be kept, not overwritten")
assert(keptRecord.sourceHash == 333)

-- Both cases must rewrite parsedSources to stamp-only, mirroring whichever
-- payload actually WON in catalogItems — not blindly parsedSources' own
-- original hash. If case 300's stamp kept the stale 444, a future live
-- reparse would compare the current (333-matching) sourceText hash against
-- a hash that was never authoritative and trigger a spurious reparse.
local stamp200 = NewerParsedHA.Addon.db.global.parsedSources[200]
assert(stamp200.sources == nil and stamp200.sourceHash == 222, "stamp must mirror the winning (parsedSources) hash")
local stamp300 = NewerCatalogHA.Addon.db.global.parsedSources[300]
assert(stamp300.sources == nil and stamp300.sourceHash == 333, "stamp must mirror the winning (catalogItems) hash, not parsedSources' stale 444")

print("hs205_sv_dedup: Part 2b newer-wins migration ok")

-------------------------------------------------------------------------------
-- HS-205 Part 2c (Argus cycle 1): the COMMON dual-write-era case — EQUAL
-- hashes on both sides (written atomically together), dev raw present. The
-- first-draft migration only copied raw inside the takeParsed branch, which
-- equal hashes never enter, so the entire dev raw corpus was destroyed while
-- the stamp rewrite deleted parsedSources' copy. Raw must survive regardless
-- of which side wins.
-------------------------------------------------------------------------------

local EqualHA = FreshCatalogStoreHA()
EqualHA.Addon.db.global.schemaVersion = 4
EqualHA.Addon.db.global.catalogItems = {
    [400] = { sources = { { sourceType = "vendor", name = "Same Vendor" } }, sourceHash = 555, lastParsed = 7000 },
}
EqualHA.Addon.db.global.parsedSources = {
    [400] = { sources = { { sourceType = "vendor", name = "Same Vendor" } }, sourceHash = 555, lastParsed = 7000,
              raw = "the dev raw corpus" },
}
EqualHA.CatalogStore:Initialize()
local equalRecord = EqualHA.CatalogStore:Get(400)
assert(equalRecord.rawSourceText == "the dev raw corpus",
    "equal-hash migration must preserve dev raw sourceText (the common case)")
local stamp400 = EqualHA.Addon.db.global.parsedSources[400]
assert(stamp400.raw == nil and stamp400.sources == nil, "stamp-only shape after raw preservation")
-- Idempotence: second run must not error or change anything (no data.raw left).
EqualHA.Addon.db.global.schemaVersion = 4  -- force the migration to re-run
EqualHA.CatalogStore:Initialize()
assert(EqualHA.CatalogStore:Get(400).rawSourceText == "the dev raw corpus",
    "re-run must keep the preserved raw untouched")

print("hs205_sv_dedup: Part 2c equal-hash raw preservation ok")
