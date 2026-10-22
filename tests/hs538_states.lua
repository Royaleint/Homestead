-- luacheck: globals assert loadfile print rawset

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Decor Browser collection states: "counting" until this session's first
-- collection read, "ready" once it is done and ownership is known, "notRead"
-- when it is done without ownership data or could not be done. The real
-- CatalogStore answers HasPersistedData; only the scanner is stubbed. Unknown
-- ownership shows neither Collected nor Not collected.
-------------------------------------------------------------------------------

rawset(_G, "Foundry_1_0", { RaiseDevError = function(_, msg) error(msg) end })
rawset(_G, "wipe", function(t) for k in pairs(t) do t[k] = nil end return t end)
rawset(_G, "GetBuildInfo", function() return "12.0.1", "1", "1", 120001 end)
rawset(_G, "C_HousingCatalog", {
    GetCatalogEntryInfoByItem = function() return nil end,
    GetCatalogEntryInfoByRecordID = function() return nil end,
})

-- scanner: done, attempted, warm, responded. records: the saved catalog, or nil for no store yet.
local function state(scanner, records)
    local HA = {
        Addon = { db = {
            global = { catalogItems = records, schemaVersion = 7, scannedVendors = {}, noDecorVendors = {} },
            profile = {},
        }, Debug = function() end, RegisterModule = function() end },
        Events = { Fire = function() end },
        Constants = { ZoneToFactionMap = {}, TEXTURE_ROOT = "" },
        DecorMapping = {},
    }
    if scanner then
        HA.CatalogScanner = {
            HasFirstReadCompleted = function() return scanner[1] end,
            HasFirstReadAttempted = function() return scanner[2] end,
            IsWarm = function() return scanner[3] end,
            HasStorageResponded = function() return scanner[4] end,
        }
    end
    for _, file in ipairs({ "Locale/enUS.lua", "Data/CatalogStore.lua", "UI/Browser/Style.lua",
        "UI/Browser/Adapter.lua", "UI/Browser/Facts.lua", "UI/Browser/CanGet.lua" }) do
        assert(loadfile(root .. "/" .. file))("Homestead", HA)
    end
    if records then HA.CatalogStore:Initialize() end
    return HA.DecorBrowser.Data.CollectionState(), HA
end

local OWNED = { [1] = { isOwned = true } }

assert(state(nil, {}) == "counting", "no scanner yet")
assert(state({ false, false, true, true }, OWNED) == "counting", "the first read has not finished")
assert(state({ false, true, false, false }, {}) == "notRead", "the first read was tried and failed")
assert(state({ true, false, true, false }, {}) == "ready", "a warm owner whose stored owned count is still 0")
assert(state({ true, false, false, true }, {}) == "ready", "a zero-decor player is known")
assert(state({ true, true, false, false }, OWNED) == "ready", "stored owned data")
assert(state({ true, false, false, false }, {}) == "notRead", "done, but storage never answered")
assert(state({ true, false, false, true }, nil) == "notRead", "done with no saved catalog (catalogItems nil)")
assert(state({ true, false, true, true }, nil) == "ready", "done and warm with no saved catalog yet")
print("hs538_states: collection state branches ok")

-- Unknown ownership: neither Collected nor Not collected.
do
    local s, HA = state({ true, false, true, true }, {})
    local D = HA.DecorBrowser.Data
    assert(s == "ready")
    assert(D.OwnState(5, nil) == nil, "no entry and no record is unknown")
    HA.SourceManager = { GetItemPresentation = function() error("unknown ownership reads no presentation") end }
    local st = D.ItemStatus(5)
    assert(st.state == "unknown", "no Collected or Not collected for an unknown item")
    print("hs538_states: unknown ownership shows no word ok")
end

print("hs538_states: ok")
