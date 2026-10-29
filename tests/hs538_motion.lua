-- luacheck: globals assert print io loadfile
-- Run from the repo root:  lua tests/hs538_motion.lua [root]

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Browser motion: open 0.15 s, close 0.1 s, travel at most 8 px, one glow
-- helper, no loops, and the side tabs' own glow never started. The timings at
-- run time are checked in hs538_window.
-------------------------------------------------------------------------------

local function readFile(path)
    local f = assert(io.open(root .. "/" .. path, "rb"), "cannot open " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

local files = {}
for line in readFile("Homestead.toc"):gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI\\Browser\\[%w_]+%.[lx][um][al])%s*$")
    if entry then files[#files + 1] = (entry:gsub("\\", "/")) end
end
assert(#files >= 10, "the TOC lists too few UI/Browser files")

local window = readFile("UI/Browser/Window.lua")
local open, close, travel = window:match("OPEN_TIME, CLOSE_TIME, TRAVEL = ([%d%.]+), ([%d%.]+), ([%d%.]+)")
assert(tonumber(open) == 0.15 and tonumber(close) == 0.1 and tonumber(travel) <= 8,
    "the open, close or travel timing changed")
for d in window:gmatch("SetDuration%(([^)]*)%)") do
    assert(d == "0" or d == "OPEN_TIME" or d == "CLOSE_TIME", "an animation has its own duration: " .. d)
end

local groups = 0
for _, path in ipairs(files) do
    local text = readFile(path)
    assert(not text:find("TabGlowAnimation", 1, true), path .. " touches the side tab's glow")
    for arg in text:gmatch("SetLooping%s*%(%s*([^)]-)%s*%)") do
        assert(arg:gsub("[\"']", ""):upper() == "NONE", path .. " loops an animation")
    end
    for value in text:gmatch("looping%s*=%s*[\"']([^\"']*)[\"']") do
        assert(value:upper() == "NONE", path .. " loops an animation")
    end
    local _, n = text:gsub("CreateAnimationGroup", "")
    if path ~= "UI/Browser/Window.lua" then
        assert(n == 0, path .. " builds its own animation; motion lives in Window.lua")
    end
    groups = groups + n
end
assert(groups == 4, "Window.lua must build exactly the open fade, the close fade, the one glow and the one slide")

-------------------------------------------------------------------------------
-- The vendor card's slide: one group on the card that the player's open plays, once the card is drawn at its
-- final width; a swap, a Back restore, a refresh, a layout change and a window open do not play it; a close and
-- a window hide stop it; a card waiting for its width stays hidden until its draw is paid.
-------------------------------------------------------------------------------

local newWorld = assert(loadfile(root .. "/tests/hs538_world.lua"))()

local function eq(a, b, msg)
    if a ~= b then error((msg or "mismatch") .. ": got " .. tostring(a) .. ", wanted " .. tostring(b), 2) end
end

local function world()
    local env = newWorld(root, { realWindow = true })
    env.standard()
    env.open()
    env.B.Data.InvalidateMemos()
    env.B.GoTop({ kind = "allVendors" })
    return env
end

local function rowOf(env, key)
    for _, d in ipairs(env.boxes("sources")[1].provider) do
        if d.key == key then return d end
    end
end

local function card(env)
    for _, f in ipairs(env.all) do
        if f.template == "ScrollFrameTemplate" and env.ownerKind(f) == "vendor" then return f.parent end
    end
end

local function group(env)
    return (card(env) or {}).browserSlide
end

local function plays(env)
    local g = group(env)
    return g and g.plays or 0
end

-- The player opens a card: it slides in over OPEN_TIME from its own width to the right, fading in, played
-- backwards so it ends where it is anchored, and it was drawn before it moved.
do
    local env = world()
    local seen
    local slide = env.B.Window.Slide
    env.B.Window.Slide = function(region, width)
        seen = { drawn = env.wareList() ~= nil, shown = region.parent.shown, width = width }
        return slide(region, width)
    end
    rowOf(env, 100).onClick()
    eq(plays(env), 1, "a card the player opens slides")
    eq(seen.drawn and seen.shown, true, "after it was drawn and shown")
    local g = group(env)
    eq(g.reverse, true, "played backwards")
    eq(g.anims[1].animKind, "Translation")
    eq(g.anims[1].offset[1], seen.width, "from its own width to the right")
    eq(seen.width + env.B.Style.space.xs + env.B.Style.nav.width, env.room(), "which is the room beside the list")
    eq(g.anims[1].duration, 0.15)
    eq(g.anims[2].animKind, "Alpha")
    eq(g.anims[2].from .. g.anims[2].to, "10", "fading in")
    eq(g.anims[2].duration, 0.15)
    eq(#env.groups >= 1, true)

    -- A swap, a refresh and a layout change do not play it again.
    rowOf(env, 101).onClick()
    eq(plays(env), 1, "a swap does not slide")
    env.dataChanged()
    eq(plays(env), 1, "a refresh does not slide")

    -- Close stops it; opening again slides again.
    rowOf(env, 101).onClick()
    eq(g.playing, false, "closing the card stops it")
    eq(plays(env), 1, "and slides nothing")
    rowOf(env, 100).onClick()
    eq(plays(env), 2, "opening it again slides again")

    -- Back to a card from the item page restores it without a slide.
    env.wareList()[1].onClick()
    eq(env.route.kind, "item")
    env.B.Back()
    eq(env.route.kind, "vendor", "Back restores the card")
    eq(plays(env), 2, "without a slide")

    -- Leaving the window stops a slide that is running.
    env.B.GoTop({ kind = "allVendors" })
    rowOf(env, 100).onClick()
    eq(plays(env), 3)
    eq(g.playing, true)
    env.B.Window.frame:Hide()
    eq(g.playing, false, "hiding the window stops it")
    env.B.Window.frame:Show()
    env.flush()
    eq(plays(env), 3, "and showing it again does not play it")

    -- A window open lands on the Overview, with no card to slide.
    env.B.Window.frame:Hide()
    env.B:Open()
    eq(plays(env), 3, "opening the window does not slide")
    print("hs538_motion: slide ok")
end

-- A card opened from another page slides; a card opened over the list a card was just closed onto does too.
do
    local env = world()
    env.B.GoTop({ kind = "overview" })
    env.B.Go({ kind = "vendor", id = 100 })
    eq(plays(env), 1, "Show vendor from another page slides")
    print("hs538_motion: slide from another page ok")
end

-- A card drawn before its page has a width is owed: it stays hidden and does not slide, and when the draw is
-- paid it appears at its final width and then slides.
do
    local env = world()
    env.size(0, 480)
    rowOf(env, 100).onClick()
    eq(card(env).parent.shown, false, "a card waiting for its width stays hidden")
    eq(plays(env), 0, "and does not slide")
    local room = env.room()
    env.size(room, 480)
    local page = env.listFrame()
    page.scripts.OnSizeChanged(page, room, 480)
    eq(card(env).parent.shown, true, "once the draw is paid it shows")
    eq(plays(env), 1, "and slides")
    eq(group(env).anims[1].offset[1] > 0, true, "from a real width")
    print("hs538_motion: owed draw ok")
end

-- An owed draw paid by a refresh and not by the size hook: the card shows, slides once, and gets the fresh
-- scroll, or the saved one on a Back restore.
do
    local env = world()
    rowOf(env, 100).onClick()
    local well = card(env)
    local sf
    for _, f in ipairs(env.all) do
        if f.template == "ScrollFrameTemplate" and env.ownerKind(f) == "vendor" then sf = f end
    end
    sf:SetVerticalScroll(40)
    rowOf(env, 100).onClick()
    env.size(0, 480)
    rowOf(env, 101).onClick()
    eq(well.parent.shown, false, "an owed card is hidden")
    eq(plays(env), 1, "and has not slid")
    env.size(env.room(), 480)
    env.dataChanged()
    eq(well.parent.shown, true, "a refresh that pays the draw shows the card")
    eq(plays(env), 2, "and it slides once")
    eq(sf:GetVerticalScroll(), 0, "from the top")

    -- A Back restore owed the same way keeps the saved scroll and does not slide.
    sf:SetVerticalScroll(40)
    env.wareList()[1].onClick()
    env.size(0, 480)
    env.B.Back()
    eq(well.parent.shown, false, "a restored card owed its draw is hidden")
    env.size(env.room(), 480)
    env.dataChanged()
    eq(well.parent.shown, true, "and shows when a refresh pays it")
    eq(sf:GetVerticalScroll(), 40, "at its saved scroll")
    eq(plays(env), 2, "without a slide")
    print("hs538_motion: owed draw paid by refresh ok")
end

-- The card sits in a holder that clips its children and places it: the card fills the holder, whose anchors
-- follow the mode, beside the list in two columns and over the page in cover.
do
    local env = world()
    rowOf(env, 100).onClick()
    local well = card(env)
    local holder = well.parent
    eq(holder.parent, env.listFrame(), "the holder is a child of the page")
    eq(holder.clips, true, "the holder clips its children")
    eq(well.pts.TOPLEFT[2], nil, "the card starts at the holder's corner")
    eq(well.pts.BOTTOMRIGHT[3], 1, "and ends 1 px above its bottom")
    eq(well.pts.BOTTOMRIGHT[2], 0, "with no change at the right edge")
    eq(holder.pts.BOTTOMRIGHT[3], -1, "where the holder reaches 1 px below it for the border's corners")
    eq(holder.pts.BOTTOMRIGHT[2], 0, "and no further to the right")
    eq(holder.pts.TOPLEFT[3], "TOPRIGHT", "in two columns the holder starts beside the list")
    eq(holder.pts.TOPLEFT[4], env.B.Style.space.xs)
    local page = env.listFrame()
    env.size(400, 480)
    page.scripts.OnSizeChanged(page, 400, 480)
    eq(#holder.pts.TOPLEFT, 1, "in cover it starts at the page's corner")
    eq(holder.pts.BOTTOMRIGHT ~= nil, true, "and ends at the opposite corner")
    eq(well.pts.BOTTOMRIGHT[3], 1, "the card keeps its place in the holder")
    eq(holder.pts.BOTTOMRIGHT[3], -1, "and the holder its extra pixel")
    env.size(env.room(), 480)
    page.scripts.OnSizeChanged(page, env.room(), 480)
    eq(holder.pts.TOPLEFT[3], "TOPRIGHT", "and beside the list again")
    print("hs538_motion: clip holder ok")
end

print("hs538_motion: ok")
