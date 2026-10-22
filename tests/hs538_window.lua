-- luacheck: globals assert loadfile print io wipe C_Timer C_Texture InCombatLockdown CreateFrame UIParent
-- luacheck: globals EventRegistry FrameUtil TextSizeManager Menu PixelUtil NineSliceUtil CreateColor
-- Run from the repo root:  lua tests/hs538_window.lua [root]

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The browser window, run through the real Window.lua and Browser.lua with
-- recording widget stubs: the frame, the open order, Escape, the close fade,
-- the one-unit-space clamp, the fit order, the text size, and what a hidden
-- window leaves registered.
-------------------------------------------------------------------------------

local function readFile(path)
    local f = assert(io.open(root .. "/" .. path, "rb"), "cannot open " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

local function near(a, b, tol) return math.abs(a - b) <= tol end

local log = {}
local function Log(what) log[#log + 1] = what end
local function Find(what, from)
    for i = from or 1, #log do if log[i] == what then return i end end
end

-- A widget stub: any unknown member is a callable stub of its own, so fields (f.Inset.Bg) and methods
-- (f:SetSize()) both work. Get* calls answer 0, Is*/Has* false, Create* a new widget.
local Widget
local function Member(name)
    local m = {}
    return setmetatable(m, {
        __index = function(t, k)
            local c = Member(k)
            rawset(t, k, c)
            return c
        end,
        __call = function()
            if name:find("^Get") then return 0 end
            if name:find("^Is") or name:find("^Has") then return false end
            if name:find("^Create") then return Widget() end
        end,
    })
end

local wordWidth, wordHeight = 40, 12
local frames = {}
function Widget(kind)
    local w = { kind = kind, scripts = {}, events = {}, shown = true }
    function w:SetScript(name, fn) self.scripts[name] = fn end
    function w:GetScript(name) return self.scripts[name] end
    function w:HookScript(name, fn) self.scripts[name] = fn end
    function w:Show() self.shown = true end
    function w:Hide() self.shown = false end
    function w:IsShown() return self.shown end
    function w:SetChecked(on) self.checked = on end
    function w:SetSize(width, height) self.width, self.height = width, height end
    function w:GetChecked() return self.checked end
    function w:RegisterEvent(name) self.events[name] = true end
    function w:UnregisterAllEvents() wipe(self.events) end
    function w:RegisterForDrag() self.drag = true end
    function w:CreateFontString()
        local fs = Widget("FontString")
        fs.GetUnboundedStringWidth = function() return wordWidth end
        fs.GetStringHeight = function() return wordHeight end
        return fs
    end
    function w:CreateAnimationGroup()
        local g = Widget("AnimationGroup")
        g.anims = {}
        g.CreateAnimation = function(group, type)
            local a = Widget(type)
            a.SetDuration = function(anim, d) anim.duration = d end
            a.SetOffset = function(anim, x, y) anim.x, anim.y = x, y end
            group.anims[#group.anims + 1] = a
            return a
        end
        g.Play = function(group) group.playing = true end
        g.Stop = function(group) group.playing = false end
        self.groups = self.groups or {}
        self.groups[#self.groups + 1] = g
        return g
    end
    return setmetatable(w, { __index = function(t, k)
        local c = Member(k)
        rawset(t, k, c)
        return c
    end })
end

function wipe(t)
    for k in pairs(t) do t[k] = nil end
    return t
end

local pw, ph = 1200, 700
UIParent = { GetWidth = function() return pw end, GetHeight = function() return ph end }

-- The window frame: scale, anchor and edges kept in frame units, as the client does.
local frame
local function NewWindowFrame()
    local f = Widget("ButtonFrameTemplate")
    f.shown, f.scale, f.alpha = false, 1, 1
    function f:GetScale() return self.scale end
    function f:SetScale(s) self.scale = s end
    function f:ClearAllPoints() self.point = nil end
    function f:SetPoint(point, rel, relPoint, x, y)
        self.point, self.rel, self.relPoint, self.x, self.y = point, rel, relPoint, x, y
        Log("anchor")
    end
    function f:GetPoint() return self.point, self.rel, self.relPoint, self.x, self.y end
    function f:GetLeft()
        Log("read")
        if self.point == "TOPLEFT" and self.rel == UIParent then return self.x end
    end
    function f:GetTop()
        if self.point == "TOPLEFT" and self.rel == UIParent then return ph / self.scale + self.y end
    end
    function f:Show()
        if self.shown then return end
        Log("show")
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function f:Hide()
        if not self.shown then return end
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:IsVisible() return self.shown end
    function f:SetAlpha(a) self.alpha = a end
    function f:SetClampRectInsets(...) self.insets = { ... } end
    function f:SetPropagateKeyboardInput(on) self.propagate = on end
    function f:GetPropagateKeyboardInput() return self.propagate end
    function f:SetFrameStrata(s) self.strata = s end
    function f:SetToplevel(on) self.toplevel = on end
    function f:SetClampedToScreen(on) self.clamped = on end
    return f
end

local created = {}
CreateFrame = function(kind, name, parent, template)
    created[#created + 1] = { kind = kind, name = name, parent = parent, template = template }
    if template == "ButtonFrameTemplate" then
        frame = NewWindowFrame()
        return frame
    end
    local w = Widget(kind)
    frames[#frames + 1] = w
    return w
end

local inCombat = false
InCombatLockdown = function() return inCombat end
local after, timers = {}, {}
C_Timer = {
    After = function(_, fn) after[#after + 1] = fn end,
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
C_Texture = { GetAtlasInfo = function() return nil end }
PixelUtil = { SetHeight = function() end, SetWidth = function() end }
NineSliceUtil = { ApplyLayoutByName = function() end }
CreateColor = function() return Widget("Color") end

local fitScale -- forced scale for a fit call; nil fits the way the client does
local fitArgs
FrameUtil = { UpdateScaleForFitSpecific = function(f, w, h)
    Log("fit")
    fitArgs = { w, h }
    f:SetScale(1)
    local s = fitScale or math.min(pw / w, ph / h)
    if s < 1 then f:SetScale(s) end
end }

local textScale = 1
TextSizeManager = { GetScale = function() return textScale end }

local registry = {}
EventRegistry = {
    RegisterCallback = function(_, event, fn, owner) registry[owner] = { event = event, fn = fn } end,
    UnregisterCallback = function(_, _, owner) registry[owner] = nil end,
}

local menuOpen = false
Menu = { GetManager = function()
    return {
        IsAnyMenuOpen = function() return menuOpen end,
        CloseMenus = function() Log("closeMenus") menuOpen = false end,
    }
end }

local callbacks, byName = {}, {}
local saved = { hideNA = false, tipSeen = false }
local saves = 0
local HA = {
    Constants = { TEXTURE_ROOT = "Textures/" },
    Addon = { _enabled = true, db = { profile = { browser = saved } } },
    Events = {
        RegisterCallback = function(_, name, fn)
            callbacks[name .. tostring(fn)] = fn
            byName[name] = fn
        end,
        UnregisterCallback = function(_, name, fn) callbacks[name .. tostring(fn)] = nil end,
    },
    PerformanceTrace = { Measure = function(_, _, _, fn, ...) return fn(...) end },
}
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)
for line in readFile("Homestead.toc"):gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI\\Browser\\[%w_]+%.lua)%s*$")
    if entry then assert(loadfile(root .. "/" .. entry:gsub("\\", "/")))("Homestead", HA) end
end
assert(#created == 0, "loading the browser created a frame")

local B = HA.DecorBrowser
local Win = B.Window
local D = B.Data
local invalidated = 0
D.IsReady = function() return true end
local realInvalidate = D.InvalidateMemos
D.InvalidateMemos = function() invalidated = invalidated + 1 realInvalidate() end
D.CollectionState = function() return "ready" end
B.Facts.Here = function() end
local realSave = B.Save
B.Save = function(...) saves = saves + 1 return realSave(...) end

local combatSeen
local shownWith = {}
for _, key in ipairs({ "summary", "catalog", "sources" }) do
    B.RegisterTab(key, {
        Build = function() end,
        Show = function(opts)
            shownWith[key] = opts == nil and "nil" or opts
            Log("render:" .. key)
        end,
        Hide = function() end,
        Refresh = function(reason) Log("refresh:" .. reason) end,
        SetCombat = function(on) combatSeen = on end,
    })
end

-- Ready() false creates nothing.
D.IsReady = function() return false end
HA.Addon.Print = function() end
B:Open()
assert(#created == 0 and not Win.frame, "opening before Homestead is ready created a frame")
D.IsReady = function() return true end

-- First open (also the first open after a reload): Summary is drawn before the window shows.
B:Open()
local c = created[1]
assert(c.template == "ButtonFrameTemplate" and c.name == nil and c.parent == UIParent,
    "the window must be an unnamed ButtonFrameTemplate on UIParent")
assert(frame.strata == "MEDIUM" and frame.toplevel and frame.clamped, "strata, top-level or clamp is wrong")
local function TabWidth() return Win.TABS[1].frame.width end
local tw = TabWidth()
assert(tw == 64, "a short tab word must keep the 64-px tab")
local ins = frame.insets
assert(ins[1] == -5 and ins[2] == tw and ins[3] == 7 and ins[4] == 0, "the clamp insets are wrong")
assert(Find("render:summary") < Find("show"), "Summary was not drawn before the window showed")
assert(frame.shown and frame.propagate == true, "the window is not shown with keys passing through")

-- Motion: the open fade is 0.15 s with at most 8 px of travel, the close fade 0.1 s.
local openGroup = frame.groups[1]
assert(openGroup.playing, "the open fade did not play")
local travel = 0
for _, a in ipairs(openGroup.anims) do
    assert(rawget(a, "duration") == 0 or rawget(a, "duration") == 0.15, "an open animation is not 0.15 s")
    travel = math.max(travel, math.abs(rawget(a, "y") or 0))
end
assert(travel > 0 and travel <= 8, "the open travel is over 8 px")
for _, a in ipairs(frame.groups[2].anims) do assert(rawget(a, "duration") == 0.1, "the close fade is not 0.1 s") end

-- R6: Escape, with a menu open and the search focused: the menu first, then the search, then the window.
local key = frame.scripts.OnKeyDown
local box = { focus = true, text = "bench" }
function box:HasFocus() return self.focus end
function box:ClearFocus() self.focus = false Log("clearFocus") end
Win.AddSearchBox(box)
menuOpen = true
log = {}
key(frame, "ESCAPE")
assert(Find("closeMenus") and box.focus and frame.shown,
    "Escape with a menu open must close only the menu and keep the window")
assert(frame.propagate == false, "Escape must not reach the game out of combat")
after[1]()
after = {}
assert(frame.propagate == true, "propagation did not come back")

key(frame, "ESCAPE")
assert(Find("clearFocus") and box.text == "bench" and frame.shown and not Win.closing,
    "Escape must let go of the search and keep its text")
key(frame, "ESCAPE")
assert(Win.closing, "Escape with nothing else to close must close the window")
key(frame, "A")
assert(frame.propagate == true, "other keys must pass through")

-- A plain tab switch passes no options, so the tab keeps its state; a table passes through as is.
B.ShowTab("catalog")
assert(shownWith.catalog == "nil", "a plain tab switch must pass nil options")
local filters = { search = "bench" }
B.ShowTab("catalog", filters)
assert(shownWith.catalog == filters, "tab options did not pass through unchanged")

-- Close fade: Open during the fade cancels it and lands on Summary.
log = {}
B:Open()
assert(not Win.closing and frame.shown and Find("render:summary"), "Open during the fade did not reopen on Summary")
B:Close()
local closeGroup = frame.groups[2]
closeGroup.scripts.OnFinished()
assert(not frame.shown and frame.alpha == 1, "the close fade did not hide the window")

-- Hidden: nothing stays registered.
assert(next(callbacks) == nil, "a hidden window still has data callbacks")
assert(next(registry) == nil, "a hidden window still has the text-size callback")
for _, w in ipairs(frames) do assert(next(w.events) == nil, "a hidden window still has game events") end

-- Reopen: the walk (and with it the collection state) is dropped, combat read, Summary drawn before the show.
invalidated, inCombat, log = 0, true, {}
B:Open()
assert(invalidated == 1 and combatSeen == true, "a reopen did not refresh its inputs")
assert(Find("render:summary") < Find("show"), "Summary was not drawn before the reopen showed")
assert(next(callbacks) and next(registry), "a shown window must listen")
inCombat = false

-- Escape in combat leaves propagation alone.
inCombat = true
frame.propagate = true
key(frame, "ESCAPE")
assert(frame.propagate == true, "propagation changed in combat")
inCombat = false
after = {}
closeGroup.scripts.OnFinished()

-- One-space clamp at s = 0.9.
saved.position = { "TOPLEFT", 100, -100 }
pw, ph, fitScale = 900, 700, 0.9
log = {}
Win.Fit(true)
assert(near(frame.x, 76.0, 0.01) and near(frame.y, -111.1, 0.1),
    ("the clamp at 0.9 anchored at %.2f, %.2f"):format(frame.x, frame.y))
assert(near((frame.x - 5) * 0.9, 63.9, 0.01), "the portrait is off screen")

-- A malformed save leaves the window where it is.
for _, bad in ipairs({ { "CENTER", 1, 2 }, { "TOPLEFT", nil, 3 }, 7, false }) do
    saved.position = bad
    local x, y = frame.x, frame.y
    Win.Fit(true)
    assert(frame.x == x and frame.y == y, "a malformed saved position moved the window")
end
saved.position = nil
saved.size = { 1000, 700 }
Win.Fit(true)
saved.size = nil

-- A place the screen no longer holds comes back to the top-left corner, portrait included.
pw, ph, fitScale = 1200, 700, 1
saved.position = { "TOPLEFT", -300, 500 }
Win.Fit(true)
assert(frame.x == 5 and frame.y == -7, "an off-screen saved place was not clamped to the corner")
pw, ph, fitScale = 800, 560, nil
Win.Fit(true)
local small = frame:GetScale()
assert(small < 1 and near(frame.x, 5, 0.001) and near(frame.y, -7, 0.001), "a small screen did not pin the window")

-- Round trip: 1 -> 0.9 -> 1 keeps the UIParent-unit corner; no save.
saves = 0
saved.position = { "TOPLEFT", 200, -100 }
pw, ph, fitScale = 1200, 700, 1
Win.Fit(true)
assert(frame.x == 200 and frame.y == -100, "the corner moved at scale 1")
fitScale = 0.9
log = {}
Win.Fit()
assert(near(frame.x, 222.2, 0.1) and near(frame.y, -111.1, 0.1), "the frame-unit anchor at 0.9 is wrong")
assert(Find("read") < Find("fit") and Find("fit") < Find("anchor"), "the fit did not read, fit, then anchor")
fitScale = 1
Win.Fit()
assert(near(frame.x, 200, 0.01) and near(frame.y, -100, 0.01), "the round trip moved the corner")
assert(saves == 0, "a fit saved the position")

-- Order on OnShow, UI_SCALE_CHANGED, DISPLAY_SIZE_CHANGED and the text-size callback.
fitScale = nil
log = {}
B:Open()
assert(Find("read") and Find("read") < Find("fit") and Find("fit") < Find("anchor", Find("fit")), "OnShow fit order")
local events
for _, w in ipairs(frames) do if w.scripts.OnEvent then events = w end end
for _, ev in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
    log = {}
    events.scripts.OnEvent(events, ev)
    assert(Find("read") < Find("fit") and Find("fit") < Find("anchor", Find("fit")), ev .. " fit order")
end

-- Text size: Gigantic words re-measure the tabs before the fit.
local owner, entry = next(registry)
assert(owner and entry.event == "TextSizeManager.OnTextScaleUpdated", "the text-size callback is not registered")
textScale, wordWidth, wordHeight = 2.0, 103.2, 24
log = {}
entry.fn()
assert(near(TabWidth(), 115.2, 0.001) and near(fitArgs[1], 980.2, 0.001) and fitArgs[2] == 587,
    "the Gigantic tab width or fit width is wrong")
assert(frame.insets[2] == TabWidth(), "the clamp insets did not follow the tab width")
assert(Find("read") < Find("fit") and Find("fit") < Find("anchor", Find("fit")), "text-size fit order")
assert(saves == 0, "a fit saved the position")

-- Text size changed while hidden: the reopen re-measures.
B:Close()
closeGroup.scripts.OnFinished()
assert(next(registry) == nil, "the text-size callback outlived the hide")
textScale, wordWidth, wordHeight = 1, 40, 12
B:Open()
assert(TabWidth() == 64, "a text-size change while hidden was not picked up")

-- Fit scales on 4:3 and 5:4 at UI scale 1.15, at Small and Gigantic text.
local cases = {
    { 890.4, 667.8, 0.8571, 40, 0.96 }, { 890.4, 667.8, 2.0, 103.2, 0.91 },
    { 834.8, 667.8, 0.8571, 40, 0.90 }, { 834.8, 667.8, 2.0, 103.2, 0.85 },
}
for _, case in ipairs(cases) do
    pw, ph, textScale, wordWidth = case[1], case[2], case[3], case[4]
    Win.CheckTextScale()
    Win.Fit()
    local s = frame:GetScale()
    assert(near(s, case[5], 0.005), ("fit scale %.3f, expected %.2f"):format(s, case[5]))
    local L, T = frame.x * s, ph + frame.y * s
    assert(L - 5 * s >= -0.001 and L + (860 + TabWidth()) * s <= pw + 0.001, "the portrait or tabs are off screen")
    assert(T + 7 * s <= ph + 0.001 and T - 580 * s >= -0.001, "the window is off screen vertically")
end

-- Refreshes: bursts coalesce into one, the walk is dropped only inside it, names refresh once, and a
-- refresh for the vendor-count fill does not ask for another fill.
local names, prewarmSeen = 0, {}
B.CanGet.RefreshNames = function() names = names + 1 end
D.NameArrived = function() return true end
B.RegisterTab("summary", {
    Build = function() end, Show = function() end, Hide = function() end, SetCombat = function() end,
    Refresh = function(reason) prewarmSeen[#prewarmSeen + 1] = reason .. ":" .. tostring(B.State.noPrewarm) end,
})
B.ShowTab("summary")
timers = {}
for i = 1, 3 do events.scripts.OnEvent(events, "GET_ITEM_INFO_RECEIVED", i, true) end
assert(#timers == 1 and names == 0, "item names did not coalesce")
flush()
assert(names == 1 and prewarmSeen[1] == "names:false", "item names did not refresh once")

B.RequestRefresh(true)
B.RequestRefresh(true)
flush()
assert(prewarmSeen[2] == "stats:true" and B.State.noPrewarm == false, "a fill refresh may ask for another fill")
local prewarms = 0
HA.BadgeCalculation = {
    PeekVendorStats = function() return nil end,
    RequestPrewarm = function() prewarms = prewarms + 1 end,
}
D.HolidayActive = function() return nil end
B.State.noPrewarm = true
D.VendorCounts({ npcID = 1 })
B.State.noPrewarm = false
D.VendorCounts({ npcID = 1 })
assert(prewarms == 1, "the vendor counts ignored the refresh's no-prewarm flag")

-- In combat: events only schedule; the walk is dropped inside the coalesced refresh, never in a handler.
inCombat = true
invalidated = 0
events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED")
assert(combatSeen == true and #timers == 0 and invalidated == 0, "entering combat refreshed or walked")
byName.OWNERSHIP_UPDATED()
byName.HS_CATALOG_TRUE_WARM()
assert(invalidated == 0 and #timers == 1, "a data event walked outside the coalesced refresh")
flush()
assert(invalidated == 1 and prewarmSeen[3] == "data:false", "the data refresh did not walk once")
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
assert(combatSeen == false and #timers == 0, "leaving combat refreshed")
inCombat = false

-- A burst of data events while shown walks exactly once per coalesced refresh, in combat or not.
local walks, walkedAt = 0, nil
B.CanGet.Walk = function()
    if D.MemoVersion() ~= walkedAt then walks, walkedAt = walks + 1, D.MemoVersion() end
    return {}
end
B.RegisterTab("summary", {
    Build = function() end, Show = function() end, Hide = function() end, SetCombat = function() end,
    Refresh = function() B.Walk() B.Walk() end,
})
HA.VendorData = { GetVendor = function() return nil end }
for _, fighting in ipairs({ false, true }) do
    inCombat = fighting
    events.scripts.OnEvent(events, fighting and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
    walks = 0
    for _ = 1, 3 do byName.OWNERSHIP_UPDATED() end
    byName.HS_CATALOG_READ_STATE()
    byName.SOURCE_CACHES_INVALIDATED()
    byName.VENDOR_SCANNED({ npcID = 9, hasHousing = true })
    B.RequestRefresh(true)
    assert(walks == 0 and #timers == 1, "a data event walked before the coalesced refresh")
    flush()
    assert(walks == 1, ("a burst walked %d times %s combat"):format(walks, fighting and "in" or "out of"))
end
inCombat = false
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")

-- A scan of a merchant the browser does not know, with no housing items, changes nothing.
HA.VendorData = { GetVendor = function(_, npcID) return npcID == 7 and {} or nil end }
local resets, reset = 0, B.CanGet.ResetFactionOnly
B.CanGet.ResetFactionOnly = function() resets = resets + 1 end
byName.VENDOR_SCANNED({ npcID = 5, hasHousing = false })
assert(#timers == 0 and resets == 0, "an unrelated merchant scan refreshed the browser")
byName.VENDOR_SCANNED({ npcID = 7, hasHousing = false })
assert(#timers == 1, "a scan of a known vendor did not refresh")
assert(resets == 1, "a scan that can add a vendor kept the faction-only answers")
B.CanGet.ResetFactionOnly = reset
flush()
byName.VENDOR_SCANNED({ npcID = 5, hasHousing = true })
assert(#timers == 1, "a scan that found housing items did not refresh")

-- A close cancels the pending refresh.
B:Close()
closeGroup.scripts.OnFinished()
assert(timers[1].cancelled, "the pending refresh outlived the close")
timers = {}
B:Open()

-- UI restore (Alt+Z): OnHide then OnShow with no Open. The callbacks come back, combat is read again,
-- one stale refresh follows and reaches the current tab, and nothing is saved.
local restored = {}
B.RegisterTab("summary", {
    Build = function() end, Hide = function() end, SetCombat = function(on) combatSeen = on end,
    Show = function() restored[#restored + 1] = "show" end,
    Refresh = function(reason) restored[#restored + 1] = reason end,
})
B.ShowTab("summary")
restored, saves, timers, invalidated = {}, 0, {}, 0
frame:Hide()
assert(next(callbacks) == nil and next(registry) == nil, "the UI hide left callbacks registered")
inCombat = true
frame:Show()
assert(next(callbacks) and next(registry), "the UI restore did not register the callbacks again")
for _, w in ipairs(frames) do if w == events then assert(next(w.events), "the UI restore did not register game events") end end
assert(combatSeen == true and B.State.inCombat == true, "the UI restore did not read combat again")
assert(#timers == 1 and invalidated == 0, "the UI restore must request exactly one coalesced refresh")
flush()
assert(table.concat(restored, ",") == "data" and invalidated == 1, "the restore refresh did not reach the tab once")
assert(saves == 0, "the UI restore saved")
inCombat = false
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")

-- Only a drop saves.
saves = 0
local grab
for _, w in ipairs(frames) do if w.drag and w.scripts.OnDragStop then grab = w end end
grab.scripts.OnDragStart()
grab.scripts.OnDragStop()
assert(saves == 1 and saved.position[1] == "TOPLEFT", "a drop must save the position once")
local s = frame:GetScale()
assert(near(saved.position[2], frame.x * s, 0.001) and near(saved.position[3], frame.y * s, 0.001),
    "the saved position is not in UIParent units")
flush()
print("hs538_window: ok")
