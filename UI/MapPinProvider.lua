--[[
    Homestead - MapPinProvider
    Unified coordinate intelligence and pin placement module

    Single source of truth for:
    - Geography lookup tables (continent exclusions, merges, manual centers)
    - Zone-continent reverse index
    - Native coordinate projection helpers
    - Native world-map pin placement and cleanup
    - Shared world-coordinate helpers for the custom minimap overlay

    No events registered. No SavedVariables access. Static module with no
    Initialize() — all setup runs at file load time.

    NOTE: ClearWorldMapPins clears native pins globally by template, not per
    namespace. This module is designed for Homestead's single-namespace use.
]]

local _, HA = ...
local MapPinProvider = {}
HA.MapPinProvider = MapPinProvider

local pairs = pairs
local Constants = HA.Constants
local projectionRectCache = {}
local parentMapCache = {}
local childMapIDsCache = {}

-- HS-282: read-only debug accessor for the /hs debug membudget walker.
-- Read-only references, never mutated by the caller.
function MapPinProvider.GetDebugCacheTables()
    return {
        projectionRectCache = projectionRectCache,
        parentMapCache = parentMapCache,
        childMapIDsCache = childMapIDsCache,
    }
end

-------------------------------------------------------------------------------
-- Zone-Continent Reverse Index
-------------------------------------------------------------------------------

local zoneToContinent = (Constants and Constants.ZoneToContinentMap) or {}

-- Reverse index: continent → list of zone mapIDs (built once at load time).
-- Exposed as module field for VendorMapPins sibling zone lookup.
MapPinProvider.continentToZones = {}
for zoneMapID, contID in pairs(zoneToContinent) do
    if not MapPinProvider.continentToZones[contID] then
        MapPinProvider.continentToZones[contID] = {}
    end
    local t = MapPinProvider.continentToZones[contID]
    t[#t + 1] = zoneMapID
end

function MapPinProvider.GetContinentForZone(zoneMapID)
    return zoneToContinent[zoneMapID] or nil
end

-------------------------------------------------------------------------------
-- Geography Tables
-------------------------------------------------------------------------------

-- Continents NOT physically on the Azeroth world map — skip their badges entirely.
MapPinProvider.excludedContinents = {
    [572] = true,   -- Draenor (alternate dimension)
    [1550] = true,  -- Shadowlands (afterlife dimension)
}

-- Continents whose vendor counts and zone badges roll into a parent continent.
-- A continent must not be both a source and a destination in these roll-up tables: the totals fold assumes no chains.
-- Argus is accessed via Dalaran (Broken Isles) — logically part of BI on the world map.
MapPinProvider.continentMergesInto = {
    [905] = 619,   -- Argus → Broken Isles
}

-- Continents whose totals roll into another continent on the world map, and whose
-- zone badges are also drawn on that continent's own map (minus the exclusions below).
MapPinProvider.continentZoneBadgesOnParent = {
    [2537] = 13,   -- Midnight/Quel'Thalas zones on Eastern Kingdoms continent map
}

-- Per-source/destination zone exclusions for cross-continent badge overlays.
-- Excluded zones still count toward continent totals; this only affects
-- whether individual zone badges render on the destination continent map.
MapPinProvider.continentZoneBadgeExclusionsOnParent = {
    [2537] = {
        [13] = {
            [2405] = true,   -- Voidstorm
            [15958] = true,  -- Voidstorm variant/child map
            [2444] = true,   -- Slayer's Rise (Voidstorm sub-zone)
            [2694] = true,   -- Harandar
            [2576] = true,   -- The Den (Harandar sub-zone)
            [2413] = true,   -- Harandar
            [2599] = true,   -- Umbral Base Camp (Voidstorm sub-zone; matters only if its chain is unresolved)
        },
    },
}

-- Off-world continents with manual positions on the Azeroth world map (mapID 947).
-- These are NOT in excludedContinents — they get badges via native pin fallback.
-- Argus zones (830, 882, 885) map to continent 905 in zoneToContinent.
MapPinProvider.offWorldContinentPositions = {
    -- [905] removed — Argus counts merge into Broken Isles (continentMergesInto)
    -- [2537] removed — Midnight/Quel'Thalas now projects natively on Eastern Kingdoms
}

-- Manual zone center positions for cross-instance maps where GetMapRectOnMap returns nil.
-- Coordinates are normalized 0-1 on the parent continent map. Positions are approximate.
-- Only used as fallback when C_Map.GetMapRectOnMap() returns nil.
MapPinProvider.manualZoneCenters = {
    -- Argus zones on Argus continent (905)
    [830] = { [905] = { x = 0.33, y = 0.60 } },  -- Krokuun
    [882] = { [905] = { x = 0.60, y = 0.65 } },  -- Eredath
    [885] = { [905] = { x = 0.68, y = 0.30 } },  -- Mac'Aree
    [831] = { [619] = { x = 0.84, y = 0.14 } },  -- The Vindicaar (Krokuun area, Argus — approximate, verify in-game)

    -- Legion class halls on Broken Isles (619) — fallback for instanced zones
    -- Physically on Broken Isles
    [739] = { [619] = { x = 0.35, y = 0.26 } },  -- Trueshot Lodge (Highmountain)
    [747] = { [619] = { x = 0.16, y = 0.50 } },  -- The Dreamgrove (Val'sharah)
    [647] = { [619] = { x = 0.40, y = 0.78 } },  -- Acherus: The Ebon Hold (above Broken Shore)
    [695] = { [619] = { x = 0.67, y = 0.16 } },  -- Skyhold (above Stormheim)
    -- Under/inside Dalaran
    [626] = { [619] = { x = 0.49, y = 0.44 } },  -- The Hall of Shadows (Dalaran sewers)
    [734] = { [619] = { x = 0.46, y = 0.48 } },  -- Hall of the Guardian (beneath Dalaran)
    -- Off-world, accessed via Dalaran portals — clustered near Dalaran
    [24]  = { [619] = { x = 0.52, y = 0.40 } },  -- Light's Hope Chapel (Paladin)
    [702] = { [619] = { x = 0.44, y = 0.40 } },  -- Netherlight Temple (Priest)
    [709] = { [619] = { x = 0.46, y = 0.65 } },  -- The Wandering Isle (Monk, legacy fallback near Dalaran)
    [717] = { [619] = { x = 0.44, y = 0.52 } },  -- Dreadscar Rift (Warlock)
    [720] = { [619] = { x = 0.54, y = 0.45 } },  -- The Fel Hammer (Demon Hunter)
    [726] = { [619] = { x = 0.42, y = 0.45 } },  -- The Maelstrom (Shaman)

    -- Undermine is its own instance, so it has no rect on Khaz Algar (2274)
    [2346] = { [2274] = { x = 0.81, y = 0.78 } },  -- Undermine (just above its name on the map art)
}

-- Notes shown in zone badge tooltips for special locations (class halls, etc.)
MapPinProvider.zoneNotes = {
    -- Class halls physically on the Broken Isles
    [739] = "Hunter Order Hall: Trueshot Lodge in Highmountain",
    [747] = "Druid Order Hall: Dreamwalk spell",
    [647] = "Death Knight Order Hall: Death Gate spell",
    [695] = "Warrior Order Hall: Jump from Krasus' Landing, Dalaran",
    -- Class halls under/inside Dalaran
    [626] = "Rogue Order Hall: Entrance in Dalaran sewers",
    [734] = "Mage Order Hall: Portal from Dalaran",
    -- Class halls off-world, accessed via Dalaran
    [24]  = "Paladin Order Hall: Portal from Dalaran",
    [702] = "Priest Order Hall: Portal from Dalaran",
    [709] = "Monk Order Hall: Zen Pilgrimage spell",
    [717] = "Warlock Order Hall: Portal from Dalaran",
    [720] = "Demon Hunter Order Hall: Portal from Krasus' Landing, Dalaran",
    [726] = "Shaman Order Hall: Portal from Dalaran",
}

-- Exclude continents in separate world spaces where cross-zone minimap translation
-- can collapse pins onto the player arrow.
MapPinProvider.minimapExcludedContinents = {
    [101] = true,   -- Outland (separate world space)
    [572] = true,   -- Draenor (alternate dimension)
    [1550] = true,  -- Shadowlands (afterlife dimension)
}


-- Get continent center position on Azeroth world map (mapID 947).
-- Fallback chain: offWorldContinentPositions → GetMapRectOnMap → nil.
function MapPinProvider:GetContinentCenterOnWorldMap(continentMapID)
    -- Off-world continents use manual positions on the Azeroth world map
    local manualPos = self.offWorldContinentPositions[continentMapID]
    if manualPos then
        return manualPos
    end

    -- Use C_Map.GetMapRectOnMap to dynamically calculate continent position on world map
    -- This is the same approach used by GetZoneCenterOnMap() for zones on continents
    local AZEROTH_WORLD_MAP = 947
    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(continentMapID, AZEROTH_WORLD_MAP)
    if minX and maxX and minY and maxY then
        return { x = (minX + maxX) / 2, y = (minY + maxY) / 2 }
    end

    return nil
end

-- Get zone center position on a parent map.
-- Fallback chain: GetMapRectOnMap → manualZoneCenters → nil.
-- NOTE: No extra projection fallback beyond manual centers — exact semantics from BadgeCalculation.
function MapPinProvider:GetZoneCenterOnMap(zoneMapID, parentMapID)
    local ok, x, y = self:ProjectZoneBadgeToContinentView(parentMapID, zoneMapID)
    if ok then
        return { x = x, y = y }
    end
    return nil
end

local function GetProjectionRect(sourceMapID, destMapID)
    local cacheKey = tostring(sourceMapID) .. ":" .. tostring(destMapID)
    local cached = projectionRectCache[cacheKey]
    if cached then
        return cached.ok, cached.minX, cached.maxX, cached.minY, cached.maxY, cached.reason
    end

    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(sourceMapID, destMapID)
    if minX == nil or maxX == nil or minY == nil or maxY == nil then
        projectionRectCache[cacheKey] = { ok = false, reason = "nil_rect" }
        return false, nil, nil, nil, nil, "nil_rect"
    end

    if minX == maxX and minY == maxY then
        projectionRectCache[cacheKey] = { ok = false, reason = "degenerate_rect" }
        return false, nil, nil, nil, nil, "degenerate_rect"
    end

    projectionRectCache[cacheKey] = {
        ok = true,
        minX = minX,
        maxX = maxX,
        minY = minY,
        maxY = maxY,
    }

    return true, minX, maxX, minY, maxY, "rect_projection"
end

local function ProjectViaRect(sourceMapID, destMapID, x, y)
    local ok, minX, maxX, minY, maxY, reason = GetProjectionRect(sourceMapID, destMapID)
    if not ok then
        return false, nil, nil, reason
    end

    return true,
        minX + ((maxX - minX) * x),
        minY + ((maxY - minY) * y),
        "rect_projection"
end

function MapPinProvider:GetParentMapID(mapID)
    if parentMapCache[mapID] ~= nil then
        return parentMapCache[mapID] or nil
    end

    local mapInfo = C_Map.GetMapInfo(mapID)
    local parentMapID = mapInfo and mapInfo.parentMapID
    if parentMapID and parentMapID > 0 then
        parentMapCache[mapID] = parentMapID
        return parentMapID
    end
    parentMapCache[mapID] = false
    return nil
end

function MapPinProvider:GetDisplayableMapForPlayer()
    local mapID = C_Map.GetBestMapForUnit("player")
    while mapID and mapID > 0 do
        if C_Map.MapHasArt and C_Map.MapHasArt(mapID) then
            return mapID
        end
        mapID = self:GetParentMapID(mapID)
    end

    return C_Map.GetFallbackWorldMapID and C_Map.GetFallbackWorldMapID() or nil
end

function MapPinProvider:GetMoreSpecificChildMapIDs(mapID, childMapType)
    local cacheKey = tostring(mapID) .. ":" .. tostring(childMapType or "all")
    local cached = childMapIDsCache[cacheKey]
    if cached then
        return cached
    end

    local childMapIDs = {}
    local currentMapInfo = C_Map.GetMapInfo(mapID)
    local currentMapType = currentMapInfo and currentMapInfo.mapType
    local childMaps = C_Map.GetMapChildrenInfo(mapID, childMapType)

    if childMaps then
        for _, childInfo in ipairs(childMaps) do
            local resolvedChildMapType = childInfo.mapType
            if not resolvedChildMapType then
                local childMapInfo = C_Map.GetMapInfo(childInfo.mapID)
                resolvedChildMapType = childMapInfo and childMapInfo.mapType
            end
            if not currentMapType or (resolvedChildMapType and resolvedChildMapType > currentMapType) then
                childMapIDs[#childMapIDs + 1] = childInfo.mapID
            end
        end
    end

    childMapIDsCache[cacheKey] = childMapIDs
    return childMapIDs
end

function MapPinProvider:ProjectMapPositionToAncestorView(sourceMapID, viewMapID, x, y)
    if sourceMapID == viewMapID then
        return true, x, y, "same_map"
    end

    local currentMapID = sourceMapID
    local projectedX = x
    local projectedY = y

    while currentMapID and currentMapID ~= viewMapID do
        local parentMapID = self:GetParentMapID(currentMapID)
        if not parentMapID then
            return false, nil, nil, "no_parent_path"
        end

        local ok, nextX, nextY, reason = ProjectViaRect(currentMapID, parentMapID, projectedX, projectedY)
        if not ok then
            return false, nil, nil, reason
        end

        projectedX = nextX
        projectedY = nextY
        currentMapID = parentMapID
    end

    if currentMapID ~= viewMapID then
        return false, nil, nil, "no_parent_path"
    end

    return true, projectedX, projectedY, "rect_projection"
end

function MapPinProvider:ProjectVendorPinToZoneView(viewMapID, vendorMapID, x, y)
    return self:ProjectMapPositionToAncestorView(vendorMapID, viewMapID, x, y)
end

function MapPinProvider:ProjectZoneBadgeToContinentView(viewMapID, zoneMapID)
    local ok, x, y, reason = self:ProjectMapPositionToAncestorView(zoneMapID, viewMapID, 0.5, 0.5)
    if ok then
        return true, x, y, reason
    end

    local manual = self.manualZoneCenters[zoneMapID]
    if manual and manual[viewMapID] then
        return true, manual[viewMapID].x, manual[viewMapID].y, "manual_zone_center"
    end

    return false, nil, nil, reason
end

function MapPinProvider:ProjectZoneBadgeToWorldView(zoneMapID)
    local continentMapID = self.GetContinentForZone(zoneMapID)
    if not continentMapID then
        return false, nil, nil, "no_parent_path"
    end

    if self.excludedContinents[continentMapID] then
        return false, nil, nil, "excluded_continent"
    end

    local ok, x, y, reason = self:ProjectMapPositionToAncestorView(zoneMapID, 947, 0.5, 0.5)
    if ok then
        return true, x, y, reason
    end

    local manual = self.manualZoneCenters[zoneMapID]
    if manual and manual[continentMapID] then
        local parentOk, parentX, parentY = self:ProjectMapPositionToAncestorView(
            continentMapID,
            947,
            manual[continentMapID].x,
            manual[continentMapID].y
        )
        if parentOk then
            return true, parentX, parentY, "manual_zone_center"
        end
    end

    return false, nil, nil, reason
end

function MapPinProvider:ProjectContinentBadgeToWorldView(continentMapID)
    if self.excludedContinents[continentMapID] then
        return false, nil, nil, "excluded_continent"
    end

    local ok, x, y, reason = self:ProjectMapPositionToAncestorView(continentMapID, 947, 0.5, 0.5)
    if ok then
        return true, x, y, reason
    end

    local manualPos = self.offWorldContinentPositions[continentMapID]
    if manualPos then
        return true, manualPos.x, manualPos.y, "manual_continent_position"
    end

    return false, nil, nil, reason
end

-- Native world-map pins
-- Homestead uses a self-managed pool instead of WorldMapFrame.pinPools to
-- avoid tainting Blizzard's protected map pin state.
-------------------------------------------------------------------------------

-- Plain-frame world-map wrappers.
-- No MapCanvasPinMixin, no AddDataProvider, no AcquirePin — these all enter
-- Blizzard's managed pin lifecycle which calls protected SetPassThroughButtons
-- in combat. Plain frames parented to the canvas with manual SetPoint avoid
-- the entire taint path.
-------------------------------------------------------------------------------

local nativePins = {}          -- active wrapper frames
local nativePinPool = {}       -- recycled wrapper frames
-- Blizzard's map pin frame levels (MEDIUM strata). Per HS-319
-- (Home_Dev/reference/MAP_LAYERING_STUDY.md, verified against Blizzard
-- source):
--   Area POI:    2023
--   Map Link:    2025
--   Encounter:   2026
-- Wrapper below = 2023 (bare positioning container, no textures); the
-- visible content frame is reparented onto it at wrapper+1 = 2024 (see
-- PlaceNativePin) — 2024 is the only level that matters visually. 2024 is
-- one level ABOVE Area POI (deterministic win over that dense class) and
-- exactly TIES Gossip (2024); sibling order vs Gossip at that tie is
-- creation-order dependent/unspecified. Quests, world quests, vignettes,
-- and waypoints already sit at 2025+, so they still outrank Homestead.
-- Intentional placement (HS-319 ruling) — do not change the level to chase
-- the old "parity with Area POI" language this replaced.
--
-- Constants below Vignette are patch-stable; PIN_FRAME_LEVEL_ACTIVE_QUEST
-- and above are runtime-sized (C_QuestLog.GetMaxNumQuests()) and vary.
local HOMESTEAD_WORLD_PIN_STRATA = "MEDIUM"
local HOMESTEAD_WORLD_PIN_FRAME_LEVEL = 2023


local function GetCanvasAndContainer()
    if not WorldMapFrame then return nil, nil end
    local canvas = WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas() or nil
    local container = WorldMapFrame.GetCanvasContainer and WorldMapFrame:GetCanvasContainer() or nil
    return canvas, container
end

local function AcquireNativePin()
    local canvas, container = GetCanvasAndContainer()
    if not canvas or not container then return nil end
    local wrapper = table.remove(nativePinPool)
    if not wrapper then
        wrapper = CreateFrame("Frame", nil, canvas)
    end
    wrapper:SetParent(canvas)
    if wrapper.SetIgnoreParentScale then
        wrapper:SetIgnoreParentScale(false)
    end
    local canvasEffectiveScale = canvas:GetEffectiveScale() or 1
    local uiEffectiveScale = UIParent:GetEffectiveScale() or 1
    if canvasEffectiveScale > 0 then
        wrapper:SetScale(uiEffectiveScale / canvasEffectiveScale)
    else
        wrapper:SetScale(1)
    end
    local strata = HOMESTEAD_WORLD_PIN_STRATA
    local level = HOMESTEAD_WORLD_PIN_FRAME_LEVEL
    wrapper:SetFrameStrata(strata)
    wrapper:SetFrameLevel(level)
    wrapper:Show()
    nativePins[#nativePins + 1] = wrapper
    return wrapper
end

local function PositionWrapper(wrapper, normX, normY)
    -- Match Blizzard's map-pin placement model:
    -- use full canvas coordinates, divided by the wrapper's counter-scale.
    local canvas = wrapper:GetParent()
    if not canvas then
        wrapper:Hide()
        return false
    end
    local width = canvas:GetWidth()
    local height = canvas:GetHeight()
    if not width or not height or width <= 0 or height <= 0 then
        wrapper:Hide()
        return false
    end
    wrapper.__hsNormX = normX
    wrapper.__hsNormY = normY
    local pinScale = wrapper:GetScale()
    if not pinScale or pinScale <= 0 then pinScale = 1 end
    wrapper:ClearAllPoints()
    wrapper:SetPoint("CENTER", canvas, "TOPLEFT",
        (width * normX) / pinScale,
        -(height * normY) / pinScale)
    wrapper:Show()
    return true
end

local function ReleaseAllNativePins()
    for i = #nativePins, 1, -1 do
        local wrapper = nativePins[i]
        if wrapper.icon then
            wrapper.icon:Hide()
            wrapper.icon:SetParent(UIParent)
            wrapper.icon:ClearAllPoints()
            wrapper.icon = nil
        end
        wrapper.__hsNormX = nil
        wrapper.__hsNormY = nil
        wrapper:Hide()
        wrapper:ClearAllPoints()
        wrapper:SetParent(UIParent)
        nativePinPool[#nativePinPool + 1] = wrapper
        nativePins[i] = nil
    end
end

-- Reposition all active wrappers from stored normalized coords.
-- Called when canvas size changes (maximize/minimize) without rebuilding data.
function MapPinProvider.RepositionWorldMapPins()
    local canvas = GetCanvasAndContainer()
    if not canvas then return end
    local width = canvas:GetWidth()
    local height = canvas:GetHeight()
    if not width or not height or width <= 0 or height <= 0 then return end
    local canvasEffectiveScale = canvas:GetEffectiveScale() or 1
    local uiEffectiveScale = UIParent:GetEffectiveScale() or 1
    local newScale = 1
    if canvasEffectiveScale > 0 then
        newScale = uiEffectiveScale / canvasEffectiveScale
    end
    for _, wrapper in ipairs(nativePins) do
        if wrapper.__hsNormX and wrapper.__hsNormY then
            -- HS-274 follow-up: this now runs on every canvas-scale tick during
            -- a zoom (previously only on rare resize/maximize), so the parent
            -- and ignore-parent-scale calls -- one-time setup from Acquire that
            -- never actually changes mid-gesture -- were re-issued dozens of
            -- times per second per pin, generating enough garbage to visibly
            -- bloat AddOn memory until the next GC pass. Guard them; SetScale
            -- and the anchor still need every tick, since those genuinely track
            -- the live zoom.
            if wrapper:GetParent() ~= canvas then
                wrapper:SetParent(canvas)
            end
            if wrapper.SetIgnoreParentScale and not wrapper.__hsIgnoreParentScaleSet then
                wrapper:SetIgnoreParentScale(false)
                wrapper.__hsIgnoreParentScaleSet = true
            end
            wrapper:SetScale(newScale)
            wrapper:ClearAllPoints()
            wrapper:SetPoint("CENTER", canvas, "TOPLEFT",
                (width * wrapper.__hsNormX) / newScale,
                -(height * wrapper.__hsNormY) / newScale)
        end
    end
end

-- HS-536: overlapping-pin nudge. Vendors that stand side by side get map
-- positions about 0.001 apart, which draws their pins on top of each other.
-- AssignOverlapNudge gives pins that overlap a small screen-pixel offset
-- (nudgeX/nudgeY, +x right, +y up). Display only: the caller passes it to
-- PlaceNativePin / SetPoint and never adds it to a stored coordinate, so
-- waypoints, tooltips and distances keep the real position. Pixels, not map
-- units, for the reason PlaceNativePin explains.
--
-- Placement is geometric. Pins closer than OVERLAP_THRESHOLD (normalized map
-- units) form pairs; a few relaxation passes push each too-close pair apart
-- along its own axis until its drawn distance is NUDGE_SPACING. A pair
-- therefore keeps its order and side, and a chained row of pins moves only
-- as far as it needs to rather than collapsing onto a ring. No pin moves
-- farther than NUDGE_MAX_OFFSET from its real position.
--
-- OVERLAP_THRESHOLD: the default pin is 10 px (setting range 8-18) on a
-- canvas about NUDGE_REF_CANVAS_PX wide at default zoom, so 0.005 is half a
-- pin: closer than that, one pin hides at least half of the other. The two
-- HS-536 pairs are 0.0011 and 0.0013 apart.
-- NUDGE_SPACING is the largest pin the size slider allows, so a nudged pair
-- never covers itself at any setting.
-- NUDGE_CROWD_NEIGHBORS: a group in which any pin has this many other pins
-- within reach is a crowd and is left un-nudged (see the relaxation below).
-- NUDGE_MAX_OFFSET is 1.3 pin widths: a pair needs 9 px, a ring of 8 fits
-- inside it, and a bigger crowd stays partly overlapped instead of scattering.
-- Pixel gaps are measured at NUDGE_REF_CANVAS_PX; at other zooms the real gap
-- differs, but the offset always pushes outward along the pair's axis, so the
-- order is kept and the drawn gap is never smaller than the real one.
local OVERLAP_THRESHOLD = 0.005
local NUDGE_SPACING = 18
local NUDGE_MAX_OFFSET = 24
local NUDGE_REF_CANVAS_PX = 1000
local NUDGE_CROWD_NEIGHBORS = 3
-- The vendor-data oracle needs at least 15 passes; 24 leaves margin.
local NUDGE_PASSES = 24
local GOLDEN_ANGLE = 2.399963

local nudgeSort = {}
local nudgePairA = {}
local nudgePairB = {}
local nudgePosX = {}
local nudgePosY = {}
local nudgeOffX = {}
local nudgeOffY = {}
local nudgeInPair = {}
local nudgeDispX = {}
local nudgeDispY = {}
local nudgeContacts = {}
local nudgeParent = {}
local nudgeCrowd = {}
local sortXKey, sortYKey

local function SortByX(a, b)
    local ax, bx = a[sortXKey], b[sortXKey]
    if ax ~= bx then return ax < bx end
    local ay, by = a[sortYKey], b[sortYKey]
    if ay ~= by then return ay < by end
    return (a.vendor.npcID or 0) < (b.vendor.npcID or 0)
end

local function NudgeFind(i)
    while nudgeParent[i] ~= i do
        nudgeParent[i] = nudgeParent[nudgeParent[i]]
        i = nudgeParent[i]
    end
    return i
end

local function WipeNudgeSort(n)
    for i = 1, n do nudgeSort[i] = nil end
end

-- pins: array of records with vendor.npcID, plus the numeric fields named by
-- xKey/yKey (map y grows downward), and optionally mapKey (pins on different
-- maps never pair). Sets pin.nudgeX/pin.nudgeY on every pin that overlaps
-- another and clears them on all others. One sort and a sweep per call:
-- O(n log n + pairs); the scratch tables are reused, not reallocated.
function MapPinProvider.AssignOverlapNudge(pins, xKey, yKey, mapKey)
    local n = 0
    for i = 1, #pins do
        local pin = pins[i]
        pin.nudgeX, pin.nudgeY = nil, nil
        local x, y = pin[xKey], pin[yKey]
        if pin.vendor and type(x) == "number" and type(y) == "number" and x == x and y == y then
            n = n + 1
            nudgeSort[n] = pin
        end
    end
    if n < 2 then
        WipeNudgeSort(n)
        return
    end

    sortXKey, sortYKey = xKey, yKey
    table.sort(nudgeSort, SortByX)

    for i = 1, n do
        local pin = nudgeSort[i]
        nudgePosX[i] = pin[xKey] * NUDGE_REF_CANVAS_PX
        nudgePosY[i] = -pin[yKey] * NUDGE_REF_CANVAS_PX
        nudgeOffX[i], nudgeOffY[i] = 0, 0
        nudgeInPair[i] = false
    end

    -- Pass 1: which pins overlap another (closer than OVERLAP_THRESHOLD)?
    local anyOverlap = false
    for i = 1, n do
        local a = nudgeSort[i]
        local ax, ay = a[xKey], a[yKey]
        local am = mapKey and a[mapKey]
        for j = i + 1, n do
            local b = nudgeSort[j]
            local dx = b[xKey] - ax
            if dx >= OVERLAP_THRESHOLD then break end
            local dy = b[yKey] - ay
            if (not mapKey or b[mapKey] == am)
                    and dx * dx + dy * dy < OVERLAP_THRESHOLD * OVERLAP_THRESHOLD then
                nudgeInPair[i], nudgeInPair[j] = true, true
                anyOverlap = true
            end
        end
    end
    if not anyOverlap then
        WipeNudgeSort(n)
        return
    end

    -- Pass 2: the pairs the relaxation keeps apart. Only overlapping pins
    -- move, but they keep NUDGE_SPACING from every pin within reach, not
    -- just OVERLAP_THRESHOLD: from each other, so a chained row spreads in
    -- order instead of leapfrogging, and from pins that do not overlap
    -- anything, which act as fixed anchors (they never move and get no
    -- nudge), so a pin is never pushed onto a neighbor just outside the
    -- threshold.
    -- A mover can travel NUDGE_MAX_OFFSET, so pins out to that much beyond
    -- NUDGE_SPACING can end up in its way: they are gathered too. Only pairs
    -- within NUDGE_SPACING count as crowd contacts.
    local reach = (NUDGE_SPACING + NUDGE_MAX_OFFSET) / NUDGE_REF_CANVAS_PX
    local pairCount = 0
    for i = 1, n do
        local a = nudgeSort[i]
        local ax, ay = a[xKey], a[yKey]
        local am = mapKey and a[mapKey]
        for j = i + 1, n do
            local b = nudgeSort[j]
            local dx = b[xKey] - ax
            if dx >= reach then break end
            local dy = b[yKey] - ay
            if (nudgeInPair[i] or nudgeInPair[j]) and (not mapKey or b[mapKey] == am)
                    and dx * dx + dy * dy < reach * reach then
                pairCount = pairCount + 1
                nudgePairA[pairCount], nudgePairB[pairCount] = i, j
            end
        end
    end
    -- Crowds stay as they are. A group of connected overlapping pins in which
    -- any pin has NUDGE_CROWD_NEIGHBORS or more other pins within reach
    -- (movers or anchors) cannot be spread without leaving some pin worse off
    -- than it is today, so the whole group gets no nudge.
    for i = 1, n do
        nudgeParent[i] = i
        nudgeContacts[i] = 0
    end
    local contactPx = NUDGE_SPACING
    for p = 1, pairCount do
        local i, j = nudgePairA[p], nudgePairB[p]
        local cx, cy = nudgePosX[j] - nudgePosX[i], nudgePosY[j] - nudgePosY[i]
        if cx * cx + cy * cy < contactPx * contactPx then
            nudgeContacts[i], nudgeContacts[j] = nudgeContacts[i] + 1, nudgeContacts[j] + 1
            if nudgeInPair[i] and nudgeInPair[j] then
                local ri, rj = NudgeFind(i), NudgeFind(j)
                if ri ~= rj then nudgeParent[rj] = ri end
            end
        end
    end
    for i = 1, n do
        nudgeCrowd[i] = false
    end
    for i = 1, n do
        if nudgeInPair[i] and nudgeContacts[i] >= NUDGE_CROWD_NEIGHBORS then
            nudgeCrowd[NudgeFind(i)] = true
        end
    end
    for i = 1, n do
        if nudgeInPair[i] and nudgeCrowd[NudgeFind(i)] then nudgeInPair[i] = false end
    end

    for _ = 1, NUDGE_PASSES do
        for i = 1, n do
            nudgeDispX[i], nudgeDispY[i], nudgeContacts[i] = 0, 0, 0
        end
        for p = 1, pairCount do
            local i, j = nudgePairA[p], nudgePairB[p]
            local dx = nudgePosX[j] + nudgeOffX[j] - nudgePosX[i] - nudgeOffX[i]
            local dy = nudgePosY[j] + nudgeOffY[j] - nudgePosY[i] - nudgeOffY[i]
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < NUDGE_SPACING - 0.01 then
                local ux, uy
                if dist < 1e-6 then
                    -- Seeded from the two npcIDs so the direction survives
                    -- a refresh that changes the other pins on the map.
                    local angle = ((nudgeSort[i].vendor.npcID or 0) + (nudgeSort[j].vendor.npcID or 0)) % 4096
                        * GOLDEN_ANGLE
                    ux, uy = math.cos(angle), math.sin(angle)
                else
                    ux, uy = dx / dist, dy / dist
                end
                -- Two movers share the push; against an anchor the mover
                -- takes all of it.
                local movesI, movesJ = nudgeInPair[i], nudgeInPair[j]
                local push = (NUDGE_SPACING - dist) / ((movesI and movesJ) and 2 or 1)
                if movesI then
                    nudgeDispX[i], nudgeDispY[i] = nudgeDispX[i] - ux * push, nudgeDispY[i] - uy * push
                    nudgeContacts[i] = nudgeContacts[i] + 1
                end
                if movesJ then
                    nudgeDispX[j], nudgeDispY[j] = nudgeDispX[j] + ux * push, nudgeDispY[j] + uy * push
                    nudgeContacts[j] = nudgeContacts[j] + 1
                end
            end
        end
        local moved = false
        for i = 1, n do
            local contacts = nudgeContacts[i]
            if contacts > 0 then
                moved = true
                -- Average the pushes: a pin squeezed by several neighbors
                -- must not take all of their corrections at once.
                local offX = nudgeOffX[i] + nudgeDispX[i] / contacts
                local offY = nudgeOffY[i] + nudgeDispY[i] / contacts
                local mag = math.sqrt(offX * offX + offY * offY)
                if mag > NUDGE_MAX_OFFSET then
                    offX, offY = offX * NUDGE_MAX_OFFSET / mag, offY * NUDGE_MAX_OFFSET / mag
                end
                nudgeOffX[i], nudgeOffY[i] = offX, offY
            end
        end
        if not moved then break end
    end

    for i = 1, n do
        if nudgeInPair[i] then
            local pin = nudgeSort[i]
            pin.nudgeX = math.floor(nudgeOffX[i] * 100 + 0.5) / 100
            pin.nudgeY = math.floor(nudgeOffY[i] * 100 + 0.5) / 100
        end
    end
    WipeNudgeSort(n)
end

-- HS-536: final minimap position of a nudged pin. diffX/diffY are the pin's
-- real position in minimap-radius units (already tested for range, and
-- already clamped to the rim for floatOnEdge pins). The pixel nudge is
-- rotated with the minimap, added to the drawn position only, and the result
-- is clamped back to the rim when it would land past the mask (the same
-- 0.9 rim and shape rule DrawPin uses). isRound is DrawPin's own value.
-- The nudge is sized for world-map pins of NUDGE_SPACING px; pinSize, the
-- minimap pin's drawn width, scales it so a pair ends up one minimap pin
-- apart (half a pin each) instead of a world-map pin apart.
function MapPinProvider.NudgeMinimapPosition(diffX, diffY, nudgeX, nudgeY, minimapWidth, minimapHeight,
        facingSin, facingCos, rotate, isRound, pinSize)
    if pinSize then
        local scale = pinSize / NUDGE_SPACING
        nudgeX, nudgeY = nudgeX * scale, nudgeY * scale
    end
    if rotate then
        nudgeX, nudgeY = nudgeX * facingCos + nudgeY * facingSin, nudgeY * facingCos - nudgeX * facingSin
    end
    local x = diffX + nudgeX / minimapWidth
    local y = diffY - nudgeY / minimapHeight
    local dist
    if isRound then
        dist = (x * x + y * y) / 0.81
    else
        dist = math.max(x * x, y * y) / 0.81
    end
    if dist > 1 then
        dist = math.sqrt(dist)
        x, y = x / dist, y / dist
    end
    return x, y
end

-- Pin Placement API
-------------------------------------------------------------------------------

-- Place a plain-frame world-map pin. Attaches the content frame as a child.
-- Optional iconOffsetX/iconOffsetY (literal pixels, +x = right, +y = up —
-- standard SetPoint offset convention) shift the content frame off the
-- wrapper's CENTER without moving the wrapper itself. The wrapper is the
-- thing anchored to the map's (x, y) — it stays at the
-- EXACT anchor, always tracking the true world position correctly across
-- zoom (PositionWrapper already multiplies normalized coords by live canvas
-- dimensions). The wrapper is also scale-normalized to real screen pixels
-- (AcquireNativePin's SetScale(uiEffectiveScale / canvasEffectiveScale)), so
-- a literal pixel offset applied HERE — to the content frame's point,
-- post-wrapper-positioning — renders as the same constant screen distance
-- at every zoom level. A normalized map-coordinate offset baked into (x, y)
-- instead (the original approach) does NOT: it's a fraction of the current
-- canvas width/height, which grows with zoom, so the on-screen gap grows
-- with it — that was the boss/entrance-pin zoom-drift bug this fixes.
function MapPinProvider.PlaceNativePin(frame, x, y, iconOffsetX, iconOffsetY)
    local wrapper = AcquireNativePin()
    if not wrapper then return nil end

    -- Size wrapper to content frame
    local iconW = frame and frame.GetWidth and frame:GetWidth() or 1
    local iconH = frame and frame.GetHeight and frame:GetHeight() or 1
    local iconScale = frame and frame.GetScale and frame:GetScale() or 1
    wrapper:SetSize(math.max(1, iconW * iconScale), math.max(1, iconH * iconScale))

    -- Attach content frame. The content frame is the same frame EnableMouse
    -- is set on (see PinFrameFactory), so offsetting ITS point — rather than
    -- e.g. just the icon texture inside a frame that stays centered — keeps
    -- the hit-rect glued to the visible icon at every offset.
    wrapper.icon = frame
    frame:SetParent(wrapper)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", wrapper, "CENTER", iconOffsetX or 0, iconOffsetY or 0)
    local strata = wrapper:GetFrameStrata()
    if frame.SetFrameStrata then frame:SetFrameStrata(strata) end
    if frame.SetFrameLevel then frame:SetFrameLevel(wrapper:GetFrameLevel() + 1) end
    frame:Show()

    -- Position on canvas
    PositionWrapper(wrapper, x, y)
    return wrapper
end

function MapPinProvider.GetNativeWorldCoordinates(mapID, x, y)
    local pos = _G.CreateVector2D(x, y)
    local instanceID, worldPos = C_Map.GetWorldPosFromMapPos(mapID, pos)
    if not instanceID or not worldPos then
        return nil, nil, nil
    end

    local worldPosX, worldPosY = worldPos:GetXY()
    if not worldPosX or not worldPosY then
        return nil, nil, nil
    end

    -- Match the UnitPosition axis order used by the minimap overlay.
    return worldPosY, worldPosX, instanceID
end

-- Clear all native world-map pins.
-- NOTE: Clear is not namespace-scoped (Homestead single-namespace only).
function MapPinProvider.ClearWorldMapPins(_)
    ReleaseAllNativePins()
end

-- Native minimap overlay manages its own frames. Keep this as a stable no-op
-- API so existing clear paths do not need to special-case the new overlay.
function MapPinProvider.ClearMinimapPins(_)
end

