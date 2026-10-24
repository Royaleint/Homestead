-- luacheck: globals assert loadfile print io wipe C_Timer InCombatLockdown CreateFrame EventRegistry pcall
-- Run from the repo root:  lua tests/hs538_router.lua [root]

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The page router: Go and Back, the history cap, equal routes, seeds, what a page
-- saves and gets back, the hide-then-refresh contract, a vanished target, combat
-- on Back. Pages here are test pages registered through RegisterPage.
-------------------------------------------------------------------------------

local function readFile(path)
    local f = assert(io.open(root .. "/" .. path, "rb"), "cannot open " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

local function noop() end
local function blank() return setmetatable({}, { __index = function() return noop end }) end

function wipe(t)
    for k in pairs(t) do t[k] = nil end
    return t
end
local timers = {}
C_Timer = {
    After = function(_, fn) fn() end,
    NewTimer = function(_, fn)
        local t = { fn = fn, Cancel = function(self) self.cancelled = true end }
        timers[#timers + 1] = t
        return t
    end,
}
local function flush()
    local due = timers
    timers = {}
    for _, t in ipairs(due) do if not t.cancelled then t.fn() end end
end
local inCombat = false
InCombatLockdown = function() return inCombat end
EventRegistry = { RegisterCallback = noop, UnregisterCallback = noop }

local host = blank()
local made = {}
CreateFrame = function(_, _, parent)
    local f = blank()
    f.parent, f.shown = parent, true
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    made[#made + 1] = f
    return f
end

local HA = {
    Constants = { TEXTURE_ROOT = "Textures/" },
    Addon = { _enabled = true },
    Events = { RegisterCallback = noop, UnregisterCallback = noop },
    VendorData = { GetVendor = noop },
}
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)
for line in readFile("Homestead.toc"):gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI\\Browser\\[%w_]+%.lua)%s*$")
    if entry then assert(loadfile(root .. "/" .. entry:gsub("\\", "/")))("Homestead", HA) end
end

local B = HA.DecorBrowser
HA.PerformanceTrace = { Measure = function(_, _, _, fn, ...) return fn(...) end }
B.Data.IsReady = function() return true end
B.Data.CollectionState = function() return "ready" end
B.Facts.Here = noop
B.CanGet.RefreshNames = noop

local Win = B.Window
local shown, hooks = false, nil
local frame = { IsVisible = function() return shown end, IsShown = function() return shown end }
Win.Build = function(h)
    hooks = h
    Win.frame, Win.host, Win.hideNA = frame, host, blank()
    return frame
end
Win.PlayOpen = function()
    shown = true
    hooks.OnShow()
end
Win.PlayClose = function()
    shown = false
    hooks.OnHide()
end
for _, name in ipairs({ "CheckTextScale", "Fit", "AssertPropagation", "StopGlow",
    "UpdateCount", "SetPlaceholder" }) do
    Win[name] = noop
end
local crumbs, navs, backs = {}, {}, {}
Win.SetCrumb = function(segments) crumbs[#crumbs + 1] = segments end
Win.SelectNav = function(route) navs[#navs + 1] = route end
Win.SetBack = function(on) backs[#backs + 1] = on end
local searchSets, order = {}, {}
Win.SetSearch = function(text)
    searchSets[#searchSets + 1] = text == nil and "none" or text
    order[#order + 1] = "search"
end

local function fail(msg) error(msg, 2) end
local function eq(a, b, msg)
    if a ~= b then fail((msg or "mismatch") .. ": got " .. tostring(a) .. ", wanted " .. tostring(b)) end
end

-- A page that keeps a search text and a scroll offset the way a list does. Typing counts as a change; Show
-- with saved state sets both without one.
local function NewPage()
    local p = { builds = 0, shows = 0, hides = 0, saves = 0, changes = 0, search = "", scroll = 0, up = false,
        refreshes = {}, known = {}, combats = 0 }
    function p:Build(parent) self.builds, self.frame = self.builds + 1, parent end
    function p:Show(route, saved)
        self.shows, self.route, self.saved, self.up = self.shows + 1, route, saved, true
        if route.id and not self.known[route.id] then
            self.home, self.search, self.scroll = true, "", 0
        elseif saved then
            self.home, self.search, self.scroll = false, saved.search, saved.scroll
        else
            self.home, self.search, self.scroll = false, route.seed and route.seed.search or "", 0
        end
    end
    function p:Hide() self.hides, self.up = self.hides + 1, false end
    function p:Refresh(reason)
        self.refreshes[#self.refreshes + 1] = reason
        self.up = true
    end
    function p:SetCombat(on) self.combat, self.combats = on, self.combats + 1 end
    function p:Save()
        self.saves = self.saves + 1
        return { search = self.search, scroll = self.scroll }
    end
    function p:Type(text) self.search, self.changes = text, self.changes + 1 end
    return p
end

local overview, catalog, vendor, source = NewPage(), NewPage(), NewPage(), NewPage()
local multi, deck = NewPage(), NewPage()
for i = 1, 9 do deck.known[i] = true end
function deck:Has(route) return route.kind ~= "pcard" or self.known[route.id] == true end
function deck:CloseCard() return B.CloseOver() end
for i = 1, 60 do vendor.known[i] = true end
function vendor:Has(route) return self.known[route.id] == true end
B.RegisterPage("overview", overview)
B.RegisterPage("catalog", multi)
B.RegisterPage("item", multi)
B.RegisterPage("vendor", vendor)
B.RegisterPage("source", source)
B.RegisterPage("sources", catalog)
B.RegisterPage("vendors", catalog)
B.RegisterPage("allVendors", catalog)
B.RegisterPage("plist", deck)
B.RegisterPage("pcard", deck)

B:Open()
eq(shown, true, "the browser did not open")
eq(overview.builds, 1, "overview was not built once")
eq(multi.builds, 1, "a page under two kinds must be built once")
eq(vendor.builds + catalog.builds + source.builds + deck.builds, 4, "the other pages were not built once each")
local children = 0
for _, f in ipairs(made) do if f.parent == host then children = children + 1 end end
eq(children, 6, "one frame per page object under the host")
eq(overview.route.kind, "overview", "an open must land on overview")
eq(backs[#backs], false, "an open has no history")
eq(navs[#navs].kind, "overview", "the nav was not told the route")
eq(crumbs[#crumbs][1].kind, "overview", "the crumb was not set from the route")

-- Go pushes the page it leaves and shows the new one.
B.Go({ kind = "vendor", id = 1 })
eq(vendor.shows, 1, "vendor was not shown")
eq(overview.hides, 1, "the old page was not hidden")
eq(overview.saves, 1, "the old page was not saved")
eq(backs[#backs], true, "Back must show once there is history")
eq(frame.IsVisible(), true)

-- An equal route does not push and refreshes in place; with a seed it shows again with that seed.
B.Go({ kind = "vendor", id = 1 })
eq(overview.saves + vendor.saves, 1, "an equal route pushed history")
eq(vendor.refreshes[#vendor.refreshes], "route", "an equal route did not refresh in place")
eq(vendor.shows, 1, "an equal route without a seed showed the page again")
local seed = { search = "lamp" }
B.Go({ kind = "vendor", id = 1, seed = seed })
eq(vendor.shows, 2, "an equal route with a seed did not show again")
eq(vendor.route.seed, seed, "the seed was not passed as is")
eq(vendor.search, "lamp", "a seed with search must show it")
eq(vendor.saves, 0, "an equal route with a seed pushed history")

-- Back restores search and scroll silently, and ignores the seed.
vendor:Type("bench")
vendor.scroll = 120
B.Go({ kind = "sources", key = "drops", seed = { search = "zzz" } })
eq(catalog.search, "zzz", "a forward Go with a seed did not apply it")
catalog:Type("typed")
B.Go({ kind = "vendor", id = 2 })
eq(vendor.search, "", "a forward Go must clear the search")
B.Back()
eq(catalog.shows, 2, "Back did not show the page it returns to")
eq(catalog.search, "typed", "Back applied the seed it was given before")
eq(catalog.route.seed, nil, "Back kept the old seed on the route")
B.Back()
eq(vendor.route.id, 1, "Back returned to the wrong route")
eq(vendor.search, "bench", "Back did not restore the search")
eq(vendor.scroll, 120, "Back did not restore the scroll")
eq(vendor.changes, 1, "Back restored the search as a change")

-- The header box: a forward Go sets it to the seed's search or clears it, before the page shows; an equal
-- route sets it only with a seed; Back clears it (the page restores its own).
local showOverview = overview.Show
overview.Show = function(self, ...)
    order[#order + 1] = "show"
    return showOverview(self, ...)
end
local function lastSearch() return searchSets[#searchSets] end
B.Go({ kind = "overview", seed = { search = "oak" } })
eq(lastSearch(), "oak", "a seed with search must reach the header box")
eq(order[#order - 1] .. order[#order], "searchshow", "the box is set before the page shows")
B.Go({ kind = "sources", key = "drops" })
eq(lastSearch(), "none", "a forward Go without a search must clear the header box")
local sets = #searchSets
B.Go({ kind = "sources", key = "drops" })
eq(#searchSets, sets, "an equal route without a seed must leave the header box alone")
B.Go({ kind = "sources", key = "drops", seed = { search = "pot" } })
eq(lastSearch(), "pot", "an equal route with a seed must set the header box")
B.Go({ kind = "vendor", id = 7 })
B.Back()
eq(lastSearch(), "none", "Back must clear the header box and leave the page to restore its own")
overview.Show = showOverview

-- Home is the tree home, never the path walked.
local function Home(route) return B.Home(route) end
eq(#Home({ kind = "overview" }), 1)
eq(Home({ kind = "item", id = 5 })[1].kind, "catalog")
eq(Home({ kind = "catalog", key = 2 })[1].key, "all")
eq(#Home({ kind = "catalog", key = "all" }), 1)
eq(Home({ kind = "vendor", id = 5 })[1].kind, "allVendors")
eq(Home({ kind = "source", key = "quests", id = 9 })[1].key, "quests")

-- History holds 40 entries; the 41st oldest is gone.
B.Go({ kind = "overview" })
for i = 1, 50 do B.Go({ kind = "vendor", id = i }) end
local steps = 0
repeat
    local before = vendor.shows + overview.shows
    B.Back()
    local moved = vendor.shows + overview.shows > before
    if moved then steps = steps + 1 end
until not moved
eq(steps, 40, "the history is capped at 40 entries")

-- Go, Hide, Refresh: a hidden page is refreshed without a Show and comes back.
B.Go({ kind = "vendor", id = 3 })
local showsBefore = vendor.shows
hooks.OnHide()
shown = false
eq(vendor.up, false, "Hide did not tear down")
shown = true
hooks.OnShow()
flush()
eq(vendor.up, true, "Refresh did not restore what Hide tore down")
eq(vendor.shows, showsBefore, "the refresh showed the page again")

-- A vanished target falls back to its list home (All vendors): on a forward Go, on Back, which drops the dead
-- entry, and on Refresh, which replaces the route with no history step.
local function onList()
    local r = catalog.route
    return r ~= nil and r.kind == "allVendors" and r.key == nil
end
local before = vendor.shows
B.Go({ kind = "vendor", id = 99 })
eq(vendor.shows, before, "a vanished target was shown")
eq(onList(), true, "a Go to a vanished target did not fall back to the list")
eq(navs[#navs].kind, "allVendors", "the tree was not told the fallback")
eq(crumbs[#crumbs][#crumbs[#crumbs]].kind, "allVendors", "the crumb was not set from the fallback")

B.Go({ kind = "vendor", id = 4 })
B.Go({ kind = "overview" })
vendor.known[4] = nil
catalog.route = nil
local overviewShows = overview.shows
B.Back()
eq(overview.shows, overviewShows, "Back showed the page it left")
eq(onList(), true, "Back did not drop the dead entry and return to the one before it")
vendor.known[4] = true

B.Go({ kind = "overview" })
B.Go({ kind = "vendor", id = 5 })
vendor.known[5] = nil
catalog.route = nil
B.RequestRefresh(false, true)
flush()
eq(onList(), true, "a refresh of a vanished target did not fall back")
vendor.known[5] = true
overviewShows = overview.shows
B.Back()
eq(overview.shows, overviewShows + 1, "the refresh pushed a history step: Back did not return to the page before")

-- A fallback must itself be live: a home that is gone too lands on Overview, not on a dead page.
multi.Has = function(self, route) return not self.dead end
B.Go({ kind = "vendor", id = 1 })
multi.dead = true
local multiShows, overviewShows2 = multi.shows, overview.shows
B.Go({ kind = "item", id = 3 })
eq(multi.shows, multiShows, "a page that is gone was shown")
eq(overview.route.kind, "overview", "a dead home did not fall back to Overview")
eq(overview.shows, overviewShows2 + 1, "Overview was not shown for a dead home")
eq(navs[#navs].kind, "overview", "the tree was not told the last resort")
multi.dead = false

-- Back with nothing alive left: every entry is dead, so Back shows nothing, empties the history, hides itself
-- and leaves the page where it was.
B:Close()
B:Open()
B.Go({ kind = "vendor", id = 1 })
B.Go({ kind = "vendor", id = 2 })
B.Go({ kind = "vendor", id = 3 })
overview.Has = function() return false end
vendor.known[1], vendor.known[2] = nil, nil
local shownBefore = overview.shows + vendor.shows + catalog.shows
local atRoute = vendor.route
B.Back()
eq(overview.shows + vendor.shows + catalog.shows, shownBefore, "Back showed a page when every entry was dead")
eq(vendor.route, atRoute, "Back moved off the current page")
eq(backs[#backs], false, "Back is still offered with an empty history")
B.Back()
eq(backs[#backs], false, "a second Back with an empty history")
overview.Has = nil
vendor.known[1], vendor.known[2] = true, true

-- A page serving several kinds hears combat once.
inCombat = true
B:Close()
catalog.combats = 0
B:Open()
eq(catalog.combats, 1, "a page registered under three kinds heard combat " .. catalog.combats .. " times")
inCombat = false

-- Same page, two routes: one Hide between them.
B.Go({ kind = "catalog", key = "all" })
local hidesBefore = multi.hides
B.Go({ kind = "item", id = 1 })
eq(multi.hides, hidesBefore + 1, "a route change on the same page must hide the page once")

-- A reopen during the close fade still hides the page it leaves, and clears the history.
B.Go({ kind = "vendor", id = 5 })
hidesBefore = vendor.hides
Win.closing = true
B:Open()
Win.closing = false
eq(vendor.hides, hidesBefore + 1, "a reopen during the close fade did not hide the old page")
eq(backs[#backs], false, "a reopen must clear the history")

-- Combat is applied on Back.
inCombat = true
B:Close()
B:Open()
B.Go({ kind = "vendor", id = 6 })
B.Go({ kind = "overview" })
vendor.combat = nil
B.Back()
eq(vendor.combat, true, "combat was not applied to the page Back returned to")
inCombat = false

-- The header box: typing reaches the current page's Filter; a page with no Filter is never asked. Enter on
-- a page that filters goes nowhere (it filters as you type); Enter on any other page searches the Catalog.
-- The box's hint is the page's own, or the default.
local hints, typed = {}, {}
Win.SetPlaceholder = function(text) hints[#hints + 1] = text == nil and "default" or text end
function catalog:Filter(text) typed[#typed + 1] = text end
function catalog:Placeholder(route) return "Find " .. route.kind end
B.Go({ kind = "allVendors" })
eq(hints[#hints], "Find allVendors", "the box did not take the page's hint")
hooks.Filter("oak")
eq(typed[#typed], "oak", "typing did not reach the page")
B.Go({ kind = "overview" })
eq(hints[#hints], "default", "a page with no hint did not restore the default")
hooks.Filter("pine")
eq(typed[#typed], "oak", "typing reached a page with no Filter")
B.Go({ kind = "allVendors" })
local at = catalog.route
hooks.Search("oak")
eq(catalog.route, at, "Enter on a filtering page left it")
B.Go({ kind = "overview" })
hooks.Search("oak")
eq(multi.route.kind .. ":" .. tostring(multi.route.key), "catalog:all", "Enter on the Overview did not search the Catalog")
eq(multi.route.seed.search, "oak")
catalog.Filter, catalog.Placeholder = nil, nil

-- GoTop starts fresh: it leaves no history to return to, even when the target is the page already showing.
B.Go({ kind = "vendor", id = 5 })
eq(backs[#backs], true, "a Go into a page leaves history")
B.GoTop({ kind = "overview" })
eq(backs[#backs], false, "GoTop hid Back")
B.Go({ kind = "vendor", id = 5 })
B.GoTop({ kind = "vendor", id = 5 })
eq(backs[#backs], false, "GoTop to the page already showing cleared history")

-- A card over its list (a route with a list): moving between the list and a card, or between two cards over
-- one list, hides nothing and leaves the header box alone. History keeps the list. A swap takes no step.
-- Closing is Back when the step before is the list and a replacement with no step otherwise.
local function over() return { kind = "plist", key = "a" } end
B.GoTop(over())
local hidesDeck, setsBefore = deck.hides, #searchSets
B.Go({ kind = "pcard", id = 1, list = over() })
eq(deck.route.kind, "pcard", "the card was not shown")
eq(deck.hides, hidesDeck, "opening a card over its list hid the page")
eq(#searchSets, setsBefore, "opening a card over its list touched the header box")
eq(backs[#backs], true, "a card over a list is one history step")
B.Go({ kind = "pcard", id = 2, list = over() })
eq(deck.route.id, 2, "the swap did not show the other card")
eq(deck.hides, hidesDeck, "a swap hid the page")
eq(#searchSets, setsBefore, "a swap touched the header box")
eq(hooks.CloseCard(), true, "the open card did not close")
eq(deck.route.kind, "plist", "closing did not land on the list")
eq(deck.hides, hidesDeck, "closing hid the page")
eq(#searchSets, setsBefore, "closing touched the header box")
eq(backs[#backs], false, "the swap took a history step: Back is still offered after the close")
eq(hooks.CloseCard(), false, "Escape found a card on a list")

-- History keeps the list: Back from a page the card led to returns to the card over its list.
B.Go({ kind = "pcard", id = 4, list = over() })
B.Go({ kind = "item", id = 7 })
B.Back()
eq(deck.route.kind .. deck.route.id, "pcard4", "Back did not return to the card")
eq(deck.route.list.key, "a", "history lost the list the card sits over")
eq(deck.saved.search, "", "the card's saved state did not come back with it")

-- A card opened from another page: the list takes its place with no step, so Back still returns there.
B.GoTop({ kind = "overview" })
B.Go({ kind = "pcard", id = 3, list = over() })
eq(hooks.CloseCard(), true)
eq(deck.route.kind, "plist", "closing a card opened from elsewhere did not land on its list")
eq(backs[#backs], true, "closing in place used up the step that leads back to the page before")
B.Back()
eq(overview.route.kind, "overview", "Back after an in-place close did not return to where the card came from")

-- A seed asks for a fresh list: the page is hidden and the box is set.
B.GoTop(over())
B.Go({ kind = "pcard", id = 5, list = over() })
hidesDeck, setsBefore = deck.hides, #searchSets
B.Go({ kind = "plist", key = "a", seed = { search = "oak" } })
eq(deck.hides, hidesDeck + 1, "a seeded list was not shown fresh")
eq(#searchSets, setsBefore + 1, "a seeded list did not set the box")

-- A route with no page is a programming error, not a silent fallback.
eq((pcall(B.Go, { kind = "nowhere" })), false, "a route with no page was accepted")

print("hs538_router: ok")
