-- luacheck: globals assert loadfile print io rawset CreateFrame UIParent C_Texture PixelUtil CreateColor C_ColorOverrides
-- luacheck: globals CreateScrollBoxListLinearView CreateScrollBoxListGridView ScrollBoxConstants ScrollUtil CreateAnchor CreateDataProvider TextSizeManager NineSliceUtil
-- luacheck: globals C_Timer C_Item C_Map date os SetPortraitTextureFromCreatureDisplayID InCombatLockdown
-- Run from the repo root:  lua tests/hs538_sources.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The Sources file, run through the real Sources.lua, Widgets, Facts, Adapter and
-- CanGet against stubbed data and recording widgets: grouping and row words, the
-- vendor page and the source page the file registers (head, location, lines, count line, rows), the route
-- every source row opens, Hide's footer, the count refresh, and the walk discipline.
-- The list page registers for the sources, vendors and allVendors routes; env.tab shows pages the way
-- the router would for a sources route with a seed, and types into the header box through Filter.
-------------------------------------------------------------------------------

local function noop() end
local Widget
local made, all, boxes, views = {}, {}, {}, {}
local scrolls = {}
local methods = {}
function methods.CreateFontString(self, _, _, font)
    local fs = Widget("FontString")
    fs.font = font
    fs.parent = self
    made[#made + 1] = fs
    return fs
end
function methods.CreateTexture() return Widget("Texture") end
function methods.SetFontObject(self, font) self.font = font end
function methods.SetText(self, text) self.text = text end
function methods.GetText(self) return self.text end
function methods.SetWidth(self, w) self.width = w end
function methods.GetWidth(self) return rawget(self, "width") or 200 end
function methods.SetSize(self, w, h) self.width, self.height = w, h end
function methods.SetHeight(self, h) self.height = h end
function methods.GetHeight(self) return rawget(self, "height") or 0 end
function methods.SetShown(self, on) self.shown = on end
function methods.Show(self) self.shown = true end
function methods.Hide(self) self.shown = false end
function methods.IsShown(self) return self.shown end
function methods.SetScript(self, name, fn) self.scripts[name] = fn end
function methods.HookScript(self, name, fn) self.scripts[name] = fn end
function methods.SetAlpha(self, a) self.alpha = a end
function methods.SetDesaturated(self, on) self.desaturated = on end
function methods.SetTextColor(self, r, g, b) self.color = { r, g, b } end
function methods.SetVertexColor(self, r, g, b) self.color = { r, g, b } end
function methods.SetColorTexture(self, r, g, b) self.color = { r, g, b } end
function methods.GetUnboundedStringWidth(self) return #self.text * 6 end
function methods.GetStringHeight() return 12 end
function methods.GetTextWidth(self) return #self.text * 6 end
function methods.GetFrameLevel() return 1 end
function methods.GetParent(self) return self.parent end
function methods.SetEnabled(self, on) self.enabled = on end
function methods.IsEnabled(self) return self.enabled ~= false end
function methods.SetMotionScriptsWhileDisabled(self, on) self.motion = on end
-- The engine's gate: a disabled button runs no OnEnter unless its motion scripts are on.
local function Enter(f)
    if f:IsEnabled() or rawget(f, "motion") then f.scripts.OnEnter(f) end
end
function methods.SetChecked(self, on) self.checked = on end
function methods.SetDataProvider(self, data) self.data = data end
function methods.ScrollToElementDataIndex(self, index) scrolls[#scrolls + 1] = { box = self, index = index } end
function methods.SetElementFactory(self, fn) self.factory = fn end
function Widget(kind)
    local w = setmetatable({ kind = kind, shown = true, text = "", scripts = {}, calls = {} }, {
        __index = function(_, k) return methods[k] or noop end,
    })
    all[#all + 1] = w
    return w
end

UIParent = Widget("UIParent")
CreateFrame = function(kind, _, parent, template)
    local w = Widget(kind)
    w.parent, w.template = parent, template
    if kind == "EditBox" then w.Instructions = Widget("FontString") end
    if template == "ScrollFrameTemplate" then w.ScrollBar = Widget("EventFrame") end
    if template == "WowScrollBoxList" then boxes[#boxes + 1] = w end
    return w
end
C_Texture = { GetAtlasInfo = function() return nil end }
PixelUtil = { SetHeight = noop, SetWidth = noop }
NineSliceUtil = { ApplyLayoutByName = noop }
CreateColor = function() return {} end
CreateAnchor = noop
CreateDataProvider = function(t) return t end
TextSizeManager = { GetScale = function() return 1 end }
C_ColorOverrides = { GetColorForQuality = function() return { r = 0, g = 0.5, b = 1 } end }
ScrollBoxConstants = { AlignBegin = 0, AlignCenter = 0.5, AlignEnd = 1 }
ScrollUtil = { InitScrollBoxListWithScrollBar = noop, AddManagedScrollBarVisibilityBehavior = noop, InitScrollFrameWithScrollBar = noop }
CreateScrollBoxListGridView = function() return Widget("View") end
CreateScrollBoxListLinearView = function()
    local v = Widget("View")
    views[#views + 1] = v
    return v
end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local portraitCalls = {}
SetPortraitTextureFromCreatureDisplayID = function(tex, id) portraitCalls[#portraitCalls + 1] = id; tex.portrait = id end
rawset(_G, "date", os.date)
local combat = false
InCombatLockdown = function() return combat end

local function newEnv()
    local env = {
        money = 1e9, currency = {}, count = {},
        done = true, attempted = true, warm = true, responded = true, faction = "Alliance",
        catalog = {}, catalogCalls = 0, names = {}, sources = {}, vendors = {}, offers = {}, reqs = {},
        scanned = {}, calendar = {}, themes = {}, vendorActiveCalls = 0, measured = {},
        playerMap = nil, maps = {},
    }
    rawset(_G, "Foundry_1_0", { RaiseDevError = function(_, msg) error(msg) end })
    rawset(_G, "wipe", function(t) for k in pairs(t) do t[k] = nil end return t end)
    rawset(_G, "GetBuildInfo", function() return "12.0.1", "1", "1", 120001 end)
    rawset(_G, "UnitFactionGroup", function() return env.faction end)
    rawset(_G, "Enum", { ItemClass = { Housing = 20 }, ItemHousingSubclass = { Decor = 0, Dye = 1 },
        UIMapType = { Continent = 2, Zone = 3 } })
    rawset(_G, "GetMoney", function() return env.money end)
    rawset(_G, "C_CurrencyInfo", { GetCurrencyInfo = function(id)
        local c = env.currency[id]
        if c == nil then return { quantity = 1e6 } end
        return c or nil
    end })
    rawset(_G, "C_Item", {
        GetItemCount = function(id) return env.count[id] or 1e6 end,
        GetItemNameByID = function(id) return env.names[id] end,
        RequestLoadItemDataByID = function() end,
    })
    rawset(_G, "C_HousingCatalog", {
        GetCatalogEntryInfoByItem = function(id)
            env.catalogCalls = env.catalogCalls + 1
            return env.catalog[id]
        end,
        GetCatalogEntryInfoByRecordID = function() return nil end,
    })
    rawset(_G, "C_Map", {
        GetBestMapForUnit = function() return env.playerMap end,
        GetMapInfo = function(id) return env.maps[id] end,
        GetMapChildrenInfo = function() return {} end,
    })
    local HA = {
        Addon = { db = {
            global = { catalogItems = {}, schemaVersion = 7, scannedVendors = {}, noDecorVendors = {} },
            profile = { vendorTracer = { showEventVendors = true } },
        }, Debug = function() end, RegisterModule = function() end },
        Events = { Fire = function() end },
        Constants = { ZoneToFactionMap = {}, TEXTURE_ROOT = "", Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
        DecorMapping = {}, EventSources = { EventVendors = {} },
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
        IsThemeActive = function(_, theme)
            if theme == nil then return nil end
            return env.themes[theme]
        end,
        IsVendorActive = function()
            env.vendorActiveCalls = env.vendorActiveCalls + 1
            return true
        end,
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
        GetScannedVendorItems = function(_, npcID, itemID) return env.scanned[npcID .. ":" .. itemID] end,
        GetMergedItemIDs = function(_, v) return v.items end,
    }
    for _, file in ipairs({ "Locale/enUS.lua", "Data/CatalogStore.lua", "Data/SourceManager.lua",
        "UI/VendorFilter.lua", "UI/Browser/Style.lua", "UI/Browser/Adapter.lua", "UI/Browser/Facts.lua",
        "UI/Browser/CanGet.lua" }) do
        assert(loadfile(root .. "/" .. file))("Homestead", HA)
    end
    local SM = HA.SourceManager
    SM.GetAllSources = function(_, id) return env.sources[id] or {} end
    SM.GetRequirements = function(_, id, npcID) return env.reqs[id .. ":" .. tostring(npcID)] or {} end
    local isMet = SM.IsRequirementMet
    SM.IsRequirementMet = function(self, req)
        if req.met ~= nil then return req.met end
        return isMet(self, req)
    end
    HA.CatalogStore:Initialize()

    -- A not-owned decor item with a name and a readable entry.
    function env.decor(itemID, entry)
        HA.DecorMapping[itemID + 900000] = itemID
        env.catalog[itemID] = entry or { totalNumStored = 0 }
        env.names[itemID] = env.names[itemID] or ("Item " .. itemID)
    end
    function env.vendor(npcID, fields)
        local v = fields or {}
        v.npcID, v.mapID, v.items = npcID, v.mapID or 1, v.items or {}
        env.vendors[npcID] = v
        return v
    end
    function env.sell(itemID, v, cost)
        local list = env.sources[itemID] or {}
        list[#list + 1] = { type = "vendor", data = { npcID = v and v.npcID, vendor = v, cost = cost or { gold = 100 } } }
        env.sources[itemID] = list
        env.offers[itemID] = true
        if v then v.items[#v.items + 1] = itemID end
    end
    return env, HA, HA.DecorBrowser.Data, HA.DecorBrowser.CanGet
end

-- A fresh world: the real browser modules over stubbed data, the real Widgets over recording frames, and the
-- Sources tab built and registered.
local function reset()
    made, all, boxes, views, scrolls, timers = {}, {}, {}, {}, {}, {}
    portraitCalls = {}
    combat = false
end

local function setup()
    reset()
    local env, HA, D, CG = newEnv()
    env.records, env.stats, env.prewarm, env.reports, env.waypoints = {}, {}, 0, {}, {}
    env.went = {}
    env.maps = {
        [100] = { name = "Kalimdor", mapType = 2, parentMapID = 0 },
        [200] = { name = "Eastern Kingdoms", mapType = 2, parentMapID = 0 },
        [10] = { name = "Stormwind", mapType = 3, parentMapID = 200 },
        [11] = { name = "Elwynn Forest", mapType = 3, parentMapID = 200 },
        [20] = { name = "Orgrimmar", mapType = 3, parentMapID = 100 },
    }
    env.playerMap = 10
    local C_Item = rawget(_G, "C_Item")
    C_Item.GetItemQualityByID = function() return 2 end
    C_Item.GetItemIconByID = function() return 1 end
    HA.Constants.VERSION = "9.9.9"
    for _, name in ipairs({ "AchievementSources", "QuestSources", "ProfessionSources", "DropSources", "ShopSources",
        "VendorPortraits", "QuestStarts", "TreasureHuntSpots" }) do
        HA[name] = {}
    end
    local VD = HA.VendorData
    function VD.GetAllVendors()
        local out = {}
        for _, v in pairs(env.vendors) do out[#out + 1] = v end
        for npcID, ev in pairs(HA.EventSources.EventVendors) do
            if env.calendar[ev.event] == true and not env.vendors[npcID] then out[#out + 1] = ev end
        end
        return out
    end
    function VD.GetScannedVendorRecord(_, v) return env.records[v.npcID] end
    HA.BadgeCalculation = {
        PeekVendorStats = function(_, v) return env.stats[v.npcID] end,
        RequestPrewarm = function() env.prewarm = env.prewarm + 1 end,
    }
    HA.OutputWindow = { Show = function(_, title, text) env.reports[#env.reports + 1] = { title = title, text = text } end }
    HA.Waypoints = { Set = function(_, mapID, x, y, o) env.waypoints[#env.waypoints + 1] = { mapID, x, y, o } end }
    HA.PerformanceTrace.Measure = function(_, op, workload, fn, ...)
        env.measured[#env.measured + 1] = op
        return fn(...)
    end

    for _, file in ipairs({ "Visuals", "Widgets" }) do
        assert(loadfile(root .. "/UI/Browser/" .. file .. ".lua"))("Homestead", HA)
    end
    local B = HA.DecorBrowser
    local pages, gen = {}, 1
    B.State = { hideNA = false, inCombat = false, generation = 1, noPrewarm = false, catalogMemo = {} }
    env.walkCalls = 0
    B.Walk = function()
        env.walkCalls = env.walkCalls + 1
        return CG.Walk()
    end
    B.Generation = function() return gen end
    B.RegisterPage = function(kind, page) pages[kind] = page end
    B.Go = function(route) env.went[#env.went + 1] = route end
    B.Tooltip = function()
        return { SetOwner = noop, SetText = function(_, t) env.tip = t end, Show = noop }
    end
    env.linkTips, env.achLinks, env.questLinks = {}, {}, {}
    B.ShowLinkTooltip = function(owner, link) env.linkTips[#env.linkTips + 1] = { owner = owner, link = link } end
    rawset(_G, "GetAchievementLink", function(id) return env.achLinks[id] end)
    rawset(_G, "GetQuestLink", function(id) return env.questLinks[id] end)
    -- Nothing on the Sources pages opens the achievement journal.
    rawset(_G, "ShowAchievementFrameForAchievement", function() error("the achievement journal opened") end)
    B.HideTooltip, B.HideTooltipFor = noop, noop
    env.search = ""
    B.Window = { AddSearchBox = noop, Slide = noop, StopSlide = noop, hideNA = Widget("CheckButton"), SetSearch = function(text) env.search = text or "" end }
    B.SetHideNA = function(on)
        B.State.hideNA = on
        env.hideNASet = on
        pages.sources:Refresh("hide")
    end
    local path = root .. "/UI/Browser/Sources.lua"
    local before = #all
    assert(loadfile(path))("Homestead", HA)
    env.framesAtLoad = #all - before
    env.pages, env.vpage, env.spage, env.B, env.W = pages, pages.vendor, pages.source, B, B.Widgets
    -- What a sources route with a seed goes to; the header box takes the seed's search, or is cleared, first.
    -- This harness sends { type = "vendors", select } to allVendors; the real router sends it to the vendor page.
    -- A pick of any other type goes to the source page, built on first use, as the router does.
    local tab = {}
    function tab.Show(opts)
        if opts and opts.type ~= "vendors" and opts.select then
            if not env.spageFrame then
                env.spageFrame = Widget("Page")
                pages.source:Build(env.spageFrame)
            end
            pages.source:Show({ kind = "source", key = opts.type, id = opts.select.key })
            return
        end
        local route = opts and opts.type == "vendors" and { kind = "allVendors", seed = opts }
            or { kind = "sources", key = opts and opts.type, seed = opts }
        B.Window.SetSearch(opts and opts.search)
        pages[route.kind]:Show(route)
    end
    function tab.Build(parent) pages.sources:Build(parent) end
    function tab.Refresh(reason) pages.sources:Refresh(reason) end
    function tab.Hide() pages.sources:Hide() end
    function tab.SetCombat(on) pages.sources:SetCombat(on) end
    function tab.Filter(text) pages.sources:Filter(text) end
    env.tab = tab
    function env.bump() gen = gen + 1 end
    env.D, env.CG, env.HA = D, CG, HA
    return env
end

-- Sample world: four vendors, one of each other source, an event.
local function world(env)
    local HA = env.HA
    local here = env.vendor(100, { name = "Anna", zone = "Stormwind", subzone = "Trade District", mapID = 10, scanConfirmed = "2026-10-01" })
    local elwynn = env.vendor(101, { name = "Bran", zone = "Elwynn Forest", mapID = 11, faction = "Alliance" })
    local horde = env.vendor(102, { name = "Cora", zone = "Orgrimmar", mapID = 20, faction = "Horde" })
    local lost = env.vendor(103, { name = "Dale", zone = "Nowhere" })
    lost.mapID = nil
    for id = 1, 3 do env.decor(id) env.sell(id, here) end
    env.decor(4) env.sell(4, elwynn)
    env.decor(5) env.sell(5, horde)
    env.decor(6) env.sell(6, lost)
    env.decor(11)
    HA.AchievementSources[11] = { achievementID = 9001, achievementName = "Ach A", category = "Catb" }
    env.decor(12)
    HA.AchievementSources[12] = { achievementID = 9002, achievementName = "Ach B", category = "Cata" }
    env.decor(21)
    HA.QuestSources[21] = { questID = 7001, questName = "Quest One" }
    HA.QuestStarts[7001] = { mapID = 10, x = 0.5, y = 0.6 }
    env.decor(22)
    HA.QuestSources[22] = { questID = 7002, questName = "Decor Treasure Hunt" }
    HA.TreasureHuntSpots[7002] = { mapID = 11, x = 0.2, y = 0.3 }
    env.decor(31)
    HA.ProfessionSources[31] = { profession = "Tailoring", recipeName = "Rug", spellID = 8001, skillTier = "Classic Tailoring" }
    env.decor(32)
    HA.ProfessionSources[32] = { profession = "Cooking", recipeName = "Stew", spellID = 8002, skillTier = "Classic Cooking" }
    env.decor(41)
    HA.DropSources[41] = { mobName = "Boss", zone = "Keep", mapID = 10, coords = { x = 0.1, y = 0.2 }, notes = "Rare." }
    env.decor(51)
    HA.EventSources[51] = { event = "Hallow's End" }
    env.decor(52)
    HA.EventSources[52] = { event = "Noblegarden" }
    env.decor(61)
    HA.ShopSources[61] = { method = "hearthsteel" }
    return { here = here, elwynn = elwynn, horde = horde, lost = lost }
end

local function build(env)
    env.tab.Build(Widget("Page"))
    return boxes[1], boxes[2]
end

local function rows(box)
    local out = {}
    for _, d in ipairs(rawget(box, "data") or {}) do
        if d.kind == "row" then out[#out + 1] = d end
    end
    return out
end

local function row(box, key)
    for _, d in ipairs(rawget(box, "data") or {}) do
        if d.key == key then return d end
    end
end

local function shownText(sub)
    for _, fs in ipairs(made) do
        if fs.shown and fs.text:find(sub, 1, true) then return fs.text end
    end
end

-- True when w is top or sits under it with nothing hidden on the way.
local function within(w, top)
    while w do
        if rawget(w, "shown") == false then return false end
        if w == top then return true end
        w = rawget(w, "parent")
    end
    return false
end

-- The text of the shown font string on the source page that has exactly this text, or contains it.
local function pageText(env, text, plain)
    for _, fs in ipairs(made) do
        if fs.shown and within(fs, env.spageFrame) and (fs.text == text or plain and fs.text:find(text, 1, true)) then
            return fs.text
        end
    end
end

-- The source page's lines that carry a waypoint icon, shown, in build order: subtitle, starts, dig site.
local function pinLines(env)
    local out = {}
    for _, w in ipairs(all) do
        if w.kind == "Frame" and rawget(w, "wp") and w.shown and within(w, env.spageFrame) then out[#out + 1] = w end
    end
    return out
end

local function same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

local function walks(env)
    local n = 0
    for _, op in ipairs(env.measured) do if op == "browser_walk" then n = n + 1 end end
    return n
end

-- What the router does when data changed: new memo generation, empty catalog memo.
local function invalidate(env)
    env.D.InvalidateMemos()
    for k in pairs(env.B.State.catalogMemo) do env.B.State.catalogMemo[k] = nil end
end

local function keyList(box)
    local out = {}
    for _, d in ipairs(box.data) do out[#out + 1] = d.kind == "header" and ("# " .. d.text) or tostring(d.key or d.kind) end
    return out
end

local function frameWith(pred)
    for _, w in ipairs(all) do
        if pred(w) then return w end
    end
end

local function button(text)
    return frameWith(function(w)
        return w.kind == "Button" and (w.text == text or type(w.text) == "table" and w.text.text == text)
    end)
end

-- The drawn "N of M collected" at the head of the list.
local function headText()
    for i = #all, 1, -1 do
        local w = all[i]
        if w.kind == "FontString" and (w.text:find("^%d+ of %d+ collected$") or w.text == "Counting…") then return w.text end
    end
end

local function allItemsOwned(env)
    for id in pairs(env.catalog) do env.catalog[id] = { totalNumStored = 1 } end
end

-------------------------------------------------------------------------------
-- Nothing is created before first open
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    assert(env.framesAtLoad == 0, "loading Sources.lua created frames")
    assert(env.vpage, "the vendor page registers itself")
    build(env)
    print("hs538_sources: lazy creation ok")
end

-------------------------------------------------------------------------------
-- Counts and grouping
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    local main = build(env)
    env.tab.Show({ type = "vendors" })
    assert(same(keyList(main), { "# Other Vendors", "# Elwynn Forest", "101", "# Nowhere", "103", "# Orgrimmar", "102",
        "# Stormwind", "100" }), "vendor groups: " .. table.concat(keyList(main), ","))
    local heads = {}
    for _, t in ipairs({ "vendors", "achievements", "quests", "professions", "drops", "events", "shop" }) do
        env.tab.Show({ type = t })
        heads[#heads + 1] = headText()
    end
    assert(same(heads, { "0 of 6 collected", "0 of 2 collected", "0 of 2 collected", "0 of 2 collected", "0 of 1 collected", "0 of 2 collected", "0 of 1 collected" }), "heads: " .. table.concat(heads, ";"))

    env.tab.Show({ type = "achievements" })
    assert(same(keyList(main), { "# Cata", "9002", "# Catb", "9001" }), "achievements by category")
    env.tab.Show({ type = "professions" })
    assert(same(keyList(main), { "# Cooking", "8002", "# Tailoring", "8001" }), "professions by profession")
    env.tab.Show({ type = "quests" })
    assert(same(keyList(main), { "7002", "7001" }), "quests are ungrouped and sorted by title")
    env.tab.Show({ type = "events" })
    assert(keyList(main)[1] == "foot", "no event active shows the empty-events note first")
    assert(main.data[1].text == "No events active right now. Event decor is sold only while its event runs.")
    assert(same({ keyList(main)[2], keyList(main)[3] }, { "Hallow's End", "Noblegarden" }))
    env.calendar["Noblegarden"] = true
    invalidate(env)
    env.tab.Refresh("data")
    assert(same(keyList(main), { "Noblegarden", "Hallow's End" }), "an active event sorts first and the note goes")
    assert(row(main, "Noblegarden").state == "live" and row(main, "Hallow's End").state == "idle")
    print("hs538_sources: heads, grouping and events ok")
end

-------------------------------------------------------------------------------
-- Row words
-------------------------------------------------------------------------------

do
    local env = setup()
    local v = world(env)
    local main = build(env)
    env.vendor(104, { name = "Eve", zone = "Stormwind", mapID = 10 })
    env.tab.Show({ type = "vendors" })
    local anna = row(main, 100)
    assert(anna.state == "some" and anna.arg == 3 and anna.right == "3 decor", "stats nil: " .. tostring(anna.right))
    assert(row(main, 104).right == "No decor")
    assert(row(main, 102).state == "faction" and row(main, 102).arg == "Horde", "other faction reads red words")
    assert(row(main, 101).unconfirmed == true and not anna.unconfirmed, "Not confirmed only without a signal")
    env.records[101] = { lastScanned = os.time() }
    env.stats[100] = { collected = 1, total = 3 }
    env.tab.Refresh("stats")
    assert(row(main, 100).right == "1 of 3", "stats arrive: " .. tostring(row(main, 100).right))
    assert(not row(main, 101).unconfirmed, "the player's own scan clears Not confirmed")
    -- All collected follows the rule Hide uses: every ware owned, never the counts alone or an unknown ware.
    env.stats[100] = { collected = 3, total = 3 }
    env.tab.Refresh("stats")
    assert(row(main, 100).state == "some", "the counts alone read All collected")
    local saved = { env.catalog[1], env.catalog[2], env.catalog[3] }
    env.catalog[1], env.catalog[2], env.catalog[3] = { totalNumStored = 1 }, { totalNumStored = 1 }, nil
    invalidate(env)
    env.tab.Refresh("data")
    assert(row(main, 100).state ~= "allDone" and env.CG.HiddenBy({ vendor = v.here }) == nil, "a ware of unknown ownership")
    env.catalog[3] = { totalNumStored = 1 }
    invalidate(env)
    env.tab.Refresh("data")
    assert(row(main, 100).state == "allDone" and env.CG.HiddenBy({ vendor = v.here }) == "collected", "every ware collected")
    env.catalog[1], env.catalog[2], env.catalog[3] = saved[1], saved[2], saved[3]
    invalidate(env)
    env.tab.Refresh("data")
    env.done, env.attempted = false, false
    env.tab.Refresh("stats")
    assert(row(main, 101).state == "counting" and row(main, 101).right == "1 decor", "counting reads N decor")
    assert(v.here.npcID == 100)
    print("hs538_sources: row words ok")
end

-------------------------------------------------------------------------------
-- The head is the By source count; it waits for the collection; the empty state sits under it
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    env.sell(99, env.vendors[100])
    local main = build(env)
    env.tab.Show({ type = "vendors" })
    local p = env.CG.Walk().progress.src.vendors
    assert(p.total == 6, "a ware that is not decor is outside the By source count: " .. p.total)
    assert(headText() == ("%d of %d collected"):format(p.owned, p.total), "the head is the By source count: " .. tostring(headText()))
    env.done, env.attempted = false, false
    env.tab.Refresh("stats")
    assert(headText() == "Counting…", "the head waits for the collection: " .. tostring(headText()))
    local head, empty
    for _, w in ipairs(all) do
        if w.kind == "FontString" and w.text == "Counting…" and not head then head = w end
        if rawget(w, "title") and rawget(w, "text") and w.kind == "Frame" and not empty then empty = w end
    end
    assert(empty and head and empty.parent == main.parent and empty.parent ~= head.parent,
        "the empty state is under the list holder, not the well the head draws in")
    print("hs538_sources: head count, counting and empty state ok")
end

-------------------------------------------------------------------------------
-- Rendered row words (the kinds are pooled with distinct frame types)
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    build(env)
    local factory = views[1].factory
    local seen = {}
    local function render(data)
        local out
        factory(function(frameType, init)
            out = Widget(frameType)
            out.built = false
            seen[data.kind] = frameType
            init(out, data)
        end, data)
        return out
    end
    made = {}
    render({ kind = "row", name = "X", state = "allDone", noTile = true, right = "3 of 3" })
    render({ kind = "row", name = "X", state = "idle", noTile = true })
    render({ kind = "row", name = "X", state = "live", noTile = true })
    render({ kind = "row", name = "X", state = "some", arg = 2, noTile = true })
    render({ kind = "row", name = "X", state = "faction", arg = "Horde", noTile = true })
    local words = {}
    for _, fs in ipairs(made) do words[fs.text] = fs end
    assert(words["All collected"] and words["Not active"] and words["Active now"] and words["2 can get now"])
    assert(words["Horde only"].color[1] == env.B.Style.color.stop[1], "the other faction is red")
    for _, k in ipairs({ "All collected", "Not active", "Active now", "2 can get now" }) do
        assert(words[k].color[1] ~= env.B.Style.color.stop[1], k .. " must not be red")
    end
    local foot = render({ kind = "foot", hidden = 2, collected = 1, faction = 1, factionName = "Horde", onShow = noop })
    assert(foot.text.text == "2 hidden by 'Hide collected and other-faction' (1 collected, 1 Horde only)." and foot.link.shown)
    local note = render({ kind = "foot", text = "No events" })
    assert(not note.link.shown, "the empty-events note has no Show them link")
    render({ kind = "header", text = "Kalimdor" })
    assert(seen.row == "Button" and seen.header ~= seen.foot and seen.row ~= seen.header and seen.row ~= seen.foot,
        "list kinds need distinct frame types")
    print("hs538_sources: pooled kinds and rendered words ok")
end

-------------------------------------------------------------------------------
-- Vendor page: the head, location, shared lines, count line and wares, drawn by the
-- page the Sources file registers for the vendor route
-------------------------------------------------------------------------------

local function vendorPage(env)
    env.vpage:Build(Widget("Page"))
    return boxes[#boxes]
end

do
    local env = setup()
    local v = world(env)
    v.here.x, v.here.y = 0.4, 0.5
    env.HA.VendorPortraits[100] = 555
    local grid = vendorPage(env)
    env.vpage:Show({ kind = "vendor", id = 100 })
    assert(shownText("Anna"), "the head names the vendor")
    assert(shownText("Trade District, Stormwind"), "subzone and zone")
    assert(not shownText("Eastern Kingdoms"), "the player's own continent is not repeated")
    assert(not shownText("Not confirmed"), "the shipped confirmation date counts")
    assert(shownText("0 of 3 collected") and shownText("3 can get now"), "the count line and the can-get line")
    assert(portraitCalls[#portraitCalls] == 555, "the headshot comes from the portrait table")
    assert(#grid.data == 3 and grid.data[1].state == "can" and grid.data[1].npcID == 100, "the wares")

    env.records[100] = { lastScanned = os.time({ year = 2026, month = 9, day = 1, hour = 12 }) }
    env.vpage:Refresh("data")
    assert(not shownText("Not confirmed"), "an older scan does not take the confirmation away")

    local wp = frameWith(function(w) return w.kind == "Button" and rawget(w, "wp") ~= nil end)
    assert(wp and wp.shown and wp.wp.mapID == 10, "the waypoint targets the vendor")
    wp.scripts.OnClick(wp)
    assert(env.waypoints[1][1] == 10 and env.waypoints[1][4].title == "Anna" and env.waypoints[1][4].data.npcID == 100)

    env.vpage:Show({ kind = "vendor", id = 101 })
    assert(shownText("Not confirmed: visit to check."), "the Not confirmed line")
    assert(not wp.shown, "no location, no waypoint button")
    assert(not shownText("Kalimdor"), "Elwynn is on the player's continent")
    env.records[101] = { lastScanned = os.time() }
    env.vpage:Refresh("data")
    assert(not shownText("Not confirmed"), "the player's own scan clears Not confirmed")
    env.vpage:Show({ kind = "vendor", id = 102 })
    assert(shownText("Horde only: can't buy on this character"), "the faction stop line")
    assert(shownText("Orgrimmar · Kalimdor"), "another continent is named")
    env.vpage:Show({ kind = "vendor", id = 103 })
    assert(not shownText("Horde only"), "the stop line is gone")
    print("hs538_sources: vendor page ok")
end

-------------------------------------------------------------------------------
-- Rows open pages: a vendor row the vendor page, any other row the page of its source, a decor row its item
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    local main = build(env)
    env.tab.Show({ type = "vendors" })
    row(main, 100).onClick()
    assert(#env.went == 1 and env.went[1].kind == "vendor" and env.went[1].id == 100, "a vendor row opens its page")
    for _, t in ipairs({ { "achievements", 9001 }, { "quests", 7001 }, { "professions", 8001 }, { "drops", "Boss|Keep" },
        { "events", "Noblegarden" } }) do
        env.tab.Show({ type = t[1] })
        local before = #env.went
        row(main, t[2]).onClick()
        local go = env.went[#env.went]
        assert(#env.went == before + 1 and go.kind == "source" and go.key == t[1] and go.id == t[2] and go.seed == nil,
            t[1] .. ": a source row opens the source's page")
    end
    env.tab.Show({ type = "shop" })
    rows(main)[1].onClick()
    assert(env.went[#env.went].key == "shop" and env.went[#env.went].id == 61, "a Shop row opens its page")
    env.tab.Show({ type = "quests", select = { key = 7001 } })
    local decor = rows(boxes[#boxes])[1]
    assert(decor and decor.itemID, "the source page lists its decor")
    decor.onClick()
    local go = env.went[#env.went]
    assert(go.kind == "item" and go.id == decor.itemID and go.key == nil and go.seed == nil,
        "a decor row on a source page opens the item's page")
    print("hs538_sources: row routes ok")
end

-------------------------------------------------------------------------------
-- The source page: head, kind named once, where it starts, event status, drop notes
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    local main = build(env)
    env.tab.Show({ type = "quests", select = { key = 7001 } })
    local lines = pinLines(env)
    assert(#lines == 2, "the subtitle and the start line carry a waypoint slot: " .. #lines)
    local sub, start = lines[1], lines[2]
    assert(pageText(env, "Quest One") and sub.text.text == "Quest · Stormwind", "the head names the quest and the kind once: " .. sub.text.text)
    assert(not sub.wp.shown, "a quest's subtitle has no waypoint")
    assert(start.text.text == "Starts in Stormwind", "quest start line")
    assert(start.wp.wp.mapID == 10 and start.wp.wp.x == 0.5 and start.wp.wp.y == 0.6, "the line's spot")
    start.wp.scripts.OnClick(start.wp)
    assert(env.waypoints[1][1] == 10 and env.waypoints[1][2] == 0.5 and env.waypoints[1][4].title == "Quest One",
        "the line's waypoint is set")
    env.tab.Show({ type = "quests", select = { key = 7002 } })
    lines = pinLines(env)
    assert(#lines == 2 and lines[2].text.text == "Dig site in Elwynn Forest", "dig site line")
    assert(lines[2].wp.wp.mapID == 11 and lines[2].wp.wp.x == 0.2 and lines[2].wp.wp.y == 0.3)
    assert(not pageText(env, "Starts in", true), "a dig site has no start line")
    assert(not shownText("Not confirmed"), "no Not confirmed for a non-vendor")
    env.tab.Show({ type = "quests" })
    assert(not row(main, 7002).unconfirmed)
    assert(not shownText("Gives 1 decor.") and not shownText("Sells"), "the old summary sentence is gone")

    env.tab.Show({ type = "drops", select = { key = "Boss|Keep" } })
    lines = pinLines(env)
    assert(#lines == 1 and lines[1].text.text == "Drop · Keep", "a drop's subtitle")
    assert(lines[1].wp.shown and lines[1].wp.wp.mapID == 10 and lines[1].wp.wp.x == 0.1 and lines[1].wp.wp.title == "Boss",
        "a drop with coordinates has a waypoint at the end of the subtitle")
    assert(pageText(env, "Rare.", true), "the drop's notes show")
    lines[1].wp.scripts.OnClick(lines[1].wp)
    assert(env.waypoints[2][1] == 10 and env.waypoints[2][2] == 0.1, "and it sets the drop's waypoint")

    env.tab.Show({ type = "events", select = { key = "Noblegarden" } })
    assert(pinLines(env)[1].text.text == "Holiday event", "an event's subtitle already names the kind")
    assert(pageText(env, "Not active"), "an idle event says so")
    assert(not pageText(env, "Active now", true) and #pinLines(env) == 1 and not pinLines(env)[1].wp.shown,
        "and has no waypoint")
    env.calendar["Noblegarden"] = true
    invalidate(env)
    env.tab.Show({ type = "events", select = { key = "Noblegarden" } })
    assert(pageText(env, "Active now", true) and not pageText(env, "Not active"), "a running event says Active now")
    print("hs538_sources: source page ok")
end

-------------------------------------------------------------------------------
-- A quest with no zone reads "Location not recorded", and the kind is named once
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    env.decor(23)
    env.HA.QuestSources[23] = { questID = 7003, questName = "Quest Lost" }
    local main = build(env)
    env.tab.Show({ type = "quests" })
    assert(row(main, 7003).line2 == "Location not recorded", "the list subtitle: " .. tostring(row(main, 7003).line2))
    assert(row(main, 7001).line2 == "Stormwind", "a quest with a zone keeps it")
    env.tab.Show({ type = "quests", select = { key = 7003 } })
    assert(pinLines(env)[1].text.text == "Quest · Location not recorded", "the page names the kind once")
    assert(#pinLines(env) == 1, "no start or dig line without a spot")
    env.tab.Show({ type = "achievements", select = { key = 9001 } })
    assert(pinLines(env)[1].text.text == "Achievement · Catb", "a category follows the kind")
    env.tab.Show({ type = "shop", select = { key = 61 } })
    assert(pinLines(env)[1].text.text == "Shop", "a subtitle that is the kind is not repeated")
    print("hs538_sources: kind named once ok")
end

-------------------------------------------------------------------------------
-- "M of N collected" and "Counting…" on the source page; the can-get line
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    -- Anna sells item 1, so this achievement's one piece of decor can be had now.
    env.HA.AchievementSources[1] = { achievementID = 9010, achievementName = "Ach Anna", category = "Cata" }
    build(env)
    env.tab.Show({ type = "achievements", select = { key = 9010 } })
    assert(pageText(env, "0 of 1 collected"), "the page counts its own decor")
    assert(pageText(env, "1 can get now"), "the can-get line")
    allItemsOwned(env)
    invalidate(env)
    env.spage:Refresh("data")
    assert(pageText(env, "1 of 1 collected") and not pageText(env, "can get now", true), "owned decor counts and the line goes")
    env.done, env.attempted = false, false
    invalidate(env)
    env.spage:Refresh("stats")
    assert(pageText(env, "Counting…") and not pageText(env, "of 1 collected", true), "the page waits for the collection")
    print("hs538_sources: collected count ok")
end

-------------------------------------------------------------------------------
-- A locked item reads "Not collected" on the page of its own requirement, and only there
-------------------------------------------------------------------------------

do
    local env = setup()
    local v = world(env)
    local HA = env.HA
    env.decor(71)
    env.sell(71, v.here)
    HA.AchievementSources[71] = { achievementID = 9005, achievementName = "Ach Own", category = "Cata" }
    env.reqs["71:100"] = { { type = "achievement", id = 9005, name = "Ach Own", met = false } }
    -- The same requirement, known by its name only, as the shipped prerequisite data has it.
    env.decor(72)
    env.sell(72, v.here)
    HA.AchievementSources[72] = { achievementID = 9007, achievementName = "Ach Named", category = "Cata" }
    env.reqs["72:100"] = { { type = "achievement", name = "Ach Named", met = false } }
    -- Locked by something else, on the page of an achievement.
    HA.AchievementSources[3] = { achievementID = 9006, achievementName = "Ach Other", category = "Cata" }
    env.reqs["3:100"] = { { type = "unknown", text = "Mysterious Favor" } }
    -- Locked by its own achievement and by something else.
    env.decor(73)
    env.sell(73, v.here)
    HA.AchievementSources[73] = { achievementID = 9008, achievementName = "Ach Both", category = "Cata" }
    env.reqs["73:100"] = { { type = "achievement", id = 9008, met = false }, { type = "unknown", text = "Mysterious Favor" } }
    -- The right requirement type under another source's number and name.
    env.decor(74)
    env.sell(74, v.here)
    HA.QuestSources[74] = { questID = 9005, questName = "Quest Same Number" }
    env.reqs["74:100"] = { { type = "achievement", id = 9005, met = false } }
    build(env)
    local function state(t, key, itemID)
        env.tab.Show({ type = t, select = { key = key } })
        local box = boxes[#boxes]
        for _, d in ipairs(box.data) do
            if d.itemID == itemID then return d.state, d.arg end
        end
    end
    assert(env.B.ItemState(71) == "locked", "the item is locked at its vendor")
    local s = state("achievements", 9005, 71)
    assert(s == "notOwned", "locked only by this achievement: Not collected here, got " .. tostring(s))
    assert(env.B.ItemState(71) == "locked", "and still Locked everywhere else")
    s = state("achievements", 9007, 72)
    assert(s == "notOwned", "a requirement known by name matches the page's title: " .. tostring(s))
    local arg
    s, arg = state("achievements", 9006, 3)
    assert(s == "locked" and arg == "Mysterious Favor", "another unmet requirement keeps Locked: " .. tostring(s))
    s = state("achievements", 9008, 73)
    assert(s == "locked", "one matching requirement among others keeps Locked: " .. tostring(s))
    s = state("quests", 9005, 74)
    assert(s == "locked", "an achievement requirement does not read as the quest of the same number: " .. tostring(s))
    env.reqs["71:100"][1].met = true
    invalidate(env)
    s = state("achievements", 9005, 71)
    assert(s == "can", "a met requirement is no longer a lock: " .. tostring(s))
    print("hs538_sources: own requirement ok")
end

-------------------------------------------------------------------------------
-- Achievement and quest rows show the game's tooltip on hover; nothing opens the journal
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    local main = build(env)
    local factory = views[1].factory
    local function hover(d)
        local frame
        factory(function(frameType, init)
            frame = Widget(frameType)
            frame.built = false
            init(frame, d)
        end, d)
        frame.scripts.OnEnter(frame)
        return frame
    end
    env.achLinks[9001] = "|cffffff00|Hachievement:9001:0:0:0:0:0:0:0:0:0:0|h[Ach A]|h|r"
    env.questLinks[7002] = "|cffffff00|Hquest:7002:80|h[Quest Two]|h|r"
    env.tab.Show({ type = "achievements" })
    local frame = hover(row(main, 9001))
    assert(#env.linkTips == 1 and env.linkTips[1].owner == frame and env.linkTips[1].link == env.achLinks[9001],
        "an achievement row shows the achievement's tooltip from its link")
    hover(row(main, 9002))
    assert(env.linkTips[2].link == nil, "an achievement the game has no link for asks for none")
    env.tab.Show({ type = "quests" })
    hover(row(main, 7002))
    assert(env.linkTips[3].link == env.questLinks[7002], "a quest row shows the quest's tooltip from its link")
    hover(row(main, 7001))
    assert(env.linkTips[4].link == "quest:7001", "a quest with no link falls back to quest:id")
    env.tab.Show({ type = "professions" })
    hover(row(main, 8001))
    env.tab.Show({ type = "vendors" })
    hover(row(main, 100))
    assert(#env.linkTips == 4, "other rows ask for no link tooltip")
    -- Clicking selects nothing and opens no journal; the rows' pages show no journal control either.
    env.tab.Show({ type = "achievements" })
    row(main, 9001).onClick()
    env.tab.Show({ type = "achievements", select = { key = 9001 } })
    local f = assert(io.open(root .. "/UI/Browser/Sources.lua", "rb"))
    local src = f:read("*a")
    f:close()
    assert(not src:find("ShowAchievementFrame", 1, true), "Sources refers to the achievement journal")
    print("hs538_sources: row tooltips ok")
end

-------------------------------------------------------------------------------
-- A source of every type opens its page, which names it; a list ignores a select seed
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    env.names[61] = "Shop Thing"
    local main = build(env)
    local picks = {
        { "achievements", 9002, "Ach B" }, { "quests", 7002, "Decor Treasure Hunt" },
        { "professions", 8002, "Stew" }, { "drops", "Boss|Keep", "Boss" }, { "events", "Noblegarden", "Noblegarden" },
        { "shop", 61, "Shop Thing" },
    }
    local spage = env.pages.source
    for _, p in ipairs(picks) do
        local t, key, title = p[1], p[2], p[3]
        env.tab.Show({ type = t, select = { key = key } })
        assert(pageText(env, title), t .. ": the page names " .. title)
        assert(spage:Has({ kind = "source", key = t, id = key }), t .. ": the page has its source")
        assert(not spage:Has({ kind = "source", key = t, id = "missing" }), t .. ": and not a missing one")
        assert(env.B.SourceTitle(t, key) == title, t .. ": the crumb names it " .. title)

        env.tab.Show({ type = t, search = "zzz" })
        assert(env.search == "zzz" and main.shown == false, t .. ": a search with no matches")
        local before = #scrolls
        env.pages.sources:Show({ kind = "sources", key = t, seed = { select = { key = key } } })
        assert(env.search == "" and #rows(main) > 0, t .. ": a select seed shows the whole list in an empty box")
        for _, r in ipairs(rows(main)) do assert(r.selected == nil, t .. ": a select seed lights row " .. tostring(r.key)) end
        assert(#scrolls == before, t .. ": and scrolls nowhere")
    end
    assert(not spage:Has({ kind = "source", key = "vendors", id = 100 }), "a vendor is not a source page")
    assert(not spage:Has({ kind = "source", key = "nowhere", id = 1 }), "nor a type that does not exist")
    assert(env.B.SourceTitle("quests", "missing") == "Unknown", "a source that is gone reads Unknown in the crumb")
    env.tab.Show({ type = "achievements" })
    env.tab.Show(nil)
    assert(#rows(main) == 2, "a plain switch keeps the type")
    print("hs538_sources: source pages and landings ok")
end

-------------------------------------------------------------------------------
-- Hide: counts unchanged, the footer, nothing unknown hidden, pinned landings
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    env.catalog[1], env.catalog[2], env.catalog[3] = { totalNumStored = 1 }, { totalNumStored = 1 }, { totalNumStored = 1 }
    local main = build(env)
    env.tab.Show({ type = "vendors" })
    env.B.SetHideNA(true)
    assert(same(keyList(main), { "# Other Vendors", "# Elwynn Forest", "101", "# Nowhere", "103", "foot" }),
        "Hide drops the collected vendor and the other faction: " .. table.concat(keyList(main), ","))
    local foot = main.data[#main.data]
    assert(foot.hidden == 2 and foot.collected == 1 and foot.faction == 1 and foot.parts[1][1] == 1 and foot.parts[1][2] ~= "" and foot.onShow,
        "the footer splits collected and faction")
    assert(headText() == "3 of 6 collected", "the head never changes under Hide: " .. tostring(headText()))
    foot.onShow()
    assert(env.hideNASet == false and env.B.Window.hideNA.checked == false, "Show them turns the toggle off")
    assert(#rows(main) == 4)

    env.done, env.attempted = false, false
    invalidate(env)
    env.B.SetHideNA(true)
    assert(row(main, 100), "while the collection is unknown nothing is hidden as collected")
    assert(not row(main, 102), "the other faction is still hidden")
    env.done, env.attempted = true, true
    invalidate(env)

    allItemsOwned(env)
    invalidate(env)
    local picks = { { "achievements", 9001 }, { "quests", 7001 },
        { "professions", 8001 }, { "drops", "Boss|Keep" }, { "shop", 61 } }
    for _, p in ipairs(picks) do
        env.tab.Show({ type = p[1], select = { key = p[2] } })
        assert(pageText(env, "Decor from this source"), p[1] .. ": a source Hide would hide still opens its page with its decor")
    end
    assert(env.W.FooterText({ hidden = 3, collected = 1, faction = 2, parts = {} })
        == "3 hidden by 'Hide collected and other-faction' (1 collected).", "the footer prints the whole hidden count")
    env.tab.Show({ type = "achievements" })
    assert(main.shown == false, "everything collected: the empty state")
    local back = button("Show them")
    assert(back and back.shown, "the empty state offers a way to show them")
    assert(not (button("Reset filters") or {}).shown, "with no search there is nothing else to reset")
    back.scripts.OnClick()
    assert(env.hideNASet == false, "and it turns Hide off")
    print("hs538_sources: Hide ok")
end

-------------------------------------------------------------------------------
-- Search, empty state and reset
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    local main = build(env)
    env.tab.Show({ type = "vendors" })
    env.tab.Filter("bran")
    assert(same(keyList(main), { "# Other Vendors", "# Elwynn Forest", "101" }), "search by name")
    env.tab.Filter("stormwind")
    assert(same(keyList(main), { "# Other Vendors", "# Stormwind", "100" }), "search by zone")
    env.tab.Filter("nothing like it")
    assert(main.shown == false and shownText("Nothing matches your search."), "no matches: the empty state")
    local resetBtn = button("Reset filters")
    assert(resetBtn and resetBtn.shown)
    resetBtn.scripts.OnClick()
    assert(env.search == "", "Reset filters clears the header box")
    assert(#rows(main) == 4 and main.shown, "and brings the whole list back with no further typing")
    env.tab.Filter("bran")
    env.tab.Filter("")
    assert(#rows(main) == 4 and main.shown, "clearing the search brings the list back")
    local data = main.data
    env.tab.Filter("")
    assert(main.data == data, "the same text is not filtered again")
    print("hs538_sources: search ok")
end

-------------------------------------------------------------------------------
-- Count fill: rows read N decor, then collected of total; one request, no listener
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    local main = build(env)
    env.tab.Show({ type = "vendors" })
    assert(row(main, 100).right == "3 decor" and env.prewarm == 1, "one fill request for the whole list")
    env.B.State.noPrewarm = true
    env.tab.Refresh("stats")
    assert(env.prewarm == 1, "a fill-triggered refresh never asks again")
    env.B.State.noPrewarm = false
    env.stats[100] = { collected = 1, total = 3 }
    env.tab.Refresh("stats")
    assert(row(main, 100).right == "1 of 3", "the row reads collected of total")
    local f = assert(io.open(root .. "/UI/Browser/Sources.lua", "rb"))
    local src = f:read("*a")
    f:close()
    assert(not src:find("HS_VENDOR_STATS_WARMED", 1, true) and not src:find("RegisterCallback", 1, true)
        and not src:find("RegisterEvent", 1, true), "Sources registers no listener of its own")
    print("hs538_sources: count fill ok")
end

-------------------------------------------------------------------------------
-- Walk discipline: only "data" walks
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    local main = build(env)
    env.tab.Show({ type = "vendors" })
    local n = walks(env)
    assert(n >= 1, "the first draw walked")
    local calls = env.walkCalls
    for _, reason in ipairs({ "zone", "paint", "layout", "hide", "names", "stats" }) do
        env.tab.Refresh(reason)
        assert(walks(env) == n and env.walkCalls == calls, reason .. " repaint walked")
    end
    local before = main.data
    env.tab.Refresh("layout")
    assert(main.data ~= before, "a layout refresh re-sets the list so row heights are measured again")
    invalidate(env)
    env.tab.Refresh("data")
    assert(walks(env) == n + 1 and env.walkCalls == calls + 1, "a data refresh walks once")
    print("hs538_sources: walk discipline ok")
end

-------------------------------------------------------------------------------
-- Report a problem (the vendor and source variants) and the combat gate
-------------------------------------------------------------------------------

do
    local env = setup()
    local v = world(env)
    v.here.x, v.here.y = 0.4, 0.5
    build(env)
    env.vpage:Show({ kind = "vendor", id = 100 })
    env.tab.Show({ type = "achievements", select = { key = 9001 } })
    local reports = {}
    for _, w in ipairs(all) do
        if w.kind == "Button" and (w.text == "Report a problem" or type(w.text) == "table" and w.text.text == "Report a problem") then
            reports[#reports + 1] = w
        end
    end
    assert(#reports == 2, "the source page and the vendor page each have a Report link, the lists none")
    local vreport, report = reports[1], reports[2]
    assert(vreport.enabled ~= false and vreport.shown)
    vreport.scripts.OnClick()
    local r = env.reports[1]
    assert(r.title == "Report a data error" and r.text:find("Vendor 100: Anna, Stormwind, map 10 at 40.0, 50.0", 1, true)
        and r.text:find("Homestead: 9.9.9", 1, true), "the vendor report")
    assert(report.enabled ~= false and report.shown)
    report.scripts.OnClick()
    assert(env.reports[2].text:find("Achievement: Ach A", 1, true), "the source report")

    env.spage:SetCombat(true)
    assert(report.enabled == false and vreport.enabled ~= false, "the source page's link is disabled in combat")
    env.B.State.inCombat = true
    env.tab.Show({ type = "quests", select = { key = 7001 } })
    assert(report.enabled == false, "a new selection in combat stays disabled")
    Enter(report)
    assert(env.tip == "Not available in combat", "the tooltip says why")
    env.tip = nil
    env.B.State.inCombat = false
    env.spage:SetCombat(false)
    assert(report.enabled == true)
    Enter(report)
    assert(env.tip == nil, "no tooltip out of combat")
    print("hs538_sources: report and combat ok")
end

-------------------------------------------------------------------------------
-- Event vendors: listing, the Active tag and the calendar check agree
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    local HA, D = env.HA, env.D
    local Facts = env.B.Facts
    local events = HA.EventSources.EventVendors
    events[20] = { npcID = 20, name = "Echo", mapID = 10, zone = "Stormwind", event = "Hallow's End", _isEventVendor = true, items = {} }
    events[21] = { npcID = 21, name = "Egg", mapID = 10, zone = "Stormwind", event = "Noblegarden", _isEventVendor = true, items = {} }
    local plain = env.vendors[100]
    for _, calendar in ipairs({ {}, { ["Hallow's End"] = true }, { ["Noblegarden"] = true }, { ["Hallow's End"] = true, ["Noblegarden"] = true } }) do
        env.calendar = calendar
        for npcID, v in pairs(events) do
            local listed = Facts.BrowserListed(v)
            assert(D.HolidayActive(v) == listed, "HolidayActive and BrowserListed disagree for " .. npcID)
            assert(listed == (calendar[v.event] == true))
        end
        assert(D.HolidayActive(plain) == nil, "a plain vendor has no holiday state")
    end
    local calendar = HA.CalendarDetector
    HA.CalendarDetector = nil
    for _, v in pairs(events) do
        assert(D.HolidayActive(v) == false and Facts.BrowserListed(v) == false, "no calendar: neither is active")
    end
    HA.CalendarDetector = calendar

    env.calendar = { ["Hallow's End"] = true }
    local main = build(env)
    env.tab.Show({ type = "vendors" })
    assert(row(main, 20).state == "live" and not row(main, 21), "an active event vendor is listed and tagged Active now")
    env.vpage:Show({ kind = "vendor", id = 20 })
    assert(shownText("Echo") and shownText("Active now"), "the head names the vendor and tags it Active now")
    assert(shownText("Seasonal: Hallow's End"), "the Seasonal note follows the location")
    print("hs538_sources: event vendors ok")
end

-------------------------------------------------------------------------------
-- The shipped holiday vendors: the Active tag and the listing share the calendar check (scope: the
-- calendar; removed and unreleased vendors are listing rules the tag does not carry)
-------------------------------------------------------------------------------

do
    local env = setup()
    local HA, D = env.HA, env.D
    assert(loadfile(root .. "/Data/EventSources.lua"))("Homestead", HA)
    local count = 0
    local names = {}
    for _, v in pairs(HA.EventSources.EventVendors) do names[v.event] = true end
    local states = { {} }
    for event in pairs(names) do
        states[#states + 1] = { [event] = true }
        states[1][event] = true
    end
    for _, calendar in ipairs(states) do
        env.calendar = calendar
        for npcID, v in pairs(HA.EventSources.EventVendors) do
            count = count + 1
            assert(not v.removed and not v.unreleased and not v.endeavor, npcID .. " carries another listing rule")
            assert(D.HolidayActive(v) == env.B.Facts.BrowserListed(v), "disagree for " .. npcID)
            assert(D.HolidayActive(v) == (calendar[v.event] == true))
        end
    end
    assert(count > 0)
    print("hs538_sources: shipped holiday vendors agree (" .. count .. " checks)")
end

-------------------------------------------------------------------------------
-- The header box's hint names the list; a source route with no key keeps the last type
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    build(env)
    local page = env.pages.sources
    local hints = {
        achievements = "Search achievements", quests = "Search quests", professions = "Search recipes and professions",
        drops = "Search drops and zones", events = "Search events", shop = "Search the Shop",
    }
    for t, hint in pairs(hints) do
        page:Show({ kind = "sources", key = t })
        assert(page:Placeholder({ kind = "sources", key = t }) == hint, t .. ": the hint is " .. hint)
    end
    page:Show({ kind = "sources", key = "quests" })
    page:Show({ kind = "sources" })
    assert(page:Placeholder({ kind = "sources" }) == "Search quests", "no key keeps the last type's hint")
    for _, kind in ipairs({ "vendors", "allVendors" }) do
        assert(page:Placeholder({ kind = kind, key = "Midnight" }) == "Search vendors and zones", kind .. ": the vendor hint")
    end
    print("hs538_sources: list hints ok")
end

-------------------------------------------------------------------------------
-- The head counts the sources Hide drops
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    allItemsOwned(env)
    local main = build(env)
    env.B.State.hideNA = true
    env.tab.Show({ type = "achievements" })
    assert(main.shown == false, "everything collected is hidden")
    assert(headText() == "2 of 2 collected", "the head counts hidden sources too: " .. tostring(headText()))
    print("hs538_sources: head counts hidden sources")
end

-------------------------------------------------------------------------------
-- Names, the Shop and the tab contract
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    local main = build(env)
    env.tab.Show({ type = "shop" })
    assert(rows(main)[1].name == "Item 61", "an unloaded name reads as the item number")
    env.names[61] = "Loaded"
    env.tab.Refresh("names")
    assert(rows(main)[1].name == "Loaded", "the name fills in on the next refresh")
    env.tab.Hide()
    env.tab.Refresh("zone")
    assert(rows(main)[1].name == "Loaded", "Refresh after Hide redraws the list")

    for state, st in pairs(env.B.Style.state) do
        if st.color == env.B.Style.color.stop then assert(state == "faction" or state == "short", "red on " .. state) end
    end
    print("hs538_sources: names and contract ok")
end

-------------------------------------------------------------------------------
-- The source page through a refresh: names fill in, a page torn down by Hide comes back on any reason,
-- and a shown page ignores the reasons that change nothing it draws
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    build(env)
    env.tab.Show({ type = "shop", select = { key = 61 } })
    assert(pageText(env, "Item 61") and env.B.SourceTitle("shop", 61) == "Item 61", "the shop page waits for its item's name")
    env.names[61] = "Loaded"
    env.spage:Refresh("names")
    assert(pageText(env, "Loaded") and env.B.SourceTitle("shop", 61) == "Loaded", "the name fills in on the next refresh")
    env.spage:Hide()
    env.names[61] = "Reloaded"
    env.spage:Refresh("hide")
    assert(pageText(env, "Reloaded"), "Refresh after Hide redraws the page, whatever the reason")
    env.names[61] = "Painted"
    env.spage:Refresh("hide")
    env.spage:Refresh("paint")
    assert(pageText(env, "Reloaded") and not pageText(env, "Painted"), "Hide and paint refreshes of a shown page redraw nothing")
    local n = walks(env)
    for _, reason in ipairs({ "zone", "paint", "layout", "hide", "names", "stats" }) do
        env.spage:Refresh(reason)
        assert(walks(env) == n, reason .. " repaint walked")
    end
    invalidate(env)
    env.spage:Refresh("data")
    assert(walks(env) == n + 1, "a data refresh walks once")
    assert(pageText(env, "Painted"), "and redraws")
    print("hs538_sources: source page refresh ok")
end

-------------------------------------------------------------------------------
-- The source page's text fits its page: a long subtitle is one line cut where the icon leaves room, the name has
-- the cut-off tooltip, the count is a text line with no bar, and a list hides the tooltip it owns
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    env.decor(42)
    local zone = ("Z"):rep(80)
    env.HA.DropSources[42] = { mobName = "Long", zone = zone, mapID = 10, coords = { x = 0.3, y = 0.4 } }
    local main = build(env)
    env.tab.Show({ type = "drops", select = { key = "Long|" .. zone } })
    local sub = pinLines(env)[1]
    assert(#sub.text.text * 6 > 200, "the subtitle is longer than the page")
    local room = 200 - sub.wp:GetWidth() - env.B.Style.space.xs
    assert(rawget(sub.text, "width") <= room and rawget(sub.text, "width") >= 1,
        "a long subtitle is capped to leave the icon room: " .. tostring(rawget(sub.text, "width")))
    env.tab.Show({ type = "drops", select = { key = "Boss|Keep" } })
    sub = pinLines(env)[1]
    assert(rawget(sub.text, "width") == #sub.text.text * 6 + 1, "a short subtitle keeps its own width")

    local name
    for _, f in ipairs(all) do
        if f.kind == "Frame" and rawget(f, "scripts") and f.scripts.OnEnter and f.scripts.OnLeave and within(f, env.spageFrame) then
            name = f
        end
    end
    assert(name, "the name has the tooltip that shows it whole when it is cut off")

    for _, w in ipairs(all) do
        assert(not (w.kind == "StatusBar" and within(w, env.spageFrame)), "the source page draws no bar")
    end
    env.tab.Show({ type = "achievements", select = { key = 9002 } })
    assert(pageText(env, "0 of 1 collected"), "the count is a text line")

    local hides = 0
    env.B.HideTooltip = function() hides = hides + 1 end
    env.tab.Show({ type = "achievements" })
    env.pages.sources:Hide()
    assert(hides == 1, "a list hides the link tooltip its rows own")
    assert(main.shown ~= nil)
    print("hs538_sources: source page text fit ok")
end

print("hs538_sources: all ok")
