-- luacheck: globals assert loadfile print CreateFrame UIParent ScrollBoxConstants Foundry_1_0

local events = {}

local function newFrame(width, height)
    local frame = {
        width = width or 0,
        height = height or 0,
        scripts = {},
        shown = false,
    }

    function frame:SetSize(newWidth, newHeight)
        events[#events + 1] = "size"
        self.width = newWidth
        self.height = newHeight
    end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:SetPoint(point, relativeTo, relativePoint, x, y)
        if self.rejectPoint == point then error("anchor unavailable") end
        self.point = point
        self.relativeTo = relativeTo
        self.relativePoint = relativePoint
        self.x = x or 0
        self.y = y or 0
    end
    function frame:GetPoint() return self.point, self.relativeTo, self.relativePoint, self.x, self.y end
    function frame:ClearAllPoints() self.point = nil end
    function frame:SetScript(name, callback) self.scripts[name] = callback end
    function frame:HookScript(name, callback) self.hooks = self.hooks or {}; self.hooks[name] = callback end
    function frame:Show()
        events[#events + 1] = "show"
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
        if self.hooks and self.hooks.OnShow then self.hooks.OnShow(self) end
    end
    function frame:Hide()
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function frame:IsShown() return self.shown end
    function frame:CreateFontString() return newFrame() end
    function frame:SetText(text) self.text = text end
    function frame:GetText() return self.text or "" end
    function frame:GetFont() return nil, 14 end
    function frame:SetWidth(newWidth) self.width = newWidth end
    function frame:SetHeight(newHeight) self.height = newHeight end
    function frame:SetAllPoints() end
    function frame:SetCursorPosition() end
    function frame:ClearFocus() self.focused = false end
    function frame:SetAutoFocus() end
    function frame:SetMultiLine() end
    function frame:SetFontObject() end
    function frame:EnableMouse() end
    function frame:EnableKeyboard() end
    function frame:SetPropagateKeyboardInput(value) self.propagate = value end
    function frame:RegisterForDrag() end
    function frame:SetFrameStrata() end
    function frame:SetFrameLevel() end
    function frame:SetMovable() end
    function frame:SetResizable() end
    function frame:SetResizeBounds() end
    function frame:SetClampedToScreen(value) self.clamped = value end
    function frame:SetBackdrop() end
    function frame:SetBackdropColor() end
    function frame:SetBackdropBorderColor() end
    function frame:SetNormalTexture() end
    function frame:SetHighlightTexture() end
    function frame:SetPushedTexture() end
    function frame:SetScrollChild() end
    function frame:ScrollToBegin(interpolation)
        assert(interpolation == ScrollBoxConstants.NoScrollInterpolation, "expected immediate scroll reset")
        self.scrollPosition = 0
        events[#events + 1] = "scroll"
    end
    function frame:HighlightText() end
    function frame:StartMoving() end
    function frame:StartSizing() end
    function frame:StopMovingOrSizing() end
    return frame
end

UIParent = newFrame()
ScrollBoxConstants = { NoScrollInterpolation = {} }
local frames = {}
function CreateFrame(_, _, parent, template)
    local frame = newFrame()
    frames[#frames + 1] = frame
    frame.parent = parent
    frame.template = template
    if template == "DefaultPanelTemplate" then
        frame.TitleContainer = newFrame()
        frame.TitleContainer.TitleText = newFrame()
    end
    return frame
end

local listOptions, rowFrame, scrollBox
Foundry_1_0 = {
    RequireModule = function(_, name, version)
        assert(name == "List" and version == 1, "expected native Foundry List")
        return {
            New = function(_, options)
                listOptions = options
                rowFrame, scrollBox = newFrame(), newFrame()
                return {
                    GetNativeHandles = function() return { scrollBox = scrollBox } end,
                    SetData = function(_, rows)
                        events[#events + 1] = "data"
                        options.resetter(rowFrame)
                        assert(not rowFrame.editBox or not rowFrame.editBox:IsShown(), "reset hides recycled edit box")
                        options.initializer(rowFrame, rows[1])
                        assert(rowFrame.editBox:IsShown(), "initializer shows recycled edit box")
                        assert(options.extentCalculator(nil, rows[1]) >= 16, "expected positive output row height")
                    end,
                }
            end,
        }
    end,
}

local HA = {
    L = {},
    Addon = {
        db = { profile = {} },
        Debug = function() end,
        RegisterModule = function() end,
        Print = function() end,
    },
}

assert(loadfile("UI/OutputWindow.lua"))("Homestead", HA)
HA.OutputWindow:Initialize()

local outputFrame = frames[1]
assert(outputFrame, "expected OutputWindow to create its frame")
assert(outputFrame.width == 600 and outputFrame.height == 400, "expected default geometry")
assert(outputFrame.template == "DefaultPanelTemplate" and outputFrame.clamped, "expected native clamped panel")
assert(not HA.Addon.db.profile.outputWindow, "initialization must not seed geometry")

local titleBar = outputFrame.TitleContainer
local resizeGrip
for _, frame in ipairs(frames) do
    if frame.scripts.OnMouseUp then resizeGrip = frame end
end
assert(titleBar and resizeGrip, "expected draggable title bar and resize grip")

local function show(title, text)
    events = {}
    scrollBox.scrollPosition = 100
    HA.OutputWindow:Show(title or "Test", text or "text")
    assert(scrollBox.scrollPosition == 0, "expected native scroll reset on every open")
    assert(rowFrame.editBox:GetText() == (text or "text"), "expected refreshed output text")
    assert(outputFrame.TitleContainer.TitleText:GetText() == (title or "Test"), "expected native title")
    local dataIndex, scrollIndex, sizeIndex
    for index, event in ipairs(events) do
        if event == "data" then dataIndex = index end
        if event == "scroll" then scrollIndex = index end
        if event == "size" then sizeIndex = index end
    end
    assert(dataIndex and scrollIndex and sizeIndex and dataIndex < scrollIndex and scrollIndex < sizeIndex
        and events[#events] == "show", "restore geometry after data and scroll reset, before Show")
end

show("First", "first\noutput")
assert(listOptions.elementType == "Frame", "expected native frame rows")
assert(outputFrame.width == 600 and outputFrame.height == 400 and outputFrame.point == "CENTER",
    "first open uses default geometry")

outputFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 42, -55)
titleBar.scripts.OnDragStop()
assert(HA.Addon.db.profile.outputWindow.x == 42, "drag stop saves immediately")
outputFrame:SetSize(700, 500)
resizeGrip.scripts.OnMouseUp(resizeGrip, "LeftButton")
assert(HA.Addon.db.profile.outputWindow.width == 700, "resize stop saves immediately")
outputFrame:Hide()

local geometry = HA.Addon.db.profile.outputWindow
assert(geometry, "expected OutputWindow geometry to be saved")
assert(geometry.point == "TOPLEFT" and geometry.x == 42 and geometry.y == -55,
    "expected dragged position to be saved")
assert(geometry.width == 700 and geometry.height == 500, "expected resized dimensions to be saved")

outputFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
outputFrame:SetSize(600, 400)
show()
assert(outputFrame.point == "TOPLEFT" and outputFrame.x == 42 and outputFrame.y == -55,
    "expected saved position to be restored on show")
assert(outputFrame.width == 700 and outputFrame.height == 500,
    "expected saved dimensions to be restored on show")
assert(outputFrame.relativeTo == UIParent and outputFrame.relativePoint == "TOPLEFT",
    "saved anchor must restore relative to UIParent")

outputFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -22, 33)
outputFrame:SetSize(650, 450)
HA.OutputWindow:Hide()
assert(HA.Addon.db.profile.outputWindow.width == 650 and HA.Addon.db.profile.outputWindow.x == -22,
    "hide persists latest geometry without a drag or resize stop")
assert(rowFrame.editBox:GetText() == "" and not rowFrame.editBox.focused, "hide clears text and focus")
show("Again", "replacement")
assert(outputFrame.width == 650 and outputFrame.point == "BOTTOMRIGHT", "repeat open restores latest geometry")
local firstProfile = HA.Addon.db.profile

local function setGeometry(value, width, height, centered)
    HA.Addon.db.profile = { outputWindow = value }
    show()
    assert(outputFrame.width == width and outputFrame.height == height, "unexpected restored dimensions")
    if centered then
        assert(outputFrame.point == "CENTER" and outputFrame.relativeTo == UIParent
            and outputFrame.relativePoint == "CENTER" and outputFrame.x == 0 and outputFrame.y == 0,
            "invalid or absent anchor must use centered fallback")
    end
end

setGeometry(nil, 600, 400, true)
setGeometry("bad", 600, 400, true)
setGeometry({}, 600, 400, true)
setGeometry({ width = 710 }, 710, 400, true)
setGeometry({ height = 510 }, 600, 510, true)
setGeometry({ width = "bad", height = false }, 600, 400, true)
setGeometry({ width = "720", height = "480" }, 720, 480, true)
setGeometry({ width = 1000, height = 50 }, 800, 300, true)
setGeometry({ width = 20, height = 900 }, 400, 600, true)
setGeometry({ width = 0 / 0, height = 0 / 0 }, 600, 400, true)
setGeometry({ width = math.huge, height = -math.huge }, 800, 300, true)
assert(firstProfile.outputWindow.width == 650 and firstProfile.outputWindow.point == "BOTTOMRIGHT",
    "restoring another profile must preserve the previous profile")

local anchors = { "CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
for _, point in ipairs(anchors) do
    setGeometry({ point = point, relativePoint = point, x = 42, y = -55 }, 600, 400)
    assert(outputFrame.point == point and outputFrame.relativePoint == point and outputFrame.relativeTo == UIParent
        and outputFrame.x == 42 and outputFrame.y == -55, "valid anchors must restore")
end
setGeometry({ point = "BAD", relativePoint = "TOP", x = 1, y = 2 }, 600, 400, true)
setGeometry({ point = "TOP", relativePoint = {}, x = 1, y = 2 }, 600, 400, true)
setGeometry({ point = "TOP", relativePoint = "TOP", x = "42", y = 2 }, 600, 400, true)
setGeometry({ point = "TOP", relativePoint = "TOP", x = 1, y = math.huge }, 600, 400, true)
setGeometry({ point = "TOP", relativePoint = "TOP", x = 0 / 0, y = 2 }, 600, 400, true)
outputFrame.rejectPoint = "TOPLEFT"
setGeometry({ point = "TOPLEFT", relativePoint = "TOPLEFT", x = 1, y = 2 }, 600, 400, true)
outputFrame.rejectPoint = nil

local savedAddon = HA.Addon
for _, missing in ipairs({ "profile", "db", "addon" }) do
    if missing == "profile" then HA.Addon.db.profile = nil end
    if missing == "db" then HA.Addon.db = nil end
    if missing == "addon" then HA.Addon = nil end
    show()
    HA.OutputWindow:Hide()
end
HA.Addon = savedAddon
HA.Addon.db = { profile = {} }
show()
outputFrame.scripts.OnKeyDown(outputFrame, "A")
assert(outputFrame.propagate and HA.OutputWindow:IsShown(), "ordinary keys propagate")
outputFrame.scripts.OnKeyDown(outputFrame, "ESCAPE")
assert(not outputFrame.propagate and not HA.OutputWindow:IsShown(), "Escape closes and consumes key")
assert(HA.Addon.db.profile.outputWindow, "Escape hide saves geometry")
show()
assert(outputFrame.propagate, "reopen restores keyboard propagation")
rowFrame.editBox.focused = true
rowFrame.editBox.scripts.OnEscapePressed(rowFrame.editBox)
assert(not HA.OutputWindow:IsShown() and not rowFrame.editBox.focused, "edit box Escape clears focus and closes")

print("hs288_output_window_geometry: ok")
