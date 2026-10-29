-- luacheck: globals assert loadfile print
-- Run from the repo root:  lua tests/hs538_persistence.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")
local newWorld = assert(loadfile(root .. "/tests/hs538_world.lua"))()

-------------------------------------------------------------------------------
-- What the vendor card and its list keep: Alt+Z twice restores both, every refresh reason keeps the selection
-- and the scrolls, a change between two columns and cover keeps them and never slides, the card in combat, a
-- vendor that vanishes, and a close followed by an open landing on the Overview.
-------------------------------------------------------------------------------

local function eq(a, b, msg)
    if a ~= b then error((msg or "mismatch") .. ": got " .. tostring(a) .. ", wanted " .. tostring(b), 2) end
end

-- Anna and Bran sell for Midnight, Cora for Classic.
local function world()
    local env = newWorld(root, { realWindow = true })
    local v = env.standard()
    v.anna.expansion, v.bran.expansion, v.cora.expansion = "Midnight", "Midnight", "Classic"
    env.open()
    env.B.Data.InvalidateMemos()
    return env
end

local function page(env)
    for p, kind in pairs(env.pageKinds) do
        if kind == "sources" then return p end
    end
end

local function rowOf(env, key)
    for _, d in ipairs(env.boxes("sources")[1].provider) do
        if d.key == key then return d end
    end
end

-- The card's well, its scroll frame and its ware grid's box.
local function card(env)
    for _, f in ipairs(env.all) do
        if f.template == "ScrollFrameTemplate" and env.ownerKind(f) == "vendor" then
            return f.parent, f, (select(2, env.wareList()))
        end
    end
end

local function slides(env)
    local g = (card(env)).browserSlide
    return g and g.plays or 0
end

-- The card showing, Anna's row lit, the list's scroll and rows, and the card's two scrolls.
local function state(env)
    local well, sf, grid = card(env)
    return table.concat({ tostring(well.parent.shown), tostring(rowOf(env, 100).selected),
        env.boxes("sources")[1]:GetDerivedScrollOffset(), sf:GetVerticalScroll(), grid:GetDerivedScrollOffset(),
        env.sourceKeys() }, "|")
end

local function typed(env, text)
    local box = env.B.Window.search
    box.text = text
    box.scripts.OnTextChanged(box, true)
end

-- A list typed into and scrolled, with Anna's card opened over it and both of the card's scrolls moved.
local function opened(env)
    env.B.GoTop({ kind = "allVendors" })
    typed(env, "an")
    rowOf(env, 100).onClick()
    local _, sf, grid = card(env)
    env.boxes("sources")[1]:ScrollToOffset(90)
    sf:SetVerticalScroll(40)
    grid:ScrollToOffset(25)
end

local function events(env)
    for _, f in ipairs(env.all) do
        if f.parent == env.B.Window.frame and f.scripts.OnEvent then return f end
    end
end

-- Alt+Z twice: the window hides and shows twice, and the list, the card and both card scrolls are as they were.
do
    local env = world()
    opened(env)
    local before, played = state(env), slides(env)
    eq(played, 1, "the player's open slid")
    for _ = 1, 2 do
        env.B.Window.frame:Hide()
        env.B.Window.frame:Show()
        env.flush()
    end
    eq(state(env), before, "Alt+Z twice restores the list and the card")
    eq(env.route.kind, "vendor", "the card is still the route")
    eq(slides(env), played, "and it did not slide again")
    print("hs538_persistence: Alt+Z ok")
end

-- Closing the window and opening it again lands on the Overview, whatever was open.
do
    local env = world()
    opened(env)
    env.B.Window.frame:Hide()
    env.B:Open()
    eq(env.route.kind, "overview", "a reopen lands on the Overview")
    print("hs538_persistence: reopen ok")
end

-- Every refresh reason keeps the card open, its row lit and the three scrolls, and none slides.
do
    local env = world()
    opened(env)
    local before = state(env)
    for _, reason in ipairs({ "data", "names", "stats", "paint", "hide", "zone", "layout", "wallet" }) do
        page(env):Refresh(reason)
        eq(state(env), before, "the " .. reason .. " refresh keeps the selection and the scrolls")
        eq(slides(env), 1, "the " .. reason .. " refresh does not slide")
    end
    -- Through the router: a data change, a zone change and a wallet change.
    env.dataChanged()
    eq(state(env), before, "a data change through the router")
    events(env).scripts.OnEvent(events(env), "ZONE_CHANGED_NEW_AREA")
    eq(state(env), before, "a zone change through the router")
    local function canGet()
        for _, d in ipairs(env.wareList()) do
            if d.state == "can" then return true end
        end
        return false
    end
    eq(canGet(), true, "the card has wares the player can get")
    env.money = 0
    events(env).scripts.OnEvent(events(env), "PLAYER_MONEY")
    env.flush()
    eq(canGet(), false, "a wallet change judges the wares again")
    eq(state(env), before, "and keeps the selection and the scrolls")
    eq(slides(env), 1, "and none of it slid")
    print("hs538_persistence: refresh reasons ok")
end

-- A change between two columns and cover keeps the selection and the scrolls, in both directions, and never slides.
do
    local env = world()
    opened(env)
    local before = state(env)
    eq(rowOf(env, 100).narrow, true, "two columns narrow the rows")
    env.size(400, 480)
    page(env):Refresh("layout")
    eq(rowOf(env, 100).narrow, nil, "cover keeps the rows as they were")
    eq(state(env), before, "cover keeps the selection and the scrolls")
    env.size(env.room(), 480)
    page(env):Refresh("layout")
    eq(rowOf(env, 100).narrow, true, "and back to two columns")
    eq(state(env), before, "two columns keep them too")
    eq(slides(env), 1, "no flip slid")
    print("hs538_persistence: layout flip ok")
end

-- In combat the card's Report link is off and its X stays on; both come back after.
do
    local env = world()
    opened(env)
    local x, report
    for _, f in ipairs(env.all) do
        if f.template == "UIPanelCloseButtonNoScripts" and env.ownerKind(f) == "vendor" then x = f end
        if f.kind == "Button" and f.text.text == "Report a problem" and env.ownerKind(f) == "vendor" then report = f end
    end
    assert(x and report, "found the card's X and Report link")
    events(env).scripts.OnEvent(events(env), "PLAYER_REGEN_DISABLED")
    eq(report:IsEnabled(), false, "Report is off in combat")
    eq(x:IsEnabled(), true, "the X stays on")
    events(env).scripts.OnEvent(events(env), "PLAYER_REGEN_ENABLED")
    eq(report:IsEnabled(), true, "Report is back")
    print("hs538_persistence: combat ok")
end

-- A vendor that vanishes closes its card onto its list, redrawing that list once. When the
-- whole expansion goes with it, the fall-back is drawn fresh and not drawn again.
do
    local env = world()
    env.B.GoTop({ kind = "allVendors" })
    typed(env, "an")
    rowOf(env, 100).onClick()
    local box = env.boxes("sources")[1]
    local builds = 0
    local set = box.SetDataProvider
    box.SetDataProvider = function(...) builds = builds + 1 return set(...) end
    env.vendors[100] = nil
    env.dataChanged()
    eq(env.route.kind, "allVendors", "the card closed onto its list")
    eq(builds, 1, "the list was drawn once")
    eq(env.B.Window.back:IsVisible(), false, "the close used up the step that opening the card added")

    env = world()
    env.B.GoTop({ kind = "overview" })
    env.B.Go({ kind = "vendor", id = 100 })
    eq(env.route.list.key, "Midnight", "the card sits over its expansion")
    box = env.boxes("sources")[1]
    builds = 0
    set = box.SetDataProvider
    box.SetDataProvider = function(...) builds = builds + 1 return set(...) end
    env.vendors[100], env.vendors[101] = nil, nil
    env.dataChanged()
    eq(env.route.kind, "allVendors", "a card whose whole expansion went falls back to All vendors")
    eq(builds, 1, "which was drawn once, not twice")
    eq(env.B.Window.back:IsVisible(), true, "the Overview it came from is still a step back")
    env.B.Back()
    eq(env.route.kind, "overview", "and Back goes there, not to the card's list")
    print("hs538_persistence: vanished vendor ok")
end
