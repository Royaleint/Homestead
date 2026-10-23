-- luacheck: globals assert loadfile print
-- Run from the repo root:  lua tests/hs538_catalog_page.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")
local newWorld = assert(loadfile(root .. "/tests/hs538_world.lua"))()

-------------------------------------------------------------------------------
-- The Catalog and the item page through the real router, window, pages and data modules: the header box
-- filters the Catalog as you type, the box's hint, Back restoring the search, the filters, the sort and the
-- scroll without a new search, and the item page's Hide, Refresh, combat and crumb.
-------------------------------------------------------------------------------

local function eq(a, b, msg)
    if a ~= b then error((msg or "mismatch") .. ": got " .. tostring(a) .. ", wanted " .. tostring(b), 2) end
end

local function world()
    local env = newWorld(root, { realWindow = true })
    env.standard()
    env.open()
    return env
end

local function pageOf(env, kind)
    for _, p in ipairs(env.pageList) do
        if env.pageKinds[p] == kind then return p end
    end
end

local function dropdown(env, template)
    for _, f in ipairs(env.all) do
        if f.template == template then return f end
    end
end

-- The checkbox or radio a dropdown's menu holds.
local function entry(menu, text)
    for _, e in ipairs(menu.menuDescription.items) do
        if e.text == text then return e end
    end
    error("no menu entry " .. text)
end

-- Typing in the header box, as the client reports it.
local function type_(env, text)
    local box = env.B.Window.search
    box.text = text
    box.scripts.OnTextChanged(box, true)
end

local function idSet(env)
    local ids = {}
    for i, id in ipairs((env.catalogList())) do ids[i] = id end
    table.sort(ids)
    return table.concat(ids, ",")
end

-- The header box filters the Catalog as you type; Enter there goes nowhere; Reset clears the box.
do
    local env = world()
    local win = env.B.Window
    local page = pageOf(env, "catalog")
    local filtered = 0
    local filter = page.Filter
    function page:Filter(text)
        filtered = filtered + 1
        return filter(self, text)
    end
    env.B.Go({ kind = "catalog", key = "all" })
    local all = idSet(env)
    local walks = env.walks()
    type_(env, "oak")
    eq(idSet(env), "1,12", "typing filters the Catalog")
    eq(filtered, 1)
    eq(env.walks(), walks, "typing never walks")
    type_(env, "OAK ")
    eq(idSet(env), "1,12", "any case, trimmed")

    local routes, go = 0, env.B.Go
    env.B.Go = function(route) routes = routes + 1 return go(route) end
    win.search.scripts.OnEnterPressed(win.search)
    eq(routes, 0, "Enter on the Catalog goes nowhere")
    env.B.Go = go

    win.search:SetText("")
    eq(idSet(env), all, "the clear button brings the whole list back")

    type_(env, "zzz")
    local empty = env.emptyOf("catalog")
    eq(empty and empty.kind, "noResults", "no results")
    env.click(empty.frame.buttons[1])
    eq(win.search.text, "", "Reset filters clears the header box")
    eq(idSet(env), all, "and brings the list back")
    print("hs538_catalog_page: header box filters the Catalog ok")
end

-- The Catalog names its hint.
do
    local env = world()
    local page = pageOf(env, "catalog")
    eq(page:Placeholder({ kind = "catalog", key = "all" }), "Search decor", "the Catalog's hint")
    env.B.Go({ kind = "sources", key = "quests" })
    eq(env.B.Window.search.Instructions.text, "Search quests")
    env.B.Go({ kind = "catalog", key = 1 })
    eq(env.B.Window.search.Instructions.text, "Search decor", "the hint follows the page")
    print("hs538_catalog_page: placeholder ok")
end

-- Back to the Catalog restores the search, the filters, the sort and the scroll, and is not a new search.
do
    local env = world()
    local win = env.B.Window
    local page = pageOf(env, "catalog")
    env.B.Go({ kind = "catalog", key = 1 })
    local kindIds = idSet(env)
    dropdown(env, "WowStyle1DropdownTemplate"):TestPick("Name")
    local filters = dropdown(env, "WowStyle1FilterDropdownTemplate")
    filters:TestPick("Collected")
    filters:TestPick("Vendors")
    type_(env, "o")
    local ids = env.idString()
    assert(ids ~= "" and idSet(env) ~= kindIds, "the filters narrow the list")

    local box = env.boxes("catalog")[1]
    box.GetDerivedScrollOffset = function() return 66 end
    local offsets = {}
    box.ScrollToOffset = function(_, offset) offsets[#offsets + 1] = offset end
    local filtered = 0
    local filter = page.Filter
    function page:Filter(text)
        filtered = filtered + 1
        return filter(self, text)
    end

    env.catalogRow(tonumber(ids:match("^%d+"))).d.onClick()
    eq(env.route.kind, "item", "a row opens its item page")
    eq(win.search.text, "", "the box clears when the page changes")
    eq(#offsets, 0, "leaving the page scrolls nothing")
    env.B.Back()
    eq(env.route.kind .. ":" .. tostring(env.route.key), "catalog:1")
    eq(win.search.text, "o", "Back sets the box again")
    eq(env.idString(), ids, "and the list is as it was: kind, filters, search and sort")
    eq(dropdown(env, "WowStyle1DropdownTemplate").text, "Sort: Name", "the sort button follows it")
    eq(entry(filters, "Collected").isSel(), false, "the filter menu reads the restored view")
    eq(entry(filters, "Not collected").isSel(), true)
    eq(entry(filters, "Vendors").isSel(), false)
    eq(offsets[#offsets], 66, "Back restores the scroll the page saved")
    eq(filtered, 0, "a restore does not count as a new search")

    -- A forward visit starts clean, with the sort kept.
    env.B.Go({ kind = "overview" })
    env.B.Go({ kind = "catalog", key = 1 })
    eq(win.search.text, "", "a forward visit starts clean")
    eq(idSet(env), kindIds, "with the kind's whole list")
    eq(dropdown(env, "WowStyle1DropdownTemplate").text, "Sort: Name", "and keeps the sort")
    print("hs538_catalog_page: Back restore ok")
end

-- The item page: Hide clears it, Refresh draws it again, the id is kept, combat reaches it, the crumb names it.
do
    local env = world()
    local win = env.B.Window
    local page = pageOf(env, "item")
    local shows = env.itemShows
    env.B.Go({ kind = "item", id = 2 })
    eq(shows[#shows], 2, "the page fills the detail")
    eq(win.crumbs[#win.crumbs].text.text, "Elm Chair", "the crumb names the item")
    eq(win.crumbs[#win.crumbs - 1].text.text, "Catalog", "under Catalog")

    local n = #shows
    page:Refresh("zone")
    page:Refresh("stats")
    eq(#shows, n, "a zone or stats refresh leaves a shown page alone")
    page:Refresh("data")
    eq(#shows, n + 1, "any other refresh draws it again")
    eq(shows[#shows], 2)

    page:Hide()
    eq(shows[#shows], false, "Hide clears the detail")
    page:Refresh("stats")
    eq(shows[#shows], 2, "a refresh after Hide draws the same item again, without a Show")
    page:Refresh("zone")
    page:Hide()
    page:Refresh("zone")
    eq(shows[#shows], 2, "even a zone refresh")

    env.B.Go({ kind = "overview" })
    eq(shows[#shows], false, "leaving the page clears the detail")
    env.B.Back()
    eq(shows[#shows], 2, "Back draws the item again")

    local combat
    env.B.ItemDetail.SetCombat = function(on) combat = on end
    page:SetCombat(true)
    eq(combat, true, "combat reaches the detail through the table")

    env.B.Go({ kind = "item", id = 9999 })
    eq(win.crumbs[#win.crumbs].text.text, "Item 9999", "an item with no name reads Item N in the crumb")
    eq(shows[#shows], 9999, "and the page opens for it")
    print("hs538_catalog_page: item page ok")
end

print("hs538_catalog_page: all ok")
