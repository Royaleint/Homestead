-- luacheck: globals assert loadfile print io loadstring CreateFrame UnitPosition
-- luacheck: globals GetCVar C_Minimap Minimap GetMinimapShape

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-208 (1): movement-skip threshold is pure math — extract and unit-test
-- it directly (same extract-and-load technique as the hs202 tooltip test),
-- rather than trust the source-text alone.
-------------------------------------------------------------------------------

local overlaySource = assert(io.open(root .. "/UI/HomesteadMinimapOverlay.lua", "r")):read("*a")

local thresholdFnText = overlaySource:match(
    '(local function IsMovementBelowSubPixelThreshold%(dx, dy, radius, pixelSpan, pixelFraction%).-\nend)')
assert(thresholdFnText ~= nil, "could not extract IsMovementBelowSubPixelThreshold from HomesteadMinimapOverlay.lua")

local thresholdChunk = thresholdFnText .. "\nreturn IsMovementBelowSubPixelThreshold"
local IsMovementBelowSubPixelThreshold = assert(loadstring(thresholdChunk, "IsMovementBelowSubPixelThreshold-extract"))()

-- At a 400-yard view radius over a 140px minimap (mapRadius/pixelSpan =
-- ~2.857 world units per pixel), half a pixel is ~1.43 world units. The
-- module's own MOVEMENT_SKIP_PIXEL_FRACTION default (0.5) isn't part of this
-- extracted text, so every call below passes the fraction explicitly.
local radius, pixelSpan, fraction = 400, 140, 0.5

-- Below the sub-pixel threshold: must skip (return true).
assert(IsMovementBelowSubPixelThreshold(0.5, 0, radius, pixelSpan, fraction) == true)
assert(IsMovementBelowSubPixelThreshold(0, -1.0, radius, pixelSpan, fraction) == true)

-- At/above the threshold: must NOT skip (return false) — real movement
-- must never be silently dropped.
assert(IsMovementBelowSubPixelThreshold(1.43, 0, radius, pixelSpan, fraction) == false)
assert(IsMovementBelowSubPixelThreshold(10, 10, radius, pixelSpan, fraction) == false)

-- Threshold scales with zoom: the SAME raw movement that was skippable at a
-- wide view radius must NOT be skippable at a much tighter one (more world
-- distance per pixel at max zoom-out than at max zoom-in for the same pixel
-- span — halving the radius halves the threshold).
assert(IsMovementBelowSubPixelThreshold(1.0, 0, 400, pixelSpan, fraction) == true)
assert(IsMovementBelowSubPixelThreshold(1.0, 0, 40, pixelSpan, fraction) == false)

-- Missing metrics (no established mapRadius/minimapWidth yet) must never
-- skip — the safe default is "treat as changed, redraw."
assert(IsMovementBelowSubPixelThreshold(0.001, 0, nil, pixelSpan, fraction) == false)
assert(IsMovementBelowSubPixelThreshold(0.001, 0, radius, nil, fraction) == false)
assert(IsMovementBelowSubPixelThreshold(0.001, 0, 0, pixelSpan, fraction) == false)

print("hs208_minimap_pin_spikes: threshold math ok")

-------------------------------------------------------------------------------
-- HS-208 (2): SetPins diffs the pin set instead of blind Clear+reacquire
--
-- Loads the REAL Overlay/HomesteadMinimapOverlay.lua module (not extracted
-- text) against a minimal WoW stub environment, reusing the real, dependency-
-- free FramePoolUtils.lua for actual pooling behavior. PinFrameFactory is
-- stubbed with a call counter so "how many frames were newly created" is
-- directly observable.
-------------------------------------------------------------------------------

local frameCreateCalls = 0

local function NewMockFrame()
    local frame = {}
    function frame:SetParent() end
    function frame:SetFrameStrata() end
    function frame:SetFrameLevel() end
    function frame:SetAlpha() end
    function frame:Show() end
    function frame:Hide() end
    function frame:ClearAllPoints() end
    function frame:SetPoint() end
    function frame:RegisterEvent() end
    function frame:SetScript() end
    function frame:GetWidth() return 140 end
    function frame:GetHeight() return 140 end
    function frame:GetZoom() return 0 end
    function frame:GetScale() return 1 end
    function frame:GetFrameStrata() return "LOW" end
    function frame:GetFrameLevel() return 0 end
    return frame
end

CreateFrame = function()
    return NewMockFrame()
end

GetCVar = function(name)
    if name == "rotateMinimap" then return "0" end
    return nil
end

Minimap = NewMockFrame()
C_Minimap = { GetViewRadius = function() return 400 end }
UnitPosition = function() return 0, 0 end
GetMinimapShape = nil

local HA = {
    PinFrameFactory = {
        CreateMinimapPinFrame = function()
            frameCreateCalls = frameCreateCalls + 1
            return NewMockFrame()
        end,
        GetMinimapIconSize = function() return 14 end,
        IsCustomPinColor = function() return false end,
        GetPinColor = function() return 1, 1, 1 end,
    },
}

assert(loadfile(root .. "/UI/FramePoolUtils.lua"))("Homestead", HA)
assert(loadfile(root .. "/UI/HomesteadMinimapOverlay.lua"))("Homestead", HA)
local Overlay = HA.HomesteadMinimapOverlay

local function MakePin(npcID, isOppositeFaction, elevation)
    return {
        vendor = { npcID = npcID },
        worldX = 0, worldY = 0,
        isOppositeFaction = isOppositeFaction or false,
        elevation = elevation,
        floatOnEdge = false,
    }
end

-- Initial set: A, B, C — all newly created.
Overlay:SetPins({ MakePin(1), MakePin(2), MakePin(3) })
assert(frameCreateCalls == 3, "expected 3 fresh frames on the initial set")

local framesAfterFirst = {}
for _, pin in ipairs(Overlay:GetActiveFrames()) do
    framesAfterFirst[pin.vendor.npcID] = pin.frame
end

-- Next set: A and C persist (same identity+style), B leaves, D is new.
-- Only D should allocate a new frame; A and C must keep their exact frame
-- objects (same table reference) rather than being released+reacquired.
Overlay:SetPins({ MakePin(1), MakePin(3), MakePin(4) })
assert(frameCreateCalls == 4, "expected exactly one new frame (D) on the second set")

local framesAfterSecond = {}
for _, pin in ipairs(Overlay:GetActiveFrames()) do
    framesAfterSecond[pin.vendor.npcID] = pin.frame
end

assert(framesAfterSecond[1] == framesAfterFirst[1], "vendor A's frame object must be reused, not reallocated")
assert(framesAfterSecond[3] == framesAfterFirst[3], "vendor C's frame object must be reused, not reallocated")
assert(framesAfterSecond[4] ~= nil)

-- A vendor whose elevation relationship changed (same npcID, different
-- style-affecting field) must NOT reuse its old frame — CreateMinimapPinFrame
-- bakes elevation into the frame's visual construction.
Overlay:SetPins({ MakePin(1, false, "above") })
assert(frameCreateCalls == 5, "an elevation change on the same vendor must allocate a fresh frame, not reuse the old one")

print("hs208_minimap_pin_spikes: SetPins diffing ok")
