-- luacheck: globals assert loadfile print io wipe C_Timer InCombatLockdown CreateFrame EventRegistry

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The catalog memo lasts one show. Refreshes for arriving item names or the
-- vendor-count fill keep it; a refresh after new data (the shared memos
-- invalidated) and every open empty it.
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
InCombatLockdown = function() return false end
CreateFrame = blank
EventRegistry = { RegisterCallback = noop, UnregisterCallback = noop }

local HA = {
    Constants = { TEXTURE_ROOT = "Textures/" },
    Addon = { _enabled = true },
    Events = { RegisterCallback = noop, UnregisterCallback = noop },
}
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)
for line in readFile("Homestead.toc"):gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI\\Browser\\[%w_]+%.lua)%s*$")
    if entry then assert(loadfile(root .. "/" .. entry:gsub("\\", "/")))("Homestead", HA) end
end

local B = HA.DecorBrowser
local measured = {}
HA.PerformanceTrace = { Measure = function(_, operation, _, fn, ...)
    measured[#measured + 1] = operation
    return fn(...)
end }
B.Data.IsReady = function() return true end
B.Data.CollectionState = function() return "ready" end
B.Facts.Here = noop
B.CanGet.RefreshNames = noop

local Win = B.Window
local shown, hooks = false, nil
local frame = { IsVisible = function() return shown end, IsShown = function() return shown end }
Win.Build = function(h)
    hooks = h
    Win.frame, Win.host, Win.hideNA = frame, blank(), blank()
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
for _, name in ipairs({ "CheckTextScale", "Fit", "SetSelectedTab", "SetLocation", "AssertPropagation", "StopGlow" }) do
    Win[name] = noop
end
for _, key in ipairs({ "summary", "catalog", "sources" }) do
    B.RegisterTab(key, { Build = noop, Show = noop, Hide = noop, Refresh = noop, SetCombat = noop })
end

local memo = B.State.catalogMemo
local function seed() memo[1] = "info" end
local function kept(why) assert(memo[1] == "info", "the catalog memo was emptied by " .. why) end
local function emptied(why) assert(memo[1] == nil, "the catalog memo survived " .. why) end

B:Open()
assert(shown, "the browser did not open")
emptied("the first open")
seed()

B.RequestRefresh()
flush()
kept("an item-name refresh")
B.RequestRefresh(true)
flush()
kept("a vendor-count refresh")
B.ShowTab("catalog")
kept("a tab change")

B.RequestRefresh(false, true)
flush()
emptied("a refresh after new data")
seed()
B.RequestRefresh()
flush()
kept("the item-name refresh after an invalidation")

B:Close()
B:Open()
emptied("an open")
seed()
B:Close()
B:Open()
emptied("opening again")

local want = "browser_first_open,browser_tab_show,browser_refresh,browser_refresh,browser_tab_show,"
    .. "browser_refresh,browser_refresh,browser_reopen,browser_tab_show,browser_reopen,browser_tab_show"
assert(table.concat(measured, ",") == want, "unexpected renders: " .. table.concat(measured, ","))
print("hs534_browser_memo: ok")
