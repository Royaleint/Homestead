-- luacheck: globals assert loadfile print rawset
-- Run from the repo root:  lua tests/hs538_vendor_page.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")
local newWorld = assert(loadfile(root .. "/tests/hs538_world.lua"))()

-------------------------------------------------------------------------------
-- The vendor page, run through the real router, Sources, Widgets, Adapter and CanGet over the shared world:
-- the grid's band order, the bar, the cells and the list row agreeing, the empty and counting states, the
-- Requires line, Hide never removing a ware, the location line, the ladder at a large text size, what
-- Save gives back on Back, and Hide followed by Refresh.
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

local function vfind(env, pred)
    for _, f in ipairs(env.all) do
        if env.ownerKind(f) == "vendor" and pred(f) then return f end
    end
end

-- The text of a visible font string on the vendor page that holds sub.
local function says(env, sub)
    for _, fs in ipairs(env.fontStrings) do
        if env.ownerKind(fs) == "vendor" and fs:IsVisible() and tostring(fs.text):find(sub, 1, true) then return fs.text end
    end
end

local function order(env)
    local ids = {}
    for i, d in ipairs((env.wareList())) do ids[i] = d.itemID end
    return table.concat(ids, ",")
end

local function page(env)
    for p, kind in pairs(env.pageKinds) do
        if kind == "sources" then return p end
    end
end

-- The page width that gives the card's text body wide, in two columns beside the nav-wide list.
local function roomFor(env, body)
    local S = env.B.Style
    return body + S.card.frame + S.nav.width + S.space.xs
end

local function barText(env)
    for _, fs in ipairs(env.fontStrings) do
        local t = tostring(fs.text)
        if env.ownerKind(fs) == "vendor" and fs:IsVisible() and (t:find("^%d+ of %d+ collected$") or t == "Counting…") then
            return t
        end
    end
end

-- The list row's right-hand words for a vendor.
local function rowRight(env, npcID)
    env.go("sources", { type = "vendors" })
    for _, d in ipairs((env.sourcesList())) do
        if d.key == npcID then return d.right end
    end
end

local function open(env, npcID)
    env.B.Go({ kind = "vendor", id = npcID })
end

-- Anna sells 1 Oak Bench (can), 2 Elm Chair, 3 Cedar Table (locked), 6 Ash Stool (can), 8 Fir Candle (ownership
-- unknown). Add a second Oak Bench for the item-number tie.
local function annaWith(env)
    env.owned(2)
    env.decor(70, "Oak Bench")
    env.sell(70, env.vendors[100], { gold = 5 })
end

-- The grid order: can get now first by name, collected last, the rest between; a tie in name falls to the id.
do
    local env = world(nil, annaWith)
    open(env, 100)
    eq(order(env), "6,1,70,3,8,2", "the wares are ordered can, other, collected, each by name then id")
    local rows = env.wareList()
    eq(rows[1].state, "can")
    eq(rows[4].state, "locked")
    eq(rows[6].state, "owned")

    -- The shared memo is read, never sorted: its own order is the source's.
    local memo = env.D.VendorWares(env.vendors[100])
    eq(table.concat(memo, ","), "1,2,3,6,8,70", "the vendor's ware list keeps its order")
    eq(type(rows[1]), "table", "a cell is its own table")
    print("hs538_vendor_page: order ok")
end

-- The bar, the cells and the list row agree; Counting… before the collection is read.
do
    local env = world(nil, function(e)
        annaWith(e)
        e.stats[100] = { collected = 1, total = 6 }
    end)
    eq(rowRight(env, 100), "1 of 6", "the list row")
    open(env, 100)
    eq(barText(env), "1 of 6 collected", "the bar")
    local owned = 0
    for _, d in ipairs((env.wareList())) do if d.state == "owned" then owned = owned + 1 end end
    eq(#env.wareList(), 6, "the cells")
    eq(owned, 1, "owned cells")
    eq(says(env, "3 can get now") ~= nil, true, "the can-get line")
    local words
    for _, fs in ipairs(env.fontStrings) do
        if env.ownerKind(fs) == "vendor" and fs.text == "3 can get now" then words = fs end
    end
    local dot
    for _, t in ipairs(env.textures) do
        if t.parent == words.parent then dot = t end
    end
    local can = env.B.Style.color.can
    assert(dot and dot.shown and dot.color[1] == can[1] and dot.color[2] == can[2], "the dot is the grid's can-get mark, in its colour")

    local counting = world({ done = false, attempted = false }, annaWith)
    open(counting, 100)
    eq(barText(counting), "Counting…", "the bar waits for the collection")
    eq(says(counting, "can get now"), nil, "and so does the can-get line")
    eq(order(counting), "6,3,2,8,1,70", "the cells still show; with no states they sort by name")
    print("hs538_vendor_page: bar, cells and row ok")
end

-- A vendor with no wares and a vanished vendor.
do
    local env = world(nil, function(e) e.vendor(110, { name = "Empty" }) end)
    open(env, 110)
    local e
    for i = #env.emptySets, 1, -1 do
        if env.ownerKind(env.emptySets[i].frame) == "vendor" then e = env.emptySets[i] break end
    end
    assert(e, "no empty state")
    eq(e.d.title, "No decor")
    eq(#env.wareList(), 0)
    eq(barText(env), nil, "no bar at 0 wares")
    eq(says(env, "Corners:"), nil, "no key for an empty grid")
    eq(says(env, "Empty") ~= nil, true, "the head still names the vendor")

    print("hs538_vendor_page: empty ok")
end

-- A vendor that is gone lands on All vendors (the tree home of a vendor), drawn by the real list page.
do
    local env = world()
    local function landed()
        local last = env.crumb[#env.crumb]
        return last.kind .. ":" .. tostring(last.key)
    end
    open(env, 100)
    open(env, 9999)
    eq(landed(), "allVendors:nil", "a Go to a vendor that does not exist")
    eq(env.tab, "sources")
    assert(#(env.sourcesList()) > 0, "the fallback page lists the vendors")
    env.B.Back()
    eq(env.crumb[#env.crumb].id, 100, "Back skips nothing it can still show")

    -- A vendor that vanishes while its page is open: the next refresh replaces it with the list.
    env.vendors[100] = nil
    env.dataChanged()
    eq(landed(), "vendors:other", "a refresh of a vendor that vanished closes onto the list it sat over")
    print("hs538_vendor_page: vanished ok")
end

-- Requires: (done), (not yet), plain text with the can't-check line when met is unknown.
do
    local env = world(nil, function(e)
        local gated = e.vendor(120, { name = "Gated" })
        for _, id in ipairs({ 81, 82 }) do
            e.decor(id, "Gated " .. id)
            e.sell(id, gated)
            e.reqs[id .. ":120"] = { { type = "level", level = 10, met = true }, { type = "achievement", name = "Feat", met = false } }
        end
        local plain = e.vendor(121, { name = "Plain" })
        e.decor(83, "Plain 83")
        e.sell(83, plain)
        e.reqs["83:121"] = { { type = "level", level = 10, met = true }, { type = "unknown", text = "Mysterious Favor" } }
    end)
    open(env, 120)
    local line = says(env, "Requires|r:")
    assert(line, "no Requires line")
    assert(line:find("Level 10 (done)", 1, true), "met true reads (done): " .. line)
    assert(line:find("Achievement: Feat (not yet)", 1, true), "met false reads (not yet): " .. line)
    assert(not line:find("Can't check", 1, true), "every requirement is known")
    local stop = env.B.Style.Colored(env.B.Style.color.stop, "x"):match("^|c(%x+)")
    assert(not line:find("|c" .. stop, 1, true), "no red on a requirement that is not yet met")

    open(env, 121)
    line = says(env, "Requires|r:")
    assert(line:find("Level 10 (done)", 1, true), "the known one still reads (done)")
    assert(line:find("Mysterious Favor", 1, true) and not line:find("Mysterious Favor (", 1, true), "an unknown one shows plain")
    assert(line:find("Can't check this requirement yet", 1, true), "and the can't-check line follows")

    open(env, 100)
    eq(says(env, "Requires|r:"), nil, "no shared requirement, no line")
    print("hs538_vendor_page: requires ok")
end

-- Labels and separators come from the locale, so a translation can reorder them.
do
    local env = world(nil, function(e)
        local L = e.HA.L
        L["%s: %s"], L["%s, %s"], L["%s; %s"], L["%s · %s"] = "%s => %s", "%s + %s", "%s ; %s", "%s @ %s"
        local gated = e.vendor(120, { name = "Gated", zone = "Orgrimmar", mapID = 20 })
        e.decor(81, "Gated 81")
        e.sell(81, gated)
        e.reqs["81:120"] = { { type = "level", level = 10, met = true }, { type = "achievement", name = "Feat", met = false } }
    end)
    open(env, 120)
    assert(says(env, "Level 10 (done) ; Achievement: Feat (not yet)"), "the requirement separator is the locale's")
    assert(says(env, "Orgrimmar @ Kalimdor"), "the continent separator is the locale's")
    assert(says(env, "Requires|r => Level 10"), "the label pattern is the locale's")
    print("hs538_vendor_page: locale ok")
end

-- Hide never removes a ware, and the bar counts them all.
do
    local env = world(nil, function(e) e.owned(4) e.stats[101] = { collected = 1, total = 1 } end)
    open(env, 101)
    eq(order(env), "4")
    env.B.SetHideNA(true)
    eq(order(env), "4", "turning Hide on dropped an owned ware")
    open(env, 100)
    local all = order(env)
    open(env, 101)
    eq(order(env), "4", "a page drawn under Hide dropped an owned ware")
    eq(barText(env), "1 of 1 collected", "and the bar still counts it")
    open(env, 100)
    eq(order(env), all, "a page drawn under Hide dropped a ware")
    env.B.SetHideNA(false)
    env.B.SetHideNA(true)
    eq(order(env), all, "toggling Hide dropped a ware")
    open(env, 102)
    eq(order(env), "6,5", "an other-faction vendor still shows its wares under Hide")
    assert(says(env, "Horde only: can't buy on this character"), "and its stop line")
    print("hs538_vendor_page: Hide ok")
end

-- The location line names the continent only when it differs from the player's.
do
    local env = world()
    open(env, 100)
    eq(says(env, "Trade District, Stormwind") ~= nil, true, "subzone and zone")
    eq(says(env, "·"), nil, "the player's own continent is not named")
    open(env, 101)
    eq(says(env, "Elwynn Forest") ~= nil and says(env, "·") == nil, true, "another zone on the same continent")
    open(env, 102)
    eq(says(env, "Orgrimmar · Kalimdor") ~= nil, true, "another continent is named")
    env.playerMap = 20
    env.B.Facts.Here()
    open(env, 100)
    eq(says(env, "Trade District, Stormwind · Eastern Kingdoms") ~= nil, true, "the same vendor from the other continent")
    print("hs538_vendor_page: continent ok")
end

-- Cells carry the copies, the bonus and the active event; the holiday vendor says Active now only in season.
do
    local env = world({ calendar = { ["Hallow's End"] = true } }, function(e) e.owned(4) end)
    open(env, 100)
    for _, d in ipairs((env.wareList())) do
        if d.itemID == 1 then eq(d.bonus, 1, "the bonus") end
    end
    open(env, 101)
    eq(env.wareList()[1].copies, 1, "the copies")
    open(env, 150)
    eq(env.wareList()[1].active, "Hallow's End", "the active event reaches the cell")
    assert(says(env, "Active now"), "and the head")
    env.calendar["Hallow's End"] = false
    env.dataChanged()
    eq(env.wareList()[1].active, nil, "out of season")
    eq(says(env, "Active now"), nil)
    print("hs538_vendor_page: cells ok")
end

-- The ladder: a short page at a large text size keeps the grid at two rows and scrolls the page.
do
    local env = world()
    open(env, 100)
    local sf = vfind(env, function(f) return f.kind == "ScrollFrame" end)
    local _, box = env.wareList()
    local holder = box.parent
    local p = page(env)
    local fr = env.listFrame()
    local inset = 2 * env.B.Style.layout.wellPad
    eq(sf.ScrollBar.hideIfUnscrollable, true, "the page's bar hides itself when nothing scrolls")
    local ranges = 0
    sf.UpdateScrollChildRect = function() ranges = ranges + 1 end
    fr:SetSize(610, 600 + inset)
    p:Refresh("layout")
    assert(holder.height > 100, "a tall page gives the grid the room")
    local cur
    for _, fs in ipairs(env.fontStrings) do
        if env.ownerKind(fs) == "vendor" and fs:IsVisible() and tostring(fs.text):find("Currency", 1, true) then cur = fs end
    end
    eq(cur.pts.TOPLEFT[3], -(88 + env.B.Style.space.s), "blocks are one space step apart")
    eq(ranges, 1, "every draw refreshes the scroll range")
    assert(holder.parent.height <= 600, "and nothing needs to scroll")

    local base = { meta = 10, metaMuted = 10, body = 12, bodyGold = 12, bodyMuted = 12, subheader = 14, header = 16 }
    env.W.TextHeight = function(role, text, width)
        local line = base[role] * 2
        if width and width > 0 and text then return line * math.max(1, math.ceil(#text * 6 * 2 / width)) end
        return line
    end
    fr:SetSize(610, 320 + inset)
    p:Refresh("layout")
    eq(holder.height, 2 * env.B.Style.ware.size + env.B.Style.ware.gap, "the grid keeps two rows and a gap")
    eq(ranges, 2)
    assert(holder.parent.height > 320, "the content is taller than the page, so the page scrolls")
    local face
    for _, tex in ipairs(env.textures) do
        if tex.width == 88 then face = tex end
    end
    local head = face.parent
    assert(head.parent == holder.parent and head.height >= 88, "the head is kept at its size, or the taller column beside the portrait")
    eq(head.pts.TOPLEFT[3], 0, "and starts at the top")
    print("hs538_vendor_page: ladder ok")
end

-- A first paint before the page has a width waits for one; a resize lays out again.
do
    local env = world()
    open(env, 101)
    local fr = env.listFrame()
    local _, box = env.wareList()
    local S = env.B.Style
    fr:SetSize(0, 400)
    open(env, 100)
    eq(says(env, "Anna"), nil, "a draw before the page has a width is owed, not made")
    fr:SetSize(500, 400)
    fr.scripts.OnSizeChanged(fr, 500, 400)
    eq(box.parent.width, 500 - S.nav.width - S.space.xs - S.card.frame, "the width arrives and the page draws beside the list")
    eq(order(env), "6,2,1,3,8", "with the wares of the vendor it waited for")
    eq(says(env, "Anna") ~= nil, true, "and the head")
    fr:SetSize(640, 400)
    fr.scripts.OnSizeChanged(fr, 640, 400)
    eq(box.parent.width, 640 - S.nav.width - S.space.xs - S.card.frame, "a resize lays out again")
    fr:SetSize(400, 400)
    fr.scripts.OnSizeChanged(fr, 400, 400)
    eq(box.parent.width, 400 - S.card.frame, "a page too narrow for both is covered by the card, which takes all of it")
    print("hs538_vendor_page: width ok")
end

-- A draw that finds its width clears the wait: a later resize redraws in place and does not replay the show that
-- was waiting (which would send the page back to the scroll it was told to restore).
do
    local env = world()
    open(env, 101)
    local sf = vfind(env, function(f) return f.kind == "ScrollFrame" end)
    local fr = env.listFrame()
    local verticals = {}
    sf.SetVerticalScroll = function(_, offset) verticals[#verticals + 1] = offset end
    fr:SetSize(0, 400)
    open(env, 100)
    eq(#verticals, 0, "a show with no width draws nothing")
    fr:SetSize(500, 400)
    page(env):Refresh("layout")
    eq(#verticals, 0, "a refresh is not a fresh show")
    fr:SetSize(640, 400)
    fr.scripts.OnSizeChanged(fr, 640, 400)
    eq(#verticals, 0, "the resize after it replayed the show that was waiting")
    print("hs538_vendor_page: wait ok")
end

-- The can-get line is laid out like the other lines: the column's width less the mark, and as tall as its wrapped text.
-- The column is the page beside the portrait, less the 10 px the close button takes over the text.
do
    local env = world()
    open(env, 100)
    local fr = env.listFrame()
    local base = { meta = 10, metaMuted = 10, body = 12, bodyGold = 12, bodyMuted = 12, subheader = 14, header = 16 }
    env.W.TextHeight = function(role, text, width)
        local line = base[role] * 2
        if width and width > 0 and text then return line * math.max(1, math.ceil(#text * 6 * 2 / width)) end
        return line
    end
    local S = env.B.Style
    local head = S.card.portrait + S.space.m
    local words
    for _, fs in ipairs(env.fontStrings) do
        if env.ownerKind(fs) == "vendor" and fs.text == "3 can get now" then words = fs end
    end
    local mark = 12 + S.space.xs
    fr:SetSize(roomFor(env, head + 10 + mark + 100), 600)
    page(env):Refresh("layout")
    eq(words.width, 100, "the text takes the head column's width less the mark")
    eq(words.height, 48, "and wraps to two lines")
    eq(words.parent.height, 48, "its frame is as tall as the text")
    eq(words.parent.width, mark + 100, "and as wide as the column beside the portrait")
    fr:SetSize(roomFor(env, head + 10 + mark + 400), 600)
    page(env):Refresh("layout")
    eq(words.height, 24, "one line when the page is wide")
    eq(words.parent.height, 24)
    print("hs538_vendor_page: can-get line ok")
end

-- Save and Back: the grid and the page scroll come back; a forward visit starts at the top.
do
    local env = world()
    open(env, 100)
    local sf = vfind(env, function(f) return f.kind == "ScrollFrame" end)
    local _, box = env.wareList()
    local scrolled, vertical = nil, 0
    box.GetDerivedScrollOffset = function() return 137 end
    box.ScrollToOffset = function(_, offset) scrolled = offset end
    sf.GetVerticalScroll = function() return 22 end
    sf.SetVerticalScroll = function(_, offset) vertical = offset end
    open(env, 101)
    eq(vertical, 0, "a forward visit starts at the top")
    eq(scrolled, nil, "and keeps nothing")
    eq(box.keep, false, "the grid is not asked to keep its place")
    env.B.Back()
    eq(env.crumb[#env.crumb].id, 100, "Back returns to the vendor")
    eq(vertical, 22, "the page scroll comes back")
    eq(scrolled, 137, "the grid scroll comes back")
    scrolled = nil
    open(env, 101)
    open(env, 100)
    eq(vertical, 0, "a new visit does not restore")
    eq(scrolled, nil, "and the grid keeps nothing")
    print("hs538_vendor_page: save and restore ok")
end

-- Hide tears down; Refresh after Hide restores without Show; a paint only repaints.
do
    local env = world()
    open(env, 100)
    local p = page(env)
    local _, box = env.wareList()
    local sets = 0
    local setData = box.SetDataProvider
    box.SetDataProvider = function(self, ...) sets = sets + 1 return setData(self, ...) end
    local painted, repaint = 0, env.W.RepaintRows
    env.W.RepaintRows = function(list)
        painted = painted + 1
        return repaint(list)
    end
    p:Refresh("paint")
    eq(sets, 0, "a paint sets no data")
    eq(painted, 2, "and repaints the list's rows and the grid's cells")
    p:Refresh("hide")
    eq(sets, 0, "Hide toggled: nothing to redo on this page")
    p:Hide()
    box.provider = {}
    p:Refresh("hide")
    eq(sets, 1, "after Hide even a hide refresh restores the page")
    eq(#box.provider, 5, "the wares are back")
    p:Hide()
    p:Refresh("paint")
    eq(sets, 2, "a paint after Hide restores the page")
    eq(painted, 2, "instead of repainting")
    p:Refresh("names")
    eq(sets, 3, "a names refresh draws again, keeping the place")
    eq(box.keep, true)
    print("hs538_vendor_page: hide and refresh ok")
end

-- The report link and the waypoint in combat.
do
    local env = world()
    open(env, 100)
    local p = page(env)
    local K = env.B.Style.color
    local function link()
        return vfind(env, function(f) return f.kind == "Button" and type(f.text) == "table" and f.text.text == "Report a problem" end)
    end
    local report = link()
    local wp = vfind(env, function(f) return f.kind == "Button" and rawget(f, "wp") ~= nil end)
    eq(report.text.color[1], K.muted[1], "the link is muted at rest")
    report.scripts.OnEnter(report)
    eq(report.text.color[1], K.body[1], "and white under the mouse")
    report.scripts.OnLeave(report)
    eq(report.text.color[1], K.muted[1])
    local said
    env.B.Tooltip().SetText = function(_, text) said = text end
    p:SetCombat(true)
    env.B.State.inCombat = true
    eq(report.enabled, false, "Report is off in combat")
    eq(report.text.color[1], K.disabled[1], "and darker")
    eq(report.motion, true, "its hover still runs while disabled")
    report.scripts.OnEnter(report)
    eq(said, "Not available in combat", "and says why")
    eq(report.text.color[1], K.disabled[1], "hovering a disabled link does not light it")
    eq(wp.enabled, true, "the waypoint stays on")
    report.scripts.OnLeave(report)
    env.B.State.inCombat = false
    p:SetCombat(false)
    eq(report.enabled, true)
    eq(report.text.color[1], K.muted[1])
    report.scripts.OnClick(report)
    local r = env.reports[1]
    assert(r and r.text:find("Vendor 100: Anna, Stormwind", 1, true), "the vendor report")
    wp.scripts.OnClick(wp)
    eq(env.waypoints[1][1], 10)
    eq(env.waypoints[1][4].data.npcID, 100)
    print("hs538_vendor_page: combat ok")
end

-- The head: the live tag, the note, the portrait on a paint refresh, the location hugging its pin.
do
    local env = world({ calendar = { ["Hallow's End"] = true } }, function(e)
        e.HA.VendorPortraits[100] = 555
        e.vendors[101].notes = "Bring gold."
    end)
    local S = env.B.Style
    local function fontString(sub)
        for _, fs in ipairs(env.fontStrings) do
            if env.ownerKind(fs) == "vendor" and fs:IsVisible() and tostring(fs.text):find(sub, 1, true) then return fs end
        end
    end
    open(env, 150)
    local tag = fontString("Active now")
    assert(tag and tag.text == "Active now", "the live tag has its own line")
    eq(tag.color[1], S.state.live.color[1], "in the live colour")
    assert(not fontString("Ghoul"):GetText():find("Active", 1, true), "and it is not part of the name")
    eq(fontString("Ghoul").width, tag.width, "the tag has the column's whole width")
    eq(fontString("Seasonal: Hallow's End") ~= nil, true, "the Seasonal note follows the location")
    open(env, 100)
    eq(fontString("Active now"), nil, "no tag out of season")
    eq(fontString("Seasonal"), nil, "and no note")
    local where = fontString("Trade District, Stormwind")
    eq(where.width, #where.text * 6 + 1, "the location is as wide as its text, so the pin sits at its end")
    open(env, 101)
    eq(fontString("Bring gold.") ~= nil, true, "a vendor's own note shows")

    open(env, 100)
    local face
    for _, tex in ipairs(env.textures) do
        if tex.width == 88 then face = tex end
    end
    eq(face.portrait, 555, "the portrait")
    env.HA.VendorPortraits[100] = 777
    page(env):Refresh("paint")
    eq(face.portrait, 777, "a paint refresh sets the portrait again")
    print("hs538_vendor_page: head ok")
end

-- The key reads in the muted body font; Not confirmed carries the full sentence in its tooltip.
do
    local env = world()
    open(env, 101)
    local key, conf
    for _, fs in ipairs(env.fontStrings) do
        if env.ownerKind(fs) == "vendor" and fs:IsVisible() then
            if tostring(fs.text):find("Corners:", 1, true) then key = fs end
            if fs.text == "Not confirmed: visit to check." then conf = fs end
        end
    end
    eq(key.font, env.B.Style.font.bodyMuted, "the key's font")
    assert(conf, "Elwynn's vendor is not confirmed")
    local said
    env.B.Tooltip().SetText = function(_, text) said = text end
    local hit = vfind(env, function(f) return f.kind == "Frame" and f.scripts.OnEnter and f.parent == conf.parent end)
    hit.scripts.OnEnter(hit)
    eq(said, env.Facts.NotConfirmed(), "the tooltip is the full sentence")
    print("hs538_vendor_page: key and tooltip ok")
end

-- The list's well and the card's: the list page's first two children.
local function wells(env)
    local fr, kids = env.listFrame(), {}
    for _, f in ipairs(env.all) do
        if f.parent == fr then kids[#kids + 1] = f end
    end
    return kids[1], kids[2]
end

local function closeButton(env)
    for _, f in ipairs(env.all) do
        if f.template == "UIPanelCloseButtonNoScripts" then return f end
    end
end

-- Whether every row of the list is narrowed, and which are selected.
local function narrowed(env)
    local all, any, lit = true, false, {}
    for _, d in ipairs((env.sourcesList())) do
        all, any = all and d.narrow == true, any or d.narrow == true
        if d.selected then lit[#lit + 1] = d.key end
    end
    return all, any, table.concat(lit, ",")
end

-- Two columns or cover (B8): a card opened from a list narrows the list and sits beside it when the page has
-- room for both, and covers the page when it does not. Only the page's width and the text decide.
do
    local env = world()
    local S = env.B.Style
    local fr = env.listFrame()
    env.B.Go({ kind = "allVendors" })
    local well, card = wells(env)
    eq(card.shown, false, "no card, no card well")
    eq(well.pts.BOTTOMRIGHT ~= nil and well.pts.BOTTOMLEFT == nil, true, "the list takes the whole page")
    open(env, 100)
    eq(card.shown, true, "the card shows")
    eq(well.shown, true, "and the list stays shown")
    eq(well.pts.BOTTOMLEFT ~= nil and well.pts.BOTTOMRIGHT == nil, true, "the list is a column")
    eq(well.width, S.nav.width, "as wide as the tree")
    eq(card.pts.TOPLEFT[2], well, "the card starts at the list")
    eq(card.pts.TOPLEFT[3], "TOPRIGHT")
    eq(card.pts.TOPLEFT[4], S.space.xs, "a gap away")
    eq(card.mouse, true, "and takes the mouse")
    local all, _, lit = narrowed(env)
    eq(all, true, "every row is narrowed beside a card")
    eq(lit, "100", "and only the open card's row is lit")

    -- A page too narrow for both: the card covers it, the list keeps its rows, and the row is still lit.
    fr:SetSize(400, 480)
    fr.scripts.OnSizeChanged(fr, 400, 480)
    eq(#card.pts.TOPLEFT, 1, "the card starts at the page's corner")
    eq(card.pts.BOTTOMRIGHT ~= nil, true, "and ends at the opposite corner")
    eq(well.pts.BOTTOMRIGHT ~= nil and well.pts.BOTTOMLEFT == nil, true, "the list is the whole page under it")
    local any
    _, any, lit = narrowed(env)
    eq(any, false, "under a covering card the list keeps its full rows")
    eq(lit, "100", "and the row is lit")
    eq(card.shown, true)

    -- Room again: the mode changes at once, in place.
    fr:SetSize(610, 480)
    fr.scripts.OnSizeChanged(fr, 610, 480)
    eq(well.width, S.nav.width)
    eq((narrowed(env)), true, "two columns again")
    eq(env.route.id, 100, "the card never closed")

    -- A search that filters the open card's row out leaves the card open with no row lit (B10).
    page(env):Filter("Elwynn")
    eq(env.route.id, 100, "the card stays open")
    eq(card.shown, true)
    eq(#env.sourcesList() > 0, true, "the list still has other vendors")
    all, _, lit = narrowed(env)
    eq(all, true, "narrowed")
    eq(lit, "", "with no row lit")
    page(env):Filter("")
    _, _, lit = narrowed(env)
    eq(lit, "100", "and the row lights again when the search clears")

    -- Close by the X: the list is whole again, with no row narrowed or lit.
    local x = closeButton(env)
    x.scripts.OnClick(x)
    eq(env.route.kind, "vendors", "the X closes the card onto its list")
    eq(card.shown, false)
    eq(well.pts.BOTTOMRIGHT ~= nil and well.pts.BOTTOMLEFT == nil, true, "the list is the whole page")
    _, any, lit = narrowed(env)
    eq(any, false, "no row stays narrowed")
    eq(lit, "", "or lit")
    print("hs538_vendor_page: columns and cover ok")
end

-- The mode follows the text and the language, at each tree width, and nothing else.
do
    local function modeAt(nav, words, size)
        local env = world(nil, function(e) e.B.Style.nav.width = nav end)
        local S = env.B.Style
        S.state.some.word = words
        env.W.TextWidth = function(_, text) return #text * 6 * size end
        env.W.ResetMeasure()
        env.B.Go({ kind = "allVendors" })
        open(env, 100)
        local well, card = wells(env)
        return well.pts.BOTTOMLEFT ~= nil and "two" or "cover", well.width, card
    end
    for _, nav in ipairs({ 172, 186, 192 }) do
        for _, size in ipairs({ 0.857, 1, 2 }) do
            local mode, col = modeAt(nav, "%d can get now", size)
            eq(mode, "two", "English at " .. size .. ", tree " .. nav)
            eq(col, size == 2 and 226 or nav, "the list column at " .. size .. ", tree " .. nav)
        end
        eq((modeAt(nav, "%d jetzt erhältlich", 1)), "two", "German at 1.0, tree " .. nav)
        eq((modeAt(nav, "%d jetzt erhältlich", 2)), "cover", "German at 2.0, tree " .. nav)
        eq((modeAt(nav, "Можно получить сейчас: %d", 2)), "cover", "Russian at 2.0, tree " .. nav)
    end
    print("hs538_vendor_page: breakpoint ok")
end

-- A text-size change moves the card between the modes at once, and a window rescale does not.
do
    local env = world()
    local S = env.B.Style
    local size = 1
    env.W.TextWidth = function(_, text) return #text * 6 * size end
    env.W.ResetMeasure()
    env.B.Go({ kind = "allVendors" })
    open(env, 100)
    local well = wells(env)
    local p = page(env)
    size = 2
    env.W.ResetMeasure()
    p:Refresh("layout")
    eq(well.width, 226, "Gigantic English: a wider column, still two columns")
    S.state.some.word = "%d jetzt erhältlich"
    env.W.ResetMeasure()
    p:Refresh("layout")
    eq(well.pts.BOTTOMRIGHT ~= nil and well.pts.BOTTOMLEFT == nil, true, "Gigantic German: the card covers")
    eq(env.route.id, 100, "with the card still open")
    local events
    for _, f in ipairs(env.all) do
        if f.scripts.OnEvent then events = f end
    end
    for _, ev in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        events.scripts.OnEvent(events, ev)
        eq(well.pts.BOTTOMRIGHT ~= nil and well.pts.BOTTOMLEFT == nil, true, ev .. " left the covering card as it was")
    end
    size = 1
    env.W.ResetMeasure()
    p:Refresh("layout")
    eq(well.pts.BOTTOMLEFT ~= nil, true, "German at 1.0 fits beside the list")
    for _, ev in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        events.scripts.OnEvent(events, ev)
        eq(well.pts.BOTTOMLEFT ~= nil, true, ev .. " left two columns as they were")
    end
    print("hs538_vendor_page: text size and rescale ok")
end

-- The red X (B6): the NoScripts template with its own click, on the card's well and not on the scroll, never
-- disabled, and no other close template on the vendor page.
do
    local env = world()
    open(env, 100)
    local _, card = wells(env)
    local x = closeButton(env)
    eq(x.kind, "Button", "a plain button")
    eq(x.parent, card, "on the card's well, so it stays put while the card scrolls")
    local names = {}
    for name in pairs(x.scripts) do names[#names + 1] = name end
    eq(table.concat(names, ","), "OnClick", "it has our own click and nothing else")
    for _, f in ipairs(env.all) do
        if env.ownerKind(f) == "vendor" or f.parent == card then
            assert(f.template ~= "UIPanelCloseButton", "the stock close button hides its parent panel")
        end
    end
    env.B.State.inCombat = true
    page(env):SetCombat(true)
    eq(x:IsEnabled(), true, "combat leaves the X enabled")
    eq(x:IsShown(), true)
    x.scripts.OnClick(x)
    eq(env.route.kind, "vendors", "and the X closes the card in combat")
    eq(card.shown, false)
    env.B.State.inCombat = false
    page(env):SetCombat(false)
    print("hs538_vendor_page: X ok")
end

-- Boundaries: a vendor with no wares, one with a single ware, and the largest (which scrolls its grid and, with
-- the header, still fits the card), at each tree width.
do
    for _, nav in ipairs({ 172, 186, 192 }) do
        local env = world(nil, function(e)
            e.B.Style.nav.width = nav
            local big = e.vendor(130, { name = "Big" })
            for i = 1, 80 do
                e.decor(1000 + i, "Big " .. i)
                e.sell(1000 + i, big)
            end
            e.vendor(131, { name = "Lone" })
            e.decor(2000, "Lone 1")
            e.sell(2000, e.vendors[131])
            e.vendor(110, { name = "Empty" })
        end)
        local S = env.B.Style
        env.B.Go({ kind = "allVendors" })
        local _, card = wells(env)
        for _, id in ipairs({ 110, 131, 130 }) do
            open(env, id)
            eq(card.shown, true, "the card opens for vendor " .. id .. " at tree " .. nav)
            local wares = env.wareList()
            eq(#wares, id == 130 and 80 or id == 131 and 1 or 0, "its wares")
            local _, box = env.wareList()
            local holder = box.parent
            local floor = 2 * S.ware.size + S.ware.gap
            assert(holder.height >= floor, "the grid keeps two rows")
            assert(holder.parent.height <= 480 - 2 * S.layout.wellPad, "the header and the grid fit the card, so the grid scrolls")
            eq(holder.width, env.room(nav) - nav - S.space.xs - S.card.frame, "the body is the page less the list and the frame")
        end
    end
    print("hs538_vendor_page: boundaries ok")
end

-- Opening, swapping, covering and closing a card change the list's width and never its data: the box measures
-- its frames again in place (Rebuild, keeping the scroll position), so a header that now wraps is drawn at its new
-- height, and the list keeps its data, its scroll and its lit row. FullUpdate would leave drawn frames as they are.
do
    for _, footer in ipairs({ false, true }) do
        local env = world(nil, function(e)
            e.owned(4)
            e.stats[101] = { collected = 1, total = 1 }
            e.vendor(140, { name = "Longzone", zone = "The Extremely Long Zone Name Of Doom And Gloom Valley" })
            e.decor(90, "Long 90")
            e.sell(90, e.vendors[140])
        end)
        local base = { meta = 10, metaMuted = 10, body = 12, bodyGold = 12, bodyMuted = 12, subheader = 14, header = 16 }
        env.W.TextHeight = function(role, text, width)
            local line = base[role]
            if width and width > 0 and text then return line * math.max(1, math.ceil(#text * 6 / width)) end
            return line
        end
        env.B.SetHideNA(footer)
        env.B.Go({ kind = "vendors", key = "other" })
        local _, note, box = env.sourcesList()
        eq(note ~= nil, footer, "the list has a footer only while Hide hides something")
        local provider, scrolls = box.provider, #box.scrolls
        local long
        local function held(label, rebuilds, width)
            eq(box.provider, provider, label .. ": it is the same data")
            eq(#box.scrolls, scrolls, label .. ": the list scrolled nowhere")
            eq(box.rebuilds or 0, rebuilds, label .. ": the box rebuilt its frames")
            if rebuilds > 0 then eq(box.retain, true, label .. ": keeping the scroll position") end
            for i, d in ipairs(provider) do
                local f = box.frames[i]
                if f and d.kind == "header" then
                    eq(f.extent, box.view.extent(i, d), label .. ": the header on screen has its new extent")
                    if d.text:find("Extremely", 1, true) then long = f.extent end
                end
            end
            eq(long > env.W.HeaderHeight(), width < 300, label .. ": the long header wraps only in the narrow list")
        end
        box.width = 130
        open(env, 100)
        held("opening", 1, 130)
        eq((select(3, narrowed(env))), "100", "the open card's row is lit")
        env.B.Go({ kind = "vendor", id = 101, list = { kind = "vendors", key = "other" } })
        held("swapping", 1, 130)
        local fr = env.listFrame()
        box.width = 600
        fr:SetSize(400, 480)
        fr.scripts.OnSizeChanged(fr, 400, 480)
        held("covering", 2, 600)
        box.width = 130
        fr:SetSize(610, 480)
        fr.scripts.OnSizeChanged(fr, 610, 480)
        held("two columns again", 3, 130)
        eq((select(3, narrowed(env))), footer and "" or "101", "the lit row is kept")
        box.width = 600
        page(env):CloseCard()
        held("closing", 4, 600)
    end
    print("hs538_vendor_page: list measures in place ok")
end

-- Headers: a long zone name is one line in a wide list and wraps in the narrow column; the width the box has
-- when it measures decides.
do
    local env = world(nil, function(e)
        e.vendor(140, { name = "Longzone", zone = "The Extremely Long Zone Name Of Doom And Gloom Valley" })
        e.decor(90, "Long 90")
        e.sell(90, e.vendors[140])
    end)
    local base = { meta = 10, metaMuted = 10, body = 12, bodyGold = 12, bodyMuted = 12, subheader = 14, header = 16 }
    env.W.TextHeight = function(role, text, width)
        local line = base[role]
        if width and width > 0 and text then return line * math.max(1, math.ceil(#text * 6 / width)) end
        return line
    end
    env.B.Go({ kind = "vendors", key = "other" })
    local _, _, box = env.sourcesList()
    local at = env.indexOf(box, function(d) return d.kind == "header" and d.text:find("Extremely", 1, true) end)
    assert(at, "the long zone has a header")
    box.width = 600
    local wide = box.view.extent(at, box.provider[at])
    eq(wide, env.W.HeaderHeight(), "wide: one line")
    box.width = 130
    local narrow = box.view.extent(at, box.provider[at])
    assert(narrow > wide, "narrow: the header wraps into more lines")
    print("hs538_vendor_page: header wrap ok")
end

-- The card's own scroll bar starts below the close button, so neither covers the other's controls; the card
-- keeps the wheel from the list under it.
do
    local env = world()
    open(env, 100)
    local _, card = wells(env)
    local x = closeButton(env)
    local sf = vfind(env, function(f) return f.kind == "ScrollFrame" end)
    local barTop = sf.pts.TOPLEFT[3] + sf.ScrollBar.pts.TOPLEFT[5]
    local xBottom = x.pts.TOPRIGHT[3] - env.B.Style.card.close
    assert(barTop <= xBottom, "the scroll bar starts at " .. barTop .. ", under the close button, which ends at " .. xBottom)
    eq(sf.ScrollBar.pts.TOPLEFT[2], sf, "and hangs from the scroll frame")
    eq(card.wheel, true, "the card takes the wheel")
    assert(card.scripts.OnMouseWheel, "and answers it, so the list under a covering card does not scroll")
    print("hs538_vendor_page: scroll bar and wheel ok")
end

-- The size hook: a height-only change does not read the mode again; a draw owed at width 0 is paid when the
-- width comes back, even though it is the width seen before.
do
    local env = world()
    env.B.Go({ kind = "allVendors" })
    local splits, split = 0, env.W.Split
    env.W.Split = function(...) splits = splits + 1 return split(...) end
    open(env, 100)
    local fr = env.listFrame()
    fr.scripts.OnSizeChanged(fr, 610, 480)
    local seen = splits
    fr.scripts.OnSizeChanged(fr, 610, 500)
    eq(splits, seen, "the same width reads nothing again")
    fr.scripts.OnSizeChanged(fr, 611, 500)
    eq(splits, seen + 1, "a new width reads the mode")
    fr:SetSize(610, 480)
    fr.scripts.OnSizeChanged(fr, 610, 480)
    fr:SetSize(0, 480)
    fr.scripts.OnSizeChanged(fr, 0, 480)
    open(env, 101)
    assert(order(env) ~= "4", "a draw at width 0 is owed")
    fr:SetSize(610, 480)
    fr.scripts.OnSizeChanged(fr, 610, 480)
    eq(order(env), "4", "and paid when the width returns")
    print("hs538_vendor_page: size hook ok")
end

-- A list that never had a row has no data in its box: the client's Rebuild would raise on it, so a card opened
-- over it and closed again changes the mode and rebuilds nothing, and the route change completes.
do
    local env = world(nil, function(e)
        for id in pairs(e.vendors) do
            if id ~= 101 then e.vendors[id] = nil end
        end
        e.owned(4)
        e.stats[101] = { collected = 1, total = 1 }
    end)
    env.B.SetHideNA(true)
    open(env, 101)
    local well, card = wells(env)
    local box = env.boxes("sources")[1]
    eq(box.provider, nil, "the list never had a row, so its box has no data")
    eq(box:HasDataProvider(), false)
    eq(card.shown, true, "the card is open over the empty list")
    local x = closeButton(env)
    local ok, err = pcall(x.scripts.OnClick, x)
    eq(ok, true, "closing the card raised: " .. tostring(err))
    eq(env.route.kind, "vendors", "the route change completed")
    eq(env.tab, "sources", "and the nav is on the list")
    eq(card.shown, false, "the card is closed")
    eq(well.pts.BOTTOMRIGHT ~= nil and well.pts.BOTTOMLEFT == nil, true, "and the list is the whole page")
    eq(box.rebuilds, nil, "nothing was rebuilt")
    print("hs538_vendor_page: empty list ok")
end

print("hs538_vendor_page: all ok")
