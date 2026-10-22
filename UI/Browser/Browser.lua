-- Browser entry points, refresh coalescing, combat state and the item tooltip.
-- Reads B.State.search (lowercase, "" for none) and catalogMemo (catalog reads; one show).
-- Delayed model work checks B.Generation() first: it changes on every show and window close.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local Win = B.Window

BINDING_HEADER_HOMESTEAD = L["Homestead"]
BINDING_NAME_HOMESTEAD_TOGGLE_BROWSER = L["Toggle Decor Browser"]

local REFRESH_DELAY = 0.5
local DATA_EVENTS = {
    "OWNERSHIP_UPDATED", "VENDOR_SCANNED", "ACTIVE_HOLIDAYS_CHANGED",
    "ACTIVE_ENDEAVOR_CHANGED", "SOURCE_CACHES_INVALIDATED",
}

local State = {
    search = "", catalogMemo = {}, inCombat = false,
    collapsed = setmetatable({}, { __index = function(t, k) local s = {} t[k] = s return s end }),
}
B.State = State

local events
local generation = 0
local memoWipedAt

function B.Generation()
    return generation
end

function B.InCombat()
    return State.inCombat
end

local function Trace(operation, workload, fn, ...)
    return HA.PerformanceTrace:Measure(operation, workload, fn, ...)
end

-- Stub until the tab router lands: a show only advances the generation and empties the catalog memo.
local function Render(isRefresh)
    if not isRefresh then
        generation = generation + 1
        State.search = ""
        Win.ResetSearch(false)
    end
    local version = B.Data.MemoVersion()
    if not isRefresh or version ~= memoWipedAt then
        wipe(State.catalogMemo)
        memoWipedAt = version
    end
end

-- Every saved write comes from a player action.
function B.Save(key, value)
    local s = B.Saved()
    if not s then return end
    s[key] = value
end

local function Shown()
    return Win.frame ~= nil and Win.frame:IsShown()
end

local function RefreshInPlace(workload)
    Trace("browser_refresh", workload, Render, true)
end

function B.SetSearch(text)
    State.search = text or ""
    RefreshInPlace("search")
end

function B.ClearFilters()
    Win.ResetSearch(Win.search:IsEnabled())
    State.search = ""
    if Shown() then RefreshInPlace("clearFilters") end
end

local refreshPending, prewarmAllowed, dataChanged = false, false, false

local function RunRefresh()
    refreshPending = false
    local allowed, changed = prewarmAllowed, dataChanged
    prewarmAllowed, dataChanged = false, false
    if not Shown() then return end
    if not (allowed or changed) then return end
    if changed then B.Data.InvalidateMemos() end
    RefreshInPlace("data")
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
end

local function OnHide()
    events:UnregisterAllEvents()
    Win.CancelSearch()
    B.HideTooltip()
    generation = generation + 1
end

local function Build()
    local f = Win.Build(OnShow, OnHide)
    events = CreateFrame("Frame", nil, f)
    events:SetScript("OnEvent", OnEvent)
    RegisterDataEvents()
end

local function OpenNow()
    if not Win.frame then Build() end
    Win.Clamp()
    B.Data.InvalidateMemos()
    State.inCombat = InCombatLockdown()
    Render(false)
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
    if d.quality then
        local color = C_ColorOverrides.GetColorForQuality(d.quality)
        r, g, b = color.r, color.g, color.b
    end
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
