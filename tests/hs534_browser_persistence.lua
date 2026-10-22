-- luacheck: globals assert loadfile print io UIParent CreateFrame InCombatLockdown C_Timer wipe
-- Run from the repo root:  lua tests/hs534_browser_persistence.lua [root]

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Decor Browser settings: the saved defaults, writes only on player actions and
-- only into profile.browser, the window's fixed size, the clamp on open, and
-- no Options rows.
-------------------------------------------------------------------------------

local function readFile(path)
    local f = assert(io.open(root .. "/" .. path, "rb"), "cannot open " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

-- Defaults: two keys, and nothing the player has not set yet.
do
    local HA = {}
    assert(loadfile(root .. "/Core/constants.lua"))("Homestead", HA)
    local d = HA.Constants.Defaults.profile.browser
    assert(d, "profile.browser has no defaults")
    local keys = 0
    for _ in pairs(d) do keys = keys + 1 end
    assert(keys == 2 and d.hideNA == false and d.tipSeen == false and d.position == nil,
        "profile.browser defaults must be exactly hideNA = false and tipSeen = false")
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

local saved = { hideNA = true, tipSeen = false, position = { "TOPLEFT", 140, -48 } }
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

local HA = {
    Constants = { TEXTURE_ROOT = "Textures/" },
    Addon = { _enabled = true, db = { profile = profile, global = global } },
    Events = { RegisterCallback = noop },
    PerformanceTrace = { Measure = function(_, _, _, fn, ...) return fn(...) end },
}
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)
for line in readFile("Homestead.toc"):gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI\\Browser\\[%w_]+%.lua)%s*$")
    if entry then assert(loadfile(root .. "/" .. entry:gsub("\\", "/")))("Homestead", HA) end
end
local B = HA.DecorBrowser
local Win = B.Window
created = 0

-- The window is a fixed 860 x 580.
assert(B.Style.window.width == 860 and B.Style.window.height == 580, "the window size is not 860 x 580")

-- The window and the data are stubs; the open, restore and save paths are the real ones.
B.Data = {
    MemoVersion = function() return 1 end,
    InvalidateMemos = noop,
    IsReady = function() return true end,
}

local frame = { shown = false, w = 860, h = 580, left = 200, top = 700 }
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

Win.Build = function(show)
    onShow = show
    Win.frame = frame
    return frame
end
for _, fn in ipairs({ "ResetSearch", "AssertPropagation", "CancelSearch" }) do
    Win[fn] = noop
end

-- Opening writes nothing.
B:Open()
assert(frame.shown, "the browser did not open")
assert(TakeWrites() == "", "opening wrote saved settings")

-- Refreshes, a re-clamp, close and reopen write nothing.
B.RequestRefresh(false, true)
for _, fn in ipairs(timers) do fn() end
Win.Clamp()
B:Close()
B:Open()
assert(TakeWrites() == "", "a refresh, the clamp or a reopen wrote saved settings")

-- Player actions: a drag writes the position alone, as the top-left corner's offset.
frame.left, frame.top = 120, 650
Win.SavePosition()
assert(TakeWrites() == "browser.position", "a drag must write position only")
local p = saved.position
assert(p[1] == "TOPLEFT" and p[2] == 120 and p[3] == 650 - screenH, "the position is not the top-left offset")
for key in pairs(saved) do
    assert(key == "hideNA" or key == "tipSeen" or key == "position", "the browser saved an unexpected key: " .. key)
end

B.Save("hideNA", false)
assert(TakeWrites() == "browser.hideNA" and saved.hideNA == false, "Save did not write its one key")

-- The save paths are the ones the window uses.
local window = readFile("UI/Browser/Window.lua")
assert(window:find("self:StopMovingOrSizing%(%)%s+Win%.SavePosition%(%)"), "drag stop does not save the position")
assert(window:find("Win.Restore(f, B.Saved())", 1, true), "the window does not restore the saved position")
assert(not window:find("SetResiz", 1, true), "the window must not be resizable")

-- Clamp maths: the size is fixed, so only the corner moves.
local C = Win.ClampPosition
local l, t = C(860, 580, 50, 700, 1365, 768)
assert(l == 50 and t == 700, "a window that fits must not move")
l, t = C(860, 580, -400, 2000, 1365, 768)
assert(l == 0 and t == 768, "a window off the top-left must come back on screen")
l, t = C(860, 580, 1300, 100, 1365, 768)
assert(l == 1365 - 860 and t == 580, "a window off the bottom-right must come back on screen")
l, t = C(860, 580, nil, nil, 1365, 768)
assert(l == nil and t == nil, "an unplaced window keeps its anchor")

-- A small screen: the corner pins to the top-left.
screenW, screenH = 800, 560
frame.left, frame.top = 600, 900
Win.Clamp()
assert(frame.w == 860 and frame.h == 580 and frame.left == 0 and frame.top == 560,
    "the window does not pin to the corner of a small screen")

-- Restore: a well-formed position comes back unchanged; a malformed one, or a saved size, leaves the window alone.
screenW, screenH = 1365, 768
frame.left, frame.top = 140, 720
Win.SavePosition()
frame.left, frame.top = 0, 0
Win.Restore(frame, saved)
Win.Clamp()
assert(frame.left == 140 and frame.top == 720, "a saved position did not come back unchanged")
Win.Restore(frame, { position = { "CENTER", 1, 2 } })
Win.Restore(frame, { position = { "TOPLEFT", nil, 3 } })
Win.Restore(frame, { position = 7 })
Win.Restore(frame, nil)
Win.Restore(frame, { size = { 1000, 700 } })
assert(frame.w == 860 and frame.h == 580 and frame.left == 140 and frame.top == 720,
    "a malformed save or a stale size moved or resized the window")

-- Before its first layout the window has no edges: the clamp reads the restored anchor instead.
frame.unplaced = true
Win.Restore(frame, { position = { "TOPLEFT", -300, 500 } })
Win.Clamp()
frame.unplaced = nil
assert(frame.left == 0 and frame.top == 768, "a saved place the screen no longer holds was not clamped on the first open")
TakeWrites()

-- A profile.browser that is not a table is never trusted: writes are skipped.
do
    local real = HA.Addon.db
    for _, bad in ipairs({ "corrupt", 5, true }) do
        HA.Addon.db = { profile = { browser = bad } }
        assert(B.Saved() == nil, "a non-table profile.browser was trusted")
        B.Save("hideNA", true)
        assert(HA.Addon.db.profile.browser == bad, "a non-table profile.browser was replaced")
    end
    HA.Addon.db = real
end

-- Only profile.browser is ever written.
assert(#allWrites >= 3, "the write log missed the player actions")
for _, entry in ipairs(allWrites) do
    assert(entry:find("^browser%."), "wrote outside profile.browser: " .. entry)
end

-- Options carry no Decor Browser rows.
do
    local OHA = { L = HA.L, Addon = { db = { profile = { browser = {} } } } }
    assert(loadfile(root .. "/UI/OptionsModel.lua"))("Homestead", OHA)
    for _, section in ipairs(OHA.OptionsModel.sections) do
        for _, row in ipairs(section.rows) do
            assert(not tostring(row.key):find("^browser"), "an Options row belongs to the Decor Browser: " .. row.key)
        end
    end
end

print("hs534_browser_persistence: ok")
