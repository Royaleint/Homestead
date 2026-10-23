-- luacheck: globals assert io loadfile print rawget rawset
local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- One ware list per vendor: D.VendorWares is the list the map pins count, so
-- the grid, the bar and the list row agree with them. The real BadgeCalculation
-- runs beside the browser over the shared world, so its totals are computed,
-- not written down. Also the vendor page's Currency and Requires data.
-------------------------------------------------------------------------------

local newWorld = assert(loadfile(root .. "/tests/hs538_world.lua"))()

-- BadgeCalculation.lua is the map pins' rule; the browser's ware list must not change it.
do
    local f = assert(io.open(root .. "/UI/BadgeCalculation.lua", "rb"))
    local text = f:read("*a"):gsub("\r", "")
    f:close()
    local h = 0
    for i = 1, #text do h = (h * 31 + text:byte(i)) % 4294967291 end
    assert(#text == 71149 and h == 3595448028, "BadgeCalculation.lua changed: " .. #text .. " bytes, hash " .. h)
end

local function world()
    local env = newWorld(root)
    local HA = env.HA
    HA.MapPinProvider = { continentToZones = {} }
    HA.VendorData.GetMergedItemSet = function(_, v)
        local set = {}
        for _, id in ipairs(v.items or {}) do set[id] = true end
        return set, v.items or {}
    end
    rawget(_G, "C_Timer").NewTicker = function() return { Cancel = function() end } end
    assert(loadfile(root .. "/UI/BadgeCalculation.lua"))("Homestead", HA)

    local store, SM = HA.CatalogStore, HA.SourceManager
    env.unknowable, env.ownedAs = {}, {}
    local unknowable, isOwned = store.IsOwnershipUnknowable, store.IsOwned
    function store:IsOwnershipUnknowable(id) return env.unknowable[id] or unknowable(self, id) end
    function store:IsOwned(id)
        if env.ownedAs[id] ~= nil then return env.ownedAs[id] end
        return isOwned(self, id)
    end
    env.smCalls, env.probes = 0, 0
    local avail, reqs = SM.GetVendorItemAvailabilityState, SM.GetRequirements
    SM.GetVendorItemAvailabilityState = function(...) env.smCalls = env.smCalls + 1 return avail(...) end
    SM.GetRequirements = function(...) env.smCalls = env.smCalls + 1 return reqs(...) end
    local catalog = rawget(_G, "C_HousingCatalog")
    local byItem = catalog.GetCatalogEntryInfoByItem
    catalog.GetCatalogEntryInfoByItem = function(...) env.probes = env.probes + 1 return byItem(...) end

    -- Owned the way the scanner records it: in the store's cache, not only in a catalog entry.
    function env.cacheOwned(id)
        HA.Addon.db.global.catalogItems[id] = { isOwned = true }
        assert(store:IsOwned(id) == true, "the fixture must own " .. id .. " in the store cache")
    end
    function env.promo(id, npcID) env.reqs[id .. ":" .. npcID] = { { type = "promotion", name = "Drop" } } end
    function env.wareCount(id)
        local n = 0
        for _, op in ipairs(env.measured) do if op == id then n = n + 1 end end
        return n
    end
    return env, HA, HA.DecorBrowser.Data, HA.DecorBrowser.CanGet, HA.BadgeCalculation
end

local function ids(list) return table.concat(list, ",") end

-------------------------------------------------------------------------------
-- The ware list: BadgeCalculation's rule, memoised per vendor and refresh
-------------------------------------------------------------------------------

do
    local env, HA, D, CG, BC = world()
    local v = env.standard()
    -- Nell: owned decor plus a non-decor ware whose ownership the game cannot report.
    local nell = env.vendor(300, { name = "Nell" })
    env.decor(301, "Nell Owned")
    env.decor(302, "Nell Dye")
    env.sell(301, nell)
    env.sell(302, nell)
    env.cacheOwned(301)
    env.unknowable[302] = true
    -- Opal: owned decor plus a promotion ware not owned.
    local opal = env.vendor(310, { name = "Opal" })
    env.decor(311, "Opal Owned")
    env.decor(312, "Opal Promo")
    env.sell(311, opal)
    env.sell(312, opal)
    env.cacheOwned(311)
    env.promo(312, 310)
    -- Pia: an owned promotion (kept), an unowned one (dropped), one IsOwned answers 1 for (dropped), one
    -- only a catalog entry calls owned (dropped: the cache decides, as it does for the map pins), one plain.
    local pia = env.vendor(320, { name = "Pia" })
    for id = 321, 325 do
        env.decor(id, "Pia " .. id)
        env.sell(id, pia)
        if id < 325 then env.promo(id, 320) end
    end
    env.cacheOwned(321)
    env.ownedAs[323] = 1
    env.catalog[324] = { totalNumPlaced = 1, categoryIDs = { 1 } }

    assert(ids(D.VendorWares(nell)) == "301", "an unknowable ware is left out: " .. ids(D.VendorWares(nell)))
    assert(ids(D.VendorWares(opal)) == "311", "an unowned promotion is left out")
    D.InvalidateMemos()
    env.probes = 0
    assert(ids(D.VendorWares(pia)) == "321,325", "Pia: " .. ids(D.VendorWares(pia)))
    assert(env.probes == 0, "the ware list reads ownership from the cache only")

    -- Every listed vendor, and Pia's mix: the list is the map pins' list.
    local checked = 0
    for _, vendor in ipairs(D.ListedVendors()) do
        local list, owned = D.VendorWares(vendor), 0
        for _, id in ipairs(list) do
            if HA.CatalogStore:IsOwned(id) == true then owned = owned + 1 end
        end
        local stats = BC:GetVendorStats(vendor, "all")
        assert(#list == stats.total, vendor.name .. ": " .. #list .. " wares, the map pins count " .. stats.total)
        assert(owned == stats.collected, vendor.name .. ": collected " .. owned .. " against " .. stats.collected)
        checked = checked + 1
    end
    assert(checked >= 7, "too few listed vendors checked: " .. checked)

    -- How many can get now is the same over the full merged list.
    for _, vendor in ipairs(D.ListedVendors()) do
        local n = 0
        for _, id in ipairs(HA.VendorData:GetMergedItemIDs(vendor)) do
            local e = CG.Entry(id)
            if e.canBy and e.canBy[vendor.npcID] then n = n + 1 end
        end
        assert(CG.VendorCanCount(vendor) == n, vendor.name .. ": VendorCanCount moved")
    end

    -- Hide: both vendors now hide as collected, as their map pins read.
    assert(CG.HiddenBy({ vendor = nell }) == "collected", "owned decor plus an unknowable ware hides as collected")
    assert(CG.HiddenBy({ vendor = opal }) == "collected", "owned decor plus an unowned promotion hides as collected")
    assert(CG.HiddenBy({ vendor = v.anna }) == nil)

    -- Memoised: the second call makes no SourceManager call; a new refresh computes again.
    D.InvalidateMemos()
    local first = D.VendorWares(v.anna)
    local measured = env.wareCount("browser_vendor_wares")
    env.smCalls = 0
    assert(D.VendorWares(v.anna) == first and env.smCalls == 0, "the second call makes no SourceManager call")
    assert(D.VendorWares(D.Vendor(100)) == first, "keyed by npcID")
    assert(env.wareCount("browser_vendor_wares") == measured, "measured only when computed")
    D.InvalidateMemos()
    assert(D.VendorWares(v.anna) ~= first and env.smCalls > 0, "a new memo generation computes again")
    assert(#D.VendorWares({}) == 0, "a vendor without an npcID has no wares")
    print("hs538_vendor_counts: ware list ok")
end

-------------------------------------------------------------------------------
-- Currency
-------------------------------------------------------------------------------

do
    local env, HA, D = world()
    local v = env.standard()
    local currencies = { [1] = { name = "Valor", iconFileID = 501 }, [2] = { name = "Honor", iconFileID = 502 } }
    rawset(_G, "C_CurrencyInfo", { GetCurrencyInfo = function(id) return currencies[id] end })
    local costs, costCalls = {}, 0
    HA.SourceManager.GetVendorItemCost = function(_, id, vendor)
        costCalls = costCalls + 1
        return costs[id .. ":" .. vendor.npcID] or { gold = 100 }
    end

    local list, pending = D.VendorCurrencies(v.anna)
    assert(ids(list) == "Gold" and pending == false, "gold only: " .. ids(list))

    local two = env.vendor(400, { name = "Quinn" })
    for id = 401, 403 do env.decor(id, "Q" .. id) env.sell(id, two) end
    costs["401:400"] = { currencies = { { id = 1, amount = 5 } } }
    costs["402:400"] = { currencies = { { id = 2, amount = 5 }, { id = 1, amount = 2 } } }
    costs["403:400"] = { currencies = { { id = 2, amount = 1 } } }
    list, pending = D.VendorCurrencies(two)
    assert(ids(list) == "|T501:0|t Valor,|T502:0|t Honor" and not pending, "two currencies, once each: " .. ids(list))

    -- An item currency whose name is still loading: left out, asked again, filled in after the names refresh.
    local parts = env.vendor(410, { name = "Rook" })
    env.decor(411, "R411")
    env.sell(411, parts)
    costs["411:410"] = { items = { { id = 901, amount = 3 } } }
    list, pending = D.VendorCurrencies(parts)
    assert(#list == 0 and pending == true, "a loading name is left out and reported pending")
    costCalls = 0
    pending = select(2, D.VendorCurrencies(parts))
    assert(costCalls == 1 and pending == true, "not memoised while pending")
    local walks = env.walks()
    env.names[901] = "Spare Parts"
    assert(D.NameArrived(901, true) == true)
    list, pending = D.VendorCurrencies(parts)
    assert(ids(list) == "|T1901:0|t Spare Parts" and pending == false, "filled after the names refresh: " .. ids(list))
    assert(env.walks() == walks, "filling a name walks nothing")
    costCalls = 0
    assert(D.VendorCurrencies(parts) == list and costCalls == 0, "memoised once complete")
    print("hs538_vendor_counts: currency ok")
end

-------------------------------------------------------------------------------
-- Requires: the requirements every ware shares, with met; never the faction
-------------------------------------------------------------------------------

do
    local env, _, D = world()
    env.standard()
    local friendly = { type = "reputation", faction = "F", standing = "Friendly", met = true }
    local honored = { type = "reputation", faction = "G", standing = "Honored", met = false }
    local favor = { type = "unknown", text = "Mysterious Favor" }
    local shop = env.vendor(500, { name = "Sela", faction = "Alliance" })
    for id = 501, 503 do env.decor(id, "S" .. id) env.sell(id, shop) end
    env.reqs["501:500"] = { friendly, honored, favor, { type = "level", level = 70, met = true } }
    env.reqs["502:500"] = { favor, honored, friendly }
    env.reqs["503:500"] = { honored, favor, friendly }
    local reqs = D.VendorRequirements(shop)
    local out = {}
    for i, r in ipairs(reqs) do out[i] = r.text .. "=" .. tostring(r.met) end
    assert(table.concat(out, ";") == "Friendly with F=true;Honored with G=false;Mysterious Favor=nil",
        "shared, met, not yet and unchecked: " .. table.concat(out, ";"))
    for _, r in ipairs(reqs) do assert(r.text ~= "Alliance", "the faction is never a requirement") end
    assert(D.VendorRequirements(shop) == reqs, "memoised")

    local mixed = env.vendor(510, { name = "Tam", faction = "Horde" })
    for id = 511, 513 do env.decor(id, "T" .. id) env.sell(id, mixed) end
    env.reqs["511:510"] = { friendly }
    env.reqs["513:510"] = { friendly }
    assert(#D.VendorWares(mixed) == 3)
    env.smCalls = 0
    assert(#D.VendorRequirements(mixed) == 0, "nothing shared: no requirement, and no faction line")
    assert(env.smCalls == 2, "once nothing is shared, the other wares are not read")
    print("hs538_vendor_counts: requirements ok")
end

print("hs538_vendor_counts: ok")
