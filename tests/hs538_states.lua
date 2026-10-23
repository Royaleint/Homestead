-- luacheck: globals assert io loadfile print rawset

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
    HA.VendorData = { HasOfferForItem = function() return false end }
    HA.SourceManager = { GetAllSources = function() return {} end }
    rawset(_G, "C_Item", { GetItemNameByID = function() return nil end, RequestLoadItemDataByID = function() end })
    assert(s == "ready")
    assert(HA.DecorBrowser.CanGet.Entry(5).own == nil, "no entry and no record is unknown")
    print("hs538_states: unknown ownership shows no word ok")
end

-- The words and second signal of every state.
do
    local _, HA = state({ true, false, true, true }, {})
    local S = HA.DecorBrowser.Style
    local words = {
        owned = { "Collected", "check" }, can = { "Can get now", "dot" }, locked = { "Requires: %s", "lock" },
        faction = { "%s only", "stop" }, event = { "%s only", "clock" }, notOwned = { "Not collected", nil },
        counting = { "Counting\226\128\166", nil },
        allDone = { "All collected", "check" }, some = { "%d can get now", "dot" },
        idle = { "Not active", "clock" }, live = { "Active now", "clock" },
    }
    for key, want in pairs(words) do
        local st = S.state[key]
        assert(st and st.word == want[1], "wrong words for state " .. key)
        assert(st.glyph == want[2], "wrong second signal for state " .. key)
    end
    for key in pairs(S.state) do assert(words[key], "unexpected state " .. key) end
    assert(S.state.can.color == S.color.can, "Can get now is not the green")
    assert(S.state.faction.color == S.color.stop, "the other faction is not red")
    for key, st in pairs(S.state) do
        if key ~= "faction" then assert(st.color ~= S.color.stop, key .. " must not be red") end
    end
    assert(S.state.unlocked == nil and not S.state.owned.word:find("Unlocked"), "rows must not say Unlocked to buy")
    print("hs538_states: state words ok")
end

-- Collected is marked with a check and the word, and no state is dimmed.
do
    local _, HA = state({ true, false, true, true }, {})
    local S = HA.DecorBrowser.Style
    assert(S.state.owned.glyph == "check" and S.state.owned.word == "Collected", "Collected lost its check or its word")
    assert(S.state.allDone.glyph == "check", "All collected lost its check")
    for key, st in pairs(S.state) do assert(st.dim == nil, key .. " is dimmed") end
    assert(S.ware.size == 48 and S.ware.gap == 4, "the ware cell is not 48 px with a 4 px gap")
    print("hs538_states: collected is marked, not dimmed ok")
end

-- Every locale file carries each tab's section, ending with its fixed line, so the tab changes can add
-- keys above their own line without touching each other.
do
    local tabs = { "Summary", "Catalog", "Sources", "Item" }
    local locales = { "enUS", "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }
    for _, loc in ipairs(locales) do
        local f = assert(io.open(root .. "/Locale/" .. loc .. ".lua", "rb"))
        local text = f:read("*a"):gsub("\r", "")
        f:close()
        local last = 0
        for _, tab in ipairs(tabs) do
            local at = text:find("-- Decor Browser: " .. tab .. "\n", 1, true)
            local stop = text:find("\n-- end: " .. tab .. "\n", 1, true) or text:find("\n-- end: " .. tab .. "$")
            assert(at and stop and at > last and stop > at, loc .. " lacks the " .. tab .. " section or its end line")
            assert(not text:find("-- end: " .. tab, stop + 2, true), loc .. " has two end lines for " .. tab)
            last = stop
        end
    end
    print("hs538_states: locale tab sections ok")
end

print("hs538_states: ok")
