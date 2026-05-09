--[[
    Homestead - MapSidePanel
    World map side panel showing vendors and collection status for the current zone

    Collapsible panel positioned at the left edge of WorldMapFrame.
    Parented to UIParent (not WorldMapFrame) to prevent displacement when
    the map is maximized, minimized, or closed. Cross-parent anchoring
    keeps the panel flush with the map canvas in docked mode.
    Shows vendor list with collection counts, click-to-waypoint support.

    Toggle button uses the same visual pattern as HandyNotes_TWW
    (Krowi_WorldMapButtons): 32x32 circular minimap-style icon positioned
    at the TOPRIGHT of the map canvas container.
]]

local _, HA = ...

local MapSidePanel = {}
HA.MapSidePanel = MapSidePanel

local L = HA.L or {}

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
local ITEM_RESULT_ICON_SIZE = 20
local ITEM_RESULT_BADGE_SIZE = 14
local ITEM_RESULT_LINE_HEIGHT = 18
local ITEM_GRID_INSET = 24  -- Left indent for item grid (aligns under name text)
local PROGRESS_BAR_HEIGHT = 14
local SEARCH_OPTIONS = { includeItemResults = true }
local PANEL_TOOLTIP_NAME = "HomesteadMapSidePanelTooltip"

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
local itemResultRows = {}
local expandedVendorID = nil  -- npcID of currently expanded vendor (nil = none)
local expandedItemID = nil    -- itemID of currently expanded item result row
local lastRefreshMapID = nil
local isPoppedOut = false
local panelSourceFilter = "all"  -- all|vendor|quest|achievement|profession|event|drop
local sourceFilterDropdown = nil
local progressBar = nil
local progressBarBg = nil
local progressBarLockedFill = nil
local progressBarPurchasableFill = nil
local progressBarText = nil
local scrollContainer = nil  -- Scroll area container (re-anchored by progress bar)

local summaryRows = {}
local currentDisplayLevel = "zone"  -- "zone" | "continent" | "world"
local backBar = nil  -- Back navigation bar (visible at zone/continent level)
local expandedSummaryMapID = nil  -- mapID of expanded summary row (nil = none)
local summarySubRows = {}         -- reusable sub-row frame pool
local iconPool = {}               -- reusable item icon frame pool

-- Search state
local searchEditBox = nil
local searchBar = nil
local searchText = ""
local searchResults = nil            -- Array from SearchProvider or nil
local searchDebounceTimer = nil      -- C_Timer.NewTimer handle (cancelable)
local searchResultsRevision = nil    -- Tracks which index revision results came from
local suppressTextChanged = false    -- Prevents debounce on programmatic SetText

-- HS-019 cycle state: highlight + scroll-to + match cycling for search results.
-- cycleTargets is an array of {kind, index, itemID} populated by Phase 2.
-- All three reset on query change, search clear, or index revision change.
local cycleItemID = nil
local cycleCursor = 0
local cycleTargets = nil

local SOURCE_FILTER_LABELS = {
    all = L["All"] or "All",
    vendor = L["Vendor"] or "Vendor",
    quest = L["Quest"] or "Quest",
    achievement = L["Achievement"] or "Achievement",
    profession = L["Profession"] or "Profession",
    event = L["Event"] or "Event",
    drop = L["Drop"] or "Drop",
}

local DISPLAY_LEVEL_TITLES = {
    zone = L["Zone Collection Progress"] or "Zone Collection Progress",
    continent = L["Continent Collection Progress"] or "Continent Collection Progress",
    world = L["Global Collection Progress"] or "Global Collection Progress",
}

-- Order Hall mapIDs (only the 3 that have housing vendors)
local ORDER_HALL_MAPS = {
    [626] = true,  -- The Hall of Shadows (Rogue)
    [647] = true,  -- Acherus: The Ebon Hold (Death Knight)
    [709] = true,  -- The Wandering Isle (Monk)
    [734] = true,  -- Hall of the Guardian (Mage)
}

local function GetVendorDisplayName(vendor)
    local name = vendor.name or "Unknown"
    if vendor.mapID and ORDER_HALL_MAPS[vendor.mapID] then
        name = name .. " |cff888888(" .. (L["Order Hall"] or "Order Hall") .. ")|r"
    end
    return name
end

-- Map shift state (declared early so preview hooks can reference them)
local mapShifted = false
local savedMapPoint = nil  -- {point, relativeTo, relativePoint, xOfs, yOfs}
local ShiftMapRight  -- forward declaration; body defined in Map Position Shifting section
local SaveDetachedPosition  -- forward declaration; body defined in Pop-Out section

-- Pop-out UI elements (created in CreatePanel, shown/hidden based on state)
local resizeHandle = nil   -- Bottom-edge grip for height resize (detached mode)
local popOutButton = nil   -- Arrow button to detach (docked mode)
local closeButton = nil    -- X button (detached mode)
local reattachButton = nil -- Dock-back button (detached mode)
local pendingDockedAction = nil  -- "apply" | "remove" | "clear" | nil
local panelTooltip = nil

local function GetPanelTooltip()
    if panelTooltip then
        return panelTooltip
    end

    local tooltip = CreateFrame("GameTooltip", PANEL_TOOLTIP_NAME, UIParent, "GameTooltipTemplate")
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetClampedToScreen(true)
    tooltip.isHomesteadManagedTooltip = true
    tooltip.isHomesteadPanelTooltip = true
    panelTooltip = tooltip
    return tooltip
end

local function BeginPanelTooltip(owner, anchor)
    local tooltip = GetPanelTooltip()
    tooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    tooltip:ClearLines()
    return tooltip
end

local function HidePanelTooltip()
    if panelTooltip then
        panelTooltip:Hide()
    end
end

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
                if InCombatLockdown() then
                    pendingDockedAction = "apply"
                    return
                end
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

local function NormalizePanelSourceFilter(sourceFilter)
    local SM = HA.SourceManager
    if SM and SM.NormalizeSourceFilter then
        return SM:NormalizeSourceFilter(sourceFilter)
    end

    if type(sourceFilter) ~= "string" or sourceFilter == "" then
        return "all"
    end

    local lower = sourceFilter:lower()
    if lower == "all" then
        return "all"
    end

    return lower
end

local function GetSourceFilterLabel(sourceFilter)
    local normalized = NormalizePanelSourceFilter(sourceFilter)
    return SOURCE_FILTER_LABELS[normalized] or normalized
end

local function UpdateSourceFilterDropdownText()
    if not sourceFilterDropdown then return end

    local normalized = NormalizePanelSourceFilter(panelSourceFilter)
    local setSelectedValue = _G.UIDropDownMenu_SetSelectedValue
    local setText = _G.UIDropDownMenu_SetText

    if setSelectedValue then
        setSelectedValue(sourceFilterDropdown, normalized)
    end
    if setText then
        setText(sourceFilterDropdown, GetSourceFilterLabel(normalized))
    end
end

local function InitializeSourceFilterDropdown(_, level)
    if level ~= 1 then return end

    local createInfo = _G.UIDropDownMenu_CreateInfo
    local addButton = _G.UIDropDownMenu_AddButton
    if not createInfo or not addButton then return end

    local sourceTypes = {}
    if HA.SourceManager and HA.SourceManager.GetRegisteredSourceTypes then
        sourceTypes = HA.SourceManager:GetRegisteredSourceTypes()
    end

    local info = createInfo()
    info.text = SOURCE_FILTER_LABELS.all
    info.value = "all"
    info.checked = (panelSourceFilter == "all")
    info.func = function(self)
        MapSidePanel:SetSourceFilter(self.value)
    end
    addButton(info, level)

    for _, token in ipairs(sourceTypes) do
        local entryInfo = createInfo()
        entryInfo.text = SOURCE_FILTER_LABELS[token] or token
        entryInfo.value = token
        entryInfo.checked = (token == panelSourceFilter)
        entryInfo.func = function(self)
            MapSidePanel:SetSourceFilter(self.value)
        end
        addButton(entryInfo, level)
    end
end

local function ItemMatchesPanelSourceFilter(itemID, sourceFilter)
    local normalizedFilter = NormalizePanelSourceFilter(sourceFilter)
    if normalizedFilter == "all" then
        return true
    end

    local SM = HA.SourceManager
    if SM and SM.ItemMatchesSourceFilter then
        -- Vendor-scoped list: treat displayed vendor inventory as vendor context.
        return SM:ItemMatchesSourceFilter(itemID, normalizedFilter, true)
    end

    return false
end

-- Gather all unique item IDs for a vendor (static DB + scanned data)
local function GetVendorItemIDs(vendor, sourceFilter)
    if not HA.VendorData or not HA.VendorData.GetMergedItemIDs then
        return {}
    end

    local itemIDs = HA.VendorData:GetMergedItemIDs(vendor)
    if NormalizePanelSourceFilter(sourceFilter) == "all" then
        return itemIDs
    end

    local filtered = {}
    for _, itemID in ipairs(itemIDs) do
        if ItemMatchesPanelSourceFilter(itemID, sourceFilter) then
            filtered[#filtered + 1] = itemID
        end
    end
    return filtered
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
    frame.requirements = nil -- Cached requirement data for lock icon overlay
    frame.isHomesteadPanelIcon = true  -- Marker for Tooltips.lua DetectContext()

    frame:EnableMouse(true)
    -- Tooltip on hover: SetItemByID fires TooltipDataProcessor synchronously,
    -- so Tooltips.lua adds [Homestead] + sources + requirements. We only add
    -- the preview hint here to avoid duplicating requirement lines.
    frame:SetScript("OnEnter", function(self)
        if self.itemID then
            local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
            tooltip:SetItemByID(self.itemID)
            tooltip:AddLine(" ")
            tooltip:AddLine(L["Click to preview"] or "Click to preview", 0.5, 0.5, 0.5)
            tooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", HidePanelTooltip)

    -- Click to open 3D preview
    frame:SetScript("OnMouseUp", function(self)
        if self.itemID then
            ShowItemPreview(self.itemID)
        end
    end)

    return frame
end

local function ResetIcon(icon)
    icon.itemID = nil
    icon.npcID = nil
    icon.requirements = nil
    icon.texture:SetDesaturated(false)
    icon.texture:SetVertexColor(1, 1, 1)
    icon.check:Hide()
    icon.lock:Hide()
    icon:Hide()
    icon:ClearAllPoints()
end

local function AcquireIcon(parent)
    local icon = table.remove(iconPool)
    if not icon then
        icon = CreateItemIcon(parent)
    else
        icon:SetParent(parent)
    end
    icon:Show()
    return icon
end

local function ReleaseIcon(icon)
    ResetIcon(icon)
    table.insert(iconPool, icon)
end

-- Shared count text formatter (green collected / white total / red locked).
local function FormatPurchasabilityCountText(collected, total, locked)
    return BC.FormatCountText(collected, total, locked)
end

-- Check if an item has unmet requirements the player hasn't satisfied
local function GetUnmetRequirements(itemID, npcID)
    local SM = HA.SourceManager
    if not SM then return nil end
    local reqs = SM:GetRequirements(itemID, npcID)
    if not reqs or #reqs == 0 then return nil end

    -- Use vendor-scoped availability classification when possible.
    -- Only confirmed false (not nil/unknown) counts as locked.
    local state = SM.GetVendorItemAvailabilityState
        and SM:GetVendorItemAvailabilityState(itemID, npcID)
        or nil

    if state == "locked" then
        return reqs, reqs
    end

    return nil, reqs
end

local function HideItemGrid(row)
    if row.itemGrid then
        -- Release all icons back to the pool
        if row.itemIcons then
            for i = #row.itemIcons, 1, -1 do
                ReleaseIcon(row.itemIcons[i])
                row.itemIcons[i] = nil
            end
        end
        row.itemGrid:Hide()
    end
end

-- Populate the item grid for a vendor row. Returns total height of the grid.
local function PopulateItemGrid(row, vendor, sourceFilter, highlightItems)
    local itemIDs = GetVendorItemIDs(vendor, sourceFilter)
    if #itemIDs == 0 then
        HideItemGrid(row)
        return 0
    end

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

    -- Ensure enough icon frames (acquire from pool)
    while #icons < #itemIDs do
        icons[#icons + 1] = AcquireIcon(grid)
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

        -- Dim non-matching items in search mode
        if highlightItems and not highlightItems[itemID] then
            icon.texture:SetDesaturated(true)
            icon.texture:SetVertexColor(0.4, 0.4, 0.4)
            icon.border:SetColorTexture(0.2, 0.2, 0.2, 0.5)
            icon.check:Hide()
            icon.lock:Hide()
        end

        -- HS-019: cycle-hit override wins over dim, owned, locked, and unowned
        -- visuals so the active cycle position reads as the panel's focal point.
        -- Pin-color tint is the v1 visual; subject to Gate 2 review.
        local cycleTarget = cycleTargets and cycleTargets[cycleCursor + 1]
        if cycleTarget
                and cycleTarget.kind == "grid"
                and cycleTarget.itemID == itemID
                and cycleTarget.npcID == npcID then
            icon.texture:SetDesaturated(false)
            icon.texture:SetVertexColor(1, 1, 1)
            local r, g, b = HA.PinFrameFactory:GetPinColor()
            icon.border:SetColorTexture(r, g, b, 1)
            icon.check:Hide()
            icon.lock:Hide()
        end

        icon:Show()
    end

    -- Release excess icons back to pool
    for i = #icons, #itemIDs + 1, -1 do
        ReleaseIcon(icons[i])
        icons[i] = nil
    end

    -- Calculate grid height
    local numRows = math.ceil(#itemIDs / iconsPerRow)
    local gridHeight = numRows * (ITEM_ICON_SIZE + ITEM_ICON_PAD)
    grid:SetHeight(gridHeight)
    grid:Show()

    return gridHeight + ITEM_ICON_PAD  -- Extra padding below grid
end

-------------------------------------------------------------------------------
-- Item Search Result Rows
-------------------------------------------------------------------------------

local function GetSourceTypeLabel(sourceType)
    local SM = HA.SourceManager
    local normalizedType = sourceType
    if SM and SM.NormalizeSourceType then
        normalizedType = SM:NormalizeSourceType(sourceType) or sourceType
    end
    return SOURCE_FILTER_LABELS[normalizedType] or normalizedType or "Source"
end

local function GetSourceBadgeAtlas(sourceType)
    local SM = HA.SourceManager
    local normalizedType = sourceType
    if SM and SM.NormalizeSourceType then
        normalizedType = SM:NormalizeSourceType(sourceType) or sourceType
    end

    local badgeAtlases = HA.Constants and HA.Constants.SourceBadgeAtlas
    return badgeAtlases and badgeAtlases[normalizedType] or nil
end

local function ApplySourceBadge(texture, sourceType)
    if not texture or not sourceType then
        if texture then texture:Hide() end
        return
    end

    local atlas = GetSourceBadgeAtlas(sourceType)
    if atlas then
        texture:SetTexture(nil)
        texture:SetAtlas(atlas, false)
        texture:SetTexCoord(0, 1, 0, 1)
    else
        local SM = HA.SourceManager
        local icon = SM and SM.GetSourceTypeIcon and SM:GetSourceTypeIcon(sourceType)
        texture:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    texture:Show()
end

local function GetSourceLocationText(data)
    if type(data) ~= "table" then return nil end

    if data.subzone and data.zone then
        return data.subzone .. ", " .. data.zone
    end

    return data.zone or data.subzone
end

local function FormatSourceSummary(source)
    if not source then
        return "Source details unavailable"
    end

    local sourceType = source.type or source.sourceType
    local data = source.data or source
    local label = GetSourceTypeLabel(sourceType)
    local detail

    if sourceType == "vendor" then
        local vendorName = data.name or data.vendorName or "Unknown Vendor"
        local location = GetSourceLocationText(data)
        detail = location and (vendorName .. " (" .. location .. ")") or vendorName
    elseif sourceType == "quest" then
        detail = data.questName or "Unknown Quest"
    elseif sourceType == "achievement" then
        detail = data.achievementName or "Unknown Achievement"
    elseif sourceType == "profession" then
        local recipeName = data.recipeName or data.name
        local professionName = data.skillTier or data.profession
        if recipeName and professionName then
            detail = recipeName .. " (" .. professionName .. ")"
        else
            detail = recipeName or professionName or "Unknown Recipe"
        end
    elseif sourceType == "event" then
        local eventName = data.event or data.vendorName or "Unknown Event"
        local vendorName = data.vendorName
        local location = GetSourceLocationText(data)
        if vendorName and vendorName ~= eventName then
            local vendorDisplay = location and (vendorName .. " - " .. location) or vendorName
            detail = eventName .. " / " .. vendorDisplay
        else
            detail = location and (eventName .. " (" .. location .. ")") or eventName
        end
    elseif sourceType == "drop" then
        local mobName = data.mobName or "Unknown Drop"
        local location = data.zone
        detail = location and (mobName .. " (" .. location .. ")") or mobName
    elseif sourceType == "shop" then
        local method = data.method or "hearthsteel"
        if method == "hearthsteel" and data.cost then
            detail = data.cost .. " Hearthsteel"
        else
            detail = data.name or "In-Game Shop"
        end
        if data.expires then
            detail = detail .. " (until " .. data.expires .. ")"
        end
    else
        detail = data.name or data.sourceText or "Unknown Source"
    end

    return label .. ": " .. detail
end

local function GetDisplaySourcesForItem(itemID, sourceFilter)
    local SM = HA.SourceManager
    if not itemID or not SM or not SM.GetAllSources then
        return {}
    end

    local allSources = SM:GetAllSources(itemID) or {}
    local normalizedFilter = NormalizePanelSourceFilter(sourceFilter)
    if normalizedFilter == "all" then
        return allSources
    end

    local filteredSources = {}
    for _, source in ipairs(allSources) do
        local normalizedType = source.type
        if SM.NormalizeSourceType then
            normalizedType = SM:NormalizeSourceType(source.type) or source.type
        end
        if normalizedType == normalizedFilter then
            filteredSources[#filteredSources + 1] = source
        end
    end

    return filteredSources
end

local function GetPreferredDisplaySource(result, displaySources)
    if not displaySources or #displaySources == 0 then return nil end
    if not result then return displaySources[1] end

    local SM = HA.SourceManager
    local desiredType = result.sourceType
    if SM and SM.NormalizeSourceType then
        desiredType = SM:NormalizeSourceType(desiredType) or desiredType
    end

    if result.sourceData then
        for _, source in ipairs(displaySources) do
            if source.data == result.sourceData then
                return source
            end
        end
    end

    if desiredType then
        for _, source in ipairs(displaySources) do
            local normalizedType = source.type
            if SM and SM.NormalizeSourceType then
                normalizedType = SM:NormalizeSourceType(source.type) or source.type
            end
            if normalizedType == desiredType then
                return source
            end
        end
    end

    return displaySources[1]
end

local function CreateItemResultSourceLine(parent)
    local line = CreateFrame("Frame", nil, parent)
    line:SetHeight(ITEM_RESULT_LINE_HEIGHT)

    local badge = line:CreateTexture(nil, "ARTWORK")
    badge:SetSize(ITEM_RESULT_BADGE_SIZE, ITEM_RESULT_BADGE_SIZE)
    badge:SetPoint("LEFT", line, "LEFT", 0, 0)
    line.badge = badge

    local text = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", badge, "RIGHT", 6, 0)
    text:SetPoint("RIGHT", line, "RIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    line.text = text

    return line
end

local function HideItemSourceList(row)
    if row and row.sourcesFrame then
        row.sourcesFrame:Hide()
    end

    if row and row.sourceLines then
        for _, line in ipairs(row.sourceLines) do
            line:Hide()
        end
    end
end

local function PopulateItemSourceList(row, itemID, sourceFilter)
    if not row then return 0 end

    if not row.sourcesFrame then
        row.sourcesFrame = CreateFrame("Frame", nil, row)
        row.sourcesFrame:SetPoint("TOPLEFT", row, "TOPLEFT", PADDING + ITEM_RESULT_ICON_SIZE + 8, -ROW_HEIGHT - 2)
        row.sourcesFrame:SetPoint("TOPRIGHT", row, "TOPRIGHT", -PADDING, -ROW_HEIGHT - 2)
        row.sourceLines = {}
    end

    local sourcesFrame = row.sourcesFrame
    local sourceLines = row.sourceLines
    local displaySources = GetDisplaySourcesForItem(itemID, sourceFilter)
    local renderedCount

    if #displaySources == 0 then
        renderedCount = 1
        if not sourceLines[1] then
            sourceLines[1] = CreateItemResultSourceLine(sourcesFrame)
        end

        local line = sourceLines[1]
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", sourcesFrame, "TOPLEFT", 0, 0)
        line:SetPoint("TOPRIGHT", sourcesFrame, "TOPRIGHT", 0, 0)
        line.badge:Hide()

        if NormalizePanelSourceFilter(sourceFilter) == "all" then
            line.text:SetText("Source details unavailable")
        else
            line.text:SetText("No matching " .. GetSourceFilterLabel(sourceFilter):lower() .. " sources")
        end

        line.text:SetTextColor(0.5, 0.5, 0.5)
        line:Show()
    else
        while #sourceLines < #displaySources do
            sourceLines[#sourceLines + 1] = CreateItemResultSourceLine(sourcesFrame)
        end

        for i, source in ipairs(displaySources) do
            local line = sourceLines[i]
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", sourcesFrame, "TOPLEFT", 0, -((i - 1) * ITEM_RESULT_LINE_HEIGHT))
            line:SetPoint("TOPRIGHT", sourcesFrame, "TOPRIGHT", 0, -((i - 1) * ITEM_RESULT_LINE_HEIGHT))
            ApplySourceBadge(line.badge, source.type)
            line.text:SetText(FormatSourceSummary(source))
            line.text:SetTextColor(0.8, 0.8, 0.8)
            line:Show()
        end

        renderedCount = #displaySources
    end

    for i = renderedCount + 1, #sourceLines do
        sourceLines[i]:Hide()
    end

    local totalHeight = renderedCount * ITEM_RESULT_LINE_HEIGHT + 4
    sourcesFrame:SetHeight(totalHeight)
    sourcesFrame:Show()
    return totalHeight
end

-- HS-019: Build the ordered list of positions where `itemID` appears in the
-- current search results. Vendor-grid positions first (in result order), then
-- the item-first row last.
--
-- `index` is the per-type row position (vendor-row count or item-row count),
-- matching how RefreshSearchResults assigns vendorRows[vendorCount] and
-- itemResultRows[itemCount]. `npcID` is stored on grid targets so Phase 4's
-- highlight predicate and FocusTarget's vendor-expand step don't need to
-- re-walk searchResults to resolve the vendor.
local function BuildCycleTargets(itemID)
    local list = {}
    if not itemID or not searchResults then return list end

    local vendorCount = 0
    for _, result in ipairs(searchResults) do
        if result.resultType == "vendor" then
            vendorCount = vendorCount + 1
            if result.matchedItems
                    and result.matchedItems[itemID]
                    and result.vendor then
                list[#list + 1] = {
                    kind = "grid",
                    index = vendorCount,
                    itemID = itemID,
                    npcID = result.vendor.npcID,
                }
            end
        end
    end

    local itemCount = 0
    for _, result in ipairs(searchResults) do
        if result.resultType == "item" then
            itemCount = itemCount + 1
            if result.itemID == itemID then
                list[#list + 1] = {
                    kind = "itemRow",
                    index = itemCount,
                    itemID = itemID,
                }
            end
        end
    end

    return list
end

-- HS-019: Scroll the panel so the target row's top sits ~8px below the
-- panel header. Silently no-ops on hidden frames (e.g. faction filter
-- toggled mid-cycle) and clamps to scrollChild bounds.
local function ScrollToTarget(target)
    if not target then return end

    local frame
    if target.kind == "grid" then
        frame = vendorRows[target.index]
    else
        frame = itemResultRows[target.index]
    end
    if not frame or not frame:IsShown() then return end
    if not scrollFrame or not scrollChild then return end

    local panelTop = scrollFrame:GetTop() or 0
    local frameTop = frame:GetTop() or panelTop
    local current = scrollFrame:GetVerticalScroll() or 0
    local desired = current + (panelTop - frameTop) - 8  -- 8px header offset
    local maxScroll = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
    scrollFrame:SetVerticalScroll(math.min(maxScroll, math.max(0, desired)))
end

-- HS-019: Click-time focus: expand the vendor row if the target needs the
-- grid rendered, refresh the panel once, then scroll. Callers update cycle
-- state first; this function is the single repaint+scroll point so the
-- click handler doesn't have to manage RefreshContent itself.
local function FocusTarget(target)
    if target and target.kind == "grid" and expandedVendorID ~= target.npcID then
        expandedVendorID = target.npcID
    end
    MapSidePanel:RefreshContent()
    if target then ScrollToTarget(target) end
end

local function HideAllItemResultRows()
    for _, row in ipairs(itemResultRows) do
        row:Hide()
        HideItemSourceList(row)
    end
end

local function CreateItemResultRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)

    local iconBorder = row:CreateTexture(nil, "BACKGROUND")
    iconBorder:SetSize(ITEM_RESULT_ICON_SIZE + 2, ITEM_RESULT_ICON_SIZE + 2)
    iconBorder:SetPoint("TOPLEFT", row, "TOPLEFT", PADDING, -7)
    iconBorder:SetColorTexture(0.25, 0.25, 0.25, 1)
    row.iconBorder = iconBorder

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ITEM_RESULT_ICON_SIZE, ITEM_RESULT_ICON_SIZE)
    icon:SetPoint("TOPLEFT", row, "TOPLEFT", PADDING + 1, -8)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
    nameText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -PADDING, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    local sourceBadge = row:CreateTexture(nil, "ARTWORK")
    sourceBadge:SetSize(ITEM_RESULT_BADGE_SIZE, ITEM_RESULT_BADGE_SIZE)
    sourceBadge:SetPoint("TOPLEFT", row, "TOPLEFT", PADDING + ITEM_RESULT_ICON_SIZE + 8, -20)
    row.sourceBadge = sourceBadge

    local sourceText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sourceText:SetPoint("LEFT", sourceBadge, "RIGHT", 6, 0)
    sourceText:SetPoint("RIGHT", row, "RIGHT", -PADDING, 0)
    sourceText:SetJustifyH("LEFT")
    sourceText:SetWordWrap(false)
    row.sourceText = sourceText

    local sep = row:CreateTexture(nil, "BACKGROUND")
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT", 4, 0)
    sep:SetPoint("BOTTOMRIGHT", -4, 0)
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.4)

    row.itemID = nil
    row.result = nil

    row:RegisterForClicks("AnyUp")

    row:SetScript("OnClick", function(self)
        if not self.itemID then return end

        -- HS-019: same-target click advances the cycle cursor without
        -- re-toggling expansion, so repeated clicks walk through positions
        -- instead of fighting the expand/collapse legacy.
        if cycleItemID == self.itemID
                and cycleTargets
                and #cycleTargets > 1 then
            cycleCursor = (cycleCursor + 1) % #cycleTargets
            FocusTarget(cycleTargets[cycleCursor + 1])
            return
        end

        -- Toggle expansion
        local nowExpanded
        if expandedItemID == self.itemID then
            expandedItemID = nil
            nowExpanded = false
        else
            expandedItemID = self.itemID
            nowExpanded = true
        end

        -- HS-019: cycle is tied to expansion. Expand initiates cycle on
        -- this itemID; collapse clears cycle so the dismiss reads cleanly.
        if nowExpanded then
            cycleItemID = self.itemID
            cycleCursor = 0
            cycleTargets = BuildCycleTargets(self.itemID)
            FocusTarget(cycleTargets[1])
        else
            cycleItemID = nil
            cycleCursor = 0
            cycleTargets = nil
            MapSidePanel:RefreshContent()
        end
    end)

    row:SetScript("OnEnter", function(self)
        if not self.itemID then return end

        local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
        tooltip:SetItemByID(self.itemID)
        tooltip:AddLine(" ")
        if expandedItemID == self.itemID then
            tooltip:AddLine("Click to collapse sources", 0.5, 0.5, 0.5)
        else
            tooltip:AddLine("Click to show all sources", 0.5, 0.5, 0.5)
        end
        tooltip:Show()
    end)

    row:SetScript("OnLeave", HidePanelTooltip)

    return row
end

local function PopulateItemResultRow(row, result, sourceFilter)
    if not row or not result then return false end

    local itemID = result.itemID
    local itemName = result.itemName or C_Item.GetItemNameByID(itemID) or ("Item " .. tostring(itemID))
    local itemIcon = C_Item.GetItemIconByID(itemID)
    local displaySources = GetDisplaySourcesForItem(itemID, sourceFilter)
    local preferredSource = GetPreferredDisplaySource(result, displaySources)

    row.itemID = itemID
    row.result = result
    row.icon:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.nameText:SetText(itemName)

    if IsItemOwned(itemID) then
        row.iconBorder:SetColorTexture(0.2, 0.7, 0.2, 1)
        row.nameText:SetTextColor(0.7, 1, 0.7)
    else
        row.iconBorder:SetColorTexture(0.6, 0.5, 0.2, 1)
        row.nameText:SetTextColor(1, 1, 1)
    end

    -- HS-019: cycle-hit override on the item-first row's top portion only
    -- (icon border). Expanded source-list area is unaffected.
    local cycleTarget = cycleTargets and cycleTargets[cycleCursor + 1]
    if cycleTarget
            and cycleTarget.kind == "itemRow"
            and cycleTarget.itemID == itemID then
        local r, g, b = HA.PinFrameFactory:GetPinColor()
        row.iconBorder:SetColorTexture(r, g, b, 1)
    end

    if preferredSource then
        ApplySourceBadge(row.sourceBadge, preferredSource.type)
        row.sourceText:SetText(FormatSourceSummary(preferredSource))
        row.sourceText:SetTextColor(0.8, 0.8, 0.8)
    else
        row.sourceBadge:Hide()
        if NormalizePanelSourceFilter(sourceFilter) == "all" then
            row.sourceText:SetText("Source details unavailable")
        else
            row.sourceText:SetText("No matching " .. GetSourceFilterLabel(sourceFilter):lower() .. " sources")
        end
        row.sourceText:SetTextColor(0.5, 0.5, 0.5)
    end

    local isExpanded = (expandedItemID == itemID)
    if isExpanded then
        local detailHeight = PopulateItemSourceList(row, itemID, sourceFilter)
        row:SetHeight(ROW_HEIGHT + detailHeight)
    else
        HideItemSourceList(row)
        row:SetHeight(ROW_HEIGHT)
    end

    return isExpanded
end

-------------------------------------------------------------------------------
-- Search Helpers
-------------------------------------------------------------------------------

local function ExecuteSearch()
    searchDebounceTimer = nil
    local SP = HA.SearchProvider
    if not SP then return end
    local query = searchEditBox and searchEditBox:GetText() or ""
    query = query:match("^%s*(.-)%s*$") or ""  -- trim
    searchText = query
    cycleItemID = nil
    cycleCursor = 0
    cycleTargets = nil
    if query == "" then
        searchResults = nil
        searchResultsRevision = nil
    else
        searchResults = SP:Search(query, SEARCH_OPTIONS)
        searchResultsRevision = SP:GetRevision()
    end
    MapSidePanel:RefreshContent()
end

local function ClearSearch(refreshNow)
    searchText = ""
    searchResults = nil
    searchResultsRevision = nil
    expandedItemID = nil
    cycleItemID = nil
    cycleCursor = 0
    cycleTargets = nil
    if searchDebounceTimer then searchDebounceTimer:Cancel(); searchDebounceTimer = nil end
    if searchEditBox then
        suppressTextChanged = true
        searchEditBox:SetText("")
        suppressTextChanged = false
    end
    HideAllItemResultRows()
    if refreshNow then
        MapSidePanel:RefreshContent()
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

        -- Search mode: toggle expand + navigate to vendor's zone (with
        -- HS-019 cycle layer when the row's matched-items set has a
        -- single entry — that's when "this row matches one item" is
        -- unambiguous enough to drive cycling).
        if self.searchMode then
            -- HS-019: derive the unique matched itemID for cycle eligibility.
            local uniqueItemID = nil
            if self.searchMatchedItems then
                local count = 0
                for id in pairs(self.searchMatchedItems) do
                    count = count + 1
                    uniqueItemID = id
                    if count > 1 then uniqueItemID = nil; break end
                end
            end

            -- HS-019: same-target advance — no toggle, no map nav, just cursor.
            if uniqueItemID
                    and cycleItemID == uniqueItemID
                    and cycleTargets
                    and #cycleTargets > 1 then
                cycleCursor = (cycleCursor + 1) % #cycleTargets
                FocusTarget(cycleTargets[cycleCursor + 1])
                return
            end

            -- Existing search-mode toggle + map nav
            local npcID = self.vendor.npcID
            local nowExpanded
            if expandedVendorID == npcID then
                expandedVendorID = nil  -- collapse
                nowExpanded = false
            else
                expandedVendorID = npcID
                nowExpanded = true
                -- Navigate map to vendor's zone
                local VF = HA.VendorFilter
                if VF then
                    local _, vendorMapID = VF.GetBestVendorCoordinates(self.vendor)
                    if vendorMapID and WorldMapFrame then
                        if not WorldMapFrame:IsShown() then
                            WorldMapFrame:Show()
                        end
                        WorldMapFrame:SetMapID(vendorMapID)
                    end
                end
            end

            -- HS-019: cycle is tied to expansion + unambiguous match. Expand
            -- with a unique itemID initiates cycle; collapse or multi-match
            -- expansion clears any active cycle for clean dismiss/handoff.
            if nowExpanded and uniqueItemID then
                cycleItemID = uniqueItemID
                cycleCursor = 0
                cycleTargets = BuildCycleTargets(uniqueItemID)
                FocusTarget(cycleTargets[1])
            else
                cycleItemID = nil
                cycleCursor = 0
                cycleTargets = nil
                MapSidePanel:RefreshContent()
            end
            return
        end

        -- Normal mode: toggle item grid expansion
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
        local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
        tooltip:AddLine(self.vendor.name or "Unknown", 1, 1, 1)
        if self.vendor.subzone then
            tooltip:AddLine(self.vendor.subzone .. " (" .. (self.vendor.zone or "?") .. ")", 0.7, 0.7, 0.7)
        elseif self.vendor.zone then
            tooltip:AddLine(self.vendor.zone, 0.7, 0.7, 0.7)
        end
        if self.vendor.mapID and ORDER_HALL_MAPS[self.vendor.mapID] then
            tooltip:AddLine("Legion Order Hall", 1, 0.82, 0)
        end
        if self.vendor.faction and self.vendor.faction ~= "Neutral" then
            local factionColor = self.vendor.faction == "Alliance" and {0, 0.44, 0.87} or {0.77, 0.12, 0.23}
            tooltip:AddLine(self.vendor.faction, unpack(factionColor))
        end
        if HA.VendorFilter and HA.VendorFilter.IsOppositeFaction
                and HA.VendorFilter.IsOppositeFaction(self.vendor) then
            tooltip:AddLine("Cannot access - opposite faction vendor", 0.8, 0.3, 0.3)
        end
        if self.total and self.total > 0 then
            local stats = BC:GetVendorStats(self.vendor, panelSourceFilter)
            BC.AddSummaryLine(tooltip, stats.collected, stats.total, stats.locked, stats.unverified)
        end
        tooltip:AddLine(" ")
        if self.searchMode then
            if self.vendor.expansion then
                tooltip:AddLine(self.vendor.expansion, 0.5, 0.5, 0.5)
            end
            if expandedVendorID == self.vendor.npcID then
                tooltip:AddLine("Click to collapse items", 0.5, 0.5, 0.5)
            else
                tooltip:AddLine("Click to show items and go to vendor", 0.5, 0.5, 0.5)
            end
        else
            tooltip:AddLine("Click to show items", 0.5, 0.5, 0.5)
        end
        tooltip:Show()
        -- Highlight the corresponding map pin at zone level
        if HA.VendorMapPins and HA.VendorMapPins.HighlightVendor and self.vendor.npcID then
            HA.VendorMapPins:HighlightVendor(self.vendor.npcID)
        end
    end)

    row:SetScript("OnLeave", function()
        HidePanelTooltip()
        if HA.VendorMapPins and HA.VendorMapPins.ClearHighlight then
            HA.VendorMapPins:ClearHighlight()
        end
    end)

    return row
end

-------------------------------------------------------------------------------
-- Summary Row Creation (continent/world level)
-------------------------------------------------------------------------------

local function CreateSummaryRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)

    -- Highlight on hover
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)

    -- Expand/collapse arrow icon (toggles between forward and down)
    local arrow = row:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(12, 12)
    arrow:SetPoint("TOPLEFT", PADDING, -4)
    arrow:SetAtlas("common-icon-forwardarrow")
    row.arrow = arrow

    -- Navigate arrow button (overlaid on right side, navigates to zone/continent)
    local navButton = CreateFrame("Button", nil, row)
    navButton:SetSize(20, 20)
    navButton:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    local navArrow = navButton:CreateTexture(nil, "ARTWORK")
    navArrow:SetSize(12, 12)
    navArrow:SetPoint("CENTER")
    navArrow:SetAtlas("common-icon-forwardarrow")
    local navHL = navButton:CreateTexture(nil, "HIGHLIGHT")
    navHL:SetAllPoints()
    navHL:SetColorTexture(0.4, 0.4, 0.4, 0.4)
    navButton:SetScript("OnClick", function()
        if row.targetMapID and WorldMapFrame:IsShown() then
            WorldMapFrame:SetMapID(row.targetMapID)
        end
    end)
    navButton:SetScript("OnEnter", function(self)
        local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
        local level = currentDisplayLevel
        if level == "world" then
            tooltip:SetText("Navigate to continent")
        else
            tooltip:SetText("Navigate to zone")
        end
        tooltip:Show()
    end)
    navButton:SetScript("OnLeave", HidePanelTooltip)
    row.navButton = navButton

    -- Zone/continent name (leave room for nav button)
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOPLEFT", arrow, "TOPRIGHT", 6, 0)
    nameText:SetPoint("RIGHT", navButton, "LEFT", -2, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- Summary line (vendor count + collection)
    local summaryLine = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summaryLine:SetPoint("TOPLEFT", arrow, "BOTTOMRIGHT", 6, -2)
    summaryLine:SetPoint("RIGHT", navButton, "LEFT", -2, 0)
    summaryLine:SetJustifyH("LEFT")
    row.summaryLine = summaryLine

    -- Separator line
    local sep = row:CreateTexture(nil, "BACKGROUND")
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT", 4, 0)
    sep:SetPoint("BOTTOMRIGHT", -4, 0)
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.4)

    -- Navigation data
    row.targetMapID = nil
    row.vendorCount = 0
    row.collectedItems = 0
    row.totalItems = 0

    row:RegisterForClicks("AnyUp")

    row:SetScript("OnClick", function(self, mouseButton)
        if not self.targetMapID then return end
        if mouseButton == "RightButton" then
            -- Right-click: navigate
            if WorldMapFrame:IsShown() then
                WorldMapFrame:SetMapID(self.targetMapID)
            else
                -- Detached mode: navigate via internal state
                lastRefreshMapID = self.targetMapID
                MapSidePanel:RefreshContent()
            end
        else
            -- Left-click: toggle expand/collapse
            if expandedSummaryMapID == self.targetMapID then
                expandedSummaryMapID = nil
            else
                expandedSummaryMapID = self.targetMapID
            end
            MapSidePanel:RefreshContent()
        end
    end)

    row:SetScript("OnEnter", function(self)
        local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
        tooltip:AddLine(self.nameText:GetText() or "Unknown", 1, 1, 1)
        if self.vendorCount > 0 then
            tooltip:AddLine(string.format("%d vendors", self.vendorCount), 0.7, 0.7, 0.7)
        end
        if self.totalItems > 0 then
            BC.AddSummaryLine(tooltip, self.collectedItems, self.totalItems, self.lockedItems, self.unverifiedItems)
        end
        tooltip:AddLine(" ")
        tooltip:AddLine("Click to expand | Right-click to navigate", 0.5, 0.5, 0.5)
        tooltip:Show()
    end)

    row:SetScript("OnLeave", HidePanelTooltip)

    return row
end

local function HideAllSummaryRows()
    for _, row in ipairs(summaryRows) do
        row:Hide()
    end
end

local function HideAllSummarySubRows()
    for _, row in ipairs(summarySubRows) do
        row:Hide()
    end
end

-- Unified cleanup helper: hides all non-vendor content (summary rows, sub-rows,
-- back bar). Called in every early-return and level-switch path.
local function HideAllNonVendorContent()
    HideAllSummaryRows()
    HideAllSummarySubRows()
    if backBar then backBar:Hide() end
    if HA.VendorMapPins then HA.VendorMapPins:ClearHighlight() end
end

-------------------------------------------------------------------------------
-- Summary Sub-Row Creation (expandable children of summary rows)
-------------------------------------------------------------------------------

local SUB_ROW_HEIGHT = 24
local SUB_ROW_INDENT = 20

local function CreateSummarySubRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(SUB_ROW_HEIGHT)
    row:RegisterForClicks("AnyUp")

    -- Subtle dark background for visual nesting
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.15, 0.3)

    -- Highlight on hover
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)

    -- Small icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(12, 12)
    icon:SetPoint("LEFT", SUB_ROW_INDENT, 0)
    icon:SetAtlas("poi-door")
    icon:SetDesaturated(true)
    row.icon = icon

    -- Name text
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- Count text (right side)
    local countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("RIGHT", row, "RIGHT", -PADDING, 0)
    countText:SetJustifyH("RIGHT")
    row.countText = countText

    -- Clamp name text to not overlap count
    nameText:SetPoint("RIGHT", countText, "LEFT", -4, 0)

    -- Separator
    local sep = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT", SUB_ROW_INDENT, 0)
    sep:SetPoint("BOTTOMRIGHT", -4, 0)
    sep:SetColorTexture(0.25, 0.25, 0.25, 0.3)

    row.vendor = nil      -- vendor reference (for zone expansion sub-rows)
    row.targetMapID = nil  -- zone mapID to navigate to on click

    row:SetScript("OnClick", function(self)
        if not self.targetMapID then return end
        -- Pre-set expandedVendorID so the item grid opens at zone level
        if self.vendor and self.vendor.npcID then
            expandedVendorID = self.vendor.npcID
        end
        if WorldMapFrame:IsShown() then
            WorldMapFrame:SetMapID(self.targetMapID)
        else
            -- Detached mode: navigate via internal state
            lastRefreshMapID = self.targetMapID
            MapSidePanel:RefreshContent()
        end
    end)

    row:SetScript("OnEnter", function(self)
        if not self.tooltipText then return end
        local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
        tooltip:AddLine(self.tooltipText, 1, 1, 1)
        if self.isOrderHall then
            tooltip:AddLine("Legion Order Hall", 1, 0.82, 0)
        end
        if self.tooltipSub then
            tooltip:AddLine(self.tooltipSub, 0.7, 0.7, 0.7)
        end
        tooltip:AddLine(" ")
        if self.vendor then
            tooltip:AddLine("Click to view items", 0.5, 0.5, 0.5)
        else
            tooltip:AddLine("Click to view zone", 0.5, 0.5, 0.5)
        end
        tooltip:Show()
    end)
    row:SetScript("OnLeave", HidePanelTooltip)

    return row
end

-- Get or create a sub-row from the pool
local function GetSummarySubRow(index)
    if not summarySubRows[index] then
        summarySubRows[index] = CreateSummarySubRow(scrollChild)
    end
    return summarySubRows[index]
end

-- Populate zone expansion: show vendor sub-rows for a zone at continent level.
-- Uses same data source as badge calculation (GetAllVendors + VendorFilter).
-- Returns total height consumed.
local function PopulateZoneExpansion(zoneMapID, yOffsetStart, subRowIndex)
    if not VendorData or not BC then return 0, subRowIndex end

    local VF = HA.VendorFilter
    local allVendors = VendorData:GetAllVendors()
    local showOpposite = VF.ShouldShowOppositeFaction()

    -- Build set of maps to include (canonical + siblings for merged zones)
    local targetMaps = {[zoneMapID] = true}
    local Constants = HA.Constants
    if Constants and Constants.VerticalSiblings and Constants.VerticalSiblings[zoneMapID] then
        for sibID, _ in pairs(Constants.VerticalSiblings[zoneMapID]) do
            targetMaps[sibID] = true
        end
    end

    -- Gather vendors in this zone using same logic as badge calculation
    local zoneVendors = {}
    for _, vendor in ipairs(allVendors) do
        if not VF.ShouldHideVendor(vendor) then
            local coords, vendorMapID = VF.GetBestVendorCoordinates(vendor)
            if coords and targetMaps[vendorMapID] then
                local canAccess = VF.CanAccessVendor(vendor)
                local isOpposite = VF.IsOppositeFaction(vendor)
                if canAccess or (isOpposite and showOpposite) then
                    zoneVendors[#zoneVendors + 1] = vendor
                end
            end
        end
    end

    table.sort(zoneVendors, function(a, b)
        return (a.name or "") < (b.name or "")
    end)

    local totalHeight = 0
    for _, vendor in ipairs(zoneVendors) do
        local subRow = GetSummarySubRow(subRowIndex)
        subRow.vendor = vendor
        -- Use vendor's actual mapID for navigation (important for merged sibling zones)
        local _, vendorMapID = VendorFilter.GetBestVendorCoordinates(vendor)
        subRow.targetMapID = vendorMapID or zoneMapID
        subRow.tooltipText = vendor.name or "Unknown"
        subRow.isOrderHall = vendor.mapID and ORDER_HALL_MAPS[vendor.mapID] or false

        subRow.nameText:SetText(GetVendorDisplayName(vendor))
        subRow.nameText:SetTextColor(0.9, 0.9, 0.9)

        -- Collection counts using same filter as panel
        local stats = BC:GetVendorStats(vendor, panelSourceFilter)
        if (stats.total or 0) > 0 then
            subRow.countText:SetText(FormatPurchasabilityCountText(stats.collected, stats.total, stats.locked))
            subRow.countText:SetTextColor(1, 1, 1)
            subRow.tooltipSub = string.format("Collected: %d/%d", stats.collected or 0, stats.total or 0)
        else
            subRow.countText:SetText("")
            subRow.tooltipSub = nil
        end

        -- Pin color for icon
        local r, g, b = HA.PinFrameFactory:GetPinColor()
        subRow.icon:SetVertexColor(r, g, b)

        subRow:ClearAllPoints()
        subRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffsetStart - totalHeight)
        subRow:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -yOffsetStart - totalHeight)
        subRow:Show()

        totalHeight = totalHeight + SUB_ROW_HEIGHT
        subRowIndex = subRowIndex + 1
    end

    return totalHeight, subRowIndex
end

-- Populate continent expansion: show zone sub-rows for a continent at world level.
-- Returns total height consumed.
local function PopulateContinentExpansion(continentMapID, yOffsetStart, subRowIndex)
    if not BC then return 0, subRowIndex end

    local zoneCounts = BC:GetZoneVendorCounts(continentMapID, panelSourceFilter)

    -- Build sorted zone list
    local zoneList = {}
    for zoneMapID, data in pairs(zoneCounts) do
        zoneList[#zoneList + 1] = { mapID = zoneMapID, data = data }
    end
    table.sort(zoneList, function(a, b)
        return (a.data.zoneName or "") < (b.data.zoneName or "")
    end)

    local totalHeight = 0
    for _, entry in ipairs(zoneList) do
        local data = entry.data
        local dataVendorCount = data.vendorCount or 0
        local dataCollected = data.collectedItems or 0
        local dataTotal = data.totalItems or 0
        local subRow = GetSummarySubRow(subRowIndex)
        subRow.vendor = nil
        subRow.targetMapID = entry.mapID
        subRow.tooltipText = data.zoneName or "Unknown"
        subRow.isOrderHall = false

        subRow.nameText:SetText(data.zoneName or "Unknown")
        subRow.nameText:SetTextColor(0.9, 0.9, 0.9)

        -- Zone collection counts
        local dataLocked = data.lockedItems or 0
        if dataTotal > 0 then
            subRow.countText:SetText(FormatPurchasabilityCountText(dataCollected, dataTotal, dataLocked))
            subRow.countText:SetTextColor(1, 1, 1)
            subRow.tooltipSub = string.format("%d vendors | %d/%d collected",
                dataVendorCount, dataCollected, dataTotal)
        else
            subRow.countText:SetText(string.format("%d vendors", dataVendorCount))
            subRow.countText:SetTextColor(0.5, 0.5, 0.5)
            subRow.tooltipSub = string.format("%d vendors", dataVendorCount)
        end

        -- Zone icon
        subRow.icon:SetAtlas("poi-door")
        subRow.icon:SetVertexColor(0.7, 0.7, 0.7)

        subRow:ClearAllPoints()
        subRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffsetStart - totalHeight)
        subRow:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -yOffsetStart - totalHeight)
        subRow:Show()

        totalHeight = totalHeight + SUB_ROW_HEIGHT
        subRowIndex = subRowIndex + 1
    end

    return totalHeight, subRowIndex
end

-------------------------------------------------------------------------------
-- Panel Frame Creation
-------------------------------------------------------------------------------

local function CreatePanel()
    if panelFrame then return end

    -- Main panel frame, parented to UIParent with cross-parent anchoring to
    -- the map canvas. Sits flush against the left edge of the canvas.
    -- When shown, the map shifts right to make room (see ShiftMapRight).
    -- Styled using Blizzard's NineSlice border system to match the map frame.
    -- Anonymous to avoid tainting UIParentPanelManager's CloseWindows() iteration.
    local canvas = WorldMapFrame.ScrollContainer
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetWidth(PANEL_WIDTH)
    panel:SetPoint("TOPRIGHT", canvas, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMLEFT", 0, 0)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel(500)
    panel:EnableMouse(true)  -- Prevent clicks falling through to world map
    panel:SetClampedToScreen(true)  -- Safety net: prevent off-screen displacement

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

    -- Search bar (above summary line at bottom)
    searchBar = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    searchBar:SetHeight(22)
    searchBar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", BORDER_LEFT, BORDER_BOTTOM + 16)
    searchBar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -BORDER_RIGHT, BORDER_BOTTOM + 16)
    searchBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    searchBar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    searchBar:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    local searchIcon = searchBar:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(12, 12)
    searchIcon:SetPoint("LEFT", searchBar, "LEFT", 4, 0)
    searchIcon:SetAtlas("common-search-magnifyingglass", false)
    searchIcon:SetVertexColor(0.7, 0.7, 0.7)

    searchEditBox = CreateFrame("EditBox", nil, searchBar)
    searchEditBox:SetFontObject(GameFontHighlightSmall)
    searchEditBox:SetPoint("LEFT", searchIcon, "RIGHT", 4, 0)
    searchEditBox:SetPoint("RIGHT", searchBar, "RIGHT", -16, 0)
    searchEditBox:SetHeight(16)
    searchEditBox:SetAutoFocus(false)
    searchEditBox:SetMaxLetters(50)

    local placeholder = searchBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", searchEditBox, "LEFT", 2, 0)
    placeholder:SetText("Search items, vendors...")
    placeholder:SetTextColor(0.5, 0.5, 0.5)

    local clearBtn = CreateFrame("Button", nil, searchBar)
    clearBtn:SetSize(10, 10)
    clearBtn:SetPoint("RIGHT", searchBar, "RIGHT", -2, 0)
    clearBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    clearBtn:GetNormalTexture():SetVertexColor(0.6, 0.6, 0.6)
    clearBtn:Hide()
    clearBtn:SetScript("OnClick", function()
        ClearSearch(true)
        searchEditBox:ClearFocus()
    end)

    local function UpdateSearchUI()
        local text = searchEditBox:GetText()
        local hasText = text and text ~= ""
        placeholder:SetShown(not hasText and not searchEditBox:HasFocus())
        clearBtn:SetShown(hasText)
    end

    searchEditBox:SetScript("OnTextChanged", function()
        if suppressTextChanged then return end
        UpdateSearchUI()
        if searchDebounceTimer then searchDebounceTimer:Cancel() end
        searchDebounceTimer = C_Timer.NewTimer(0.3, ExecuteSearch)
    end)

    searchEditBox:SetScript("OnEditFocusGained", function()
        placeholder:Hide()
        searchBar:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        searchIcon:SetVertexColor(1, 0.82, 0)
        if HA.SearchProvider then
            HA.SearchProvider:PreWarm()
        end
    end)

    searchEditBox:SetScript("OnEditFocusLost", function()
        UpdateSearchUI()
        searchBar:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        searchIcon:SetVertexColor(0.7, 0.7, 0.7)
    end)

    searchEditBox:SetScript("OnEscapePressed", function(self)
        ClearSearch(true)
        self:ClearFocus()
    end)

    searchEditBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    -- Back navigation bar (between header and progress bar / scroll area)
    backBar = CreateFrame("Button", nil, panel)
    backBar:SetHeight(20)
    backBar:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
    backBar:SetPoint("TOPRIGHT", headerFrame, "BOTTOMRIGHT", 0, 0)

    local backArrow = backBar:CreateTexture(nil, "ARTWORK")
    backArrow:SetSize(12, 12)
    backArrow:SetPoint("LEFT", 8, 0)
    backArrow:SetAtlas("common-icon-backarrow")
    backBar.arrow = backArrow

    local backText = backBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    backText:SetPoint("LEFT", backArrow, "RIGHT", 4, 0)
    backText:SetPoint("RIGHT", backBar, "RIGHT", -8, 0)
    backText:SetJustifyH("LEFT")
    backText:SetTextColor(0.5, 0.7, 1.0)
    backBar.text = backText

    local backHighlight = backBar:CreateTexture(nil, "HIGHLIGHT")
    backHighlight:SetAllPoints()
    backHighlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)

    local backSep = backBar:CreateTexture(nil, "BACKGROUND")
    backSep:SetHeight(1)
    backSep:SetPoint("BOTTOMLEFT", 4, 0)
    backSep:SetPoint("BOTTOMRIGHT", -4, 0)
    backSep:SetColorTexture(0.3, 0.3, 0.3, 0.4)

    backBar:SetScript("OnClick", function()
        MapSidePanel:NavigateBack()
    end)
    backBar:SetScript("OnEnter", function(self)
        local tooltip = BeginPanelTooltip(self, "ANCHOR_BOTTOM")
        tooltip:SetText("Go back")
        tooltip:Show()
    end)
    backBar:SetScript("OnLeave", HidePanelTooltip)
    backBar:Hide()

    -- Progress bar (between header and scroll area, shown at zone level)
    progressBar = CreateFrame("StatusBar", nil, panel)
    progressBar:SetHeight(PROGRESS_BAR_HEIGHT)
    progressBar:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -3)
    progressBar:SetPoint("TOPRIGHT", headerFrame, "BOTTOMRIGHT", 0, -3)
    progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    progressBar:SetStatusBarColor(0.2, 0.6, 0.8)
    progressBar:Hide()

    -- Dark background behind fill
    progressBarBg = progressBar:CreateTexture(nil, "BACKGROUND")
    progressBarBg:SetAllPoints()
    progressBarBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    -- Full-width purchasable fill (muted gold, sits behind the blue collected fill)
    -- The blue StatusBar fill covers collected items from the left; the red locked
    -- fill covers locked items from the right; this middle layer fills the rest
    -- so the purchasable segment has a visible color instead of just dark background.
    progressBarPurchasableFill = progressBar:CreateTexture(nil, "ARTWORK", nil, -1)
    progressBarPurchasableFill:SetAllPoints()
    progressBarPurchasableFill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    progressBarPurchasableFill:SetVertexColor(0.9, 0.7, 0.0, 0.8)

    -- Right-anchored locked fill (nested StatusBar so it renders with the same
    -- gradient stripes as the blue fill, not a flat texture)
    progressBarLockedFill = CreateFrame("StatusBar", nil, progressBar)
    progressBarLockedFill:SetPoint("TOPRIGHT", progressBar, "TOPRIGHT", 0, 0)
    progressBarLockedFill:SetPoint("BOTTOMRIGHT", progressBar, "BOTTOMRIGHT", 0, 0)
    progressBarLockedFill:SetWidth(0)
    progressBarLockedFill:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    progressBarLockedFill:SetStatusBarColor(0.80, 0.20, 0.20, 0.95)
    progressBarLockedFill:SetMinMaxValues(0, 1)
    progressBarLockedFill:SetValue(1)
    progressBarLockedFill:Hide()

    -- Diagonal stripe overlay on locked segment (blocked/disabled visual cue)
    progressBarLockedFill.hashOverlay = progressBar:CreateTexture(nil, "ARTWORK", nil, 2)
    progressBarLockedFill.hashOverlay:SetAllPoints(progressBarLockedFill)
    progressBarLockedFill.hashOverlay:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent")
    progressBarLockedFill.hashOverlay:SetAlpha(0.4)
    progressBarLockedFill.hashOverlay:Hide()

    -- Ensure locked fill doesn't cover the text — lower its frame level
    progressBarLockedFill:SetFrameLevel(progressBar:GetFrameLevel() + 1)

    -- Centered count text on its own frame above both fills — must not be
    -- a child of progressBarLockedFill or it hides when locked == 0
    local textOverlay = CreateFrame("Frame", nil, progressBar)
    textOverlay:SetAllPoints()
    textOverlay:SetFrameLevel(progressBarLockedFill:GetFrameLevel() + 1)
    progressBarText = textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    progressBarText:SetPoint("CENTER", progressBar, "CENTER")

    -- Tooltip on hover
    progressBar:EnableMouse(true)
    progressBar:SetScript("OnEnter", function(self)
        local tooltip = BeginPanelTooltip(self, "ANCHOR_BOTTOM")
        tooltip:AddLine(DISPLAY_LEVEL_TITLES[currentDisplayLevel] or "Collection Progress", 1, 1, 1)
        local _, max = self:GetMinMaxValues()
        local val = self:GetValue()
        if max > 0 then
            local pct = math.floor(val / max * 100)
            tooltip:AddLine(string.format("%d of %d items (%d%%)", val, max, pct), 0.4, 0.8, 0.8)
            local lockedVal = self.lockedValue or 0
            BC.AddSummaryLine(tooltip, val, max, lockedVal)
        end
        tooltip:Show()
    end)
    progressBar:SetScript("OnLeave", HidePanelTooltip)

    -- Scroll frame for vendor list
    scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)
    scrollContainer:SetPoint("BOTTOMRIGHT", searchBar, "TOPRIGHT", 0, -2)

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
        local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
        tooltip:SetText("Detach panel")
        tooltip:Show()
    end)
    popOutButton:SetScript("OnLeave", HidePanelTooltip)

    -- Source filter control (title pane): dropdown on left side of header.
    sourceFilterDropdown = CreateFrame("Frame", nil, headerFrame, "UIDropDownMenuTemplate")
    sourceFilterDropdown:SetPoint("LEFT", headerFrame, "LEFT", -14, -1)
    sourceFilterDropdown:SetScale(0.825) -- 10% larger than the previous compact version

    local setWidth = _G.UIDropDownMenu_SetWidth
    local justifyText = _G.UIDropDownMenu_JustifyText
    local initializeDropdown = _G.UIDropDownMenu_Initialize

    if setWidth then
        setWidth(sourceFilterDropdown, 67) -- 20% narrower than prior width
    end
    if justifyText then
        justifyText(sourceFilterDropdown, "LEFT")
    end
    if initializeDropdown then
        initializeDropdown(sourceFilterDropdown, InitializeSourceFilterDropdown)
    end
    UpdateSourceFilterDropdownText()

    if sourceFilterDropdown.Button then
        sourceFilterDropdown.Button:SetScript("OnEnter", function(self)
            local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
            tooltip:SetText("Item Source Filter")
            tooltip:AddLine("Current: " .. GetSourceFilterLabel(panelSourceFilter), 1, 1, 1)
            tooltip:Show()
        end)
        sourceFilterDropdown.Button:SetScript("OnLeave", HidePanelTooltip)
    end

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
        local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
        tooltip:SetText("Attach to World Map")
        tooltip:Show()
    end)
    reattachButton:SetScript("OnLeave", HidePanelTooltip)
    reattachButton:Hide()

    -- Resize handle (detached mode): thin grip bar at the bottom edge for
    -- height-only resizing. Hidden when docked.
    resizeHandle = CreateFrame("Frame", nil, panel)
    resizeHandle:SetHeight(8)
    resizeHandle:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, 0)
    resizeHandle:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 0)
    resizeHandle:EnableMouse(true)
    resizeHandle:SetScript("OnMouseDown", function()
        panelFrame:StartSizing("BOTTOM")
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        panelFrame:StopMovingOrSizing()
        SaveDetachedPosition()
    end)
    resizeHandle:SetScript("OnEnter", function(self)
        -- Visual feedback: WoW doesn't support custom cursors, so highlight the grip
        self.highlight:Show()
    end)
    resizeHandle:SetScript("OnLeave", function(self)
        self.highlight:Hide()
    end)

    -- Grip line visual (subtle horizontal lines)
    local grip = resizeHandle:CreateTexture(nil, "ARTWORK")
    grip:SetHeight(2)
    grip:SetPoint("LEFT", 8, 0)
    grip:SetPoint("RIGHT", -8, 0)
    grip:SetColorTexture(0.6, 0.6, 0.6, 0.4)
    local grip2 = resizeHandle:CreateTexture(nil, "ARTWORK")
    grip2:SetHeight(2)
    grip2:SetPoint("LEFT", 8, -3)
    grip2:SetPoint("RIGHT", -8, -3)
    grip2:SetColorTexture(0.6, 0.6, 0.6, 0.4)

    -- Hover highlight
    local hl = resizeHandle:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.1)
    hl:Hide()
    resizeHandle.highlight = hl

    resizeHandle:Hide()

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

    -- No Krowi — count Blizzard's default overlay frames manually.
    -- Filter by height: button-row frames are ~32px tall; larger frames (map
    -- decorations, zone label overlays, etc.) that also live in overlayFrames
    -- in 11.x+ must be excluded or they inflate the count and push our button
    -- down to the centre of the right border.
    local count = 0
    if WorldMapFrame.overlayFrames then
        for _, f in ipairs(WorldMapFrame.overlayFrames) do
            if f:IsShown() and f:GetHeight() <= 36 then
                count = count + 1
            end
        end
    end
    return count
end

local function PositionOverlayButton()
    if not overlayButton then return end
    local container = WorldMapFrame:GetCanvasContainer()
    if not container then return end
    overlayButton:ClearAllPoints()
    local visibleCount = CountVisibleOverlayButtons()
    local yOffset = -(2 + visibleCount * 32)
    overlayButton:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, yOffset)
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
    [8] = "8 px",
    [10] = "Default (10)",
    [12] = "12 px",
    [14] = "14 px",
    [16] = "16 px",
    [18] = "18 px",
}

local PIN_SIZE_ORDER = { 8, 10, 12, 14, 16, 18 }

local function ShowContextMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle("Homestead")

        -- Toggle: Show map pins
        rootDescription:CreateCheckbox("Show Map Pins", function()
            return HA.Addon.db.profile.vendorTracer.showMapPins ~= false
        end, function()
            local newVal = HA.Addon.db.profile.vendorTracer.showMapPins == false
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
                return HA.PinFrameFactory:GetPinIconSize() == size
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
        local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(tooltip, "Homestead")
        if isPoppedOut and panelFrame and panelFrame:IsShown() then
            GameTooltip_AddNormalLine(tooltip, "Left-click: Show vendor panel")
        else
            GameTooltip_AddNormalLine(tooltip, "Left-click: Toggle vendor panel")
        end
        GameTooltip_AddNormalLine(tooltip, "Right-click: Pin options")
        tooltip:Show()
    end)

    button:SetScript("OnLeave", HidePanelTooltip)

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
    local isNeighborhoodMap = (mapID == 2351 or mapID == 2352)

    -- Get vendors for this map + sub-zone child maps.
    -- Filter children to only include maps MORE specific than the current map.
    -- Some child links report nil mapType, so resolve fallback via GetMapInfo
    -- before deciding whether to include the child.
    local mapsToCheck = { [mapID] = true }
    local currentMapInfo = C_Map.GetMapInfo(mapID)
    local currentMapType = currentMapInfo and currentMapInfo.mapType
    local childMaps = C_Map.GetMapChildrenInfo(mapID)
    if childMaps then
        for _, childInfo in ipairs(childMaps) do
            local childMapType = childInfo.mapType
            if not childMapType then
                local childMapInfo = C_Map.GetMapInfo(childInfo.mapID)
                childMapType = childMapInfo and childMapInfo.mapType
            end
            -- Only include children that are more specific than the current map
            -- (higher mapType = more specific: Zone < Dungeon < Micro)
            if not currentMapType or (childMapType and childMapType > currentMapType) then
                mapsToCheck[childInfo.mapID] = true
            end
        end
    end

    local showOpposite = VendorFilter.ShouldShowOppositeFaction()

    local function TryAddVendor(vendor)
        if not vendor or not vendor.npcID or seen[vendor.npcID] then
            return
        end
        seen[vendor.npcID] = true

        if VendorFilter.ShouldHideVendor(vendor) then
            return
        end

        local isOpposite = VendorFilter.IsOppositeFaction(vendor)
        if showOpposite or not isOpposite then
            vendors[#vendors + 1] = {
                vendor = vendor,
                isOpposite = isOpposite,
            }
        end
    end

    for queryMapID in pairs(mapsToCheck) do
        local mapVendors = VendorData:GetVendorsInMap(queryMapID)
        if mapVendors then
            for _, vendor in ipairs(mapVendors) do
                TryAddVendor(vendor)
            end
        end
    end

    -- Neighborhood maps are split across 2351/2352.
    -- Inject only active endeavor vendor(s) from the sibling map.
    if isNeighborhoodMap then
        local endeavorsData = HA.EndeavorsData
        for _, endeavorMapID in ipairs({2351, 2352}) do
            if endeavorMapID ~= mapID then
                local mapVendors = VendorData:GetVendorsInMap(endeavorMapID)
                if mapVendors then
                    for _, vendor in ipairs(mapVendors) do
                        if vendor.endeavor then
                            local isActive
                            if endeavorsData and endeavorsData.IsVendorActive then
                                isActive = endeavorsData:IsVendorActive(vendor)
                            end
                            if isActive == true then
                                TryAddVendor(vendor)
                            end
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

-- Returns the frame that content (progress bar / scroll area) should anchor below.
-- When backBar is visible, content sits below it; otherwise directly below header.
local function GetContentTopAnchor()
    if backBar and backBar:IsShown() then return backBar end
    return headerFrame
end

local function UpdateBackBar()
    if not backBar then return end
    if not lastRefreshMapID then
        backBar:Hide()
        return
    end
    local mapInfo = C_Map.GetMapInfo(lastRefreshMapID)
    if not mapInfo or not mapInfo.parentMapID or mapInfo.parentMapID <= 0 then
        backBar:Hide()
        return
    end
    -- World level: no back bar (already at top)
    if currentDisplayLevel == "world" then
        backBar:Hide()
        return
    end
    local parentInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
    local parentName = parentInfo and parentInfo.name or "Back"
    backBar.text:SetText("< " .. parentName)
    backBar:Show()
end

function MapSidePanel:NavigateBack()
    if not lastRefreshMapID then return end
    local mapInfo = C_Map.GetMapInfo(lastRefreshMapID)
    if not mapInfo or not mapInfo.parentMapID or mapInfo.parentMapID <= 0 then return end
    if WorldMapFrame:IsShown() then
        WorldMapFrame:SetMapID(mapInfo.parentMapID)
    else
        -- Detached mode: map not open, navigate via internal state
        lastRefreshMapID = mapInfo.parentMapID
        self:RefreshContent()
    end
end

local function HideProgressBar()
    if not progressBar then return end
    progressBar:Hide()
    if progressBarLockedFill then
        progressBarLockedFill:Hide()
        progressBarLockedFill:SetWidth(0)
        if progressBarLockedFill.hashOverlay then
            progressBarLockedFill.hashOverlay:Hide()
        end
    end
    progressBar.lockedValue = nil
    progressBar.purchasableValue = nil
    progressBar.pendingLockedRatio = nil
    progressBar.needsLockedFillLayout = false
    -- Re-anchor scroll area below back bar or header (skip hidden progress bar)
    local anchor = GetContentTopAnchor()
    if scrollContainer then
        scrollContainer:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    end
end

local function UpdateProgressBar(collected, total, locked)
    if not progressBar then return end
    locked = locked or 0
    if total > 0 then
        -- Anchor progress bar below back bar or header
        local anchor = GetContentTopAnchor()
        progressBar:ClearAllPoints()
        progressBar:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -3)
        progressBar:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -3)

        progressBar:SetMinMaxValues(0, total)

        -- Green fill for collected items
        progressBar:SetStatusBarColor(0.0, 0.7, 0.0)
        local pct = collected / total
        local pctDisplay = math.floor(pct * 100)
        progressBarText:SetText(string.format("%d/%d (%d%%)", collected, total, pctDisplay))

        -- Store locked metadata for tooltip and OnUpdate layout
        progressBar.lockedValue = locked
        progressBar.purchasableValue = math.max(0, total - collected - locked)
        progressBar.pendingLockedRatio = locked / total
        progressBar.needsLockedFillLayout = true

        progressBar:Show()

        -- Smooth fill: animate bar value toward target over ~0.4s.
        -- Also sizes the locked fill texture once layout width is available.
        progressBar.targetValue = collected
        if not progressBar.filling then
            progressBar.filling = true
            progressBar:SetScript("OnUpdate", function(self, elapsed)
                local current = self:GetValue()
                local target = self.targetValue
                local _, max = self:GetMinMaxValues()
                local step = max * elapsed / 0.4
                if math.abs(current - target) <= step then
                    self:SetValue(target)
                    self.filling = false
                    -- Keep OnUpdate alive if locked fill still needs layout
                    if not self.needsLockedFillLayout then
                        self:SetScript("OnUpdate", nil)
                    end
                elseif current < target then
                    self:SetValue(current + step)
                else
                    self:SetValue(current - step)
                end

                -- Deferred locked-fill sizing (needs valid GetWidth after layout pass)
                if self.needsLockedFillLayout and progressBarLockedFill then
                    local barWidth = self:GetWidth()
                    if barWidth and barWidth > 0 then
                        local lockedRatio = self.pendingLockedRatio or 0
                        local lockedWidth = math.floor(barWidth * lockedRatio + 0.5)
                        if lockedWidth > 0 then
                            progressBarLockedFill:SetWidth(lockedWidth)
                            progressBarLockedFill:Show()
                            if progressBarLockedFill.hashOverlay then
                                progressBarLockedFill.hashOverlay:Show()
                            end
                        else
                            progressBarLockedFill:SetWidth(0)
                            progressBarLockedFill:Hide()
                            if progressBarLockedFill.hashOverlay then
                                progressBarLockedFill.hashOverlay:Hide()
                            end
                        end
                        self.needsLockedFillLayout = false
                        -- Clear OnUpdate entirely if fill animation also finished
                        if not self.filling then
                            self:SetScript("OnUpdate", nil)
                        end
                    end
                end
            end)
        end

        -- Anchor scroll area below bar
        if scrollContainer then
            scrollContainer:SetPoint("TOPLEFT", progressBar, "BOTTOMLEFT", 0, -2)
        end
    else
        HideProgressBar()
    end
end

-------------------------------------------------------------------------------
-- Continent/World Summary Refresh
-------------------------------------------------------------------------------

function MapSidePanel:RefreshZoneSummaries(mapID, mapInfo)
    currentDisplayLevel = "continent"

    -- Hide vendor rows and item grids
    expandedVendorID = nil
    for _, row in ipairs(vendorRows) do
        row:Hide()
        HideItemGrid(row)
    end
    HideAllSummarySubRows()

    headerText:SetText(mapInfo.name or "")

    local zoneCounts = BC:GetZoneVendorCounts(mapID)

    -- Build sorted zone list
    local zoneList = {}
    for zoneMapID, data in pairs(zoneCounts) do
        zoneList[#zoneList + 1] = { mapID = zoneMapID, data = data }
    end
    table.sort(zoneList, function(a, b)
        return (a.data.zoneName or "") < (b.data.zoneName or "")
    end)

    if #zoneList == 0 then
        emptyText:SetText("No vendors on this continent")
        emptyText:Show()
        summaryText:SetText("")
        scrollChild:SetHeight(1)
        UpdateBackBar()
        HideProgressBar()
        return
    end

    -- Ensure enough summary rows
    while #summaryRows < #zoneList do
        summaryRows[#summaryRows + 1] = CreateSummaryRow(scrollChild, #summaryRows + 1)
    end

    local totalCollected, totalItems, totalLocked = 0, 0, 0
    local zoneCount = 0
    local yOffset = 0
    local subRowIndex = 1  -- shared pool index across all expansions

    for i, entry in ipairs(zoneList) do
        local row = summaryRows[i]
        local data = entry.data
        local dataVendorCount = data.vendorCount or 0
        local dataCollected = data.collectedItems or 0
        local dataTotal = data.totalItems or 0
        local dataLocked = data.lockedItems or 0

        row.targetMapID = entry.mapID
        row.vendorCount = dataVendorCount
        row.collectedItems = dataCollected
        row.totalItems = dataTotal
        row.lockedItems = dataLocked
        row.unverifiedItems = data.unverifiedItems or 0

        row.nameText:SetText(data.zoneName or "Unknown")
        row.nameText:SetTextColor(1, 1, 1)

        -- Arrow icon: down if expanded, forward if collapsed
        local isExpanded = (expandedSummaryMapID == entry.mapID)
        row.arrow:SetAtlas(isExpanded and "common-icon-downarrow" or "common-icon-forwardarrow")

        -- Summary line: "N vendors | owned/total[/locked]" with inline colors
        if dataTotal > 0 then
            row.summaryLine:SetText(string.format("%d vendors | %s",
                dataVendorCount, FormatPurchasabilityCountText(dataCollected, dataTotal, dataLocked)))
            row.summaryLine:SetTextColor(1, 1, 1)
        elseif dataVendorCount > 0 then
            row.summaryLine:SetText(string.format("%d vendors (no item data)", dataVendorCount))
            row.summaryLine:SetTextColor(0.5, 0.5, 0.5)
        else
            row.summaryLine:SetText("")
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -yOffset)
        row:Show()

        yOffset = yOffset + ROW_HEIGHT

        -- If expanded, populate vendor sub-rows below this zone row
        if isExpanded then
            local expansionHeight
            expansionHeight, subRowIndex = PopulateZoneExpansion(entry.mapID, yOffset, subRowIndex)
            yOffset = yOffset + expansionHeight
        end

        totalCollected = totalCollected + dataCollected
        totalItems = totalItems + dataTotal
        totalLocked = totalLocked + dataLocked
        zoneCount = zoneCount + 1
    end

    -- Hide excess summary rows and sub-rows
    for i = #zoneList + 1, #summaryRows do
        summaryRows[i]:Hide()
    end
    for i = subRowIndex, #summarySubRows do
        summarySubRows[i]:Hide()
    end

    scrollChild:SetHeight(math.max(1, yOffset))
    emptyText:Hide()

    -- Summary line
    if totalItems > 0 then
        summaryText:SetText(string.format("%d zones | %s items",
            zoneCount, FormatPurchasabilityCountText(totalCollected, totalItems, totalLocked)))
    else
        summaryText:SetText(string.format("%d zones", zoneCount))
    end

    UpdateBackBar()
    UpdateProgressBar(totalCollected, totalItems, totalLocked)
end

function MapSidePanel:RefreshContinentSummaries(mapID, mapInfo)
    currentDisplayLevel = "world"

    -- Hide vendor rows and item grids
    expandedVendorID = nil
    for _, row in ipairs(vendorRows) do
        row:Hide()
        HideItemGrid(row)
    end
    HideAllSummarySubRows()

    headerText:SetText(mapInfo.name or "")

    local continentCounts = BC:GetContinentVendorCounts(panelSourceFilter)

    -- Build sorted continent list, filtered to children of the current map view.
    -- On Azeroth (947) this excludes Draenor continents; on Draenor it excludes Azeroth.
    -- Cosmic map (946) or unknown parents show all.
    local continentList = {}
    for contMapID, data in pairs(continentCounts) do
        local contInfo = C_Map.GetMapInfo(contMapID)
        if not contInfo or not contInfo.parentMapID
                or contInfo.parentMapID == mapID
                or mapID == 946 then
            continentList[#continentList + 1] = { mapID = contMapID, data = data }
        end
    end
    table.sort(continentList, function(a, b)
        return (a.data.continentName or "") < (b.data.continentName or "")
    end)

    if #continentList == 0 then
        emptyText:SetText("No vendor data available")
        emptyText:Show()
        summaryText:SetText("")
        scrollChild:SetHeight(1)
        UpdateBackBar()
        HideProgressBar()
        return
    end

    -- Ensure enough summary rows
    while #summaryRows < #continentList do
        summaryRows[#summaryRows + 1] = CreateSummaryRow(scrollChild, #summaryRows + 1)
    end

    local totalCollected, totalItems, totalLocked = 0, 0, 0
    local contCount = 0
    local yOffset = 0
    local subRowIndex = 1

    for i, entry in ipairs(continentList) do
        local row = summaryRows[i]
        local data = entry.data
        local dataVendorCount = data.vendorCount or 0
        local dataCollected = data.collectedItems or 0
        local dataTotal = data.totalItems or 0
        local dataLocked = data.lockedItems or 0

        row.targetMapID = entry.mapID
        row.vendorCount = dataVendorCount
        row.collectedItems = dataCollected
        row.totalItems = dataTotal
        row.lockedItems = dataLocked
        row.unverifiedItems = data.unverifiedItems or 0

        -- Gold color for continent names
        row.nameText:SetText(data.continentName or "Unknown")
        row.nameText:SetTextColor(1, 0.82, 0)

        -- Arrow icon: down if expanded, forward if collapsed
        local isExpanded = (expandedSummaryMapID == entry.mapID)
        row.arrow:SetAtlas(isExpanded and "common-icon-downarrow" or "common-icon-forwardarrow")

        -- Summary line: "N vendors | owned/total[/locked]" with inline colors
        if dataTotal > 0 then
            row.summaryLine:SetText(string.format("%d vendors | %s",
                dataVendorCount, FormatPurchasabilityCountText(dataCollected, dataTotal, dataLocked)))
            row.summaryLine:SetTextColor(1, 1, 1)
        elseif dataVendorCount > 0 then
            row.summaryLine:SetText(string.format("%d vendors (no item data)", dataVendorCount))
            row.summaryLine:SetTextColor(0.5, 0.5, 0.5)
        else
            row.summaryLine:SetText("")
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -yOffset)
        row:Show()

        yOffset = yOffset + ROW_HEIGHT

        -- If expanded, populate zone sub-rows below this continent row
        if isExpanded then
            local expansionHeight
            expansionHeight, subRowIndex = PopulateContinentExpansion(entry.mapID, yOffset, subRowIndex)
            yOffset = yOffset + expansionHeight
        end

        totalCollected = totalCollected + dataCollected
        totalItems = totalItems + dataTotal
        totalLocked = totalLocked + dataLocked
        contCount = contCount + 1
    end

    -- Hide excess summary rows and sub-rows
    for i = #continentList + 1, #summaryRows do
        summaryRows[i]:Hide()
    end
    for i = subRowIndex, #summarySubRows do
        summarySubRows[i]:Hide()
    end

    scrollChild:SetHeight(math.max(1, yOffset))
    emptyText:Hide()

    -- Summary line
    if totalItems > 0 then
        summaryText:SetText(string.format("%d continents | %s items",
            contCount, FormatPurchasabilityCountText(totalCollected, totalItems, totalLocked)))
    else
        summaryText:SetText(string.format("%d continents", contCount))
    end

    UpdateBackBar()
    UpdateProgressBar(totalCollected, totalItems, totalLocked)
end

-------------------------------------------------------------------------------
-- Search Results Refresh
-------------------------------------------------------------------------------

function MapSidePanel:RefreshSearchResults()
    -- Self-healing: re-query if index was invalidated since last results
    local SP = HA.SearchProvider
    if SP and searchResultsRevision ~= SP:GetRevision() then
        searchResults = SP:Search(searchText, SEARCH_OPTIONS)
        searchResultsRevision = SP:GetRevision()
        -- HS-019: rebuild cycle targets against the new results so cycling
        -- survives index churn. Reset cursor to 0 since position semantics
        -- changed; the matched item identity is preserved.
        if cycleItemID then
            cycleTargets = BuildCycleTargets(cycleItemID)
            cycleCursor = 0
            if #cycleTargets == 0 then
                cycleItemID = nil
                cycleTargets = nil
            end
        end
    end

    HideAllNonVendorContent()
    expandedSummaryMapID = nil
    HideProgressBar()

    -- Reset all vendor rows: hide, clear grids, clear search mode
    for _, row in ipairs(vendorRows) do
        row:Hide()
        HideItemGrid(row)
        row.searchMode = false
    end
    HideAllItemResultRows()

    if not searchResults or #searchResults == 0 then
        emptyText:SetText("No results found")
        emptyText:Show()
        summaryText:SetText("")
        headerText:SetText("Search Results")
        scrollChild:SetHeight(1)
        return
    end

    emptyText:Hide()
    headerText:SetText("Search Results")

    local yOffset = 0
    local vendorCount = 0
    local itemCount = 0
    local r, g, b = HA.PinFrameFactory:GetPinColor()

    for _, result in ipairs(searchResults) do
        if result.resultType == "item" then
            itemCount = itemCount + 1
            local row = itemResultRows[itemCount]
            if not row then
                row = CreateItemResultRow(scrollChild, itemCount)
                itemResultRows[itemCount] = row
            end

            local isExpanded = PopulateItemResultRow(row, result, panelSourceFilter)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
            row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -yOffset)
            row:Show()

            yOffset = yOffset + (isExpanded and row:GetHeight() or ROW_HEIGHT)
        else
            vendorCount = vendorCount + 1
            local vendor = result.vendor
            local row = vendorRows[vendorCount]
            if not row then
                row = CreateVendorRow(scrollChild, vendorCount)
                vendorRows[vendorCount] = row
            end

            row.vendor = vendor
            row.searchMode = true
            -- HS-019: stash the per-result matchedItems set so the click
            -- handler can decide cycle eligibility without re-walking results.
            row.searchMatchedItems = result.matchedItems

            row.nameText:SetText(GetVendorDisplayName(vendor))
            row.nameText:SetTextColor(1, 1, 1)

            -- Collection stats (uses panelSourceFilter for display only)
            local stats = BC:GetVendorStats(vendor, panelSourceFilter)
            row.collected = stats.collected or 0
            row.total = stats.total or 0
            row.locked = stats.locked or 0
            if result.matchType == "item" then
                row.countText:SetText(string.format("%d match%s | %s",
                    result.matchCount, result.matchCount == 1 and "" or "es",
                    FormatPurchasabilityCountText(row.collected, row.total, row.locked)))
            else
                row.countText:SetText(FormatPurchasabilityCountText(row.collected, row.total, row.locked))
            end
            row.countText:SetTextColor(1, 1, 1)

            row.icon:SetDesaturated(true)
            row.icon:SetVertexColor(r, g, b)

            local isExpanded = (expandedVendorID == vendor.npcID)
            if isExpanded then
                local gridHeight = PopulateItemGrid(row, vendor, panelSourceFilter, result.matchedItems)
                row:SetHeight(ROW_HEIGHT + gridHeight)
            else
                HideItemGrid(row)
                row:SetHeight(ROW_HEIGHT)
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
            row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -yOffset)
            row:Show()

            yOffset = yOffset + (isExpanded and row:GetHeight() or ROW_HEIGHT)
        end
    end

    -- Hide excess rows
    for i = vendorCount + 1, #vendorRows do
        vendorRows[i]:Hide()
        HideItemGrid(vendorRows[i])
        vendorRows[i].searchMode = false
    end
    for i = itemCount + 1, #itemResultRows do
        itemResultRows[i]:Hide()
        HideItemSourceList(itemResultRows[i])
    end

    scrollChild:SetHeight(math.max(1, yOffset))
    if vendorCount > 0 and itemCount > 0 then
        summaryText:SetText(string.format("%d vendor%s, %d item%s found",
            vendorCount, vendorCount == 1 and "" or "s",
            itemCount, itemCount == 1 and "" or "s"))
    elseif vendorCount > 0 then
        summaryText:SetText(string.format("%d vendor%s found",
            vendorCount, vendorCount == 1 and "" or "s"))
    else
        summaryText:SetText(string.format("%d item%s found",
            itemCount, itemCount == 1 and "" or "s"))
    end
end

-------------------------------------------------------------------------------
-- Content Refresh
-------------------------------------------------------------------------------

function MapSidePanel:RefreshContent()
    if not panelFrame or not panelFrame:IsShown() then HideAllNonVendorContent() expandedSummaryMapID = nil HideProgressBar() currentDisplayLevel = "zone" return end
    if not VendorData or not BC then HideAllNonVendorContent() expandedSummaryMapID = nil HideProgressBar() currentDisplayLevel = "zone" return end

    -- Search mode overrides normal display
    if searchText ~= "" and searchResults then
        self:RefreshSearchResults()
        return
    end

    expandedItemID = nil
    HideAllItemResultRows()

    -- MapID resolution: map frame → last viewed → player zone
    -- When detached, panel keeps its own navigation state
    local mapID
    if not isPoppedOut and WorldMapFrame:IsShown() then
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
        HideAllNonVendorContent()
        expandedSummaryMapID = nil
        currentDisplayLevel = "zone"
        for _, row in ipairs(vendorRows) do
            row:Hide()
            HideItemGrid(row)
        end
        emptyText:SetText("Open the World Map to view vendors")
        emptyText:Show()
        summaryText:SetText("")
        scrollChild:SetHeight(1)
        HideProgressBar()
        return
    end

    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo then HideAllNonVendorContent() expandedSummaryMapID = nil HideProgressBar() currentDisplayLevel = "zone" return end

    -- Ensure scrollChild has a valid width (may be 0 if panel was hidden during creation)
    if scrollChild and scrollChild:GetWidth() < 1 then
        scrollChild:SetWidth(PANEL_WIDTH - 20 - 22)  -- 20 = border insets, 22 = scrollbar
    end

    -- Update header with zone name
    headerText:SetText(mapInfo.name or "")

    -- Determine map type — three-tier dispatch
    local mapType = mapInfo.mapType
    local isContinentLevel = mapType and mapType == Enum.UIMapType.Continent
    local isWorldLevel = mapType and (mapType == Enum.UIMapType.World or mapType == Enum.UIMapType.Cosmic)

    -- Set lastRefreshMapID early so UpdateBackBar() can read it
    lastRefreshMapID = mapID

    if isWorldLevel then
        HideAllSummaryRows()
        self:RefreshContinentSummaries(mapID, mapInfo)
        return
    elseif isContinentLevel then
        HideAllSummaryRows()
        self:RefreshZoneSummaries(mapID, mapInfo)
        return
    end

    -- Zone level: hide all non-vendor content, reset summary expansion
    HideAllNonVendorContent()
    expandedSummaryMapID = nil
    currentDisplayLevel = "zone"

    -- Zone level — show individual vendors
    local vendorList = GetVendorsForCurrentMap(mapID)
    local sourceFilter = panelSourceFilter

    -- Get pin color for icons
    local r, g, b = HA.PinFrameFactory:GetPinColor()

    -- Ensure we have enough rows
    while #vendorRows < #vendorList do
        local row = CreateVendorRow(scrollChild, #vendorRows + 1)
        vendorRows[#vendorRows + 1] = row
    end

    local totalCollected, totalItems, totalLocked = 0, 0, 0
    local yOffset = 0  -- Tracks cumulative Y position (variable row heights)

    for i, entry in ipairs(vendorList) do
        local row = vendorRows[i]
        local vendor = entry.vendor

        row.vendor = vendor
        row.searchMode = false

        -- Set name with color coding
        local nameColor = entry.isOpposite and {0.5, 0.5, 0.5} or {1, 1, 1}
        row.nameText:SetText(GetVendorDisplayName(vendor))
        row.nameText:SetTextColor(nameColor[1], nameColor[2], nameColor[3])

        -- Set icon color
        row.icon:SetDesaturated(true)
        row.icon:SetVertexColor(r, g, b)

        -- Get collection stats (includes purchasable/locked breakdown)
        local stats = BC:GetVendorStats(vendor, sourceFilter)
        row.collected = stats.collected or 0
        row.total = stats.total or 0
        row.locked = stats.locked or 0

        if row.total > 0 then
            row.countText:SetText(FormatPurchasabilityCountText(row.collected, row.total, row.locked))
            -- White base color — inline escapes handle segment coloring
            row.countText:SetTextColor(1, 1, 1)
        else
            if sourceFilter ~= "all" then
                row.countText:SetText("No matching items")
            else
                row.countText:SetText("No item data")
            end
            row.countText:SetTextColor(0.5, 0.5, 0.5)
        end

        totalCollected = totalCollected + row.collected
        totalItems = totalItems + row.total
        totalLocked = totalLocked + row.locked

        -- Check if this vendor is expanded (item grid visible)
        local isExpanded = (expandedVendorID == vendor.npcID)
        local rowHeight = ROW_HEIGHT
        if isExpanded then
            local gridHeight = PopulateItemGrid(row, vendor, sourceFilter)
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
        summaryText:SetText(string.format("%d vendors | %s items",
            #vendorList, FormatPurchasabilityCountText(totalCollected, totalItems, totalLocked)))
    elseif #vendorList > 0 then
        summaryText:SetText(string.format("%d vendors", #vendorList))
    else
        summaryText:SetText("")
    end

    -- Back bar + progress bar
    UpdateBackBar()
    UpdateProgressBar(totalCollected, totalItems, totalLocked)
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
-- Map CAN be opened during combat (M+ dungeons). ShowPanel() should not
-- mutate WorldMapFrame while InCombatLockdown() is true.
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
local savedNavBarState = nil
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

    -- 3. Nav bar → reparent to panelFrame so it shares the same rendering
    --    subtree. Without this, the nav bar (in WorldMapFrame's tree) renders
    --    behind the panel (on UIParent) regardless of frame level or strata.
    --    Walk the parent chain first to disable clipping, then reparent.
    local navBar = wm.NavBar
    if navBar and not savedNavBarState then
        savedNavBarState = SaveFrameState(navBar)

        -- Walk the parent chain from nav bar upward, disabling clipping
        -- (must happen before reparent while the chain is still intact)
        local frame = navBar
        while frame and frame ~= wm do
            DisableClipping(frame)
            local parent = frame:GetParent()
            if parent == frame then break end  -- safety
            frame = parent
        end
        DisableClipping(wm)
        DisableClipping(navBar)

        -- Find original Y offset from TOPLEFT anchor
        local origY = 0
        for _, a in ipairs(savedNavBarState.anchors) do
            if a[1] == "TOPLEFT" then
                origY = a[5] or 0
                break
            end
        end

        -- Reparent to panel, then set anchors and level
        navBar:SetParent(panelFrame)
        navBar:SetFrameStrata("HIGH")
        navBar:SetFrameLevel(panelFrame:GetFrameLevel() + 15)  -- 515

        -- Proxy SetMapID/GetMapID: Blizzard's NavBar GoToMap calls
        -- self:GetParent():SetMapID(mapID), which now hits panelFrame.
        if not panelFrame.SetMapID then
            panelFrame.SetMapID = function(_, mapID)
                WorldMapFrame:SetMapID(mapID)
            end
            panelFrame.GetMapID = function()
                return WorldMapFrame:GetMapID()
            end
        end

        -- Replace the left anchor: start at the panel's left edge, past
        -- the portrait (~64px). Keep the original Y offset and right anchor.
        navBar:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 64, origY)
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

    -- Nav bar (full restore — parent, strata, level, all anchors)
    local navBar = wm.NavBar
    if navBar and savedNavBarState then
        RestoreFrameState(navBar, savedNavBarState)
        savedNavBarState = nil
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

local function ApplyDockedIntegration()
    ShiftMapRight()

    if not ShouldUseStandaloneMode() then
        ReparentMapElements()
        -- Defer border + content inset by one frame for accurate layout values.
        -- Guard with generation counter so a quick close cancels this.
        panelShowGeneration = panelShowGeneration + 1
        local gen = panelShowGeneration
        C_Timer.After(0, function()
            if gen ~= panelShowGeneration then return end
            if not panelFrame or not panelFrame:IsShown() then return end
            UnifyTopBorder()
            ApplyContentInset()
        end)
    end
end

local function RemoveDockedIntegration(restoreMapPosition)
    RestoreContentInset()
    RestoreTopBorder()
    RestoreMapElements()
    if restoreMapPosition then
        RestoreMapPosition()
    else
        mapShifted = false
        savedMapPoint = nil
    end
end

-------------------------------------------------------------------------------
-- Combat Lockdown Deferral
-- WorldMapFrame and its children are protected frames. Mutating them during
-- combat (SetPoint, SetParent, ClearAllPoints, etc.) triggers
-- ADDON_ACTION_BLOCKED errors and taints layout values. All docked-mode
-- map mutations are gated behind InCombatLockdown() and replayed via
-- PLAYER_REGEN_ENABLED when combat ends.
-------------------------------------------------------------------------------

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function()
    if not pendingDockedAction then return end
    local action = pendingDockedAction
    pendingDockedAction = nil
    if action == "apply" then
        -- Panel was shown during combat; apply map integration now
        if panelFrame and panelFrame:IsShown() and not isPoppedOut
                and not WorldMapFrame.isMaximized
                and WorldMapFrame:IsShown() then
            ApplyDockedIntegration()
        end
    elseif action == "remove" then
        -- Panel was hidden during combat; restore map now
        RemoveDockedIntegration(true)
    elseif action == "clear" then
        -- Blizzard already repositioned the map; only clear our integrated state.
        RemoveDockedIntegration(false)
    end
end)

local function ShowPanel()
    if not panelFrame then return end

    -- When popped out, skip all map integration (panel is independent)
    if isPoppedOut then
        panelFrame:Show()
        return
    end

    -- Don't show docked panel when map is maximized (fills the screen)
    if WorldMapFrame.isMaximized then return end

    panelFrame:Show()

    -- Defer all docked map mutations until combat ends
    if InCombatLockdown() then
        pendingDockedAction = "apply"
        return
    end

    ApplyDockedIntegration()
end

local function HidePanel()
    if not panelFrame then return end
    -- Bump generation to cancel any pending deferred Show callbacks
    panelShowGeneration = panelShowGeneration + 1

    -- Explicit cleanup of expandable content
    HideAllNonVendorContent()
    ClearSearch(false)
    if searchEditBox then searchEditBox:ClearFocus() end

    if isPoppedOut then
        -- When popped out, just hide the frame — no map restoration needed
        panelFrame:Hide()
        return
    end

    panelFrame:Hide()

    -- Defer map restoration until combat ends
    if InCombatLockdown() then
        pendingDockedAction = "remove"
        return
    end

    RemoveDockedIntegration(true)
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

-- Save detached position to profile (forward-declared at file scope)
SaveDetachedPosition = function()
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

    -- 1. Determine detached height: prefer saved user preference (from previous
    --    resize), then half the canvas height, then a compact screen fraction.
    --    Without a saved preference the full canvas/screen height is too tall
    --    for a standalone floating panel.
    local db = HA.Addon and HA.Addon.db
    local savedHeight = db and db.profile.vendorTracer.sidePanelHeight
    local h
    if savedHeight and savedHeight > 1 then
        h = savedHeight
    else
        local canvasH = panelFrame:GetHeight()
        if canvasH > 1 then
            h = canvasH * 0.5
        else
            h = UIParent:GetHeight() * 0.3
        end
    end

    -- 2. Restore all map modifications
    if InCombatLockdown() then
        pendingDockedAction = "remove"
    else
        RemoveDockedIntegration(true)
    end

    -- 3. Panel is already parented to UIParent; no reparent needed

    -- 4. Re-set strata/levels
    RestoreFrameLevels()

    -- 5-6. Clear anchors, set size, restore position
    panelFrame:ClearAllPoints()
    panelFrame:SetWidth(PANEL_WIDTH)
    panelFrame:SetHeight(h)

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
    panelFrame:SetScript("OnDragStop", function(self) -- luacheck: ignore 432
        self:StopMovingOrSizing()
        SaveDetachedPosition()
    end)

    -- 8. Enable height resizing
    panelFrame:SetResizable(true)
    panelFrame:SetResizeBounds(PANEL_WIDTH, 200, PANEL_WIDTH, UIParent:GetHeight() * 0.9)
    if resizeHandle then resizeHandle:Show() end

    -- 9. Ensure complete border
    EnsureCompleteBorder()

    -- 8b. Raise reattach button above NineSlice (only needed when detached;
    --     setting at creation time breaks the unified top border in docked mode)
    if reattachButton then
        reattachButton:SetFrameLevel(panelFrame:GetFrameLevel() + 5)
    end

    -- 9. Update buttons
    isPoppedOut = true  -- Set before UpdatePopOutButtons so it reads correctly
    UpdatePopOutButtons()

    -- 10. (Removed: UISpecialFrames registration caused combat taint via CloseWindows())

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

    -- 2. Panel stays parented to UIParent; just reconfigure for docked mode

    -- 3. Clear drag and resize handlers
    panelFrame:SetMovable(false)
    panelFrame:SetResizable(false)
    panelFrame:SetScript("OnDragStart", nil)
    panelFrame:SetScript("OnDragStop", nil)
    if resizeHandle then resizeHandle:Hide() end

    -- 4. Restore original anchors (flush left of canvas, height from top+bottom anchors)
    local canvas = WorldMapFrame.ScrollContainer
    panelFrame:ClearAllPoints()
    panelFrame:SetWidth(PANEL_WIDTH)
    panelFrame:SetPoint("TOPRIGHT", canvas, "TOPLEFT", 0, 0)
    panelFrame:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMLEFT", 0, 0)

    -- 5. Re-set strata/levels
    RestoreFrameLevels()
    -- Reattach button level is not reset here — it's hidden when docked
    -- and touching frame levels during dock disrupts NineSlice rendering.

    -- 6. Update buttons
    isPoppedOut = false
    UpdatePopOutButtons()

    -- 7. Pre-hide panel's top NineSlice pieces before integrated mode re-applies.
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

    -- 8. If map is open, re-apply integrated mode; otherwise hide
    if WorldMapFrame:IsShown() then
        ShowPanel()
        self:RefreshContent()
    else
        panelFrame:Hide()
    end

    -- 9. Save to profile
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

    -- Panel stays on UIParent; just reconfigure for docked mode next time
    panelFrame:SetMovable(false)
    panelFrame:SetResizable(false)
    panelFrame:SetScript("OnDragStart", nil)
    panelFrame:SetScript("OnDragStop", nil)
    if resizeHandle then resizeHandle:Hide() end

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

function MapSidePanel:GetSourceFilter()
    return panelSourceFilter
end

function MapSidePanel:SetSourceFilter(sourceFilter)
    local normalized = NormalizePanelSourceFilter(sourceFilter)
    if panelSourceFilter == normalized then
        UpdateSourceFilterDropdownText()
        return
    end

    panelSourceFilter = normalized

    if HA.Addon and HA.Addon.db and HA.Addon.db.profile and HA.Addon.db.profile.vendorTracer then
        HA.Addon.db.profile.vendorTracer.mapSidePanelSourceFilter = normalized
    end

    UpdateSourceFilterDropdownText()

    -- QA Fix #3: Source filter is ignored at continent/world level (shows unfiltered
    -- totals). Only invalidate caches when at zone level — the badge caches will be
    -- rebuilt with the current filter when the user next navigates to a zone.
    if currentDisplayLevel == "zone" then
        if BC and BC.InvalidateAllCaches then
            BC:InvalidateAllCaches()
        end
    end

    self:RefreshContent()
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

    if HA.Addon and HA.Addon.db and HA.Addon.db.profile and HA.Addon.db.profile.vendorTracer then
        panelSourceFilter = NormalizePanelSourceFilter(HA.Addon.db.profile.vendorTracer.mapSidePanelSourceFilter)
    end

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
            -- Popped out: panel maintains its own navigation state
            return
        end
        -- Don't show docked panel when map is maximized (fills the screen)
        if WorldMapFrame.isMaximized then return end
        -- Restore panel visibility + shift map when map opens
        if HA.Addon and HA.Addon.db
                and HA.Addon.db.profile.vendorTracer.showMapSidePanel then
            -- Delay to let the map settle its position first
            C_Timer.After(0, function()
                if WorldMapFrame.isMaximized then return end
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
        -- Explicitly hide panel (no longer auto-hides since parent is UIParent)
        if panelFrame then panelFrame:Hide() end

        if InCombatLockdown() then
            -- Map is closing during combat; defer restoration.
            -- Cancel any pending "apply" — the map is gone, nothing to integrate.
            pendingDockedAction = "remove"
            return
        end

        RestoreContentInset()
        RestoreTopBorder()
        RestoreMapElements()
        RestoreMapPosition()
        mapShifted = false
    end)

    -- Handle map maximize: hide docked panel to prevent off-screen displacement.
    -- hooksecurefunc fires AFTER Blizzard's code has already repositioned the map,
    -- so we clear our shift state without restoring (the old savedMapPoint is stale).
    if WorldMapFrame.HandleUserActionMaximizeSelf then
        hooksecurefunc(WorldMapFrame, "HandleUserActionMaximizeSelf", function()
            if isPoppedOut then return end
            if not panelFrame or not panelFrame:IsShown() then return end
            panelShowGeneration = panelShowGeneration + 1
            panelFrame:Hide()

            if InCombatLockdown() then
                mapShifted = false
                savedMapPoint = nil
                pendingDockedAction = "clear"
                return
            end

            RemoveDockedIntegration(false)
        end)
    end

    -- Handle map minimize: re-show docked panel
    if WorldMapFrame.HandleUserActionMinimizeSelf then
        hooksecurefunc(WorldMapFrame, "HandleUserActionMinimizeSelf", function()
            if isPoppedOut then return end
            if not panelFrame then return end
            if HA.Addon and HA.Addon.db
                    and HA.Addon.db.profile.vendorTracer.showMapSidePanel then
                C_Timer.After(0, function()
                    ShowPanel()
                    MapSidePanel:RefreshContent()
                end)
            end
        end)
    end

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

        -- Source caches invalidated — covers achievement, quest, reputation,
        -- profession, and holiday changes through SourceManager.
        HA.Events:RegisterCallback("SOURCE_CACHES_INVALIDATED", function()
            MapSidePanel:RefreshContent()
        end)
    end

    -- Initialize SearchProvider
    if HA.SearchProvider and HA.SearchProvider.Initialize then
        HA.SearchProvider:Initialize()
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
