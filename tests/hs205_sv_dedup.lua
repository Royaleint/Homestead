-- luacheck: globals assert loadfile print time GetLocale

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")
local fakeClock = 1000
time = function()
    fakeClock = fakeClock + 1
    return fakeClock
end
GetLocale = function() return "enUS" end

local parseCalls = 0
local HA = {
    Addon = {
        db = { global = { parsedSources = {}, catalogItems = {} } },
        Debug = function() end,
        RegisterModule = function() end,
    },
    Constants = { VERSION = "test" },
    Events = { Fire = function() end },
    DecorMapping = {},
    SourceTextParser = {
        ParseSourceText = function(_, sourceText)
            parseCalls = parseCalls + 1
            if sourceText:find("VendorB") then
                return { sources = { { sourceType = "vendor", name = "Vendor B" } } }
            end
            return { sources = { { sourceType = "vendor", name = "Vendor A" } } }
        end,
    },
}

assert(loadfile(root .. "/Data/CatalogStore.lua"))("Homestead", HA)
HA.CatalogStore:Initialize()
assert(HA.Addon.db.global.schemaVersion == 7, "expected fresh db to land on schemaVersion 7")
assert(loadfile(root .. "/Modules/SourceTextScanner.lua"))("Homestead", HA)

-- Live parsing keeps payload in catalogItems and hash/timestamp only in parsedSources.
HA.SourceTextScanner:ProcessScannedItem({ itemID = 123, sourceText = "Sold by VendorA", recordID = 456 })
local stamp = HA.Addon.db.global.parsedSources[123]
local record = HA.CatalogStore:Get(123)
assert(stamp and type(stamp.sourceHash) == "number" and type(stamp.lastParsed) == "number")
assert(stamp.sources == nil and stamp.recordID == nil and stamp.raw == nil)
assert(record and record.sources[1].name == "Vendor A")
assert(record.sourceHash == nil and record.lastParsed == nil and record.lastScanned == nil,
    "live parse must not recreate retired record fields")
assert(parseCalls == 1)
HA.SourceTextScanner:ProcessScannedItem({ itemID = 123, sourceText = "Sold by VendorA", recordID = 456 })
assert(parseCalls == 1, "unchanged sourceText must not reparse")
HA.SourceTextScanner:ProcessScannedItem({ itemID = 123, sourceText = "Sold by VendorB", recordID = 456 })
local newStamp = HA.Addon.db.global.parsedSources[123]
local newRecord = HA.CatalogStore:Get(123)
assert(parseCalls == 2, "changed sourceText must reparse")
assert(newStamp.sourceHash ~= stamp.sourceHash)
assert(newRecord.sources[1].name == "Vendor B")
assert(newRecord.sourceHash == nil and newRecord.lastParsed == nil and newRecord.lastScanned == nil)
local parsed = HA.SourceTextScanner:GetParsedSource(123)
assert(parsed and parsed.sources[1].name == "Vendor B")
assert(parsed.sourceHash == newStamp.sourceHash and parsed.lastParsed == newStamp.lastParsed)
assert(parsed.raw == nil)
assert(HA.SourceTextScanner:GetParsedSource(99999) == nil)
print("hs205_sv_dedup: live source payload and stamp split ok")

local function FreshCatalogStoreHA()
    local freshHA = {
        Addon = { db = { global = {} }, Debug = function() end, RegisterModule = function() end },
        Constants = { VERSION = "test" }, Events = { Fire = function() end }, DecorMapping = {},
    }
    assert(loadfile(root .. "/Data/CatalogStore.lua"))("Homestead", freshHA)
    return freshHA
end

local function assertMigrated(record, stamp, sourceName, hash, parsedAt)
    assert(record.sources[1].name == sourceName)
    assert(record.sourceHash == nil and record.lastParsed == nil and record.lastScanned == nil)
    assert(stamp.sources == nil and stamp.recordID == nil and stamp.raw == nil)
    assert(stamp.sourceHash == hash and stamp.lastParsed == parsedAt)
end

-- Historic 4->5 reconciliation keeps the stamp of whichever payload wins before v7 clears copies.
local NewerParsedHA = FreshCatalogStoreHA()
NewerParsedHA.Addon.db.global.schemaVersion = 4
NewerParsedHA.Addon.db.global.catalogItems = {
    [200] = { sources = { { sourceType = "vendor", name = "Stale Vendor" } }, sourceHash = 111, lastParsed = 5000 },
}
NewerParsedHA.Addon.db.global.parsedSources = {
    [200] = { sources = { { sourceType = "vendor", name = "Fresh Vendor" } }, sourceHash = 222, lastParsed = 6000 },
}
NewerParsedHA.CatalogStore:Initialize()
assert(NewerParsedHA.Addon.db.global.schemaVersion == 7)
assertMigrated(NewerParsedHA.CatalogStore:Get(200), NewerParsedHA.Addon.db.global.parsedSources[200], "Fresh Vendor", 222, 6000)

local NewerCatalogHA = FreshCatalogStoreHA()
NewerCatalogHA.Addon.db.global.schemaVersion = 4
NewerCatalogHA.Addon.db.global.catalogItems = {
    [300] = { sources = { { sourceType = "vendor", name = "Current Vendor" } }, sourceHash = 333, lastParsed = 9000 },
}
NewerCatalogHA.Addon.db.global.parsedSources = {
    [300] = { sources = { { sourceType = "vendor", name = "Stale Vendor" } }, sourceHash = 444, lastParsed = 2000 },
}
NewerCatalogHA.CatalogStore:Initialize()
assertMigrated(NewerCatalogHA.CatalogStore:Get(300), NewerCatalogHA.Addon.db.global.parsedSources[300], "Current Vendor", 333, 9000)

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
assertMigrated(equalRecord, EqualHA.Addon.db.global.parsedSources[400], "Same Vendor", 555, 7000)
assert(equalRecord.rawSourceText == "the dev raw corpus", "equal-hash migration must retain raw source text")
EqualHA.CatalogStore:Initialize()
assert(equalRecord.rawSourceText == "the dev raw corpus")
print("hs205_sv_dedup: historical winner stamps and raw preservation ok")

-- HS-241: a parser version bump must force a re-parse even when sourceHash
-- is unchanged, so a parsing-logic fix reaches players who already scanned
-- the affected item and stored a stamp under an older (or no) parserVersion.
local versionParseCalls = 0
local VersionHA = {
    Addon = {
        db = { global = { parsedSources = {}, catalogItems = {} } },
        Debug = function() end,
        RegisterModule = function() end,
    },
    Constants = { VERSION = "test" },
    Events = { Fire = function() end },
    DecorMapping = {},
    SourceTextParser = {
        VERSION = 2,
        ParseSourceText = function(_, sourceText)
            versionParseCalls = versionParseCalls + 1
            return { sources = { { sourceType = "treasure", name = sourceText } } }
        end,
    },
}
assert(loadfile(root .. "/Data/CatalogStore.lua"))("Homestead", VersionHA)
VersionHA.CatalogStore:Initialize()
assert(loadfile(root .. "/Modules/SourceTextScanner.lua"))("Homestead", VersionHA)

local staleSourceText = "Treasure: Gift of the Phoenix|nZone: Eversong Woods"
VersionHA.SourceTextScanner:ProcessScannedItem({ itemID = 900, sourceText = staleSourceText, recordID = 1 })
assert(versionParseCalls == 1, "first scan always parses")
local staleStamp = VersionHA.Addon.db.global.parsedSources[900]
assert(staleStamp.parserVersion == 2, "stamp must record the parser version it was parsed with")

-- Simulate a stamp written before this gate existed (or under an older
-- parserVersion): same sourceHash, no parserVersion. Hash-only
-- change-detection would skip this; the version gate must not.
staleStamp.parserVersion = nil
VersionHA.SourceTextScanner:ProcessScannedItem({ itemID = 900, sourceText = staleSourceText, recordID = 1 })
assert(versionParseCalls == 2, "stale/missing parserVersion must force a reparse even when sourceHash is unchanged")
assert(VersionHA.Addon.db.global.parsedSources[900].parserVersion == 2, "reparse must stamp the current parserVersion")

-- Once stamped at the current version, an unchanged sourceText skips again.
VersionHA.SourceTextScanner:ProcessScannedItem({ itemID = 900, sourceText = staleSourceText, recordID = 1 })
assert(versionParseCalls == 2, "current parserVersion + unchanged hash must still skip")
print("hs205_sv_dedup: parser version gate forces reparse of stale stamps ok")
