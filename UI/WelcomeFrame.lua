--[[
    Homestead - WelcomeFrame
    First-time user onboarding and welcome screen
]]

local addonName, HA = ...

local WelcomeFrame = {}
HA.WelcomeFrame = WelcomeFrame

local welcomeFrame = nil

-- Layout constants
local FRAME_WIDTH = 700
local FRAME_HEIGHT = 655
local PADDING = 25
local CONTENT_WIDTH = FRAME_WIDTH - (PADDING * 2) - 24  -- account for border insets
local SECTION_GAP = 14
local LINE_GAP = 4

-- SavedVariable key (bumped to V4 so existing users see the updated welcome)
local SV_KEY = "hasSeenWelcomeV4"

-------------------------------------------------------------------------------
-- Helpers: all anchored relative to a previous element
-------------------------------------------------------------------------------

local function AddHeader(parent, anchor, text, gap)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or SECTION_GAP))
    fs:SetWidth(CONTENT_WIDTH)
    fs:SetJustifyH("LEFT")
    fs:SetText("|cFFFFD100" .. text .. "|r")
    return fs
end

local function AddParagraph(parent, anchor, text, gap)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local font, size, flags = fs:GetFont()
    fs:SetFont(font, size + 2, flags)
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or LINE_GAP))
    fs:SetWidth(CONTENT_WIDTH)
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(3)
    fs:SetText(text)
    return fs
end

local function AddBullet(parent, anchor, iconStr, text, gap)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local font, size, flags = fs:GetFont()
    fs:SetFont(font, size + 2, flags)
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or LINE_GAP))
    fs:SetWidth(CONTENT_WIDTH - 10)
    fs:SetJustifyH("LEFT")
    fs:SetText(iconStr .. "  " .. text)
    return fs
end

local function AddCommand(parent, anchor, command, description, gap)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local font, size, flags = fs:GetFont()
    fs:SetFont(font, size + 2, flags)
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or LINE_GAP))
    fs:SetWidth(CONTENT_WIDTH - 10)
    fs:SetJustifyH("LEFT")
    fs:SetText("|cFF00FF00" .. command .. "|r  -  " .. description)
    return fs
end

local function AddSmallText(parent, anchor, text, gap)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local font, size, flags = fs:GetFont()
    fs:SetFont(font, size + 2, flags)
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or LINE_GAP))
    fs:SetWidth(CONTENT_WIDTH)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function AddURLBox(parent, anchor, url, gap)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or LINE_GAP))
    box:SetSize(CONTENT_WIDTH - 10, 20)
    box:SetAutoFocus(false)
    box:SetText(url)
    box:SetCursorPosition(0)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

-------------------------------------------------------------------------------
-- Frame Creation
-------------------------------------------------------------------------------

local function CreateWelcomeFrame()
    if welcomeFrame then return welcomeFrame end

    local frame = CreateFrame("Frame", "HomesteadWelcomeFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(200)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.98)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetScript("OnClick", function() WelcomeFrame:Hide() end)

    -- =========================================================================
    -- Title block: centered icon + title, tagline below
    -- =========================================================================

    -- Title anchored near top-center; offset right to visually center the
    -- icon+title group (icon 48px + 10px gap ≈ 29px half-offset).
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge2")
    title:SetPoint("TOP", frame, "TOP", 15, -24)
    title:SetText("|cFF00FF00Homestead|r")

    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(48, 48)
    icon:SetPoint("RIGHT", title, "LEFT", -10, -2)
    icon:SetTexture("Interface\\AddOns\\Homestead\\Textures\\icon")
    if not icon:GetTexture() then
        icon:SetTexture("Interface\\ICONS\\INV_Misc_Furniture_Chair_03")
    end

    local tagline = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tagline:SetPoint("TOP", title, "BOTTOM", -15, -12)
    tagline:SetText("|cFFFFD100Every decor vendor on your map. That's it.|r")

    -- =========================================================================
    -- Content area (no scroll - everything fits at this size)
    -- =========================================================================

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", PADDING, -96)
    content:SetPoint("BOTTOMRIGHT", -PADDING, 66)

    -- Invisible top anchor
    local topAnchor = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    topAnchor:SetPoint("TOPLEFT", 0, 0)
    topAnchor:SetText("")
    topAnchor:SetHeight(1)

    -- =====================================================================
    -- SECTION 1: Quick Start
    -- =====================================================================

    local sec1Header = AddHeader(content, topAnchor, "Quick Start", 2)

    local sec1Intro = AddParagraph(content, sec1Header,
        "Lightweight vendor tracking. No complex UI - just pins and tooltips.",
        6)

    -- Bullet icons: use recognizable WoW icons that match each feature
    local worldMapIcon = "Interface\\WorldMap\\WorldMap-Icon"

    local bullet1 = AddBullet(content, sec1Intro,
        "|T" .. worldMapIcon .. ":14:14:0:0|t",
        "Open your |cFFFFD100World Map|r - vendor pins are already there",
        8)

    local bullet2 = AddBullet(content, bullet1,
        "|TInterface\\GossipFrame\\VendorGossipIcon:14:14:0:0|t",
        "|cFFFFD100Hover any pin|r to see inventory and what you own",
        6)

    local bullet3 = AddBullet(content, bullet2,
        "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t",
        "Visit vendors to |cFF00FF00auto-scan|r and help improve the database",
        6)

    local warning = AddParagraph(content, bullet3,
        "|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:14:14:0:0|t |cFFFFCC00Open the Housing Catalog once per session to enable ownership tracking.|r",
        12)

    -- =====================================================================
    -- SECTION 2: Key Commands
    -- =====================================================================

    local sec2Header = AddHeader(content, warning, "Key Commands", SECTION_GAP)

    local cmd1 = AddCommand(content, sec2Header, "/hs", "Open main window", 6)
    local cmd2 = AddCommand(content, cmd1, "/hs scan", "Scan current vendor")
    local cmd3 = AddCommand(content, cmd2, "/hs export", "Export scanned vendor data")
    local cmd4 = AddCommand(content, cmd3, "/hs help", "Show all commands")

    -- =====================================================================
    -- SECTION 3: Help Us Grow
    -- =====================================================================

    local sec3Header = AddHeader(content, cmd4, "Help Us Grow the Database!", SECTION_GAP)

    local sec3Body = AddParagraph(content, sec3Header,
        "Help expand our database! After scanning vendors, use " ..
        "|cFF00FF00/hs export|r and submit your data:",
        6)

    local formLabel = AddSmallText(content, sec3Body,
        "|cFFFFD100Submit vendor data (Google Form):|r", 8)
    local formBox = AddURLBox(content, formLabel,
        "https://forms.gle/QkYBVnGZfVWYhFudA", 2)

    local issueLabel = AddSmallText(content, formBox,
        "|cFFAAAAAAReport issues:|r", 10)
    local ghBox = AddURLBox(content, issueLabel,
        "https://github.com/Royaleint/Homestead/issues", 2)

    local cfLabel = AddSmallText(content, ghBox, "|cFFAAAAACurseForge:|r", 6)
    local cfBox = AddURLBox(content, cfLabel,
        "https://www.curseforge.com/wow/addons/homestead-wow", 2)

    -- =========================================================================
    -- Bottom bar: checkbox + button (fixed to frame bottom)
    -- =========================================================================

    local checkBtn = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    checkBtn:SetPoint("BOTTOMLEFT", 18, 28)
    checkBtn:SetSize(24, 24)
    checkBtn:SetScript("OnClick", function(self)
        if HA.Addon and HA.Addon.db then
            HA.Addon.db.global[SV_KEY] = self:GetChecked()
        end
    end)

    local checkLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    checkLabel:SetPoint("LEFT", checkBtn, "RIGHT", 2, 0)
    checkLabel:SetText("Don't show this again")
    checkLabel:SetTextColor(0.7, 0.7, 0.7)

    local startBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    startBtn:SetSize(120, 24)
    startBtn:SetPoint("BOTTOMRIGHT", -18, 28)
    startBtn:SetText("Let's Decorate!")
    startBtn:SetScript("OnClick", function() WelcomeFrame:Hide() end)

    frame:Hide()
    tinsert(UISpecialFrames, "HomesteadWelcomeFrame")

    welcomeFrame = frame
    return frame
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function WelcomeFrame:Show()
    local frame = CreateWelcomeFrame()
    frame:Show()
    if HA.Analytics then
        HA.Analytics:Switch("WelcomeScreenSeen")
    end
end

function WelcomeFrame:Hide()
    if welcomeFrame then
        welcomeFrame:Hide()
        if HA.Addon and HA.Addon.db then
            HA.Addon.db.global[SV_KEY] = true
        end
        if HA.Analytics then
            HA.Analytics:IncrementCounter("WelcomeScreenClosed")
        end
    end
end

function WelcomeFrame:Toggle()
    if welcomeFrame and welcomeFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function WelcomeFrame:CheckFirstRun()
    if HA.Addon and HA.Addon.db and not HA.Addon.db.global[SV_KEY] then
        C_Timer.After(1.5, function()
            if HA.Addon.db and not HA.Addon.db.global[SV_KEY] then
                self:Show()
            end
        end)
    end
end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function WelcomeFrame:Initialize()
    if HA.Addon then
        C_Timer.After(2, function()
            self:CheckFirstRun()
        end)
    end
end

if HA.Addon then
    HA.Addon:RegisterModule("WelcomeFrame", WelcomeFrame)
end
