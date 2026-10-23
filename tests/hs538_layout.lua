-- luacheck: globals assert loadfile print CreateFrame UIParent C_Texture PixelUtil CreateColor C_ColorOverrides
-- luacheck: globals CreateScrollBoxListLinearView ScrollUtil CreateAnchor CreateDataProvider TextSizeManager
-- luacheck: globals CreateFont NineSliceUtil
-- luacheck: globals wipe
-- Run from the repo root:  lua tests/hs538_layout.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Sizes follow the player's text size. With every font's height scaled by the
-- user font scale (Small 0.8571 to Gigantic 2.0), rows, buttons, the footer and
-- the toolbar are at least the measured text plus padding, the list extent is
-- the sum of its rows' heights, and the window keeps its logical size.
-------------------------------------------------------------------------------

local BASE = {
    UserScaledFontGameHighlightSmall = 10, UserScaledFontGameNormalSmall = 10, UserScaledFontGameDisableSmall = 10,
    UserScaledFontGameHighlight = 12, UserScaledFontGameNormal = 12, UserScaledFontGameDisable = 12,
    UserScaledFontGameNormalMed2 = 14, UserScaledFontGameNormalLarge = 16,
}
local scale = 1

local function noop() end
local Widget
local methods = {}
function methods.CreateFontString(self, _, _, font) local fs = Widget("FontString") fs.font = font return fs end
function methods.CreateTexture() return Widget("Texture") end
function methods.SetFontObject(self, font) self.font = font end
function methods.SetText(self, text) self.text = text end
function methods.GetText(self) return self.text end
function methods.SetWidth(self, w) self.width = w end
function methods.GetWidth(self) return self.width or 0 end
function methods.SetHeight(self, h) self.height = h end
function methods.GetHeight(self) return self.height or 0 end
function methods.SetSize(self, w, h) self.width, self.height = w, h end
function methods.SetShown(self, on) self.shown = on end
function methods.Show(self) self.shown = true end
function methods.Hide(self) self.shown = false end
function methods.IsShown(self) return self.shown end
function methods.SetScript(self, name, fn) self.scripts[name] = fn end
function methods.HookScript(self, name, fn) self.scripts[name] = fn end
function methods.GetStringWidth(self) return #self.text * 6 * scale end
function methods.GetUnboundedStringWidth(self) return #self.text * 6 * scale end
function methods.GetTextWidth(self) return #self.text * 6 * scale end
function methods.GetFrameLevel() return 1 end
function methods.GetStringHeight(self)
    local line = (BASE[self.font] or 12) * scale
    if self.width and self.width > 0 then
        return line * math.max(1, math.ceil(#self.text * 6 * scale / self.width))
    end
    return line
end
function Widget(kind)
    return setmetatable({ kind = kind, shown = true, text = "", scripts = {} }, {
        __index = function(_, k) return methods[k] or noop end,
    })
end

UIParent = Widget("UIParent")
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
CreateFrame = function(kind) return Widget(kind) end
C_Texture = { GetAtlasInfo = function() return nil end }
PixelUtil = { SetHeight = noop, SetWidth = noop }
NineSliceUtil = { ApplyLayoutByName = noop }
CreateColor = function() return {} end
CreateAnchor = noop
CreateDataProvider = function(t) return t end
TextSizeManager = { GetScale = function() return scale end }
C_ColorOverrides = { GetColorForQuality = function() return { r = 1, g = 1, b = 1 } end }
ScrollUtil = { InitScrollBoxListWithScrollBar = noop, AddManagedScrollBarVisibilityBehavior = noop }

local view
CreateScrollBoxListLinearView = function()
    view = Widget("View")
    function view:SetElementExtentCalculator(fn) self.extent = fn end
    return view
end

local HA = { Constants = { TEXTURE_ROOT = "Textures/" } }
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)
for _, file in ipairs({ "Style", "Visuals", "Widgets" }) do
    assert(loadfile(root .. "/UI/Browser/" .. file .. ".lua"))("Homestead", HA)
end
local B = HA.DecorBrowser
local S, W = B.Style, B.Widgets
local R = S.row

for _, s in ipairs({ 0.8571, 1, 2.0 }) do
    scale = s
    local body, meta = 12 * s, 10 * s
    assert(W.TextHeight("body") == body, "the ruler did not measure body text at scale " .. s)
    assert(W.TextHeight("meta") == meta, "the ruler did not measure meta text at scale " .. s)

    -- A row holds two lines of body text between its padding, and never less than its tile.
    local rowH = W.RowHeight()
    assert(rowH >= 2 * body + 2 * R.pad, "row is shorter than its text at scale " .. s)
    assert(rowH >= R.tile + 2 * R.pad, "row is shorter than its tile at scale " .. s)

    -- The list extent is the sum of the row heights, so the last row is reachable.
    local list = W.NewList(Widget("Frame"), { kinds = { row = { frameType = "Button", build = noop, init = noop } } })
    assert(list and view.extent, "the list set no extent calculator")
    local total = 0
    for _ = 1, 40 do total = total + view.extent(nil, { kind = "row" }) end
    assert(total == 40 * rowH, "the list extent is not the sum of its rows at scale " .. s)

    -- Buttons and the group header grow with the text.
    local b = W.NewButton(Widget("Frame"), "Reset filters", noop)
    assert(b.height >= body, "a button is shorter than its text at scale " .. s)
    assert(b.width >= #"Reset filters" * 6 * s, "a button is narrower than its text at scale " .. s)
    assert(W.HeaderHeight() >= body, "the group header is shorter than its text at scale " .. s)

    -- The footer wraps: narrower lists give taller footers, and it always holds text plus the link.
    local d = { hidden = 12, collected = 7, faction = 5, factionName = "Horde" }
    local wide, narrow = W.FooterHeight(d, 2000), W.FooterHeight(d, 200)
    assert(wide >= 2 * body, "the footer is shorter than its text and link at scale " .. s)
    assert(narrow > wide, "a narrow footer does not wrap into more height at scale " .. s)
end

-- The window keeps its logical size whatever the text size (the fit scales the frame, not the size).
assert(S.window.width == 860 and S.window.height == 580, "the window's logical size changed")

-- The title step is the header font, one of Blizzard's user-scaled fonts, so it follows the text size without a private font.
scale = 1
local made = false
CreateFont = function()
    made = true
    return Widget("Font")
end
local title = S.Text(Widget("Frame"), "header")
assert(title.font == "UserScaledFontGameNormalLarge", "the title is not the header font")
assert(not made and S.font.display == nil, "a private display font is still made")
scale = 2
assert(W.TextHeight("header") == 32, "the header step did not follow the text size")

-- Heights are measured once per text size, not once per row.
local measures = 0
local rawHeight = methods.GetStringHeight
methods.GetStringHeight = function(self)
    measures = measures + 1
    return rawHeight(self)
end
for _, s in ipairs({ 1, 2.0 }) do
    scale = s
    measures = 0
    for _ = 1, 1000 do
        W.RowHeight()
        W.HeaderHeight()
    end
    assert(measures <= 2, "1,000 height asks measured " .. measures .. " times at scale " .. s)
    assert(W.RowHeight() >= 2 * 12 * s, "the cached row height is wrong at scale " .. s)
end
W.ResetMeasure()
measures = 0
W.RowHeight()
assert(measures >= 1, "ResetMeasure did not force a new measure")
methods.GetStringHeight = rawHeight

print("hs538_layout: ok")
