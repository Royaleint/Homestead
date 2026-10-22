-- luacheck: globals assert loadfile print io CreateFrame UIParent
-- Run from the repo root:  lua tests/hs538_widgets.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Collapsible groups in the browser lists: a collapsed header drops its rows,
-- expanding restores them, and each list key keeps its own collapsed set.
-------------------------------------------------------------------------------

local function noop() end
local function Stub() return setmetatable({}, { __index = function() return noop end }) end
UIParent = { GetWidth = function() return 1365 end, GetHeight = function() return 768 end }
CreateFrame = function() return Stub() end

local HA = { Constants = { TEXTURE_ROOT = "Textures/" } }
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)
for _, file in ipairs({ "Style", "Visuals", "Widgets" }) do
    assert(loadfile(root .. "/UI/Browser/" .. file .. ".lua"))("Homestead", HA)
end
local B = HA.DecorBrowser
B.State = { collapsed = setmetatable({}, { __index = function(t, k) local s = {} t[k] = s return s end }) }
local W = B.Widgets

local function lay(zones)
    local out = {}
    for _, z in ipairs(zones) do
        out[#out + 1] = { kind = "header", text = z[1] }
        for i = 1, z[2] do out[#out + 1] = { kind = "vendor", vendor = { name = z[1] .. i } } end
    end
    return out
end
local function newList()
    local l = { SetGroups = W.SetGroups, ToggleGroup = W.ToggleGroup }
    function l:SetData(d) self.shown = d end
    return l
end
local function shape(lst)
    local t = {}
    for _, d in ipairs(lst.shown) do t[#t + 1] = d.kind == "header" and (d.collapsed and "+" or "-") .. d.text or "v" end
    return table.concat(t, ",")
end
local a, b = newList(), newList()
a:SetGroups(lay({ { "Ard", 2 }, { "Zul", 1 } }), "shops:Midnight", false)
b:SetGroups(lay({ { "Ard", 2 } }), "shops:Dragonflight", false)
assert(shape(a) == "-Ard,v,v,-Zul,v", "default is all expanded: " .. shape(a))
a:ToggleGroup("Ard")
assert(shape(a) == "+Ard,-Zul,v", "collapse hides that group's rows only: " .. shape(a))
assert(shape(b) == "-Ard,v,v", "another page's set is independent")
a:SetGroups(lay({ { "Ard", 2 }, { "Zul", 1 } }), "shops:Midnight", true)
assert(shape(a) == "+Ard,-Zul,v", "a re-render keeps the collapsed set")
a:ToggleGroup("Zul")
assert(shape(a) == "+Ard,+Zul", "several groups can be collapsed at once")
a:ToggleGroup("Ard")
a:ToggleGroup("Zul")
assert(shape(a) == "-Ard,v,v,-Zul,v", "expanding restores the rows")
local hdr = a.shown[1]
assert(hdr.list == a and hdr.key == "Ard", "a header reaches its list and key")
assert(next(B.State.collapsed["shops:Midnight"]) == nil, "an expanded group leaves no key behind")

print("hs538_widgets: ok")
