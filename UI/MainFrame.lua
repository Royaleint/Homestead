--[[
    Homestead - MainFrame
    Main addon window with navigation buttons for all features
]]

local addonName, HA = ...

-- Create MainFrame module
local MainFrame = {}
HA.MainFrame = MainFrame

-- Local references
local Constants = HA.Constants

-- Frame references
local mainFrame = nil
local contentFrame = nil
local currentPanel = nil

-- Panel registry
local panels = {}

-------------------------------------------------------------------------------
-- Frame Creation
-------------------------------------------------------------------------------

local function CreateMainFrame()
    if mainFrame then return mainFrame end

    -- Create main frame
    local frame = CreateFrame("Frame", "HomesteadMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(600, 450)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)

    -- Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetHeight(32)
    titleBar:SetPoint("TOPLEFT", 12, -12)
    titleBar:SetPoint("TOPRIGHT", -12, -12)
    titleBar:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Header",
        edgeFile = nil,
    })

    -- Title text (parented to titleBar so it renders on top)
    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    titleText:SetText("|cFF00FF00Homestead|r")

    -- Version text (parented to titleBar, anchored left of close button)
    local versionText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -20)
    versionText:SetText("v" .. (Constants.VERSION or "0.1.0"))
    versionText:SetTextColor(0.6, 0.6, 0.6)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetScript("OnClick", function()
        MainFrame:Hide()
    end)

    -- Navigation button container (left side)
    local navFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    navFrame:SetWidth(140)
    navFrame:SetPoint("TOPLEFT", 16, -50)
    navFrame:SetPoint("BOTTOMLEFT", 16, 16)
    navFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    navFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    navFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    frame.navFrame = navFrame

    -- Content frame (right side)
    contentFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    contentFrame:SetPoint("TOPLEFT", navFrame, "TOPRIGHT", 8, 0)
    contentFrame:SetPoint("BOTTOMRIGHT", -16, 16)
    contentFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    contentFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    contentFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    frame.contentFrame = contentFrame

    -- Create navigation buttons
    MainFrame:CreateNavButtons(navFrame)

    -- Hide by default
    frame:Hide()

    -- Make closeable with Escape
    tinsert(UISpecialFrames, "HomesteadMainFrame")

    mainFrame = frame
    return frame
end

-------------------------------------------------------------------------------
-- Navigation Buttons
-------------------------------------------------------------------------------

local navButtonData = {
    {
        name = "Dashboard",
        icon = "Interface\\ICONS\\INV_Misc_Furniture_Chair_03",
        panel = "dashboard",
        tooltip = "Overview and statistics",
    },
    {
        name = "Scan",
        icon = "Interface\\ICONS\\INV_Misc_Spyglass_03",
        panel = "scan",
        tooltip = "Scan catalog for owned items",
    },
    {
        name = "Vendors",
        icon = "Interface\\GossipFrame\\VendorGossipIcon",
        panel = "vendors",
        tooltip = "Search decor vendors",
    },
    {
        name = "Cache",
        icon = "Interface\\ICONS\\INV_Misc_Bag_07_Blue",
        panel = "cache",
        tooltip = "View ownership cache",
    },
    {
        name = "Waypoint",
        icon = "Interface\\MINIMAP\\TRACKING\\None",
        panel = "waypoint",
        tooltip = "Manage waypoints",
    },
    {
        name = "Options",
        icon = "Interface\\ICONS\\Trade_Engineering",
        panel = "options",
        tooltip = "Open settings",
    },
}

function MainFrame:CreateNavButtons(parent)
    local yOffset = -10

    for i, data in ipairs(navButtonData) do
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(120, 32)
        btn:SetPoint("TOP", 0, yOffset)

        -- Background highlight
        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)

        -- Selected indicator
        local selected = btn:CreateTexture(nil, "BACKGROUND")
        selected:SetAllPoints()
        selected:SetColorTexture(0.2, 0.4, 0.2, 0.5)
        selected:Hide()
        btn.selected = selected

        -- Icon
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", 8, 0)
        icon:SetTexture(data.icon)

        -- Text
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        text:SetText(data.name)

        -- Store data
        btn.panelName = data.panel
        btn.buttonData = data

        -- Click handler
        btn:SetScript("OnClick", function(self)
            MainFrame:ShowPanel(self.panelName)
        end)

        -- Tooltip
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.buttonData.name)
            if self.buttonData.tooltip then
                GameTooltip:AddLine(self.buttonData.tooltip, 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Store reference
        panels[data.panel] = panels[data.panel] or {}
        panels[data.panel].navButton = btn

        yOffset = yOffset - 36
    end
end

-------------------------------------------------------------------------------
-- Panel System
-------------------------------------------------------------------------------

function MainFrame:ShowPanel(panelName)
    -- Hide current panel content
    if currentPanel and panels[currentPanel] then
        if panels[currentPanel].frame then
            panels[currentPanel].frame:Hide()
        end
        if panels[currentPanel].navButton then
            panels[currentPanel].navButton.selected:Hide()
        end
    end

    -- Show new panel
    currentPanel = panelName

    if panels[panelName] then
        if panels[panelName].navButton then
            panels[panelName].navButton.selected:Show()
        end

        -- Create panel content if it doesn't exist
        if not panels[panelName].frame then
            panels[panelName].frame = self:CreatePanelContent(panelName)
        end

        if panels[panelName].frame then
            panels[panelName].frame:Show()
        end
    end
end

function MainFrame:CreatePanelContent(panelName)
    local frame = CreateFrame("Frame", nil, contentFrame)
    frame:SetAllPoints()

    if panelName == "dashboard" then
        self:CreateDashboardPanel(frame)
    elseif panelName == "scan" then
        self:CreateScanPanel(frame)
    elseif panelName == "vendors" then
        self:CreateVendorsPanel(frame)
    elseif panelName == "cache" then
        self:CreateCachePanel(frame)
    elseif panelName == "waypoint" then
        self:CreateWaypointPanel(frame)
    elseif panelName == "options" then
        self:CreateOptionsPanel(frame)
    end

    return frame
end

-------------------------------------------------------------------------------
-- Dashboard Panel
-------------------------------------------------------------------------------

function MainFrame:CreateDashboardPanel(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Dashboard")

    -- Stats section
    local statsY = -50

    local function AddStat(label, getValue)
        local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        labelText:SetPoint("TOPLEFT", 16, statsY)
        labelText:SetText(label .. ":")
        labelText:SetTextColor(0.8, 0.8, 0.8)

        local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        valueText:SetPoint("TOPLEFT", 150, statsY)

        -- Update function
        local function UpdateValue()
            local value = getValue()
            valueText:SetText(tostring(value))
        end

        parent:SetScript("OnShow", function()
            UpdateValue()
        end)
        UpdateValue()

        statsY = statsY - 24
    end

    AddStat("Cached Items", function()
        if HA.Addon and HA.Addon.db and HA.Addon.db.global.ownedDecor then
            local count = 0
            for _ in pairs(HA.Addon.db.global.ownedDecor) do
                count = count + 1
            end
            return count
        end
        return 0
    end)

    AddStat("Vendors in Database", function()
        if HA.VendorData then
            return HA.VendorData:GetVendorCount()
        end
        return 0
    end)

    AddStat("TomTom Available", function()
        return (TomTom and "Yes" or "No")
    end)

    AddStat("Debug Mode", function()
        if HA.Addon and HA.Addon.db and HA.Addon.db.profile then
            return HA.Addon.db.profile.debug and "ON" or "OFF"
        end
        return "OFF"
    end)

    -- Quick actions
    local actionsTitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    actionsTitle:SetPoint("TOPLEFT", 16, statsY - 20)
    actionsTitle:SetText("Quick Actions:")

    local actionY = statsY - 50

    -- Toggle Debug button
    local debugBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    debugBtn:SetSize(120, 24)
    debugBtn:SetPoint("TOPLEFT", 16, actionY)
    debugBtn:SetText("Toggle Debug")
    debugBtn:SetScript("OnClick", function()
        if HA.Addon then
            HA.Addon.db.profile.debug = not HA.Addon.db.profile.debug
            HA.Addon:Print("Debug mode:", HA.Addon.db.profile.debug and "ON" or "OFF")
        end
    end)
end

-------------------------------------------------------------------------------
-- Scan Panel
-------------------------------------------------------------------------------

function MainFrame:CreateScanPanel(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Catalog Scanner")

    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 16, -50)
    desc:SetWidth(380)
    desc:SetJustifyH("LEFT")
    desc:SetText("Scan the Housing Catalog to populate the ownership cache.")

    -- Scan button
    local scanBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    scanBtn:SetSize(150, 30)
    scanBtn:SetPoint("TOPLEFT", 16, -120)
    scanBtn:SetText("Scan Catalog")
    scanBtn:SetScript("OnClick", function()
        if HA.CatalogScanner then
            HA.CatalogScanner:ManualScan()
        end
    end)

    -- Debug scan button
    local debugScanBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    debugScanBtn:SetSize(150, 30)
    debugScanBtn:SetPoint("LEFT", scanBtn, "RIGHT", 10, 0)
    debugScanBtn:SetText("Debug Scan")
    debugScanBtn:SetScript("OnClick", function()
        if HA.CatalogScanner then
            HA.CatalogScanner:DebugScan()
        end
    end)

    -- Note
    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    note:SetPoint("TOPLEFT", 16, -170)
    note:SetWidth(380)
    note:SetJustifyH("LEFT")
    note:SetTextColor(1, 0.8, 0)
    note:SetText("Note: Ownership is detected automatically. The cache improves performance and serves as a backup.")
end

-------------------------------------------------------------------------------
-- Vendors Panel
-------------------------------------------------------------------------------

function MainFrame:CreateVendorsPanel(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Vendor Search & Map")

    -- Search box
    local searchBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    searchBox:SetSize(250, 24)
    searchBox:SetPoint("TOPLEFT", 16, -50)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if HA.Addon then
            HA.Addon:SearchVendors(text)
        end
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- Search button
    local searchBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    searchBtn:SetSize(80, 24)
    searchBtn:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)
    searchBtn:SetText("Search")
    searchBtn:SetScript("OnClick", function()
        local text = searchBox:GetText()
        if HA.Addon then
            HA.Addon:SearchVendors(text)
        end
    end)

    -- Vendor count
    local countText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    countText:SetPoint("TOPLEFT", 16, -90)

    -- Map pins section
    local mapTitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mapTitle:SetPoint("TOPLEFT", 16, -120)
    mapTitle:SetText("World Map Integration:")

    -- Toggle map pins button
    local mapPinsBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    mapPinsBtn:SetSize(150, 24)
    mapPinsBtn:SetPoint("TOPLEFT", 16, -145)

    local function UpdateMapPinsButton()
        local enabled = HA.VendorMapPins and HA.VendorMapPins:IsEnabled()
        if enabled then
            mapPinsBtn:SetText("Map Pins: ON")
        else
            mapPinsBtn:SetText("Map Pins: OFF")
        end
    end

    mapPinsBtn:SetScript("OnClick", function()
        if HA.VendorMapPins then
            HA.VendorMapPins:Toggle()
            UpdateMapPinsButton()
        end
    end)

    -- Open World Map button
    local openMapBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    openMapBtn:SetSize(150, 24)
    openMapBtn:SetPoint("LEFT", mapPinsBtn, "RIGHT", 10, 0)
    openMapBtn:SetText("Open World Map")
    openMapBtn:SetScript("OnClick", function()
        ToggleWorldMap()
    end)

    -- Instructions
    local instructions = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    instructions:SetPoint("TOPLEFT", 16, -190)
    instructions:SetWidth(380)
    instructions:SetJustifyH("LEFT")
    instructions:SetText("Search by vendor name or zone. Results appear in chat.\n\nWith map pins enabled:\n- Continent view: Shows vendor count badges per zone\n- Zone view: Shows vendor pin icons at locations\n- Hover over pins for item details\n- Click pins to set waypoints")

    -- Update on show
    parent:SetScript("OnShow", function()
        local count = 0
        if HA.VendorData then
            count = HA.VendorData:GetVendorCount()
        end
        countText:SetText("Vendors in database: " .. count)
        UpdateMapPinsButton()
    end)
end

-------------------------------------------------------------------------------
-- Cache Panel
-------------------------------------------------------------------------------

function MainFrame:CreateCachePanel(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Ownership Cache")

    -- Show cache info button
    local showCacheBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    showCacheBtn:SetSize(150, 30)
    showCacheBtn:SetPoint("TOPLEFT", 16, -50)
    showCacheBtn:SetText("Show Cache Info")
    showCacheBtn:SetScript("OnClick", function()
        if HA.Addon then
            HA.Addon:ShowCacheInfo()
        end
    end)

    -- Clear cache button
    local clearCacheBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    clearCacheBtn:SetSize(150, 30)
    clearCacheBtn:SetPoint("LEFT", showCacheBtn, "RIGHT", 10, 0)
    clearCacheBtn:SetText("Clear Cache")
    clearCacheBtn:SetScript("OnClick", function()
        StaticPopup_Show("HOMESTEAD_CLEAR_CACHE")
    end)

    -- Description
    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 16, -100)
    desc:SetWidth(380)
    desc:SetJustifyH("LEFT")
    desc:SetText("The ownership cache stores items that the API has confirmed as owned. This persists across reloads to work around a Blizzard bug where the API returns stale data.\n\nClearing the cache will require re-scanning to restore ownership data.")

    -- Cache stats (updated on show)
    local statsText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsText:SetPoint("TOPLEFT", 16, -200)

    parent:SetScript("OnShow", function()
        local count = 0
        if HA.Addon and HA.Addon.db and HA.Addon.db.global.ownedDecor then
            for _ in pairs(HA.Addon.db.global.ownedDecor) do
                count = count + 1
            end
        end
        statsText:SetText("Items in cache: " .. count)
    end)
end

-------------------------------------------------------------------------------
-- Waypoint Panel
-------------------------------------------------------------------------------

function MainFrame:CreateWaypointPanel(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Waypoint Management")

    -- Clear waypoint button
    local clearWpBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    clearWpBtn:SetSize(150, 30)
    clearWpBtn:SetPoint("TOPLEFT", 16, -50)
    clearWpBtn:SetText("Clear Waypoint")
    clearWpBtn:SetScript("OnClick", function()
        if HA.Addon then
            HA.Addon:ClearWaypoint()
        end
    end)

    -- Status text
    local statusText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOPLEFT", 16, -100)

    -- TomTom status
    local tomtomText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tomtomText:SetPoint("TOPLEFT", 16, -130)

    parent:SetScript("OnShow", function()
        local hasWaypoint = HA.Waypoints and HA.Waypoints:HasWaypoint()
        if hasWaypoint then
            local wp = HA.Waypoints:GetCurrent()
            local zoneName = HA.Waypoints:GetMapName(wp.mapID)
            statusText:SetText("Active waypoint: " .. (wp.title or "Unknown") .. "\nZone: " .. zoneName)
        else
            statusText:SetText("No active waypoint")
        end

        local hasTomTom = TomTom and true or false
        tomtomText:SetText("TomTom: " .. (hasTomTom and "|cFF00FF00Available|r" or "|cFFFF0000Not installed|r"))
    end)

    -- Instructions
    local instructions = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    instructions:SetPoint("TOPLEFT", 16, -180)
    instructions:SetWidth(380)
    instructions:SetJustifyH("LEFT")
    instructions:SetText("Waypoints are set automatically when navigating to vendors. Both native WoW waypoints and TomTom (if installed) are supported.")
end

-------------------------------------------------------------------------------
-- Options Panel
-------------------------------------------------------------------------------

function MainFrame:CreateOptionsPanel(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Options")

    -- Open options button
    local openOptionsBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    openOptionsBtn:SetSize(180, 30)
    openOptionsBtn:SetPoint("TOPLEFT", 16, -50)
    openOptionsBtn:SetText("Open Settings Panel")
    openOptionsBtn:SetScript("OnClick", function()
        if HA.Addon then
            HA.Addon:OpenOptions()
        end
    end)

    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 16, -100)
    desc:SetWidth(380)
    desc:SetJustifyH("LEFT")
    desc:SetText("Opens the full settings panel where you can configure overlay display, tooltip options, vendor tracer settings, and more.")
end

-------------------------------------------------------------------------------
-- Static Popups
-------------------------------------------------------------------------------

StaticPopupDialogs["HOMESTEAD_CLEAR_CACHE"] = {
    text = "Are you sure you want to clear the ownership cache?\n\nYou will need to scan the catalog again to restore ownership data.",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        if HA.Addon then
            HA.Addon:ClearOwnershipCache()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function MainFrame:Show()
    local frame = CreateMainFrame()
    frame:Show()

    -- Show dashboard by default
    if not currentPanel then
        self:ShowPanel("dashboard")
    end
end

function MainFrame:Hide()
    if mainFrame then
        mainFrame:Hide()
    end
end

function MainFrame:Toggle()
    if mainFrame and mainFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function MainFrame:IsShown()
    return mainFrame and mainFrame:IsShown()
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("MainFrame", MainFrame)
end
