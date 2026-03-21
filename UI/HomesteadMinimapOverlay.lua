--[[
    Homestead - Minimap Overlay
    Native minimap renderer for Homestead vendor pins.

    Owns minimap frame pooling, active pin state, and the live update loop.
    VendorMapPins provides the current candidate set; this module handles
    placement relative to the player and current minimap state.
]]

local _, HA = ...

local Overlay = {}
HA.HomesteadMinimapOverlay = Overlay

local PinFrameFactory = HA.PinFrameFactory
local FPU = HA.FramePoolUtils

local cos, sin, max, sqrt = math.cos, math.sin, math.max, math.sqrt
local format = string.format
local ipairs = ipairs

local BoolToKey = FPU.BoolToKey
local AcquirePooledFrame = FPU.AcquirePooledFrame

local updateFrame = CreateFrame("Frame")
local activePins = {}
local framePool = {}
local isUpdating = false

local lastZoom
local lastFacing
local lastPlayerX
local lastPlayerY
local lastMinimapScale
local minimapWidth
local minimapHeight
local mapRadius
local mapSin
local mapCos
local minimapShape

local minimapShapes = {
    -- { upper-left, lower-left, upper-right, lower-right }
    ["SQUARE"]                = { false, false, false, false },
    ["CORNER-TOPLEFT"]        = { true,  false, false, false },
    ["CORNER-TOPRIGHT"]       = { false, false, true,  false },
    ["CORNER-BOTTOMLEFT"]     = { false, true,  false, false },
    ["CORNER-BOTTOMRIGHT"]    = { false, false, false, true },
    ["SIDE-LEFT"]             = { true,  true,  false, false },
    ["SIDE-RIGHT"]            = { false, false, true,  true },
    ["SIDE-TOP"]              = { true,  false, true,  false },
    ["SIDE-BOTTOM"]           = { false, true,  false, true },
    ["TRICORNER-TOPLEFT"]     = { true,  true,  true,  false },
    ["TRICORNER-TOPRIGHT"]    = { true,  false, true,  true },
    ["TRICORNER-BOTTOMLEFT"]  = { true,  true,  false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { false, true,  true,  true },
}

local function BuildMinimapPinStyleKey()
    local size = PinFrameFactory:GetMinimapIconSize()
    local isCustom = PinFrameFactory:IsCustomPinColor()
    local r, g, b = PinFrameFactory:GetPinColor()
    return format("ms%d|c%s|%.3f|%.3f|%.3f", size, BoolToKey(isCustom), r, g, b)
end

local function GetFramePoolKey(pin)
    return format("%s|o%s|u%s|e%s",
        BuildMinimapPinStyleKey(),
        BoolToKey(pin.isOppositeFaction),
        BoolToKey(pin.isUnverified),
        pin.elevation or "none")
end

local function CleanupMinimapFrame(frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(UIParent)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(1)
end

local function ReleasePooledFrame(poolByKey, frame)
    FPU.ReleasePooledFrame(poolByKey, frame, CleanupMinimapFrame)
end

local function FlushPoolBuckets(poolByKey)
    FPU.FlushPoolBuckets(poolByKey, CleanupMinimapFrame)
end

local function AcquireFrame(pin)
    local minimap = _G.Minimap
    local poolKey = GetFramePoolKey(pin)
    local frame = AcquirePooledFrame(framePool, poolKey, function()
        return PinFrameFactory:CreateMinimapPinFrame(
            pin.vendor,
            pin.isOppositeFaction,
            pin.isUnverified,
            pin.elevation
        )
    end)
    frame.vendor = pin.vendor
    frame.isOppositeFaction = pin.isOppositeFaction
    frame.isUnverified = pin.isUnverified
    frame.elevation = pin.elevation
    frame:SetParent(_G.Minimap)
    frame:SetFrameStrata(minimap:GetFrameStrata())
    frame:SetFrameLevel(minimap:GetFrameLevel() + 10)
    return frame
end

local function GetPlayerWorldPosition()
    local y, x = _G.UnitPosition("player")
    if not x or not y then
        return nil, nil
    end
    return x, y
end

local function IsHybridMinimapActive()
    local hybridMinimap = _G.HybridMinimap
    return hybridMinimap and hybridMinimap:IsShown()
end

local function RefreshPlacementMetrics(facing)
    local minimap = _G.Minimap
    local getShape = _G.GetMinimapShape
    local minimapAPI = _G.C_Minimap

    minimapShape = getShape and minimapShapes[getShape() or "ROUND"]
    minimapWidth = minimap:GetWidth() / 2
    minimapHeight = minimap:GetHeight() / 2
    mapRadius = minimapAPI and minimapAPI.GetViewRadius and minimapAPI.GetViewRadius() or nil
    if facing then
        mapSin = sin(facing)
        mapCos = cos(facing)
    end
end

local function DrawPin(pin, playerX, playerY, rotateMinimap)
    local xDist = playerX - pin.worldX
    local yDist = playerY - pin.worldY

    if rotateMinimap then
        local dx, dy = xDist, yDist
        xDist = dx * mapCos - dy * mapSin
        yDist = dx * mapSin + dy * mapCos
    end

    local diffX = xDist / mapRadius
    local diffY = yDist / mapRadius

    local isRound = true
    if minimapShape and not (xDist == 0 or yDist == 0) then
        isRound = (xDist < 0) and 1 or 3
        if yDist < 0 then
            isRound = minimapShape[isRound]
        else
            isRound = minimapShape[isRound + 1]
        end
    end

    local dist
    if isRound then
        dist = (diffX * diffX + diffY * diffY) / 0.9^2
    else
        dist = max(diffX * diffX, diffY * diffY) / 0.9^2
    end

    if dist > 1 and pin.floatOnEdge then
        dist = sqrt(dist)
        diffX = diffX / dist
        diffY = diffY / dist
    end

    if dist <= 1 or pin.floatOnEdge then
        pin.frame:Show()
        pin.frame:ClearAllPoints()
        pin.frame:SetPoint("CENTER", _G.Minimap, "CENTER", diffX * minimapWidth, -diffY * minimapHeight)
    else
        pin.frame:Hide()
    end
end

function Overlay:RefreshPositions(force)
    if #activePins == 0 then
        return
    end

    if IsHybridMinimapActive() then
        for _, pin in ipairs(activePins) do
            pin.frame:Hide()
        end
        return
    end

    local playerX, playerY = GetPlayerWorldPosition()
    local rotateMinimap = _G.GetCVar("rotateMinimap") == "1"
    local facing = rotateMinimap and _G.GetPlayerFacing() or nil

    if not playerX or not playerY or (rotateMinimap and not facing) then
        for _, pin in ipairs(activePins) do
            pin.frame:Hide()
        end
        return
    end

    local zoom = _G.Minimap:GetZoom()
    local minimapScale = _G.Minimap:GetScale()
    if force
            or zoom ~= lastZoom
            or facing ~= lastFacing
            or playerX ~= lastPlayerX
            or playerY ~= lastPlayerY
            or minimapScale ~= lastMinimapScale then
        lastZoom = zoom
        lastFacing = facing
        lastPlayerX = playerX
        lastPlayerY = playerY
        lastMinimapScale = minimapScale
        RefreshPlacementMetrics(facing)
        if not mapRadius or mapRadius <= 0 then
            for _, pin in ipairs(activePins) do
                pin.frame:Hide()
            end
            return
        end
    else
        return
    end

    for _, pin in ipairs(activePins) do
        DrawPin(pin, playerX, playerY, rotateMinimap)
    end
end

function Overlay:Start()
    if isUpdating then
        return
    end
    isUpdating = true
    updateFrame:SetScript("OnUpdate", function()
        Overlay:RefreshPositions(false)
    end)
end

function Overlay:Stop()
    if not isUpdating then
        return
    end
    isUpdating = false
    updateFrame:SetScript("OnUpdate", nil)
end

function Overlay:Clear()
    self:Stop()

    for i = #activePins, 1, -1 do
        ReleasePooledFrame(framePool, activePins[i].frame)
        activePins[i] = nil
    end

    lastZoom = nil
    lastFacing = nil
    lastPlayerX = nil
    lastPlayerY = nil
    lastMinimapScale = nil
end

function Overlay:SetPins(pinRecords)
    self:Clear()

    if IsHybridMinimapActive() then
        return
    end

    for _, pin in ipairs(pinRecords) do
        pin.frame = AcquireFrame(pin)
        activePins[#activePins + 1] = pin
    end

    if #activePins > 0 then
        self:RefreshPositions(true)
        self:Start()
    end
end

function Overlay:GetActiveFrames()
    return activePins
end

function Overlay:FlushPools()
    self:Clear()
    FlushPoolBuckets(framePool)
end
