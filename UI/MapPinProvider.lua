--[[
    Homestead - MapPinProvider
    Unified coordinate intelligence and pin placement module

    Single source of truth for:
    - Geography lookup tables (continent exclusions, merges, manual centers)
    - Zone-continent reverse index
    - HBD map support detection and coordinate projection
    - Native pin fallback (for maps HBD can't handle)
    - Pin placement API (HBD world map, minimap, native fallback)
    - Pin clustering (radial arc spread for co-located vendors)

    No events registered. No SavedVariables access. Static module with no
    Initialize() — all setup runs at file load time.

    NOTE: ClearWorldMapPins clears native pins globally by template, not per
    namespace. This module is designed for Homestead's single-namespace use.
]]

local _, HA = ...
local MapPinProvider = {}
HA.MapPinProvider = MapPinProvider

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

local pairs, ipairs = pairs, ipairs
local math_sin, math_cos, math_pi = math.sin, math.cos, math.pi
local math_max, math_min = math.max, math.min
local Constants = HA.Constants

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
    [572] = true,   -- Draenor (alternate dimension, HBD works at zone level)
    [1550] = true,  -- Shadowlands (afterlife dimension)
}

-- Continents whose vendor counts and zone badges roll into a parent continent.
-- Argus is accessed via Dalaran (Broken Isles) — logically part of BI on the world map.
MapPinProvider.continentMergesInto = {
    [905] = 619,   -- Argus → Broken Isles
}

-- Continents whose zone badges should also be shown on another continent map.
-- This is a display-only overlay on continent views; it does not merge totals.
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
            [2413] = true,   -- Harandar sub-zone
        },
    },
}

-- Off-world continents with manual positions on the Azeroth world map (mapID 947).
-- These are NOT in excludedContinents — they get badges via native pin fallback.
-- Argus zones (830, 882, 885) map to continent 905 in zoneToContinent.
MapPinProvider.offWorldContinentPositions = {
    -- [905] removed — Argus counts merge into Broken Isles (continentMergesInto)
    -- [2537] removed — Midnight/Quel'Thalas handed to HBD; manual position was incorrect
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
    [709] = { [619] = { x = 0.52, y = 0.50 } },  -- The Wandering Isle (Monk)
    [717] = { [619] = { x = 0.44, y = 0.52 } },  -- Dreadscar Rift (Warlock)
    [720] = { [619] = { x = 0.54, y = 0.45 } },  -- The Fel Hammer (Demon Hunter)
    [726] = { [619] = { x = 0.42, y = 0.45 } },  -- The Maelstrom (Shaman)
}

-- Notes shown in zone badge tooltips for special locations (class halls, etc.)
MapPinProvider.zoneNotes = {
    -- Class halls physically on the Broken Isles
    [739] = "Hunter Order Hall — Trueshot Lodge in Highmountain",
    [747] = "Druid Order Hall — Dreamwalk spell",
    [647] = "Death Knight Order Hall — Death Gate spell",
    [695] = "Warrior Order Hall — Jump from Krasus' Landing, Dalaran",
    -- Class halls under/inside Dalaran
    [626] = "Rogue Order Hall — Entrance in Dalaran sewers",
    [734] = "Mage Order Hall — Portal from Dalaran",
    -- Class halls off-world, accessed via Dalaran
    [24]  = "Paladin Order Hall — Portal from Dalaran",
    [702] = "Priest Order Hall — Portal from Dalaran",
    [709] = "Monk Order Hall — Zen Pilgrimage spell",
    [717] = "Warlock Order Hall — Portal from Dalaran",
    [720] = "Demon Hunter Order Hall — Portal from Krasus' Landing, Dalaran",
    [726] = "Shaman Order Hall — Portal from Dalaran",
}

-- Exclude continents in separate world spaces where cross-zone minimap translation
-- can collapse pins onto the player arrow.
MapPinProvider.minimapExcludedContinents = {
    [101] = true,   -- Outland (separate world space)
    [572] = true,   -- Draenor (alternate dimension)
    [1550] = true,  -- Shadowlands (afterlife dimension)
}

-------------------------------------------------------------------------------
-- HBD Map Support Cache
-------------------------------------------------------------------------------

local hbdMapSupport = {}

-- Check whether HBD can translate coordinates for a given mapID.
-- Caches result per session since map data is static.
function MapPinProvider.IsMapSupported(mapID)
    if hbdMapSupport[mapID] ~= nil then return hbdMapSupport[mapID] end
    local wx = HBD:GetWorldCoordinatesFromZone(0.5, 0.5, mapID)
    hbdMapSupport[mapID] = (wx ~= nil)
    return hbdMapSupport[mapID]
end

-------------------------------------------------------------------------------
-- Coordinate Projection
-------------------------------------------------------------------------------

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
-- NOTE: No HBD projection fallback — exact semantics from BadgeCalculation.
function MapPinProvider:GetZoneCenterOnMap(zoneMapID, parentMapID)
    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(zoneMapID, parentMapID)
    -- Guard against degenerate rects (e.g. 0,0,0,0 returned for phased/instanced zones
    -- that the current character cannot access). In Lua, 0 is truthy, so we must
    -- explicitly reject a collapsed rect to avoid placing badges at (0, 0).
    if minX and maxX and minY and maxY and (minX ~= maxX or minY ~= maxY) then
        return { x = (minX + maxX) / 2, y = (minY + maxY) / 2 }
    end
    -- Fallback for cross-instance/phased maps (e.g. Argus zones on Argus continent,
    -- or Trueshot Lodge on Broken Isles for non-hunters)
    local manual = self.manualZoneCenters[zoneMapID]
    if manual and manual[parentMapID] then
        return manual[parentMapID]
    end
    return nil
end

-------------------------------------------------------------------------------
-- Native Pin Fallback (for maps HBD can't handle, e.g. Argus zones)
-- HBD stores zero-dimension map data for cross-instance zones, causing
-- GetWorldCoordinatesFromZone() to return nil and AddWorldMapIconMap() to
-- silently bail. This fallback uses WoW's native MapCanvasPin system
-- with zone-normalized (0-1) coordinates directly.
-------------------------------------------------------------------------------

local NATIVE_PIN_TEMPLATE = "HomesteadNativePinTemplate"

-- Native pin mixin (mirrors HBD's pin behavior)
local nativePinMixin = CreateFromMixins(MapCanvasPinMixin)

function nativePinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, 1.0, 1.2)
end

function nativePinMixin:OnAcquired(icon, x, y)
    self:SetPosition(x, y)
    self.icon = icon
    icon:SetParent(self)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", self)
    icon:Show()
end

function nativePinMixin:OnReleased()
    if self.icon then
        self.icon:Hide()
        self.icon:SetParent(UIParent)
        self.icon:ClearAllPoints()
        self.icon = nil
    end
end

-- Suppress in-combat errors (same as HBD)
nativePinMixin.SetPassThroughButtons = function() end

-- Create pin pool (deferred registration to avoid WorldMapFrame taint at load)
local nativePool
if CreateUnsecuredRegionPoolInstance then
    nativePool = CreateUnsecuredRegionPoolInstance(NATIVE_PIN_TEMPLATE)
else
    nativePool = CreateFramePool("FRAME")
end
nativePool.parent = WorldMapFrame:GetCanvas()
nativePool.createFunc = function()
    local f = CreateFrame("Frame", nil, WorldMapFrame:GetCanvas())
    f:SetSize(1, 1)
    return Mixin(f, nativePinMixin)
end
nativePool.resetFunc = function(pool, pin)
    pin:Hide()
    pin:ClearAllPoints()
    pin:OnReleased()
    pin.pinTemplate = nil
    pin.owningMap = nil
end
-- Pre-11.x compat names
nativePool.creationFunc = nativePool.createFunc
nativePool.resetterFunc = nativePool.resetFunc

-- Lazy registration: writing to WorldMapFrame.pinPools at file load taints the
-- protected frame, causing "secret number value tainted by Homestead" errors in
-- Blizzard tooltip/widget code. Defer until first native pin use.
local nativePoolRegistered = false
local function EnsureNativePoolRegistered()
    if nativePoolRegistered then return end
    nativePoolRegistered = true
    WorldMapFrame.pinPools[NATIVE_PIN_TEMPLATE] = nativePool -- luacheck: ignore 122
end

-------------------------------------------------------------------------------
-- Pin Placement API
-------------------------------------------------------------------------------

-- Place a pin using HBD if possible, native fallback otherwise.
-- Returns true if the pin was placed.
function MapPinProvider.PlaceWorldMapPin(namespace, frame, mapID, x, y, showFlag)
    if MapPinProvider.IsMapSupported(mapID) then
        HBDPins:AddWorldMapIconMap(namespace, frame, mapID, x, y, showFlag)
        return true
    end
    -- Native fallback: only works when viewing THIS exact map
    local currentMapID = WorldMapFrame:GetMapID()
    if currentMapID == mapID then
        EnsureNativePoolRegistered()
        WorldMapFrame:AcquirePin(NATIVE_PIN_TEMPLATE, frame, x, y)
        return true
    end
    return false
end

-- Place a native pin directly (no HBD, no fallback check).
function MapPinProvider.PlaceNativePin(frame, x, y)
    EnsureNativePoolRegistered()
    WorldMapFrame:AcquirePin(NATIVE_PIN_TEMPLATE, frame, x, y)
end

-- Place a minimap pin on a specific map via HBD.
function MapPinProvider.PlaceMinimapPin(namespace, frame, mapID, x, y, showInParent, floatOnEdge)
    HBDPins:AddMinimapIconMap(namespace, frame, mapID, x, y, showInParent, floatOnEdge)
end

-- Convert zone coordinates to world coordinates for cross-floor minimap placement.
-- Returns worldX, worldY, instanceID or nil (caller decides frame lifecycle).
function MapPinProvider.GetWorldCoordinatesForPin(x, y, mapID)
    return HBD:GetWorldCoordinatesFromZone(x, y, mapID)
end

-- Place a minimap pin using world coordinates (for cross-floor pins).
function MapPinProvider.PlaceMinimapPinWorld(namespace, frame, instanceID, worldX, worldY, floatOnEdge)
    HBDPins:AddMinimapIconWorld(namespace, frame, instanceID, worldX, worldY, floatOnEdge)
end

-- Place a world map pin via HBD directly (no native fallback).
-- Only use at call sites that were previously raw HBDPins:AddWorldMapIconMap.
function MapPinProvider.PlaceWorldMapPinDirect(namespace, frame, mapID, x, y, showFlag)
    HBDPins:AddWorldMapIconMap(namespace, frame, mapID, x, y, showFlag)
end

-- Clear all world map pins: HBD by namespace + native pins globally by template.
-- NOTE: Native pin clear is NOT namespace-scoped (Homestead single-namespace only).
function MapPinProvider.ClearWorldMapPins(namespace)
    HBDPins:RemoveAllWorldMapIcons(namespace)
    if nativePoolRegistered then
        WorldMapFrame:RemoveAllPinsByTemplate(NATIVE_PIN_TEMPLATE)
    end
end

-- Clear all minimap pins by namespace.
function MapPinProvider.ClearMinimapPins(namespace)
    HBDPins:RemoveAllMinimapIcons(namespace)
end

-------------------------------------------------------------------------------
-- Pin Clustering
-------------------------------------------------------------------------------

-- Pin clustering: group co-located vendors and spread them in a radial arc.
-- CLUSTER_RADIUS: normalized distance threshold — vendors within this distance
--   are considered co-located (0.010 comfortably covers all known stacking cases).
-- SPREAD_DIAMETER: minimum chord length between adjacent spread pins; just over
--   one 20px pin diameter so all pins are individually hoverable/clickable.
local PIN_CLUSTER_RADIUS    = 0.010
local PIN_CLUSTER_RADIUS_SQ = PIN_CLUSTER_RADIUS * PIN_CLUSTER_RADIUS  -- avoids sqrt in hot path
local PIN_SPREAD_DIAMETER   = 0.016

-- ClusterAndSpread: pre-process a list of pin entries, group nearby vendors
-- into clusters, and return a spread-position table keyed by npcID.
--
-- pinList:  array of { vendor=, coords={x,y}, vendorMapID= }
-- Returns:  table [npcID] = {x=, y=}
--
-- Algorithm: greedy single-pass — each vendor joins the first cluster whose
-- centroid is within PIN_CLUSTER_RADIUS; solo vendors pass through unchanged.
-- Clustering is performed per vendorMapID to avoid grouping vendors across maps.
-- Distance comparisons use squared distance (dx*dx+dy*dy < r*r) to avoid
-- math.sqrt in the inner loop — equivalent result, no transcendental overhead.
function MapPinProvider.ClusterAndSpread(pinList)
    if not pinList or #pinList == 0 then return {} end

    -- Partition by vendorMapID so vendors on different maps are never grouped.
    local byMap = {}
    for _, pin in ipairs(pinList) do
        local mid = pin.vendorMapID
        if not byMap[mid] then byMap[mid] = {} end
        byMap[mid][#byMap[mid] + 1] = pin
    end

    local positions = {}

    for _, mapPins in pairs(byMap) do
        -- Greedy clustering for this map.
        local clusters = {}

        for _, pin in ipairs(mapPins) do
            local placed = false
            for _, cluster in ipairs(clusters) do
                local dx = pin.coords.x - cluster.cx
                local dy = pin.coords.y - cluster.cy
                if dx * dx + dy * dy < PIN_CLUSTER_RADIUS_SQ then
                    cluster.members[#cluster.members + 1] = pin
                    -- Running centroid update.
                    local n = #cluster.members
                    cluster.cx = cluster.cx + (pin.coords.x - cluster.cx) / n
                    cluster.cy = cluster.cy + (pin.coords.y - cluster.cy) / n
                    placed = true
                    break
                end
            end
            if not placed then
                clusters[#clusters + 1] = {
                    cx      = pin.coords.x,
                    cy      = pin.coords.y,
                    members = { pin },
                }
            end
        end

        -- Assign spread positions.
        for _, cluster in ipairs(clusters) do
            local n = #cluster.members
            if n == 1 then
                local m = cluster.members[1]
                positions[m.vendor.npcID] = { x = m.coords.x, y = m.coords.y }
            else
                -- Radial arrangement: pins on a circle centred on the cluster centroid.
                -- Radius is the minimum so adjacent pins don't overlap:
                --   chord = 2*r*sin(π/n) >= PIN_SPREAD_DIAMETER  →  r = d/(2*sin(π/n))
                -- Pins start at top (-π/2) and are spaced evenly clockwise.
                local r = PIN_SPREAD_DIAMETER / (2 * math_sin(math_pi / n))
                for i, m in ipairs(cluster.members) do
                    local angle = (2 * math_pi * (i - 1) / n) - math_pi / 2
                    local spreadX = math_max(0.001, math_min(0.999, cluster.cx + r * math_cos(angle)))
                    local spreadY = math_max(0.001, math_min(0.999, cluster.cy + r * math_sin(angle)))
                    positions[m.vendor.npcID] = { x = spreadX, y = spreadY }
                end
            end
        end
    end

    return positions
end
