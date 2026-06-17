-- luacheck: globals assert loadfile print

local HA = {
    Constants = {
        Icons = {
            HOMESTONE_BASE = { atlas = "homestone-minimap-icon" },
            HOMESTONE_INNERGLOW = { atlas = "homestone-minimap-icon-innerglow" },
        },
        Colors = {
            COLLECTED = { r = 0.0, g = 0.8, b = 0.0, a = 1.0 },
            IN_BAGS_UNLEARNED = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 },
            NOT_COLLECTED = { r = 0.8, g = 0.0, b = 0.0, a = 1.0 },
        },
        Overlay = {
            ICON_SIZE = 14,
            DEFAULT_ANCHOR = "TOPLEFT",
            OFFSET_X = 2,
            OFFSET_Y = -2,
        },
    },
    Events = {},
    Addon = {
        db = {
            profile = {
                overlay = {
                    iconSize = 14,
                    iconAnchor = "TOPLEFT",
                },
            },
        },
        Debug = function() end,
    },
}

local function newTexture()
    local texture = {
        color = { 1, 1, 1, 1 },
        height = nil,
        point = nil,
        shown = false,
        width = nil,
    }

    function texture:ClearAllPoints() end
    function texture:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
        self.point = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            offsetX = offsetX,
            offsetY = offsetY,
        }
    end
    function texture:SetSize(width, height)
        self.width = width
        self.height = height
    end
    function texture:SetAtlas(atlas) self.atlas = atlas end
    function texture:SetTexture(texturePath) self.texture = texturePath end
    function texture:SetVertexColor(r, g, b, a) self.color = { r, g, b, a or 1 } end
    function texture:GetVertexColor() return self.color[1], self.color[2], self.color[3], self.color[4] end
    function texture:Show() self.shown = true end
    function texture:Hide() self.shown = false end

    return texture
end

local parent = {}
function parent:CreateTexture()
    return newTexture()
end

local chunk = assert(loadfile("Overlay/overlay.lua"))
chunk("Homestead", HA)

HA.Overlay:SetHomestoneState(parent, "owned")

local br, bg, bb, ba = parent.HomestoneBase:GetVertexColor()
local gr, gg, gb, ga = parent.HomestoneGlow:GetVertexColor()

local function nearlyEqual(actual, expected)
    return math.abs(actual - expected) < 0.0001
end

assert(br > 0.0 and br < 1.0 and bg > br and bg > bb and bb > 0.0 and bb < 1.0 and ba == 1.0,
    string.format("expected base to be subtly owned-tinted, got %.2f/%.2f/%.2f/%.2f", br, bg, bb, ba))
assert(br > gr and bb > gb,
    string.format("expected base tint to be less saturated than glow, base %.2f/%.2f/%.2f glow %.2f/%.2f/%.2f",
        br, bg, bb, gr, gg, gb))
assert(nearlyEqual(br, 0.55) and nearlyEqual(bg, 0.91) and nearlyEqual(bb, 0.55),
    string.format("expected stronger owned base tint, got %.2f/%.2f/%.2f", br, bg, bb))
assert(gr == 0.0 and gg == 0.8 and gb == 0.0 and ga == 1.0,
    string.format("expected glow to be owned green, got %.2f/%.2f/%.2f/%.2f", gr, gg, gb, ga))
assert(parent.HomestoneGlow.width > parent.HomestoneBase.width,
    string.format("expected glow width to exceed base width, got %s <= %s",
        tostring(parent.HomestoneGlow.width), tostring(parent.HomestoneBase.width)))
assert(parent.HomestoneGlow.height > parent.HomestoneBase.height,
    string.format("expected glow height to exceed base height, got %s <= %s",
        tostring(parent.HomestoneGlow.height), tostring(parent.HomestoneBase.height)))
assert(parent.HomestoneGlow.point.point == "CENTER"
    and parent.HomestoneGlow.point.relativeTo == parent.HomestoneBase
    and parent.HomestoneGlow.point.relativePoint == "CENTER"
    and parent.HomestoneGlow.point.offsetX == 0
    and parent.HomestoneGlow.point.offsetY == 0,
    "expected enlarged glow to stay centered on the neutral base")

print("hs123_homestone_tint: ok")
