-- Browser entry points, page router, refresh coalescing, combat state and the item tooltip.
--
-- Pages call B.RegisterPage(key, page) at load. Page fields:
--   Build(host) -> frame   once, on first show; the frame fills host
--   Show(route, isRefresh, noPrewarm)  fill the page. isRefresh: data, search or Hide owned changed
--                          in view. Pass noPrewarm on to B.Data.VendorCounts
--   Shown()                optional: window just became visible; replay bar easing
--   Hide()                 optional: page leaves view or window closes
--   SetCombatGated(gated)  optional: after each Show and when combat starts or ends
--   topLevel               pages the navigation column reaches (no breadcrumb)
--   searchable             header search filters this page
--   usesCounts             page reads the vendor-count cache: a finished background fill re-renders it
-- Routes: { page = key, nav = navigation key, label = breadcrumb text (optional), ... }; shops adds
--   expansion or nearYou, shop npcID, item itemID and npcID, sources source ("achievements" ... "events").
-- Pages read B.State.search (lowercase, "" for none), hideOwned and catalogMemo (catalog reads; one page show).
-- Delayed model work checks B.Generation() first: it changes on every page show and window close.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local Win = B.Window

BINDING_HEADER_HOMESTEAD = L["Homestead"]
BINDING_NAME_HOMESTEAD_TOGGLE_BROWSER = L["Toggle Decor Browser"]

local HISTORY_MAX = 40
local REFRESH_DELAY = 0.5
local DATA_EVENTS = {
    "OWNERSHIP_UPDATED", "VENDOR_SCANNED", "ACTIVE_HOLIDAYS_CHANGED",
    "ACTIVE_ENDEAVOR_CHANGED", "SOURCE_CACHES_INVALIDATED",
}

local State = {
    history = {}, search = "", hideOwned = false, catalogMemo = {}, inCombat = false,
    collapsed = setmetatable({}, { __index = function(t, k) local s = {} t[k] = s return s end }),
}
B.State = State

local pages, frames = B.pages, {}
local current, events
local generation = 0
local memoWipedAt

function B.Generation()
    return generation
end

function B.InCombat()
    return State.inCombat
end

function B.IsTopLevel(route)
    local page = pages[route.page]
    return page ~= nil and page.topLevel == true
end

local function Trace(operation, workload, fn, ...)
    return HA.PerformanceTrace:Measure(operation, workload, fn, ...)
end

local function Overview()
    return { page = "overview", nav = "overview" }
end

local function ApplyCombat(page)
    if page.SetCombatGated then page.SetCombatGated(State.inCombat) end
end

local function Render(route, isRefresh, noPrewarm)
    local page = pages[route.page]
    if not page then
        route = Overview()
        page = pages.overview
    end
    if not isRefresh then
        generation = generation + 1
        if current and current ~= page then
            if current.Hide then current.Hide() end
            frames[current]:Hide()
        end
        if not frames[page] then frames[page] = page.Build(Win.host) end
        frames[page]:Show()
        current = page
        State.route = route
        State.search = ""
        Win.ResetSearch(page.searchable == true)
        Win.SelectNav(route.nav)
    end
    local version = B.Data.MemoVersion()
    if not isRefresh or version ~= memoWipedAt then
        wipe(State.catalogMemo)
        memoWipedAt = version
    end
    Win.UpdateCrumbs(route)
    Win.UpdateProgress()
    page.Show(route, isRefresh, noPrewarm == true)
    ApplyCombat(page)
end

-- Every saved write comes from a player action; Options redraws on a changed 3D setting.
function B.Save(key, value)
    local s = B.Saved()
    if not s then return end
    s[key] = value
    local O = HA.OptionsFrame
    if key == "model3D" and O and O:IsShown() then O:Refresh() end
end

local ROUTE_KEYS = { "page", "nav", "expansion", "nearYou", "npcID", "itemID", "source" }
local SOURCES = { achievements = true, quests = true, professions = true, drops = true, events = true }

local function Navigate(route)
    Trace("browser_page_show", route.page, Render, route)
    local saved = {}
    for _, k in ipairs(ROUTE_KEYS) do saved[k] = State.route[k] end
    B.Save("lastPage", saved)
end

local function IsExpansion(exp)
    for _, e in ipairs(B.Data.Expansions()) do
        if e == exp then return true end
    end
    return false
end

local function ListedVendor(npcID)
    local v = type(npcID) == "number" and B.Data.Vendor(npcID)
    return v and B.Data.IsListedVendor(v) or false
end

-- A new route from a saved one, or nil (Overview) unless its shape is known and what it names still lists
-- (an item page keeps its vendor only while that vendor does).
function B.ValidateLastPage(t)
    if type(t) ~= "table" then return nil end
    local D, p, r = B.Data, t.page, nil
    if p == "overview" then
        r = { page = p, nav = "overview" }
    elseif p == "shops" and t.nearYou == true then
        r = { page = p, nearYou = true, nav = "nearyou" }
    elseif p == "shops" and IsExpansion(t.expansion) then
        r = { page = p, expansion = t.expansion, nav = "vendors:" .. t.expansion }
    elseif p == "sources" and SOURCES[t.source] then
        r = { page = p, source = t.source, nav = t.source }
    elseif p == "shop" and ListedVendor(t.npcID) then
        r = { page = p, npcID = t.npcID }
    elseif p == "item" and type(t.itemID) == "number" and D.ItemKnown(t.itemID) then
        r = { page = p, itemID = t.itemID, npcID = ListedVendor(t.npcID) and t.npcID or nil }
    end
    if r and not r.nav then
        local nav = type(t.nav) == "string" and t.nav or ""
        local exp = nav:match("^vendors:(.+)$")
        r.nav = (Win.NavLabel(nav) or (exp and IsExpansion(exp))) and nav or "overview"
    end
    return r
end

function B.Go(route)
    local h = State.history
    if State.route then
        h[#h + 1] = State.route
        if #h > HISTORY_MAX then table.remove(h, 1) end
    end
    route.nav = route.nav or (State.route and State.route.nav) or "overview"
    Navigate(route)
end

function B.Back()
    local h = State.history
    local r = h[#h]
    if not r then return end
    h[#h] = nil
    Navigate(r)
end

-- idx counts history entries then the current route. Going to idx drops it and everything after, as
-- repeated Back would; a route passed in replaces that entry.
function B.GoCrumb(idx, route)
    local h = State.history
    if idx > #h then return end
    local target = route or h[idx]
    for i = #h, idx, -1 do h[i] = nil end
    Navigate(target)
end

local function Shown()
    return Win.frame ~= nil and Win.frame:IsShown()
end

local function RefreshInPlace(workload, noPrewarm)
    if State.route then Trace("browser_refresh", workload, Render, State.route, true, noPrewarm) end
end

function B.SetSearch(text)
    State.search = text or ""
    RefreshInPlace("search")
end

local function StoreHideOwned(on)
    State.hideOwned = on and true or false
    B.Save("hideOwned", State.hideOwned)
    if Win.frame then Win.SetHideOwnedChecked(State.hideOwned) end
end

function B.SetHideOwned(on)
    StoreHideOwned(on)
    if Shown() then RefreshInPlace("hideOwned") end
end

function B.ClearFilters()
    Win.ResetSearch(current ~= nil and current.searchable == true)
    State.search = ""
    StoreHideOwned(false)
    if Shown() then RefreshInPlace("clearFilters") end
end

local refreshPending, prewarmAllowed, dataChanged = false, false, false

local function RunRefresh()
    refreshPending = false
    local allowed, changed = prewarmAllowed, dataChanged
    prewarmAllowed, dataChanged = false, false
    if not (Shown() and State.route) then return end
    if not (allowed or changed or (current and current.usesCounts)) then return end
    if changed then B.Data.InvalidateMemos() end
    RefreshInPlace(State.route.page, not allowed)
end

-- Coalesces bursts into one refresh half a second later, if shown. fromStatsFill must not ask for another
-- fill; newData drops memoised totals (item names and the fill keep them).
function B.RequestRefresh(fromStatsFill, newData)
    if not fromStatsFill then prewarmAllowed = true end
    if newData then dataChanged = true end
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(REFRESH_DELAY, RunRefresh)
end

local function RegisterDataEvents()
    local function onData()
        if Shown() then B.RequestRefresh(false, true) end
    end
    for _, name in ipairs(DATA_EVENTS) do HA.Events:RegisterCallback(name, onData) end
    HA.Events:RegisterCallback("HS_VENDOR_STATS_WARMED", function()
        if Shown() then B.RequestRefresh(true) end
    end)
end

local function SetCombat(inCombat)
    State.inCombat = inCombat
    if current and Shown() then ApplyCombat(current) end
end

local function OnEvent(_, event, itemID, success)
    if event == "GET_ITEM_INFO_RECEIVED" then
        if B.Data.NameArrived(itemID, success) then B.RequestRefresh() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        SetCombat(true)
    else
        Win.AssertPropagation()
        SetCombat(false)
    end
end

local function OnShow()
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    Win.AssertPropagation()
    Win.sheen:Play()
    B.Widgets.RefreshPulses()
    if current and current.Shown then current.Shown() end
end

local function OnHide()
    events:UnregisterAllEvents()
    if current and current.Hide then current.Hide() end
    B.Widgets.StopAll()
    Win.sheen:Stop()
    Win.CancelSearch()
    B.HideTooltip()
    generation = generation + 1
end

local function Build()
    local f = Win.Build(OnShow, OnHide)
    events = CreateFrame("Frame", nil, f)
    events:SetScript("OnEvent", OnEvent)
    local s = B.Saved()
    State.hideOwned = s ~= nil and s.hideOwned == true
    Win.SetHideOwnedChecked(State.hideOwned)
    RegisterDataEvents()
end

local function OpenNow()
    if not Win.frame then Build() end
    Win.Clamp()
    B.Data.InvalidateMemos()
    State.inCombat = InCombatLockdown()
    local s = B.Saved()
    Render(State.route or B.ValidateLastPage(s and s.lastPage) or Overview())
    Win.frame:Show()
end

local function Ready()
    return HA.Addon and HA.Addon._enabled and not HA.__collisionStandDown and B.Data.IsReady()
end

function B:Open()
    if Shown() then return end
    if not Ready() then
        local msg = L["The Decor Browser opens once Homestead has finished loading."]
        if HA.Addon and HA.Addon.Print then HA.Addon:Print(msg) else print(msg) end
        return
    end
    Trace(Win.frame and "browser_reopen" or "browser_first_open", nil, OpenNow)
end

-- Options changed a browser setting. A never-opened browser builds nothing; a hidden one picks it up on show.
function B:OnSettingChanged()
    State.model3D = nil
    if not Shown() then return end
    Win.sheen:Play()
    B.Widgets.RefreshPulses()
    RefreshInPlace("settings")
end

function B:Close()
    if Win.frame then Win.frame:Hide() end
end

function B:Toggle()
    if Shown() then self:Close() else self:Open() end
end

local tooltip

function B.Tooltip()
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", "HomesteadBrowserTooltip", UIParent, "GameTooltipTemplate")
    end
    return tooltip
end

function B.HideTooltip()
    if tooltip then tooltip:Hide() end
end

local LABEL = { 0.74, 0.70, 0.62 }

local function Pair(tip, label, value)
    tip:AddDoubleLine(label, tostring(value), LABEL[1], LABEL[2], LABEL[3], 1, 1, 1)
end

function B.ShowItemTooltip(owner, itemID, npcID)
    local S = B.Style
    local d = B.Data.TooltipData(itemID, npcID, State.catalogMemo)
    local tip = B.Tooltip()
    local gold = NORMAL_FONT_COLOR
    local r, g, b = 1, 1, 1
    if d.quality then r, g, b = C_Item.GetItemQualityColor(d.quality) end
    local sc = S.color.stateText[d.state] or S.color.stateText.unknown

    tip:SetOwner(owner, "ANCHOR_RIGHT")
    tip:AddLine(d.name, r, g, b)
    tip:AddLine(S.stateLabel[d.state] or "", sc[1], sc[2], sc[3])
    tip:AddLine(L["Collection"], gold.r, gold.g, gold.b)
    if d.counts then
        Pair(tip, L["Placed"], d.counts.placed)
        Pair(tip, L["In storage"], d.counts.stored)
        if d.counts.redeemable > 0 then Pair(tip, L["Not yet redeemed"], d.counts.redeemable) end
    else
        tip:AddLine(L["Counts not loaded yet"], 0.6, 0.6, 0.6)
    end
    tip:AddLine(L["Source"], gold.r, gold.g, gold.b)
    if d.price then Pair(tip, L["Price"], d.price) end
    tip:AddLine(d.source, LABEL[1], LABEL[2], LABEL[3], true)
    tip:Show()
end

function B.ShowLinkTooltip(owner, link)
    if not link then return end
    local tip = B.Tooltip()
    tip:SetOwner(owner, "ANCHOR_RIGHT")
    tip:SetHyperlink(link)
    tip:Show()
end
