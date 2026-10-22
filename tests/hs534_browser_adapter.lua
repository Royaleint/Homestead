-- luacheck: globals assert loadfile print

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Decor browser data adapter (UI/Browser/Adapter.lua): the vendor-list
-- predicate, item status, vendor counts, the catalog memo, progress, the
-- faction label and Near You. The real Style, VendorFilter, enUS, Adapter,
-- Facts and CanGet files run against stubbed Homestead modules and WoW globals.
-- The collection is ready when the first read is done and store.known is true.
-------------------------------------------------------------------------------

local T0 = 1700000000
rawset(_G, "GetBuildInfo", function() return "12.0.1", "1", "1", 120001 end)
rawset(_G, "wipe", function(t) for k in pairs(t) do t[k] = nil end return t end)

local function newEnv()
    local HA = { DecorMapping = {} }
    local store = { records = {}, known = true, excluded = {}, getCalls = 0 }
    function store:HasPersistedData() return self.known end
    function store:IsOwned(id)
        local r = self.records[id]
        return r ~= nil and r.isOwned == true
    end
    function store:IsOwnershipUnknowable(id) return self.excluded[id] == true end
    function store:ComputeOwnedFromInfo(info)
        return ((info.totalNumStored or 0) + (info.remainingRedeemable or 0) + (info.totalNumPlaced or 0)) > 0
    end
    function store:Get(id)
        self.getCalls = self.getCalls + 1
        return self.records[id]
    end
    HA.CatalogStore = store
    HA.CatalogScanner = {
        HasFirstReadCompleted = function() return true end,
        HasFirstReadAttempted = function() return true end,
        IsWarm = function() return false end,
    }
    HA.PerformanceTrace = { Measure = function(_, _, _, fn, ...) return fn(...) end }
    local catalog = {}
    HA.catalogFixture = catalog
    rawset(_G, "C_HousingCatalog", {
        GetCatalogEntryInfoByItem = function(itemID) return catalog[itemID] end,
        GetCatalogEntryInfoByRecordID = function() return nil end,
    })
    rawset(_G, "C_Item", { GetItemNameByID = function() return "Item" end })
    HA.Addon = { db = {
        global = { noDecorVendors = {}, scannedVendors = {} },
        profile = { vendorTracer = { showEventVendors = true } },
    } }
    HA.Constants = { ZoneToFactionMap = {}, TEXTURE_ROOT = "Textures/" }
    HA.VendorData = { HasVendor = function() return false end }
    for _, file in ipairs({ "Locale/enUS.lua", "UI/Browser/Style.lua", "UI/VendorFilter.lua", "UI/Browser/Adapter.lua",
            "UI/Browser/Facts.lua", "UI/Browser/CanGet.lua" }) do
        assert(loadfile(root .. "/" .. file))("Homestead", HA)
    end
    return HA, store, HA.DecorBrowser.Data
end

local function addOwned(HA, store, itemID, firstSeen)
    store.records[itemID] = { isOwned = true, firstSeen = firstSeen }
    HA.DecorMapping[itemID + 500000] = itemID
end

-------------------------------------------------------------------------------
-- Vendor-list predicate
-------------------------------------------------------------------------------

do
    local HA, _, D = newEnv()
    assert(D.IsListedVendor({ npcID = 1 }) == true)
    assert(D.IsListedVendor({ npcID = 2, removed = true }) == false, "removed")
    assert(D.IsListedVendor({ npcID = 3, unreleased = true }) == false, "unreleased")

    HA.Addon.db.global.noDecorVendors[4] = { scanConfidence = "confirmed" }
    assert(D.IsListedVendor({ npcID = 4 }) == false, "confirmed no-decor")
    HA.VendorData.HasVendor = function() return true end
    assert(D.IsListedVendor({ npcID = 4 }) == true, "a known vendor is never hidden as no-decor")
    HA.VendorData.HasVendor = function() return false end

    -- Holiday vendors list while their holiday runs, whatever the map pin setting says.
    local running = { ["Hallow's End"] = true }
    HA.CalendarDetector = { IsHolidayActive = function(_, name) return running[name] end }
    local event = { npcID = 5, event = "Hallow's End", _isEventVendor = true }
    assert(D.IsListedVendor(event) == true)
    HA.Addon.db.global.noDecorVendors[5] = { scanConfidence = "confirmed" }
    assert(D.IsListedVendor(event) == true, "event vendors skip the no-decor check")
    HA.Addon.db.profile.vendorTracer.showEventVendors = false
    assert(D.IsListedVendor(event) == true, "event pins off: a running holiday's vendor is still listed")
    assert(D.IsListedVendor({ npcID = 5, removed = true, _isEventVendor = true }) == false, "removed beats event")
    HA.Addon.db.profile.vendorTracer.showEventVendors = true
    running["Hallow's End"] = false
    assert(D.IsListedVendor(event) == false, "holiday over")
    running["Hallow's End"] = nil
    assert(D.IsListedVendor(event) == false, "holiday state unknown")

    -- Endeavor vendors list only while their theme is known to be on; others never ask.
    local themeCalls, active = 0, { [8] = false, [9] = true }
    HA.EndeavorsData = {
        GetThemeForVendor = function(_, vendor) return vendor.npcID ~= 10 and vendor.npcID or nil end,
        IsThemeActive = function(_, theme)
            themeCalls = themeCalls + 1
            return active[theme]
        end,
        IsVendorActive = function() error("the browser never asks IsVendorActive") end,
    }
    assert(D.IsListedVendor({ npcID = 8, endeavor = true }) == false, "inactive Endeavor")
    assert(D.IsListedVendor({ npcID = 9, endeavor = true }) == true, "active Endeavor")
    assert(D.IsListedVendor({ npcID = 7, endeavor = true }) == false, "unknown theme state")
    assert(D.IsListedVendor({ npcID = 10, endeavor = true }) == false, "no theme")
    local before = themeCalls
    assert(D.IsListedVendor({ npcID = 8 }) == true)
    assert(themeCalls == before, "only Endeavor vendors consult the Endeavor state")


end

-------------------------------------------------------------------------------
-- Faction label and the vendor requirement line: the effective faction, never nil in a format
-------------------------------------------------------------------------------

do
    local HA, _, D = newEnv()
    local allianceMap, hordeMap = 1, 2
    HA.Constants.ZoneToFactionMap[allianceMap] = "Alliance"
    HA.Constants.ZoneToFactionMap[hordeMap] = "Horde"
    local nilInHorde = { npcID = 1, mapID = hordeMap }
    local neutralInHorde = { npcID = 2, mapID = hordeMap, faction = "Neutral" }
    assert(D.VendorFactionLabel(nilInHorde) == "Horde", "a vendor with no faction labels its map's faction")
    assert(D.VendorFactionLabel(neutralInHorde) == "Horde", "a Neutral vendor must not label as Neutral")
    assert(D.VendorFactionLabel({ npcID = 9 }) == nil, "no faction and no map gives no label")

    assert(D.VendorRequirements({ npcID = 3, mapID = allianceMap, faction = "Horde" }, {})[1] == "Horde")
    assert(D.VendorRequirements(neutralInHorde, {})[1] == "Horde", "a Neutral vendor in a Horde map lists Horde")
    assert(D.VendorRequirements({ npcID = 7, mapID = allianceMap, faction = "Neutral" }, {})[1] == "Alliance")
    local nilInAlliance = D.VendorRequirements({ npcID = 4, mapID = allianceMap }, {})
    assert(#nilInAlliance == 1 and nilInAlliance[1] == "Alliance", "a vendor with no faction in an Alliance map lists exactly Alliance")
    assert(#D.VendorRequirements({ npcID = 5, faction = "Neutral" }, {}) == 0, "no faction map lists no faction")
    assert(#D.VendorRequirements({ npcID = 8 }, {}) == 0, "no faction and no map lists no faction")
end

-------------------------------------------------------------------------------
-- Item status
-------------------------------------------------------------------------------

do
    local HA, store, D = newEnv()
    local calls, lastOptions, pres = 0, nil, nil
    HA.SourceManager = { GetItemPresentation = function(_, itemID, options)
        calls = calls + 1
        lastOptions = options
        return pres[itemID]
    end }
    pres = {
        [1] = { availabilityState = "owned", isOwned = true },
        [2] = { availabilityState = "purchasable" },
        [3] = { availabilityState = "locked", blockerLabels = { "Renown" } },
        [4] = { availabilityState = "owned", isOwned = true, isOwnershipExcluded = true },
    }

    -- Item 1 is stored as owned; the others have readable entries that count 0.
    store.records[1] = { isOwned = true }
    for id = 2, 6 do HA.catalogFixture[id] = { totalNumStored = 0 } end

    store.known = false
    assert(D.ItemStatus(1, 99).state == "unknown", "no persisted data")
    assert(calls == 0, "no presentation read without persisted data")
    store.known = true

    store.excluded[5] = true
    assert(D.ItemStatus(5, 99).state == "unknown" and D.ItemStatus(5, 99).excluded == true, "excluded item")
    assert(calls == 0, "no presentation read for an excluded item")

    assert(D.ItemStatus(1, 99).state == "owned")
    assert(calls == 0, "stored ownership answers without a presentation read")
    local locked = D.ItemStatus(3, 99)
    assert(locked.state == "locked" and locked.labels[1] == "Renown")
    assert(lastOptions.context == "browser" and lastOptions.npcID == 99 and lastOptions.isVendorContext == true)
    assert(D.ItemStatus(2).state == "unlocked" and lastOptions.isVendorContext == false)
    assert(D.ItemStatus(4, 99).state == "unknown", "an owned flag on an excluded presentation stays unknown")
    assert(D.ItemStatus(6, 99).state == "unknown", "no presentation")
end

-------------------------------------------------------------------------------
-- Vendor counts: peek only, prewarm on a miss
-------------------------------------------------------------------------------

do
    local HA, store, D = newEnv()
    local prewarm, stats = {}, nil
    HA.BadgeCalculation = {
        PeekVendorStats = function(_, vendor, filter)
            assert(filter == "all")
            return stats and stats[vendor.npcID]
        end,
        GetVendorStats = function() error("the list must never compute a vendor's stats") end,
        RequestPrewarm = function(_, reason) prewarm[#prewarm + 1] = reason end,
    }
    assert(D.VendorCounts({ npcID = 1 }) == nil and #prewarm == 1, "cold cache asks for a fill")
    stats = { [1] = { collected = 3, total = 7 } }
    local collected, total = D.VendorCounts({ npcID = 1 })
    assert(collected == 3 and total == 7 and #prewarm == 1, "warm cache answers without a request")
    assert(D.VendorCounts({}) == nil and #prewarm == 1, "no npcID, no request")
    store.known = false
    assert(D.VendorCounts({ npcID = 1 }) == nil and #prewarm == 1, "unknown ownership shows no count, even when warm")
    store.known = true
    stats = nil
    assert(D.VendorCounts({ npcID = 1 }, true) == nil and #prewarm == 1, "noPrewarm makes no request")
    assert(D.VendorCounts({ npcID = 1 }) == nil and #prewarm == 2, "the default still asks")
end

-------------------------------------------------------------------------------
-- Catalog read memo
-------------------------------------------------------------------------------

do
    local HA, _, D = newEnv()
    local byItem, byRecord = 0, 0
    local entries = { [1] = { quality = 4 } }
    rawset(_G, "C_HousingCatalog", {
        GetCatalogEntryInfoByItem = function(itemID, tryGet)
            assert(type(itemID) == "number" and tryGet == true)
            byItem = byItem + 1
            return entries[itemID]
        end,
        GetCatalogEntryInfoByRecordID = function(_, decorID)
            byRecord = byRecord + 1
            return decorID == 77 and { quality = 2 } or nil
        end,
    })
    HA.CatalogStore.GetDecorIDFromItemID = function(_, itemID) return itemID == 2 and 77 or nil end

    local memo = {}
    assert(D.CatalogInfo(1, memo).quality == 4 and D.CatalogInfo(1, memo).quality == 4)
    assert(byItem == 1, "a memo hit makes no API call")
    assert(D.CatalogInfo(3, memo) == nil and D.CatalogInfo(3, memo) == nil)
    assert(byItem == 3, "a miss is asked again, so late catalog data still arrives")
    assert(D.CatalogInfo(2, memo).quality == 2 and byRecord == 1, "record-ID fallback")
    D.CatalogInfo(1)
    D.CatalogInfo(1)
    assert(byItem == 6, "without a memo every call reads")
end

-------------------------------------------------------------------------------
-- Progress
-------------------------------------------------------------------------------

do
    local HA, store, D = newEnv()
    HA.VendorData.HasOfferForItem = function(_, id) return id <= 2 end
    HA.VendorIdentity = {}
    HA.SourceManager = { GetAllSources = function() return {} end }
    HA.QuestSources = { [2] = {}, [3] = {} }
    addOwned(HA, store, 1, T0)
    addOwned(HA, store, 2, T0)
    HA.DecorMapping[500003] = 3
    HA.DecorMapping[900001] = 1 -- a second decor record for an item already counted
    local p = D.Progress()
    assert(p.known and p.total == 3 and p.owned == 2)
    assert(p.src.vendors.total == 2 and p.src.vendors.owned == 2)
    assert(p.src.quests.total == 2 and p.src.quests.owned == 1)
    assert(D.Progress() == p, "memoised")
    D.InvalidateMemos()
    assert(D.Progress() ~= p, "invalidation recomputes")
    store.known = false
    assert(D.Progress() == nil, "no totals until the collection is ready")
    store.known = true
    assert(D.Progress().known == true, "a change in what is known recomputes")
end

-------------------------------------------------------------------------------
-- Source summary line and drop waypoints
-------------------------------------------------------------------------------

do
    local HA, _, D = newEnv()
    local function line(src) return D.SourceLine(1, { src }) end
    assert(line({ type = "shop", name = "In-Game Shop" }) == "Shop: In-Game Shop")
    assert(line({ type = "treasure", name = "Chest" }) == "Treasure: Chest")
    assert(line({ type = "structural", name = "X" }) == "Other source: X", "parser types read generically")
    assert(line({ type = "unknown", name = "X" }) == "Other source: X")
    assert(line({ type = "somethingnew", name = "X" }) == "Other source: X", "never the raw key")
    assert(line({ type = "vendor", name = "V", zone = "Z" }) == "Vendor: V, Z")
    assert(D.SourceLine(1, {}) == "Source unknown")

    -- A journal-anchored drop carries an area ID in mapID: no map data.
    HA.DropSources = {
        [1] = { mobName = "Rare", zone = "Z", mapID = 14, coords = { x = 0.4, y = 0.5 } },
        [2] = { mobName = "Boss", zone = "Y", mapID = 7673, coords = { x = 0.4, y = 0.5 }, journalEncounterID = 9 },
        [3] = { mobName = "Dungeon", zone = "W", mapID = 7673, coords = { x = 0.4, y = 0.5 }, journalInstanceID = 8 },
    }
    HA.SourceManager = { GetAllSources = function(_, itemID)
        return { { type = "drop", data = HA.DropSources[itemID] } }
    end }
    local plain, boss = D.ItemSources(1)[1], D.ItemSources(2)[1]
    assert(plain.mapID == 14 and plain.x == 0.4, "a plain drop keeps its map data")
    assert(boss.mapID == nil and boss.x == nil and boss.y == nil, "journal drop source has no map data")
end

-------------------------------------------------------------------------------
-- Near You
-------------------------------------------------------------------------------

do
    local HA, _, D = newEnv()
    rawset(_G, "UnitFactionGroup", function() return "Alliance" end)
    rawset(_G, "CreateVector2D", function(x, y) return { x = x, y = y } end)
    local function world(c, x, y)
        return c, { GetXY = function() return x, y end }
    end
    local continentOf = 1
    local vendorsByMap = {}
    rawset(_G, "Enum", { UIMapType = { Continent = 2, Zone = 3 } })
    rawset(_G, "C_Map", {
        GetBestMapForUnit = function() return 10 end,
        GetMapInfo = function() return { name = "Here", mapType = 3 } end,
        GetMapChildrenInfo = function() return { { mapID = 11 } } end,
        GetPlayerMapPosition = function() return { x = 0, y = 0 } end,
        GetWorldPosFromMapPos = function(_, pos)
            if pos.x == 0 and pos.y == 0 then return world(continentOf, 0, 0) end
            return world(continentOf, pos.x * 100, pos.y * 100)
        end,
    })
    HA.VendorData.GetVendorsInMap = function(_, mapID) return vendorsByMap[mapID] or {} end
    vendorsByMap[10] = {
        { npcID = 1, name = "Far", mapID = 10, x = 0.9, y = 0.9 },
        { npcID = 2, name = "Near", mapID = 10, x = 0.1, y = 0.2 },
        { npcID = 3, name = "Rival", mapID = 10, x = 0.01, y = 0.01, faction = "Horde" },
        { npcID = 4, name = "Gone", mapID = 10, x = 0.02, y = 0.02, removed = true },
    }
    vendorsByMap[11] = {
        { npcID = 5, name = "Child", mapID = 11, x = 0.3, y = 0.3 },
        { npcID = 2, name = "Near", mapID = 11, x = 0.1, y = 0.2 },
    }
    local vendors, mapID, mapName = D.NearYou()
    local order = {}
    for i, v in ipairs(vendors) do order[i] = v.npcID end
    assert(table.concat(order, ",") == "2,5,1", table.concat(order, ","))
    assert(mapID == 10 and mapName == "Here")

    -- Without a usable world position the order falls back to name.
    continentOf = nil
    rawset(_G, "C_Map", setmetatable({
        GetWorldPosFromMapPos = function() return nil end,
    }, { __index = _G.C_Map }))
    vendors = D.NearYou()
    order = {}
    for i, v in ipairs(vendors) do order[i] = v.name end
    assert(table.concat(order, ",") == "Child,Far,Near", table.concat(order, ","))
end

-------------------------------------------------------------------------------
-- Holiday vendors: always available to the holiday list with a season tag, unlisted elsewhere out of season
-------------------------------------------------------------------------------

do
    local HA, _, D = newEnv()
    local running = { ["Lunar Festival"] = true }
    HA.EventSources = {
        [900] = { event = "Lunar Festival", vendorName = "Valadar", zone = "Moonglade" },
        [901] = { event = "Hallow's End", vendorName = "Echo", zone = "Tirisfal" },
        EventVendors = {
            [15864] = { npcID = 15864, name = "Valadar", zone = "Moonglade", event = "Lunar Festival", _isEventVendor = true },
            [273402] = { npcID = 273402, name = "Echo", zone = "Tirisfal", event = "Hallow's End", _isEventVendor = true },
            [273403] = { npcID = 273403, name = "Jack", zone = "Elwynn", event = "Hallow's End", _isEventVendor = true },
        },
    }
    local VD = HA.VendorData
    function VD.IsHolidayVendorHidden(_, npcID)
        local v = HA.EventSources.EventVendors[npcID]
        return v ~= nil and not running[v.event]
    end
    function VD.GetVendorItems() return { 900 } end
    HA.CalendarDetector = { IsHolidayActive = function(_, event) return running[event] == true end }

    local function holiday()
        local t = {}
        for _, v in ipairs(D.HolidayVendors()) do t[#t + 1] = v.name .. (D.HolidayActive(v) and ":Active" or ":Not Active") end
        table.sort(t)
        return table.concat(t, ",")
    end
    assert(holiday() == "Echo:Not Active,Jack:Not Active,Valadar:Active",
        "every holiday vendor is available, each tagged by season: " .. holiday())
    running["Hallow's End"] = true
    assert(holiday() == "Echo:Active,Jack:Active,Valadar:Active", "the tag follows the holiday state: " .. holiday())
    running["Hallow's End"] = false

    -- Every other surface still drops the out-of-season ones.
    assert(D.IsListedVendor(HA.EventSources.EventVendors[273402]) == false, "Near You and the lists share this predicate")
    assert(D.IsListedVendor(HA.EventSources.EventVendors[15864]) == true)

    -- The shop page still opens one.
    function VD.GetVendor() return nil end
    local shop = D.Vendor(273402)
    assert(shop and shop.name == "Echo" and shop.items[1] == 900, "an out-of-season vendor opens on its shop page")
    assert(shop ~= HA.EventSources.EventVendors[273402], "the shop page works on a copy")
    assert(D.HolidayActive(shop) == false and D.HolidayActive({ npcID = 1 }) == nil)
    assert(D.Vendor(404) == nil)

    -- The map pin setting never changes the browser's holiday list.
    local pinsOn = holiday()
    HA.Addon.db.profile.vendorTracer.showEventVendors = false
    assert(holiday() == pinsOn, "event pins off lists the same vendors: " .. holiday())
    HA.EventSources.EventVendors[273403].removed = true
    assert(holiday() == "Echo:Not Active,Valadar:Active", "a removed holiday vendor drops out: " .. holiday())
end

-------------------------------------------------------------------------------
-- Item names that load later
-------------------------------------------------------------------------------

do
    local HA, _, D = newEnv()
    local names, requests = {}, {}
    rawset(_G, "C_Item", {
        GetItemNameByID = function(id) return names[id] end,
        RequestLoadItemDataByID = function(id) requests[#requests + 1] = id end,
    })
    assert(D.ItemName(10) == nil and D.ItemName(10) == nil and D.ItemName(11) == nil)
    assert(table.concat(requests, ",") == "10,11", "each missing name is requested once")

    assert(D.NameArrived(99, true) == false, "an item the browser did not ask for must not refresh")
    names[10] = "Lamp"
    assert(D.NameArrived(10, true) == true, "an awaited item refreshes")
    assert(D.NameArrived(10, true) == false, "an item refreshes once")
    assert(D.ItemName(10) == "Lamp")

    -- A failed load stops waiting and is never asked for again.
    assert(D.NameArrived(11, false) == true)
    assert(D.ItemName(11) == nil)
    assert(D.NameArrived(11, true) == false, "a failed item must not be waited on again")
    assert(#requests == 2, "a failed item must not be requested again")

    -- A vendor's currency line waits for a loading item name, not for one that failed.
    rawset(_G, "C_Item", {
        GetItemNameByID = function(id) return names[id] end,
        RequestLoadItemDataByID = function(id) requests[#requests + 1] = id end,
        GetItemIconByID = function() return nil end,
    })
    HA.SourceManager = { GetVendorItemCost = function(_, itemID)
        return { items = { { id = itemID } } }
    end }
    local out, pending = D.VendorCurrencies({}, { 12 })
    assert(#out == 0 and pending == true, "a currency whose name is loading keeps the line pending")
    D.NameArrived(12, false)
    out, pending = D.VendorCurrencies({}, { 12 })
    assert(#out == 0 and pending == false, "a currency whose name failed must not keep the line pending")
    out, pending = D.VendorCurrencies({}, { 10 })
    assert(out[1] == "Lamp" and pending == false)
end

print("hs534_browser_adapter: ok")
