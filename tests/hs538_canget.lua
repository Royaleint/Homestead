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
        money = 1e9, currency = {}, count = {},
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
    rawset(_G, "GetMoney", function() return env.money end)
    rawset(_G, "C_CurrencyInfo", { GetCurrencyInfo = function(id)
        local c = env.currency[id]
        if c == nil then return { quantity = 1e6 } end
        return c or nil
    end })
    rawset(_G, "C_Item", {
        GetItemCount = function(id) return env.count[id] or 1e6 end,
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
    local env, _, _, CG = newEnv()
    local v = env.vendor(10)
    env.decor(1)
    env.sell(1, v)
    for _, state in ipairs({ { false, false }, { false, true } }) do
        env.done, env.attempted = state[1], state[2]
        assert(CG.Offer(1, 10) == "unknown" and CG.Walk() == nil and CG.Rank() == nil and CG.Fill() == nil)
        assert(CG.Entry(1) == nil and CG.VendorCanCount(v) == nil)
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
    D.InvalidateMemos()
    local w = CG.Walk()
    assert(#env.measured == 1 and env.measured[1].op == "browser_walk" and env.measured[1].workload == 3,
        "the walk is measured as browser_walk with the item count")
    assert(env.catalogCalls == 3, "one catalog read per item")
    assert(CG.Walk() == w and #env.measured == 1, "memoised")
    assert(CG.VendorCanCount(v) == 3 and env.measured[2].op == "browser_vendor_wares")
    D.InvalidateMemos()
    assert(CG.Walk() ~= w and #env.measured == 3 and env.measured[3].op == "browser_walk", "a new memo generation walks again")
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
    local currency = { gold = 0, currencies = { { id = 1, amount = 5 } } }
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
    local B
    local function fillFor(q, candidates, allOwned)
        local env, HA, _, CG = newEnv()
        B = HA.DecorBrowser
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
            assert(row.unmet == i and select(3, B.ItemState(row.entry.itemID)) == 10)
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

-------------------------------------------------------------------------------
-- Paying: "can get now" needs the requirements met and the cost covered by what
-- this character carries. Each case is a fresh load, so a fresh wallet snapshot.
-------------------------------------------------------------------------------

local function costWords(_, c)
    local t = {}
    if c.gold then t[#t + 1] = "g" .. c.gold end
    for _, p in ipairs(c.currencies or {}) do t[#t + 1] = "c" .. p.id .. "x" .. p.amount end
    for _, p in ipairs(c.items or {}) do t[#t + 1] = "i" .. p.id .. "x" .. p.amount end
    return t[1] and table.concat(t, " ") or nil
end

local function payEnv()
    local env, HA, D, CG = newEnv()
    HA.VendorData.FormatCost = costWords
    return env, HA, D, CG, HA.DecorBrowser
end

-- An offer with no cost recorded at all.
local function sellFree(env, itemID, v)
    local list = env.sources[itemID] or {}
    list[#list + 1] = { type = "vendor", data = { npcID = v.npcID, vendor = v } }
    env.sources[itemID] = list
    env.offers[itemID] = true
    v.items[#v.items + 1] = itemID
end

local function judge(setup)
    local env, HA, _, CG, B = payEnv()
    local v = env.vendor(10)
    env.decor(1)
    setup(env, v, HA)
    return CG.Entry(1).verdict, CG.Offer(1, 10), select(2, B.ItemState(1)), CG, B
end

do
    local reads = 0
    for _, case in ipairs({ { 99, "short" }, { 100, "can" }, { 101, "can" }, { 0, "short" }, { 1e15, "can" } }) do
        local verdict, offer, words = judge(function(env, v)
            env.sell(1, v, { gold = 100 })
            env.money = case[1]
        end)
        assert(verdict == case[2] and offer == case[2], "gold with " .. case[1] .. ": " .. verdict .. "/" .. offer)
        assert(words == (case[2] == "short" and "g100" or nil), "short words name the gold price")
    end

    local env, _, _, CG = payEnv()
    local v = env.vendor(10)
    for id = 1, 3 do env.decor(id) env.sell(id, v, { gold = 100 }) end
    rawset(_G, "GetMoney", function() reads = reads + 1 return env.money end)
    CG.Walk()
    assert(CG.Offer(2, 10) == "can" and reads == 1, "gold is read once per snapshot: " .. reads)
    print("hs538_canget: gold short, exact and enough ok")
end

do
    local cost = { currencies = { { id = 3363, amount = 5 } } }
    for _, case in ipairs({ { 4, "short" }, { 5, "can" }, { 0, "short" }, { false, "unpriced" } }) do
        local verdict, offer = judge(function(env, v)
            env.sell(1, v, cost)
            env.currency[3363] = case[1] and { quantity = case[1] } or false
        end)
        assert(verdict == case[2] and offer == case[2], "currency with " .. tostring(case[1]) .. ": " .. verdict)
    end
    print("hs538_canget: currency short, undiscovered and no info ok")
end

do
    local args
    local function carrying(bags, reagent, bank)
        return function(env, v)
            env.sell(1, v, { items = { { id = 7, amount = 2 } } })
            rawget(_G, "C_Item").GetItemCount = function(id, includeBank, includeUses, includeReagentBank, includeAccountBank)
                args = { id, includeBank, includeUses, includeReagentBank, includeAccountBank }
                return bags + (includeReagentBank and reagent or 0) + (includeBank and bank or 0)
                    + (includeAccountBank and bank or 0)
            end
        end
    end
    assert(judge(carrying(2, 0, 0)) == "can", "bags count")
    assert(judge(carrying(0, 2, 0)) == "can", "the reagent bank counts")
    assert(judge(carrying(0, 0, 5)) == "short", "the bank alone does not count")
    assert(args[1] == 7 and args[2] == false and args[3] == false and args[4] == true and args[5] == nil,
        "counted as the merchant counts: bags and reagent bank")
    assert(judge(carrying(1, 0, 0)) == "short")
    print("hs538_canget: item costs ok")
end

do
    local mixed = { gold = 100, currencies = { { id = 1, amount = 5 } }, items = { { id = 7, amount = 2 } } }
    local verdict, _, words = judge(function(env, v) env.sell(1, v, mixed) env.money = 100 env.count[7] = 1 end)
    assert(verdict == "short" and words == "i7x2", "every part must be covered; the words list only short parts")
    verdict, _, words = judge(function(env, v)
        env.sell(1, v, mixed)
        env.money, env.currency[1], env.count[7] = 50, { quantity = 1 }, 2
    end)
    assert(verdict == "short" and words == "g100 c1x5", "full prices of the short parts: " .. tostring(words))
    assert(judge(function(env, v) env.sell(1, v, mixed) env.money, env.count[7] = 100, 2 end) == "can")
    verdict, _, words = judge(function(env, v)
        env.sell(1, v, { gold = 100, currencies = { { id = 1 } } })
        env.money = 10
    end)
    assert(verdict == "short" and words == "g100", "a short part outweighs one that can't be checked")
    print("hs538_canget: mixed costs ok")
end

-------------------------------------------------------------------------------
-- Unknown prices are never "can get now"
-------------------------------------------------------------------------------

do
    local verdict, offer, words, CG, B = judge(function(env, v) sellFree(env, 1, v) end)
    assert(verdict == "unpriced" and offer == "unpriced" and words == nil, "no cost recorded")
    assert(next(CG.Entry(1).canBy) == nil and CG.VendorCanCount(B.Data.Vendor(10)) == 0 and #CG.Rank() == 0,
        "not counted")
    local st = B.Style.state.unpriced
    assert(st.word == "Price not recorded" and st.color == B.Style.color.muted and st.glyph == nil, "muted, no glyph")
    for _, cost in ipairs({
        { currencies = { { amount = 5 } } }, { currencies = { { id = 1 } } }, { items = { { amount = 1 } } },
        { items = { { id = 7 } } }, { gold = 0 }, {},
    }) do
        assert(judge(function(env, v) env.sell(1, v, cost) end) == "unpriced", "a part that can't be checked")
    end
    assert(judge(function(env, v) env.sell(1, v, { currencies = { { id = 1, amount = 5 } } }) env.currency[1] = false end)
        == "unpriced", "a currency the game has no info for")
    print("hs538_canget: unknown prices ok")
end

do
    local env, HA, _, CG, B = payEnv()
    local events = HA.EventSources.EventVendors
    events[20] = { npcID = 20, mapID = 1, event = "Lunar Festival", _isEventVendor = true, items = { 1, 2 } }
    env.calendar = { ["Lunar Festival"] = true }
    env.decor(1) env.decor(2)
    local asked = {}
    HA.SourceManager.GetVendorItemCost = function(_, id, vendor)
        asked[id] = vendor.npcID
        return id == 1 and { gold = 100 } or nil
    end
    local e = CG.Entry(1)
    assert(asked[1] == 20 and e.verdict == "can" and e.reach[20].cost.gold == 100 and e.canBy[20],
        "an event vendor's shipped or scanned cost is used")
    assert(CG.Entry(2).verdict == "unpriced" and next(CG.Entry(2).canBy) == nil, "an event vendor with no cost stays unpriced")
    assert(select(3, B.ItemState(2)) == 20, "the state names the event vendor")
    env.money = 99
    B.Data.InvalidateMemos()
    assert(CG.Entry(1).verdict == "short", "an event vendor's cost is judged like any other")
    print("hs538_canget: event vendor costs ok")
end

-------------------------------------------------------------------------------
-- Any vendor: one paid offer makes "can get now"; the state names its vendor
-------------------------------------------------------------------------------

do
    local env, _, D, CG, B = payEnv()
    local a, b, c = env.vendor(10), env.vendor(11), env.vendor(12)
    env.money = 150
    for id = 1, 5 do env.decor(id) end
    env.sell(1, a, { gold = 100 }) env.sell(1, b, { gold = 200 })
    env.sell(2, a, { gold = 300 }) env.sell(2, b, { gold = 200 })
    env.sell(3, c, { gold = 100 }) env.sell(3, b, { gold = 200 })
    env.sell(4, c, { gold = 100 }) sellFree(env, 4, a)
    env.sell(5, c, { gold = 100 })
    env.reqs["3:12"] = { { type = "achievement", id = 1, met = false } }
    env.reqs["4:12"] = { { type = "achievement", id = 1, met = false } }

    local e = CG.Entry(1)
    assert(e.verdict == "can" and e.canBy[10] and not e.canBy[11], "A paid and B short: can, with only A in canBy")
    assert(CG.Offer(1, 11) == "short" and B.ItemState(1, 11) == "short", "B judged alone is short")
    assert(select(2, B.ItemState(1, 11)) == "g200" and CG.Primary(1).npcID == 10)

    local state, words, at = B.ItemState(2)
    assert(state == "short" and (at == 10 or at == 11), "both short")
    assert(words == (at == 10 and "g300" or "g200"), "the words describe the vendor the state names")
    assert(CG.Primary(2).npcID == at, "the row names the state's vendor")

    state, words, at = B.ItemState(3)
    assert(state == "short" and words == "g200" and at == 11, "short plus locked is short")
    assert(CG.Primary(3).npcID == 11, "the short vendor, not the first listed")

    state, words, at = B.ItemState(4)
    assert(state == "unpriced" and words == nil and at == 10, "unpriced plus locked is unpriced")
    assert(CG.Primary(4).npcID == 10)

    assert(B.ItemState(5) == "can" and CG.Entry(5).canBy[12], "a plain paid offer")

    -- The counts agree, and none counts short or unpriced.
    local counts = CG.VendorCanCount(D.Vendor(10)) .. "," .. CG.VendorCanCount(D.Vendor(11)) .. ","
        .. CG.VendorCanCount(D.Vendor(12))
    assert(counts == "1,0,1", "vendor counts: " .. counts)
    local ranked = {}
    for i, r in ipairs(CG.Rank()) do ranked[i] = r.itemID end
    assert(table.concat(ranked, ",") == "1,5" and CG.Fill().count == 2, "ranked: " .. table.concat(ranked, ","))
    print("hs538_canget: any vendor ok")
end

-------------------------------------------------------------------------------
-- A row that can't be got now names the vendor its state names
-------------------------------------------------------------------------------

do
    local env, HA, _, CG, B = payEnv()
    local events = HA.EventSources.EventVendors
    events[20] = { npcID = 20, mapID = 1, event = "Hallow's End", _isEventVendor = true, items = { 2 } }
    local a, b = env.vendor(10), env.vendor(11)
    env.decor(1)
    env.sell(1, a) env.sell(1, b)
    env.reqs["1:10"] = { { type = "achievement", id = 1, met = false }, { type = "achievement", id = 2, met = false } }
    env.reqs["1:11"] = { { type = "achievement", id = 1, met = false } }
    assert(B.ItemState(1) == "locked" and CG.Primary(1).npcID == 11, "the easiest locked vendor, not the first listed")

    env.decor(2)
    env.sell(2, env.vendor(41, { removed = true }))
    local state, arg, at = B.ItemState(2)
    assert(state == "event" and arg == "Hallow's End" and at == 20, "an off-season holiday names its vendor")
    assert(CG.Primary(2).npcID == 20, "the holiday vendor, not the first listed")
    print("hs538_canget: state vendor ok")
end

-------------------------------------------------------------------------------
-- The fill's next steps: short, then unpriced, then locked by fewest unmet
-------------------------------------------------------------------------------

do
    local env, _, _, CG = payEnv()
    local v = env.vendor(10)
    env.money = 50
    for id = 1, 5 do env.decor(id) end
    env.names[1], env.names[2], env.names[3], env.names[4], env.names[5] = "Zed", "Yew", "Bell", "Alpha", "Cork"
    env.sell(1, v, { gold = 100 })
    sellFree(env, 2, v)
    env.sell(3, v) env.reqs["3:10"] = { { type = "achievement", id = 1, met = false } }
    env.sell(4, v) env.reqs["4:10"] = { { type = "achievement", id = 1, met = false }, { type = "achievement", id = 2, met = false } }
    env.sell(5, v, { gold = 100 })
    local f = CG.Fill()
    local ids = {}
    for i, row in ipairs(f.notYet) do ids[i] = row.entry.itemID end
    assert(f.count == 0 and table.concat(ids, ",") == "5,1,2", "short by name first: " .. table.concat(ids, ","))

    env, _, _, CG = payEnv()
    v = env.vendor(10)
    env.money = 50
    for id = 2, 4 do env.decor(id) end
    env.names[2], env.names[3], env.names[4] = "Yew", "Bell", "Alpha"
    sellFree(env, 2, v)
    env.sell(3, v) env.reqs["3:10"] = { { type = "achievement", id = 1, met = false } }
    env.sell(4, v) env.reqs["4:10"] = { { type = "achievement", id = 1, met = false }, { type = "achievement", id = 2, met = false } }
    ids = {}
    for i, row in ipairs(CG.Fill().notYet) do ids[i] = row.entry.itemID .. ":" .. row.unmet end
    assert(table.concat(ids, ",") == "2:0,3:1,4:2", "unpriced, then locked by fewest unmet: " .. table.concat(ids, ","))
    print("hs538_canget: fill next steps ok")
end

print("hs538_canget: ok")
