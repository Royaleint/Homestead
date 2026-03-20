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

local function ProjectViaRect(sourceMapID, destMapID, x, y)
    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(sourceMapID, destMapID)
    if minX == nil or maxX == nil or minY == nil or maxY == nil then
        return false, nil, nil, "nil_rect"
    end

    if minX == maxX and minY == maxY then
        return false, nil, nil, "degenerate_rect"
    end

    return true,
        minX + ((maxX - minX) * x),
        minY + ((maxY - minY) * y),
        "rect_projection"
end

function MapPinProvider:GetParentMapID(mapID)
    local mapInfo = C_Map.GetMapInfo(mapID)
    local parentMapID = mapInfo and mapInfo.parentMapID
    if parentMapID and parentMapID > 0 then
        return parentMapID
    end
    return nil
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
-- Blizzard's map pin frame levels (MEDIUM strata):
--   Canvas base:    3
--   Area POI:       2023
--   Event POI:      2737
-- Homestead shares the Area POI level so neither dominates the other.
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
            wrapper:SetParent(canvas)
            if wrapper.SetIgnoreParentScale then
                wrapper:SetIgnoreParentScale(false)
            end
            wrapper:SetScale(newScale)
            wrapper:ClearAllPoints()
            wrapper:SetPoint("CENTER", canvas, "TOPLEFT",
                (width * wrapper.__hsNormX) / newScale,
                -(height * wrapper.__hsNormY) / newScale)
        end
    end
end

-- Pin Placement API
-------------------------------------------------------------------------------

-- Place a plain-frame world-map pin. Attaches the content frame as a child.
function MapPinProvider.PlaceNativePin(frame, x, y)
    local wrapper = AcquireNativePin()
    if not wrapper then return nil end

    -- Size wrapper to content frame
    local iconW = frame and frame.GetWidth and frame:GetWidth() or 1
    local iconH = frame and frame.GetHeight and frame:GetHeight() or 1
    local iconScale = frame and frame.GetScale and frame:GetScale() or 1
    wrapper:SetSize(math.max(1, iconW * iconScale), math.max(1, iconH * iconScale))

    -- Attach content frame
    wrapper.icon = frame
    frame:SetParent(wrapper)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", wrapper)
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

