-- luacheck: globals assert loadfile print rawset io os table string
-- Run from the repo root:  lua tests/hs538_catalog.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The Catalog tab, run through the real Catalog.lua, Widgets.lua, CanGet.lua and
-- the real data stack against stubbed data and recording widgets: sorts, filters
-- (unknown ownership in neither ownership filter), the landing contract, the
-- Hide pin and footer, the states, the walk discipline and the keystroke cost.
-------------------------------------------------------------------------------

local function noop() end

-- Widgets: stored text and shown state, a ScrollBox that renders its first rows through the real
-- element factory, and dropdowns whose menu the test can read.
local Widget
local methods = {}
local fontStrings = {}
function methods.CreateFontString(self)
    local fs = Widget("FontString")
    fs.parent = self
    fontStrings[#fontStrings + 1] = fs
    return fs
end
function methods.CreateTexture() return Widget("Texture") end
function methods.SetText(self, text)
    self.text = text
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function methods.GetText(self) return self.text end
function methods.SetWidth(self, w) self.width = w end
function methods.GetWidth(self) return self.width or 300 end
function methods.SetSize(self, w, h) self.width, self.height = w, h end
function methods.SetHeight(self, h) self.height = h end
function methods.SetShown(self, on) self.shown = on end
function methods.Show(self) self.shown = true end
function methods.Hide(self) self.shown = false end
function methods.IsShown(self) return self.shown end
function methods.SetScript(self, name, fn) self.scripts[name] = fn end
function methods.HookScript(self, name, fn) self.scripts[name] = fn end
function methods.GetUnboundedStringWidth(self) return #self.text * 6 end
function methods.GetStringHeight() return 12 end
function methods.GetTextWidth(self) return #self.text * 6 end
function methods.GetFrameLevel() return 1 end
function methods.GetParent(self) return self.parent end
function methods.SetupMenu(self, fn) self.menu = fn end
function Widget(kind)
    return setmetatable({ kind = kind, shown = true, text = "", scripts = {} }, {
        __index = function(_, k)
            if methods[k] then return methods[k] end
            if type(k) == "string" and k:find("^%u") then return noop end
        end,
    })
end

local function Render(box)
    local view = box.view
    for _, f in ipairs(box.frames) do view.resetter(f) end
    box.frames = {}
    local used = {}
    for i = 1, math.min(8, #box.provider) do
        view.factory(function(frameType, init)
            local pool = box.pool[frameType] or {}
            box.pool[frameType] = pool
            used[frameType] = (used[frameType] or 0) + 1
            local f = pool[used[frameType]]
            if not f then
                f = Widget(frameType)
                pool[used[frameType]] = f
                box.created = box.created + 1
            end
            box.frames[#box.frames + 1] = f
            init(f, box.provider[i])
        end, box.provider[i])
    end
end

local function NewBox()
    local box = Widget("WowScrollBoxList")
    box.frames, box.pool, box.created, box.sets, box.scrolls = {}, {}, 0, 0, {}
    function box:SetDataProvider(p, keep)
        self.provider, self.keep, self.sets = p, keep, self.sets + 1
        Render(self)
    end
    function box:ForEachFrame(fn)
        for _, f in ipairs(self.frames) do fn(f) end
    end
    function box:FindElementDataIndexByPredicate(pred)
        for i, d in ipairs(self.provider or {}) do
            if pred(d) then return i end
        end
    end
    function box:ScrollToElementDataIndex(i) self.scrolls[#self.scrolls + 1] = i end
    return box
end

local function newEnv(opts)
    opts = opts or {}
    local env = {
        done = true, attempted = true, warm = true, responded = true, faction = "Alliance",
        catalog = {}, catalogCalls = 0, names = {}, sources = {}, vendors = {}, offers = {}, reqs = {},
        scanned = {}, calendar = {}, measured = {}, sortCalls = 0, sourceCalls = 0,
    }
    for k, v in pairs(opts) do env[k] = v end
    rawset(_G, "Foundry_1_0", { RaiseDevError = function(_, msg) error(msg) end })
    rawset(_G, "wipe", function(t) for k in pairs(t) do t[k] = nil end return t end)
    rawset(_G, "GetBuildInfo", function() return "12.0.1", "1", "1", 120001 end)
    rawset(_G, "UnitFactionGroup", function() return env.faction end)
    rawset(_G, "Enum", { ItemClass = { Housing = 20 }, ItemHousingSubclass = { Decor = 0, Dye = 1 },
        UIMapType = { Continent = 2, Zone = 3 } })
    rawset(_G, "C_Item", {
        GetItemNameByID = function(id) return env.names[id] end,
        RequestLoadItemDataByID = function() end,
        GetItemIconByID = function(id) return "icon" .. id end,
        GetItemQualityByID = function() return 1 end,
    })
    rawset(_G, "C_HousingCatalog", {
        GetCatalogEntryInfoByItem = function(id)
            env.catalogCalls = env.catalogCalls + 1
            return env.catalog[id]
        end,
        GetCatalogEntryInfoByRecordID = function() return nil end,
    })
    env.maps = {}
    rawset(_G, "C_Map", {
        GetBestMapForUnit = function() return env.playerMap end,
        GetMapInfo = function(id) return env.maps[id] end,
        GetMapChildrenInfo = function() return {} end,
    })
    rawset(_G, "UIParent", Widget("UIParent"))
    rawset(_G, "CreateFrame", function(kind, _, parent, template)
        local w
        if template == "WowScrollBoxList" then w = NewBox() else w = Widget(kind) end
        w.parent, w.template = parent, template
        env.all[#env.all + 1] = w
        if kind == "EditBox" then w.Instructions = Widget("FontString") end
        if template then
            env.byTemplate = env.byTemplate or {}
            env.byTemplate[template] = w
        end
        return w
    end)
    rawset(_G, "C_Texture", { GetAtlasInfo = function() return nil end })
    rawset(_G, "PixelUtil", { SetHeight = noop, SetWidth = noop })
    rawset(_G, "NineSliceUtil", { ApplyLayoutByName = noop })
    rawset(_G, "CreateColor", function() return {} end)
    rawset(_G, "CreateAnchor", noop)
    rawset(_G, "CreateDataProvider", function(t) return t end)
    rawset(_G, "TextSizeManager", { GetScale = function() return 1 end })
    rawset(_G, "C_ColorOverrides", { GetColorForQuality = function() return { r = 0, g = 0.5, b = 1 } end })
    rawset(_G, "ScrollUtil", {
        InitScrollBoxListWithScrollBar = function(box, _, view) box.view = view end,
        AddManagedScrollBarVisibilityBehavior = noop,
    })
    rawset(_G, "CreateScrollBoxListLinearView", function()
        local v = Widget("View")
        function v:SetElementFactory(fn) self.factory = fn end
        function v:SetElementResetter(fn) self.resetter = fn end
        function v:SetElementExtentCalculator(fn) self.extent = fn end
        return v
    end)
    local realSort = table.sort
    rawset(table, "sort", function(...) env.sortCalls = env.sortCalls + 1 return realSort(...) end)

    local HA = {
        Addon = { db = {
            global = { catalogItems = {}, schemaVersion = 7, scannedVendors = {}, noDecorVendors = {} },
            profile = { vendorTracer = { showEventVendors = true } },
        }, Debug = function() end, RegisterModule = function() end },
        Events = { Fire = function() end },
        Constants = { ZoneToFactionMap = {}, TEXTURE_ROOT = "", Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
        DecorMapping = {}, EventSources = { EventVendors = {} }, AchievementSources = {}, VendorIdentity = {},
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
    HA.CalendarDetector = { IsHolidayActive = function() return false end }
    HA.EndeavorsData = { GetThemeForVendor = noop, IsThemeActive = noop }
    HA.VendorData = {
        GetVendor = function(_, npcID) return env.vendors[npcID] end,
        HasOfferForItem = function(_, id) return env.offers[id] == true end,
        GetVendorItems = function(_, npcID) return (env.vendors[npcID] or {}).items end,
        GetScannedVendorItems = function(_, npcID, itemID) return env.scanned[npcID .. ":" .. itemID] end,
        GetScannedVendorRecord = function() return nil end,
        GetMergedItemIDs = function(_, v) return v.items end,
        FormatCost = function(_, cost) return (cost.gold or 0) .. "g" end,
    }
    for _, file in ipairs({ "Locale/enUS.lua", "Data/CatalogStore.lua", "Data/SourceManager.lua",
        "UI/VendorFilter.lua", "UI/Browser/Style.lua", "UI/Browser/Visuals.lua", "UI/Browser/Adapter.lua",
        "UI/Browser/Facts.lua", "UI/Browser/CanGet.lua", "UI/Browser/Widgets.lua" }) do
        assert(loadfile(root .. "/" .. file))("Homestead", HA)
    end
    local SM = HA.SourceManager
    SM.GetAllSources = function(_, id)
        env.sourceCalls = env.sourceCalls + 1
        return env.sources[id] or {}
    end
    SM.GetRequirements = function(_, id, npcID) return env.reqs[id .. ":" .. tostring(npcID)] or {} end
    HA.CatalogStore:Initialize()

    local B = HA.DecorBrowser
    local W = B.Widgets
    env.B, env.W, env.D, env.CG = B, W, B.Data, B.CanGet
    env.log, env.empty, env.fits, env.all = {}, nil, 0, {}
    B.State = { hideNA = false, inCombat = false, generation = 0, catalogMemo = {} }
    env.walkCalls = 0
    B.Walk = function()
        env.walkCalls = env.walkCalls + 1
        return B.CanGet.Walk()
    end
    B.Window = { AddSearchBox = noop, hideNA = Widget("CheckButton") }
    B.HideTooltipFor = noop
    B.SetLocation = function(text) env.location = text end
    B.ItemDetail = {
        Build = function(parent) env.log[#env.log + 1] = "build" env.detailParent = parent end,
        Show = function(id) env.log[#env.log + 1] = "show:" .. id end,
        Clear = function() env.log[#env.log + 1] = "clear" end,
        SetCombat = function(on) env.log[#env.log + 1] = "combat:" .. tostring(on) end,
    }
    local newEmpty, newCols = W.NewEmptyState, W.NewColumns
    W.NewEmptyState = function(parent)
        local f = newEmpty(parent)
        local set = f.Set
        f.Set = function(self, kind, d) env.empty = { kind = kind, d = d } return set(self, kind, d) end
        env.emptyFrame = f
        return f
    end
    W.NewColumns = function(parent)
        local c = newCols(parent)
        local fit = c.Fit
        c.Fit = function(self) env.fits = env.fits + 1 return fit(self) end
        return c
    end
    function B.RegisterTab(_, tab) env.tab = tab end
    function B.SetHideNA(on)
        B.State.hideNA = on
        env.tab.Refresh("hide")
    end
    assert(loadfile(root .. "/UI/Browser/Catalog.lua"))("Homestead", HA)

    function env.vendor(npcID, fields)
        local v = fields or {}
        v.npcID, v.mapID, v.items = npcID, v.mapID or 1, v.items or {}
        env.vendors[npcID] = v
        return v
    end
    function env.sell(itemID, v, cost)
        local list = env.sources[itemID] or {}
        list[#list + 1] = { type = "vendor", data = { npcID = v.npcID, vendor = v, name = "Vendor " .. v.npcID,
            cost = cost or { gold = 100 } } }
        env.sources[itemID] = list
        env.offers[itemID] = true
        v.items[#v.items + 1] = itemID
    end
    function env.decor(itemID, name, entry)
        HA.DecorMapping[itemID + 900000] = itemID
        env.catalog[itemID] = entry or { totalNumStored = 0 }
        env.names[itemID] = name
    end
    function env.walks()
        local n = 0
        for _, m in ipairs(env.measured) do if m.op == "browser_walk" then n = n + 1 end end
        return n
    end
    -- The visible list: item ids in order, then the footer if there is one.
    function env.rows()
        local box = env.byTemplate.WowScrollBoxList
        local ids, footer = {}, nil
        for _, d in ipairs(box.shown and box.provider or {}) do
            if d.kind == "item" then ids[#ids + 1] = d.id else footer = d end
        end
        return ids, footer
    end
    function env.box() return env.byTemplate.WowScrollBoxList end
    function env.ids() return table.concat((env.rows()), ",") end
    function env.menu(dropdown)
        local m = { items = {} }
        function m:CreateCheckbox(text, isSel, setSel) self.items[#self.items + 1] = { text = text, isSel = isSel, setSel = setSel } end
        function m:CreateRadio(text, isSel, setSel) self.items[#self.items + 1] = { text = text, isSel = isSel, setSel = setSel } end
        function m:CreateButton(text, fn) self.items[#self.items + 1] = { text = text, click = fn } end
        function m:CreateDivider() end
        dropdown.menu(dropdown, m)
        function m:Find(text)
            for _, it in ipairs(self.items) do if it.text == text then return it end end
            error("no menu item " .. text)
        end
        return m
    end
    function env.filters() return env.byTemplate.WowStyle1FilterDropdownTemplate end
    function env.sort() return env.byTemplate.WowStyle1DropdownTemplate end
    function env.type(text) env.byTemplate.SearchBoxTemplate:SetText(text) end
    -- The Filtered line: its text, and whether its button is shown.
    function env.filtered()
        for i = #fontStrings, 1, -1 do
            local fs = fontStrings[i]
            if fs.text:find("^Filtered:") then return fs.text, fs.parent.shown end
        end
    end
    function env.nav(key)
        for _, w in ipairs(env.all) do
            if w.key == key then return w end
        end
    end
    return env, HA
end

-- The standard fixture. Best order: 1 2 8 (can get now, ranked), 5 7 (plain), 3 (requirement), 6 (other faction), 4 (collected).
local function fixture(opts)
    local env, HA = newEnv(opts)
    local near, horde = env.vendor(10), env.vendor(11, { faction = "Horde" })
    env.decor(1, "Oak Bench", { totalNumStored = 0, firstAcquisitionBonus = 1, categoryIDs = { 1 } })
    env.decor(2, "Elm Chair", { totalNumStored = 0, categoryIDs = { 1 } })
    env.decor(3, "Cedar Table", { totalNumStored = 0, categoryIDs = { 2 } })
    env.decor(4, "Pine Shelf", { totalNumPlaced = 1, categoryIDs = { 3 } })
    env.decor(5, "Birch Lamp")
    env.catalog[5] = nil
    env.decor(6, "Ash Stool", { totalNumStored = 0, categoryIDs = { 4 } })
    env.decor(7, "Willow Rug", { totalNumStored = 0, categoryIDs = { 3 } })
    env.decor(8, "Fir Candle", { totalNumStored = 0, categoryIDs = { 4 } })
    env.sell(1, near, { gold = 300 })
    env.sell(2, near, { gold = 100 })
    env.sell(3, near, { gold = 50 })
    env.sell(4, near, { gold = 10 })
    env.sell(5, near, { gold = 20 })
    env.sell(6, horde, { gold = 70 })
    env.sell(8, near, { gold = 0, currencies = { { id = 1 } } })
    env.reqs["3:10"] = { { type = "unknown", text = "Mysterious Favor" } }
    HA.AchievementSources[7] = { achievementID = 9 }
    HA.AchievementSources[2] = { achievementID = 12 }
    env.sources[2][#env.sources[2] + 1] = { type = "achievement", data = { achievementID = 12, achievementName = "Chair Feat" } }
    env.sources[7] = { { type = "achievement", data = { achievementID = 9, achievementName = "Fixture Win" } } }
    local page = Widget("Frame")
    env.tab.Build(page)
    return env, HA
end

local function eq(a, b, msg) assert(a == b, (msg or "") .. ": got " .. tostring(a) .. ", expected " .. tostring(b)) end

-------------------------------------------------------------------------------
-- Build, R24 and the three sorts
-------------------------------------------------------------------------------

do
    local env = fixture()
    eq(#env.log, 1, "build")
    eq(env.log[1], "build", "the detail is built into the third column")
    env.tab.Show()
    eq(env.ids(), "1,2,8,5,7,3,6,4", "Best to get now: ranked, plain, requirement, other faction, collected")
    eq(env.log[#env.log], "show:1", "R24: the first row is selected and the detail filled")
    eq(env.location, "All decor", "location")
    local frames = env.box().frames
    eq(frames[1].d.selected, true, "the first row is drawn selected")
    eq(frames[2].d.selected, false, "the others are not")

    local rowOf = {}
    for _, f in ipairs(frames) do rowOf[f.d.itemID] = f.d end
    eq(rowOf[1].state, "can", "Can get now")
    eq(rowOf[1].right, "300g", "the price on the right")
    eq(rowOf[1].bonus, true, "the bonus star")
    eq(rowOf[3].state, "locked", "requirement")
    eq(rowOf[3].arg, "Mysterious Favor", "the first unmet requirement")
    eq(rowOf[6].state, "faction", "other faction")
    eq(rowOf[6].arg, "Horde", "the other faction's name")
    eq(rowOf[4].state, "owned", "collected")
    eq(rowOf[7].state, "notOwned", "not collected")
    eq(rowOf[7].line2, "Achievement: Fixture Win", "the primary source line")
    eq(rowOf[5].state, nil, "unknown ownership shows no state")
    assert(rowOf[2].line2:find("(+1 more)", 1, true), "R23 more sources: " .. rowOf[2].line2)
    eq(rowOf[7].line2:find("(+", 1, true), nil, "a single source has no count")

    local sortMenu = env.menu(env.sort())
    sortMenu:Find("Name").setSel()
    eq(env.ids(), "6,5,3,2,8,1,7,4", "Name: named first alphabetical, collected last")
    sortMenu:Find("Price").setSel()
    eq(env.ids(), "5,3,6,2,1,8,7,4", "Price: lowest gold first, no gold-only price last, collected last")
    print("hs538_catalog: build, rows and sorts ok")
end


-------------------------------------------------------------------------------
-- Filters match OwnState exactly; the Filtered line; kinds; sources; search
-------------------------------------------------------------------------------

do
    local env = fixture()
    env.tab.Show()
    local fm = env.menu(env.filters())
    local _, lineShown = env.filtered()
    eq(lineShown, false, "no Filtered line at the defaults")

    fm:Find("Not collected").setSel()
    eq(env.ids(), "4", "Collected only: owned items, not unknown ones")
    local text, shown = env.filtered()
    local plain = tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    eq(shown, true, "the Filtered line is shown")
    eq(plain, "Filtered: Collected \194\183 Reset filters", "R22 Filtered line")
    fm:Find("Not collected").setSel()
    fm:Find("Collected").setSel()
    eq(env.ids(), "1,2,8,7,3,6", "Not collected only: unknown ownership (5) and owned (4) are in neither filter")
    fm:Find("Not collected").setSel()
    eq(env.ids(), "", "neither: nothing, unknowns included")
    assert(env.filtered():find("Neither collected nor not collected", 1, true), "the line says so")
    eq(env.empty.kind, "noResults", "an empty result says so")
    fm:Find("Reset filters").click()
    eq(env.ids(), "1,2,8,5,7,3,6,4", "Reset: the defaults, unknown ownership included")
    eq(select(2, env.filtered()), false, "the Filtered line is gone")

    fm:Find("Can get now").setSel()
    eq(env.ids(), "1,2,8", "Can get now is verdict can only (a requirement, another faction or a plain item is not)")
    fm:Find("Can get now").setSel()
    fm:Find("First-Time Collection Bonus").setSel()
    eq(env.ids(), "1", "the bonus filter")
    fm:Find("First-Time Collection Bonus").setSel()

    fm:Find("Vendors").setSel()
    eq(env.ids(), "2,7", "unchecking a source type leaves the items that have another source, two-type ones included")
    assert(env.filtered():find("Sources: Achievements", 1, true), "the line lists the sources left")
    fm:Find("Reset filters").click()

    env.nav(1).scripts.OnClick()
    eq(env.ids(), "1,2", "a kind")
    eq(env.nav(1).count.text, 2, "its count")
    eq(env.nav("other").count.text, 1, "the unlisted-category item counts as Other")
    eq(env.nav("all").count.text, 8, "All decor counts every item")
    eq(env.location, "Furnishings", "the location line names the kind")
    env.nav("all").scripts.OnClick()

    local before = { walks = env.walks(), reads = env.catalogCalls, sorts = env.sortCalls, sources = env.sourceCalls }
    env.type("o")
    env.type("oa")
    env.type("OAK ")
    eq(env.ids(), "1", "search matches names, any case, trimmed")
    eq(env.walks(), before.walks, "typing never walks")
    eq(env.catalogCalls, before.reads, "typing never reads the catalog")
    eq(env.sortCalls, before.sorts, "typing never sorts")
    assert(env.sourceCalls - before.sources <= 3 * 8, "typing only describes the rows in view")
    env.type("zzz")
    eq(env.empty.kind, "noResults", "no results")
    eq(env.empty.d.onAll, nil, "Search all decor only while a kind is chosen")
    env.nav(2).scripts.OnClick()
    assert(type(env.empty.d.onAll) == "function", "Search all decor with a kind chosen")
    env.empty.d.onAll()
    eq(env.location, "All decor", "it leaves the kind")
    env.empty.d.onReset()
    eq(env.ids(), "1,2,8,5,7,3,6,4", "Reset filters clears the search too")
    eq(env.byTemplate.SearchBoxTemplate.text, "", "and the box")
    print("hs538_catalog: filters, kinds and search ok")
end

-- W4: the Catalog's counts per source type are the By source numbers.
do
    local env = fixture()
    env.tab.Show()
    local progress = env.D.Progress()
    for _, key in ipairs(env.CG.SOURCE_KEYS) do
        env.tab.Show({ filters = { sources = { [key] = true } } })
        eq(#env.rows(), progress.src[key].total, "total for " .. key)
        env.tab.Show({ filters = { sources = { [key] = true }, collected = true } })
        eq(#env.rows(), progress.src[key].owned, "collected for " .. key)
    end
    assert(progress.src.vendors.owned == 1 and progress.src.vendors.total == 7, "the fixture has an owned vendor item")
    eq(progress.src.achievements.total, 2, "an item with two source types counts under both")
    eq(progress.src.vendors.total, 7, "and vendors still counts it")
    print("hs538_catalog: By source parity ok")

    local two, twoHA = fixture()
    twoHA.SourceManager.IsRequirementMet = function(_, req) return req.met end
    two.reqs["3:10"] = { { type = "unknown", text = "Early Step", met = true }, { type = "unknown", text = "Mysterious Favor" },
        { type = "unknown", text = "Old Debt" } }
    two.tab.Show()
    local arg
    for _, f in ipairs(two.box().frames) do if f.d.itemID == 3 then arg = f.d.arg end end
    eq(arg, "Mysterious Favor and 1 more", "Requires: the first unmet one, then how many more")
    two.reqs["3:10"][4] = { type = "unknown", text = "Third Task" }
    two.D.InvalidateMemos()
    two.tab.Refresh("data")
    for _, f in ipairs(two.box().frames) do if f.d.itemID == 3 then arg = f.d.arg end end
    eq(arg, "Mysterious Favor and 2 more", "and the count follows the unmet ones")
end

-------------------------------------------------------------------------------
-- The opts contract and R25 landing
-------------------------------------------------------------------------------

do
    local env = fixture()
    env.tab.Show()
    env.type("oak")
    env.menu(env.sort()):Find("Name").setSel()
    env.tab.Hide()
    eq(env.log[#env.log], "clear", "Hide clears the detail")
    env.tab.Show()
    eq(env.ids(), "1", "nil opts keeps the search")
    eq(env.log[#env.log], "show:1", "and refills the detail")
    eq(env.box().keep, true, "and the scroll position")

    env.tab.Show({})
    eq(env.ids(), "6,5,3,2,8,1,7,4", "a table resets the search but sort stays")
    eq(env.byTemplate.SearchBoxTemplate.text, "", "the box is cleared")

    env.tab.Show({ search = "chair", kind = 1, filters = { canGet = true } })
    eq(env.ids(), "2", "opts are applied after the reset")
    eq(env.byTemplate.SearchBoxTemplate.text, "chair", "the box shows the landed search")

    env.tab.Show({ filters = { notCollected = true }, sort = "best" })
    eq(env.ids(), "1,2,8,7,3,6", "Show what's missing: Not collected only, sort from opts")

    env.tab.Show({ search = "zzz", kind = 2, filters = { canGet = true } })
    env.tab.Show({ itemID = 3 })
    eq(env.ids(), "1,2,8,5,7,3,6,4", "R25: search, kind and filters reset")
    eq(env.log[#env.log], "show:3", "R25: the item is selected and its detail filled")
    eq(env.box().scrolls[#env.box().scrolls], 6, "R25: scrolled to the item's index")
    eq(env.box().frames[1].d.selected, false, "the first row is no longer the selected one")
    eq(env.emptyFrame.shown, false, "no empty state")

    env.tab.Show({ itemID = 999 })
    eq(env.log[#env.log], "show:999", "an id with no record still lands on its detail")
    for _, f in ipairs(env.box().frames) do assert(not f.d.selected, "no row is selected for it") end
    env.tab.Refresh("data")
    eq(env.log[#env.log], "show:999", "a data refresh keeps it")
    env.tab.Show({ search = "chair" })
    eq(env.log[#env.log], "show:2", "a new landing drops it for the first row")
    print("hs538_catalog: opts contract and landing ok")
end

-------------------------------------------------------------------------------
-- Hide: counts, pin and footer
-------------------------------------------------------------------------------

do
    local env = fixture()
    env.decor(9, "Hazel Vase", { totalNumStored = 0, categoryIDs = { 4 } })
    env.sell(9, env.vendors[11], { gold = 5 })
    env.B.State.hideNA = true
    env.tab.Show()
    local ids, footer = env.rows()
    eq(table.concat(ids, ","), "1,2,8,5,7,3", "collected and other-faction items are hidden, unknown ones are not")
    eq(footer.hidden, 3, "the footer counts them")
    eq(footer.collected, 1, "one collected")
    eq(footer.faction, 2, "two other-faction")
    eq(#footer.parts == 1 and footer.parts[1][1] == 2 and footer.parts[1][2], "Horde", "the faction named")
    eq(env.box().view.extent(nil, footer), env.W.FooterHeight(footer, env.box():GetWidth()), "the footer measures its own text")
    eq(env.box().view.extent(nil, env.box().provider[1]), env.W.RowHeight(), "a row is a row high")

    env.tab.Show({ itemID = 4 })
    ids, footer = env.rows()
    eq(table.concat(ids, ","), "1,2,8,5,7,3,4", "R25: an item hidden only by Hide is pinned in view")
    eq(footer.hidden, 2, "the pinned item is not counted as hidden")
    eq(env.log[#env.log], "show:4", "and selected")

    footer.onShow()
    eq(env.B.State.hideNA, false, "Show them turns the toggle off")
    eq(env.ids(), "1,2,8,5,7,3,6,9,4", "and refreshes the list")
    print("hs538_catalog: Hide pin and footer ok")
end

-------------------------------------------------------------------------------
-- States: counting, not read, then ready
-------------------------------------------------------------------------------

do
    local env = fixture({ done = false, attempted = false })
    env.tab.Show()
    eq(env.empty.kind, "countingSort", "Best sort while counting")
    eq(env.box().shown, false, "the list is hidden")
    eq(type(env.empty.d.onSort), "function", "with the Sort by name button")
    eq(env.walks(), 0, "no walk before the first read")
    env.empty.d.onSort()
    eq(env.ids(), "6,5,3,2,8,1,4,7", "Sort by name lists every item, nothing jumps")
    eq(env.box().frames[1].d.state, "counting", "rows read Counting…")
    local fm = env.menu(env.filters())
    fm:Find("Can get now").setSel()
    eq(env.empty.kind, "counting", "a filter that needs the collection waits too")
    eq(env.empty.d.onSort, nil, "and offers no sort button under Name")
    fm:Find("Can get now").setSel()
    eq(env.walks(), 0, "still no walk")

    env.done, env.warm = true, true
    env.D.InvalidateMemos()
    env.tab.Refresh("data")
    eq(env.walks(), 1, "the data refresh walks once")
    eq(env.ids(), "6,5,3,2,8,1,7,4", "ownership is known: collected sinks")
    eq(env.box().frames[1].d.state, "faction", "and rows have their states")
end

do
    local env = fixture({ done = true, attempted = true, warm = false, responded = false })
    env.tab.Show()
    eq(#env.rows(), 8, "not read: every item is listed")
    eq(env.box().frames[1].d.state, nil, "with no state words")
    env.menu(env.filters()):Find("Can get now").setSel()
    eq(env.empty.kind, "notReadFilters", "a filter that needs the collection says so")
    eq(type(env.empty.d.onReset), "function", "with Reset filters")
    env.empty.d.onReset()
    eq(#env.rows(), 8, "reset")
    env.B.State.hideNA = true
    env.tab.Refresh("hide")
    local ids, footer = env.rows()
    eq(#ids, 7, "Hide drops the other-faction item while the collection is unknown")
    eq(table.concat(ids, ","):find("6", 1, true), nil, "that item is the other-faction one")
    eq(footer.hidden, 1, "the footer counts it")
    eq(footer.collected, 0, "nothing collected is hidden: ownership is unknown")
    eq(footer.faction, 1, "one other-faction")
    eq(#footer.parts == 1 and footer.parts[1][1] == 1 and footer.parts[1][2], "Horde", "the faction named")
    assert(table.concat(ids, ","):find("4", 1, true), "the owned item stays listed")
    print("hs538_catalog: counting and not-read states ok")
end

-------------------------------------------------------------------------------
-- The walk runs only for "data"; the other repaints reuse the cache
-------------------------------------------------------------------------------

do
    local env = fixture()
    env.tab.Show()
    eq(env.walks(), 1, "the first show walks once")
    local asked = env.walkCalls
    for _, reason in ipairs({ "paint", "zone", "layout", "names", "hide", "stats" }) do
        env.tab.Refresh(reason)
        eq(env.walks(), 1, reason .. " never walks")
        eq(env.walkCalls, asked, reason .. " never asks for the walk")
    end
    env.tab.Show()
    eq(env.walks(), 1, "a plain tab switch does not walk again")
    eq(env.walkCalls, asked, "nor ask for it")

    local n = env.box().sets
    env.tab.Refresh("paint")
    eq(env.box().sets, n, "paint redraws the rows without re-setting the data")
    local fits = env.fits
    env.tab.Refresh("layout")
    eq(env.box().sets, n + 1, "layout re-sets the data so the heights are measured again")
    eq(env.box().keep, true, "keeping the scroll position")
    eq(env.fits, fits + 1, "and the columns fit again")

    env.D.InvalidateMemos()
    env.tab.Refresh("data")
    eq(env.walks(), 2, "data walks once")
    env.tab.Hide()
    env.tab.Refresh("data")
    eq(env.log[#env.log], "show:1", "a data refresh after Hide restores the detail")
    env.tab.Hide()
    env.tab.Refresh("paint")
    eq(env.log[#env.log], "show:1", "so does a paint refresh")
    env.tab.Hide()
    env.tab.Refresh("zone")
    eq(env.log[#env.log], "show:1", "and a zone refresh")
    env.tab.SetCombat(true)
    eq(env.log[#env.log], "combat:true", "combat reaches the detail")

    local created = env.box().created
    for _, q in ipairs({ "a", "b", "", "c", "" }) do env.type(q) end
    env.B.State.hideNA = true
    env.tab.Refresh("hide")
    assert(env.box().created <= created + 2, "row frames are pooled, not rebuilt")
    print("hs538_catalog: walk discipline ok")
end

-------------------------------------------------------------------------------
-- A zone change re-ranks Best to get now from the cached walk
-------------------------------------------------------------------------------

do
    local env = newEnv()
    env.maps[100] = { mapType = 2, parentMapID = 0 }
    env.maps[101] = { mapType = 3, parentMapID = 100 }
    env.maps[200] = { mapType = 2, parentMapID = 0 }
    env.maps[201] = { mapType = 3, parentMapID = 200 }
    env.playerMap = 101
    local here, far = env.vendor(30, { mapID = 101 }), env.vendor(31, { mapID = 201 })
    env.decor(21, "Zeta Lamp")
    env.decor(22, "Alpha Lamp")
    env.sell(21, here)
    env.sell(22, far)
    env.tab.Build(Widget("Frame"))
    env.tab.Show()
    eq(env.ids(), "21,22", "the item sold here comes first")
    env.playerMap = 201
    env.tab.Refresh("zone")
    eq(env.ids(), "22,21", "after a zone change the item sold in the new zone comes first")
    eq(env.walks(), 1, "without a new walk")
    print("hs538_catalog: zone re-rank ok")
end

-- Hide with a walk reads the walk; a row is judged as an item, not by its first vendor
do
    local env = fixture()
    env.decor(10, "Pine Lamp", { totalNumStored = 0, categoryIDs = { 4 } })
    env.sell(10, env.vendors[11], { gold = 5 })
    env.sell(10, env.vendors[10], { gold = 6 })
    env.B.State.hideNA = true
    local calls, real = 0, env.CG.HiddenBy
    env.CG.HiddenBy = function(...) calls = calls + 1 return real(...) end
    env.tab.Show()
    env.tab.Refresh("hide")
    eq(calls, 0, "with a walk, Hide never asks HiddenBy")
    env.CG.HiddenBy = real
    env.B.State.hideNA = false
    env.tab.Show()
    local d
    for _, f in ipairs(env.box().frames) do if f.d.itemID == 10 then d = f.d end end
    assert(d, "the item is listed")
    eq(d.npcID, nil, "a row carries no vendor")
    eq(d.state, "can", "an Alliance character can get it from the other vendor")
    eq(env.B.ItemState(10, d.npcID), "can", "the tooltip judges the item: can get now")
    print("hs538_catalog: item-level rows ok")
end

-- One rule on every surface. hs538_item checks the page and the tooltip for the same shape: an achievement
-- plus an other-faction vendor reads Not collected, never the faction stop.
do
    local env = fixture()
    env.decor(12, "Fern Rug", { totalNumStored = 0, categoryIDs = { 4 } })
    env.sell(12, env.vendors[11], { gold = 5 })
    env.HA.AchievementSources[12] = { achievementID = 13 }
    env.sources[12][#env.sources[12] + 1] = { type = "achievement", data = { achievementID = 13, achievementName = "Rug Feat" } }
    env.tab.Show()
    local d
    for _, f in ipairs(env.box().frames) do if f.d.itemID == 12 then d = f.d end end
    assert(d, "the rug is listed")
    local state, arg = env.B.ItemState(12)
    eq(d.state, "notOwned", "achievement plus other-faction vendor: Not collected on the row")
    assert(d.state == state and d.arg == arg, "the row and the shared rule disagree")
    print("hs538_catalog: one item state ok")
end

print("hs538_catalog: ok")
