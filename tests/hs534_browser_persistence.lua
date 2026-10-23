-- luacheck: globals assert loadfile print io UIParent CreateFrame InCombatLockdown C_Timer wipe EventRegistry
-- Run from the repo root:  lua tests/hs534_browser_persistence.lua [root]

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Decor Browser settings: the saved defaults, writes only on player actions and
-- only into profile.browser, the window's fixed size, the save on a drop only,
-- and one Options row, the 3D preview. The clamp and the drop itself run in hs538_window.
-------------------------------------------------------------------------------

local function readFile(path)
    local f = assert(io.open(root .. "/" .. path, "rb"), "cannot open " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

-- Defaults: three keys, and nothing the player has not set yet. The 3D preview is on by default; a profile
-- saved before it existed has no model3D and reads the default.
do
    local HA = {}
    assert(loadfile(root .. "/Core/constants.lua"))("Homestead", HA)
    local d = HA.Constants.Defaults.profile.browser
    assert(d, "profile.browser has no defaults")
    local keys = 0
    for _ in pairs(d) do keys = keys + 1 end
    assert(keys == 3 and d.hideNA == false and d.tipSeen == false and d.model3D == true and d.position == nil,
        "profile.browser defaults must be exactly hideNA = false, tipSeen = false and model3D = true")
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
local function noop() end
local function Stub() return setmetatable({}, { __index = function() return noop end }) end
CreateFrame = Stub
InCombatLockdown = function() return false end
local timers = {}
C_Timer = {
    After = function(_, fn) fn() end,
    NewTimer = function(_, fn)
        timers[#timers + 1] = fn
        return { Cancel = noop }
    end,
}
EventRegistry = { RegisterCallback = noop, UnregisterCallback = noop }
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

local HA = {
    Constants = { TEXTURE_ROOT = "Textures/" },
    Addon = { _enabled = true, db = { profile = profile, global = global } },
    Events = { RegisterCallback = noop, UnregisterCallback = noop },
    PerformanceTrace = { Measure = function(_, _, _, fn, ...) return fn(...) end },
}
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)
for line in readFile("Homestead.toc"):gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI\\Browser\\[%w_]+%.lua)%s*$")
    if entry then assert(loadfile(root .. "/" .. entry:gsub("\\", "/")))("Homestead", HA) end
end
local B = HA.DecorBrowser
local Win = B.Window

-- The window is a fixed 860 x 580.
assert(B.Style.window.width == 860 and B.Style.window.height == 580, "the window size is not 860 x 580")

-- The window and the data are stubs; the open, refresh and save paths are the real ones.
B.Data.IsReady = function() return true end
B.Data.CollectionState = function() return "ready" end
B.Facts.Here = noop
local shown, hooks = false, nil
local frame = { IsVisible = function() return shown end, IsShown = function() return shown end }
Win.Build = function(h)
    hooks = h
    Win.frame, Win.host, Win.hideNA = frame, Stub(), Stub()
    return frame
end
Win.PlayOpen = function()
    if shown then return end
    shown = true
    hooks.OnShow()
end
Win.PlayClose = function()
    shown = false
    hooks.OnHide()
end
for _, name in ipairs({ "CheckTextScale", "Fit", "SetSelectedTab", "SetLocation", "AssertPropagation", "StopGlow",
    "SetCrumb", "SelectNav", "SetBack", "SetSearch", "SetPlaceholder", "UpdateCount" }) do
    Win[name] = noop
end
for _, key in ipairs({ "summary", "catalog", "sources" }) do
    B.RegisterTab(key, { Build = noop, Show = noop, Hide = noop, Refresh = noop, SetCombat = noop })
end
for _, kind in ipairs({ "vendor", "vendors", "allVendors", "source", "item" }) do
    B.RegisterPage(kind, { Build = noop, Show = noop, Hide = noop, Refresh = noop, SetCombat = noop })
end

-- Opening writes nothing.
B:Open()
assert(shown, "the browser did not open")
assert(TakeWrites() == "", "opening wrote saved settings")

-- Refreshes, a tab change, close and reopen write nothing.
B.RequestRefresh(false, true)
for _, fn in ipairs(timers) do fn() end
B.ShowTab("sources")
B:Close()
B:Open()
assert(TakeWrites() == "", "a refresh, a tab change or a reopen wrote saved settings")

-- Player actions: the Hide toggle writes hideNA alone; a drop writes the position alone.
B.SetHideNA(false)
assert(TakeWrites() == "browser.hideNA" and saved.hideNA == false, "the Hide toggle did not write its one key")
B.Save("position", { "TOPLEFT", 120, -118 })
assert(TakeWrites() == "browser.position", "a drop must write position only")
for key in pairs(saved) do
    assert(key == "hideNA" or key == "tipSeen" or key == "position", "the browser saved an unexpected key: " .. key)
end

-- The window saves in one place, the drop, as the top-left corner in UIParent units; a fit never saves.
local window = readFile("UI/Browser/Window.lua")
local _, saveCalls = window:gsub("B%.Save%(", "")
assert(saveCalls == 1, "the window must save only on a drop")
assert(window:find('B%.Save%("position", { "TOPLEFT", l, t %- ph }%)'), "the drop does not save the UIParent-unit corner")
assert(window:find('SetScript%("OnDragStop", function%(%) DropSave%(f%) end%)'), "drag stop does not save the position")
local fit = window:match("function Win%.Fit%(.-\nend")
assert(fit and not fit:find("B.Save", 1, true), "a fit must not save")
assert(window:find("SavedCorner", 1, true) and window:find("Win.Fit(true)", 1, true),
    "the window does not restore the saved position")
assert(not window:find("SetResiz", 1, true), "the window must not be resizable")
local browser = readFile("UI/Browser/Browser.lua")
local _, browserSaves = browser:gsub("B%.Save%(\"", "")
assert(browserSaves == 2, "the router saves only the Hide toggle and the 3D preview setting")
TakeWrites()

-- Options: one Decor Browser header and one checkbox, the 3D preview. A profile without the key reads on; the
-- checkbox writes model3D alone, while the browser is open or closed.
do
    assert(loadfile(root .. "/UI/OptionsModel.lua"))("Homestead", HA)
    local found = {}
    for _, section in ipairs(HA.OptionsModel.sections) do
        for _, row in ipairs(section.rows) do
            if tostring(row.key):find("^browser") then found[#found + 1] = row end
        end
    end
    assert(#found == 2 and found[1].type == "header" and found[2].type == "checkbox"
        and found[2].label == "Show 3D preview", "the Options rows for the Decor Browser are not one header and one checkbox")
    local box = found[2]
    assert(saved.model3D == nil and box.get() == true, "a profile without the key does not read on")
    box.set(false)
    assert(TakeWrites() == "browser.model3D" and saved.model3D == false and box.get() == false,
        "the checkbox did not write model3D alone")
    B:Close()
    box.set(true)
    assert(TakeWrites() == "browser.model3D" and saved.model3D == true and box.get() == true,
        "the checkbox did not write model3D alone while the browser is closed")
    B:Open()
    TakeWrites()
end

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
assert(#allWrites >= 2, "the write log missed the player actions")
for _, entry in ipairs(allWrites) do
    assert(entry:find("^browser%."), "wrote outside profile.browser: " .. entry)
end

print("hs534_browser_persistence: ok")
