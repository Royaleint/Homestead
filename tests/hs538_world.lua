-- luacheck: globals assert loadfile print rawset rawget io os date
-- Shared world for the cross-tab browser tests. Running this file alone does nothing; the tests load it:
--   local newWorld = assert(loadfile(root .. "/tests/hs538_world.lua"))()
--   local env = newWorld(root, { faction = "Alliance" })
-- The world is the real router, Summary, Catalog, Sources and the item detail over the real data modules,
-- with stubbed game data and recording widgets. Tests drive it through env.go (a page key and options, turned
-- into a route), B.SetHideNA, the pages' Show and Refresh, the drawn rows and frames, and B.ItemState.
-- opts.realWindow loads the real Window.lua in place of the window stub, so B:Toggle builds what the client
-- builds. Showing a frame runs the OnShow script of each frame that becomes visible with it, and the two
-- dropdown templates follow Blizzard's menu order (tests/hs538_menu.lua).

local function noop() end

return function(root, opts)
    root = root:gsub("\\", "/"):gsub("/+$", "")
    local menuStub = assert(loadfile(root .. "/tests/hs538_menu.lua"))()
    local env = {
        money = 1e9, currency = {}, count = {},
        done = true, attempted = true, warm = true, responded = true, faction = "Alliance",
        catalog = {}, names = {}, sources = {}, vendors = {}, offers = {}, reqs = {}, scanned = {}, records = {},
        calendar = {}, themes = {}, measured = {}, maps = {}, playerMap = nil, stats = {},
        all = {}, boxList = {}, timers = {}, saves = {}, waypoints = {}, reports = {}, itemShows = {},
        walkCalls = 0, combat = false, fontStrings = {}, textures = {}, emptySets = {}, links = {}, linked = {},
        sceneIDs = {}, models = {}, clears = 0, noActor = {},
    }
    for k, v in pairs(opts or {}) do env[k] = v end

    ---------------------------------------------------------------------------
    -- Recording widgets
    ---------------------------------------------------------------------------
    local Widget
    local methods = {}
    function methods.CreateFontString(self, _, _, font)
        local fs = Widget("FontString")
        fs.parent, fs.font = self, font
        env.fontStrings[#env.fontStrings + 1] = fs
        return fs
    end
    function methods.CreateTexture(self)
        local t = Widget("Texture")
        t.parent = self
        env.textures[#env.textures + 1] = t
        return t
    end
    function methods.SetFontObject(self, font) self.font = font end
    function methods.SetNormalFontObject(self, font) self.normalFont = font end
    function methods.SetHighlightFontObject(self, font) self.highlightFont = font end
    function methods.SetHitRectInsets(self, l, r, t, b) self.hitInsets = { l, r, t, b } end
    function methods.SetMotionScriptsWhileDisabled(self, on) self.motion = on end
    function methods.SetText(self, text)
        self.text = text
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
    end
    function methods.GetText(self) return self.text end
    function methods.SetWidth(self, w) self.width = w end
    function methods.GetWidth(self) return rawget(self, "width") or 300 end
    function methods.SetSize(self, w, h) self.width, self.height = w, h end
    function methods.SetHeight(self, h) self.height = h end
    function methods.GetHeight(self) return rawget(self, "height") or 24 end
    -- Visible: shown, and every parent shown. A frame that becomes visible runs its OnShow, and so does
    -- each shown frame under it, as the client does; becoming hidden runs OnHide the same way.
    local function Visible(w)
        while w do
            if not w.shown then return false end
            w = w.parent
        end
        return true
    end
    local function Under(f, top)
        while f do
            if f == top then return true end
            f = f.parent
        end
    end
    local function SetShown(self, on)
        on = on and true or false
        local was = Visible(self)
        local hiding = {}
        if was and not on then
            for _, f in ipairs(env.all) do
                if f.scripts and f.scripts.OnHide and Under(f, self) and Visible(f) then hiding[#hiding + 1] = f end
            end
        end
        self.shown = on
        for _, f in ipairs(hiding) do f.scripts.OnHide(f) end
        if not on or was or not Visible(self) then return end
        for _, f in ipairs(env.all) do
            if f.scripts and f.scripts.OnShow and Under(f, self) and Visible(f) then f.scripts.OnShow(f) end
        end
    end
    methods.SetShown = SetShown
    function methods.Show(self) SetShown(self, true) end
    function methods.Hide(self) SetShown(self, false) end
    function methods.IsShown(self) return self.shown end
    function methods.IsVisible(self) return Visible(self) end
    function methods.SetEnabled(self, on) self.enabled = on end
    function methods.IsEnabled(self) return self.enabled end
    function methods.SetChecked(self, on) self.checked = on end
    function methods.GetChecked(self) return self.checked end
    function methods.SetScript(self, name, fn) self.scripts[name] = fn end
    function methods.HookScript(self, name, fn) self.scripts[name] = fn end
    function methods.SetPoint(self, ...)
        self.pt = { ... }
        self.pts = self.pts or {}
        self.pts[(...)] = self.pt
    end
    function methods.SetNormalAtlas(self, atlas) self.atlas = atlas end
    function methods.SetAlpha(self, a) self.alpha = a end
    function methods.SetDesaturated(self, on) self.desaturated = on end
    function methods.SetTextColor(self, r, g, b) self.color = { r, g, b } end
    function methods.SetVertexColor(self, r, g, b) self.color = { r, g, b } end
    function methods.SetColorTexture(self, r, g, b) self.color = { r, g, b } end
    function methods.GetUnboundedStringWidth(self) return #tostring(self.text) * 6 end
    function methods.GetStringHeight() return 12 end
    function methods.GetTextWidth(self) return #tostring(self.text) * 6 end
    function methods.GetFrameLevel() return 1 end
    function methods.GetParent(self) return self.parent end
    function methods.GetStringWidth(self) return #tostring(self.text) * 6 end
    function methods.SetCustomOnMouseUpHandler(self, fn) self.customMouseUpHandler = fn end
    function methods.CreateAnimationGroup()
        local g = Widget("AnimationGroup")
        function g.CreateAnimation() return Widget("Animation") end
        return g
    end
    function methods.SetCreature(self, id) self.creature = id end
    function methods.GetModelFileID(self) return self.fileID end
    function Widget(kind)
        local w = setmetatable({ kind = kind, shown = true, enabled = true, text = "", scripts = {} }, {
            __index = function(_, k)
                if methods[k] then return methods[k] end
                if type(k) == "string" and k:find("^%u") then return noop end
            end,
        })
        return w
    end

    -- A ScrollBox that keeps its data and renders its first rows through the real element factory, so the
    -- tests read what the rows draw.
    local function Render(box)
        local view = box.view
        -- The client measures every element before it initialises the visible ones.
        if view.extent then
            for i, d in ipairs(box.provider) do view.extent(i, d) end
        end
        for _, f in ipairs(box.frames) do view.resetter(f) end
        box.frames = {}
        local used = {}
        for i = 1, math.min(40, #box.provider) do
            view.factory(function(frameType, init)
                local pool = box.pool[frameType] or {}
                box.pool[frameType] = pool
                used[frameType] = (used[frameType] or 0) + 1
                local f = pool[used[frameType]]
                if not f then
                    f = Widget(frameType)
                    f.parent = box
                    pool[used[frameType]] = f
                end
                box.frames[#box.frames + 1] = f
                init(f, box.provider[i])
            end, box.provider[i])
        end
    end

    local function NewBox()
        local box = Widget("WowScrollBoxList")
        box.frames, box.pool, box.scrolls, box.provider = {}, {}, {}, {}
        box.aligns = {}
        function box:SetDataProvider(p, keep)
            self.provider, self.data, self.keep = p, p, keep
            Render(self)
        end
        function box:ForEachFrame(fn)
            for _, f in ipairs(self.frames) do fn(f) end
        end
        function box:FindElementDataIndexByPredicate(pred)
            for i, d in ipairs(self.provider) do
                if pred(d) then return i end
            end
        end
        function box:ScrollToElementDataIndex(i, align)
            self.scrolls[#self.scrolls + 1] = i
            self.aligns[#self.scrolls] = align
        end
        env.boxList[#env.boxList + 1] = box
        return box
    end

    ---------------------------------------------------------------------------
    -- Game globals
    ---------------------------------------------------------------------------
    local function G(name, value) rawset(_G, name, value) end
    G("Foundry_1_0", { RaiseDevError = function(_, msg) error(msg) end })
    G("ScrollBoxConstants", { AlignBegin = 0, AlignCenter = 0.5, AlignEnd = 1 })
    G("wipe", function(t) for k in pairs(t) do t[k] = nil end return t end)
    G("date", os.date)
    G("GetBuildInfo", function() return "12.0.1", "1", "1", 120001 end)
    G("UnitFactionGroup", function() return env.faction end)
    G("InCombatLockdown", function() return env.combat end)
    G("Enum", { ItemClass = { Housing = 20 }, ItemHousingSubclass = { Decor = 0, Dye = 1 },
        UIMapType = { Continent = 2, Zone = 3 } })
    G("GetMoney", function() return env.money end)
    G("C_CurrencyInfo", { GetCurrencyInfo = function(id)
        local c = env.currency[id]
        if c == nil then return { quantity = 1e6 } end
        return c or nil
    end })
    G("C_Item", {
        GetItemCount = function(id) return env.count[id] or 1e6 end,
        GetItemNameByID = function(id) return env.names[id] end,
        RequestLoadItemDataByID = noop,
        GetItemIconByID = function(id) return 1000 + id end,
        GetItemQualityByID = function() return 2 end,
        GetItemInfo = function(id) return env.names[id], env.links[id] end,
    })
    G("IsModifiedClick", function(action) return env.modifier == action end)
    G("HandleModifiedItemClick", function(link) env.linked[#env.linked + 1] = link return true end)
    G("C_HousingCatalog", {
        GetCatalogEntryInfoByItem = function(id) return env.catalog[id] end,
        GetCatalogEntryInfoByRecordID = function() return nil end,
    })
    G("C_Map", {
        GetBestMapForUnit = function() return env.playerMap end,
        GetMapInfo = function(id) return env.maps[id] end,
        GetMapChildrenInfo = function() return {} end,
        GetPlayerMapPosition = function() return nil end,
    })
    G("C_Timer", {
        After = function(_, fn) env.timers[#env.timers + 1] = { fn = fn } end,
        NewTimer = function(_, fn)
            local t = { fn = fn, Cancel = function(self) self.cancelled = true end }
            env.timers[#env.timers + 1] = t
            return t
        end,
    })
    G("UIParent", Widget("UIParent"))
    G("CreateFrame", function(kind, _, parent, template)
        local w = template == "WowScrollBoxList" and NewBox() or Widget(kind)
        w.parent, w.template = parent, template
        env.all[#env.all + 1] = w
        if kind == "EditBox" then w.Instructions = Widget("FontString") end
        if template == "WowStyle1DropdownTemplate" or template == "WowStyle1FilterDropdownTemplate" then
            menuStub(w, template)
        elseif template == "ButtonFrameTemplate" then
            w.Inset, w.CloseButton = Widget("Frame"), Widget("Button")
            w.Inset.parent, w.CloseButton.parent = w, w
            w.Inset.Bg = Widget("Texture")
            w.TitleContainer = { TitleText = Widget("FontString") }
            function w:GetTitleText() return self.TitleContainer.TitleText end
        elseif template == "LargeSideTabButtonTemplate" then
            w.Icon = Widget("Texture")
            -- SidePanelTabButtonMixin:SetChecked sets the icon from the atlas fields set before it.
            function w:SetChecked(on)
                assert(self.activeAtlas and self.inactiveAtlas, "a side tab is checked before its atlases are set")
                self.checked = on
            end
        elseif template == "ScrollFrameTemplate" then
            w.ScrollBar = Widget("EventFrame")
            w.ScrollBar.SetHideIfUnscrollable = function(self, on) self.hideIfUnscrollable = on end
        elseif template == "UICheckButtonTemplate" then
            w.Text = Widget("FontString")
        elseif template == "UIPanelButtonTemplate" then
            local label = Widget("FontString")
            function w:GetFontString() return label end
        elseif template == "NoZoomModelSceneMixinTemplate" then
            -- A decor scene's actor is tagged "decor", unless env.noActor names the scene. env.sceneIDs and
            -- env.models record what the scene is given; env.clears counts ClearScene.
            local actor = {}
            function actor:SetPreferModelCollisionBounds(on) self.bounds = on end
            function actor:SetModelByFileID(id) env.models[#env.models + 1] = id end
            w.actor = actor
            function w:TransitionToModelSceneID(id, transition, modification, force)
                env.sceneIDs[#env.sceneIDs + 1] = id
                self.sceneID, self.sceneArgs = id, { transition, modification, force }
            end
            function w:GetActorByTag(tag)
                return tag == "decor" and self.sceneID and not env.noActor[self.sceneID] and actor or nil
            end
            function w:ClearScene()
                self.sceneID = nil
                env.clears = env.clears + 1
            end
            function w:EnableMouseWheel(on) self.wheel = on end
        end
        return w
    end)
    G("Constants", { HousingCatalogConsts = { HOUSING_CATALOG_DECOR_MODELSCENEID_DEFAULT = 1317 } })
    G("CAMERA_TRANSITION_TYPE_IMMEDIATE", "immediate")
    G("CAMERA_MODIFICATION_TYPE_DISCARD", "discard")
    G("CreateFont", function() return Widget("Font") end)
    G("C_Texture", { GetAtlasInfo = function(atlas)
        if atlas:find("^housing%-dashboard%-woodsign") and not env.noSignAtlas then return { width = 64, height = 32 } end
    end })
    G("PixelUtil", { SetHeight = noop, SetWidth = noop })
    G("NineSliceUtil", { ApplyLayoutByName = noop })
    G("CreateColor", function() return {} end)
    G("CreateAnchor", noop)
    G("CreateDataProvider", function(t) return t end)
    G("TextSizeManager", { GetScale = function() return 1 end })
    G("FrameUtil", { UpdateScaleForFitSpecific = noop })
    G("EventRegistry", { RegisterCallback = noop, UnregisterCallback = noop })
    G("Menu", { GetManager = function() return { IsAnyMenuOpen = function() return false end, CloseMenus = noop } end })
    G("BreakUpLargeNumbers", tostring)
    G("NORMAL_FONT_COLOR", { r = 1, g = 0.82, b = 0 })
    G("ITEM_QUALITY2_DESC", "Uncommon")
    G("C_ColorOverrides", { GetColorForQuality = function() return { r = 0, g = 0.5, b = 1 } end })
    G("SetPortraitTextureFromCreatureDisplayID", function(tex, id) tex.portrait = id end)
    G("ScrollUtil", {
        InitScrollBoxListWithScrollBar = function(box, _, view) box.view = view end,
        AddManagedScrollBarVisibilityBehavior = noop,
        InitScrollFrameWithScrollBar = noop,
    })
    G("CreateScrollBoxListGridView", function(stride)
        local v = Widget("View")
        v.stride = stride
        function v:SetElementInitializer(template, fn) self.factory = function(factory) factory(template, fn) end end
        function v:SetElementResetter(fn) self.resetter = fn end
        function v:SetStride(n) self.stride = n end
        function v:GetStride() return self.stride end
        return v
    end)
    G("CreateScrollBoxListLinearView", function()
        local v = Widget("View")
        function v:SetElementFactory(fn) self.factory = fn end
        function v:SetElementResetter(fn) self.resetter = fn end
        function v:SetElementExtentCalculator(fn) self.extent = fn end
        return v
    end)

    ---------------------------------------------------------------------------
    -- The addon table: stubs for what the browser reads from the rest of Homestead
    ---------------------------------------------------------------------------
    local HA = {
        Addon = { _enabled = true, db = {
            global = { catalogItems = {}, schemaVersion = 7, scannedVendors = {}, noDecorVendors = {} },
            profile = { vendorTracer = { showEventVendors = true }, browser = { hideNA = false, tipSeen = true } },
        }, Debug = noop, RegisterModule = noop, Print = noop },
        Events = { Fire = noop, RegisterCallback = noop, UnregisterCallback = noop },
        Constants = { ZoneToFactionMap = {}, TEXTURE_ROOT = "", Icons = {}, SourceBadgeAtlas = {}, Colors = {}, VERSION = "9.9.9" },
        DecorMapping = {}, EventSources = { EventVendors = {} }, VendorIdentity = {},
        Waypoints = { Set = function(_, mapID, x, y, o) env.waypoints[#env.waypoints + 1] = { mapID, x, y, o } end },
        OutputWindow = { Show = function(_, title, text) env.reports[#env.reports + 1] = { title = title, text = text } end },
    }
    for _, name in ipairs({ "AchievementSources", "QuestSources", "ProfessionSources", "DropSources", "ShopSources",
        "VendorPortraits", "QuestStarts", "TreasureHuntSpots" }) do
        HA[name] = {}
    end
    env.HA = HA
    HA.PerformanceTrace = { Measure = function(_, op, _, fn, ...)
        env.measured[#env.measured + 1] = op
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
        IsVendorActive = function() return true end,
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
        GetScannedVendorRecord = function(_, v) return env.records[v.npcID] end,
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
        GetAllVendors = function()
            local out = {}
            for _, v in pairs(env.vendors) do out[#out + 1] = v end
            for npcID, ev in pairs(events) do
                if env.calendar[ev.event] == true and not env.vendors[npcID] then out[#out + 1] = ev end
            end
            return out
        end,
        FormatCost = function(_, cost) return (cost.gold or 0) .. "g" end,
    }
    HA.BadgeCalculation = {
        PeekVendorStats = function(_, v) return env.stats[v.npcID] end,
        RequestPrewarm = noop,
    }

    local function Load(file)
        assert(loadfile(root .. "/" .. file))("Homestead", HA)
    end
    for _, file in ipairs({ "Locale/enUS.lua", "Data/CatalogStore.lua", "Data/SourceManager.lua",
        "UI/VendorFilter.lua", "UI/Browser/Style.lua", "UI/Browser/Visuals.lua", "UI/Browser/Adapter.lua",
        "UI/Browser/Facts.lua", "UI/Browser/CanGet.lua", "UI/Browser/Widgets.lua" }) do
        Load(file)
    end
    local SM = HA.SourceManager
    SM.GetAllSources = function(_, id) return env.sources[id] or {} end
    SM.GetRequirements = function(_, id, npcID) return env.reqs[id .. ":" .. tostring(npcID)] or {} end
    SM.GetVendorItemCost = function() return { gold = 100 } end
    local isMet = SM.IsRequirementMet
    SM.IsRequirementMet = function(self, req)
        if req.met ~= nil then return req.met end
        return isMet(self, req)
    end
    HA.VendorFilter.GetBestVendorCoordinates = function(v) return v.coords, v.mapID end
    HA.CatalogStore:Initialize()

    local B = HA.DecorBrowser
    local W = B.Widgets
    env.B, env.W, env.D, env.CG, env.Facts = B, W, B.Data, B.CanGet, B.Facts

    -- The window: a stub, or the real Window.lua. The router and the tabs are the real files.
    local Win
    -- The tab a route kind belongs to, for the finders below.
    local TAB_OF = { overview = "summary", catalog = "catalog", item = "catalog" }
    local function TabOf(kind) return TAB_OF[kind] or "sources" end
    if env.realWindow then
        Load("UI/Browser/Window.lua")
        Win = B.Window
        local build, selectNav = Win.Build, Win.SelectNav
        function Win.Build(handlers)
            env.handlers = handlers
            return build(handlers)
        end
        function Win.SelectNav(route) env.tab, env.route = TabOf(route.kind), route return selectNav(route) end
    else
        Win = {}
        B.Window = Win
        function Win.AddSearchBox() end
        function Win.SetCrumb(segs) env.crumb = segs end
        function Win.SetBack() end
        function Win.SetSearch(text) env.search = text end
        function Win.SetPlaceholder(text) env.placeholder = text end
        function Win.UpdateCount() end
        function Win.SelectNav(route) env.tab, env.route = TabOf(route.kind), route end
        function Win.Build(handlers)
            env.handlers = handlers
            Win.frame, Win.host = Widget("Frame"), Widget("Frame")
            Win.hideNA = Widget("CheckButton")
            return Win.frame
        end
        for _, name in ipairs({ "PlayOpen", "PlayClose", "Fit", "CheckTextScale", "AssertPropagation", "StopGlow",
            "OnTextScale", "Glow" }) do
            Win[name] = noop
        end
    end
    Load("UI/Browser/Browser.lua")

    -- The page objects the pages register, in order, each with the first kind it was registered under.
    env.pageList, env.pageKinds = {}, {}
    local registerPage = B.RegisterPage
    function B.RegisterPage(kind, page)
        if not env.pageKinds[page] then
            env.pageList[#env.pageList + 1] = page
            env.pageKinds[page] = kind
        end
        return registerPage(kind, page)
    end

    -- Counts of what the tabs ask the router for.
    local realWalk, realSave = B.Walk, B.Save
    B.Walk = function()
        env.walkCalls = env.walkCalls + 1
        return realWalk()
    end
    B.Save = function(key, value)
        env.saves[#env.saves + 1] = key
        return realSave(key, value)
    end

    local newEmpty = W.NewEmptyState
    W.NewEmptyState = function(parent)
        local f = newEmpty(parent)
        local set = f.Set
        f.Set = function(self, kind, d)
            env.emptySets[#env.emptySets + 1] = { frame = self, kind = kind, d = d or {} }
            return set(self, kind, d)
        end
        return f
    end

    for _, file in ipairs({ "Summary", "Catalog", "Sources", "Item" }) do Load("UI/Browser/" .. file .. ".lua") end
    env.pageCount = #env.pageList

    -- Every item the item page is shown for.
    for _, page in ipairs(env.pageList) do
        if env.pageKinds[page] == "item" then
            local realShow = page.Show
            function page.Show(self, route, saved)
                local out = realShow(self, route, saved)
                env.itemShows[#env.itemShows + 1] = route.id
                return out
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Map: Eastern Kingdoms > Stormwind (the player), Elwynn Forest; Kalimdor > Orgrimmar
    ---------------------------------------------------------------------------
    env.maps = {
        [100] = { name = "Kalimdor", mapType = 2, parentMapID = 0 },
        [200] = { name = "Eastern Kingdoms", mapType = 2, parentMapID = 0 },
        [10] = { name = "Stormwind", mapType = 3, parentMapID = 200 },
        [11] = { name = "Elwynn Forest", mapType = 3, parentMapID = 200 },
        [20] = { name = "Orgrimmar", mapType = 3, parentMapID = 100 },
    }
    env.playerMap = 10

    ---------------------------------------------------------------------------
    -- Fixture builders
    ---------------------------------------------------------------------------
    function env.decor(itemID, name, entry)
        HA.DecorMapping[itemID + 900000] = itemID
        env.catalog[itemID] = entry or { totalNumStored = 0, categoryIDs = { 1 } }
        env.names[itemID] = name
    end
    function env.vendor(npcID, fields)
        local v = fields or {}
        v.npcID, v.mapID, v.items = npcID, v.mapID or 10, v.items or {}
        v.name = v.name or ("Vendor " .. npcID)
        v.zone = v.zone or "Stormwind"
        if v.coords == nil then v.coords = { x = 0.5, y = 0.5 } end
        env.vendors[npcID] = v
        return v
    end
    function env.sell(itemID, v, cost)
        local list = env.sources[itemID] or {}
        list[#list + 1] = { type = "vendor", data = { npcID = v.npcID, vendor = v, name = v.name, cost = cost or { gold = 100 } } }
        env.sources[itemID] = list
        env.offers[itemID] = true
        v.items[#v.items + 1] = itemID
    end
    -- A non-vendor source: records it for the item and in the source table the Sources tab lists.
    function env.give(itemID, sourceType, data, tbl)
        local list = env.sources[itemID] or {}
        list[#list + 1] = { type = sourceType, data = data }
        env.sources[itemID] = list
        HA[tbl][itemID] = data
    end
    function env.owned(itemID) env.catalog[itemID] = { totalNumStored = 1, categoryIDs = { 1 } } end

    ---------------------------------------------------------------------------
    -- The standard world. Player: Alliance in Stormwind.
    --   1 Oak Bench      Anna 300g, first-time bonus                  can
    --   2 Elm Chair      Anna 100g, also achievement 9002            can
    --   3 Cedar Table    Anna, one unmet requirement                  locked
    --   4 Pine Shelf     Bran, owned                                  owned
    --   5 Birch Lamp     Cora (Horde) only                            other faction only
    --   6 Ash Stool      Cora and Anna                                can
    --   7 Willow Rug     achievement 9001                             not collected
    --   8 Fir Candle     Anna, ownership unknown                      nothing
    --  12 Oak Crate      achievement 9003, owned                      owned
    --  13 Far Lantern    Eve, far away, first-time bonus, no spot     can
    --  21 Quest Chest    quest 7001                                   not collected
    --  22 Quest Mystery  quest 7002, ownership unknown                nothing
    --  31 Woven Rug      profession recipe 8001                       not collected
    --  41 Boss Banner    drop Boss|Keep                               not collected
    --  51 Spooky Lamp    Hallow's End vendor, out of season           "Hallow's End only"
    --  61 Shop Statue    Shop                                         not collected
    --  Optional opts.dale: 9 Dale Wreath, sold only by Dale (Alliance-flagged vendor 103).
    ---------------------------------------------------------------------------
    function env.standard()
        local anna = env.vendor(100, { name = "Anna", zone = "Stormwind", subzone = "Trade District", mapID = 10, scanConfirmed = "2026-10-01" })
        local bran = env.vendor(101, { name = "Bran", zone = "Elwynn Forest", mapID = 11 })
        local cora = env.vendor(102, { name = "Cora", zone = "Orgrimmar", mapID = 20, faction = "Horde" })
        local eve = env.vendor(104, { name = "Eve", zone = "Orgrimmar", mapID = 20, coords = false })
        env.decor(1, "Oak Bench", { totalNumStored = 0, firstAcquisitionBonus = 1, categoryIDs = { 1 } })
        env.decor(2, "Elm Chair")
        env.decor(3, "Cedar Table", { totalNumStored = 0, categoryIDs = { 2 } })
        env.decor(4, "Pine Shelf", { totalNumPlaced = 1, categoryIDs = { 3 } })
        env.decor(5, "Birch Lamp", { totalNumStored = 0, categoryIDs = { 4 } })
        env.decor(6, "Ash Stool")
        env.decor(7, "Willow Rug", { totalNumStored = 0, categoryIDs = { 3 } })
        env.decor(8, "Fir Candle")
        env.catalog[8] = nil
        env.decor(12, "Oak Crate", { totalNumPlaced = 1, categoryIDs = { 3 } })
        env.decor(13, "Far Lantern", { totalNumStored = 0, firstAcquisitionBonus = 1, categoryIDs = { 1 } })
        env.decor(21, "Quest Chest")
        env.decor(22, "Quest Mystery")
        env.catalog[22] = nil
        env.decor(31, "Woven Rug")
        env.decor(41, "Boss Banner")
        env.decor(51, "Spooky Lamp")
        env.decor(61, "Shop Statue")
        env.sell(1, anna, { gold = 300 })
        env.sell(2, anna, { gold = 100 })
        env.sell(3, anna, { gold = 50 })
        env.sell(4, bran, { gold = 10 })
        env.sell(5, cora, { gold = 70 })
        env.sell(6, cora, { gold = 70 })
        env.sell(6, anna, { gold = 20 })
        env.sell(8, anna, { gold = 30 })
        env.sell(13, eve, { gold = 80 })
        env.reqs["3:100"] = { { type = "unknown", text = "Mysterious Favor" } }
        env.give(2, "achievement", { achievementID = 9002, achievementName = "Chair Feat", category = "Cata" }, "AchievementSources")
        env.give(7, "achievement", { achievementID = 9001, achievementName = "Rug Feat", category = "Catb" }, "AchievementSources")
        env.give(12, "achievement", { achievementID = 9003, achievementName = "Crate Feat", category = "Cata" }, "AchievementSources")
        env.give(21, "quest", { questID = 7001, questName = "Quest One" }, "QuestSources")
        env.give(22, "quest", { questID = 7002, questName = "Quest Two" }, "QuestSources")
        env.give(31, "profession", { profession = "Tailoring", recipeName = "Rug", spellID = 8001, skillTier = "Classic Tailoring" }, "ProfessionSources")
        env.give(41, "drop", { mobName = "Boss", zone = "Keep", mapID = 10, coords = { x = 0.1, y = 0.2 }, notes = "Rare." }, "DropSources")
        env.give(61, "shop", { method = "hearthsteel" }, "ShopSources")
        HA.QuestStarts[7001] = { mapID = 10, x = 0.5, y = 0.6 }
        -- Out of season: nothing in GetVendor; the holiday table sells it.
        events[150] = { npcID = 150, event = "Hallow's End", mapID = 10, zone = "Stormwind", name = "Ghoul", items = { 51 }, _isEventVendor = true }
        HA.EventSources[51] = { event = "Hallow's End" }
        env.sources[51] = { { type = "event", data = { event = "Hallow's End", vendorName = "Ghoul", zone = "Stormwind" } } }
        if env.dale then
            local dale = env.vendor(103, { name = "Dale", zone = "Elwynn Forest", mapID = 11, faction = "Alliance" })
            env.decor(9, "Dale Wreath")
            env.sell(9, dale, { gold = 40 })
        end
        return { anna = anna, bran = bran, cora = cora, eve = eve }
    end

    ---------------------------------------------------------------------------
    -- Driving and reading
    ---------------------------------------------------------------------------
    function env.open()
        B:Open()
        assert(Win.frame, "the browser did not open")
        env.pages = {}
        for _, f in ipairs(env.all) do
            if f.parent == Win.host then env.pages[#env.pages + 1] = f end
        end
        assert(#env.pages == env.pageCount, "expected one frame per page, got " .. #env.pages)
    end
    -- A page key and its seed as the route the router takes. No seed keeps the page's state; an item id opens
    -- the item page, a vendor pick the vendor page, other picks the source page.
    local KIND_OF = { summary = "overview", catalog = "catalog", sources = "sources" }
    local SEED_KEY = { catalog = "kind", sources = "type" }
    function env.routeFor(key, seed)
        if key == "sources" and seed and seed.type == "vendors" then
            if seed.select then return { kind = "vendor", id = seed.select.key } end
            return { kind = "allVendors", seed = seed }
        end
        if key == "sources" and seed and seed.type and seed.select then
            return { kind = "source", key = seed.type, id = seed.select.key }
        end
        if key == "catalog" and seed and seed.itemID then return { kind = "item", id = seed.itemID } end
        local route = { kind = KIND_OF[key], seed = seed }
        if seed and SEED_KEY[key] then route.key = seed[SEED_KEY[key]] or key == "catalog" and "all" or nil end
        return route
    end
    function env.go(key, o) B.Go(env.routeFor(key, o)) end
    function env.flush()
        local run = env.timers
        env.timers = {}
        for _, t in ipairs(run) do
            if not t.cancelled then t.fn() end
        end
    end
    -- What the router does for a data event: the next coalesced refresh walks again.
    function env.dataChanged()
        B.RequestRefresh(false, true)
        env.flush()
    end
    function env.walks()
        local n = 0
        for _, op in ipairs(env.measured) do if op == "browser_walk" then n = n + 1 end end
        return n
    end

    -- The route kind a frame is drawn under (the first kind of its page), and the tab that kind lights up.
    function env.ownerKind(frame)
        local f = frame
        while f and f.parent ~= Win.host do f = f.parent end
        for i, page in ipairs(env.pages) do
            if page == f then return env.pageKinds[env.pageList[i]] end
        end
    end
    function env.owner(frame)
        local kind = env.ownerKind(frame)
        return kind and TabOf(kind)
    end
    function env.find(key, pred)
        for _, f in ipairs(env.all) do
            if env.owner(f) == key and pred(f) then return f end
        end
    end
    function env.button(key, text)
        return env.find(key, function(f) return f.kind == "Button" and f.text == text and f.shown and f.scripts.OnClick end)
    end
    function env.click(f, ...)
        assert(f, "no such frame")
        f.scripts.OnClick(f, ...)
    end
    function env.boxes(key)
        local out = {}
        for _, b in ipairs(env.boxList) do
            if env.owner(b) == key then out[#out + 1] = b end
        end
        return out
    end
    -- Catalog: the item ids in the list, in order, and the footer if there is one.
    function env.catalogList()
        local box = env.boxes("catalog")[1]
        local ids, footer = {}, nil
        for _, d in ipairs(box.shown and box.provider or {}) do
            if d.kind == "item" then ids[#ids + 1] = d.id else footer = d end
        end
        return ids, footer, box
    end
    function env.idString() return table.concat((env.catalogList()), ",") end
    -- The drawn Catalog row of an item, if it is among the rendered rows.
    function env.catalogRow(itemID)
        for _, f in ipairs(env.boxes("catalog")[1].frames) do
            if f.d and f.d.itemID == itemID then return f end
        end
    end
    function env.selectedItem()
        local shows = env.itemShows
        return shows[#shows]
    end
    -- The item page: the first line of each shown source row, top to bottom.
    function env.itemRows()
        local rows = {}
        for _, f in ipairs(env.all) do
            if f.one and f.shown and env.ownerKind(f) == "item" then rows[#rows + 1] = f end
        end
        table.sort(rows, function(a, b) return a.pt[5] > b.pt[5] end)
        local out = {}
        for i, f in ipairs(rows) do out[i] = f.one.text end
        return table.concat(out, " | ")
    end
    -- Sources: the main list's rows, its footer and its box.
    function env.sourcesList()
        local box = env.boxes("sources")[1]
        local rows, footer = {}, nil
        for _, d in ipairs(box.shown and box.provider or {}) do
            if d.kind == "row" then
                rows[#rows + 1] = d
            elseif d.kind == "foot" then
                footer = d
            end
        end
        return rows, footer, box
    end
    function env.sourceKeys()
        local keys = {}
        for i, d in ipairs((env.sourcesList())) do keys[i] = tostring(d.key) end
        return table.concat(keys, ",")
    end
    function env.decorList()
        local box
        for _, b in ipairs(env.boxList) do
            if env.ownerKind(b) == "source" then box = b end
        end
        local rows = {}
        for _, d in ipairs(box.provider) do
            if d.kind == "row" then rows[#rows + 1] = d end
        end
        return rows, box
    end
    function env.decorIds()
        local ids = {}
        for i, d in ipairs((env.decorList())) do ids[i] = d.itemID end
        table.sort(ids)
        return table.concat(ids, ",")
    end
    -- The vendor page: its wares as the grid draws them, and the grid's box.
    function env.wareList()
        for _, b in ipairs(env.boxList) do
            if env.ownerKind(b) == "vendor" then return b.provider, b end
        end
    end
    function env.wareIds()
        local ids = {}
        for i, d in ipairs((env.wareList())) do ids[i] = d.itemID end
        table.sort(ids)
        return table.concat(ids, ",")
    end
    -- The last empty-state call made under a tab.
    function env.emptyOf(key)
        for i = #env.emptySets, 1, -1 do
            local e = env.emptySets[i]
            if env.owner(e.frame) == key and e.frame.shown then return e end
        end
    end
    function env.searchText(key)
        local box = env.find(key, function(f) return f.kind == "EditBox" end)
        return box and box.text
    end
    function env.lastScroll(box)
        return box.scrolls[#box.scrolls]
    end
    function env.indexOf(box, pred)
        for i, d in ipairs(box.provider) do
            if pred(d) then return i end
        end
    end
    return env
end
