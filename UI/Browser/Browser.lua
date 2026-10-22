-- Browser router: tabs, opening and closing, coalesced refresh, events while shown, combat state and the
-- item tooltip. Delayed work checks B.Generation() first: it changes on every open and every close.
-- Tab contract: Show(opts) gets nil on a plain tab switch (keep state) and a table to set state. Refresh may
-- follow Hide without Show (UI restore); Refresh must restore whatever Hide tore down.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local Win = B.Window

BINDING_HEADER_HOMESTEAD = L["Homestead"]
BINDING_NAME_HOMESTEAD_TOGGLE_BROWSER = L["Toggle Decor Browser"]

local REFRESH_DELAY = 0.5
-- Each marks the walk stale; one refresh follows.
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

-- hideNA: the Hide toggle. noPrewarm: true while a refresh must not ask for the vendor-count fill.
local State = {
    hideNA = false, inCombat = false, generation = 0, noPrewarm = false, catalogMemo = {},
}
B.State = State

local tabs, pages, current = {}, {}, nil
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

-- Visible (Alt+Z hides it) and not fading out.
local function Shown()
    return Win.frame ~= nil and Win.frame:IsVisible() and not Win.closing
end

-- The memoised walk over every decor item; nil until the collection is ready.
function B.Walk()
    return B.CanGet.Walk()
end

-- tab = { Build(parent), Show(opts), Hide(), Refresh(reason), SetCombat(inCombat) }; see the contract above.
function B.RegisterTab(key, tab)
    tabs[key] = tab
end

local WORD = {}
for _, t in ipairs(Win.TABS) do WORD[t.key] = t.word end

-- The header's location line: the tab's word, then what the tab says is open in it.
function B.SetLocation(detail)
    local word = WORD[current] or ""
    Win.SetLocation(detail and (word .. "  \226\128\186  " .. detail) or word)
end

-- Empties the catalog memo when the shared memos moved on since it was filled.
local function SyncMemo()
    local version = B.Data.MemoVersion()
    if version ~= memoWipedAt then
        wipe(State.catalogMemo)
        memoWipedAt = version
    end
end

local function ShowTabNow(key, opts)
    if current and current ~= key then
        tabs[current].Hide()
        pages[current]:Hide()
    end
    current = key
    Win.SetSelectedTab(key)
    pages[key]:Show()
    B.SetLocation()
    tabs[key].Show(opts)
end

function B.ShowTab(key, opts)
    SyncMemo()
    Trace("browser_tab_show", key, ShowTabNow, key, opts)
end

local function SetCombat(inCombat)
    State.inCombat = inCombat
    for _, tab in pairs(tabs) do tab.SetCombat(inCombat) end
end

function B.SetHideNA(on)
    State.hideNA = on
    B.Save("hideNA", on)
    if current then tabs[current].Refresh("hide") end
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
    tabs[current].Refresh(reason)
end

-- The walk runs only here, at most once per coalesced refresh, in combat too.
local function RunRefresh()
    local wasStale, hadNames, allowed = stale, names, prewarm
    timer = nil
    stale, names, prewarm = false, false, false
    if not (Shown() and current) then return end
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

-- A scan of a merchant the browser does not know, with no housing items, changes nothing it shows.
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
    if current then tabs[current].Hide() end
    B.HideTooltip()
    State.generation = State.generation + 1
end

local function Build()
    BuildCallbacks()
    local f = Win.Build({
        OnShow = OnShow, OnHide = OnHide,
        Close = function() B:Close() end,
        Help = function() B.ShowTab("summary", { showTip = true }) end,
        HideNA = B.SetHideNA,
        SelectTab = function(key) B.ShowTab(key) end,
    })
    events = CreateFrame("Frame", nil, f)
    events:SetScript("OnEvent", OnEvent)
    for _, t in ipairs(Win.TABS) do
        local page = CreateFrame("Frame", nil, Win.host)
        page:SetAllPoints()
        page:Hide()
        pages[t.key] = page
        tabs[t.key].Build(page)
    end
    local s = B.Saved()
    State.hideNA = s and s.hideNA == true or false
end

-- Every open: build once, drop the walk (it re-reads the collection state), read the zone and combat,
-- draw Summary, then show and fade in.
local function OpenNow()
    if not Win.frame then Build() end
    B.Data.InvalidateMemos()
    B.Facts.Here()
    SetCombat(InCombatLockdown())
    Win.hideNA:SetChecked(State.hideNA)
    Win.CheckTextScale()
    State.generation = State.generation + 1
    opening = true
    B.ShowTab("summary")
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
