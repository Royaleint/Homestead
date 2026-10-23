-- luacheck: globals assert loadfile print rawset io CreateFrame UIParent C_Texture PixelUtil CreateColor C_ColorOverrides
-- luacheck: globals CreateFont TextSizeManager NineSliceUtil C_Timer UnitFactionGroup BreakUpLargeNumbers
-- Run from the repo root:  lua tests/hs538_summary.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The Decor Browser Overview page: the three rows and their reason lines, the
-- fill, the zone line, the first-use tip, and no search box or By source list of
-- its own. The real CatalogStore, SourceManager verdict, VendorFilter, Adapter,
-- Facts, CanGet and Widgets run against stubbed data and frames. Every link, an
-- item's and a vendor's too, is a B.Go route; the test records them.
-------------------------------------------------------------------------------

local function noop() end

-- Frames record their anchors (an unknown CamelCase name is a no-op method; any other missing field is nil), heights and scripts so the layout can be read back.
local frames, lineHeight = {}, 12
local Widget
local methods = {}
function methods.CreateFontString(self, _, _, font)
    local fs = Widget("FontString")
    fs.font, fs.parent = font, self
    frames[#frames + 1] = fs
    return fs
end
function methods.CreateTexture() return Widget("Texture") end
function methods.SetFontObject(self, font) self.font = font end
function methods.SetText(self, text) self.text = text end
function methods.GetText(self) return self.text end
function methods.SetWidth(self, w) self.width = w end
function methods.GetWidth(self) return self.width or 0 end
function methods.SetSize(self, w, h) self.width, self.height = w, h end
function methods.SetHeight(self, h) self.height = h end
function methods.GetHeight(self) return self.height or 0 end
function methods.SetShown(self, on) self.shown = on and true or false end
function methods.Show(self) self.shown = true end
function methods.Hide(self) self.shown = false end
function methods.IsShown(self) return self.shown end
function methods.IsVisible(self) return self.shown end
function methods.SetPoint(self, ...) self.points[#self.points + 1] = { ... } end
function methods.ClearAllPoints(self) self.points = {} end
function methods.SetScript(self, name, fn) self.scripts[name] = fn end
function methods.HookScript(self, name, fn) self.scripts[name] = fn end
function methods.SetAlpha(self, a) self.alpha = a end
function methods.SetTextColor(self, r, g, b) self.color = { r, g, b } end
function methods.GetUnboundedStringWidth(self) return #self.text * 6 end
function methods.GetStringHeight() return lineHeight end
function methods.GetTextWidth(self) return #self.text * 6 end
function methods.GetFrameLevel() return 1 end
function methods.GetParent(self) return self.parent end
function Widget(kind)
    return setmetatable({ kind = kind, shown = true, text = "", scripts = {}, points = {} }, {
        __index = function(_, k) return methods[k] or (k:match("^%u") and noop or nil) end,
    })
end

local function click(f, ...) f.scripts.OnClick(f, ...) end

-------------------------------------------------------------------------------
-- The environment: the canget fixtures plus the UI files
-------------------------------------------------------------------------------

local function newEnv()
    local env = {
        done = true, attempted = true, warm = true, responded = true, faction = "Alliance",
        catalog = {}, names = {}, sources = {}, vendors = {}, offers = {}, reqs = {}, scanned = {},
        calendar = {}, themes = {}, measured = {}, playerMap = nil, maps = {}, gen = 1,
        routes = {}, saves = {}, glows = {}, timers = {}, tooltips = {}, hidden = {}, waypoints = {},
        qualityReads = 0,
    }
    frames = {}
    rawset(_G, "Foundry_1_0", { RaiseDevError = function(_, msg) error(msg) end })
    rawset(_G, "wipe", function(t) for k in pairs(t) do t[k] = nil end return t end)
    rawset(_G, "GetBuildInfo", function() return "12.0.1", "1", "1", 120001 end)
    rawset(_G, "UnitFactionGroup", function() return env.faction end)
    rawset(_G, "Enum", { ItemClass = { Housing = 20 }, ItemHousingSubclass = { Decor = 0, Dye = 1 },
        UIMapType = { Continent = 2, Zone = 3 } })
    rawset(_G, "C_Item", {
        GetItemNameByID = function(id) return env.names[id] end,
        RequestLoadItemDataByID = function() end,
        GetItemIconByID = function(id) return 1000 + id end,
        GetItemQualityByID = function() return 1 end,
    })
    rawset(_G, "IsModifiedClick", function() return false end)
    rawset(_G, "C_HousingCatalog", {
        GetCatalogEntryInfoByItem = function(id) return env.catalog[id] end,
        GetCatalogEntryInfoByRecordID = function() return nil end,
    })
    rawset(_G, "C_Map", {
        GetBestMapForUnit = function() return env.playerMap end,
        GetMapInfo = function(id) return env.maps[id] end,
        GetMapChildrenInfo = function() return {} end,
        GetPlayerMapPosition = function() return nil end,
    })
    rawset(_G, "C_Timer", { After = function(_, fn) env.timers[#env.timers + 1] = fn end })
    rawset(_G, "UIParent", Widget("UIParent"))
    rawset(_G, "CreateFrame", function(kind, _, parent, template)
        local w = Widget(kind)
        w.parent, w.template = parent, template
        if kind == "EditBox" then w.Instructions = Widget("FontString") end
        frames[#frames + 1] = w
        return w
    end)
    rawset(_G, "CreateFont", function() return Widget("Font") end)
    rawset(_G, "C_Texture", { GetAtlasInfo = function() return nil end })
    rawset(_G, "PixelUtil", { SetHeight = noop, SetWidth = noop })
    rawset(_G, "NineSliceUtil", { ApplyLayoutByName = noop })
    rawset(_G, "CreateColor", function() return {} end)
    rawset(_G, "TextSizeManager", { GetScale = function() return 1 end })
    rawset(_G, "BreakUpLargeNumbers", tostring)
    rawset(_G, "C_ColorOverrides", { GetColorForQuality = function()
        env.qualityReads = env.qualityReads + 1
        return { r = 0, g = 0.5, b = 1 }
    end })

    local HA = {
        Addon = { db = {
            global = { catalogItems = {}, schemaVersion = 7, scannedVendors = {}, noDecorVendors = {} },
            profile = { vendorTracer = { showEventVendors = true }, browser = { tipSeen = true } },
        }, Debug = function() end, RegisterModule = function() end },
        Events = { Fire = function() end },
        Constants = { ZoneToFactionMap = {}, TEXTURE_ROOT = "", Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
        DecorMapping = {}, EventSources = { EventVendors = {} },
        Waypoints = { Set = function(_, mapID, x, y, opts) env.waypoints[#env.waypoints + 1] = { mapID, x, y, opts } end },
    }
    env.HA = HA
    HA.PerformanceTrace = { Measure = function(_, op, workload, fn, ...)
        env.measured[#env.measured + 1] = { op = op, workload = workload }
        return fn(...)
    end }
    HA.CatalogScanner = {
        HasFirstReadCompleted = function() return env.done end,
        HasFirstReadAttempted = function() return env.attempted end,
        IsWarm = function() return env.warm end,
        HasStorageResponded = function() return env.responded end,
    }
    HA.CalendarDetector = { IsHolidayActive = function(_, name)
        if env.calendar == nil then return nil end
        return env.calendar[name] == true
    end }
    HA.EndeavorsData = {
        GetThemeForVendor = function(_, v) return v.theme end,
        IsThemeActive = function(_, theme) return theme ~= nil and env.themes[theme] or nil end,
    }
    local events = HA.EventSources.EventVendors
    HA.VendorData = {
        GetVendor = function(_, npcID)
            if env.vendors[npcID] then return env.vendors[npcID] end
            local ev = events[npcID]
            if ev and env.calendar and env.calendar[ev.event] == true then return ev end
        end,
        HasOfferForItem = function(_, id) return env.offers[id] == true end,
        GetVendorItems = function(_, npcID) return (env.vendors[npcID] or events[npcID] or {}).items end,
        GetScannedVendorItems = function() return nil end,
        GetMergedItemIDs = function(_, v) return v.items end,
        GetVendorsInMap = function(_, mapID)
            local out = {}
            for _, v in pairs(env.vendors) do
                if v.mapID == mapID then out[#out + 1] = v end
            end
            for _, v in pairs(events) do
                if v.mapID == mapID and env.calendar and env.calendar[v.event] == true then out[#out + 1] = v end
            end
            table.sort(out, function(a, b) return a.npcID < b.npcID end)
            return out
        end,
        FormatCost = function(_, cost) return cost.gold .. "g" end,
    }
    for _, file in ipairs({ "Locale/enUS.lua", "Data/CatalogStore.lua", "Data/SourceManager.lua",
        "UI/VendorFilter.lua", "UI/Browser/Style.lua", "UI/Browser/Visuals.lua", "UI/Browser/Adapter.lua",
        "UI/Browser/Facts.lua", "UI/Browser/CanGet.lua", "UI/Browser/Widgets.lua" }) do
        assert(loadfile(root .. "/" .. file))("Homestead", HA)
    end
    local SM = HA.SourceManager
    SM.GetAllSources = function(_, id) return env.sources[id] or {} end
    SM.GetRequirements = function(_, id, npcID) return env.reqs[id .. ":" .. tostring(npcID)] or {} end
    SM.GetVendorItemCost = function(_, id) return env.cost and env.cost[id] or { gold = 100 } end
    local isMet = SM.IsRequirementMet
    SM.IsRequirementMet = function(self, req)
        if req.met ~= nil then return req.met end
        return isMet(self, req)
    end
    HA.VendorFilter.GetBestVendorCoordinates = function(v) return v.coords, v.mapID end
    HA.CatalogStore:Initialize()

    local B = HA.DecorBrowser
    B.State = { catalogMemo = {} }
    B.Window = { AddSearchBox = noop, Glow = function(region) env.glows[#env.glows + 1] = region end }
    B.Generation = function() return env.gen end
    B.Go = function(route) env.routes[#env.routes + 1] = route end
    B.Save = function(key, value)
        env.saves[#env.saves + 1] = { key, value }
        B.Saved()[key] = value
    end
    B.HideTooltip = noop
    B.HideTooltipFor = function(owner) env.hidden[#env.hidden + 1] = owner end
    B.ShowItemTooltip = function(owner, itemID, npcID) env.tooltips[#env.tooltips + 1] = { owner, itemID, npcID } end
    local pages = {}
    B.RegisterPage = function(kind, page) pages[kind] = page end
    local created = #frames
    assert(loadfile(root .. "/UI/Browser/Summary.lua"))("Homestead", HA)
    assert(#frames == created, "loading Summary created a frame")
    env.tab, env.B, env.D, env.CG = pages.overview, B, B.Data, B.CanGet

    function env.decor(itemID, entry)
        HA.DecorMapping[itemID + 900000] = itemID
        env.catalog[itemID] = entry or { totalNumStored = 0 }
        env.names[itemID] = env.names[itemID] or ("Item " .. itemID)
    end
    function env.vendor(npcID, fields)
        local v = fields or {}
        v.npcID, v.mapID, v.items = npcID, v.mapID or 101, v.items or {}
        v.name = v.name or ("Vendor " .. npcID)
        v.zone = v.zone or "Durotar"
        if v.coords == nil then v.coords = { x = 0.5, y = 0.5 } end
        env.vendors[npcID] = v
        return v
    end
    function env.sell(itemID, v, cost)
        local list = env.sources[itemID] or {}
        list[#list + 1] = { type = "vendor", data = { npcID = v.npcID, vendor = v, cost = cost or { gold = 100 } } }
        env.sources[itemID] = list
        env.offers[itemID] = true
        v.items[#v.items + 1] = itemID
    end
    function env.owned(itemID) env.catalog[itemID] = { totalNumStored = 1 } end
    function env.walks()
        local n = 0
        for _, m in ipairs(env.measured) do if m.op == "browser_walk" then n = n + 1 end end
        return n
    end
    -- Map layout: continent 100 > zone 101 (Durotar) > building 103; zone 102 next door; continent 200 > zone 201.
    env.maps[100] = { mapType = 2, parentMapID = 0, name = "Kalimdor" }
    env.maps[101] = { mapType = 3, parentMapID = 100, name = "Durotar" }
    env.maps[102] = { mapType = 3, parentMapID = 100, name = "Mulgore" }
    env.maps[103] = { mapType = 5, parentMapID = 101, name = "Shop" }
    env.maps[200] = { mapType = 2, parentMapID = 0, name = "Eastern Kingdoms" }
    env.maps[201] = { mapType = 3, parentMapID = 200, name = "Elwynn" }
    env.playerMap = 101

    -- Builds and shows the page the way the router does.
    function env.open(seed)
        local page = Widget("Frame")
        env.page = page
        env.tab:Build(page)
        env.tab:Show({ kind = "overview", seed = seed })
    end
    function env.rows()
        local out = {}
        for _, f in ipairs(frames) do
            if rawget(f, "why") and rawget(f, "src") and f.shown then out[#out + 1] = f end
        end
        return out
    end
    function env.find(pred)
        for _, f in ipairs(frames) do if pred(f) then return f end end
    end
    function env.top(f) return -f.points[1][5] end
    function env.seeAll()
        local main = env.find(function(f) return f.text == "What can I get now?" end).parent
        return env.find(function(f) return f.template == "UIPanelButtonTemplate" and f.parent == main end)
    end
    function env.empty()
        return env.find(function(f) return rawget(f, "buttons") end)
    end
    -- What the router does for a data refresh: a new memo generation, then the repaint.
    function env.refreshData()
        env.D.InvalidateMemos()
        wipe(env.B.State.catalogMemo)
        env.tab:Refresh("data")
    end
    function env.flush()
        local run = env.timers
        env.timers = {}
        for _, fn in ipairs(run) do fn() end
    end
    return env, HA
end

local function eq(a, b, msg)
    if a ~= b then error((msg or "mismatch") .. ": got " .. tostring(a) .. ", wanted " .. tostring(b), 2) end
end

-------------------------------------------------------------------------------
-- Nothing is built before the first open, and a repaint with no page is harmless
-------------------------------------------------------------------------------

do
    local env = newEnv()
    eq(#frames, 0, "frames before the first open")
    env.tab:Refresh("data")
    env.tab:Hide()
    env.tab:SetCombat(true)
    eq(#frames, 0, "a repaint before Build built something")
    print("hs538_summary: nothing built early ok")
end

-------------------------------------------------------------------------------
-- R13: the rows follow the ranked walk; the reason line is never empty, has at most
-- two signals and falls back to the mock's words; the button and the links
-------------------------------------------------------------------------------

do
    local env, HA = newEnv()
    local here = env.vendor(1, { mapID = 101, name = "Joruh", zone = "Durotar" })
    local same = env.vendor(2, { mapID = 102 })
    local far = env.vendor(3, { mapID = 201, coords = false })
    local ev = { npcID = 4, mapID = 101, event = "Hallow's End", _isEventVendor = true, items = {}, name = "Ghoul", zone = "Durotar" }
    HA.EventSources.EventVendors[4] = ev
    env.calendar = { ["Hallow's End"] = true }
    local currency = { gold = 0, currencies = { { id = 1, amount = 5 } } }
    for id = 1, 5 do env.decor(id) end
    env.sell(1, here)
    env.sell(2, same, currency)
    env.sell(3, far)
    env.sell(4, far, currency)
    env.sell(5, ev, currency)
    env.catalog[5].firstAcquisitionBonus = 2
    env.sell(5, here)
    env.open()

    local order = {}
    for i, e in ipairs(env.CG.Rank()) do order[i] = e.itemID end
    eq(table.concat(order, ","), "5,1,2,3,4", "R11 order")

    local rows = env.rows()
    eq(#rows, 3, "three rows")
    eq(rows[1].name.text, "Item 5")
    eq(rows[1].why.text, "Hallow's End: active now \194\183 First-Time Collection Bonus", "two signals, never three")
    eq(rows[2].why.text, "Sold here in Durotar \194\183 Gold only", "sold here, then gold only")
    eq(rows[2].src.text, "Vendor: Joruh, Durotar \194\183 100g", "source and price line")
    eq(rows[3].why.text, "Sold on Kalimdor", "same continent")

    -- Take the near items out of the walk so the far ones show their fallback lines.
    for _, id in ipairs({ 1, 2, 5 }) do env.owned(id) end
    env.refreshData()
    rows = env.rows()
    eq(rows[1].name.text, "Item 3")
    eq(rows[1].why.text, "Gold only, no requirements left", "gold-only fallback")
    eq(rows[2].why.text, "No requirements left", "plain fallback")
    for _, r in ipairs(rows) do
        assert(r.why.text ~= "" and r.name.text ~= "" and r.src.text ~= "", "a row has a blank line")
        local _, n = r.why.text:gsub("\194\183", "")
        assert(n <= 1, "more than two signals")
    end

    -- Buttons: no spot for vendor 3 means Show; a spot means Set waypoint.
    assert(rows[1].show.shown and not rows[1].wp.shown, "no coordinates: Show")
    click(rows[1].show)
    local route = env.routes[#env.routes]
    assert(route.kind == "item" and route.id == 3, "Show opens the item page")
    click(rows[1])
    route = env.routes[#env.routes]
    assert(route.kind == "item" and route.id == 3, "the row opens the item page")
    print("hs538_summary: R13 rows ok")
end

do
    local env = newEnv()
    local here = env.vendor(1, { mapID = 101, name = "Joruh" })
    env.decor(1)
    env.sell(1, here)
    env.open()
    local row = env.rows()[1]
    assert(row.wp.shown and not row.show.shown, "a known spot: Set waypoint")
    eq(row.wp.wp.mapID, 101)
    eq(row.wp.wp.title, "Joruh")
    local routed = #env.routes
    click(row.wp)
    eq(#env.waypoints, 1, "Set waypoint sets the waypoint and changes no tab")
    eq(env.waypoints[1][1], 101)
    eq(#env.routes, routed, "and goes nowhere")
    eq(row.itemID, 1)
    row.scripts.OnEnter(row)
    eq(env.tooltips[1][1], row, "the tooltip goes through the browser tooltip")
    eq(env.tooltips[1][3], 1, "with the vendor")
    env.tab:Hide()
    eq(#env.hidden, 3, "Hide releases the tooltip of every row")
    print("hs538_summary: R13 buttons and tooltip ok")
end

-------------------------------------------------------------------------------
-- R14: the fill at q = 0, 1, 2, 3 and all collected, and never a blank slot
-------------------------------------------------------------------------------

local function filled(q, candidates, extra)
    local env = newEnv()
    local v = env.vendor(10, { mapID = 201 })
    for i = 1, q do env.decor(i) env.sell(i, v) end
    for i = 1, candidates do
        local id = 50 + i
        env.decor(id)
        env.sell(id, v)
        local reqs = {}
        for r = 1, i + 1 do reqs[r] = { type = "achievement", name = "Feat " .. r, met = false } end
        env.reqs[id .. ":10"] = reqs
    end
    if extra then extra(env, v) end
    env.open()
    return env
end

do
    for _, case in ipairs({ { 0, 3 }, { 1, 2 }, { 2, 1 }, { 3, 0 }, { 0, 1 }, { 2, 0 } }) do
        local q, notYet = case[1], case[2]
        local env = filled(q, notYet)
        local rows = env.rows()
        eq(#rows, q + notYet, "rows at q = " .. q .. " with " .. notYet .. " candidates")
        for i, r in ipairs(rows) do
            assert(r.name.text ~= "" and r.why.text ~= "" and r.src.text ~= "", "blank line in row " .. i)
            if i > q then
                eq(r.why.text, "Not yet: next step")
                eq(r.alpha, 0.6, "a next step is dimmed")
                assert(not r.wp.shown and not r.show.shown, "a next step has no button")
            else
                eq(r.alpha, 1)
            end
        end
        for i = 2, #rows do
            eq(env.top(rows[i]), env.top(rows[i - 1]) + rows[i - 1].height + 8, "a gap between rows")
        end
        local seeAll = env.seeAll()
        eq(seeAll.shown, q > 0, "See all only with something to see")
        local empty = env.empty()
        eq(empty.shown, q == 0, "Nothing you can get right now at q = " .. q)
        if q == 0 then eq(empty.title.text, "Nothing you can get right now") end
        print("hs538_summary: R14 q = " .. q .. " with " .. notYet .. " next steps ok")
    end

    -- A next step shows its first requirement and how many more.
    local env = filled(0, 3)
    local rows = env.rows()
    eq(rows[1].src.text, "Requires: Achievement: Feat 1 and 1 more")
    eq(rows[3].src.text, "Requires: Achievement: Feat 1 and 3 more")

    -- An event that is off season reads "<event> only".
    env = newEnv()
    local ev = { npcID = 20, mapID = 101, event = "Lunar Festival", _isEventVendor = true, items = { 21 }, name = "Elder" }
    env.HA.EventSources.EventVendors[20] = ev
    env.decor(21)
    env.open()
    eq(env.rows()[1].src.text, "Lunar Festival only")

    -- Nothing you can get: the button opens Catalog on what is missing.
    env = filled(0, 0, function(e) e.decor(70) end)
    local empty = env.empty()
    local none = "Everything you're missing needs a reputation, achievement or quest first, or is sold only during an event."
    assert(empty.shown and empty.text.text == none, "no missing item is faction-limited, yet a faction is named: " .. empty.text.text)
    click(empty.buttons[1])
    eq(#env.routes, 1)
    eq(env.routes[1].kind, "catalog")
    eq(env.routes[1].key, "all")
    assert(env.routes[1].seed.filters.notCollected == true, "Show what's missing")
    env.HA.Addon.db.profile.browser.tipSeen = true
    env.faction = "Neutral"
    env.tab:Refresh("paint")
    assert(empty.text.text == none, "a Neutral character with no faction-only item is told a faction: " .. empty.text.text)
    env = filled(0, 0, function(e) e.decor(70) e.sell(70, e.vendor(71, { faction = "Horde" })) end)
    empty = env.empty()
    assert(empty.shown and empty.text.text:find("sold only to the Horde.", 1, true), "a Horde-only missing item: " .. empty.text.text)

    -- Everything collected.
    env = filled(0, 0, function(e) e.decor(80) e.owned(80) end)
    env.refreshData()
    local done = env.empty()
    assert(done.shown and done.text.text:find("all 1 decor", 1, true), done.text.text)
    eq(#env.rows(), 0, "no rows when nothing is missing")
    print("hs538_summary: R14 states ok")
end

-------------------------------------------------------------------------------
-- Counting and not read (R37)
-------------------------------------------------------------------------------

do
    local env = newEnv()
    env.vendor(1)
    env.decor(1)
    env.sell(1, env.vendors[1])
    env.done, env.attempted = false, false
    env.open()
    local rows = env.rows()
    eq(#rows, 3, "three placeholder rows")
    for _, r in ipairs(rows) do
        eq(r.name.text, "Counting\226\128\166")
        eq(r.why.text, "Reading your collection")
        eq(rawget(r, "itemID"), nil, "a placeholder opens nothing")
    end
    click(rows[1])
    eq(#env.routes, 0, "clicking a placeholder goes nowhere")
    eq(env.walks(), 0, "no walk before the collection is ready")

    env.done, env.attempted, env.warm, env.responded = true, true, false, false
    env.tab:Refresh("data")
    eq(#env.rows(), 0)
    local notRead = env.empty()
    assert(notRead.shown, "the not-read block")
    eq(env.walks(), 0)
    print("hs538_summary: counting and not read ok")
end

-------------------------------------------------------------------------------
-- R15 and R19: See all, and the first-use tip (written once)
-------------------------------------------------------------------------------

do
    local env = filled(4, 0)
    env.HA.Addon.db.profile.browser.tipSeen = false
    env.tab:Refresh("paint")
    local tip = env.find(function(f) return type(f.text) == "string" and f.text:find("^Can get now means") end).parent
    assert(tip.shown, "the tip shows while tipSeen is false")
    local firstRow = env.rows()[1]
    local topWithTip = env.top(firstRow)
    local seeAll = env.seeAll()
    eq(seeAll.text, "See all you can get now (4)")
    click(seeAll)
    local route = env.routes[#env.routes]
    assert(route.kind == "catalog" and route.key == "all", "See all opens All decor")
    assert(route.seed.filters.canGet == true and route.seed.sort == "best", "See all opens Can get now, best first")
    eq(#env.saves, 1, "See all dismisses the tip with one write")
    eq(env.saves[1][1], "tipSeen")
    click(seeAll)
    eq(#env.saves, 1, "a second See all writes nothing")
    env.tab:Refresh("paint")
    assert(not tip.shown, "the dismissed tip is gone")
    assert(env.top(env.rows()[1]) < topWithTip, "the tip leaves no gap")

    -- Help brings it back without a write; closing it again writes nothing more.
    env.tab:Show({ kind = "overview", seed = { showTip = true } })
    assert(tip.shown, "showTip shows the tip")
    eq(#env.saves, 1, "showTip never writes")
    local close = env.find(function(f) return f.template == "UIPanelCloseButton" and f.parent == tip end)
    click(close)
    assert(not tip.shown, "close hides the tip")
    eq(#env.saves, 1, "tipSeen is saved once, ever")
    env.tab:Show({ kind = "overview" })
    assert(not tip.shown, "a plain tab switch keeps the tip closed")

    -- Close on a fresh account writes once.
    local env2 = filled(1, 0)
    env2.HA.Addon.db.profile.browser.tipSeen = false
    env2.tab:Refresh("paint")
    local tip2 = env2.find(function(f) return type(f.text) == "string" and f.text:find("^Can get now means") end).parent
    click(env2.find(function(f) return f.template == "UIPanelCloseButton" and f.parent == tip2 end))
    eq(#env2.saves, 1)
    eq(env2.saves[1][2], true)
    print("hs538_summary: R15 and R19 ok")
end

-------------------------------------------------------------------------------
-- R16: Here in <zone>, the glow, the walk-up and the missing line
-------------------------------------------------------------------------------

do
    local env = newEnv()
    local joruh = env.vendor(1, { mapID = 101, name = "Joruh" })
    local small = env.vendor(2, { mapID = 103, name = "Smith" })
    local mul = env.vendor(3, { mapID = 102, name = "Hunter", zone = "Mulgore" })
    for id = 1, 3 do env.decor(id) env.sell(id, joruh) end
    env.decor(4)
    env.sell(4, small)
    env.decor(5)
    env.sell(5, mul)
    env.decor(6)
    env.sell(6, mul)
    env.maps[103].parentMapID = 101
    env.playerMap = 103
    env.open()
    local line = env.find(function(f) return f.text == "Here in Durotar: Joruh sells 3 decor you can get now." end)
    assert(line, "the zone line, walked up from the building to the zone")
    local zone = line.parent
    assert(zone.shown, "shown")
    eq(env.top(zone), 40, "the zone line sits under the title and the lede")
    assert(zone.btn.shown)
    click(zone.btn)
    eq(#env.routes, 1)
    eq(env.routes[1].kind, "vendor", "Show vendor opens the vendor page")
    eq(env.routes[1].id, 1, "Show vendor routes to the vendor's key")

    eq(zone.more.text, "More vendors here")
    assert(zone.more.shown, "the Here line links to more vendors")
    click(zone.more)
    eq(#env.routes, 2)
    eq(env.routes[2].kind, "allVendors", "More vendors here opens All vendors")
    eq(env.routes[2].key, nil)
    eq(env.routes[2].seed.zone, 101, "at the player's zone, walked up from the building (map 103)")

    eq(#env.glows, 0, "the glow waits for the next frame")
    env.flush()
    eq(#env.glows, 1, "glows when it first shows")
    env.tab:Refresh("paint")
    env.tab:Refresh("layout")
    env.tab:Show({ kind = "overview" })
    env.flush()
    eq(#env.glows, 1, "later draws for the same map do not glow")
    local walks = env.walks()
    env.playerMap = 102
    env.tab:Refresh("zone")
    env.flush()
    eq(#env.glows, 2, "a new map glows once")
    env.tab:Refresh("zone")
    env.flush()
    eq(#env.glows, 2, "and only once")
    env.playerMap = 101
    env.tab:Refresh("zone")
    env.flush()
    eq(#env.glows, 3, "back to the first map is a new map again")
    eq(env.walks(), walks, "a zone change never walks")

    -- A glow queued before the window closed is dropped.
    env.playerMap = 102
    env.tab:Refresh("zone")
    env.gen = env.gen + 1
    env.flush()
    eq(#env.glows, 3, "a stale glow is dropped")

    -- Nothing here: the line is absent and leaves no gap.
    env.playerMap = 201
    env.tab:Refresh("zone")
    assert(not zone.shown, "no vendor here, no line")
    eq(env.top(env.rows()[1]), 40, "the rows move up into the gap")

    -- An unknown spot: the line is not shown at all.
    env.playerMap = nil
    env.tab:Refresh("zone")
    assert(not zone.shown, "no map, no line")

    -- A vendor the browser cannot select names itself with no button.
    local env2 = newEnv()
    local ghost = { npcID = 9, mapID = 101, items = {}, name = "Ghost", zone = "Durotar" }
    env2.decor(1)
    env2.sell(1, ghost)
    env2.HA.VendorData.GetVendorsInMap = function() return { ghost } end
    env2.open()
    local line2 = env2.find(function(f) return f.text == "Here in Durotar: Ghost sells 1 decor you can get now." end)
    assert(line2 and line2.parent.shown, "the line is drawn")
    assert(not line2.parent.btn.shown, "a nil key draws no Show vendor button")
    print("hs538_summary: R16 ok")
end

-------------------------------------------------------------------------------
-- R17: the page registers as the overview, and the search and the By source list
-- are not its own: the header searches, and the tree and the list heads count
-------------------------------------------------------------------------------

do
    local env = filled(1, 0)
    assert(env.tab and type(env.tab.Show) == "function", "Summary registers a page for the overview")
    eq(env.tab:Save(), nil, "the overview has nothing to restore")
    eq(env.find(function(f) return f.kind == "EditBox" end), nil, "the search box lives in the header")
    eq(env.find(function(f) return f.kind == "Button" and f.text == "Search" end), nil, "no Search button")
    eq(env.find(function(f) return f.text == "By source" or rawget(f, "num") ~= nil end), nil, "no By source list")
    local title = env.find(function(f) return f.text == "What can I get now?" end)
    eq(title.font, env.B.Style.font.header, "the title wears the header font")
    print("hs538_summary: R17 ok")
end

-------------------------------------------------------------------------------
-- R18: the walk's By source counts, which the source list heads draw (the heads
-- are asserted in hs538_parity and hs538_hide). They equal what Catalog's filter
-- rule counts over the same walk (every item with the source type; collected =
-- owned), with unknown ownership in the total and never in the collected.
-------------------------------------------------------------------------------

do
    local env, HA = newEnv()
    local v = env.vendor(1)
    HA.AchievementSources, HA.QuestSources, HA.ShopSources = {}, {}, {}
    for id = 1, 12 do env.decor(id) end
    env.sell(1, v) env.sell(2, v) env.sell(3, v)
    HA.AchievementSources[3], HA.AchievementSources[4], HA.AchievementSources[5] = true, true, true
    HA.QuestSources[6], HA.QuestSources[7] = true, true
    HA.ShopSources[8], HA.ShopSources[1] = true, true
    env.owned(1) env.owned(4) env.owned(6) env.owned(8)
    env.catalog[5], env.catalog[7] = nil, nil
    env.catalog[9] = nil
    env.owned(10)
    env.open()
    local w = env.CG.Walk()
    local shown = 0
    for _, key in ipairs(env.CG.SOURCE_KEYS) do
        local total, collected = 0, 0
        for _, e in ipairs(w.list) do
            if e.src[key] then
                total = total + 1
                if e.own == "owned" then collected = collected + 1 end
            end
        end
        local p = w.progress.src[key]
        eq(p.owned, collected, "By source " .. key .. " collected")
        eq(p.total, total, "By source " .. key .. " total")
        if total > 0 then shown = shown + 1 end
    end
    assert(shown >= 4, "the fixture covers several source types")
    eq(w.progress.src.achievements.owned, 1, "achievements: one owned, one unknown, one not owned")
    eq(w.progress.src.achievements.total, 3)
    local pct = env.find(function(f) return type(f.text) == "string" and f.text:find("%%") and f.text:find("collected") end)
    eq(pct, nil, "no overall percentage")
    print("hs538_summary: R18 parity ok")
end

-------------------------------------------------------------------------------
-- The walk: only a data refresh may start one; the others reuse the saved walk
-------------------------------------------------------------------------------

do
    local env = filled(3, 1)
    eq(env.walks(), 1, "opening walks once")
    local fills, fill = 0, env.CG.Fill
    env.CG.Fill = function() fills = fills + 1 return fill() end
    for _, reason in ipairs({ "paint", "layout", "hide", "names", "stats" }) do
        env.tab:Refresh(reason)
        eq(env.walks(), 1, reason .. " walked")
    end
    eq(fills, 0, "the fill is reused while the ranking stands")
    env.tab:Refresh("zone")
    eq(env.walks(), 1, "zone walked")
    env.tab:Hide()
    env.tab:Refresh("paint")
    eq(#env.rows(), 3, "a repaint after Hide restores the page without Show")
    eq(env.walks(), 1)
    env.refreshData()
    eq(env.walks(), 2, "a data refresh walks")
    eq(fills, 1, "a new walk fills again")
    print("hs538_summary: walk discipline ok")
end

-------------------------------------------------------------------------------
-- Colours are read at draw time; a text size change re-measures
-------------------------------------------------------------------------------

do
    local env = filled(2, 0)
    local before = env.qualityReads
    env.tab:Refresh("paint")
    assert(env.qualityReads >= before + 2, "quality colours are read on every draw")
    local r1 = env.rows()[1]
    eq(r1.name.color[2], 0.5, "the name wears the quality colour")
    local h = r1.height
    lineHeight = 24
    env.tab:Refresh("layout")
    assert(r1.height > h, "rows grow with the text size")
    lineHeight = 12
    print("hs538_summary: colour and layout ok")
end

-------------------------------------------------------------------------------
-- Saved keys: the tab writes only tipSeen
-------------------------------------------------------------------------------

do
    local env = filled(3, 0)
    env.HA.Addon.db.profile.browser.tipSeen = false
    env.tab:Refresh("paint")
    click(env.seeAll())
    for _, s in ipairs(env.saves) do eq(s[1], "tipSeen") end
    local f = assert(io.open(root .. "/UI/Browser/Summary.lua", "rb"))
    local src = f:read("*a")
    f:close()
    assert(not src:find("GameTooltip", 1, true), "Summary uses the browser tooltip")
    assert(not src:find("InCombatLockdown", 1, true), "nothing protected on this tab")
    print("hs538_summary: saved keys ok")
end

print("hs538_summary: all ok")
