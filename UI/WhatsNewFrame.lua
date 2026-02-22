--[[
    Homestead - WhatsNewFrame
    Version-aware "What's New" popup with ICYMI section for previous version highlights.
    Reads all display data from HA.WhatsNew (WhatsNewData.lua).
]]

local _, HA = ...

local WhatsNewFrame = {}
HA.WhatsNewFrame = WhatsNewFrame

local whatsNewFrame = nil

-- Layout constants
local FRAME_WIDTH = 800
local FRAME_HEIGHT = 700
local PADDING = 25
local CONTENT_WIDTH = FRAME_WIDTH - (PADDING * 2) - 24
local FEATURE_GAP = 12
local ICON_SIZE_PRIMARY = 32
local ICON_SIZE_ICYMI = 24

-- Upvalue stdlib
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local math_max = math.max
local table_sort = table.sort
local tinsert = tinsert

-------------------------------------------------------------------------------
-- Version comparison utilities (local scope only)
-------------------------------------------------------------------------------

local function ParseVersion(versionStr)
    local parts = {}
    for segment in versionStr:gmatch("(%d+)") do
        parts[#parts + 1] = tonumber(segment)
    end
    return parts
end

local function CompareVersions(a, b)
    -- Returns true if version string a > version string b.
    -- Splits on ".", compares each segment as integer.
    -- Correctly handles "1.10.0" > "1.9.0".
    local partsA = ParseVersion(a)
    local partsB = ParseVersion(b)
    local maxLen = math_max(#partsA, #partsB)
    for i = 1, maxLen do
        local segA = partsA[i] or 0
        local segB = partsB[i] or 0
        if segA > segB then return true end
        if segA < segB then return false end
    end
    return false
end

local function GetSortedVersions()
    -- Returns array of version strings from HA.WhatsNew sorted descending.
    local versions = {}
    for version in pairs(HA.WhatsNew) do
        versions[#versions + 1] = version
    end
    table_sort(versions, function(a, b) return CompareVersions(a, b) end)
    return versions
end

local function FindPreviousVersion(currentVersion)
    -- Returns the highest version string in HA.WhatsNew less than currentVersion.
    -- Returns nil if none exists.
    local sorted = GetSortedVersions()
    for _, version in ipairs(sorted) do
        if CompareVersions(currentVersion, version) then
            return version
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Feature row builder
-------------------------------------------------------------------------------

local function CreateFeatureRow(parent, anchor, feature, iconSize, alpha, gap)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or FEATURE_GAP))
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(iconSize, iconSize)
    icon:SetPoint("TOPLEFT", 0, 0)
    icon:SetTexture(feature.icon)

    local textLeft = iconSize + 10
    local textWidth = CONTENT_WIDTH - textLeft

    local heading = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", textLeft, 0)
    heading:SetWidth(textWidth)
    heading:SetJustifyH("LEFT")
    heading:SetText("|cFFFFD100" .. feature.heading .. "|r")

    local body = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local font, size, flags = body:GetFont()
    body:SetFont(font, size + 2, flags)
    body:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -2)
    body:SetWidth(textWidth)
    body:SetJustifyH("LEFT")
    body:SetSpacing(2)
    body:SetText(feature.body)

    if alpha and alpha < 1 then
        heading:SetAlpha(alpha)
        body:SetAlpha(alpha)
        icon:SetAlpha(alpha)
    end

    local headingHeight = heading:GetStringHeight()
    local bodyHeight = body:GetStringHeight()
    local totalHeight = math_max(iconSize, headingHeight + 2 + bodyHeight)
    row:SetHeight(totalHeight)

    return row
end

-------------------------------------------------------------------------------
-- Content builder (called once per frame lifetime)
-------------------------------------------------------------------------------

local function BuildContent(frame, version)
    local currentData = HA.WhatsNew[version]
    if not currentData then
        -- Fallback: use the highest available version
        local sorted = GetSortedVersions()
        if #sorted > 0 then
            version = sorted[1]
            currentData = HA.WhatsNew[version]
            if HA.Addon then
                HA.Addon:Debug("WhatsNew: no entry for current version, falling back to " .. version)
            end
        end
    end
    if not currentData then return end

    frame.shownVersion = version
    frame.titleText:SetText("|cFF00FF00" .. currentData.title .. "|r")

    -- Hero texture: show if provided, otherwise collapse the space
    local contentTop
    if currentData.heroTexture then
        local heroHeight = currentData.heroHeight or 100
        frame.heroTexture:SetHeight(heroHeight)
        frame.heroTexture:SetTexture(currentData.heroTexture)
        frame.heroTexture:Show()
        contentTop = -68 - heroHeight - 4
    else
        frame.heroTexture:Hide()
        contentTop = -68
    end

    local content = frame.content
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", PADDING, contentTop)
    content:SetPoint("BOTTOMRIGHT", -PADDING, 56)

    -- Invisible top anchor for chain
    local topAnchor = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    topAnchor:SetPoint("TOPLEFT", 0, 0)
    topAnchor:SetText("")
    topAnchor:SetHeight(1)

    local lastRow = topAnchor

    -- Primary feature list
    for _, feature in ipairs(currentData.features) do
        lastRow = CreateFeatureRow(content, lastRow, feature, ICON_SIZE_PRIMARY, 1.0, FEATURE_GAP)
    end

    -- ICYMI section (only when a previous version entry exists)
    local prevVersion = FindPreviousVersion(version)
    if prevVersion and HA.WhatsNew[prevVersion] then
        local prevData = HA.WhatsNew[prevVersion]

        -- Horizontal divider
        local divider = content:CreateTexture(nil, "ARTWORK")
        divider:SetColorTexture(0.4, 0.4, 0.4, 0.6)
        divider:SetHeight(1)
        divider:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -20)
        divider:SetPoint("RIGHT", content, "RIGHT", 0, 0)

        -- ICYMI label
        local icymiLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        icymiLabel:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -8)
        icymiLabel:SetWidth(CONTENT_WIDTH)
        icymiLabel:SetJustifyH("LEFT")
        icymiLabel:SetTextColor(0.53, 0.53, 0.53)
        icymiLabel:SetText("In Case You Missed It  \226\128\148  v" .. prevVersion)

        lastRow = icymiLabel
        for _, feature in ipairs(prevData.features) do
            lastRow = CreateFeatureRow(content, lastRow, feature, ICON_SIZE_ICYMI, 0.9, FEATURE_GAP)
        end
    end

    -- Checkbox handler
    frame.dontShowCheck:SetChecked(true)
    frame.dontShowCheck:SetScript("OnClick", function(cb)
        if HA.Addon and HA.Addon.db then
            if cb:GetChecked() then
                HA.Addon.db.global.suppressWhatsNewUntil = version
            else
                HA.Addon.db.global.suppressWhatsNewUntil = ""
            end
        end
    end)
end

-------------------------------------------------------------------------------
-- Frame creation (lazy, one-shot)
-------------------------------------------------------------------------------

local function CreateWhatsNewFrame()
    if whatsNewFrame then return whatsNewFrame end

    local frame = CreateFrame("Frame", "HomesteadWhatsNewFrame", UIParent, "BackdropTemplate")
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

    -- Close button (top-right X)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetScript("OnClick", function() WhatsNewFrame:Hide() end)

    -- Header: icon + title
    frame.titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge2")
    frame.titleText:SetPoint("TOP", frame, "TOP", 12, -24)

    frame.headerIcon = frame:CreateTexture(nil, "OVERLAY")
    frame.headerIcon:SetSize(36, 36)
    frame.headerIcon:SetPoint("RIGHT", frame.titleText, "LEFT", -8, -1)
    frame.headerIcon:SetTexture("Interface\\AddOns\\Homestead\\Textures\\icon")
    if not frame.headerIcon:GetTexture() then
        frame.headerIcon:SetTexture("Interface\\ICONS\\INV_Misc_Furniture_Chair_03")
    end

    -- Hero texture region (hidden by default; shown and sized by BuildContent)
    frame.heroTexture = frame:CreateTexture(nil, "ARTWORK")
    frame.heroTexture:SetPoint("TOPLEFT", PADDING, -68)
    frame.heroTexture:SetPoint("TOPRIGHT", -PADDING, -68)
    frame.heroTexture:SetHeight(100)
    frame.heroTexture:Hide()

    -- Content area (position set by BuildContent based on hero visibility)
    frame.content = CreateFrame("Frame", nil, frame)

    -- OnHide: acknowledge version on any close path (button, X, ESC)
    frame:SetScript("OnHide", function()
        if HA.Addon and HA.Addon.db and frame.shownVersion then
            local globalDB = HA.Addon.db.global
            globalDB.lastSeenVersion = frame.shownVersion
            if frame.dontShowCheck and frame.dontShowCheck:GetChecked() then
                globalDB.suppressWhatsNewUntil = frame.shownVersion
            elseif globalDB.suppressWhatsNewUntil == frame.shownVersion then
                globalDB.suppressWhatsNewUntil = ""
            end
        end
        if HA.Analytics then
            HA.Analytics:IncrementCounter("WhatsNewClosed")
        end
    end)

    -- Bottom row: checkbox (left) + close button (right)
    frame.dontShowCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.dontShowCheck:SetPoint("BOTTOMLEFT", 18, 22)
    frame.dontShowCheck:SetSize(24, 24)

    frame.checkLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.checkLabel:SetPoint("LEFT", frame.dontShowCheck, "RIGHT", 2, 0)
    frame.checkLabel:SetText("Don't show again for this version")
    frame.checkLabel:SetTextColor(0.7, 0.7, 0.7)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeButton:SetSize(100, 24)
    closeButton:SetPoint("BOTTOMRIGHT", -18, 24)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function() WhatsNewFrame:Hide() end)

    frame:Hide()
    tinsert(UISpecialFrames, "HomesteadWhatsNewFrame")

    whatsNewFrame = frame
    return frame
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function WhatsNewFrame:Show(version)
    local frame = CreateWhatsNewFrame()
    version = version or HA.Constants.VERSION
    if not frame.shownVersion then
        BuildContent(frame, version)
    end
    frame:Show()
    if HA.Analytics then
        HA.Analytics:Switch("WhatsNewSeen")
    end
end

function WhatsNewFrame:Hide()
    if whatsNewFrame then
        whatsNewFrame:Hide()
    end
end

function WhatsNewFrame:Toggle()
    if whatsNewFrame and whatsNewFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function WhatsNewFrame:Initialize()
    if not HA.Addon or not HA.Addon.db then return end

    local db = HA.Addon.db.global

    -- Migrate existing users: they've seen the welcome but not the WhatsNew system.
    -- Set lastSeenVersion to "0.0.0" so the first version with a WhatsNew entry triggers.
    -- Note: WelcomeFrame still manages its own hasSeenWelcomeV* keys — don't touch them.
    if (db.lastSeenVersion or "") == "" then
        -- Check any welcome key to distinguish existing user from brand-new install
        local isExistingUser = false
        for i = 1, 10 do
            if db["hasSeenWelcomeV" .. i] then
                isExistingUser = true
                break
            end
        end
        if isExistingUser then
            db.lastSeenVersion = "0.0.0"
        end
    end

    -- Auto-popup: show if player hasn't seen this version yet.
    -- Skip for brand-new users (lastSeenVersion still empty — WelcomeFrame handles them).
    local currentVersion = HA.Constants.VERSION
    local lastSeen = db.lastSeenVersion or ""
    local suppressed = db.suppressWhatsNewUntil or ""

    if lastSeen ~= "" and lastSeen ~= currentVersion and suppressed ~= currentVersion then
        if HA.WhatsNew and HA.WhatsNew[currentVersion] then
            C_Timer.After(2, function()
                -- Re-check after delay in case state changed
                local g = HA.Addon.db and HA.Addon.db.global
                if g and g.lastSeenVersion ~= currentVersion
                    and g.suppressWhatsNewUntil ~= currentVersion then
                    WhatsNewFrame:Show(currentVersion)
                end
            end)
        end
    end
end

-------------------------------------------------------------------------------
-- Module registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("WhatsNewFrame", WhatsNewFrame)
end
