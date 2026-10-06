-- luacheck: globals assert loadfile print time Foundry_1_0

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")
local fakeClock = 1000
time = function()
    fakeClock = fakeClock + 1
    return fakeClock
end

local raiseDevErrorCalls = {}
Foundry_1_0 = {
    RaiseDevError = function(_, msg)
        table.insert(raiseDevErrorCalls, msg)
    end,
}

local V7_DROPPED_RECORD_KEYS = { "lastScanned", "sourceHash", "lastParsed" }

local function FreshCatalogStoreHA()
    local freshHA = {
        Addon = { db = { global = {} }, Debug = function() end, RegisterModule = function() end },
        Constants = { VERSION = "hs398-test" },
        Events = { Fire = function() end },
        DecorMapping = {},
    }
    assert(loadfile(root .. "/Data/CatalogStore.lua"))("Homestead", freshHA)
    return freshHA
end

local function assertV7Record(record)
    for _, key in ipairs(V7_DROPPED_RECORD_KEYS) do
        assert(record[key] == nil, "expected retired record key " .. key .. " to be nil")
    end
end

-- Case 1: v6->v7 modifies catalogItems in place and retains only live fields.
local Case1 = FreshCatalogStoreHA()
local g1 = Case1.Addon.db.global
local catalogItems1 = {
    [100] = {
        isOwned = true, decorID = 999, name = "Owned Decor",
        sources = { { sourceType = "vendor", name = "Vendor" } },
        rawSourceText = "Sold by Vendor", lastScanned = 100, sourceHash = 200, lastParsed = 300,
    },
}
g1.schemaVersion = 6
g1.catalogItems = catalogItems1
g1.parsedSources = { [100] = { sourceHash = 200, lastParsed = 300 } }
g1.scannedVendors = { [77] = { lastScanned = 444, items = {} } }
g1.__v5Backup = { keys = { vendorVisited = { [1] = true } } }

Case1.CatalogStore:Initialize()
assert(g1.schemaVersion == 7, "expected v6->v7 to stamp 7")
assert(g1.catalogItems == catalogItems1, "expected catalogItems table identity to survive v7")
assertV7Record(catalogItems1[100])
assert(catalogItems1[100].isOwned == true and catalogItems1[100].decorID == 999)
assert(catalogItems1[100].name == "Owned Decor")
assert(catalogItems1[100].sources[1].name == "Vendor")
assert(catalogItems1[100].rawSourceText == "Sold by Vendor")
assert(g1.parsedSources[100].sourceHash == 200 and g1.parsedSources[100].lastParsed == 300)
assert(g1.scannedVendors[77].lastScanned == 444, "must not alter vendor scan timestamps")
assert(g1.__v5Backup == nil, "v7 must remove the completed-chain backup")
assert(Case1.CatalogStore.RestoreV5Backup == nil, "v7 must retire the v5 restore API")
Case1.CatalogStore:Initialize()
assert(g1.schemaVersion == 7 and g1.catalogItems == catalogItems1)
assertV7Record(catalogItems1[100])
print("hs300_schema_v6: case 1 (v6->v7 retention and idempotence) ok")

-- Case 2: v5 still traverses the old chain, then v7 removes transient fields.
local Case2 = FreshCatalogStoreHA()
local g2 = Case2.Addon.db.global
g2.schemaVersion = 5
g2.catalogItems = { [200] = { isOwned = true, lastScanned = 1, sourceHash = 2, lastParsed = 3 } }
g2.parsedSources = { [200] = { sourceHash = 2, lastParsed = 3 } }
g2.vendorVisited = { [1001] = true }
Case2.CatalogStore:Initialize()
assert(g2.schemaVersion == 7, "expected v5 replay to complete through v7")
assert(g2.vendorVisited == nil, "expected v6 cleanup to remain active")
assert(g2.__v5Backup == nil, "expected v7 to remove backup after v5 replay")
assertV7Record(g2.catalogItems[200])
assert(g2.catalogItems[200].isOwned == true)
assert(g2.parsedSources[200].sourceHash == 2 and g2.parsedSources[200].lastParsed == 3)
print("hs300_schema_v6: case 2 (v5 chain through v7) ok")

-- Case 3: corrupt stamps repair through the historic chain and end at v7.
local Case3 = FreshCatalogStoreHA()
local g3 = Case3.Addon.db.global
g3.schemaVersion = "corrupt"
g3.catalogItems = {}
g3.parsedSources = {
    [300] = {
        sources = { { sourceType = "vendor", name = "Old Vendor" } }, recordID = 999,
        lastParsed = 1000, sourceHash = 555, raw = "raw sourceText",
    },
}
local ok3, err3 = pcall(function() Case3.CatalogStore:Initialize() end)
assert(ok3, "Initialize() must repair corrupt schemaVersion: " .. tostring(err3))
assert(g3.schemaVersion == 7)
assert(g3.__v5Backup == nil)
assertV7Record(g3.catalogItems[300])
assert(g3.catalogItems[300].decorID == 999 and g3.catalogItems[300].rawSourceText == "raw sourceText")
assert(g3.parsedSources[300].sourceHash == 555 and g3.parsedSources[300].lastParsed == 1000)
print("hs300_schema_v6: case 3 (corrupt chain through v7) ok")

-- Case 4: future v8 is fail-loud and byte-preserving.
local Case4 = FreshCatalogStoreHA()
local g4 = Case4.Addon.db.global
g4.schemaVersion = 8
g4.catalogItems = { [400] = { lastScanned = 1, sourceHash = 2, lastParsed = 3, isOwned = true } }
g4.__v5Backup = { keys = { vendorVisited = { [1] = true } } }
raiseDevErrorCalls = {}
Case4.CatalogStore:Initialize()
assert(#raiseDevErrorCalls == 1, "expected one fail-loud future-version error")
assert(g4.schemaVersion == 8 and g4.__v5Backup ~= nil)
assert(g4.catalogItems[400].lastScanned == 1 and g4.catalogItems[400].sourceHash == 2)
assert(g4.catalogItems[400].lastParsed == 3 and g4.catalogItems[400].isOwned == true)
print("hs300_schema_v6: case 4 (v8 refuses mutation) ok")

print("hs300_schema_v6: all cases ok")
