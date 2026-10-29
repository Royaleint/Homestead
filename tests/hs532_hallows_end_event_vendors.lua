-- luacheck: globals assert loadfile loadstring print io _G

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-- HS-532: Echo, Jack, Cordula Wolfgang and Spew Gutsout sell the Hallow's End
-- decorations, and every holiday vendor (these four and Valadar Starsong) is
-- shown only while its holiday runs. VendorData:IsHolidayVendorHidden is the
-- one gate; this walks every surface that lists vendors in each of three
-- calendar states (running, not running, unknown) with and without saved
-- scans. Loads the REAL Data/VendorIdentity.lua, Data/VendorOffers.lua,
-- Data/VendorData.lua, Data/EndeavorsData.lua, Data/EventSources.lua,
-- Modules/Validation.lua, UI/VendorFilter.lua, UI/MapPinProvider.lua,
-- UI/VendorMapPins.lua and UI/MinimapPinCollect.lua.

local profile = {
    debug = false,
    vendorTracer = {
        showOppositeFaction = true,
        showEventVendors = true,
        showMinimapPins = false,
        minimapCrossZoneMode = "off",
    },
}
local HA = {
    Addon = {
        db = {
            profile = profile,
            global = { discoveredInitiativeThemes = {}, scannedVendors = {} },
        },
        Debug = function() end,
        RegisterModule = function() end,
    },
    Events = { Fire = function() end, RegisterCallback = function() end },
}

-- The endeavor payload the game would return; nil means "unknown".
local initiative = nil
_G.C_NeighborhoodInitiative = {
    GetNeighborhoodInitiativeInfo = function() return initiative end,
}

-- The calendar: nil is unknown, a table lists the holidays that are running.
local calendar = nil
HA.CalendarDetector = {
    IsHolidayActive = function(_, name)
        if not name or calendar == nil then return nil end
        return calendar[name] == true
    end,
}
local CAL_ON = { ["Hallow's End"] = true, ["Lunar Festival"] = true }
local CAL_OFF = {}

assert(loadfile(root .. "/Data/VendorIdentity.lua"))("Homestead", HA)
assert(loadfile(root .. "/Data/VendorOffers.lua"))("Homestead", HA)
assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)
assert(loadfile(root .. "/Data/EndeavorsData.lua"))("Homestead", HA)
assert(loadfile(root .. "/Data/EventSources.lua"))("Homestead", HA)

local VD, ED, ES = HA.VendorData, HA.EndeavorsData, HA.EventSources
VD:BuildOfferIndexes()

local ECHO, JACK, CORDULA, SPEW, VALADAR = 273402, 273403, 273472, 273470, 15864
local JOLLI, HOLLY = 271366, 271604
local TRICKY_TREATS = 33226
local EVENT_NPCS = { ECHO, JACK, CORDULA, SPEW, VALADAR }
local NAMES = { [ECHO] = "Echo", [JACK] = "Jack", [CORDULA] = "Cordula Wolfgang",
    [SPEW] = "Spew Gutsout", [VALADAR] = "Valadar Starsong" }
local MAP_OF = { [ECHO] = 18, [JACK] = 37, [CORDULA] = 2352, [SPEW] = 2351, [VALADAR] = 80 }
local MAPS_LISTED = { 18, 37, 2351, 2352, 80 }

-- Base prices in copper (Jack showed 5% off; his rows carry base), and the Tricky Treats counts.
local GOLD = {
    [282081] = 5000000, [282083] = 5000000, [282086] = 2500000, [282090] = 1000000,
    [282072] = 1000000, [282051] = 1000000, [282077] = 5000000, [282095] = 5000000,
    [282075] = 1000000, [282092] = 5000000, [282100] = 1000000, [282098] = 1000000,
}
local TT = {
    [282192] = 20, [282194] = 20, [282196] = 20, [282198] = 20, [282200] = 20,
    [282202] = 15, [282204] = 25, [282206] = 15, [282208] = 25, [282213] = 25,
    [282289] = 20,
}
local function Set(...)
    local set = {}
    for _, t in ipairs({ ... }) do
        for id in pairs(t) do set[id] = true end
    end
    return set
end
local VALADAR_ITEMS = {}
for _, id in ipairs(ES.EventVendors[VALADAR].items) do VALADAR_ITEMS[id] = true end
local ITEMS_OF = {
    [ECHO] = Set(GOLD, TT), [JACK] = Set(GOLD, TT),
    [CORDULA] = Set(TT), [SPEW] = Set(TT),
    [VALADAR] = VALADAR_ITEMS,
}
local COUNT_OF = { [ECHO] = 23, [JACK] = 23, [CORDULA] = 11, [SPEW] = 11, [VALADAR] = 13 }
local SCAN_ONLY_ITEM = 999001

local function Sorted(set)
    local list = {}
    for id in pairs(set) do list[#list + 1] = id end
    table.sort(list)
    return list
end

-------------------------------------------------------------------------------
-- Endeavor states: the 144 (item, vendor) pairs the endeavor items resolve to
-- are unchanged by the holiday vendors, in every endeavor state and calendar
-- state. Measured on the code before this change. HS-486 changes these
-- deliberately; update the constants there.
-------------------------------------------------------------------------------

local BASE_ITEMS, BASE_PAIRS, BASE_DIGEST = 144, 144, "9884782568737"

local function Digest()
    local items, seen = {}, {}
    local function add(id)
        if id and not seen[id] then seen[id] = true; items[#items + 1] = id end
    end
    for id in pairs(ED.ByItemID) do add(id) end
    for npc in pairs(ED.Vendors) do
        for _, it in ipairs(VD:GetVendorItems(npc)) do add(VD:GetItemID(it)) end
    end
    table.sort(items)
    local pairsCount, digest, listing = 0, 0, {}
    for _, id in ipairs(items) do
        for _, v in ipairs(VD:GetVendorsForItem(id)) do
            pairsCount = pairsCount + 1
            digest = digest + id * v.npcID
            listing[#listing + 1] = id .. ":" .. v.npcID
        end
    end
    table.sort(listing)
    return #items, pairsCount, string.format("%.0f", digest), listing
end

local function CheckDigest(label)
    local nItems, nPairs, digest, listing = Digest()
    if nItems ~= BASE_ITEMS or nPairs ~= BASE_PAIRS or digest ~= BASE_DIGEST then
        print(table.concat(listing, " "))
        assert(false, label .. ": endeavor items must resolve as before, expected "
            .. BASE_ITEMS .. "/" .. BASE_PAIRS .. "/" .. BASE_DIGEST .. ", got "
            .. nItems .. "/" .. nPairs .. "/" .. digest)
    end
end

local CALENDAR_STATES = {
    { name = "holiday on", cal = CAL_ON },
    { name = "holiday off", cal = CAL_OFF },
    { name = "holiday unknown", cal = nil },
}

local function CheckEndeavorState(stateName)
    for _, cs in ipairs(CALENDAR_STATES) do
        calendar = cs.cal
        CheckDigest("endeavor " .. stateName .. ", " .. cs.name)
    end
    calendar = nil
end

-- Unknown first, on the freshly loaded module, before any payload is set.
initiative = nil
ED:RefreshCache()
assert(ED:GetActiveTheme() == nil, "before any payload the active theme must be unknown")
CheckEndeavorState("unknown")

initiative = { isLoaded = true, initiativeID = 9999,
    title = "Some Unrecognized Future Initiative", progressRequired = 500 }
ED:RefreshCache()
CheckEndeavorState("unrecognized")

initiative = { isLoaded = true, initiativeID = 0, title = "", progressRequired = 0 }
ED:RefreshCache()
assert(ED:GetActiveTheme() == nil, "an empty initiative must leave no active theme")
CheckEndeavorState("none")

local themes = {}
for theme in pairs(ED.Endeavors) do themes[#themes + 1] = theme end
table.sort(themes)
for i, theme in ipairs(themes) do
    initiative = { isLoaded = true, initiativeID = 9200 + i, title = "",
        progressRequired = 500, vendorNPCID = ED.Endeavors[theme].vendorNPC }
    ED:RefreshCache()
    assert(ED:GetActiveTheme() == theme,
        "theme " .. theme .. " must resolve from its vendor NPC, got " .. tostring(ED:GetActiveTheme()))
    CheckEndeavorState(theme)
end
for _, npcID in ipairs(EVENT_NPCS) do
    assert(ED.Vendors[npcID] == nil, NAMES[npcID] .. " must not be an endeavor vendor")
    for itemID, sellers in pairs(ED.ByItemID) do
        for _, sellerID in ipairs(sellers) do
            assert(sellerID ~= npcID,
                NAMES[npcID] .. " must not be listed as an endeavor seller of item " .. itemID)
        end
    end
end

-- No endeavor active for the rest: the two Razorwind/Founder's vendors that
-- sit beside the new ones are then shown on their maps.
initiative = { isLoaded = true, initiativeID = 0, title = "", progressRequired = 0 }
ED:RefreshCache()

-------------------------------------------------------------------------------
-- The four vendor rows
-------------------------------------------------------------------------------

local EXPECT_ROWS = {
    [ECHO] = { name = "Echo", mapID = 18, zone = "Tirisfal Glades", subzone = "Ruins of Lordaeron",
        x = 0.6232, y = 0.6674, faction = "Horde" },
    [JACK] = { name = "Jack", mapID = 37, zone = "Elwynn Forest", subzone = "Stormwind Gate",
        x = 0.3197, y = 0.5029, faction = "Alliance" },
    [CORDULA] = { name = "Cordula Wolfgang", mapID = 2352, zone = "Founder's Point",
        x = 0.5431, y = 0.327 },
    [SPEW] = { name = "Spew Gutsout", mapID = 2351, zone = "Razorwind Shores",
        x = 0.5241, y = 0.5441 },
}
for npcID, want in pairs(EXPECT_ROWS) do
    local row = ES.EventVendors[npcID]
    assert(row, want.name .. " must be a holiday vendor")
    for _, field in ipairs({ "name", "mapID", "zone", "subzone", "x", "y", "faction" }) do
        assert(row[field] == want[field], want.name .. "'s " .. field .. " must be "
            .. tostring(want[field]) .. ", got " .. tostring(row[field]))
    end
    assert(row.npcID == npcID and row.event == "Hallow's End" and row._isEventVendor == true
            and row.scanConfirmed == "2026-10-19",
        want.name .. " must carry its npcID, event, event-vendor flag and scan date")
    assert(row.items == nil, want.name .. " must carry no items key (wares are in the offer table)")
    assert(HA.VendorIdentity.Vendors[npcID] == nil and HA.VendorIdentity.Aliases[npcID] == nil,
        want.name .. " must not be an identity vendor or alias")
end
assert(ES.EventVendors[CORDULA].faction == nil and ES.EventVendors[SPEW].faction == nil,
    "Cordula Wolfgang and Spew Gutsout carry no faction field")

local zoneRows = 0
for itemID, row in pairs(ES) do
    if type(itemID) == "number" and row.event == "Hallow's End" then
        zoneRows = zoneRows + 1
        assert(row.vendorName == "Hallow's End Vendor",
            "item " .. itemID .. " must keep its generic vendor name")
        assert(row.zone == "Tirisfal Glades / Elwynn Forest / Founder's Point / Razorwind Shores",
            "item " .. itemID .. " must name all four zones, got " .. tostring(row.zone))
    end
end
assert(zoneRows == 11, "eleven Hallow's End item rows expected, got " .. zoneRows)

local valadar = ES.EventVendors[VALADAR]
assert(valadar.mapID == 80 and valadar.event == "Lunar Festival" and valadar.faction == "Neutral"
        and #valadar.items == 13 and valadar.items[1] == 253244 and valadar.items[13] == 253297,
    "Valadar Starsong and his 13 items must be unchanged")

-------------------------------------------------------------------------------
-- The 68 offers
-------------------------------------------------------------------------------

for _, npcID in ipairs({ ECHO, JACK, CORDULA, SPEW }) do
    local name = NAMES[npcID]
    local wanted = ITEMS_OF[npcID]
    local items = VD:GetItemsForVendor(npcID)
    assert(#items == COUNT_OF[npcID],
        name .. " must list " .. COUNT_OF[npcID] .. " items, got " .. #items)
    local got = {}
    for _, item in ipairs(items) do got[VD:GetItemID(item)] = true end
    for itemID in pairs(wanted) do
        assert(got[itemID], name .. " must sell item " .. itemID)
    end
    for itemID in pairs(got) do
        assert(wanted[itemID], name .. " lists unexpected item " .. itemID)
    end

    local offers = VD:GetOffers(npcID)
    for itemID in pairs(wanted) do
        local offer = offers[itemID]
        assert(offer, name .. " must have an offer for item " .. itemID)
        assert(#(offer.currencies or {}) == 0 and offer.costBuild == nil and offer.isUsable == true,
            name .. "'s item " .. itemID .. " must have no currencies, no costBuild, and be usable")
        if GOLD[itemID] then
            assert(offer.price == GOLD[itemID] and offer.itemCosts == nil,
                name .. "'s item " .. itemID .. " must cost " .. GOLD[itemID] .. " copper only, got "
                .. tostring(offer.price))
        else
            assert(offer.price == 0 and offer.itemCosts and #offer.itemCosts == 1
                    and offer.itemCosts[1].itemID == TRICKY_TREATS
                    and offer.itemCosts[1].amount == TT[itemID],
                name .. "'s item " .. itemID .. " must cost " .. TT[itemID] .. " Tricky Treats only")
        end
    end

    local cost = VD:GetStaticItemCost(ES.EventVendors[npcID], 282192)
    assert(cost and cost.items and cost.items[1] and cost.items[1].id == TRICKY_TREATS
            and cost.items[1].amount == 20,
        name .. "'s static cost for item 282192 must be 20 Tricky Treats")
end
do
    local cost = VD:GetStaticItemCost(ES.EventVendors[JACK], 282081)
    assert(cost and cost.gold == 5000000,
        "Jack's static cost for item 282081 must be the base price 5000000, got "
        .. tostring(cost and cost.gold))
end

-- The offer table's npcID keys have an identity, endeavor, scanned or holiday
-- record, so the data check raises nothing for the four.
assert(loadfile(root .. "/Modules/Validation.lua"))("Homestead", HA)
do
    local errors, warnings = HA.Validation:ValidateVendorOffers()
    for _, text in ipairs(warnings) do
        for _, npcID in ipairs({ ECHO, JACK, CORDULA, SPEW }) do
            assert(not text:find(tostring(npcID), 1, true),
                "offer validation must not warn about " .. NAMES[npcID] .. ": " .. text)
        end
    end
    for _, text in ipairs(errors) do
        for _, npcID in ipairs({ ECHO, JACK, CORDULA, SPEW }) do
            assert(not text:find(tostring(npcID), 1, true),
                "offer validation must not fail on " .. NAMES[npcID] .. ": " .. text)
        end
    end
end

-------------------------------------------------------------------------------
-- Surfaces: maps for the code under test, the world-map collector, the minimap
-- collector.
-------------------------------------------------------------------------------

local playerMapID, playerPos
local MAPINFO = {
    [18] = "Tirisfal Glades", [37] = "Elwynn Forest", [80] = "Moonglade",
    [2351] = "Razorwind Shores", [2352] = "Founder's Point",
}
_G.C_Map = {
    GetBestMapForUnit = function() return playerMapID end,
    GetPlayerMapPosition = function() return playerPos end,
    GetMapInfo = function(mapID)
        local name = MAPINFO[mapID]
        if not name then return nil end
        return { name = name, parentMapID = 0, mapType = 3 }
    end,
    GetMapChildrenInfo = function() return {} end,
    GetWorldPosFromMapPos = function(_, pos)
        return 1, { GetXY = function() return pos.x * 1000, pos.y * 1000 end }
    end,
}
_G.CreateVector2D = function(x, y) return { x = x, y = y } end
_G.time = function() return 2000000000 end
_G.GetBuildInfo = function() return "12.0.0", "1", "Jan 1 2026", 120000 end
_G.CreateFrame = function()
    return setmetatable({}, { __index = function() return function() end end })
end
_G.InCombatLockdown = function() return false end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.GetTimePreciseSec = function() return 0 end
_G.C_Timer = {
    NewTicker = function() return { Cancel = function() end } end,
    NewTimer = function() return { Cancel = function() end } end,
    After = function() end,
}
_G.Enum = { UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 } }
_G.IsIndoors = function() return false end

local playerFaction = "Horde"
_G.UnitFactionGroup = function() return playerFaction end

assert(loadfile(root .. "/Core/constants.lua"))("Homestead", HA)
assert(loadfile(root .. "/UI/VendorFilter.lua"))("Homestead", HA)
local VF = HA.VendorFilter
VF.ShouldHideCompletedVendorPin = function() return false end

HA.PerformanceTrace = { Measure = function(_, _label, _tag, pcallFn, fn) return pcallFn(fn) end }
HA.BadgeCalculation = {}
assert(loadfile(root .. "/UI/MapPinProvider.lua"))("Homestead", HA)
assert(loadfile(root .. "/UI/VendorMapPins.lua"))("Homestead", HA)
local VMP = HA.VendorMapPins
VMP:Initialize()
local collect = VMP.pinSourceProviders.vendor.collect

local function WorldMapPins(viewMapID)
    local state = { vendorPins = {} }
    collect(VMP, viewMapID, { [viewMapID] = true }, "all", state)
    local counts = {}
    for _, record in ipairs(state.vendorPins) do
        local npcID = record.vendor.npcID
        counts[npcID] = (counts[npcID] or 0) + 1
    end
    return counts
end

local collected
local minimapHA = {
    Constants = HA.Constants,
    Addon = HA.Addon,
    VendorData = VD,
    VendorFilter = VF,
    PerformanceTrace = { Measure = function(_, _label, _tag, fn) return fn() end },
    HomesteadMinimapOverlay = {
        ShouldHideMinimapPins = function() return false end,
        SetPins = function(_, pins) collected = pins end,
    },
    MapPinProvider = {
        GetContinentForZone = function() return nil end,
        minimapExcludedContinents = {},
        continentToZones = {},
        AssignOverlapNudge = function() end,
        GetNativeWorldCoordinates = function(mapID_, px, py)
            return py * 1000, px * 1000, 1, mapID_
        end,
    },
    VendorMapPins = {
        IsInitialized = function() return true end,
        IsMinimapPinsEnabled = function() return true end,
        IsMapFilterSourceEnabled = function() return true end,
        ClearMinimapPins = function() end,
        IsMinimapWarmupActive = function() return false end,
        CanAccessVendor = function() return true end,
        IsOppositeFaction = function() return false end,
    },
}
assert(loadfile(root .. "/UI/MinimapPinCollect.lua"))("Homestead", minimapHA)

local function MinimapPins(mapID, npcID)
    local row = ES.EventVendors[npcID]
    playerMapID, playerPos = mapID, { x = row.x, y = row.y }
    collected = nil
    minimapHA.MinimapPinCollect:RefreshMinimapPins()
    local n = 0
    for _, pin in ipairs(collected or {}) do
        if pin.vendor.npcID == npcID then n = n + 1 end
    end
    return n
end

-- Saved scans: each holiday vendor where it stands, with its wares; Echo also
-- carries an item no offer table has.
local function SetScans(on)
    local scans = {}
    if on then
        for _, npcID in ipairs(EVENT_NPCS) do
            local row = ES.EventVendors[npcID]
            local items = {}
            for _, itemID in ipairs(Sorted(ITEMS_OF[npcID])) do
                items[#items + 1] = { itemID = itemID, price = 10000 }
            end
            if npcID == ECHO then items[#items + 1] = { itemID = SCAN_ONLY_ITEM, price = 10000 } end
            scans[npcID] = { name = row.name, mapID = row.mapID,
                coords = { x = row.x, y = row.y }, items = items }
        end
    end
    HA.Addon.db.global.scannedVendors = scans
    VD:BuildScannedIndex()
end

local function Count(list, npcID)
    local n = 0
    for _, vendor in ipairs(list) do
        if vendor.npcID == npcID then n = n + 1 end
    end
    return n
end

local function ExpectPresence(label, list, npcID, shouldBePresent)
    local n = Count(list, npcID)
    assert(n == (shouldBePresent and 1 or 0), label .. ": " .. NAMES[npcID] .. " must be listed "
        .. (shouldBePresent and "once" or "never") .. ", got " .. n)
end

local ALL_ITEMS = Set(GOLD, TT, VALADAR_ITEMS, { [SCAN_ONLY_ITEM] = true })

local function RunMatrix(label, visible, scans)
    -- Single-vendor lookups and the gate itself.
    for _, npcID in ipairs(EVENT_NPCS) do
        assert(VD:IsHolidayVendorHidden(npcID) == not visible,
            label .. ": " .. NAMES[npcID] .. " hidden flag must be " .. tostring(not visible))
        local vendor = VD:GetVendor(npcID)
        if visible then
            assert(vendor and vendor.npcID == npcID and vendor.name == NAMES[npcID],
                label .. ": GetVendor must return " .. NAMES[npcID])
        else
            assert(vendor == nil, label .. ": GetVendor must return nothing for " .. NAMES[npcID])
        end
        assert(VD:HasVendor(npcID) == false,
            label .. ": HasVendor must stay false for " .. NAMES[npcID])
    end
    assert(VD:IsHolidayVendorHidden(nil) == false and VD:IsHolidayVendorHidden(999999999) == false
            and VD:IsHolidayVendorHidden(JOLLI) == false and VD:IsHolidayVendorHidden(260485) == false,
        label .. ": only holiday vendors are ever hidden by the gate")

    -- Vendors on a map.
    for _, mapID in ipairs(MAPS_LISTED) do
        local list = VD:GetVendorsInMap(mapID)
        local seen = {}
        for _, vendor in ipairs(list) do
            assert(not seen[vendor.npcID],
                label .. ": npc " .. tostring(vendor.npcID) .. " is listed twice on map " .. mapID)
            seen[vendor.npcID] = true
        end
        for _, npcID in ipairs(EVENT_NPCS) do
            ExpectPresence(label .. " map " .. mapID, list, npcID, visible and MAP_OF[npcID] == mapID)
        end
    end

    -- Vendors for an item.
    for _, itemID in ipairs(Sorted(ALL_ITEMS)) do
        local list = VD:GetVendorsForItem(itemID)
        local seen = {}
        for _, vendor in ipairs(list) do
            assert(not seen[vendor.npcID],
                label .. ": npc " .. tostring(vendor.npcID) .. " is listed twice for item " .. itemID)
            seen[vendor.npcID] = true
        end
        for _, npcID in ipairs(EVENT_NPCS) do
            local sells = ITEMS_OF[npcID][itemID] or (scans and npcID == ECHO and itemID == SCAN_ONLY_ITEM)
            ExpectPresence(label .. " item " .. itemID, list, npcID, visible and sells == true)
        end
        if GOLD[itemID] then
            assert(seen[JOLLI] and seen[HOLLY],
                label .. ": Jolli and Holly must always sell gold item " .. itemID)
        end
    end

    -- Closest vendor, standing at each holiday vendor's spot.
    for _, npcID in ipairs(EVENT_NPCS) do
        local row = ES.EventVendors[npcID]
        playerMapID, playerPos = row.mapID, { x = row.x, y = row.y }
        for _, itemID in ipairs(Sorted(ITEMS_OF[npcID])) do
            local closest = VD:GetClosestVendorForItem(itemID)
            if visible then
                assert(closest and closest.npcID == npcID, label .. ": at " .. NAMES[npcID]
                    .. " the closest seller of item " .. itemID .. " must be " .. NAMES[npcID])
            elseif GOLD[itemID] then
                assert(closest and (closest.npcID == JOLLI or closest.npcID == HOLLY),
                    label .. ": item " .. itemID .. " must fall back to Jolli or Holly")
            else
                assert(closest == nil, label .. ": item " .. itemID .. " must have no seller, got "
                    .. tostring(closest and closest.npcID))
            end
        end
    end
    playerMapID, playerPos = nil, nil

    -- Search.
    for _, query in ipairs({ { "Echo", ECHO }, { "Jack", JACK }, { "Cordula", CORDULA },
            { "Spew", SPEW } }) do
        ExpectPresence(label .. " search " .. query[1], VD:SearchVendors(query[1]), query[2], visible)
    end
    local hallow = VD:SearchVendors("Hallow")
    for _, npcID in ipairs({ ECHO, JACK, CORDULA, SPEW }) do
        ExpectPresence(label .. " search Hallow", hallow, npcID, visible)
    end
    ExpectPresence(label .. " search Hallow", hallow, VALADAR, false)
    ExpectPresence(label .. " search Lunar", VD:SearchVendors("Lunar"), VALADAR, visible)

    -- Every vendor: once, and a copy.
    local all = VD:GetAllVendors()
    local seenAll = {}
    for _, vendor in ipairs(all) do
        if vendor.npcID then
            assert(not seenAll[vendor.npcID],
                label .. ": npc " .. vendor.npcID .. " is listed twice in GetAllVendors")
            seenAll[vendor.npcID] = true
        end
    end
    for _, npcID in ipairs(EVENT_NPCS) do
        ExpectPresence(label .. " all vendors", all, npcID, visible)
        for _, vendor in ipairs(all) do
            if vendor.npcID == npcID then
                assert(vendor ~= ES.EventVendors[npcID],
                    label .. ": GetAllVendors must hand out a copy of " .. NAMES[npcID])
            end
        end
    end

    -- The world map and the minimap, as a Horde player who sees both factions.
    playerFaction = "Horde"
    profile.vendorTracer.showOppositeFaction = true
    for _, mapID in ipairs(MAPS_LISTED) do
        local pins = WorldMapPins(mapID)
        for _, npcID in ipairs(EVENT_NPCS) do
            local want = (visible and MAP_OF[npcID] == mapID) and 1 or 0
            assert((pins[npcID] or 0) == want, label .. ": world map " .. mapID .. " must have "
                .. want .. " pin(s) for " .. NAMES[npcID] .. ", got " .. (pins[npcID] or 0))
        end
    end
    for _, npcID in ipairs({ ECHO, JACK, CORDULA, SPEW }) do
        local n = MinimapPins(MAP_OF[npcID], npcID)
        assert(n == (visible and 1 or 0), label .. ": minimap on map " .. MAP_OF[npcID]
            .. " must have " .. (visible and 1 or 0) .. " pin(s) for " .. NAMES[npcID] .. ", got " .. n)
    end
end

-------------------------------------------------------------------------------
-- Settings and factions on the world map (holiday on, scans saved), then the
-- full matrix
-------------------------------------------------------------------------------

SetScans(true)
calendar = CAL_ON

-- An Alliance player who hides opposite-faction vendors: no Echo (Horde) on
-- Tirisfal Glades, still Jack (Alliance) in Elwynn Forest.
playerFaction = "Alliance"
profile.vendorTracer.showOppositeFaction = false
assert((WorldMapPins(18)[ECHO] or 0) == 0,
    "Alliance, show-opposite off, holiday on with scans: map 18 must have no Echo pin")
assert((WorldMapPins(37)[JACK] or 0) == 1,
    "Alliance, show-opposite off, holiday on with scans: map 37 must still have Jack's pin")
assert((WorldMapPins(2351)[SPEW] or 0) == 0 and (WorldMapPins(2352)[CORDULA] or 0) == 1,
    "Alliance, show-opposite off: Razorwind Shores hides Spew Gutsout, Founder's Point shows Cordula Wolfgang")
playerFaction = "Horde"
profile.vendorTracer.showOppositeFaction = true

-- Event vendors switched off: none of the four pins, Jolli and Holly stay.
profile.vendorTracer.showEventVendors = false
for _, mapID in ipairs({ 18, 37, 2351, 2352 }) do
    local pins = WorldMapPins(mapID)
    for _, npcID in ipairs({ ECHO, JACK, CORDULA, SPEW }) do
        assert((pins[npcID] or 0) == 0,
            "event vendors off: map " .. mapID .. " must have no pin for " .. NAMES[npcID])
    end
end
assert((WorldMapPins(2351)[JOLLI] or 0) == 1 and (WorldMapPins(2352)[HOLLY] or 0) == 1,
    "event vendors off: Jolli and Holly must stay pinned")
profile.vendorTracer.showEventVendors = true

local ALL_STATES = {
    { "holiday on", CAL_ON, true },
    { "holiday off", CAL_OFF, false },
    { "holiday unknown", nil, false },
}
for _, scans in ipairs({ false, true }) do
    SetScans(scans)
    for _, state in ipairs(ALL_STATES) do
        calendar = state[2]
        RunMatrix(state[1] .. (scans and ", with scans" or ", no scans"), state[3], scans)
    end
end
-- A saved scan with the holiday not running shows no pin and lists nothing.
SetScans(true)
calendar = CAL_OFF
for _, npcID in ipairs({ ECHO, JACK, CORDULA, SPEW }) do
    assert((WorldMapPins(MAP_OF[npcID])[npcID] or 0) == 0,
        "holiday off with scans: no pin for " .. NAMES[npcID])
end

print("hs532_hallows_end_event_vendors: ok")
