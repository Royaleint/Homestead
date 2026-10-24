-- Browser router: pages and routes, opening and closing, coalesced refresh, events while shown, combat state
-- and the item tooltip. Delayed work checks B.Generation() first: it changes on every open and every close.
-- Page contract: Show(route, saved) gets saved only on Back. Hide tears down transient state, resets render
-- keys and keeps the route. Refresh may follow Hide without Show (UI restore) and must restore whatever Hide
-- tore down. A page may define Has(route); a target it reports gone falls back to its list home on Go, is
-- dropped from Back, and replaces the route (no history step) on Refresh. A list page may define
-- Filter(text), called as the player edits the header box (never for a restore), and Placeholder(route),
-- the box's hint for that route. A route may carry list, the route it sits over (the vendor card over its
-- list): moving between a route and its list, or between two routes over one list, on one page hides nothing
-- and leaves the header box alone. Such a page defines ListOf(route), the list a route sits over (the router
-- stores it on the route before anything reads it), and CloseCard(), true when it closed a card; its
-- Show(route, saved, keep) hears keep when the list is already up and must be left as it is.
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
    "PLAYER_MONEY", "CURRENCY_DISPLAY_UPDATE", "BAG_UPDATE_DELAYED", "ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED",
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

-- page = { Build(parent), Show(route, saved), Hide(), Refresh(reason), SetCombat(on), Save(), Has(route)? };
-- built once however many kinds it serves.
function B.RegisterPage(kind, page)
    if not kindPage[kind] then kinds[#kinds + 1] = kind end
    kindPage[kind] = page
end

-- The crumb: the page's home in the tree (its parent, then itself), never the path walked.
function B.Home(route)
    local kind, key = route.kind, route.key
    if kind == "vendor" then
        local v = B.Data.Vendor(route.id)
        return { { kind = "allVendors" }, { kind = "vendors", key = B.Data.VendorHome(v or {}) }, route }
    end
    local up = (kind == "item" or kind == "catalog" and key and key ~= "all") and { kind = "catalog", key = "all" }
        or kind == "vendors" and { kind = "allVendors" }
        or kind == "source" and { kind = "sources", key = key }
    return up and { up, route } or { route }
end

local function Gone(route)
    local page = kindPage[route.kind]
    return page and page.Has and not page:Has(route)
end

-- A route whose target is gone becomes the list it sits over, else its tree home, or Overview when that is
-- gone too.
local function Resolved(route)
    if not Gone(route) then return route end
    local home = route.list and not Gone(route.list) and route.list or B.Home(route)[1]
    return Gone(home) and { kind = "overview" } or home
end

local function SyncMemo()
    local version = B.Data.MemoVersion()
    if version ~= memoWipedAt then
        wipe(State.catalogMemo)
        memoWipedAt = version
    end
end

-- Other characters' currency amounts are asked for once per show (until the next hide), after a draw finds a
-- short part in a currency they could cover. The opening draw comes before OnShow.
local asked = false
local function AskAccount()
    if not asked and B.CanGet.NeedAccount() then
        asked = true
        C_CurrencyInfo.RequestCurrencyDataForAccountCharacters()
    end
end

local function SameRoute(a, b)
    return a.kind == b.kind and a.key == b.key and a.id == b.id
end

-- The list a route sits over; a list sits over itself.
local function Over(route)
    return route.list or route
end

local function Transition(route, saved)
    local page = kindPage[route.kind]
    if not page then error("no page for the route kind " .. tostring(route.kind), 2) end
    if page.ListOf then route.list = page:ListOf(route) end
    local old = Current()
    -- A card and its list share a page: moving between them leaves the page and the header box as they are.
    local keep = old == page and not route.seed and (curRoute.list or route.list) ~= nil
        and SameRoute(Over(curRoute), Over(route))
    if old and not keep then old:Hide() end
    if old and old ~= page then frames[curRoute.kind]:Hide() end
    curRoute = route
    frames[route.kind]:Show()
    if not keep then Win.SetSearch(route.seed and route.seed.search) end
    -- The crumb bar comes and goes with the route's depth and the history, so both are set before the page
    -- measures its room.
    Win.SetBack(#history > 0)
    Win.SetCrumb(B.Home(route))
    page:Show(route, saved, keep)
    Win.SetPlaceholder(page.Placeholder and page:Placeholder(route))
    Win.SelectNav(route)
    Win.UpdateCount()
    page:SetCombat(State.inCombat)
    AskAccount()
end

-- top: a jump to the top of a hierarchy (tree row, crumb) starts fresh, so Back shows only after going into something.
local function GoNow(route, top)
    route = Resolved(route)
    if top then wipe(history) end
    if curRoute and SameRoute(curRoute, route) then
        local page = Current()
        if route.seed then
            Win.SetSearch(route.seed.search)
            page:Show(route)
        else
            page:Refresh("route")
        end
        Win.SelectNav(route)
        Win.SetBack(#history > 0)
        return
    end
    -- Another card over the same list takes the card's place.
    local swap = curRoute and curRoute.list and route.list and SameRoute(curRoute.list, route.list)
    if curRoute and not top and not swap then
        history[#history + 1] = {
            { kind = curRoute.kind, key = curRoute.key, id = curRoute.id, list = curRoute.list }, Current():Save(),
        }
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

function B.GoTop(route)
    Traced(route, GoNow, true)
end

function B.Back()
    local entry
    repeat entry = table.remove(history) until not entry or not Gone(entry[1])
    if entry then Traced(entry[1], Transition, entry[2]) else Win.SetBack(false) end
end

local function Replace(route)
    Transition(Resolved(route))
end

-- Closes a route that sits over a list. When the step before it is that list this is Back; otherwise the
-- list takes the route's place with no history step. False when the route sits over nothing.
function B.CloseOver()
    local over = curRoute and curRoute.list
    if not over then return false end
    local top = history[#history]
    if top and SameRoute(top[1], over) and not Gone(top[1]) then B.Back() else Traced(over, Replace) end
    return true
end

local function SetCombat(inCombat)
    State.inCombat = inCombat
    local done = {}
    for _, kind in ipairs(kinds) do
        local page = kindPage[kind]
        if not done[page] then
            done[page] = true
            page:SetCombat(inCombat)
        end
    end
end

function B.SetHideNA(on)
    State.hideNA = on
    B.Save("hideNA", on)
    local page = Current()
    if page then page:Refresh("hide") end
end

-- Pending refresh: stale (walk out of date), names (item names arrived), wallet (money, a currency or a bag
-- changed: judge again, no walk), walletPaint (account data arrived: draw again), plain (any other request),
-- prewarm (a data change or a name may ask for the vendor-count fill; a fill-only repaint must not, or fill and
-- repaint loop).
local timer
local stale, names, wallet, walletPaint, plain, prewarm = false, false, false, false, false, false

local function ClearPending()
    if timer then timer:Cancel() end
    timer = nil
    stale, names, wallet, walletPaint, plain, prewarm = false, false, false, false, false, false
end

local function Repaint(reason)
    SyncMemo()
    local at = curRoute
    if Gone(at) then
        Transition(Resolved(at))
        -- A card closed onto its list leaves the list as it was, so the data that removed it redraws it.
        if not at.list then return end
    end
    Current():Refresh(reason)
    Win.UpdateCount()
    AskAccount()
end

-- The item page's 3D preview: on unless the player turned it off.
function B.Model3D()
    local s = B.Saved()
    return not s or s.model3D ~= false
end

-- The Options checkbox. A browser that was never opened builds nothing; a shown one draws its page again.
function B.SetModel3D(on)
    B.Save("model3D", on)
    if Shown() and curRoute then Repaint("paint") end
end

-- The walk runs only here, at most once per coalesced refresh, in combat too. A wallet change judges the
-- offers again and draws only if one changed.
local function RunRefresh()
    local wasStale, hadNames, allowed, moved, account, other = stale, names, prewarm, wallet, walletPaint, plain
    timer = nil
    stale, names, wallet, walletPaint, plain, prewarm = false, false, false, false, false, false
    if not (Shown() and curRoute) then return end
    if wasStale then B.Data.InvalidateMemos() end
    if hadNames then B.CanGet.RefreshNames() end
    local reason = wasStale and "data" or hadNames and "names" or nil
    local changed = moved and not wasStale and Trace("browser_rejudge", nil, B.CanGet.Rejudge)
    reason = reason or (changed or account) and "wallet" or other and "stats"
    if not reason then return end
    State.noPrewarm = not allowed
    Trace("browser_refresh", reason, Repaint, reason)
    State.noPrewarm = false
end

-- Coalesces bursts into one refresh half a second later, if shown. fromStatsFill must not ask for another
-- fill; newData marks the walk stale; fromWallet is a wallet event's request, which draws only for a change.
function B.RequestRefresh(fromStatsFill, newData, fromWallet)
    if not fromStatsFill then prewarm = true end
    if not fromWallet then plain = true end
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
    elseif event == "PLAYER_MONEY" or event == "BAG_UPDATE_DELAYED" then
        wallet = true
        B.RequestRefresh(true, false, true)
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        -- A nil currencyType could be any currency.
        local cur = B.CanGet.wallet.cur
        if arg1 == nil and next(cur) ~= nil or cur[arg1] ~= nil then
            wallet = true
            B.RequestRefresh(true, false, true)
        end
    elseif event == "ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED" then
        walletPaint = true
        B.CanGet.AccountData()
        B.RequestRefresh(true, false, true)
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
    asked = false
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
        CloseCard = function()
            local page = Current()
            return page and page.CloseCard and page:CloseCard()
        end,
        Search = function(text)
            local page = Current()
            if page and page.Filter then return end
            B.Go({ kind = "catalog", key = "all", seed = { search = text } })
        end,
        Filter = function(text)
            local page = Current()
            if page and page.Filter then page:Filter(text) end
        end,
        HideNA = B.SetHideNA,
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

-- The game's own tooltip for a hyperlink (achievement, quest). A nil or empty link leaves no box.
function B.ShowLinkTooltip(owner, link)
    local tip = B.Tooltip()
    tip:SetOwner(owner, "ANCHOR_RIGHT")
    if link then tip:SetHyperlink(link) end
    if tip:NumLines() == 0 then tip:Hide() else tip:Show() end
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
    if d.active then tip:AddLine(L["Active now: %s"]:format(d.active), unpack(B.Style.color.badge)) end
    if d.bonus then
        if GameTooltip_AddNormalLine and HOUSING_DECOR_FIRST_ACQUISITION_FORMAT then
            GameTooltip_AddNormalLine(tip, HOUSING_DECOR_FIRST_ACQUISITION_FORMAT:format(d.bonus))
        else
            tip:AddLine(L["First-Time Collection Bonus Available"], gold.r, gold.g, gold.b)
        end
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
