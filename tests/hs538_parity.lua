-- luacheck: globals assert loadfile print
-- Run from the repo root:  lua tests/hs538_parity.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")
local newWorld = assert(loadfile(root .. "/tests/hs538_world.lua"))()

-------------------------------------------------------------------------------
-- The tabs agree. Summary's progress numbers equal the Catalog's filtered counts
-- for the same filters, and one item reads the same state on a Catalog row, on a
-- Sources decor row, on the item page and from B.ItemState, in every phase of
-- the collection read.
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

local SOURCE_KEYS = { "vendors", "achievements", "quests", "professions", "drops", "events", "shop" }

-- The "N of M" Summary draws on each By source line.
local function summaryCounts(env)
    local out = {}
    for _, f in ipairs(env.all) do
        if env.owner(f) == "summary" and rawget(f, "key") and rawget(f, "num") then
            local owned, total = tostring(f.num.text):match("^(%d+) of (%d+)$")
            out[f.key] = owned and { owned = tonumber(owned), total = tonumber(total) } or f.num.text
        end
    end
    return out
end

-- How many items the Catalog lists for a filter set.
local function catalogCount(env, filters)
    env.go("catalog", { filters = filters })
    return #(env.catalogList())
end

local function checkCounts(env, label)
    env.go("summary")
    local summary = summaryCounts(env)
    local walk = env.B.Walk()
    for _, key in ipairs(SOURCE_KEYS) do
        local s = summary[key]
        assert(type(s) == "table", label .. ": Summary draws no count for " .. key .. ": " .. tostring(s))
        eq(catalogCount(env, { sources = { [key] = true } }), s.total, label .. ": " .. key .. " total")
        eq(catalogCount(env, { sources = { [key] = true }, collected = true }), s.owned, label .. ": " .. key .. " collected")
        eq(walk.progress.src[key].total, s.total, label .. ": " .. key .. " walk total")
        eq(walk.progress.src[key].owned, s.owned, label .. ": " .. key .. " walk collected")
    end
    -- Overall: every item, and the collected ones.
    eq(catalogCount(env, nil), walk.progress.total, label .. ": overall total")
    eq(catalogCount(env, { collected = true }), walk.progress.owned, label .. ": overall collected")
    local unknown = 0
    for _, id in pairs(env.HA.DecorMapping) do
        if env.catalog[id] == nil then unknown = unknown + 1 end
    end
    eq(catalogCount(env, { notCollected = true }) + catalogCount(env, { collected = true }) + unknown,
        walk.progress.total, label .. ": items of unknown ownership are in neither ownership filter")
end

do
    local env = world()
    checkCounts(env, "standard")
    -- A source with two types of item and one with an unknown item are counted in totals, not collected.
    env.go("summary")
    local s = summaryCounts(env)
    eq(s.quests.total, 2, "quests: the unknown-ownership item is in the total")
    eq(s.quests.owned, 0, "and not collected")
    eq(s.achievements.total, 3)
    eq(s.achievements.owned, 1)
    eq(s.vendors.total, 8, "vendors: items 1 2 3 4 5 6 8 13, each counted once")
    print("hs538_parity: standard counts ok")
end

do
    -- The counts move together when the collection changes.
    local env = world()
    for _, id in ipairs({ 1, 7, 21, 41 }) do env.owned(id) end
    env.dataChanged()
    checkCounts(env, "after collecting four")
    for id in pairs(env.catalog) do env.owned(id) end
    env.owned(8)
    env.owned(22)
    env.dataChanged()
    checkCounts(env, "everything collected")
    env.go("summary")
    local empty = env.emptyOf("summary")
    eq(empty and empty.kind, "nothingMissing")
    eq(empty.d.arg, catalogCount(env, nil), "Summary's total is the Catalog's All decor")
    print("hs538_parity: counts follow the collection ok")
end

-------------------------------------------------------------------------------
-- One item, one state, on every surface
-------------------------------------------------------------------------------

-- The text lines the item page draws.
local function pageLines(env)
    local out = {}
    for _, f in ipairs(env.all) do
        if env.owner(f) == "catalog" and rawget(f, "mark") and f.shown and f.text and f.text.text ~= "" then
            out[#out + 1] = f.text.text
        end
    end
    return out
end

local function words(env, state, arg)
    return state and env.W.StateWords(state, arg) or nil
end

local function holds(list, text)
    for _, t in ipairs(list) do if t == text then return true end end
    return false
end

local function describe(state, arg)
    return tostring(state) .. "/" .. tostring(arg)
end

-- Checks every surface for every decor item, and returns how many comparisons were made.
local function surfaces(env, label)
    local B, n = env.B, 0
    local decor = {}
    for _, id in pairs(env.HA.DecorMapping) do decor[#decor + 1] = id end
    table.sort(decor)

    -- Catalog rows and the item page, against B.ItemState with no vendor.
    env.go("catalog", { sort = "name" })
    for _, id in ipairs(decor) do
        local state, arg = B.ItemState(id)
        local row = env.catalogRow(id)
        assert(row, label .. ": Catalog draws no row for item " .. id)
        eq(describe(row.d.state, row.d.arg), describe(state, arg), label .. ": Catalog row, item " .. id)
        env.go("catalog", { sort = "name", itemID = id })
        local lines = pageLines(env)
        if state then
            assert(holds(lines, words(env, state, arg)), label .. ": the item page lacks '" .. words(env, state, arg)
                .. "' for item " .. id .. ", it draws: " .. table.concat(lines, " | "))
        else
            for _, text in ipairs(lines) do
                assert(text ~= "Collected" and text ~= "Not collected" and text ~= "Can get now" and text ~= "Counting…",
                    label .. ": the item page draws a state for item " .. id .. " whose state is unknown: " .. text)
            end
        end
        n = n + 2
    end

    -- Sources decor rows: a vendor's rows read that vendor's offer, any other source reads the item's.
    for _, t in ipairs(SOURCE_KEYS) do
        env.go("sources", { type = t })
        local keys = {}
        for _, d in ipairs((env.sourcesList())) do keys[#keys + 1] = d.key end
        for _, key in ipairs(keys) do
            env.go("sources", { type = t, select = { key = key } })
            local npcID = t == "vendors" and key or nil
            for _, d in ipairs((env.decorList())) do
                local state, arg = B.ItemState(d.itemID, npcID)
                eq(describe(d.state, d.arg), describe(state, arg), label .. ": Sources " .. t .. " " .. tostring(key) .. ", item " .. d.itemID)
                n = n + 1
            end
        end
    end
    return n
end

do
    local env = world()
    local n = surfaces(env, "ready")
    assert(n > 40, "the matrix is too small to mean anything: " .. n)

    -- The values themselves, so a surface and ItemState can't agree on the wrong thing.
    local B = env.B
    local function is(id, npcID, state, arg)
        local s, a = B.ItemState(id, npcID)
        eq(describe(s, a), describe(state, arg), "item " .. id .. " vendor " .. tostring(npcID))
    end
    is(1, nil, "can")
    is(3, nil, "locked", "Mysterious Favor")
    is(4, nil, "owned")
    is(5, nil, "faction", "Horde")
    is(6, nil, "can")
    is(6, 102, "faction", "Horde")
    is(7, nil, "notOwned")
    is(8, nil, nil)
    is(22, nil, nil)
    is(51, nil, "event", "Hallow's End")
    is(51, 150, "event", "Hallow's End")
    eq(env.W.StateWords("event", "Hallow's End"), "Hallow's End only", "the out-of-season event item reads '<Event> only'")
    print("hs538_parity: ready-phase states ok (" .. n .. " comparisons)")
end

do
    -- The event item in season is gettable, and every surface follows.
    local env = world(nil, function(e) e.calendar["Hallow's End"] = true end)
    local state = env.B.ItemState(51)
    eq(state, "can", "in season, the event vendor sells it")
    surfaces(env, "in season")
    print("hs538_parity: in-season event ok")
end

do
    -- Before the read, every surface says Counting; after a failed read, none says anything.
    local counting = world({ done = false, attempted = false })
    eq(surfaces(counting, "counting") > 20, true)
    eq((counting.B.ItemState(1)), "counting")
    local unread = world({ done = false, attempted = true })
    surfaces(unread, "not read")
    eq(unread.B.ItemState(1), nil, "a failed read gives no state")
    print("hs538_parity: counting and not-read phases ok")
end

do
    -- An item with several unmet requirements names them the same way on every surface.
    local env = world(nil, function(e)
        e.reqs["3:100"] = { { type = "unknown", text = "Mysterious Favor" }, { type = "unknown", text = "Old Debt" },
            { type = "unknown", text = "Third Step" } }
    end)
    surfaces(env, "several requirements")
    print("hs538_parity: several unmet requirements ok")
end

do
    -- Two locked vendors: Summary's next step, the Catalog row and the item page all name the vendor with the
    -- fewest unmet requirements, though it comes second.
    local env = world(nil, function(e)
        for _, id in ipairs({ 1, 2, 6, 13 }) do e.owned(id) end
        e.sell(3, e.vendors[101], { gold = 60 })
        e.reqs["3:100"] = { { type = "unknown", text = "Mysterious Favor" }, { type = "unknown", text = "Old Debt" } }
        e.reqs["3:101"] = { { type = "unknown", text = "Bran's Favor" } }
    end)
    local state, arg, at = env.B.ItemState(3)
    eq(describe(state, arg), "locked/Bran's Favor", "the easiest vendor")
    eq(at, 101)
    env.go("summary")
    local next
    for _, f in ipairs(env.all) do
        if env.owner(f) == "summary" and rawget(f, "why") and f.shown and f.itemID == 3 then next = f end
    end
    assert(next, "Summary draws no next step for item 3")
    env.go("catalog", { sort = "name" })
    local row = env.catalogRow(3)
    eq(describe(row.d.state, row.d.arg), describe(state, arg), "Catalog row")
    eq(next.src.text, "Requires: " .. row.d.arg, "Summary's next step reads as the Catalog row")
    env.go("catalog", { sort = "name", itemID = 3 })
    assert(holds(pageLines(env), words(env, state, arg)), "the item page names the same vendor's requirement")
    print("hs538_parity: easiest locked vendor ok")
end

do
    -- An Alliance character, items sold by a Horde vendor listed first: every surface names the vendor this
    -- character can use, and says when no scan has confirmed it.
    local env = world(nil, function(e)
        for _, id in ipairs({ 1, 2, 13 }) do e.owned(id) end
        e.decor(71, "Yew Bench", { totalNumStored = 0, categoryIDs = { 1 } })
        e.sell(71, e.vendors[102], { gold = 70 })
        e.sell(71, e.vendors[101], { gold = 15 })
        e.reqs["71:101"] = { { type = "unknown", text = "Bran's Favor" } }
    end)
    local D = env.B.Data
    eq(env.B.ItemState(71), "locked", "Bran's item")
    env.go("summary")
    local next
    for _, f in ipairs(env.all) do
        if env.owner(f) == "summary" and rawget(f, "why") and f.shown and f.itemID == 6 then next = f end
    end
    assert(next, "Summary draws no row for item 6")
    env.go("catalog", { sort = "name" })
    for id, name in pairs({ [6] = "Anna", [71] = "Bran" }) do
        local tip, row = D.TooltipData(id), env.catalogRow(id)
        assert(tip.source:find("^Vendor: " .. name), "tooltip, item " .. id .. ": " .. tip.source)
        eq(row.d.line2:sub(1, #tip.source), tip.source, "Catalog row, item " .. id)
        eq(tip.unconfirmed, name == "Bran" or nil, "tooltip unconfirmed, item " .. id)
    end
    eq(next.src.text:sub(1, #D.TooltipData(6).source), D.TooltipData(6).source, "Summary names another vendor")
    print("hs538_parity: one primary source ok")
end

do
    -- A tooltip for one vendor's ware describes that vendor, never the item's primary source.
    local env = world(nil, function(e)
        e.vendors[100].scanConfirmed = nil
        e.vendors[102].scanConfirmed = "2026-10-01"
    end)
    local D = env.B.Data
    local cora, anna = D.TooltipData(6, 102), D.TooltipData(6)
    assert(anna.source:find("^Vendor: Anna") and anna.unconfirmed, "the primary source is Anna, unconfirmed")
    assert(cora.source:find("^Vendor: Cora"), "Cora's tooltip names " .. cora.source)
    eq(cora.price, D.Price(6, D.Vendor(102)), "Cora's price")
    eq(cora.unconfirmed, nil, "Cora's tooltip says Anna is not confirmed")
    print("hs538_parity: one vendor's tooltip ok")
end

do
    -- In season, the event vendor is the primary source though it is not listed: the listed source is "more".
    local env = world(nil, function(e) e.calendar["Hallow's End"] = true end)
    env.go("catalog", { sort = "name" })
    local line = env.catalogRow(51).d.line2
    assert(line:find("^Vendor: Ghoul") and line:find("(+1 more)", 1, true), "item 51 reads " .. line)
    local row, drawn = env.catalogRow(51)
    for _, fs in ipairs(env.fontStrings) do
        local p = fs.parent
        while p and p ~= row do p = p.parent end
        drawn = drawn or p and fs.text == "Active now" and fs.shown
    end
    assert(row.d.active and drawn, "the in-season row draws no Active now")
    print("hs538_parity: unlisted primary source ok")
end
