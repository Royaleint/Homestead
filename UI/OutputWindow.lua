--[[
    Homestead - OutputWindow
    Reusable popup window for displaying command output
]]

local _, HA = ...

local OutputWindow = {}
HA.OutputWindow = OutputWindow

local L = HA.L or {}

-- Frame reference
local outputFrame = nil
local scrollFrame = nil
local editBox = nil
local titleText = nil

local function EnableSafeEscapeClose(frame)
    if not frame then return end

    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
    frame:HookScript("OnShow", function(self)
        self:SetPropagateKeyboardInput(true)
    end)
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            OutputWindow:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
end

-------------------------------------------------------------------------------
-- Frame Creation
-------------------------------------------------------------------------------

local function CreateOutputWindow()
    if outputFrame then return outputFrame end

    -- Main frame
    local frame = CreateFrame("Frame", "HomesteadOutputWindow", UIParent, "DefaultPanelTemplate")
    frame:SetSize(600, 400)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(200)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(400, 300, 800, 600)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()

    -- Native panel title and title-container drag target.
    titleText = frame.TitleContainer.TitleText
    titleText:SetText(L["Output"] or "Output")
    frame.TitleContainer:EnableMouse(true)
    frame.TitleContainer:RegisterForDrag("LeftButton")
    frame.TitleContainer:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame.TitleContainer:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButtonDefaultAnchors")
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- Scroll frame container
    local scrollContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    scrollContainer:SetPoint("TOPLEFT", 16, -50)
    scrollContainer:SetPoint("BOTTOMRIGHT", -16, 50)
    scrollContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    scrollContainer:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    scrollContainer:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Scroll frame
    scrollFrame = CreateFrame("ScrollFrame", nil, scrollContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 6)

    -- Edit box (multi-line, read-only)
    editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(scrollFrame:GetWidth() - 10)
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    editBox:SetScript("OnTextChanged", function(self)
        -- Auto-adjust height based on content
        local _, fontHeight = self:GetFont()
        fontHeight = fontHeight or 14
        local text = self:GetText()
        local numLines = 1
        for _ in text:gmatch("\n") do
            numLines = numLines + 1
        end
        self:SetHeight(math.max(scrollFrame:GetHeight(), numLines * (fontHeight + 2)))
    end)

    scrollFrame:SetScrollChild(editBox)

    -- Button container
    local buttonContainer = CreateFrame("Frame", nil, frame)
    buttonContainer:SetHeight(40)
    buttonContainer:SetPoint("BOTTOMLEFT", 16, 8)
    buttonContainer:SetPoint("BOTTOMRIGHT", -16, 8)

    -- Select All button
    local copyBtn = CreateFrame("Button", nil, buttonContainer, "UIPanelButtonTemplate")
    copyBtn:SetSize(100, 25)
    copyBtn:SetPoint("LEFT", 8, 0)
    copyBtn:SetText(L["Select All"] or "Select All")
    copyBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
        HA.Addon:Print(L["All text selected. Press Ctrl+C to copy to clipboard."] or "All text selected. Press Ctrl+C to copy to clipboard.")
    end)

    local closeBottomBtn = CreateFrame("Button", nil, buttonContainer, "UIPanelButtonTemplate")
    closeBottomBtn:SetSize(100, 25)
    closeBottomBtn:SetPoint("RIGHT", -8, 0)
    closeBottomBtn:SetText(L["Close"] or "Close")
    closeBottomBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- Resize grip
    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", -6, 6)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:EnableMouse(true)
    resizeGrip:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeGrip:SetScript("OnMouseUp", function(self, button)
        frame:StopMovingOrSizing()
        -- Update editbox width on resize
        editBox:SetWidth(scrollFrame:GetWidth() - 10)
    end)

    -- ESC key handling
    frame:SetScript("OnHide", function()
        editBox:SetText("")
        editBox:ClearFocus()
    end)

    -- Close on Escape without touching UISpecialFrames.
    EnableSafeEscapeClose(frame)

    outputFrame = frame
    return frame
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function OutputWindow:Show(title, text)
    if not outputFrame then
        CreateOutputWindow()
    end

    -- Set title
    titleText:SetText(title or "Output")

    -- Set text (read-only)
    editBox:SetText(text or "")
    editBox:SetCursorPosition(0)
    editBox:ClearFocus()

    -- Reset scroll position
    scrollFrame:SetVerticalScroll(0)

    -- Show frame
    outputFrame:Show()
end

function OutputWindow:Hide()
    if outputFrame then
        outputFrame:Hide()
    end
end

function OutputWindow:IsShown()
    return outputFrame and outputFrame:IsShown()
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

function OutputWindow:Initialize()
    -- Pre-create frame to avoid lag on first show
    CreateOutputWindow()

    HA.Addon:Debug("OutputWindow initialized")
end

-- Register module
HA.Addon:RegisterModule("OutputWindow", OutputWindow)
