--[[
    Homestead - Native Options Frame
    Frame host and ScrollBox shell for the native Blizzard options UI.
]]

local addonName, HA = ...

local L = HA.L or {}

local OptionsFrame = {}
HA.OptionsFrame = OptionsFrame

local frame
local navButtons = {}
local activeSection = "general"
local rowControlCache = {}
local settingsBridgeRegistered = false

local DEFAULT_WIDTH = 760
local DEFAULT_HEIGHT = 560
local MIN_WIDTH = 640
local MIN_HEIGHT = 420
local NAV_WIDTH = 150
local NAV_BUTTON_HEIGHT = 24
local NAV_BUTTON_SPACING = 6
local CONTENT_INSET = 18
local SCROLL_SPACING = 8

local DEFAULT_ROW_HEIGHTS = {
    header = 36,
    description = 34,
    checkbox = 32,
    button = 32,
    slider = 46,
    dropdown = 40,
    color = 34,
    pinPreview = 34,
}

local VALID_POINTS = {
    CENTER = true,
    TOP = true,
    BOTTOM = true,
    LEFT = true,
    RIGHT = true,
    TOPLEFT = true,
    TOPRIGHT = true,
    BOTTOMLEFT = true,
    BOTTOMRIGHT = true,
}

local function GetProfile()
    local addon = HA.Addon
    return addon and addon.db and addon.db.profile
end

local function GetGeometry()
    local profile = GetProfile()
    if not profile then
        return nil
    end

    profile.optionsFrame = profile.optionsFrame or {}
    return profile.optionsFrame
end

local function SaveGeometry()
    if not frame then
        return
    end

    local geometry = GetGeometry()
    if not geometry then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    geometry.point = point or "CENTER"
    geometry.relativePoint = relativePoint or geometry.point
    geometry.x = x or 0
    geometry.y = y or 0
    geometry.width = frame:GetWidth()
    geometry.height = frame:GetHeight()
end

local function RestoreGeometry()
    if not frame then
        return
    end

    local geometry = GetGeometry()
    frame:ClearAllPoints()

    local width = geometry and tonumber(geometry.width)
    local height = geometry and tonumber(geometry.height)
    frame:SetSize(math.max(width or DEFAULT_WIDTH, MIN_WIDTH), math.max(height or DEFAULT_HEIGHT, MIN_HEIGHT))

    local point = geometry and geometry.point
    local relativePoint = geometry and (geometry.relativePoint or point)
    if point and VALID_POINTS[point] and relativePoint and VALID_POINTS[relativePoint] then
        local ok = pcall(frame.SetPoint, frame, point, UIParent, relativePoint, geometry.x or 0, geometry.y or 0)
        if not ok then
            frame:SetPoint("CENTER")
        end
    else
        frame:SetPoint("CENTER")
    end
end

local function EnableSafeEscapeClose(targetFrame)
    if not targetFrame then
        return
    end

    targetFrame:EnableKeyboard(true)
    targetFrame:SetPropagateKeyboardInput(true)
    targetFrame:HookScript("OnShow", function(self)
        self:SetPropagateKeyboardInput(true)
    end)
    targetFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
end

local function GetRowHeight(row)
    if row and row.height then
        return row.height
    end
    return (row and DEFAULT_ROW_HEIGHTS[row.type]) or DEFAULT_ROW_HEIGHTS.checkbox
end

local function IsRowVisible(row)
    if not row then
        return false
    end
    if row.hidden then
        return not row.hidden()
    end
    return true
end

local function ClearRenderedChild(rowFrame)
    local child = rowFrame.homesteadOptionsChild
    if not child then
        return
    end

    child:Hide()
    child:ClearAllPoints()
    child:SetParent(nil)
    child.homesteadOwnerRowFrame = nil
    rowFrame.homesteadOptionsChild = nil
end

local function AttachRenderedChild(rowFrame, child, height)
    if not child then
        return
    end

    if child.homesteadOwnerRowFrame and child.homesteadOwnerRowFrame ~= rowFrame then
        child.homesteadOwnerRowFrame.homesteadOptionsChild = nil
    end

    child:SetParent(rowFrame)
    child:ClearAllPoints()
    child:SetAllPoints(rowFrame)
    child:SetHeight(height)
    if child.homesteadRefresh then
        child:homesteadRefresh()
    end
    child:Show()
    rowFrame.homesteadOptionsChild = child
    child.homesteadOwnerRowFrame = rowFrame
end

local function GetCachedControl(row)
    return row and rowControlCache[row]
end

local function CacheControl(row, child)
    if row and child then
        rowControlCache[row] = child
    end
end

local function UpdateNavButtons()
    for _, button in ipairs(navButtons) do
        local isActive = button.sectionKey == activeSection
        button:SetEnabled(not isActive)
        if isActive and button.LockHighlight then
            button:LockHighlight()
        elseif button.UnlockHighlight then
            button:UnlockHighlight()
        end
    end
end

local function CreateNavButton(parent, section, index)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(NAV_WIDTH, NAV_BUTTON_HEIGHT)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * (NAV_BUTTON_HEIGHT + NAV_BUTTON_SPACING)))
    button:SetText(section.label or section.key or "")
    button.sectionKey = section.key
    button:SetScript("OnClick", function(self)
        OptionsFrame:ShowSection(self.sectionKey)
    end)
    navButtons[index] = button
end

local function AddDragHandling(targetFrame, ownerFrame)
    if not targetFrame then
        return
    end

    targetFrame:EnableMouse(true)
    targetFrame:RegisterForDrag("LeftButton")
    targetFrame:SetScript("OnDragStart", function()
        ownerFrame:StartMoving()
    end)
    targetFrame:SetScript("OnDragStop", function()
        ownerFrame:StopMovingOrSizing()
        SaveGeometry()
    end)
end

local function CreateTitleHitBox(ownerFrame)
    local titleHitBox = CreateFrame("Frame", nil, ownerFrame)
    titleHitBox:SetPoint("TOPLEFT", ownerFrame, "TOPLEFT", 10, -2)
    titleHitBox:SetPoint("TOPRIGHT", ownerFrame, "TOPRIGHT", -30, -2)
    titleHitBox:SetHeight(24)
    return titleHitBox
end

local function SetTitle(ownerFrame)
    local title = L["Homestead Options"] or "Homestead Options"
    if ownerFrame.TitleContainer and ownerFrame.TitleContainer.TitleText then
        ownerFrame.TitleContainer.TitleText:SetText(title)
        return
    end

    ownerFrame.titleText = ownerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ownerFrame.titleText:SetPoint("TOP", ownerFrame, "TOP", 0, -7)
    ownerFrame.titleText:SetText(title)
end

local function CreateShell()
    local ownerFrame = CreateFrame("Frame", "HomesteadOptionsFrame", UIParent, "DefaultPanelTemplate")
    ownerFrame.homesteadAddonName = addonName
    ownerFrame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    ownerFrame:SetPoint("CENTER")
    ownerFrame:SetFrameStrata("HIGH")
    ownerFrame:SetMovable(true)
    ownerFrame:EnableMouse(true)
    ownerFrame:SetClampedToScreen(true)
    ownerFrame:Hide()

    SetTitle(ownerFrame)

    local closeButton = CreateFrame("Button", nil, ownerFrame, "UIPanelCloseButtonDefaultAnchors")
    closeButton:SetScript("OnClick", function()
        ownerFrame:Hide()
    end)
    ownerFrame.closeButton = closeButton

    AddDragHandling(ownerFrame.TitleContainer or CreateTitleHitBox(ownerFrame), ownerFrame)

    local content = CreateFrame("Frame", nil, ownerFrame)
    content:SetPoint("TOPLEFT", ownerFrame, "TOPLEFT", CONTENT_INSET, -38)
    content:SetPoint("BOTTOMRIGHT", ownerFrame, "BOTTOMRIGHT", -CONTENT_INSET, CONTENT_INSET)
    ownerFrame.content = content

    local background = content:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", content, "TOPLEFT", -4, 4)
    background:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 4, -4)
    background:SetAtlas("house-drawing-stone-bg", false)
    background:SetAlpha(0.45)
    ownerFrame.background = background

    local nav = CreateFrame("Frame", nil, content)
    nav:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -8)
    nav:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 8)
    nav:SetWidth(NAV_WIDTH)
    ownerFrame.nav = nav

    local scrollBar = CreateFrame("EventFrame", nil, content, "MinimalScrollBar")
    scrollBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -2, -8)
    scrollBar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -2, 8)
    ownerFrame.scrollBar = scrollBar

    local scrollBox = CreateFrame("Frame", nil, content, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", nav, "TOPRIGHT", 18, 0)
    scrollBox:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMLEFT", -10, 0)
    ownerFrame.scrollBox = scrollBox

    local view = CreateScrollBoxListLinearView(0, 0, 0, 0, SCROLL_SPACING)
    view:SetElementExtentCalculator(function(_, row)
        return GetRowHeight(row)
    end)
    view:SetElementFactory(function(factory, row)
        factory("Frame", function(rowFrame)
            OptionsFrame:RenderRow(rowFrame, row)
        end)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    ownerFrame.view = view

    local model = HA.OptionsModel
    if model and model.GetSections then
        for index, section in ipairs(model:GetSections() or {}) do
            CreateNavButton(nav, section, index)
        end
    end

    ownerFrame:HookScript("OnHide", SaveGeometry)
    EnableSafeEscapeClose(ownerFrame)

    return ownerFrame
end

local function CreateSettingsPanel()
    local panel = OptionsFrame.settingsPanel
    if panel then
        return panel
    end

    panel = CreateFrame("Frame", "HomesteadSettingsPanel")
    panel.name = "Homestead"

    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    label:SetText("Homestead")
    panel.label = label

    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(200, 24)
    button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -16)
    button:SetText("Open Homestead Options")
    button:SetScript("OnClick", function()
        OptionsFrame:Open()
    end)
    panel.openButton = button

    OptionsFrame.settingsPanel = panel
    return panel
end

local function RegisterSettingsBridge()
    if settingsBridgeRegistered then
        return
    end

    local panel = CreateSettingsPanel()

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local categoryOk, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Homestead")
        if categoryOk and category then
            local addonOk = pcall(Settings.RegisterAddOnCategory, category)
            if addonOk then
                OptionsFrame.settingsCategory = category
                settingsBridgeRegistered = true
                return
            end
        end
    end

    if InterfaceOptions_AddCategory then
        local legacyOk = pcall(InterfaceOptions_AddCategory, panel)
        if legacyOk then
            settingsBridgeRegistered = true
        end
    end
end

function OptionsFrame:Initialize()
    if not frame then
        frame = CreateShell()
    end

    RegisterSettingsBridge()
    return frame
end

function OptionsFrame:Open(sectionKey)
    self:Initialize()
    RestoreGeometry()
    frame:Show()
    self:ShowSection(sectionKey or activeSection)
end

function OptionsFrame:Toggle(sectionKey)
    if self:IsShown() then
        frame:Hide()
    else
        self:Open(sectionKey)
    end
end

function OptionsFrame:IsShown()
    return frame and frame:IsShown() and true or false
end

function OptionsFrame:ShowSection(sectionKey)
    self:Initialize()

    local model = HA.OptionsModel
    if not model or not model.GetSection then
        return
    end

    local section = model:GetSection(sectionKey or activeSection)
    if not section then
        return
    end

    activeSection = section.key or activeSection
    UpdateNavButtons()

    local dataProvider = CreateDataProvider()
    for _, row in ipairs(section.rows or {}) do
        if IsRowVisible(row) then
            dataProvider:Insert(row)
        end
    end

    frame.scrollBox:SetDataProvider(dataProvider)
end

function OptionsFrame:Refresh()
    if frame then
        self:ShowSection(activeSection)
    end
end

function OptionsFrame:RenderRow(rowFrame, row)
    local controls = HA.OptionsControls
    if not controls or not row then
        ClearRenderedChild(rowFrame)
        return
    end

    local height = GetRowHeight(row)
    rowFrame:SetHeight(height)

    local child = GetCachedControl(row)
    if not child then
        if row.type == "header" then
            child = controls.CreateHeader(rowFrame, row)
        elseif row.type == "description" then
            child = controls.CreateDescription(rowFrame, row)
        elseif row.type == "checkbox" then
            child = controls.CreateCheckbox(rowFrame, row, function() OptionsFrame:Refresh() end)
        elseif row.type == "button" then
            child = controls.CreateButton(rowFrame, row)
        elseif row.type == "slider" then
            child = controls.CreateSlider(rowFrame, row, function() OptionsFrame:Refresh() end)
        elseif row.type == "dropdown" then
            child = controls.CreateDropdown(rowFrame, row, function() OptionsFrame:Refresh() end)
        elseif row.type == "color" then
            child = controls.CreateColor(rowFrame, row, function() OptionsFrame:Refresh() end)
        elseif row.type == "pinPreview" then
            child = controls.CreatePinPreview(rowFrame, row)
        end

        CacheControl(row, child)
    end

    ClearRenderedChild(rowFrame)
    AttachRenderedChild(rowFrame, child, height)
end

return OptionsFrame
