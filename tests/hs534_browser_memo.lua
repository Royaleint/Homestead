-- luacheck: globals assert loadfile print io wipe C_Timer

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The catalog memo lasts one page show. Refreshes for arriving item names, the
-- vendor-count fill, search or Hide owned keep it; a refresh after new data
-- (the shared memos invalidated) and every page show empty it.
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

local HA = { Constants = { TEXTURE_ROOT = "Textures/" } }
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)
for line in readFile("Homestead.toc"):gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI\\Browser\\[%w_]+%.lua)%s*$")
    if entry then assert(loadfile(root .. "/" .. entry:gsub("\\", "/")))("Homestead", HA) end
end

local B = HA.DecorBrowser
HA.PerformanceTrace = { Measure = function(_, _, _, fn, ...) return fn(...) end }

local function stubFrame()
    local shown = false
    return {
        Show = function() shown = true end,
        Hide = function() shown = false end,
        IsShown = function() return shown end,
    }
end
local Win = B.Window
Win.frame = stubFrame()
Win.frame:Show()
for _, name in ipairs({ "ResetSearch", "SelectNav", "UpdateCrumbs", "UpdateProgress", "SetHideOwnedChecked" }) do
    Win[name] = function() end
end

local shows = 0
local function fakePage()
    return { usesCounts = true, Build = stubFrame, Show = function() shows = shows + 1 end }
end
B.RegisterPage("memoA", fakePage())
B.RegisterPage("memoB", fakePage())

local memo = B.State.catalogMemo
local function seed() memo[1] = "info" end
local function kept(why) assert(memo[1] == "info", "the catalog memo was emptied by " .. why) end
local function emptied(why) assert(memo[1] == nil, "the catalog memo survived " .. why) end

B.Go({ page = "memoA" })
seed()

B.RequestRefresh()
kept("an item-name refresh")
B.RequestRefresh(true)
kept("a vendor-count refresh")
B.SetSearch("bench")
kept("a search refresh")
B.SetHideOwned(true)
kept("a Hide owned refresh")

B.RequestRefresh(false, true)
emptied("a refresh after new data")
seed()
B.RequestRefresh()
kept("the item-name refresh after an invalidation")

B.Go({ page = "memoB" })
emptied("a page show")
seed()
B.Go({ page = "memoB" })
emptied("showing the same page again")

assert(shows == 9, "expected every route and refresh to render its page, got " .. shows)
print("hs534_browser_memo: ok")
