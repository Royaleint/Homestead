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

local PLAYER_ARROW_CLEAR_RADIUS = 12
local PLAYER_ARROW_OVERLAP_ALPHA = 0.3

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
local lastHideReason

-- HS-090 Phase H: cache the rotateMinimap cvar instead of calling GetCVar
-- every OnUpdate tick. Refresh on CVAR_UPDATE so live toggles of "Rotate
-- Minimap" in the Blizzard Interface options work without /reload.
local rotateMinimapEnabled = _G.GetCVar and _G.GetCVar("rotateMinimap") == "1" or false
local cvarFrame = CreateFrame("Frame")
cvarFrame:RegisterEvent("CVAR_UPDATE")
cvarFrame:SetScript("OnEvent", function(_, _, cvarName, value)
    if cvarName == "rotateMinimap" then
        rotateMinimapEnabled = value == "1"
    end
end)

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

-- HS-358: elevation-arrow existence is the one property CreateMinimapPinFrame
-- genuinely bakes into construction (a whole extra texture object exists only
-- when elevation is set). isOppositeFaction no longer changes construction at
-- all -- ApplyMinimapPinStyle now sets its texture state on every acquire --
-- but the axis stays in the key anyway; it's a cheap, already-bounded boolean
-- and removing it would buy nothing. Size/color/arrow-direction are style,
-- applied in place by ApplyMinimapPinStyle every time a frame is handed out
-- -- see AcquireFrame.
local function GetFramePoolKey(pin)
    return format("o%s|e%s", BoolToKey(pin.isOppositeFaction), BoolToKey(pin.elevation ~= nil))
end

-- HS-208: identity used by SetPins to diff the new pin set against the
-- previous one. Deliberately the vendor's npcID PLUS the same pool key
-- (opposite-faction/elevation-existence) rather than npcID alone --
-- elevation-arrow existence changes the frame's actual visual construction
-- (CreateMinimapPinFrame bakes it in), so a vendor gaining or losing its
-- elevation arrow across a zone crossing must NOT reuse its old frame.
-- Elevation *direction* (above/below) is style, not identity, as of HS-358 --
-- a vendor whose direction flips keeps its frame and gets restyled in place
-- by ApplyMinimapPinStyle; only an identity+style match is required to carry
-- a frame over as-is.
local function GetPinIdentityKey(pin)
    local npcID = pin.vendor and pin.vendor.npcID
    return tostring(npcID) .. "|" .. GetFramePoolKey(pin)
end

local function CleanupMinimapFrame(frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(UIParent)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(1)
    frame:SetAlpha(1)
end

local function ReleasePooledFrame(poolByKey, frame)
    FPU.ReleasePooledFrame(poolByKey, frame, CleanupMinimapFrame)
end

local function AcquireFrame(pin)
    local minimap = _G.Minimap
    local poolKey = GetFramePoolKey(pin)
    local frame = AcquirePooledFrame(framePool, poolKey, function()
        return PinFrameFactory:CreateMinimapPinFrame(
            pin.vendor,
            pin.isOppositeFaction,
            pin.elevation
        )
    end)
    frame.vendor = pin.vendor
    frame.isOppositeFaction = pin.isOppositeFaction
    frame.elevation = pin.elevation
    frame:SetParent(_G.Minimap)
    frame:SetFrameStrata(minimap:GetFrameStrata())
    frame:SetFrameLevel(minimap:GetFrameLevel() + 10)
    frame:SetAlpha(1)
    -- The actual repaint mechanism (HS-358): a pool hit may be carrying
    -- stale size/color/direction from before a style change, so every
    -- acquire restyles regardless of whether the frame was just built or
    -- pulled from the pool.
    PinFrameFactory:ApplyMinimapPinStyle(frame, pin.isOppositeFaction, pin.elevation)
    return frame
end

local function GetPlayerWorldPosition()
    local y, x = _G.UnitPosition("player")
    if not x or not y then
        return nil, nil
    end
    return x, y
end

function Overlay:GetHybridMinimapState()
    local minimapAPI = _G.C_Minimap
    -- Blizzard enables HybridMinimap from Minimap.lua via
    -- C_Minimap.ShouldUseHybridMinimap(), then shows the HybridMinimap frame.
    local shouldUse = minimapAPI
        and minimapAPI.ShouldUseHybridMinimap
        and minimapAPI.ShouldUseHybridMinimap()
        or false
    local hybridMinimap = _G.HybridMinimap
    -- The frame check mirrors HybridMinimap:IsShown() without assuming the
    -- Blizzard_HybridMinimap addon has already been loaded.
    local frameShown = hybridMinimap
        and hybridMinimap.IsShown
        and hybridMinimap:IsShown()
        or false
    local reason
    if frameShown then
        reason = "hybrid_frame_shown"
    elseif shouldUse then
        reason = "api_should_use_frame_hidden"
    else
        reason = "inactive"
    end
    return frameShown == true, reason, shouldUse == true, frameShown == true
end

-- HS-362: Blizzard swaps in an opaque static overlay across the whole
-- minimap whenever the player is inside a house (Minimap.lua's
-- UpdateStaticOverlayTexture, gated on C_Housing.IsInsideHouse()) --
-- independent of HybridMinimap state, so it needs its own check rather than
-- folding into GetHybridMinimapState's hybrid-specific reason reporting.
local function IsInsideHouse()
    local housingAPI = _G.C_Housing
    return housingAPI and housingAPI.IsInsideHouse and housingAPI.IsInsideHouse() or false
end

-- HS-362 (cycle 2/3): an ordinary building (not a player house) has no
-- distinct map ID, so a collect-time filter can never react to its
-- entry/exit -- this MUST be re-checked live, every RefreshPositions/SetPins
-- pass, not decided once at collect time. The generic IsIndoors() flag is
-- broader than IsInsideHouse() (any WMO interior, not just player housing),
-- a known accepted tradeoff for this ticket -- see Home_Tracker.md HS-362
-- for the open, live-client-only risk that some vendors' own coordinates may
-- sit inside a WMO (e.g. City of Threads) and would have their own pin
-- suppressed by proximity.
local function IsInsideBuilding()
    return _G.IsIndoors and _G.IsIndoors() or false
end

-- Single source of truth for "should minimap pins stay hidden right now" --
-- consumed both internally (RefreshPositions/SetPins below) and externally
-- (MinimapPinCollect's pre-collection skip), so a future fourth hide
-- condition only needs adding here once.
function Overlay:ShouldHideMinimapPins()
    local hybridActive, hybridReason = self:GetHybridMinimapState()
    if hybridActive then
        return true, hybridReason
    end
    if IsInsideHouse() then
        return true, "inside_house"
    end
    if IsInsideBuilding() then
        return true, "indoors"
    end
    return false, "inactive"
end

local function ShouldHideMinimapPins()
    local hide, reason = Overlay:ShouldHideMinimapPins()
    if hide and reason ~= lastHideReason then
        lastHideReason = reason
        if HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug then
            HA.Addon:Debug("Homestead minimap pins hidden (" .. reason .. ")")
        end
    elseif not hide then
        lastHideReason = nil
    end
    return hide
end

-- HS-208: RefreshPositions used to treat ANY change in playerX/playerY as
-- worth a full redraw, so every OnUpdate tick while moving re-ran
-- RefreshPlacementMetrics + DrawPin for every active pin — a small but
-- continuous per-frame cost while flying. A sub-pixel world-distance
-- threshold (derived from the current mapRadius/minimapWidth, so it scales
-- with zoom instead of being a fixed constant) lets genuinely-imperceptible
-- movement skip the redraw without any visible lag or jitter: the next
-- frame that pushes the accumulated movement past the threshold still
-- redraws from the true, current player position (last* is only updated on
-- an actual redraw), so nothing ever drifts.
-- Pure and parameterized (no module upvalues) so it's directly unit-testable.
local MOVEMENT_SKIP_PIXEL_FRACTION = 0.5

local function IsMovementBelowSubPixelThreshold(dx, dy, radius, pixelSpan, pixelFraction)
    if not radius or radius <= 0 or not pixelSpan or pixelSpan <= 0 then
        return false
    end
    local worldPerPixel = radius / pixelSpan
    local threshold = worldPerPixel * (pixelFraction or MOVEMENT_SKIP_PIXEL_FRACTION)
    return (dx * dx + dy * dy) < (threshold * threshold)
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
        local pixelX = diffX * minimapWidth
        local pixelY = -diffY * minimapHeight
        local clearRadiusSq = PLAYER_ARROW_CLEAR_RADIUS * PLAYER_ARROW_CLEAR_RADIUS
        local centerDistSq = pixelX * pixelX + pixelY * pixelY

        pin.frame:Show()
        pin.frame:ClearAllPoints()
        pin.frame:SetPoint("CENTER", _G.Minimap, "CENTER", pixelX, pixelY)
        pin.frame:SetAlpha(centerDistSq <= clearRadiusSq and PLAYER_ARROW_OVERLAP_ALPHA or 1)
    else
        pin.frame:Hide()
    end
end

function Overlay:RefreshPositions(force)
    if #activePins == 0 then
        return
    end

    if ShouldHideMinimapPins() then
        for _, pin in ipairs(activePins) do
            pin.frame:Hide()
        end
        return
    end

    local playerX, playerY = GetPlayerWorldPosition()
    local rotateMinimap = rotateMinimapEnabled
    local facing = rotateMinimap and _G.GetPlayerFacing() or nil

    if not playerX or not playerY or (rotateMinimap and not facing) then
        for _, pin in ipairs(activePins) do
            pin.frame:Hide()
        end
        return
    end

    local zoom = _G.Minimap:GetZoom()
    local minimapScale = _G.Minimap:GetScale()

    -- HS-208: a raw position change no longer forces a redraw on its own —
    -- only one that exceeds the current sub-pixel threshold does. lastPlayerX/
    -- lastPlayerY are nil only before the first-ever redraw (Clear() resets
    -- them, and SetPins always forces the next call), so this never runs
    -- without an established mapRadius/minimapWidth to derive the threshold
    -- from — IsMovementBelowSubPixelThreshold's own radius/pixelSpan guard
    -- covers that case defensively regardless.
    local positionChanged = playerX ~= lastPlayerX or playerY ~= lastPlayerY
    if positionChanged and lastPlayerX and lastPlayerY then
        local pixelSpan = max(minimapWidth or 0, minimapHeight or 0)
        local dx = playerX - lastPlayerX
        local dy = playerY - lastPlayerY
        if IsMovementBelowSubPixelThreshold(dx, dy, mapRadius, pixelSpan) then
            positionChanged = false
        end
    end

    if force
            or zoom ~= lastZoom
            or facing ~= lastFacing
            or positionChanged
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

-- HS-208: diffs the new pin set against the previous one instead of
-- releasing every existing frame to the pool and reacquiring the whole set.
-- Crossing a zone boundary re-triggers a full VendorMapPins candidate-set
-- rebuild, but a zone crossing typically leaves most of that set unchanged
-- (parent/sibling-zone vendors aren't affected by the player's own zone
-- changing) — releasing and reacquiring those frames anyway, every crossing,
-- was the likelier source of the reported spikes. Frames are only
-- released/reacquired for vendors that actually left or entered the set (or
-- whose rendering identity changed, see GetPinIdentityKey); everything else
-- keeps its exact frame object.
function Overlay:SetPins(pinRecords)
    -- HS-362 (cycle 3): don't destroy existing pin state on a hidden call --
    -- RefreshPositions's own per-frame hide check already suppresses display
    -- without releasing frames; clearing here would reintroduce the same
    -- one-way-door defect this cycle fixed in MinimapPinCollect.lua's caller
    -- (nothing left to restore once unhidden, since a same-mapID exit never
    -- re-triggers a collect). This path is unreached in production today
    -- (MinimapPinCollect.lua always hide-checks before calling SetPins), but
    -- kept correct defensively for HS-364, which will make it reachable.
    if ShouldHideMinimapPins() then
        return
    end

    local previousPinsByKey = {}
    for _, oldPin in ipairs(activePins) do
        local key = GetPinIdentityKey(oldPin)
        if not previousPinsByKey[key] then
            previousPinsByKey[key] = oldPin
        end
    end

    local newActivePins = {}
    local reusedOldPins = {}

    for _, pin in ipairs(pinRecords) do
        local previousPin = previousPinsByKey[GetPinIdentityKey(pin)]
        if previousPin and not reusedOldPins[previousPin] then
            -- Same vendor identity + same rendering identity: reuse the
            -- frame object outright. frame.vendor/isOppositeFaction/elevation
            -- still need refreshing — pin.vendor is a fresh projected table
            -- every VendorData:GetVendorsInMap call, even when the npcID is
            -- unchanged, and PinFrameFactory-driven hover/click handlers read
            -- frame.vendor directly.
            local frame = previousPin.frame
            frame.vendor = pin.vendor
            frame.isOppositeFaction = pin.isOppositeFaction
            frame.elevation = pin.elevation
            -- Defense-in-depth (HS-358): this branch is confirmed unreachable
            -- in production today (MinimapPinCollect.lua always clears
            -- activePins before calling SetPins) — inert until HS-364 makes
            -- it reachable, correct either way.
            PinFrameFactory:ApplyMinimapPinStyle(frame, pin.isOppositeFaction, pin.elevation)
            pin.frame = frame
            reusedOldPins[previousPin] = true
        else
            pin.frame = AcquireFrame(pin)
        end
        newActivePins[#newActivePins + 1] = pin
    end

    -- Release only the frames that didn't survive into the new set.
    for _, oldPin in ipairs(activePins) do
        if not reusedOldPins[oldPin] then
            ReleasePooledFrame(framePool, oldPin.frame)
        end
    end

    activePins = newActivePins

    if #activePins > 0 then
        self:RefreshPositions(true)
        self:Start()
    else
        self:Stop()
    end
end

function Overlay:GetActiveFrames()
    return activePins
end
