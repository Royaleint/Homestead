-- luacheck: globals assert loadfile print CreateFrame UIParent C_Texture PixelUtil CreateColor C_ColorOverrides wipe
-- luacheck: globals CreateScrollBoxListLinearView CreateScrollBoxListGridView ScrollUtil CreateAnchor CreateDataProvider
-- luacheck: globals TextSizeManager
-- luacheck: globals NineSliceUtil C_Timer InCombatLockdown EventRegistry NORMAL_FONT_COLOR table
-- Run from the repo root:  lua tests/hs538_colour.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Quality colours: read from C_ColorOverrides at every draw and never
-- kept, so an override shows at once. The browser listens for COLOR_OVERRIDE_UPDATED
-- and COLOR_OVERRIDES_RESET only while its window is shown, and the open tab is
-- told to repaint. Real Widgets, Browser, Adapter and CanGet; the window is a
-- recording stand-in.
-------------------------------------------------------------------------------

local function noop() end
local Widget
local methods = {}
function methods.CreateFontString() return Widget("FontString") end
function methods.CreateTexture() return Widget("Texture") end
function methods.SetText(self, text) self.text = text end
function methods.SetWidth(self, w) self.width = w end
function methods.GetWidth(self) return self.width or 0 end
function methods.SetShown(self, on) self.shown = on end
function methods.Show(self) self.shown = true end
function methods.Hide(self) self.shown = false end
function methods.IsShown(self) return self.shown end
function methods.IsVisible(self) return self.shown end
function methods.SetScript(self, name, fn) self.scripts[name] = fn end
function methods.SetTextColor(self, r, g, b) self.color = { r, g, b } end
function methods.GetUnboundedStringWidth() return 0 end
function methods.GetStringHeight() return 12 end
function methods.RegisterEvent(self, name) self.events[name] = true end
function methods.UnregisterAllEvents(self) for k in pairs(self.events) do self.events[k] = nil end end
function methods.GetFrameLevel() return 1 end
function methods.SetOwner(self, owner) self.owner = owner end
function methods.GetOwner(self) return self.owner end
function Widget(kind)
    return setmetatable({ kind = kind, shown = false, text = "", scripts = {}, events = {} }, {
        __index = function(_, k)
            if type(k) == "string" and k:find("^%u") then return methods[k] or noop end
        end,
    })
end

UIParent = Widget("UIParent")
local created = {}
CreateFrame = function(kind)
    local w = Widget(kind)
    w.shown = true
    created[#created + 1] = w
    return w
end
C_Texture = { GetAtlasInfo = function() return nil end }
PixelUtil = { SetHeight = noop, SetWidth = noop }
NineSliceUtil = { ApplyLayoutByName = noop }
CreateColor = function() return {} end
CreateAnchor = noop
CreateDataProvider = function(t) return t end
TextSizeManager = { GetScale = function() return 1 end }
ScrollUtil = { InitScrollBoxListWithScrollBar = noop, AddManagedScrollBarVisibilityBehavior = noop }
CreateScrollBoxListLinearView = function() return Widget("View") end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
C_Timer = { After = noop, NewTimer = function() return { Cancel = noop } end }
InCombatLockdown = function() return false end
local registry = {}
EventRegistry = {
    RegisterCallback = function(_, event, fn, owner) registry[owner] = { event = event, fn = fn } end,
    UnregisterCallback = function(_, _, owner) registry[owner] = nil end,
}

-- The colour service: each call answers the next colour, and counts.
local calls, answer = 0, { r = 1, g = 0, b = 0 }
C_ColorOverrides = { GetColorForQuality = function() calls = calls + 1 return answer end }

local HA = {
    Constants = { TEXTURE_ROOT = "Textures/" },
    Addon = { _enabled = true, db = { profile = { browser = { hideNA = false, tipSeen = false } } } },
    Events = { RegisterCallback = noop, UnregisterCallback = noop },
    PerformanceTrace = { Measure = function(_, _, _, fn, ...) return fn(...) end },
}
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)
for _, file in ipairs({ "Style", "Visuals", "Widgets" }) do
    assert(loadfile(root .. "/UI/Browser/" .. file .. ".lua"))("Homestead", HA)
end
local B = HA.DecorBrowser
local W = B.Widgets

-- A recording stand-in for the window: Build keeps the hooks, the fade just shows or hides.
local hooks
local Win = { TABS = { { key = "summary", word = "S" }, { key = "catalog", word = "C" }, { key = "sources", word = "O" } } }
B.Window = Win
Win.host = Widget("Frame")
Win.hideNA = Widget("CheckButton")
function Win.Build(h)
    hooks = h
    Win.frame = Widget("Frame")
    return Win.frame
end
function Win.PlayOpen() Win.frame.shown = true hooks.OnShow() end
function Win.PlayClose() Win.frame.shown = false hooks.OnHide() end
Win.CheckTextScale, Win.Fit, Win.AssertPropagation, Win.StopGlow = noop, noop, noop, noop
Win.SetSelectedTab, Win.SetLocation = noop, noop
Win.SetCrumb, Win.SelectNav, Win.SetBack, Win.SetSearch, Win.SetPlaceholder, Win.UpdateCount = noop, noop, noop, noop, noop, noop
for _, file in ipairs({ "Adapter", "Facts", "CanGet", "Browser", "Item" }) do
    assert(loadfile(root .. "/UI/Browser/" .. file .. ".lua"))("Homestead", HA)
end
B.Data.IsReady = function() return true end
B.Facts.Here = noop

-- Draw time: every draw asks the colour service, and the name wears the answer.
local row = W.BuildRow(CreateFrame("Button", nil, Widget("Frame")))
row:Set({ name = "Oak Bench", quality = 3, state = "notOwned" })
assert(calls == 1, "a draw must read the quality colour once, read " .. calls)
answer = { r = 0, g = 1, b = 0 }
row:Set({ name = "Oak Bench", quality = 3, state = "notOwned" })
assert(calls == 2, "the second draw did not read the colour again (cached?)")
row:Redraw()
assert(calls == 3, "Redraw must read the colour again")

-- A real list repaints its pooled rows. The view stand-in keeps the factory and resetter the list installs and
-- builds frames the way the pool does: one frame per frameType, reused after a reset.
local view
CreateScrollBoxListLinearView = function()
    view = Widget("View")
    function view:SetElementFactory(fn) self.factory = fn end
    function view:SetElementResetter(fn) self.resetter = fn end
    function view:SetElementExtentCalculator() end
    return view
end
local list = W.NewList(Widget("Frame"), { kinds = { row = W.rowKind } })
local pool, shown = {}, {}
local function Show(data)
    view.factory(function(frameType, init)
        local frame = table.remove(pool)
        frame = frame or CreateFrame(frameType)
        init(frame, data)
        shown[#shown + 1] = frame
    end, data)
end
list.box.ForEachFrame = function(_, fn) for _, frame in ipairs(shown) do fn(frame) end end
Show({ kind = "row", name = "Pine Table", quality = 2, state = "can", itemID = 11 })
Show({ kind = "row", name = "Oak Bench", quality = 3, state = "notOwned", itemID = 12 })
assert(rawget(shown[1], "Redraw") and rawget(shown[1], "Set"), "the pooled frame is not itself the row")
calls = 0
W.RepaintRows(list)
assert(calls == 2, "a repaint must redraw each pooled row of a list, redrew " .. calls)

-- A recycled row that owns the tooltip hides it; a row that does not own it leaves it alone.
NORMAL_FONT_COLOR = { r = 1, g = 0.8, b = 0 }
B.Data.TooltipData = function() return { name = "Pine Table" } end
shown[1].scripts.OnEnter(shown[1])
local tip = B.Tooltip()
assert(tip:IsShown() and tip:GetOwner() == shown[1], "the hover did not put the tooltip on the row")
view.resetter(shown[2])
assert(tip:IsShown(), "recycling another row hid the tooltip")
view.resetter(shown[1])
assert(not tip:IsShown(), "recycling the hovered row left its tooltip up")
assert(shown[1].d == nil and shown[1].itemID == nil, "a recycled row kept its data")
calls = 0
shown[1]:Redraw()
assert(calls == 0, "a recycled row redrew old data")

-- A real grid repaints its pooled cells the same way.
CreateScrollBoxListGridView = function()
    local v = Widget("View")
    function v:SetElementInitializer(_, fn) self.init = fn end
    return v
end
local grid = W.NewGrid(Widget("Frame"), 48, 4)
local cells = { CreateFrame("Button"), CreateFrame("Button"), CreateFrame("Button") }
for i, cell in ipairs(cells) do grid.view.init(cell, { itemID = 20 + i, quality = 3, state = "can" }) end
grid.box.ForEachFrame = function(_, fn) for _, cell in ipairs(cells) do fn(cell) end end
calls = 0
W.RepaintRows(grid)
assert(calls == 3, "a repaint must redraw each pooled cell of a grid, redrew " .. calls)
cells[1]:Reset()
calls = 0
W.RepaintRows(grid)
assert(calls == 2, "a recycled cell redrew old data, redrew " .. calls)

-- The window: the colour events are heard while shown, tell the open tab to repaint, and are gone on hide.
local refreshed = {}
for _, key in ipairs({ "summary", "catalog", "sources" }) do
    B.RegisterTab(key, {
        Build = noop, Show = noop, Hide = noop, SetCombat = noop,
        Refresh = function(reason) refreshed[#refreshed + 1] = key .. ":" .. reason end,
    })
end
B:Open()
assert(next(registry), "the text-size owner was not registered while shown")
local events
for _, w in ipairs(created) do
    if w.scripts.OnEvent then events = w end
end
assert(events, "the browser made no event frame")
for _, name in ipairs({ "COLOR_OVERRIDE_UPDATED", "COLOR_OVERRIDES_RESET" }) do
    assert(events.events[name], name .. " is not registered while the window is shown")
    refreshed = {}
    events.scripts.OnEvent(events, name, 2)
    assert(refreshed[1] == "summary:paint" and #refreshed == 1, name .. " did not repaint the open tab once")
end
B:Close()
assert(next(registry) == nil, "the text-size owner outlived the hide")
for _, name in ipairs({ "COLOR_OVERRIDE_UPDATED", "COLOR_OVERRIDES_RESET" }) do
    assert(not events.events[name], name .. " is still registered after the window hid")
end
refreshed = {}
events.scripts.OnEvent(events, "COLOR_OVERRIDE_UPDATED", 2)
assert(#refreshed == 0, "a hidden window repainted on a colour event")

print("hs538_colour: ok")
