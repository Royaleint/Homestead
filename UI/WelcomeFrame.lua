--[[
    Homestead - WelcomeFrame
    First-time user onboarding and welcome screen
]]

local _, HA = ...

local WelcomeFrame = {}
HA.WelcomeFrame = WelcomeFrame

local welcomeFrame = nil

-- Layout constants
local FRAME_WIDTH = 700
local FRAME_HEIGHT = 810
local PADDING = 25
local CONTENT_WIDTH = FRAME_WIDTH - (PADDING * 2) - 24  -- account for border insets
local SECTION_GAP = 14
local LINE_GAP = 4
local FEATURE_ICON_SIZE = 28
local FEATURE_GAP = 14

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

local function AddFeatureRow(parent, anchor, iconPath, heading, body, gap)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or FEATURE_GAP))
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(FEATURE_ICON_SIZE, FEATURE_ICON_SIZE)
    icon:SetPoint("TOPLEFT", 0, 0)
    icon:SetTexture(iconPath)

    local textLeft = FEATURE_ICON_SIZE + 10
    local textWidth = CONTENT_WIDTH - textLeft

    local headingFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headingFS:SetPoint("TOPLEFT", textLeft, 0)
    headingFS:SetWidth(textWidth)
    headingFS:SetJustifyH("LEFT")
    headingFS:SetText("|cFFFFD100" .. heading .. "|r")

    local bodyFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local font, size, flags = bodyFS:GetFont()
    bodyFS:SetFont(font, size + 1, flags)
    bodyFS:SetPoint("TOPLEFT", headingFS, "BOTTOMLEFT", 0, -3)
    bodyFS:SetWidth(textWidth)
    bodyFS:SetJustifyH("LEFT")
    bodyFS:SetSpacing(2)
    bodyFS:SetText(body)

    local headingHeight = headingFS:GetStringHeight()
    local bodyHeight = bodyFS:GetStringHeight()
    local totalHeight = math.max(FEATURE_ICON_SIZE, headingHeight + 3 + bodyHeight)
    row:SetHeight(totalHeight)

    return row
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

local function AddSmallText(parent, anchor, text, gap, extraSize)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local font, size, flags = fs:GetFont()
    fs:SetFont(font, size + 2 + (extraSize or 0), flags)
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
    tagline:SetText("|cFFFFD100Every decor vendor on your map \226\128\148 see what you own before you buy.|r")

    -- =========================================================================
    -- Content area
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
    -- SECTION 1: What Homestead Does
    -- =====================================================================

    local sec1Header = AddHeader(content, topAnchor, "What Homestead Does", 2)

    local bullet1 = AddFeatureRow(content, sec1Header,
        "Interface\\Icons\\INV_Misc_Map_01",
        "Map Pins",
        "Every decor vendor pinned on your world map and minimap, with badges showing how many items you still need per zone.",
        8)

    local bullet2 = AddFeatureRow(content, bullet1,
        "Interface\\AddOns\\Homestead\\Textures\\icon",
        "Homestead Panel",
        "Open your world map and click the Homestead icon to reveal the panel showing all vendors in your current zone. Click any vendor to browse their wares, your collection status, and what you can or can't buy. Use |cFF00FF00/hs panel|r for a standalone window.",
        FEATURE_GAP)

    -- Bullet 3: Tooltips Expanded — custom layout to accommodate right-floated mock tooltip
    local TOOLTIP_W = 185
    local TOOLTIP_GAP = 10  -- gap between text column and tooltip mock
    local b3TextLeft = FEATURE_ICON_SIZE + 10
    local b3TextWidth = CONTENT_WIDTH - b3TextLeft - TOOLTIP_W - TOOLTIP_GAP

    local bullet3 = CreateFrame("Frame", nil, content)
    bullet3:SetPoint("TOPLEFT", bullet2, "BOTTOMLEFT", 0, -FEATURE_GAP)
    bullet3:SetPoint("RIGHT", content, "RIGHT", 0, 0)

    local b3Icon = bullet3:CreateTexture(nil, "ARTWORK")
    b3Icon:SetSize(FEATURE_ICON_SIZE, FEATURE_ICON_SIZE)
    b3Icon:SetPoint("TOPLEFT", 0, 0)
    b3Icon:SetTexture("Interface\\Icons\\INV_Inscription_ScrollOfWisdom_01")

    local b3Heading = bullet3:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    b3Heading:SetPoint("TOPLEFT", b3TextLeft, 0)
    b3Heading:SetWidth(b3TextWidth)
    b3Heading:SetJustifyH("LEFT")
    b3Heading:SetText("|cFFFFD100Tooltips Expanded|r")

    local b3Body = bullet3:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local b3Font, b3Size, b3Flags = b3Body:GetFont()
    b3Body:SetFont(b3Font, b3Size + 1, b3Flags)
    b3Body:SetPoint("TOPLEFT", b3Heading, "BOTTOMLEFT", 0, -3)
    b3Body:SetWidth(b3TextWidth)
    b3Body:SetJustifyH("LEFT")
    b3Body:SetSpacing(2)
    b3Body:SetText("Every item in the Housing Catalog gets enriched tooltips showing where it comes from and exactly what it costs \226\128\148 vendor, quest, achievement, profession, or drop \226\128\148 so you never have to leave the game or dig through another addon panel to look something up.")

    local b3HeadingH = b3Heading:GetStringHeight()
    local b3BodyH = b3Body:GetStringHeight()
    local b3TextTotalH = b3HeadingH + 3 + b3BodyH
    local b3RowHeight = math.max(FEATURE_ICON_SIZE, b3TextTotalH, 110)
    bullet3:SetHeight(b3RowHeight)

    -- Tooltip screenshot: right-floated, displayed as a static texture
    local tipTex = bullet3:CreateTexture(nil, "OVERLAY")
    tipTex:SetSize(TOOLTIP_W, 110)
    tipTex:SetPoint("RIGHT", bullet3, "RIGHT", 0, 0)
    tipTex:SetPoint("TOP", bullet3, "TOP", 0, 0)
    tipTex:SetTexture("Interface\\AddOns\\Homestead\\Textures\\WelcomeIcon")
    tipTex:SetTexCoord(0, 1, 0, 1)

    -- =====================================================================
    -- SECTION 2: Key Commands
    -- =====================================================================

    local sec2Header = AddHeader(content, bullet3, "Key Commands", SECTION_GAP)

    local cmd1 = AddCommand(content, sec2Header, "/hs", "Open options & settings", 6)
    local cmd2 = AddCommand(content, cmd1, "/hs exportall", "Export everything you've scanned")
    local cmd3 = AddCommand(content, cmd2, "/hs help", "Show all commands")

    -- =====================================================================
    -- SECTION 3: Contribute to the Community
    -- =====================================================================

    -- Centered header with community icons flanking the text
    local sec3Header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sec3Header:SetPoint("TOP", cmd3, "BOTTOM", 0, -(SECTION_GAP + 10))
    sec3Header:SetWidth(CONTENT_WIDTH)
    sec3Header:SetJustifyH("CENTER")
    sec3Header:SetText("|cFFFFD100Contribute to the Community|r")

    -- Icons flanking the header: anchor to the frame center with a fixed
    -- pixel offset so they sit just outside the rendered text (~220px wide,
    -- so half = ~110px). Add icon size (24) + small gap (8) = 142px from center.
    local SEC3_ICON_OFFSET = 142
    local sec3IconLeft = content:CreateTexture(nil, "ARTWORK")
    sec3IconLeft:SetSize(24, 24)
    sec3IconLeft:SetPoint("CENTER", sec3Header, "CENTER", -SEC3_ICON_OFFSET, 0)
    sec3IconLeft:SetTexture("Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend")

    local sec3IconRight = content:CreateTexture(nil, "ARTWORK")
    sec3IconRight:SetSize(24, 24)
    sec3IconRight:SetPoint("CENTER", sec3Header, "CENTER", SEC3_ICON_OFFSET, 0)
    sec3IconRight:SetTexture("Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend")

    local sec3Body = AddParagraph(content, sec3Header,
        "When you visit vendors, Homestead saves info on those that carry housing items. Use " ..
        "|cFF00FF00/hs exportall|r to export what you've collected and share it via the form below. " ..
        "Every submission helps the community.",
        14)

    local formLabel = AddSmallText(content, sec3Body,
        "|cFFFFD100Submit vendor data (Google Form):|r", 18, 1)
    local formBox = AddURLBox(content, formLabel,
        "https://forms.gle/QkYBVnGZfVWYhFudA", 2)

    local issueLabel = AddSmallText(content, formBox,
        "|cFFFF4444Report issues (GitHub):|r", 10)
    local ghBox = AddURLBox(content, issueLabel,
        "https://github.com/Royaleint/Homestead/issues", 2)

    local cfLabel = AddSmallText(content, ghBox, "|cFFFF4444CurseForge:|r", 6)
    AddURLBox(content, cfLabel, "https://www.curseforge.com/wow/addons/homestead-wow", 2)

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
            -- Set lastSeenVersion so WhatsNew doesn't trigger for this version
            HA.Addon.db.global.lastSeenVersion = HA.Constants.VERSION
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
