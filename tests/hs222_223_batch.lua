-- luacheck: globals assert loadfile print io loadstring UnitFactionGroup
-- luacheck: globals showBadgeCalls hideBadgeCalls showGlowCalls hideGlowCalls hideCheckmarkCalls applyOwnedCalls

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-222: badge pool key drops live counts (HomesteadWorldMapProvider.lua),
-- and PinFrameFactory:RefreshBadgePinVisuals (the single source of truth,
-- shared by CreateBadgePinFrame and the provider's post-acquire call) RESETS
-- a reused frame's tint/text instead of only re-applying when a condition
-- matches. HomesteadWorldMapProvider.lua pulls in MapPinProvider/frame:SetScale/
-- etc through Provider:RenderEntries, so the pool-key functions are extracted
-- (same technique as hs202/hs208) rather than a full load through the render
-- pipeline. PinFrameFactory.lua itself has no file-scope CreateFrame/heavy
-- init (only inside its Create*/Refresh* methods), so it loads standalone for
-- real — no extraction needed for RefreshBadgePinVisuals.
-------------------------------------------------------------------------------

local providerSource = assert(io.open(root .. "/UI/HomesteadWorldMapProvider.lua", "r")):read("*a")

local function ExtractFunction(name)
    local text = providerSource:match('(local function ' .. name .. '%(.-%).-\nend)')
    assert(text ~= nil, "could not extract " .. name .. " from HomesteadWorldMapProvider.lua")
    return text
end

local poolKeyChunk = "local _, HA = ...\n"
    .. "local PinFrameFactory = HA.PinFrameFactory\n"
    .. "local format = string.format\n"
    .. "local function BoolToKey(v) return v and \"1\" or \"0\" end\n"
    .. ExtractFunction("BuildWorldPinStyleKey")
    .. "\n" .. ExtractFunction("GetBadgeDisplayFactionKey")
    .. "\n" .. ExtractFunction("GetBadgeFramePoolKey")
    .. "\nreturn { GetBadgeFramePoolKey = GetBadgeFramePoolKey }"

UnitFactionGroup = function() return "Alliance" end

local PinFrameStubHA = {
    PinFrameFactory = {
        GetPinIconSize = function() return 10 end,
        IsCustomPinColor = function() return false end,
        GetPinColor = function() return 1, 1, 1 end,
        DESAT_ALPHA = 0.95,
    },
}

local extracted = assert(loadstring(poolKeyChunk, "badge-pool-key-extract"))("Homestead", PinFrameStubHA)

-- Two badges, same style + faction, wildly different live counts.
local badgeA = { vendorCount = 3, uncollectedCount = 1, oppositeFactionCount = 0 }
local badgeB = { vendorCount = 17, uncollectedCount = 17, oppositeFactionCount = 0 }

assert(extracted.GetBadgeFramePoolKey(badgeA) == extracted.GetBadgeFramePoolKey(badgeB),
    "badges sharing style+faction must share ONE pool key regardless of count combination")

-- Different faction classification MUST still produce a different key
-- (faction is a deliberately-kept, bounded-cardinality key component).
local badgeOpposite = { vendorCount = 3, uncollectedCount = 1, oppositeFactionCount = 3 }
assert(extracted.GetBadgeFramePoolKey(badgeA) ~= extracted.GetBadgeFramePoolKey(badgeOpposite),
    "a genuinely different faction classification must still produce a different pool key")

-- PinFrameFactory:RefreshBadgePinVisuals: reusing a frame for a badge with a
-- DIFFERENT isOppositeFactionOnly verdict must RESET the icon tint and count
-- color, not just leave the frame in whatever state a previous badge left it
-- in. Loads the REAL PinFrameFactory.lua (full file, not extracted text).
local PinFactoryHA = {
    Addon = { db = { profile = { vendorTracer = {} } } },
}
assert(loadfile(root .. "/UI/PinFrameFactory.lua"))("Homestead", PinFactoryHA)
local RealPinFrameFactory = PinFactoryHA.PinFrameFactory
assert(RealPinFrameFactory and RealPinFrameFactory.RefreshBadgePinVisuals,
    "expected PinFrameFactory:RefreshBadgePinVisuals to exist")

local function NewMockBadgeFrame()
    local iconState, countState = {}, {}
    return {
        icon = {
            SetDesaturated = function(_, v) iconState.desaturated = v end,
            SetVertexColor = function(_, r, g, b, a) iconState.color = { r, g, b, a } end,
        },
        count = {
            SetText = function(_, t) countState.text = t end,
            SetTextColor = function(_, r, g, b) countState.color = { r, g, b } end,
        },
        _iconState = iconState,
        _countState = countState,
    }
end

local frame = NewMockBadgeFrame()

-- First: an opposite-faction-only badge (desaturated grey icon, colored count).
local oppositeOnlyBadge = { vendorCount = 3, uncollectedCount = 3, oppositeFactionCount = 3, dominantFaction = "Horde" }
RealPinFrameFactory:RefreshBadgePinVisuals(frame, oppositeOnlyBadge)
assert(frame._iconState.desaturated == true, "opposite-faction-only badge must desaturate the icon")
assert(frame._countState.text == "3")

-- Reuse the SAME frame object for a badge that is NOT opposite-faction-only
-- (same pool key bucket, different counts) — the icon tint and count color
-- MUST reset, not remain desaturated/faction-colored from the previous badge.
local mixedBadge = { vendorCount = 5, uncollectedCount = 0, oppositeFactionCount = 0 }
RealPinFrameFactory:RefreshBadgePinVisuals(frame, mixedBadge)
assert(frame._iconState.desaturated == false,
    "reusing a frame for a non-opposite-only badge must reset icon desaturation, not leave it desaturated")
assert(frame._iconState.color[1] == 1 and frame._iconState.color[2] == 1 and frame._iconState.color[3] == 1,
    "reset icon tint must be plain white, not the previous badge's faction grey")
assert(frame._countState.text == "5")
assert(frame._countState.color[1] == 0.2 and frame._countState.color[2] == 1 and frame._countState.color[3] == 0.2,
    "0 uncollected must show the green all-collected count color, not the previous badge's faction color")

print("hs222_223_batch: HS-222 badge pool key + reuse visual reset ok")

-------------------------------------------------------------------------------
-- HS-222 (DRY follow-up): CreateBadgePinFrame and the provider's post-acquire
-- call must both go through the ONE shared method — no duplicated visual
-- logic between the two files.
-------------------------------------------------------------------------------

local pinFrameFactorySource = assert(io.open(root .. "/UI/PinFrameFactory.lua", "r")):read("*a")
assert(pinFrameFactorySource:find("function PinFrameFactory:RefreshBadgePinVisuals", 1, true) ~= nil,
    "expected RefreshBadgePinVisuals to live in PinFrameFactory.lua")
assert(pinFrameFactorySource:find("self:RefreshBadgePinVisuals%(frame, badgeData%)", 1) ~= nil,
    "expected CreateBadgePinFrame to call the shared RefreshBadgePinVisuals instead of inlining the logic")

assert(providerSource:find("PinFrameFactory:RefreshBadgePinVisuals%(frame, entry%.badgeData%)", 1) ~= nil,
    "expected AcquireBadgeFrame to call PinFrameFactory:RefreshBadgePinVisuals")
assert(providerSource:find("local function RefreshBadgeFrameVisuals", 1, true) == nil,
    "the provider-local duplicate of the badge visual refresh must be deleted")

print("hs222_223_batch: HS-222 DRY (single shared RefreshBadgePinVisuals) ok")

-------------------------------------------------------------------------------
-- HS-223a: the dual 10Hz map watchers are merged into one. MapSidePanel no
-- longer runs its own C_Timer.NewTicker(0.1, ...); it registers a callback
-- with the shared watcher hosted in HomesteadWorldMapProvider.lua (loads
-- first per the TOC and owns the canvas relationship). Structural/grep-pins:
-- the actual polling logic (WorldMapFrame state reads, secure-path timing) is
-- exercised in-game, not unit-testable without a real map canvas.
-------------------------------------------------------------------------------

assert(providerSource:find("function Provider:RegisterMapWatchCallback", 1, true) ~= nil,
    "expected Provider to expose RegisterMapWatchCallback")
assert(providerSource:find("function Provider:UnregisterMapWatchCallback", 1, true) ~= nil,
    "expected Provider to expose UnregisterMapWatchCallback")
assert(providerSource:find("for key, cb in pairs%(mapWatchCallbacks%) do", 1) ~= nil,
    "expected the shared ticker to dispatch to every registered external callback")
assert(providerSource:find("local success, err = pcall%(cb, isShown, mapID, maximized%)", 1) ~= nil,
    "expected the dispatch loop to pcall each registrant (Argus cycle 1 WARNING) "
    .. "so one callback's error can't kill the rest of that tick's dispatch")

local mapSidePanelSource = assert(io.open(root .. "/UI/MapSidePanel.lua", "r")):read("*a")

assert(mapSidePanelSource:find("C_Timer%.NewTicker%(0%.1", 1) == nil,
    "MapSidePanel must no longer run its own 0.1s map-state ticker")
assert(mapSidePanelSource:find('WorldMapProvider:RegisterMapWatchCallback%("MapSidePanel", MapWatchTick%)', 1) ~= nil,
    "expected MapSidePanel to register its watch logic with the shared provider ticker")
assert(mapSidePanelSource:find("local function MapWatchTick%(shown, mapID, maximized%)", 1) ~= nil,
    "expected MapSidePanel's watch logic to be a named function taking the shared poll's raw state")

print("hs222_223_batch: HS-223a merged map watcher wiring ok")

-------------------------------------------------------------------------------
-- HS-223b: CatalogOverlay's ApplyResolvedOverlay must skip re-applying
-- Show*/Hide*/ApplyOwnedStyle when the outcome is unchanged since the last
-- tick, and must still repaint when something real changes. Extract the
-- function (self-contained apart from the Show*/Hide* helpers and the
-- appliedState memo table it closes over) against counting stubs.
-------------------------------------------------------------------------------

local catalogOverlaySource = assert(io.open(root .. "/Overlay/CatalogOverlay.lua", "r")):read("*a")

local applyResolvedText = catalogOverlaySource:match(
    '(local function ApplyResolvedOverlay%(.-%).-\nend)')
assert(applyResolvedText ~= nil, "could not extract ApplyResolvedOverlay from CatalogOverlay.lua")

-- HS-223b (Argus cycle 1 CRITICAL): HideAllOverlays must clear appliedState
-- too, or a recycled entry frame rebinding to the SAME item with an
-- unchanged verdict would match the stale signature and skip every Show
-- call. Extracted alongside ApplyResolvedOverlay so both share the same
-- appliedState table in this chunk.
local hideAllText = catalogOverlaySource:match(
    '(local function HideAllOverlays%(.-%).-\nend)')
assert(hideAllText ~= nil, "could not extract HideAllOverlays from CatalogOverlay.lua")

-- Globals, not locals: the extracted chunk below is a SEPARATE loadstring
-- compilation and cannot close over this file's locals — same convention as
-- hs203/hs210's counting stubs.
showBadgeCalls, hideBadgeCalls, showGlowCalls, hideGlowCalls, hideCheckmarkCalls, applyOwnedCalls = 0, 0, 0, 0, 0, 0

local applyChunk = "local appliedState = setmetatable({}, { __mode = \"k\" })\n"
    .. "local function ShowBadgeAtlas() showBadgeCalls = showBadgeCalls + 1 end\n"
    .. "local function HideBadge() hideBadgeCalls = hideBadgeCalls + 1 end\n"
    .. "local function ShowGlow() showGlowCalls = showGlowCalls + 1 end\n"
    .. "local function HideGlow() hideGlowCalls = hideGlowCalls + 1 end\n"
    .. "local function HideCheckmark() hideCheckmarkCalls = hideCheckmarkCalls + 1 end\n"
    .. "local function ApplyOwnedStyle() applyOwnedCalls = applyOwnedCalls + 1 end\n"
    .. applyResolvedText
    .. "\n" .. hideAllText
    .. "\nreturn { ApplyResolvedOverlay = ApplyResolvedOverlay, HideAllOverlays = HideAllOverlays }"

local extracted223b = assert(loadstring(applyChunk, "ApplyResolvedOverlay-extract"))()
local ApplyResolvedOverlay = extracted223b.ApplyResolvedOverlay
local HideAllOverlays = extracted223b.HideAllOverlays

local fakeFrame = { SetAlpha = function() end }

-- First call for this frame: nothing applied yet, must render.
ApplyResolvedOverlay(fakeFrame, 501, "atlas-vendor", "available", true, true, "default")
assert(showBadgeCalls == 1 and showGlowCalls == 1 and applyOwnedCalls == 1,
    "first application must render badge + glow + owned style")

-- Second call, IDENTICAL inputs (simulates the next 5Hz tick with no real
-- change): must skip every Show*/Hide*/ApplyOwnedStyle call.
ApplyResolvedOverlay(fakeFrame, 501, "atlas-vendor", "available", true, true, "default")
assert(showBadgeCalls == 1 and showGlowCalls == 1 and applyOwnedCalls == 1,
    "an unchanged tick must not re-invoke any Show*/Hide*/ApplyOwnedStyle call")

-- Third call, itemID unchanged but glowState changed (e.g. OWNERSHIP_UPDATED
-- flipped it to owned): a real change must still repaint.
ApplyResolvedOverlay(fakeFrame, 501, "atlas-vendor", "owned", true, true, "default")
assert(showGlowCalls == 2 and applyOwnedCalls == 2,
    "a real verdict change must still repaint, not be suppressed by the memo")

print("hs222_223_batch: HS-223b idle no-op redraw skip ok")

-------------------------------------------------------------------------------
-- HS-223b (Argus cycle 1 CRITICAL, recycle scenario): a frame that passes
-- through HideAllOverlays (early-return path — nil entryInfo, nil itemID, or
-- the master toggle off) and then rebinds to the SAME item with the SAME
-- verdict must repaint, not skip on a stale signature.
-------------------------------------------------------------------------------

HideAllOverlays(fakeFrame)
assert(hideBadgeCalls == 1 and hideGlowCalls == 1 and hideCheckmarkCalls == 1,
    "HideAllOverlays must hide badge/glow/checkmark")

local showBadgeCallsBeforeRecycle, showGlowCallsBeforeRecycle, applyOwnedCallsBeforeRecycle =
    showBadgeCalls, showGlowCalls, applyOwnedCalls

-- Recycle: rebind to the EXACT same (itemID, atlas, glowState, settings) that
-- was applied before the hide. Without clearing appliedState in
-- HideAllOverlays, this signature would still match the pre-hide memo and
-- every Show* call below would be wrongly skipped.
ApplyResolvedOverlay(fakeFrame, 501, "atlas-vendor", "owned", true, true, "default")
assert(showBadgeCalls == showBadgeCallsBeforeRecycle + 1
    and showGlowCalls == showGlowCallsBeforeRecycle + 1
    and applyOwnedCalls == applyOwnedCallsBeforeRecycle + 1,
    "a frame recycled through HideAllOverlays must repaint on rebind, even with an unchanged verdict")

print("hs222_223_batch: HS-223b recycle-through-hide repaint ok")
