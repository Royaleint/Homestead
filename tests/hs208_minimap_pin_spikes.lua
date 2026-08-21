-- luacheck: globals assert loadfile print io loadstring CreateFrame UnitPosition
-- luacheck: globals GetCVar C_Minimap Minimap GetMinimapShape C_Housing IsIndoors

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
    frame.__shown = false
    function frame:Show() self.__shown = true end
    function frame:Hide() self.__shown = false end
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
C_Housing = { IsInsideHouse = function() return false end }
IsIndoors = function() return false end

local mockIconSize = 14

local HA = {
    PinFrameFactory = {
        CreateMinimapPinFrame = function()
            frameCreateCalls = frameCreateCalls + 1
            return NewMockFrame()
        end,
        -- HS-358: records the size it was applied with, so a test can assert
        -- a pool-hit frame actually got restyled, not just reused stale.
        ApplyMinimapPinStyle = function(self, frame)
            frame.__appliedSize = self:GetMinimapIconSize()
        end,
        GetMinimapIconSize = function() return mockIconSize end,
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

-- A vendor whose elevation arrow EXISTENCE changed (same npcID, nil to
-- "above") must NOT reuse its old frame — CreateMinimapPinFrame bakes
-- elevation-arrow existence into the frame's visual construction. (A later
-- direction-only change, e.g. "above" to "below" on an already-elevated
-- vendor, is a different case — see the HS-358 block below, where the frame
-- IS reused and restyled in place.)
Overlay:SetPins({ MakePin(1, false, "above") })
assert(frameCreateCalls == 5, "an elevation change on the same vendor must allocate a fresh frame, not reuse the old one")

print("hs208_minimap_pin_spikes: SetPins diffing ok")

-------------------------------------------------------------------------------
-- HS-358: AcquireFrame's pool-hit path must restyle, not just reuse
--
-- MinimapPinCollect.lua unconditionally calls Overlay:Clear() before every
-- real SetPins call, so SetPins's own identity-diff reuse branch never fires
-- in production (confirmed in the plan) -- the actual repaint mechanism is
-- AcquireFrame reacquiring a frame from its own pool bucket after a Clear().
-- This test
-- mirrors that real Clear()-then-SetPins shape rather than calling SetPins
-- twice back to back (which doesn't discriminate: GetFramePoolKey is
-- recomputed live for both old and new pins, so both sides shift together
-- even on unfixed code). A single pin avoids LIFO ambiguity between two
-- frames sharing one bucket.
-------------------------------------------------------------------------------

Overlay:SetPins({ MakePin(5) })
local createsBeforeStyleChange = frameCreateCalls
local frameBeforeStyleChange = Overlay:GetActiveFrames()[1].frame

Overlay:Clear()

mockIconSize = 20 -- simulate a minimapIconSize style change

Overlay:SetPins({ MakePin(5) })
assert(frameCreateCalls == createsBeforeStyleChange,
    "a same-shape style-only change must be a pool hit, not a fresh construct")

local frameAfterStyleChange = Overlay:GetActiveFrames()[1].frame
assert(frameAfterStyleChange == frameBeforeStyleChange,
    "the pool-hit frame must be the exact same object released by Clear()")
assert(frameAfterStyleChange.__appliedSize == 20,
    "AcquireFrame must restyle a pool-hit frame with the new size, not leave it stale")

print("hs208_minimap_pin_spikes: pool-hit restyle ok")

-------------------------------------------------------------------------------
-- HS-362: pins must stay hidden while C_Housing.IsInsideHouse() is true
--
-- Argus's Gate 1 review of HS-362 found this composed hide condition had
-- zero regression coverage -- proved by mutation: deleting the indoor branch
-- entirely left every existing assertion in this file green. This closes
-- that gap directly rather than relying on the elevation/style assertions
-- above to incidentally exercise it (they don't -- C_Housing is never
-- touched by anything before this block). Explicitly cleared to a known
-- empty baseline first (HS-362 cycle 3 changed SetPins to leave leftover
-- pins from the prior block untouched while hidden, rather than wiping them
-- -- see the "hidden-refresh no longer destroys pin state" block below for
-- that behavior's own coverage).
-------------------------------------------------------------------------------

Overlay:Clear()
C_Housing.IsInsideHouse = function() return true end

Overlay:SetPins({ MakePin(6) })
assert(#Overlay:GetActiveFrames() == 0,
    "SetPins must not place any pins while C_Housing.IsInsideHouse() is true")

C_Housing.IsInsideHouse = function() return false end

print("hs208_minimap_pin_spikes: indoor-housing pin suppression ok")

-------------------------------------------------------------------------------
-- HS-362 (second finding): pins must stay hidden while the generic IsIndoors()
-- flag is true, independent of C_Housing.IsInsideHouse() -- an ordinary
-- building (not a player house) still needs pins suppressed, since its
-- vendors-outside-the-walls case has no distinct map ID for a collect-time
-- fix to key off. This must be re-checked live (via RefreshPositions/SetPins,
-- not a one-shot collect-time filter) since walking into a same-map-ID
-- building never triggers a new collect at all -- see the code comment on
-- IsInsideBuilding() in HomesteadMinimapOverlay.lua for why.
-------------------------------------------------------------------------------

IsIndoors = function() return true end

Overlay:SetPins({ MakePin(7) })
assert(#Overlay:GetActiveFrames() == 0,
    "SetPins must not place any pins while IsIndoors() is true")

IsIndoors = function() return false end

print("hs208_minimap_pin_spikes: indoor-building pin suppression ok")

-------------------------------------------------------------------------------
-- HS-362 (cycle 3): a refresh landing WHILE hidden must not destroy pin
-- state. Argus's Gate 1 review of the previous fix (af7156b) found
-- ShouldHideMinimapPins()'s live re-check was itself correct, but the
-- caller (MinimapPinCollect.lua) unconditionally cleared activePins BEFORE
-- checking hide -- so any refresh trigger landing while already indoors
-- wiped pin state permanently. Nothing ever restored it: a same-mapID exit
-- never re-triggers a collect, and Clear() also stops the OnUpdate driver
-- RefreshPositions relies on. This reproduces the failure at the Overlay
-- level, where both the bug and the fix live: SetPins must leave activePins
-- untouched while hidden, and the existing per-frame RefreshPositions check
-- must resume showing the SAME frames -- no recreate -- the instant hidden
-- goes false again. Mirrors Argus's differential probe (Case A: already
-- active, walk in and out, recovers; Case B: a refresh lands while indoors,
-- never recovers) at the mechanism this cycle actually touched.
-------------------------------------------------------------------------------

Overlay:SetPins({ MakePin(8), MakePin(9) })
assert(#Overlay:GetActiveFrames() == 2, "expected 2 active pins before the hide cycle")
local createsBeforeHideCycle = frameCreateCalls
local framesBeforeHide = {}
for _, pin in ipairs(Overlay:GetActiveFrames()) do
    framesBeforeHide[pin.vendor.npcID] = pin.frame
    assert(pin.frame.__shown == true, "pins must be shown before the hide cycle starts")
end

-- Simulate a refresh LANDING while indoors -- the exact cycle-2 regression.
-- (MinimapPinCollect.lua's own fix is the ClearMinimapPins/hide-check
-- reorder, which this file's stub environment can't reach directly since it
-- doesn't load VendorData/MapPinProvider/VendorFilter -- SetPins is the
-- shared surface where both the bug and the fix actually live, per Argus's
-- review.)
C_Housing.IsInsideHouse = function() return true end

Overlay:SetPins({ MakePin(8), MakePin(9) })
assert(#Overlay:GetActiveFrames() == 2,
    "a SetPins call while hidden must not destroy already-active pin state")
for _, pin in ipairs(Overlay:GetActiveFrames()) do
    assert(pin.frame == framesBeforeHide[pin.vendor.npcID],
        "pins surviving a hidden SetPins call must keep their exact frame objects")
end
assert(frameCreateCalls == createsBeforeHideCycle,
    "a hidden SetPins call must not allocate any new frames")

Overlay:RefreshPositions(true)
for _, pin in ipairs(Overlay:GetActiveFrames()) do
    assert(pin.frame.__shown == false, "pins must be visually hidden while indoors")
end

-- Un-hide: the SAME per-frame check that hid them must resume showing them,
-- reusing the exact same frames -- this is the recovery edge the previous
-- fix never had.
C_Housing.IsInsideHouse = function() return false end
Overlay:RefreshPositions(true)

assert(frameCreateCalls == createsBeforeHideCycle,
    "recovering from hidden must reuse the surviving frames, not recreate them")
for _, pin in ipairs(Overlay:GetActiveFrames()) do
    assert(pin.frame.__shown == true, "pins must resume showing once no longer hidden, with no new collect")
end

print("hs208_minimap_pin_spikes: hidden-refresh no longer destroys pin state ok")
