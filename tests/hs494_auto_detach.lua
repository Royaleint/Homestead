-- luacheck: globals assert io print loadstring ipairs pairs select table unpack setfenv pcall math type string tostring setmetatable

-- HS-494: the side panel floats in the strip beside the maximized world map.
-- UI/MapSidePanel.lua cannot be loaded whole, so this uses the extract-and-
-- loadstring harness from hs291_mapsidepanel_list.lua: pure arithmetic and the
-- State functions run against mock frames, and the wiring is pinned as source text.

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

local function read(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local source = read(root .. "/UI/MapSidePanel.lua")

local function extract(pattern, label)
    local text = source:match(pattern)
    assert(text, "could not extract " .. label)
    return text
end

local function count(text, needle)
    local n, pos = 0, 1
    while true do
        local s, e = text:find(needle, pos, true)
        if not s then return n end
        n = n + 1
        pos = e + 1
    end
end

local function near(a, b, tol)
    return a ~= nil and b ~= nil and math.abs(a - b) <= tol
end

-- Runs a chunk with only the names it is given: any other global it touches is nil.
local function load_sandboxed(text, label, ...)
    local fn = assert(loadstring(text, label))
    setfenv(fn, { math = math, ipairs = ipairs })
    return fn(...)
end

local layoutLines = {}
for _, name in ipairs({ "PANEL_WIDTH", "AUTO_DETACH_MIN_WIDTH", "PADDING", "ITEM_ICON_SIZE",
                        "ITEM_ICON_PAD", "ITEM_GRID_INSET" }) do
    assert(count(source, "\nLayout." .. name .. " = ") == 1,
        "expected exactly one module-scope declaration of " .. name)
    layoutLines[#layoutLines + 1] = extract("\n(Layout%." .. name .. " = [^\n]*)", name .. " declaration")
end
layoutLines[#layoutLines + 1] = extract("\n(local function IconsPerRowForWidth%(panelWidth%).-\nend)", "IconsPerRowForWidth")
layoutLines[#layoutLines + 1] = extract("\n(Layout%.ICONS_PER_ROW = IconsPerRowForWidth%(Layout%.PANEL_WIDTH%))",
    "the ICONS_PER_ROW declaration")
local LAYOUT_CHUNK = "local Layout = {}\n" .. table.concat(layoutLines, "\n") .. "\n"

local function fn(name) return extract("\n(local function " .. name .. "%(.-\nend)", name) end
local function stateFn(name) return extract("\n(State%." .. name .. " = function%(.-\nend)", name) end

local computeBody = fn("ComputeAutoDetachPlacement")
local setWidthBody = fn("SetPanelWidth")
local showGripBody = fn("ShowResizeHandle")
local selectorBody = fn("GetFloorSelectorBottom")
local placeBody = stateFn("PlaceAutoDetached")
local enterBody = stateFn("EnterAutoDetached")
local exitBody = stateFn("ExitAutoDetached")
local dragBody = stateFn("DetachAfterDrag")

-------------------------------------------------------------------------------
-- (a) Placement arithmetic (pure)
-------------------------------------------------------------------------------

local Compute, IconsPerRowForWidth, ArithLayout = load_sandboxed(
    LAYOUT_CHUNK .. computeBody .. "\nreturn ComputeAutoDetachPlacement, IconsPerRowForWidth, Layout",
    "compute-extract")
assert(ArithLayout.ICONS_PER_ROW == 6, "the panel's own width gives six tiles per row")

-- Blizzard's maximized map: width = floor(min(W - 30, (H - 67) x 702 / 467)),
-- centred, top at the screen top. Screen is W x H UI units.
local function geometry(W, H)
    local width = math.floor(math.min(W - 30, (H - 67) * 702 / 467))
    return { 0, H, (W - width) / 2, H, 0, nil, (W - width) / 2 }
end

local ROWS = {
    { "Rawb 2048x1152", geometry(2048, 1152), "beside", 209 },
    { "16:9 slider 0.65", geometry(768 / 0.65 * 16 / 9, 768 / 0.65), "beside", 212 },
    { "16:9 slider 1.0", geometry(768 * 16 / 9, 768), "beside", 156 },
    { "16:9 slider 1.15", geometry(768 / 1.15 * 16 / 9, 768 / 1.15), "beside", 142 },
    { "16:9 2560x1440 off", geometry(2560, 1440), "beside", 248 },
    { "16:9 3840x2160 off", geometry(3840, 2160), "beside", 260 },
    { "16:10 slider 1.0", geometry(768 * 1.6, 768), "overlap", 133 },
    { "16:10 slider 1.15", geometry(768 / 1.15 * 1.6, 768 / 1.15), "overlap", 133 },
    { "16:10 1920x1200 off", geometry(1920, 1200), "overlap", 133 },
    { "4:3 1024x768", geometry(1024, 768), "overlap", 133 },
    { "strip exactly 260", { 0, 800, 260, 800, 0, nil, 260 }, "beside", 260, true },
    { "strip exactly 133", { 0, 800, 133, 800, 0, nil, 133 }, "beside", 133, true },
    { "strip 132.9", { 0, 800, 132.9, 800, 0, nil, 132.9 }, "overlap", 133, true },
    { "map edge unreadable", { 0, 1152, nil, nil, nil, nil, 0 }, "overlap", 133, true },
    { "strip zero", { 0, 800, 0, 800, 0, nil, 0 }, "overlap", 133, true },
    { "strip negative", { 0, 800, -5, 800, 0, nil, -5 }, "overlap", 133, true },
}

for _, row in ipairs(ROWS) do
    local label, args, wantMode, wantWidth, exact = row[1], row[2], row[3], row[4], row[5]
    local mode, width = Compute(unpack(args, 1, 6))
    assert(mode == wantMode, label .. ": mode " .. tostring(mode) .. ", want " .. wantMode)
    assert(near(width, wantWidth, exact and 1e-9 or 1),
        label .. ": width " .. tostring(width) .. ", want " .. wantWidth)
    assert(width >= 133 and width <= 260, label .. ": width outside 133 to 260")
    if mode == "beside" then
        assert(width <= args[7], label .. ": beside panel wider than its strip")
    end
end

do
    local _, _, height, topOffset, maxHeight = Compute(0, 1152, 209, 1152, 0, nil)
    assert(height == 1152 and topOffset == 0 and maxHeight == 1152, "beside height, topOffset and maxHeight")
    local mode, width, h2, t2, m2 = Compute(0, 768, 100, 768, 0, 701)
    assert(mode == "overlap" and width == 133 and h2 == 701 and t2 == 67 and m2 == 768,
        "overlap: top at the given edge, offset from the screen top")
    local _, _, h3 = Compute(0, 768, 100, 768, 0, nil)
    assert(h3 == 768, "overlap with no given top starts at the map top")
end

for _, case in ipairs({ { 260, 6 }, { 226, 5 }, { 209, 4 }, { 195, 4 }, { 164, 3 },
                        { 163, 2 }, { 142, 2 }, { 133, 2 }, { 132, 1 } }) do
    assert(IconsPerRowForWidth(case[1]) == case[2],
        "tiles per row at width " .. case[1] .. " should be " .. case[2] .. ", got "
            .. tostring(IconsPerRowForWidth(case[1])))
end

print("hs494_auto_detach: placement arithmetic ok")

-------------------------------------------------------------------------------
-- (b) Mock frames
-------------------------------------------------------------------------------

local function NewFrame(maxHeight, orderLog)
    local f = { log = {}, anchors = {}, shown = true, height = 0, width = 0, scripts = {},
                minW = nil, maxW = nil, maxHeight = maxHeight, left = nil, top = nil }
    local function rec(name) f.log[#f.log + 1] = name end
    function f.calls(name)
        local n = 0
        for _, v in ipairs(f.log) do if v == name then n = n + 1 end end
        return n
    end
    f.StartMoving = function() rec("StartMoving") end
    f.StopMovingOrSizing = function()
        rec("StopMovingOrSizing")
        if orderLog then orderLog[#orderLog + 1] = "stop" end
    end
    function f:SetScale() rec("SetScale") end
    function f:SetResizeBounds(minW, _, maxW, maxH)
        rec("SetResizeBounds")
        self.minW, self.maxW, self.maxHeight = minW, maxW, maxH
    end
    function f:ClearAllPoints() rec("ClearAllPoints") self.anchors = {} end
    function f:SetWidth(w)
        rec("SetWidth")
        if self.minW and w < self.minW then w = self.minW end
        if self.maxW and w > self.maxW then w = self.maxW end
        self.width = w
    end
    function f:SetHeight(h)
        rec("SetHeight")
        if self.maxHeight and self.maxHeight > 0 and h > self.maxHeight then h = self.maxHeight end
        self.height = h
    end
    function f:GetHeight() return self.height end
    function f:GetLeft() return self.left end
    function f:GetTop() return self.top end
    function f:SetPoint(p, rel, rp, x, y) rec("SetPoint") self.anchors[#self.anchors + 1] = { p, rel, rp, x, y } end
    function f:GetPoint(i)
        local a = self.anchors[i]
        if not a then return nil end
        return a[1], a[2], a[3], a[4], a[5]
    end
    function f:GetFrameLevel() return 500 end
    function f:SetFrameLevel() rec("SetFrameLevel") end
    function f:SetMovable() rec("SetMovable") end
    function f:SetResizable() rec("SetResizable") end
    function f:RegisterForDrag() rec("RegisterForDrag") end
    function f:SetScript(name, handler) rec("SetScript") self.scripts[name] = handler end
    function f:Show() rec("Show") self.shown = true end
    function f:Hide() rec("Hide") self.shown = false end
    function f:IsShown() return self.shown end
    return f
end

-- A table that logs every key written to it and stays empty, so each write fires.
local function NewRecorder()
    local backing, writes = {}, {}
    local t = setmetatable({}, {
        __index = backing,
        __newindex = function(_, k, v) writes[#writes + 1] = k backing[k] = v end,
    })
    return t, writes
end

local saveBody = stateFn("SaveDetachedPosition")

-------------------------------------------------------------------------------
-- (c) Save chokepoint: only a player-detached panel writes the saved keys
-------------------------------------------------------------------------------

do
    local vendorTracer, writes = NewRecorder()
    local HA = { Addon = { db = { profile = { vendorTracer = vendorTracer } } } }
    local State = { panelFrame = NewFrame(), isPoppedOut = false }
    State.panelFrame.anchors = { { "TOPLEFT", nil, nil, 5, 6 } }
    State.panelFrame.height = 400
    load_sandboxed("local HA, State = ...\n" .. saveBody, "save-extract", HA, State)

    State.SaveDetachedPosition()
    assert(#writes == 0, "SaveDetachedPosition must write nothing unless the panel is player-detached")

    State.isPoppedOut = true
    State.SaveDetachedPosition()
    assert(#writes == 2 and vendorTracer.sidePanelHeight == 400
        and vendorTracer.sidePanelPosition and vendorTracer.sidePanelPosition.x == 5,
        "SaveDetachedPosition must write position and height when player-detached")
end

print("hs494_auto_detach: save chokepoint ok")

-------------------------------------------------------------------------------
-- (d) Enter / Place / Exit / drag against mock frames
-------------------------------------------------------------------------------

local function NewEnv()
    local env = { order = {}, popOutCalls = 0 }
    env.geo = { ui = 2/3, H = 1152, mapScale = 2/3,
                mapLeft = 209, mapTop = 1152, mapBottom = 0, containerTop = 1100 }
    local geo = env.geo
    env.UIParent = {
        GetEffectiveScale = function() return geo.ui end,
        GetLeft = function() return 0 end,
        GetTop = function() return geo.H end,
        GetHeight = function() return geo.H end,
    }
    local container = {
        GetTop = function() return geo.containerTop end,
        GetEffectiveScale = function() return geo.mapScale end,
    }
    env.WorldMapFrame = {
        ScrollContainer = {},
        overlayFrames = {},
        GetEffectiveScale = function() return geo.mapScale end,
        GetLeft = function() return geo.mapLeft end,
        GetTop = function() return geo.mapTop end,
        GetBottom = function() return geo.mapBottom end,
        GetCanvasContainer = function() return container end,
    }
    -- A panel as PopOut leaves it: canvas anchors, 260 wide, resize bounds 260 wide
    -- and 0.9 screen height tall
    env.panel = NewFrame(0.9 * 1152, env.order)
    env.panel.minW, env.panel.maxW = 260, 260
    env.panel.width = 260
    env.panel.anchors = {
        { "TOPRIGHT", env.WorldMapFrame.ScrollContainer, "TOPLEFT", 0, 0 },
        { "BOTTOMRIGHT", env.WorldMapFrame.ScrollContainer, "BOTTOMLEFT", 0, 0 },
    }
    env.panel.height = 600
    env.grip = NewFrame()
    env.headerWidth = nil
    env.headerText = { SetWidth = function(_, w) env.headerWidth = w end }
    env.State = { panelFrame = env.panel, isPoppedOut = false, isAutoDetached = false,
                  autoPlacement = {}, panelShowGeneration = 0, resizeHandle = env.grip,
                  headerText = env.headerText }
    env.MapSidePanel = {
        PopOut = function()
            env.popOutCalls = env.popOutCalls + 1
            env.order[#env.order + 1] = "popout"
            env.State.isPoppedOut = true
            env.State.isAutoDetached = false
        end,
    }
    local noop = function() end
    local chunk = LAYOUT_CHUNK
        .. "local State, UIParent, WorldMapFrame, RestoreFrameLevels, EnsureCompleteBorder,"
        .. " UpdatePopOutButtons, MapSidePanel = ...\n"
        .. computeBody .. "\n" .. setWidthBody .. "\n" .. showGripBody .. "\n" .. selectorBody .. "\n"
        .. placeBody .. "\n" .. enterBody .. "\n" .. exitBody .. "\n" .. dragBody .. "\nreturn Layout"
    env.Layout = load_sandboxed(chunk, "state-fns-extract", env.State, env.UIParent, env.WorldMapFrame,
        noop, noop, noop, env.MapSidePanel)
    return env
end

local function addSelector(env, bottom, shown)
    env.WorldMapFrame.overlayFrames[1] = {
        RefreshMenu = function() end,
        IsShown = function() return shown end,
        GetBottom = function() return bottom end,
        GetEffectiveScale = function() return env.geo.mapScale end,
    }
end

do
    local env = NewEnv()
    local State, panel, geo = env.State, env.panel, env.geo
    local vendorTracer, writes = NewRecorder()
    local HA = { Addon = { db = { profile = { vendorTracer = vendorTracer } } } }
    load_sandboxed("local HA, State = ...\n" .. saveBody, "save-extract", HA, State)

    State.EnterAutoDetached()
    assert(State.isAutoDetached == true, "Enter should set the flag")
    -- Fails if the resize bounds are set after the size (the stale 260 bounds clamp the width)
    assert(panel.width == 209, "Rawb's screen: width 209, got " .. tostring(panel.width))
    assert(panel.height == 1152, "Rawb's screen: height 1152, got " .. tostring(panel.height))
    assert(panel.calls("SetScale") == 0, "the panel is never scaled")
    assert(env.Layout.ICONS_PER_ROW == 4, "209 wide gives four tiles per row, got " .. tostring(env.Layout.ICONS_PER_ROW))
    assert(env.headerWidth == 209 - 56, "the header text follows the width")
    assert(#panel.anchors == 1 and panel.anchors[1][1] == "TOPRIGHT"
        and panel.anchors[1][2] == env.WorldMapFrame and panel.anchors[1][3] == "TOPLEFT",
        "beside mode: exactly one anchor, TOPRIGHT to the map's TOPLEFT")
    assert(#writes == 0, "Enter must write no saved key")
    assert(env.grip.calls("SetFrameLevel") == 1 and env.grip.shown, "the grip is raised and shown")

    -- Resizing by the grip ends with the save call: nothing is written while auto-detached
    State.SaveDetachedPosition()
    assert(#writes == 0, "resizing while auto-detached must write no saved key")

    local before = #panel.log
    assert(State.PlaceAutoDetached() == false, "Place with unchanged geometry returns false")
    assert(#panel.log == before, "Place with unchanged geometry must make no frame call")

    -- What a drag leaves behind, then the map moves
    panel.anchors = { { "TOPLEFT", env.UIParent, "TOPLEFT", 100, -100 } }
    local stops = panel.calls("StopMovingOrSizing")
    geo.mapLeft = 150
    assert(State.PlaceAutoDetached() == true, "a width change makes Place return true")
    assert(panel.calls("StopMovingOrSizing") == stops + 1, "re-place must stop a drag in progress")
    assert(panel.width == 150 and env.Layout.ICONS_PER_ROW == 2, "re-place follows the new strip")
    assert(#panel.anchors == 1 and panel.anchors[1][1] == "TOPRIGHT",
        "re-place: exactly one anchor, the beside anchor")

    -- A strip under 133: overlap on the screen's left edge
    geo.mapLeft = 100
    State.PlaceAutoDetached()
    assert(panel.width == 133 and #panel.anchors == 1 and panel.anchors[1][1] == "TOPLEFT"
        and panel.anchors[1][2] == env.UIParent, "narrow strip: overlap anchor on the screen edge")

    -- Unreadable map edges
    geo.mapLeft, geo.mapTop, geo.mapBottom = nil, nil, nil
    local ok, err = pcall(State.PlaceAutoDetached, true)
    assert(ok, "nil map geometry must not error: " .. tostring(err))
    assert(panel.anchors[1][1] == "TOPLEFT", "nil map geometry falls to the overlap placement")

    State.ExitAutoDetached()
    assert(State.isAutoDetached == false, "Exit clears the flag")
    -- Fails if the narrow resize bounds are left in place (they clamp the width back to 133)
    assert(panel.width == 260, "Exit restores the 260 width, got " .. tostring(panel.width))
    assert(env.Layout.ICONS_PER_ROW == 6, "Exit restores six tiles per row")
    assert(env.headerWidth == 260 - 56, "Exit restores the header text width")
    assert(#panel.anchors == 2 and panel.anchors[1][2] == env.WorldMapFrame.ScrollContainer
        and panel.anchors[1][3] == "TOPLEFT" and panel.anchors[2][3] == "BOTTOMLEFT",
        "Exit restores the two canvas anchors")
    assert(panel.scripts.OnDragStop == nil and panel.scripts.OnDragStart == nil, "Exit clears the drag scripts")
    assert(panel.calls("SetScale") == 0, "the panel is never scaled")
end

do
    -- Drag: stop, then the player's own detach, then the drop spot is saved through the normal path
    local env = NewEnv()
    local State, panel = env.State, env.panel
    local vendorTracer, writes = NewRecorder()
    local HA = { Addon = { db = { profile = { vendorTracer = vendorTracer } } } }
    load_sandboxed("local HA, State = ...\n" .. saveBody, "save-extract", HA, State)

    State.EnterAutoDetached()
    panel.left, panel.top = 350, 900
    env.order[#env.order + 1] = "reset"
    assert(panel.scripts.OnDragStop, "Enter installs a drag-stop handler")
    panel.scripts.OnDragStop(panel)
    local first, second
    for i, v in ipairs(env.order) do
        if v == "reset" then first, second = env.order[i + 1], env.order[i + 2] end
    end
    assert(first == "stop" and second == "popout", "the drag handler stops moving, then detaches")
    assert(env.popOutCalls == 1 and State.isPoppedOut, "the drag becomes the player's own detach")
    assert(#panel.anchors == 1 and panel.anchors[1][1] == "TOPLEFT" and panel.anchors[1][2] == env.UIParent
        and panel.anchors[1][3] == "TOPLEFT" and panel.anchors[1][4] == 350 and panel.anchors[1][5] == 900 - 1152,
        "the panel is re-anchored at the drop spot")
    assert(vendorTracer.sidePanelPosition and vendorTracer.sidePanelPosition.x == 350
        and vendorTracer.sidePanelPosition.y == 900 - 1152 and #writes == 2,
        "the drop spot and height are saved")

    -- A drag stop with no auto-detached state does nothing beyond stopping the move
    local env2 = NewEnv()
    env2.State.EnterAutoDetached()
    env2.State.isAutoDetached = false
    env2.panel.scripts.OnDragStop(env2.panel)
    assert(env2.popOutCalls == 0, "no detach when the panel is not auto-detached")
end

do
    -- Overlap top: below the floor selector when it is shown, else the canvas top
    local function topOffsetFor(prepare)
        local env = NewEnv()
        env.geo.mapLeft = 100
        prepare(env)
        env.State.EnterAutoDetached()
        local a = env.panel.anchors[1]
        assert(a[1] == "TOPLEFT" and a[2] == env.UIParent, "overlap anchor expected")
        return a[5]
    end
    assert(topOffsetFor(function(env) addSelector(env, 1130, true) end) == -22,
        "selector shown: the top starts below its bottom edge")
    assert(topOffsetFor(function(env) addSelector(env, 1130, false) end) == -52,
        "selector hidden: the top starts at the canvas top")
    assert(topOffsetFor(function() end) == -52, "no selector: the top starts at the canvas top")
    assert(topOffsetFor(function(env) addSelector(env, nil, true) end) == -52,
        "unreadable selector: the top starts at the canvas top")
end

do
    -- Enter refuses while a map piece still rides on the panel
    local env = NewEnv()
    env.State.savedNavBarState = {}
    env.panel.shown = false
    env.State.EnterAutoDetached()
    assert(env.panel:IsShown() == false and env.panel.calls("Hide") == 0 and env.panel.calls("Show") == 0
        and env.State.isAutoDetached == false and env.panel.calls("SetWidth") == 0 and env.panel.width == 260,
        "Enter with a restore owed and the panel hidden must do nothing")

    env = NewEnv()
    env.State.savedNavBarState = {}
    env.State.EnterAutoDetached()
    assert(env.panel.calls("Hide") == 1 and env.State.isAutoDetached == false
        and env.panel.calls("SetWidth") == 0 and env.panel.width == 260,
        "Enter with a restore owed and the panel shown must hide it once")

    env = NewEnv()
    env.State.isPoppedOut = true
    env.State.EnterAutoDetached()
    assert(#env.panel.log == 0 and env.State.isAutoDetached == false,
        "Enter on a player-detached panel must do nothing")
end

print("hs494_auto_detach: enter, place, exit and drag ok")

-------------------------------------------------------------------------------
-- (e) Nav bar restore keeps Blizzard's anchors
-------------------------------------------------------------------------------

do
    local chunk = "local State, WorldMapFrame, RestoreClipping = ...\n"
        .. extract("\n(local function SaveFrameState%(.-\nend)", "SaveFrameState") .. "\n"
        .. extract("\n(local function RestoreFrameState%(.-\nend)", "RestoreFrameState") .. "\n"
        .. extract("\n(local function RestoreMapElements%(.-\nend)", "RestoreMapElements") .. "\n"
        .. "return RestoreMapElements"

    local function run(liveAnchors)
        local panel, spacer, origParent = {}, {}, {}
        local nav = { parent = panel, level = 515, strata = "HIGH", anchors = {} }
        for i, a in ipairs(liveAnchors(panel, spacer)) do nav.anchors[i] = a end
        function nav:GetParent() return self.parent end
        function nav:GetFrameLevel() return self.level end
        function nav:GetFrameStrata() return self.strata end
        function nav:GetNumPoints() return #self.anchors end
        function nav:GetPoint(i) local a = self.anchors[i] return a[1], a[2], a[3], a[4], a[5] end
        function nav:SetParent(p) self.parent = p end
        function nav:SetFrameStrata(s) self.strata = s end
        function nav:SetFrameLevel(l) self.level = l end
        function nav:ClearAllPoints() self.anchors = {} end
        function nav:SetPoint(p, r, rp, x, y) self.anchors[#self.anchors + 1] = { p, r, rp, x, y } end
        local State = { panelFrame = panel, savedClipStates = {},
            savedNavBarState = { parent = origParent, level = 3, strata = "MEDIUM",
                anchors = { { "TOPLEFT", spacer, "BOTTOMLEFT", 64, -25 },
                            { "BOTTOMRIGHT", spacer, "BOTTOMRIGHT", -4, 9 } } } }
        local WorldMapFrame = { NavBar = nav, BorderFrame = {} }
        local restore = load_sandboxed(chunk, "navbar-extract", State, WorldMapFrame, function() end)
        restore()
        return nav, State, origParent
    end

    -- A: still anchored to the panel since docking: the saved small-map pair comes back
    local nav, State = run(function(panel, spacer)
        return { { "TOPLEFT", panel, "TOPLEFT", 64, -25 }, { "BOTTOMRIGHT", spacer, "BOTTOMRIGHT", -4, 9 } }
    end)
    assert(nav.anchors[1][4] == 64 and nav.anchors[1][5] == -25 and nav.anchors[2][4] == -4,
        "case A: saved pair expected")
    assert(State.savedNavBarState == nil, "case A: saved state cleared")

    -- B: Blizzard re-anchored it on maximize: its points are kept, parent and level restored
    local navB, StateB, origParent = run(function(_, spacer)
        return { { "TOPLEFT", spacer, "BOTTOMLEFT", 8, -25 }, { "BOTTOMRIGHT", spacer, "BOTTOMRIGHT", -4, 9 } }
    end)
    assert(#navB.anchors == 2 and navB.anchors[1][4] == 8 and navB.anchors[1][5] == -25
        and navB.anchors[2][4] == -4 and navB.anchors[2][5] == 9,
        "case B: Blizzard's (8, -25) and (-4, 9) expected")
    assert(navB.parent == origParent and navB.level == 3 and navB.strata == "MEDIUM",
        "case B: original parent, level and strata expected")
    assert(StateB.savedNavBarState == nil, "case B: saved state cleared")

    -- C: no live points: the saved pair
    local navC = run(function() return {} end)
    assert(#navC.anchors == 2 and navC.anchors[1][4] == 64, "case C: saved pair expected")
end

print("hs494_auto_detach: nav bar restore ok")

-------------------------------------------------------------------------------
-- (f) Wiring and order
-------------------------------------------------------------------------------

local function posOf(text, needle, init)
    return (text:find(needle, init or 1, true))
end

do
    local popBody = extract("\n(function MapSidePanel:PopOut%(%).-\nend)", "PopOut")
    local exitPos = posOf(popBody, "State.ExitAutoDetached()")
    local heightPos = posOf(popBody, "State.panelFrame:GetHeight()")
    assert(exitPos and heightPos and exitPos < heightPos, "PopOut must exit the auto-detached state before it reads the height")
    local boundsPos = posOf(popBody, "State.panelFrame:SetResizeBounds(")
    local widthPos = posOf(popBody, "State.panelFrame:SetWidth(")
    assert(boundsPos and widthPos and boundsPos < widthPos, "PopOut must set the resize bounds before the width")
    assert(count(popBody, "ShowResizeHandle()") == 1, "PopOut shows the grip through ShowResizeHandle")

    local showBody = extract("\n(local function ShowPanel%(%).-\nend)", "ShowPanel")
    assert(showBody:find("State.EnterAutoDetached()", 1, true), "ShowPanel must enter the auto-detached state on a maximized map")
    local docked = posOf(showBody, "    State.ExitAutoDetached()\n    State.panelFrame:Show()\n")
    local defer = posOf(showBody, "-- Defer all docked map mutations until combat ends")
    assert(docked and defer and docked < defer, "ShowPanel docked path must exit before it shows, ahead of the combat deferral")

    local hideBody = extract("\n(local function HidePanel%(%).-\nend)", "HidePanel")
    local lastHide, p = nil, 1
    while true do
        local s, e = hideBody:find("State.panelFrame:Hide()", p, true)
        if not s then break end
        lastHide, p = s, e + 1
    end
    local exitAt = posOf(hideBody, "State.ExitAutoDetached()")
    local restoreAt = posOf(hideBody, "-- Defer map restoration until combat ends")
    assert(lastHide and exitAt and restoreAt and lastHide < exitAt and exitAt < restoreAt,
        "HidePanel must exit after its last hide and before the map restoration deferral")

    -- Resize bounds are reset before the width everywhere the width goes back to 260
    local exitBounds = posOf(exitBody, "panel:SetResizeBounds(Layout.PANEL_WIDTH")
    local exitWidth = posOf(exitBody, "SetPanelWidth(Layout.PANEL_WIDTH)")
    assert(exitBounds and exitWidth and exitBounds < exitWidth, "Exit must reset the resize bounds before the width")
    local placeBounds = posOf(placeBody, "panel:SetResizeBounds(")
    local placeWidth = posOf(placeBody, "SetPanelWidth(width)")
    local placeHeight = posOf(placeBody, "panel:SetHeight(")
    assert(placeBounds and placeWidth and placeHeight and placeBounds < placeWidth and placeWidth < placeHeight,
        "Place must set the bounds, then the width, then the height")

    -- A drag converts in this order: stop, detach, anchor at the drop spot, save
    local stopAt = posOf(dragBody, "panel:StopMovingOrSizing()")
    local popAt = posOf(dragBody, "MapSidePanel:PopOut()")
    local anchorAt = posOf(dragBody, "panel:SetPoint(")
    local saveAt = posOf(dragBody, "State.SaveDetachedPosition()")
    assert(stopAt and popAt and anchorAt and saveAt and stopAt < popAt and popAt < anchorAt and anchorAt < saveAt,
        "DetachAfterDrag must stop, detach, anchor, then save")
    local readAt = posOf(dragBody, "panel:GetLeft()")
    assert(readAt and readAt < popAt, "DetachAfterDrag must read the drop spot before PopOut moves the panel")
end

assert(count(source, 'panel:SetScript("OnDragStop", State.DetachAfterDrag)') == 1,
    "Enter must install the drag conversion as the drag-stop handler")

local CLOSE_BRANCH = "if State.panelFrame then State.panelFrame:Hide() end\n"
    .. "                State.ExitAutoDetached()\n"
assert(source:find(CLOSE_BRANCH, 1, true), "the map-close branch must exit right after the panel hide")

local G6_EXTENDED = [[
                    if InCombatLockdown() then
                        State.mapShifted = false
                        State.savedMapPoint = nil
                        State.pendingDockedAction = "clear"
                        State.panelFrame:Hide()]]
assert(source:find(G6_EXTENDED, 1, true), "the combat maximize arm must set the deferral, then hide the panel")

local MAXIMIZE_ELSE = [[
                        RemoveDockedIntegration(false)
                        ShowPanel()
                        MapSidePanel:RefreshContent()]]
assert(source:find(MAXIMIZE_ELSE, 1, true), "the out-of-combat maximize arm must restore, show, then refresh")

local REGEN_TAIL = [[
    -- A panel that a maximize hid in combat comes back beside the maximized map
    if not State.isPoppedOut and State.panelFrame and not State.panelFrame:IsShown()
            and WorldMapFrame:IsShown() and WorldMapFrame.isMaximized
            and HA.Addon and HA.Addon.db
            and HA.Addon.db.profile.vendorTracer.showMapSidePanel then
        MapSidePanel:Show()
    end]]
assert(source:find(REGEN_TAIL, 1, true), "the combat-end handler must show a panel that a maximize hid")

assert(count(source, "if State.isAutoDetached and State.PlaceAutoDetached() then MapSidePanel:RefreshContent() end") == 1,
    "the map watch must re-place the auto-detached panel once, and rebuild the list when the width changed")
assert(count(source, "RemoveDockedIntegration(not WorldMapFrame.isMaximized)") == 1,
    "the pending remove must skip the position restore on a maximized map")
assert(count(source, "RemoveDockedIntegration(true)") == 2, "RemoveDockedIntegration(true) must remain at exactly two sites")
assert(count(source, "ShowResizeHandle()") == 3, "ShowResizeHandle: the definition, Enter and PopOut")

-- Map-open and minimize conditions, and the X button's visibility
local openBranch = extract("(Map just opened.-Map just closed)", "the map-open branch")
assert(not openBranch:find("not maximized", 1, true),
    "the map-open condition must no longer exclude a maximized map")
assert(source:find("keeps its own one-frame border/inset defer.\n"
    .. "            if not State.isPoppedOut\n"
    .. "                    and HA.Addon and HA.Addon.db\n", 1, true),
    "the map-open condition must read: not popped out, then the setting")
assert(count(source, "and (State.isAutoDetached") == 1,
    "the minimize condition must also accept an auto-detached panel")
assert(count(source, "State.closeButton:SetShown(State.isAutoDetached)") == 1,
    "the X button must show while auto-detached")

-- Narrow-panel text: these strings must not wrap or must follow the panel's width
assert(count(source, "countText:SetWordWrap(false)") == 2, "the two row count lines must not wrap")
assert(count(source, "summaryLine:SetWordWrap(false)") == 1, "the summary row's second line must not wrap")
assert(count(source, "backText:SetWordWrap(false)") == 1, "the back bar text must not wrap")
assert(count(source, "State.summaryText:SetWordWrap(false)") == 1, "the bottom summary line must not wrap")
do
    local emptyAt = posOf(source, 'State.emptyText = panel:CreateFontString(')
    local empty = source:sub(emptyAt, emptyAt + 600)
    assert(empty:find('State.emptyText:SetPoint("LEFT"', 1, true) and empty:find('State.emptyText:SetPoint("RIGHT"', 1, true),
        "the empty-state text must be anchored on both sides so it wraps inside the panel")
end

print("hs494_auto_detach: wiring and order ok")

-------------------------------------------------------------------------------
-- (g) String gates
-------------------------------------------------------------------------------

assert(count(source, ":SetScale(") == 1, ":SetScale( must occur once, in the housing preview")
assert(not source:find("AUTO_DETACH_FLOOR", 1, true), "the scale floor must be gone")
assert(count(source, "State.isAutoDetached = true") == 1, "the flag is set in exactly one place")
assert(count(source, "State.isAutoDetached = false") == 2, "the flag is declared and cleared in exactly two places")
assert(count(source, "sidePanelPosition = ") == 1, "sidePanelPosition has one write site")
assert(count(source, "sidePanelHeight = ") == 2, "sidePanelHeight has two write sites")
assert(count(source, "sidePanelPoppedOut = ") == 4, "sidePanelPoppedOut has four write sites")
assert(count(source, "SetPanelWidth(") == 3, "SetPanelWidth: the definition, Place and Exit")

for label, body in pairs({ Place = placeBody, Enter = enterBody, Exit = exitBody }) do
    for _, banned in ipairs({ "sidePanel", "showMapSidePanel", "WorldMapFrame:Set", "WorldMapFrame:Clear",
                              "SetParent", "HookScript", "hooksecurefunc", "InCombatLockdown", "SetScale" }) do
        assert(not body:find(banned, 1, true), label .. "AutoDetached must not contain " .. banned)
    end
end
assert(not dragBody:find("sidePanel", 1, true), "DetachAfterDrag must not write a saved key itself")

assert(count(source, ":CloseDetached()") == 4, ":CloseDetached() must match four times: three calls and the definition")
assert(count(source, "function MapSidePanel:CloseDetached()") == 1, "CloseDetached must be defined once")

local closeHandler = extract("State%.closeButton:SetScript%(\"OnClick\", function%(%)(.-)\n    end%)", "close button handler")
local collapsed = (closeHandler:gsub("%-%-[^\n]*", ""):gsub("%s+", " "))
assert(collapsed == " if State.isPoppedOut then MapSidePanel:CloseDetached() else MapSidePanel:Toggle() end",
    "the X button must close a detached panel and toggle an auto-detached one, got: " .. collapsed)

assert(extract("local function ReapplyMapShift%(%)\n%s*([^\n]*)", "ReapplyMapShift") == "if State.isAutoDetached then return end",
    "ReapplyMapShift must return first while auto-detached")

print("hs494_auto_detach: string gates ok")
print("hs494_auto_detach: ok")
