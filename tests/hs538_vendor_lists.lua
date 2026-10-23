-- luacheck: globals assert loadfile print C_Map ScrollBoxConstants
-- Run from the repo root:  lua tests/hs538_vendor_lists.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")
local newWorld = assert(loadfile(root .. "/tests/hs538_world.lua"))()

-------------------------------------------------------------------------------
-- The vendor lists, through the real router, window, Sources page and data modules: All vendors grouped by
-- expansion then zone, one expansion's list grouped by zone, rows that open the vendor page and never select,
-- the heads, the zone seed behind "More vendors here", the header box (live filter, a restore that is not a new
-- search, the clear button, Enter), the per-page placeholder, the full-width page, the ware reads, and a
-- vanished expansion.
-------------------------------------------------------------------------------

local function eq(a, b, msg)
    if a ~= b then error((msg or "mismatch") .. ": got " .. tostring(a) .. ", wanted " .. tostring(b), 2) end
end

-- Anna and Bran sell for Midnight, Cora for Classic, Eve for no expansion, Fay for no zone.
local function world(setup)
    local env = newWorld(root, { realWindow = true })
    local v = env.standard()
    v.anna.expansion, v.bran.expansion, v.cora.expansion = "Midnight", "Midnight", "Classic"
    env.sell(2, v.bran, { gold = 1 })
    v.fay = env.vendor(105, { name = "Fay" })
    v.fay.zone = nil
    env.decor(80, "Fay Lamp")
    env.sell(80, v.fay, { gold = 5 })
    if setup then setup(env, v) end
    env.open()
    env.B.Data.InvalidateMemos()
    return env, v
end

-- The list as it draws: "# text" for a header, "## text" for a nested one, the vendor's key for a row.
local function shape(env)
    local box = env.boxes("sources")[1]
    local out = {}
    for _, d in ipairs(box.provider) do
        out[#out + 1] = d.kind == "header" and ((d.nested and "## " or "# ") .. d.text) or tostring(d.key or d.kind)
    end
    return table.concat(out, ","), box
end

local function head(env)
    for i = #env.fontStrings, 1, -1 do
        local fs = env.fontStrings[i]
        if env.owner(fs) == "sources" and (tostring(fs.text):find("^%d+ of %d+ collected$") or fs.text == "Counting…") then
            return fs.text
        end
    end
end

-- The Sources page object, to count what the header box asks of it.
local function page(env)
    for _, p in ipairs(env.pageList) do
        if env.pageKinds[p] == "sources" then return p end
    end
end

local function wares(env)
    local n = 0
    for _, op in ipairs(env.measured) do if op == "browser_vendor_wares" then n = n + 1 end end
    return n
end

-- The header box's hint.
local function hint(env)
    return env.B.Window.search.Instructions:GetText()
end

local function type_(env, text)
    local box = env.B.Window.search
    box.text = text
    box.scripts.OnTextChanged(box, true)
end

-- All vendors: expansion headers, zone headers nested under them, a vendor with no zone last.
do
    local env = world()
    env.B.Go({ kind = "allVendors" })
    eq(shape(env), "# Midnight,## Elwynn Forest,101,## Stormwind,100,# Classic,## Orgrimmar,102,"
        .. "# Other Vendors,## Orgrimmar,104,## Location not recorded,105", "All vendors")
    eq(env.route.kind, "allVendors")
    eq(head(env), "1 of 9 collected", "the head is the walk's vendor count: items 1-6, 8, 13 and 80")
    -- A zone header sits one step in under its expansion's.
    local _, box = shape(env)
    local function indent(text)
        for _, f in ipairs(box.frames) do
            if rawget(f, "text") and f.text.text == text then return f.text.pts.LEFT[2] end
        end
    end
    local SP = env.B.Style.space
    eq(indent("Midnight"), SP.s, "an expansion header")
    eq(indent("Stormwind"), SP.s + SP.m, "a zone header under it")
    print("hs538_vendor_lists: all vendors ok")
end

-- One expansion: zone headers only, only its vendors, its head counts each ware once.
do
    local env = world()
    env.B.Go({ kind = "vendors", key = "Midnight" })
    eq(shape(env), "# Elwynn Forest,101,# Stormwind,100", "Midnight")
    eq(head(env), "1 of 6 collected", "Anna's 1, 2, 3, 6, 8 and Bran's 4 and 2 (a ware both sell counts once), one owned")
    env.B.Go({ kind = "vendors", key = "other" })
    eq(shape(env), "# Orgrimmar,104,# Location not recorded,105", "Other Vendors")
    eq(head(env), "0 of 2 collected")
    env.B.Go({ kind = "vendors", key = "Classic" })
    eq(shape(env), "# Orgrimmar,102")
    print("hs538_vendor_lists: expansion lists ok")
end

-- Rows open the vendor page and never select. Every list, vendor or source, is one well filling its page.
do
    local env = world()
    env.B.Go({ kind = "allVendors" })
    local _, box = shape(env)
    for _, d in ipairs(box.provider) do assert(not d.selected, "a vendor list selects no row") end
    -- The list box sits in the holder and the well; the well is the page's only child.
    local listPage = env.boxes("sources")[1].parent.parent.parent
    local function fills()
        local kids = {}
        for _, f in ipairs(env.all) do
            if f.parent == listPage then kids[#kids + 1] = f end
        end
        eq(#kids, 1, "the list page holds the well alone")
        eq(#kids[1].pts.TOPLEFT, 1, "the well starts at the page's corner")
        eq(#kids[1].pts.BOTTOMRIGHT, 1, "and ends at the page's opposite corner")
        eq(kids[1].shown, true, "and is shown")
    end
    fills()
    local d
    for _, row in ipairs(box.provider) do if row.key == 101 then d = row end end
    d.onClick()
    eq(env.route.kind .. ":" .. env.route.id, "vendor:101", "a row opens the vendor page")
    env.B.Go({ kind = "sources", key = "achievements" })
    fills()
    eq(hint(env), "Search achievements", "a source list's hint names its kind")
    env.B.Go({ kind = "sources", key = "shop" })
    eq(hint(env), "Search the Shop", "and follows the list")
    env.B.Go({ kind = "vendors", key = "Midnight" })
    fills()
    eq(hint(env), "Search vendors and zones", "a vendor list's hint names vendors and zones")
    print("hs538_vendor_lists: rows and full width ok")
end

-- The zone seed scrolls to that zone's header; Back and a seed with no match scroll nowhere.
do
    local env = world()
    env.B.Go({ kind = "allVendors", seed = { zone = 10 } })
    local _, box = shape(env)
    local at = env.lastScroll(box)
    eq(box.provider[at].text, "Stormwind", "the seed zone's header")
    eq(box.provider[at].nested, true)
    env.B.Go({ kind = "allVendors", seed = { zone = 999 } })
    eq(env.lastScroll(box), at, "a zone with no vendor scrolls nowhere")
    env.B.Go({ kind = "allVendors", seed = { zone = 20 } })
    eq(box.provider[env.lastScroll(box)].text, "Orgrimmar")
    eq(box.provider[env.lastScroll(box)].nested, true)
    eq(env.lastScroll(box) , env.indexOf(box, function(row) return row.text == "Orgrimmar" end),
        "the first matching header is the newest expansion's")
    -- Back restores the saved offset and ignores the seed.
    box.GetDerivedScrollOffset = function() return 77 end
    local offsets = {}
    box.ScrollToOffset = function(_, offset) offsets[#offsets + 1] = offset end
    local scrolls = #box.scrolls
    env.B.Go({ kind = "overview" })
    env.B.Back()
    eq(offsets[#offsets], 77, "Back restores the offset the page saved")
    eq(#box.scrolls, scrolls, "and the seed is not applied again")
    print("hs538_vendor_lists: zone seed ok")
end

-- "More vendors here" opens All vendors at the player's zone.
do
    local env = world()
    env.go("summary")
    local more = env.button("summary", "More vendors here")
    assert(more and more.shown, "the Here line links to more vendors")
    env.click(more)
    eq(env.route.kind, "allVendors")
    local _, box = shape(env)
    eq(box.provider[env.lastScroll(box)].text, "Stormwind", "at the zone the line is about")
    eq(box.aligns[#box.scrolls], ScrollBoxConstants.AlignBegin, "the zone header lands at the top of the list")
    print("hs538_vendor_lists: more vendors here ok")
end

-- The player's zone counts its child maps, as the Here line does: a vendor in a zone-type child map of the
-- player's zone is "here", so the jump goes to that vendor's header even though its own zone differs.
do
    local env = world(function(e)
        e.maps[12] = { name = "Stormwind Harbor", mapType = 3, parentMapID = 10 }
        C_Map.GetMapChildrenInfo = function(zone) return zone == 10 and { { mapID = 12 } } or {} end
        local harbor = e.vendor(106, { name = "Harbor Hand", mapID = 12, zone = "Aaa Harbor" })
        harbor.expansion = "Midnight"
        e.decor(81, "Harbor Lamp")
        e.sell(81, harbor, { gold = 5 })
    end)
    env.go("summary")
    env.click(env.button("summary", "More vendors here"))
    local _, box = shape(env)
    eq(box.provider[env.lastScroll(box)].text, "Aaa Harbor", "the child-map vendor's header, not the zone's own")
    -- A zone that is not the player's keeps the plain match: Orgrimmar's own header.
    env.B.Go({ kind = "allVendors", seed = { zone = 20 } })
    eq(box.provider[env.lastScroll(box)].text, "Orgrimmar")
    print("hs538_vendor_lists: here zone includes child maps ok")
end

-- The header box filters the list as you type; a restore is not typing; the clear button is.
do
    local env = world()
    local P = page(env)
    local filtered = 0
    local filter = P.Filter
    function P:Filter(text)
        filtered = filtered + 1
        return filter(self, text)
    end
    env.B.Go({ kind = "allVendors" })
    local win = env.B.Window
    type_(env, "bran")
    eq(shape(env), "# Midnight,## Elwynn Forest,101", "typing filters")
    eq(filtered, 1)
    env.B.Go({ kind = "vendor", id = 101 })
    eq(win.search.text, "", "the box clears when the page changes")
    eq(filtered, 1, "and that is not typing")
    env.B.Back()
    eq(win.search.text, "bran", "Back sets the box again")
    eq(shape(env), "# Midnight,## Elwynn Forest,101", "and the list is as it was")
    eq(filtered, 1, "a restore does not count as a new search")
    win.SetSearch("oak")
    eq(filtered, 1, "SetSearch never filters")
    win.search:SetText("")
    eq(filtered, 2, "the clear button's SetText filters")
    eq(env.sourceKeys(), "101,100,102,104,105", "and the whole list is back")
    type_(env, "stormwind")
    eq(env.sourceKeys(), "100", "by zone")
    type_(env, "nothing like it")
    local empty = env.emptyOf("sources")
    eq(empty and empty.d.text, "Nothing matches your search.")
    env.click(empty.frame.buttons[1])
    eq(win.search.text, "", "Reset filters clears the box")
    eq(env.sourceKeys(), "101,100,102,104,105", "and brings the list back")
    -- Back out of the page and in again: one step each, no stray history from the restore.
    type_(env, "bran")
    env.B.Go({ kind = "vendor", id = 101 })
    env.B.Back()
    env.B.Back()
    eq(env.route.kind, "overview", "two Backs reach Overview: the restore added no step")
    print("hs538_vendor_lists: header box ok")
end

-- A source list gets its search and scroll back on Back, as the vendor lists do.
do
    local env = world()
    env.B.Go({ kind = "sources", key = "achievements" })
    type_(env, "rug")
    eq(env.sourceKeys(), "9001", "typing filters a source list")
    local box = env.boxes("sources")[1]
    box.GetDerivedScrollOffset = function() return 55 end
    local offsets = {}
    box.ScrollToOffset = function(_, offset) offsets[#offsets + 1] = offset end
    env.B.Go({ kind = "overview" })
    eq(env.B.Window.search.text, "", "the box clears when the page changes")
    env.B.Back()
    eq(env.route.kind .. ":" .. env.route.key, "sources:achievements")
    eq(env.B.Window.search.text, "rug", "Back sets the box again")
    eq(env.sourceKeys(), "9001", "and the list is as it was")
    eq(offsets[#offsets], 55, "and the offset the page saved")
    print("hs538_vendor_lists: source list Back ok")
end

-- Enter on a list page filters nothing further and goes nowhere; the hint follows the page.
do
    local env = world()
    local win = env.B.Window
    eq(win.search.Instructions.text, "Search decor")
    env.B.Go({ kind = "allVendors" })
    eq(win.search.Instructions.text, "Search vendors and zones")
    type_(env, "bran")
    win.search.scripts.OnEnterPressed(win.search)
    eq(env.route.kind, "allVendors", "Enter on a vendor list stays on it")
    env.B.Go({ kind = "vendors", key = "Midnight" })
    eq(win.search.Instructions.text, "Search vendors and zones")
    env.B.Go({ kind = "sources", key = "quests" })
    eq(win.search.Instructions.text, "Search quests")
    env.B.Go({ kind = "overview" })
    eq(win.search.Instructions.text, "Search decor", "a page with no hint restores the default")
    env.B.Back()
    eq(win.search.Instructions.text, "Search quests", "Back takes the page's hint again")
    print("hs538_vendor_lists: Enter and hints ok")
end

-- The legacy call shapes land on the right pages.
do
    local env = world()
    env.go("sources", { type = "vendors", search = "bran" })
    eq(env.route.kind, "allVendors")
    eq(env.B.Window.search.text, "bran", "the seed's search is in the box")
    eq(shape(env), "# Midnight,## Elwynn Forest,101")
    env.go("sources", { type = "vendors", select = { key = 100 } })
    eq(env.route.kind .. ":" .. env.route.id, "vendor:100", "a pick opens the vendor page")
    print("hs538_vendor_lists: legacy calls ok")
end

-- A vendor's wares are read once per memo version, and only for the vendors a list shows. The tree, folding it
-- and repainting read none.
do
    local env = world()
    env.B.Data.InvalidateMemos()
    local n = wares(env)
    local Win = env.B.Window
    Win.SelectNav({ kind = "vendors", key = "Midnight" })
    eq(wares(env), n, "the tree reads no wares")
    env.B.Go({ kind = "vendors", key = "Midnight" })
    eq(wares(env), n + 2, "an expansion list reads its own vendors' wares, Anna's and Bran's")
    env.handlers.HideNA(true)
    env.handlers.HideNA(false)
    env.B.RequestRefresh(true)
    env.flush()
    env.B.Go({ kind = "vendors", key = "Midnight" })
    eq(wares(env), n + 2, "Hide, a count refresh and a repeat of the same list read none")
    env.B.Go({ kind = "allVendors" })
    eq(wares(env), n + 5, "All vendors reads the rest once: Cora, Eve and Fay")
    env.B.Go({ kind = "vendors", key = "Classic" })
    env.B.Go({ kind = "allVendors" })
    eq(wares(env), n + 5, "and nothing again within the memo version")
    env.B.Data.InvalidateMemos()
    env.B.Go({ kind = "vendors", key = "Classic" })
    eq(wares(env), n + 6, "a new memo version reads again, and only the vendors shown")
    print("hs538_vendor_lists: ware reads ok")
end

-- An expansion with no listed vendor left is gone: the router lands on All vendors, and Back skips it.
do
    local env = world()
    env.B.Go({ kind = "vendors", key = "Classic" })
    env.B.Go({ kind = "vendor", id = 100 })
    env.vendors[102] = nil
    env.dataChanged()
    env.B.Back()
    eq(env.route.kind, "overview", "Back drops the dead expansion and returns to the entry before it")
    env.B.Go({ kind = "vendors", key = "Classic" })
    eq(env.route.kind, "allVendors", "a Go to an expansion with no vendor lands on All vendors")
    env.B.Go({ kind = "vendors", key = "Midnight" })
    env.vendors[100], env.vendors[101] = nil, nil
    env.dataChanged()
    eq(env.route.kind, "allVendors", "a refresh of an emptied expansion falls back")
    print("hs538_vendor_lists: vanished expansion ok")
end

print("hs538_vendor_lists: all ok")
