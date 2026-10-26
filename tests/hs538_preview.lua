-- luacheck: globals assert loadfile print rawget
-- Run from the repo root:  lua tests/hs538_preview.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")
local newWorld = assert(loadfile(root .. "/tests/hs538_world.lua"))()

-------------------------------------------------------------------------------
-- The item page's 3D preview and its place in the router, over the shared world: one model load per item,
-- none when the setting is off or the item has no model, the scene let go on Hide and loaded again after it,
-- the setting never building the browser, what Save gives back on Back, and Hide followed by Refresh.
-------------------------------------------------------------------------------

local function eq(a, b, msg)
    if a ~= b then error((msg or "mismatch") .. ": got " .. tostring(a) .. ", wanted " .. tostring(b), 2) end
end

-- Oak Bench (1) and Elm Chair (2) carry models; Cedar Table (3) has none.
local function world(setup)
    local env = newWorld(root)
    env.standard()
    env.catalog[1].asset = 5001
    env.catalog[2] = { totalNumStored = 0, categoryIDs = { 1 }, asset = 5002, uiModelSceneID = 40 }
    if setup then setup(env) end
    env.open()
    return env
end

local function page(env)
    for p, kind in pairs(env.pageKinds) do
        if kind == "item" then return p end
    end
end

local function open(env, itemID)
    env.B.Go({ kind = "item", id = itemID })
end

local function scenes(env)
    local n = 0
    for _, f in ipairs(env.all) do
        if f.kind == "ModelScene" then n = n + 1 end
    end
    return n
end

local function scene(env)
    for _, f in ipairs(env.all) do
        if f.kind == "ModelScene" then return f end
    end
end

-- The well the scene sits in: shown only while a model is up.
local function wellShown(env)
    local s = scene(env)
    return s ~= nil and s.parent.shown
end

-- One load per item: showing, routing to and refreshing the same item load nothing more.
do
    local env = world()
    open(env, 1)
    eq(#env.models, 1, "the first show loads the model")
    eq(env.models[1], 5001)
    eq(env.sceneIDs[1], 1317, "an entry without its own scene uses the catalog's")
    local s = scene(env)
    eq(s.actor.bounds, true, "the model is framed by its collision bounds")
    eq(s.sceneArgs[1], "immediate")
    eq(s.sceneArgs[2], "discard")
    eq(s.sceneArgs[3], true)
    eq(s.wheel, false, "the scene leaves the wheel to the page")
    eq(wellShown(env), true)
    open(env, 1)
    page(env):Refresh("data")
    page(env):Refresh("zone")
    page(env):Refresh("layout")
    eq(#env.models, 1, "a second show of the same item loaded again")
    eq(scenes(env), 1)
    open(env, 2)
    eq(#env.models, 2, "another item loads its own model")
    eq(env.models[2], 5002)
    eq(env.sceneIDs[#env.sceneIDs], 40, "an entry's own scene is used")
    eq(scenes(env), 1, "the scene is reused")
    print("hs538_preview: one load per item ok")
end

-- An entry's own scene without a decor actor falls back to the catalog's.
do
    local env = world(function(e) e.noActor[40] = true end)
    open(env, 2)
    eq(table.concat(env.sceneIDs, ","), "40,1317", "no fallback to the catalog's scene")
    eq(#env.models, 1)
    eq(wellShown(env), true)
    env.noActor[1317] = true
    open(env, 1)
    eq(#env.models, 1, "a scene with no actor took a model")
    eq(wellShown(env), false, "the well stays up with nothing in it")
    print("hs538_preview: scene fallback ok")
end

-- The setting off, or an item with no model: no scene is made.
do
    local env = world()
    env.B.SetModel3D(false)
    open(env, 1)
    eq(scenes(env), 0, "a scene was made with the setting off")
    eq(#env.models, 0)
    env.B.SetModel3D(true)
    eq(#env.models, 1, "turning the setting on did not load the shown item")
    eq(wellShown(env), true)
    env.B.SetModel3D(false)
    eq(env.clears, 1, "turning the setting off did not let the model go")
    eq(wellShown(env), false)
    env.B.SetModel3D(true)
    eq(#env.models, 2, "turning it back on did not load again")

    local bare = world()
    open(bare, 3)
    eq(scenes(bare), 0, "a scene was made for an item with no model")
    eq(#bare.models, 0)
    print("hs538_preview: setting and no-model ok")
end

-- The setting changes a single repaint, writes only its own key, and is kept in the profile.
do
    local env = world()
    open(env, 1)
    local p = page(env)
    local reasons, refresh = {}, p.Refresh
    p.Refresh = function(self, reason)
        reasons[#reasons + 1] = reason
        return refresh(self, reason)
    end
    local before = #env.saves
    env.B.SetModel3D(false)
    p.Refresh = refresh
    eq(table.concat(reasons, ","), "paint", "the setting did not repaint once")
    eq(#env.saves, before + 1)
    eq(env.saves[#env.saves], "model3D")
    eq(env.HA.Addon.db.profile.browser.model3D, false)
    eq(env.B.Model3D(), false)
    print("hs538_preview: setting repaint ok")
end

-- Hide lets the model go; Go, Hide then Refresh keeps the item and loads its model again.
do
    local env = world()
    open(env, 1)
    local p = page(env)
    p:Hide()
    eq(env.clears, 1, "Hide kept the model")
    p:Refresh("stats")
    eq(env.selectedItem(), 1)
    eq(#env.models, 2, "Refresh after Hide did not load the model again")
    eq(env.models[2], 5001, "Refresh after Hide lost the item")
    eq(wellShown(env), true)
    print("hs538_preview: hide and reload ok")
end

-- The browser never opened: the Options checkbox writes the setting and builds nothing.
do
    local env = newWorld(root)
    env.standard()
    assert(loadfile(root .. "/UI/OptionsModel.lua"))("Homestead", env.HA)
    local box
    for _, section in ipairs(env.HA.OptionsModel.sections) do
        for _, row in ipairs(section.rows) do
            if row.key == "browserModel3D" then box = row end
        end
    end
    assert(box, "no 3D preview checkbox")
    local count = #env.all
    box.set(false)
    eq(box.get(), false)
    box.set(true)
    eq(box.get(), true)
    eq(#env.all, count, "the setting built frames")
    eq(rawget(env.B.Window, "frame"), nil, "the setting built the browser")
    print("hs538_preview: closed browser ok")
end

-- Save and Back: the item's page scroll comes back; a forward visit starts at the top.
do
    local env = world()
    open(env, 1)
    local sf
    for _, f in ipairs(env.all) do
        if f.kind == "ScrollFrame" and env.ownerKind(f) == "item" then sf = f end
    end
    local vertical
    sf.GetVerticalScroll = function() return 31 end
    sf.SetVerticalScroll = function(_, offset) vertical = offset end
    open(env, 2)
    eq(vertical, 0, "a forward visit starts at the top")
    env.B.Back()
    eq(env.selectedItem(), 1, "Back returns to the first item")
    eq(vertical, 31, "the page scroll comes back")
    eq(#env.models, 3, "Back loads the first item's model again")
    vertical = nil
    page(env):Refresh("data")
    eq(vertical, nil, "a refresh moved the scroll")
    print("hs538_preview: save and back ok")
end

-- Hidden by the game's interface toggle and back: the page is hidden, then the router's refresh draws the item
-- again without a Show.
do
    local env = world()
    open(env, 1)
    local shows = #env.itemShows
    env.B.Window.frame:Hide()
    env.handlers.OnHide()
    eq(env.clears, 1, "hiding the browser kept the model")
    env.B.Window.frame:Show()
    env.handlers.OnShow()
    env.flush()
    eq(#env.itemShows, shows, "reopening showed the page again instead of refreshing it")
    eq(#env.models, 2, "reopening did not load the model again")
    eq(wellShown(env), true)
    print("hs538_preview: close and reopen ok")
end

print("hs538_preview: ok")
