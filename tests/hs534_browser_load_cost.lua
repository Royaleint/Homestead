-- luacheck: globals assert loadfile loadstring print io setfenv

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- A browser that is never opened costs nothing: loading every UI/Browser file
-- in TOC order creates no frame, registers no event or Homestead callback,
-- starts no timer and touches no game API. Each file runs against counting
-- stubs, and any other game global it reads at load fails the test.
-------------------------------------------------------------------------------

local function readFile(path)
    local f = assert(io.open(root .. "/" .. path, "rb"), "cannot open " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

local files = {}
for line in readFile("Homestead.toc"):gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI\\Browser\\[%w_\\]+%.lua)%s*$")
    if entry then files[#files + 1] = (entry:gsub("\\", "/")) end
end
assert(#files >= 8, "the TOC lists too few UI/Browser Lua files")
assert(files[#files] == "UI/Browser/Browser.lua", "Browser.lua must load last")

local counts = { CreateFrame = 0, RegisterEvent = 0, RegisterCallback = 0, C_Timer = 0 }

local frameMeta = { __index = function(_, method)
    return function()
        if method == "RegisterEvent" or method == "RegisterUnitEvent" then
            counts.RegisterEvent = counts.RegisterEvent + 1
        end
    end
end }

local stubs = {
    CreateFrame = function()
        counts.CreateFrame = counts.CreateFrame + 1
        return setmetatable({}, frameMeta)
    end,
    C_Timer = setmetatable({}, { __index = function()
        return function() counts.C_Timer = counts.C_Timer + 1 end
    end }),
}

-- Lua itself, plus the stubs above. Anything else read while a file loads is a game API touch.
local env = {}
for k, v in pairs(_G) do env[k] = v end
for k, v in pairs(stubs) do env[k] = v end
env._G = env
local stray = {}
setmetatable(env, { __index = function(_, name)
    stray[#stray + 1] = name
    return nil
end })

local HA = {
    Constants = { TEXTURE_ROOT = "Textures/" },
    Events = { RegisterCallback = function()
        counts.RegisterCallback = counts.RegisterCallback + 1
    end },
}

local function load(path)
    local chunk = assert(loadfile(root .. "/" .. path))
    setfenv(chunk, env)
    chunk("Homestead", HA)
end

-- The strict environment must catch a read through _G as well as a bare one.
do
    local probe = assert(loadstring("local a = _G.HomesteadLoadProbe; local b = HomesteadBareProbe"))
    setfenv(probe, env)
    probe()
    assert(table.concat(stray, ",") == "HomesteadLoadProbe,HomesteadBareProbe",
        "the strict environment missed a probe read: " .. table.concat(stray, ","))
    for i = #stray, 1, -1 do stray[i] = nil end
end

-- enUS runs first in the real TOC and reads a few Blizzard strings with fallbacks.
local enUS = assert(loadfile(root .. "/Locale/enUS.lua"))
enUS("Homestead", HA)

for _, path in ipairs(files) do
    load(path)
    assert(#stray == 0, path .. " reads game globals at load: " .. table.concat(stray, ", "))
end

for what, n in pairs(counts) do
    assert(n == 0, what .. " ran " .. n .. " time(s) at load")
end

local B = HA.DecorBrowser
assert(B and B.Window and B.Data and B.Widgets, "the browser modules did not load")
for _, fn in ipairs({ "Toggle", "Open", "Close", "RegisterPage", "Go", "Back", "RequestRefresh",
        "Tooltip", "HideTooltip", "ShowItemTooltip", "ShowLinkTooltip", "ValidateLastPage" }) do
    assert(type(B[fn]) == "function", "B." .. fn .. " is missing")
end
assert(B.Window.frame == nil, "the window exists before the first open")

-- Pages load before Browser.lua and still reach its router.
-- Browser.lua loads last, so a stub registered there would replace the real Overview.
local PAGES = {
    overview = { topLevel = true, searchable = false, fns = { "Build", "Show", "Shown" } },
    shops = { topLevel = true, searchable = true, fns = { "Build", "Show", "Hide" } },
    shop = { topLevel = false, searchable = true, fns = { "Build", "Show", "Hide" } },
    item = { topLevel = false, searchable = false, fns = { "Build", "Show", "Hide" } },
    sources = { topLevel = true, searchable = true, fns = { "Build", "Show", "SetCombatGated" } },
}
for key, want in pairs(PAGES) do
    local page = B.pages[key]
    assert(page, "the " .. key .. " page did not register")
    for _, fn in ipairs(want.fns) do
        assert(type(page[fn]) == "function", key .. "." .. fn .. " is missing")
    end
    assert(page.topLevel == want.topLevel and page.searchable == want.searchable,
        key .. " has the wrong page flags")
end
assert(type(B.pages.item.SetCombatGated) == "function", "the item page has no combat gate")
assert(type(B.pages.overview.RelativeDate) == "function", "the registered overview is not the real page")

-- TOC order: the pages in the agreed order, all before Browser.lua.
local order = {}
for _, path in ipairs(files) do order[#order + 1] = path:match("([%w_]+)%.lua$") end
local pos = {}
for i, name in ipairs(order) do pos[name] = i end
local ORDER = { "Overview", "Shops", "Shop", "Item", "Sources", "Browser" }
for i, name in ipairs(ORDER) do
    assert(pos[name], name .. ".lua is not in the TOC")
    assert(i == 1 or pos[name] > pos[ORDER[i - 1]], name .. ".lua is out of order in the TOC")
end

-- The counters must see what they claim to: the stubs count when called.
stubs.CreateFrame():RegisterEvent("X")
stubs.C_Timer.After(0, print)
HA.Events.RegisterCallback()
for what, n in pairs(counts) do assert(n == 1, "the " .. what .. " counter is broken") end

print("hs534_browser_load_cost: ok (" .. #files .. " files)")
