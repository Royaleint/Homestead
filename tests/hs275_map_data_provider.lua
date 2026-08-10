-- luacheck: globals assert loadfile print io loadstring

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-275: the 10Hz world-map watcher ticker is replaced with a pin-less
-- MapCanvas data provider. Structural/grep pins against regression -- the
-- actual dispatch (Blizzard calling our handlers from secureexecuterange) is
-- exercised in-game, not unit-testable without a real map canvas.
-------------------------------------------------------------------------------

local providerSource = assert(io.open(root .. "/UI/HomesteadWorldMapProvider.lua", "r")):read("*a")

-- 1. The 10Hz ticker is gone. NOTE: this line is a Lua pattern, not the old
-- ticker literal quoted verbatim in a comment -- keep it that way, or this
-- assertion would trivially find its own text.
assert(providerSource:find("NewTicker%(0%.1") == nil,
    "the 10Hz map-state polling ticker must be deleted")

-- 2. Exactly one NewTicker remains: the login pool-floor pre-build poll,
-- which is unrelated to map-state detection and explicitly out of scope.
local tickerLine = nil
local tickerCount = 0
for line in providerSource:gmatch("[^\n]+") do
    if line:find("NewTicker", 1, true) then
        tickerCount = tickerCount + 1
        tickerLine = line
    end
end
assert(tickerCount == 1,
    "expected exactly one remaining NewTicker call (the login pool-floor poll), found " .. tickerCount)
assert(tickerLine ~= nil and tickerLine:find("POOL_FLOOR_LOGIN_POLL_INTERVAL", 1, true) ~= nil,
    "the one remaining NewTicker must be the named POOL_FLOOR_LOGIN_POLL_INTERVAL poll, not a new map-state timer")

-- 3. The provider registers itself as a real pin-less data provider.
assert(providerSource:find("WorldMapFrame:AddDataProvider(mapDataProvider)", 1, true) ~= nil,
    "expected EnsureRegistered to call WorldMapFrame:AddDataProvider(mapDataProvider)")

-- 4. Built from the mixin Blizzard defines for canvas data providers.
assert(providerSource:find("CreateFromMixins(MapCanvasDataProviderMixin)", 1, true) ~= nil,
    "expected the delegate to be built via CreateFromMixins(MapCanvasDataProviderMixin)")

-- 5. Registration-time fail-loud assert: a missing OnCanvasScaleChanged must
-- error(), not silently return or just Debug-log.
assert(providerSource:find("MapCanvasDataProviderMixin.OnCanvasScaleChanged == nil", 1, true) ~= nil,
    "expected a registration-time guard checking MapCanvasDataProviderMixin.OnCanvasScaleChanged")
assert(providerSource:find("error(", 1, true) ~= nil,
    "expected a fail-loud error() call guarding the missing-mixin-method case")

-- 6. Every dispatched method name Provider needs is defined on the delegate
-- methods table, including RemoveAllData (ADDENDUM item 1 -- required by
-- MapCanvasMixin:RemoveDataProvider, which calls it before clearing the
-- provider table key; the inherited stub is a no-op and would strand
-- rendered pins on a future unregister).
for _, methodName in ipairs({
    "OnCanvasScaleChanged", "OnCanvasSizeChanged", "OnMapChanged",
    "OnShow", "OnHide", "RefreshAllData", "RemoveAllData",
}) do
    assert(providerSource:find("function mapDataProviderMethods:" .. methodName .. "%(%)") ~= nil,
        "expected mapDataProviderMethods:" .. methodName .. "() to be defined")
end

-- 7. The UIParent-scale residue is caught by Homestead's own event frame
-- (engine events via CreateFrame+RegisterEvent), not by asking the mixin's
-- provider-event mechanism to watch a global event.
for _, eventName in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
    local pattern = 'RegisterEvent%("' .. eventName .. '"%)'
    local pos = providerSource:find(pattern)
    assert(pos ~= nil, "expected RegisterEvent(\"" .. eventName .. "\") to be present")

    -- "not preceded by MapCanvasDataProviderMixin on the same line" -- find
    -- the start of that line and confirm MapCanvasDataProviderMixin doesn't
    -- appear between the line start and the RegisterEvent call.
    local lineStart = providerSource:sub(1, pos):match(".*\n()") or 1
    local linePrefix = providerSource:sub(lineStart, pos)
    assert(linePrefix:find("MapCanvasDataProviderMixin", 1, true) == nil,
        eventName .. "'s RegisterEvent must go through Homestead's own event frame, "
        .. "not MapCanvasDataProviderMixin:RegisterEvent")
end

-- 8. The pin-less invariant, permanently pinned: this provider must never
-- enter Blizzard's managed pin lifecycle.
assert(providerSource:find("AcquirePin", 1, true) == nil,
    "the map data provider must never call AcquirePin -- pin-less is absolute")
assert(providerSource:find("pinPools", 1, true) == nil,
    "the map data provider must never touch pinPools -- pin-less is absolute")

-- 9. [ADDENDUM item 2] One-mechanism constraint, narrowed to CALL patterns so
-- explanatory comments naming EventRegistry stay legal (e.g. contrasting it
-- with the mechanism actually used).
for _, callPattern in ipairs({
    "EventRegistry:Register", "EventRegistry.Register", "EventRegistry:TriggerEvent",
}) do
    assert(providerSource:find(callPattern, 1, true) == nil,
        "expected no " .. callPattern .. " call -- map-state detection is provider "
        .. "dispatch + two engine events, not EventRegistry")
end

-- 10. mapDataProvider is a file-scope local (its identity is what
-- RemoveDataProvider would need to match on -- CLAIM-PINS-0011).
assert(providerSource:find("local mapDataProvider = nil", 1, true) ~= nil,
    "expected mapDataProvider to be declared as a file-scope local")

print("hs275_map_data_provider: HS-275 pin-less map data provider structural pins ok")
