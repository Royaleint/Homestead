-- luacheck: globals assert loadfile print io loadstring

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-368: HybridMinimap vendor pin coverage. Structural/grep pins against
-- regression -- the actual dispatch (Blizzard calling our handlers from
-- secureexecuterange) is exercised in-game, not unit-testable without a real
-- map canvas. Same idiom as tests/hs275_map_data_provider.lua.
-------------------------------------------------------------------------------

local providerSource = assert(io.open(root .. "/UI/HybridMinimapProvider.lua", "r")):read("*a")

-- 1. The pin-less invariant, permanently pinned: this provider must never
-- enter Blizzard's managed pin lifecycle or hook a Blizzard-owned frame. The
-- header comment deliberately avoids these literal identifiers so this
-- assertion doesn't just find its own text (same self-matching trap
-- hs275_map_data_provider.lua:14-16 documents).
assert(providerSource:find("AcquirePin", 1, true) == nil,
    "the HybridMinimap provider must never call AcquirePin -- pin-less is absolute")
assert(providerSource:find("MapCanvasPinMixin", 1, true) == nil,
    "the HybridMinimap provider must never reference MapCanvasPinMixin")
assert(providerSource:find("HookScript(", 1, true) == nil,
    "the HybridMinimap provider must never call HookScript on a Blizzard frame")
assert(providerSource:find("hooksecurefunc(", 1, true) == nil,
    "the HybridMinimap provider must never call hooksecurefunc on a Blizzard frame")

-- 2. Load-on-demand gate: exactly one ContinueOnAddOnLoaded call, at module
-- scope (not inside a function that could run repeatedly).
local gateCount = 0
for line in providerSource:gmatch("[^\n]+") do
    if line:find("EventUtil.ContinueOnAddOnLoaded(", 1, true) then
        gateCount = gateCount + 1
    end
end
assert(gateCount == 1,
    "expected exactly one EventUtil.ContinueOnAddOnLoaded call, found " .. gateCount)

local moduleScopeGate = providerSource:match(
    '\nEventUtil%.ContinueOnAddOnLoaded%("Blizzard_HybridMinimap"')
assert(moduleScopeGate ~= nil,
    'expected EventUtil.ContinueOnAddOnLoaded("Blizzard_HybridMinimap", ...) at column 1 '
    .. "(module scope, not indented inside a function)")

-- 3. Registration targets HybridMinimap.MapCanvas, never HybridMinimap itself.
assert(providerSource:find("hybridMinimap.MapCanvas:AddDataProvider(", 1, true) ~= nil,
    "expected EnsureRegistered to call hybridMinimap.MapCanvas:AddDataProvider(...)")
assert(providerSource:find("CreateFromMixins(MapCanvasDataProviderMixin)", 1, true) ~= nil,
    "expected the delegate to be built via CreateFromMixins(MapCanvasDataProviderMixin)")

-- 4. Placement targets GetCanvas() -- the pannable inner scroll-child -- not
-- the MapCanvas viewport frame itself. Anchored specifically inside the
-- local GetCanvasAndContainer-equivalent so this isn't just "GetCanvas
-- appears somewhere in the file."
local canvasAccessorBody = providerSource:match(
    "local function GetCanvasAndContainer%(%)(.-)\nend")
assert(canvasAccessorBody, "GetCanvasAndContainer function body not found")
assert(canvasAccessorBody:find("mapCanvas:GetCanvas()", 1, true) ~= nil,
    "expected the placement-path canvas accessor to call mapCanvas:GetCanvas() "
    .. "(the pannable inner scroll-child), not just read MapCanvas directly")

-- 5. RequestRefresh gates on _G.HybridMinimap being nil, and never touches
-- GetMapID itself -- that call lives only in the deferred fire handler,
-- re-checked fresh at fire time.
local requestRefreshBody = providerSource:match(
    "function Provider:RequestRefresh%(reason%)(.-)\nend")
assert(requestRefreshBody, "Provider:RequestRefresh function body not found")
assert(requestRefreshBody:find("_G.HybridMinimap == nil", 1, true) ~= nil,
    "expected Provider:RequestRefresh to gate on _G.HybridMinimap == nil")
assert(requestRefreshBody:find("GetMapID", 1, true) == nil,
    "Provider:RequestRefresh must not touch GetMapID directly -- that belongs only in the "
    .. "deferred fire handler, gated and re-checked at fire time")

-- 6. Registration-time fail-loud guard: a missing OnCanvasScaleChanged must
-- error(), not silently return or just Debug-log.
assert(providerSource:find("MapCanvasDataProviderMixin.OnCanvasScaleChanged == nil", 1, true) ~= nil,
    "expected a registration-time guard checking MapCanvasDataProviderMixin.OnCanvasScaleChanged")
assert(providerSource:find("error(", 1, true) ~= nil,
    "expected a fail-loud error() call guarding the missing-mixin-method case")

-- 7. Correct enable-toggle: the minimap pins toggle, not the world-map toggle.
assert(providerSource:find("IsMinimapPinsEnabled", 1, true) ~= nil,
    "expected the refresh gate to check VendorMapPins:IsMinimapPinsEnabled()")

-- 8. Data reuse: calls BuildWorldMapRenderState directly, never the
-- WorldMapFrame-coupled RefreshPins entry point.
assert(providerSource:find("BuildWorldMapRenderState", 1, true) ~= nil,
    "expected the refresh handler to call VendorMapPins:BuildWorldMapRenderState(mapID)")
assert(providerSource:find("RefreshPins", 1, true) == nil,
    "the HybridMinimap provider must never call the WorldMapFrame-coupled RefreshPins entry point")

-- 9. Public API the VendorMapPins pokes depend on.
assert(providerSource:find("function Provider:RequestRefresh", 1, true) ~= nil,
    "expected a public Provider:RequestRefresh method")
assert(providerSource:find("function Provider:Clear", 1, true) ~= nil,
    "expected a public Provider:Clear method")

-- 10. Every method the canvas-dispatch delegate needs is actually defined.
for _, methodName in ipairs({
    "OnShow", "OnHide", "OnMapChanged", "OnCanvasSizeChanged",
    "OnCanvasScaleChanged", "RefreshAllData", "RemoveAllData",
}) do
    assert(providerSource:find("function providerMethods:" .. methodName .. "%(%)") ~= nil,
        "expected providerMethods:" .. methodName .. "() to be defined")
end

-- 11. Own pool tables -- never shared with MapPinProvider's (two
-- simultaneously-live canvases, world map + HybridMinimap, must not fight
-- over the same pooled frame objects).
assert(providerSource:find("local nativePins = {}", 1, true) ~= nil,
    "expected the provider to own its own nativePins table")
assert(providerSource:find("local nativePinPool = {}", 1, true) ~= nil,
    "expected the provider to own its own nativePinPool table")
assert(providerSource:find("local vendorFramePool = {}", 1, true) ~= nil,
    "expected the provider to own its own vendorFramePool table")

-- 12. The vendor frame pool key must encode every property
-- PinFrameFactory:CreateVendorPinFrame bakes into a frame permanently at
-- creation time (icon size, color, faction, vendorType) -- this module does
-- a full release-then-reacquire pass every refresh with no in-place restyle
-- and no separate flush path, so leaving any of these out of the key means
-- a style change (or a vendorType/faction mismatch on reuse) sticks on
-- already-live frames until /reload, with the stale-styled frames
-- permanently unreachable in the pool. Anchored inside the key-building
-- functions specifically, not "these identifiers appear somewhere."
local poolKeyBody = providerSource:match(
    "local function GetVendorFramePoolKey%(entry%)(.-)\nend")
assert(poolKeyBody, "GetVendorFramePoolKey function body not found")
assert(poolKeyBody:find("BuildVendorPinStyleKey()", 1, true) ~= nil,
    "expected GetVendorFramePoolKey to fold in BuildVendorPinStyleKey()")
assert(poolKeyBody:find("vendor.vendorType", 1, true) ~= nil,
    "expected GetVendorFramePoolKey to include the vendor's vendorType -- "
    .. "PinFrameFactory:CreateVendorPinFrame bakes it into the icon set at creation time")
-- Requires an actual per-vendor read, not just the presence of a fallback
-- constant -- a bare "local factionKey = \"neutral\"" alone would satisfy a
-- looser check while silently dropping the real per-vendor value.
assert(poolKeyBody:find("entry.vendor.faction", 1, true) ~= nil,
    "expected GetVendorFramePoolKey to actually read the vendor's own faction, not just "
    .. "declare a fallback constant")

local styleKeyBody = providerSource:match(
    "local function BuildVendorPinStyleKey%(%)(.-)\nend")
assert(styleKeyBody, "BuildVendorPinStyleKey function body not found")
assert(styleKeyBody:find("GetPinIconSize()", 1, true) ~= nil,
    "expected BuildVendorPinStyleKey to include icon size")
assert(styleKeyBody:find("IsCustomPinColor()", 1, true) ~= nil,
    "expected BuildVendorPinStyleKey to include the custom-color flag")

-- Pins the format call's SHAPE, not just that GetPinColor() is called
-- somewhere in the function -- a mutant that drops or swaps one RGB channel
-- (e.g. passing r, g, r instead of r, g, b) would silently collide two
-- distinct colors into the same pool bucket while still calling every
-- identifier this test used to check for.
local formatPattern = styleKeyBody:match('format%("([^"]+)"')
assert(formatPattern, "expected a format(...) call inside BuildVendorPinStyleKey")
local rgbPlaceholderCount = 0
for _ in formatPattern:gmatch("%%%.3f") do
    rgbPlaceholderCount = rgbPlaceholderCount + 1
end
assert(rgbPlaceholderCount == 3,
    "expected BuildVendorPinStyleKey's format string to carry three %.3f placeholders (one "
    .. "per RGB channel), found " .. rgbPlaceholderCount)
assert(styleKeyBody:find(", r, g, b)", 1, true) ~= nil,
    "expected BuildVendorPinStyleKey's format call to pass r, g, b in that exact order as its "
    .. "final arguments -- dropping or swapping any one channel silently collides distinct "
    .. "colors into the same pool bucket")

-- 13. DoRefresh must not run a full render pass onto a hidden canvas --
-- HybridMinimapMixin:CheckMap can leave self.mapID set while the frame
-- itself stays hidden. Pins the whole guard (the check AND that it actually
-- returns), not just that the IsShown() call appears somewhere in the
-- function -- a mutant that reads IsShown() into an unused local without
-- acting on it would still satisfy a looser check.
local doRefreshBody = providerSource:match("local function DoRefresh%(%)(.-)\nend")
assert(doRefreshBody, "DoRefresh function body not found")
local shownGateBlock = doRefreshBody:match("if not hybridMinimap:IsShown%(%) then(.-)end")
assert(shownGateBlock,
    "expected DoRefresh to contain 'if not hybridMinimap:IsShown() then ... end'")
assert(shownGateBlock:find("RemoveAllData()", 1, true) ~= nil,
    "expected the IsShown() guard to call RemoveAllData() so a hidden canvas doesn't retain "
    .. "stale pins")
assert(shownGateBlock:find("return", 1, true) ~= nil,
    "expected the IsShown() guard to actually return, not just observe the call")

-------------------------------------------------------------------------------
-- Cross-file regression guard: the two VendorMapPins.lua poke calls this
-- provider depends on to stay fed while HybridMinimap is active.
-------------------------------------------------------------------------------

local vmpSource = assert(io.open(root .. "/UI/VendorMapPins.lua", "r")):read("*a")

local refreshMinimapPinsBody = vmpSource:match(
    "function VendorMapPins:RefreshMinimapPins%(%)(.-)\nend")
assert(refreshMinimapPinsBody, "VendorMapPins:RefreshMinimapPins function body not found")
assert(refreshMinimapPinsBody:find("HA.HybridMinimapProvider:RequestRefresh(", 1, true) ~= nil,
    "expected VendorMapPins:RefreshMinimapPins to poke HA.HybridMinimapProvider:RequestRefresh(...)")

local disableMinimapPinsBody = vmpSource:match(
    "function VendorMapPins:DisableMinimapPins%(%)(.-)\nend")
assert(disableMinimapPinsBody, "VendorMapPins:DisableMinimapPins function body not found")
assert(disableMinimapPinsBody:find("HA.HybridMinimapProvider:Clear(", 1, true) ~= nil,
    "expected VendorMapPins:DisableMinimapPins to poke HA.HybridMinimapProvider:Clear()")

print("hs368_hybridminimap_provider: HybridMinimap vendor pin coverage structural pins ok")
