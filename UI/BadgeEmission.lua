--[[
    Homestead - BadgeEmission
    Zone, continent, and portal badge emission — pure renderState producers,
    no frame contact.

    Extracted from VendorMapPins.lua (HS-301 cut #2) to reduce file size.
    Badge counts and collection status come from BadgeCalculation; coordinate
    projection comes from MapPinProvider. This module only appends entries to
    a caller-supplied renderState table.

    External callers should use the VendorMapPins delegation wrappers
    (EmitPortalBadges, ShowZoneBadges, ShowZoneBadgesOnWorldMap,
    ShowContinentBadges) — HA.VendorMapPins is the frozen public surface;
    this module is an implementation detail behind it.
]]

local _, HA = ...

local BadgeEmission = {}
HA.BadgeEmission = BadgeEmission

-- BadgeCalculation / MapPinProvider / VendorFilter references (loaded before
-- this file per TOC order)
local BC = HA.BadgeCalculation
local MPP = HA.MapPinProvider
local VF = HA.VendorFilter

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

function BadgeEmission:EmitPortalBadges(mapID, renderState)
    -- Portal badge pass: draw entrance markers for Order Hall vendors
    -- accessible via this map. Gated to vendor/all filters by CollectSourcePins.
    local sourceFilter = HA.VendorMapPins:GetActiveSourceFilter()
    local allVendors = HA.VendorData:GetAllVendors()
    for _, vendor in ipairs(allVendors) do
        local portal = vendor.portal
        if portal and portal.mapID == mapID then
            -- HS-022: a hidden vendor must not leave an orphaned portal badge.
            if not VF.ShouldHideVendor(vendor) and not VF.ShouldHideCompletedVendorPin(vendor, sourceFilter) then
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

function BadgeEmission:ShowZoneBadges(continentMapID, renderState)
    local sourceFilter = HA.VendorMapPins:GetActiveSourceFilter()
    local zoneCounts = BC:GetZoneVendorCounts(continentMapID, sourceFilter)

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
                HA.VendorMapPins:DebugWorldMapProjectionSkip("zone_badge", zoneMapID, continentMapID, reason)
            end
        end
    end

    -- Show individual zone badges for continents that merge into this one
    -- (e.g. Argus zones shown on the Broken Isles continent map)
    for srcContinentID, destContinentID in pairs(MPP.continentMergesInto) do
        if destContinentID == continentMapID then
            local mergedZones = BC:GetZoneVendorCounts(srcContinentID, sourceFilter)
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
                        HA.VendorMapPins:DebugWorldMapProjectionSkip("merged_zone_badge", zoneMapID, continentMapID, reason)
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
            local sourceZones = BC:GetZoneVendorCounts(srcContinentID, sourceFilter)
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
                        HA.VendorMapPins:DebugWorldMapProjectionSkip("overlay_zone_badge", zoneMapID, continentMapID, reason)
                    end
                end
            end
        end
    end

end
function BadgeEmission:ShowZoneBadgesOnWorldMap(renderState)
    local sourceFilter = HA.VendorMapPins:GetActiveSourceFilter()
    local continentCounts = BC:GetContinentVendorCounts(sourceFilter)

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
                local zoneCounts = BC:GetZoneVendorCounts(continentMapID, sourceFilter)
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
                            HA.VendorMapPins:DebugWorldMapProjectionSkip("world_zone_badge", zoneMapID, 947, reason)
                        end
                    end
                end
            end
        end
    end
end

function BadgeEmission:ShowContinentBadges(renderState)
    -- Toggle: zone-level badges spread across continents vs single continent totals
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.vendorTracer.worldMapZoneBadges then
        self:ShowZoneBadgesOnWorldMap(renderState)
        return
    end

    local continentCounts = BC:GetContinentVendorCounts(HA.VendorMapPins:GetActiveSourceFilter())

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
                    HA.VendorMapPins:DebugWorldMapProjectionSkip("continent_badge", continentMapID, 947, reason)
                end
            end
        end
    end
end
