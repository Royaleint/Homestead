-- luacheck: globals assert loadfile print io loadstring CreateFrame UnitPosition
-- luacheck: globals GetCVar C_Minimap Minimap GetMinimapShape C_Housing IsIndoors
-- luacheck: globals C_Map C_Timer

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

-- HS-367: a settable mapID and a capturable ticker callback, so the
-- reconciliation backstop's tick logic can be driven directly rather than
-- waiting on a real WoW timer (which doesn't exist in this headless
-- environment).
local mockMapID = 100
C_Map = { GetBestMapForUnit = function() return mockMapID end }

local activeTicker
C_Timer = {
    NewTicker = function(_, callback)
        activeTicker = { callback = callback, cancelled = false }
        return {
            Cancel = function()
                activeTicker.cancelled = true
            end,
        }
    end,
}

local mockIconSize = 14

-- HS-367: minimal stand-ins for the two VendorMapPins surfaces the
-- reconciliation backstop calls into (pending-flag consumption, refresh
-- requests) — VendorMapPins.lua itself is too heavy to load in this
-- lightweight spike harness (see its own header comment on external
-- dependencies), so its contract is mocked the same way PinFrameFactory is.
local minimapRefreshPendingForTest = false
local minimapRefreshRequests = {}
local minimapPinsEnabledForTest = true
local vendorFilterEnabledForTest = true

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
    VendorMapPins = {
        IsMinimapPinsEnabled = function()
            return minimapPinsEnabledForTest
        end,
        IsMapFilterSourceEnabled = function(_, sourceKey)
            return sourceKey == "vendor" and vendorFilterEnabledForTest
        end,
        ConsumePendingMinimapRefresh = function()
            if not minimapRefreshPendingForTest then
                return false
            end
            minimapRefreshPendingForTest = false
            return true
        end,
        RequestMinimapRefresh = function(_, reason)
            minimapRefreshRequests[#minimapRefreshRequests + 1] = reason
        end,
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
-- This composed hide condition previously had zero regression coverage --
-- proved by mutation: deleting the indoor branch entirely left every
-- existing assertion in this file green. This closes that gap directly
-- rather than relying on the elevation/style assertions above to
-- incidentally exercise it (they don't -- C_Housing is never touched by
-- anything before this block).
-------------------------------------------------------------------------------

Overlay:Clear()
C_Housing.IsInsideHouse = function() return true end

Overlay:SetPins({ MakePin(6) })
assert(#Overlay:GetActiveFrames() == 0,
    "SetPins must not place any pins while C_Housing.IsInsideHouse() is true")

C_Housing.IsInsideHouse = function() return false end

print("hs208_minimap_pin_spikes: indoor-housing pin suppression ok")

-------------------------------------------------------------------------------
-- HS-362: pins must stay hidden while the generic IsIndoors() flag is true,
-- independent of C_Housing.IsInsideHouse() -- an ordinary building (not a
-- player house) still needs pins suppressed, since its vendors-outside-the-
-- walls case has no distinct map ID for a collect-time fix to key off. This
-- must be re-checked live (via RefreshPositions/SetPins, not a one-shot
-- collect-time filter) since walking into a same-map-ID building never
-- triggers a new collect at all -- see IsInsideBuilding() in
-- HomesteadMinimapOverlay.lua for why.
-------------------------------------------------------------------------------

IsIndoors = function() return true end

Overlay:SetPins({ MakePin(7) })
assert(#Overlay:GetActiveFrames() == 0,
    "SetPins must not place any pins while IsIndoors() is true")

IsIndoors = function() return false end

print("hs208_minimap_pin_spikes: indoor-building pin suppression ok")

-------------------------------------------------------------------------------
-- HS-367: a SetPins call landing WHILE hidden must not destroy existing pin
-- state. An earlier design's caller unconditionally cleared activePins
-- BEFORE checking hide -- so any refresh trigger landing while already
-- indoors wiped pin state permanently, with nothing to restore it (a
-- same-mapID exit never re-triggers a collect, and the old Clear() call
-- also stopped the OnUpdate driver RefreshPositions relies on). Reproduces
-- the failure at the Overlay level, where both the bug and the fix live:
-- SetPins must leave activePins untouched while hidden, and the existing
-- per-frame RefreshPositions check must resume showing the SAME frames --
-- no recreate -- the instant hidden goes false again.
-------------------------------------------------------------------------------

Overlay:SetPins({ MakePin(8), MakePin(9) })
assert(#Overlay:GetActiveFrames() == 2, "expected 2 active pins before the hide cycle")
local createsBeforeHideCycle = frameCreateCalls
local framesBeforeHide = {}
for _, pin in ipairs(Overlay:GetActiveFrames()) do
    framesBeforeHide[pin.vendor.npcID] = pin.frame
end

-- A refresh LANDS while indoors -- the drop this ticket exists to close.
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
    assert(pin.frame.__shown ~= true, "pins must not be left shown while indoors")
end

-- Un-hide: the same per-frame check that hid them must resume showing them,
-- reusing the exact same frames -- the recovery edge the drop defect broke.
C_Housing.IsInsideHouse = function() return false end
Overlay:RefreshPositions(true)

assert(frameCreateCalls == createsBeforeHideCycle,
    "recovering from hidden must reuse the surviving frames, not recreate them")

print("hs208_minimap_pin_spikes: hidden SetPins no longer destroys pin state ok")

-------------------------------------------------------------------------------
-- HS-367: the reconciliation backstop replays a dropped refresh request.
-- MinimapPinCollect.lua's hide-check drop site marks a pending refresh
-- instead of silently losing it; the backstop's own ticker consumes that
-- flag the moment ShouldHideMinimapPins() next reports false.
-------------------------------------------------------------------------------

Overlay:Clear()
minimapPinsEnabledForTest = true
vendorFilterEnabledForTest = true
C_Housing.IsInsideHouse = function() return true end
Overlay:StartReconciliationBackstop()
assert(activeTicker ~= nil, "StartReconciliationBackstop must register a ticker")

-- Establish a reconciled baseline through the same mechanism production
-- uses -- the tick itself, not a direct SetPins call (unreached while
-- hidden). The first tick always fires once (nothing reconciled yet);
-- discard that request before testing the pending-flag mechanic itself.
activeTicker.callback()
minimapRefreshRequests = {}
minimapRefreshPendingForTest = true

-- Not yet un-hidden: the tick must NOT replay while still suppressed.
activeTicker.callback()
assert(#minimapRefreshRequests == 0,
    "a pending refresh must not replay while still suppressed")
assert(minimapRefreshPendingForTest == true,
    "the pending flag must survive a tick that stays suppressed")

-- Suppression lifts: the very next tick must replay it exactly once.
C_Housing.IsInsideHouse = function() return false end
activeTicker.callback()
assert(#minimapRefreshRequests == 1 and minimapRefreshRequests[1] == "reconciliation_backstop",
    "the backstop must replay a pending refresh the moment hidden goes false")
assert(minimapRefreshPendingForTest == false,
    "a replayed refresh must consume the pending flag")

Overlay:StopReconciliationBackstop()

print("hs208_minimap_pin_spikes: reconciliation backstop replays pending refresh ok")

-------------------------------------------------------------------------------
-- HS-367: the reconciliation backstop self-heals even with ZERO active
-- pins. A backstop hosted on RefreshPositions's OnUpdate loop only runs
-- while #activePins > 0 and is started solely from SetPins -- never
-- reached while suppressed, so it would be inert in exactly the state it
-- exists to heal (e.g. login/reload while already indoors). This backstop
-- runs on its own always-on ticker instead, so it must detect drift with
-- no active pins and nothing having ever called SetPins this session --
-- and, once it has observed and acted on the current state, it must go
-- quiet rather than keep re-requesting forever.
-------------------------------------------------------------------------------

Overlay:Clear()
assert(#Overlay:GetActiveFrames() == 0, "expected zero active pins for the backstop-at-zero-pins case")

minimapPinsEnabledForTest = true
vendorFilterEnabledForTest = true
minimapRefreshRequests = {}
minimapRefreshPendingForTest = false
C_Housing.IsInsideHouse = function() return false end
mockMapID = 200 -- a mapID nothing has reconciled against this session

Overlay:StartReconciliationBackstop()
activeTicker.callback()
assert(#minimapRefreshRequests == 1 and minimapRefreshRequests[1] == "reconciliation_backstop",
    "the backstop must request a refresh when live state has never been reconciled, even with zero active pins")

-- The tick itself is what reconciles state (not a real SetPins call) --
-- the next tick, with nothing else having changed, must be silent.
minimapRefreshRequests = {}
activeTicker.callback()
assert(#minimapRefreshRequests == 0,
    "the backstop must not re-request once it has already observed and acted on the current live state")

Overlay:StopReconciliationBackstop()

print("hs208_minimap_pin_spikes: reconciliation backstop self-heals at zero active pins ok")

-------------------------------------------------------------------------------
-- HS-367: vendor pins genuinely being off (map-filter source toggled off,
-- while minimap pins stay enabled) must not make the backstop re-request a
-- refresh forever. That state never resolves to a real SetPins call on its
-- own -- there is nothing to reconcile TO -- so treating it as ordinary
-- drift would fire a refresh every tick for the rest of the session.
-------------------------------------------------------------------------------

Overlay:Clear()
minimapPinsEnabledForTest = true
vendorFilterEnabledForTest = false -- the vendor map-filter source is off
C_Housing.IsInsideHouse = function() return false end
mockMapID = 300
minimapRefreshRequests = {}

Overlay:StartReconciliationBackstop()
activeTicker.callback()
activeTicker.callback()
activeTicker.callback()
assert(#minimapRefreshRequests == 0,
    "the backstop must not request refreshes while vendor pins are genuinely off")

-- Turning the filter back on is real drift (nothing was ever reconciled
-- while it was off) and must be caught exactly once.
vendorFilterEnabledForTest = true
activeTicker.callback()
assert(#minimapRefreshRequests == 1 and minimapRefreshRequests[1] == "reconciliation_backstop",
    "re-enabling vendor pins must be treated as drift and trigger exactly one refresh")

minimapRefreshRequests = {}
activeTicker.callback()
assert(#minimapRefreshRequests == 0,
    "the backstop must go quiet again once re-enabling has been reconciled")

Overlay:StopReconciliationBackstop()

print("hs208_minimap_pin_spikes: reconciliation backstop stays quiet while vendor pins are off ok")
