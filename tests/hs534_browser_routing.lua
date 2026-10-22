-- luacheck: globals assert loadfile loadstring print io setfenv
-- Run from the repo root:  lua tests/hs534_browser_routing.lua [root]

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

local function readFile(path)
    local f = assert(io.open(root .. "/" .. path, "rb"), "cannot open " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

-------------------------------------------------------------------------------
-- core.lua: which input reaches which function
-------------------------------------------------------------------------------
local core = readFile("Core/core.lua")

local function block(startPattern, endPattern)
    local s = assert(core:find(startPattern), "core.lua lacks: " .. startPattern)
    local _, e = core:find(endPattern, s)
    assert(e, "core.lua lacks: " .. endPattern)
    return core:sub(s, e)
end

local function calls(text, name)
    return text:find("self:" .. name .. "()", 1, true) ~= nil
end

local slash = block("defaultHandler = function", "\n")
assert(calls(slash, "ToggleBrowser") and not calls(slash, "OpenOptions"), "bare /hs must toggle the browser")

local config = block('name = "config"', "handler = function[^\n]*\n")
assert(calls(config, "OpenOptions"), "/hs config must open Options")

local click = block("OnClick = function", "OnTooltipShow")
local left = click:match('"LeftButton" then(.-)elseif')
local right = click:match('"RightButton" then(.-)end')
assert(left and calls(left, "ToggleBrowser"), "left click must toggle the browser")
assert(right and calls(right, "OpenOptions"), "right click must open Options")
assert(not click:find("ToggleDetached", 1, true), "right click must not toggle the detached panel")

local compartment = block("AddonCompartmentFrame:RegisterAddon", "funcOnEnter")
assert(calls(compartment, "ToggleBrowser"), "the Addon Compartment click must toggle the browser")

assert(core:find("function HousingAddon:ToggleBrowser()", 1, true), "ToggleBrowser is not defined")
assert(not core:find("ToggleOptions", 1, true), "ToggleOptions has no caller left and must stay removed")
assert(core:find("HA.DecorBrowser:Toggle()", 1, true), "ToggleBrowser must call HA.DecorBrowser:Toggle()")

-------------------------------------------------------------------------------
-- Bindings.xml and the binding strings
-------------------------------------------------------------------------------
local xml = readFile("Bindings.xml")
local tag, body = xml:match("<Binding%s+([^>]*)>(.-)</Binding>")
assert(tag, "Bindings.xml has no Binding element")
assert(tag:find('name="HOMESTEAD_TOGGLE_BROWSER"', 1, true), "wrong binding name")
assert(not tag:find("header=", 1, true), "a header= entry draws as a blank spacer row")
assert(tag:find('category="BINDING_HEADER_HOMESTEAD"', 1, true), "wrong binding category")
assert(select(2, xml:gsub("<Binding[%s>]", "")) == 1, "Bindings.xml must hold exactly one binding")

-- The body runs with the real addon global, and is safe before it exists.
local function runBinding(env)
    local fn = assert(loadstring(body, "binding"))
    setfenv(fn, env)
    fn()
end
runBinding({})
runBinding({ Homestead = {} })
local toggled = 0
runBinding({ Homestead = { DecorBrowser = { Toggle = function() toggled = toggled + 1 end } } })
assert(toggled == 1, "the binding must call Homestead.DecorBrowser:Toggle() once")
assert(core:find("_G.Homestead = HA", 1, true), "the global the binding uses is no longer exported")

local HA = { Constants = { TEXTURE_ROOT = "Textures/" } }
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)
for line in readFile("Homestead.toc"):gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI\\Browser\\[%w_]+%.lua)%s*$")
    if entry then assert(loadfile(root .. "/" .. entry:gsub("\\", "/")))("Homestead", HA) end
end

assert(BINDING_HEADER_HOMESTEAD == HA.L["Homestead"], "binding header string is not set from L")
assert(BINDING_NAME_HOMESTEAD_TOGGLE_BROWSER == HA.L["Toggle Decor Browser"], "binding name string is not set from L")

print("hs534_browser_routing: ok")
