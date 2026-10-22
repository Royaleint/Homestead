-- luacheck: globals assert loadfile print io CreateFrame UIParent C_Texture PixelUtil CreateColor C_ColorOverrides
-- luacheck: globals CreateScrollBoxListLinearView ScrollUtil CreateAnchor CreateDataProvider TextSizeManager NineSliceUtil
-- Run from the repo root:  lua tests/hs538_widgets.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The shared parts: a decor row shows each state's words with its second signal
-- (and red only for the other faction), the empty-state kinds say their own
-- words and show only the buttons a tab asked for, the hidden-by footer reads
-- as the spec words it, the columns have their widths, and a search box is
-- known to Escape.
-------------------------------------------------------------------------------

local function noop() end
local Widget
local made = {}
local methods = {}
function methods.CreateFontString(self, _, _, font)
    local fs = Widget("FontString")
    fs.font = font
    made[#made + 1] = fs
    return fs
end
function methods.CreateTexture() return Widget("Texture") end
function methods.SetFontObject(self, font) self.font = font end
function methods.SetText(self, text) self.text = text end
function methods.GetText(self) return self.text end
function methods.SetWidth(self, w) self.width = w end
function methods.GetWidth(self) return self.width or 0 end
function methods.SetSize(self, w, h) self.width, self.height = w, h end
function methods.SetHeight(self, h) self.height = h end
function methods.SetShown(self, on) self.shown = on end
function methods.Show(self) self.shown = true end
function methods.Hide(self) self.shown = false end
function methods.IsShown(self) return self.shown end
function methods.SetScript(self, name, fn) self.scripts[name] = fn end
function methods.HookScript(self, name, fn) self.scripts[name] = fn end
function methods.SetAlpha(self, a) self.alpha = a end
function methods.SetDesaturated(self, on) self.desaturated = on end
function methods.SetTextColor(self, r, g, b) self.color = { r, g, b } end
function methods.SetVertexColor(self, r, g, b) self.color = { r, g, b } end
function methods.SetColorTexture(self, r, g, b) self.color = { r, g, b } end
function methods.GetUnboundedStringWidth(self) return #self.text * 6 end
function methods.GetStringHeight() return 12 end
function methods.GetTextWidth(self) return #self.text * 6 end
function methods.GetFrameLevel() return 1 end
function methods.GetParent(self) return self.parent end
function Widget(kind)
    return setmetatable({ kind = kind, shown = true, text = "", scripts = {} }, {
        __index = function(_, k) return methods[k] or noop end,
    })
end

UIParent = Widget("UIParent")
CreateFrame = function(kind, _, parent)
    local w = Widget(kind)
    w.parent = parent
    if kind == "EditBox" then w.Instructions = Widget("FontString") end
    return w
end
C_Texture = { GetAtlasInfo = function() return nil end }
PixelUtil = { SetHeight = noop, SetWidth = noop }
NineSliceUtil = { ApplyLayoutByName = noop }
CreateColor = function() return {} end
CreateAnchor = noop
CreateDataProvider = function(t) return t end
TextSizeManager = { GetScale = function() return 1 end }
C_ColorOverrides = { GetColorForQuality = function() return { r = 0, g = 0.5, b = 1 } end }
ScrollUtil = { InitScrollBoxListWithScrollBar = noop, AddManagedScrollBarVisibilityBehavior = noop }
CreateScrollBoxListLinearView = function() return Widget("View") end

local HA = { Constants = { TEXTURE_ROOT = "Textures/" } }
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)
for _, file in ipairs({ "Style", "Visuals", "Widgets" }) do
    assert(loadfile(root .. "/UI/Browser/" .. file .. ".lua"))("Homestead", HA)
end
local B = HA.DecorBrowser
local S, W = B.Style, B.Widgets
local K = S.color
local searchBoxes = {}
B.Window = { AddSearchBox = function(box) searchBoxes[#searchBoxes + 1] = box end }

local function find(text)
    for _, fs in ipairs(made) do
        if fs.text == text then return fs end
    end
end
local function sameColor(a, b) return a and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end

-- Rows: the words of every state, and a second signal wherever one is called for.
local row
local cases = {
    { "owned", nil, "Collected", K.muted, true },
    { "can", nil, "Can get now", K.can, true },
    { "locked", "Alliance Renown 5", "Requires: Alliance Renown 5", K.muted, true },
    { "faction", "Horde", "Horde only", K.stop, true },
    { "event", "Noblegarden", "Noblegarden only", K.muted, true },
    { "notOwned", nil, "Not collected", K.muted, false },
    { "counting", nil, "Counting…", K.muted, false },
}
for _, case in ipairs(cases) do
    local state, arg, words, color, marked = case[1], case[2], case[3], case[4], case[5]
    made = {}
    row = W.BuildRow(CreateFrame("Button", nil, Widget("Frame")))
    row:Set({ name = "Oak Bench", quality = 3, state = state, arg = arg, line2 = "Vendor: Joruh" })
    local fs = find(words)
    assert(fs, "no words '" .. words .. "' for state " .. state)
    assert(sameColor(fs.color, color), "wrong colour for " .. state)
    if state ~= "faction" then
        assert(not sameColor(fs.color, K.stop), state .. " must not be red")
    end
    assert(W.StateWords(state, arg) == words, "StateWords disagrees for " .. state)
    local nameFs = find("Oak Bench")
    assert(nameFs.color[2] == 0.5, "the name is not in the quality colour")
    assert(nameFs.alpha == (state == "owned" and 0.55 or 1), "only a Collected row is dimmed")
    assert((marked and 1 or 0) == (S.state[state].glyph and 1 or 0), "second signal table disagrees for " .. state)
end

-- No lock badge, no "Unlocked to buy" and no stateLabel on rows; red belongs to the faction state alone.
for state, st in pairs(S.state) do
    assert(not st.word:find("Unlocked"), "state " .. state .. " says Unlocked to buy")
    if st.color == K.stop then assert(state == "faction", "red on " .. state) end
end
assert(S.state.unlocked == nil, "an unlocked row state exists")
local f = assert(io.open(root .. "/UI/Browser/Widgets.lua", "rb"))
local src = f:read("*a")
f:close()
assert(not src:find("Unlocked", 1, true) and not src:find("stateLabel", 1, true) and not src:find("lockBadge", 1, true),
    "Widgets refers to the old row states or the lock badge")

-- Tags and counts on the source line.
made = {}
row = W.BuildRow(CreateFrame("Button", nil, Widget("Frame")))
row:Set({ name = "Oak Bench", quality = 1, state = "can", line2 = "Vendor: Joruh (+2 more)", unconfirmed = true, active = true })
assert(find("Vendor: Joruh (+2 more)"), "the source line is not drawn as given")
assert(find("Not confirmed"), "the Not confirmed tag text is missing")
assert(find("Active now"), "the Active now badge text is missing")

-- Empty states say their own words; buttons show only for handlers a tab passes.
local function empty(kind, d)
    local e = W.NewEmptyState(Widget("Frame"))
    e:Set(kind, d)
    return e
end
local e = empty("noResults", { onReset = noop })
assert(e.title.text == "No results" and e.text.text:find("Search looks at item names only", 1, true), "no-results words")
assert(e.buttons[1] and e.buttons[1].text == "Reset filters" and not e.buttons[2], "no results shows Reset only")
e = empty("noResults", { onReset = noop, onAll = noop })
assert(e.buttons[2] and e.buttons[2].text == "Search all decor", "no results with a kind shows Search all decor")
e:Set("noResults", { onShow = noop })
assert(e.buttons[1].text == "Show them" and e.buttons[1].shown and not e.buttons[2].shown, "hidden rows: Show them alone")
e = empty("countingSort", { onSort = noop })
assert(e.title.text == "Counting…" and e.buttons[1].text == "Sort by name", "counting sort button")
assert(next(empty("counting", {}).buttons) == nil, "plain counting has no button")
e = empty("nothingMissing", { arg = 1686 })
assert(e.title.text == "Nothing missing" and e.text.text == "You've collected all 1686 decor Homestead knows about.", "nothing missing")
e = empty("nothingNow", { arg = "Horde", onMissing = noop })
assert(e.title.text == "Nothing you can get right now" and e.text.text:find("sold only to the Horde.", 1, true)
    and e.buttons[1].text == "Show what's missing", "nothing you can get")
e = empty("notRead", {})
assert(e.title.text == "Collection not read yet" and e.text.text:find("open the Housing Dashboard once", 1, true), "not read")

-- The hidden-by footer words.
local shown
local kind = W.footerKind
local frame = Widget("Frame")
frame.parent = nil
kind.build(frame)
kind.init(frame, { hidden = 12, collected = 7, faction = 5, factionName = "Horde", onShow = function() shown = true end })
assert(frame.text.text == "12 hidden by 'Hide what doesn't apply to me' (7 collected, 5 Horde only).", "footer words: " .. frame.text.text)
assert(frame.link.text.text == "Show them", "footer link words")
frame.link.scripts.OnClick(frame.link)
assert(shown, "Show them did nothing")

-- Columns: 172 | list | 252.
local cols = W.NewColumns(Widget("Frame"))
assert(cols.nav.width == 172 and cols.detail.width == 252, "column widths")

-- A search box is known to the window, so Escape can take its focus.
local changed
local box = W.NewSearchBox(Widget("Frame"), "Search decor by name", function(text) changed = text end)
assert(searchBoxes[1] == box, "the search box was not handed to the window")
box.scripts.OnTextChanged(box, true)
assert(changed ~= nil, "typing did not reach the tab")

-- A count kind without its count never shows a raw %d or %s.
for _, name in ipairs({ "nothingMissing", "nothingNow" }) do
    assert(not pcall(empty, name, {}), name .. " accepted no count")
end

-- No quality colour from the service: the name wears the body colour.
local good = C_ColorOverrides.GetColorForQuality
C_ColorOverrides.GetColorForQuality = function() return nil end
local qr, qg, qb = W.QualityRGB(3)
assert(qr == B.Style.color.body[1] and qg == B.Style.color.body[2] and qb == B.Style.color.body[3],
    "a missing quality colour did not fall back to the body colour")
C_ColorOverrides.GetColorForQuality = good

-- The colour-square marker resets desaturation left by an earlier atlas on the same texture.
local tex = Widget("Texture")
tex:SetDesaturated(true)
B.Vis.Marker.Set(tex, "check", { 1, 0, 0 })
assert(tex.desaturated == false, "the colour-square marker kept the texture desaturated")

print("hs538_widgets: ok")
