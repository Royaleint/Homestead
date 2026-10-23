-- luacheck: globals assert loadfile print rawset

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Decor Browser ownership: the browser derives "owned" from the catalog entry
-- it already reads, never downgrades a stored owned, says nothing before this
-- session's first collection read, and writes nothing to CatalogStore. The
-- real CatalogStore, SourceManager verdict, VendorFilter, Adapter, Facts and
-- CanGet run against stubbed data and WoW globals.
-------------------------------------------------------------------------------

local function newEnv()
    local env = {
        done = true, attempted = true, warm = true, responded = true,
        catalog = {}, subclass = {}, sources = {}, vendors = {}, offers = {},
        measured = {}, spies = { SetOwned = 0, SetUnowned = 0, ProbeByDecorID = 0, IsOwnedFresh = 0 },
    }
    rawset(_G, "Foundry_1_0", { RaiseDevError = function(_, msg) error(msg) end })
    rawset(_G, "wipe", function(t) for k in pairs(t) do t[k] = nil end return t end)
    rawset(_G, "GetBuildInfo", function() return "12.0.1", "1", "1", 120001 end)
    rawset(_G, "UnitFactionGroup", function() return "Alliance" end)
    rawset(_G, "Enum", { ItemClass = { Housing = 20 }, ItemHousingSubclass = { Decor = 0, Dye = 1 },
        UIMapType = { Continent = 2, Zone = 3 } })
    rawset(_G, "C_Item", {
        GetItemInfoInstant = function(id)
            local sub = env.subclass[id]
            if sub then return id, "", "", "", 0, 20, sub end
        end,
        GetItemNameByID = function(id) return "Item " .. id end,
        RequestLoadItemDataByID = function() end,
    })
    rawset(_G, "C_Map", {
        GetBestMapForUnit = function() return nil end,
        GetMapInfo = function() return nil end,
    })
    rawset(_G, "C_HousingCatalog", {
        GetCatalogEntryInfoByItem = function(id) return env.catalog[id] end,
        GetCatalogEntryInfoByRecordID = function() return nil end,
    })
    local HA = {
        Addon = { db = {
            global = { catalogItems = {}, schemaVersion = 7, scannedVendors = {}, noDecorVendors = {} },
            profile = { vendorTracer = { showEventVendors = true } },
        }, Debug = function() end, RegisterModule = function() end },
        Events = { Fire = function() end },
        Constants = { ZoneToFactionMap = {}, TEXTURE_ROOT = "", Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
        DecorMapping = {}, AchievementSources = {}, QuestSources = {}, EventSources = { EventVendors = {} },
    }
    env.HA = HA
    HA.PerformanceTrace = { Measure = function(_, op, workload, fn, ...)
        env.measured[#env.measured + 1] = { op = op, workload = workload }
        return fn(...)
    end }
    HA.CatalogScanner = {
        HasFirstReadCompleted = function() return env.done end,
        HasFirstReadAttempted = function() return env.attempted end,
        IsWarm = function() return env.warm end,
        HasStorageResponded = function() return env.responded end,
    }
    HA.CalendarDetector = { IsHolidayActive = function() return nil end }
    HA.VendorData = {
        GetVendor = function(_, npcID) return env.vendors[npcID] end,
        HasOfferForItem = function(_, id) return env.offers[id] == true end,
        GetVendorItems = function(_, npcID) return env.vendors[npcID] and env.vendors[npcID].items end,
        GetScannedVendorItems = function() return nil end,
        GetMergedItemIDs = function(_, v) return v.items end,
    }
    for _, file in ipairs({ "Locale/enUS.lua", "Data/CatalogStore.lua", "Data/SourceManager.lua",
        "UI/VendorFilter.lua", "UI/Browser/Style.lua", "UI/Browser/Adapter.lua", "UI/Browser/Facts.lua",
        "UI/Browser/CanGet.lua" }) do
        assert(loadfile(root .. "/" .. file))("Homestead", HA)
    end
    -- The router is not loaded; the item page registers itself on it.
    HA.DecorBrowser.RegisterPage = function() end
    assert(loadfile(root .. "/UI/Browser/Item.lua"))("Homestead", HA)
    local SM = HA.SourceManager
    SM.GetAllSources = function(_, id) return env.sources[id] or {} end
    SM.GetRequirements = function() return {} end
    local store = HA.CatalogStore
    for name in pairs(env.spies) do
        local original = store[name]
        store[name] = function(self, itemID, readOnly, ...)
            if name ~= "IsOwnedFresh" or readOnly ~= true then env.spies[name] = env.spies[name] + 1 end
            return original(self, itemID, readOnly, ...)
        end
    end
    -- Stored records go in before Initialize, which counts them.
    function env.records(list)
        HA.Addon.db.global.catalogItems = list
        store:Initialize()
    end
    function env.decor(itemID, entry)
        HA.DecorMapping[itemID + 900000] = itemID
        env.catalog[itemID] = entry
    end
    function env.sell(itemID, npcID)
        local v = env.vendors[npcID] or { npcID = npcID, mapID = 1, items = {} }
        env.vendors[npcID] = v
        v.items[#v.items + 1] = itemID
        env.offers[itemID] = true
        local list = env.sources[itemID] or {}
        list[#list + 1] = { type = "vendor", data = { npcID = npcID, vendor = v, cost = { gold = 100 } } }
        env.sources[itemID] = list
    end
    env.records({})
    return env, HA, HA.DecorBrowser.Data, HA.DecorBrowser.CanGet
end

local function deepEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = deepCopy(v) end
    return out
end

local ZERO = { totalNumStored = 0, remainingRedeemable = 0, totalNumPlaced = 0 }

-------------------------------------------------------------------------------
-- An owned achievement-only item the scan never recorded reads owned
-------------------------------------------------------------------------------

do
    local env, HA, D, CG = newEnv()
    env.decor(101, { totalNumStored = 1 })
    HA.AchievementSources[101] = { achievementID = 7 }
    env.decor(102, ZERO)
    HA.AchievementSources[102] = { achievementID = 8 }
    assert(HA.CatalogStore:Get(101) == nil, "sanity: no stored record")
    assert(D.OwnState(101, env.catalog[101]) == "owned", "a readable entry with counts reads owned")
    local p = CG.Walk().progress
    assert(p.src.achievements.total == 2 and p.src.achievements.owned == 1,
        "counted in Achievements collected: " .. p.src.achievements.owned)
    print("hs538_ownership: derived owned outside the scan list ok")
end

-------------------------------------------------------------------------------
-- Never downgrade, readable zero, nil entry
-------------------------------------------------------------------------------

do
    local env, HA, D, CG = newEnv()
    env.records({ [201] = { isOwned = true } })
    env.decor(201, ZERO)
    env.decor(202, ZERO)
    env.decor(203, nil)
    HA.QuestSources[203] = { questID = 9 }
    assert(D.OwnState(201, env.catalog[201]) == "owned", "a stored owned beats an entry that reads 0")
    assert(CG.Offer(201, nil) == "owned")
    assert(D.OwnState(202, env.catalog[202]) == "notOwned", "a readable entry with counts 0 is not owned")
    assert(D.OwnState(203, nil) == nil, "no entry and no stored owned is unknown")
    local p = CG.Walk().progress
    assert(p.total == 3 and p.owned == 1, "the unknown item counts in the total, not as collected")
    assert(p.src.quests.total == 1 and p.src.quests.owned == 0)
    print("hs538_ownership: never downgrade, zero and unknown ok")
end

-------------------------------------------------------------------------------
-- A zero-decor account after the login skip latched the first read
-------------------------------------------------------------------------------

do
    local env, _, D, CG = newEnv()
    env.warm, env.responded = false, true
    env.decor(301, ZERO)
    env.decor(302, ZERO)
    env.sell(301, 50)
    assert(D.CollectionState() == "ready", "a zero-decor player is known")
    assert(D.OwnState(302, env.catalog[302]) == "notOwned", "every readable entry reads not owned")
    assert(CG.Offer(301, 50) == "can", "Can get now is possible")
    assert(CG.Walk().list[1].verdict == "can")
    print("hs538_ownership: zero-decor account ok")
end

-------------------------------------------------------------------------------
-- Before the first read every item is unknown, even with stored owned
-------------------------------------------------------------------------------

do
    local env, _, D, CG = newEnv()
    env.records({ [401] = { isOwned = true } })
    env.decor(401, { totalNumStored = 2 })
    env.decor(402, ZERO)
    env.sell(402, 51)
    env.done, env.attempted = false, false
    assert(D.OwnState(401, env.catalog[401]) == nil, "stored owned says nothing before the first read")
    assert(D.OwnState(402, env.catalog[402]) == nil)
    assert(CG.Offer(402, 51) == "unknown" and CG.Walk() == nil and CG.Entry(402) == nil)
    assert(#env.measured == 0, "no walk runs before the first read")
    print("hs538_ownership: nothing before the first read ok")
end

-------------------------------------------------------------------------------
-- An ownership-unknowable housing item is unknown and never Can get now
-------------------------------------------------------------------------------

do
    local env, _, D, CG = newEnv()
    env.subclass[501] = 1
    env.decor(501, { totalNumStored = 3 })
    env.sell(501, 52)
    assert(D.OwnState(501, env.catalog[501]) == nil, "a non-decor housing item is unknown")
    assert(CG.Offer(501, 52) == "unknown", "never Can get now")
    assert(CG.Entry(501).verdict == "unknown" and CG.Entry(501).canBy == nil)
    print("hs538_ownership: unknowable subclass ok")
end

-------------------------------------------------------------------------------
-- A walk writes nothing to CatalogStore
-------------------------------------------------------------------------------

do
    local env, HA, _, CG = newEnv()
    env.records({ [601] = { isOwned = true, decorID = 1601 }, [602] = { name = "Lamp" } })
    env.decor(601, ZERO)
    env.decor(602, { totalNumPlaced = 1 })
    env.decor(603, { remainingRedeemable = 1 })
    env.decor(604, ZERO)
    env.sell(604, 53)
    local before = deepCopy(HA.Addon.db.global)
    local ownedBefore = HA.CatalogStore:GetOwnedCount()
    local w = CG.Walk()
    CG.Rank()
    CG.Fill()
    for _, id in ipairs({ 601, 602, 603, 604 }) do
        CG.HiddenBy(id)
        HA.DecorBrowser.ItemState(id, 53)
        HA.DecorBrowser.ItemState(id)
    end
    assert(w.progress.owned == 3, "sanity: two items were derived as owned")
    assert(deepEqual(before, HA.Addon.db.global), "the saved catalog must be unchanged by a walk")
    assert(HA.CatalogStore:GetOwnedCount() == ownedBefore, "the stored owned count must be unchanged")
    assert(HA.CatalogStore:IsOwned(602) == false and HA.CatalogStore:IsOwned(603) == false,
        "a derived owned must never reach the store")
    for name, n in pairs(env.spies) do assert(n == 0, name .. " was called " .. n .. " times") end
    print("hs538_ownership: no CatalogStore writes ok")
end

-------------------------------------------------------------------------------
-- The derived rule is the store's own rule
-------------------------------------------------------------------------------

do
    local env, HA, D = newEnv()
    local cases = {
        { "stored", { totalNumStored = 1 }, "owned" }, { "placed", { totalNumPlaced = 2 }, "owned" },
        { "redeemable", { remainingRedeemable = 1 }, "owned" }, { "zero", ZERO, "notOwned" },
    }
    for i, case in ipairs(cases) do
        local name, info, expected = case[1], case[2], case[3]
        env.decor(700 + i, info)
        local store = HA.CatalogStore:ComputeOwnedFromInfo(info) and "owned" or "notOwned"
        assert(store == expected, "sanity: " .. name)
        assert(D.OwnState(700 + i, info) == store, name .. " entry: " .. tostring(D.OwnState(700 + i, info)))
    end
    print("hs538_ownership: ComputeOwnedFromInfo parity ok")
end

-------------------------------------------------------------------------------
-- By source matches the Catalog filters, with unknowns present
-------------------------------------------------------------------------------

do
    local env, HA, _, CG = newEnv()
    env.records({ [801] = { isOwned = true } })
    env.decor(801, ZERO)
    env.decor(802, { totalNumStored = 1 })
    env.decor(803, ZERO)
    env.decor(804, nil)
    env.decor(805, nil)
    for _, id in ipairs({ 801, 803, 804 }) do env.sell(id, 54) end
    for _, id in ipairs({ 802, 803, 805 }) do HA.QuestSources[id] = { questID = id } end
    HA.AchievementSources[804] = { achievementID = 1 }
    local w = CG.Walk()
    for _, key in ipairs(CG.SOURCE_KEYS) do
        local total, collected, notCollected, unknown = 0, 0, 0, 0
        for _, e in ipairs(w.list) do
            if e.src[key] then
                total = total + 1
                if e.own == "owned" then collected = collected + 1
                elseif e.own == "notOwned" then notCollected = notCollected + 1
                else unknown = unknown + 1 end
            end
        end
        local s = w.progress.src[key]
        assert(s.total == total, key .. " total " .. s.total .. " vs " .. total)
        assert(s.owned == collected, key .. " collected " .. s.owned .. " vs " .. collected)
        assert(total == collected + notCollected + unknown)
    end
    assert(w.progress.src.vendors.total == 3 and w.progress.src.vendors.owned == 1)
    assert(w.progress.src.quests.total == 3 and w.progress.src.quests.owned == 1)
    assert(w.progress.total == 5 and w.progress.owned == 2, "unknowns stay in the total")
    print("hs538_ownership: By source parity ok")
end

print("hs538_ownership: ok")
