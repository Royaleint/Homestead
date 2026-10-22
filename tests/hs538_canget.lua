-- luacheck: globals assert loadfile print rawset

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Decor Browser "Can get now": the single verdict, the walk, ranking, the
-- Summary fill and the Hide reasons. The real CatalogStore, SourceManager
-- verdict (requirements and scanned offers stubbed), VendorFilter, Adapter,
-- Facts and CanGet run against stubbed data and WoW globals.
-------------------------------------------------------------------------------

local function newEnv()
    local env = {
        done = true, attempted = true, warm = true, responded = true, faction = "Alliance",
        catalog = {}, catalogCalls = 0, names = {}, sources = {}, vendors = {}, offers = {}, reqs = {},
        scanned = {}, calendar = {}, themes = {}, vendorActiveCalls = 0, measured = {},
        playerMap = nil, maps = {},
    }
    rawset(_G, "Foundry_1_0", { RaiseDevError = function(_, msg) error(msg) end })
    rawset(_G, "wipe", function(t) for k in pairs(t) do t[k] = nil end return t end)
    rawset(_G, "GetBuildInfo", function() return "12.0.1", "1", "1", 120001 end)
    rawset(_G, "UnitFactionGroup", function() return env.faction end)
    rawset(_G, "Enum", { ItemClass = { Housing = 20 }, ItemHousingSubclass = { Decor = 0, Dye = 1 },
        UIMapType = { Continent = 2, Zone = 3 } })
    rawset(_G, "C_Item", {
        GetItemNameByID = function(id) return env.names[id] end,
        RequestLoadItemDataByID = function() end,
    })
    rawset(_G, "C_HousingCatalog", {
        GetCatalogEntryInfoByItem = function(id)
            env.catalogCalls = env.catalogCalls + 1
            return env.catalog[id]
        end,
        GetCatalogEntryInfoByRecordID = function() return nil end,
    })
    rawset(_G, "C_Map", {
        GetBestMapForUnit = function() return env.playerMap end,
        GetMapInfo = function(id) return env.maps[id] end,
        GetMapChildrenInfo = function() return {} end,
    })
    local HA = {
        Addon = { db = {
            global = { catalogItems = {}, schemaVersion = 7, scannedVendors = {}, noDecorVendors = {} },
            profile = { vendorTracer = { showEventVendors = true } },
        }, Debug = function() end, RegisterModule = function() end },
        Events = { Fire = function() end },
        Constants = { ZoneToFactionMap = {}, TEXTURE_ROOT = "", Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
        DecorMapping = {}, EventSources = { EventVendors = {} },
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
    HA.CalendarDetector = { IsHolidayActive = function(_, name)
        if env.calendar == nil then return nil end
        return env.calendar[name] == true
    end }
    HA.EndeavorsData = {
        GetThemeForVendor = function(_, v) return v.theme end,
        IsThemeActive = function(_, theme)
            if theme == nil then return nil end
            return env.themes[theme]
        end,
        IsVendorActive = function()
            env.vendorActiveCalls = env.vendorActiveCalls + 1
            return true
        end,
    }
    local events = HA.EventSources.EventVendors
    HA.VendorData = {
        GetVendor = function(_, npcID)
            if env.vendors[npcID] then return env.vendors[npcID] end
            local ev = events[npcID]
            if ev and env.calendar and env.calendar[ev.event] == true then return ev end
        end,
        HasOfferForItem = function(_, id) return env.offers[id] == true end,
        GetVendorItems = function(_, npcID) return (env.vendors[npcID] or events[npcID] or {}).items end,
        GetScannedVendorItems = function(_, npcID, itemID) return env.scanned[npcID .. ":" .. itemID] end,
        GetMergedItemIDs = function(_, v) return v.items end,
    }
    for _, file in ipairs({ "Locale/enUS.lua", "Data/CatalogStore.lua", "Data/SourceManager.lua",
        "UI/VendorFilter.lua", "UI/Browser/Style.lua", "UI/Browser/Adapter.lua", "UI/Browser/Facts.lua",
        "UI/Browser/CanGet.lua" }) do
        assert(loadfile(root .. "/" .. file))("Homestead", HA)
    end
    local SM = HA.SourceManager
    SM.GetAllSources = function(_, id) return env.sources[id] or {} end
    SM.GetRequirements = function(_, id, npcID) return env.reqs[id .. ":" .. tostring(npcID)] or {} end
    local isMet = SM.IsRequirementMet
    SM.IsRequirementMet = function(self, req)
        if req.met ~= nil then return req.met end
        return isMet(self, req)
    end
    HA.CatalogStore:Initialize()

    -- A not-owned decor item with a name and a readable entry.
    function env.decor(itemID, entry)
        HA.DecorMapping[itemID + 900000] = itemID
        env.catalog[itemID] = entry or { totalNumStored = 0 }
        env.names[itemID] = env.names[itemID] or ("Item " .. itemID)
    end
    function env.vendor(npcID, fields)
        local v = fields or {}
        v.npcID, v.mapID, v.items = npcID, v.mapID or 1, v.items or {}
        env.vendors[npcID] = v
        return v
    end
    function env.sell(itemID, v, cost)
        local list = env.sources[itemID] or {}
        list[#list + 1] = { type = "vendor", data = { npcID = v and v.npcID, vendor = v, cost = cost or { gold = 100 } } }
        env.sources[itemID] = list
        env.offers[itemID] = true
        if v then v.items[#v.items + 1] = itemID end
    end
    return env, HA, HA.DecorBrowser.Data, HA.DecorBrowser.CanGet
end

-------------------------------------------------------------------------------
-- The shared vendor verdict: requirements, scanned offers, promotions, "A vendor"
-------------------------------------------------------------------------------

do
    local env, _, D, CG = newEnv()
    local v = env.vendor(10)
    for id = 1, 5 do env.decor(id) env.sell(id, v) end
    env.reqs["2:10"] = { { type = "unknown", text = "Mysterious Favor" } }
    env.scanned["10:3"] = { { isPurchasable = false } }
    env.reqs["4:10"] = { { type = "promotion", name = "Twitch Drop" } }
    env.reqs["5:10"] = { { type = "reputation", faction = "F", standing = "Friendly", met = true } }

    assert(CG.Offer(1, 10) == "can", "no requirements, purchasable")
    assert(CG.Offer(2, 10) == "locked", "a requirement Homestead cannot check never qualifies")
    local reqs = D.Requirements(2, 10)
    assert(#reqs == 1 and reqs[1].met == nil and reqs[1].text == "Mysterious Favor", "the requirement is shown in words")
    assert(CG.Offer(3, 10) == "locked", "the player's scan saw it greyed out")
    assert(CG.Offer(4, 10) == "unobtainable", "a promotion")
    assert(CG.Offer(5, 10) == "can", "a met requirement")

    env.decor(6)
    env.sell(6, nil)
    assert(CG.Offer(6, nil) == "unknown", '"A vendor" never counts')
    assert(CG.Entry(6).verdict == "unknown" and CG.Entry(6).canBy == nil)

    local fill = CG.Fill()
    for _, row in ipairs(fill.notYet) do assert(row.entry.itemID ~= 4, "a promotion is never a next step") end
    print("hs538_canget: shared vendor verdict ok")
end

-------------------------------------------------------------------------------
-- Listing: event pins, holidays, Endeavors, faction, removed, unreleased
-------------------------------------------------------------------------------

do
    local env, HA, _, CG = newEnv()
    local events = HA.EventSources.EventVendors
    events[20] = { npcID = 20, mapID = 1, event = "Hallow's End", _isEventVendor = true, items = { 21 } }
    env.decor(21)
    HA.EventSources[21] = { event = "Hallow's End" }
    env.calendar = { ["Hallow's End"] = true }
    env.sources[21] = { { type = "vendor", data = { npcID = 20, vendor = events[20], cost = { gold = 5 } } } }
    HA.Addon.db.profile.vendorTracer.showEventVendors = false
    assert(CG.Offer(21, 20) == "can", "event pins off: still Can get now while the event runs")

    HA.DecorBrowser.Data.InvalidateMemos()
    env.calendar = {}
    env.sources[21] = nil
    assert(CG.Offer(21, 20) == "unlisted", "an off-season holiday vendor is not listed")
    local e = CG.Entry(21)
    assert(e.verdict == "unlisted" and e.event == "Hallow's End", "found through the holiday vendor's wares")
    env.calendar = nil
    assert(CG.Offer(21, 20) == "unlisted", "an unknown calendar is not active")

    -- A holiday item with no vendor never counts.
    env.decor(22)
    HA.EventSources[22] = { event = "Noblegarden", vendorName = "Noblegarden Merchant" }
    env.calendar = { Noblegarden = true }
    HA.DecorBrowser.Data.InvalidateMemos()
    assert(CG.Entry(22).verdict == nil and CG.Entry(22).canBy == nil, "Noblegarden with no vendor never counts")

    local endeavor = env.vendor(30, { endeavor = true, theme = "Harvest" })
    env.decor(31)
    env.sell(31, endeavor)
    env.themes.Harvest = true
    assert(CG.Offer(31, 30) == "can", "an active Endeavor vendor")
    env.themes.Harvest = false
    assert(CG.Offer(31, 30) == "unlisted", "an inactive Endeavor vendor")
    env.themes.Harvest = nil
    assert(CG.Offer(31, 30) == "unlisted", "an unknown Endeavor theme is not active")
    endeavor.theme = nil
    assert(CG.Offer(31, 30) == "unlisted", "an Endeavor vendor with no theme is not active")
    assert(env.vendorActiveCalls == 0, "the fail-open Endeavor check is never used")

    local horde = env.vendor(40, { faction = "Horde" })
    local removed = env.vendor(41, { removed = true })
    local unreleased = env.vendor(42, { unreleased = true })
    env.decor(43)
    env.sell(43, horde)
    env.sell(43, removed)
    env.sell(43, unreleased)
    assert(CG.Offer(43, 40) == "faction" and CG.Offer(43, 41) == "unlisted" and CG.Offer(43, 42) == "unlisted")
    HA.DecorBrowser.Data.InvalidateMemos()
    assert(CG.Entry(43).verdict == "unlisted", "an item's verdict is its best offer's")
    print("hs538_canget: listing ok")
end

-------------------------------------------------------------------------------
-- Before the first read: no walk and no Can get now
-------------------------------------------------------------------------------

do
    local env, _, D, CG = newEnv()
    local v = env.vendor(10)
    env.decor(1)
    env.sell(1, v)
    for _, state in ipairs({ { false, false }, { false, true } }) do
        env.done, env.attempted = state[1], state[2]
        assert(CG.Offer(1, 10) == "unknown" and CG.Walk() == nil and CG.Rank() == nil and CG.Fill() == nil)
        assert(CG.Entry(1) == nil and CG.VendorCanCount(v) == nil and D.Progress() == nil)
    end
    assert(#env.measured == 0 and env.catalogCalls == 0, "no item walk and no catalog read before the first read")
    env.done = true
    assert(CG.Offer(1, 10) == "can")
    print("hs538_canget: nothing before the first read ok")
end

-------------------------------------------------------------------------------
-- The walk: one measured pass per memo generation
-------------------------------------------------------------------------------

do
    local env, HA, D, CG = newEnv()
    local v = env.vendor(10)
    for id = 1, 3 do env.decor(id) env.sell(id, v) end
    HA.DecorBrowser.State = { catalogMemo = {} }
    CG.Offer(1, 10)
    CG.Offer(1, 10)
    assert(env.catalogCalls == 1, "an offer reads the catalog through the shared page memo")
    HA.DecorBrowser.State, env.catalogCalls = nil, 0
    local w = CG.Walk()
    assert(#env.measured == 1 and env.measured[1].op == "browser_walk" and env.measured[1].workload == 3,
        "the walk is measured as browser_walk with the item count")
    assert(env.catalogCalls == 3, "one catalog read per item")
    assert(CG.Walk() == w and #env.measured == 1, "memoised")
    assert(CG.VendorCanCount(v) == 3)
    D.InvalidateMemos()
    assert(CG.Walk() ~= w and #env.measured == 2, "a new memo generation walks again")
    print("hs538_canget: walk ok")
end

-------------------------------------------------------------------------------
-- Ranking: time-limited, bonus, nearness, gold only, then name
-------------------------------------------------------------------------------

do
    local env, HA, _, CG = newEnv()
    env.maps[100] = { mapType = 2, parentMapID = 0, name = "Continent" }
    env.maps[101] = { mapType = 3, parentMapID = 100, name = "Here" }
    env.maps[102] = { mapType = 3, parentMapID = 100, name = "Next door" }
    env.maps[103] = { mapType = 5, parentMapID = 101, name = "Shop" }
    env.maps[200] = { mapType = 2, parentMapID = 0, name = "Far" }
    env.maps[201] = { mapType = 3, parentMapID = 200, name = "Far zone" }
    env.playerMap = 103
    local here, near, far = env.vendor(1, { mapID = 101 }), env.vendor(2, { mapID = 102 }), env.vendor(3, { mapID = 201 })
    local events = HA.EventSources.EventVendors
    events[4] = { npcID = 4, mapID = 201, event = "Lunar Festival", _isEventVendor = true, items = {} }
    env.calendar = { ["Lunar Festival"] = true }
    local currency = { gold = 0, currencies = { { id = 1 } } }
    for id = 11, 17 do env.decor(id) end
    env.names[16] = nil
    env.sell(11, far, currency)
    env.sell(12, near, currency)
    env.sell(13, here, currency)
    env.sell(14, here)
    env.catalog[15].firstAcquisitionBonus = 1
    env.sell(15, far, currency)
    env.sell(16, here)
    env.sell(17, events[4], currency)
    env.sell(17, here)
    local order = {}
    for i, e in ipairs(CG.Rank()) do order[i] = e.itemID end
    assert(table.concat(order, ",") == "17,15,14,16,13,12,11", table.concat(order, ","))
    local first = CG.Rank()[1]
    assert(first.best.npcID == 4 and first.near == 3, "the best source is the time-limited one, even far away")
    assert(CG.Rank()[3].near == 1, "a building's map walks up to its zone")

    env.playerMap = 201
    order = {}
    for i, e in ipairs(CG.Rank()) do order[i] = e.itemID end
    assert(#env.measured == 1, "a zone change re-ranks without walking again")
    assert(table.concat(order, ",", 3) == "11,14,16,12,13", table.concat(order, ","))
    print("hs538_canget: ranking ok")
end

-------------------------------------------------------------------------------
-- Names that load after the walk re-sort the ranking and join the fill, with no new walk
-------------------------------------------------------------------------------

do
    local env, _, _, CG = newEnv()
    local v = env.vendor(10)
    env.decor(1) env.decor(2) env.decor(3)
    env.names[1], env.names[2], env.names[3] = "Zed", nil, nil
    env.sell(1, v) env.sell(2, v) env.sell(3, v)
    env.reqs["3:10"] = { { type = "achievement", id = 1, met = false } }
    local function ranked()
        local t = {}
        for i, e in ipairs(CG.Rank()) do t[i] = e.itemID end
        return table.concat(t, ",")
    end
    local function notYet()
        local t = {}
        for i, row in ipairs(CG.Fill().notYet) do t[i] = row.entry.itemID end
        return table.concat(t, ",")
    end
    assert(ranked() == "1,2" and notYet() == "", "unnamed items sort last and are not next steps")
    assert(CG.RefreshNames() == false, "nothing arrived")
    env.names[2], env.names[3] = "Alpha", "Bell"
    assert(CG.RefreshNames() == true)
    assert(ranked() == "2,1", "a late name re-sorts: " .. ranked())
    assert(notYet() == "3", "a late name joins the fill")
    assert(#env.measured == 1, "no new walk")
    print("hs538_canget: late names ok")
end

-------------------------------------------------------------------------------
-- The Summary fill: q = 0, 1, 2, 3 and all collected
-------------------------------------------------------------------------------

do
    local function fillFor(q, candidates, allOwned)
        local env, _, _, CG = newEnv()
        local v = env.vendor(10)
        for i = 1, q do env.decor(i) env.sell(i, v) end
        for i = 1, candidates do
            local id = 50 + i
            env.decor(id)
            env.sell(id, v)
            local reqs = {}
            for r = 1, 5 - i do reqs[r] = { type = "achievement", id = r, met = false } end
            env.reqs[id .. ":10"] = reqs
        end
        env.decor(60, { totalNumStored = 1 })
        env.decor(61)
        env.names[61] = nil
        env.sell(61, v)
        env.reqs["61:10"] = { { type = "achievement", id = 1, met = false } }
        if allOwned then
            for id in pairs(env.catalog) do env.catalog[id] = { totalNumStored = 1 } end
        end
        return CG.Fill()
    end
    for _, case in ipairs({ { 0, 3 }, { 1, 2 }, { 2, 1 }, { 3, 0 } }) do
        local q, notYet = case[1], case[2]
        local f = fillFor(q, 4, false)
        assert(f.count == q and #f.rows == q and #f.notYet == notYet, "q = " .. q .. ": " .. #f.rows .. "+" .. #f.notYet)
        assert(not f.allCollected)
        for i, row in ipairs(f.notYet) do
            assert(row.entry.itemID == 55 - i, "fewest unmet first: " .. row.entry.itemID)
            assert(row.unmet == i and row.npcID == 10)
            assert(row.entry.name ~= nil, "unnamed items are never next steps")
        end
    end
    local few = fillFor(0, 1, false)
    assert(#few.rows == 0 and #few.notYet == 1, "too few candidates: the slots close up")
    local all = fillFor(0, 2, true)
    assert(all.allCollected and #all.rows == 0 and #all.notYet == 0, "all collected")
    print("hs538_canget: fill ok")
end

-------------------------------------------------------------------------------
-- Hide reasons: collected, other faction, never an unknown
-------------------------------------------------------------------------------

do
    local env, _, _, CG = newEnv()
    local ally, horde = env.vendor(1), env.vendor(2, { faction = "Horde" })
    env.decor(1, { totalNumPlaced = 1 })
    env.sell(1, ally)
    env.decor(2)
    env.sell(2, horde)
    env.decor(3, nil)
    env.sell(3, ally)
    env.decor(4)
    env.sell(4, horde)
    env.sell(4, ally)
    assert(CG.HiddenBy(1) == "collected" and CG.HiddenBy(2) == "faction")
    assert(CG.HiddenBy(3) == nil, "unknown ownership is never hidden as collected")
    assert(CG.HiddenBy(4) == nil, "an item one own-faction vendor sells is not hidden")
    assert(CG.HiddenBy({ vendor = horde }) == "faction")
    assert(CG.HiddenBy({ vendor = ally }) == nil, "an unknown ware keeps the vendor shown")
    assert(CG.HiddenBy({ items = { 1 } }) == "collected" and CG.HiddenBy({ items = { 1, 4 } }) == nil)
    env.sell(2, ally)
    CG.ResetFactionOnly()
    assert(CG.HiddenBy(2) == nil, "a new own-faction vendor clears the faction hide once the sources change")
    env.done, env.attempted = false, false
    assert(CG.HiddenBy(1) == nil and CG.HiddenBy({ items = { 1 } }) == nil, "nothing hides as collected while counting")
    print("hs538_canget: hide reasons ok")
end

print("hs538_canget: ok")
