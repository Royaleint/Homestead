-- luacheck: globals assert loadfile print C_Timer C_Map CreateFrame InCombatLockdown GetTimePreciseSec

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-497: a vendor recorded on a sub-zone or dungeon map is counted under the
-- zone map directly below its continent (BadgeCalculation.GetBadgeZoneMapID),
-- so a continent map shows one badge per zone. Loads the REAL Constants
-- (ZoneToContinentMap, VerticalSiblings), the REAL MapPinProvider (for
-- GetParentMapID and the continent index) and the REAL BadgeCalculation, with
-- C_Map.GetMapInfo serving the parent chains below.
-------------------------------------------------------------------------------

CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript() end
    return frame
end
InCombatLockdown = function() return false end
GetTimePreciseSec = function() return 0 end
C_Timer = {
    NewTicker = function() return { Cancel = function() end } end,
    NewTimer = function() return { Cancel = function() end } end,
    After = function() end,
}

-- mapID -> { name, parent }. parent 0 / nil = no parent. Parents of the real
-- maps match the client; 9001-9005 are synthetic edge cases.
local MAPS = {
    [2537] = { "Quel'Thalas", 13 },
    [2405] = { "Voidstorm", 2537 },
    [2444] = { "Slayer's Rise", 2405 },
    [2599] = { "Umbral Base Camp", 2405 },
    [2413] = { "Harandar", 2537 },
    [2576] = { "The Den", 2413 },
    [2512] = { "The Coiled Isle", 2537 },
    [2509] = { "Vaults of Atal'Utek", 2512 },
    -- Vertical siblings
    [627] = { "Dalaran", 619 },
    [628] = { "Dalaran Underbelly", 627 },
    [2255] = { "Azj-Kahet", 2274 },
    [2213] = { "City of Threads", 2255 },
    [2216] = { "City of Threads - Lower", 2255 },
    -- Tazavesh: the ancestor under the continent (K'aresh) is not in ZoneToContinentMap
    [2371] = { "K'aresh", 2274 },
    [2472] = { "Tazavesh", 2371 },
    -- Top-level zone: parent is the continent already
    [2395] = { "Silvermoon", 2537 },
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
        return { name = row[1], parentMapID = row[2] }
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
    for _, mapID in ipairs({ 2444, 2599, 2576, 2509, 2405, 628, 2213, 2216, 2472, 9001, 9004 }) do
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
        assert(sum == expected, "continent " .. continent .. " zone counts sum to " .. sum .. ", expected " .. expected)
    end

    -- Continent totals are unaffected by the roll-up.
    local totals = BC:GetContinentVendorCounts("all")
    assert(totals[2537].vendorCount == 8, "continent total counts every vendor once, got " .. totals[2537].vendorCount)

    print("hs497_subzone_badge_rollup: GetZoneVendorCounts one badge per zone ok")
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

print("hs497_subzone_badge_rollup: ok")
