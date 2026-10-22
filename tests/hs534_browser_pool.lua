-- luacheck: globals assert loadfile print io CreateFrame
local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- A frame is built once and pooled by frameType, so no two kinds of one list may share a frameType.
-- Runs the real Shops and Sources page builds, takes the kinds they hand to the list, and feeds
-- them through a stub factory that pools by frame type and reuses the last released frame first.
-------------------------------------------------------------------------------

local HA = { Constants = { TEXTURE_ROOT = "Textures/" } }
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)
local toc = assert(io.open(root .. "/Homestead.toc", "rb")):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI\\Browser\\[%w_]+%.lua)%s*$")
    if entry then assert(loadfile(root .. "/" .. entry:gsub("\\", "/")))("Homestead", HA) end
end
local B = HA.DecorBrowser
local W = B.Widgets

local captured = {}
W.NewList = function(_, opts) captured[#captured + 1] = opts; return {} end
W.NewEmptyState = function() return {} end
local frame = { SetAllPoints = function() end }
CreateFrame = function() return frame end
B.pages.shops.Build({})
B.pages.sources.Build({})
assert(#captured == 2, "both pages build a list")

-- Any frameType that is not a native one must be a template declared in Visuals.xml.
local xml = assert(io.open(root .. "/UI/Browser/Visuals.xml", "rb")):read("*a")
for _, opts in ipairs(captured) do
    for kind, spec in pairs(opts.kinds) do
        local t = spec.frameType
        assert(t == "Frame" or t == "Button" or xml:find('name="' .. t .. '"', 1, true), kind .. ": undeclared template " .. t)
    end
end

for i, opts in ipairs(captured) do
    local factory = W.KindFactory(opts.kinds)
    local order = {}
    for kind, spec in pairs(opts.kinds) do
        order[#order + 1] = kind
        spec.build = function(f) f.builtAs = kind end
        spec.init = function(f, d) assert(f.builtAs == d.kind, "list " .. i .. ": a " .. f.builtAs .. " frame was initialised as " .. d.kind) end
    end
    table.sort(order)
    local pool = {}
    local function show(kind)
        local made
        factory(function(frameType, init)
            local stack = pool[frameType] or {}
            pool[frameType] = stack
            local f = table.remove(stack) or {}
            init(f, { kind = kind })
            made = { f = f, type = frameType }
        end, { kind = kind })
        return made
    end
    -- Show every kind, release them all, then bring them back in each other order.
    for round = 1, 3 do
        local held = {}
        for k = 1, #order do held[#held + 1] = show(order[(k + round - 2) % #order + 1]) end
        for _, h in ipairs(held) do table.insert(pool[h.type], h.f) end
    end
end

print("hs534_browser_pool: ok")
