-- luacheck: globals assert loadfile print C_Timer C_Map Enum CreateFrame InCombatLockdown GetTimePreciseSec wipe rawequal

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-497: child-map badges are produced through the real
-- VendorMapPins:BuildWorldMapRenderState, and only for a Zone view. Loads the
-- REAL Constants, MapPinProvider, BadgeCalculation, BadgeEmission and
-- VendorMapPins. Only the pin collector (CollectSourcePins) is replaced, since
-- it draws vendor pins and is not part of the badge path.
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
Enum = { UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 } }

local COSMIC, WORLD, CONTINENT, ZONE, DUNGEON, MICRO, ORPHAN = 0, 1, 2, 3, 4, 5, 6
-- mapID -> { name, parent, mapType }
local MAPS = {
    [946] = { "Cosmic", 0, COSMIC },
    [947] = { "Azeroth", 946, WORLD },
    [2274] = { "Khaz Algar", 947, CONTINENT },
    [2371] = { "K'aresh", 2274, ZONE },
    [2472] = { "Tazavesh", 2371, ZONE },
    [2509] = { "Vaults of Atal'Utek", 2512, ZONE },
    [2512] = { "The Coiled Isle", 2537, ZONE },
    [2537] = { "Quel'Thalas", 13, CONTINENT },
    [627] = { "Dalaran", 619, DUNGEON },
    [628] = { "Dalaran Underbelly", 619, DUNGEON },
    [2576] = { "The Den", 2413, MICRO },
    [9001] = { "Orphan", 0, ORPHAN },
}

C_Map = {
    GetBestMapForUnit = function() return nil end,
    GetMapInfo = function(mapID)
        local row = MAPS[mapID]
        if not row then return nil end
        return { name = row[1], parentMapID = row[2], mapType = row[3] }
    end,
    GetMapChildrenInfo = function(mapID)
        local children = {}
        for childID, row in pairs(MAPS) do
            if row[2] == mapID then
                children[#children + 1] = { mapID = childID, name = row[1], mapType = row[3] }
            end
        end
        table.sort(children, function(a, b) return a.mapID < b.mapID end)
        return children
    end,
    GetMapRectOnMap = function() return 0.4, 0.6, 0.4, 0.6 end,
}

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
assert(loadfile(root .. "/UI/MapPinProvider.lua"))("Homestead", HA)

-- Vendors: npc 1 on Tazavesh (badged under K'aresh), npc 2 on K'aresh (a pin),
-- npc 3 on the Vaults (badged under The Coiled Isle), npc 4 on a Dalaran map.
local mapByNpc = { [1] = 2472, [2] = 2371, [3] = 2509, [4] = 628 }
local vendors = {}
for npcID = 1, 4 do vendors[#vendors + 1] = { npcID = npcID } end

local vendorWalks = 0
local statCalls = 0
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
    GetAllVendors = function() vendorWalks = vendorWalks + 1 return vendors end,
    GetMergedItemSet = function(_, _vendor, includeOrderedIDs)
        statCalls = statCalls + 1
        if includeOrderedIDs then return { [5001] = true }, { 5001 } end
        return { [5001] = true }
    end,
}
assert(loadfile(root .. "/UI/BadgeCalculation.lua"))("Homestead", HA)
assert(loadfile(root .. "/UI/BadgeEmission.lua"))("Homestead", HA)
assert(loadfile(root .. "/UI/VendorMapPins.lua"))("Homestead", HA)

local VMP = HA.VendorMapPins
assert(type(VMP.BuildWorldMapRenderState) == "function", "VendorMapPins must load")
VMP.CollectSourcePins = function() end
VMP.GetActiveSourceFilter = function() return "all" end
VMP.IsMapFilterSourceEnabled = function() return true end

-- Zone view with a badged child.
local state = VMP:BuildWorldMapRenderState(2371)
assert(state.mapType == ZONE)
assert(#state.zoneBadges == 1, "K'aresh view: one child badge, got " .. #state.zoneBadges)
assert(state.zoneBadges[1].mapID == 2472 and state.zoneBadges[1].badgeData.vendorCount == 1,
    "the badge is Tazavesh with its one vendor")

-- A Zone child of a Zone view is badged too (Vaults on The Coiled Isle).
state = VMP:BuildWorldMapRenderState(2512)
assert(#state.zoneBadges == 1 and state.zoneBadges[1].mapID == 2509, "Coiled Isle view badges the Vaults")

-- Cosmic, Dungeon, Micro and Orphan views: no child badges, no vendor-stat work.
vendorWalks, statCalls = 0, 0
for _, view in ipairs({ 946, 628, 2576, 9001 }) do
    state = VMP:BuildWorldMapRenderState(view)
    assert(#state.zoneBadges == 0, "view " .. view .. " must have no child badges")
end
assert(vendorWalks == 0 and statCalls == 0,
    "non-zone views must not walk vendors (walks " .. vendorWalks .. ", stat calls " .. statCalls .. ")")
-- The same guard on the helper itself, which the side panel calls directly.
for _, view in ipairs({ 946, 947, 2274, 628, 2576, 9001 }) do
    assert(next(HA.BadgeCalculation:GetChildMapVendorCounts(view, "all")) == nil)
end
assert(vendorWalks == 0 and statCalls == 0, "GetChildMapVendorCounts must do no vendor work off a zone view")

-- Mutation guard: the call site gate is what stops the Dungeon view, not the helper's.
local calls = 0
local realShow = VMP.ShowChildMapBadges
VMP.ShowChildMapBadges = function(...) calls = calls + 1 return realShow(...) end
VMP:BuildWorldMapRenderState(628)
VMP:BuildWorldMapRenderState(946)
assert(calls == 0, "ShowChildMapBadges must not be called for non-zone views")
VMP:BuildWorldMapRenderState(2371)
assert(calls == 1, "ShowChildMapBadges is called for a zone view")

print("hs497_child_badge_wiring: ok")
