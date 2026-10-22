-- luacheck: globals assert loadfile print

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Decor browser data adapter (UI/Browser/Adapter.lua): Recently Acquired,
-- the vendor-list predicate, hide-owned rules, item status, vendor counts,
-- the catalog memo, progress and Near You. The real Style, VendorFilter, enUS
-- and Adapter files run against stubbed Homestead modules and WoW globals.
-------------------------------------------------------------------------------

local NOW = 1800000000
local T0 = 1700000000
rawset(_G, "time", function() return NOW end)
rawset(_G, "GetBuildInfo", function() return "12.0.1", "1", "1", 120001 end)

local function newEnv()
    local HA = { DecorMapping = {} }
    local store = { records = {}, known = true, excluded = {}, getCalls = 0 }
    function store:HasPersistedData() return self.known end
    function store:IsOwned(id)
        local r = self.records[id]
        return r ~= nil and r.isOwned == true
    end
    function store:IsOwnershipUnknowable(id) return self.excluded[id] == true end
    function store:Get(id)
        self.getCalls = self.getCalls + 1
        return self.records[id]
    end
    HA.CatalogStore = store
    HA.Addon = { db = {
        global = { noDecorVendors = {}, scannedVendors = {} },
        profile = { vendorTracer = { showEventVendors = true } },
    } }
    HA.Constants = { ZoneToFactionMap = {}, TEXTURE_ROOT = "Textures/" }
    HA.VendorData = { HasVendor = function() return false end }
    for _, file in ipairs({ "Locale/enUS.lua", "UI/Browser/Style.lua", "UI/VendorFilter.lua", "UI/Browser/Adapter.lua" }) do
        assert(loadfile(root .. "/" .. file))("Homestead", HA)
    end
    return HA, store, HA.DecorBrowser.Data
end

local function addOwned(HA, store, itemID, firstSeen)
    store.records[itemID] = { isOwned = true, firstSeen = firstSeen }
    HA.DecorMapping[itemID + 500000] = itemID
end

local function ids(list)
    local t = {}
    for i, r in ipairs(list) do t[i] = r.itemID end
    return table.concat(t, ",")
end

-------------------------------------------------------------------------------
-- Recently Acquired (fixtures for the baseline rule)
-------------------------------------------------------------------------------

do
    -- First scan only: every record lands within seconds of the earliest.
    local HA, store, D = newEnv()
    for i = 1, 100 do addOwned(HA, store, i, T0 + (i % 6)) end
    assert(#D.RecentlyAcquired(3) == 0, "first scan alone must show nothing")

    -- First scan plus three later purchases.
    for i = 1, 3 do addOwned(HA, store, 200 + i, T0 + 3600 * i) end
    D.InvalidateMemos()
    assert(ids(D.RecentlyAcquired(3)) == "203,202,201", ids(D.RecentlyAcquired(3)))
    assert(ids(D.RecentlyAcquired(2)) == "203,202")
    assert(ids(D.RecentlyAcquired(10)) == "203,202,201", "never more than exist")
end

do
    -- Clear-cache re-stamp: the next scan stamps every record at one time.
    local HA, store, D = newEnv()
    for i = 1, 103 do addOwned(HA, store, i, T0 + 86400 + (i % 4)) end
    assert(#D.RecentlyAcquired(3) == 0, "a re-stamp must read as baseline")
end

do
    -- Partial first scan, then a bulk rescan well after it.
    local HA, store, D = newEnv()
    for i = 1, 10 do addOwned(HA, store, i, T0) end
    for i = 1, 60 do addOwned(HA, store, 100 + i, T0 + 600 + (i % 10)) end
    assert(#D.RecentlyAcquired(3) == 0, "a bulk rescan must read as baseline")
    addOwned(HA, store, 900, T0 + 5000)
    addOwned(HA, store, 901, T0 + 5100)
    D.InvalidateMemos()
    assert(ids(D.RecentlyAcquired(5)) == "901,900", ids(D.RecentlyAcquired(5)))
end

do
    -- No owned records, and records that are not owned.
    local HA, store, D = newEnv()
    assert(#D.RecentlyAcquired(3) == 0)
    store.records[5] = { isOwned = false, firstSeen = T0 + 9999 }
    HA.DecorMapping[500005] = 5
    D.InvalidateMemos()
    assert(#D.RecentlyAcquired(3) == 0, "unowned records never qualify")

    -- Ownership not yet known: empty, and not remembered once it is.
    addOwned(HA, store, 1, T0)
    addOwned(HA, store, 2, T0 + 5000)
    store.known = false
    D.InvalidateMemos()
    assert(#D.RecentlyAcquired(3) == 0)
    store.known = true
    assert(ids(D.RecentlyAcquired(3)) == "2", "knowing ownership later must not read a stale empty set")
end

do
    -- K edge: 49 records in a crowd stay, 50 are baseline.
    for _, case in ipairs({ { 49, 49 }, { 50, 0 } }) do
        local HA, store, D = newEnv()
        for i = 1, 10 do addOwned(HA, store, i, T0 + (i % 3)) end
        for i = 1, case[1] do addOwned(HA, store, 100 + i, T0 + 1000 + (i % 20)) end
        HA.DecorMapping[900001] = 101 -- a second decor record for the same item must not count twice
        assert(#D.RecentlyAcquired(100) == case[2],
            "crowd of " .. case[1] .. " expected " .. case[2] .. ", got " .. #D.RecentlyAcquired(100))
    end

    -- W edge: exactly W after the earliest is baseline, one second later is not.
    local HA, store, D = newEnv()
    addOwned(HA, store, 1, T0)
    addOwned(HA, store, 2, T0 + 30)
    addOwned(HA, store, 3, T0 + 31)
    assert(ids(D.RecentlyAcquired(5)) == "3", ids(D.RecentlyAcquired(5)))

    -- Ties on firstSeen fall to the higher itemID first.
    addOwned(HA, store, 10, T0 + 4000)
    addOwned(HA, store, 11, T0 + 4000)
    D.InvalidateMemos()
    assert(ids(D.RecentlyAcquired(5)) == "11,10,3", ids(D.RecentlyAcquired(5)))
end

do
    -- Memo: one walk until invalidated; IsNew reads the same set.
    local HA, store, D = newEnv()
    addOwned(HA, store, 1, T0)
    addOwned(HA, store, 2, NOW - 3600)
    addOwned(HA, store, 3, NOW - 8 * 86400)
    D.RecentlyAcquired(3)
    local calls = store.getCalls
    D.RecentlyAcquired(3)
    assert(D.IsNew(2) == true, "within the new window")
    assert(D.IsNew(3) == false, "outside the new window")
    assert(D.IsNew(1) == false, "baseline is never new")
    assert(store.getCalls == calls, "memoised reads must not walk again")
    addOwned(HA, store, 4, NOW - 60)
    D.InvalidateMemos()
    assert(D.IsNew(4) == true)
    assert(store.getCalls > calls, "invalidation must force a new walk")
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

    local event = { npcID = 5, _isEventVendor = true }
    assert(D.IsListedVendor(event) == true)
    HA.Addon.db.global.noDecorVendors[5] = { scanConfidence = "confirmed" }
    assert(D.IsListedVendor(event) == true, "event vendors skip the no-decor check")
    HA.Addon.db.profile.vendorTracer.showEventVendors = false
    assert(D.IsListedVendor(event) == false, "event setting off")
    assert(D.IsListedVendor({ npcID = 5, removed = true, _isEventVendor = true }) == false, "removed beats event")
    HA.Addon.db.profile.vendorTracer.showEventVendors = true

    -- The holiday predicate is feature-detected: absent first, then stubbed.
    assert(HA.VendorData.IsHolidayVendorHidden == nil)
    assert(D.IsListedVendor({ npcID = 6 }) == true, "absent holiday function lists the vendor")
    local asked
    HA.VendorData.IsHolidayVendorHidden = function(self, npcID)
        assert(self == HA.VendorData, "called as a method")
        asked = npcID
        return npcID == 6
    end
    assert(D.IsListedVendor({ npcID = 6 }) == false and asked == 6, "holiday hidden")
    assert(D.IsListedVendor({ npcID = 7 }) == true and asked == 7, "holiday not hidden")

    -- Inactive Endeavor vendors drop out; vendors without the flag never ask.
    local activeCalls = 0
    HA.EndeavorsData = { IsVendorActive = function(_, vendor)
        activeCalls = activeCalls + 1
        return vendor.npcID ~= 8
    end }
    assert(D.IsListedVendor({ npcID = 8, endeavor = true }) == false, "inactive Endeavor")
    assert(D.IsListedVendor({ npcID = 9, endeavor = true }) == true, "active Endeavor")
    local before = activeCalls
    assert(D.IsListedVendor({ npcID = 8 }) == true)
    assert(activeCalls == before, "only Endeavor vendors consult the Endeavor state")

    -- VendorsByExpansion applies the same predicate.
    HA.VendorData.GetVendorsByExpansion = function()
        return { { npcID = 20 }, { npcID = 21, removed = true }, { npcID = 8, endeavor = true }, { npcID = 22 } }
    end
    local listed = D.VendorsByExpansion("Midnight")
    assert(#listed == 2 and listed[1].npcID == 20 and listed[2].npcID == 22)
end

-------------------------------------------------------------------------------
-- Expansion list
-------------------------------------------------------------------------------

do
    local HA, _, D = newEnv()
    HA.VendorIdentity = { GetAllVendors = function()
        return {
            { npcID = 1, expansion = "Classic" }, { npcID = 2, expansion = "Midnight" },
            { npcID = 3, expansion = "Events" }, { npcID = 4, expansion = "Zeta" },
            { npcID = 5, expansion = "Alpha" }, { npcID = 6 },
        }
    end }
    HA.EndeavorsData = { Vendors = { [7] = { npcID = 7, expansion = "The War Within" } } }
    local list = D.Expansions()
    assert(table.concat(list, "|") == "Midnight|The War Within|Classic|Alpha|Zeta|Events", table.concat(list, "|"))
    assert(D.Expansions() == list, "memoised for the session")
    assert(D.ExpansionLabel("Events") == "Other Vendors")
    assert(D.ExpansionLabel("Midnight") == "Midnight")
    assert(D.ExpansionLabel("Alpha") == "Alpha", "unknown keys display as themselves")
end

-------------------------------------------------------------------------------
-- Hide owned, and the owned == total > 0 rule
-------------------------------------------------------------------------------

do
    local HA, store, D = newEnv()
    addOwned(HA, store, 1, T0)
    assert(D.HidesOwnedItem(1) == true)
    assert(D.HidesOwnedItem(2) == false)
    assert(D.HidesOwnedVendor(3, 3) == true)
    assert(D.HidesOwnedVendor(0, 0) == false, "no knowable wares is never hidden")
    assert(D.HidesOwnedVendor(3, 4) == false)
    assert(D.HidesOwnedVendor(nil, nil) == false, "a cold count cache never hides a vendor")
    assert(D.HidesOwnedVendor(3, nil) == false)

    store.known = false
    assert(D.HidesOwnedItem(1) == false, "unknown ownership removes nothing")
    assert(D.HidesOwnedVendor(3, 3) == false, "unknown ownership removes no vendor")

    -- Source rows follow the same rule.
    HA.DropSources = { [1] = { mobName = "Alpha" }, [2] = { mobName = "Beta" } }
    rawset(_G, "C_Item", { GetItemNameByID = function(id) return "Item" .. id end })
    local shownUnknown = D.SourceList("drops", "", true)
    assert(#shownUnknown == 2, "unknown ownership keeps owned rows")
    store.known = true
    local rows = D.SourceList("drops", "", true)
    assert(#rows == 1 and rows[1].itemID == 2, "known ownership removes the owned row")
    local searched = D.SourceList("drops", "ALPHA", false)
    assert(#searched == 1, "search is case-insensitive over names")
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

    store.known = false
    assert(D.ItemStatus(1, 99).state == "unknown", "no persisted data")
    assert(calls == 0, "no presentation read without persisted data")
    store.known = true

    store.excluded[5] = true
    assert(D.ItemStatus(5, 99).state == "unknown" and D.ItemStatus(5, 99).excluded == true, "excluded item")
    assert(calls == 0, "no presentation read for an excluded item")

    assert(D.ItemStatus(1, 99).state == "owned")
    assert(lastOptions.context == "browser" and lastOptions.npcID == 99 and lastOptions.isVendorContext == true)
    assert(D.ItemStatus(2).state == "unlocked" and lastOptions.isVendorContext == false)
    local locked = D.ItemStatus(3, 99)
    assert(locked.state == "locked" and locked.labels[1] == "Renown")
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
    HA.SourceManager = {}
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
    local unknown = D.Progress()
    assert(unknown.known == false and unknown.owned == 0 and unknown.total == 3, "no owned fraction while unknown")
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

    -- A journal-anchored drop carries an area ID in mapID: no waypoint, no map data.
    HA.DropSources = {
        [1] = { mobName = "Rare", zone = "Z", mapID = 14, coords = { x = 0.4, y = 0.5 } },
        [2] = { mobName = "Boss", zone = "Y", mapID = 7673, coords = { x = 0.4, y = 0.5 }, journalEncounterID = 9 },
        [3] = { mobName = "Dungeon", zone = "W", mapID = 7673, coords = { x = 0.4, y = 0.5 }, journalInstanceID = 8 },
    }
    rawset(_G, "C_Item", { GetItemNameByID = function(id) return "Item" .. id end })
    local rows = D.SourceList("drops", "", false)
    local byItem = {}
    for _, r in ipairs(rows) do byItem[r.itemID or 0] = r end
    assert(byItem[1].wp and byItem[1].wp.mapID == 14, "a plain drop keeps its waypoint")
    assert(byItem[2].wp == nil and byItem[3].wp == nil, "journal drops get no waypoint")

    HA.SourceManager = { GetAllSources = function(_, itemID)
        return { { type = "drop", data = HA.DropSources[itemID] } }
    end }
    local plain, boss = D.ItemSources(1)[1], D.ItemSources(2)[1]
    assert(plain.mapID == 14 and plain.x == 0.4)
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
    rawset(_G, "C_Map", {
        GetBestMapForUnit = function() return 10 end,
        GetMapInfo = function() return { name = "Here" } end,
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
-- Holiday vendors: listed on Events in or out of season, hidden everywhere else
-------------------------------------------------------------------------------

do
    local HA, _, D = newEnv()
    rawset(_G, "C_Item", { GetItemNameByID = function(id) return "Item" .. id end })
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
    function VD.GetVendorsByExpansion()
        return { { npcID = 1, name = "Plain" }, HA.EventSources.EventVendors[15864], HA.EventSources.EventVendors[273402] }
    end

    local function layout(search, hide)
        local rows = D.SourceList("events", search or "", hide or false)
        local t = {}
        for _, r in ipairs(rows) do
            t[#t + 1] = r.kind == "header" and ("[" .. r.text .. "]")
                or r.kind == "vendor" and (r.vendor.name .. (r.active and ":Active" or ":Not Active"))
                or ("item" .. r.itemID)
        end
        return table.concat(t, ",")
    end
    assert(layout() == "[Hallow's End],Echo:Not Active,Jack:Not Active,item901,[Lunar Festival],Valadar:Active,item900",
        "vendors sort ahead of their holiday's items, each tagged by season: " .. layout())
    running["Hallow's End"] = true
    assert(layout():find("Echo:Active,Jack:Active", 1, true), "the tag follows the holiday state on the next build")
    running["Hallow's End"] = false
    assert(layout("jack") == "[Hallow's End],Jack:Not Active", "search filters the holiday vendors: " .. layout("jack"))

    assert(D.SourceList("drops", "", false) ~= nil and not layout():find("drops"), "other sources never gain vendor rows")

    -- Every other surface still drops the out-of-season ones.
    local names = {}
    for _, v in ipairs(D.VendorsByExpansion("Midnight")) do names[#names + 1] = v.name end
    assert(table.concat(names, ",") == "Plain,Valadar", "Vendors lists only vendors in season: " .. table.concat(names, ","))
    assert(D.IsListedVendor(HA.EventSources.EventVendors[273402]) == false, "Near You and the lists share this predicate")
    assert(D.IsListedVendor(HA.EventSources.EventVendors[15864]) == true)

    -- The shop page still opens one.
    function VD.GetVendor() return nil end
    local shop = D.Vendor(273402)
    assert(shop and shop.name == "Echo" and shop.items[1] == 900, "an out-of-season vendor opens on its shop page")
    assert(shop ~= HA.EventSources.EventVendors[273402], "the shop page works on a copy")
    assert(D.HolidayActive(shop) == false and D.HolidayActive({ npcID = 1 }) == nil)
    assert(D.Vendor(404) == nil)

    -- The pin setting still hides event vendors.
    HA.Addon.db.profile.vendorTracer.showEventVendors = false
    assert(layout() == "[Hallow's End],item901,[Lunar Festival],item900", "event vendors off: " .. layout())
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
