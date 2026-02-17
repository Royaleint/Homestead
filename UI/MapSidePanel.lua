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
local ITEM_ICON_SIZE = 28
local ITEM_ICON_PAD = 3
local ITEM_GRID_INSET = 24  -- Left indent for item grid (aligns under name text)

-- State
local panelFrame = nil
local overlayButton = nil
local scrollFrame = nil
local scrollChild = nil
local headerFrame = nil  -- Title + zone name header region
local headerText = nil
local summaryText = nil
local emptyText = nil
local topTileFrame = nil   -- Inner decorative top-edge tile
local topStreaksFrame = nil -- Decorative streaks overlay
local bgTexture = nil      -- QuestLogBackground fill (anchored below header zone)
local isInitialized = false
local vendorRows = {}
local expandedVendorID = nil  -- npcID of currently expanded vendor (nil = none)
local lastRefreshMapID = nil
local isPoppedOut = false

-- Map shift state (declared early so preview hooks can reference them)
local mapShifted = false
local savedMapPoint = nil  -- {point, relativeTo, relativePoint, xOfs, yOfs}
local ShiftMapRight  -- forward declaration; body defined in Map Position Shifting section

-- Pop-out UI elements (created in CreatePanel, shown/hidden based on state)
local popOutButton = nil   -- Arrow button to detach (docked mode)
local closeButton = nil    -- X button (detached mode)
local reattachButton = nil -- Dock-back button (detached mode)

-------------------------------------------------------------------------------
-- 3D Item Preview (uses Blizzard's HousingModelPreviewFrame)
-------------------------------------------------------------------------------

local previewHooked = false  -- true after we hook the preview frame's OnShow
local previewDragHandle = nil  -- overlay frame for dragging (ModelScene eats drag events)

local function ShowItemPreview(itemID)
    if not itemID then return end

    -- Demand-load Blizzard's housing preview addon (no-op if already loaded)
    if not HousingModelPreviewFrame then
        local loaded, reason = C_AddOns.LoadAddOn("Blizzard_HousingModelPreview")
        if not loaded then
            if HA.Addon then
                HA.Addon:Debug("Preview addon not available:", reason)
            end
            return
        end
    end

    if not HousingModelPreviewFrame then return end

    -- Hook once after the Blizzard addon is loaded
    if not previewHooked then
        local pf = HousingModelPreviewFrame

        -- Re-apply our map shift if Blizzard's preview resets WorldMapFrame
        local function ReapplyMapShift()
            if panelFrame and panelFrame:IsShown() and not isPoppedOut then
                mapShifted = false
                ShiftMapRight()
            end
        end

        -- Re-apply our customizations + map shift each time Blizzard shows it
        pf:HookScript("OnShow", function(self)
            self:SetScale(0.75)
            self:SetMovable(true)
            self:SetClampedToScreen(true)
            ReapplyMapShift()
        end)

        -- Re-apply map shift after close (deferred so Blizzard finishes first)
        pf:HookScript("OnHide", function()
            C_Timer.After(0, ReapplyMapShift)
        end)

        -- Create a drag handle overlay on the title bar area (top ~30px).
        -- The ModelScene child captures drag for model rotation, so the
        -- parent frame's OnDragStart never fires. This overlay sits above
        -- the title bar region only and forwards drag to move the window.
        previewDragHandle = CreateFrame("Frame", nil, pf)
        previewDragHandle:SetHeight(30)
        previewDragHandle:SetPoint("TOPLEFT", pf, "TOPLEFT", 0, 0)
        previewDragHandle:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -30, 0)  -- avoid close button
        previewDragHandle:SetFrameLevel(pf:GetFrameLevel() + 100)
        previewDragHandle:EnableMouse(true)
        previewDragHandle:RegisterForDrag("LeftButton")
        previewDragHandle:SetScript("OnDragStart", function()
            pf:StartMoving()
        end)
        previewDragHandle:SetScript("OnDragStop", function()
            pf:StopMovingOrSizing()
        end)

        previewHooked = true
    end

    -- Get catalog entry info directly from itemID
    local info = C_HousingCatalog.GetCatalogEntryInfoByItem(itemID, true)
    if not info then
        if HA.Addon then
            HA.Addon:Debug("No catalog info for itemID:", itemID)
        end
        return
    end

    HousingModelPreviewFrame:ShowCatalogEntryInfo(info)
end

-------------------------------------------------------------------------------
-- Item Helpers
-------------------------------------------------------------------------------

-- Check if item is owned (same pattern as BadgeCalculation/VendorMapPins)
local function IsItemOwned(itemID)
    if not itemID then return false end
    if HA.CatalogStore then
        return HA.CatalogStore:IsOwnedFresh(itemID)
    end
    return false
end

-- Gather all unique item IDs for a vendor (static DB + scanned data)
local function GetVendorItemIDs(vendor)
    if not vendor or not vendor.npcID then return {} end

    local items = {}
    local seen = {}

    -- Static items from vendor database
    if vendor.items and #vendor.items > 0 then
        for _, item in ipairs(vendor.items) do
            local itemID = HA.VendorData:GetItemID(item)
            if itemID and not seen[itemID] then
                seen[itemID] = true
                items[#items + 1] = itemID
            end
        end
    end

    -- Scanned items from VendorScanner
    if HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
        local scannedData = HA.Addon.db.global.scannedVendors[vendor.npcID]
        if not scannedData and vendor.name and HA.VendorScanner then
            local correctedID = HA.VendorScanner:GetCorrectedNPCID(vendor.name)
            if correctedID then
                scannedData = HA.Addon.db.global.scannedVendors[correctedID]
            end
        end
        local scannedItems = scannedData and scannedData.items
        if scannedItems then
            for _, item in ipairs(scannedItems) do
                if item.itemID and not seen[item.itemID] then
                    seen[item.itemID] = true
                    items[#items + 1] = item.itemID
                end
            end
        end
    end

    return items
end

-------------------------------------------------------------------------------
-- Item Grid (expandable section below each vendor row)
-------------------------------------------------------------------------------

local function CreateItemIcon(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(ITEM_ICON_SIZE, ITEM_ICON_SIZE)

    -- Item icon texture
    local tex = frame:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- Trim default icon border
    frame.texture = tex

    -- Border (behind icon so it shows as a colored rim)
    local border = frame:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.3, 0.3, 0.3, 1)
    frame.border = border

    -- Owned check overlay
    local check = frame:CreateTexture(nil, "OVERLAY")
    check:SetSize(14, 14)
    check:SetPoint("BOTTOMRIGHT", 2, -2)
    check:SetAtlas("common-icon-checkmark")
    check:Hide()
    frame.check = check

    -- Lock icon for items with unmet requirements
    local lock = frame:CreateTexture(nil, "OVERLAY")
    lock:SetSize(12, 12)
    lock:SetPoint("TOPLEFT", -2, 2)
    lock:SetAtlas("Padlock")
    lock:Hide()
    frame.lock = lock

    frame.itemID = nil
    frame.npcID = nil        -- Vendor NPC ID for requirement lookups
    frame.requirements = nil -- Cached requirement data for tooltip

    -- Tooltip on hover (includes requirement info for locked items)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        if self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemID)
            -- Append requirement info for locked items
            if self.requirements and #self.requirements > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Requirements:", 1, 0.5, 0)
                local SM = HA.SourceManager
                for _, req in ipairs(self.requirements) do
                    local met = SM and SM:IsRequirementMet(req)
                    local color = met and {0, 1, 0} or {1, 0, 0}
                    local text
                    if req.type == "reputation" then
                        text = string.format("%s - %s", req.faction or "?", req.standing or "?")
                    elseif req.type == "achievement" then
                        text = req.name or ("Achievement " .. (req.id or "?"))
                    elseif req.type == "quest" then
                        text = "Quest: " .. (req.name or "?")
                    elseif req.type == "level" then
                        text = "Level " .. (req.level or "?")
                    else
                        text = req.text or "Unknown requirement"
                    end
                    GameTooltip:AddLine("  " .. text, color[1], color[2], color[3])
                end
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to preview", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Click to open 3D preview
    frame:SetScript("OnMouseUp", function(self)
        if self.itemID then
            ShowItemPreview(self.itemID)
        end
    end)

    return frame
end

-- Check if an item has unmet requirements the player hasn't satisfied
local function GetUnmetRequirements(itemID, npcID)
    local SM = HA.SourceManager
    if not SM then return nil end
    local reqs = SM:GetRequirements(itemID, npcID)
    if not reqs or #reqs == 0 then return nil end

    local unmet = false
    for _, req in ipairs(reqs) do
        local met = SM:IsRequirementMet(req)
        -- Treat both false (unmet) and nil (can't determine) as locked.
        -- If a requirement exists but we can't confirm it's met, show locked.
        if met ~= true then
            unmet = true
            break
        end
    end
    return unmet and reqs or nil, reqs
end

-- Populate the item grid for a vendor row. Returns total height of the grid.
local function PopulateItemGrid(row, vendor)
    local itemIDs = GetVendorItemIDs(vendor)
    if #itemIDs == 0 then return 0 end

    -- Create grid container if not yet created
    if not row.itemGrid then
        row.itemGrid = CreateFrame("Frame", nil, row)
        row.itemGrid:SetPoint("TOPLEFT", row, "TOPLEFT", ITEM_GRID_INSET, -ROW_HEIGHT)
        row.itemGrid:SetPoint("RIGHT", row, "RIGHT", -PADDING, 0)
        row.itemIcons = {}
    end

    local grid = row.itemGrid
    local icons = row.itemIcons

    -- Calculate how many icons fit per row using actual available width
    -- scrollChild width = PANEL_WIDTH - 20 (borders) - 22 (scrollbar) = 218
    local scrollWidth = PANEL_WIDTH - 20 - 22
    local gridWidth = scrollWidth - ITEM_GRID_INSET - PADDING
    local iconsPerRow = math.floor((gridWidth + ITEM_ICON_PAD) / (ITEM_ICON_SIZE + ITEM_ICON_PAD))
    if iconsPerRow < 1 then iconsPerRow = 1 end

    local npcID = vendor.npcID

    -- Ensure enough icon frames
    while #icons < #itemIDs do
        icons[#icons + 1] = CreateItemIcon(grid)
    end

    -- Position and populate icons
    for i, itemID in ipairs(itemIDs) do
        local icon = icons[i]
        icon.itemID = itemID
        icon.npcID = npcID

        -- Position in grid
        local col = (i - 1) % iconsPerRow
        local gridRow = math.floor((i - 1) / iconsPerRow)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", grid, "TOPLEFT",
            col * (ITEM_ICON_SIZE + ITEM_ICON_PAD),
            -(gridRow * (ITEM_ICON_SIZE + ITEM_ICON_PAD)))

        -- Set icon texture (async via C_Item)
        local itemIcon = C_Item.GetItemIconByID(itemID)
        if itemIcon then
            icon.texture:SetTexture(itemIcon)
        else
            icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        -- Check ownership and requirements
        local owned = IsItemOwned(itemID)
        local unmetReqs, allReqs = GetUnmetRequirements(itemID, npcID)
        icon.requirements = unmetReqs and allReqs or nil

        icon.texture:SetDesaturated(false)
        icon.texture:SetVertexColor(1, 1, 1)
        icon.lock:Hide()
        icon.check:Hide()

        if owned then
            -- Owned: green border + checkmark
            icon.border:SetColorTexture(0.2, 0.7, 0.2, 1)
            icon.check:Show()
        elseif unmetReqs then
            -- Locked: red border + desaturated icon + lock icon
            icon.border:SetColorTexture(0.7, 0.15, 0.15, 1)
            icon.texture:SetDesaturated(true)
            icon.texture:SetVertexColor(0.6, 0.4, 0.4)
            icon.lock:Show()
        else
            -- Available to purchase: gold border
            icon.border:SetColorTexture(0.6, 0.5, 0.2, 1)
        end

        icon:Show()
    end

    -- Hide excess icons
    for i = #itemIDs + 1, #icons do
        icons[i]:Hide()
    end

    -- Calculate grid height
    local numRows = math.ceil(#itemIDs / iconsPerRow)
    local gridHeight = numRows * (ITEM_ICON_SIZE + ITEM_ICON_PAD)
    grid:SetHeight(gridHeight)
    grid:Show()

    return gridHeight + ITEM_ICON_PAD  -- Extra padding below grid
end

local function HideItemGrid(row)
    if row.itemGrid then
        row.itemGrid:Hide()
    end
end

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

    row:RegisterForClicks("AnyUp")

    row:SetScript("OnClick", function(self)
        if not self.vendor then return end
        -- Left-click: toggle item grid expansion
        local npcID = self.vendor.npcID
        if expandedVendorID == npcID then
            expandedVendorID = nil  -- Collapse
        else
            expandedVendorID = npcID  -- Expand this one
        end
        MapSidePanel:RefreshContent()
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
            local color
            if self.collected == self.total then
                color = {0, 1, 0}       -- Fully collected: green
            elseif self.collected > 0 then
                color = {1, 0.82, 0}    -- Partial: yellow
            else
                color = {1, 0.3, 0.3}   -- None: red
            end
            GameTooltip:AddLine(string.format("Collected: %d/%d", self.collected, self.total),
                color[1], color[2], color[3])
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to show items", 0.5, 0.5, 0.5)
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
    -- Named for UISpecialFrames support (Escape-to-close when detached).
    local canvas = WorldMapFrame.ScrollContainer
    local panel = CreateFrame("Frame", "HomesteadSidePanel", WorldMapFrame)
    panel:SetWidth(PANEL_WIDTH)
    panel:SetPoint("TOPRIGHT", canvas, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMLEFT", 0, 0)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel(500)
    panel:EnableMouse(true)  -- Prevent clicks falling through to world map

    -- 1. BORDER: NineSlice metal border (PortraitFrameTemplate base, corners overridden)
    panel.NineSlice = CreateFrame("Frame", nil, panel, "NineSlicePanelTemplate")
    panel.NineSlice:SetAllPoints()
    panel.NineSlice:SetFrameLevel(panel:GetFrameLevel() + 2)
    NineSliceUtil.ApplyLayoutByName(panel.NineSlice, "PortraitFrameTemplate")

    -- Replace portrait-style corner with standard metal corner (no portrait circle)
    if panel.NineSlice.TopLeftCorner then
        panel.NineSlice.TopLeftCorner:SetAtlas("UI-Frame-Metal-CornerTopLeft", true)
    end

    -- Match the map frame's double-corner style for top-right
    if panel.NineSlice.TopRightCorner then
        panel.NineSlice.TopRightCorner:SetAtlas("UI-Frame-Metal-CornerTopRightDouble")
    end

    -- Re-anchor TopEdge between the (now standard-sized) corners
    if panel.NineSlice.TopEdge then
        panel.NineSlice.TopEdge:ClearAllPoints()
        panel.NineSlice.TopEdge:SetPoint("TOPLEFT", panel.NineSlice.TopLeftCorner, "TOPRIGHT", -2, 0)
        panel.NineSlice.TopEdge:SetPoint("TOPRIGHT", panel.NineSlice.TopRightCorner, "TOPLEFT", 2, 0)
    end

    -- 2. INNER TOP BORDER: Decorative top-edge tile inside the border
    --    Created before background so bg can anchor to it.
    topTileFrame = panel:CreateTexture(nil, "ARTWORK")
    topTileFrame:SetAtlas("_UI-Frame-InnerTopTile", false)
    topTileFrame:SetHorizTile(true)
    topTileFrame:SetHeight(10)
    topTileFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -18)
    topTileFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -18)

    -- 3. BACKGROUND FILL: Blizzard's quest log background atlas.
    --    Fills full panel by default (standalone/detached). In integrated mode,
    --    ApplyContentInset adjusts the top anchor below the header zone so the
    --    dark background doesn't bleed into the map's border area.
    bgTexture = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    bgTexture:SetAtlas("QuestLogBackground", false)
    bgTexture:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    bgTexture:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

    -- Decorative streaks overlay on the inner top border
    topStreaksFrame = panel:CreateTexture(nil, "ARTWORK", nil, 1)
    topStreaksFrame:SetAtlas("_UI-Frame-TopTileStreaks", false)
    topStreaksFrame:SetHorizTile(true)
    topStreaksFrame:SetHeight(10)
    topStreaksFrame:SetPoint("TOPLEFT", topTileFrame, "TOPLEFT", 0, 0)
    topStreaksFrame:SetPoint("TOPRIGHT", topTileFrame, "TOPRIGHT", 0, 0)

    -- Content insets (inside NineSlice border)
    local BORDER_LEFT = 10
    local BORDER_RIGHT = 10
    local BORDER_TOP = 22  -- Reduced from 28 (portrait corner was larger)
    local BORDER_BOTTOM = 10

    -- Title header (centered horizontally)
    headerFrame = CreateFrame("Frame", nil, panel)
    headerFrame:SetHeight(HEADER_HEIGHT)
    headerFrame:SetPoint("TOPLEFT", BORDER_LEFT, -BORDER_TOP)
    headerFrame:SetPoint("TOPRIGHT", -BORDER_RIGHT, -BORDER_TOP)

    -- Homestead label (centered, below inner top border tile)
    local titleLabel = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleLabel:SetPoint("TOP", headerFrame, "TOP", 0, -4)
    titleLabel:SetText("Homestead")

    -- Zone/map name (centered below title)
    headerText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerText:SetPoint("TOP", titleLabel, "BOTTOM", 0, -3)
    headerText:SetJustifyH("CENTER")
    headerText:SetWordWrap(false)
    headerText:SetTextColor(0.7, 0.7, 0.7)
    headerText:SetText("")

    -- Header separator line
    local headerSep = headerFrame:CreateTexture(nil, "ARTWORK")
    headerSep:SetHeight(1)
    headerSep:SetPoint("BOTTOMLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
    headerSep:SetPoint("BOTTOMRIGHT", headerFrame, "BOTTOMRIGHT", 0, 0)
    headerSep:SetColorTexture(0.4, 0.4, 0.4, 0.5)

    -- Summary line (centered at bottom)
    summaryText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summaryText:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", BORDER_LEFT, BORDER_BOTTOM)
    summaryText:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -BORDER_RIGHT, BORDER_BOTTOM)
    summaryText:SetJustifyH("CENTER")
    summaryText:SetTextColor(0.6, 0.6, 0.6)

    -- Scroll frame for vendor list
    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)
    scrollContainer:SetPoint("BOTTOMRIGHT", -BORDER_RIGHT, BORDER_BOTTOM + 18)

    scrollFrame = CreateFrame("ScrollFrame", nil, scrollContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -22, 0)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    -- Use a computed width (panel is hidden during creation, so GetWidth() returns 0)
    local scrollWidth = PANEL_WIDTH - BORDER_LEFT - BORDER_RIGHT - 22  -- 22 = scrollbar
    scrollChild:SetWidth(scrollWidth)
    scrollChild:SetHeight(1)  -- Will be resized dynamically
    scrollFrame:SetScrollChild(scrollChild)

    -- Empty state text
    emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("CENTER", scrollContainer, "CENTER", 0, 0)
    emptyText:SetText("No vendors in this zone")
    emptyText:Hide()

    -- Pop-out button (docked mode): arrow icon in header area next to title
    popOutButton = CreateFrame("Button", nil, headerFrame)
    popOutButton:SetSize(16, 16)
    popOutButton:SetPoint("RIGHT", headerFrame, "RIGHT", -2, -2)

    popOutButton:SetNormalAtlas("RedButton-Expand")
    popOutButton:SetPushedAtlas("RedButton-Expand-Pressed")
    popOutButton:SetHighlightAtlas("RedButton-Highlight")

    popOutButton:SetScript("OnClick", function()
        MapSidePanel:PopOut()
    end)
    popOutButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Detach panel")
        GameTooltip:Show()
    end)
    popOutButton:SetScript("OnLeave", GameTooltip_Hide)

    -- Close button (detached mode): standard X at top-right
    closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -2, -2)
    closeButton:SetScript("OnClick", function()
        -- Full reset: hide panel, clear pop-out state
        MapSidePanel:CloseDetached()
    end)
    closeButton:Hide()

    -- Re-attach button (detached mode): small icon next to close button
    reattachButton = CreateFrame("Button", nil, panel)
    reattachButton:SetSize(16, 16)
    reattachButton:SetPoint("RIGHT", closeButton, "LEFT", 2, 0)

    reattachButton:SetNormalAtlas("RedButton-Condense")
    reattachButton:SetPushedAtlas("RedButton-Condense-Pressed")
    reattachButton:SetHighlightAtlas("RedButton-Highlight")

    reattachButton:SetScript("OnClick", function()
        MapSidePanel:DockPanel()
    end)
    reattachButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Attach to World Map")
        GameTooltip:Show()
    end)
    reattachButton:SetScript("OnLeave", GameTooltip_Hide)
    reattachButton:Hide()

    panel:Hide()
    panelFrame = panel
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

        -- Detach / Attach panel toggle (only when panel is visible or popped out)
        if panelFrame and (panelFrame:IsShown() or isPoppedOut) then
            rootDescription:CreateCheckbox(
                isPoppedOut and "Attach to Map" or "Detach Panel",
                function() return isPoppedOut end,
                function()
                    if isPoppedOut then
                        MapSidePanel:DockPanel()
                    else
                        MapSidePanel:PopOut()
                    end
                end
            )
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
        elseif isPoppedOut and panelFrame and panelFrame:IsShown() then
            -- Popped out + visible: raise to front instead of toggling
            panelFrame:Raise()
        else
            MapSidePanel:Toggle()
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, "Homestead")
        if isPoppedOut and panelFrame and panelFrame:IsShown() then
            GameTooltip_AddNormalLine(GameTooltip, "Left-click: Show vendor panel")
        else
            GameTooltip_AddNormalLine(GameTooltip, "Left-click: Toggle vendor panel")
        end
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

    -- MapID resolution: map frame → last viewed → player zone
    local mapID
    if WorldMapFrame:IsShown() then
        mapID = WorldMapFrame:GetMapID()
    end
    if not mapID then
        mapID = lastRefreshMapID
    end
    if not mapID then
        mapID = C_Map.GetBestMapForUnit("player")
    end
    if not mapID then
        -- No map data available (loading screen, instance)
        for _, row in ipairs(vendorRows) do
            row:Hide()
            HideItemGrid(row)
        end
        emptyText:SetText("Open the World Map to view vendors")
        emptyText:Show()
        summaryText:SetText("")
        scrollChild:SetHeight(1)
        return
    end

    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo then return end

    -- Ensure scrollChild has a valid width (may be 0 if panel was hidden during creation)
    if scrollChild and scrollChild:GetWidth() < 1 then
        scrollChild:SetWidth(PANEL_WIDTH - 20 - 22)  -- 20 = border insets, 22 = scrollbar
    end

    -- Update header with zone name
    headerText:SetText(mapInfo.name or "")

    -- Determine map type
    local isZoneLevel = mapInfo.mapType and mapInfo.mapType >= Enum.UIMapType.Zone

    if not isZoneLevel then
        -- Continent or world view — show prompt
        expandedVendorID = nil
        for _, row in ipairs(vendorRows) do
            row:Hide()
            HideItemGrid(row)
        end
        if isPoppedOut and not WorldMapFrame:IsShown() then
            emptyText:SetText("Open the World Map to view vendors")
        else
            emptyText:SetText("Select a zone to see vendors")
        end
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
    local yOffset = 0  -- Tracks cumulative Y position (variable row heights)

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
                countColor = {0, 1, 0}      -- Fully collected: green
            elseif collected > 0 then
                countColor = {1, 0.82, 0}   -- Partial: yellow/gold
            else
                countColor = {1, 0.3, 0.3}  -- None collected: red
            end
            row.countText:SetText(string.format("%d/%d collected", collected, total))
            row.countText:SetTextColor(countColor[1], countColor[2], countColor[3])
        else
            row.countText:SetText("No item data")
            row.countText:SetTextColor(0.5, 0.5, 0.5)
        end

        totalCollected = totalCollected + collected
        totalItems = totalItems + total

        -- Check if this vendor is expanded (item grid visible)
        local isExpanded = (expandedVendorID == vendor.npcID)
        local rowHeight = ROW_HEIGHT
        if isExpanded then
            local gridHeight = PopulateItemGrid(row, vendor)
            rowHeight = ROW_HEIGHT + gridHeight
        else
            HideItemGrid(row)
        end

        -- Position row with variable height
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -yOffset)
        row:SetHeight(rowHeight)
        row:Show()

        yOffset = yOffset + rowHeight
    end

    -- Hide excess rows
    for i = #vendorList + 1, #vendorRows do
        vendorRows[i]:Hide()
        HideItemGrid(vendorRows[i])
    end

    -- Update scroll height (variable total)
    scrollChild:SetHeight(math.max(1, yOffset))

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
-- Custom UI Detection
-- ElvUI, GW2, Tukui, etc. may reskin WorldMapFrame. When detected (or when
-- the user disables integration), the panel renders self-contained with its
-- own complete border and never touches map frame elements.
-------------------------------------------------------------------------------

local useStandaloneMode = nil  -- nil = not yet checked, true/false after check

local function ShouldUseStandaloneMode()
    -- Cache after first check
    if useStandaloneMode ~= nil then return useStandaloneMode end

    -- User setting overrides detection
    if HA.Addon and HA.Addon.db then
        if HA.Addon.db.profile.vendorTracer.integrateMapBorder == false then
            useStandaloneMode = true
            return true
        end
    end

    -- Detect custom UIs that replace WorldMapFrame
    if _G.ElvUI or _G.GW2_UI or _G.Tukui then
        useStandaloneMode = true
        return true
    end

    -- Verify expected Blizzard frame structure exists
    local bf = WorldMapFrame.BorderFrame
    if not bf or not bf.NineSlice or not bf.NineSlice.TopEdge then
        useStandaloneMode = true
        return true
    end

    useStandaloneMode = false
    return false
end

-- Call when the setting changes to re-evaluate
local function ResetStandaloneCheck()
    useStandaloneMode = nil
end

-------------------------------------------------------------------------------
-- Map Position Shifting
-- Nudges the WorldMapFrame right when the panel is open, restores when closed.
-- Safe because the world map cannot be opened during combat.
-------------------------------------------------------------------------------

-- Saved anchor data for the map's NineSlice top edge (left anchor only)
local savedMapTopEdge = nil  -- {point, relativeTo, relativePoint, xOfs, yOfs}

ShiftMapRight = function()
    if mapShifted then return end
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
-- Map Element Repositioning (integrated mode)
--
-- The old approach (ShiftElementLeft by PANEL_WIDTH) failed because elements
-- moved outside their parent's clipping rect. New approach:
--
-- Portrait + Info button: temporarily reparented to panelFrame so they
-- render within the panel's bounds at its top-left corner.
--
-- Nav bar: left anchor extended to the panel via cross-parent anchoring,
-- with parent clipping disabled so the breadcrumbs remain visible.
--
-- All changes are fully reversed on close.
-------------------------------------------------------------------------------

-- Saved state per element: { parent, level, strata, anchors = {{p,r,rp,x,y}, ...} }
local savedPortraitState = nil
local savedPortraitTexture = nil  -- original portrait texture/ID, restored on close
local savedTutorialState = nil
-- NavBar: surgical save — only the TOPLEFT anchor, strata, and level are modified,
-- so only those need saving. Avoids SetParent/ClearAllPoints side effects.
local savedNavBarTOPLEFT = nil  -- {relativeTo, relativePoint, x, y}
local savedNavBarStrata = nil
local savedNavBarLevel = nil
local savedClipStates = {}  -- { [frame] = originalClipBool }

local function SaveFrameState(frame)
    if not frame then return nil end
    local state = {
        parent = frame:GetParent(),
        level = frame:GetFrameLevel(),
        strata = frame:GetFrameStrata(),
        anchors = {},
    }
    for i = 1, frame:GetNumPoints() do
        local p, r, rp, x, y = frame:GetPoint(i)
        state.anchors[i] = { p, r, rp, x, y }
    end
    return state
end

local function RestoreFrameState(frame, state)
    if not frame or not state then return end
    frame:SetParent(state.parent)
    frame:SetFrameStrata(state.strata)
    frame:SetFrameLevel(state.level)
    frame:ClearAllPoints()
    for _, a in ipairs(state.anchors) do
        frame:SetPoint(a[1], a[2], a[3], a[4], a[5])
    end
end

local function DisableClipping(frame)
    if not frame or not frame.SetClipsChildren then return end
    if savedClipStates[frame] == nil then
        savedClipStates[frame] = frame:DoesClipChildren()
    end
    frame:SetClipsChildren(false)
end

local function RestoreClipping()
    for frame, wasClipping in pairs(savedClipStates) do
        if frame and frame.SetClipsChildren then
            frame:SetClipsChildren(wasClipping)
        end
    end
    wipe(savedClipStates)
end

local function ReparentMapElements()
    if savedPortraitState then return end  -- already done
    if not panelFrame then return end

    local wm = WorldMapFrame
    local bf = wm.BorderFrame

    -- 1. Portrait container → reparent to panel, position at top-left corner.
    --    The container has a CircleMask that clips all textures to a circle,
    --    which hides the built-in ring border. So we create a separate ring
    --    frame on top that isn't subject to the mask.
    local pc = wm.PortraitContainer or (bf and bf.PortraitContainer)
    if pc then
        savedPortraitState = SaveFrameState(pc)
        pc:SetParent(panelFrame)
        -- Must be above NineSlice (502) AND background.
        pc:SetFrameLevel(panelFrame:GetFrameLevel() + 10)  -- 510
        pc:ClearAllPoints()
        pc:SetPoint("CENTER", panelFrame, "TOPLEFT", 3, -1)
        pc:Show()

        -- Swap portrait texture to Homestead icon
        if pc.portrait then
            if not savedPortraitTexture then
                savedPortraitTexture = pc.portrait:GetTexture()
            end
            pc.portrait:SetTexture("Interface\\AddOns\\Homestead\\Textures\\HomesteadPortrait_64")
        end

    end

    -- 2. Info / tutorial button → reparent to panel, tuck against portrait
    --    Position it to the RIGHT of the portrait, vertically centered,
    --    so it sits between the portrait circle and the "World" breadcrumb.
    local tutorial = bf and bf.Tutorial
    if tutorial and pc then
        savedTutorialState = SaveFrameState(tutorial)
        tutorial:SetParent(panelFrame)
        tutorial:SetFrameLevel(panelFrame:GetFrameLevel() + 11)
        tutorial:ClearAllPoints()
        -- Absolute position on panel, to the right of the ~40px portrait circle
        tutorial:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 52, 23)
        tutorial:Show()
    end

    -- 3. Nav bar → extend left anchor to panel (keep right anchor on map).
    --    Walk the entire parent chain from nav bar to WorldMapFrame and
    --    disable clipping on every frame to prevent breadcrumb cutoff.
    --    Only the TOPLEFT anchor, strata, and level are changed — surgical
    --    save avoids SetParent/ClearAllPoints side effects on restore.
    local navBar = wm.NavBar
    if navBar and not savedNavBarTOPLEFT and navBar:GetNumPoints() > 0 then
        -- Save only what we change: TOPLEFT anchor, strata, level
        savedNavBarStrata = navBar:GetFrameStrata()
        savedNavBarLevel = navBar:GetFrameLevel()

        -- Find the TOPLEFT anchor specifically
        local origRelTo, origRelPt, origX, origY
        for i = 1, navBar:GetNumPoints() do
            local p, r, rp, x, y = navBar:GetPoint(i)
            if p == "TOPLEFT" then
                origRelTo = r
                origRelPt = rp
                origX = x or 0
                origY = y or 0
                break
            end
        end
        savedNavBarTOPLEFT = { origRelTo, origRelPt, origX, origY }

        -- Walk the entire parent chain from nav bar upward, disabling clipping
        local frame = navBar
        while frame and frame ~= wm do
            DisableClipping(frame)
            local parent = frame:GetParent()
            if parent == frame then break end  -- safety
            frame = parent
        end
        DisableClipping(wm)

        -- Also disable clipping on the nav bar itself
        DisableClipping(navBar)

        -- Raise nav bar above the panel so buttons aren't hidden behind
        -- the panel's opaque background. Panel is HIGH/500; nav bar must
        -- be above that for the left-extending breadcrumbs to be visible.
        navBar:SetFrameStrata("HIGH")
        navBar:SetFrameLevel(panelFrame:GetFrameLevel() + 15)  -- 515

        -- Replace the left anchor: start at the panel's left edge, past
        -- the portrait (≈64px). Keep the original Y offset and right anchor.
        navBar:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 64, origY or 0)

    end
end

local function RestoreMapElements()
    local wm = WorldMapFrame
    local bf = wm.BorderFrame

    -- Portrait
    local pc = wm.PortraitContainer or (bf and bf.PortraitContainer)
    if pc and savedPortraitState then
        -- Restore original portrait texture before reparenting back
        if pc.portrait and savedPortraitTexture then
            pc.portrait:SetTexture(savedPortraitTexture)
        end
        RestoreFrameState(pc, savedPortraitState)
        savedPortraitState = nil
    end
    -- Tutorial
    local tutorial = bf and bf.Tutorial
    if tutorial and savedTutorialState then
        RestoreFrameState(tutorial, savedTutorialState)
        savedTutorialState = nil
    end

    -- Nav bar (surgical restore — only TOPLEFT anchor, strata, level)
    local navBar = wm.NavBar
    if navBar and savedNavBarTOPLEFT then
        navBar:SetPoint("TOPLEFT", savedNavBarTOPLEFT[1], savedNavBarTOPLEFT[2],
            savedNavBarTOPLEFT[3], savedNavBarTOPLEFT[4])
        navBar:SetFrameStrata(savedNavBarStrata)
        navBar:SetFrameLevel(savedNavBarLevel)
        savedNavBarTOPLEFT = nil
        savedNavBarStrata = nil
        savedNavBarLevel = nil
    end

    -- Clipping
    RestoreClipping()
end

-------------------------------------------------------------------------------
-- Content Inset (integrated mode)
-- Push the panel's content area below the nav bar / portrait header zone.
-- Only the interior elements move; the panel frame stays at the top.
-------------------------------------------------------------------------------

local contentInsetApplied = false
local DEFAULT_TOP_TILE_OFFSET = 18   -- Default tile Y (standalone mode)
local DEFAULT_HEADER_TOP = 22        -- Default BORDER_TOP for header

-- Measure the lowest bottom edge of the header zone elements (portrait,
-- nav bar) relative to the panel's top, then re-anchor tiles + header below.
-- Must run after a layout pass (deferred) for accurate GetBottom/GetTop.
local function ApplyContentInset()
    if contentInsetApplied then return end
    if not panelFrame or not headerFrame then return end

    local panelTop = panelFrame:GetTop()
    if not panelTop then return end

    -- Find the lowest bottom edge among header zone elements
    local lowestBottom = nil
    local wm = WorldMapFrame

    -- Check nav bar (usually extends lower than the portrait)
    local navBar = wm.NavBar
    if navBar and navBar:IsShown() then
        local nb = navBar:GetBottom()
        if nb then
            lowestBottom = nb
        end
    end

    -- Check portrait container
    local pc = wm.PortraitContainer or (wm.BorderFrame and wm.BorderFrame.PortraitContainer)
    if pc then
        local pb = pc:GetBottom()
        if pb and (not lowestBottom or pb < lowestBottom) then
            lowestBottom = pb
        end
    end

    if not lowestBottom then return end

    -- Negative offset from panel top to just below the header zone
    local insetY = lowestBottom - panelTop - 5  -- 5px padding

    -- Move decorative tiles
    if topTileFrame then
        topTileFrame:ClearAllPoints()
        topTileFrame:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 6, insetY)
        topTileFrame:SetPoint("TOPRIGHT", panelFrame, "TOPRIGHT", -6, insetY)
    end

    -- Move header below the tiles
    local headerY = insetY - 10  -- 10 = tile height
    headerFrame:ClearAllPoints()
    headerFrame:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 10, headerY)
    headerFrame:SetPoint("TOPRIGHT", panelFrame, "TOPRIGHT", -10, headerY)

    contentInsetApplied = true
end

local function RestoreContentInset()
    if not contentInsetApplied then return end

    if topTileFrame then
        topTileFrame:ClearAllPoints()
        topTileFrame:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 6, -DEFAULT_TOP_TILE_OFFSET)
        topTileFrame:SetPoint("TOPRIGHT", panelFrame, "TOPRIGHT", -6, -DEFAULT_TOP_TILE_OFFSET)
    end

    if headerFrame then
        headerFrame:ClearAllPoints()
        headerFrame:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 10, -DEFAULT_HEADER_TOP)
        headerFrame:SetPoint("TOPRIGHT", panelFrame, "TOPRIGHT", -10, -DEFAULT_HEADER_TOP)
    end

    contentInsetApplied = false
end

-------------------------------------------------------------------------------
-- Portrait: swapped to HomesteadPortrait_64 when panel opens, restored on close.
-- The portrait container is reparented to panelFrame (see ReparentMapElements)
-- so the entire unit (icon + mask + ring) moves together.

-------------------------------------------------------------------------------
-- Unified Top Border (integrated mode only)
-- Extends the map's metal top edge leftward over the Homestead panel
-- so the two frames share one seamless top border.
--
-- Skipped entirely in standalone mode (custom UI or user preference).
-- All Blizzard frame access is nil-guarded for safety.
-------------------------------------------------------------------------------

local borderUnified = false
local savedMapTopLeftCornerShown = nil

local function UnifyTopBorder()
    if borderUnified then return end
    if not panelFrame then return end
    if ShouldUseStandaloneMode() then return end

    local bf = WorldMapFrame.BorderFrame
    if not bf then return end
    local mapNS = bf.NineSlice
    if not mapNS then return end

    local canvas = WorldMapFrame.ScrollContainer
    local mapTopEdge = mapNS.TopEdge
    local mapTopLeft = mapNS.TopLeftCorner
    local panelNS = panelFrame.NineSlice

    if not mapTopEdge or not panelNS or not canvas then return end

    -- 1. Extend panel upward so its top aligns with the map border top.
    local borderTop = bf.GetTop and bf:GetTop()
    local canvasTop = canvas.GetTop and canvas:GetTop()
    if borderTop and canvasTop and (borderTop - canvasTop) > 0 then
        panelFrame:SetPoint("TOPRIGHT", canvas, "TOPLEFT", 0, borderTop - canvasTop)
    end

    -- 2. Save map TopEdge's original left anchor for restore
    if not savedMapTopEdge then
        local ok, p, r, rp, x, y = pcall(mapTopEdge.GetPoint, mapTopEdge, 1)
        if ok and p then
            savedMapTopEdge = { p, r, rp, x, y }
        end
    end

    -- 3. Hide the map's NineSlice portrait corner (TopLeftCorner is the large
    --    corner piece with border geometry). The portrait container's own built-in
    --    gold ring (region 3, texture 136430) handles the circular border.
    if mapTopLeft then
        savedMapTopLeftCornerShown = mapTopLeft:IsShown()
        mapTopLeft:Hide()
    end

    -- 4. Stretch map TopEdge left to start at the panel's standard corner.
    if panelNS.TopLeftCorner then
        mapTopEdge:SetPoint("TOPLEFT", panelNS.TopLeftCorner, "TOPRIGHT", -2, 0)
    end

    -- 5. Hide panel's top border (map's extended TopEdge covers this area)
    if panelNS.TopEdge then panelNS.TopEdge:Hide() end
    if panelNS.TopRightCorner then panelNS.TopRightCorner:Hide() end

    -- 6. Clip panel background just below the map's metal top border.
    --    The panel extends (borderTop - canvasTop) above the canvas; offset
    --    the bg top upward by 20px from the canvas level to meet the border's
    --    inner bottom edge.
    if bgTexture and borderTop and canvasTop then
        local borderHeight = borderTop - canvasTop
        local bgOffset = borderHeight - 45  -- 45px up from canvas to border bottom
        if bgOffset > 0 then
            bgTexture:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 0, -bgOffset)
        end
    end

    borderUnified = true
end

local function RestoreTopBorder()
    if not borderUnified then return end

    local bf = WorldMapFrame.BorderFrame
    local mapNS = bf and bf.NineSlice
    local canvas = WorldMapFrame.ScrollContainer
    local mapTopEdge = mapNS and mapNS.TopEdge
    local mapTopLeft = mapNS and mapNS.TopLeftCorner
    local panelNS = panelFrame and panelFrame.NineSlice

    -- Restore map TopEdge original anchor
    if mapTopEdge and savedMapTopEdge then
        pcall(mapTopEdge.SetPoint, mapTopEdge,
            savedMapTopEdge[1], savedMapTopEdge[2],
            savedMapTopEdge[3], savedMapTopEdge[4], savedMapTopEdge[5])
    end
    savedMapTopEdge = nil  -- Re-capture fresh on next UnifyTopBorder

    -- Restore background to fill full panel (no border zone offset)
    if bgTexture then
        bgTexture:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 0, 0)
    end

    -- Restore map TopLeftCorner (portrait ring) visibility
    if mapTopLeft and savedMapTopLeftCornerShown then
        mapTopLeft:Show()
    end
    savedMapTopLeftCornerShown = nil

    -- Restore panel top border pieces
    if panelNS then
        if panelNS.TopEdge then panelNS.TopEdge:Show() end
        if panelNS.TopRightCorner then panelNS.TopRightCorner:Show() end
    end

    -- Restore panel anchor (back to canvas top, no Y extension)
    if canvas then
        panelFrame:SetPoint("TOPRIGHT", canvas, "TOPLEFT", 0, 0)
    end

    borderUnified = false
end

-------------------------------------------------------------------------------
-- Toggle / Visibility
-------------------------------------------------------------------------------

local panelShowGeneration = 0  -- Incremented each Show, guards deferred callbacks

local function ShowPanel()
    if not panelFrame then return end
    panelFrame:Show()

    -- When popped out, skip all map integration (panel is independent)
    if isPoppedOut then return end

    ShiftMapRight()

    if not ShouldUseStandaloneMode() then
        ReparentMapElements()
        -- Defer border + content inset by one frame for accurate layout values.
        -- Guard with generation counter so a quick close cancels this.
        panelShowGeneration = panelShowGeneration + 1
        local gen = panelShowGeneration
        C_Timer.After(0, function()
            if gen ~= panelShowGeneration then return end  -- stale, panel was toggled
            if not panelFrame or not panelFrame:IsShown() then return end
            UnifyTopBorder()
            ApplyContentInset()
        end)
    end
end

local function HidePanel()
    if not panelFrame then return end
    -- Bump generation to cancel any pending deferred Show callbacks
    panelShowGeneration = panelShowGeneration + 1

    if isPoppedOut then
        -- When popped out, just hide the frame — no map restoration needed
        panelFrame:Hide()
        return
    end

    RestoreContentInset()
    RestoreTopBorder()
    RestoreMapElements()
    panelFrame:Hide()
    RestoreMapPosition()
end

-- Update button visibility based on pop-out state
local function UpdatePopOutButtons()
    if not popOutButton then return end
    if isPoppedOut then
        popOutButton:Hide()
        closeButton:Show()
        reattachButton:Show()
    else
        popOutButton:Show()
        closeButton:Hide()
        reattachButton:Hide()
    end
end

-- Re-set frame levels after reparent (SetParent can reset child levels)
local function RestoreFrameLevels()
    if not panelFrame then return end
    panelFrame:SetFrameStrata("HIGH")
    panelFrame:SetFrameLevel(500)
    if panelFrame.NineSlice then
        panelFrame.NineSlice:SetFrameLevel(502)
    end
end

-- Ensure NineSlice border is visually complete (re-show pieces hidden by UnifyTopBorder)
local function EnsureCompleteBorder()
    if not panelFrame or not panelFrame.NineSlice then return end
    local ns = panelFrame.NineSlice
    if ns.TopEdge then ns.TopEdge:Show() end
    if ns.TopRightCorner then ns.TopRightCorner:Show() end
end

-- Save detached position to profile
local function SaveDetachedPosition()
    if not panelFrame or not HA.Addon or not HA.Addon.db then return end
    local point, _, _, x, y = panelFrame:GetPoint(1)
    if point then
        HA.Addon.db.profile.vendorTracer.sidePanelPosition = {
            point = point, x = x or 0, y = y or 0,
        }
    end
    HA.Addon.db.profile.vendorTracer.sidePanelHeight = panelFrame:GetHeight()
end

-- Check if a saved position is on-screen; returns true if valid
local function IsPositionOnScreen(pos)
    if not pos or not pos.point then return false end
    local sw, sh = GetScreenWidth(), GetScreenHeight()
    local x, y = pos.x or 0, pos.y or 0
    -- Simple bounds: check if the anchor point is within screen bounds (with margin)
    if math.abs(x) > sw or math.abs(y) > sh then return false end
    return true
end

function MapSidePanel:PopOut()
    if not panelFrame then return end
    if isPoppedOut then return end

    -- 1. Capture height before clearing anchors
    local h = panelFrame:GetHeight()
    if h < 1 then
        local db = HA.Addon and HA.Addon.db
        h = db and db.profile.vendorTracer.sidePanelHeight
        if not h or h < 1 then
            h = UIParent:GetHeight() * 0.6
        end
    end

    -- 2. Restore all map modifications
    RestoreContentInset()
    RestoreTopBorder()
    RestoreMapElements()
    RestoreMapPosition()

    -- 3. Reparent to UIParent
    panelFrame:SetParent(UIParent)

    -- 4. Re-set strata/levels after reparent
    RestoreFrameLevels()

    -- 5-6. Clear anchors, set size, restore position
    panelFrame:ClearAllPoints()
    panelFrame:SetWidth(PANEL_WIDTH)
    panelFrame:SetHeight(h)

    local db = HA.Addon and HA.Addon.db
    local saved = db and db.profile.vendorTracer.sidePanelPosition
    if saved and IsPositionOnScreen(saved) then
        panelFrame:SetPoint(saved.point, UIParent, saved.point, saved.x, saved.y)
    else
        panelFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    -- 7. Make movable via panelFrame drag (not headerFrame — header starts 22px
    --    below the top, so the NineSlice border wouldn't be draggable).
    --    Child frames (buttons, scroll) capture their own clicks; panelFrame drag
    --    only activates from "empty" areas like the border and header text.
    panelFrame:SetMovable(true)
    panelFrame:SetClampedToScreen(true)
    panelFrame:RegisterForDrag("LeftButton")
    panelFrame:SetScript("OnDragStart", panelFrame.StartMoving)
    panelFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveDetachedPosition()
    end)

    -- 8. Ensure complete border
    EnsureCompleteBorder()

    -- 8b. Raise reattach button above NineSlice (only needed when detached;
    --     setting at creation time breaks the unified top border in docked mode)
    if reattachButton then
        reattachButton:SetFrameLevel(panelFrame:GetFrameLevel() + 5)
    end

    -- 9. Update buttons
    isPoppedOut = true  -- Set before UpdatePopOutButtons so it reads correctly
    UpdatePopOutButtons()

    -- 10. UISpecialFrames for Escape-to-close
    tinsert(UISpecialFrames, "HomesteadSidePanel")

    -- 11. Cancel pending deferred callbacks
    panelShowGeneration = panelShowGeneration + 1

    -- 12. Save to profile
    if db then
        db.profile.vendorTracer.sidePanelPoppedOut = true
        db.profile.vendorTracer.sidePanelHeight = h
    end

    panelFrame:Show()
    self:RefreshContent()
end

function MapSidePanel:DockPanel()
    if not panelFrame then return end
    if not isPoppedOut then return end

    -- 1. Save position and height
    SaveDetachedPosition()

    -- 2. Remove from UISpecialFrames
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "HomesteadSidePanel" then
            table.remove(UISpecialFrames, i)
            break
        end
    end

    -- 3. Reparent back to WorldMapFrame
    panelFrame:SetParent(WorldMapFrame)

    -- 4. Clear drag handlers
    panelFrame:SetMovable(false)
    panelFrame:SetClampedToScreen(false)
    panelFrame:SetScript("OnDragStart", nil)
    panelFrame:SetScript("OnDragStop", nil)

    -- 5. Restore original anchors (flush left of canvas, height from top+bottom anchors)
    local canvas = WorldMapFrame.ScrollContainer
    panelFrame:ClearAllPoints()
    panelFrame:SetWidth(PANEL_WIDTH)
    panelFrame:SetPoint("TOPRIGHT", canvas, "TOPLEFT", 0, 0)
    panelFrame:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMLEFT", 0, 0)

    -- 6. Re-set strata/levels after reparent
    RestoreFrameLevels()
    -- Reattach button level is not reset here — it's hidden when docked
    -- and touching frame levels during dock disrupts NineSlice rendering.

    -- 7. Update buttons
    isPoppedOut = false
    UpdatePopOutButtons()

    -- 8. Pre-hide panel's top NineSlice pieces before integrated mode re-applies.
    --    EnsureCompleteBorder() during PopOut showed these; UnifyTopBorder will
    --    hide them again via the deferred callback, but pre-hiding avoids a
    --    one-frame flash where both the panel's top border and map border overlap.
    if not ShouldUseStandaloneMode() then
        local ns = panelFrame.NineSlice
        if ns then
            if ns.TopEdge then ns.TopEdge:Hide() end
            if ns.TopRightCorner then ns.TopRightCorner:Hide() end
        end
    end

    -- 9-10. If map is open, re-apply integrated mode; otherwise hide
    if WorldMapFrame:IsShown() then
        ShowPanel()
        self:RefreshContent()
    else
        panelFrame:Hide()
    end

    -- 10. Save to profile
    if HA.Addon and HA.Addon.db then
        HA.Addon.db.profile.vendorTracer.sidePanelPoppedOut = false
    end
end

function MapSidePanel:CloseDetached()
    if not panelFrame then return end

    -- Save position while frame is still visible and anchored
    SaveDetachedPosition()

    -- Full reset: hide panel, clear both pop-out and panel-shown state
    HidePanel()
    isPoppedOut = false
    UpdatePopOutButtons()

    -- Remove from UISpecialFrames
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "HomesteadSidePanel" then
            table.remove(UISpecialFrames, i)
            break
        end
    end

    -- Reparent back to WorldMapFrame so it's ready for docked mode next time
    panelFrame:SetParent(WorldMapFrame)
    panelFrame:SetMovable(false)
    panelFrame:SetClampedToScreen(false)
    panelFrame:SetScript("OnDragStart", nil)
    panelFrame:SetScript("OnDragStop", nil)

    -- Restore original anchors
    local canvas = WorldMapFrame.ScrollContainer
    panelFrame:ClearAllPoints()
    panelFrame:SetWidth(PANEL_WIDTH)
    panelFrame:SetPoint("TOPRIGHT", canvas, "TOPLEFT", 0, 0)
    panelFrame:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMLEFT", 0, 0)

    RestoreFrameLevels()

    if HA.Addon and HA.Addon.db then
        HA.Addon.db.profile.vendorTracer.sidePanelPoppedOut = false
        HA.Addon.db.profile.vendorTracer.showMapSidePanel = false
    end
end

function MapSidePanel:Toggle()
    if not panelFrame then return end

    if isPoppedOut then
        if panelFrame:IsShown() then
            -- Popped out + visible: full reset
            self:CloseDetached()
        else
            -- Popped out + hidden (shouldn't normally happen): open docked
            isPoppedOut = false
            UpdatePopOutButtons()
            ShowPanel()
            if HA.Addon and HA.Addon.db then
                HA.Addon.db.profile.vendorTracer.showMapSidePanel = true
                HA.Addon.db.profile.vendorTracer.sidePanelPoppedOut = false
            end
            self:RefreshContent()
        end
        return
    end

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

function MapSidePanel:IsPoppedOut()
    return isPoppedOut
end

-- Slash command toggle: pop out if docked/hidden, close if already popped out
function MapSidePanel:ToggleDetached()
    if not panelFrame then return end
    if isPoppedOut then
        self:CloseDetached()
    else
        self:PopOut()
    end
end

function MapSidePanel:ResetIntegrationMode()
    ResetStandaloneCheck()
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
        if isPoppedOut then
            -- Popped out: just refresh content (map opened, may have new mapID)
            MapSidePanel:RefreshContent()
            return
        end
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
        if isPoppedOut then
            -- Popped out: panel stays visible, no map elements to restore
            return
        end
        -- Restore all map modifications when map closes
        -- Also bump generation to cancel any pending deferred Show callbacks
        panelShowGeneration = panelShowGeneration + 1
        RestoreContentInset()
        RestoreTopBorder()
        RestoreMapElements()
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

    -- /reload restoration: if panel was popped out last session, restore it
    if HA.Addon and HA.Addon.db then
        local vt = HA.Addon.db.profile.vendorTracer
        if vt.sidePanelPoppedOut and vt.showMapSidePanel then
            self:PopOut()
            -- Defer content refresh — map data may not be available during early load
            C_Timer.After(0.5, function()
                MapSidePanel:RefreshContent()
            end)
        end
    end

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
