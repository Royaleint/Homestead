-- luacheck: globals assert loadfile print io rawset CreateFrame UIParent C_Texture PixelUtil CreateColor C_ColorOverrides
-- luacheck: globals CreateScrollBoxListLinearView ScrollUtil CreateAnchor CreateDataProvider TextSizeManager NineSliceUtil
-- luacheck: globals C_Timer C_Item C_Map date os SetPortraitTextureFromCreatureDisplayID InCombatLockdown
-- Run from the repo root:  lua tests/hs538_sources.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The Sources tab, run through the real Sources.lua, Widgets, Facts, Adapter and
-- CanGet against stubbed data and recording widgets: grouping and row words, the
-- vendor detail (confirmation, counts, model, report), the select contract for
-- every type, Hide's footer, the count refresh, and the walk discipline.
-------------------------------------------------------------------------------

local function noop() end
local Widget
local made, all, boxes, views, models = {}, {}, {}, {}, {}
local scrolls = {}
local methods = {}
function methods.CreateFontString(_, _, _, font)
    local fs = Widget("FontString")
    fs.font = font
    made[#made + 1] = fs
    return fs
end
function methods.CreateTexture() return Widget("Texture") end
function methods.SetFontObject(self, font) self.font = font end
function methods.SetText(self, text) self.text = text end
function methods.GetText(self) return self.text end
function methods.SetWidth(self, w) self.width = w end
function methods.GetWidth(self) return self.width or 200 end
function methods.SetSize(self, w, h) self.width, self.height = w, h end
function methods.SetHeight(self, h) self.height = h end
function methods.GetHeight(self) return self.height or 0 end
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
function methods.FindElementDataIndexByPredicate(self, fn)
    for i, d in ipairs(self.data or {}) do
        if fn(d) then return i end
    end
end
function methods.ScrollToElementDataIndex(self, index) scrolls[#scrolls + 1] = { box = self, index = index } end
function methods.SetElementFactory(self, fn) self.factory = fn end
function methods.SetCreature(self, id) self.creature = id; self.calls[#self.calls + 1] = "SetCreature" end
function methods.ClearModel(self) self.calls[#self.calls + 1] = "ClearModel" end
function methods.GetModelFileID(self) return self.fileID end
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
    if template == "WowScrollBoxList" then boxes[#boxes + 1] = w end
    if kind == "PlayerModel" then models[#models + 1] = w end
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
ScrollUtil = { InitScrollBoxListWithScrollBar = noop, AddManagedScrollBarVisibilityBehavior = noop }
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
    rawset(_G, "C_Item", {
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
    made, all, boxes, views, models, scrolls, timers = {}, {}, {}, {}, {}, {}, {}
    portraitCalls = {}
    combat = false
end

local function setup()
    reset()
    local env, HA, D, CG = newEnv()
    env.records, env.stats, env.prewarm, env.reports, env.waypoints = {}, {}, 0, {}, {}
    env.shown = {}
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
    local tabs, gen = {}, 1
    B.State = { hideNA = false, inCombat = false, generation = 1, noPrewarm = false, catalogMemo = {} }
    env.walkCalls = 0
    B.Walk = function()
        env.walkCalls = env.walkCalls + 1
        return CG.Walk()
    end
    B.Generation = function() return gen end
    B.InCombat = function() return B.State.inCombat end
    B.SetLocation = function(detail) env.location = detail end
    B.RegisterTab = function(key, tab) tabs[key] = tab end
    B.ShowTab = function(key, o) env.shown[#env.shown + 1] = { key = key, opts = o } end
    B.Tooltip = function()
        return { SetOwner = noop, SetText = function(_, t) env.tip = t end, Show = noop }
    end
    B.HideTooltip, B.HideTooltipFor = noop, noop
    B.Window = { AddSearchBox = noop, hideNA = Widget("CheckButton") }
    B.SetHideNA = function(on)
        B.State.hideNA = on
        env.hideNASet = on
        if tabs.sources then tabs.sources.Refresh("hide") end
    end
    local path = root .. "/UI/Browser/Sources.lua"
    local before = #all
    assert(loadfile(path))("Homestead", HA)
    env.framesAtLoad = #all - before
    env.tab, env.B, env.W = tabs.sources, B, B.Widgets
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
    return frameWith(function(w) return w.kind == "Button" and w.text == text end)
end

local function searchBox()
    return frameWith(function(w) return w.kind == "EditBox" end)
end

local function allItemsOwned(env)
    for id in pairs(env.catalog) do env.catalog[id] = { totalNumStored = 1 } end
end

-------------------------------------------------------------------------------
-- Nothing is created before first open; the model frame waits for a vendor
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    assert(env.framesAtLoad == 0, "loading Sources.lua created frames")
    build(env)
    assert(#models == 0, "the vendor model was created at Build")
    env.tab.Show(nil)
    assert(#models == 1, "the model is created when the first vendor is shown")
    print("hs538_sources: lazy creation ok")
end

-------------------------------------------------------------------------------
-- R26 counts, R27 grouping
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    local main = build(env)
    env.tab.Show({})
    assert(same(keyList(main), { "# Here in Stormwind", "100", "# Eastern Kingdoms", "101", "# Kalimdor", "102",
        "# Location not recorded", "103" }), "vendor groups: " .. table.concat(keyList(main), ","))
    local counts = {}
    for _, w in ipairs(all) do if rawget(w, "count") and rawget(w, "label") then counts[#counts + 1] = w.count.text end end
    assert(same(counts, { "4", "2", "2", "2", "1", "2", "1" }), "nav counts: " .. table.concat(counts, ","))

    env.tab.Show({ type = "achievements" })
    assert(same(keyList(main), { "# Cata", "9002", "# Catb", "9001" }), "achievements by category")
    env.tab.Show({ type = "professions" })
    assert(same(keyList(main), { "# Cooking", "8002", "# Tailoring", "8001" }), "professions by profession")
    env.tab.Show({ type = "quests" })
    assert(same(keyList(main), { "7002", "7001" }), "quests are ungrouped and sorted by title")
    env.tab.Show({ type = "events" })
    assert(keyList(main)[1] == "foot", "R30: no event active shows the empty-events note first")
    assert(main.data[1].text == "No events active right now. Event decor is sold only while its event runs.")
    assert(same({ keyList(main)[2], keyList(main)[3] }, { "Hallow's End", "Noblegarden" }))
    env.calendar["Noblegarden"] = true
    invalidate(env)
    env.tab.Refresh("data")
    assert(same(keyList(main), { "Noblegarden", "Hallow's End" }), "an active event sorts first and the note goes")
    assert(row(main, "Noblegarden").state == "live" and row(main, "Hallow's End").state == "idle")
    print("hs538_sources: nav counts, grouping and events ok")
end

-------------------------------------------------------------------------------
-- R28 row words
-------------------------------------------------------------------------------

do
    local env = setup()
    local v = world(env)
    local main = build(env)
    env.vendor(104, { name = "Eve", zone = "Stormwind", mapID = 10 })
    env.tab.Show({})
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
    assert(foot.text.text == "2 hidden by 'Hide what doesn't apply to me' (1 collected, 1 Horde only)." and foot.link.shown)
    local note = render({ kind = "foot", text = "No events" })
    assert(not note.link.shown, "the empty-events note has no Show them link")
    render({ kind = "header", text = "Kalimdor" })
    assert(seen.row == "Button" and seen.header ~= seen.foot and seen.row ~= seen.header and seen.row ~= seen.foot,
        "list kinds need distinct frame types")
    print("hs538_sources: pooled kinds and rendered words ok")
end

-------------------------------------------------------------------------------
-- R29 vendor detail
-------------------------------------------------------------------------------

do
    local env = setup()
    local v = world(env)
    v.here.x, v.here.y = 0.4, 0.5
    env.HA.VendorPortraits[100] = 555
    local _, side = build(env)
    env.tab.Show({ type = "vendors", select = { key = 100 } })
    assert(env.location == "Anna", "the location line names the vendor")
    assert(shownText("Trade District, Stormwind") and shownText("Eastern Kingdoms"), "zone, subzone and continent")
    assert(shownText("Confirmed by a scan on 2026-10-01"), "the shipped date shows")
    assert(shownText("Sells 3 decor.") and shownText("3 you can get now."), "the count line")
    assert(portraitCalls[#portraitCalls] == 555, "the headshot comes from the portrait table")
    assert(models[1].creature == 100, "the model is set from the vendor")
    assert(#side.data == 3 and side.data[1].state == "can" and side.data[1].npcID == 100, "the decor list")
    side.data[1].onClick()
    assert(env.shown[#env.shown].key == "catalog" and env.shown[#env.shown].opts.itemID == side.data[1].itemID,
        "a decor row opens Catalog at the item")

    env.records[100] = { lastScanned = os.time({ year = 2026, month = 9, day = 1, hour = 12 }) }
    env.tab.Refresh("data")
    assert(shownText("Confirmed by a scan on 2026-10-01"), "an older scan does not replace the shipped date")
    env.records[100] = { lastScanned = os.time({ year = 2026, month = 10, day = 20, hour = 12 }) }
    env.tab.Refresh("data")
    assert(shownText("Confirmed by a scan on 2026-10-20"), "the newer of the two shows")

    local go = frameWith(function(w) return w.kind == "Button" and w.text == "Set waypoint" and rawget(w, "target") end)
    assert(go and go.target.mapID == 10 and go.shown, "Set waypoint targets the vendor")
    go.scripts.OnClick(go)
    assert(env.waypoints[1][1] == 10 and env.waypoints[1][4].title == "Anna")

    env.tab.Select(101)
    assert(shownText("Not confirmed: No scan has confirmed this vendor yet."), "the Not confirmed sentence")
    assert(not frameWith(function(w) return w.kind == "Button" and w.text == "Set waypoint" and rawget(w, "target") and w.shown end),
        "no location, no waypoint button")
    env.tab.Select(102)
    assert(shownText("Horde only: can't buy on this character"), "the faction stop line")
    env.tab.Select(103)
    assert(not shownText("Horde only"), "the stop line is gone")
    print("hs538_sources: vendor detail ok")
end

-------------------------------------------------------------------------------
-- The model: placeholder until it loads, stale work does nothing, Hide clears
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    build(env)
    env.tab.Show({ type = "vendors", select = { key = 100 } })
    local model = models[1]
    model.fileID = false
    local ph = frameWith(function(w) return w.kind == "Frame" and w.parent == model.parent end)
    assert(ph and ph.shown, "the placeholder shows while the model is unknown")
    local t100 = timers[1]
    t100()
    assert(ph.shown, "no model file yet: the placeholder stays")
    env.tab.Select(101)
    assert(model.creature == 101 and ph.shown)
    model.fileID = 99
    t100()
    assert(ph.shown, "the first vendor's late check does nothing")
    timers[2]()
    assert(not ph.shown, "the current vendor's check hides the placeholder")
    env.tab.Select(100)
    assert(ph.shown, "a new vendor starts on the placeholder")
    model.scripts.OnModelLoaded(model)
    assert(not ph.shown, "OnModelLoaded hides it for the current vendor")
    env.tab.Select(101)
    assert(ph.shown)
    env.bump()
    model.scripts.OnModelLoaded(model)
    assert(ph.shown, "work from before a window change does nothing")
    local t101 = timers[#timers]
    t101()
    assert(ph.shown, "a timer from before a window change does nothing")

    env.tab.Hide()
    assert(model.shown == false and model.calls[#model.calls] == "ClearModel", "Hide clears and hides the model")
    model.scripts.OnModelLoaded(model)
    assert(ph.shown, "nothing is current after Hide")
    local creatures = 0
    for _, c in ipairs(model.calls) do if c == "SetCreature" then creatures = creatures + 1 end end
    env.tab.Refresh("paint")
    local after = 0
    for _, c in ipairs(model.calls) do if c == "SetCreature" then after = after + 1 end end
    assert(after == creatures + 1 and model.shown, "Refresh after Hide restores the model without Show")
    env.tab.Show({ type = "achievements" })
    assert(model.shown == false, "a source with no vendor clears the model")

    env.tab.Show({ type = "vendors", select = { key = 100 } })
    local creates, nt = 0, #timers
    for _, c in ipairs(model.calls) do if c == "SetCreature" then creates = creates + 1 end end
    local box = searchBox()
    env.tab.Refresh("stats")
    env.tab.Refresh("names")
    env.tab.Refresh("zone")
    env.tab.Select(100)
    box.text = "anna"
    box.scripts.OnTextChanged(box, true)
    local now = 0
    for _, c in ipairs(model.calls) do if c == "SetCreature" then now = now + 1 end end
    assert(now == creates and #timers == nt, "the same vendor keeps its model through repaints, clicks and searches")
    print("hs538_sources: model ok")
end

-------------------------------------------------------------------------------
-- Other source details, the S4 lines and the Not confirmed rule
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    local main = build(env)
    env.tab.Show({ type = "quests", select = { key = 7001 } })
    local q = {}
    for _, w in ipairs(all) do if rawget(w, "wp") and w.kind == "Frame" then q[#q + 1] = w end end
    assert(#q == 2)
    assert(q[1].shown and q[1].text.text == "Starts in Stormwind" and not q[2].shown, "quest start line")
    assert(q[1].wp.wp.mapID == 10 and q[1].wp.wp.x == 0.5 and q[1].wp.wp.y == 0.6)
    q[1].wp.scripts.OnClick(q[1].wp)
    assert(env.waypoints[1][1] == 10 and env.waypoints[1][2] == 0.5, "the line's waypoint is set")
    env.tab.Show({ type = "quests", select = { key = 7002 } })
    assert(not q[1].shown and q[2].shown and q[2].text.text == "Dig site in Elwynn Forest", "dig site line")
    assert(q[2].wp.wp.mapID == 11 and q[2].wp.wp.x == 0.2)
    assert(not shownText("Not confirmed"), "no Not confirmed for a non-vendor")
    assert(not row(main, 7002).unconfirmed)
    assert(shownText("Gives 1 decor.") and not shownText("Sells"))
    env.tab.Show({ type = "drops", select = { key = "Boss|Keep" } })
    local go = frameWith(function(w) return w.kind == "Button" and w.text == "Set waypoint" and rawget(w, "target") end)
    assert(go.shown and go.target.mapID == 10 and go.target.x == 0.1, "a drop with coordinates has a waypoint")
    assert(shownText("Rare."), "the drop's notes show")
    env.tab.Show({ type = "events", select = { key = "Noblegarden" } })
    assert(shownText("Not active") and not go.shown, "an idle event says so and has no waypoint")
    print("hs538_sources: other details ok")
end

-------------------------------------------------------------------------------
-- The select contract for every type
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    env.names[61] = "Shop Thing"
    local main = build(env)
    local box = searchBox()
    local picks = {
        { "vendors", 101, "Bran" }, { "achievements", 9002, "Ach B" }, { "quests", 7002, "Decor Treasure Hunt" },
        { "professions", 8002, "Stew" }, { "drops", "Boss|Keep", "Boss" }, { "events", "Noblegarden", "Noblegarden" },
        { "shop", 61, "Shop Thing" },
    }
    for _, p in ipairs(picks) do
        local t, key, title = p[1], p[2], p[3]
        env.tab.Show({ type = t, search = "zzz" })
        assert(box.text == "zzz" and main.shown == false, t .. ": a search with no matches")
        env.tab.Show({ type = t, select = { key = key }, search = "ignored" })
        assert(box.text == "", t .. ": select clears the type's search and ignores opts.search")
        local d = row(main, key)
        assert(d and d.selected, t .. ": the row is selected")
        local last = scrolls[#scrolls]
        assert(last.box == main and main.data[last.index] == d, t .. ": scrolled to the row")
        assert(env.location == title, t .. ": the detail is filled (" .. tostring(env.location) .. ")")
        env.tab.Show({ type = t, select = { key = "missing" } })
        local first = rows(main)[1]
        assert(first.selected and env.location == first.name, t .. ": a missing key opens the first row")
        env.tab.Show({ type = t })
        assert(rows(main)[1].selected, t .. ": no select opens the first row")
    end
    env.tab.Show({ type = "achievements", select = { key = 9001 } })
    env.tab.Show(nil)
    assert(row(main, 9001).selected and #rows(main) == 2, "a plain switch keeps the state")
    print("hs538_sources: select contract ok")
end

-------------------------------------------------------------------------------
-- R33 Hide: counts unchanged, the footer, nothing unknown hidden, pinned landings
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    env.catalog[1], env.catalog[2], env.catalog[3] = { totalNumStored = 1 }, { totalNumStored = 1 }, { totalNumStored = 1 }
    local main = build(env)
    env.tab.Show({})
    env.B.SetHideNA(true)
    assert(same(keyList(main), { "# Eastern Kingdoms", "101", "# Location not recorded", "103", "foot" }),
        "Hide drops the collected vendor and the other faction: " .. table.concat(keyList(main), ","))
    local foot = main.data[#main.data]
    assert(foot.hidden == 2 and foot.collected == 1 and foot.faction == 1 and foot.parts[1][1] == 1 and foot.parts[1][2] ~= "" and foot.onShow,
        "the footer splits collected and faction")
    local counts = {}
    for _, w in ipairs(all) do if rawget(w, "count") and rawget(w, "label") then counts[#counts + 1] = w.count.text end end
    assert(counts[1] == "4", "counts never change")
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
    local picks = { { "vendors", 100 }, { "vendors", 102 }, { "achievements", 9001 }, { "quests", 7001 },
        { "professions", 8001 }, { "drops", "Boss|Keep" }, { "shop", 61 } }
    for _, p in ipairs(picks) do
        env.tab.Show({ type = p[1], select = { key = p[2] } })
        local d = row(main, p[2])
        assert(d and d.selected, p[1] .. " " .. tostring(p[2]) .. ": Hide alone does not stop a landing")
    end
    env.tab.Show({ type = "achievements", select = { key = 9001 } })
    assert(not row(main, 9002), "the other collected source stays hidden")
    local fd = main.data[#main.data]
    assert(fd.kind == "foot" and fd.collected == 1 and fd.faction == 0
        and #fd.parts == 0, "only collected rows hidden: no faction is named")
    assert(env.W.FooterText({ hidden = 3, collected = 1, faction = 2, parts = {} })
        == "3 hidden by 'Hide what doesn't apply to me' (1 collected).", "the footer prints the whole hidden count")
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
    local box = searchBox()
    env.tab.Show({})
    box.text = "bran"
    box.scripts.OnTextChanged(box, true)
    assert(same(keyList(main), { "# Eastern Kingdoms", "101" }), "search by name")
    box.text = "stormwind"
    box.scripts.OnTextChanged(box, true)
    assert(same(keyList(main), { "# Here in Stormwind", "100" }), "search by zone")
    box.text = "nothing like it"
    box.scripts.OnTextChanged(box, true)
    assert(main.shown == false and shownText("Nothing matches your search."), "no matches: the empty state")
    local resetBtn = button("Reset filters")
    assert(resetBtn and resetBtn.shown)
    resetBtn.scripts.OnClick()
    assert(box.text == "", "Reset filters clears the search")
    env.tab.Refresh("paint")
    box.text = ""
    box.scripts.OnTextChanged(box, true)
    assert(#rows(main) == 4 and main.shown, "clearing the search brings the list back")
    print("hs538_sources: search ok")
end

-------------------------------------------------------------------------------
-- Count fill: rows read N decor, then collected of total; one request, no listener
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    local main = build(env)
    env.tab.Show({})
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
    env.tab.Show({})
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
    env.tab.Show({ type = "vendors", select = { key = 100 } })
    local report = button("Report a problem")
    assert(report.enabled ~= false and report.shown)
    report.scripts.OnClick()
    local r = env.reports[1]
    assert(r.title == "Report a data error" and r.text:find("Vendor 100: Anna, Stormwind, map 10 at 40.0, 50.0", 1, true)
        and r.text:find("Homestead: 9.9.9", 1, true), "the vendor report")
    env.tab.Show({ type = "achievements", select = { key = 9001 } })
    report.scripts.OnClick()
    assert(env.reports[2].text:find("Achievement: Ach A", 1, true), "the source report")

    env.tab.SetCombat(true)
    assert(report.enabled == false, "disabled in combat")
    env.B.State.inCombat = true
    env.tab.Show({ type = "vendors", select = { key = 101 } })
    assert(report.enabled == false, "a new selection in combat stays disabled")
    Enter(report)
    assert(env.tip == "Not available in combat", "the tooltip says why")
    env.tip = nil
    env.B.State.inCombat = false
    env.tab.SetCombat(false)
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
    env.tab.Show({})
    assert(row(main, 20).state == "live" and not row(main, 21), "an active event vendor is listed and tagged Active now")
    env.tab.Select(20)
    assert(shownText("Active now. Seasonal: Hallow's End"), "the event line")
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
-- A landing's pin ends when the player moves to another kind of source
-------------------------------------------------------------------------------

do
    local env = setup()
    world(env)
    allItemsOwned(env)
    local main = build(env)
    env.B.State.hideNA = true
    env.tab.Show({ type = "vendors", select = { key = 100 } })
    assert(row(main, 100) and row(main, 100).selected)
    local nav
    for _, w in ipairs(all) do
        if rawget(w, "label") and w.label.text == "Achievements" then nav = w end
    end
    nav.scripts.OnClick()
    for _, w in ipairs(all) do
        if rawget(w, "label") and w.label.text == "Vendors" then nav = w end
    end
    nav.scripts.OnClick()
    assert(main.shown == false, "the pinned vendor is hidden again after leaving the kind")
    print("hs538_sources: pin ends on a kind switch")
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
    assert(rows(main)[1].name == "Loaded" and env.location == "Loaded", "Refresh after Hide redraws the detail")
    for state, st in pairs(env.B.Style.state) do
        if st.color == env.B.Style.color.stop then assert(state == "faction", "red on " .. state) end
    end
    print("hs538_sources: names and contract ok")
end

print("hs538_sources: all ok")
