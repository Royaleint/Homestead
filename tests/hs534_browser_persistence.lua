-- luacheck: globals assert loadfile print io UIParent CreateFrame InCombatLockdown C_Timer wipe
-- Run from the repo root:  lua tests/hs534_browser_persistence.lua [root]

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Decor Browser settings: the saved defaults, writes only on player actions and
-- only into profile.browser, the saved page check, the clamp on open, and the
-- Options checkboxes.
-------------------------------------------------------------------------------

local function readFile(path)
    local f = assert(io.open(root .. "/" .. path, "rb"), "cannot open " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

-- Defaults: three keys, and nothing the player has not set yet.
do
    local HA = {}
    assert(loadfile(root .. "/Core/constants.lua"))("Homestead", HA)
    local d = HA.Constants.Defaults.profile.browser
    assert(d, "profile.browser has no defaults")
    local keys = 0
    for _ in pairs(d) do keys = keys + 1 end
    assert(keys == 3 and d.hideOwned == false and d.animations == true and d.model3D == true,
        "profile.browser defaults must be exactly hideOwned = false, animations = true, model3D = true")
end

-- Every write to the saved tables is recorded as "<table>.<key>".
local writes, allWrites = {}, {}
local function Proxy(name, backing)
    return setmetatable({}, {
        __index = backing,
        __newindex = function(_, k, v)
            writes[#writes + 1] = name .. "." .. tostring(k)
            allWrites[#allWrites + 1] = writes[#writes]
            backing[k] = v
        end,
    })
end
local function TakeWrites()
    local list = table.concat(writes, ",")
    for i = #writes, 1, -1 do writes[i] = nil end
    return list
end

local saved = { hideOwned = true, animations = true, model3D = true,
    lastPage = { page = "shop", npcID = 101, nav = "vendors:Midnight" } }
local profile = Proxy("profile", { browser = Proxy("browser", saved) })
local global = Proxy("global", {})

local screenW, screenH = 1365, 768
UIParent = { GetWidth = function() return screenW end, GetHeight = function() return screenH end }
local created = 0
local function noop() end
local function Stub() return setmetatable({}, { __index = function() return noop end }) end
CreateFrame = function()
    created = created + 1
    return Stub()
end
InCombatLockdown = function() return false end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

local optionsRefreshed = 0
local HA = {
    Constants = { TEXTURE_ROOT = "Textures/" },
    Addon = { _enabled = true, db = { profile = profile, global = global } },
    Events = { RegisterCallback = noop },
    PerformanceTrace = { Measure = function(_, _, _, fn, ...) return fn(...) end },
    OptionsFrame = { IsShown = function() return true end,
        Refresh = function() optionsRefreshed = optionsRefreshed + 1 end },
}
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)
for line in readFile("Homestead.toc"):gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI\\Browser\\[%w_]+%.lua)%s*$")
    if entry then assert(loadfile(root .. "/" .. entry:gsub("\\", "/")))("Homestead", HA) end
end
local B = HA.DecorBrowser
local Win = B.Window
created = 0

-- Options on a browser never opened: nothing is built and the in-page 3D override is cleared.
B.State.model3D = false
B:OnSettingChanged("model3D")
assert(Win.frame == nil and created == 0, "a setting change built the browser before its first open")
assert(B.State.model3D == nil, "a setting change from Options must clear the in-page 3D override")
assert(TakeWrites() == "", "a setting change wrote saved settings itself")

-- The window and the data are stubs; the router, restore and save paths are the real ones.
local vendors = { [101] = { npcID = 101 }, [102] = { npcID = 102, hidden = true } }
local items = { [5001] = true }
B.Data = {
    MemoVersion = function() return 1 end,
    InvalidateMemos = noop,
    IsReady = function() return true end,
    Expansions = function() return { "Midnight", "Events" } end,
    Vendor = function(npcID) return vendors[npcID] end,
    IsListedVendor = function(v) return not v.hidden end,
    ItemKnown = function(itemID) return items[itemID] == true end,
}
B.Widgets.StopAll, B.Widgets.RefreshPulses = noop, noop

local shows = {}
for key in pairs(B.pages) do
    B.pages[key] = { topLevel = key ~= "shop" and key ~= "item", searchable = false,
        Build = function() return Stub() end,
        Show = function(route, isRefresh) shows[#shows + 1] = { page = key, route = route, refresh = isRefresh } end }
end

local hideChecked
local sheenPlays = 0
local frame = { shown = false, w = 930, h = 620, left = 200, top = 700 }
local onShow
function frame:Show() self.shown = true onShow() end
function frame:Hide() self.shown = false end
function frame:IsShown() return self.shown end
function frame:GetWidth() return self.w end
function frame:GetHeight() return self.h end
function frame:GetLeft() return not self.unplaced and self.left or nil end
function frame:GetTop() return not self.unplaced and self.top or nil end
function frame:GetPoint() return self.point, UIParent, self.point, self.px, self.py end
function frame:SetSize(w, h) self.w, self.h = w, h end
function frame:ClearAllPoints() self.point = nil end
function frame:SetPoint(point, rel, relPoint, x, y)
    assert(rel == UIParent and relPoint == point, "positions must be relative to the same point of UIParent")
    self.point, self.px, self.py = point, x, y
    if point == "TOPLEFT" then self.left, self.top = x, screenH + y end
end
function frame:SetResizeBounds(...) self.bounds = { ... } end

Win.Build = function(show)
    onShow = show
    Win.frame = frame
    return frame
end
Win.grip = Stub()
Win.sheen = { Play = function() sheenPlays = sheenPlays + 1 end, Stop = noop }
Win.SetHideOwnedChecked = function(on) hideChecked = on end
for _, fn in ipairs({ "ResetSearch", "SelectNav", "UpdateCrumbs", "UpdateProgress", "AssertPropagation", "CancelSearch" }) do
    Win[fn] = noop
end

-- Opening restores Hide owned and the saved page, and writes nothing.
B:Open()
assert(frame.shown, "the browser did not open")
assert(B.State.hideOwned == true and hideChecked == true, "Hide owned was not restored")
local last = shows[#shows]
assert(last.page == "shop" and last.route.npcID == 101 and last.route.nav == "vendors:Midnight",
    "the saved vendor page was not restored")
assert(last.route ~= saved.lastPage, "the saved route table itself must not become the live route")
assert(TakeWrites() == "", "opening wrote saved settings")

-- Refreshes, a setting change while shown, a re-clamp, close and reopen write nothing.
B.RequestRefresh(false, true)
for _, fn in ipairs(timers) do fn() end
assert(shows[#shows].refresh == true, "the coalesced refresh did not run")
local playsBefore = sheenPlays
B.State.model3D = true
B:OnSettingChanged("model3D")
assert(B.State.model3D == nil, "Options did not clear the in-page 3D override")
assert(shows[#shows].refresh == true and sheenPlays == playsBefore + 1,
    "a setting change did not re-apply to the shown page and the sheen")
Win.Clamp()
B:Close()
B:Open()
assert(TakeWrites() == "", "refresh, a setting change, the clamp or a reopen wrote saved settings")

-- Player actions: each writes its one key under profile.browser.
B.Go({ page = "item", itemID = 5001, npcID = 101, label = "x", extra = {} })
assert(TakeWrites() == "browser.lastPage", "navigation must write lastPage only")
local lp = saved.lastPage
assert(lp.page == "item" and lp.itemID == 5001 and lp.npcID == 101 and lp.nav == "vendors:Midnight",
    "the saved page lost its route")
assert(lp.label == nil and lp.extra == nil, "the saved page kept fields outside the route shape")
B.Back()
assert(TakeWrites() == "browser.lastPage" and saved.lastPage.page == "shop", "Back must save the page it lands on")

B.SetHideOwned(false)
assert(TakeWrites() == "browser.hideOwned" and saved.hideOwned == false, "the Hide owned toggle was not saved")
B.SetHideOwned(true)
B.ClearFilters()
assert(TakeWrites() == "browser.hideOwned,browser.hideOwned" and saved.hideOwned == false,
    "clearing filters must save Hide owned off")

frame.left, frame.top = 120, 650
Win.SavePosition()
assert(TakeWrites() == "browser.position", "a drag must write position only")
local p = saved.position
assert(p[1] == "TOPLEFT" and p[2] == 120 and p[3] == 650 - screenH, "the position is not the top-left offset")
frame.w, frame.h = 1000, 700
Win.SaveSize()
assert(TakeWrites() == "browser.size,browser.position" and saved.size[1] == 1000 and saved.size[2] == 700,
    "a resize must save the size and the place, so a window only ever resized keeps its place")

local refreshedBefore = optionsRefreshed
B.Save("model3D", false)
assert(TakeWrites() == "browser.model3D" and optionsRefreshed == refreshedBefore + 1,
    "the 3D toggle must save and redraw the open Options")
B.Save("hideOwned", false)
assert(optionsRefreshed == refreshedBefore + 1, "Options shows no Hide owned setting and must not redraw for it")
TakeWrites()

-- The save paths are the ones the window and the item page use.
local window, item = readFile("UI/Browser/Window.lua"), readFile("UI/Browser/Item.lua")
assert(window:find("self:StopMovingOrSizing%(%)%s+Win%.SavePosition%(%)"), "drag stop does not save the position")
assert(window:find("grip:SetOnResizeStoppedCallback(Win.SaveSize)", 1, true), "the resize grip does not save the size")
assert(window:find("Win.Restore(f, B.Saved())", 1, true), "the window does not restore the saved size and position")
assert(item:find('B.Save("model3D", B.State.model3D)', 1, true), "the 3D toggle does not save")

-- Saved page check: known shapes whose IDs still resolve; anything else is Overview (nil).
local V = B.ValidateLastPage
local function same(r, want)
    if not r then return false end
    for k, v in pairs(want) do if r[k] ~= v then return false end end
    for k in pairs(r) do if want[k] == nil then return false end end
    return true
end
assert(same(V({ page = "overview" }), { page = "overview", nav = "overview" }))
assert(same(V({ page = "shops", nearYou = true }), { page = "shops", nearYou = true, nav = "nearyou" }))
assert(same(V({ page = "shops", expansion = "Midnight", nav = "junk" }),
    { page = "shops", expansion = "Midnight", nav = "vendors:Midnight" }))
assert(same(V({ page = "sources", source = "quests" }), { page = "sources", source = "quests", nav = "quests" }))
assert(same(V({ page = "shop", npcID = 101, nav = "nearyou" }), { page = "shop", npcID = 101, nav = "nearyou" }))
assert(same(V({ page = "item", itemID = 5001, npcID = 101, nav = "drops" }),
    { page = "item", itemID = 5001, npcID = 101, nav = "drops" }))
assert(same(V({ page = "item", itemID = 5001, npcID = 999 }), { page = "item", itemID = 5001, nav = "overview" }),
    "an item page keeps its item but drops a vendor that no longer lists")
assert(same(V({ page = "shop", npcID = 101, nav = "vendors:Gone" }), { page = "shop", npcID = 101, nav = "overview" }),
    "a nav entry naming a missing expansion must fall back")
for i, bad in ipairs({
    false, "overview", 7, {}, { page = "bogus" }, { page = "shop" }, { page = "shop", npcID = 999 },
    { page = "shop", npcID = 102 }, { page = "shop", npcID = "101" }, { page = "item", itemID = 6000 },
    { page = "item", itemID = "5001" }, { page = "shops", expansion = "Gone" }, { page = "shops" },
    { page = "shops", nearYou = "yes" }, { page = "sources", source = "bogus" }, { page = "sources", source = {} },
}) do
    assert(V(bad) == nil, "a malformed or stale saved page was accepted (case " .. i .. ")")
end
assert(V(nil) == nil)
local input = { page = "overview" }
assert(V(input) ~= input, "the check must return a new table")

-- A bad saved page opens on Overview.
B:Close()
B.State.route = nil
saved.lastPage = { page = "shop", npcID = 102 }
B:Open()
assert(shows[#shows].page == "overview", "a stale saved page did not open on Overview")
assert(TakeWrites() == "", "the fallback to Overview wrote saved settings")

-- Clamp maths.
local C = Win.ClampRect
local w, h, l, t = C(5000, 3000, 10, 700, 1365, 768, 930, 620)
assert(w == 1365 and h == 768 and l == 0 and t == 768, "an oversized window must shrink to the screen")
w, h = C(100, 100, nil, nil, 1365, 768, 930, 620)
assert(w == 930 and h == 620, "a window below the minimum must grow to it")
l, t = select(3, C(930, 620, -400, 2000, 1365, 768, 930, 620))
assert(l == 0 and t == 768, "a window off the top-left must come back on screen")
l, t = select(3, C(930, 620, 1300, 100, 1365, 768, 930, 620))
assert(l == 1365 - 930 and t == 620, "a window off the bottom-right must come back on screen")
w, h, l, t = C(1000, 650, 50, 700, 1365, 768, 930, 620)
assert(w == 1000 and h == 650 and l == 50 and t == 700, "a window that fits must not move")
assert(select(3, C(930, 620, nil, nil, 1365, 768, 930, 620)) == nil, "an unplaced window keeps its anchor")

-- A small screen (4:3 at UI scale 1.15): the screen wins over the 930 x 620 minimum.
screenW, screenH = 890, 668
frame.w, frame.h, frame.left, frame.top = 1000, 700, 600, 900
Win.Clamp()
local b = frame.bounds
assert(b[1] == 890 and b[2] == 620 and b[3] == 890 and b[4] == 668, "resize bounds do not fit the small screen")
assert(frame.w == 890 and frame.h == 668 and frame.left == 0 and frame.top == 668,
    "the window does not fit the small screen")

-- Restore: a well-formed save comes back unchanged; a malformed one leaves the window alone.
screenW, screenH = 1365, 768
frame.w, frame.h, frame.left, frame.top = 1000, 700, 140, 720
Win.SavePosition()
Win.SaveSize()
frame.w, frame.h, frame.left, frame.top = 930, 620, 0, 0
Win.Restore(frame, saved)
Win.Clamp()
assert(frame.w == 1000 and frame.h == 700 and frame.left == 140 and frame.top == 720, "a saved size and position did not come back unchanged")
Win.Restore(frame, { size = { "wide", 5 }, position = { "CENTER", 1, 2 } })
Win.Restore(frame, { size = 7, position = { "TOPLEFT", nil, 3 } })
Win.Restore(frame, nil)
assert(frame.w == 1000 and frame.left == 140 and frame.top == 720, "a malformed save moved or resized the window")

-- Before its first layout the window has no edges: the clamp reads the restored anchor instead.
frame.unplaced = true
Win.Restore(frame, { size = { 4000, 4000 }, position = { "TOPLEFT", -300, 500 } })
Win.Clamp()
frame.unplaced = nil
assert(frame.w == 1365 and frame.h == 768 and frame.left == 0 and frame.top == 768,
    "a saved place the screen no longer holds was not clamped on the first open")
TakeWrites()

-- A profile.browser that is not a table is never trusted: reads use the defaults, writes are skipped.
do
    local real = HA.Addon.db
    for _, bad in ipairs({ "corrupt", 5, true }) do
        HA.Addon.db = { profile = { browser = bad } }
        assert(B.Saved() == nil, "a non-table profile.browser was trusted")
        B.Save("hideOwned", true)
        assert(B.Vis.AnimationsOn() == true, "a non-table profile.browser must read as the defaults")
        assert(HA.Addon.db.profile.browser == bad, "a non-table profile.browser was replaced")
    end
    HA.Addon.db = real
end

-- Only profile.browser is ever written.
assert(#allWrites >= 10, "the write log missed the player actions")
for _, entry in ipairs(allWrites) do
    assert(entry:find("^browser%."), "wrote outside profile.browser: " .. entry)
end

-- Options: the checkboxes read and write profile.browser and tell the browser.
do
    local data = { browser = { animations = true, model3D = true } }
    local told
    local OHA = { L = HA.L, Addon = { db = { profile = data } },
        DecorBrowser = { OnSettingChanged = function(_, key) told = key end } }
    assert(loadfile(root .. "/UI/OptionsModel.lua"))("Homestead", OHA)
    local rows = {}
    for _, row in ipairs(OHA.OptionsModel.sections[1].rows) do rows[row.key] = row end
    local anim, model = rows.browserAnimations, rows.browserModel3D
    assert(rows.browserHeader and anim and model, "the Decor Browser rows are missing from Options")
    assert(anim.get() == true and model.get() == true)
    model.set(false)
    assert(data.browser.model3D == false and model.get() == false and told == "model3D",
        "the 3D checkbox did not save or tell the browser")
    anim.set(false)
    assert(data.browser.animations == false and told == "animations", "the Animations checkbox did not save")
    data.browser = nil
    told = nil
    model.set(false)
    assert(told == nil and data.browser == nil, "with no saved table a checkbox must neither save nor notify")
    assert(model.get() == true, "a missing table must read as on")
end

print("hs534_browser_persistence: ok")
