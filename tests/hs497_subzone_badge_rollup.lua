-- luacheck: globals assert loadfile print C_Timer C_Map Enum CreateFrame InCombatLockdown GetTimePreciseSec wipe rawequal io loadstring setfenv

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-497: a vendor recorded on a sub-zone or dungeon map is counted under the
-- zone map directly below its continent (BadgeCalculation.GetBadgeZoneMapID),
-- so a continent map shows one badge per zone. Loads the REAL Constants
-- (ZoneToContinentMap, VerticalSiblings), the REAL MapPinProvider (for
-- GetParentMapID and the continent index) and the REAL BadgeCalculation, with
-- C_Map.GetMapInfo and GetMapChildrenInfo serving the parent chains below.
-------------------------------------------------------------------------------

CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript() end
    return frame
end
InCombatLockdown = function() return false end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
GetTimePreciseSec = function() return 0 end
C_Timer = {
    NewTicker = function() return { Cancel = function() end } end,
    NewTimer = function() return { Cancel = function() end } end,
    After = function() end,
}

-- mapID -> { name, parent, mapType }. parent 0 / nil = no parent; mapType
-- defaults to Zone. Parents and map types of the real maps match the game
-- client; 9001-9005 are synthetic edge cases.
local WORLD, CONTINENT, ZONE, DUNGEON, MICRO = 1, 2, 3, 4, 5
Enum = { UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 } }
local MAPS = {
    [13] = { "Eastern Kingdoms", 947, CONTINENT },
    [619] = { "Broken Isles", 947, CONTINENT },
    [905] = { "Argus", 946, CONTINENT },
    [830] = { "Krokuun", 905 },
    [709] = { "Suramar", 619 },
    [17] = { "Blasted Lands", 13 },
    [2537] = { "Quel'Thalas", 13, CONTINENT },
    [2405] = { "Voidstorm", 2537 },
    [2444] = { "Slayer's Rise", 2405 },
    [2599] = { "Umbral Base Camp", 2405 },
    [2413] = { "Harandar", 2537 },
    [2576] = { "The Den", 2413, MICRO },
    [2512] = { "The Coiled Isle", 2537 },
    [2509] = { "Vaults of Atal'Utek", 2512 },
    -- Vertical siblings
    [627] = { "Dalaran", 619, DUNGEON },
    [628] = { "Dalaran Underbelly", 619, DUNGEON },
    [947] = { "Azeroth", 946, WORLD },
    [2274] = { "Khaz Algar", 947, CONTINENT },
    [2255] = { "Azj-Kahet", 2274 },
    [2213] = { "City of Threads", 2255 },
    [2216] = { "City of Threads - Lower", 2255 },
    -- Tazavesh: the ancestor under the continent (K'aresh) is not in ZoneToContinentMap
    [2371] = { "K'aresh", 2274 },
    [2472] = { "Tazavesh", 2371 },
    -- Undermine: zone and dungeon map both hang off The Ringing Deeps
    [2214] = { "The Ringing Deeps", 2274 },
    [2346] = { "Undermine", 2214 },
    [2406] = { "Liberation of Undermine", 2214, DUNGEON },
    -- Silvermoon City sits on Eversong Woods, which is directly under the continent
    [2395] = { "Eversong Woods", 2537 },
    [2393] = { "Silvermoon City", 2395 },
    -- Chain never reaches the continent (ends at a map with no parent)
    [9001] = { "Orphan Annex", 9002 },
    [9002] = { "Orphan Hall", 0 },
    -- Map with no parent data at all
    [9003] = { "Lone Map", nil },
    -- Chain loops; the walk must stop
    [9004] = { "Loop A", 9005 },
    [9005] = { "Loop B", 9004 },
}

local getMapInfoCalls = 0
C_Map = {
    GetBestMapForUnit = function() return nil end,
    GetMapInfo = function(mapID)
        getMapInfoCalls = getMapInfoCalls + 1
        local row = MAPS[mapID]
        if not row then return nil end
        return { name = row[1], parentMapID = row[2], mapType = row[3] or ZONE }
    end,
    -- The real helper reads childInfo.mapID and childInfo.mapType.
    GetMapChildrenInfo = function(mapID)
        local children = {}
        for childID, row in pairs(MAPS) do
            if row[2] == mapID then
                children[#children + 1] = { mapID = childID, name = row[1], mapType = row[3] or ZONE }
            end
        end
        table.sort(children, function(a, b) return a.mapID < b.mapID end)
        return children
    end,
}

local function NewHA()
    local HA = {
        Events = { RegisterCallback = function() end, Fire = function() end },
        PerformanceTrace = {
            Measure = function(_, _label, _tag, pcallFn, fn) return pcallFn(fn) end,
        },
        CatalogStore = { HasPersistedData = function() return true end },
        SourceManager = {
            GetItemPresentation = function()
                return {
                    matchesSourceFilter = true, isOwnershipExcluded = false,
                    isOwned = false, availabilityState = "purchasable",
                }
            end,
        },
    }
    assert(loadfile(root .. "/Core/constants.lua"))("Homestead", HA)
    -- Synthetic edge-case maps need a continent to reach the chain walk.
    for _, mapID in ipairs({ 9001, 9002, 9003, 9004, 9005 }) do
        HA.Constants.ZoneToContinentMap[mapID] = 2537
    end
    assert(loadfile(root .. "/UI/MapPinProvider.lua"))("Homestead", HA)
    return HA
end

local function LoadBadgeCalculation(HA, vendors, mapByNpc)
    HA.VendorFilter = {
        GetBestVendorCoordinates = function(vendor)
            return { x = 0.5, y = 0.5 }, mapByNpc[vendor.npcID]
        end,
        ShouldShowOppositeFaction = function() return false end,
        ShouldHideVendor = function() return false end,
        CanAccessVendor = function() return true end,
        IsOppositeFaction = function() return false end,
    }
    HA.VendorData = {
        GetAllVendors = function() return vendors end,
        GetMergedItemSet = function(_, _vendor, includeOrderedIDs)
            if includeOrderedIDs then return { [5001] = true }, { 5001 } end
            return { [5001] = true }
        end,
    }
    assert(loadfile(root .. "/UI/BadgeCalculation.lua"))("Homestead", HA)
    return HA.BadgeCalculation
end

-------------------------------------------------------------------------------
-- GetBadgeZoneMapID: the four chains from the ticket, siblings, edge cases
-------------------------------------------------------------------------------

do
    local HA = NewHA()
    local BC = LoadBadgeCalculation(HA, {}, {})

    assert(BC.GetBadgeZoneMapID(2444) == 2405, "Slayer's Rise must roll up to Voidstorm")
    assert(BC.GetBadgeZoneMapID(2599) == 2405, "Umbral Base Camp must roll up to Voidstorm")
    assert(BC.GetBadgeZoneMapID(2576) == 2413, "The Den must roll up to Harandar")
    assert(BC.GetBadgeZoneMapID(2509) == 2512, "Vaults of Atal'Utek must roll up to The Coiled Isle")

    assert(BC.GetBadgeZoneMapID(2405) == 2405, "a zone directly under its continent is its own key")
    assert(BC.GetBadgeZoneMapID(2395) == 2395, "a top-level zone is unchanged")

    -- Siblings still merge, to the same key as before the roll-up existed.
    assert(BC.GetBadgeZoneMapID(628) == 627, "Underbelly still merges into Dalaran")
    assert(BC.GetBadgeZoneMapID(627) == 627)
    -- City of Threads hangs off Azj-Kahet, so the merged pair rolls up to it.
    assert(BC.GetBadgeZoneMapID(2216) == 2255, "City of Threads - Lower must roll up to Azj-Kahet")
    assert(BC.GetBadgeZoneMapID(2213) == 2255, "City of Threads must roll up to Azj-Kahet")

    -- K'aresh is not in ZoneToContinentMap, so Tazavesh keeps its own key
    -- rather than a key that would resolve to no continent.
    assert(BC.GetBadgeZoneMapID(2472) == 2472, "Tazavesh must keep its own key")
    for mapID in pairs(HA.Constants.ZoneToContinentMap) do
        local key = BC.GetBadgeZoneMapID(mapID)
        assert(BC.GetContinentForZone(key) == BC.GetContinentForZone(BC.GetCanonicalZoneMapID(mapID)),
            "badge key " .. key .. " for map " .. mapID .. " must resolve to the input's continent")
    end

    -- Unresolvable chains keep today's behaviour: the input ID.
    assert(BC.GetBadgeZoneMapID(9001) == 9001, "chain ending without reaching the continent is unchanged")
    assert(BC.GetBadgeZoneMapID(9003) == 9003, "a map with no parent data is unchanged")
    assert(BC.GetBadgeZoneMapID(9004) == 9004, "a looping chain stops at the bound and is unchanged")
    assert(BC.GetBadgeZoneMapID(8888) == 8888, "a map outside ZoneToContinentMap is unchanged")

    -- Memoised: a second lookup of every ID does no further C_Map work.
    local before = getMapInfoCalls
    for _, id in ipairs({ 2444, 2599, 2576, 2509, 2405, 628, 2472, 9001, 9003, 9004, 8888 }) do
        BC.GetBadgeZoneMapID(id)
    end
    assert(getMapInfoCalls == before, "repeat lookups must be answered from the memo")

    print("hs497_subzone_badge_rollup: GetBadgeZoneMapID chains, siblings, unresolved ok")
end

-------------------------------------------------------------------------------
-- GetZoneVendorCounts: one key per zone, counts include the sub-zone vendors
-------------------------------------------------------------------------------

do
    local HA = NewHA()
    local mapByNpc = {
        [1] = 2405, [2] = 2444, [3] = 2599,
        [4] = 2413, [5] = 2576,
        [6] = 2512, [7] = 2509,
        [8] = 627, [9] = 628,
        [10] = 2213, [11] = 2216,
        [12] = 9001, [14] = 2472,
    }
    local vendors = {}
    for npcID = 1, 12 do vendors[#vendors + 1] = { npcID = npcID } end
    vendors[#vendors + 1] = { npcID = 14 }
    -- Override case: recorded on an unrelated map, counted under badgeMapID.
    vendors[#vendors + 1] = { npcID = 13, badgeMapID = 2444 }
    mapByNpc[13] = 9999

    local BC = LoadBadgeCalculation(HA, vendors, mapByNpc)

    local qt = BC:GetZoneVendorCounts(2537, "all")
    assert(qt[2405] and qt[2405].vendorCount == 4,
        "Voidstorm: zone + two sub-zones + badgeMapID override, got " .. tostring(qt[2405] and qt[2405].vendorCount))
    assert(qt[2413] and qt[2413].vendorCount == 2, "Harandar: zone + The Den")
    assert(qt[2512] and qt[2512].vendorCount == 2, "The Coiled Isle: zone + Vaults")
    assert(qt[2444] == nil and qt[2599] == nil and qt[2576] == nil and qt[2509] == nil,
        "no sub-zone key may survive")
    assert(qt[9001] and qt[9001].vendorCount == 1, "unresolved chain keeps its own key")
    assert(qt[2405].zoneName == "Voidstorm" and qt[2413].zoneName == "Harandar")
    assert(qt[2405].totalItems == 4, "stats aggregate across the merged vendors")

    local keys = 0
    for _ in pairs(qt) do keys = keys + 1 end
    assert(keys == 4, "expected Voidstorm, Harandar, Coiled Isle and the unresolved map, got " .. keys)

    local bi = BC:GetZoneVendorCounts(619, "all")
    assert(bi[627] and bi[627].vendorCount == 2 and bi[628] == nil, "Dalaran + Underbelly share one key")
    local kd = BC:GetZoneVendorCounts(2274, "all")
    assert(kd[2255] and kd[2255].vendorCount == 2 and kd[2213] == nil and kd[2216] == nil,
        "City of Threads halves share one key under Azj-Kahet")
    assert(kd[2472] and kd[2472].vendorCount == 1 and kd[2371] == nil,
        "Tazavesh vendor must still be counted, under its own map")

    -- Per continent, the zone counts add up to what they would without the roll-up.
    for _, continent in ipairs({ 2537, 619, 2274 }) do
        local expected = 0
        for _, vendor in ipairs(vendors) do
            local mapID = vendor.badgeMapID or mapByNpc[vendor.npcID]
            local merged = BC.GetCanonicalZoneMapID(mapID)
            if BC.GetContinentForZone(merged) == continent then expected = expected + 1 end
        end
        local sum = 0
        for _, entry in pairs(BC:GetZoneVendorCounts(continent, "all")) do
            sum = sum + entry.vendorCount
        end
        assert(sum == expected, "continent " .. continent .. ": zone keys hold " .. sum
            .. " vendors, expected " .. expected .. " (a vendor vanished from or was double-counted in the keys)")
    end

    -- Continent totals are unaffected by the roll-up: Quel'Thalas counts every
    -- vendor once, under Eastern Kingdoms.
    local totals = BC:GetContinentVendorCounts("all")
    assert(totals[13].vendorCount == 8, "continent total counts every vendor once, got " .. totals[13].vendorCount)

    print("hs497_subzone_badge_rollup: GetZoneVendorCounts one badge per zone ok")
end

-------------------------------------------------------------------------------
-- Undermine keeps its own continent badge; zone views badge undrawn child maps
-------------------------------------------------------------------------------

local function LoadEmission(HA)
    HA.VendorMapPins = {
        filter = "all",
        vendorEnabled = true,
        skips = {},
        GetActiveSourceFilter = function(self) return self.filter end,
        IsMapFilterSourceEnabled = function(self) return self.vendorEnabled end,
        DebugWorldMapProjectionSkip = function(self, kind, source, view, reason)
            self.skips[#self.skips + 1] = kind .. ":" .. source .. ":" .. view .. ":" .. tostring(reason)
        end,
    }
    assert(loadfile(root .. "/UI/BadgeEmission.lua"))("Homestead", HA)
    return HA.BadgeEmission
end

do
    local HA = NewHA()
    local mapByNpc = {
        [21] = 2346, [22] = 2406, [23] = 2214,   -- Undermine, its dungeon map, The Ringing Deeps
        [24] = 2472, [25] = 2472, [26] = 2371,   -- Tazavesh x2, K'aresh
        [27] = 2444, [28] = 2599, [29] = 2405,   -- Slayer's Rise, Umbral Base Camp, Voidstorm
        [30] = 2393, [31] = 2395,                -- Silvermoon City, Eversong Woods
        [32] = 2509, [33] = 2512,                -- Vaults (zone child), The Coiled Isle
        [34] = 2213, [35] = 2216,                -- City of Threads and its lower half
    }
    local vendors = {}
    for npcID = 21, 35 do vendors[#vendors + 1] = { npcID = npcID } end
    local BC = LoadBadgeCalculation(HA, vendors, mapByNpc)
    local MPP = HA.MapPinProvider

    -- Override table: both Undermine maps count under 2346.
    assert(HA.Constants.ContinentBadgeOverrides[2346] == 2346 and HA.Constants.ContinentBadgeOverrides[2406] == 2346)
    assert(HA.Constants.ZoneToContinentMap[2346] == 2274 and HA.Constants.ZoneToContinentMap[2406] == 2274,
        "both Undermine maps must be in ZoneToContinentMap under Khaz Algar")
    assert(BC.GetBadgeZoneMapID(2346) == 2346, "Undermine keeps its own key")
    assert(BC.GetBadgeZoneMapID(2406) == 2346, "the Undermine dungeon map counts under Undermine")
    assert(BC.GetBadgeZoneMapID(2214) == 2214, "The Ringing Deeps is its own key")

    local kd = BC:GetZoneVendorCounts(2274, "all")
    assert(kd[2346] and kd[2346].vendorCount == 2, "Undermine key holds both Undermine maps' vendors")
    assert(kd[2214] and kd[2214].vendorCount == 1, "The Ringing Deeps no longer absorbs Undermine")
    assert(kd[2406] == nil, "the dungeon map keeps no key of its own")

    -- K'aresh: Tazavesh is the same type as its parent, so it is badged.
    local kr = BC:GetChildMapVendorCounts(2371, "all")
    local keys = 0
    for _ in pairs(kr) do keys = keys + 1 end
    assert(keys == 1 and kr[2472] and kr[2472].vendorCount == 2,
        "K'aresh view: one child badge for Tazavesh with 2 vendors")
    assert(kr[2472].zoneName == "Tazavesh" and kr[2472].totalItems == 2)

    -- Voidstorm: both Zone-type children are badged; the Voidstorm vendor is a pin.
    local vs = BC:GetChildMapVendorCounts(2405, "all")
    assert(vs[2444] and vs[2444].vendorCount == 1 and vs[2599] and vs[2599].vendorCount == 1,
        "Voidstorm view: badges for Slayer's Rise and Umbral Base Camp")
    assert(vs[2405] == nil, "the viewed map's own vendor is never badged")

    -- Same-type parent/child pairs from the ticket.
    assert(BC:GetChildMapVendorCounts(2395, "all")[2393].vendorCount == 1, "Silvermoon City on Eversong Woods")
    assert(BC:GetChildMapVendorCounts(2214, "all")[2346].vendorCount == 1,
        "Undermine on The Ringing Deeps counts its zone vendor only")
    assert(BC:GetChildMapVendorCounts(2214, "all")[2406] == nil,
        "the dungeon map is drawn as pins on The Ringing Deeps, so it gets no badge")

    -- Vaults of Atal'Utek is a Zone map, the same type as its parent, so it is not
    -- drawn as pins on The Coiled Isle and is badged there.
    local ci = BC:GetChildMapVendorCounts(2512, "all")
    assert(ci[2509] and ci[2509].vendorCount == 1 and ci[2512] == nil,
        "The Coiled Isle view: one badge for Vaults of Atal'Utek, its own vendor is a pin")
    assert(next(BC:GetChildMapVendorCounts(2509, "all")) == nil, "a map without children has no badges")
    -- The Den is a Micro map, drawn as pins on Harandar, so it gets no badge.
    assert(next(BC:GetChildMapVendorCounts(2413, "all")) == nil, "micro child is pinned, no badge")
    -- Only a zone view badges child maps.
    assert(next(BC:GetChildMapVendorCounts(2274, "all")) == nil, "a continent view gets no child badges")
    assert(next(BC:GetChildMapVendorCounts(2537, "all")) == nil, "a continent view gets no child badges")
    assert(next(BC:GetChildMapVendorCounts(946, "all")) == nil, "an unknown or cosmic map gets no child badges")

    -- Vertical siblings merge under one child badge; deeper vendors count under
    -- the direct child that leads to them.
    local ak = BC:GetChildMapVendorCounts(2255, "all")
    assert(ak[2213] and ak[2213].vendorCount == 2 and ak[2216] == nil,
        "City of Threads and its lower half share one child badge")

    -- No vendor is both pinned and badged: on every view the pinned vendors and
    -- the badged vendors partition the vendors that sit below the view.
    for _, view in ipairs({ 2371, 2405, 2395, 2214, 2512, 2255, 2413 }) do
        local pinned = { [view] = true }
        for _, childID in ipairs(MPP:GetMoreSpecificChildMapIDs(view)) do pinned[childID] = true end
        local badgedExpected = 0
        for _, vendor in ipairs(vendors) do
            local mapID = mapByNpc[vendor.npcID]
            local below = false
            local current = mapID
            for _ = 1, 6 do
                local parent = MPP:GetParentMapID(current)
                if not parent then break end
                if parent == view then below = true break end
                current = parent
            end
            if below and not pinned[mapID] then badgedExpected = badgedExpected + 1 end
        end
        local badged = 0
        for _, entry in pairs(BC:GetChildMapVendorCounts(view, "all")) do badged = badged + entry.vendorCount end
        assert(badged == badgedExpected, "view " .. view .. " badges " .. badged .. " vendors, expected " .. badgedExpected)
    end

    -- Cache: the second build is a hit (same table, no vendor walk); invalidation drops it.
    local walks = 0
    local realGetAll = HA.VendorData.GetAllVendors
    HA.VendorData.GetAllVendors = function(...) walks = walks + 1 return realGetAll(...) end
    local first = BC:GetChildMapVendorCounts(2371, "all")
    local second = BC:GetChildMapVendorCounts(2371, "all")
    assert(rawequal(first, second), "second build must be answered from the cache")
    assert(walks == 0, "a cached view must not walk the vendor list, walked " .. walks)
    BC:InvalidateBadgeCache()
    local third = BC:GetChildMapVendorCounts(2371, "all")
    assert(not rawequal(first, third) and walks == 1, "InvalidateBadgeCache must drop the child-map cache")
    BC:InvalidateAllCaches()
    BC:GetChildMapVendorCounts(2371, "all")
    assert(walks == 2, "InvalidateAllCaches must drop the child-map cache")
    HA.VendorData.GetAllVendors = realGetAll
    assert(BC:GetDebugCacheTables().cachedChildMapBadges, "debug accessor exposes the child-map cache")

    -- Emission: a K'aresh view yields one Tazavesh zone badge in the existing shape.
    C_Map.GetMapRectOnMap = function() return 0.4, 0.6, 0.4, 0.6 end
    local Emission = LoadEmission(HA)
    local state = { zoneBadges = {} }
    Emission:ShowChildMapBadges(2371, state)
    assert(#state.zoneBadges == 1, "one badge expected, got " .. #state.zoneBadges)
    local badge = state.zoneBadges[1]
    assert(badge.mapID == 2472 and badge.badgeData.mapID == 2472 and badge.badgeData.vendorCount == 2
        and badge.badgeData.zoneName == "Tazavesh", "badge carries the child map and its counts")
    assert(math.abs(badge.x - 0.5) < 1e-9 and math.abs(badge.y - 0.5) < 1e-9)

    -- Source gates follow the vendor pins.
    HA.VendorMapPins.filter = "drop"
    state = { zoneBadges = {} }
    Emission:ShowChildMapBadges(2371, state)
    assert(#state.zoneBadges == 0, "no badges under a non-vendor source filter")
    HA.VendorMapPins.filter = "all"
    HA.VendorMapPins.vendorEnabled = false
    Emission:ShowChildMapBadges(2371, state)
    assert(#state.zoneBadges == 0, "no badges when the vendor source is off")

    -- A failed projection skips the badge and logs through the skip hook.
    C_Map.GetMapRectOnMap = function() return nil end
    local HA2 = NewHA()
    HA2.MapPinProvider.manualZoneCenters = {}
    LoadBadgeCalculation(HA2, vendors, mapByNpc)
    local Emission2 = LoadEmission(HA2)
    state = { zoneBadges = {} }
    Emission2:ShowChildMapBadges(2371, state)
    assert(#state.zoneBadges == 0 and #HA2.VendorMapPins.skips == 1
        and HA2.VendorMapPins.skips[1]:find("^child_map_badge:2472:2371:"), "projection failure is skipped and logged")

    print("hs497_subzone_badge_rollup: Undermine override and child-map badges ok")
end

-------------------------------------------------------------------------------
-- The Eastern Kingdoms overlay filters by the rolled-up key
-------------------------------------------------------------------------------

do
    local HA = NewHA()
    local excluded = HA.MapPinProvider.continentZoneBadgeExclusionsOnParent[2537][13]
    for _, zoneMapID in ipairs({ 2405, 2413, 2599 }) do
        assert(excluded[zoneMapID], "zone " .. zoneMapID .. " must stay off the Eastern Kingdoms map")
    end
    print("hs497_subzone_badge_rollup: Eastern Kingdoms exclusions cover the rolled-up zones ok")
end

-------------------------------------------------------------------------------
-- Quel'Thalas rolls into Eastern Kingdoms on the Azeroth world map
-------------------------------------------------------------------------------

do
    local HA = NewHA()
    C_Map.GetMapRectOnMap = function() return 0.4, 0.6, 0.4, 0.6 end
    -- 17 (Blasted Lands) sits directly under Eastern Kingdoms (13).
    local mapByNpc = {
        [1] = 17, [2] = 17, [3] = 17,                 -- Eastern Kingdoms: 3
        [4] = 2395, [5] = 2393,                       -- Eversong Woods, Silvermoon City
        [6] = 2405, [7] = 2444,                       -- Voidstorm and its sub-zone (excluded from the overlay)
        [8] = 2413,                                   -- Harandar (excluded from the overlay)
        [9] = 2512,                                   -- The Coiled Isle
    }
    local vendors = {}
    for npcID = 1, 9 do vendors[#vendors + 1] = { npcID = npcID } end
    local BC = LoadBadgeCalculation(HA, vendors, mapByNpc)
    local MPP = HA.MapPinProvider
    local Emission = LoadEmission(HA)

    local function Count(t)
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        return n
    end

    -- Totals: one Eastern Kingdoms entry carrying both, excluded zones included.
    local totals = BC:GetContinentVendorCounts("all")
    assert(totals[2537] == nil, "Quel'Thalas has no continent entry of its own")
    assert(totals[13] and totals[13].vendorCount == 9, "Eastern Kingdoms carries both, got "
        .. tostring(totals[13] and totals[13].vendorCount))
    assert(totals[13].totalItems == 9, "item totals are combined too")
    assert(Count(totals) == 1, "no other continent entries")

    -- Zone counts per continent are untouched by the roll-up.
    assert(Count(BC:GetZoneVendorCounts(13, "all")) == 1 and BC:GetZoneVendorCounts(13, "all")[17].vendorCount == 3)
    assert(BC:GetZoneVendorCounts(2537, "all")[2395].vendorCount == 2)

    -- Side panel list: own zones plus one Quel'Thalas entry, never its zones.
    local list = BC:GetContinentZoneListCounts(13, "all")
    assert(Count(list) == 2 and list[17] and list[2537], "Eastern Kingdoms lists Blasted Lands and Quel'Thalas")
    assert(list[2395] == nil and list[2405] == nil and list[2413] == nil and list[2512] == nil,
        "Quel'Thalas zones are not flattened into Eastern Kingdoms")
    assert(list[2537].zoneName == "Quel'Thalas" and list[2537].vendorCount == 6
        and list[2537].totalItems == 6 and list[2537].isContinent, "the entry carries the continent aggregate")
    local own = BC:GetZoneVendorCounts(2537, "all")
    local ownVendors = 0
    for _, zoneData in pairs(own) do ownVendors = ownVendors + zoneData.vendorCount end
    assert(list[2537].vendorCount == ownVendors, "entry equals the sum of the continent's own zone list")
    assert(Count(BC:GetContinentZoneListCounts(2537, "all")) == 4, "Quel'Thalas alone lists its own zones")

    -- World map, continent totals: a single Eastern Kingdoms badge, none for 2537.
    local state = { continentBadges = {}, zoneBadges = {} }
    Emission:ShowContinentBadges(state)
    assert(#state.continentBadges == 1 and state.continentBadges[1].mapID == 13
        and state.continentBadges[1].badgeData.vendorCount == 9, "one combined Eastern Kingdoms badge")

    -- World map, zone badges mode: the Quel'Thalas zones are still drawn.
    HA.Addon = { db = { profile = { vendorTracer = { worldMapZoneBadges = true } } } }
    state = { continentBadges = {}, zoneBadges = {} }
    Emission:ShowContinentBadges(state)
    local drawn = {}
    for _, badge in ipairs(state.zoneBadges) do drawn[badge.mapID] = (drawn[badge.mapID] or 0) + 1 end
    assert(#state.continentBadges == 0, "zone mode draws no continent badge")
    for _, zoneMapID in ipairs({ 17, 2395, 2405, 2413, 2512 }) do
        assert(drawn[zoneMapID] == 1, "zone " .. zoneMapID .. " drawn once on the world map, got " .. tostring(drawn[zoneMapID]))
    end
    assert(#state.zoneBadges == 5)
    HA.Addon = nil

    -- Eastern Kingdoms continent map: today's zones, exclusions honoured, no duplicates.
    state = { zoneBadges = {} }
    Emission:ShowZoneBadges(13, state)
    drawn = {}
    for _, badge in ipairs(state.zoneBadges) do drawn[badge.mapID] = (drawn[badge.mapID] or 0) + 1 end
    assert(drawn[17] == 1 and drawn[2395] == 1 and drawn[2512] == 1, "own and allowed overlay zones drawn once")
    assert(drawn[2405] == nil and drawn[2413] == nil, "excluded zones stay off the Eastern Kingdoms map")
    assert(#state.zoneBadges == 3)

    -- Quel'Thalas continent map: its own zones, nothing added or removed.
    state = { zoneBadges = {} }
    Emission:ShowZoneBadges(2537, state)
    assert(#state.zoneBadges == 4, "Quel'Thalas map keeps all its zone badges, got " .. #state.zoneBadges)
    assert(MPP.continentZoneBadgesOnParent[2537] == 13)

    print("hs497_subzone_badge_rollup: Quel'Thalas rolls into Eastern Kingdoms ok")
end

-------------------------------------------------------------------------------
-- The continent totals fold: Argus into Broken Isles, and a destination with
-- no vendors of its own
-------------------------------------------------------------------------------

do
    local HA = NewHA()
    local mapByNpc = { [1] = 709, [2] = 830 }
    local BC = LoadBadgeCalculation(HA, { { npcID = 1 }, { npcID = 2 } }, mapByNpc)
    local totals = BC:GetContinentVendorCounts("all")
    assert(totals[905] == nil and totals[619] and totals[619].vendorCount == 2,
        "Argus vendor folds into Broken Isles, got " .. tostring(totals[619] and totals[619].vendorCount))
    assert(BC:GetContinentZoneListCounts(619, "all")[905] == nil, "Argus is not listed under Broken Isles")

    HA = NewHA()
    BC = LoadBadgeCalculation(HA, { { npcID = 1 }, { npcID = 2 } }, { [1] = 2395, [2] = 2405 })
    totals = BC:GetContinentVendorCounts("all")
    assert(totals[2537] == nil and totals[13] and totals[13].vendorCount == 2 and totals[13].totalItems == 2,
        "a destination with no vendors of its own takes the source's totals")
    local list = BC:GetContinentZoneListCounts(13, "all")
    assert(list[2537] and list[2537].vendorCount == 2 and list[17] == nil,
        "the list holds only the Quel'Thalas entry")

    -- No vendors under the filter in the rolled-in continent: no entry.
    HA = NewHA()
    BC = LoadBadgeCalculation(HA, { { npcID = 1 } }, { [1] = 17 })
    assert(BC:GetContinentZoneListCounts(13, "all")[2537] == nil, "an empty rolled-in continent has no entry")

    print("hs497_subzone_badge_rollup: continent fold and empty-entry cases ok")
end

-------------------------------------------------------------------------------
-- The real side-panel code paths: the continent view list and the continent
-- expansion sub-rows. UI/MapSidePanel.lua cannot be loaded whole, so the three
-- functions are cut out of the source text and run against the real
-- BadgeCalculation with stubs for the panel's frames.
-------------------------------------------------------------------------------

do
    local file = assert(io.open(root .. "/UI/MapSidePanel.lua", "rb"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    local function cut(pattern)
        local text = source:match(pattern)
        assert(text, "could not extract " .. pattern)
        return text
    end
    local chunkText = cut("(local function AppendZoneSubRows%(.-\nend\n)") .. "\n"
        .. cut("(local function BuildContinentExpansionRows%(.-\nend\n)") .. "\n"
        .. cut("(function MapSidePanel:RefreshZoneSummaries%(.-\nend\n)")

    local function Run(HA, expandedMapID)
        local BC = HA.BadgeCalculation
        local rows, summary = nil, nil
        local text = { SetText = function() end, Show = function() end, Hide = function() end }
        local env = {
            BC = BC,
            State = {
                panelSourceFilter = "all", expandedSummaryMapID = expandedMapID,
                headerText = text, emptyText = text,
                summaryText = { SetText = function(_, value) summary = value end },
            },
            Layout = {
                ROW_HEIGHT = 40, SUB_ROW_HEIGHT = 24,
                COLOR_WHITE = { 1, 1, 1 }, COLOR_DIM = { 0.5, 0.5, 0.5 },
            },
            MapSidePanel = {},
            FormatPurchasabilityCountText = function(collected, total) return collected .. "/" .. total end,
            SetListRows = function(value) rows = value end,
            UpdateBackBar = function() end,
            HideProgressBar = function() end,
            UpdateProgressBar = function() end,
            BuildZoneExpansionRows = function(zoneMapID, out)
                out[#out + 1] = { kind = "subrow", iconMode = "vendor", targetMapID = zoneMapID }
            end,
            string = string, table = table, ipairs = ipairs, pairs = pairs,
        }
        local chunk = assert(loadstring(chunkText .. "\nreturn BuildContinentExpansionRows"))
        setfenv(chunk, env)
        local buildContinentExpansionRows = chunk()
        env.MapSidePanel:RefreshZoneSummaries(13, { name = "Eastern Kingdoms" })
        local expansion = {}
        buildContinentExpansionRows(13, expansion)
        return rows, summary, expansion
    end

    local HA = NewHA()
    local mapByNpc = { [1] = 17, [2] = 17, [3] = 2395, [4] = 2405, [5] = 2512 }
    local vendors = {}
    for npcID = 1, 5 do vendors[npcID] = { npcID = npcID } end
    LoadBadgeCalculation(HA, vendors, mapByNpc)

    local rows, summary, expansion = Run(HA, nil)
    assert(#rows == 2, "continent view: Blasted Lands and Quel'Thalas, got " .. #rows)
    assert(rows[1].name == "Blasted Lands" and rows[1].targetMapID == 17 and rows[1].vendorCount == 2)
    assert(rows[2].name == "Quel'Thalas" and rows[2].targetMapID == 2537 and rows[2].vendorCount == 3
        and rows[2].collectedItems == 0 and rows[2].totalItems == 3 and rows[2].kind == "summary",
        "continent view: one Quel'Thalas row carrying the aggregate")
    assert(rows[2].summaryLineText == "3 vendors | 0/3", "row text, got " .. tostring(rows[2].summaryLineText))
    assert(summary == "2 zones | 0/5 items", "footer still totals the listed rows, got " .. tostring(summary))

    assert(#expansion == 2 and expansion[1].name == "Blasted Lands" and expansion[2].name == "Quel'Thalas"
        and expansion[2].targetMapID == 2537 and expansion[2].iconMode == "zone"
        and expansion[2].countText == "0/3", "expansion: one Quel'Thalas sub-row targeting 2537")

    -- Expanding the Quel'Thalas row lists its zones, not a vendor expansion.
    rows = Run(HA, 2537)
    local names = {}
    for _, row in ipairs(rows) do names[#names + 1] = row.name or ("<" .. row.iconMode .. ">") end
    assert(#rows == 5 and rows[3].name == "Eversong Woods" and rows[4].name == "The Coiled Isle"
        and rows[5].name == "Voidstorm", "expanded Quel'Thalas lists its zones: " .. table.concat(names, ", "))
    rows = Run(HA, 17)
    assert(#rows == 3 and rows[2].iconMode == "vendor", "an expanded zone still expands to its vendors")

    print("hs497_subzone_badge_rollup: side panel lists one Quel'Thalas row ok")
end

print("hs497_subzone_badge_rollup: ok")
