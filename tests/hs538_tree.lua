-- luacheck: globals assert loadfile print rawset rawget
-- Run from the repo root:  lua tests/hs538_tree.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")
local newWorld = assert(loadfile(root .. "/tests/hs538_world.lua"))()

-------------------------------------------------------------------------------
-- The navigation tree, the crumb, Back and the header, through the real window
-- and router: the rows, a group label that opens its page while its +/- only
-- folds, the row a crumb lights, the vendor home that decides a vendor's crumb
-- whatever path led to it, the expansion names, the header count, and where the
-- tree and crumb bar sit.
-------------------------------------------------------------------------------

local function eq(a, b, msg)
    if a ~= b then error((msg or "mismatch") .. ": got " .. tostring(a) .. ", wanted " .. tostring(b), 2) end
end

local function world()
    local env = newWorld(root, { realWindow = true })
    env.HA.Addon.db.profile.browser = {}
    local v = env.standard()
    v.anna.expansion = "Midnight"
    v.bran.expansion = "Classic"
    v.cora.expansion = "Events"
    v.eve.expansion = "Not An Expansion"
    env.open()
    env.B.Data.InvalidateMemos()
    return env, v
end

local function treeBox(env)
    for _, box in ipairs(env.boxList) do
        if box.provider[1] and box.provider[1].route then return box end
    end
    error("no tree")
end

local function keys(env)
    local out = {}
    for i, d in ipairs(treeBox(env).provider) do out[i] = d.key end
    return table.concat(out, ",")
end

local function row(env, key)
    for _, f in ipairs(treeBox(env).frames) do
        if f.data and f.data.key == key then return f end
    end
end

local function selectedKey(env)
    local picked
    for _, f in ipairs(treeBox(env).frames) do
        if f.sel.shown then
            assert(not picked, "more than one row is selected")
            picked = f.data.key
        end
    end
    return picked
end

local function pageShows(env)
    local n = 0
    for _, op in ipairs(env.measured) do if op == "browser_page_show" then n = n + 1 end end
    return n
end

local function crumbText(Win)
    local out = {}
    for _, c in ipairs(Win.crumbs) do
        if c.btn.shown then out[#out + 1] = c.text.text end
    end
    return table.concat(out, ">")
end

-- The rows, collapsed to start; the page's group opens when the page shows.
do
    local env = world()
    eq(keys(env), "overview,catalog,vendors,achievements,quests,professions,drops,events,shop", "the rows")
    eq(selectedKey(env), "overview", "the first open lights Overview")
    eq(row(env, "catalog").data.label, "Catalog")
    eq(row(env, "shop").data.label, "Shop")
    assert(not row(env, "overview").fold.shown and row(env, "catalog").fold.shown, "only groups have a fold")
    eq(row(env, "catalog").fold.atlas, "common-icon-plus", "a closed group shows plus")
    print("hs538_tree: rows ok")
end

-- A group label opens its page and its group; the +/- only folds.
do
    local env = world()
    local shows = pageShows(env)
    env.click(row(env, "catalog"))
    eq(env.tab, "catalog", "the Catalog label opens the Catalog")
    eq(pageShows(env), shows + 1, "one page show")
    eq(keys(env), "overview,catalog,catalog:all,catalog:1,catalog:2,catalog:3,catalog:4,catalog:other,vendors,"
        .. "achievements,quests,professions,drops,events,shop", "the page's group is open")
    eq(selectedKey(env), "catalog:all", "the All decor child is lit")
    eq(row(env, "catalog").fold.atlas, "common-icon-minus", "an open group shows minus")

    -- Folding changes the rows and nothing else.
    local page = env.tab
    env.click(row(env, "catalog").fold)
    eq(pageShows(env), shows + 1, "folding shows no page")
    eq(env.tab, page, "folding leaves the page")
    eq(keys(env), "overview,catalog,vendors,achievements,quests,professions,drops,events,shop", "folded")
    eq(selectedKey(env), "catalog", "a folded group lights itself")
    env.click(row(env, "catalog"))
    assert(row(env, "catalog:all"), "the label reopens the group")
    eq(selectedKey(env), "catalog:all", "and lights the child again")
    env.click(row(env, "catalog").fold)
    env.click(row(env, "vendors").fold)
    eq(pageShows(env), shows + 2, "unfolding shows no page")
    assert(keys(env):find("vendors:Midnight", 1, true), "unfolded Vendors lists its expansions")
    eq(env.tab, "catalog", "unfolding leaves the page")
    eq(row(env, "vendors").fold.atlas, "common-icon-minus")

    -- The Vendors label opens the vendors list until the vendor pages exist.
    env.click(row(env, "vendors"))
    eq(env.tab, "sources", "the Vendors label opens the vendors list")
    eq(pageShows(env), shows + 3)
    eq(selectedKey(env), "vendors", "the Vendors row is lit")
    -- Until the expansion lists exist, an expansion row opens the same list and the Vendors row stays lit.
    env.click(row(env, "vendors:Midnight"))
    eq(env.tab, "sources", "an expansion row opens the vendors list")
    eq(selectedKey(env), "vendors")
    env.click(row(env, "vendors:other"))
    eq(env.tab, "sources", "Other Vendors opens the vendors list")
    env.click(row(env, "quests"))
    eq(env.tab, "sources")
    eq(selectedKey(env), "quests")
    eq(env.B.Window.crumbs[1].text.text, "Quests", "the crumb names the page")
    print("hs538_tree: group labels and folds ok")
end

-- Expansion rows: ordered, only the ones with a listed vendor, unknown ones under Other Vendors.
do
    local env, v = world()
    local D = env.D
    eq(table.concat(D.Expansions(), ","), "Midnight,Classic,other")
    eq(D.VendorHome(v.anna), "Midnight")
    eq(D.VendorHome(v.cora), "other", "Events is not an expansion")
    eq(D.VendorHome(v.eve), "other", "an unknown name is not an expansion")
    eq(D.VendorHome({}), "other", "no expansion")
    env.click(row(env, "vendors").fold)
    eq(row(env, "vendors:other").data.label, "Other Vendors")
    eq(row(env, "vendors:Midnight").data.child, true)
    -- Vendor tables only; no wares.
    for _, vendor in ipairs(D.ListedVendors()) do assert(vendor.npcID, "a vendor table") end
    eq(D.ListedVendors(), D.ListedVendors(), "memoised")
    local before = D.ListedVendors()
    env.vendor(200, { name = "Newcomer", expansion = "Cataclysm" })
    eq(D.ListedVendors(), before, "no rebuild without an invalidation")
    D.InvalidateMemos()
    assert(D.ListedVendors() ~= before, "rebuilt after InvalidateMemos")
    eq(table.concat(D.Expansions(), ","), "Midnight,Cataclysm,Classic,other", "and the new vendor's expansion appears")
    print("hs538_tree: expansions ok")
end

-- The expansion name comes from the client's globals, resolved when asked; without them the data name stands.
do
    local env = world()
    local D = env.D
    eq(D.ExpansionLabel("Midnight"), "Midnight", "no EXPANSION_NAME: the data name")
    rawset(_G, "LE_EXPANSION_MIDNIGHT", 11)
    rawset(_G, "EXPANSION_NAME11", "Midnight (client)")
    eq(D.ExpansionLabel("Midnight"), "Midnight (client)", "EXPANSION_NAME present")
    rawset(_G, "EXPANSION_NAME11", nil)
    eq(D.ExpansionLabel("Midnight"), "Midnight", "EXPANSION_NAME nil again")
    rawset(_G, "LE_EXPANSION_MIDNIGHT", nil)
    eq(D.ExpansionLabel("other"), "Other Vendors")
    eq(D.ExpansionLabel("Not An Expansion"), "Not An Expansion")
    print("hs538_tree: expansion names ok")
end

-- SelectNav lights the deepest crumb segment that has a row, else its group row.
do
    local env, v = world()
    local Win, B = env.B.Window, env.B
    Win.SelectNav({ kind = "vendor", id = v.anna.npcID })
    eq(selectedKey(env), "vendors:Midnight", "a vendor lights its expansion, not the whole Vendors group")
    assert(row(env, "vendors").fold.atlas == "common-icon-minus", "and opens the group")
    Win.SelectNav({ kind = "vendor", id = v.cora.npcID })
    eq(selectedKey(env), "vendors:other")
    Win.SelectNav({ kind = "vendors", key = "Wrath of the Lich King" })
    eq(selectedKey(env), "vendors", "an expansion with no row falls back to its group row")
    Win.SelectNav({ kind = "item", id = 1 })
    eq(selectedKey(env), "catalog:all", "an item lights All decor")
    Win.SelectNav({ kind = "catalog", key = 9 })
    eq(selectedKey(env), "catalog", "a kind with no row falls back to the Catalog row")
    Win.SelectNav({ kind = "source", key = "drops", id = "x" })
    eq(selectedKey(env), "drops", "a source lights its type")
    Win.SelectNav({ kind = "overview" })
    eq(selectedKey(env), "overview")
    eq(#B.Home({ kind = "vendor", id = v.anna.npcID }), 3, "Vendors > expansion > vendor")
    print("hs538_tree: SelectNav ok")
end

-- The falsifier: every listed vendor has one home, and its crumb is that home whatever led to it.
do
    local env = world()
    local Win, D, B = env.B.Window, env.D, env.B
    local listed = D.ListedVendors()
    assert(#listed >= 4, "the world lists its vendors")
    local expansions = {}
    for _, e in ipairs(D.Expansions()) do expansions[e] = true end
    local other = { kind = "sources", key = "quests" }
    for _, vendor in ipairs(listed) do
        local home = D.VendorHome(vendor)
        assert(expansions[home], "the home of " .. vendor.name .. " is a row")
        local want = table.concat({ "Vendors", D.ExpansionLabel(home), vendor.name }, ">")
        -- Reached from nowhere, from another page's crumb, and after a trip through the catalog.
        for _, before in ipairs({ false, other, { kind = "item", id = 1 } }) do
            if before then Win.SetCrumb(B.Home(before)) end
            Win.SetCrumb(B.Home({ kind = "vendor", id = vendor.npcID }))
            eq(crumbText(Win), want, vendor.name .. ": the crumb is its home")
        end
        Win.SelectNav({ kind = "vendor", id = vendor.npcID })
        eq(selectedKey(env), "vendors:" .. home, vendor.name .. ": the tree follows the crumb")
    end
    print("hs538_tree: vendor homes ok")
end

-- The crumb: earlier segments link, the last is plain, and it is the home rather than the path walked.
do
    local env = world()
    local Win, B = env.B.Window, env.B
    -- Pages for these kinds come later; the crumb is set from the route alone.
    Win.SetCrumb(B.Home({ kind = "item", id = 2 }))
    eq(crumbText(Win), "Catalog>Elm Chair", "an item's home is the Catalog")
    assert(Win.crumbs[1].route and not Win.crumbs[2].route, "the earlier segment links and the last does not")
    B.Go({ kind = "sources", key = "drops" })
    Win.SetCrumb(B.Home({ kind = "source", key = "quests", id = 7001 }))
    eq(crumbText(Win), "Quests>7001", "a source sits under its type, not under the page before it")
    Win.crumbs[1].btn.scripts.OnClick()
    eq(env.tab, "sources", "a link opens that page")
    eq(crumbText(Win), "Quests")
    B.Go({ kind = "catalog", key = "all" })
    eq(crumbText(Win), "All decor")
    B.Go({ kind = "catalog", key = 2 })
    eq(crumbText(Win), "Catalog>Structural")
    B.Go({ kind = "overview" })
    eq(crumbText(Win), "Overview")
    print("hs538_tree: crumb ok")
end

-- Back shows with history and returns one page; an open starts clean.
do
    local env = world()
    local Win, B = env.B.Window, env.B
    assert(not Win.back.shown, "no Back on the first page")
    env.click(row(env, "catalog"))
    assert(Win.back.shown, "Back shows once there is a page to return to")
    eq(env.tab, "catalog")
    env.click(Win.back)
    eq(env.tab, "summary", "Back returns to the page before")
    assert(not Win.back.shown, "and hides when the history is empty")
    eq(selectedKey(env), "overview", "the tree follows Back")
    env.click(row(env, "quests"))
    env.click(row(env, "drops"))
    env.click(Win.back)
    eq(selectedKey(env), "quests")
    B.Go({ kind = "catalog", key = "all" })
    assert(Win.back.shown)
    print("hs538_tree: Back ok")
end

-- The header: the overall count, "Counting…" until the collection is ready.
do
    local env = newWorld(root, { realWindow = true, done = false, attempted = false })
    env.standard()
    env.open()
    local Win = env.B.Window
    eq(Win.count.text, "Counting…", "before the collection is read")
    local env2 = world()
    local walk = env2.CG.Walk()
    eq(env2.B.Window.count.text, ("%d of %d decor collected"):format(walk.progress.owned, walk.progress.total))
    assert(walk.progress.total > 0, "the world has decor")
    env2.owned(1)
    env2.dataChanged()
    eq(env2.B.Window.count.text, ("%d of %d decor collected"):format(walk.progress.owned + 1, walk.progress.total),
        "a refresh updates the count")
    print("hs538_tree: header count ok")
end

-- The tree and the crumb bar are children of the page frame, never of the host.
do
    local env = world()
    local Win = env.B.Window
    eq(#env.pages, env.pageCount, "the host holds only the page frames")
    for _, f in ipairs(env.pages) do
        assert(f ~= Win.bar and f ~= treeBox(env).parent, "the tree or the crumb bar is a child of the host")
    end
    assert(Win.bar.parent ~= Win.host and treeBox(env).parent.parent == Win.bar.parent, "tree and bar share a parent")
    eq(Win.host.pts.TOPLEFT[2], Win.bar, "the host sits below the crumb bar")
    eq(Win.bar.pts.TOPLEFT[2], treeBox(env).parent, "the bar sits right of the tree")
    eq(treeBox(env).parent.width, 172, "the tree is 172 wide")
    print("hs538_tree: placement ok")
end

print("hs538_tree: ok")
