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
assert(#files >= 7, "the TOC lists too few UI/Browser Lua files")
assert(files[#files] == "UI/Browser/Item.lua", "Item.lua must load last")

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
for _, fn in ipairs({ "Toggle", "Open", "Close", "RequestRefresh",
        "Tooltip", "HideTooltip", "ShowItemTooltip" }) do
    assert(type(B[fn]) == "function", "B." .. fn .. " is missing")
end
assert(B.Window.frame == nil, "the window exists before the first open")

assert(B.Item == nil and B.ItemDetail == nil, "the item page leaks a public table; it registers with the router")
assert(type(B.Data.ReportText) == "function", "Data.ReportText is missing")
for _, fn in ipairs({ "RegisterTab", "ShowTab", "Walk" }) do
    assert(type(B[fn]) == "function", "B." .. fn .. " is missing")
end

-- TOC order: each file loads after the ones it reads; the tabs register with the router in Browser.lua.
local order = {}
for _, path in ipairs(files) do order[#order + 1] = path:match("([%w_]+)%.lua$") end
local pos = {}
for i, name in ipairs(order) do pos[name] = i end
local ORDER = { "Style", "Visuals", "Adapter", "Facts", "CanGet", "Widgets", "Window", "Browser",
    "Summary", "Catalog", "Sources", "Item" }
for i, name in ipairs(ORDER) do
    assert(pos[name], name .. ".lua is not in the TOC")
    assert(i == 1 or pos[name] > pos[ORDER[i - 1]], name .. ".lua is out of order in the TOC")
end
assert(#order == #ORDER, "the TOC lists a UI/Browser Lua file this test does not know")

-- The counters must see what they claim to: the stubs count when called.
stubs.CreateFrame():RegisterEvent("X")
stubs.C_Timer.After(0, print)
HA.Events.RegisterCallback()
for what, n in pairs(counts) do assert(n == 1, "the " .. what .. " counter is broken") end

print("hs534_browser_load_cost: ok (" .. #files .. " files)")
