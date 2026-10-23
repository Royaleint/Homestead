-- luacheck: globals assert loadfile print rawset rawget getmetatable CreateFrame C_Item
-- Run from the repo root:  lua tests/hs538_ware_grid.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")
local newWorld = assert(loadfile(root .. "/tests/hs538_world.lua"))()

-------------------------------------------------------------------------------
-- The ware grid and its cells: the stride follows the box width, each cell's marks match B.ItemState, copies
-- wait for the collection and cap at 99+, Collected is marked and never dimmed, a recycled cell lets go of
-- its tooltip, shift-click links the item when the game has its link and otherwise falls through, and the
-- tooltip carries Active now and the First-Time Collection Bonus. Real Widgets, Browser, Adapter and CanGet.
-------------------------------------------------------------------------------

local function eq(a, b, msg)
    if a ~= b then error((msg or "mismatch") .. ": got " .. tostring(a) .. ", wanted " .. tostring(b), 2) end
end

local function world(opts, setup)
    local env = newWorld(root, opts)
    env.standard()
    if setup then setup(env) end
    env.open()
    return env
end

-- A frame whose textures are recorded.
local function frame(kind)
    local f = CreateFrame(kind or "Button")
    local make = getmetatable(f).__index(f, "CreateTexture")
    f.textures = {}
    f.CreateTexture = function(self, ...)
        local t = make(self, ...)
        self.textures[#self.textures + 1] = t
        return t
    end
    return f
end

local function at(f, point)
    for _, t in ipairs(f.textures) do
        if t.pts and t.pts[point] then return t end
    end
end

-- A built cell, its mark corners and its copies text.
local function newCell(env)
    local cell = frame()
    env.W.NewWareCell(cell)
    local copies
    for _, fs in ipairs(env.fontStrings) do
        if fs.parent == cell then copies = fs end
    end
    return cell, { mark = at(cell, "TOPRIGHT"), star = at(cell, "TOPLEFT"), clock = at(cell, "BOTTOMLEFT"), copies = copies }
end

-- The state B.ItemState gives an item, as a cell's data.
local function ware(env, itemID, npcID, extra)
    local state, arg = env.B.ItemState(itemID, npcID)
    local d = { itemID = itemID, npcID = npcID, quality = 2, icon = 1000 + itemID, state = state, arg = arg }
    for k, v in pairs(extra or {}) do d[k] = v end
    return d
end

local tipLines
local function recordTip(env)
    local tip = env.B.Tooltip()
    tip.SetOwner = function(self, owner)
        self.owner = owner
        tipLines = {}
    end
    tip.GetOwner = function(self) return self.owner end
    tip.AddLine = function(_, text) tipLines[#tipLines + 1] = text end
    tip.AddDoubleLine = function(_, a, b) tipLines[#tipLines + 1] = a .. " " .. b end
    return tip
end

local function hasLine(text)
    for _, l in ipairs(tipLines) do if l == text then return true end end
    return false
end

-- The stride follows the box width.
do
    local env = world()
    local W = env.W
    local view
    rawset(_G, "CreateScrollBoxListGridView", function(stride, top, bottom, left, right, hGap, vGap)
        view = { stride = stride, args = { top, bottom, left, right, hGap, vGap } }
        function view:SetElementInitializer(_, fn) self.init = fn end
        function view:SetElementResetter(fn) self.reset = fn end
        function view:SetElementSize(w, h) self.cellW, self.cellH = w, h end
        function view:SetStride(n) self.stride = n end
        function view:GetStride() return self.stride end
        return view
    end)
    local S = env.B.Style
    local grid = W.NewGrid(frame("Frame"), S.ware.size, S.ware.gap)
    eq(S.ware.size, 48)
    eq(S.ware.gap, 4)
    eq(view.cellW, 48, "cell size")
    local full = 0
    grid.box.SetDataProvider = function(_, p) grid.box.provider = p end
    grid.box.FullUpdate = function() full = full + 1 end
    grid.box:SetWidth(582)
    grid:SetData({})
    eq(view.stride, 11, "stride at 582 px")
    grid:SetData({}, false, 214)
    eq(view.stride, 4, "stride at 214 px (a width given with the data wins)")
    grid.box:SetWidth(582)
    grid.box.scripts.OnSizeChanged(grid.box)
    eq(view.stride, 11, "a resize restrides")
    eq(full, 1, "and redraws once")
    grid.box.scripts.OnSizeChanged(grid.box)
    eq(full, 1, "a resize that keeps the stride does not redraw")
    grid.box:SetWidth(20)
    grid.box.scripts.OnSizeChanged(grid.box)
    eq(view.stride, 11, "a box narrower than a cell keeps its stride")
    local data = { ware(env, 1, 100), ware(env, 4, 101) }
    grid:SetData(data)
    eq(grid.box.provider[2], data[2], "the data reaches the box")

    -- The pooled frame is built once and is the cell.
    local f = frame()
    view.init(f, data[1])
    eq(f.itemID, 1, "init sets the cell")
    local mark = at(f, "TOPRIGHT")
    view.init(f, data[2])
    eq(f.itemID, 4, "a swap re-sets the cell")
    eq(#f.textures, 7, "the cell is built once")
    assert(mark.shown and at(f, "TOPRIGHT") == mark, "the swapped cell keeps its mark")
    view.reset(f)
    eq(f.itemID, nil, "reset clears the cell")

    -- A box with nothing to scroll gives the wheel to the page behind it; a hidden grid hides its bar.
    local scrollable = false
    grid.box.HasScrollableExtent = function() return scrollable end
    grid.box.EnableMouseWheel = function(self, on) self.wheel = on end
    grid:SetData(data)
    eq(grid.box.wheel, false, "a grid with nothing to scroll took the wheel")
    scrollable = true
    grid:SetData(data)
    eq(grid.box.wheel, true, "a grid that scrolls lost the wheel")
    scrollable = false
    grid.box.scripts.OnSizeChanged(grid.box)
    eq(grid.box.wheel, false, "a resize did not hand the wheel back")
    grid:SetShown(false)
    eq(grid.box.shown, false)
    eq(grid.bar.shown, false, "a hidden grid left its bar showing")
    grid:SetShown(true)
    eq(grid.box.shown, true)
    print("hs538_ware_grid: stride ok")
end

-- Marks against B.ItemState, nine states.
do
    local cases = {}
    local function add(name, env, id, npc, want) cases[#cases + 1] = { name, env, id, npc, want } end
    local ready = world()
    add("can", ready, 1, 100, "dot")
    add("locked", ready, 3, 100, "lock")
    add("owned", ready, 4, 101, "check")
    add("faction", ready, 5, 102, "stop")
    add("notOwned", ready, 7, nil, false)
    add("unknown", ready, 8, 100, false)
    add("event", ready, 51, 150, "clock")
    add("counting", world({ done = false, attempted = false }), 1, nil, false)
    add("notRead", world({ done = false, attempted = true }), 1, nil, false)
    eq(#cases, 9)
    local seen = {}
    for _, c in ipairs(cases) do
        local name, env, id, npc, want = c[1], c[2], c[3], c[4], c[5]
        local cell, parts = newCell(env)
        local d = ware(env, id, npc)
        seen[tostring(d.state)] = true
        cell:Set(d)
        local st = env.B.Style.state[d.state]
        if want then
            eq(d.state ~= nil and st.glyph, want, name .. ": the state's glyph")
            assert(parts.mark.shown, name .. ": no mark")
            local col = st.color
            assert(parts.mark.color[1] == col[1] and parts.mark.color[2] == col[2] and parts.mark.color[3] == col[3],
                name .. ": the mark takes the state colour")
        else
            assert(not parts.mark.shown, name .. ": a mark where the state has none (" .. tostring(d.state) .. ")")
        end
    end
    for _, s in ipairs({ "can", "locked", "owned", "faction", "notOwned", "event", "counting", "nil" }) do
        assert(seen[s], "the matrix never reached state " .. s)
    end
    print("hs538_ware_grid: marks ok")
end

-- Collected is marked and never dimmed; Locked is desaturated; the other corners.
do
    local env = world()
    local cell, parts = newCell(env)
    local icon = at(cell, "CENTER")
    cell:Set(ware(env, 4, 101))
    assert(parts.mark.shown, "Collected has no check")
    eq(env.W.StateWords("owned"), "Collected")
    eq(icon.desaturated, false, "a Collected cell is not desaturated")
    eq(rawget(cell, "alpha"), nil, "a Collected cell is not dimmed")
    eq(rawget(icon, "alpha"), nil, "nor its icon")
    cell:Set(ware(env, 3, 100))
    eq(icon.desaturated, true, "a Locked cell is desaturated")
    cell:Set(ware(env, 1, 100))
    eq(icon.desaturated, false, "a recycled cell keeps no desaturation")
    assert(not parts.star.shown and not parts.clock.shown, "no star or clock without a bonus or an active event")
    cell:Set(ware(env, 1, 100, { bonus = true, active = true }))
    assert(parts.star.shown and parts.clock.shown, "the star and the clock")
    cell:Set(ware(env, 1, 100))
    assert(not parts.star.shown and not parts.clock.shown, "a recycled cell keeps no star or clock")

    -- A row follows the same rule.
    local row = env.W.BuildRow(frame())
    local rowIcon = at(row, "LEFT")
    row:Set({ name = "Pine Shelf", quality = 2, state = "owned" })
    eq(rowIcon.desaturated, false, "a Collected row is not desaturated")
    row:Set({ name = "Cedar Table", quality = 2, state = "locked", arg = "Favor" })
    eq(rowIcon.desaturated, true, "a Locked row is desaturated")
    print("hs538_ware_grid: collected and locked ok")
end

-- Copies wait for the collection and cap at 99+.
do
    local env = world()
    local cell, parts = newCell(env)
    cell:Set(ware(env, 4, 101))
    assert(not parts.copies.shown and parts.copies.text == "", "no copies before there is a number")
    for _, case in ipairs({ { 1, "1" }, { 99, "99" }, { 100, "99+" }, { 250, "99+" } }) do
        cell:Set(ware(env, 4, 101, { copies = case[1] }))
        assert(parts.copies.shown, "copies hidden at " .. case[1])
        eq(tostring(parts.copies.text), case[2], "copies at " .. case[1])
    end
    cell:Set(ware(env, 4, 101))
    assert(not parts.copies.shown, "a recycled cell keeps no copies")
    -- The data side: nil until the collection is ready, then placed plus stored.
    local counting = world({ done = false, attempted = false })
    eq(select(2, counting.D.IconData(4, true)), nil, "copies are nil while counting")
    eq(select(2, env.D.IconData(4, true)), 1, "copies once ready")
    print("hs538_ware_grid: copies ok")
end

-- A recycled cell hides its tooltip, and only its own.
do
    local env = world()
    local tip = recordTip(env)
    local a, b = newCell(env), newCell(env)
    a:Set(ware(env, 1, 100))
    b:Set(ware(env, 2, 100))
    a.scripts.OnEnter(a)
    assert(tip:IsShown() and tip:GetOwner() == a, "the hover did not put the tooltip on the cell")
    b:Reset()
    assert(tip:IsShown(), "recycling another cell hid the tooltip")
    a:Reset()
    assert(not tip:IsShown(), "recycling the hovered cell left its tooltip up")
    eq(a.itemID, nil)
    a:Set(ware(env, 1, 100))
    a.scripts.OnEnter(a)
    a.scripts.OnLeave(a)
    assert(not tip:IsShown(), "leaving the cell leaves the tooltip up")
    -- A row with its own hover handler runs it instead of the item tooltip.
    local own, hovered = frame(), 0
    local row = env.W.BuildRow(own)
    row:Set({ name = "Elm Chair", quality = 2, itemID = 2, onEnter = function() hovered = hovered + 1 end })
    tip:Hide()
    row.scripts.OnEnter(row)
    eq(hovered, 1, "the row's own hover handler runs")
    assert(not tip:IsShown(), "and the item tooltip stays down")
    print("hs538_ware_grid: recycled cell tooltip ok")
end

-- Shift-click on cells and rows.
do
    local env = world()
    local loads, shows = 0, {}
    C_Item.RequestLoadItemDataByID = function() loads = loads + 1 end
    env.B.Go = function(route) shows[#shows + 1] = route.kind .. ":" .. tostring(route.id) end
    local cell = newCell(env)
    cell:Set(ware(env, 2, 100))

    cell.scripts.OnClick(cell)
    eq(shows[1], "item:2", "a plain click opens the item")
    eq(#env.linked, 0)

    env.modifier = "CHATLINK"
    env.links[2] = "|Hitem:2|h[Elm Chair]|h"
    cell.scripts.OnClick(cell)
    eq(#shows, 1, "a shift-click with a link does not open the item")
    eq(env.linked[1], "|Hitem:2|h[Elm Chair]|h", "and links it")

    env.links[2] = nil
    cell.scripts.OnClick(cell)
    eq(#env.linked, 1, "without a cached link nothing is linked")
    eq(shows[2], "item:2", "and the click falls through to open the item")
    eq(loads, 0, "and no load is requested")

    -- A modifier that is not the chat link does not link.
    env.modifier, env.links[2] = "SPLITSTACK", "|Hitem:2|h[Elm Chair]|h"
    cell.scripts.OnClick(cell)
    eq(#env.linked, 1, "another modified click does not link")

    -- Rows.
    local clicked = 0
    local row = env.W.BuildRow(frame())
    row:Set({ name = "Elm Chair", quality = 2, itemID = 2, onClick = function() clicked = clicked + 1 end })
    env.modifier = "CHATLINK"
    row.scripts.OnClick(row)
    eq(clicked, 0, "a shift-click with a link does not run the row's click")
    eq(#env.linked, 2, "it links")
    env.links[2] = nil
    row.scripts.OnClick(row)
    eq(clicked, 1, "without a link the row's click runs")
    eq(#env.linked, 2)
    env.modifier = nil
    row.scripts.OnClick(row)
    eq(clicked, 2, "a plain click runs the row's click")
    local plain = env.W.BuildRow(frame())
    plain:Set({ name = "No item", quality = 2, onClick = function() clicked = clicked + 1 end })
    env.modifier = "CHATLINK"
    plain.scripts.OnClick(plain)
    eq(clicked, 3, "a row with no item has nothing to link")
    eq(loads, 0)
    print("hs538_ware_grid: shift-click ok")
end

-- Overview rows link on shift-click too, and a closed chat box (the link is refused) falls through everywhere.
do
    local env = world()
    env.go("summary")
    local row
    for _, f in ipairs(env.all) do
        if env.owner(f) == "summary" and rawget(f, "why") and f.shown and f.itemID then row = f end
    end
    assert(row, "Overview draws no item row")
    local id = row.itemID
    local shows = {}
    env.B.Go = function(route) shows[#shows + 1] = route.kind .. ":" .. tostring(route.id) end
    env.modifier, env.links[id] = "CHATLINK", "|Hitem:" .. id .. "|h[Item]|h"
    row.scripts.OnClick(row)
    eq(env.linked[1], env.links[id], "a shift-click on an Overview row links the item")
    eq(#shows, 0, "and does not navigate")
    env.modifier = nil
    row.scripts.OnClick(row)
    eq(shows[1], "item:" .. id, "a plain click on an Overview row opens the item")

    env.modifier = "CHATLINK"
    rawset(_G, "HandleModifiedItemClick", function() return false end)
    local cell = newCell(env)
    cell:Set(ware(env, 2, 100))
    local plain = env.W.BuildRow(frame())
    local clicked = 0
    plain:Set({ name = "Elm Chair", quality = 2, itemID = 2, onClick = function() clicked = clicked + 1 end })
    env.links[2] = "|Hitem:2|h[Elm Chair]|h"
    cell.scripts.OnClick(cell)
    eq(shows[#shows], "item:2", "a refused link falls through to opening the item (cell)")
    plain.scripts.OnClick(plain)
    eq(clicked, 1, "a refused link falls through to the row's click")
    local n = #shows
    row.scripts.OnClick(row)
    eq(#shows, n + 1, "a refused link falls through to opening the item (Overview row)")
    print("hs538_ware_grid: overview shift-click and refused link ok")
end

-- The tooltip: Active now and the First-Time Collection Bonus.
do
    local B
    local normal
    -- Blizzard's own helper and format string, stubbed the way the client defines them.
    rawset(_G, "HOUSING_DECOR_FIRST_ACQUISITION_FORMAT", "Bonus: %d")
    rawset(_G, "GameTooltip_AddNormalLine", function(tip, text)
        normal[#normal + 1] = text
        tip:AddLine(text)
    end)
    local function show(env, id, npc)
        B = env.B
        normal = {}
        recordTip(env)
        B.ShowItemTooltip(frame(), id, npc)
    end
    local active = world(nil, function(e) e.calendar["Hallow's End"] = true end)
    show(active, 51, 150)
    assert(hasLine("Active now: Hallow's End"), "in season the tooltip lacks Active now")
    local idle = world()
    show(idle, 51, 150)
    assert(not hasLine("Active now: Hallow's End"), "out of season the tooltip says Active now")
    for _, l in ipairs(tipLines) do assert(not l:find("Active now", 1, true), "out of season: " .. l) end
    eq(idle.D.TooltipData(51, 150).active, nil)
    eq(active.D.TooltipData(51, 150).active, "Hallow's End")

    local bonus, fallback = "Bonus: 1", "First-Time Collection Bonus Available"
    show(idle, 1, nil)
    assert(hasLine(bonus), "item 1 has the bonus line with its amount (no vendor given)")
    eq(normal[1], bonus, "through Blizzard's normal-line helper")
    show(idle, 2, nil)
    assert(not hasLine(bonus) and #normal == 0, "item 2 has no bonus line")
    show(idle, 1, 100)
    assert(hasLine(bonus), "item 1 at a vendor has the bonus line")
    eq(idle.D.TooltipData(1).bonus, 1, "the entry carries the amount")
    eq(idle.D.TooltipData(2).bonus, nil)
    -- The amount is the catalog's, not a flag.
    local five = world(nil, function(e) e.catalog[13].firstAcquisitionBonus = 5 end)
    show(five, 13, nil)
    eq(normal[1], "Bonus: 5", "the line carries the entry's amount")
    -- Without Blizzard's helper or string the old words are used.
    rawset(_G, "HOUSING_DECOR_FIRST_ACQUISITION_FORMAT", nil)
    show(idle, 1, nil)
    assert(hasLine(fallback) and #normal == 0, "the fallback line when the format is missing")
    rawset(_G, "HOUSING_DECOR_FIRST_ACQUISITION_FORMAT", "Bonus: %d")
    local helper = _G.GameTooltip_AddNormalLine
    rawset(_G, "GameTooltip_AddNormalLine", nil)
    show(idle, 1, nil)
    assert(hasLine(fallback), "the fallback line when the helper is missing")
    rawset(_G, "GameTooltip_AddNormalLine", helper)
    -- An owned item no longer carries the bonus; before the collection is read there is nothing to say.
    local owned = world(nil, function(e) e.owned(1) e.catalog[1].firstAcquisitionBonus = 1 end)
    show(owned, 1, nil)
    assert(not hasLine(bonus) and not hasLine(fallback), "an owned item still shows the bonus")
    local counting = world({ done = false, attempted = false })
    show(counting, 1, nil)
    assert(not hasLine(bonus) and not hasLine(fallback), "the bonus shows before the collection is read")
    print("hs538_ware_grid: tooltip lines ok")
end

-- The bar.
do
    local env = world()
    local bar = env.W.Bar(frame("Frame"))
    local fill
    for _, f in ipairs(env.all) do
        if f.kind == "StatusBar" then fill = f end
    end
    assert(fill, "the bar made no status bar")
    fill.SetValue = function(self, v) self.value = v end
    bar.text.SetText = function(self, t) self.shown_text = t end
    bar:Set("3 of 4 collected", 0.75)
    eq(fill.value, 0.75)
    eq(bar.text.shown_text, "3 of 4 collected")
    bar:Set("Counting…", nil)
    eq(fill.value, 0, "no ratio is an empty bar")
    print("hs538_ware_grid: bar ok")
end

print("hs538_ware_grid: ok")
