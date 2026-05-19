--[[
    Homestead - Native Options Controls
    Reusable Blizzard UI control helpers for the native options frame.
]]

local _, HA = ...

local Controls = {}
HA.OptionsControls = Controls

local ROW_HEIGHT = 32
local HEADER_HEIGHT = 36
local DESCRIPTION_HEIGHT = 34
local SLIDER_HEIGHT = 46
local DROPDOWN_HEIGHT = 40
local COLOR_HEIGHT = 34
local PIN_PREVIEW_HEIGHT = 34

local LEFT_WIDTH = 210
local RIGHT_WIDTH = 240
local CONTROL_GAP = 12

local function GetTooltip()
    local tooltip = _G.HomesteadOptionsTooltip
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", "HomesteadOptionsTooltip", UIParent, "GameTooltipTemplate")
    end
    return tooltip
end

local function SetRowHeight(frame, height)
    frame:SetHeight(height)
    frame:SetSize(LEFT_WIDTH + RIGHT_WIDTH + CONTROL_GAP, height)
end

local function SafeGet(row, defaultValue)
    if row.get then
        local value = row.get()
        if value ~= nil then
            return value
        end
    end
    return defaultValue
end

local function Clamp(value, minValue, maxValue)
    if minValue and value < minValue then
        return minValue
    end
    if maxValue and value > maxValue then
        return maxValue
    end
    return value
end

local function RoundToStep(value, minValue, step)
    if not step or step <= 0 then
        return value
    end

    local origin = minValue or 0
    return origin + math.floor(((value - origin) / step) + 0.5) * step
end

local function FormatValue(value)
    if math.floor(value) == value then
        return tostring(value)
    end
    return string.format("%.2f", value)
end

local function CreateLabel(parent, row)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", parent, "LEFT", 0, 0)
    label:SetWidth(LEFT_WIDTH)
    label:SetJustifyH("LEFT")
    label:SetText(row.label or "")
    return label
end

local function GetDropdownLabel(row)
    local selected = SafeGet(row, nil)
    for _, value in ipairs(row.values or {}) do
        if value.key == selected then
            return value.label
        end
    end
    return row.label or ""
end

local function SetDropdownText(dropdown, row)
    local text = GetDropdownLabel(row)
    if dropdown.SetDefaultText then
        dropdown:SetDefaultText(text)
    elseif dropdown.SetText then
        dropdown:SetText(text)
    end
end

local function AttachRefresh(refresh)
    if refresh then
        refresh()
    end
end

function Controls.AttachTooltip(frame, title, body)
    if not frame then
        return
    end

    frame.homesteadTooltipTitle = title
    frame.homesteadTooltipBody = body

    frame:EnableMouse(true)

    if frame.homesteadTooltipAttached then
        return
    end
    frame.homesteadTooltipAttached = true

    frame:HookScript("OnEnter", function(self)
        local tooltipTitle = self.homesteadTooltipTitle
        local tooltipBody = self.homesteadTooltipBody
        if not tooltipTitle and not tooltipBody then
            return
        end

        local tooltip = GetTooltip()
        tooltip:SetOwner(self, "ANCHOR_RIGHT")
        tooltip:ClearLines()
        if tooltipTitle then
            tooltip:SetText(tooltipTitle, 1, 1, 1, true)
        end
        if tooltipBody then
            tooltip:AddLine(tooltipBody, 0.85, 0.85, 0.85, true)
        end
        tooltip:Show()
    end)

    frame:HookScript("OnLeave", function()
        GetTooltip():Hide()
    end)
end

function Controls.CreateHeader(parent, row)
    local frame = CreateFrame("Frame", nil, parent)
    SetRowHeight(frame, HEADER_HEIGHT)

    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    label:SetPoint("LEFT", frame, "LEFT", 0, -2)
    label:SetText(row.label or "")

    return frame
end

function Controls.CreateDescription(parent, row)
    local frame = CreateFrame("Frame", nil, parent)
    SetRowHeight(frame, DESCRIPTION_HEIGHT)

    local text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("LEFT", frame, "LEFT", 0, 0)
    text:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetText(row.label or "")

    return frame
end

function Controls.CreateCheckbox(parent, row, refresh)
    local frame = CreateFrame("Frame", nil, parent)
    SetRowHeight(frame, ROW_HEIGHT)

    local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    checkbox:SetPoint("LEFT", frame, "LEFT", -4, 0)
    checkbox:SetChecked(SafeGet(row, false) and true or false)

    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
    label:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetText(row.label or "")

    checkbox:SetScript("OnClick", function(self)
        if row.set then
            row.set(self:GetChecked() and true or false)
        end
        AttachRefresh(refresh)
    end)

    Controls.AttachTooltip(frame, row.label, row.tooltip)
    Controls.AttachTooltip(checkbox, row.label, row.tooltip)

    return frame
end

function Controls.CreateButton(parent, row)
    local frame = CreateFrame("Frame", nil, parent)
    SetRowHeight(frame, ROW_HEIGHT)

    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetPoint("LEFT", frame, "LEFT", 0, 0)
    button:SetSize(180, 24)
    button:SetText(row.label or "")
    button:SetScript("OnClick", function()
        if row.run then
            row.run()
        end
    end)

    Controls.AttachTooltip(button, row.label, row.tooltip)

    return frame
end

function Controls.CreateSlider(parent, row, refresh)
    local frame = CreateFrame("Frame", nil, parent)
    SetRowHeight(frame, SLIDER_HEIGHT)

    CreateLabel(frame, row)

    local slider = CreateFrame("Slider", nil, frame, "UISliderTemplate")
    slider:SetPoint("LEFT", frame, "LEFT", LEFT_WIDTH + CONTROL_GAP, 0)
    slider:SetSize(RIGHT_WIDTH, 18)
    slider:SetMinMaxValues(row.min or 0, row.max or 100)
    if row.step then
        slider:SetValueStep(row.step)
        slider:SetObeyStepOnDrag(true)
    end

    local valueText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, -4)

    local function UpdateValueText(value)
        valueText:SetText(FormatValue(value))
    end

    local initialValue = Clamp(RoundToStep(tonumber(SafeGet(row, row.min or 0)) or 0, row.min, row.step), row.min, row.max)
    slider:SetValue(initialValue)
    UpdateValueText(initialValue)

    slider:SetScript("OnValueChanged", function(self, value)
        local newValue = Clamp(RoundToStep(value, row.min, row.step), row.min, row.max)
        if newValue ~= value then
            self:SetValue(newValue)
            return
        end

        UpdateValueText(newValue)

        local oldValue = tonumber(SafeGet(row, newValue))
        if oldValue ~= newValue and row.set then
            row.set(newValue)
            AttachRefresh(refresh)
        end
    end)

    Controls.AttachTooltip(frame, row.label, row.tooltip)
    Controls.AttachTooltip(slider, row.label, row.tooltip)

    return frame
end

function Controls.CreateDropdown(parent, row, refresh)
    local frame = CreateFrame("Frame", nil, parent)
    SetRowHeight(frame, DROPDOWN_HEIGHT)

    CreateLabel(frame, row)

    local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("LEFT", frame, "LEFT", LEFT_WIDTH + CONTROL_GAP, 0)
    dropdown:SetWidth(RIGHT_WIDTH)
    SetDropdownText(dropdown, row)

    if dropdown.SetupMenu then
        dropdown:SetupMenu(function(_, root)
            root:CreateTitle(row.label or "")
            for _, value in ipairs(row.values or {}) do
                root:CreateRadio(value.label, function()
                    return SafeGet(row, nil) == value.key
                end, function()
                    if row.set then
                        row.set(value.key)
                    end
                    SetDropdownText(dropdown, row)
                    AttachRefresh(refresh)
                end)
            end
        end)
    end

    Controls.AttachTooltip(frame, row.label, row.tooltip)
    Controls.AttachTooltip(dropdown, row.label, row.tooltip)

    return frame
end

function Controls.CreateColor(parent, row, refresh)
    local frame = CreateFrame("Frame", nil, parent)
    SetRowHeight(frame, COLOR_HEIGHT)

    CreateLabel(frame, row)

    local swatch = CreateFrame("Button", nil, frame)
    swatch:SetPoint("LEFT", frame, "LEFT", LEFT_WIDTH + CONTROL_GAP, 0)
    swatch:SetSize(22, 22)

    local texture = swatch:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(swatch)

    local border = swatch:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", swatch, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0, 0, 0, 1)

    local function SetSwatchColor(r, g, b)
        texture:SetColorTexture(r or 1, g or 1, b or 1, 1)
    end

    local function GetColor()
        local r, g, b = 1, 1, 1
        if row.get then
            r, g, b = row.get()
        end
        return r or 1, g or 1, b or 1
    end

    local r, g, b = GetColor()
    SetSwatchColor(r, g, b)

    swatch:SetScript("OnClick", function()
        local previousR, previousG, previousB = GetColor()
        local picker = _G.ColorPickerFrame
        if not picker then
            return
        end

        local suppressSetupCallback = true

        local function ApplyColor()
            if suppressSetupCallback then
                suppressSetupCallback = false
                return
            end

            local newR, newG, newB = picker:GetColorRGB()
            if row.set then
                row.set(newR, newG, newB)
            end
            SetSwatchColor(newR, newG, newB)
            AttachRefresh(refresh)
        end

        local function CancelColor()
            if row.set then
                row.set(previousR, previousG, previousB)
            end
            SetSwatchColor(previousR, previousG, previousB)
            AttachRefresh(refresh)
        end

        if not picker.SetupColorPickerAndShow then
            return
        end

        picker:SetupColorPickerAndShow({
            r = previousR,
            g = previousG,
            b = previousB,
            swatchFunc = ApplyColor,
            cancelFunc = CancelColor,
        })
        suppressSetupCallback = false
    end)

    Controls.AttachTooltip(frame, row.label, row.tooltip)
    Controls.AttachTooltip(swatch, row.label, row.tooltip)

    return frame
end

function Controls.CreatePinPreview(parent, row)
    local frame = CreateFrame("Frame", nil, parent)
    SetRowHeight(frame, PIN_PREVIEW_HEIGHT)

    CreateLabel(frame, row)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", frame, "LEFT", LEFT_WIDTH + CONTROL_GAP, 0)
    icon:SetSize(20, 20)
    icon:SetAtlas("housing-decor-vendor_32", false)

    local r, g, b = HA.OptionsModel:GetPinPreviewColor()
    local alpha = HA.OptionsModel:GetPinPreviewAlpha()
    if HA.OptionsModel:IsCustomPinColor() then
        icon:SetDesaturated(true)
        icon:SetVertexColor(r or 1, g or 1, b or 1, alpha or 1)
    else
        icon:SetDesaturated(false)
        icon:SetVertexColor(1, 1, 1, 1)
    end

    return frame
end

return Controls
