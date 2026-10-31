-- luacheck: globals assert loadfile print io _G

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-- HS-536: vendors that stand side by side (Cordula Wolfgang and Holly
-- Twinklebright on Founder's Point, Spew Gutsout and Jolli Maxiboom on
-- Razorwind Shores) get map positions about 0.001 apart. Their pins are drawn
-- a few pixels apart through a display-only offset (nudgeX/nudgeY) set by
-- MapPinProvider.AssignOverlapNudge. Loads the REAL vendor data, the REAL
-- UI/MapPinProvider.lua, UI/VendorMapPins.lua and UI/MinimapPinCollect.lua.

local profile = {
    debug = false,
    vendorTracer = {
        showOppositeFaction = true,
        showEventVendors = true,
        showMinimapPins = false,
        minimapCrossZoneMode = "off",
    },
}
local HA = {
    Addon = {
        db = {
            profile = profile,
            global = { discoveredInitiativeThemes = {}, scannedVendors = {} },
        },
        Debug = function() end,
        RegisterModule = function() end,
    },
    Events = { Fire = function() end, RegisterCallback = function() end },
}

_G.C_NeighborhoodInitiative = {
    GetNeighborhoodInitiativeInfo = function() return nil end,
}
HA.CalendarDetector = {
    IsHolidayActive = function() return true end,
}

assert(loadfile(root .. "/Data/VendorIdentity.lua"))("Homestead", HA)
assert(loadfile(root .. "/Data/VendorOffers.lua"))("Homestead", HA)
assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)
assert(loadfile(root .. "/Data/EndeavorsData.lua"))("Homestead", HA)
assert(loadfile(root .. "/Data/EventSources.lua"))("Homestead", HA)
local VD = HA.VendorData
VD:BuildOfferIndexes()

local CORDULA, HOLLY, SPEW, JOLLI = 273472, 271604, 273470, 271366
local PAIRS = {
    { map = 2352, a = HOLLY, b = CORDULA },
    { map = 2351, a = JOLLI, b = SPEW },
}

local playerMapID, playerPos
local MAPINFO = { [2351] = "Razorwind Shores", [2352] = "Founder's Point" }
_G.C_Map = {
    GetBestMapForUnit = function() return playerMapID end,
    GetPlayerMapPosition = function() return playerPos end,
    GetMapInfo = function(mapID)
        local name = MAPINFO[mapID]
        if not name then return nil end
        return { name = name, parentMapID = 0, mapType = 3 }
    end,
    GetMapChildrenInfo = function() return {} end,
    GetWorldPosFromMapPos = function(_, pos)
        return 1, { GetXY = function() return pos.x * 1000, pos.y * 1000 end }
    end,
}
_G.CreateVector2D = function(x, y) return { x = x, y = y } end
_G.time = function() return 2000000000 end
_G.GetBuildInfo = function() return "12.0.0", "1", "Jan 1 2026", 120000 end
_G.CreateFrame = function()
    return setmetatable({}, { __index = function() return function() end end })
end
_G.InCombatLockdown = function() return false end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.GetTimePreciseSec = function() return 0 end
_G.C_Timer = {
    NewTicker = function() return { Cancel = function() end } end,
    NewTimer = function() return { Cancel = function() end } end,
    After = function() end,
}
_G.Enum = { UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 } }
_G.IsIndoors = function() return false end
_G.UnitFactionGroup = function() return "Horde" end

assert(loadfile(root .. "/Core/constants.lua"))("Homestead", HA)
assert(loadfile(root .. "/UI/VendorFilter.lua"))("Homestead", HA)
HA.VendorFilter.ShouldHideCompletedVendorPin = function() return false end
HA.PerformanceTrace = { Measure = function(_, _label, _tag, pcallFn, fn) return pcallFn(fn) end }
HA.BadgeCalculation = {}
assert(loadfile(root .. "/UI/MapPinProvider.lua"))("Homestead", HA)
assert(loadfile(root .. "/UI/VendorMapPins.lua"))("Homestead", HA)
local MPP, VMP = HA.MapPinProvider, HA.VendorMapPins
VMP:Initialize()
local collect = VMP.pinSourceProviders.vendor.collect

-- A deep, order-independent dump of a table, to compare before and after.
local function Dump(value, seen)
    if type(value) ~= "table" then return tostring(value) end
    seen = seen or {}
    if seen[value] then return "<cycle>" end
    seen[value] = true
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. Dump(value[k], seen) end
    return "{" .. table.concat(out, ",") .. "}"
end

local function ByNpc(pins)
    local map = {}
    for _, pin in ipairs(pins) do map[pin.vendor.npcID] = pin end
    return map
end

-- Where the pin is drawn, in pixels on a 1000 px canvas (+x right, +y up):
-- its real map position plus the display offset.
local CANVAS = 1000
local function PinX(pin) return pin.x or pin.mapX end
local function PinY(pin) return pin.y or pin.mapY end
local function Drawn(pin)
    return PinX(pin) * CANVAS + (pin.nudgeX or 0), -PinY(pin) * CANVAS + (pin.nudgeY or 0)
end

local function DrawnGap(p, q)
    local px, py = Drawn(p)
    local qx, qy = Drawn(q)
    return math.sqrt((px - qx) ^ 2 + (py - qy) ^ 2)
end

local function RealGap(p, q)
    return math.sqrt((PinX(p) - PinX(q)) ^ 2 + (PinY(p) - PinY(q)) ^ 2) * CANVAS
end

-- a left of b stays left of b, a above b stays above b, and the drawn gap is
-- at least the largest pin width and at least the real gap.
local function CheckSeparated(label, a, b)
    assert(a and b, label .. ": both pins must be drawn")
    assert(a.nudgeX and a.nudgeY and b.nudgeX and b.nudgeY, label .. ": both pins must carry an offset")
    local ax, ay = Drawn(a)
    local bx, by = Drawn(b)
    assert((PinX(a) - PinX(b)) * (ax - bx) >= 0 and (PinY(b) - PinY(a)) * (ay - by) >= 0,
        label .. ": the drawn order of the two pins must match the real order")
    assert(DrawnGap(a, b) >= 18 - 0.05,
        label .. ": the drawn gap must be at least one largest-pin width, got " .. DrawnGap(a, b))
    assert(DrawnGap(a, b) >= RealGap(a, b) - 0.05, label .. ": the drawn gap must not shrink")
end

-------------------------------------------------------------------------------
-- World map: both real pairs separate; the real coordinates stay as they are.
-------------------------------------------------------------------------------

local function WorldPins(mapID)
    local state = { vendorPins = {} }
    collect(VMP, mapID, { [mapID] = true }, "all", state)
    return state.vendorPins
end

local dumpBefore = {}
for _, pair in ipairs(PAIRS) do
    dumpBefore[pair.map] = Dump(VD:GetVendorsInMap(pair.map))
end

for _, pair in ipairs(PAIRS) do
    local pins = WorldPins(pair.map)
    local byNpc = ByNpc(pins)
    local a, b = byNpc[pair.a], byNpc[pair.b]
    CheckSeparated("world map " .. pair.map, a, b)
    -- The drawn anchor is still the real position of each vendor.
    local va, vb = VD:GetVendor(pair.a), VD:GetVendor(pair.b)
    assert(a.x == va.x and a.y == va.y and b.x == vb.x and b.y == vb.y,
        "world map " .. pair.map .. ": the pins' map coordinates must be the real ones")
    assert(a.vendor.x == va.x and b.vendor.y == vb.y,
        "world map " .. pair.map .. ": the vendor tables must keep the real coordinates")
    -- Brute-force check of every pin on the map: it moves only when another
    -- pin lies within the overlap distance (0.005). (Crowds are left alone,
    -- so an overlapping pin may also stay put.)
    local moved = 0
    for _, pin in ipairs(pins) do
        local crowded = false
        for _, other in ipairs(pins) do
            if other ~= pin then
                local dx, dy = other.x - pin.x, other.y - pin.y
                if dx * dx + dy * dy < 0.005 * 0.005 then crowded = true end
            end
        end
        assert(pin.nudgeX == nil or crowded,
            "world map " .. pair.map .. ": vendor " .. pin.vendor.npcID
            .. " must move only when another pin is within 0.005")
        if crowded then moved = moved + 1 end
    end
    assert(moved < #pins, "world map " .. pair.map .. ": not every pin may move")
end

-- The source vendor tables are untouched by any of it.
for _, pair in ipairs(PAIRS) do
    assert(Dump(VD:GetVendorsInMap(pair.map)) == dumpBefore[pair.map],
        "the vendor tables of map " .. pair.map .. " must be unchanged by the nudge")
end

-- Same result on every run.
for _, pair in ipairs(PAIRS) do
    local first = ByNpc(WorldPins(pair.map))
    local second = ByNpc(WorldPins(pair.map))
    for _, npcID in ipairs({ pair.a, pair.b }) do
        assert(first[npcID].nudgeX == second[npcID].nudgeX and first[npcID].nudgeY == second[npcID].nudgeY,
            "vendor " .. npcID .. " must get the same offset on every redraw")
    end
end

-------------------------------------------------------------------------------
-- The grouping rule itself, on synthetic pins.
-------------------------------------------------------------------------------

local function Pin(npcID, x, y, mapID)
    return { vendor = { npcID = npcID }, x = x, y = y, mapID = mapID or 1 }
end

do
    -- A lone pin is unchanged, even with far neighbors.
    local pins = { Pin(1, 0.2, 0.2), Pin(2, 0.5, 0.5), Pin(3, 0.8, 0.1) }
    MPP.AssignOverlapNudge(pins, "x", "y")
    for _, pin in ipairs(pins) do
        assert(pin.nudgeX == nil and pin.nudgeY == nil, "a lone pin must carry no offset")
    end
    assert(pins[1].x == 0.2 and pins[2].y == 0.5, "the pin coordinates must never be rewritten")

    -- A stale offset from an earlier pass is cleared when the pin is alone again.
    pins[1].nudgeX, pins[1].nudgeY = 5, 5
    MPP.AssignOverlapNudge(pins, "x", "y")
    assert(pins[1].nudgeX == nil and pins[1].nudgeY == nil, "a stale offset must be cleared")

    -- Input order does not matter.
    local forward = { Pin(10, 0.3, 0.3), Pin(20, 0.3004, 0.3003), Pin(30, 0.3002, 0.3008) }
    local backward = { Pin(30, 0.3002, 0.3008), Pin(20, 0.3004, 0.3003), Pin(10, 0.3, 0.3) }
    MPP.AssignOverlapNudge(forward, "x", "y")
    MPP.AssignOverlapNudge(backward, "x", "y")
    local f, bk = ByNpc(forward), ByNpc(backward)
    for _, npcID in ipairs({ 10, 20, 30 }) do
        assert(f[npcID].nudgeX and f[npcID].nudgeX == bk[npcID].nudgeX and f[npcID].nudgeY == bk[npcID].nudgeY,
            "pin " .. npcID .. " must get the same offset whatever the input order")
    end
    assert(DrawnGap(f[10], f[20]) >= 16 and DrawnGap(f[20], f[30]) >= 16 and DrawnGap(f[10], f[30]) >= 16,
        "a group of three must be spread apart")

    -- Asymmetric pair 4 px apart, aligned with the x axis: each pin moves
    -- outward along the axis, the order holds, and the gap never shrinks.
    local asym = { Pin(10, 0.500, 0.5), Pin(20, 0.504, 0.5) }
    MPP.AssignOverlapNudge(asym, "x", "y")
    CheckSeparated("asymmetric pair", asym[1], asym[2])
    assert(select(1, Drawn(asym[1])) < select(1, Drawn(asym[2])), "the west pin must stay west")
    -- The same pair with the npcIDs swapped: geometry decides the sides, not the npcID.
    local swapped = { Pin(20, 0.500, 0.5), Pin(10, 0.504, 0.5) }
    MPP.AssignOverlapNudge(swapped, "x", "y")
    CheckSeparated("swapped-id pair", swapped[1], swapped[2])
    assert(select(1, Drawn(swapped[1])) < select(1, Drawn(swapped[2])), "the west pin must stay west")

    -- Diagonal pair.
    local diag = { Pin(10, 0.500, 0.5), Pin(20, 0.5025, 0.5025) }
    MPP.AssignOverlapNudge(diag, "x", "y")
    CheckSeparated("diagonal pair", diag[1], diag[2])

    -- A chained row (each pin 4 px from the next, 10 pins) is a crowd: left alone.
    local row = {}
    for i = 1, 10 do row[i] = Pin(100 + i, 0.4 + (i - 1) * 0.004, 0.5) end
    MPP.AssignOverlapNudge(row, "x", "y")
    for i, pin in ipairs(row) do
        assert(pin.nudgeX == nil and pin.nudgeY == nil, "pin " .. i .. " of a crowded row must stay where it is")
    end

    -- A pin with three neighbors within 18 px makes its whole group a crowd,
    -- even when the group itself has only two overlapping pins.
    local crowdA = { Pin(1, 0.5, 0.5), Pin(2, 0.502, 0.5), Pin(3, 0.51, 0.5), Pin(4, 0.5, 0.51) }
    MPP.AssignOverlapNudge(crowdA, "x", "y")
    for _, pin in ipairs(crowdA) do
        assert(pin.nudgeX == nil, "a crowd with anchors in reach must stay where it is")
    end

    -- E/A/B: A and B overlap each other, E does not overlap either but sits
    -- 6 px from A. E is an anchor: it does not move, and A is not pushed onto it.
    local eab = { Pin(1, 0.500, 0.5), Pin(2, 0.506, 0.5), Pin(3, 0.507, 0.5) }
    MPP.AssignOverlapNudge(eab, "x", "y")
    assert(eab[1].nudgeX == nil and eab[1].nudgeY == nil, "the anchor E must get no nudge")
    assert(eab[2].nudgeX and eab[3].nudgeX, "A and B must be nudged")
    for _, other in ipairs({ eab[2], eab[3] }) do
        assert(DrawnGap(eab[1], other) >= math.min(RealGap(eab[1], other), 18) - 0.05,
            "a nudged pin must not be pushed closer to the anchor than it really is")
        assert(select(1, Drawn(eab[1])) < select(1, Drawn(other)), "E must stay west of A and B")
    end
    assert(select(1, Drawn(eab[2])) < select(1, Drawn(eab[3])), "A must stay west of B")
    for _, pin in ipairs(eab) do
        assert(math.sqrt((pin.nudgeX or 0) ^ 2 + (pin.nudgeY or 0) ^ 2) <= 24.01, "no pin moves past the cap")
    end
    -- B would need 29 px to clear both; the 24 px cap leaves A and B 14.7 px apart.
    assert(DrawnGap(eab[2], eab[3]) >= 14, "A and B must be spread apart")

    -- Y/A/B: Y is 20 px from A, past the 18 px reach, but A moves up to 24 px
    -- when A and B are pushed apart. Y must not end up crowded by A.
    local yab = { Pin(1, 0.000, 0.5), Pin(2, 0.020, 0.5), Pin(3, 0.021, 0.5) }
    MPP.AssignOverlapNudge(yab, "x", "y")
    assert(yab[1].nudgeX == nil and yab[2].nudgeX and yab[3].nudgeX, "only A and B are nudged")
    for _, other in ipairs({ yab[2], yab[3] }) do
        assert(DrawnGap(yab[1], other) >= math.min(RealGap(yab[1], other), 18) - 0.05,
            "a mover must not be pushed closer to a pin 20 px away than it really is")
    end

    -- The direction of two coincident pins depends on their npcIDs only.
    local solo = { Pin(10, 0.2, 0.2), Pin(20, 0.2, 0.2) }
    local crowd = { Pin(10, 0.2, 0.2), Pin(20, 0.2, 0.2), Pin(5, 0.9, 0.9), Pin(6, 0.1, 0.9) }
    MPP.AssignOverlapNudge(solo, "x", "y")
    MPP.AssignOverlapNudge(crowd, "x", "y")
    assert(solo[1].nudgeX == crowd[1].nudgeX and solo[1].nudgeY == crowd[1].nudgeY,
        "coincident pins must get the same direction whatever else is on the map")

    -- Pins just past the threshold stay put; different maps never group.
    local apart = { Pin(1, 0.5, 0.5), Pin(2, 0.5051, 0.5) }
    MPP.AssignOverlapNudge(apart, "x", "y")
    assert(apart[1].nudgeX == nil and apart[2].nudgeX == nil, "pins past the threshold must not move")
    local maps = { Pin(1, 0.5, 0.5, 100), Pin(2, 0.5, 0.5, 200) }
    MPP.AssignOverlapNudge(maps, "x", "y", "mapID")
    assert(maps[1].nudgeX == nil and maps[2].nudgeX == nil, "pins on different maps must not group")

    -- NaN input is ignored, not grouped.
    local nan = { Pin(1, 0 / 0, 0.5), Pin(2, 0 / 0, 0.5) }
    MPP.AssignOverlapNudge(nan, "x", "y")
    assert(nan[1].nudgeX == nil and nan[2].nudgeX == nil, "NaN pins must be ignored")
end

-- Nudged pins skip the POI dodge: it picks a direction per vendor and would
-- pull a nudged pair back together. (Exercised in game; structural pin here.)
do
    local provider = assert(io.open(root .. "/UI/HomesteadWorldMapProvider.lua", "r")):read("*a")
    local body = provider:match("local function ApplyAreaPoiDodge%(entry, x, y%)(.-)\nend")
    assert(body and body:find("if entry.nudgeX then%s+return x, y%s+end"),
        "ApplyAreaPoiDodge must return early for nudged pins")
end

-------------------------------------------------------------------------------
-- Every map in the vendor data: for each nudged pin and each pin within 0.018
-- of it (nudged or not; 18 px reach plus the 24 px a mover can travel), the drawn gap is at least min(real gap, 18) and the
-- drawn order matches the real order on both axes.
-------------------------------------------------------------------------------

do
    local maps = {}
    for _, v in pairs(HA.VendorIdentity.Vendors) do
        if v.mapID then maps[v.mapID] = true end
    end
    local checked, anchors, notNudged = 0, 0, 0
    local notNudgedByMap = {}
    local razorwindCrowd = {}
    for mapID in pairs(maps) do
        local pins = {}
        for _, v in ipairs(VD:GetVendorsInMap(mapID) or {}) do
            if v.x and v.y then pins[#pins + 1] = { vendor = v, x = v.x, y = v.y } end
        end
        MPP.AssignOverlapNudge(pins, "x", "y")
        for i, p in ipairs(pins) do
            local overlaps = false
            for j, q in ipairs(pins) do
                if p ~= q then
                    local real = RealGap(p, q)
                    if real < 5 then overlaps = true end
                    if real < 18 + 24 and (p.nudgeX or q.nudgeX) then
                        local px, py = Drawn(p)
                        local qx, qy = Drawn(q)
                        local label = "map " .. mapID .. " pins " .. p.vendor.npcID .. "/" .. q.vendor.npcID
                        checked = checked + 1
                        if i < j and not (p.nudgeX and q.nudgeX) then anchors = anchors + 1 end
                        assert(math.sqrt((px - qx) ^ 2 + (py - qy) ^ 2) >= math.min(real, 18) - 0.05,
                            label .. ": the drawn gap must be at least min(real gap, 18)")
                        -- Order must hold on every axis where the real gap is 5 px or more.
                        for _, axis in ipairs({ { (p.x - q.x) * CANVAS, px - qx },
                                { (q.y - p.y) * CANVAS, py - qy } }) do
                            if math.abs(axis[1]) >= 5 then
                                assert(axis[1] * axis[2] > 0, label .. ": the drawn order must match the real order")
                            end
                        end
                    end
                end
            end
            if overlaps and p.nudgeX == nil then
                notNudged = notNudged + 1
                notNudgedByMap[mapID] = (notNudgedByMap[mapID] or 0) + 1
                if mapID == 2351 then razorwindCrowd[p.vendor.npcID] = true end
            end
        end
    end
    -- The Razorwind Shores cluster is a crowd and stays exactly where it is.
    for _, npcID in ipairs({ 257257, 255278, 255297, 255298, 268106 }) do
        assert(razorwindCrowd[npcID], "Razorwind Shores vendor " .. npcID .. " must be left un-nudged")
    end
    local clusterLeftAlone = 0
    for _ in pairs(razorwindCrowd) do clusterLeftAlone = clusterLeftAlone + 1 end
    assert(clusterLeftAlone >= 8, "the Razorwind Shores cluster must be left un-nudged, got " .. clusterLeftAlone)
    assert(checked > 0)
    local list = {}
    for mapID, count in pairs(notNudgedByMap) do list[#list + 1] = mapID .. "=" .. count end
    table.sort(list)
    print("hs536 oracle: " .. checked .. " directed pairs hold; " .. anchors .. " nudged-pin/anchor pairs; "
        .. notNudged .. " overlapping pins left un-nudged by map: " .. table.concat(list, " "))
end

-------------------------------------------------------------------------------
-- Minimap drawn position: rotation, then rim clamp, from the real position.
-------------------------------------------------------------------------------

do
    local N = MPP.NudgeMinimapPosition
    local function near(a, b) return math.abs(a - b) < 1e-9 end
    -- North-up, mid-minimap pin, nudge 9 px right and 3 px up on a 70x70 half-size minimap.
    local x, y = N(0.1, 0.2, 9, 3, 70, 70, 0, 1, false, true)
    assert(near(x, 0.1 + 9 / 70) and near(y, 0.2 - 3 / 70), "a north-up nudge adds right/up pixels")
    -- Facing 90 degrees: the nudge rotates with the minimap.
    x, y = N(0.1, 0.2, 9, 3, 70, 70, 1, 0, true, true)
    assert(near(x, 0.1 + 3 / 70) and near(y, 0.2 + 9 / 70), "the nudge must rotate with the minimap")
    -- A pin on the rim, nudged outward, is clamped back to the rim (0.9 radius).
    x, y = N(0.9, 0, 12, 0, 70, 70, 0, 1, false, true)
    assert(near(x * x + y * y, 0.81), "a pin nudged past the mask must be clamped to the rim")
    -- Square minimap shape clamps on the larger axis.
    x = N(0.9, 0.3, 12, 0, 70, 70, 0, 1, false, false)
    assert(near(x, 0.9), "a square minimap clamps to its edge")
    -- Nudged inward from the rim: no clamp.
    x, y = N(0.9, 0, -12, 0, 70, 70, 0, 1, false, true)
    assert(near(x, 0.9 - 12 / 70) and near(y, 0), "an inward nudge is not clamped")
end

-------------------------------------------------------------------------------
-- Minimap: the same pairs get the offset; the world position is the real one.
-------------------------------------------------------------------------------

local collected
local minimapHA = {
    Constants = HA.Constants,
    Addon = HA.Addon,
    VendorData = VD,
    VendorFilter = HA.VendorFilter,
    PerformanceTrace = { Measure = function(_, _label, _tag, fn) return fn() end },
    HomesteadMinimapOverlay = {
        ShouldHideMinimapPins = function() return false end,
        SetPins = function(_, pins) collected = pins end,
    },
    MapPinProvider = MPP,
    VendorMapPins = {
        IsInitialized = function() return true end,
        IsMinimapPinsEnabled = function() return true end,
        IsMapFilterSourceEnabled = function() return true end,
        ClearMinimapPins = function() end,
        IsMinimapWarmupActive = function() return false end,
        CanAccessVendor = function() return true end,
        IsOppositeFaction = function() return false end,
    },
}
assert(loadfile(root .. "/UI/MinimapPinCollect.lua"))("Homestead", minimapHA)

for _, pair in ipairs(PAIRS) do
    playerMapID, playerPos = pair.map, { x = 0.5, y = 0.5 }
    collected = nil
    minimapHA.MinimapPinCollect:RefreshMinimapPins()
    local byNpc = ByNpc(collected or {})
    local a, b = byNpc[pair.a], byNpc[pair.b]
    CheckSeparated("minimap " .. pair.map, a, b)
    local va = VD:GetVendor(pair.a)
    assert(a.worldX == va.y * 1000 and a.worldY == va.x * 1000,
        "minimap " .. pair.map .. ": the world position must be the real one")
end


-- On the minimap the nudge is scaled to the minimap pin's width (12 px
-- by default, against the 18 px world-map pin the nudge is sized for), so a
-- pair ends up one minimap pin apart instead of 18 px apart. The world-map
-- nudge values above are not touched.
do
    local MINIMAP_PIN = 12
    for _, p in ipairs(PAIRS) do
        playerMapID, playerPos = p.map, { x = 0.5, y = 0.5 }
        collected = nil
        minimapHA.MinimapPinCollect:RefreshMinimapPins()
        local byNpc = ByNpc(collected or {})
        local a, b = byNpc[p.a], byNpc[p.b]
        local ax, ay = MPP.NudgeMinimapPosition(0, 0, a.nudgeX, a.nudgeY, 1000, 1000, 0, 1, false, true, MINIMAP_PIN)
        local bx, by = MPP.NudgeMinimapPosition(0, 0, b.nudgeX, b.nudgeY, 1000, 1000, 0, 1, false, true, MINIMAP_PIN)
        local realGap = RealGap(a, b) -- px on the 1000 px reference canvas, ~1 px
        ax, ay, bx, by = ax * 1000, ay * 1000, bx * 1000, by * 1000
        local gap = math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
        local off = math.max(math.sqrt(ax * ax + ay * ay), math.sqrt(bx * bx + by * by))
        print("hs561 minimap " .. p.map .. ": gap " .. gap .. " px, max offset " .. off .. " px")
        -- The nudge alone leaves the pair (18 - real gap) * 12 / 18 apart, about 11 px.
        assert(gap >= MINIMAP_PIN * 0.9, "minimap " .. p.map .. ": the pair must stop covering at the minimap pin size, got " .. gap)
        assert(off <= MINIMAP_PIN * 0.6, "minimap " .. p.map .. ": each pin moves about half a pin, got " .. off)
        assert(realGap < 2, "sanity: the pair really is about 1 px apart")
        -- Without a pin size the pixel nudge is applied as given (world-map units).
        local ux = MPP.NudgeMinimapPosition(0, 0, a.nudgeX, a.nudgeY, 1000, 1000, 0, 1, false, true)
        assert(math.abs(ux * 1000 - a.nudgeX) < 1e-6, "no pinSize: nudge unscaled")
    end
    -- Pin size 24 (slider max) scales up with the pin so it still clears.
    local x1 = MPP.NudgeMinimapPosition(0, 0, 9, 0, 1000, 1000, 0, 1, false, true, 24)
    assert(math.abs(x1 * 1000 - 12) < 1e-6, "nudge scales with the minimap pin size")
end
print("hs536_pin_overlap_nudge: ok")
