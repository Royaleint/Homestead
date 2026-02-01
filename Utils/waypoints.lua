--[[
    Homestead - Waypoints Utility
    Unified waypoint system supporting both native WoW waypoints and TomTom

    This utility provides a consistent API for waypoint management regardless
    of which waypoint system the player prefers to use.
]]

local addonName, HA = ...

-- Create Waypoints utility
local Waypoints = {}
HA.Waypoints = Waypoints

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

-- Default options
local defaults = {
    useTomTom = true,       -- Use TomTom if available
    useNative = true,       -- Use native WoW waypoints
    announceWaypoint = true, -- Print waypoint info to chat
    autoRemoveOnArrival = true, -- Remove waypoint when player arrives
    arrivalDistance = 0.01, -- Distance threshold for arrival (1% of map = ~10 yards)
}

-- Current waypoint state
local currentWaypoint = nil
local tomtomWaypoint = nil
local arrivalCheckTimer = nil

-------------------------------------------------------------------------------
-- TomTom Integration
-------------------------------------------------------------------------------

-- Check if TomTom addon is available
function Waypoints:IsTomTomAvailable()
    return TomTom and TomTom.AddWaypoint and TomTom.RemoveWaypoint and true or false
end

-- Add a TomTom waypoint
local function AddTomTomWaypoint(mapID, x, y, options)
    if not Waypoints:IsTomTomAvailable() then
        return nil
    end

    local opts = {
        title = options.title or "Waypoint",
        persistent = options.persistent or false,
        minimap = options.minimap ~= false,
        world = options.world ~= false,
        from = "Homestead",
    }

    -- TomTom expects coordinates in 0-1 format
    return TomTom:AddWaypoint(mapID, x, y, opts)
end

-- Remove a TomTom waypoint
local function RemoveTomTomWaypoint(uid)
    if uid and Waypoints:IsTomTomAvailable() then
        TomTom:RemoveWaypoint(uid)
    end
end

-------------------------------------------------------------------------------
-- Native Waypoint System
-------------------------------------------------------------------------------

-- Set native WoW waypoint using the supertracking system
local function SetNativeWaypoint(mapID, x, y, options)
    -- Clear existing user waypoint
    if C_Map.HasUserWaypoint and C_Map.HasUserWaypoint() then
        C_Map.ClearUserWaypoint()
    end

    -- Create new waypoint
    local mapPoint = UiMapPoint.CreateFromCoordinates(mapID, x, y)
    if not mapPoint then
        return false
    end

    C_Map.SetUserWaypoint(mapPoint)

    -- Enable supertracking
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end

    return true
end

-- Clear native WoW waypoint
local function ClearNativeWaypoint()
    if C_Map.HasUserWaypoint and C_Map.HasUserWaypoint() then
        C_Map.ClearUserWaypoint()
    end
    if C_SuperTrack then
        C_SuperTrack.ClearAllSuperTracked()
    end
end

-------------------------------------------------------------------------------
-- Arrival Detection
-------------------------------------------------------------------------------

-- Check if player has arrived at waypoint
local function CheckArrival()
    if not currentWaypoint then
        return false
    end

    local playerMapID = C_Map.GetBestMapForUnit("player")
    if playerMapID ~= currentWaypoint.mapID then
        return false
    end

    local playerPos = C_Map.GetPlayerMapPosition(playerMapID, "player")
    if not playerPos then
        return false
    end

    local dx = playerPos.x - currentWaypoint.x
    local dy = playerPos.y - currentWaypoint.y
    local distance = math.sqrt(dx*dx + dy*dy)

    local threshold = defaults.arrivalDistance
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.arrivalDistance then
        threshold = HA.Addon.db.profile.arrivalDistance
    end

    return distance <= threshold
end

-- Start checking for arrival
local function StartArrivalCheck()
    if arrivalCheckTimer then
        return -- Already checking
    end

    local checkInterval = 1.0 -- Check every second

    arrivalCheckTimer = C_Timer.NewTicker(checkInterval, function()
        if CheckArrival() then
            -- Player has arrived
            local title = currentWaypoint and currentWaypoint.title or "destination"

            if defaults.autoRemoveOnArrival then
                Waypoints:Clear()
            end

            if HA.Addon and defaults.announceWaypoint then
                HA.Addon:Print("Arrived at", title)
            end
        elseif not currentWaypoint then
            -- Waypoint was cleared externally
            StopArrivalCheck()
        end
    end)
end

-- Stop checking for arrival
local function StopArrivalCheck()
    if arrivalCheckTimer then
        arrivalCheckTimer:Cancel()
        arrivalCheckTimer = nil
    end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

-- Set a waypoint
-- @param mapID: The map ID for the waypoint
-- @param x: X coordinate (0-1)
-- @param y: Y coordinate (0-1)
-- @param options: Optional table with title, persistent, etc.
function Waypoints:Set(mapID, x, y, options)
    options = options or {}

    -- Clear existing waypoint first
    self:Clear()

    -- Get user preferences
    local useTomTom = defaults.useTomTom
    local useNative = defaults.useNative

    if HA.Addon and HA.Addon.db and HA.Addon.db.profile then
        if HA.Addon.db.profile.useTomTom ~= nil then
            useTomTom = HA.Addon.db.profile.useTomTom
        end
        if HA.Addon.db.profile.useNativeWaypoints ~= nil then
            useNative = HA.Addon.db.profile.useNativeWaypoints
        end
    end

    local success = false

    -- Set TomTom waypoint if preferred
    if useTomTom and self:IsTomTomAvailable() then
        tomtomWaypoint = AddTomTomWaypoint(mapID, x, y, options)
        if tomtomWaypoint then
            success = true
        end
    end

    -- Set native waypoint
    if useNative then
        if SetNativeWaypoint(mapID, x, y, options) then
            success = true
        end
    end

    if success then
        -- Store current waypoint info
        currentWaypoint = {
            mapID = mapID,
            x = x,
            y = y,
            title = options.title,
            data = options.data,
        }

        -- Start arrival checking if enabled
        if defaults.autoRemoveOnArrival then
            StartArrivalCheck()
        end

        -- Announce waypoint
        if HA.Addon and defaults.announceWaypoint then
            local mapInfo = C_Map.GetMapInfo(mapID)
            local zoneName = mapInfo and mapInfo.name or "Unknown"
            local coordStr = string.format("%.1f, %.1f", x * 100, y * 100)

            HA.Addon:Print("Waypoint set:", options.title or "Destination")
            HA.Addon:Print("  " .. zoneName .. " (" .. coordStr .. ")")
        end
    end

    return success
end

-- Clear current waypoint
function Waypoints:Clear()
    -- Remove TomTom waypoint
    if tomtomWaypoint then
        RemoveTomTomWaypoint(tomtomWaypoint)
        tomtomWaypoint = nil
    end

    -- Clear native waypoint
    ClearNativeWaypoint()

    -- Clear state
    currentWaypoint = nil

    -- Stop arrival checking
    StopArrivalCheck()
end

-- Get current waypoint info
function Waypoints:GetCurrent()
    return currentWaypoint
end

-- Check if a waypoint is set
function Waypoints:HasWaypoint()
    return currentWaypoint ~= nil
end

-- Get distance to current waypoint (returns nil if not on same map)
function Waypoints:GetDistanceToCurrent()
    if not currentWaypoint then
        return nil
    end

    local playerMapID = C_Map.GetBestMapForUnit("player")
    if playerMapID ~= currentWaypoint.mapID then
        return nil, "different_map"
    end

    local playerPos = C_Map.GetPlayerMapPosition(playerMapID, "player")
    if not playerPos then
        return nil, "no_position"
    end

    local dx = playerPos.x - currentWaypoint.x
    local dy = playerPos.y - currentWaypoint.y
    return math.sqrt(dx*dx + dy*dy)
end

-- Set waypoint to a vendor
function Waypoints:SetToVendor(vendor)
    if not vendor or not vendor.mapID then
        return false
    end

    -- Handle both old (coords.x/y) and new (x/y) coordinate formats
    local x = vendor.x or (vendor.coords and vendor.coords.x)
    local y = vendor.y or (vendor.coords and vendor.coords.y)

    if not x or not y then
        return false
    end

    return self:Set(vendor.mapID, x, y, {
        title = vendor.name or "Vendor",
        data = {
            type = "vendor",
            npcID = vendor.npcID,
            vendor = vendor,
        },
    })
end

-------------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------------

-- Format coordinates for display
function Waypoints:FormatCoords(x, y, precision)
    precision = precision or 1
    local format = "%." .. precision .. "f, %." .. precision .. "f"
    return string.format(format, x * 100, y * 100)
end

-- Get map name by ID
function Waypoints:GetMapName(mapID)
    local mapInfo = C_Map.GetMapInfo(mapID)
    return mapInfo and mapInfo.name or "Unknown"
end

-- Convert coordinates between formats
function Waypoints:NormalizeCoords(x, y)
    -- If coordinates are > 1, assume they're in 0-100 format
    if x > 1 or y > 1 then
        return x / 100, y / 100
    end
    return x, y
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function Waypoints:Initialize()
    -- Load user preferences
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile then
        local profile = HA.Addon.db.profile
        if profile.useTomTom ~= nil then
            defaults.useTomTom = profile.useTomTom
        end
        if profile.useNativeWaypoints ~= nil then
            defaults.useNative = profile.useNativeWaypoints
        end
        if profile.announceWaypoint ~= nil then
            defaults.announceWaypoint = profile.announceWaypoint
        end
    end

    if HA.Addon then
        HA.Addon:Debug("Waypoints utility initialized")
        if self:IsTomTomAvailable() then
            HA.Addon:Debug("TomTom detected and available")
        end
    end
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("Waypoints", Waypoints)
end
