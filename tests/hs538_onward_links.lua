-- luacheck: globals assert loadfile print
-- Run from the repo root:  lua tests/hs538_onward_links.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")
local newWorld = assert(loadfile(root .. "/tests/hs538_world.lua"))()

-------------------------------------------------------------------------------
-- Every onward link between the tabs, run through the real router with the real
-- Summary, Catalog, Sources and item detail: the target tab is shown, a Catalog
-- landing resets the filters and keeps the sort, the landed item or source is
-- selected, scrolled into view and its detail filled, a plain tab switch keeps
-- state, and a landing still works when the Hide toggle would hide the target.
-------------------------------------------------------------------------------

local function eq(a, b, msg)
    if a ~= b then error((msg or "mismatch") .. ": got " .. tostring(a) .. ", wanted " .. tostring(b), 2) end
end

local function world(profile)
    local env = newWorld(root)
    for k, v in pairs(profile or {}) do env.HA.Addon.db.profile.browser[k] = v end
    env.standard()
    env.open()
    return env
end

-- The Summary rows as drawn, best first.
local function summaryRows(env)
    local out = {}
    for _, f in ipairs(env.all) do
        if env.owner(f) == "summary" and rawget(f, "why") and rawget(f, "src") and f.shown then out[#out + 1] = f end
    end
    return out
end

local function summaryRow(env, itemID)
    for _, r in ipairs(summaryRows(env)) do
        if r.itemID == itemID then return r end
    end
    error("Summary draws no row for item " .. itemID)
end

-- Runs fn, then checks the Catalog landed on itemID: shown, selected, scrolled to, detail filled.
local function landsOnItem(env, itemID, fn, label)
    local _, _, box = env.catalogList()
    local scrolls, shows = #box.scrolls, #env.itemShows
    fn()
    eq(env.tab, "catalog", label .. ": tab")
    local ids, _, nowBox = env.catalogList()
    local at
    for i, id in ipairs(ids) do if id == itemID then at = i end end
    assert(at, label .. ": item " .. itemID .. " is not in the list " .. table.concat(ids, ","))
    assert(#nowBox.scrolls > scrolls, label .. ": the list was not scrolled")
    eq(env.lastScroll(nowBox), at, label .. ": scrolled to the item's row")
    assert(#env.itemShows > shows, label .. ": the detail was not filled")
    eq(env.selectedItem(), itemID, label .. ": selected item")
    local row = env.catalogRow(itemID)
    assert(row and row.d.selected == true, label .. ": the drawn row is not selected")
end

-- Runs fn, then checks the source page is open for key and lists the source's decor.
local function landsOnSource(env, key, wares, fn, label)
    fn()
    eq(env.tab, "sources", label .. ": tab")
    local last = env.crumb[#env.crumb]
    eq(last.kind, "source", label .. ": page")
    eq(last.id, key, label .. ": source")
    eq(env.decorIds(), wares, label .. ": the page lists the source's decor")
end

-- Runs fn, then checks the vendor page is open for npcID and draws its wares.
local function landsOnVendor(env, npcID, wares, fn, label)
    fn()
    local last = env.crumb[#env.crumb]
    eq(last.kind, "vendor", label .. ": page")
    eq(last.id, npcID, label .. ": vendor")
    eq(env.wareIds(), wares, label .. ": the page draws the vendor's wares")
end

-- The Catalog's item ids, sorted, for checks that do not care about the order.
local function idSet(env)
    local ids = {}
    for i, id in ipairs((env.catalogList())) do ids[i] = id end
    table.sort(ids)
    return table.concat(ids, ",")
end

local function tipWrites(env)
    local n = 0
    for _, key in ipairs(env.saves) do if key == "tipSeen" then n = n + 1 end end
    return n
end

-------------------------------------------------------------------------------
-- Summary: row, Show, Set waypoint, See all, Show vendor, search, By source
-------------------------------------------------------------------------------

do
    local env = world()
    eq(env.tab, "summary", "opens on Summary")
    local rows = summaryRows(env)
    eq(#rows, 3, "three rows")
    eq(rows[1].itemID, 1, "best row")

    landsOnItem(env, 1, function() env.click(rows[1]) end, "row click")

    -- A row with a known spot offers Set waypoint and leaves the tab alone.
    env.go("summary")
    local row = summaryRow(env, 1)
    assert(row.wp.shown and not row.show.shown, "a known spot offers Set waypoint")
    local tab = env.tab
    env.click(row.wp)
    eq(#env.waypoints, 1, "one waypoint set")
    eq(env.waypoints[1][1], 10, "at the vendor's map")
    eq(env.tab, tab, "Set waypoint changes no tab")

    -- A row without a spot offers Show.
    row = summaryRow(env, 13)
    assert(row.show.shown and not row.wp.shown, "no spot offers Show")
    landsOnItem(env, 13, function() env.click(row.show) end, "row Show")
    print("hs538_onward_links: Summary rows ok")
end

do
    local env = world({ tipSeen = false })
    -- See all lands in Best order on the can-get-now filter, whatever the sort was, and writes tipSeen once.
    env.go("catalog", { sort = "name" })
    env.go("summary")
    local see = env.find("summary", function(f) return f.kind == "Button" and f.shown and f.text:find("^See all you can get now") end)
    assert(see, "no See all button")
    eq(see.text, "See all you can get now (4)")
    env.click(see)
    eq(env.tab, "catalog")
    eq(env.idString(), "1,13,6,2", "R15: the four you can get now, Best order")
    eq(env.searchText("catalog"), "", "no search")
    eq(tipWrites(env), 1, "tipSeen written once")
    eq(env.HA.Addon.db.profile.browser.tipSeen, true, "tipSeen saved")
    env.go("summary")
    env.click(env.find("summary", function(f) return f.kind == "Button" and f.shown and f.text:find("^See all") end))
    eq(tipWrites(env), 1, "tipSeen is not written again")
    print("hs538_onward_links: See all ok")
end

do
    local env = world()
    -- R16: the zone block's Show vendor lands on that vendor's page with its wares.
    local btn = env.button("summary", "Show vendor")
    assert(btn, "the zone block offers Show vendor")
    landsOnVendor(env, 100, "1,2,3,6,8", function() env.click(btn) end, "Show vendor")
    eq(env.crumb[2].key, "other", "the crumb passes through the vendor's expansion")

    print("hs538_onward_links: zone block ok")
end

do
    -- R17: the header search box lands on All decor with the words, from any page, both ways.
    local env = newWorld(root, { realWindow = true })
    env.standard()
    env.open()
    local B = env.B
    local box = B.Window.search
    local routes, go = {}, B.Go
    B.Go = function(route) routes[#routes + 1] = route return go(route) end
    box.text = "  oak "
    box.scripts.OnEnterPressed(box)
    eq(#routes, 1, "Enter makes one route")
    eq(routes[1].kind, "catalog")
    eq(routes[1].key, "all")
    eq(routes[1].seed.search, "oak", "the words arrive trimmed")
    eq(env.tab, "catalog")
    eq(idSet(env), "1,12", "Search: the Oak items, kind all")
    eq(env.searchText("catalog"), "oak", "the Catalog box shows the words")
    eq(box.text, "oak", "and so does the header box")
    env.go("summary")
    eq(box.text, "", "a page opened without a search clears the header box")
    box.text = "willow"
    box.scripts.OnEnterPressed(box)
    eq(env.idString(), "7", "Enter does the same from the Overview")
    box.text = "oak"
    box.scripts.OnEnterPressed(box)
    eq(env.idString(), "1,12", "Enter on the Catalog searches again")
    print("hs538_onward_links: header search ok")
end

do
    -- R18: each source type's tree row opens that type with its sources listed (the By source list's job).
    local want = { vendors = "100", achievements = "9001", quests = "7001", professions = "8001",
        drops = "Boss|Keep", events = "Hallow's End", shop = "61" }
    for _, key in ipairs({ "vendors", "achievements", "quests", "professions", "drops", "events", "shop" }) do
        local env = newWorld(root, { realWindow = true })
        env.standard()
        env.open()
        local label = env.B.Style.sourceLabel[key]
        local row
        for _, box in ipairs(env.boxList) do
            for _, f in ipairs(box.frames) do
                if f.data and f.data.label == label then row = f end
            end
        end
        assert(row, "no tree row for " .. key)
        env.click(row)
        eq(env.tab, "sources", key .. ": tab")
        local found = false
        for _, d in ipairs((env.sourcesList())) do
            if tostring(d.key) == want[key] then found = true end
        end
        assert(found, key .. ": the type's sources are not listed, got " .. env.sourceKeys())
    end
    print("hs538_onward_links: source tree rows ok")
end

do
    -- R37: Show what's missing, from the Nothing you can get right now state.
    local env = world()
    for _, id in ipairs({ 1, 2, 6, 13 }) do env.owned(id) end
    env.dataChanged()
    local empty = env.emptyOf("summary")
    eq(empty and empty.kind, "nothingNow", "nothing left to get now")
    env.click(env.button("summary", "Show what's missing"))
    eq(env.tab, "catalog")
    eq(idSet(env), "3,5,7,21,31,41,51,61", "the not-collected items; owned and unknown ones are in neither list")
    print("hs538_onward_links: Show what's missing ok")
end

-------------------------------------------------------------------------------
-- Sources: a decor row lands on Catalog; the landing resets filters and keeps the sort
-------------------------------------------------------------------------------

do
    local env = world()
    local order = {}
    env.go("catalog", { sort = "name" })
    order.name = env.idString()
    env.go("catalog", { sort = "best" })
    order.best = env.idString()
    assert(order.name ~= order.best, "the two sorts must differ for this test to see them")

    env.go("catalog", { sort = "name", search = "oak", filters = { canGet = true } })
    eq(env.idString(), "1", "filtered Catalog")
    env.go("sources", { type = "vendors", select = { key = 100 } })
    local frame
    for _, f in ipairs(select(2, env.wareList()).frames) do
        if f.d and f.d.itemID == 3 then frame = f end
    end
    assert(frame, "Anna's ware cell for item 3 is drawn")
    landsOnItem(env, 3, function() env.click(frame) end, "ware cell")
    eq(env.searchText("catalog"), "", "the landing cleared the search")
    eq(env.idString(), order.name, "filters reset, the sort kept (Name)")
    print("hs538_onward_links: Sources decor list ok")
end

-------------------------------------------------------------------------------
-- The item page: Show vendor and Show <source> for every source type
-------------------------------------------------------------------------------

do
    local cases = {
        { item = 2, button = "Show vendor", key = 100, wares = "1,2,3,6,8" },
        { item = 2, button = "Show achievement", key = 9002, wares = "2" },
        { item = 21, button = "Show quest", key = 7001, wares = "21" },
        { item = 31, button = "Show recipe", key = 8001, wares = "31" },
        { item = 41, button = "Show drop", key = "Boss|Keep", wares = "41" },
        { item = 51, button = "Show event", key = "Hallow's End", wares = "51" },
    }
    for _, c in ipairs(cases) do
        local env = world()
        env.go("catalog", { itemID = c.item })
        eq(env.selectedItem(), c.item)
        local btn = env.button("catalog", c.button)
        assert(btn, c.item .. ": no " .. c.button .. " button")
        if c.button == "Show vendor" then
            landsOnVendor(env, c.key, c.wares, function() env.click(btn) end, c.button)
        else
            landsOnSource(env, c.key, c.wares, function() env.click(btn) end, c.button)
        end
    end

    local env = world()
    env.go("catalog", { itemID = 61 })
    eq(env.selectedItem(), 61)
    local any = env.find("catalog", function(f) return f.kind == "Button" and f.shown and f.text:find("^Show ") end)
    eq(any, nil, "the Shop block has no Show button")

    -- An event vendor out of season has no row to show, so it gets no Show vendor button.
    env.go("catalog", { itemID = 51 })
    eq(env.button("catalog", "Show vendor"), nil, "an idle event vendor has no row")
    print("hs538_onward_links: item page links ok")
end

-------------------------------------------------------------------------------
-- Hide would hide the target: the landing pins it
-------------------------------------------------------------------------------

do
    local env = world()
    env.B.SetHideNA(true)
    for _, id in ipairs((env.catalogList())) do
        assert(id ~= 4 and id ~= 5 and id ~= 12, "Hide shows item " .. id)
    end

    -- A Catalog landing on a collected item and on an other-faction item.
    for _, id in ipairs({ 4, 5, 12 }) do
        landsOnItem(env, id, function() env.go("catalog", { itemID = id }) end, "pinned item " .. id)
        env.go("summary")
    end

    -- A Sources landing on a source whose decor is all collected, and on an other-faction vendor.
    landsOnVendor(env, 101, "4", function() env.go("sources", { type = "vendors", select = { key = 101 } }) end, "pinned vendor 101")
    landsOnVendor(env, 102, "5,6", function() env.go("sources", { type = "vendors", select = { key = 102 } }) end, "pinned vendor 102")
    landsOnSource(env, 9003, "12", function() env.go("sources", { type = "achievements", select = { key = 9003 } }) end, "pinned achievement")

    -- From a pinned vendor's decor list, the other-faction item still lands in Catalog.
    env.go("sources", { type = "vendors", select = { key = 102 } })
    local frame
    for _, f in ipairs(select(2, env.wareList()).frames) do
        if f.d and f.d.itemID == 5 then frame = f end
    end
    assert(frame, "Cora's ware cell for item 5 is drawn")
    landsOnItem(env, 5, function() env.click(frame) end, "ware cell under Hide")

    -- Without a select the pin does not apply: the hidden vendors stay out.
    env.go("summary")
    env.go("sources", { type = "vendors" })
    eq(env.sourceKeys(), "104,100", "no select, no pin")
    print("hs538_onward_links: pinned landings ok")
end

-------------------------------------------------------------------------------
-- A plain tab switch keeps state
-------------------------------------------------------------------------------

do
    local env = world()
    env.go("catalog", { search = "o", sort = "name", filters = { notCollected = true } })
    local ids, shown = env.idString(), env.selectedItem()
    assert(ids ~= "", "the filtered Catalog has rows")
    env.go("summary")
    env.go("sources")
    env.go("catalog")
    eq(env.idString(), ids, "Catalog keeps its filters, search and sort")
    eq(env.searchText("catalog"), "o", "and its search box")
    eq(env.selectedItem(), shown, "and its selection")

    env.go("sources", { type = "achievements" })
    local keys = env.sourceKeys()
    env.go("catalog")
    env.go("sources")
    eq(env.sourceKeys(), keys, "Sources keeps its type")
    print("hs538_onward_links: plain switch keeps state ok")
end

-------------------------------------------------------------------------------
-- The source page through the real router: Back restores its scroll, a source that is gone falls back to its
-- list, and a forward visit starts at the top
-------------------------------------------------------------------------------

do
    local env = world()
    local function onSource(id)
        local last = env.crumb[#env.crumb]
        return last.kind == "source" and last.id == id
    end
    env.go("sources", { type = "achievements", select = { key = 9002 } })
    assert(onSource(9002), "a source pick opens the source's page")
    local _, box = env.decorList()
    local scrolled = {}
    box.GetDerivedScrollOffset = function() return 88 end
    box.ScrollToOffset = function(_, offset) scrolled[#scrolled + 1] = offset end
    env.go("summary")
    eq(#scrolled, 0, "leaving the page scrolls nothing")
    env.B.Back()
    assert(onSource(9002), "Back returns to the source's page")
    eq(env.decorIds(), "2", "and lists its decor")
    eq(scrolled[1], 88, "Back restores the page's scroll")
    env.go("summary")
    env.go("sources", { type = "achievements", select = { key = 9002 } })
    eq(#scrolled, 1, "a forward visit starts at the top")

    -- A source the data does not have falls back to its type's list, on a forward Go.
    env.B.Go({ kind = "source", key = "quests", id = 99999 })
    local last = env.crumb[#env.crumb]
    eq(last.kind .. ":" .. tostring(last.key), "sources:quests", "a missing source lands on its list")
    eq(env.sourceKeys(), "7001,7002", "and the list is drawn")

    -- A source that goes while the player is elsewhere is dropped from Back; one that goes while its page is
    -- open replaces the route, with no history step.
    local page
    for _, p in ipairs(env.pageList) do
        if env.pageKinds[p] == "source" then page = p end
    end
    env.go("sources", { type = "quests", select = { key = 7001 } })
    env.go("summary")
    env.go("sources", { type = "quests", select = { key = 7002 } })
    local has = page.Has
    page.Has = function(self, route) return route.id ~= 7002 and has(self, route) end
    env.dataChanged()
    last = env.crumb[#env.crumb]
    eq(last.kind .. ":" .. tostring(last.key), "sources:quests", "a page whose source went falls back to the list")
    env.B.Back()
    eq(env.crumb[#env.crumb].kind, "overview", "the fallback took no history step: Back returns to the page before the dead one")
    env.B.Back()
    assert(onSource(7001), "and the entry before that is still the first source's page")
    page.Has = function() return false end
    env.go("summary")
    env.B.Back()
    assert(env.crumb[#env.crumb].kind ~= "source", "Back drops a source page whose source is gone")
    page.Has = has
    print("hs538_onward_links: source page restore and fallback ok")
end
