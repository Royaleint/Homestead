--[[-----------------------------------------------------------------------------
Homestead - PinColorPreviewWidget

Custom AceGUI-3.0 widget used as the dialogControl for the pinColorPreview
description row in the Vendor Tracer Options panel. Renders the actual
housing-decor-vendor_32 atlas with the same desaturation + vertex tint path
used by the in-game vendor pins, so the swatch exactly matches what the
player will see on the map.

Single source of truth: reads HA.PinFrameFactory:GetPinColor(),
HA.PinFrameFactory:IsCustomPinColor(), and HA.PinFrameFactory.DESAT_ALPHA.

Pattern mirrors Libs/AceGUI-3.0/widgets/AceGUIWidget-Label.lua. All frames
are unnamed; no new globals; no WoW API calls at file scope.
-------------------------------------------------------------------------------]]

local _, HA = ...

local Type, Version = "HomesteadPinColorPreview", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs
local max, pairs = math.max, pairs

-- Icon size chosen to read well at AceConfig description-row heights.
-- AceConfig's default image size is 32x32 (AceConfigDialog-3.0.lua:1429),
-- but the vendor atlas is tuned for map pins and looks chunky at that size
-- in a settings row. 20x20 matches the visual weight of surrounding
-- GameFontHighlightSmall text without dominating the row.
local ICON_SIZE = 20

-- Horizontal gap between icon and label (matches Label widget convention).
local ICON_LABEL_GAP = 4

--[[-----------------------------------------------------------------------------
Support functions
-------------------------------------------------------------------------------]]

-- Re-anchor the label next to the icon. Mirrors the "image on the left"
-- branch of AceGUIWidget-Label.lua:40-49 (the Label widget's support
-- function). Called from OnAcquire, OnWidthSet, and SetText.
local function UpdateAnchors(self)
    if self.resizing then return end
    local frame = self.frame
    local width = frame.width or frame:GetWidth() or 0
    local icon = self.icon
    local label = self.label
    local iconWidth = icon:GetWidth()

    label:ClearAllPoints()
    icon:ClearAllPoints()

    icon:SetPoint("TOPLEFT")
    if icon:GetHeight() > label:GetStringHeight() then
        label:SetPoint("LEFT", icon, "RIGHT", ICON_LABEL_GAP, 0)
    else
        label:SetPoint("TOPLEFT", icon, "TOPRIGHT", ICON_LABEL_GAP, 0)
    end
    label:SetWidth(max(width - iconWidth - ICON_LABEL_GAP, 1))
    local height = max(icon:GetHeight(), label:GetStringHeight())
    if height == 0 then height = 1 end

    self.resizing = true
    frame:SetHeight(height)
    frame.height = height
    self.resizing = nil
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
    ["OnAcquire"] = function(self)
        -- stop reflows while we set defaults
        self.resizing = true
        self:SetWidth(200)
        self.label:SetFontObject(GameFontHighlightSmall)
        self.label:SetJustifyH("LEFT")
        self.label:SetJustifyV("TOP")
        self.icon:SetSize(ICON_SIZE, ICON_SIZE)
        self:SetText(nil)
        self:RefreshPreview()
        self.resizing = nil
        UpdateAnchors(self)
    end,

    -- ["OnRelease"] = nil,

    ["OnWidthSet"] = function(self, _width)
        UpdateAnchors(self)
    end,

    -- AceConfigDialog calls control:SetText(name) on description rows
    -- (AceConfigDialog-3.0.lua:1402). Provide it as the canonical setter.
    ["SetText"] = function(self, text)
        self.label:SetText(text or "")
        UpdateAnchors(self)
    end,

    -- SetLabel is an alias for SetText. Not called by AceConfigDialog (which
    -- uses SetText directly at AceConfigDialog-3.0.lua:1402). Preserved as a
    -- public API surface for any future caller constructing this widget
    -- directly via AceGUI:Create("HomesteadPinColorPreview").
    ["SetLabel"] = function(self, text)
        self:SetText(text)
    end,

    -- AceConfigDialog calls SetImage / SetImageSize on description controls
    -- when the option entry sets `image` (guarded at AceConfigDialog-3.0.lua
    -- :1416). This widget renders its own atlas icon via RefreshPreview, so
    -- these are intentional no-ops. Keeping the methods prevents a
    -- method-not-found error if the option entry ever adds `image = "..."`.
    ["SetImage"] = function(self, path, ...) end,
    ["SetImageSize"] = function(self, width, height) end,

    -- AceConfigDialog calls control:SetFontObject after SetText
    -- (AceConfigDialog-3.0.lua:1406-1410) based on the fontSize option.
    -- Implement so that call path does not error.
    ["SetFontObject"] = function(self, font)
        self.label:SetFontObject(font or GameFontHighlightSmall)
        UpdateAnchors(self)
    end,

    -- Render the icon using the same path as the in-game vendor pins:
    -- atlas first, then (if a custom/preset color is active) desaturate
    -- and vertex-tint with PinFrameFactory.DESAT_ALPHA. Explicitly reset
    -- to natural on the default preset because AceGUI pools widgets and
    -- a prior acquire's desaturation/tint can linger otherwise.
    ["RefreshPreview"] = function(self)
        local factory = HA and HA.PinFrameFactory
        self.icon:SetAtlas("housing-decor-vendor_32", false)
        if factory and factory:IsCustomPinColor() then
            local r, g, b = factory:GetPinColor()
            self.icon:SetDesaturated(true)
            self.icon:SetVertexColor(r, g, b, factory.DESAT_ALPHA)
        else
            self.icon:SetDesaturated(false)
            self.icon:SetVertexColor(1, 1, 1, 1)
        end
    end,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()

    -- BACKGROUND layer matches the canonical Label widget pattern at
    -- Libs/AceGUI-3.0/widgets/AceGUIWidget-Label.lua:162-163.
    local label = frame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
    local icon = frame:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(ICON_SIZE, ICON_SIZE)

    local widget = {
        label = label,
        icon  = icon,
        frame = frame,
        type  = Type,
    }
    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
