-- luacheck: globals assert loadfile print io os date time wipe C_Timer

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Pure logic of the Overview and Shops pages: relative dates, vendor list
-- layout and filtering, and the count placeholder text.
-------------------------------------------------------------------------------

local function readFile(path)
    local f = assert(io.open(root .. "/" .. path, "rb"), "cannot open " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

date, time = os.date, os.time

local HA = { Constants = { TEXTURE_ROOT = "Textures/" } }
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)
for line in readFile("Homestead.toc"):gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI\\Browser\\[%w_]+%.lua)%s*$")
    if entry then assert(loadfile(root .. "/" .. entry:gsub("\\", "/")))("Homestead", HA) end
end
local B = HA.DecorBrowser

-- Relative dates count calendar days, not hours.
local overview = B.pages.overview
local now = time({ year = 2026, month = 10, day = 21, hour = 0, min = 30 })
local function at(day, hour) return time({ year = 2026, month = 10, day = day, hour = hour, min = 0 }) end
assert(overview.RelativeDate(at(21, 0), now) == "today")
assert(overview.RelativeDate(at(20, 23), now) == "yesterday", "23:00 the evening before is yesterday")
assert(overview.RelativeDate(at(19, 9), now) == "2 days ago")
assert(overview.RelativeDate(at(7, 12), now) == "14 days ago", "the 14-day edge still reads relative")
assert(overview.RelativeDate(at(6, 12), now) == date("%b %d", at(6, 12)), "past 14 days is a short date")
assert(overview.RelativeDate(at(22, 12), now) == "today", "a time ahead of now never reads as the future")

-- Shops layout: an expansion groups by zone, sorted; Near You keeps its order and has no headers.
local shops = B.pages.shops
local function v(npcID, name, zone, subzone) return { npcID = npcID, name = name, zone = zone, subzone = subzone } end
local list = { v(1, "Zed", "Zul"), v(2, "Ann", "Zul"), v(3, "Bob", "Ard"), v(4, "Nox") }
local data = shops.Layout(list, false)
local got = {}
for _, d in ipairs(data) do got[#got + 1] = d.kind == "header" and ("[" .. d.text .. "]") or d.vendor.name end
assert(table.concat(got, ",") == "[Unknown],Nox,[Ard],Bob,[Zul],Ann,Zed",
    "unexpected layout: " .. table.concat(got, ","))
assert(#shops.Layout({}, false) == 0)
local near = shops.Layout({ v(1, "Zed", "Zul"), v(3, "Bob", "Ard") }, true)
assert(#near == 2 and near[1].kind == "vendor" and near[1].vendor.name == "Zed" and near[2].vendor.name == "Bob",
    "Near You must keep the order it is given and show no zone headers")

-- Search matches name, zone and subzone, case-folded by the caller.
local q = v(1, "Ardent Trader", "Silvermoon", "Sunfury Spire")
assert(shops.Matches(q, ""))
assert(shops.Matches(q, "trader") and shops.Matches(q, "silver") and shops.Matches(q, "sunfury"))
assert(not shops.Matches(q, "dornogal"))
assert(shops.Matches({ npcID = 9 }, "") and not shops.Matches({ npcID = 9 }, "x"), "a vendor with no names never errors")

-- Counts: nil total is a placeholder (cold cache or unknown ownership), never "0 of 0".
assert(shops.CountsText(nil, nil) == "Counts not loaded yet")
assert(shops.CountsText(0, 0) == "No decor listed")
assert(shops.CountsText(3, 12) == "3 of 12 owned")
assert(shops.CountsText(0, 5) == "0 of 5 owned")

-- Collapsible groups: a collapsed header drops its rows, expanding restores them, and each page keeps its own set.
do
    local W = B.Widgets
    local function lay(zones)
        local out = {}
        for _, z in ipairs(zones) do
            out[#out + 1] = { kind = "header", text = z[1] }
            for i = 1, z[2] do out[#out + 1] = { kind = "vendor", vendor = { name = z[1] .. i } } end
        end
        return out
    end
    local function newList()
        local l = { SetGroups = W.SetGroups, ToggleGroup = W.ToggleGroup }
        function l:SetData(d) self.shown = d end
        return l
    end
    local function shape(lst)
        local t = {}
        for _, d in ipairs(lst.shown) do t[#t + 1] = d.kind == "header" and (d.collapsed and "+" or "-") .. d.text or "v" end
        return table.concat(t, ",")
    end
    local a, b = newList(), newList()
    a:SetGroups(lay({ { "Ard", 2 }, { "Zul", 1 } }), "shops:Midnight", false)
    b:SetGroups(lay({ { "Ard", 2 } }), "shops:Dragonflight", false)
    assert(shape(a) == "-Ard,v,v,-Zul,v", "default is all expanded: " .. shape(a))
    a:ToggleGroup("Ard")
    assert(shape(a) == "+Ard,-Zul,v", "collapse hides that group's rows only: " .. shape(a))
    assert(shape(b) == "-Ard,v,v", "another page's set is independent")
    a:SetGroups(lay({ { "Ard", 2 }, { "Zul", 1 } }), "shops:Midnight", true)
    assert(shape(a) == "+Ard,-Zul,v", "a re-render keeps the collapsed set")
    a:ToggleGroup("Zul")
    assert(shape(a) == "+Ard,+Zul", "several groups can be collapsed at once")
    a:ToggleGroup("Ard")
    a:ToggleGroup("Zul")
    assert(shape(a) == "-Ard,v,v,-Zul,v", "expanding restores the rows")
    local hdr = a.shown[1]
    assert(hdr.list == a and hdr.key == "Ard", "a header reaches its list and key")
    assert(next(B.State.collapsed["shops:Midnight"]) == nil, "an expanded group leaves no key behind")
end

-- Sources: header frames carry no row view; combat gating must pass over them and still gate rows.
do
    local gated
    local row = { view = { SetLinkGated = function(_, g) gated = g end } }
    B.pages.sources.list = { box = { ForEachFrame = function(_, fn)
        fn({}, { kind = "header" })
        fn(row, { kind = "row" })
    end } }
    B.pages.sources.SetCombatGated(true)
    assert(gated == true, "the row was not gated in combat")
    B.pages.sources.SetCombatGated(false)
    assert(gated == false, "the row was not released after combat")
end

-- Count-fill refreshes re-render only the pages that read the count cache.
for key, want in pairs({ shops = true, shop = true, overview = false, sources = false, item = false }) do
    assert((B.pages[key].usesCounts == true) == want, key .. " has the wrong usesCounts flag")
end
do
    local timers, shows = {}, { A = 0, B = 0 }
    local Win = B.Window
    local noop = function() end
    wipe = function(t) for k in pairs(t) do t[k] = nil end end
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    HA.PerformanceTrace = { Measure = function(_, _, _, fn, ...) return fn(...) end }
    Win.host, Win.frame = {}, { IsShown = function() return true end }
    for _, name in ipairs({ "ResetSearch", "SelectNav", "UpdateCrumbs", "UpdateProgress" }) do Win[name] = noop end
    local function fake(key, counts)
        B.RegisterPage(key, { usesCounts = counts, Build = function() return { Show = noop, Hide = noop } end,
            Show = function() shows[key] = shows[key] + 1 end })
    end
    fake("A", true)
    fake("B", false)
    local function fire(fromFill, newData)
        B.RequestRefresh(fromFill, newData)
        local run = table.remove(timers)
        run()
    end
    B.Go({ page = "A", nav = "a" })
    assert(shows.A == 1)
    fire(true)
    assert(shows.A == 2, "a count fill must refresh a page that reads counts")
    B.Go({ page = "B", nav = "b" })
    assert(shows.B == 1)
    fire(true)
    assert(shows.B == 1, "a count fill must not re-render a page that ignores counts")
    fire(false)
    assert(shows.B == 2, "other refreshes still re-render every page")
end

print("hs534_browser_pages: ok")
