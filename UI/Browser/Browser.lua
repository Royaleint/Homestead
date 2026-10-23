-- Browser router: pages and routes, opening and closing, coalesced refresh, events while shown, combat state
-- and the item tooltip. Delayed work checks B.Generation() first: it changes on every open and every close.
-- Page contract: Show(route, saved) gets saved only on Back. Hide tears down transient state and keeps the
-- route. Refresh may follow Hide without Show (UI restore); Refresh must restore whatever Hide tore down.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local Win = B.Window

BINDING_HEADER_HOMESTEAD = L["Homestead"]
BINDING_NAME_HOMESTEAD_TOGGLE_BROWSER = L["Toggle Decor Browser"]

local REFRESH_DELAY = 0.5
local DATA_EVENTS = {
    "OWNERSHIP_UPDATED", "SOURCE_CACHES_INVALIDATED", "ACTIVE_HOLIDAYS_CHANGED",
    "ACTIVE_ENDEAVOR_CHANGED", "HS_CATALOG_TRUE_WARM", "HS_CATALOG_READ_STATE",
}
local GAME_EVENTS = {
    "GET_ITEM_INFO_RECEIVED", "PORTRAITS_UPDATED", "COLOR_OVERRIDE_UPDATED", "COLOR_OVERRIDES_RESET",
    "ZONE_CHANGED_NEW_AREA", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}
local TEXT_SCALE_EVENT = "TextSizeManager.OnTextScaleUpdated"

local State = {
    hideNA = false, inCombat = false, generation = 0, noPrewarm = false, catalogMemo = {},
}
B.State = State

local kindPage, kinds, frames, history = {}, {}, {}, {}
local curRoute

local function Current()
    return curRoute and kindPage[curRoute.kind]
end

local events, callbacks, textScaleOwner
local memoWipedAt
local opening = false

function B.Generation()
    return State.generation
end

function B.InCombat()
    return State.inCombat
end

local function Trace(operation, workload, fn, ...)
    return HA.PerformanceTrace:Measure(operation, workload, fn, ...)
end

-- Every saved write comes from a player action.
function B.Save(key, value)
    local s = B.Saved()
    if not s then return end
    s[key] = value
end

local function Shown()
    return Win.frame ~= nil and Win.frame:IsVisible() and not Win.closing
end

function B.Walk()
    return B.CanGet.Walk()
end

-- page = { Build(parent), Show(route, saved), Hide(), Refresh(reason), SetCombat(on), Save() }; built once
-- however many kinds it serves.
function B.RegisterPage(kind, page)
    if not kindPage[kind] then kinds[#kinds + 1] = kind end
    kindPage[kind] = page
end

local TAB_KIND = { summary = "overview", catalog = "catalog", sources = "sources" }
local TAB_OF = { overview = "summary", catalog = "catalog", item = "catalog" }
local SEED_KEY = { catalog = "kind", sources = "type" }

function B.TabOf(kind)
    return TAB_OF[kind] or "sources"
end

-- A tab-era page: Show(opts) gets the seed as is, else the key, else nil.
function B.RegisterTab(key, tab)
    local field = SEED_KEY[key]
    local page = { Save = function() end }
    function page:Show(route)
        tab.Show(route.seed or route.key and { [field] = route.key } or nil)
    end
    for _, name in ipairs({ "Build", "Hide", "Refresh", "SetCombat" }) do
        page[name] = function(_, ...) return tab[name](...) end
    end
    B.RegisterPage(TAB_KIND[key], page)
end

local WORD = {}
for _, t in ipairs(Win.TABS) do WORD[t.key] = t.word end

-- The header's location line: the tab's word, then what the tab says is open in it.
function B.SetLocation(detail)
    local word = curRoute and WORD[B.TabOf(curRoute.kind)] or ""
    Win.SetLocation(detail and (word .. "  \226\128\186  " .. detail) or word)
end

-- The crumb: the page's home in the tree (its parent, then itself), never the path walked.
function B.Home(route)
    local kind, key = route.kind, route.key
    local up = (kind == "item" or kind == "catalog" and key and key ~= "all") and { kind = "catalog", key = "all" }
        or (kind == "vendors" or kind == "vendor") and { kind = "allVendors" }
        or kind == "source" and { kind = "sources", key = key }
    return up and { up, route } or { route }
end

local function SyncMemo()
    local version = B.Data.MemoVersion()
    if version ~= memoWipedAt then
        wipe(State.catalogMemo)
        memoWipedAt = version
    end
end

local function Transition(route, saved)
    local page = kindPage[route.kind]
    if not page then error("no page for the route kind " .. tostring(route.kind), 2) end
    local old = Current()
    if old then old:Hide() end
    if old and old ~= page then frames[curRoute.kind]:Hide() end
    curRoute = route
    frames[route.kind]:Show()
    B.SetLocation()
    page:Show(route, saved)
    Win.SetCrumb(B.Home(route))
    Win.SelectNav(route)
    Win.SetBack(#history > 0)
    page:SetCombat(State.inCombat)
end

local function GoNow(route)
    if curRoute and curRoute.kind == route.kind and curRoute.key == route.key and curRoute.id == route.id then
        local page = Current()
        if route.seed then page:Show(route) else page:Refresh("route") end
        return
    end
    if curRoute then
        history[#history + 1] = { { kind = curRoute.kind, key = curRoute.key, id = curRoute.id }, Current():Save() }
        if #history > 40 then table.remove(history, 1) end
    end
    Transition(route)
end

local function Traced(route, fn, ...)
    SyncMemo()
    Trace("browser_page_show", route.kind, fn, route, ...)
end

function B.Go(route)
    Traced(route, GoNow)
end

function B.Back()
    local entry = table.remove(history)
    if entry then Traced(entry[1], Transition, entry[2]) end
end

function B.ShowTab(key, opts)
    local route = { kind = TAB_KIND[key], seed = opts }
    if opts and SEED_KEY[key] then route.key = opts[SEED_KEY[key]] or key == "catalog" and "all" or nil end
    B.Go(route)
end

local function SetCombat(inCombat)
    State.inCombat = inCombat
    for _, kind in ipairs(kinds) do kindPage[kind]:SetCombat(inCombat) end
end

function B.SetHideNA(on)
    State.hideNA = on
    B.Save("hideNA", on)
    local page = Current()
    if page then page:Refresh("hide") end
end

-- Pending refresh: stale (walk out of date), names (item names arrived), prewarm (a data change or a
-- name may ask for the vendor-count fill; a fill-only repaint must not, or fill and repaint loop).
local timer
local stale, names, prewarm = false, false, false

local function ClearPending()
    if timer then timer:Cancel() end
    timer = nil
    stale, names, prewarm = false, false, false
end

local function Repaint(reason)
    SyncMemo()
    Current():Refresh(reason)
end

-- The walk runs only here, at most once per coalesced refresh, in combat too.
local function RunRefresh()
    local wasStale, hadNames, allowed = stale, names, prewarm
    timer = nil
    stale, names, prewarm = false, false, false
    if not (Shown() and curRoute) then return end
    if wasStale then B.Data.InvalidateMemos() end
    if hadNames then B.CanGet.RefreshNames() end
    local reason = wasStale and "data" or hadNames and "names" or "stats"
    State.noPrewarm = not allowed
    Trace("browser_refresh", reason, Repaint, reason)
    State.noPrewarm = false
end

-- Coalesces bursts into one refresh half a second later, if shown. fromStatsFill must not ask for another
-- fill; newData marks the walk stale.
function B.RequestRefresh(fromStatsFill, newData)
    if not fromStatsFill then prewarm = true end
    if newData then stale = true end
    if timer then return end
    timer = C_Timer.NewTimer(REFRESH_DELAY, RunRefresh)
end

local function ScanMatters(record)
    if type(record) ~= "table" or record.hasHousing then return true end
    return HA.VendorData:GetVendor(record.npcID) ~= nil
end

local function BuildCallbacks()
    callbacks = {
        data = function() if Shown() then B.RequestRefresh(false, true) end end,
        scan = function(record)
            if Shown() and ScanMatters(record) then
                -- A scan adds sources without SOURCE_CACHES_INVALIDATED.
                B.CanGet.ResetFactionOnly()
                B.RequestRefresh(false, true)
            end
        end,
        stats = function() if Shown() then B.RequestRefresh(true) end end,
    }
    textScaleOwner = {}
end

local function OnEvent(_, event, arg1, arg2)
    if not Shown() then return end
    if event == "GET_ITEM_INFO_RECEIVED" then
        if B.Data.NameArrived(arg1, arg2) then
            names = true
            B.RequestRefresh()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        SetCombat(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        Win.AssertPropagation()
        SetCombat(false)
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        Win.Fit()
        Repaint("layout")
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        Repaint("zone")
    else
        Repaint("paint")
    end
end

local function OnTextScale()
    if not Shown() then return end
    Win.OnTextScale()
    Repaint("layout")
end

local function OnShow()
    for _, name in ipairs(DATA_EVENTS) do HA.Events:RegisterCallback(name, callbacks.data) end
    HA.Events:RegisterCallback("VENDOR_SCANNED", callbacks.scan)
    HA.Events:RegisterCallback("HS_VENDOR_STATS_WARMED", callbacks.stats)
    HA.Events:RegisterCallback("SOURCE_CACHES_INVALIDATED", B.CanGet.ResetFactionOnly)
    B.CanGet.ResetFactionOnly()
    for _, name in ipairs(GAME_EVENTS) do events:RegisterEvent(name) end
    EventRegistry:RegisterCallback(TEXT_SCALE_EVENT, OnTextScale, textScaleOwner)
    Win.AssertPropagation()
    Win.CheckTextScale()
    Win.Fit()
    if opening then return end
    -- Back from Alt+Z: nothing was heard while hidden.
    SetCombat(InCombatLockdown())
    B.RequestRefresh(false, true)
end

local function OnHide()
    for _, name in ipairs(DATA_EVENTS) do HA.Events:UnregisterCallback(name, callbacks.data) end
    HA.Events:UnregisterCallback("VENDOR_SCANNED", callbacks.scan)
    HA.Events:UnregisterCallback("HS_VENDOR_STATS_WARMED", callbacks.stats)
    HA.Events:UnregisterCallback("SOURCE_CACHES_INVALIDATED", B.CanGet.ResetFactionOnly)
    events:UnregisterAllEvents()
    EventRegistry:UnregisterCallback(TEXT_SCALE_EVENT, textScaleOwner)
    ClearPending()
    Win.closing = false
    Win.StopGlow()
    local page = Current()
    if page then page:Hide() end
    B.HideTooltip()
    State.generation = State.generation + 1
end

local function Build()
    BuildCallbacks()
    local f = Win.Build({
        OnShow = OnShow, OnHide = OnHide,
        Close = function() B:Close() end,
        Help = function() B.Go({ kind = "overview", seed = { showTip = true } }) end,
        HideNA = B.SetHideNA,
        SelectTab = function(key) B.ShowTab(key) end,
    })
    events = CreateFrame("Frame", nil, f)
    events:SetScript("OnEvent", OnEvent)
    local built = {}
    for _, kind in ipairs(kinds) do
        local page = kindPage[kind]
        if not built[page] then
            local frame = CreateFrame("Frame", nil, Win.host)
            frame:SetAllPoints()
            frame:Hide()
            built[page] = frame
            page:Build(frame)
        end
        frames[kind] = built[page]
    end
    local s = B.Saved()
    State.hideNA = s and s.hideNA == true or false
end

local function OpenNow()
    if not Win.frame then Build() end
    B.Data.InvalidateMemos()
    B.Facts.Here()
    SetCombat(InCombatLockdown())
    Win.hideNA:SetChecked(State.hideNA)
    Win.CheckTextScale()
    State.generation = State.generation + 1
    opening = true
    wipe(history)
    if curRoute then Current():Hide() frames[curRoute.kind]:Hide() end
    curRoute = nil
    B.Go({ kind = "overview" })
    Win.PlayOpen()
    opening = false
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

function B:Close()
    if not Win.frame then return end
    B.HideTooltip()
    Win.StopGlow()
    Win.PlayClose()
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

function B.HideTooltipFor(owner)
    if tooltip and tooltip:IsShown() and tooltip:GetOwner() == owner then tooltip:Hide() end
end

local LABEL = { 0.74, 0.70, 0.62 }

local function Pair(tip, label, value)
    tip:AddDoubleLine(label, tostring(value), LABEL[1], LABEL[2], LABEL[3], 1, 1, 1)
end

function B.ShowItemTooltip(owner, itemID, npcID)
    local W = B.Widgets
    local d = B.Data.TooltipData(itemID, npcID, State.catalogMemo)
    local tip = B.Tooltip()
    local gold = NORMAL_FONT_COLOR
    local r, g, b = W.QualityRGB(d.quality)
    local state, arg = B.ItemState(itemID, npcID)

    tip:SetOwner(owner, "ANCHOR_RIGHT")
    tip:AddLine(d.name, r, g, b)
    if state then
        local c = B.Style.state[state].color
        tip:AddLine(W.StateWords(state, arg), c[1], c[2], c[3])
    end
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
    if d.unconfirmed then tip:AddLine(B.Facts.NotConfirmed(), LABEL[1], LABEL[2], LABEL[3], true) end
    tip:Show()
end
