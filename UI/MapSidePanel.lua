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

local F = _G.Foundry_1_0
local FPU = HA.FramePoolUtils

local MapSidePanel = {}
HA.MapSidePanel = MapSidePanel

local L = HA.L or {}
local MPP = HA.MapPinProvider

-- Module references (set during Initialize, after TOC load order)
local VendorData
local VendorFilter
local BC  -- BadgeCalculation

local Layout = {}
local State = {}

-- Constants
Layout.PANEL_WIDTH = 260
Layout.ROW_HEIGHT = 36
Layout.HEADER_HEIGHT = 36
Layout.PADDING = 8
Layout.ICON_SIZE = 14
Layout.ITEM_ICON_SIZE = 28
Layout.ITEM_ICON_PAD = 3
Layout.ITEM_RESULT_ICON_SIZE = 20
Layout.ITEM_RESULT_BADGE_SIZE = 14
Layout.ITEM_RESULT_LINE_HEIGHT = 18
Layout.ITEM_GRID_INSET = 24  -- Left indent for item grid (aligns under name text)

-- Icons per grid row. Derived only from constants above, so it is one itself:
-- content width is Layout.PANEL_WIDTH - 20 (borders) - 22 (scrollbar) = 218.
Layout.ICONS_PER_ROW = math.floor(
    ((Layout.PANEL_WIDTH - 20 - 22) - Layout.ITEM_GRID_INSET - Layout.PADDING + Layout.ITEM_ICON_PAD)
    / (Layout.ITEM_ICON_SIZE + Layout.ITEM_ICON_PAD))
if Layout.ICONS_PER_ROW < 1 then Layout.ICONS_PER_ROW = 1 end

Layout.PROGRESS_BAR_HEIGHT = 14
local SEARCH_OPTIONS = { includeItemResults = true }
Layout.PANEL_TOOLTIP_NAME = "HomesteadMapSidePanelTooltip"

-- Shared row colours. Read-only: a renderer applies one, never mutates it.
Layout.COLOR_WHITE = { 1, 1, 1 }
Layout.COLOR_DIM   = { 0.5, 0.5, 0.5 }
Layout.COLOR_GOLD  = { 1, 0.82, 0 }

-- State
State.panelFrame = nil
State.overlayButton = nil
State.contentList = nil
State.listScrollBox = nil
State.headerFrame = nil  -- Title + zone name header region
State.headerText = nil
State.sourceFilterBar = nil
State.summaryText = nil
State.emptyText = nil
State.topTileFrame = nil   -- Inner decorative top-edge tile
State.topStreaksFrame = nil -- Decorative streaks overlay
State.bgTexture = nil      -- QuestLogBackground fill (anchored below header zone)
State.isInitialized = false
-- HS-210: debounced content-refresh scheduler shared by every event listener
-- below that wants a deferred repaint. Mirrors Overlay/Merchant.lua's
-- ScheduleOverlayUpdate shape, but tracks pending state with an explicit
-- boolean instead of the C_Timer.After return value — C_Timer.After returns
-- nothing, so assigning its result to the guard variable would leave it nil
-- immediately and never actually debounce.
State.pendingContentRefresh = false
-- One free-list bucket per record kind, acquired and released through FramePoolUtils.
-- Replaces the six per-kind row pools the manual scroll layout used.
State.rowPool = { vendor = {}, summary = {}, subrow = {}, boss = {}, item = {}, header = {} }
State.expandedVendorID = nil  -- npcID of currently expanded vendor (nil = none)
State.expandedItemID = nil    -- itemID of currently expanded item result row
State.expandedBossKey = nil   -- journalEncounterID of currently expanded boss row (nil = none)
State.lastRefreshMapID = nil
State.isPoppedOut = false
State.panelSourceFilter = "all"  -- all|vendor|quest|achievement|profession|event|drop
State.sourceFilterDropdown = nil
State.menuContextMenu = nil   -- Foundry.Menu controller, set in MapSidePanel:Initialize()
State.menuSourceFilter = nil  -- Foundry.Menu controller, set in MapSidePanel:Initialize()
State.progressBar = nil
State.progressBarBg = nil
State.progressBarLockedFill = nil
State.progressBarPurchasableFill = nil
State.progressBarText = nil
State.scrollContainer = nil  -- Scroll area container (re-anchored by progress bar)

State.currentDisplayLevel = "zone"  -- "zone" | "continent" | "world"
State.backBar = nil  -- Back navigation bar (visible at zone/continent level)
State.expandedSummaryMapID = nil  -- mapID of expanded summary row (nil = none)
State.iconPool = { default = {} } -- reusable item icon frame pool

-- Search state
State.searchEditBox = nil
State.searchBar = nil
State.searchText = ""
State.searchResults = nil            -- Array from SearchProvider or nil
State.searchDebounceTimer = nil      -- C_Timer.NewTimer handle (cancelable)
State.searchResultsRevision = nil    -- Tracks which index revision results came from
State.suppressTextChanged = false    -- Prevents debounce on programmatic SetText

local SOURCE_FILTER_LABELS = {
    all = L["All"] or "All",
    vendor = L["Vendor"] or "Vendor",
    quest = L["Quest"] or "Quest",
    achievement = L["Achievement"] or "Achievement",
    profession = L["Profession"] or "Profession",
    event = L["Event"] or "Event",
    shop = L["Shop"] or "Shop",
    drop = L["Drop"] or "Drop",
    treasure = L["Treasure"] or "Treasure",
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
State.mapShifted = false
State.savedMapPoint = nil  -- {point, relativeTo, relativePoint, xOfs, yOfs}

-- Pop-out UI elements (created in CreatePanel, shown/hidden based on state)
State.resizeHandle = nil   -- Bottom-edge grip for height resize (detached mode)
State.popOutButton = nil   -- Arrow button to detach (docked mode)
State.closeButton = nil    -- X button (detached mode)
State.reattachButton = nil -- Dock-back button (detached mode)
State.pendingDockedAction = nil  -- "apply" | "remove" | "clear" | nil
State.panelTooltip = nil

local function GetPanelTooltip()
    if State.panelTooltip then
        return State.panelTooltip
    end

    local tooltip = CreateFrame("GameTooltip", Layout.PANEL_TOOLTIP_NAME, UIParent, "GameTooltipTemplate")
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetClampedToScreen(true)
    tooltip.isHomesteadManagedTooltip = true
    tooltip.isHomesteadPanelTooltip = true
    State.panelTooltip = tooltip
    return tooltip
end

local function BeginPanelTooltip(owner, anchor)
    local tooltip = GetPanelTooltip()
    tooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    tooltip:ClearLines()
    return tooltip
end

local function HidePanelTooltip()
    if State.panelTooltip then
        State.panelTooltip:Hide()
    end
end

-------------------------------------------------------------------------------
-- 3D Item Preview (uses Blizzard's HousingModelPreviewFrame)
-------------------------------------------------------------------------------

State.previewHooked = false  -- true after we hook the preview frame's OnShow
State.previewDragHandle = nil  -- overlay frame for dragging (ModelScene eats drag events)

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
    if not State.previewHooked then
        local pf = HousingModelPreviewFrame

        -- Re-apply our map shift if Blizzard's preview resets WorldMapFrame
        local function ReapplyMapShift()
            if State.panelFrame and State.panelFrame:IsShown() and not State.isPoppedOut then
                if InCombatLockdown() then
                    State.pendingDockedAction = "apply"
                    return
                end
                State.mapShifted = false
                State.ShiftMapRight()
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
        State.previewDragHandle = CreateFrame("Frame", nil, pf)
        State.previewDragHandle:SetHeight(30)
        State.previewDragHandle:SetPoint("TOPLEFT", pf, "TOPLEFT", 0, 0)
        State.previewDragHandle:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -30, 0)  -- avoid close button
        State.previewDragHandle:SetFrameLevel(pf:GetFrameLevel() + 100)
        State.previewDragHandle:EnableMouse(true)
        State.previewDragHandle:RegisterForDrag("LeftButton")
        State.previewDragHandle:SetScript("OnDragStart", function()
            pf:StartMoving()
        end)
        State.previewDragHandle:SetScript("OnDragStop", function()
            pf:StopMovingOrSizing()
        end)

        State.previewHooked = true
    end

    -- Get catalog entry info directly from itemID. Guarded like every other
    -- GetCatalogEntryInfoByItem call site (HS-059: nil for some items) with
    -- the byRecordID fallback via CatalogStore's decorID reverse index — see
    -- CatalogStore:IsOwnedFresh's readOnly branch for the reference pattern.
    local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, itemID, true)
    if not ok then info = nil end

    if not info and HA.CatalogStore and HA.CatalogStore.GetDecorIDFromItemID
            and C_HousingCatalog.GetCatalogEntryInfoByRecordID then
        local decorID = HA.CatalogStore:GetDecorIDFromItemID(itemID)
        if decorID then
            local ok2, info2 = pcall(C_HousingCatalog.GetCatalogEntryInfoByRecordID, 1, decorID, true)
            if ok2 then info = info2 end
        end
    end

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

-- Check if item is owned (same pattern as BadgeCalculation/VendorMapPins).
-- HS-200: this is the no-presentation fallback for PopulateItemGrid and
-- RenderItemRow. PopulateItemGrid is still an aggregate per-item loop over a
-- vendor's full item grid; the item path now runs once per realized row rather
-- than over the full result list. It must stay cache-only, matching
-- SourceManager's "sidePanel" context, or it reintroduces a per-item API
-- burst on the map side panel.
local function IsItemOwned(itemID)
    if not itemID then return false end
    if HA.CatalogStore then
        return HA.CatalogStore:IsOwned(itemID)
    end
    return false
end

-- HS-249: is this item's ownership knowable at all? Housing items outside the
-- Decor subclass resolve to no catalog entry, so IsItemOwned answers a hard
-- false that says nothing about the player. The grids must render those in a
-- neutral state rather than the gold "available to purchase" border, which
-- would be telling the player to buy a room they may already own.
local function IsOwnershipExcluded(itemID, presentation)
    if presentation then
        return presentation.isOwnershipExcluded == true
    end
    if itemID and HA.CatalogStore and HA.CatalogStore.IsOwnershipUnknowable then
        return HA.CatalogStore:IsOwnershipUnknowable(itemID) == true
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
    if not State.sourceFilterDropdown then return end

    local normalized = NormalizePanelSourceFilter(State.panelSourceFilter)

    if State.sourceFilterDropdown.SetDefaultText then
        State.sourceFilterDropdown:SetDefaultText(GetSourceFilterLabel(normalized))
    elseif State.sourceFilterDropdown.SetText then
        State.sourceFilterDropdown:SetText(GetSourceFilterLabel(normalized))
    end
end

-- Source types that SourceManager registers but should not appear in the map
-- side panel's filter dropdown — they have no map presence (housing dashboard
-- consumers only). Shop sits here because shop items don't render as pins
-- and there's no plan to.
local MAP_DROPDOWN_HIDDEN_TYPES = {
    shop = true,
}

local function AddSourceFilterMenuEntries(rootDescription)
    local sourceTypes = {}
    if HA.SourceManager and HA.SourceManager.GetRegisteredSourceTypes then
        sourceTypes = HA.SourceManager:GetRegisteredSourceTypes()
    end

    rootDescription:CreateRadio(SOURCE_FILTER_LABELS.all, function()
        return NormalizePanelSourceFilter(State.panelSourceFilter) == "all"
    end, function()
        MapSidePanel:SetSourceFilter("all")
    end)

    for _, token in ipairs(sourceTypes) do
        if not MAP_DROPDOWN_HIDDEN_TYPES[token] then
            local menuToken = token
            local menuLabel = SOURCE_FILTER_LABELS[menuToken] or menuToken
            rootDescription:CreateRadio(menuLabel, function()
                return NormalizePanelSourceFilter(State.panelSourceFilter) == menuToken
            end, function()
                MapSidePanel:SetSourceFilter(menuToken)
            end)
        end
    end
end

local function OpenSourceFilterDropdown()
    if not State.sourceFilterDropdown or not State.menuSourceFilter then return end
    State.menuSourceFilter:CreateContextMenu(State.sourceFilterDropdown)
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

local function GetPanelItemPresentation(itemID, npcID, sourceFilter, result)
    local SM = HA.SourceManager
    if not SM or not SM.GetItemPresentation then
        return nil
    end

    return SM:GetItemPresentation(itemID, {
        context = "sidePanel",
        npcID = npcID,
        sourceFilter = sourceFilter,
        isVendorContext = true,
        preferredSourceType = result and result.sourceType or nil,
        preferredSourceData = result and result.sourceData or nil,
    })
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
    frame:SetSize(Layout.ITEM_ICON_SIZE, Layout.ITEM_ICON_SIZE)

    -- Item icon texture
    local tex = frame:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- Trim default icon border
    frame.texture = tex

    -- HS-019: search-match ring (yellow, rendered BEHIND the ownership border so
    -- red/green/gold accessibility coloring remains visible on matched items).
    local matchRing = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    matchRing:SetPoint("TOPLEFT", -3, 3)
    matchRing:SetPoint("BOTTOMRIGHT", 3, -3)
    matchRing:SetColorTexture(1, 0.9, 0.2, 1)
    matchRing:Hide()
    frame.matchRing = matchRing

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
    -- Tooltip on hover: SetManagedItemTooltip renders the item tooltip from
    -- structured data without Blizzard's sell-back price line (issue #46) and
    -- adds [Homestead] + sources + requirements itself. We only add
    -- the preview hint here to avoid duplicating requirement lines.
    frame:SetScript("OnEnter", function(self)
        if self.itemID then
            local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
            HA.SetManagedItemTooltip(tooltip, self.itemID)
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
    if icon.matchRing then icon.matchRing:Hide() end
    icon:Hide()
    icon:ClearAllPoints()
end

local function AcquireIcon(parent)
    local icon = FPU.AcquirePooledFrame(State.iconPool, "default", function()
        return CreateItemIcon(parent)
    end)
    icon:SetParent(parent)
    icon:Show()
    return icon
end

local function ReleaseIcon(icon)
    ResetIcon(icon)
    FPU.ReleasePooledFrame(State.iconPool, icon)
end

-- Shared count text formatter (green collected / white total / red locked).
local function FormatPurchasabilityCountText(collected, total, locked)
    return BC.FormatCountText(collected, total, locked)
end

-- HS-338: a vendor whose every filter-matching item is ownership-excluded
-- (total == 0, excluded > 0) has real stock — just nothing this addon can
-- track ownership for. Names that stock by housing subclass instead of
-- falling through to "No item data", which reads as an absence it isn't.
-- Pure/self-contained (no upvalues but the global Enum) so it can be
-- extracted and unit-tested standalone. Returns nil when there is nothing
-- excluded to report, so callers can fall through to the existing guard.
local function FormatOwnershipExcludedInventoryText(stats)
    if not stats or (stats.excluded or 0) == 0 then
        return nil
    end

    -- Singular label only -- plurals are formed mechanically at :613
    -- (label .. "s"), so every subclass here must have a regular plural.
    local subclassLabels = {
        [Enum.ItemHousingSubclass.Room] = "room plan",
        [Enum.ItemHousingSubclass.Dye] = "dye",
        [Enum.ItemHousingSubclass.RoomCustomization] = "customization",
        [Enum.ItemHousingSubclass.ExteriorCustomization] = "customization",
        [Enum.ItemHousingSubclass.ServiceItem] = "service item",
    }

    -- Room/ExteriorCustomization share the "customization" label above, so
    -- keying by that label merges them automatically.
    local byLabel = {}
    local remainder = stats.excluded
    local excludedBySubclass = stats.excludedBySubclass
    if excludedBySubclass then
        for subclassID, count in pairs(excludedBySubclass) do
            local singular = subclassLabels[subclassID]
            if singular then
                byLabel[singular] = (byLabel[singular] or 0) + count
                remainder = remainder - count
            end
        end
    end

    -- Resolved subclasses sort by count desc then label; the unresolved
    -- remainder ("housing item(s)") is a catch-all bucket, not a named
    -- class, so it always trails last regardless of its count.
    local parts = {}
    for label, count in pairs(byLabel) do
        parts[#parts + 1] = { label = label, count = count }
    end

    table.sort(parts, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.label < b.label
    end)

    if remainder > 0 then
        parts[#parts + 1] = { label = "housing item", count = remainder }
    end

    local segments = {}
    for _, part in ipairs(parts) do
        local label = part.count == 1 and part.label or (part.label .. "s")
        segments[#segments + 1] = string.format("%d %s", part.count, label)
    end

    return table.concat(segments, ", ")
end

-- Check if an item has unmet requirements the player hasn't satisfied
local function GetUnmetRequirements(itemID, npcID, presentation)
    local SM = HA.SourceManager
    if not SM then return nil end
    local reqs = SM:GetRequirements(itemID, npcID)

    local state = presentation and presentation.availabilityState
    local blockerLabels = presentation and presentation.blockerLabels

    if not presentation and SM.GetVendorItemAvailabilityState then
        local availability = { SM:GetVendorItemAvailabilityState(itemID, npcID) }
        state = availability[1]
        blockerLabels = availability[4]
    end

    if state == "locked" then
        local details = reqs or blockerLabels
        return details or true, details
    end

    if not reqs or #reqs == 0 then return nil end
    return nil, reqs
end

local function ComputeItemGridHeight(itemCount)
    if itemCount == 0 then return 0 end
    return math.ceil(itemCount / Layout.ICONS_PER_ROW) * (Layout.ITEM_ICON_SIZE + Layout.ITEM_ICON_PAD) + Layout.ITEM_ICON_PAD
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
local function PopulateItemGrid(row, vendor, sourceFilter, highlightItems, itemIDs)
    itemIDs = itemIDs or GetVendorItemIDs(vendor, sourceFilter)
    if #itemIDs == 0 then
        HideItemGrid(row)
        return 0
    end

    -- Create grid container if not yet created
    if not row.itemGrid then
        row.itemGrid = CreateFrame("Frame", nil, row)
        row.itemGrid:SetPoint("TOPLEFT", row, "TOPLEFT", Layout.ITEM_GRID_INSET, -Layout.ROW_HEIGHT)
        row.itemGrid:SetPoint("RIGHT", row, "RIGHT", -Layout.PADDING, 0)
        row.itemIcons = {}
    end

    local grid = row.itemGrid
    local icons = row.itemIcons

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
        local col = (i - 1) % Layout.ICONS_PER_ROW
        local gridRow = math.floor((i - 1) / Layout.ICONS_PER_ROW)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", grid, "TOPLEFT",
            col * (Layout.ITEM_ICON_SIZE + Layout.ITEM_ICON_PAD),
            -(gridRow * (Layout.ITEM_ICON_SIZE + Layout.ITEM_ICON_PAD)))

        -- Set icon texture (async via C_Item)
        local itemIcon = C_Item.GetItemIconByID(itemID)
        if itemIcon then
            icon.texture:SetTexture(itemIcon)
        else
            icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        local presentation = GetPanelItemPresentation(itemID, npcID, sourceFilter)
        local owned = presentation and presentation.isOwned
        if not presentation then
            owned = IsItemOwned(itemID)
        end
        local unmetReqs, allReqs = GetUnmetRequirements(itemID, npcID, presentation)
        icon.requirements = unmetReqs and allReqs or nil

        icon.texture:SetDesaturated(false)
        icon.texture:SetVertexColor(1, 1, 1)
        icon.lock:Hide()
        icon.check:Hide()

        if IsOwnershipExcluded(itemID, presentation) then
            -- HS-249: ownership not yet knowable — neutral grey border, no
            -- check and no lock tint. Tested first: neither the owned nor the
            -- available branch may claim an item we cannot resolve. The
            -- requirement tooltip is unaffected (icon.requirements is set
            -- above, outside this branch).
            icon.border:SetColorTexture(0.45, 0.45, 0.45, 1)
        elseif owned then
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

        -- HS-019: in search mode, dim non-matching items; matched items get a
        -- yellow outer ring (rendered behind the ownership border) so red/green
        -- /gold accessibility coloring + lock/check indicators remain readable.
        if highlightItems then
            if highlightItems[itemID] then
                icon.matchRing:Show()
            else
                icon.matchRing:Hide()
                icon.texture:SetDesaturated(true)
                icon.texture:SetVertexColor(0.4, 0.4, 0.4)
                icon.border:SetColorTexture(0.2, 0.2, 0.2, 0.5)
                icon.check:Hide()
                icon.lock:Hide()
            end
        else
            icon.matchRing:Hide()
        end

        icon:Show()
    end

    -- Release excess icons back to pool
    for i = #icons, #itemIDs + 1, -1 do
        ReleaseIcon(icons[i])
        icons[i] = nil
    end

    -- Calculate grid height
    local gridHeight = ComputeItemGridHeight(#itemIDs)
    grid:SetHeight(gridHeight - Layout.ITEM_ICON_PAD)
    grid:Show()

    return gridHeight
end

-------------------------------------------------------------------------------
-- HS-230: Instance Drop-Source Rows
--
-- Sibling of the vendor row/item-grid pair above, for instance maps
-- (C_EncounterJournal.GetEncountersOnMap(mapID) non-empty): one row per
-- boss present on the viewed map with Homestead drop items, expandable to
-- an item grid exactly like a vendor row's. Reuses every shared helper the
-- vendor path uses that isn't vendor-coupled (AcquireIcon/ReleaseIcon/
-- CreateItemIcon, BC.FormatCountText, GetPinColor, BeginPanelTooltip);
-- forks only where vendor-specific fields (npcID, faction, portal,
-- GetVendorItemIDs/GetPanelItemPresentation's isVendorContext=true) don't
-- apply to a boss/drop group.
-------------------------------------------------------------------------------

-- Groups HA.DropSources rows by journalEncounterID against the given
-- encounter array (from C_EncounterJournal.GetEncountersOnMap), in the
-- SAME order Blizzard returned them — bosses read in canonical order, not
-- itemID/table order. Items within a boss are sorted by itemID, matching
-- the HS-229 pin tooltip's stability convention. No entrance-fallback pass
-- here (unlike CollectEjDropPinRecords) — the panel only lists bosses
-- actually present on THIS map, per the spec ("a row per boss... present
-- on this map").
local function GetInstanceDropGroups(encounters)
    local drops = HA.DropSources
    if not drops or not encounters or #encounters == 0 then
        return {}
    end

    local recordsByEncounter = {}
    for itemID, drop in pairs(drops) do
        if drop.journalEncounterID then
            local list = recordsByEncounter[drop.journalEncounterID]
            if not list then
                list = {}
                recordsByEncounter[drop.journalEncounterID] = list
            end
            list[#list + 1] = { itemID = itemID, drop = drop }
        end
    end

    local groups = {}
    for _, enc in ipairs(encounters) do
        local records = enc.encounterID and recordsByEncounter[enc.encounterID]
        if records then
            table.sort(records, function(a, b) return a.itemID < b.itemID end)
            groups[#groups + 1] = {
                encounterID = enc.encounterID,
                records = records,
            }
        end
    end
    return groups
end

-- HS-229's own dropMapPin presentation context — same context string
-- AddPinTooltipItemLine (VendorPinTooltips.lua) and BuildDropGroupStats
-- (BadgeCalculation.lua) already use, so this is provably the same
-- cache-backed call, not a new SourceManager surface.
local function GetDropItemPresentation(itemID)
    local SM = HA.SourceManager
    if not SM or not SM.GetItemPresentation then return nil end
    return SM:GetItemPresentation(itemID, {
        context = "dropMapPin",
        sourceFilter = "drop",
        isVendorContext = false,
    })
end

local function CreateBossRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(Layout.ROW_HEIGHT)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)

    -- Same decor-drop art as the world-map drop pin (PinFrameFactory:CreateDropPinFrame)
    -- so the panel row and the pin read as the same feature.
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(Layout.ICON_SIZE, Layout.ICON_SIZE)
    icon:SetPoint("TOPLEFT", Layout.PADDING, -4)
    icon:SetTexture(HA.Constants.TEXTURE_ROOT .. "HomesteadDropIcon_32")
    row.icon = icon

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, 0)
    nameText:SetPoint("RIGHT", row, "RIGHT", -Layout.PADDING, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    local countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("TOPLEFT", icon, "BOTTOMRIGHT", 6, -2)
    countText:SetPoint("RIGHT", row, "RIGHT", -Layout.PADDING, 0)
    countText:SetJustifyH("LEFT")
    row.countText = countText

    local sep = row:CreateTexture(nil, "BACKGROUND")
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT", 4, 0)
    sep:SetPoint("BOTTOMRIGHT", -4, 0)
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.4)

    row.dropGroup = nil

    row:RegisterForClicks("AnyUp")

    row:SetScript("OnClick", function(self)
        if not self.dropGroup then return end
        if State.expandedBossKey == self.dropGroup.encounterID then
            State.expandedBossKey = nil
        else
            State.expandedBossKey = self.dropGroup.encounterID
        end
        MapSidePanel:RefreshContent()
    end)

    row:SetScript("OnEnter", function(self)
        if not self.dropGroup then return end
        local primaryDrop = self.dropGroup.records[1].drop
        local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
        tooltip:AddLine((primaryDrop and primaryDrop.mobName) or "Unknown", 1, 1, 1)
        if primaryDrop and primaryDrop.zone then
            tooltip:AddLine(primaryDrop.zone, 0.7, 0.7, 0.7)
        end
        if self.total and self.total > 0 then
            local stats = BC:GetDropGroupStats(self.dropGroup.records)
            BC.AddSummaryLine(tooltip, stats.collected, stats.total, stats.locked, 0)
        end
        tooltip:AddLine(" ")
        tooltip:AddLine("Click to show items", 0.5, 0.5, 0.5)
        tooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        HidePanelTooltip()
    end)

    return row
end

-- Populate the item grid for a boss row. Returns total height of the grid.
-- Same pooling/layout math as PopulateItemGrid; only the item-list source
-- (dropGroup.records, already itemID-sorted) and the per-item lookup
-- (GetDropItemPresentation instead of GetPanelItemPresentation's
-- npcID/isVendorContext=true path) differ.
local function PopulateBossItemGrid(row, dropGroup)
    local records = dropGroup and dropGroup.records
    if not records or #records == 0 then
        HideItemGrid(row)
        return 0
    end

    if not row.itemGrid then
        row.itemGrid = CreateFrame("Frame", nil, row)
        row.itemGrid:SetPoint("TOPLEFT", row, "TOPLEFT", Layout.ITEM_GRID_INSET, -Layout.ROW_HEIGHT)
        row.itemGrid:SetPoint("RIGHT", row, "RIGHT", -Layout.PADDING, 0)
        row.itemIcons = {}
    end

    local grid = row.itemGrid
    local icons = row.itemIcons

    while #icons < #records do
        icons[#icons + 1] = AcquireIcon(grid)
    end

    for i, itemRecord in ipairs(records) do
        local itemID = itemRecord.itemID
        local icon = icons[i]
        icon.itemID = itemID
        icon.npcID = nil

        local col = (i - 1) % Layout.ICONS_PER_ROW
        local gridRow = math.floor((i - 1) / Layout.ICONS_PER_ROW)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", grid, "TOPLEFT",
            col * (Layout.ITEM_ICON_SIZE + Layout.ITEM_ICON_PAD),
            -(gridRow * (Layout.ITEM_ICON_SIZE + Layout.ITEM_ICON_PAD)))

        local itemIcon = C_Item.GetItemIconByID(itemID)
        if itemIcon then
            icon.texture:SetTexture(itemIcon)
        else
            icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        local presentation = GetDropItemPresentation(itemID)
        local owned = presentation and presentation.isOwned
        if not presentation then
            owned = IsItemOwned(itemID)
        end
        -- HS-200: no live SM:GetRequirements(itemID, npcID) call — a drop
        -- item has no npcID to scope requirements to. presentation's own
        -- availabilityState/blockerLabels (already computed by the same
        -- cache-backed GetItemPresentation call above) carry the same
        -- information GetUnmetRequirements derives for vendor items.
        local unmetReqs = presentation and presentation.availabilityState == "locked"
        icon.requirements = unmetReqs and presentation.blockerLabels or nil

        icon.texture:SetDesaturated(false)
        icon.texture:SetVertexColor(1, 1, 1)
        icon.lock:Hide()
        icon.check:Hide()
        if icon.matchRing then icon.matchRing:Hide() end

        -- HS-249: same neutral state as the vendor grid, same reason.
        if IsOwnershipExcluded(itemID, presentation) then
            icon.border:SetColorTexture(0.45, 0.45, 0.45, 1)
        elseif owned then
            icon.border:SetColorTexture(0.2, 0.7, 0.2, 1)
            icon.check:Show()
        elseif unmetReqs then
            icon.border:SetColorTexture(0.7, 0.15, 0.15, 1)
            icon.texture:SetDesaturated(true)
            icon.texture:SetVertexColor(0.6, 0.4, 0.4)
            icon.lock:Show()
        else
            icon.border:SetColorTexture(0.6, 0.5, 0.2, 1)
        end

        icon:Show()
    end

    for i = #icons, #records + 1, -1 do
        ReleaseIcon(icons[i])
        icons[i] = nil
    end

    local gridHeight = ComputeItemGridHeight(#records)
    grid:SetHeight(gridHeight - Layout.ITEM_ICON_PAD)
    grid:Show()

    return gridHeight
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

local function ApplySourceBadge(texture, sourceType, atlas, icon)
    if not texture or (not sourceType and not atlas and not icon) then
        if texture then texture:Hide() end
        return
    end

    atlas = atlas or GetSourceBadgeAtlas(sourceType)
    if atlas then
        texture:SetTexture(nil)
        texture:SetAtlas(atlas, false)
        texture:SetTexCoord(0, 1, 0, 1)
    else
        local SM = HA.SourceManager
        icon = icon or (SM and SM.GetSourceTypeIcon and SM:GetSourceTypeIcon(sourceType))
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
    line:SetHeight(Layout.ITEM_RESULT_LINE_HEIGHT)

    local badge = line:CreateTexture(nil, "ARTWORK")
    badge:SetSize(Layout.ITEM_RESULT_BADGE_SIZE, Layout.ITEM_RESULT_BADGE_SIZE)
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

local function ComputeItemSourceListHeight(sourceCount)
    return math.max(1, sourceCount) * Layout.ITEM_RESULT_LINE_HEIGHT + 4
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
        row.sourcesFrame:SetPoint("TOPLEFT", row, "TOPLEFT", Layout.PADDING + Layout.ITEM_RESULT_ICON_SIZE + 8, -Layout.ROW_HEIGHT - 2)
        row.sourcesFrame:SetPoint("TOPRIGHT", row, "TOPRIGHT", -Layout.PADDING, -Layout.ROW_HEIGHT - 2)
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
            line:SetPoint("TOPLEFT", sourcesFrame, "TOPLEFT", 0, -((i - 1) * Layout.ITEM_RESULT_LINE_HEIGHT))
            line:SetPoint("TOPRIGHT", sourcesFrame, "TOPRIGHT", 0, -((i - 1) * Layout.ITEM_RESULT_LINE_HEIGHT))
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

    local totalHeight = ComputeItemSourceListHeight(renderedCount)
    sourcesFrame:SetHeight(totalHeight)
    sourcesFrame:Show()
    return totalHeight
end

-- HS-019: search-result section header. Non-interactive divider that labels
-- the section by source type (Vendors / Profession / Quest / Achievement /
-- Event / Drop). One per active section; emitted on type transitions in
-- RefreshSearchResults.
Layout.SEARCH_HEADER_HEIGHT = 22

local function CreateSearchHeaderRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(Layout.SEARCH_HEADER_HEIGHT)

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", row, "CENTER", 0, 0)
    text:SetTextColor(1, 0.82, 0)
    row.text = text

    -- HS-019: hairlines bracket the centered label. Anchored to the text's
    -- left/right edges with a 6px gap, so they reflow automatically when
    -- different section labels (different lengths) are set.
    local leftLine = row:CreateTexture(nil, "ARTWORK")
    leftLine:SetHeight(1)
    leftLine:SetPoint("LEFT", row, "LEFT", Layout.PADDING, 0)
    leftLine:SetPoint("RIGHT", text, "LEFT", -6, 0)
    leftLine:SetColorTexture(1, 0.82, 0, 0.4)

    local rightLine = row:CreateTexture(nil, "ARTWORK")
    rightLine:SetHeight(1)
    rightLine:SetPoint("LEFT", text, "RIGHT", 6, 0)
    rightLine:SetPoint("RIGHT", row, "RIGHT", -Layout.PADDING, 0)
    rightLine:SetColorTexture(1, 0.82, 0, 0.4)

    return row
end

local function CreateItemResultRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(Layout.ROW_HEIGHT)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)

    local iconBorder = row:CreateTexture(nil, "BACKGROUND")
    iconBorder:SetSize(Layout.ITEM_RESULT_ICON_SIZE + 2, Layout.ITEM_RESULT_ICON_SIZE + 2)
    iconBorder:SetPoint("TOPLEFT", row, "TOPLEFT", Layout.PADDING, -7)
    iconBorder:SetColorTexture(0.25, 0.25, 0.25, 1)
    row.iconBorder = iconBorder

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(Layout.ITEM_RESULT_ICON_SIZE, Layout.ITEM_RESULT_ICON_SIZE)
    icon:SetPoint("TOPLEFT", row, "TOPLEFT", Layout.PADDING + 1, -8)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
    nameText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -Layout.PADDING, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    local sourceBadge = row:CreateTexture(nil, "ARTWORK")
    sourceBadge:SetSize(Layout.ITEM_RESULT_BADGE_SIZE, Layout.ITEM_RESULT_BADGE_SIZE)
    sourceBadge:SetPoint("TOPLEFT", row, "TOPLEFT", Layout.PADDING + Layout.ITEM_RESULT_ICON_SIZE + 8, -20)
    row.sourceBadge = sourceBadge

    local sourceText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sourceText:SetPoint("LEFT", sourceBadge, "RIGHT", 6, 0)
    sourceText:SetPoint("RIGHT", row, "RIGHT", -Layout.PADDING, 0)
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

        if State.expandedItemID == self.itemID then
            State.expandedItemID = nil
        else
            State.expandedItemID = self.itemID
        end
        MapSidePanel:RefreshContent()
    end)

    row:SetScript("OnEnter", function(self)
        if not self.itemID then return end

        local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
        HA.SetManagedItemTooltip(tooltip, self.itemID)
        tooltip:AddLine(" ")
        if State.expandedItemID == self.itemID then
            tooltip:AddLine("Click to collapse sources", 0.5, 0.5, 0.5)
        else
            tooltip:AddLine("Click to show all sources", 0.5, 0.5, 0.5)
        end
        tooltip:Show()
    end)

    row:SetScript("OnLeave", HidePanelTooltip)

    return row
end

local function RenderItemRow(row, rec)
    local result = rec.result
    local sourceFilter = State.panelSourceFilter

    local itemID = result.itemID
    local itemName = result.itemName or C_Item.GetItemNameByID(itemID) or ("Item " .. tostring(itemID))
    local itemIcon = C_Item.GetItemIconByID(itemID)
    local presentation = GetPanelItemPresentation(itemID, nil, sourceFilter, result)
    local displaySources = presentation and presentation.displaySources or GetDisplaySourcesForItem(itemID, sourceFilter)
    local preferredSource = presentation and presentation.displaySource or GetPreferredDisplaySource(result, displaySources)

    row.itemID = itemID
    row.result = result
    row.icon:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.nameText:SetText(itemName)

    local owned = presentation and presentation.isOwned
    if not presentation then
        owned = IsItemOwned(itemID)
    end

    -- HS-249: same neutral state as the item grids, same reason.
    if IsOwnershipExcluded(itemID, presentation) then
        row.iconBorder:SetColorTexture(0.45, 0.45, 0.45, 1)
        row.nameText:SetTextColor(1, 1, 1)
    elseif owned then
        row.iconBorder:SetColorTexture(0.2, 0.7, 0.2, 1)
        row.nameText:SetTextColor(0.7, 1, 0.7)
    else
        row.iconBorder:SetColorTexture(0.6, 0.5, 0.2, 1)
        row.nameText:SetTextColor(1, 1, 1)
    end

    if preferredSource then
        ApplySourceBadge(row.sourceBadge, preferredSource.type,
            presentation and presentation.sourceBadgeAtlas,
            presentation and presentation.sourceIcon)
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

    if rec.isExpanded then
        PopulateItemSourceList(row, itemID, sourceFilter)
    else
        HideItemSourceList(row)
    end
end

-------------------------------------------------------------------------------
-- Search Helpers
-------------------------------------------------------------------------------

local function ExecuteSearch()
    State.searchDebounceTimer = nil
    local SP = HA.SearchProvider
    if not SP then return end
    local query = State.searchEditBox and State.searchEditBox:GetText() or ""
    query = query:match("^%s*(.-)%s*$") or ""  -- trim
    State.searchText = query
    if query == "" then
        State.searchResults = nil
        State.searchResultsRevision = nil
    else
        State.searchResults = SP:Search(query, SEARCH_OPTIONS)
        State.searchResultsRevision = SP:GetRevision()
    end
    MapSidePanel:RefreshContent()
end

local function ClearSearch(refreshNow)
    State.searchText = ""
    State.searchResults = nil
    State.searchResultsRevision = nil
    State.expandedItemID = nil
    if State.searchDebounceTimer then State.searchDebounceTimer:Cancel(); State.searchDebounceTimer = nil end
    if State.searchEditBox then
        State.suppressTextChanged = true
        State.searchEditBox:SetText("")
        State.suppressTextChanged = false
    end
    if refreshNow then
        MapSidePanel:RefreshContent()
    end
end

-------------------------------------------------------------------------------
-- Row Creation
-------------------------------------------------------------------------------

local function CreateVendorRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(Layout.ROW_HEIGHT)

    -- Highlight on hover
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)

    -- Pin color indicator (small circle)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(Layout.ICON_SIZE, Layout.ICON_SIZE)
    icon:SetPoint("TOPLEFT", Layout.PADDING, -4)
    icon:SetAtlas("poi-door")
    icon:SetDesaturated(true)
    row.icon = icon

    -- Vendor name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, 0)
    nameText:SetPoint("RIGHT", row, "RIGHT", -Layout.PADDING, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- Collection count
    local countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("TOPLEFT", icon, "BOTTOMRIGHT", 6, -2)
    countText:SetPoint("RIGHT", row, "RIGHT", -Layout.PADDING, 0)
    countText:SetJustifyH("LEFT")
    countText:SetWordWrap(false)
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

        local npcID = self.vendor.npcID
        if State.expandedVendorID == npcID then
            State.expandedVendorID = nil
        else
            State.expandedVendorID = npcID
            -- Search mode: also navigate the world map to this vendor's zone.
            if self.searchMode then
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
            local stats = BC:GetVendorStats(self.vendor, State.panelSourceFilter)
            BC.AddSummaryLine(tooltip, stats.collected, stats.total, stats.locked, stats.unverified)
        end
        tooltip:AddLine(" ")
        if self.searchMode then
            if self.vendor.expansion then
                tooltip:AddLine(self.vendor.expansion, 0.5, 0.5, 0.5)
            end
            if State.expandedVendorID == self.vendor.npcID then
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

local function CreateSummaryRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(Layout.ROW_HEIGHT)

    -- Highlight on hover
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)

    -- Expand/collapse arrow icon (toggles between forward and down)
    local arrow = row:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(12, 12)
    arrow:SetPoint("TOPLEFT", Layout.PADDING, -4)
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
        local level = State.currentDisplayLevel
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
                State.lastRefreshMapID = self.targetMapID
                MapSidePanel:RefreshContent()
            end
        else
            -- Left-click: toggle expand/collapse
            if State.expandedSummaryMapID == self.targetMapID then
                State.expandedSummaryMapID = nil
            else
                State.expandedSummaryMapID = self.targetMapID
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

-- Unified cleanup helper: hides the back bar and clears the map pin highlight.
-- Called in every early-return and level-switch path. It no longer touches the
-- list itself; rows are cleared by replacing the list's data provider.
local function HideAllNonVendorContent()
    if State.backBar then State.backBar:Hide() end
    if HA.VendorMapPins then HA.VendorMapPins:ClearHighlight() end
end

-------------------------------------------------------------------------------
-- Summary Sub-Row Creation (expandable children of summary rows)
-------------------------------------------------------------------------------

Layout.SUB_ROW_HEIGHT = 24
Layout.SUB_ROW_INDENT = 20

local function CreateSummarySubRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(Layout.SUB_ROW_HEIGHT)
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
    icon:SetPoint("LEFT", Layout.SUB_ROW_INDENT, 0)
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
    countText:SetPoint("RIGHT", row, "RIGHT", -Layout.PADDING, 0)
    countText:SetJustifyH("RIGHT")
    row.countText = countText

    -- Clamp name text to not overlap count
    nameText:SetPoint("RIGHT", countText, "LEFT", -4, 0)

    -- Separator
    local sep = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT", Layout.SUB_ROW_INDENT, 0)
    sep:SetPoint("BOTTOMRIGHT", -4, 0)
    sep:SetColorTexture(0.25, 0.25, 0.25, 0.3)

    row.vendor = nil      -- vendor reference (for zone expansion sub-rows)
    row.targetMapID = nil  -- zone mapID to navigate to on click

    row:SetScript("OnClick", function(self)
        if not self.targetMapID then return end
        -- Pre-set State.expandedVendorID so the item grid opens at zone level
        if self.vendor and self.vendor.npcID then
            State.expandedVendorID = self.vendor.npcID
        end
        if WorldMapFrame:IsShown() then
            WorldMapFrame:SetMapID(self.targetMapID)
        else
            -- Detached mode: navigate via internal state
            State.lastRefreshMapID = self.targetMapID
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

local CREATORS = {
    vendor = CreateVendorRow,
    summary = CreateSummaryRow,
    subrow = CreateSummarySubRow,
    boss = CreateBossRow,
    item = CreateItemResultRow,
    header = CreateSearchHeaderRow,
}

-- The pool invokes createFunc() with no arguments, so a fresh row is built
-- parentless; RenderListElement's SetParent gives it its container, on the
-- first render and on every reuse alike.
local function AcquireRowContent(kind)
    return FPU.AcquirePooledFrame(State.rowPool, kind, CREATORS[kind])
end

local function RenderVendorRow(row, rec)
    local r, g, b = HA.PinFrameFactory:GetPinColor()
    local vendor = rec.vendor

    row.vendor = vendor
    row.searchMode = rec.searchMode
    row.searchMatchedItems = rec.matchedItems

    row.nameText:SetText(GetVendorDisplayName(vendor))
    row.nameText:SetTextColor(rec.nameColor[1], rec.nameColor[2], rec.nameColor[3])

    -- Set icon color
    row.icon:SetDesaturated(true)
    row.icon:SetVertexColor(r, g, b)

    row.collected = rec.collected
    row.total = rec.total
    row.locked = rec.locked

    row.countText:SetText(rec.countText)
    row.countText:SetTextColor(rec.countColor[1], rec.countColor[2], rec.countColor[3])

    if rec.isExpanded then
        PopulateItemGrid(row, vendor, State.panelSourceFilter, rec.matchedItems, rec.itemIDs)
    else
        HideItemGrid(row)
    end
end

local function RenderSummaryRow(row, rec)
    row.targetMapID = rec.targetMapID
    row.vendorCount = rec.vendorCount
    row.collectedItems = rec.collectedItems
    row.totalItems = rec.totalItems
    row.lockedItems = rec.lockedItems
    row.unverifiedItems = rec.unverifiedItems

    row.nameText:SetText(rec.name)
    row.nameText:SetTextColor(rec.nameColor[1], rec.nameColor[2], rec.nameColor[3])

    -- Arrow icon: down if expanded, forward if collapsed
    row.arrow:SetAtlas(rec.isExpanded and "common-icon-downarrow" or "common-icon-forwardarrow")

    row.summaryLine:SetText(rec.summaryLineText)
    if rec.summaryLineColor then
        row.summaryLine:SetTextColor(rec.summaryLineColor[1], rec.summaryLineColor[2], rec.summaryLineColor[3])
    end
end

local function RenderSubRow(row, rec)
    local r, g, b = HA.PinFrameFactory:GetPinColor()

    row.vendor = rec.vendor
    row.targetMapID = rec.targetMapID
    row.tooltipText = rec.tooltipText
    row.tooltipSub = rec.tooltipSub
    row.isOrderHall = rec.isOrderHall

    row.nameText:SetText(rec.name)
    row.nameText:SetTextColor(0.9, 0.9, 0.9)

    row.countText:SetText(rec.countText)
    if rec.countColor then
        row.countText:SetTextColor(rec.countColor[1], rec.countColor[2], rec.countColor[3])
    end

    if rec.iconMode == "vendor" then
        -- Pin color for icon
        row.icon:SetVertexColor(r, g, b)
    else
        -- Zone icon
        row.icon:SetAtlas("poi-door")
        row.icon:SetVertexColor(0.7, 0.7, 0.7)
    end
end

local function RenderBossRow(row, rec)
    local r, g, b = HA.PinFrameFactory:GetPinColor()

    row.dropGroup = rec.dropGroup

    row.nameText:SetText(rec.name)
    row.nameText:SetTextColor(1, 1, 1)

    row.icon:SetDesaturated(true)
    row.icon:SetVertexColor(r, g, b)

    row.collected = rec.collected
    row.total = rec.total
    row.locked = rec.locked

    row.countText:SetText(rec.countText)
    row.countText:SetTextColor(rec.countColor[1], rec.countColor[2], rec.countColor[3])

    if rec.isExpanded then
        PopulateBossItemGrid(row, rec.dropGroup)
    else
        HideItemGrid(row)
    end
end

local function RenderHeaderRow(row, rec)
    row.text:SetText(rec.label)
end

local RENDERERS = {
    vendor = RenderVendorRow,
    summary = RenderSummaryRow,
    subrow = RenderSubRow,
    boss = RenderBossRow,
    item = RenderItemRow,
    header = RenderHeaderRow,
}

-- ScrollBox element initializer. Render before Show: a frame shown under a
-- stationary cursor fires OnEnter on the next update, and the resetter has
-- just cleared every field those handlers read.
local function RenderListElement(container, rec)
    local content = AcquireRowContent(rec.kind)
    content:SetParent(container)
    content:ClearAllPoints()
    content:SetAllPoints(container)
    container.content = content
    RENDERERS[rec.kind](content, rec)
    content:Show()
end

local function ResetListElement(container)
    local content = container.content
    if not content then return end
    HideItemGrid(content)
    HideItemSourceList(content)
    content.vendor, content.dropGroup, content.result, content.itemID = nil, nil, nil, nil
    content.targetMapID, content.tooltipText, content.tooltipSub, content.isOrderHall = nil, nil, nil, nil
    content.searchMode, content.searchMatchedItems = false, nil
    content.collected, content.total, content.locked = nil, nil, nil
    content.vendorCount, content.totalItems = 0, 0
    content.collectedItems, content.lockedItems, content.unverifiedItems = nil, nil, nil
    content:Hide()
    content:ClearAllPoints()
    FPU.ReleasePooledFrame(State.rowPool, content)
    container.content = nil
end

local function SetListRows(rows)
    State.listScrollBox:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)
end

-- Build zone expansion: append vendor sub-row records for a zone at continent level.
-- Uses same data source as badge calculation (GetAllVendors + VendorFilter).
local function BuildZoneExpansionRows(zoneMapID, rows)
    if not VendorData or not BC then return end

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

    for _, vendor in ipairs(zoneVendors) do
        -- Use vendor's actual mapID for navigation (important for merged sibling zones)
        local _, vendorMapID = VendorFilter.GetBestVendorCoordinates(vendor)

        -- Collection counts using same filter as panel
        local stats = BC:GetVendorStats(vendor, State.panelSourceFilter)
        local countText, countColor, tooltipSub
        if (stats.total or 0) > 0 then
            countText = FormatPurchasabilityCountText(stats.collected, stats.total, stats.locked)
            countColor = Layout.COLOR_WHITE
            tooltipSub = string.format("Collected: %d/%d", stats.collected or 0, stats.total or 0)
        else
            countText = ""
        end

        rows[#rows + 1] = {
            kind = "subrow",
            height = Layout.SUB_ROW_HEIGHT,
            iconMode = "vendor",
            vendor = vendor,
            targetMapID = vendorMapID or zoneMapID,
            tooltipText = vendor.name or "Unknown",
            tooltipSub = tooltipSub,
            isOrderHall = vendor.mapID and ORDER_HALL_MAPS[vendor.mapID] or false,
            name = GetVendorDisplayName(vendor),
            countText = countText,
            countColor = countColor,
        }
    end
end

-- Build continent expansion: append zone sub-row records for a continent at world level.
local function BuildContinentExpansionRows(continentMapID, rows)
    if not BC then return end

    local zoneCounts = BC:GetZoneVendorCounts(continentMapID, State.panelSourceFilter)

    -- Build sorted zone list
    local zoneList = {}
    for zoneMapID, data in pairs(zoneCounts) do
        zoneList[#zoneList + 1] = { mapID = zoneMapID, data = data }
    end
    table.sort(zoneList, function(a, b)
        return (a.data.zoneName or "") < (b.data.zoneName or "")
    end)

    for _, entry in ipairs(zoneList) do
        local data = entry.data
        local dataVendorCount = data.vendorCount or 0
        local dataCollected = data.collectedItems or 0
        local dataTotal = data.totalItems or 0

        -- Zone collection counts
        local dataLocked = data.lockedItems or 0
        local countText, countColor, tooltipSub
        if dataTotal > 0 then
            countText = FormatPurchasabilityCountText(dataCollected, dataTotal, dataLocked)
            countColor = Layout.COLOR_WHITE
            tooltipSub = string.format("%d vendors | %d/%d collected",
                dataVendorCount, dataCollected, dataTotal)
        else
            countText = string.format("%d vendors", dataVendorCount)
            countColor = Layout.COLOR_DIM
            tooltipSub = string.format("%d vendors", dataVendorCount)
        end

        rows[#rows + 1] = {
            kind = "subrow",
            height = Layout.SUB_ROW_HEIGHT,
            iconMode = "zone",
            targetMapID = entry.mapID,
            tooltipText = data.zoneName or "Unknown",
            tooltipSub = tooltipSub,
            isOrderHall = false,
            name = data.zoneName or "Unknown",
            countText = countText,
            countColor = countColor,
        }
    end
end

-------------------------------------------------------------------------------
-- Panel Frame Creation
-------------------------------------------------------------------------------

local function CreatePanel()
    if State.panelFrame then return end

    -- Main panel frame, parented to UIParent with cross-parent anchoring to
    -- the map canvas. Sits flush against the left edge of the canvas.
    -- When shown, the map shifts right to make room (see State.ShiftMapRight).
    -- Styled using Blizzard's NineSlice border system to match the map frame.
    -- Anonymous to avoid tainting UIParentPanelManager's CloseWindows() iteration.
    local canvas = WorldMapFrame.ScrollContainer
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetWidth(Layout.PANEL_WIDTH)
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
    State.topTileFrame = panel:CreateTexture(nil, "ARTWORK")
    State.topTileFrame:SetAtlas("_UI-Frame-InnerTopTile", false)
    State.topTileFrame:SetHorizTile(true)
    State.topTileFrame:SetHeight(10)
    State.topTileFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -18)
    State.topTileFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -18)

    -- 3. BACKGROUND FILL: Blizzard's quest log background atlas.
    --    Fills full panel by default (standalone/detached). In integrated mode,
    --    ApplyContentInset adjusts the top anchor below the header zone so the
    --    dark background doesn't bleed into the map's border area.
    State.bgTexture = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    State.bgTexture:SetAtlas("QuestLogBackground", false)
    State.bgTexture:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    State.bgTexture:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

    -- Decorative streaks overlay on the inner top border
    State.topStreaksFrame = panel:CreateTexture(nil, "ARTWORK", nil, 1)
    State.topStreaksFrame:SetAtlas("_UI-Frame-TopTileStreaks", false)
    State.topStreaksFrame:SetHorizTile(true)
    State.topStreaksFrame:SetHeight(10)
    State.topStreaksFrame:SetPoint("TOPLEFT", State.topTileFrame, "TOPLEFT", 0, 0)
    State.topStreaksFrame:SetPoint("TOPRIGHT", State.topTileFrame, "TOPRIGHT", 0, 0)

    -- Content insets (inside NineSlice border)
    local BORDER_LEFT = 10
    local BORDER_RIGHT = 10
    local BORDER_TOP = 22  -- Reduced from 28 (portrait corner was larger)
    local BORDER_BOTTOM = 10

    -- Title header (centered horizontally)
    State.headerFrame = CreateFrame("Frame", nil, panel)
    State.headerFrame:SetHeight(Layout.HEADER_HEIGHT)
    State.headerFrame:SetPoint("TOPLEFT", BORDER_LEFT, -BORDER_TOP)
    State.headerFrame:SetPoint("TOPRIGHT", -BORDER_RIGHT, -BORDER_TOP)

    -- Homestead label (centered, below inner top border tile)
    local titleLabel = State.headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleLabel:SetPoint("TOP", State.headerFrame, "TOP", 0, -4)
    titleLabel:SetText("Homestead")

    -- Zone/map name (centered below title)
    State.headerText = State.headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    State.headerText:SetPoint("TOP", titleLabel, "BOTTOM", 0, -3)
    State.headerText:SetJustifyH("CENTER")
    State.headerText:SetWordWrap(false)
    State.headerText:SetTextColor(0.7, 0.7, 0.7)
    State.headerText:SetText("")

    -- Header separator line
    local headerSep = State.headerFrame:CreateTexture(nil, "ARTWORK")
    headerSep:SetHeight(1)
    headerSep:SetPoint("BOTTOMLEFT", State.headerFrame, "BOTTOMLEFT", 0, 0)
    headerSep:SetPoint("BOTTOMRIGHT", State.headerFrame, "BOTTOMRIGHT", 0, 0)
    headerSep:SetColorTexture(0.4, 0.4, 0.4, 0.5)

    -- Source filter row below the title header. Kept outside State.headerFrame so
    -- the native dropdown cannot overlap the centered Homestead title.
    State.sourceFilterBar = CreateFrame("Frame", nil, panel)
    State.sourceFilterBar:SetHeight(24)
    State.sourceFilterBar:SetPoint("TOPLEFT", State.headerFrame, "BOTTOMLEFT", 0, -1)
    State.sourceFilterBar:SetPoint("TOPRIGHT", State.headerFrame, "BOTTOMRIGHT", 0, -1)

    -- Summary line (centered at bottom)
    State.summaryText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    State.summaryText:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", BORDER_LEFT, BORDER_BOTTOM)
    State.summaryText:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -BORDER_RIGHT, BORDER_BOTTOM)
    State.summaryText:SetJustifyH("CENTER")
    State.summaryText:SetTextColor(0.6, 0.6, 0.6)

    -- Search bar (above summary line at bottom)
    State.searchBar = CreateFrame("Frame", nil, panel)
    State.searchBar:SetHeight(22)
    State.searchBar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", BORDER_LEFT, BORDER_BOTTOM + 16)
    State.searchBar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -BORDER_RIGHT, BORDER_BOTTOM + 16)
    State.searchEditBox = CreateFrame("EditBox", nil, State.searchBar, "SearchBoxTemplate")
    State.searchEditBox:SetFontObject(GameFontHighlightSmall)
    State.searchEditBox:SetPoint("TOPLEFT", State.searchBar, "TOPLEFT", 0, 0)
    State.searchEditBox:SetPoint("BOTTOMRIGHT", State.searchBar, "BOTTOMRIGHT", 0, 0)
    State.searchEditBox:SetMaxLetters(50)

    State.searchEditBox.Instructions:SetText("Search items, vendors...")
    State.searchEditBox.clearButton:HookScript("OnClick", function()
        ClearSearch(true)
        State.searchEditBox:ClearFocus()
    end)

    State.searchEditBox:HookScript("OnTextChanged", function()
        if State.suppressTextChanged then return end
        if State.searchDebounceTimer then State.searchDebounceTimer:Cancel() end
        State.searchDebounceTimer = C_Timer.NewTimer(0.3, ExecuteSearch)
    end)

    State.searchEditBox:HookScript("OnEditFocusGained", function()
        if HA.SearchProvider then
            HA.SearchProvider:PreWarm()
        end
    end)

    State.searchEditBox:HookScript("OnEscapePressed", function(self)
        ClearSearch(true)
        self:ClearFocus()
    end)

    State.searchEditBox:HookScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    -- Back navigation bar (between header and progress bar / scroll area)
    State.backBar = CreateFrame("Button", nil, panel)
    State.backBar:SetHeight(20)
    State.backBar:SetPoint("TOPLEFT", State.sourceFilterBar, "BOTTOMLEFT", 0, 0)
    State.backBar:SetPoint("TOPRIGHT", State.sourceFilterBar, "BOTTOMRIGHT", 0, 0)

    local backArrow = State.backBar:CreateTexture(nil, "ARTWORK")
    backArrow:SetSize(12, 12)
    backArrow:SetPoint("LEFT", 8, 0)
    backArrow:SetAtlas("common-icon-backarrow")
    State.backBar.arrow = backArrow

    local backText = State.backBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    backText:SetPoint("LEFT", backArrow, "RIGHT", 4, 0)
    backText:SetPoint("RIGHT", State.backBar, "RIGHT", -8, 0)
    backText:SetJustifyH("LEFT")
    backText:SetTextColor(0.5, 0.7, 1.0)
    State.backBar.text = backText

    local backHighlight = State.backBar:CreateTexture(nil, "HIGHLIGHT")
    backHighlight:SetAllPoints()
    backHighlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)

    local backSep = State.backBar:CreateTexture(nil, "BACKGROUND")
    backSep:SetHeight(1)
    backSep:SetPoint("BOTTOMLEFT", 4, 0)
    backSep:SetPoint("BOTTOMRIGHT", -4, 0)
    backSep:SetColorTexture(0.3, 0.3, 0.3, 0.4)

    State.backBar:SetScript("OnClick", function()
        MapSidePanel:NavigateBack()
    end)
    State.backBar:SetScript("OnEnter", function(self)
        local tooltip = BeginPanelTooltip(self, "ANCHOR_BOTTOM")
        tooltip:SetText("Go back")
        tooltip:Show()
    end)
    State.backBar:SetScript("OnLeave", HidePanelTooltip)
    State.backBar:Hide()

    -- Progress bar (between header and scroll area, shown at zone level)
    State.progressBar = CreateFrame("StatusBar", nil, panel)
    State.progressBar:SetHeight(Layout.PROGRESS_BAR_HEIGHT)
    State.progressBar:SetPoint("TOPLEFT", State.sourceFilterBar, "BOTTOMLEFT", 0, -3)
    State.progressBar:SetPoint("TOPRIGHT", State.sourceFilterBar, "BOTTOMRIGHT", 0, -3)
    State.progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    State.progressBar:SetStatusBarColor(0.2, 0.6, 0.8)
    State.progressBar:Hide()

    -- Dark background behind fill
    State.progressBarBg = State.progressBar:CreateTexture(nil, "BACKGROUND")
    State.progressBarBg:SetAllPoints()
    State.progressBarBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    -- Full-width purchasable fill (muted gold, sits behind the blue collected fill)
    -- The blue StatusBar fill covers collected items from the left; the red locked
    -- fill covers locked items from the right; this middle layer fills the rest
    -- so the purchasable segment has a visible color instead of just dark background.
    State.progressBarPurchasableFill = State.progressBar:CreateTexture(nil, "ARTWORK", nil, -1)
    State.progressBarPurchasableFill:SetAllPoints()
    State.progressBarPurchasableFill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    State.progressBarPurchasableFill:SetVertexColor(0.9, 0.7, 0.0, 0.8)

    -- Right-anchored locked fill (nested StatusBar so it renders with the same
    -- gradient stripes as the blue fill, not a flat texture)
    State.progressBarLockedFill = CreateFrame("StatusBar", nil, State.progressBar)
    State.progressBarLockedFill:SetPoint("TOPRIGHT", State.progressBar, "TOPRIGHT", 0, 0)
    State.progressBarLockedFill:SetPoint("BOTTOMRIGHT", State.progressBar, "BOTTOMRIGHT", 0, 0)
    State.progressBarLockedFill:SetWidth(0)
    State.progressBarLockedFill:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    State.progressBarLockedFill:SetStatusBarColor(0.80, 0.20, 0.20, 0.95)
    State.progressBarLockedFill:SetMinMaxValues(0, 1)
    State.progressBarLockedFill:SetValue(1)
    State.progressBarLockedFill:Hide()

    -- Diagonal stripe overlay on locked segment (blocked/disabled visual cue)
    State.progressBarLockedFill.hashOverlay = State.progressBar:CreateTexture(nil, "ARTWORK", nil, 2)
    State.progressBarLockedFill.hashOverlay:SetAllPoints(State.progressBarLockedFill)
    State.progressBarLockedFill.hashOverlay:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent")
    State.progressBarLockedFill.hashOverlay:SetAlpha(0.4)
    State.progressBarLockedFill.hashOverlay:Hide()

    -- Ensure locked fill doesn't cover the text — lower its frame level
    State.progressBarLockedFill:SetFrameLevel(State.progressBar:GetFrameLevel() + 1)

    -- Centered count text on its own frame above both fills — must not be
    -- a child of State.progressBarLockedFill or it hides when locked == 0
    local textOverlay = CreateFrame("Frame", nil, State.progressBar)
    textOverlay:SetAllPoints()
    textOverlay:SetFrameLevel(State.progressBarLockedFill:GetFrameLevel() + 1)
    State.progressBarText = textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    State.progressBarText:SetPoint("CENTER", State.progressBar, "CENTER")

    -- Tooltip on hover
    State.progressBar:EnableMouse(true)
    State.progressBar:SetScript("OnEnter", function(self)
        local tooltip = BeginPanelTooltip(self, "ANCHOR_BOTTOM")
        tooltip:AddLine(DISPLAY_LEVEL_TITLES[State.currentDisplayLevel] or "Collection Progress", 1, 1, 1)
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
    State.progressBar:SetScript("OnLeave", HidePanelTooltip)

    -- List area for the vendor list
    State.scrollContainer = CreateFrame("Frame", nil, panel)
    State.scrollContainer:SetPoint("TOPLEFT", State.sourceFilterBar, "BOTTOMLEFT", 0, -4)
    State.scrollContainer:SetPoint("BOTTOMRIGHT", State.searchBar, "TOPRIGHT", 0, -2)

    local List = F:RequireModule("List", 1)
    State.contentList = List:New({
        name             = "HomesteadMapSidePanelList",
        parent           = State.scrollContainer,
        elementType      = "Frame",
        extentCalculator = function(_, rec) return rec.height end,
        initializer      = RenderListElement,
        resetter         = ResetListElement,
    })

    -- Re-anchor through the native handles: List:New's default fill anchors do
    -- not reserve the 22px scrollbar gutter this layout has always kept.
    local handles = State.contentList:GetNativeHandles()
    State.listScrollBox = handles.scrollBox
    State.listScrollBox:ClearAllPoints()
    State.listScrollBox:SetPoint("TOPLEFT", State.scrollContainer, "TOPLEFT", 0, 0)
    State.listScrollBox:SetPoint("BOTTOMRIGHT", State.scrollContainer, "BOTTOMRIGHT", -22, 0)
    handles.scrollBar:ClearAllPoints()
    handles.scrollBar:SetPoint("TOPLEFT", State.listScrollBox, "TOPRIGHT", 4, 0)
    handles.scrollBar:SetPoint("BOTTOMLEFT", State.listScrollBox, "BOTTOMRIGHT", 4, 0)

    -- Empty state text
    State.emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    State.emptyText:SetPoint("CENTER", State.scrollContainer, "CENTER", 0, 0)
    State.emptyText:SetText("No vendors in this zone")
    State.emptyText:Hide()

    -- Pop-out button (docked mode): arrow icon in header area next to title
    State.popOutButton = CreateFrame("Button", nil, State.headerFrame)
    State.popOutButton:SetSize(16, 16)
    State.popOutButton:SetPoint("RIGHT", State.headerFrame, "RIGHT", -2, -2)

    State.popOutButton:SetNormalAtlas("RedButton-Expand")
    State.popOutButton:SetPushedAtlas("RedButton-Expand-Pressed")
    State.popOutButton:SetHighlightAtlas("RedButton-Highlight")

    State.popOutButton:SetScript("OnClick", function()
        MapSidePanel:PopOut()
    end)
    State.popOutButton:SetScript("OnEnter", function(self)
        local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
        tooltip:SetText("Detach panel")
        tooltip:Show()
    end)
    State.popOutButton:SetScript("OnLeave", HidePanelTooltip)

    -- Source filter control: native dropdown below the title header.
    State.sourceFilterDropdown = CreateFrame("DropdownButton", nil, State.sourceFilterBar, "WowStyle1DropdownTemplate")
    State.sourceFilterDropdown:SetPoint("LEFT", State.sourceFilterBar, "LEFT", -4, 0)
    State.sourceFilterDropdown:SetSize(104, 22)
    UpdateSourceFilterDropdownText()

    State.sourceFilterDropdown:SetScript("OnClick", OpenSourceFilterDropdown)
    State.sourceFilterDropdown:SetScript("OnEnter", function(self)
        local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
        tooltip:SetText("Item Source Filter")
        tooltip:AddLine("Current: " .. GetSourceFilterLabel(State.panelSourceFilter), 1, 1, 1)
        tooltip:Show()
    end)
    State.sourceFilterDropdown:SetScript("OnLeave", HidePanelTooltip)

    -- Close button (detached mode): standard X at top-right
    State.closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    State.closeButton:SetPoint("TOPRIGHT", -2, -2)
    State.closeButton:SetScript("OnClick", function()
        -- Full reset: hide panel, clear pop-out state
        MapSidePanel:CloseDetached()
    end)
    State.closeButton:Hide()

    -- Re-attach button (detached mode): small icon next to close button
    State.reattachButton = CreateFrame("Button", nil, panel)
    State.reattachButton:SetSize(16, 16)
    State.reattachButton:SetPoint("RIGHT", State.closeButton, "LEFT", 2, 0)

    State.reattachButton:SetNormalAtlas("RedButton-Condense")
    State.reattachButton:SetPushedAtlas("RedButton-Condense-Pressed")
    State.reattachButton:SetHighlightAtlas("RedButton-Highlight")

    State.reattachButton:SetScript("OnClick", function()
        MapSidePanel:DockPanel()
    end)
    State.reattachButton:SetScript("OnEnter", function(self)
        local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
        tooltip:SetText("Attach to World Map")
        tooltip:Show()
    end)
    State.reattachButton:SetScript("OnLeave", HidePanelTooltip)
    State.reattachButton:Hide()

    -- Resize handle (detached mode): thin grip bar at the bottom edge for
    -- height-only resizing. Hidden when docked.
    State.resizeHandle = CreateFrame("Frame", nil, panel)
    State.resizeHandle:SetHeight(8)
    State.resizeHandle:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, 0)
    State.resizeHandle:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 0)
    State.resizeHandle:EnableMouse(true)
    State.resizeHandle:SetScript("OnMouseDown", function()
        State.panelFrame:StartSizing("BOTTOM")
    end)
    State.resizeHandle:SetScript("OnMouseUp", function()
        State.panelFrame:StopMovingOrSizing()
        State.SaveDetachedPosition()
    end)
    State.resizeHandle:SetScript("OnEnter", function(self)
        -- Visual feedback: WoW doesn't support custom cursors, so highlight the grip
        self.highlight:Show()
    end)
    State.resizeHandle:SetScript("OnLeave", function(self)
        self.highlight:Hide()
    end)

    -- Grip line visual (subtle horizontal lines)
    local grip = State.resizeHandle:CreateTexture(nil, "ARTWORK")
    grip:SetHeight(2)
    grip:SetPoint("LEFT", 8, 0)
    grip:SetPoint("RIGHT", -8, 0)
    grip:SetColorTexture(0.6, 0.6, 0.6, 0.4)
    local grip2 = State.resizeHandle:CreateTexture(nil, "ARTWORK")
    grip2:SetHeight(2)
    grip2:SetPoint("LEFT", 8, -3)
    grip2:SetPoint("RIGHT", -8, -3)
    grip2:SetColorTexture(0.6, 0.6, 0.6, 0.4)

    -- Hover highlight
    local hl = State.resizeHandle:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.1)
    hl:Hide()
    State.resizeHandle.highlight = hl

    State.resizeHandle:Hide()

    -- HS-282 sub-item G: evict the SearchProvider index whenever this panel
    -- hides, on ANY path (Hide/Toggle/CloseDetached, or the map closing/
    -- maximizing out from under a docked panel via MapWatchTick) -- every one
    -- of those paths ends by calling panel:Hide(), so OnHide is the single
    -- point they all converge on. Reclaims ~2.2 MB in the non-searching
    -- steady state; BuildIndex() lazily rebuilds (~20ms worst case) on the
    -- next Search, a trade Rawb accepted against the reclaim.
    panel:HookScript("OnHide", function()
        if HA.SearchProvider and HA.SearchProvider.Invalidate then
            HA.SearchProvider:Invalidate()
        end
    end)

    panel:Hide()
    State.panelFrame = panel
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
    if not State.overlayButton then return end
    local container = WorldMapFrame:GetCanvasContainer()
    if not container then return end
    State.overlayButton:ClearAllPoints()
    local visibleCount = CountVisibleOverlayButtons()
    local yOffset = -(2 + visibleCount * 32)
    State.overlayButton:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, yOffset)
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
    if State.menuContextMenu then
        State.menuContextMenu:CreateContextMenu(owner)
    end
end

local function CreateOverlayButton()
    if State.overlayButton then return end

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
    icon:SetTexture(HA.Constants.TEXTURE_ROOT .. "icon")
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

    -- Position after existing overlay buttons. Re-runs from the WorldMapFrame
    -- state poll in MapSidePanel:Initialize (on map open / zone change / overlay-
    -- count change) -- HS-081 removed the RefreshOverlayFrames hooksecurefunc that
    -- used to do this, because it ran inside Blizzard's secure map path and tainted it.
    PositionOverlayButton()

    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            ShowContextMenu(self)
        elseif State.isPoppedOut and State.panelFrame and State.panelFrame:IsShown() then
            -- Popped out + visible: raise to front instead of toggling
            State.panelFrame:Raise()
        else
            MapSidePanel:Toggle()
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    button:SetScript("OnEnter", function(self)
        local tooltip = BeginPanelTooltip(self, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(tooltip, "Homestead")
        if State.isPoppedOut and State.panelFrame and State.panelFrame:IsShown() then
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

    State.overlayButton = button
end

-------------------------------------------------------------------------------
-- Content Refresh
-------------------------------------------------------------------------------

local function GetVendorsForCurrentMap(mapID)
    if not VendorData then return {} end

    local vendors = {}
    local seen = {}
    local isNeighborhoodMap = (mapID == 2351 or mapID == 2352)

    -- Get vendors for this map + more-specific sub-zone child maps.
    local mapsToCheck = { [mapID] = true }
    local childMapIDs = MPP:GetMoreSpecificChildMapIDs(mapID)
    for _, childMapID in ipairs(childMapIDs) do
        mapsToCheck[childMapID] = true
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
-- When State.backBar is visible, content sits below it; otherwise below the source
-- filter row that follows the title header.
local function GetContentTopAnchor()
    if State.backBar and State.backBar:IsShown() then return State.backBar end
    return State.sourceFilterBar or State.headerFrame
end

local function UpdateBackBar()
    if not State.backBar then return end
    if not State.lastRefreshMapID then
        State.backBar:Hide()
        return
    end
    local mapInfo = C_Map.GetMapInfo(State.lastRefreshMapID)
    if not mapInfo or not mapInfo.parentMapID or mapInfo.parentMapID <= 0 then
        State.backBar:Hide()
        return
    end
    -- World level: no back bar (already at top)
    if State.currentDisplayLevel == "world" then
        State.backBar:Hide()
        return
    end
    local parentInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
    local parentName = parentInfo and parentInfo.name or "Back"
    State.backBar.text:SetText("< " .. parentName)
    State.backBar:Show()
end

function MapSidePanel:NavigateBack()
    if not State.lastRefreshMapID then return end
    local mapInfo = C_Map.GetMapInfo(State.lastRefreshMapID)
    if not mapInfo or not mapInfo.parentMapID or mapInfo.parentMapID <= 0 then return end
    if WorldMapFrame:IsShown() then
        WorldMapFrame:SetMapID(mapInfo.parentMapID)
    else
        -- Detached mode: map not open, navigate via internal state
        State.lastRefreshMapID = mapInfo.parentMapID
        self:RefreshContent()
    end
end

local function HideProgressBar()
    if not State.progressBar then return end
    State.progressBar:Hide()
    if State.progressBarLockedFill then
        State.progressBarLockedFill:Hide()
        State.progressBarLockedFill:SetWidth(0)
        if State.progressBarLockedFill.hashOverlay then
            State.progressBarLockedFill.hashOverlay:Hide()
        end
    end
    State.progressBar.lockedValue = nil
    State.progressBar.purchasableValue = nil
    State.progressBar.pendingLockedRatio = nil
    State.progressBar.needsLockedFillLayout = false
    -- Re-anchor scroll area below back bar or header (skip hidden progress bar)
    local anchor = GetContentTopAnchor()
    if State.scrollContainer then
        State.scrollContainer:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    end
end

local function UpdateProgressBar(collected, total, locked)
    if not State.progressBar then return end
    locked = locked or 0
    if total > 0 then
        -- Anchor progress bar below back bar or header
        local anchor = GetContentTopAnchor()
        State.progressBar:ClearAllPoints()
        State.progressBar:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -3)
        State.progressBar:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -3)

        State.progressBar:SetMinMaxValues(0, total)

        -- Green fill for collected items
        State.progressBar:SetStatusBarColor(0.0, 0.7, 0.0)
        local pct = collected / total
        local pctDisplay = math.floor(pct * 100)
        State.progressBarText:SetText(string.format("%d/%d (%d%%)", collected, total, pctDisplay))

        -- Store locked metadata for tooltip and OnUpdate layout
        State.progressBar.lockedValue = locked
        State.progressBar.purchasableValue = math.max(0, total - collected - locked)
        State.progressBar.pendingLockedRatio = locked / total
        State.progressBar.needsLockedFillLayout = true

        State.progressBar:Show()

        -- Smooth fill: animate bar value toward target over ~0.4s.
        -- Also sizes the locked fill texture once layout width is available.
        State.progressBar.targetValue = collected
        if not State.progressBar.filling then
            State.progressBar.filling = true
            State.progressBar:SetScript("OnUpdate", function(self, elapsed)
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
                if self.needsLockedFillLayout and State.progressBarLockedFill then
                    local barWidth = self:GetWidth()
                    if barWidth and barWidth > 0 then
                        local lockedRatio = self.pendingLockedRatio or 0
                        local lockedWidth = math.floor(barWidth * lockedRatio + 0.5)
                        if lockedWidth > 0 then
                            State.progressBarLockedFill:SetWidth(lockedWidth)
                            State.progressBarLockedFill:Show()
                            if State.progressBarLockedFill.hashOverlay then
                                State.progressBarLockedFill.hashOverlay:Show()
                            end
                        else
                            State.progressBarLockedFill:SetWidth(0)
                            State.progressBarLockedFill:Hide()
                            if State.progressBarLockedFill.hashOverlay then
                                State.progressBarLockedFill.hashOverlay:Hide()
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
        if State.scrollContainer then
            State.scrollContainer:SetPoint("TOPLEFT", State.progressBar, "BOTTOMLEFT", 0, -2)
        end
    else
        HideProgressBar()
    end
end

-------------------------------------------------------------------------------
-- Continent/World Summary Refresh
-------------------------------------------------------------------------------

function MapSidePanel:RefreshZoneSummaries(mapID, mapInfo)
    State.currentDisplayLevel = "continent"

    -- Vendor expansion is not part of this display. The rows themselves are
    -- cleared when this function publishes its own records below.
    State.expandedVendorID = nil
    -- HS-230: instance drop-source expansion too, same convention as above.
    State.expandedBossKey = nil

    State.headerText:SetText(mapInfo.name or "")

    -- HS-018: honor the panel's source filter at continent view so per-zone
    -- summary rows reflect the active filter (was previously unfiltered).
    local zoneCounts = BC:GetZoneVendorCounts(mapID, State.panelSourceFilter)

    -- Build sorted zone list
    local zoneList = {}
    for zoneMapID, data in pairs(zoneCounts) do
        zoneList[#zoneList + 1] = { mapID = zoneMapID, data = data }
    end
    table.sort(zoneList, function(a, b)
        return (a.data.zoneName or "") < (b.data.zoneName or "")
    end)

    if #zoneList == 0 then
        State.emptyText:SetText("No vendors on this continent")
        State.emptyText:Show()
        State.summaryText:SetText("")
        SetListRows({})
        UpdateBackBar()
        HideProgressBar()
        return
    end

    local totalCollected, totalItems, totalLocked = 0, 0, 0
    local zoneCount = 0
    local rows = {}

    for _, entry in ipairs(zoneList) do
        local data = entry.data
        local dataVendorCount = data.vendorCount or 0
        local dataCollected = data.collectedItems or 0
        local dataTotal = data.totalItems or 0
        local dataLocked = data.lockedItems or 0

        local isExpanded = (State.expandedSummaryMapID == entry.mapID)

        -- Summary line: "N vendors | owned/total[/locked]" with inline colors
        local summaryLineText, summaryLineColor
        if dataTotal > 0 then
            summaryLineText = string.format("%d vendors | %s",
                dataVendorCount, FormatPurchasabilityCountText(dataCollected, dataTotal, dataLocked))
            summaryLineColor = Layout.COLOR_WHITE
        elseif dataVendorCount > 0 then
            summaryLineText = string.format("%d vendors (no item data)", dataVendorCount)
            summaryLineColor = Layout.COLOR_DIM
        else
            summaryLineText = ""
        end

        rows[#rows + 1] = {
            kind = "summary",
            height = Layout.ROW_HEIGHT,
            targetMapID = entry.mapID,
            vendorCount = dataVendorCount,
            collectedItems = dataCollected,
            totalItems = dataTotal,
            lockedItems = dataLocked,
            unverifiedItems = data.unverifiedItems or 0,
            name = data.zoneName or "Unknown",
            nameColor = Layout.COLOR_WHITE,
            summaryLineText = summaryLineText,
            summaryLineColor = summaryLineColor,
            isExpanded = isExpanded,
        }

        -- If expanded, append vendor sub-rows below this zone row
        if isExpanded then
            BuildZoneExpansionRows(entry.mapID, rows)
        end

        totalCollected = totalCollected + dataCollected
        totalItems = totalItems + dataTotal
        totalLocked = totalLocked + dataLocked
        zoneCount = zoneCount + 1
    end

    SetListRows(rows)
    State.emptyText:Hide()

    -- Summary line
    if totalItems > 0 then
        State.summaryText:SetText(string.format("%d zones | %s items",
            zoneCount, FormatPurchasabilityCountText(totalCollected, totalItems, totalLocked)))
    else
        State.summaryText:SetText(string.format("%d zones", zoneCount))
    end

    UpdateBackBar()
    UpdateProgressBar(totalCollected, totalItems, totalLocked)
end

function MapSidePanel:RefreshContinentSummaries(mapID, mapInfo)
    State.currentDisplayLevel = "world"

    -- Vendor expansion is not part of this display. The rows themselves are
    -- cleared when this function publishes its own records below.
    State.expandedVendorID = nil
    -- HS-230: instance drop-source expansion too, same convention as above.
    State.expandedBossKey = nil

    State.headerText:SetText(mapInfo.name or "")

    local continentCounts = BC:GetContinentVendorCounts(State.panelSourceFilter)

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
        State.emptyText:SetText("No vendor data available")
        State.emptyText:Show()
        State.summaryText:SetText("")
        SetListRows({})
        UpdateBackBar()
        HideProgressBar()
        return
    end

    local totalCollected, totalItems, totalLocked = 0, 0, 0
    local contCount = 0
    local rows = {}

    for _, entry in ipairs(continentList) do
        local data = entry.data
        local dataVendorCount = data.vendorCount or 0
        local dataCollected = data.collectedItems or 0
        local dataTotal = data.totalItems or 0
        local dataLocked = data.lockedItems or 0

        local isExpanded = (State.expandedSummaryMapID == entry.mapID)

        -- Summary line: "N vendors | owned/total[/locked]" with inline colors
        local summaryLineText, summaryLineColor
        if dataTotal > 0 then
            summaryLineText = string.format("%d vendors | %s",
                dataVendorCount, FormatPurchasabilityCountText(dataCollected, dataTotal, dataLocked))
            summaryLineColor = Layout.COLOR_WHITE
        elseif dataVendorCount > 0 then
            summaryLineText = string.format("%d vendors (no item data)", dataVendorCount)
            summaryLineColor = Layout.COLOR_DIM
        else
            summaryLineText = ""
        end

        rows[#rows + 1] = {
            kind = "summary",
            height = Layout.ROW_HEIGHT,
            targetMapID = entry.mapID,
            vendorCount = dataVendorCount,
            collectedItems = dataCollected,
            totalItems = dataTotal,
            lockedItems = dataLocked,
            unverifiedItems = data.unverifiedItems or 0,
            -- Gold color for continent names
            name = data.continentName or "Unknown",
            nameColor = Layout.COLOR_GOLD,
            summaryLineText = summaryLineText,
            summaryLineColor = summaryLineColor,
            isExpanded = isExpanded,
        }

        -- If expanded, append zone sub-rows below this continent row
        if isExpanded then
            BuildContinentExpansionRows(entry.mapID, rows)
        end

        totalCollected = totalCollected + dataCollected
        totalItems = totalItems + dataTotal
        totalLocked = totalLocked + dataLocked
        contCount = contCount + 1
    end

    SetListRows(rows)
    State.emptyText:Hide()

    -- Summary line
    if totalItems > 0 then
        State.summaryText:SetText(string.format("%d continents | %s items",
            contCount, FormatPurchasabilityCountText(totalCollected, totalItems, totalLocked)))
    else
        State.summaryText:SetText(string.format("%d continents", contCount))
    end

    UpdateBackBar()
    UpdateProgressBar(totalCollected, totalItems, totalLocked)
end

-------------------------------------------------------------------------------
-- Search Results Refresh
-------------------------------------------------------------------------------

-- HS-019: header labels keyed by source-section identifier. The vendor
-- section always shows when any vendor result is present; item sections only
-- show when at least one item-first row in that source type is present.
local SEARCH_SECTION_LABELS = {
    vendor      = L["Vendors"] or "Vendors",
    profession  = L["Profession"] or "Profession",
    quest       = L["Quest"] or "Quest",
    achievement = L["Achievement"] or "Achievement",
    event       = L["Event"] or "Event",
    drop        = L["Drop"] or "Drop",
}

function MapSidePanel:RefreshSearchResults()
    -- Self-healing: re-query if index was invalidated since last results
    local SP = HA.SearchProvider
    if SP and State.searchResultsRevision ~= SP:GetRevision() then
        State.searchResults = SP:Search(State.searchText, SEARCH_OPTIONS)
        State.searchResultsRevision = SP:GetRevision()
    end

    HideAllNonVendorContent()
    State.expandedSummaryMapID = nil
    HideProgressBar()

    -- Search mode deliberately leaves State.expandedVendorID and State.expandedBossKey set:
    -- closing search returns to whatever was expanded before it.

    if not State.searchResults or #State.searchResults == 0 then
        State.emptyText:SetText("No results found")
        State.emptyText:Show()
        State.summaryText:SetText("")
        State.headerText:SetText("Search Results")
        SetListRows({})
        return
    end

    State.emptyText:Hide()
    State.headerText:SetText("Search Results")

    local rows = {}
    local vendorCount = 0
    local itemCount = 0
    local lastSection = nil

    local function EmitHeader(sectionKey)
        if sectionKey == lastSection then return end
        lastSection = sectionKey
        rows[#rows + 1] = {
            kind = "header",
            height = Layout.SEARCH_HEADER_HEIGHT,
            label = SEARCH_SECTION_LABELS[sectionKey] or sectionKey,
        }
    end

    for _, result in ipairs(State.searchResults) do
        if result.resultType == "item" then
            EmitHeader(result.sourceType or "drop")
            itemCount = itemCount + 1

            local itemID = result.itemID
            local isExpanded = (State.expandedItemID == itemID)
            local sourceCount
            if isExpanded then
                sourceCount = #GetDisplaySourcesForItem(itemID, State.panelSourceFilter)
            end

            rows[#rows + 1] = {
                kind = "item",
                height = Layout.ROW_HEIGHT + (isExpanded and ComputeItemSourceListHeight(sourceCount) or 0),
                result = result,
                itemID = itemID,
                isExpanded = isExpanded,
                sourceCount = sourceCount,
            }
        else
            EmitHeader("vendor")
            vendorCount = vendorCount + 1
            local vendor = result.vendor

            -- Collection stats (uses State.panelSourceFilter for display only)
            local stats = BC:GetVendorStats(vendor, State.panelSourceFilter)
            local collected = stats.collected or 0
            local total = stats.total or 0
            local locked = stats.locked or 0

            -- HS-338: a plans-only vendor (total == 0, excluded > 0) has real
            -- stock the addon can't track ownership for — name it instead of
            -- falling through to the dim "No item data" guard below.
            local excludedText = total == 0 and FormatOwnershipExcludedInventoryText(stats) or nil

            local countText, countColor, infoText
            if total > 0 then
                countColor = Layout.COLOR_WHITE
                infoText = FormatPurchasabilityCountText(collected, total, locked)
            elseif excludedText then
                countColor = Layout.COLOR_WHITE
                infoText = excludedText
            else
                countColor = Layout.COLOR_DIM
                infoText = (State.panelSourceFilter ~= "all") and "No matching items" or "No item data"
            end

            if result.matchType == "item" then
                countText = string.format("%d match%s | %s",
                    result.matchCount, result.matchCount == 1 and "" or "es",
                    infoText)
            else
                countText = infoText
            end

            local isExpanded = (State.expandedVendorID == vendor.npcID)
            local itemIDs
            if isExpanded then
                itemIDs = GetVendorItemIDs(vendor, State.panelSourceFilter)
            end

            rows[#rows + 1] = {
                kind = "vendor",
                height = Layout.ROW_HEIGHT + (isExpanded and ComputeItemGridHeight(#itemIDs) or 0),
                vendor = vendor,
                searchMode = true,
                matchedItems = result.matchedItems,
                collected = collected,
                total = total,
                locked = locked,
                countText = countText,
                countColor = countColor,
                nameColor = Layout.COLOR_WHITE,
                isExpanded = isExpanded,
                itemIDs = itemIDs,
            }
        end
    end

    SetListRows(rows)
    if vendorCount > 0 and itemCount > 0 then
        State.summaryText:SetText(string.format("%d vendor%s, %d item%s found",
            vendorCount, vendorCount == 1 and "" or "s",
            itemCount, itemCount == 1 and "" or "s"))
    elseif vendorCount > 0 then
        State.summaryText:SetText(string.format("%d vendor%s found",
            vendorCount, vendorCount == 1 and "" or "s"))
    else
        State.summaryText:SetText(string.format("%d item%s found",
            itemCount, itemCount == 1 and "" or "s"))
    end
end

-------------------------------------------------------------------------------
-- HS-230: Instance Drop-Source Listing
--
-- Sibling of the zone-level vendor listing inside RefreshContent — same
-- row-population/expand/collapse/empty-state/summary-line shape, built off
-- GetInstanceDropGroups instead of GetVendorsForCurrentMap. Called once per
-- RefreshContent pass when the viewed map is an instance with EJ encounters;
-- never lists vendors.
-------------------------------------------------------------------------------

function MapSidePanel:RefreshInstanceDropSources(mapID, mapInfo, encounters)
    State.currentDisplayLevel = "zone"

    -- Vendor expansion is not part of this display, mirroring how the zone-level
    -- path above resets boss expansion when it is the active display.
    State.expandedVendorID = nil

    -- Deliberate filter contract: drop groups are entirely drop-sourced by
    -- construction, so this is an all-or-nothing gate, not a per-item
    -- filter like the zone path's BC:GetVendorStats(vendor, sourceFilter)
    -- — a vendor-filtered (etc.) user mapping into an instance sees an
    -- empty state (with a filter-aware message below), never a partial
    -- "0 matching items" boss list.
    local normalizedFilter = NormalizePanelSourceFilter(State.panelSourceFilter)
    local groups = (normalizedFilter == "all" or normalizedFilter == "drop")
        and GetInstanceDropGroups(encounters) or {}

    local totalCollected, totalItems, totalLocked = 0, 0, 0
    local rows = {}

    for _, group in ipairs(groups) do
        local stats = BC:GetDropGroupStats(group.records)
        local collected = stats.collected or 0
        local total = stats.total or 0
        local locked = stats.locked or 0

        local countText, countColor
        if total > 0 then
            countText = FormatPurchasabilityCountText(collected, total, locked)
            countColor = Layout.COLOR_WHITE
        else
            countText = "No item data"
            countColor = Layout.COLOR_DIM
        end

        local isExpanded = (State.expandedBossKey == group.encounterID)

        local rec = {
            kind = "boss",
            height = Layout.ROW_HEIGHT + (isExpanded and ComputeItemGridHeight(#group.records) or 0),
            dropGroup = group,
            name = (group.records[1].drop and group.records[1].drop.mobName) or "Unknown",
            collected = collected,
            total = total,
            locked = locked,
            countText = countText,
            countColor = countColor,
            isExpanded = isExpanded,
        }
        rows[#rows + 1] = rec

        totalCollected = totalCollected + rec.collected
        totalItems = totalItems + rec.total
        totalLocked = totalLocked + rec.locked
    end

    SetListRows(rows)

    if #groups == 0 then
        -- Honest empty state: a filtered-out view names the filter as the
        -- reason, never "no drops tracked" when drops exist but are hidden.
        if normalizedFilter ~= "all" and normalizedFilter ~= "drop" then
            State.emptyText:SetText("Drops hidden by source filter")
        else
            State.emptyText:SetText("No drops tracked for this instance")
        end
        State.emptyText:Show()
    else
        State.emptyText:Hide()
    end

    if totalItems > 0 then
        State.summaryText:SetText(string.format("%d boss%s | %s items",
            #groups, #groups == 1 and "" or "es",
            FormatPurchasabilityCountText(totalCollected, totalItems, totalLocked)))
    elseif #groups > 0 then
        State.summaryText:SetText(string.format("%d boss%s", #groups, #groups == 1 and "" or "es"))
    else
        State.summaryText:SetText("")
    end

    UpdateBackBar()
    UpdateProgressBar(totalCollected, totalItems, totalLocked)
end

-------------------------------------------------------------------------------
-- Content Refresh
-------------------------------------------------------------------------------

function MapSidePanel:RefreshContent()
    if not State.panelFrame or not State.panelFrame:IsShown() then HideAllNonVendorContent() State.expandedSummaryMapID = nil HideProgressBar() State.currentDisplayLevel = "zone" return end
    if not VendorData or not BC then HideAllNonVendorContent() State.expandedSummaryMapID = nil HideProgressBar() State.currentDisplayLevel = "zone" return end

    -- Search mode overrides normal display
    if State.searchText ~= "" and State.searchResults then
        self:RefreshSearchResults()
        return
    end

    State.expandedItemID = nil

    -- MapID resolution: map frame → last viewed → player zone
    -- When detached, panel keeps its own navigation state
    local mapID
    if not State.isPoppedOut and WorldMapFrame:IsShown() then
        mapID = WorldMapFrame:GetMapID()
    end
    if not mapID then
        mapID = State.lastRefreshMapID
    end
    if not mapID then
        mapID = C_Map.GetBestMapForUnit("player")
    end
    if not mapID then
        -- No map data available (loading screen, instance)
        HideAllNonVendorContent()
        State.expandedSummaryMapID = nil
        State.currentDisplayLevel = "zone"
        State.emptyText:SetText("Open the World Map to view vendors")
        State.emptyText:Show()
        State.summaryText:SetText("")
        SetListRows({})
        HideProgressBar()
        return
    end

    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo then HideAllNonVendorContent() SetListRows({}) State.expandedSummaryMapID = nil HideProgressBar() State.currentDisplayLevel = "zone" return end

    -- Update header with zone name
    State.headerText:SetText(mapInfo.name or "")

    -- Determine map type — three-tier dispatch (HS-230 adds a fourth: instance)
    local mapType = mapInfo.mapType
    local isContinentLevel = mapType and mapType == Enum.UIMapType.Continent
    local isWorldLevel = mapType and (mapType == Enum.UIMapType.World or mapType == Enum.UIMapType.Cosmic)

    -- HS-230: instance maps (dungeon/raid interiors) with EJ encounters get
    -- their own drop-source listing instead of the (always-empty, since no
    -- Homestead vendor lives inside an instance) vendor list. Structurally
    -- gated on mapType == Dungeon — Zone/Continent/World/Cosmic/Micro/Orphan
    -- are all distinct Enum.UIMapType values, so this can never fire for
    -- them regardless of what GetEncountersOnMap returns. Enum member
    -- verified via wow-api MCP (no separate "Raid" mapType — both use
    -- Dungeon). The GetEncountersOnMap call itself is cheap (a single C
    -- function call returning a small array, not a live requirement/
    -- ownership evaluation) and VendorMapPins makes its own independent
    -- call from CollectDropPinRecords on a different refresh cadence (pin
    -- refresh triggers differ from panel refresh triggers) — a shared
    -- memo would add cross-module coupling for a call this cheap, so this
    -- is deliberately its own call, not shared.
    local isInstanceLevel = mapType == Enum.UIMapType.Dungeon
    local instanceEncounters = nil
    if isInstanceLevel then
        local ok, encounters = pcall(C_EncounterJournal.GetEncountersOnMap, mapID)
        if ok and encounters and #encounters > 0 then
            instanceEncounters = encounters
        else
            isInstanceLevel = false
        end
    end

    -- Set State.lastRefreshMapID early so UpdateBackBar() can read it
    State.lastRefreshMapID = mapID

    if isWorldLevel then
        self:RefreshContinentSummaries(mapID, mapInfo)
        return
    elseif isContinentLevel then
        self:RefreshZoneSummaries(mapID, mapInfo)
        return
    elseif isInstanceLevel then
        HideAllNonVendorContent()
        State.expandedSummaryMapID = nil
        self:RefreshInstanceDropSources(mapID, mapInfo, instanceEncounters)
        return
    end

    -- Zone level: hide all non-vendor content, reset summary expansion
    HideAllNonVendorContent()
    State.expandedSummaryMapID = nil
    State.currentDisplayLevel = "zone"

    -- HS-230: instance drop-source expansion is not part of the zone-level display,
    -- mirroring how the summary paths reset vendor expansion when they are active.
    State.expandedBossKey = nil

    -- Zone level — show individual vendors
    local vendorList = GetVendorsForCurrentMap(mapID)
    local sourceFilter = State.panelSourceFilter

    local totalCollected, totalItems, totalLocked = 0, 0, 0
    local rows = {}

    for _, entry in ipairs(vendorList) do
        local vendor = entry.vendor

        -- Set name with color coding
        local nameColor = entry.isOpposite and Layout.COLOR_DIM or Layout.COLOR_WHITE

        -- Get collection stats (includes purchasable/locked breakdown)
        local stats = BC:GetVendorStats(vendor, sourceFilter)
        local collected = stats.collected or 0
        local total = stats.total or 0
        local locked = stats.locked or 0

        -- HS-338: a plans-only vendor (total == 0, excluded > 0) has real
        -- stock the addon can't track ownership for — name it instead of
        -- falling through to the dim "No item data" guard below.
        local excludedText = total == 0 and FormatOwnershipExcludedInventoryText(stats) or nil

        local countText, countColor
        if total > 0 then
            countText = FormatPurchasabilityCountText(collected, total, locked)
            -- White base color — inline escapes handle segment coloring
            countColor = Layout.COLOR_WHITE
        elseif excludedText then
            countText = excludedText
            countColor = Layout.COLOR_WHITE
        else
            if sourceFilter ~= "all" then
                countText = "No matching items"
            else
                countText = "No item data"
            end
            countColor = Layout.COLOR_DIM
        end

        -- Check if this vendor is expanded (item grid visible)
        local isExpanded = (State.expandedVendorID == vendor.npcID)
        local itemIDs
        if isExpanded then
            itemIDs = GetVendorItemIDs(vendor, sourceFilter)
        end

        local rec = {
            kind = "vendor",
            height = Layout.ROW_HEIGHT + (isExpanded and ComputeItemGridHeight(#itemIDs) or 0),
            vendor = vendor,
            searchMode = false,
            nameColor = nameColor,
            collected = collected,
            total = total,
            locked = locked,
            countText = countText,
            countColor = countColor,
            isExpanded = isExpanded,
            itemIDs = itemIDs,
        }
        rows[#rows + 1] = rec

        totalCollected = totalCollected + rec.collected
        totalItems = totalItems + rec.total
        totalLocked = totalLocked + rec.locked
    end

    SetListRows(rows)

    -- Empty state
    if #vendorList == 0 then
        State.emptyText:SetText("No vendors in this zone")
        State.emptyText:Show()
    else
        State.emptyText:Hide()
    end

    -- Summary line
    if totalItems > 0 then
        State.summaryText:SetText(string.format("%d vendors | %s items",
            #vendorList, FormatPurchasabilityCountText(totalCollected, totalItems, totalLocked)))
    elseif #vendorList > 0 then
        State.summaryText:SetText(string.format("%d vendors", #vendorList))
    else
        State.summaryText:SetText("")
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

State.useStandaloneMode = nil  -- nil = not yet checked, true/false after check

local function ShouldUseStandaloneMode()
    -- Cache after first check
    if State.useStandaloneMode ~= nil then return State.useStandaloneMode end

    -- User setting overrides detection
    if HA.Addon and HA.Addon.db then
        if HA.Addon.db.profile.vendorTracer.integrateMapBorder == false then
            State.useStandaloneMode = true
            return true
        end
    end

    -- Detect custom UIs that replace WorldMapFrame
    if _G.ElvUI or _G.GW2_UI or _G.Tukui then
        State.useStandaloneMode = true
        return true
    end

    -- Verify expected Blizzard frame structure exists
    local bf = WorldMapFrame.BorderFrame
    if not bf or not bf.NineSlice or not bf.NineSlice.TopEdge then
        State.useStandaloneMode = true
        return true
    end

    State.useStandaloneMode = false
    return false
end

-- Call when the setting changes to re-evaluate
local function ResetStandaloneCheck()
    State.useStandaloneMode = nil
end

-------------------------------------------------------------------------------
-- Map Position Shifting
-- Nudges the WorldMapFrame right when the panel is open, restores when closed.
-- Map CAN be opened during combat (M+ dungeons). ShowPanel() should not
-- mutate WorldMapFrame while InCombatLockdown() is true.
-------------------------------------------------------------------------------

-- Saved anchor data for the map's NineSlice top edge (left anchor only)
State.savedMapTopEdge = nil  -- {point, relativeTo, relativePoint, xOfs, yOfs}

State.ShiftMapRight = function()
    if State.mapShifted then return end
    local point, relativeTo, relativePoint, xOfs, yOfs = WorldMapFrame:GetPoint(1)
    if point then
        State.savedMapPoint = { point, relativeTo, relativePoint, xOfs or 0, yOfs or 0 }
        WorldMapFrame:SetPoint(point, relativeTo, relativePoint,
            (xOfs or 0) + Layout.PANEL_WIDTH, yOfs or 0)
        State.mapShifted = true
    end
end

local function RestoreMapPosition()
    if not State.mapShifted or not State.savedMapPoint then return end
    WorldMapFrame:SetPoint(State.savedMapPoint[1], State.savedMapPoint[2], State.savedMapPoint[3],
        State.savedMapPoint[4], State.savedMapPoint[5])
    State.mapShifted = false
end

-------------------------------------------------------------------------------
-- Map Element Repositioning (integrated mode)
--
-- The old approach (ShiftElementLeft by Layout.PANEL_WIDTH) failed because elements
-- moved outside their parent's clipping rect. New approach:
--
-- Portrait + Info button: temporarily reparented to State.panelFrame so they
-- render within the panel's bounds at its top-left corner.
--
-- Nav bar: left anchor extended to the panel via cross-parent anchoring,
-- with parent clipping disabled so the breadcrumbs remain visible.
--
-- All changes are fully reversed on close.
-------------------------------------------------------------------------------

-- Saved state per element: { parent, level, strata, anchors = {{p,r,rp,x,y}, ...} }
State.savedPortraitState = nil
State.savedPortraitTexture = nil  -- original portrait texture/ID, restored on close
State.savedTutorialState = nil
State.savedNavBarState = nil
State.savedClipStates = {}  -- { [frame] = originalClipBool }

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
    if State.savedClipStates[frame] == nil then
        State.savedClipStates[frame] = frame:DoesClipChildren()
    end
    frame:SetClipsChildren(false)
end

local function RestoreClipping()
    for frame, wasClipping in pairs(State.savedClipStates) do
        if frame and frame.SetClipsChildren then
            frame:SetClipsChildren(wasClipping)
        end
    end
    wipe(State.savedClipStates)
end

local function ReparentMapElements()
    if State.savedPortraitState then return end  -- already done
    if not State.panelFrame then return end

    local wm = WorldMapFrame
    local bf = wm.BorderFrame

    -- 1. Portrait container → reparent to panel, position at top-left corner.
    --    The container has a CircleMask that clips all textures to a circle,
    --    which hides the built-in ring border. So we create a separate ring
    --    frame on top that isn't subject to the mask.
    local pc = wm.PortraitContainer or (bf and bf.PortraitContainer)
    if pc then
        State.savedPortraitState = SaveFrameState(pc)
        pc:SetParent(State.panelFrame)
        -- Must be above NineSlice (502) AND background.
        pc:SetFrameLevel(State.panelFrame:GetFrameLevel() + 10)  -- 510
        pc:ClearAllPoints()
        pc:SetPoint("CENTER", State.panelFrame, "TOPLEFT", 3, -1)
        pc:Show()

        -- Swap portrait texture to Homestead icon
        if pc.portrait then
            if not State.savedPortraitTexture then
                State.savedPortraitTexture = pc.portrait:GetTexture()
            end
            pc.portrait:SetTexture(HA.Constants.TEXTURE_ROOT .. "HomesteadPortrait_64")
        end

    end

    -- 2. Info / tutorial button → reparent to panel, tuck against portrait
    --    Position it to the RIGHT of the portrait, vertically centered,
    --    so it sits between the portrait circle and the "World" breadcrumb.
    local tutorial = bf and bf.Tutorial
    if tutorial and pc then
        State.savedTutorialState = SaveFrameState(tutorial)
        tutorial:SetParent(State.panelFrame)
        tutorial:SetFrameLevel(State.panelFrame:GetFrameLevel() + 11)
        tutorial:ClearAllPoints()
        -- Absolute position on panel, to the right of the ~40px portrait circle
        tutorial:SetPoint("TOPLEFT", State.panelFrame, "TOPLEFT", 52, 23)
        tutorial:Show()
    end

    -- 3. Nav bar → reparent to State.panelFrame so it shares the same rendering
    --    subtree. Without this, the nav bar (in WorldMapFrame's tree) renders
    --    behind the panel (on UIParent) regardless of frame level or strata.
    --    Walk the parent chain first to disable clipping, then reparent.
    local navBar = wm.NavBar
    if navBar and not State.savedNavBarState then
        State.savedNavBarState = SaveFrameState(navBar)

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
        for _, a in ipairs(State.savedNavBarState.anchors) do
            if a[1] == "TOPLEFT" then
                origY = a[5] or 0
                break
            end
        end

        -- Reparent to panel, then set anchors and level
        navBar:SetParent(State.panelFrame)
        navBar:SetFrameStrata("HIGH")
        navBar:SetFrameLevel(State.panelFrame:GetFrameLevel() + 15)  -- 515

        -- Proxy SetMapID/GetMapID: Blizzard's NavBar GoToMap calls
        -- self:GetParent():SetMapID(mapID), which now hits State.panelFrame.
        if not State.panelFrame.SetMapID then
            State.panelFrame.SetMapID = function(_, mapID)
                WorldMapFrame:SetMapID(mapID)
            end
            State.panelFrame.GetMapID = function()
                return WorldMapFrame:GetMapID()
            end
        end

        -- Replace the left anchor: start at the panel's left edge, past
        -- the portrait (~64px). Keep the original Y offset and right anchor.
        navBar:SetPoint("TOPLEFT", State.panelFrame, "TOPLEFT", 64, origY)
    end
end

local function RestoreMapElements()
    local wm = WorldMapFrame
    local bf = wm.BorderFrame

    -- Portrait
    local pc = wm.PortraitContainer or (bf and bf.PortraitContainer)
    if pc and State.savedPortraitState then
        -- Restore original portrait texture before reparenting back
        if pc.portrait and State.savedPortraitTexture then
            pc.portrait:SetTexture(State.savedPortraitTexture)
        end
        RestoreFrameState(pc, State.savedPortraitState)
        State.savedPortraitState = nil
    end
    -- Tutorial
    local tutorial = bf and bf.Tutorial
    if tutorial and State.savedTutorialState then
        RestoreFrameState(tutorial, State.savedTutorialState)
        State.savedTutorialState = nil
    end

    -- Nav bar (full restore — parent, strata, level, all anchors)
    local navBar = wm.NavBar
    if navBar and State.savedNavBarState then
        RestoreFrameState(navBar, State.savedNavBarState)
        State.savedNavBarState = nil
    end

    -- Clipping
    RestoreClipping()
end

-------------------------------------------------------------------------------
-- Content Inset (integrated mode)
-- Push the panel's content area below the nav bar / portrait header zone.
-- Only the interior elements move; the panel frame stays at the top.
-------------------------------------------------------------------------------

State.contentInsetApplied = false
Layout.DEFAULT_TOP_TILE_OFFSET = 18   -- Default tile Y (standalone mode)
Layout.DEFAULT_HEADER_TOP = 22        -- Default BORDER_TOP for header

-- Measure the lowest bottom edge of the header zone elements (portrait,
-- nav bar) relative to the panel's top, then re-anchor tiles + header below.
-- Must run after a layout pass (deferred) for accurate GetBottom/GetTop.
local function ApplyContentInset()
    if State.contentInsetApplied then return end
    if not State.panelFrame or not State.headerFrame then return end

    local panelTop = State.panelFrame:GetTop()
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
    if State.topTileFrame then
        State.topTileFrame:ClearAllPoints()
        State.topTileFrame:SetPoint("TOPLEFT", State.panelFrame, "TOPLEFT", 6, insetY)
        State.topTileFrame:SetPoint("TOPRIGHT", State.panelFrame, "TOPRIGHT", -6, insetY)
    end

    -- Move header below the tiles
    local headerY = insetY - 10  -- 10 = tile height
    State.headerFrame:ClearAllPoints()
    State.headerFrame:SetPoint("TOPLEFT", State.panelFrame, "TOPLEFT", 10, headerY)
    State.headerFrame:SetPoint("TOPRIGHT", State.panelFrame, "TOPRIGHT", -10, headerY)

    State.contentInsetApplied = true
end

local function RestoreContentInset()
    if not State.contentInsetApplied then return end

    if State.topTileFrame then
        State.topTileFrame:ClearAllPoints()
        State.topTileFrame:SetPoint("TOPLEFT", State.panelFrame, "TOPLEFT", 6, -Layout.DEFAULT_TOP_TILE_OFFSET)
        State.topTileFrame:SetPoint("TOPRIGHT", State.panelFrame, "TOPRIGHT", -6, -Layout.DEFAULT_TOP_TILE_OFFSET)
    end

    if State.headerFrame then
        State.headerFrame:ClearAllPoints()
        State.headerFrame:SetPoint("TOPLEFT", State.panelFrame, "TOPLEFT", 10, -Layout.DEFAULT_HEADER_TOP)
        State.headerFrame:SetPoint("TOPRIGHT", State.panelFrame, "TOPRIGHT", -10, -Layout.DEFAULT_HEADER_TOP)
    end

    State.contentInsetApplied = false
end

-------------------------------------------------------------------------------
-- Portrait: swapped to HomesteadPortrait_64 when panel opens, restored on close.
-- The portrait container is reparented to State.panelFrame (see ReparentMapElements)
-- so the entire unit (icon + mask + ring) moves together.

-------------------------------------------------------------------------------
-- Unified Top Border (integrated mode only)
-- Extends the map's metal top edge leftward over the Homestead panel
-- so the two frames share one seamless top border.
--
-- Skipped entirely in standalone mode (custom UI or user preference).
-- All Blizzard frame access is nil-guarded for safety.
-------------------------------------------------------------------------------

State.borderUnified = false
State.savedMapTopLeftCornerShown = nil

local function UnifyTopBorder()
    if State.borderUnified then return end
    if not State.panelFrame then return end
    if ShouldUseStandaloneMode() then return end

    local bf = WorldMapFrame.BorderFrame
    if not bf then return end
    local mapNS = bf.NineSlice
    if not mapNS then return end

    local canvas = WorldMapFrame.ScrollContainer
    local mapTopEdge = mapNS.TopEdge
    local mapTopLeft = mapNS.TopLeftCorner
    local panelNS = State.panelFrame.NineSlice

    if not mapTopEdge or not panelNS or not canvas then return end

    -- 1. Extend panel upward so its top aligns with the map border top.
    local borderTop = bf.GetTop and bf:GetTop()
    local canvasTop = canvas.GetTop and canvas:GetTop()
    if borderTop and canvasTop and (borderTop - canvasTop) > 0 then
        State.panelFrame:SetPoint("TOPRIGHT", canvas, "TOPLEFT", 0, borderTop - canvasTop)
    end

    -- 2. Save map TopEdge's original left anchor for restore
    if not State.savedMapTopEdge then
        local ok, p, r, rp, x, y = pcall(mapTopEdge.GetPoint, mapTopEdge, 1)
        if ok and p then
            State.savedMapTopEdge = { p, r, rp, x, y }
        end
    end

    -- 3. Hide the map's NineSlice portrait corner (TopLeftCorner is the large
    --    corner piece with border geometry). The portrait container's own built-in
    --    gold ring (region 3, texture 136430) handles the circular border.
    if mapTopLeft then
        State.savedMapTopLeftCornerShown = mapTopLeft:IsShown()
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
    if State.bgTexture and borderTop and canvasTop then
        local borderHeight = borderTop - canvasTop
        local bgOffset = borderHeight - 45  -- 45px up from canvas to border bottom
        if bgOffset > 0 then
            State.bgTexture:SetPoint("TOPLEFT", State.panelFrame, "TOPLEFT", 0, -bgOffset)
        end
    end

    State.borderUnified = true
end

local function RestoreTopBorder()
    if not State.borderUnified then return end

    local bf = WorldMapFrame.BorderFrame
    local mapNS = bf and bf.NineSlice
    local canvas = WorldMapFrame.ScrollContainer
    local mapTopEdge = mapNS and mapNS.TopEdge
    local mapTopLeft = mapNS and mapNS.TopLeftCorner
    local panelNS = State.panelFrame and State.panelFrame.NineSlice

    -- Restore map TopEdge original anchor
    if mapTopEdge and State.savedMapTopEdge then
        pcall(mapTopEdge.SetPoint, mapTopEdge,
            State.savedMapTopEdge[1], State.savedMapTopEdge[2],
            State.savedMapTopEdge[3], State.savedMapTopEdge[4], State.savedMapTopEdge[5])
    end
    State.savedMapTopEdge = nil  -- Re-capture fresh on next UnifyTopBorder

    -- Restore background to fill full panel (no border zone offset)
    if State.bgTexture then
        State.bgTexture:SetPoint("TOPLEFT", State.panelFrame, "TOPLEFT", 0, 0)
    end

    -- Restore map TopLeftCorner (portrait ring) visibility
    if mapTopLeft and State.savedMapTopLeftCornerShown then
        mapTopLeft:Show()
    end
    State.savedMapTopLeftCornerShown = nil

    -- Restore panel top border pieces
    if panelNS then
        if panelNS.TopEdge then panelNS.TopEdge:Show() end
        if panelNS.TopRightCorner then panelNS.TopRightCorner:Show() end
    end

    -- Restore panel anchor (back to canvas top, no Y extension)
    if canvas then
        State.panelFrame:SetPoint("TOPRIGHT", canvas, "TOPLEFT", 0, 0)
    end

    State.borderUnified = false
end

-------------------------------------------------------------------------------
-- Toggle / Visibility
-------------------------------------------------------------------------------

State.panelShowGeneration = 0  -- Incremented each Show, guards deferred callbacks

local function ApplyDockedIntegration()
    State.ShiftMapRight()

    if not ShouldUseStandaloneMode() then
        ReparentMapElements()
        -- Defer border + content inset by one frame for accurate layout values.
        -- Guard with generation counter so a quick close cancels this.
        State.panelShowGeneration = State.panelShowGeneration + 1
        local gen = State.panelShowGeneration
        C_Timer.After(0, function()
            if gen ~= State.panelShowGeneration then return end
            if not State.panelFrame or not State.panelFrame:IsShown() then return end
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
        State.mapShifted = false
        State.savedMapPoint = nil
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

State.combatFrame = CreateFrame("Frame")
State.combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
State.combatFrame:SetScript("OnEvent", function()
    if not State.pendingDockedAction then return end
    local action = State.pendingDockedAction
    State.pendingDockedAction = nil
    if action == "apply" then
        -- Panel was shown during combat; apply map integration now
        if State.panelFrame and State.panelFrame:IsShown() and not State.isPoppedOut
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
    if not State.panelFrame then return end

    -- When popped out, skip all map integration (panel is independent)
    if State.isPoppedOut then
        State.panelFrame:Show()
        return
    end

    -- Don't show docked panel when map is maximized (fills the screen)
    if WorldMapFrame.isMaximized then return end

    State.panelFrame:Show()

    -- Defer all docked map mutations until combat ends
    if InCombatLockdown() then
        State.pendingDockedAction = "apply"
        return
    end

    ApplyDockedIntegration()
end

local function HidePanel()
    if not State.panelFrame then return end
    -- Bump generation to cancel any pending deferred Show callbacks
    State.panelShowGeneration = State.panelShowGeneration + 1

    -- Explicit cleanup of expandable content
    HideAllNonVendorContent()
    ClearSearch(false)
    if State.searchEditBox then State.searchEditBox:ClearFocus() end

    if State.isPoppedOut then
        -- When popped out, just hide the frame — no map restoration needed
        State.panelFrame:Hide()
        return
    end

    State.panelFrame:Hide()

    -- Defer map restoration until combat ends
    if InCombatLockdown() then
        State.pendingDockedAction = "remove"
        return
    end

    RemoveDockedIntegration(true)
end

-- Update button visibility based on pop-out state
local function UpdatePopOutButtons()
    if not State.popOutButton then return end
    if State.isPoppedOut then
        State.popOutButton:Hide()
        State.closeButton:Show()
        State.reattachButton:Show()
    else
        State.popOutButton:Show()
        State.closeButton:Hide()
        State.reattachButton:Hide()
    end
end

-- Re-set frame levels after reparent (SetParent can reset child levels)
local function RestoreFrameLevels()
    if not State.panelFrame then return end
    State.panelFrame:SetFrameStrata("HIGH")
    State.panelFrame:SetFrameLevel(500)
    if State.panelFrame.NineSlice then
        State.panelFrame.NineSlice:SetFrameLevel(502)
    end
end

-- Ensure NineSlice border is visually complete (re-show pieces hidden by UnifyTopBorder)
local function EnsureCompleteBorder()
    if not State.panelFrame or not State.panelFrame.NineSlice then return end
    local ns = State.panelFrame.NineSlice
    if ns.TopEdge then ns.TopEdge:Show() end
    if ns.TopRightCorner then ns.TopRightCorner:Show() end
end

-- Save detached position to profile. Called from the resize/drag handlers
-- above and from DockPanel()/CloseDetached() below.
State.SaveDetachedPosition = function()
    if not State.panelFrame or not HA.Addon or not HA.Addon.db then return end
    local point, _, _, x, y = State.panelFrame:GetPoint(1)
    if point then
        HA.Addon.db.profile.vendorTracer.sidePanelPosition = {
            point = point, x = x or 0, y = y or 0,
        }
    end
    HA.Addon.db.profile.vendorTracer.sidePanelHeight = State.panelFrame:GetHeight()
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
    if not State.panelFrame then return end
    if State.isPoppedOut then return end

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
        local canvasH = State.panelFrame:GetHeight()
        if canvasH > 1 then
            h = canvasH * 0.5
        else
            h = UIParent:GetHeight() * 0.3
        end
    end

    -- 2. Restore all map modifications
    if InCombatLockdown() then
        State.pendingDockedAction = "remove"
    else
        RemoveDockedIntegration(true)
    end

    -- 3. Panel is already parented to UIParent; no reparent needed

    -- 4. Re-set strata/levels
    RestoreFrameLevels()

    -- 5-6. Clear anchors, set size, restore position
    State.panelFrame:ClearAllPoints()
    State.panelFrame:SetWidth(Layout.PANEL_WIDTH)
    State.panelFrame:SetHeight(h)

    local saved = db and db.profile.vendorTracer.sidePanelPosition
    if saved and IsPositionOnScreen(saved) then
        State.panelFrame:SetPoint(saved.point, UIParent, saved.point, saved.x, saved.y)
    else
        State.panelFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    -- 7. Make movable via State.panelFrame drag (not State.headerFrame — header starts 22px
    --    below the top, so the NineSlice border wouldn't be draggable).
    --    Child frames (buttons, scroll) capture their own clicks; State.panelFrame drag
    --    only activates from "empty" areas like the border and header text.
    State.panelFrame:SetMovable(true)
    State.panelFrame:SetClampedToScreen(true)
    State.panelFrame:RegisterForDrag("LeftButton")
    State.panelFrame:SetScript("OnDragStart", State.panelFrame.StartMoving)
    State.panelFrame:SetScript("OnDragStop", function(self) -- luacheck: ignore 432
        self:StopMovingOrSizing()
        State.SaveDetachedPosition()
    end)

    -- 8. Enable height resizing
    State.panelFrame:SetResizable(true)
    State.panelFrame:SetResizeBounds(Layout.PANEL_WIDTH, 200, Layout.PANEL_WIDTH, UIParent:GetHeight() * 0.9)
    if State.resizeHandle then State.resizeHandle:Show() end

    -- 9. Ensure complete border
    EnsureCompleteBorder()

    -- 8b. Raise reattach button above NineSlice (only needed when detached;
    --     setting at creation time breaks the unified top border in docked mode)
    if State.reattachButton then
        State.reattachButton:SetFrameLevel(State.panelFrame:GetFrameLevel() + 5)
    end

    -- 9. Update buttons
    State.isPoppedOut = true  -- Set before UpdatePopOutButtons so it reads correctly
    UpdatePopOutButtons()

    -- 10. (Removed: UISpecialFrames registration caused combat taint via CloseWindows())

    -- 11. Cancel pending deferred callbacks
    State.panelShowGeneration = State.panelShowGeneration + 1

    -- 12. Save to profile
    if db then
        db.profile.vendorTracer.sidePanelPoppedOut = true
        db.profile.vendorTracer.sidePanelHeight = h
    end

    State.panelFrame:Show()
    self:RefreshContent()
end

function MapSidePanel:DockPanel()
    if not State.panelFrame then return end
    if not State.isPoppedOut then return end

    -- 1. Save position and height
    State.SaveDetachedPosition()

    -- 2. Panel stays parented to UIParent; just reconfigure for docked mode

    -- 3. Clear drag and resize handlers
    State.panelFrame:SetMovable(false)
    State.panelFrame:SetResizable(false)
    State.panelFrame:SetScript("OnDragStart", nil)
    State.panelFrame:SetScript("OnDragStop", nil)
    if State.resizeHandle then State.resizeHandle:Hide() end

    -- 4. Restore original anchors (flush left of canvas, height from top+bottom anchors)
    local canvas = WorldMapFrame.ScrollContainer
    State.panelFrame:ClearAllPoints()
    State.panelFrame:SetWidth(Layout.PANEL_WIDTH)
    State.panelFrame:SetPoint("TOPRIGHT", canvas, "TOPLEFT", 0, 0)
    State.panelFrame:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMLEFT", 0, 0)

    -- 5. Re-set strata/levels
    RestoreFrameLevels()
    -- Reattach button level is not reset here — it's hidden when docked
    -- and touching frame levels during dock disrupts NineSlice rendering.

    -- 6. Update buttons
    State.isPoppedOut = false
    UpdatePopOutButtons()

    -- 7. Pre-hide panel's top NineSlice pieces before integrated mode re-applies.
    --    EnsureCompleteBorder() during PopOut showed these; UnifyTopBorder will
    --    hide them again via the deferred callback, but pre-hiding avoids a
    --    one-frame flash where both the panel's top border and map border overlap.
    if not ShouldUseStandaloneMode() then
        local ns = State.panelFrame.NineSlice
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
        State.panelFrame:Hide()
    end

    -- 9. Save to profile
    if HA.Addon and HA.Addon.db then
        HA.Addon.db.profile.vendorTracer.sidePanelPoppedOut = false
    end
end

function MapSidePanel:CloseDetached()
    if not State.panelFrame then return end

    -- Save position while frame is still visible and anchored
    State.SaveDetachedPosition()

    -- Full reset: hide panel, clear both pop-out and panel-shown state
    HidePanel()
    State.isPoppedOut = false
    UpdatePopOutButtons()

    -- Panel stays on UIParent; just reconfigure for docked mode next time
    State.panelFrame:SetMovable(false)
    State.panelFrame:SetResizable(false)
    State.panelFrame:SetScript("OnDragStart", nil)
    State.panelFrame:SetScript("OnDragStop", nil)
    if State.resizeHandle then State.resizeHandle:Hide() end

    -- Restore original anchors
    local canvas = WorldMapFrame.ScrollContainer
    State.panelFrame:ClearAllPoints()
    State.panelFrame:SetWidth(Layout.PANEL_WIDTH)
    State.panelFrame:SetPoint("TOPRIGHT", canvas, "TOPLEFT", 0, 0)
    State.panelFrame:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMLEFT", 0, 0)

    RestoreFrameLevels()

    if HA.Addon and HA.Addon.db then
        HA.Addon.db.profile.vendorTracer.sidePanelPoppedOut = false
        HA.Addon.db.profile.vendorTracer.showMapSidePanel = false
    end
end

function MapSidePanel:Toggle()
    if not State.panelFrame then return end

    if State.isPoppedOut then
        if State.panelFrame:IsShown() then
            -- Popped out + visible: full reset
            self:CloseDetached()
        else
            -- Popped out + hidden (shouldn't normally happen): open docked
            State.isPoppedOut = false
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

    if State.panelFrame:IsShown() then
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
    if State.panelFrame then
        ShowPanel()
        self:RefreshContent()
    end
end

function MapSidePanel:Hide()
    if State.panelFrame then
        HidePanel()
    end
end

function MapSidePanel:IsShown()
    return State.panelFrame and State.panelFrame:IsShown()
end

function MapSidePanel:IsPoppedOut()
    return State.isPoppedOut
end

function MapSidePanel:GetSourceFilter()
    return State.panelSourceFilter
end

function MapSidePanel:SetSourceFilter(sourceFilter)
    local normalized = NormalizePanelSourceFilter(sourceFilter)
    if State.panelSourceFilter == normalized then
        UpdateSourceFilterDropdownText()
        return
    end

    State.panelSourceFilter = normalized

    if HA.Addon and HA.Addon.db and HA.Addon.db.profile and HA.Addon.db.profile.vendorTracer then
        HA.Addon.db.profile.vendorTracer.mapSidePanelSourceFilter = normalized
    end

    UpdateSourceFilterDropdownText()

    -- HS-018: continent/world badges now honor the filter, so invalidate caches
    -- unconditionally on filter change (the prior zone-only gate at this site
    -- was a workaround for the unfiltered higher-level paths). Also kick a
    -- world-map repaint when the map is currently open so pins/badges update
    -- in place rather than waiting for the next map re-open.
    if HA.VendorMapPins and HA.VendorMapPins.InvalidateAllCaches then
        HA.VendorMapPins:InvalidateAllCaches()
    elseif BC and BC.InvalidateAllCaches then
        BC:InvalidateAllCaches()
    end
    if HA.VendorMapPins and HA.VendorMapPins.RequestWorldMapRefresh
            and WorldMapFrame and WorldMapFrame:IsShown() then
        HA.VendorMapPins:RequestWorldMapRefresh("source_filter_changed", 0, true)
    end

    self:RefreshContent()
end

-- Slash command toggle: pop out if docked/hidden, close if already popped out
function MapSidePanel:ToggleDetached()
    if not State.panelFrame then return end
    if State.isPoppedOut then
        self:CloseDetached()
    else
        self:PopOut()
    end
end

function MapSidePanel:ResetIntegrationMode()
    ResetStandaloneCheck()
end

-- HS-210: debounced scheduler for OWNERSHIP_UPDATED / VENDOR_SCANNED /
-- ACTIVE_ENDEAVOR_CHANGED / SOURCE_CACHES_INVALIDATED. Without this, a burst
-- of the same event (e.g. UPDATE_FACTION firing SOURCE_CACHES_INVALIDATED
-- several times in one frame) schedules N independent 0.1s timers that each
-- run a full RefreshContent — same defer, just N rebuilds 0.1s later instead
-- of 0. One pending flag collapses any burst into exactly one refresh.
local function ScheduleContentRefresh()
    if State.pendingContentRefresh then return end
    State.pendingContentRefresh = true
    C_Timer.After(0.1, function()
        State.pendingContentRefresh = false
        MapSidePanel:RefreshContent()
    end)
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function MapSidePanel:Initialize()
    if State.isInitialized then return end

    -- Set module references
    VendorData = HA.VendorData
    VendorFilter = HA.VendorFilter
    BC = HA.BadgeCalculation

    if HA.Addon and HA.Addon.db and HA.Addon.db.profile and HA.Addon.db.profile.vendorTracer then
        State.panelSourceFilter = NormalizePanelSourceFilter(HA.Addon.db.profile.vendorTracer.mapSidePanelSourceFilter)
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

    -- HS-081: passive WorldMapFrame state detection. Replaces 6 hooksecurefunc/
    -- HookScript callbacks (SetMapID, OnShow, OnHide, HandleUserActionMaximizeSelf,
    -- HandleUserActionMinimizeSelf, and the RefreshOverlayFrames hook in
    -- CreateOverlayButton) that fired inside Blizzard's secure ToggleWorldMap ->
    -- ShowUIPanel(WorldMapFrame) -> Show()/SetMapID() path; the posthook bodies left
    -- that context tainted, blocking the protected SetPassThroughButtons continuation
    -- (QuestDataProvider -> MapCanvasPinMixin:CheckMouseButtonPassthrough), surfacing
    -- as [ADDON_ACTION_BLOCKED] tainted by 'Homestead'. HS-275: the provider now feeds
    -- this from DispatchMapWatch's C_Timer.After(0) deferral (HomesteadWorldMapProvider.lua),
    -- which reacts one frame AFTER the secure path has returned, so the reaction is
    -- never in a tainted context -- the same pattern as that file (which has zero
    -- WorldMapFrame hooks). Behavior is unchanged: the in-combat docked-panel deferral
    -- via State.pendingDockedAction / PLAYER_REGEN_ENABLED is preserved verbatim, and mapWatch
    -- is seeded from the current WorldMapFrame state so /reload with the map already
    -- open is a no-op -- matching the old behavior, where the OnShow hook was installed
    -- after the map was already shown and therefore never fired.
    local mapWatch = {
        shown        = WorldMapFrame and WorldMapFrame:IsShown() or false,
        maximized    = false,
        mapID        = nil,
        overlayCount = nil,
    }
    if mapWatch.shown then
        mapWatch.maximized    = WorldMapFrame.isMaximized and true or false
        mapWatch.mapID        = WorldMapFrame:GetMapID()
        mapWatch.overlayCount = CountVisibleOverlayButtons()
    end

    -- HS-223a: this used to run its own independent 10Hz ticker polling
    -- WorldMapFrame:IsShown()/:GetMapID()/isMaximized -- the exact same raw
    -- state HomesteadWorldMapProvider.lua reads. Registered as a callback
    -- there instead of running a second redundant poll; trigger semantics
    -- below are unchanged, just fed from the shared dispatch's (isShown,
    -- mapID, maximized) instead of a private one. HS-275: the provider side
    -- is now push-driven off Blizzard's map-canvas data-provider dispatch
    -- rather than a 10Hz ticker, so this callback fires on-change instead of
    -- 10 times a second -- every branch here is edge-triggered against
    -- mapWatch, so cadence doesn't change what fires. Do NOT convert this to
    -- a WorldMapFrame hook (HS-081): hooks run inside Blizzard's secure
    -- map-open path and taint execution.
    local function MapWatchTick(shown, mapID, maximized)
        if shown and not mapWatch.shown then
            -- Map just opened (was: WorldMapFrame OnShow hook). No C_Timer.After(0)
            -- wrapper needed here -- DispatchMapWatch's own After(0) deferral already
            -- runs this after the secure path; ShowPanel -> ApplyDockedIntegration
            -- keeps its own one-frame border/inset defer.
            if not State.isPoppedOut and not maximized
                    and HA.Addon and HA.Addon.db
                    and HA.Addon.db.profile.vendorTracer.showMapSidePanel then
                ShowPanel()
                MapSidePanel:RefreshContent()
            end
            -- (was: RefreshOverlayFrames hook -- a map open rebuilds overlayFrames)
            PositionOverlayButton()
            mapWatch.overlayCount = CountVisibleOverlayButtons()

        elseif not shown and mapWatch.shown then
            -- Map just closed (was: WorldMapFrame OnHide hook).
            if not State.isPoppedOut then
                -- HS-019: clear any active search when the docked panel closes with
                -- the map. Popped-out panels keep their search state (early return above).
                ClearSearch(false)
                -- Bump generation to cancel any pending deferred Show callbacks.
                State.panelShowGeneration = State.panelShowGeneration + 1
                if State.panelFrame then State.panelFrame:Hide() end

                if InCombatLockdown() then
                    -- Closing during combat; defer restoration. Cancel any pending
                    -- "apply" -- the map is gone, nothing to integrate.
                    State.pendingDockedAction = "remove"
                else
                    RestoreContentInset()
                    RestoreTopBorder()
                    RestoreMapElements()
                    RestoreMapPosition()
                    State.mapShifted = false
                end
            end

        elseif shown then
            if maximized and not mapWatch.maximized then
                -- Map maximized (was: HandleUserActionMaximizeSelf hook). Blizzard has
                -- already repositioned the map, so clear our shift state without
                -- restoring (the saved point is stale).
                if not State.isPoppedOut and State.panelFrame and State.panelFrame:IsShown() then
                    State.panelShowGeneration = State.panelShowGeneration + 1
                    State.panelFrame:Hide()

                    if InCombatLockdown() then
                        State.mapShifted = false
                        State.savedMapPoint = nil
                        State.pendingDockedAction = "clear"
                    else
                        RemoveDockedIntegration(false)
                    end
                end

            elseif not maximized and mapWatch.maximized then
                -- Map minimized (was: HandleUserActionMinimizeSelf hook).
                if not State.isPoppedOut and State.panelFrame
                        and HA.Addon and HA.Addon.db
                        and HA.Addon.db.profile.vendorTracer.showMapSidePanel then
                    ShowPanel()
                    MapSidePanel:RefreshContent()
                end

            elseif mapID and mapID ~= mapWatch.mapID and mapID ~= State.lastRefreshMapID then
                -- Blizzard-driven zone change (was: SetMapID hook). Self-driven nav
                -- (vendor/summary-row clicks, back button) already calls RefreshContent
                -- synchronously and sets State.lastRefreshMapID, so this fires only for
                -- map-canvas / NavBar navigation.
                MapSidePanel:RefreshContent()
                PositionOverlayButton()  -- a zone change rebuilds overlayFrames
                mapWatch.overlayCount = CountVisibleOverlayButtons()

            else
                -- Residual overlay-button count change (was: RefreshOverlayFrames hook
                -- on a non-zone-change overlay toggle).
                local oc = CountVisibleOverlayButtons()
                if oc ~= mapWatch.overlayCount then
                    mapWatch.overlayCount = oc
                    PositionOverlayButton()
                end
            end
        end

        mapWatch.shown     = shown
        mapWatch.maximized = maximized
        mapWatch.mapID     = mapID
    end

    local WorldMapProvider = HA.HomesteadWorldMapProvider
    if WorldMapProvider then
        WorldMapProvider:RegisterMapWatchCallback("MapSidePanel", MapWatchTick)
        -- Idempotent (no-op if VendorMapPins:Initialize already registered
        -- the data provider) -- ensures registration happens even if init
        -- order ever changes, since MapSidePanel:Initialize() currently runs
        -- first.
        WorldMapProvider:EnsureRegistered()
    end

    -- Listen for data changes
    if HA.Events then
        -- Deferred like its VENDOR_SCANNED sibling below: VendorMapPins' cache wipe
        -- on this same event is init-order dependent, so a synchronous repaint here
        -- can race ahead of it and never repaint after the wipe lands. All four
        -- listeners below share ScheduleContentRefresh's debounce so a burst of
        -- any one of them (or a mix) collapses into a single RefreshContent.
        HA.Events:RegisterCallback("OWNERSHIP_UPDATED", ScheduleContentRefresh)

        HA.Events:RegisterCallback("VENDOR_SCANNED", ScheduleContentRefresh)

        HA.Events:RegisterCallback("ACTIVE_ENDEAVOR_CHANGED", ScheduleContentRefresh)

        -- Source caches invalidated — covers achievement, quest, reputation,
        -- profession, and holiday changes through SourceManager. An
        -- UPDATE_FACTION burst can invalidate several times in one frame;
        -- ScheduleContentRefresh's debounce collapses that into one rebuild.
        HA.Events:RegisterCallback("SOURCE_CACHES_INVALIDATED", ScheduleContentRefresh)
    end

    -- Initialize SearchProvider
    if HA.SearchProvider and HA.SearchProvider.Initialize then
        HA.SearchProvider:Initialize()
    end

    -- Foundry.Menu controllers for context menus and source-filter dropdown.
    -- RequireModule fails loud if a standalone Foundry without Menu is loaded
    -- instead of the embed (matches the List/Lifecycle/DB call sites).
    do
        local Menu = F:RequireModule("Menu", 1)
        State.menuContextMenu = Menu:New({
            name    = "HS.ContextMenu",
            builder = function(owner, rootDescription)
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
                if State.panelFrame and (State.panelFrame:IsShown() or State.isPoppedOut) then
                    rootDescription:CreateCheckbox(
                        State.isPoppedOut and "Attach to Map" or "Detach Panel",
                        function() return State.isPoppedOut end,
                        function()
                            if State.isPoppedOut then
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
                    if HA.OptionsFrame and HA.OptionsFrame.Open then
                        HA.OptionsFrame:Open()
                    end
                end)
            end,
        })

        State.menuSourceFilter = Menu:New({
            name    = "HS.SourceFilter",
            builder = function(_, rootDescription)
                AddSourceFilterMenuEntries(rootDescription)
            end,
        })
    end

    State.isInitialized = true

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
