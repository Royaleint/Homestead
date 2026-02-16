--[[
    Homestead - MapSidePanel
    World map side panel showing vendors and collection status for the current zone

    Attaches a collapsible panel to the left edge of WorldMapFrame.
    Shows vendor list with collection counts, click-to-waypoint support.
    Foundation for future prerequisite/progress tracking UI.

    Toggle button uses the same visual pattern as HandyNotes_TWW
    (Krowi_WorldMapButtons): 32x32 circular minimap-style icon positioned
    at the TOPRIGHT of the map canvas container.
]]

local addonName, HA = ...

local MapSidePanel = {}
HA.MapSidePanel = MapSidePanel

-- Module references (set during Initialize, after TOC load order)
local VendorData
local VendorFilter
local BC  -- BadgeCalculation

-- Constants
local PANEL_WIDTH = 260
local ROW_HEIGHT = 36
local HEADER_HEIGHT = 36
local PADDING = 8
local ICON_SIZE = 14

-- State
local panelFrame = nil
local overlayButton = nil
local scrollFrame = nil
local scrollChild = nil
local headerText = nil
local summaryText = nil
local emptyText = nil
local isInitialized = false
local vendorRows = {}
local lastRefreshMapID = nil

-------------------------------------------------------------------------------
-- Row Creation
-------------------------------------------------------------------------------

local function CreateVendorRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)

    -- Highlight on hover
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)

    -- Pin color indicator (small circle)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("TOPLEFT", PADDING, -4)
    icon:SetAtlas("poi-door")
    icon:SetDesaturated(true)
    row.icon = icon

    -- Vendor name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, 0)
    nameText:SetPoint("RIGHT", row, "RIGHT", -PADDING, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- Collection count
    local countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("TOPLEFT", icon, "BOTTOMRIGHT", 6, -2)
    countText:SetPoint("RIGHT", row, "RIGHT", -PADDING, 0)
    countText:SetJustifyH("LEFT")
    row.countText = countText

    -- Separator line
    local sep = row:CreateTexture(nil, "BACKGROUND")
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT", 4, 0)
    sep:SetPoint("BOTTOMRIGHT", -4, 0)
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.4)

    -- Store vendor reference for click handler
    row.vendor = nil

    row:SetScript("OnClick", function(self)
        if self.vendor and HA.VendorMapPins then
            HA.VendorMapPins:SetWaypointToVendor(self.vendor)
        end
    end)

    row:SetScript("OnEnter", function(self)
        if not self.vendor then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(self.vendor.name or "Unknown", 1, 1, 1)
        if self.vendor.zone then
            GameTooltip:AddLine(self.vendor.zone, 0.7, 0.7, 0.7)
        end
        if self.collected and self.total and self.total > 0 then
            local color = self.collected == self.total and {0.5, 0.5, 0.5} or {0, 1, 0}
            GameTooltip:AddLine(string.format("Collected: %d/%d", self.collected, self.total),
                color[1], color[2], color[3])
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to set waypoint", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return row
end

-------------------------------------------------------------------------------
-- Panel Frame Creation
-------------------------------------------------------------------------------

local function CreatePanel()
    if panelFrame then return end

    -- Main panel frame, anchored flush against the left edge of the map canvas.
    -- When shown, the map shifts right to make room (see ShiftMap).
    -- Styled using Blizzard's NineSlice border system to match the map frame.
    local canvas = WorldMapFrame.ScrollContainer
    local panel = CreateFrame("Frame", nil, WorldMapFrame)
    panel:SetWidth(PANEL_WIDTH)
    panel:SetPoint("TOPRIGHT", canvas, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMLEFT", 0, 0)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel(500)
    panel:EnableMouse(true)  -- Prevent clicks falling through to world map

    -- 1. BORDER: NineSlice metal border (same as Blizzard's PortraitFrameTemplate)
    panel.NineSlice = CreateFrame("Frame", nil, panel, "NineSlicePanelTemplate")
    panel.NineSlice:SetAllPoints()
    panel.NineSlice:SetFrameLevel(panel:GetFrameLevel() + 2)
    NineSliceUtil.ApplyLayoutByName(panel.NineSlice, "PortraitFrameTemplate")

    -- Override top-right corner to match the map frame's double-corner style
    if panel.NineSlice.TopRightCorner then
        panel.NineSlice.TopRightCorner:SetAtlas("UI-Frame-Metal-CornerTopRightDouble")
    end

    -- Fix top gap: tuck the top edge left anchor under the portrait corner piece
    if panel.NineSlice.TopEdge then
        panel.NineSlice.TopEdge:ClearAllPoints()
        panel.NineSlice.TopEdge:SetPoint("TOPLEFT", panel.NineSlice.TopLeftCorner, "TOPRIGHT", -2, 0)
        panel.NineSlice.TopEdge:SetPoint("TOPRIGHT", panel.NineSlice.TopRightCorner, "TOPLEFT", 2, 0)
    end

    -- 2. BACKGROUND FILL: Blizzard's quest log background atlas
    local bg = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAtlas("QuestLogBackground", false)
    bg:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

    -- 3. PORTRAIT ICON: Homestead icon inside the portrait circle
    -- PortraitFrameTemplate portrait circle is ~58x58, centered at roughly (-5, 7) from TOPLEFT
    local portrait = panel:CreateTexture(nil, "OVERLAY")
    portrait:SetSize(55, 55)
    portrait:SetPoint("TOPLEFT", panel, "TOPLEFT", -2.5, 5.5)
    portrait:SetTexture("Interface\\AddOns\\Homestead\\Textures\\icon")

    -- 4. INNER TOP BORDER: Decorative top-edge tile inside the border
    local topTile = panel:CreateTexture(nil, "ARTWORK")
    topTile:SetAtlas("_UI-Frame-InnerTopTile", false)
    topTile:SetHorizTile(true)
    topTile:SetHeight(10)
    topTile:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -24)
    topTile:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -24)

    -- Decorative streaks overlay on the inner top border
    local topStreaks = panel:CreateTexture(nil, "ARTWORK", nil, 1)
    topStreaks:SetAtlas("_UI-Frame-TopTileStreaks", false)
    topStreaks:SetHorizTile(true)
    topStreaks:SetHeight(10)
    topStreaks:SetPoint("TOPLEFT", topTile, "TOPLEFT", 0, 0)
    topStreaks:SetPoint("TOPRIGHT", topTile, "TOPRIGHT", 0, 0)

    -- Content insets (inside NineSlice border)
    local BORDER_LEFT = 10
    local BORDER_RIGHT = 10
    local BORDER_TOP = 28
    local BORDER_BOTTOM = 10

    -- Title header (centered horizontally)
    local header = CreateFrame("Frame", nil, panel)
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", BORDER_LEFT, -BORDER_TOP)
    header:SetPoint("TOPRIGHT", -BORDER_RIGHT, -BORDER_TOP)

    -- Homestead label (centered, nudged down 3px to clear inner top border)
    local titleLabel = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleLabel:SetPoint("TOP", header, "TOP", 0, -7.5)
    titleLabel:SetText("Homestead")

    -- Zone/map name (centered below title)
    headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerText:SetPoint("TOP", titleLabel, "BOTTOM", 0, -3)
    headerText:SetJustifyH("CENTER")
    headerText:SetWordWrap(false)
    headerText:SetTextColor(0.7, 0.7, 0.7)
    headerText:SetText("")

    -- Header separator line
    local headerSep = header:CreateTexture(nil, "ARTWORK")
    headerSep:SetHeight(1)
    headerSep:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    headerSep:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    headerSep:SetColorTexture(0.4, 0.4, 0.4, 0.5)

    -- Summary line (centered at bottom)
    summaryText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summaryText:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", BORDER_LEFT, BORDER_BOTTOM)
    summaryText:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -BORDER_RIGHT, BORDER_BOTTOM)
    summaryText:SetJustifyH("CENTER")
    summaryText:SetTextColor(0.6, 0.6, 0.6)

    -- Scroll frame for vendor list
    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    scrollContainer:SetPoint("BOTTOMRIGHT", -BORDER_RIGHT, BORDER_BOTTOM + 18)

    scrollFrame = CreateFrame("ScrollFrame", nil, scrollContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -22, 0)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or (PANEL_WIDTH - PADDING * 2 - 22))
    scrollChild:SetHeight(1)  -- Will be resized dynamically
    scrollFrame:SetScrollChild(scrollChild)

    -- Empty state text
    emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("CENTER", scrollContainer, "CENTER", 0, 0)
    emptyText:SetText("No vendors in this zone")
    emptyText:Hide()

    panel:Hide()
    panelFrame = panel

    -- Recalculate scrollChild width after layout settles
    C_Timer.After(0, function()
        if scrollFrame:GetWidth() > 0 then
            scrollChild:SetWidth(scrollFrame:GetWidth())
        end
    end)
end

-------------------------------------------------------------------------------
-- Overlay Button (map toggle icon)
-- Matches the HandyNotes_TWW / Krowi_WorldMapButtons visual pattern:
-- 32x32 circular minimap-style button at top-right of the map canvas.
-------------------------------------------------------------------------------

-- Count how many overlay buttons are visible (Blizzard defaults + Krowi-managed)
-- so we can position ours below the last one. Buttons stack vertically along
-- the right border of the map canvas.
local function CountVisibleOverlayButtons()
    -- If Krowi_WorldMapButtons is loaded (from HandyNotes_TWW etc.), use its
    -- managed button list — it already includes Blizzard's default overlay frames
    -- and any addon buttons it manages.
    local KrowiButtons = LibStub and LibStub("Krowi_WorldMapButtons-1.4", true)
    if KrowiButtons and KrowiButtons.Buttons then
        local count = 0
        for _, btn in ipairs(KrowiButtons.Buttons) do
            if btn:IsShown() then
                count = count + 1
            end
        end
        return count
    end

    -- No Krowi — count Blizzard's default overlay frames manually
    local count = 0
    if WorldMapFrame.overlayFrames then
        for _, f in ipairs(WorldMapFrame.overlayFrames) do
            if f:IsShown() then
                count = count + 1
            end
        end
    end
    return count
end

local function PositionOverlayButton()
    if not overlayButton then return end
    overlayButton:ClearAllPoints()
    local visibleCount = CountVisibleOverlayButtons()
    local yOffset = -(2 + visibleCount * 32)
    overlayButton:SetPoint("TOPRIGHT", WorldMapFrame:GetCanvasContainer(),
        "TOPRIGHT", -4, yOffset)
end

-- Right-click context menu: quick-access settings for map pins.
-- Uses WoW 11.0+ native MenuUtil (no library needed).
local PIN_COLOR_NAMES = {
    default   = "Default (Gold)",
    green     = "Green",
    blue      = "Blue",
    lightblue = "Light Blue",
    cyan      = "Cyan",
    purple    = "Purple",
    pink      = "Pink",
    red       = "Red",
    yellow    = "Yellow",
    white     = "White",
}

local PIN_COLOR_ORDER = {
    "default", "green", "blue", "lightblue", "cyan",
    "purple", "pink", "red", "yellow", "white",
}

local PIN_SIZE_LABELS = {
    [12] = "Tiny (12)",
    [14] = "Small (14)",
    [16] = "Medium-Small (16)",
    [18] = "Medium (18)",
    [20] = "Default (20)",
    [22] = "Medium-Large (22)",
    [24] = "Large (24)",
    [26] = "Extra Large (26)",
    [28] = "Huge (28)",
    [30] = "Giant (30)",
    [32] = "Maximum (32)",
}

local PIN_SIZE_ORDER = { 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32 }

local function ShowContextMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle("Homestead")

        -- Toggle: Show map pins
        local pinsEnabled = HA.Addon.db.profile.vendorTracer.showMapPins ~= false
        rootDescription:CreateCheckbox("Show Map Pins", function()
            return HA.Addon.db.profile.vendorTracer.showMapPins ~= false
        end, function()
            local newVal = not (HA.Addon.db.profile.vendorTracer.showMapPins ~= false)
            HA.Addon.db.profile.vendorTracer.showMapPins = newVal
            if HA.VendorMapPins then
                if newVal then
                    HA.VendorMapPins:Enable()
                else
                    HA.VendorMapPins:Disable()
                end
            end
        end)

        -- Submenu: Pin color
        local colorSubmenu = rootDescription:CreateButton("Pin Color")
        for _, preset in ipairs(PIN_COLOR_ORDER) do
            colorSubmenu:CreateRadio(PIN_COLOR_NAMES[preset], function()
                return (HA.Addon.db.profile.vendorTracer.pinColorPreset or "default") == preset
            end, function()
                HA.Addon.db.profile.vendorTracer.pinColorPreset = preset
                if HA.VendorMapPins then
                    HA.VendorMapPins:RefreshAllPinColors()
                end
                MapSidePanel:RefreshContent()
            end)
        end

        -- Submenu: Pin size
        local sizeSubmenu = rootDescription:CreateButton("World Map Pin Size")
        for _, size in ipairs(PIN_SIZE_ORDER) do
            sizeSubmenu:CreateRadio(PIN_SIZE_LABELS[size], function()
                return (HA.Addon.db.profile.vendorTracer.pinIconSize or 20) == size
            end, function()
                HA.Addon.db.profile.vendorTracer.pinIconSize = size
                if HA.VendorMapPins then
                    HA.VendorMapPins:RefreshAllPinColors()
                end
            end)
        end

        -- Open full settings
        rootDescription:CreateDivider()
        rootDescription:CreateButton("Open Settings", function()
            HideUIPanel(WorldMapFrame)
            Settings.OpenToCategory("Homestead")
        end)
    end)
end

local function CreateOverlayButton()
    if overlayButton then return end

    local button = CreateFrame("Button", nil, WorldMapFrame)
    button:SetSize(32, 32)
    button:SetFrameStrata("HIGH")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Circular minimap background (same as HandyNotes/Blizzard tracking buttons)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(25, 25)
    bg:SetPoint("TOPLEFT", 2, -4)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    -- Homestead icon (centered in the circle)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 6, -6)
    icon:SetTexture("Interface\\AddOns\\Homestead\\Textures\\icon")
    button.Icon = icon

    -- Minimap tracking border ring (same as HandyNotes)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Highlight on hover (same as Blizzard's tracking buttons)
    local hl = button:CreateTexture(nil, "HIGHLIGHT")
    hl:SetSize(25, 25)
    hl:SetPoint("TOPLEFT", 2, -4)
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    hl:SetBlendMode("ADD")

    -- Position after existing overlay buttons
    PositionOverlayButton()

    -- Reposition when map refreshes its overlay frames
    hooksecurefunc(WorldMapFrame, "RefreshOverlayFrames", PositionOverlayButton)

    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            ShowContextMenu(self)
        else
            MapSidePanel:Toggle()
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, "Homestead")
        GameTooltip_AddNormalLine(GameTooltip, "Left-click: Toggle vendor panel")
        GameTooltip_AddNormalLine(GameTooltip, "Right-click: Pin options")
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", GameTooltip_Hide)

    -- Press feedback (same as HandyNotes: icon shifts 2px down-right on press)
    button:SetScript("OnMouseDown", function(self)
        self.Icon:SetPoint("TOPLEFT", 8, -8)
    end)

    button:SetScript("OnMouseUp", function(self)
        self.Icon:SetPoint("TOPLEFT", 6, -6)
    end)

    overlayButton = button
end

-------------------------------------------------------------------------------
-- Content Refresh
-------------------------------------------------------------------------------

local function GetVendorsForCurrentMap(mapID)
    if not VendorData then return {} end

    local vendors = {}
    local seen = {}

    -- Get vendors for this map + child maps (same pattern as VendorMapPins:ShowVendorPins)
    local mapsToCheck = { [mapID] = true }
    local childMaps = C_Map.GetMapChildrenInfo(mapID)
    if childMaps then
        for _, childInfo in ipairs(childMaps) do
            mapsToCheck[childInfo.mapID] = true
        end
    end

    local showOpposite = VendorFilter.ShouldShowOppositeFaction()
    local showUnverified = VendorFilter.ShouldShowUnverifiedVendors()

    for queryMapID in pairs(mapsToCheck) do
        local mapVendors = VendorData:GetVendorsInMap(queryMapID)
        if mapVendors then
            for _, vendor in ipairs(mapVendors) do
                if vendor.npcID and not seen[vendor.npcID] then
                    seen[vendor.npcID] = true

                    if not VendorFilter.ShouldHideVendor(vendor) then
                        local isOpposite = VendorFilter.IsOppositeFaction(vendor)
                        local isUnverified = not VendorFilter.IsVendorVerified(vendor)

                        if isUnverified and not showUnverified then
                            -- skip
                        elseif isOpposite and not showOpposite then
                            -- skip
                        else
                            vendors[#vendors + 1] = {
                                vendor = vendor,
                                isOpposite = isOpposite,
                                isUnverified = isUnverified,
                            }
                        end
                    end
                end
            end
        end
    end

    -- Sort alphabetically
    table.sort(vendors, function(a, b)
        return (a.vendor.name or "") < (b.vendor.name or "")
    end)

    return vendors
end

function MapSidePanel:RefreshContent()
    if not panelFrame or not panelFrame:IsShown() then return end
    if not VendorData or not BC then return end

    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return end

    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo then return end

    -- Update header with zone name
    headerText:SetText(mapInfo.name or "")

    -- Determine map type
    local isZoneLevel = mapInfo.mapType and mapInfo.mapType >= Enum.UIMapType.Zone

    if not isZoneLevel then
        -- Continent or world view — show prompt
        for _, row in ipairs(vendorRows) do
            row:Hide()
        end
        emptyText:SetText("Select a zone to see vendors")
        emptyText:Show()
        summaryText:SetText("")
        scrollChild:SetHeight(1)
        lastRefreshMapID = mapID
        return
    end

    -- Zone level — show individual vendors
    local vendorList = GetVendorsForCurrentMap(mapID)

    -- Get pin color for icons
    local r, g, b = HA.PinFrameFactory:GetPinColor()
    local isCustomColor = HA.PinFrameFactory:IsCustomPinColor()

    -- Ensure we have enough rows
    while #vendorRows < #vendorList do
        local row = CreateVendorRow(scrollChild, #vendorRows + 1)
        vendorRows[#vendorRows + 1] = row
    end

    local totalCollected, totalItems = 0, 0

    for i, entry in ipairs(vendorList) do
        local row = vendorRows[i]
        local vendor = entry.vendor

        row.vendor = vendor

        -- Set name with color coding
        local nameColor
        if entry.isOpposite then
            nameColor = {0.5, 0.5, 0.5}
        elseif entry.isUnverified then
            nameColor = {1, 0.6, 0}
        else
            nameColor = {1, 1, 1}
        end
        row.nameText:SetText(vendor.name or "Unknown")
        row.nameText:SetTextColor(nameColor[1], nameColor[2], nameColor[3])

        -- Set icon color
        if isCustomColor or (not entry.isUnverified) then
            row.icon:SetDesaturated(true)
            row.icon:SetVertexColor(r, g, b)
        else
            -- Unverified: orange
            row.icon:SetDesaturated(true)
            row.icon:SetVertexColor(1, 0.6, 0)
        end

        -- Get collection counts
        local collected, total = BC:GetVendorCollectionCounts(vendor)
        row.collected = collected
        row.total = total

        if total > 0 then
            local countColor
            if collected == total then
                countColor = {0.5, 0.5, 0.5}  -- Completed: gray
            elseif collected > 0 then
                countColor = {1, 0.82, 0}  -- Partial: gold
            else
                countColor = {0, 1, 0}  -- None collected: green (all available)
            end
            row.countText:SetText(string.format("%d/%d collected", collected, total))
            row.countText:SetTextColor(countColor[1], countColor[2], countColor[3])
        else
            row.countText:SetText("No item data")
            row.countText:SetTextColor(0.5, 0.5, 0.5)
        end

        totalCollected = totalCollected + collected
        totalItems = totalItems + total

        -- Position row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)
        row:Show()
    end

    -- Hide excess rows
    for i = #vendorList + 1, #vendorRows do
        vendorRows[i]:Hide()
    end

    -- Update scroll height
    scrollChild:SetHeight(math.max(1, #vendorList * ROW_HEIGHT))

    -- Empty state
    if #vendorList == 0 then
        emptyText:SetText("No vendors in this zone")
        emptyText:Show()
    else
        emptyText:Hide()
    end

    -- Summary line
    if totalItems > 0 then
        summaryText:SetText(string.format("%d vendors | %d/%d items",
            #vendorList, totalCollected, totalItems))
    elseif #vendorList > 0 then
        summaryText:SetText(string.format("%d vendors", #vendorList))
    else
        summaryText:SetText("")
    end

    lastRefreshMapID = mapID
end

-------------------------------------------------------------------------------
-- Map Position Shifting
-- Nudges the WorldMapFrame right when the panel is open, restores when closed.
-- Safe because the world map cannot be opened during combat.
-------------------------------------------------------------------------------

local mapShifted = false
local savedMapPoint = nil  -- {point, relativeTo, relativePoint, xOfs, yOfs}

local function ShiftMapRight()
    if mapShifted then return end
    -- Save current position
    local point, relativeTo, relativePoint, xOfs, yOfs = WorldMapFrame:GetPoint(1)
    if point then
        savedMapPoint = { point, relativeTo, relativePoint, xOfs or 0, yOfs or 0 }
        WorldMapFrame:SetPoint(point, relativeTo, relativePoint,
            (xOfs or 0) + PANEL_WIDTH, yOfs or 0)
        mapShifted = true
    end
end

local function RestoreMapPosition()
    if not mapShifted or not savedMapPoint then return end
    WorldMapFrame:SetPoint(savedMapPoint[1], savedMapPoint[2], savedMapPoint[3],
        savedMapPoint[4], savedMapPoint[5])
    mapShifted = false
end

-------------------------------------------------------------------------------
-- Toggle / Visibility
-------------------------------------------------------------------------------

local function ShowPanel()
    if not panelFrame then return end
    panelFrame:Show()
    ShiftMapRight()
end

local function HidePanel()
    if not panelFrame then return end
    panelFrame:Hide()
    RestoreMapPosition()
end

function MapSidePanel:Toggle()
    if not panelFrame then return end

    if panelFrame:IsShown() then
        HidePanel()
        if HA.Addon and HA.Addon.db then
            HA.Addon.db.profile.vendorTracer.showMapSidePanel = false
        end
    else
        ShowPanel()
        if HA.Addon and HA.Addon.db then
            HA.Addon.db.profile.vendorTracer.showMapSidePanel = true
        end
        self:RefreshContent()
    end
end

function MapSidePanel:Show()
    if panelFrame then
        ShowPanel()
        self:RefreshContent()
    end
end

function MapSidePanel:Hide()
    if panelFrame then
        HidePanel()
    end
end

function MapSidePanel:IsShown()
    return panelFrame and panelFrame:IsShown()
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function MapSidePanel:Initialize()
    if isInitialized then return end

    -- Set module references
    VendorData = HA.VendorData
    VendorFilter = HA.VendorFilter
    BC = HA.BadgeCalculation

    if not VendorData or not VendorFilter or not BC then
        if HA.Addon then
            HA.Addon:Debug("MapSidePanel: Missing dependencies, skipping init")
        end
        return
    end

    -- Create UI elements
    CreatePanel()
    CreateOverlayButton()

    -- Hook WorldMapFrame to refresh on map change
    hooksecurefunc(WorldMapFrame, "SetMapID", function(_, mapID)
        if mapID == lastRefreshMapID then return end
        C_Timer.After(0, function()
            MapSidePanel:RefreshContent()
        end)
    end)

    WorldMapFrame:HookScript("OnShow", function()
        -- Restore panel visibility + shift map when map opens
        if HA.Addon and HA.Addon.db
                and HA.Addon.db.profile.vendorTracer.showMapSidePanel then
            -- Delay to let the map settle its position first
            C_Timer.After(0, function()
                ShowPanel()
                MapSidePanel:RefreshContent()
            end)
        end
    end)

    WorldMapFrame:HookScript("OnHide", function()
        -- Restore map position when map closes (so it opens correctly next time)
        RestoreMapPosition()
        mapShifted = false
    end)

    -- Listen for data changes
    if HA.Events then
        HA.Events:RegisterCallback("OWNERSHIP_UPDATED", function()
            MapSidePanel:RefreshContent()
        end)

        HA.Events:RegisterCallback("VENDOR_SCANNED", function()
            C_Timer.After(0.1, function()
                MapSidePanel:RefreshContent()
            end)
        end)
    end

    isInitialized = true

    if HA.Addon then
        HA.Addon:Debug("MapSidePanel initialized")
    end
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("MapSidePanel", MapSidePanel)
end
