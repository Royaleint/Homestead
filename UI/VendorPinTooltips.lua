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
    local tooltip = GetPinTooltip()
    tooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    tooltip:ClearLines()
    return tooltip
end

local function IsActivePinTooltipVisible()
    if not activeTooltipData or not pinTooltip then
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
                        activeTooltipData.vendor
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
    activeTooltipData = nil
    itemInfoEventFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    if pinTooltip then
        pinTooltip:Hide()
    end
end

function VendorPinTooltips:HidePinTooltip()
    self:OnPinLeave()
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
-- Argus: src.type runs through NormalizeSourceType, matching every other
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

function VendorPinTooltips:ShowVendorTooltip(pin, vendor)
    if not vendor then return end

    local itemDetailsEnabled = IsVendorPinItemDetailsEnabled()

    -- Track active tooltip for GET_ITEM_INFO_RECEIVED refresh
    activeTooltipData = { kind = "vendor", pin = pin, vendor = vendor }
    itemInfoEventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

    local isOpposite = HA.VendorMapPins:IsOppositeFaction(vendor)

    local tooltip = BeginPinTooltip(pin, "ANCHOR_RIGHT")
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

    -- Gather items from both static and scanned data
    local allItems = {}
    local itemsSeen = {}

    -- Scanned items for this vendor, keyed by itemID -> normalized cost.
    -- Built once (before the static loop) so a static row with no cost data
    -- can be backfilled from the vendor's real scanned price instead of
    -- rendering "?" forever, and so the scanned loop below doesn't have to
    -- re-normalize per item. First non-nil cost per itemID wins -- a costless
    -- record (an unfinished scan of that merchant slot) never overwrites a
    -- real price seen elsewhere for the same item.
    -- Gated on itemDetailsEnabled: AddPinTooltipItemLine only reads item.cost
    -- when isVendorContext is true (below), so with the toggle off this
    -- normalization pass (up to one call per scanned item) is pure waste.
    local scannedCostByItemID = {}
    local scannedItems
    if vendor.npcID and HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
        local scannedData = HA.Addon.db.global.scannedVendors[vendor.npcID]
        scannedItems = scannedData and (scannedData.items)
        if scannedItems and itemDetailsEnabled then
            for _, item in ipairs(scannedItems) do
                if item.itemID and scannedCostByItemID[item.itemID] == nil then
                    -- HS-074B: scanned items carry the legacy {price, currencies}
                    -- shape instead of the static gather's {cost} field below --
                    -- normalize once here so the cost column renders the same way
                    -- for both sources. NormalizeScannedCost's already-normalized
                    -- passthrough branch returns scannedItem.cost BY REFERENCE, so
                    -- a mapped cost can still alias a live SavedVariables
                    -- sub-table. Nothing writes through it today -- don't assume
                    -- that stays true.
                    scannedCostByItemID[item.itemID] = HA.VendorData and HA.VendorData:NormalizeScannedCost(item)
                end
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
            -- HS-074B: curated static cost stays authoritative when present;
            -- a costless static row (offer captured no price) backfills from
            -- the vendor's scanned price so a real scan result isn't shadowed
            -- by a permanent "?".
            local cost = HA.VendorData:GetItemCost(item)
            if cost == nil then
                cost = scannedCostByItemID[itemID]
            end
            tinsert(allItems, {itemID = itemID, cost = cost})
        end
    end

    -- Add scanned items (new format: items = {...}, old format: decor = {...})
    if scannedItems then
        for _, item in ipairs(scannedItems) do
            if item.itemID and not itemsSeen[item.itemID] then
                itemsSeen[item.itemID] = true
                tinsert(allItems, {itemID = item.itemID, name = item.name, cost = scannedCostByItemID[item.itemID]})
            end
        end
    end

    if #allItems > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("Items Sold:", 1, 1, 0)

        for _, item in ipairs(allItems) do
            AddPinTooltipItemLine(tooltip, item, {
                context = "vendorMapPin",
                npcID = vendor.npcID,
                sourceFilter = HA.VendorMapPins:GetActiveSourceFilter(),
                isVendorContext = itemDetailsEnabled,
            })
        end

    else
        -- No item data available
        tooltip:AddLine(" ")
        tooltip:AddLine("Item data unknown - visit vendor to scan", 1, 0.82, 0)
    end

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
            tooltip:AddLine(string.format("Vendor-only: %d", stats.vendorOnly), 0.85, 0.85, 0.85)
        end

        if isOpposite and not HA.VendorMapPins:CanAccessVendor(vendor) then
            tooltip:AddLine("Cannot buy on this character - opposite faction vendor", 1.0, 0.5, 0.5)
            tooltip:AddLine("Locked counts above only reflect requirement gates.", 0.9, 0.7, 0.7)
        end

        local blockers = stats.blockers or {}
        for i = 1, math.min(3, #blockers) do
            local blocker = blockers[i]
            tooltip:AddLine(string.format("Locked by: %s (%d)", blocker.label, blocker.count), 1.0, 0.82, 0)
        end

        if #blockers > 3 then
            tooltip:AddLine(string.format("Locked by: +%d more blocker types", #blockers - 3), 0.8, 0.8, 0.8)
        end
    end

    tooltip:AddLine(" ")
    if isOpposite then
        tooltip:AddLine("Left-click to set waypoint (for alts)", 0.5, 0.5, 0.5)
    else
        tooltip:AddLine("Left-click to set waypoint", 0.5, 0.5, 0.5)
    end
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
