--[[
    Homestead - MinimapPinCollect
    Minimap vendor pin collection — gathers nearby vendors into pending pins
    and hands them to the minimap overlay for placement.

    Extracted from VendorMapPins.lua (HS-301 cut #3) to reduce file size.
    Cross-zone reach, pin caps, and warmup throttling are resolved here;
    faction/collection filtering comes from VendorFilter, coordinates from
    VendorFilter and MapPinProvider.

    External callers should use the VendorMapPins delegation wrapper
    (RefreshMinimapPins) — HA.VendorMapPins is the frozen public surface;
    this module is an implementation detail behind it.
]]

local _, HA = ...

local MinimapPinCollect = {}
HA.MinimapPinCollect = MinimapPinCollect

-- MapPinProvider / VendorFilter / minimap overlay references (loaded before
-- this file per TOC order)
local Constants = HA.Constants
local MPP = HA.MapPinProvider
local VF = HA.VendorFilter
local MinimapOverlay = HA.HomesteadMinimapOverlay
local GetContinentForZone = MPP.GetContinentForZone

-- Pin caps reduce work in dense hubs while preserving nearby visibility.
local MINIMAP_PIN_CAPS = {
    off = 80,
    auto = 60,
    on = 120,
}

local MINIMAP_WARMUP_PIN_CAP = 28

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

function MinimapPinCollect:RefreshMinimapPins()
    if not HA.VendorMapPins:IsInitialized() then return end
    -- HS-231: the minimap has always only ever shown vendor pins (no
    -- provider-registry abstraction here, unlike the world map's
    -- CollectSourcePins), so gating on the "vendor" toggle covers it —
    -- "vendor toggle hides minimap vendor pins too, one mental model."
    if not HA.VendorMapPins:IsMinimapPinsEnabled() or not HA.VendorMapPins:IsMapFilterSourceEnabled("vendor") then
        HA.VendorMapPins:ClearMinimapPins()
        return
    end

    HA.VendorMapPins:ClearMinimapPins()

    if MinimapOverlay and MinimapOverlay.ShouldHideMinimapPins then
        local shouldHide = MinimapOverlay:ShouldHideMinimapPins()
        if shouldHide then
            return
        end
    end

    if not HA.VendorData then return end

    -- Get the player's current zone
    local playerMapID = C_Map.GetBestMapForUnit("player")
    if not playerMapID then return end

    -- HS-271 item 4: workload is playerMapID, already read/validated above --
    -- no new scan added to feed this call. Minimap-refresh cost was
    -- previously unmeasured (HS-270, open item); this is its peer
    -- boundary to world_map_refresh/world_map_build for the movement capture.
    HA.PerformanceTrace:Measure("minimap_refresh", playerMapID, function()
        local showElevationArrows = HA.Addon.db.profile.vendorTracer.showElevationArrows ~= false
        local crossZoneMode = GetMinimapCrossZoneMode()
        local pinCap = GetMinimapPinCap(crossZoneMode)
        local includeSiblingZones = ShouldIncludeSiblingZones(playerMapID, crossZoneMode)
        local isWarmupRefresh = HA.VendorMapPins:IsMinimapWarmupActive()
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

        local showOpposite = VF.ShouldShowOppositeFaction()
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
                        -- HS-022: minimap has no source filter; pass nil and let
                        -- the completion check default to "all" internally.
                        local shouldSkipVendor = VF.ShouldHideVendor(vendor)
                            or VF.ShouldHideCompletedVendorPin(vendor, nil)

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
                            local coords, vendorMapID = VF.GetBestVendorCoordinates(vendor)

                            -- Only show pins for vendors with valid coordinates
                            if coords and vendorMapID then
                                local canAccess = HA.VendorMapPins:CanAccessVendor(vendor)
                                local isOpposite = HA.VendorMapPins:IsOppositeFaction(vendor)
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
    end)
end
