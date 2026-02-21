--[[
    Homestead - VendorMapPins
    World map integration for housing decor vendor locations

    Uses HereBeDragons-Pins-2.0 library for reliable map pin management.
    HBD pin SetScalingLimits(1, 1.0, 1.2) handles zoom behavior.

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

-- Load HereBeDragons
local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

-- Local references
local Constants = HA.Constants

-- Upvalued Lua stdlib
local pairs, ipairs = pairs, ipairs
local tinsert = table.insert
local format = string.format
local unpack = unpack

-- State
local isInitialized = false
local pinsEnabled = true

-- Pin frame pools (we create the actual frames, HBD manages their position)
local vendorPinFrames = {}
local badgePinFrames = {}
local minimapPinFrames = {}

-------------------------------------------------------------------------------
-- Native Pin Fallback (for maps HBD can't handle, e.g. Argus zones)
-- HBD stores zero-dimension map data for cross-instance zones, causing
-- GetWorldCoordinatesFromZone() to return nil and AddWorldMapIconMap() to
-- silently bail. This fallback uses WoW's native MapCanvasPin system
-- with zone-normalized (0-1) coordinates directly.
-------------------------------------------------------------------------------

local NATIVE_PIN_TEMPLATE = "HomesteadNativePinTemplate"

-- Cache which maps HBD can/can't handle (per session)
local hbdMapSupport = {}

local function IsHBDSupported(mapID)
    if hbdMapSupport[mapID] ~= nil then return hbdMapSupport[mapID] end
    local wx = HBD:GetWorldCoordinatesFromZone(0.5, 0.5, mapID)
    hbdMapSupport[mapID] = (wx ~= nil)
    return hbdMapSupport[mapID]
end

-- Native pin mixin (mirrors HBD's pin behavior)
local nativePinMixin = CreateFromMixins(MapCanvasPinMixin)

function nativePinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, 1.0, 1.2)
end

function nativePinMixin:OnAcquired(icon, x, y)
    self:SetPosition(x, y)
    self.icon = icon
    icon:SetParent(self)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", self)
    icon:Show()
end

function nativePinMixin:OnReleased()
    if self.icon then
        self.icon:Hide()
        self.icon:SetParent(UIParent)
        self.icon:ClearAllPoints()
        self.icon = nil
    end
end

-- Suppress in-combat errors (same as HBD)
nativePinMixin.SetPassThroughButtons = function() end

-- Create pin pool and register with WorldMapFrame
local nativePool
if CreateUnsecuredRegionPoolInstance then
    nativePool = CreateUnsecuredRegionPoolInstance(NATIVE_PIN_TEMPLATE)
else
    nativePool = CreateFramePool("FRAME")
end
nativePool.parent = WorldMapFrame:GetCanvas()
nativePool.createFunc = function()
    local f = CreateFrame("Frame", nil, WorldMapFrame:GetCanvas())
    f:SetSize(1, 1)
    return Mixin(f, nativePinMixin)
end
nativePool.resetFunc = function(pool, pin)
    pin:Hide()
    pin:ClearAllPoints()
    pin:OnReleased()
    pin.pinTemplate = nil
    pin.owningMap = nil
end
-- Pre-11.x compat names
nativePool.creationFunc = nativePool.createFunc
nativePool.resetterFunc = nativePool.resetFunc
WorldMapFrame.pinPools[NATIVE_PIN_TEMPLATE] = nativePool -- luacheck: ignore 122

-- Helper: add a pin using HBD if possible, native fallback otherwise.
-- Returns true if the pin was placed.
local function AddWorldMapPin(frame, mapID, x, y, showFlag)
    if IsHBDSupported(mapID) then
        HBDPins:AddWorldMapIconMap("HomesteadVendors", frame, mapID, x, y, showFlag)
        return true
    end
    -- Native fallback: only works when viewing THIS exact map
    local currentMapID = WorldMapFrame:GetMapID()
    if currentMapID == mapID then
        WorldMapFrame:AcquirePin(NATIVE_PIN_TEMPLATE, frame, x, y)
        return true
    end
    return false
end

-- Pin color/size helpers delegated to PinFrameFactory (loaded before this file)
-- Vendor filter/coord helpers delegated to VendorFilter (loaded before this file)
local VendorFilter = HA.VendorFilter
local IsVendorVerified = VendorFilter.IsVendorVerified
local ShouldHideVendor = VendorFilter.ShouldHideVendor
local GetBestVendorCoordinates = VendorFilter.GetBestVendorCoordinates
local ShouldShowOppositeFaction = VendorFilter.ShouldShowOppositeFaction
local ShouldShowUnverifiedVendors = VendorFilter.ShouldShowUnverifiedVendors

-- Badge/collection helpers delegated to BadgeCalculation (loaded before this file)
local BC = HA.BadgeCalculation
local GetContinentForZone = BC.GetContinentForZone

-- Minimap pins enabled state
local minimapPinsEnabled = true

-- Shared minimap refresh timer used to coalesce bursty refresh requests.
local minimapRefreshTimer = nil
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

-- Exclude continents in separate world spaces where cross-zone minimap translation
-- can collapse pins onto the player arrow.
local minimapExcludedContinents = {
    [101] = true,   -- Outland (separate world space)
    [572] = true,   -- Draenor (alternate dimension)
    [1550] = true,  -- Shadowlands (afterlife dimension)
}

-- Runtime event/ticker handles (registered conditionally by feature state)
local merchantEventFrame = nil
local zoneEventFrame = nil
local indoorStateTicker = nil
local lastKnownIndoors = nil
local minimapWarmupActive = false
local minimapWarmupTimer = nil

-- Dedup guards for minimap and world map refreshes
local lastMinimapMapID = nil
local lastWorldMapID = nil

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
local activeTooltipData = nil      -- {pin, vendor} while tooltip is visible
local tooltipRebuildPending = false -- Debounce flag for batching rebuilds

itemInfoEventFrame:SetScript("OnEvent", function(self, event, itemID, success)
    if not success or not activeTooltipData then return end
    if not tooltipRebuildPending then
        tooltipRebuildPending = true
        C_Timer.After(0.05, function()
            tooltipRebuildPending = false
            if activeTooltipData and GameTooltip:IsShown() then
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
    end
end

local function UnregisterZoneChangeEvents()
    if zoneEventFrame and zoneEventFrame:IsEventRegistered("ZONE_CHANGED") then
        zoneEventFrame:UnregisterEvent("ZONE_CHANGED")
        zoneEventFrame:UnregisterEvent("ZONE_CHANGED_INDOORS")
        zoneEventFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
        zoneEventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end

    if minimapRefreshTimer then
        minimapRefreshTimer:Cancel()
        minimapRefreshTimer = nil
    end
end

-- Indoor state polling ticker lifecycle (minimap-only).
local function StartIndoorTicker()
    if indoorStateTicker then return end

    lastKnownIndoors = IsIndoors()
    indoorStateTicker = C_Timer.NewTicker(1, function()
        -- Secondary safeguard; ticker should also be canceled when minimap pins are disabled.
        if not minimapPinsEnabled then return end

        local indoors = IsIndoors()
        if indoors ~= lastKnownIndoors then
            lastKnownIndoors = indoors
            VendorMapPins:RequestMinimapRefresh("indoor_state_changed", 0.05)
        end
    end)
end

local function StopIndoorTicker()
    if indoorStateTicker then
        indoorStateTicker:Cancel()
        indoorStateTicker = nil
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
        StartIndoorTicker()
    else
        UnregisterZoneChangeEvents()
        StopIndoorTicker()
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
    self:RefreshPins()
    self:RefreshMinimapPins()
end

-- Called by PinFrameFactory OnLeave scripts to clear tooltip tracking state
function VendorMapPins:OnPinLeave()
    activeTooltipData = nil
    itemInfoEventFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
end

-- Local wrappers for frame creation (delegate to PinFrameFactory)
local function CreateVendorPinFrame(vendor, isOppositeFaction, isUnverified)
    return HA.PinFrameFactory:CreateVendorPinFrame(vendor, isOppositeFaction, isUnverified)
end

local function CreateBadgePinFrame(badgeData)
    return HA.PinFrameFactory:CreateBadgePinFrame(badgeData)
end

local function CreateMinimapPinFrame(vendor, isOppositeFaction, isUnverified, elevation)
    return HA.PinFrameFactory:CreateMinimapPinFrame(vendor, isOppositeFaction, isUnverified, elevation)
end

-------------------------------------------------------------------------------
-- Filter/Faction Delegates (forwarded to VendorFilter)
-------------------------------------------------------------------------------

function VendorMapPins:CanAccessVendor(vendor)
    return VendorFilter.CanAccessVendor(vendor)
end

function VendorMapPins:IsOppositeFaction(vendor)
    return VendorFilter.IsOppositeFaction(vendor)
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

function VendorMapPins:InvalidateBadgeCache()
    BC:InvalidateBadgeCache()
    lastWorldMapID = nil
    lastMinimapMapID = nil
end

function VendorMapPins:InvalidateAllCaches()
    BC:InvalidateAllCaches()
    lastWorldMapID = nil
    lastMinimapMapID = nil
end

function VendorMapPins:GetZoneVendorCounts(continentMapID)
    return BC:GetZoneVendorCounts(continentMapID)
end

function VendorMapPins:GetContinentVendorCounts()
    return BC:GetContinentVendorCounts()
end

function VendorMapPins:GetContinentCenterOnWorldMap(continentMapID)
    return BC:GetContinentCenterOnWorldMap(continentMapID)
end

function VendorMapPins:GetZoneCenterOnMap(zoneMapID, parentMapID)
    return BC:GetZoneCenterOnMap(zoneMapID, parentMapID)
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
    activeTooltipData = { pin = pin, vendor = vendor }
    itemInfoEventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

    local isOpposite = self:IsOppositeFaction(vendor)
    local isUnverified = not IsVendorVerified(vendor)

    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(vendor.name, 1, 1, 1)

    if vendor.subzone then
        GameTooltip:AddLine(vendor.subzone .. " (" .. vendor.zone .. ")", 0.7, 0.7, 0.7)
    elseif vendor.zone then
        GameTooltip:AddLine(vendor.zone, 0.7, 0.7, 0.7)
    end

    if vendor.faction and vendor.faction ~= "Neutral" then
        local factionColor = vendor.faction == "Alliance" and {0, 0.44, 0.87} or {0.77, 0.12, 0.23}
        GameTooltip:AddLine(vendor.faction, unpack(factionColor))
    end

    -- Warning for unverified vendors (imported data not yet confirmed in-game)
    if isUnverified then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Unverified location - visit to confirm", 1.0, 0.6, 0.2)
    end

    -- Warning for opposite faction vendors
    if isOpposite then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Cannot access - opposite faction vendor", 0.8, 0.3, 0.3)
    end

    if vendor.notes then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(vendor.notes, 1, 0.82, 0, true)
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
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Items Sold:", 1, 1, 0)

        local collectedCount = 0
        local uncollectedItems = {}

        for _, item in ipairs(allItems) do
            local itemName = item.name or (item.itemID and GetItemInfo(item.itemID)) or "Unknown Item"
            local isOwned = false

            if item.itemID then
                isOwned = IsItemOwned(item.itemID)
                -- Debug: Check if item is in cache (verbose, dev only)
                if HA.DevAddon and HA.Addon.db.profile.debug then
                    local inCache = HA.CatalogStore and HA.CatalogStore:IsOwned(item.itemID)
                    HA.Addon:Debug("Item", item.itemID, itemName, "owned:", isOwned, "inCache:", inCache and "yes" or "no")
                end
            end

            if isOwned then
                collectedCount = collectedCount + 1
            else
                tinsert(uncollectedItems, itemName)
            end
        end

        -- If all items are collected, show them all in grey
        if #uncollectedItems == 0 then
            for _, item in ipairs(allItems) do
                local itemName = item.name or (item.itemID and GetItemInfo(item.itemID)) or "Unknown Item"
                GameTooltip:AddLine("  " .. itemName .. " (owned)", 0.5, 0.5, 0.5)
            end
        else
            -- Show uncollected items first (in green)
            for _, itemName in ipairs(uncollectedItems) do
                GameTooltip:AddLine("  " .. itemName, 0, 1, 0)
            end

            -- Show collected count summary
            if collectedCount > 0 then
                GameTooltip:AddLine(format("  ... and %d collected item(s)", collectedCount), 0.5, 0.5, 0.5)
            end
        end

        GameTooltip:AddLine(" ")
        local statusColor = collectedCount == #allItems and {0.5, 0.5, 0.5} or {0, 1, 0}
        GameTooltip:AddLine(format("Collected: %d/%d", collectedCount, #allItems), unpack(statusColor))
    else
        -- No item data available
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Item data unknown - visit vendor to scan", 1, 0.82, 0)
    end

    GameTooltip:AddLine(" ")
    if isOpposite then
        GameTooltip:AddLine("Left-click to set waypoint (for alts)", 0.5, 0.5, 0.5)
    else
        GameTooltip:AddLine("Left-click to set waypoint", 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end

function VendorMapPins:ShowZoneBadgeTooltip(pin, zoneInfo)
    if not zoneInfo then return end

    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(zoneInfo.zoneName, 1, 1, 1)

    -- Show note (class hall info, access method, etc.)
    if zoneInfo.note then
        GameTooltip:AddLine(zoneInfo.note, 0.7, 0.7, 1.0, true)
    end

    GameTooltip:AddLine(format("Decor Vendors: %d", zoneInfo.vendorCount), 1, 0.82, 0)

    -- Show faction breakdown if there are opposite faction vendors
    if zoneInfo.oppositeFactionCount and zoneInfo.oppositeFactionCount > 0 then
        local accessibleCount = zoneInfo.vendorCount - zoneInfo.oppositeFactionCount
        local playerFaction = UnitFactionGroup("player")
        local oppositeFaction = playerFaction == "Alliance" and "Horde" or "Alliance"

        if accessibleCount > 0 then
            GameTooltip:AddLine(format("  %s: %d", playerFaction, accessibleCount), 0.7, 0.7, 0.7)
        end

        local factionColor = oppositeFaction == "Alliance" and {0.2, 0.4, 0.8} or {0.8, 0.2, 0.2}
        GameTooltip:AddLine(format("  %s: %d", oppositeFaction, zoneInfo.oppositeFactionCount),
            factionColor[1], factionColor[2], factionColor[3])
    end

    -- Show collection status
    if zoneInfo.uncollectedCount and zoneInfo.uncollectedCount > 0 then
        GameTooltip:AddLine(format("With uncollected items: %d", zoneInfo.uncollectedCount), 0, 1, 0)
    end

    if zoneInfo.unknownCount and zoneInfo.unknownCount > 0 then
        GameTooltip:AddLine(format("Unknown status: %d (visit to scan)", zoneInfo.unknownCount), 1, 0.82, 0)
    end

    local knownVendors = zoneInfo.vendorCount - (zoneInfo.unknownCount or 0)
    local allCollected = (zoneInfo.uncollectedCount or 0) == 0 and knownVendors > 0
    if allCollected and (zoneInfo.unknownCount or 0) == 0 then
        GameTooltip:AddLine("All items collected!", 0.5, 0.5, 0.5)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click to view zone map", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

-------------------------------------------------------------------------------
-- Pin Management
-------------------------------------------------------------------------------

function VendorMapPins:ClearAllPins()
    -- Remove all vendor pins from HereBeDragons
    HBDPins:RemoveAllWorldMapIcons("HomesteadVendors")

    -- Remove native fallback pins (Argus, etc.)
    WorldMapFrame:RemoveAllPinsByTemplate(NATIVE_PIN_TEMPLATE)

    -- Hide and release all our frame objects
    for _, frame in pairs(vendorPinFrames) do
        frame:Hide()
    end
    for _, frame in pairs(badgePinFrames) do
        frame:Hide()
    end

    -- Clear the tables
    wipe(vendorPinFrames)
    wipe(badgePinFrames)
end

function VendorMapPins:ClearMinimapPins()
    -- Remove all minimap pins from HereBeDragons
    HBDPins:RemoveAllMinimapIcons("HomesteadMinimapVendors")

    -- Hide and release all minimap frame objects
    for _, frame in pairs(minimapPinFrames) do
        frame:Hide()
    end

    -- Clear the table
    wipe(minimapPinFrames)
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

    local continentID = GetContinentForZone(playerMapID)
    if includeSiblingZones then
        if continentID and not minimapExcludedContinents[continentID] then
            local siblingZones = BC.continentToZones[continentID]
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
    local floatOnEdge = not IsIndoors()  -- Hide distant pins when inside buildings/caves
    local addedVendors = {}  -- Prevent duplicate pins for same vendor
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
                    if not shouldSkipVendor and HA.Addon and HA.Addon.db
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
                            local isUnverified = not IsVendorVerified(vendor)
                            local showUnverified = ShouldShowUnverifiedVendors()

                            -- Show vendor only when allowed by verification and faction-access rules.
                            if (showUnverified or not isUnverified) and (canAccess or (isOpposite and showOpposite)) then
                                local elevation = Constants.GetElevationDirection(playerMapID, vendorMapID)

                                if elevation then
                                    -- Cross-floor: use AddMinimapIconWorld to bypass HBD mapID filter
                                    local worldX, worldY, instanceID = HBD:GetWorldCoordinatesFromZone(
                                        coords.x, coords.y, vendorMapID)
                                    if worldX then
                                        local showArrow = showElevationArrows
                                        local frame = CreateMinimapPinFrame(vendor, isOpposite, isUnverified,
                                            showArrow and elevation or nil)
                                        minimapPinFrames[vendor] = frame
                                        addedVendors[vendor.npcID] = true
                                        addedCount = addedCount + 1
                                        -- Always float on edge for cross-floor pins; indoor detection
                                        -- would otherwise hide them in underground zones
                                        HBDPins:AddMinimapIconWorld("HomesteadMinimapVendors", frame,
                                            instanceID, worldX, worldY, true)
                                    end
                                    -- If conversion fails, skip — zone has no HBD mapData and
                                    -- AddMinimapIconMap would also fail (same conversion internally)
                                else
                                    local frame = CreateMinimapPinFrame(vendor, isOpposite, isUnverified)
                                    minimapPinFrames[vendor] = frame
                                    addedVendors[vendor.npcID] = true
                                    addedCount = addedCount + 1
                                    HBDPins:AddMinimapIconMap("HomesteadMinimapVendors", frame, vendorMapID,
                                        coords.x, coords.y,
                                        true,         -- showInParentZone
                                        floatOnEdge)  -- false indoors: hides distant pins
                                end
                            end
                        end
                    end
                end
            end
        end
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

function VendorMapPins:RefreshPins()
    if not isInitialized then return end
    if not pinsEnabled then
        self:ClearAllPins()
        return
    end

    self:ClearAllPins()

    if not HA.VendorData then return end

    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return end

    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo then return end

    -- Determine what to show based on map type
    if mapInfo.mapType == Enum.UIMapType.World or mapInfo.mapType == Enum.UIMapType.Cosmic then
        self:ShowContinentBadges()
    elseif mapInfo.mapType == Enum.UIMapType.Continent then
        self:ShowZoneBadges(mapID)
    else
        self:ShowVendorPins(mapID)
    end
end

function VendorMapPins:ShowVendorPins(mapID)
    local showOpposite = ShouldShowOppositeFaction()
    local addedVendors = {}  -- Track by npcID to avoid duplicates

    -- Build set of valid mapIDs: current map + child/sub-zone maps
    -- This ensures vendors in sub-zones (e.g., City of Threads inside Azj-Kahet)
    -- appear on the parent zone map via HBD's showInParentZone
    local validMapIDs = { [mapID] = true }
    local childMaps = C_Map.GetMapChildrenInfo(mapID)
    if childMaps then
        for _, childInfo in ipairs(childMaps) do
            validMapIDs[childInfo.mapID] = true
        end
    end

    -- Helper function to process a vendor
    local function ProcessVendor(vendor)
        if not vendor or not vendor.npcID then return end
        if addedVendors[vendor.npcID] then return end

        -- Skip unreleased or no-decor vendors
        if ShouldHideVendor(vendor) then
            -- Mark as processed to avoid re-checking in scanned vendors loop
            addedVendors[vendor.npcID] = true
            return
        end

        -- Get best coordinates (scanned preferred over static)
        local coords, vendorMapID = GetBestVendorCoordinates(vendor)

        -- Show pins for vendors on this map OR any child/sub-zone map
        -- Child map vendors are placed via HBD's showInParentZone (HBD_PINS_WORLDMAP_SHOW_PARENT)
        if coords and vendorMapID and validMapIDs[vendorMapID] then
            local canAccess = self:CanAccessVendor(vendor)
            local isOpposite = self:IsOppositeFaction(vendor)
            local isUnverified = not IsVendorVerified(vendor)
            local showUnverified = ShouldShowUnverifiedVendors()

            -- Skip unverified vendors if setting is disabled
            if isUnverified and not showUnverified then
                addedVendors[vendor.npcID] = true
                return
            end

            -- Show vendor if accessible OR if opposite faction and setting enabled
            if canAccess or (isOpposite and showOpposite) then
                local frame = CreateVendorPinFrame(vendor, isOpposite, isUnverified)
                vendorPinFrames[vendor] = frame
                addedVendors[vendor.npcID] = true

                -- Add to world map using vendor's actual mapID (HBD with native fallback for Argus etc.)
                -- vendorMapID may differ from mapID for sub-zone vendors; HBD_PINS_WORLDMAP_SHOW_PARENT
                -- ensures sub-zone pins appear on the parent zone map
                AddWorldMapPin(frame, vendorMapID, coords.x, coords.y,
                    HBD_PINS_WORLDMAP_SHOW_PARENT)
            end
        end
    end

    -- First, process vendors from static database for this map and child maps
    for queryMapID in pairs(validMapIDs) do
        local staticVendors = HA.VendorData:GetVendorsInMap(queryMapID)
        if staticVendors then
            for _, vendor in ipairs(staticVendors) do
                local shouldSkip = false
                local skipReason = nil

                -- Check 1: Skip unreleased or no-decor vendors
                if ShouldHideVendor(vendor) then
                    shouldSkip = true
                    skipReason = vendor.unreleased and "unreleased" or "no decor"
                end

                -- Check 2: Skip if vendor was scanned on a map outside this zone hierarchy
                if not shouldSkip and HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
                    local scannedData = HA.Addon.db.global.scannedVendors[vendor.npcID]
                    if scannedData and scannedData.mapID and not validMapIDs[scannedData.mapID] then
                        shouldSkip = true
                        skipReason = format("scanned on map %d", scannedData.mapID)
                    end
                end

                if shouldSkip then
                    -- Mark as processed to prevent re-check in scanned vendors loop
                    addedVendors[vendor.npcID] = true
                    if HA.DevAddon and HA.Addon.db.profile.debug then
                        HA.Addon:Debug(format("Skipping static vendor %s (%d) on map %d - %s",
                            vendor.name or "Unknown", vendor.npcID, queryMapID, skipReason or "unknown"))
                    end
                else
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
                -- Try to get full vendor info from static data, fall back to scanned data
                local vendor = HA.VendorData:GetVendor(npcID)
                if vendor then
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
                    ProcessVendor(tempVendor)
                end
            end
        end
    end

    -- Pre-warm item info cache for all visible vendor pins
    -- GetItemInfo() triggers async server fetch if not cached; fire-and-forget
    for _, frame in pairs(vendorPinFrames) do
        local vendor = frame.vendor
        if vendor then
            -- Static DB items (plain int or {itemID, cost=...})
            if vendor.items then
                for _, item in ipairs(vendor.items) do
                    local itemID = HA.VendorData:GetItemID(item)
                    if itemID then
                        GetItemInfo(itemID)
                    end
                end
            end
            -- Scanned items ({itemID = X, name = "...", ...})
            if vendor.npcID and HA.Addon and HA.Addon.db
                    and HA.Addon.db.global.scannedVendors then
                local scanned = HA.Addon.db.global.scannedVendors[vendor.npcID]
                local scannedItems = scanned and scanned.items
                if scannedItems then
                    for _, item in ipairs(scannedItems) do
                        if item.itemID then
                            GetItemInfo(item.itemID)
                        end
                    end
                end
            end
        end
    end
end

function VendorMapPins:ShowZoneBadges(continentMapID)
    local zoneCounts = self:GetZoneVendorCounts(continentMapID)

    for zoneMapID, zoneData in pairs(zoneCounts) do
        if zoneData.vendorCount > 0 then
            local zoneCenter = self:GetZoneCenterOnMap(zoneMapID, continentMapID)
            if zoneCenter then
                local badgeData = {
                    mapID = zoneMapID,
                    zoneName = zoneData.zoneName,
                    vendorCount = zoneData.vendorCount,
                    uncollectedCount = zoneData.uncollectedCount,
                    unknownCount = zoneData.unknownCount,
                    oppositeFactionCount = zoneData.oppositeFactionCount,
                    dominantFaction = zoneData.dominantFaction,
                    note = BC.zoneNotes[zoneMapID],
                }

                local frame = CreateBadgePinFrame(badgeData)
                badgePinFrames[zoneMapID] = frame

                -- Add badge to the continent map (HBD with native fallback)
                AddWorldMapPin(frame, continentMapID, zoneCenter.x, zoneCenter.y,
                    HBD_PINS_WORLDMAP_SHOW_CONTINENT)
            end
        end
    end

    -- Show child continent badges (e.g. Argus on Broken Isles)
    local children = BC.childContinents[continentMapID]
    if children then
        local continentCounts = self:GetContinentVendorCounts()
        for _, child in ipairs(children) do
            local childData = continentCounts[child.id]
            if childData and childData.vendorCount > 0 then
                local badgeData = {
                    mapID = child.id,
                    zoneName = childData.continentName,
                    vendorCount = childData.vendorCount,
                    uncollectedCount = childData.uncollectedCount,
                    unknownCount = childData.unknownCount,
                    oppositeFactionCount = childData.oppositeFactionCount,
                }

                local frame = CreateBadgePinFrame(badgeData)
                badgePinFrames["child_" .. child.id] = frame

                -- Place on parent continent map via native fallback
                AddWorldMapPin(frame, continentMapID, child.x, child.y,
                    HBD_PINS_WORLDMAP_SHOW_CONTINENT)
            end
        end
    end
end

function VendorMapPins:ShowZoneBadgesOnWorldMap()
    local continentCounts = self:GetContinentVendorCounts()

    for continentMapID, continentData in pairs(continentCounts) do
        if continentData.vendorCount > 0 then
            -- Off-world continents: keep as aggregate badge (HBD can't translate)
            local manualPos = BC.offWorldContinentPositions[continentMapID]
            if manualPos then
                local badgeData = {
                    mapID = continentMapID,
                    zoneName = continentData.continentName,
                    vendorCount = continentData.vendorCount,
                    uncollectedCount = continentData.uncollectedCount,
                    unknownCount = continentData.unknownCount,
                    oppositeFactionCount = continentData.oppositeFactionCount,
                }
                local frame = CreateBadgePinFrame(badgeData)
                badgePinFrames[continentMapID] = frame
                WorldMapFrame:AcquirePin(NATIVE_PIN_TEMPLATE, frame, manualPos.x, manualPos.y)

            elseif not BC.excludedContinents[continentMapID] then
                -- Normal continent: place individual zone badges
                local zoneCounts = self:GetZoneVendorCounts(continentMapID)
                for zoneMapID, zoneData in pairs(zoneCounts) do
                    if zoneData.vendorCount > 0 then
                        local badgeData = {
                            mapID = zoneMapID,
                            zoneName = zoneData.zoneName,
                            vendorCount = zoneData.vendorCount,
                            uncollectedCount = zoneData.uncollectedCount,
                            unknownCount = zoneData.unknownCount,
                            oppositeFactionCount = zoneData.oppositeFactionCount,
                            dominantFaction = zoneData.dominantFaction,
                            note = BC.zoneNotes[zoneMapID],
                        }
                        local frame = CreateBadgePinFrame(badgeData)
                        badgePinFrames["world_" .. zoneMapID] = frame

                        -- HBD translates zone center to world map position automatically
                        HBDPins:AddWorldMapIconMap("HomesteadVendors", frame, zoneMapID,
                            0.5, 0.5,
                            HBD_PINS_WORLDMAP_SHOW_WORLD)
                    end
                end
            end
        end
    end
end

function VendorMapPins:ShowContinentBadges()
    -- Toggle: zone-level badges spread across continents vs single continent totals
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.vendorTracer.worldMapZoneBadges then
        self:ShowZoneBadgesOnWorldMap()
        return
    end

    local continentCounts = self:GetContinentVendorCounts()

    for continentMapID, continentData in pairs(continentCounts) do
        if continentData.vendorCount > 0 then
            -- Off-world continent with manual position (e.g. Argus)
            local manualPos = BC.offWorldContinentPositions[continentMapID]

            if manualPos then
                -- Off-world continent: place badge directly on map 947 canvas
                -- using native AcquirePin (HBD can't translate these coordinates)
                local badgeData = {
                    mapID = continentMapID,
                    zoneName = continentData.continentName,
                    vendorCount = continentData.vendorCount,
                    uncollectedCount = continentData.uncollectedCount,
                    unknownCount = continentData.unknownCount,
                    oppositeFactionCount = continentData.oppositeFactionCount,
                }

                local frame = CreateBadgePinFrame(badgeData)
                badgePinFrames[continentMapID] = frame

                WorldMapFrame:AcquirePin(NATIVE_PIN_TEMPLATE, frame, manualPos.x, manualPos.y)

            elseif not BC.excludedContinents[continentMapID] then
                -- Normal continent — HBD handles world map positioning
                local badgeData = {
                    mapID = continentMapID,
                    zoneName = continentData.continentName,
                    vendorCount = continentData.vendorCount,
                    uncollectedCount = continentData.uncollectedCount,
                    unknownCount = continentData.unknownCount,
                    oppositeFactionCount = continentData.oppositeFactionCount,
                }

                local frame = CreateBadgePinFrame(badgeData)
                badgePinFrames[continentMapID] = frame

                HBDPins:AddWorldMapIconMap("HomesteadVendors", frame, continentMapID,
                    0.5, 0.5,
                    HBD_PINS_WORLDMAP_SHOW_WORLD)
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

    -- Hook WorldMapFrame to refresh pins when map changes
    WorldMapFrame:HookScript("OnShow", function()
        self:RefreshPins()
    end)

    hooksecurefunc(WorldMapFrame, "SetMapID", function(_, mapID)
        if mapID == lastWorldMapID then return end
        lastWorldMapID = mapID
        -- Small delay to let the map update first
        C_Timer.After(0, function()
            self:RefreshPins()
        end)
    end)

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
                C_Timer.After(0.1, function()
                    self:RefreshPins()
                end)
            end
            self:RequestMinimapRefresh("vendor_scanned", 0.1)
        end)

        -- Also listen for ownership cache updates
        HA.Events:RegisterCallback("OWNERSHIP_UPDATED", function()
            -- Ownership changed — flush all caches
            self:InvalidateAllCaches()
            if WorldMapFrame:IsShown() then
                C_Timer.After(0.1, function()
                    self:RefreshPins()
                end)
            end
        end)

        -- Holiday state changed — event vendor pins may need to appear/disappear
        HA.Events:RegisterCallback("ACTIVE_HOLIDAYS_CHANGED", function()
            self:InvalidateBadgeCache()
            if WorldMapFrame:IsShown() then
                self:RefreshPins()
            end
            self:RequestMinimapRefresh("holidays_changed")
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
        HA.Addon:Debug("VendorMapPins initialized (HereBeDragons with multi-zone minimap support)")
    end
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("VendorMapPins", VendorMapPins)
end
