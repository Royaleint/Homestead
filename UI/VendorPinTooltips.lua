--[[
    Homestead - VendorPinTooltips
    Pin tooltips: vendor, zone/continent badge, portal, minimap, and drop pins

    Extracted from VendorMapPins.lua (HS-301 cut #1) to reduce file size.
    Owns the pin-tooltip GameTooltip instance, GET_ITEM_INFO_RECEIVED-driven
    tooltip refresh, and the five Show*Tooltip entry points PinFrameFactory
    calls on hover.

    External callers should use the VendorMapPins delegation wrappers
    (Show*Tooltip, OnPinLeave, HidePinTooltip) — HA.VendorMapPins is the
    frozen public surface; this module is an implementation detail behind it.
]]

local _, HA = ...

local VendorPinTooltips = {}
HA.VendorPinTooltips = VendorPinTooltips

-- BadgeCalculation reference (loaded before this file per TOC order)
local BC = HA.BadgeCalculation

-- Upvalued Lua stdlib
local ipairs = ipairs
local tinsert = table.insert
local format = string.format
local unpack = unpack

local PIN_TOOLTIP_NAME = "HomesteadVendorMapPinsTooltip"

-- Item info event tracking for tooltip refresh (GET_ITEM_INFO_RECEIVED)
local itemInfoEventFrame = CreateFrame("Frame")
local activeTooltipData = nil      -- {kind="vendor"|"drop", pin, vendor|record} while a pin tooltip is visible
local tooltipRebuildPending = false -- Debounce flag for batching rebuilds
local pinTooltip = nil

-- Interactive tooltip for long wares lists: a second GameTooltip with a scroll
-- bar and search box. Short vendors stay on pinTooltip.
local LONG_WARES_THRESHOLD = 15
local MAX_VISIBLE_WARE_ROWS = 15
local INTERACTIVE_TOOLTIP_NAME = "HomesteadVendorMapPinsWaresTooltip"
local INTERACTIVE_RIGHT_PADDING = 24
local INTERACTIVE_BAR_INSET = 10
local INTERACTIVE_BOTTOM_PADDING = 26
local INTERACTIVE_MIN_WIDTH = 240
local interactiveTooltip = nil
local interactiveScrollBar = nil
local interactiveSearchBox = nil
-- nil when closed, else one table per hover: pin, vendor, active (this hover's
-- activeTooltipData), wares, matches, query, offset (0-based), itemDetailsEnabled,
-- isOpposite, measuredWidth, anchored, itemIDs (wares and reagent costs, built per gather).
local interactiveHover = nil
local syncingScrollBar = false
local interactiveThumbHeld = false
local interactiveSearchTimer = nil

-- Idempotent; runs from every close path and from the frame's own OnHide.
local function ResetInteractiveState()
    local hover = interactiveHover
    interactiveHover = nil -- first: the focus-lost hook must see no hover
    interactiveThumbHeld = false
    if hover and activeTooltipData == hover.active then
        activeTooltipData = nil
        itemInfoEventFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    end
    if interactiveSearchTimer then
        interactiveSearchTimer:Cancel()
        interactiveSearchTimer = nil
    end
    if interactiveSearchBox then
        interactiveSearchBox:ClearFocus()
        interactiveSearchBox:SetText("")
    end
    -- Last: ends a thumb or arrow hold that a forced close interrupted.
    if interactiveScrollBar and interactiveScrollBar.UnregisterUpdate then
        interactiveScrollBar:UnregisterUpdate()
    end
end

local function CloseInteractiveTooltip()
    if not interactiveTooltip then return end
    ResetInteractiveState()
    if interactiveTooltip:IsShown() then interactiveTooltip:Hide() end
end

-- Zero-delay so the cursor has settled on its next frame (pin to tooltip crossing).
local function ScheduleInteractiveLeaveCheck()
    local hover = interactiveHover
    if not hover then return end
    C_Timer.After(0, function()
        if interactiveHover ~= hover then return end
        if interactiveThumbHeld then return end -- a drag strays off the thumb; the release re-checks
        if interactiveSearchBox:HasFocus() then return end
        if interactiveTooltip:IsMouseOver() then return end
        if hover.pin:IsMouseOver() then return end
        CloseInteractiveTooltip()
    end)
end

local function GetPinTooltip()
    if pinTooltip then
        return pinTooltip
    end

    local tooltip = CreateFrame("GameTooltip", PIN_TOOLTIP_NAME, UIParent, "GameTooltipTemplate")
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetClampedToScreen(true)
    pinTooltip = tooltip
    return tooltip
end

local function BeginPinTooltip(owner, anchor)
    CloseInteractiveTooltip()
    local tooltip = GetPinTooltip()
    tooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    tooltip:ClearLines()
    return tooltip
end

local function IsActivePinTooltipVisible()
    if not activeTooltipData then
        return false
    end

    -- Before the pinTooltip test: it is nil until a plain tooltip has been shown.
    if interactiveHover then
        return interactiveTooltip ~= nil and interactiveTooltip:IsShown()
            and interactiveHover.pin == activeTooltipData.pin
    end

    if not pinTooltip then
        return false
    end

    if not pinTooltip:IsShown() then
        return false
    end

    return pinTooltip:GetOwner() == activeTooltipData.pin
end

-- HS-235: shared debounced rebuild, factored out of the GET_ITEM_INFO_RECEIVED
-- handler below so a second arrival signal (Item:ContinueOnItemLoad's own
-- callback, see RequestItemDataForTooltip) can drive the exact same render
-- path through the exact same tooltipRebuildPending debounce, instead of
-- duplicating this logic or assuming GET_ITEM_INFO_RECEIVED also fires for
-- the modern Item-Mixin load path (unverified — see RequestItemDataForTooltip).
local function RebuildActivePinTooltip()
    if not activeTooltipData then return end
    if not tooltipRebuildPending then
        tooltipRebuildPending = true
        C_Timer.After(0.05, function()
            tooltipRebuildPending = false
            if IsActivePinTooltipVisible() then
                if activeTooltipData.kind == "vendor" then
                    VendorPinTooltips:ShowVendorTooltip(
                        activeTooltipData.pin,
                        activeTooltipData.vendor,
                        true
                    )
                elseif activeTooltipData.kind == "drop" then
                    VendorPinTooltips:ShowDropPinTooltip(activeTooltipData.pin, activeTooltipData.record)
                end
            end
        end)
    end
end

itemInfoEventFrame:SetScript("OnEvent", function(self, event, itemID, success)
    if not success or not activeTooltipData then return end
    -- An open long tooltip only cares about its own wares and reagent costs.
    local hover = interactiveHover
    if hover and hover.active == activeTooltipData and itemID and hover.itemIDs and not hover.itemIDs[itemID] then
        return
    end
    RebuildActivePinTooltip()
end)

-- HS-235: item 264500 class — C_Item.DoesItemExistByID true, but the server
-- never volunteers the data, so GetItemInfo stays nil forever and
-- GET_ITEM_INFO_RECEIVED never arrives to drive a rebuild; the tooltip line
-- was stuck on "Unknown Item" across hovers AND sessions. HS-190 precedent
-- (Overlay/Tooltips.lua's cold-cache re-render on OnTooltipSetItem) is the
-- idiom reused here verbatim: Item:CreateFromItemID(itemID):ContinueOnItemLoad
-- rather than a manual C_Item.RequestLoadItemDataByID + GET_ITEM_INFO_RECEIVED
-- wait — ContinueOnItemLoad both requests the load AND calls back on arrival
-- (or immediately if already cached), and is the modern API surface Blizzard
-- uses for this exact class of problem throughout its own UI (Mount Journal,
-- Encounter Journal, Professions, EventToastManager, etc. — confirmed via
-- Blizzard UI source search, all following the identical shape).
--
-- The rebuild is driven directly from ContinueOnItemLoad's own callback
-- (through RebuildActivePinTooltip, the SAME debounce GET_ITEM_INFO_RECEIVED
-- already uses) rather than assumed to also arrive via GET_ITEM_INFO_RECEIVED
-- — GET_ITEM_INFO_RECEIVED and ITEM_DATA_LOAD_RESULT are distinct events, and
-- the already-shipped HS-190 precedent in Tooltips.lua does the same thing
-- (never waits on GET_ITEM_INFO_RECEIVED for its own cold-cache path). This
-- means no new event registration was needed to close this gap.
--
-- Session-scoped guard: requestedItemDataIDs prevents re-requesting on every
-- hover of an item that's already been asked for once. A server-withheld
-- item (264500's class) may NEVER arrive — ContinueOnItemLoad's callback
-- then simply never fires. That's not a leak: nothing is polling or holding
-- a ticker open waiting for it, the closure just sits inert as part of
-- Blizzard's own item-load callback registry until the item (if ever) loads,
-- and the tooltip correctly keeps showing the honest "Unknown Item" fallback
-- in the meantime.
local requestedItemDataIDs = {}

local function RequestItemDataForTooltip(itemID)
    if requestedItemDataIDs[itemID] then return end
    requestedItemDataIDs[itemID] = true
    Item:CreateFromItemID(itemID):ContinueOnItemLoad(function()
        RebuildActivePinTooltip()
    end)
end

-- Called by PinFrameFactory OnLeave scripts to clear tooltip tracking state
function VendorPinTooltips:OnPinLeave()
    if interactiveHover then
        ScheduleInteractiveLeaveCheck()
        return
    end
    activeTooltipData = nil
    itemInfoEventFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    if pinTooltip then
        pinTooltip:Hide()
    end
end

-- Unconditional close: pin teardown, and the badge, portal and minimap pin leave handlers.
function VendorPinTooltips:HidePinTooltip()
    CloseInteractiveTooltip()
    self:OnPinLeave()
end

function VendorPinTooltips:CloseInteractiveTooltip()
    CloseInteractiveTooltip()
end

-------------------------------------------------------------------------------
-- Tooltips
-------------------------------------------------------------------------------

-- HS-074 test: atlas-based inline glyphs for non-vendor source types.
-- Atlas rendering tends to be sharper at small inline sizes than item-icon
-- texture paths (which can look pixelated when scaled down from 64x64). Atlas
-- names mirror Constants.SourceBadgeAtlas (the catalog overlay's pick).
-- Filter implicit: vendor/event/shop are not in this table, so they render no glyph
-- (the current tooltip context IS a vendor — its own type would be redundant).
local SOURCE_TOOLTIP_ICONS = {
    profession  = "|A:UI-HUD-MicroMenu-Professions-Mouseover:16:16|a",
    drop        = "|A:Crosshair_lootall_64:16:16|a",
    quest       = "|A:QuestNormal:16:16|a",
    achievement = "|A:UI-Achievement-Shield-NoPoints:16:16|a",
}

-- HS-074 test: concatenated icon string for an item's non-vendor source types.
-- Returns empty string when item is vendor-only or has no source data.
-- Optional `sources` lets a caller that already fetched GetAllSources (e.g.
-- AddPinTooltipItemLine's presentation.allSources) pass them in and skip the
-- second lookup; GetAllSources is memoized regardless (HS-273/281/282).
-- src.type runs through NormalizeSourceType, matching every other
-- source.type consumer (SourceManager.lua's own display-source resolution).
local function BuildItemSourceIconText(itemID, sources)
    local SM = HA.SourceManager
    if not itemID or not SM then return "" end
    if not sources and SM.GetAllSources then
        sources = SM:GetAllSources(itemID)
    end
    if not sources or #sources == 0 then return "" end

    local seen = {}
    local parts = {}
    for _, src in ipairs(sources) do
        local normalizedType = SM.NormalizeSourceType and SM:NormalizeSourceType(src.type) or src.type
        local glyph = normalizedType and SOURCE_TOOLTIP_ICONS[normalizedType]
        if glyph and not seen[normalizedType] then
            seen[normalizedType] = true
            parts[#parts + 1] = glyph
        end
    end
    if #parts == 0 then return "" end
    -- Two spaces between name and first icon (single space looked attached to text);
    -- one space between adjacent icons when multiple types apply.
    return "  " .. table.concat(parts, " ")
end

local function AddPinTooltipItemLine(tooltip, item, options, suffix)
    local itemID = item and item.itemID
    local resolvedName = (item and item.name) or (itemID and C_Item.GetItemInfo(itemID))
    -- HS-235: name genuinely unresolved (not just "item has no .name override") —
    -- request the data once per session so a future hover (this one still
    -- shows the honest fallback) or the debounced rebuild below can pick it
    -- up once/if it arrives.
    if not resolvedName and itemID then
        RequestItemDataForTooltip(itemID)
    end
    local itemName = resolvedName or "Unknown Item"
    local availabilityState = nil
    local allSources = nil
    local SM = HA.SourceManager

    if itemID and SM and SM.GetItemPresentation then
        local presentation = SM:GetItemPresentation(itemID, options)
        availabilityState = presentation and presentation.availabilityState
        allSources = presentation and presentation.allSources
    -- HS-203: no-presentation fallback stays cache-only, matching
    -- SourceManager's "vendorMapPin" context (the primary path above).
    elseif itemID and HA.CatalogStore and HA.CatalogStore:IsOwned(itemID) then
        availabilityState = "owned"
    elseif itemID and options and options.npcID
            and SM and SM.GetVendorItemAvailabilityState then
        availabilityState = SM:GetVendorItemAvailabilityState(itemID, options.npcID)
    end

    -- HS-229: entrance-grouped drop pins can carry records from several
    -- different bosses; callers pass a suffix (e.g. "(Boss Name)") so each
    -- item line stays attributable when the tooltip header can't name one.
    local lineText = suffix and ("  " .. itemName .. " " .. suffix) or ("  " .. itemName)

    local lr, lg, lb = 1, 1, 1  -- default: white (available/unknown)
    if availabilityState == "owned" then
        lr, lg, lb = 0, 1, 0
    elseif availabilityState == "locked" then
        lr, lg, lb = 1, 0.25, 0.25
    end

    -- HS-074: vendor-pin tooltips additionally show alternative-source glyphs
    -- trailing the name and the vendor's cost in a right-aligned column.
    -- Drop-pin tooltips (isVendorContext false/absent) keep the plain
    -- single-line rendering unchanged.
    if options and options.isVendorContext then
        local sourceIcons = BuildItemSourceIconText(itemID, allSources)
        local costText = HA.VendorData and HA.VendorData:FormatCost(item and item.cost) or "?"
        tooltip:AddDoubleLine(lineText .. sourceIcons, costText, lr, lg, lb, 1, 0.82, 0)
    else
        tooltip:AddLine(lineText, lr, lg, lb)
    end

    return availabilityState
end

-- HS-074B: "Vendor pin item details" toggle (default ON) gates the whole
-- HS-074/HS-074B pin-tooltip enrichment as a unit -- source icons, cost
-- column, and the vendor-only summary line. Read fresh per tooltip build
-- (cheap -- tooltip content already rebuilds per hover), not cached at load.
-- profile.vendorTracer.showVendorPinItemDetails has a registered
-- Constants.Defaults entry, which Foundry.DB backfills into every profile at
-- materialization time (Libs/Foundry-1.0/Modules/DB.lua's applyDefaults) --
-- so this plain read is ON for existing profiles too, matching the sibling
-- vendorTracer.showVendorDetails idiom (VendorTracer.lua:159), not a
-- defensive ~= false check.
local function IsVendorPinItemDetailsEnabled()
    local vendorTracer = HA.Addon and HA.Addon.db and HA.Addon.db.profile and HA.Addon.db.profile.vendorTracer
    if not vendorTracer then return true end
    return vendorTracer.showVendorPinItemDetails
end

local function AddVendorHeaderLines(tooltip, vendor, isOpposite)
    tooltip:AddLine(vendor.name, 1, 1, 1)

    if vendor.subzone then
        tooltip:AddLine(vendor.subzone .. " (" .. vendor.zone .. ")", 0.7, 0.7, 0.7)
    elseif vendor.zone then
        tooltip:AddLine(vendor.zone, 0.7, 0.7, 0.7)
    end

    if vendor.faction and vendor.faction ~= "Neutral" then
        local factionColor = vendor.faction == "Alliance" and {0, 0.44, 0.87} or {0.77, 0.12, 0.23}
        tooltip:AddLine(vendor.faction, unpack(factionColor))
    end

    -- Warning for opposite faction vendors
    if isOpposite then
        tooltip:AddLine(" ")
        tooltip:AddLine("Cannot access - opposite faction vendor", 0.8, 0.3, 0.3)
    end

    if vendor.notes then
        tooltip:AddLine(" ")
        tooltip:AddLine(vendor.notes, 1, 0.82, 0, true)
    end
end

local function AddVendorWareLines(tooltip, vendor, wares, first, last, itemDetailsEnabled)
    tooltip:AddLine(" ")
    tooltip:AddLine("Items Sold:", 1, 1, 0)

    for index = first, last do
        AddPinTooltipItemLine(tooltip, wares[index], {
            context = "vendorMapPin",
            npcID = vendor.npcID,
            sourceFilter = HA.VendorMapPins:GetActiveSourceFilter(),
            isVendorContext = itemDetailsEnabled,
        })
    end
end

-- The long wares tooltip takes its width from the ware rows and wraps footer
-- text to fit. The plain tooltip's AddLine calls carry no wrap argument.
local function AddFooterLine(tooltip, wrap, text, r, g, b)
    if wrap then
        tooltip:AddLine(text, r, g, b, true)
    else
        tooltip:AddLine(text, r, g, b)
    end
end

local function AddVendorFooterLines(tooltip, vendor, isOpposite, itemDetailsEnabled, wrap)
    -- Purchasability summary (only when we have item data)
    local stats = HA.VendorMapPins:GetVendorStats(vendor, HA.VendorMapPins:GetActiveSourceFilter())
    if stats.total > 0 then
        tooltip:AddLine(" ")
        BC.AddSummaryLine(tooltip, stats.collected, stats.total, stats.locked, stats.unverified)

        -- HS-074 test: count of items at this vendor with no non-vendor source
        -- type. Read from stats.vendorOnly (BadgeCalculation) rather than
        -- re-walking allItems here — that keeps this number counting the exact
        -- same population as the collected/total/locked figures above it
        -- (source filter, HS-249 exclusion, merged static+scanned set) instead
        -- of a second, differently-filtered pass. Wording is a stand-in;
        -- refine during design review.
        if itemDetailsEnabled and stats.vendorOnly and stats.vendorOnly > 0 then
            AddFooterLine(tooltip, wrap, string.format("Vendor-only: %d", stats.vendorOnly), 0.85, 0.85, 0.85)
        end

        if isOpposite and not HA.VendorMapPins:CanAccessVendor(vendor) then
            AddFooterLine(tooltip, wrap, "Cannot buy on this character - opposite faction vendor", 1.0, 0.5, 0.5)
            AddFooterLine(tooltip, wrap, "Locked counts above only reflect requirement gates.", 0.9, 0.7, 0.7)
        end

        local blockers = stats.blockers or {}
        for i = 1, math.min(3, #blockers) do
            local blocker = blockers[i]
            AddFooterLine(tooltip, wrap, string.format("Locked by: %s (%d)", blocker.label, blocker.count), 1.0, 0.82, 0)
        end

        if #blockers > 3 then
            AddFooterLine(tooltip, wrap, string.format("Locked by: +%d more blocker types", #blockers - 3), 0.8, 0.8, 0.8)
        end
    end

    tooltip:AddLine(" ")
    if isOpposite then
        AddFooterLine(tooltip, wrap, "Left-click to set waypoint (for alts)", 0.5, 0.5, 0.5)
    else
        AddFooterLine(tooltip, wrap, "Left-click to set waypoint", 0.5, 0.5, 0.5)
    end
end

local function ScrollMaximum(hover)
    return math.max(0, #hover.matches - MAX_VISIBLE_WARE_ROWS)
end

-- The measuring pass stops before the footer, so no footer line can set the width.
-- The caller clears the frame and sizes it first, so wrapped lines fold to that size.
local function AddInteractiveLines(hover, list, first, last, measuring)
    local frame = interactiveTooltip
    AddVendorHeaderLines(frame, hover.vendor, hover.isOpposite)
    AddVendorWareLines(frame, hover.vendor, list, first, last, hover.itemDetailsEnabled)
    if measuring then return end
    if #list == 0 then
        frame:AddLine(HA.L["No items found"], 0.7, 0.7, 0.7, true)
    end
    AddVendorFooterLines(frame, hover.vendor, hover.isOpposite, hover.itemDetailsEnabled, true)
end

-- Open and rebuild only: the width is frozen from the header and every ware,
-- plus the bar column, so scrolling never resizes the tooltip under the cursor.
local function MeasureInteractiveWidth(hover)
    local frame = interactiveTooltip
    frame:ClearLines()
    frame:SetMinimumWidth(INTERACTIVE_MIN_WIDTH)
    frame:SetPadding(0, INTERACTIVE_BOTTOM_PADDING)
    AddInteractiveLines(hover, hover.wares, 1, #hover.wares, true)
    -- Sized on both sides of the lines: wrapped lines need the width as they go
    -- in, and a minimum set on an empty tooltip is not known to hold.
    frame:SetMinimumWidth(INTERACTIVE_MIN_WIDTH)
    frame:SetPadding(0, INTERACTIVE_BOTTOM_PADDING)
    frame:Show()
    local width = frame:GetWidth()
    if not width or width <= 0 then return end
    -- Whether a minimum width counts the padding and the frame's own margins
    -- is the client's call: set the target, read back any overshoot, take it off.
    local target = width + INTERACTIVE_RIGHT_PADDING
    frame:SetMinimumWidth(target)
    frame:SetPadding(INTERACTIVE_RIGHT_PADDING, INTERACTIVE_BOTTOM_PADDING)
    frame:Show()
    hover.measuredWidth = target - math.max(0, frame:GetWidth() - target)
end

local function SyncInteractiveScrollBar(hover)
    local bar = interactiveScrollBar
    local maximum = ScrollMaximum(hover)
    if maximum == 0 then
        bar:Hide()
        interactiveThumbHeld = false
        bar:UnregisterUpdate()
        return
    end
    bar:Show()
    -- SetScrollPercentage re-fires the bar's OnScroll; the callback ignores it.
    syncingScrollBar = true
    bar:SetVisibleExtentPercentage(MAX_VISIBLE_WARE_ROWS / #hover.matches)
    bar:SetPanExtentPercentage(1 / maximum)
    bar:SetScrollPercentage(hover.offset / maximum, ScrollBoxConstants.NoScrollInterpolation)
    syncingScrollBar = false
end

-- Edge to edge against the pin, both axes tested in screen pixels: pins sit
-- under a scaled map canvas, so their coordinates are not UIParent units.
local function AnchorInteractiveTooltip(hover)
    local frame, pin = interactiveTooltip, hover.pin
    local right, top = pin:GetRight(), pin:GetTop()
    if not right or not top then return false end
    local pinScale, frameScale = pin:GetEffectiveScale(), frame:GetEffectiveScale()
    local screenRight = UIParent:GetWidth() * UIParent:GetEffectiveScale()
    local flip = (screenRight - right * pinScale) < frame:GetWidth() * frameScale
    local hangsDown = top * pinScale >= frame:GetHeight() * frameScale
    frame:ClearAllPoints()
    if hangsDown then
        frame:SetPoint(flip and "TOPRIGHT" or "TOPLEFT", pin, flip and "TOPLEFT" or "TOPRIGHT", 0, 0)
    else
        frame:SetPoint(flip and "BOTTOMRIGHT" or "BOTTOMLEFT", pin, flip and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, 0)
    end
    return true
end

-- At most MAX_VISIBLE_WARE_ROWS rows. GameTooltip_OnHide clears padding, so
-- it is re-applied on every render.
local function RenderInteractiveWindow(hover)
    local frame = interactiveTooltip
    hover.offset = math.max(0, math.min(hover.offset, ScrollMaximum(hover)))
    local last = math.min(#hover.matches, hover.offset + MAX_VISIBLE_WARE_ROWS)
    frame:ClearLines()
    frame:SetMinimumWidth(hover.measuredWidth or INTERACTIVE_MIN_WIDTH)
    -- The bar column stays reserved when the bar hides, so a search never moves the right edge.
    frame:SetPadding(INTERACTIVE_RIGHT_PADDING, INTERACTIVE_BOTTOM_PADDING)
    AddInteractiveLines(hover, hover.matches, hover.offset + 1, last)
    frame:SetMinimumWidth(hover.measuredWidth or INTERACTIVE_MIN_WIDTH)
    frame:SetPadding(INTERACTIVE_RIGHT_PADDING, INTERACTIVE_BOTTOM_PADDING)
    frame:Show()
    -- Placed once per hover, once the height is real; a zero height reads as room below.
    if not hover.anchored and hover.measuredWidth and frame:GetHeight() > 0 then
        hover.anchored = AnchorInteractiveTooltip(hover)
    end
    SyncInteractiveScrollBar(hover)
end

-- A thumb drag fires every frame; offsets are whole rows, so most calls resolve
-- to the offset already shown.
local function SetInteractiveScrollOffset(offset)
    local hover = interactiveHover
    if not hover then return end
    offset = math.max(0, math.min(offset, ScrollMaximum(hover)))
    if offset == hover.offset then return end
    hover.offset = offset
    RenderInteractiveWindow(hover)
end

local function OnInteractiveMouseWheel(_, delta)
    local hover = interactiveHover
    if hover then
        SetInteractiveScrollOffset(hover.offset - delta)
    end
end

-- Search text is built when the wares are gathered, following FormatCost's guards
-- for what the cost column shows; a keystroke then only scans cached strings.
local function BuildWareSearchText(hover)
    local itemIDs = {}
    hover.itemIDs = itemIDs
    for _, ware in ipairs(hover.wares) do
        local parts = {}
        if ware.itemID then itemIDs[ware.itemID] = true end
        local name = ware.name or (ware.itemID and C_Item.GetItemNameByID(ware.itemID))
        if name then parts[#parts + 1] = name end
        local cost = hover.itemDetailsEnabled and ware.cost or nil
        if cost and cost.currencies then
            for _, currency in ipairs(cost.currencies) do
                if currency.amount then
                    local info = currency.id and C_CurrencyInfo.GetCurrencyInfo(currency.id)
                    local currencyName = (info and info.name) or currency.name
                    if currencyName then parts[#parts + 1] = currencyName end
                end
            end
        end
        if cost and cost.items then
            for _, itemCost in ipairs(cost.items) do
                if itemCost.id then itemIDs[itemCost.id] = true end
                if itemCost.amount and itemCost.id then
                    local reagentName = C_Item.GetItemNameByID(itemCost.id) or itemCost.name
                    if reagentName then parts[#parts + 1] = reagentName end
                end
            end
        end
        ware.searchText = table.concat(parts, "\n"):lower()
    end
end

local function ApplyInteractiveSearch(hover)
    if hover.query == "" then
        hover.matches = hover.wares
        return
    end
    local matches = {}
    for _, ware in ipairs(hover.wares) do
        if ware.searchText:find(hover.query, 1, true) then
            matches[#matches + 1] = ware
        end
    end
    hover.matches = matches
end

local function EnsureInteractiveTooltip()
    if interactiveTooltip then
        return interactiveTooltip
    end

    local frame = CreateFrame("GameTooltip", INTERACTIVE_TOOLTIP_NAME, UIParent, "GameTooltipTemplate")
    frame:SetFrameStrata("TOOLTIP")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)

    local bar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -INTERACTIVE_BAR_INSET, -8)
    bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -INTERACTIVE_BAR_INSET, INTERACTIVE_BOTTOM_PADDING + 4)
    bar:Init(1, 1)
    bar:RegisterCallback(BaseScrollBoxEvents.OnScroll, function(_, percentage)
        local hover = interactiveHover
        if syncingScrollBar or not hover then return end
        SetInteractiveScrollOffset(math.floor(percentage * ScrollMaximum(hover) + 0.5))
    end, frame)
    bar:SetScript("OnMouseWheel", OnInteractiveMouseWheel)

    local box = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    box:SetAutoFocus(false)
    box:SetMaxLetters(50)
    box:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 6)
    box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 6)
    box:SetHeight(20)
    -- Focus was holding the tooltip open; when it ends, close unless the cursor is on it or its pin.
    box:HookScript("OnEditFocusLost", function()
        local hover = interactiveHover
        if not hover or not frame:IsShown() then return end
        if frame:IsMouseOver() then return end
        if hover.pin:IsMouseOver() then return end
        CloseInteractiveTooltip()
    end)
    box:HookScript("OnTextChanged", function(self)
        if interactiveSearchTimer then
            interactiveSearchTimer:Cancel()
            interactiveSearchTimer = nil
        end
        local hover = interactiveHover
        if not hover then return end
        interactiveSearchTimer = C_Timer.NewTimer(0.3, function()
            interactiveSearchTimer = nil
            if interactiveHover ~= hover or not frame:IsShown() then return end
            hover.query = (self:GetText():match("^%s*(.-)%s*$") or ""):lower()
            ApplyInteractiveSearch(hover)
            hover.offset = 0
            RenderInteractiveWindow(hover)
        end)
    end)
    box:HookScript("OnEscapePressed", function() CloseInteractiveTooltip() end)

    -- The bar's children take the cursor off the tooltip frame; each leave re-checks.
    -- A drag that strays off the thumb must not close the tooltip, so the held flag defers to the release.
    local thumb = bar:GetThumb()
    thumb:HookScript("OnMouseDown", function() interactiveThumbHeld = true end)
    thumb:HookScript("OnMouseUp", function()
        interactiveThumbHeld = false
        ScheduleInteractiveLeaveCheck()
    end)
    bar:GetTrack():SetScript("OnLeave", ScheduleInteractiveLeaveCheck)
    for _, child in ipairs({ thumb, bar:GetBackStepper(), bar:GetForwardStepper(), box, box.clearButton }) do
        child:HookScript("OnLeave", ScheduleInteractiveLeaveCheck)
    end

    frame:SetScript("OnMouseWheel", OnInteractiveMouseWheel)
    frame:SetScript("OnLeave", ScheduleInteractiveLeaveCheck)
    -- HookScript: SetScript would replace the template's GameTooltip_OnHide.
    frame:HookScript("OnHide", ResetInteractiveState)
    -- A frame re-shown by its parent after an implicit hide has no hover and must not linger.
    frame:SetScript("OnShow", function(self)
        if not interactiveHover then self:Hide() end
    end)

    interactiveTooltip = frame
    interactiveScrollBar = bar
    interactiveSearchBox = box
    return frame
end

local function ShowInteractiveVendorTooltip(pin, vendor, allItems, itemDetailsEnabled, isOpposite, isRebuild)
    local frame = EnsureInteractiveTooltip()
    local current = interactiveHover
    -- Late names: update rows in place and keep offset, query, focus and placement.
    if isRebuild and current and current.pin == pin and current.vendor == vendor and frame:IsShown() then
        current.active = activeTooltipData
        current.wares = allItems
        current.itemDetailsEnabled = itemDetailsEnabled
        current.isOpposite = isOpposite
        BuildWareSearchText(current)
        ApplyInteractiveSearch(current)
        MeasureInteractiveWidth(current)
        RenderInteractiveWindow(current)
        return
    end
    if pinTooltip then pinTooltip:Hide() end
    CloseInteractiveTooltip()
    frame:SetOwner(pin, "ANCHOR_NONE")
    frame:ClearAllPoints()
    -- Provisional; placed for good after the first render.
    frame:SetPoint("TOPLEFT", pin, "TOPRIGHT", 0, 0)
    local hover = {
        pin = pin, vendor = vendor, active = activeTooltipData,
        wares = allItems, matches = allItems, query = "", offset = 0,
        itemDetailsEnabled = itemDetailsEnabled, isOpposite = isOpposite, anchored = false,
    }
    -- Before the first Show: the OnShow guard hides a frame with no hover.
    interactiveHover = hover
    BuildWareSearchText(hover)
    MeasureInteractiveWidth(hover)
    RenderInteractiveWindow(hover)
    -- A zero first width is never stored; retry once, never from scroll or search.
    if not hover.measuredWidth then
        C_Timer.After(0, function()
            if interactiveHover ~= hover or hover.measuredWidth then return end
            MeasureInteractiveWidth(hover)
            RenderInteractiveWindow(hover)
        end)
    end
end

function VendorPinTooltips:ShowVendorTooltip(pin, vendor, isRebuild)
    if not vendor then return end

    local itemDetailsEnabled = IsVendorPinItemDetailsEnabled()

    -- Track active tooltip for GET_ITEM_INFO_RECEIVED refresh
    activeTooltipData = { kind = "vendor", pin = pin, vendor = vendor }
    itemInfoEventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

    local isOpposite = HA.VendorMapPins:IsOppositeFaction(vendor)

    -- Gather items from both static and scanned data
    local allItems = {}
    local itemsSeen = {}

    local scannedItems
    local scannedLastScanned
    if HA.VendorData and HA.VendorData.GetScannedVendorRecord then
        local scannedData = HA.VendorData:GetScannedVendorRecord(vendor)
        scannedItems = scannedData and scannedData.items
        scannedLastScanned = scannedData and scannedData.lastScanned
    end
    local scannedCostByItemID = {}
    local scannedCostKnownByItemID = {}
    if scannedItems and itemDetailsEnabled then
        for _, item in ipairs(scannedItems) do
            if item.itemID then
                scannedCostKnownByItemID[item.itemID] = true
            end
            if item.itemID and scannedCostByItemID[item.itemID] == nil then
                    scannedCostByItemID[item.itemID] = HA.VendorData and HA.VendorData:NormalizeScannedCost(item)
            end
        end
    end

    -- Add static items from the unified vendor access layer.
    local vendorItems = HA.VendorData and HA.VendorData.GetItemsForVendor and HA.VendorData:GetItemsForVendor(vendor) or {}
    for _, item in ipairs(vendorItems) do
        local itemID = HA.VendorData:GetItemID(item)
        if itemID and not itemsSeen[itemID] then
            itemsSeen[itemID] = true
            -- HS-074 test: preserve cost on the wrapped record so the right column
            -- can format it. Previously stripped, which is why the cost column
            -- rendered "?" even for vendors that had data populated.
            local cost = HA.VendorData:GetItemCost(item)
            if cost == nil then
                cost = scannedCostByItemID[itemID]
            end
            tinsert(allItems, {itemID = itemID, cost = cost})
            if itemDetailsEnabled and HA.SourceManager and HA.SourceManager.GetVendorItemCost then
                allItems[#allItems].cost = HA.SourceManager:GetVendorItemCost(
                    itemID, vendor, scannedCostByItemID[itemID],
                    true, cost, true, scannedLastScanned)
            end
        end
    end

    -- Add scanned items (new format: items = {...}, old format: decor = {...})
    if scannedItems then
        for _, item in ipairs(scannedItems) do
            if item.itemID and not itemsSeen[item.itemID] then
                itemsSeen[item.itemID] = true
                local cost = scannedCostByItemID[item.itemID]
                if itemDetailsEnabled and HA.SourceManager and HA.SourceManager.GetVendorItemCost then
                    cost = HA.SourceManager:GetVendorItemCost(
                        item.itemID, vendor, scannedCostByItemID[item.itemID],
                        scannedCostKnownByItemID[item.itemID] == true, nil, true, scannedLastScanned)
                end
                tinsert(allItems, {itemID = item.itemID, name = item.name, cost = cost})
            end
        end
    end

    if #allItems > LONG_WARES_THRESHOLD then
        ShowInteractiveVendorTooltip(pin, vendor, allItems, itemDetailsEnabled, isOpposite, isRebuild)
        return
    end

    local tooltip = BeginPinTooltip(pin, "ANCHOR_RIGHT")
    AddVendorHeaderLines(tooltip, vendor, isOpposite)
    if #allItems > 0 then
        AddVendorWareLines(tooltip, vendor, allItems, 1, #allItems, itemDetailsEnabled)
    else
        -- No item data available
        tooltip:AddLine(" ")
        tooltip:AddLine("Item data unknown - visit vendor to scan", 1, 0.82, 0)
    end
    AddVendorFooterLines(tooltip, vendor, isOpposite, itemDetailsEnabled)
    tooltip:Show()
end

function VendorPinTooltips:ShowZoneBadgeTooltip(pin, zoneInfo)
    if not zoneInfo then return end

    activeTooltipData = nil
    itemInfoEventFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")

    local tooltip = BeginPinTooltip(pin, "ANCHOR_RIGHT")
    tooltip:AddLine(zoneInfo.zoneName, 1, 1, 1)

    -- Show note (class hall info, access method, etc.)
    if zoneInfo.note then
        tooltip:AddLine(zoneInfo.note, 0.7, 0.7, 1.0, true)
    end

    tooltip:AddLine(format("Decor Vendors: %d", zoneInfo.vendorCount), 1, 0.82, 0)

    -- Show faction breakdown if there are opposite faction vendors
    if zoneInfo.oppositeFactionCount and zoneInfo.oppositeFactionCount > 0 then
        local accessibleCount = zoneInfo.vendorCount - zoneInfo.oppositeFactionCount
        local playerFaction = UnitFactionGroup("player")
        local oppositeFaction = playerFaction == "Alliance" and "Horde" or "Alliance"

        if accessibleCount > 0 then
            tooltip:AddLine(format("  %s: %d", playerFaction, accessibleCount), 0.7, 0.7, 0.7)
        end

        local factionColor = oppositeFaction == "Alliance" and {0.2, 0.4, 0.8} or {0.8, 0.2, 0.2}
        tooltip:AddLine(format("  %s: %d", oppositeFaction, zoneInfo.oppositeFactionCount),
            factionColor[1], factionColor[2], factionColor[3])
    end

    -- Collection summary
    BC.AddSummaryLine(tooltip, zoneInfo.collectedItems, zoneInfo.totalItems, zoneInfo.lockedItems, zoneInfo.unverifiedItems)

    if zoneInfo.unknownCount and zoneInfo.unknownCount > 0 then
        tooltip:AddLine(format("Unknown status: %d vendor(s) (visit to scan)", zoneInfo.unknownCount), 1, 0.82, 0)
    end

    local knownVendors = zoneInfo.vendorCount - (zoneInfo.unknownCount or 0)
    local allCollected = (zoneInfo.uncollectedCount or 0) == 0 and knownVendors > 0
    if allCollected and (zoneInfo.unknownCount or 0) == 0 then
        tooltip:AddLine("All items collected!", 0.5, 0.5, 0.5)
    end

    tooltip:AddLine(" ")
    tooltip:AddLine("Left-click to view zone map", 0.5, 0.5, 0.5)
    tooltip:Show()
end

function VendorPinTooltips:ShowPortalTooltip(pin, vendor)
    if not vendor then return end

    activeTooltipData = nil
    itemInfoEventFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")

    local tooltip = BeginPinTooltip(pin, "ANCHOR_RIGHT")
    tooltip:AddLine(vendor.name, 1, 1, 1)
    tooltip:AddLine("Order Hall Portal", 0.7, 0.5, 1.0)
    if vendor.notes then
        tooltip:AddLine(vendor.notes, 1, 0.82, 0, true)
    end
    tooltip:AddLine("Click to view vendor location", 0.5, 0.5, 0.5)
    tooltip:Show()
end

function VendorPinTooltips:ShowMinimapTooltip(pin, vendor, isOppositeFaction, elevation)
    if not vendor then return end

    activeTooltipData = nil
    itemInfoEventFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")

    local tooltip = BeginPinTooltip(pin, "ANCHOR_LEFT")
    tooltip:AddLine(vendor.name, 1, 1, 1)
    if vendor.subzone and vendor.subzone ~= "" then
        tooltip:AddLine(vendor.subzone, 0.7, 0.7, 0.7)
    elseif vendor.zone then
        tooltip:AddLine(vendor.zone, 0.7, 0.7, 0.7)
    end
    if isOppositeFaction then
        tooltip:AddLine("Opposite faction", 0.8, 0.3, 0.3)
    end
    if elevation == "above" then
        tooltip:AddLine("|A:Rotating-MinimapGuideArrow:0:0|a Above you", 0.6, 0.8, 1.0)
    elseif elevation == "below" then
        tooltip:AddLine("v Below you", 0.6, 0.8, 1.0)
    end
    tooltip:Show()
end

function VendorPinTooltips:ShowDropPinTooltip(pin, record)
    if not record or not record.records or #record.records == 0 then return end

    activeTooltipData = { kind = "drop", pin = pin, record = record }
    itemInfoEventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

    local tooltip = BeginPinTooltip(pin, "ANCHOR_RIGHT")
    local primaryDrop = record.records[1].drop

    -- An "ent:" (dungeon-entrance) pin can carry records from several
    -- DIFFERENT bosses sharing one instance entrance (e.g. all Voidspire
    -- rows on the outdoor zone map), so it gets an instance-level header
    -- with per-item boss attribution below. "enc:" groups share one
    -- encounter — records may span tier variants, but the boss is the
    -- same — and "legacy" groups are single-record, so records[1] is an
    -- accurate header for both.
    if record.dropGroupKind == "ent" then
        tooltip:AddLine(primaryDrop and primaryDrop.zone or "Unknown Instance", 1, 1, 1)
    else
        if primaryDrop and primaryDrop.mobName then
            tooltip:AddLine(primaryDrop.mobName, 1, 1, 1)
        else
            tooltip:AddLine("Unknown Drop", 1, 1, 1)
        end
        if primaryDrop and primaryDrop.zone then
            tooltip:AddLine(primaryDrop.zone, 0.7, 0.7, 0.7)
        end
        if primaryDrop and primaryDrop.notes then
            tooltip:AddLine(" ")
            tooltip:AddLine(primaryDrop.notes, 1, 0.82, 0, true)
        end
    end

    tooltip:AddLine(" ")
    tooltip:AddLine(#record.records > 1
        and ("Items Dropped (%d):"):format(#record.records)
        or "Items Dropped:", 1, 1, 0)

    -- HS-249: this loop derives its own counts rather than reading
    -- BadgeCalculation, so it needs its own exclusion guard. The denominator
    -- is the record count, so an item whose ownership we cannot resolve would
    -- otherwise inflate it and read as "0/1 collected" on a room plan.
    -- The item still gets its tooltip line; only the summary count changes.
    local CS = HA.CatalogStore
    local collected, locked, excluded = 0, 0, 0
    for _, itemRecord in ipairs(record.records) do
        -- ent: groups can't rely on the header to name a boss, so each item
        -- line names its own (mobName may still differ between records that
        -- share an entrance but not an encounter).
        local suffix = record.dropGroupKind == "ent" and itemRecord.drop and itemRecord.drop.mobName
            and ("(%s)"):format(itemRecord.drop.mobName) or nil
        local availabilityState = AddPinTooltipItemLine(tooltip, { itemID = itemRecord.itemID }, {
            context = "dropMapPin",
            sourceFilter = "drop",
            isVendorContext = false,
        }, suffix)
        if CS and CS.IsOwnershipUnknowable and CS:IsOwnershipUnknowable(itemRecord.itemID) then
            excluded = excluded + 1
        elseif availabilityState == "owned" then
            collected = collected + 1
        elseif availabilityState == "locked" then
            locked = locked + 1
        end
    end

    tooltip:AddLine(" ")
    BC.AddSummaryLine(tooltip, collected, #record.records - excluded, locked, 0)

    tooltip:Show()
end
