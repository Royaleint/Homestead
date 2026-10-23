-- luacheck: globals assert loadfile print
-- Run from the repo root:  lua tests/hs538_hide.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")
local newWorld = assert(loadfile(root .. "/tests/hs538_world.lua"))()

-------------------------------------------------------------------------------
-- "Hide what doesn't apply to me" across the three tabs, through the real router:
-- a toggle repaints the open tab and never walks (only a data refresh does),
-- collected and other-faction items and sources hide, unknown ownership never
-- hides as collected, the footers count exactly what was hidden, the all-hidden
-- states offer a way back, and a Neutral character is never told it is shut out
-- of a faction it is not.
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

local function setHide(env, on)
    env.handlers.HideNA(on)
end

local function idSet(env)
    local ids = {}
    for i, id in ipairs((env.catalogList())) do ids[i] = id end
    table.sort(ids)
    return table.concat(ids, ",")
end

-- The drawn footer text of a list box, if the box draws one.
local function footerText(box)
    for _, f in ipairs(box.frames) do
        if rawget(f, "link") then return f.text.text, f end
    end
end

local function hiddenLine(hidden, collected, faction, name)
    return ("%d hidden by 'Hide what doesn't apply to me' (%d collected, %d %s only)."):format(hidden, collected, faction, name)
end

-- Summary's drawn numbers and rows, for "counts unchanged".
local function summaryFace(env)
    local out = {}
    for _, f in ipairs(env.all) do
        if env.owner(f) == "summary" and rawget(f, "key") and rawget(f, "num") then out[#out + 1] = f.key .. "=" .. f.num.text end
    end
    for _, f in ipairs(env.all) do
        if env.owner(f) == "summary" and rawget(f, "why") and rawget(f, "src") and f.shown then out[#out + 1] = tostring(f.itemID) end
    end
    return table.concat(out, ";")
end

-- The drawn "N of M collected" at the head of a page's list.
local function head(env, key)
    for _, f in ipairs(env.fontStrings) do
        if env.owner(f) == key and tostring(f.text):find("^%d+ of %d+ collected$") then return f.text end
    end
end

-- Every source type's head, and back to the vendors list.
local function sourceHeads(env)
    local out = {}
    for _, t in ipairs({ "vendors", "achievements", "quests", "professions", "drops", "events", "shop" }) do
        env.go("sources", { type = t })
        out[#out + 1] = tostring(head(env, "sources"))
    end
    env.go("sources", { type = "vendors" })
    return table.concat(out, ";")
end

local function rowRights(env)
    local out = {}
    for _, d in ipairs((env.sourcesList())) do out[#out + 1] = tostring(d.key) .. "=" .. tostring(d.right) end
    return table.concat(out, ";")
end

-------------------------------------------------------------------------------
-- A toggle repaints without a walk; only a data refresh walks
-------------------------------------------------------------------------------

do
    local env = world()
    for _, key in ipairs({ "summary", "catalog", "sources" }) do
        env.go(key)
        local calls, walks = env.walkCalls, env.walks()
        setHide(env, true)
        eq(env.walkCalls, calls, key .. ": hide on asked for a walk")
        eq(env.walks(), walks, key .. ": hide on walked")
        setHide(env, false)
        eq(env.walkCalls, calls, key .. ": hide off asked for a walk")
        eq(env.walks(), walks, key .. ": hide off walked")
    end
    -- Switching tabs afterwards reuses the walk too.
    local walks = env.walks()
    setHide(env, true)
    for _, key in ipairs({ "catalog", "sources", "summary", "catalog" }) do env.go(key) end
    eq(env.walks(), walks, "tabs opened under Hide reuse the walk")
    eq(env.HA.Addon.db.profile.browser.hideNA, true, "the toggle is saved")

    -- A data refresh is the one thing that walks, once, whichever tab is open.
    for _, key in ipairs({ "summary", "catalog", "sources" }) do
        env.go(key)
        walks = env.walks()
        env.dataChanged()
        eq(env.walks(), walks + 1, key .. ": a data refresh walks once")
    end
    print("hs538_hide: toggling never walks ok")
end

-------------------------------------------------------------------------------
-- A source head is the walk's By source count; a ware that is not decor is outside it
-------------------------------------------------------------------------------

do
    local env = world(nil, function(e) e.sell(99, e.vendors[100]) end)
    local p = env.CG.Walk().progress.src.vendors
    env.go("sources", { type = "vendors" })
    eq(head(env, "sources"), ("%d of %d collected"):format(p.owned, p.total), "the Vendors head is the By source count")
    print("hs538_hide: source heads match the By source count ok")
end

-------------------------------------------------------------------------------
-- What hides, and what the footers say
-------------------------------------------------------------------------------

do
    local env = world()
    local all = "1,2,3,4,5,6,7,8,12,13,21,22,31,41,51,61"
    env.go("catalog")
    eq(idSet(env), all, "Catalog without Hide")
    local counts = head(env, "catalog")
    eq(counts, "2 of 16 collected", "the Catalog head")
    local face = summaryFace(env)
    setHide(env, true)
    env.go("catalog")
    eq(idSet(env), "1,2,3,6,7,8,13,21,22,31,41,51,61", "collected (4, 12) and other-faction-only (5) hide; unknown (8, 22) stays")
    local ids, footer, box = env.catalogList()
    eq(#ids, 13)
    eq(footer.hidden, 3, "footer: hidden")
    eq(footer.collected, 2, "footer: collected")
    eq(footer.faction, 1, "footer: other faction")
    eq(footerText(box), hiddenLine(3, 2, 1, "Horde"), "the drawn footer")
    eq(head(env, "catalog"), counts, "the Catalog head is unchanged by Hide")
    eq(env.CG.Entry(8).own, nil, "item 8's ownership is unknown")
    eq(env.CG.HiddenBy(8), nil, "unknown ownership is not hidden as collected")
    eq(env.CG.HiddenBy(6), nil, "an item one accessible vendor sells is not other-faction only")

    env.go("summary")
    eq(summaryFace(env), face, "Summary's rows and counts are unchanged")

    -- Sources: a vendor hides when it is other-faction or every ware is collected.
    env.go("sources", { type = "vendors" })
    local rights = rowRights(env)
    eq(env.sourceKeys(), "104,100", "vendors: Bran (all collected) and Cora (Horde) hide")
    local _, sfooter, sbox = env.sourcesList()
    eq(sfooter.hidden, 2)
    eq(sfooter.collected, 1)
    eq(sfooter.faction, 1)
    eq(footerText(sbox), hiddenLine(2, 1, 1, "Horde"), "the drawn vendor footer")
    local on = sourceHeads(env)
    setHide(env, false)
    eq(sourceHeads(env), on, "the source heads are unchanged by Hide")
    eq(on, "1 of 8 collected;1 of 3 collected;0 of 2 collected;0 of 1 collected;0 of 1 collected;0 of 1 collected;0 of 1 collected", "the source heads")
    eq(env.sourceKeys(), "101,102,104,100", "off brings them back")
    local offRights = rowRights(env)
    setHide(env, true)
    for key, text in offRights:gmatch("(%d+)=([^;]*)") do
        if key == "100" or key == "104" then
            assert(rights:find(key .. "=" .. text, 1, true), "a visible vendor's counts changed: " .. key)
        end
    end

    env.go("sources", { type = "achievements" })
    eq(env.sourceKeys(), "9002,9001", "achievements: Crate Feat (all collected) hides")
    local _, afooter = env.sourcesList()
    eq(afooter.hidden, 1)
    eq(afooter.collected, 1)
    eq(afooter.faction, 0)

    env.go("sources", { type = "quests" })
    eq(env.sourceKeys(), "7001,7002", "quests: the unknown-ownership quest does not hide")
    local _, qfooter = env.sourcesList()
    eq(qfooter, nil, "and nothing is counted as hidden")

    for _, t in ipairs({ "professions", "drops", "events", "shop" }) do
        env.go("sources", { type = t })
        local _, f = env.sourcesList()
        eq(f and f.hidden, nil, t .. ": nothing to hide")
    end
    env.go("sources", { type = "events" })
    eq(env.sourceKeys(), "Hallow's End", "events: the idle event stays")

    -- Show them turns Hide off from either footer.
    env.go("sources", { type = "vendors" })
    local _, link = footerText(env.boxes("sources")[1])
    env.click(link.link)
    eq(env.B.State.hideNA, false, "Sources: Show them turns Hide off")
    eq(env.Win and env.Win.hideNA or env.B.Window.hideNA.checked, false, "and unchecks the box")
    eq(env.sourceKeys(), "101,102,104,100")
    setHide(env, true)
    env.go("catalog")
    local _, catLink = footerText(env.boxes("catalog")[1])
    env.click(catLink.link)
    eq(env.B.State.hideNA, false, "Catalog: Show them turns Hide off")
    eq(idSet(env), all)
    print("hs538_hide: hidden sets and footers ok")
end

-------------------------------------------------------------------------------
-- Before the read, nothing is known to be collected, so nothing hides as collected
-------------------------------------------------------------------------------

do
    for _, phase in ipairs({ { done = false, attempted = false }, { done = false, attempted = true } }) do
        local env = world(phase)
        setHide(env, true)
        env.go("catalog", { sort = "name" })
        local ids = "," .. idSet(env) .. ","
        assert(ids:find(",4,", 1, true) and ids:find(",12,", 1, true), "owned items hide while ownership is unread: " .. ids)
        assert(not ids:find(",5,", 1, true), "an other-faction item still hides: " .. ids)
        local _, footer = env.catalogList()
        eq(footer.collected, 0, "nothing counted as collected")
        eq(footer.faction, 1)
        env.go("sources", { type = "vendors" })
        eq(env.sourceKeys(), "101,104,100", "vendors: Bran stays, Cora hides")
    end
    print("hs538_hide: unread ownership never hides as collected ok")
end

-------------------------------------------------------------------------------
-- Everything hidden: the state offers a way to turn Hide off
-------------------------------------------------------------------------------

do
    local env = world()
    for id in pairs(env.catalog) do
        if id ~= 5 then env.owned(id) end
    end
    env.catalog[8], env.catalog[22] = { totalNumStored = 1 }, { totalNumStored = 1 }
    env.dataChanged()
    setHide(env, true)

    env.go("catalog")
    local ids, footer, box = env.catalogList()
    eq(#ids, 0, "Catalog: every item hides")
    assert(footer and footer.onShow, "the footer still offers Show them")
    eq(footer.hidden, 16)
    eq(footer.faction, 1)
    local _, link = footerText(box)
    env.click(link.link)
    eq(env.B.State.hideNA, false, "Show them turns Hide off")
    eq(#(env.catalogList()), 16, "and the items come back")
    setHide(env, true)

    env.go("sources", { type = "vendors" })
    eq(env.sourceKeys(), "", "Sources: every vendor hides")
    local empty = env.emptyOf("sources")
    eq(empty and empty.kind, "noResults")
    assert(empty.d.text:find("hidden by 'Hide what doesn't apply to me'", 1, true), "the state says why: " .. tostring(empty.d.text))
    assert(empty.d.text:find("(3 collected, 1 Horde only)", 1, true), "and counts what: " .. tostring(empty.d.text))
    local button = empty.frame.buttons[1]
    assert(button and button.shown and button.scripts.OnClick, "the state offers a button")
    env.click(button)
    eq(env.B.State.hideNA, false, "the button turns Hide off")
    eq(env.sourceKeys(), "101,102,104,100", "and the vendors come back")

    -- An expansion's list says the same when Hide takes every vendor out of it.
    setHide(env, true)
    env.B.Go({ kind = "vendors", key = "other" })
    eq(env.sourceKeys(), "", "an expansion list: every vendor hides")
    empty = env.emptyOf("sources")
    eq(empty and empty.kind, "noResults")
    assert(empty.d.text:find("(3 collected, 1 Horde only)", 1, true), "and counts what: " .. tostring(empty.d.text))
    env.click(empty.frame.buttons[1])
    eq(env.B.State.hideNA, false, "its button turns Hide off")
    eq(env.sourceKeys(), "101,102,104,100", "and the vendors come back")
    print("hs538_hide: all-hidden states ok")
end

-------------------------------------------------------------------------------
-- A source list takes nothing from a select seed: under Hide the collected source stays hidden and no row is lit
-------------------------------------------------------------------------------

do
    local env = world()
    setHide(env, true)
    env.go("sources", { type = "achievements" })
    eq(env.sourceKeys(), "9002,9001", "achievements: Crate Feat hides")
    local function unlit(label)
        for _, d in ipairs((env.sourcesList())) do eq(d.selected, nil, label .. ": row " .. tostring(d.key) .. " is lit") end
    end
    env.B.Go({ kind = "sources", key = "achievements", seed = { select = { key = 9003 } } })
    eq(env.sourceKeys(), "9002,9001", "a select seed on the open list exempts nothing from Hide")
    unlit("same list")
    env.go("sources", { type = "quests" })
    env.B.Go({ kind = "sources", key = "achievements", seed = { select = { key = 9003 } } })
    eq(env.sourceKeys(), "9002,9001", "nor does one that switches the list")
    unlit("switched list")
    env.B.Back()
    env.B.Back()
    eq(env.sourceKeys(), "9002,9001", "and Back to the list shows it the same way")
    print("hs538_hide: a list ignores a select seed ok")
end

-------------------------------------------------------------------------------
-- Neutral: an unaffiliated Pandaren is never told what it can't buy is sold to a faction it isn't
-------------------------------------------------------------------------------

do
    local failures = {}
    local function check(ok, msg)
        if not ok then failures[#failures + 1] = msg end
    end

    -- Cora has no faction here, so the only faction-gated item is Dale's, an Alliance vendor's.
    local function neutral(setup)
        return world({ faction = "Neutral", dale = true }, function(env)
            env.vendors[102].faction = nil
            if setup then setup(env) end
        end)
    end

    do
        local env = neutral()
        local row = env.CG.Entry(6)
        check(row and row.factionOnly == false, "an item an unaffiliated vendor also sells reads other-faction only")
        check(env.B.ItemState(6) ~= "faction", "ItemState says item 6 is faction-only")
        setHide(env, true)
        env.go("catalog")
        local _, footer, box = env.catalogList()
        local text = footer and footerText(box) or ""
        check(footer and footer.faction == 1, "Dale's item should be the one faction-hidden item")
        check(not text:find("Horde", 1, true), "the Catalog footer names the Horde for an Alliance vendor's item: " .. text)
        env.go("sources", { type = "vendors" })
        local _, _, sbox = env.sourcesList()
        text = footerText(sbox) or ""
        check(not text:find("Horde", 1, true), "the Sources footer names the Horde for an Alliance vendor: " .. text)
    end

    do
        local env = neutral(function(e)
            for id in pairs(e.catalog) do
                if id ~= 3 then e.owned(id) end
            end
            e.catalog[8], e.catalog[22] = { totalNumStored = 1 }, { totalNumStored = 1 }
        end)
        local empty = env.emptyOf("summary")
        check(empty and empty.kind == "nothingNow", "Summary should read nothing you can get right now")
        local text = empty and empty.frame.text.text or ""
        check(not text:find("Alliance", 1, true) and not text:find("Horde", 1, true),
            "Summary tells a Neutral character the rest is sold only to a faction: " .. text)
    end

    if #failures > 0 then error("Neutral: " .. table.concat(failures, "\n  ")) end
    print("hs538_hide: Neutral ok")
end

-------------------------------------------------------------------------------
-- Neutral, both factions: each hidden faction is its own footer part, and Summary names both
-------------------------------------------------------------------------------

do
    -- Cora keeps her Horde flag, so item 5 is Horde-only and Dale's item 9 Alliance-only.
    local function neutral(keep)
        return world({ faction = "Neutral", dale = true }, function(env)
            for id in pairs(env.catalog) do
                if not keep[id] then env.owned(id) end
            end
        end)
    end

    local env = neutral({ [5] = true, [9] = true })
    setHide(env, true)
    env.go("catalog")
    local _, _, box = env.catalogList()
    local text = footerText(box) or ""
    assert(text:find(" collected, 1 Alliance only, 1 Horde only).", 1, true), "Catalog footer, both factions: " .. text)
    env.go("sources", { type = "vendors" })
    local _, _, sbox = env.sourcesList()
    text = footerText(sbox) or ""
    assert(text:find("1 Alliance only, 1 Horde only", 1, true), "Sources footer, both factions: " .. text)
    setHide(env, false)
    local empty = env.emptyOf("summary")
    eq(empty and empty.frame.text.text,
        "Everything you're missing needs a reputation, achievement or quest first, is sold only during an event, or is sold only to the Alliance or the Horde.",
        "Summary, both factions")

    env = neutral({ [9] = true })
    empty = env.emptyOf("summary")
    assert(empty and empty.frame.text.text:find("sold only to the Alliance.", 1, true), "Summary, one faction")

    env = neutral({ [9] = true })
    env.vendors[103].faction = nil
    for id in pairs(env.catalog) do env.owned(id) end
    env.B.CanGet.ResetFactionOnly()
    setHide(env, true)
    env.go("catalog")
    _, _, box = env.catalogList()
    text = footerText(box) or ""
    assert(text:find("collected).", 1, true) and not text:find("only", 1, true), "collected only names no faction: " .. text)
    print("hs538_hide: Neutral, both factions ok")
end
