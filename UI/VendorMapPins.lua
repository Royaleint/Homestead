--[[
    Homestead - VendorMapPins
    World and minimap integration for housing decor vendor locations

    World map pins are now rendered through Homestead's native world-map provider.
    Minimap pins are rendered through Homestead's native minimap overlay.

    Features:
    - Zone view: Shows pin icons at vendor locations
    - Continent view: Shows zone badges with vendor counts
    - World map: Shows continent badges with vendor counts
    - Pin tooltips: Shows vendor name, items sold, collection status
    - Click to set waypoint (with TomTom support if available)
    - Minimap pins: Shows nearby vendors HandyNotes-style (with elevation arrows)
]]

local _, HA = ...

-- Create VendorMapPins module
local VendorMapPins = {}
HA.VendorMapPins = VendorMapPins

-- Local references
local Constants = HA.Constants
local MPP = HA.MapPinProvider
local WorldMapProvider = HA.HomesteadWorldMapProvider
local MinimapOverlay = HA.HomesteadMinimapOverlay

-- Upvalued Lua stdlib
local pairs, ipairs = pairs, ipairs
local tinsert = table.insert
local format = string.format
local unpack = unpack

-- State
local isInitialized = false
local pinsEnabled = true
local PIN_TOOLTIP_NAME = "HomesteadVendorMapPinsTooltip"

local highlightedPinFrame = nil
local highlightOverlay = nil
local highlightOriginalScale = nil
local highlightOriginalFrameLevel = nil


-- Pin color/size helpers delegated to PinFrameFactory (loaded before this file)
-- Vendor filter/coord helpers resolved in Initialize() to avoid load-order fragility.
local ShouldHideVendor
local GetBestVendorCoordinates
local ShouldShowOppositeFaction
local CanAccessVendor
local IsOppositeFaction
local GetVendorXY

-- Badge/collection helpers delegated to BadgeCalculation (loaded before this file)
local BC = HA.BadgeCalculation
local GetContinentForZone = MPP.GetContinentForZone

-- HS-018: read the active side-panel source filter, with a defensive fallback
-- to "all" if MapSidePanel isn't loaded yet (e.g. early init before panel module
-- finishes Initialize()). MapSidePanel:GetSourceFilter() reads the persisted
-- profile value at module load, so this returns the user's setting even when
-- the panel UI is hidden.
local function GetActiveSourceFilter()
    local panel = HA.MapSidePanel
    if panel and panel.GetSourceFilter then
        return panel:GetSourceFilter() or "all"
    end
    return "all"
end

-- Minimap pins enabled state
local minimapPinsEnabled = true

-- Shared minimap refresh timer used to coalesce bursty refresh requests.
local minimapRefreshTimer = nil
local worldMapRefreshTimer = nil
local WORLDMAP_REFRESH_DEFAULT_DELAY = 0.02
local MINIMAP_REFRESH_DEFAULT_DELAY = 0.15
local MINIMAP_REFRESH_ZONE_DELAY = 0.35
local MINIMAP_WARMUP_DELAY = 0.9
local MINIMAP_WARMUP_PIN_CAP = 28

-- Pin caps reduce work in dense hubs while preserving nearby visibility.
local MINIMAP_PIN_CAPS = {
    off = 80,
    auto = 60,
    on = 120,
}



-- Runtime event handles (registered conditionally by feature state)
local merchantEventFrame = nil
local zoneEventFrame = nil
local minimapWarmupActive = false
local minimapWarmupTimer = nil

-- Dedup guards for minimap and world map refreshes
local lastMinimapMapID = nil
local lastRenderedWorldMapID = nil
local worldMapDirty = true
local worldMapDebugStats = {
    refreshRequests = 0,
    skippedRequests = 0,
    builtStates = 0,
    lastLogTime = 0,
    lastLoggedRequests = 0,
    lastLoggedSkips = 0,
    lastLoggedBuilds = 0,
    lastLoggedProviderCalls = 0,
    lastLoggedProviderRenders = 0,
    lastLoggedProviderNoops = 0,
    lastLoggedProviderHidden = 0,
    lastLoggedProviderMismatch = 0,
    lastLoggedMemoryKB = nil,
}

local function IsDebugModeEnabled()
    return HA.DevAddon and HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug
end

local function GetWorldRenderStateTotal(renderState)
    if not renderState then
        return 0
    end

    return #(renderState.vendorPins or {})
        + #(renderState.zoneBadges or {})
        + #(renderState.portalBadges or {})
        + #(renderState.continentBadges or {})
end

local function LogWorldMapPerf(mapID, renderState, force)
    if not IsDebugModeEnabled() then
        return
    end

    local now = (_G.GetTimePreciseSec and _G.GetTimePreciseSec()) or _G.GetTime()
    local previousLogTime = worldMapDebugStats.lastLogTime or 0
    if not force and (now - previousLogTime) < 1 then
        return
    end

    worldMapDebugStats.lastLogTime = now

    local providerStats = WorldMapProvider and WorldMapProvider.GetDebugStats and WorldMapProvider:GetDebugStats()
    local totalRequests = worldMapDebugStats.refreshRequests
    local totalSkips = worldMapDebugStats.skippedRequests
    local totalBuilds = worldMapDebugStats.builtStates
    local totalProviderCalls = providerStats and providerStats.refreshCalls or 0
    local totalProviderRenders = providerStats and providerStats.renderedPasses or 0
    local totalProviderNoops = providerStats and providerStats.skippedUnchanged or 0
    local totalProviderHidden = providerStats and providerStats.skippedHidden or 0
    local totalProviderMismatch = providerStats and providerStats.skippedMapMismatch or 0
    local deltaRequests = totalRequests - (worldMapDebugStats.lastLoggedRequests or 0)
    local deltaSkips = totalSkips - (worldMapDebugStats.lastLoggedSkips or 0)
    local deltaBuilds = totalBuilds - (worldMapDebugStats.lastLoggedBuilds or 0)
    local deltaProviderCalls = totalProviderCalls - (worldMapDebugStats.lastLoggedProviderCalls or 0)
    local deltaProviderRenders = totalProviderRenders - (worldMapDebugStats.lastLoggedProviderRenders or 0)
    local deltaProviderNoops = totalProviderNoops - (worldMapDebugStats.lastLoggedProviderNoops or 0)
    local deltaProviderHidden = totalProviderHidden - (worldMapDebugStats.lastLoggedProviderHidden or 0)
    local deltaProviderMismatch = totalProviderMismatch - (worldMapDebugStats.lastLoggedProviderMismatch or 0)
    local elapsed = previousLogTime > 0 and (now - previousLogTime) or 0
    local total = GetWorldRenderStateTotal(renderState)
    local vendorCount = renderState and #(renderState.vendorPins or {}) or 0
    local zoneBadgeCount = renderState and #(renderState.zoneBadges or {}) or 0
    local portalCount = renderState and #(renderState.portalBadges or {}) or 0
    local continentCount = renderState and #(renderState.continentBadges or {}) or 0
    local currentMemoryKB = nil
    local memoryDeltaKB = nil

    if _G.UpdateAddOnMemoryUsage and _G.GetAddOnMemoryUsage then
        _G.UpdateAddOnMemoryUsage()
        currentMemoryKB = _G.GetAddOnMemoryUsage("Homestead")
        if currentMemoryKB and worldMapDebugStats.lastLoggedMemoryKB then
            memoryDeltaKB = currentMemoryKB - worldMapDebugStats.lastLoggedMemoryKB
        end
    end

    HA.Addon:Debug(format(
        "WorldMapPerf: map=%s req=%d(+%d) skip=%d(+%d) builds=%d(+%d) providerCalls=%d(+%d) providerRenders=%d(+%d) providerNoops=%d(+%d) providerHidden=%d(+%d) providerMismatch=%d(+%d) mem=%.2fKB(%+.2fKB) dt=%.2fs entries=v%d/z%d/p%d/c%d total=%d dirty=%s force=%s",
        tostring(mapID),
        totalRequests,
        deltaRequests,
        totalSkips,
        deltaSkips,
        totalBuilds,
        deltaBuilds,
        totalProviderCalls,
        deltaProviderCalls,
        totalProviderRenders,
        deltaProviderRenders,
        totalProviderNoops,
        deltaProviderNoops,
        totalProviderHidden,
        deltaProviderHidden,
        totalProviderMismatch,
        deltaProviderMismatch,
        currentMemoryKB or -1,
        memoryDeltaKB or 0,
        elapsed,
        vendorCount,
        zoneBadgeCount,
        portalCount,
        continentCount,
        total,
        worldMapDirty and "yes" or "no",
        force and "yes" or "no"
    ))

    worldMapDebugStats.lastLoggedRequests = totalRequests
    worldMapDebugStats.lastLoggedSkips = totalSkips
    worldMapDebugStats.lastLoggedBuilds = totalBuilds
    worldMapDebugStats.lastLoggedProviderCalls = totalProviderCalls
    worldMapDebugStats.lastLoggedProviderRenders = totalProviderRenders
    worldMapDebugStats.lastLoggedProviderNoops = totalProviderNoops
    worldMapDebugStats.lastLoggedProviderHidden = totalProviderHidden
    worldMapDebugStats.lastLoggedProviderMismatch = totalProviderMismatch
    worldMapDebugStats.lastLoggedMemoryKB = currentMemoryKB
end

local function IsSilvermoonClusterDebugMap(mapID)
    return mapID == 2393 or mapID == 2395
end

local function GetMinimapCrossZoneMode()
    local profile = HA.Addon and HA.Addon.db and HA.Addon.db.profile
    local tracer = profile and profile.vendorTracer
    local mode = tracer and tracer.minimapCrossZoneMode
    if mode == "off" or mode == "on" or mode == "auto" then
        return mode
    end
    return "auto"
end

local function GetMinimapPinCap(mode)
    return MINIMAP_PIN_CAPS[mode] or MINIMAP_PIN_CAPS.auto
end

local function ShouldIncludeSiblingZones(playerMapID, mode)
    if mode == "off" then
        return false
    end
    if mode == "on" then
        return true
    end
    if IsIndoors() then
        return false
    end
    if not HA.VendorData then
        return false
    end

    -- Auto mode disables cross-zone pins in dense maps to avoid hitching.
    local vendorsInZone = HA.VendorData:GetVendorsInMap(playerMapID)
    local vendorCount = vendorsInZone and #vendorsInZone or 0
    return vendorCount < 16
end

local function StartMinimapWarmup(reason)
    minimapWarmupActive = true

    if minimapWarmupTimer then
        minimapWarmupTimer:Cancel()
    end

    minimapWarmupTimer = C_Timer.NewTimer(MINIMAP_WARMUP_DELAY, function()
        minimapWarmupTimer = nil
        minimapWarmupActive = false
        VendorMapPins:RequestMinimapRefresh("warmup_followup", 0.05)
    end)

    if reason and HA.DevAddon and HA.Addon.db.profile.debug then
        HA.Addon:Debug(format("Minimap warmup start: %s (%.2fs)", reason, MINIMAP_WARMUP_DELAY))
    end
end

local function StopMinimapWarmup()
    minimapWarmupActive = false
    if minimapWarmupTimer then
        minimapWarmupTimer:Cancel()
        minimapWarmupTimer = nil
    end
end

-- Item info event tracking for tooltip refresh (GET_ITEM_INFO_RECEIVED)
local itemInfoEventFrame = CreateFrame("Frame")
local activeTooltipData = nil      -- {kind="vendor", pin, vendor} while vendor tooltip is visible
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

local function IsActiveVendorTooltipVisible()
    if not activeTooltipData or activeTooltipData.kind ~= "vendor" or not pinTooltip then
        return false
    end

    if not pinTooltip:IsShown() then
        return false
    end

    return pinTooltip:GetOwner() == activeTooltipData.pin
end

itemInfoEventFrame:SetScript("OnEvent", function(self, event, itemID, success)
    if not success or not activeTooltipData then return end
    if not tooltipRebuildPending then
        tooltipRebuildPending = true
        C_Timer.After(0.05, function()
            tooltipRebuildPending = false
            if IsActiveVendorTooltipVisible() then
                VendorMapPins:ShowVendorTooltip(
                    activeTooltipData.pin,
                    activeTooltipData.vendor
                )
            end
        end)
    end
end)

-- Register/Unregister MERCHANT_CLOSED based on pin feature state.
local function RegisterMerchantClosedEvent()
    if not merchantEventFrame then
        merchantEventFrame = CreateFrame("Frame")
        merchantEventFrame:SetScript("OnEvent", function()
            -- Small delay to ensure scanned data is saved.
            C_Timer.After(0.3, function()
                VendorMapPins:InvalidateBadgeCache()
                if WorldMapFrame:IsShown() then
                    VendorMapPins:RefreshPins()
                end
                VendorMapPins:RequestMinimapRefresh("merchant_closed", 0.05)
            end)
        end)
    end

    if not merchantEventFrame:IsEventRegistered("MERCHANT_CLOSED") then
        merchantEventFrame:RegisterEvent("MERCHANT_CLOSED")
    end
end

local function UnregisterMerchantClosedEvent()
    if merchantEventFrame and merchantEventFrame:IsEventRegistered("MERCHANT_CLOSED") then
        merchantEventFrame:UnregisterEvent("MERCHANT_CLOSED")
    end
end

-- Register/Unregister zone-change events used by minimap pin refresh.
local function RegisterZoneChangeEvents()
    if not zoneEventFrame then
        zoneEventFrame = CreateFrame("Frame")
        zoneEventFrame:SetScript("OnEvent", function()
            -- Skip refresh if player hasn't actually changed zones.
            local currentMapID = C_Map.GetBestMapForUnit("player")
            if currentMapID == lastMinimapMapID then return end
            lastMinimapMapID = currentMapID

            VendorMapPins:RequestMinimapRefresh("zone_changed", MINIMAP_REFRESH_ZONE_DELAY)
        end)
    end

    if not zoneEventFrame:IsEventRegistered("ZONE_CHANGED") then
        zoneEventFrame:RegisterEvent("ZONE_CHANGED")
        zoneEventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
        zoneEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        zoneEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        zoneEventFrame:RegisterEvent("NEW_WMO_CHUNK")
    end
end

local function UnregisterZoneChangeEvents()
    if zoneEventFrame and zoneEventFrame:IsEventRegistered("ZONE_CHANGED") then
        zoneEventFrame:UnregisterEvent("ZONE_CHANGED")
        zoneEventFrame:UnregisterEvent("ZONE_CHANGED_INDOORS")
        zoneEventFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
        zoneEventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        zoneEventFrame:UnregisterEvent("NEW_WMO_CHUNK")
    end

    if minimapRefreshTimer then
        minimapRefreshTimer:Cancel()
        minimapRefreshTimer = nil
    end
end

-- Reconcile event/ticker subscriptions with current feature state.
local function RefreshRuntimeSubscriptions()
    if not isInitialized then return end

    if pinsEnabled or minimapPinsEnabled then
        RegisterMerchantClosedEvent()
    else
        UnregisterMerchantClosedEvent()
    end

    if minimapPinsEnabled then
        RegisterZoneChangeEvents()
    else
        UnregisterZoneChangeEvents()
    end
end

-------------------------------------------------------------------------------
-- Pin Color/Size Delegates (forwarded to PinFrameFactory)
-------------------------------------------------------------------------------

function VendorMapPins:GetPinColor()
    return HA.PinFrameFactory:GetPinColor()
end

function VendorMapPins:GetPinIconSize()
    return HA.PinFrameFactory:GetPinIconSize()
end

function VendorMapPins:GetMinimapIconSize()
    return HA.PinFrameFactory:GetMinimapIconSize()
end

function VendorMapPins:IsCustomPinColor()
    return HA.PinFrameFactory:IsCustomPinColor()
end

function VendorMapPins:GetPinColorPreviewHex()
    return HA.PinFrameFactory:GetPinColorPreviewHex()
end

function VendorMapPins:RefreshAllPinColors()
    worldMapDirty = true
    lastRenderedWorldMapID = nil

    if WorldMapProvider and WorldMapProvider.FlushPools then
        WorldMapProvider:FlushPools()
    else
        self:ClearAllPins()
    end

    if MinimapOverlay and MinimapOverlay.FlushPools then
        MinimapOverlay:FlushPools()
    else
        self:ClearMinimapPins()
    end

    self:RefreshPins(true)
    self:RefreshMinimapPins()
end

-- Called by PinFrameFactory OnLeave scripts to clear tooltip tracking state
function VendorMapPins:OnPinLeave()
    activeTooltipData = nil
    itemInfoEventFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    if pinTooltip then
        pinTooltip:Hide()
    end
end

function VendorMapPins:HidePinTooltip()
    self:OnPinLeave()
end

-------------------------------------------------------------------------------
-- Filter/Faction Delegates (forwarded to VendorFilter)
-------------------------------------------------------------------------------

function VendorMapPins:CanAccessVendor(vendor)
    return CanAccessVendor(vendor)
end

function VendorMapPins:IsOppositeFaction(vendor)
    return IsOppositeFaction(vendor)
end

-------------------------------------------------------------------------------
-- Badge/Collection Delegates (forwarded to BadgeCalculation)
-------------------------------------------------------------------------------

-- Helper function to check if a specific item is owned (used by tooltips)
local function IsItemOwned(itemID)
    if not itemID then return false end
    if HA.CatalogStore then
        return HA.CatalogStore:IsOwnedFresh(itemID)
    end
    return false
end

function VendorMapPins:VendorHasUncollectedItems(vendor)
    return BC:VendorHasUncollectedItems(vendor)
end

function VendorMapPins:GetVendorCollectionCounts(vendor)
    return BC:GetVendorCollectionCounts(vendor)
end

function VendorMapPins:GetVendorStats(vendor, sourceFilter)
    return BC:GetVendorStats(vendor, sourceFilter)
end

function VendorMapPins:InvalidateBadgeCache()
    BC:InvalidateBadgeCache()
    lastRenderedWorldMapID = nil
    worldMapDirty = true
    lastMinimapMapID = nil
end

function VendorMapPins:InvalidateAllCaches()
    BC:InvalidateAllCaches()
    lastRenderedWorldMapID = nil
    worldMapDirty = true
    lastMinimapMapID = nil
end

function VendorMapPins:GetZoneVendorCounts(continentMapID, sourceFilter)
    return BC:GetZoneVendorCounts(continentMapID, sourceFilter or GetActiveSourceFilter())
end

function VendorMapPins:GetContinentVendorCounts(sourceFilter)
    return BC:GetContinentVendorCounts(sourceFilter or GetActiveSourceFilter())
end

function VendorMapPins:GetContinentCenterOnWorldMap(continentMapID)
    return MPP:GetContinentCenterOnWorldMap(continentMapID)
end

function VendorMapPins:GetZoneCenterOnMap(zoneMapID, parentMapID)
    return MPP:GetZoneCenterOnMap(zoneMapID, parentMapID)
end

function VendorMapPins:SetWaypointToVendor(vendor)
    if not vendor then return end
    if HA.Waypoints then
        HA.Waypoints:SetToVendor(vendor)
    elseif HA.VendorTracer then
        HA.VendorTracer:NavigateToVendor(vendor.npcID)
    end
end

-------------------------------------------------------------------------------
-- Tooltips
-------------------------------------------------------------------------------

function VendorMapPins:ShowVendorTooltip(pin, vendor)
    if not vendor then return end

    -- Track active tooltip for GET_ITEM_INFO_RECEIVED refresh
    activeTooltipData = { kind = "vendor", pin = pin, vendor = vendor }
    itemInfoEventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

    local isOpposite = self:IsOppositeFaction(vendor)

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

    -- Add static items
    -- New format: items can be plain integers OR tables with cost data
    if vendor.items then
        for _, item in ipairs(vendor.items) do
            -- Handle both formats: plain number or table with cost
            local itemID = HA.VendorData:GetItemID(item)
            if itemID and not itemsSeen[itemID] then
                itemsSeen[itemID] = true
                tinsert(allItems, {itemID = itemID})
            end
        end
    end

    -- Add scanned items (new format: items = {...}, old format: decor = {...})
    if vendor.npcID and HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
        local scannedData = HA.Addon.db.global.scannedVendors[vendor.npcID]
        local scannedItems = scannedData and (scannedData.items)
        if scannedItems then
            for _, item in ipairs(scannedItems) do
                if item.itemID and not itemsSeen[item.itemID] then
                    itemsSeen[item.itemID] = true
                    tinsert(allItems, item)
                end
            end
        end
    end

    if #allItems > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("Items Sold:", 1, 1, 0)

        local SM = HA.SourceManager

        for _, item in ipairs(allItems) do
            local itemName = item.name or (item.itemID and GetItemInfo(item.itemID)) or "Unknown Item"

            if item.itemID and IsItemOwned(item.itemID) then
                -- Collected: green
                tooltip:AddLine("  " .. itemName, 0, 1, 0)
            elseif item.itemID and SM and SM.GetVendorItemAvailabilityState then
                local state = SM:GetVendorItemAvailabilityState(item.itemID, vendor.npcID)
                if state == "locked" then
                    -- Locked: red
                    tooltip:AddLine("  " .. itemName, 1, 0.25, 0.25)
                else
                    -- Available: white
                    tooltip:AddLine("  " .. itemName, 1, 1, 1)
                end
            else
                -- Unknown state: white
                tooltip:AddLine("  " .. itemName, 1, 1, 1)
            end
        end

    else
        -- No item data available
        tooltip:AddLine(" ")
        tooltip:AddLine("Item data unknown - visit vendor to scan", 1, 0.82, 0)
    end

    -- Purchasability summary (only when we have item data)
    local stats = self:GetVendorStats(vendor, GetActiveSourceFilter())
    if stats.total > 0 then
        tooltip:AddLine(" ")
        BC.AddSummaryLine(tooltip, stats.collected, stats.total, stats.locked, stats.unverified)

        if isOpposite and not self:CanAccessVendor(vendor) then
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

function VendorMapPins:ShowZoneBadgeTooltip(pin, zoneInfo)
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

function VendorMapPins:ShowPortalTooltip(pin, vendor)
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

function VendorMapPins:ShowMinimapTooltip(pin, vendor, isOppositeFaction, elevation)
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

-------------------------------------------------------------------------------
-- Pin Management
-------------------------------------------------------------------------------

function VendorMapPins:HighlightVendor(npcID)
    self:ClearHighlight()

    local targetNPCID = tonumber(npcID)
    if not targetNPCID then return end

    local activeFrames = WorldMapProvider and WorldMapProvider.GetActiveVendorFrames
        and WorldMapProvider:GetActiveVendorFrames() or {}

    for _, frame in ipairs(activeFrames) do
        local vendor = frame and frame.vendor
        if frame and frame:IsShown() and vendor and vendor.npcID == targetNPCID then
            highlightedPinFrame = frame
            highlightOriginalScale = frame:GetScale() or 1
            highlightOriginalFrameLevel = frame:GetFrameLevel() or 1

            frame:SetScale(highlightOriginalScale * 1.4)
            frame:SetFrameLevel(highlightOriginalFrameLevel + 10)

            if not highlightOverlay then
                highlightOverlay = frame:CreateTexture(nil, "OVERLAY")
                highlightOverlay:SetAtlas("auctionhouse-itemicon-border-artifact", false)
                highlightOverlay:SetBlendMode("ADD")
            end

            highlightOverlay:SetParent(frame)
            highlightOverlay:ClearAllPoints()
            highlightOverlay:SetPoint("CENTER", frame, "CENTER", 0, 0)
            highlightOverlay:SetSize(frame:GetWidth() + 8, frame:GetHeight() + 8)
            highlightOverlay:SetVertexColor(1, 0.85, 0.2, 0.95)
            highlightOverlay:Show()
            return
        end
    end
end

function VendorMapPins:ClearHighlight()
    if highlightOverlay then
        highlightOverlay:Hide()
    end

    if highlightedPinFrame then
        highlightedPinFrame:SetScale(highlightOriginalScale or 1)
        if highlightOriginalFrameLevel then
            highlightedPinFrame:SetFrameLevel(math.max(1, highlightOriginalFrameLevel))
        end
    end

    highlightedPinFrame = nil
    highlightOriginalScale = nil
    highlightOriginalFrameLevel = nil
end

function VendorMapPins:ClearAllPins()
    self:ClearHighlight()
    self:OnPinLeave()
    lastRenderedWorldMapID = nil
    worldMapDirty = true
    if worldMapRefreshTimer then
        worldMapRefreshTimer:Cancel()
        worldMapRefreshTimer = nil
    end

    if WorldMapProvider then
        WorldMapProvider:RemoveAllData()
    else
        MPP.ClearWorldMapPins("HomesteadVendors")
    end
end

function VendorMapPins:ClearMinimapPins()
    self:OnPinLeave()
    MPP.ClearMinimapPins("HomesteadMinimapVendors")
    if MinimapOverlay then
        MinimapOverlay:Clear()
    end
end

function VendorMapPins:RequestWorldMapRefresh(reason, delay, forceImmediate)
    if not isInitialized then return end
    if not pinsEnabled then return end

    worldMapDirty = true

    if worldMapRefreshTimer then
        if forceImmediate then
            worldMapRefreshTimer:Cancel()
            worldMapRefreshTimer = nil
        else
            return
        end
    end

    if forceImmediate then
        self:RefreshPins(true)
        return
    end

    local refreshDelay = delay
    if refreshDelay == nil then
        refreshDelay = WORLDMAP_REFRESH_DEFAULT_DELAY
    end

    worldMapRefreshTimer = C_Timer.NewTimer(refreshDelay, function()
        worldMapRefreshTimer = nil
        if pinsEnabled then
            self:RefreshPins(true)
        end
    end)

    if IsDebugModeEnabled() and reason then
        HA.Addon:Debug(format("Coalesced world map refresh: %s (%.2fs)", reason, refreshDelay))
    end
end

function VendorMapPins:RequestMinimapRefresh(reason, delay, forceImmediate)
    if not isInitialized then return end
    if not minimapPinsEnabled then return end

    if minimapRefreshTimer then
        if forceImmediate then
            minimapRefreshTimer:Cancel()
            minimapRefreshTimer = nil
        else
            return
        end
    end

    if forceImmediate then
        self:RefreshMinimapPins()
        return
    end

    local refreshDelay = delay
    if refreshDelay == nil then
        refreshDelay = MINIMAP_REFRESH_DEFAULT_DELAY
    end

    minimapRefreshTimer = C_Timer.NewTimer(refreshDelay, function()
        minimapRefreshTimer = nil
        if minimapPinsEnabled then
            self:RefreshMinimapPins()
        end
    end)

    if reason and HA.DevAddon and HA.Addon.db.profile.debug then
        HA.Addon:Debug(format("Coalesced minimap refresh: %s (%.2fs)", reason, refreshDelay))
    end
end

function VendorMapPins:RefreshMinimapPins()
    if not isInitialized then return end
    if not minimapPinsEnabled then
        self:ClearMinimapPins()
        return
    end

    self:ClearMinimapPins()

    if not HA.VendorData then return end

    -- Get the player's current zone
    local playerMapID = C_Map.GetBestMapForUnit("player")
    if not playerMapID then return end

    local showElevationArrows = HA.Addon.db.profile.vendorTracer.showElevationArrows ~= false
    local crossZoneMode = GetMinimapCrossZoneMode()
    local pinCap = GetMinimapPinCap(crossZoneMode)
    local includeSiblingZones = ShouldIncludeSiblingZones(playerMapID, crossZoneMode)
    local isWarmupRefresh = minimapWarmupActive
    if isWarmupRefresh then
        includeSiblingZones = false
        if pinCap > MINIMAP_WARMUP_PIN_CAP then
            pinCap = MINIMAP_WARMUP_PIN_CAP
        end
    end

    -- Collect mapIDs to check: current zone + parent zones + sibling zones in same continent
    -- This enables HandyNotes-style "nearby vendor" pins
    local mapsToCheck = {}
    local mapsToCheckSet = {}  -- For deduplication

    -- Always include current map
    mapsToCheck[#mapsToCheck + 1] = playerMapID
    mapsToCheckSet[playerMapID] = true

    -- Add parent map (covers subzone → zone case, e.g., cave → main zone)
    local mapInfo = C_Map.GetMapInfo(playerMapID)
    if mapInfo and mapInfo.parentMapID and mapInfo.parentMapID > 0 then
        if not mapsToCheckSet[mapInfo.parentMapID] then
            mapsToCheck[#mapsToCheck + 1] = mapInfo.parentMapID
            mapsToCheckSet[mapInfo.parentMapID] = true
        end
    end

    -- Always include explicit vertical siblings even when generic cross-zone
    -- discovery is disabled; elevation-pair behavior should not depend on the
    -- broader sibling-zone policy.
    local verticalSiblings = Constants.VerticalSiblings[playerMapID]
    if verticalSiblings then
        for siblingMapID in pairs(verticalSiblings) do
            if not mapsToCheckSet[siblingMapID] then
                mapsToCheck[#mapsToCheck + 1] = siblingMapID
                mapsToCheckSet[siblingMapID] = true
            end
        end
    end

    local continentID = GetContinentForZone(playerMapID)
    if includeSiblingZones then
        if continentID and not MPP.minimapExcludedContinents[continentID] then
            local siblingZones = MPP.continentToZones[continentID]
            if siblingZones then
                for _, zoneMapID in ipairs(siblingZones) do
                    if not mapsToCheckSet[zoneMapID] then
                        mapsToCheck[#mapsToCheck + 1] = zoneMapID
                        mapsToCheckSet[zoneMapID] = true
                    end
                end
            end
        end
    end

    local showOpposite = ShouldShowOppositeFaction()
    local addedVendors = {}  -- Prevent duplicate pins for same vendor
    local pendingPins = {}   -- Collected pins for overlay placement
    local addedCount = 0
    local capReached = false

    for _, mapID in ipairs(mapsToCheck) do
        if capReached then break end

        local vendors = HA.VendorData:GetVendorsInMap(mapID)
        if vendors then
            for _, vendor in ipairs(vendors) do
                if addedCount >= pinCap then
                    capReached = true
                    break
                end

                -- Use npcID for deduplication (vendor tables may be different objects)
                if vendor.npcID and not addedVendors[vendor.npcID] then
                    local shouldSkipVendor = ShouldHideVendor(vendor)

                    -- Skip static/scanned map mismatches to avoid misplaced minimap pins.
                    -- Bypass for endeavor vendors: scan data may be stale from a previous
                    -- neighborhood rotation. GetBestVendorCoordinates handles the fallback.
                    if not shouldSkipVendor and not vendor.endeavor
                            and HA.Addon and HA.Addon.db
                            and HA.Addon.db.global.scannedVendors then
                        local scannedData = HA.Addon.db.global.scannedVendors[vendor.npcID]
                        if scannedData and scannedData.mapID and not mapsToCheckSet[scannedData.mapID] then
                            shouldSkipVendor = true
                        end
                    end

                    if shouldSkipVendor then
                        addedVendors[vendor.npcID] = true
                    else
                        -- Get best coordinates (scanned preferred over static)
                        local coords, vendorMapID = GetBestVendorCoordinates(vendor)

                        -- Only show pins for vendors with valid coordinates
                        if coords and vendorMapID then
                            local canAccess = self:CanAccessVendor(vendor)
                            local isOpposite = self:IsOppositeFaction(vendor)
                            local isPortalOnlyMinimapVendor = vendor.portal and playerMapID ~= vendor.mapID

                            -- Show vendor only when allowed by faction-access rules.
                            if not isPortalOnlyMinimapVendor
                                    and (canAccess or (isOpposite and showOpposite)) then
                                local elevation = Constants.GetElevationDirection(playerMapID, vendorMapID)
                                local relationship
                                if playerMapID == vendorMapID then
                                    relationship = "same_map"
                                elseif elevation then
                                    relationship = "vertical_sibling"
                                else
                                    relationship = "parent_child"
                                end

                                local worldX, worldY, instanceID = MPP.GetNativeWorldCoordinates(
                                    vendorMapID,
                                    coords.x,
                                    coords.y
                                )

                                if worldX and worldY then
                                    addedVendors[vendor.npcID] = true
                                    addedCount = addedCount + 1
                                    pendingPins[#pendingPins + 1] = {
                                        vendor = vendor,
                                        mapID = vendorMapID,
                                        instanceID = instanceID,
                                        worldX = worldX,
                                        worldY = worldY,
                                        relationship = relationship,
                                        floatOnEdge = elevation and true or false,
                                        elevation = showElevationArrows and elevation or nil,
                                        isOppositeFaction = isOpposite,
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if MinimapOverlay then
        MinimapOverlay:SetPins(pendingPins)
    end

    -- Debug output (verbose, dev only)
    if HA.DevAddon and HA.Addon.db.profile.debug then
        HA.Addon:Debug("RefreshMinimapPins: playerMapID=" .. playerMapID ..
            ", continentID=" .. (continentID or "nil") ..
            ", crossZone=" .. crossZoneMode ..
            ", warmup=" .. (isWarmupRefresh and "yes" or "no") ..
            ", includeSiblings=" .. (includeSiblingZones and "yes" or "no") ..
            ", mapsChecked=" .. #mapsToCheck ..
            ", vendorsAdded=" .. addedCount ..
            ", pinCap=" .. pinCap ..
            ", capReached=" .. (capReached and "yes" or "no"))
    end
end

local function DebugWorldMapProjectionSkip(kind, sourceMapID, viewMapID, reason)
    if not (HA.DevAddon and HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug) then
        return
    end

    HA.Addon:Debug(format(
        "World map projection skipped: kind=%s source=%s view=%s reason=%s",
        kind or "?",
        tostring(sourceMapID),
        tostring(viewMapID),
        tostring(reason)
    ))
end

local function BuildBadgeData(mapID, zoneName, zoneData)
    return {
        mapID = mapID,
        zoneName = zoneName,
        vendorCount = zoneData.vendorCount,
        uncollectedCount = zoneData.uncollectedCount,
        unknownCount = zoneData.unknownCount,
        oppositeFactionCount = zoneData.oppositeFactionCount,
        dominantFaction = zoneData.dominantFaction,
        note = MPP.zoneNotes[mapID],
        collectedItems = zoneData.collectedItems,
        totalItems = zoneData.totalItems,
        lockedItems = zoneData.lockedItems,
        unverifiedItems = zoneData.unverifiedItems,
    }
end

function VendorMapPins:BuildWorldMapRenderState(mapID)
    worldMapDebugStats.builtStates = worldMapDebugStats.builtStates + 1

    local mapInfo = C_Map.GetMapInfo(mapID)
    local renderState = {
        mapID = mapID,
        mapType = mapInfo and mapInfo.mapType or nil,
        vendorPins = {},
        sourcePins = {},      -- HS-018: non-vendor source pins (drop, etc.)
        zoneBadges = {},
        portalBadges = {},
        continentBadges = {},
    }

    if not mapInfo then
        return renderState
    end

    if mapInfo.mapType == Enum.UIMapType.World then
        self:ShowContinentBadges(renderState)
    elseif mapInfo.mapType == Enum.UIMapType.Continent then
        self:ShowZoneBadges(mapID, renderState)
    else
        self:CollectSourcePins(mapID, renderState)
    end

    return renderState
end

-------------------------------------------------------------------------------
-- HS-018: Pin Source Provider Registry
--
-- Registry of per-source-type pin collectors. Each entry is a table:
--   { collect = function(self, mapID, validMapIDs, filter, renderState) end }
-- Only the vendor slot is populated in HS-018 commit 2. Drop is filled in by
-- commit 3. Future tickets plug in profession (HS-075), quest, achievement,
-- shop without modifying CollectSourcePins.
--
-- Filter semantics:
--   "all"                 -> every populated provider runs
--   <canonical sourceType>-> only the matching provider runs (if populated)
--
-- Portal badges are intrinsically vendor-context (they mark transports to
-- vendor zones). They render only when the filter resolves to {vendor, all}.
-------------------------------------------------------------------------------

VendorMapPins.pinSourceProviders = {
    vendor      = nil,  -- assigned below once CollectVendorPinRecords is defined
    drop        = nil,  -- HS-018 commit 3
    event       = nil,  -- EventVendors flow through vendor pipeline
    profession  = nil,  -- HS-075
    quest       = nil,  -- registry slot reserved
    achievement = nil,  -- registry slot reserved
    shop        = nil,  -- registry slot reserved
}

local function ProviderMatchesFilter(sourceType, filter)
    if filter == "all" or filter == nil then return true end
    return sourceType == filter
end

function VendorMapPins:CollectSourcePins(mapID, renderState)
    local filter = GetActiveSourceFilter()

    -- Build set of valid mapIDs: current map + child/sub-zone maps. Shared
    -- across providers so each provider doesn't re-walk the map tree.
    local validMapIDs = { [mapID] = true }
    local childMaps = C_Map.GetMapChildrenInfo(mapID)
    if childMaps then
        for _, childInfo in ipairs(childMaps) do
            validMapIDs[childInfo.mapID] = true
        end
    end

    for sourceType, provider in pairs(self.pinSourceProviders) do
        if provider and provider.collect and ProviderMatchesFilter(sourceType, filter) then
            provider.collect(self, mapID, validMapIDs, filter, renderState)
        end
    end

    -- Portal badges are vendor-context navigation aids; only emit under
    -- vendor/all filters (Decision 2).
    if filter == "all" or filter == "vendor" then
        self:EmitPortalBadges(mapID, renderState)
    end
end

function VendorMapPins:RefreshPins(force)
    if not isInitialized then return end
    worldMapDebugStats.refreshRequests = worldMapDebugStats.refreshRequests + 1

    if not pinsEnabled then
        self:ClearAllPins()
        return
    end

    if not HA.VendorData then return end

    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return end
    if not WorldMapProvider then return end

    if not force and not worldMapDirty and mapID == lastRenderedWorldMapID then
        worldMapDebugStats.skippedRequests = worldMapDebugStats.skippedRequests + 1
        LogWorldMapPerf(mapID, nil, false)
        return
    end

    WorldMapProvider:EnsureRegistered()

    local renderState = self:BuildWorldMapRenderState(mapID)
    WorldMapProvider:SetRenderState(renderState)
    WorldMapProvider:Refresh()
    lastRenderedWorldMapID = mapID
    worldMapDirty = false
    LogWorldMapPerf(mapID, renderState, force)
end

-------------------------------------------------------------------------------
-- HS-018: Vendor pin provider
--
-- Collects vendor pins for the given mapID into renderState.vendorPins.
-- Extracted from the previous ShowVendorPins so it can be plugged into the
-- pinSourceProviders registry. Portal badges are emitted separately by
-- EmitPortalBadges (called from CollectSourcePins under vendor/all filters).
-------------------------------------------------------------------------------

local function CollectVendorPinRecords(self, mapID, validMapIDs, _filter, renderState)
    local showOpposite = ShouldShowOppositeFaction()
    local addedVendors = {}  -- Track by npcID to avoid duplicates
    local shouldLogSilvermoonDebug = IsDebugModeEnabled() and IsSilvermoonClusterDebugMap(mapID)
    local staticVendorCount = 0
    local staticProcessedCount = 0
    local staticSkippedCount = 0
    local scannedFallbackCount = 0
    local scannedFallbackProcessedCount = 0
    local startVendorPinCount = #renderState.vendorPins
    local validMapIDCount = 0
    for _ in pairs(validMapIDs) do validMapIDCount = validMapIDCount + 1 end

    -- Helper function to process a vendor
    local function ProcessVendor(vendor)
        if not vendor or not vendor.npcID then return end
        if addedVendors[vendor.npcID] then return end

        -- Endeavor vendors are visible only when their theme is active.
        if HA.EndeavorsData and HA.EndeavorsData.IsVendorActive
                and not HA.EndeavorsData:IsVendorActive(vendor) then
            addedVendors[vendor.npcID] = true
            return
        end

        -- Skip unreleased or no-decor vendors
        if ShouldHideVendor(vendor) then
            -- Mark as processed to avoid re-checking in scanned vendors loop
            addedVendors[vendor.npcID] = true
            return
        end

        -- Get best coordinates (scanned preferred over static)
        local coords, vendorMapID = GetBestVendorCoordinates(vendor)

        -- Use the vendor's STATIC mapID for inclusion check — the scanned mapID
        -- reflects where the player was, not where the vendor belongs. Scanned
        -- coords are still used for position precision via vendorMapID.
        local staticMapID = vendor.mapID
        if coords and vendorMapID and (validMapIDs[vendorMapID] or validMapIDs[staticMapID]) then
            local canAccess = self:CanAccessVendor(vendor)
            local isOpposite = self:IsOppositeFaction(vendor)

            -- Show vendor if accessible OR if opposite faction and setting enabled
            if canAccess or (isOpposite and showOpposite) then
                -- Try projection with the coordinate source mapID first.
                -- If that fails and the static mapID differs, retry with static.
                local ok, projectedX, projectedY, reason = MPP:ProjectVendorPinToZoneView(
                    mapID,
                    vendorMapID,
                    coords.x,
                    coords.y
                )
                if not ok and staticMapID and staticMapID ~= vendorMapID then
                    local sx, sy = GetVendorXY(vendor)
                    if sx and sy then
                        ok, projectedX, projectedY, reason = MPP:ProjectVendorPinToZoneView(
                            mapID, staticMapID, sx, sy)
                    end
                end
                addedVendors[vendor.npcID] = true
                if ok then
                    renderState.vendorPins[#renderState.vendorPins + 1] = {
                        vendor = vendor,
                        mapID = vendorMapID,
                        x = projectedX,
                        y = projectedY,
                        reason = reason,
                        isOppositeFaction = isOpposite,
                        sourceType = "vendor",
                    }
                else
                    DebugWorldMapProjectionSkip("vendor", vendorMapID, mapID, reason)
                end
            end
        end
    end

    -- First, process vendors from static database for this map and child maps
    for queryMapID in pairs(validMapIDs) do
        local staticVendors = HA.VendorData:GetVendorsInMap(queryMapID)
        if staticVendors then
            staticVendorCount = staticVendorCount + #staticVendors
            for _, vendor in ipairs(staticVendors) do
                local shouldSkip = false
                local skipReason = nil

                -- Check 1: Skip unreleased or no-decor vendors
                if ShouldHideVendor(vendor) then
                    shouldSkip = true
                    skipReason = vendor.unreleased and "unreleased" or "no decor"
                end

                -- Check 2 disabled: scanned mapID filter was skipping vendors whose
                -- scanned location differs from static. The projection handles
                -- visibility — if the vendor can't project onto this view, it
                -- won't render. No pre-filter needed.

                if shouldSkip then
                    staticSkippedCount = staticSkippedCount + 1
                    -- Mark as processed to prevent re-check in scanned vendors loop
                    addedVendors[vendor.npcID] = true
                    if HA.DevAddon and HA.Addon.db.profile.debug then
                        HA.Addon:Debug(format("Skipping static vendor %s (%d) on map %d - %s",
                            vendor.name or "Unknown", vendor.npcID, queryMapID, skipReason or "unknown"))
                    end
                else
                    staticProcessedCount = staticProcessedCount + 1
                    ProcessVendor(vendor)
                end
            end
        end
    end

    -- Second, check ALL scanned vendors - they may have been scanned on a different map
    -- than their static entry (e.g., Quackenbush: static=Stormwind, scanned=BrawlersGuild)
    if HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
        for npcID, scannedData in pairs(HA.Addon.db.global.scannedVendors) do
            -- Only process if this scanned vendor's mapID matches the current map or a child map
            -- AND we haven't already added this vendor from static data
            if validMapIDs[scannedData.mapID] and not addedVendors[npcID] then
                scannedFallbackCount = scannedFallbackCount + 1
                -- Try to get full vendor info from static data, fall back to scanned data
                local vendor = HA.VendorData:GetVendor(npcID)
                if vendor then
                    scannedFallbackProcessedCount = scannedFallbackProcessedCount + 1
                    ProcessVendor(vendor)
                else
                    -- Vendor not in static database - create a temporary vendor object from scanned data
                    local tempVendor = {
                        npcID = npcID,
                        name = scannedData.name or "Unknown Vendor",
                        mapID = scannedData.mapID,
                        coords = scannedData.coords,
                        faction = "Neutral",  -- Default, unknown from scan
                    }
                    scannedFallbackProcessedCount = scannedFallbackProcessedCount + 1
                    ProcessVendor(tempVendor)
                end
            end
        end
    end

    if shouldLogSilvermoonDebug then
        local renderedVendorPins = #renderState.vendorPins - startVendorPinCount
        HA.Addon:Debug(format(
            "SilvermoonMapDebug: map=%d validMaps=%d staticSeen=%d staticProcessed=%d staticSkipped=%d scannedFallbackSeen=%d scannedFallbackProcessed=%d renderedVendors=%d",
            mapID,
            validMapIDCount,
            staticVendorCount,
            staticProcessedCount,
            staticSkippedCount,
            scannedFallbackCount,
            scannedFallbackProcessedCount,
            renderedVendorPins
        ))
    end
end

VendorMapPins.pinSourceProviders.vendor = { collect = CollectVendorPinRecords }

-------------------------------------------------------------------------------
-- HS-018: Drop pin provider
--
-- Walks HA.DropSources and emits pins for drop records whose location data
-- passes Decision 7 hygiene:
--   1. Skip records with no mapID (zone-only data).
--   2. Skip records with coords = {0, 0} (explicit placeholder).
--   3. Emit {0.5, 0.5} as approximate-center pins as-is.
--   4. Clamp x/y to [0, 1] defensively; reject NaN.
--   5. No log spam on skipped records.
--
-- Records carry sourceType = "drop" so PinFrameFactory:CreateSourcePinFrame
-- knows which factory branch to take.
-------------------------------------------------------------------------------

local function IsFiniteNumber(n)
    return type(n) == "number" and n == n  -- NaN != NaN
end

local function ClampUnit(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function CollectDropPinRecords(self, mapID, validMapIDs, _filter, renderState)
    local drops = HA.DropSources
    if not drops then return end

    for itemID, drop in pairs(drops) do
        local dropMapID = drop.mapID
        if dropMapID and validMapIDs[dropMapID] then
            local coords = drop.coords
            if coords then
                local cx, cy = coords.x, coords.y
                -- Hygiene: reject NaN; skip exact-zero placeholders.
                if IsFiniteNumber(cx) and IsFiniteNumber(cy)
                        and not (cx == 0 and cy == 0) then
                    local clampedX, clampedY = ClampUnit(cx), ClampUnit(cy)
                    local ok, projectedX, projectedY, reason = MPP:ProjectVendorPinToZoneView(
                        mapID, dropMapID, clampedX, clampedY)
                    if ok then
                        renderState.sourcePins[#renderState.sourcePins + 1] = {
                            sourceType = "drop",
                            itemID = itemID,
                            drop = drop,
                            mapID = dropMapID,
                            x = projectedX,
                            y = projectedY,
                            reason = reason,
                        }
                    else
                        DebugWorldMapProjectionSkip("drop", dropMapID, mapID, reason)
                    end
                end
            end
        end
    end
end

VendorMapPins.pinSourceProviders.drop = { collect = CollectDropPinRecords }

-------------------------------------------------------------------------------
-- HS-079: Profession pin provider
--
-- Pattern mirrors the vendor pin collector at lines 1346-1359:
--   for queryMapID in pairs(validMapIDs) do
--       <get trainers at queryMapID via ByMapID index>
--       for each trainer: project, look up items, push pin record
--
-- One pin per (mapID, x, y, profession, skillTier) tuple. The aggregated
-- itemIDs list is attached to the record for the tooltip to read.
--
-- Hygiene mirrors the drop collector (Decision 7 in HS-018):
--   1. Skip records with NaN / out-of-range coords (defensive).
--   2. Reject records whose projection across the parent chain fails.
--   3. Skip trainers whose (profession, skillTier) has zero items in
--      ProfessionSources — emits no pin (no items to advertise).
-------------------------------------------------------------------------------

-- File-local lazy reverse index: "profession|skillTier" -> { itemID, ... }
-- Mirrors the VendorDatabase.ByItemID reverse-index precedent at line 3060.
-- Built once on first call, cached. ProfessionSources is static, no invalidation needed.
local itemsByProfessionTier  -- nil until first call

local function GetItemsForProfessionTier(profession, skillTier)
    if not itemsByProfessionTier then
        itemsByProfessionTier = {}
        if HA.ProfessionSources then
            for itemID, profSource in pairs(HA.ProfessionSources) do
                local p = profSource.profession
                local t = profSource.skillTier
                if p and t then
                    local key = p .. "|" .. t
                    if not itemsByProfessionTier[key] then
                        itemsByProfessionTier[key] = {}
                    end
                    local list = itemsByProfessionTier[key]
                    list[#list + 1] = itemID
                end
            end
        end
    end
    return itemsByProfessionTier[profession .. "|" .. skillTier]
end

local function CollectProfessionPinRecords(self, mapID, validMapIDs, _filter, renderState)
    local trainers = HA.ProfessionTrainerLocations
    if not trainers or not trainers.ByMapID then return end

    -- Iterate by validMapIDs first (matches vendor collector at line 1346).
    for queryMapID in pairs(validMapIDs) do
        local trainersAtMap = trainers.ByMapID[queryMapID]
        if trainersAtMap then
            for _, entry in ipairs(trainersAtMap) do
                local cx, cy = entry.x, entry.y
                -- Coord hygiene: NaN guard + range clamp check.
                if type(cx) == "number" and type(cy) == "number"
                        and cx == cx and cy == cy
                        and cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then
                    local ok, projectedX, projectedY, reason =
                        MPP:ProjectVendorPinToZoneView(mapID, queryMapID, cx, cy)
                    if ok then
                        local itemIDs = GetItemsForProfessionTier(entry.profession, entry.skillTier)
                        if itemIDs and #itemIDs > 0 then
                            renderState.sourcePins[#renderState.sourcePins + 1] = {
                                sourceType = "profession",
                                profession = entry.profession,
                                skillTier = entry.skillTier,
                                mapID = queryMapID,
                                x = projectedX,
                                y = projectedY,
                                reason = reason,
                                itemIDs = itemIDs,
                                faction = entry.faction,  -- nil-safe; reserved for Classic
                            }
                        end
                    else
                        DebugWorldMapProjectionSkip("profession", queryMapID, mapID, reason)
                    end
                end
            end
        end
    end
end

VendorMapPins.pinSourceProviders.profession = { collect = CollectProfessionPinRecords }

function VendorMapPins:ShowDropPinTooltip(pin, record)
    if not record then return end

    activeTooltipData = nil
    itemInfoEventFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")

    local tooltip = BeginPinTooltip(pin, "ANCHOR_RIGHT")
    -- Issue #38: build a plain item-name line rather than tooltip:SetItemByID().
    -- This pin tooltip is a private GameTooltipTemplate frame, not flagged
    -- isHomesteadManagedTooltip, so the Tooltips.lua post-call bails on it anyway
    -- (the source-layering the 9a47c17 commit message promised never happened) --
    -- and SetItemByID drags the whole TooltipDataProcessor / EmbeddedItemTooltip
    -- machinery into a hover path that doesn't need it. C_Item.GetItemNameByID is
    -- the non-deprecated lookup the rest of the addon already uses.
    local itemName = record.itemID
        and (C_Item.GetItemNameByID(record.itemID) or ("Item " .. tostring(record.itemID)))
        or "Item ?"
    tooltip:AddLine(itemName, 1, 1, 1)

    local drop = record.drop
    if drop and drop.mobName then
        tooltip:AddLine(drop.mobName, 0.9, 0.4, 0.4)
    end
    if drop and drop.zone then
        tooltip:AddLine(drop.zone, 0.7, 0.7, 0.7)
    end
    if drop and drop.notes then
        tooltip:AddLine(" ")
        tooltip:AddLine(drop.notes, 1, 0.82, 0, true)
    end
    tooltip:Show()
end

function VendorMapPins:EmitPortalBadges(mapID, renderState)
    -- Portal badge pass: draw entrance markers for Order Hall vendors
    -- accessible via this map. Gated to vendor/all filters by CollectSourcePins.
    local allVendors = HA.VendorData:GetAllVendors()
    for _, vendor in ipairs(allVendors) do
        local portal = vendor.portal
        if portal and portal.mapID == mapID then
            if not ShouldHideVendor(vendor) then
                renderState.portalBadges[#renderState.portalBadges + 1] = {
                    portalData = { vendor = vendor },
                    mapID = portal.mapID,
                    x = portal.x,
                    y = portal.y,
                    reason = "same_map",
                }
            end
        end
    end
end

function VendorMapPins:ShowZoneBadges(continentMapID, renderState)
    local sourceFilter = GetActiveSourceFilter()
    local zoneCounts = self:GetZoneVendorCounts(continentMapID, sourceFilter)

    for zoneMapID, zoneData in pairs(zoneCounts) do
        if zoneData.vendorCount > 0 then
            local ok, x, y, reason = MPP:ProjectZoneBadgeToContinentView(continentMapID, zoneMapID)
            if ok then
                renderState.zoneBadges[#renderState.zoneBadges + 1] = {
                    badgeData = BuildBadgeData(zoneMapID, zoneData.zoneName, zoneData),
                    mapID = zoneMapID,
                    x = x,
                    y = y,
                    reason = reason,
                }
            else
                DebugWorldMapProjectionSkip("zone_badge", zoneMapID, continentMapID, reason)
            end
        end
    end

    -- Show individual zone badges for continents that merge into this one
    -- (e.g. Argus zones shown on the Broken Isles continent map)
    for srcContinentID, destContinentID in pairs(MPP.continentMergesInto) do
        if destContinentID == continentMapID then
            local mergedZones = self:GetZoneVendorCounts(srcContinentID, sourceFilter)
            for zoneMapID, zoneData in pairs(mergedZones) do
                if zoneData.vendorCount > 0 then
                    local ok, x, y, reason = MPP:ProjectZoneBadgeToContinentView(continentMapID, zoneMapID)
                    if ok then
                        renderState.zoneBadges[#renderState.zoneBadges + 1] = {
                            badgeData = BuildBadgeData(zoneMapID, zoneData.zoneName, zoneData),
                            mapID = zoneMapID,
                            x = x,
                            y = y,
                            reason = reason,
                        }
                    else
                        DebugWorldMapProjectionSkip("merged_zone_badge", zoneMapID, continentMapID, reason)
                    end
                end
            end
        end
    end

    -- Show designated child-continent zone badges on this continent map.
    -- Example: Midnight/Quel'Thalas zones on Eastern Kingdoms.
    for srcContinentID, destContinentID in pairs(MPP.continentZoneBadgesOnParent or {}) do
        if destContinentID == continentMapID then
            local excludedBySource = MPP.continentZoneBadgeExclusionsOnParent
                and MPP.continentZoneBadgeExclusionsOnParent[srcContinentID]
            local excludedForDest = excludedBySource and excludedBySource[continentMapID]
            local sourceZones = self:GetZoneVendorCounts(srcContinentID, sourceFilter)
            for zoneMapID, zoneData in pairs(sourceZones) do
                local isExcluded = excludedForDest and excludedForDest[zoneMapID]
                if zoneData.vendorCount > 0 and not isExcluded then
                    local ok, x, y, reason = MPP:ProjectZoneBadgeToContinentView(continentMapID, zoneMapID)
                    if ok then
                        renderState.zoneBadges[#renderState.zoneBadges + 1] = {
                            badgeData = BuildBadgeData(zoneMapID, zoneData.zoneName, zoneData),
                            mapID = zoneMapID,
                            x = x,
                            y = y,
                            reason = reason,
                        }
                    else
                        DebugWorldMapProjectionSkip("overlay_zone_badge", zoneMapID, continentMapID, reason)
                    end
                end
            end
        end
    end

end
function VendorMapPins:ShowZoneBadgesOnWorldMap(renderState)
    local sourceFilter = GetActiveSourceFilter()
    local continentCounts = self:GetContinentVendorCounts(sourceFilter)

    for continentMapID, continentData in pairs(continentCounts) do
        if continentData.vendorCount > 0 then
            local projectedContinent = MPP.offWorldContinentPositions[continentMapID]
            if projectedContinent then
                local badgeData = {
                    mapID = continentMapID,
                    zoneName = continentData.continentName,
                    vendorCount = continentData.vendorCount,
                    uncollectedCount = continentData.uncollectedCount,
                    unknownCount = continentData.unknownCount,
                    oppositeFactionCount = continentData.oppositeFactionCount,
                    collectedItems = continentData.collectedItems,
                    totalItems = continentData.totalItems,
                    lockedItems = continentData.lockedItems,
                    unverifiedItems = continentData.unverifiedItems,
                }
                renderState.continentBadges[#renderState.continentBadges + 1] = {
                    badgeData = badgeData,
                    mapID = continentMapID,
                    x = projectedContinent.x,
                    y = projectedContinent.y,
                    reason = "manual_continent_position",
                }
            elseif not MPP.excludedContinents[continentMapID] then
                local zoneCounts = self:GetZoneVendorCounts(continentMapID, sourceFilter)
                for zoneMapID, zoneData in pairs(zoneCounts) do
                    if zoneData.vendorCount > 0 then
                        local ok, x, y, reason = MPP:ProjectZoneBadgeToWorldView(zoneMapID)
                        if ok then
                            renderState.zoneBadges[#renderState.zoneBadges + 1] = {
                                badgeData = BuildBadgeData(zoneMapID, zoneData.zoneName, zoneData),
                                mapID = zoneMapID,
                                x = x,
                                y = y,
                                reason = reason,
                            }
                        else
                            DebugWorldMapProjectionSkip("world_zone_badge", zoneMapID, 947, reason)
                        end
                    end
                end
            end
        end
    end
end

function VendorMapPins:ShowContinentBadges(renderState)
    -- Toggle: zone-level badges spread across continents vs single continent totals
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.vendorTracer.worldMapZoneBadges then
        self:ShowZoneBadgesOnWorldMap(renderState)
        return
    end

    local continentCounts = self:GetContinentVendorCounts(GetActiveSourceFilter())

    for continentMapID, continentData in pairs(continentCounts) do
        if continentData.vendorCount > 0 then
            if not MPP.excludedContinents[continentMapID] then
                local badgeData = {
                    mapID = continentMapID,
                    zoneName = continentData.continentName,
                    vendorCount = continentData.vendorCount,
                    uncollectedCount = continentData.uncollectedCount,
                    unknownCount = continentData.unknownCount,
                    oppositeFactionCount = continentData.oppositeFactionCount,
                    collectedItems = continentData.collectedItems,
                    totalItems = continentData.totalItems,
                    lockedItems = continentData.lockedItems,
                    unverifiedItems = continentData.unverifiedItems,
                }

                local ok, x, y, reason = MPP:ProjectContinentBadgeToWorldView(continentMapID)
                if ok then
                    renderState.continentBadges[#renderState.continentBadges + 1] = {
                        badgeData = badgeData,
                        mapID = continentMapID,
                        x = x,
                        y = y,
                        reason = reason,
                    }
                else
                    DebugWorldMapProjectionSkip("continent_badge", continentMapID, 947, reason)
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function VendorMapPins:Enable()
    pinsEnabled = true
    if isInitialized then
        RefreshRuntimeSubscriptions()
        self:RefreshPins()
    end
end

function VendorMapPins:Disable()
    pinsEnabled = false
    self:ClearAllPins()
    if isInitialized then
        RefreshRuntimeSubscriptions()
    end
end

function VendorMapPins:Toggle()
    if pinsEnabled then
        self:Disable()
    else
        self:Enable()
    end
    return pinsEnabled
end

function VendorMapPins:IsEnabled()
    return pinsEnabled
end

function VendorMapPins:EnableMinimapPins()
    minimapPinsEnabled = true
    if isInitialized then
        StartMinimapWarmup("enable_minimap_pins")
        RefreshRuntimeSubscriptions()
        self:RequestMinimapRefresh("enable_minimap_pins", 0.02, true)
    end
end

function VendorMapPins:DisableMinimapPins()
    minimapPinsEnabled = false
    StopMinimapWarmup()
    self:ClearMinimapPins()
    if isInitialized then
        RefreshRuntimeSubscriptions()
    end
end

function VendorMapPins:ToggleMinimapPins()
    if minimapPinsEnabled then
        self:DisableMinimapPins()
    else
        self:EnableMinimapPins()
    end
    return minimapPinsEnabled
end

function VendorMapPins:IsMinimapPinsEnabled()
    return minimapPinsEnabled
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function VendorMapPins:Initialize()
    if isInitialized then return end

    -- Resolve VendorFilter functions now that all modules are loaded
    local VendorFilter = HA.VendorFilter
    ShouldHideVendor = VendorFilter.ShouldHideVendor
    GetBestVendorCoordinates = VendorFilter.GetBestVendorCoordinates
    ShouldShowOppositeFaction = VendorFilter.ShouldShowOppositeFaction
    CanAccessVendor = VendorFilter.CanAccessVendor
    IsOppositeFaction = VendorFilter.IsOppositeFaction
    GetVendorXY = VendorFilter.GetVendorXY

    -- Get settings from saved variables
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.vendorTracer then
        pinsEnabled = HA.Addon.db.profile.vendorTracer.showMapPins ~= false
        minimapPinsEnabled = HA.Addon.db.profile.vendorTracer.showMinimapPins ~= false
    end

    -- Track pin settings state
    if HA.Analytics then
        HA.Analytics:Switch("MapPinsEnabled", pinsEnabled)
        HA.Analytics:Switch("MinimapPinsEnabled", minimapPinsEnabled)
    end

    if WorldMapProvider then
        WorldMapProvider:EnsureRegistered()
    end

    -- World map refresh is driven by the provider's watcher frame
    -- (HomesteadWorldMapProvider:EnsureRegistered). Do NOT hook WorldMapFrame
    -- OnShow or SetMapID directly — those run during Blizzard's secure
    -- map-open path and taint the execution context, causing
    -- SetPassThroughButtons() errors in combat.

    -- Listen for vendor scan events to refresh pins with new data
    if HA.Events then
        HA.Events:RegisterCallback("VENDOR_SCANNED", function(vendorRecord)
            -- Invalidate caches for rescanned vendor
            if vendorRecord and vendorRecord.npcID then
                BC:InvalidateVendorCache(vendorRecord.npcID)
            end
            self:InvalidateBadgeCache()
            -- Refresh pins if the world map is currently open
            if WorldMapFrame:IsShown() then
                self:RequestWorldMapRefresh("vendor_scanned", 0.1)
            end
            self:RequestMinimapRefresh("vendor_scanned", 0.1)
        end)

        -- Also listen for ownership cache updates
        HA.Events:RegisterCallback("OWNERSHIP_UPDATED", function()
            -- Ownership changed — flush all caches
            self:InvalidateAllCaches()
            if WorldMapFrame:IsShown() then
                self:RequestWorldMapRefresh("ownership_updated", 0.1)
            end
        end)

        -- Source caches invalidated — covers achievement, quest, reputation,
        -- profession, and holiday changes through SourceManager.
        HA.Events:RegisterCallback("SOURCE_CACHES_INVALIDATED", function()
            self:InvalidateBadgeCache()
            if WorldMapFrame:IsShown() then
                self:RequestWorldMapRefresh("source_caches_invalidated", 0.1)
            end
            self:RequestMinimapRefresh("source_caches_invalidated", 0.1)
        end)

        HA.Events:RegisterCallback("ACTIVE_ENDEAVOR_CHANGED", function()
            self:InvalidateBadgeCache()
            if WorldMapFrame:IsShown() then
                self:RequestWorldMapRefresh("endeavor_changed")
            end
            self:RequestMinimapRefresh("endeavor_changed")
        end)
    end

    isInitialized = true
    RefreshRuntimeSubscriptions()

    -- Initial minimap pin refresh
    if minimapPinsEnabled then
        StartMinimapWarmup("initial_load")
        C_Timer.After(1, function()
            self:RequestMinimapRefresh("initial_load", 0.02, true)
        end)
    end

    if HA.Addon then
        HA.Addon:Debug("VendorMapPins initialized (native world map and minimap overlay)")
    end
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("VendorMapPins", VendorMapPins)
end
