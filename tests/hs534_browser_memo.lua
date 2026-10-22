-- luacheck: globals assert loadfile print io wipe C_Timer InCombatLockdown

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The catalog memo lasts one show. Refreshes for arriving item names, the
-- vendor-count fill or a search keep it; a refresh after new data (the shared
-- memos invalidated) and every open empty it.
-------------------------------------------------------------------------------

local function readFile(path)
    local f = assert(io.open(root .. "/" .. path, "rb"), "cannot open " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

function wipe(t)
    for k in pairs(t) do t[k] = nil end
    return t
end
C_Timer = { After = function(_, fn) fn() end }
InCombatLockdown = function() return false end

local HA = {
    Constants = { TEXTURE_ROOT = "Textures/" },
    Addon = { _enabled = true },
    Events = { RegisterCallback = function() end },
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

local Win = B.Window
local shown = false
Win.frame = {
    Show = function() shown = true end,
    Hide = function() shown = false end,
    IsShown = function() return shown end,
}
for _, name in ipairs({ "ResetSearch", "Clamp" }) do
    Win[name] = function() end
end

local memo = B.State.catalogMemo
local function seed() memo[1] = "info" end
local function kept(why) assert(memo[1] == "info", "the catalog memo was emptied by " .. why) end
local function emptied(why) assert(memo[1] == nil, "the catalog memo survived " .. why) end

B:Open()
assert(shown, "the browser did not open")
seed()

B.RequestRefresh()
kept("an item-name refresh")
B.RequestRefresh(true)
kept("a vendor-count refresh")
B.SetSearch("bench")
kept("a search refresh")

B.RequestRefresh(false, true)
emptied("a refresh after new data")
seed()
B.RequestRefresh()
kept("the item-name refresh after an invalidation")

B:Close()
B:Open()
emptied("an open")
seed()
B:Close()
B:Open()
emptied("opening again")

local want = "browser_reopen,browser_refresh,browser_refresh,browser_refresh,browser_refresh,"
    .. "browser_reopen,browser_reopen"
assert(table.concat(measured, ",") == want, "unexpected renders: " .. table.concat(measured, ","))
print("hs534_browser_memo: ok")
