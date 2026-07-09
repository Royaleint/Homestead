--[[
    Homestead - BadgeCalculation
    Zone/continent badge counts and collection status calculation

    Extracted from VendorMapPins.lua to reduce file size.
    Collection caches and badge counts. Geography tables and coordinate
    projection delegated to MapPinProvider. All data flows through VendorFilter.

    External callers should use VendorMapPins delegation wrappers
    (InvalidateAllCaches, InvalidateBadgeCache, GetVendorCollectionCounts)
    to ensure dedup guards are also reset.
]]

local _, HA = ...

local BadgeCalculation = {}
HA.BadgeCalculation = BadgeCalculation

-- VendorFilter reference (loaded before this file per TOC order)
local VF = HA.VendorFilter
local Constants = HA.Constants
local MPP = HA.MapPinProvider

-------------------------------------------------------------------------------
-- Zone to Parent Map Mapping (delegated to MapPinProvider)
-------------------------------------------------------------------------------
BadgeCalculation.continentToZones = MPP.continentToZones

function BadgeCalculation.GetContinentForZone(zoneMapID)
    return MPP.GetContinentForZone(zoneMapID)
end

-- Resolve vertically-sibling zones to a canonical mapID.
-- The "above" sibling is canonical (e.g., Dalaran 627 absorbs Underbelly 628).
-- Returns input mapID unchanged if it has no siblings or is already canonical.
function BadgeCalculation.GetCanonicalZoneMapID(zoneMapID)
    if not Constants or not Constants.VerticalSiblings then
        return zoneMapID
    end
    local siblings = Constants.VerticalSiblings[zoneMapID]
    if not siblings then
        return zoneMapID
    end
    for siblingMapID, direction in pairs(siblings) do
        if direction == "above" then
            return siblingMapID
        end
    end
    return zoneMapID
end

-------------------------------------------------------------------------------
-- Caches
-------------------------------------------------------------------------------

-- Cached per-vendor stats keyed by "npcID|sourceFilter".
-- hasUncollectedState stores true / false / "unknown".
local vendorStatsCache = {}

-- Cached badge counts (invalidated on ownership/scan/settings changes)
-- Keyed by "continentMapID|sourceFilter" for zone badges, sourceFilter for continent badges.
local cachedZoneBadges = {}
local cachedContinentBadges = {}

local function ShouldIncludeVendorInBadgeCounts(vendor)
    if not vendor or not vendor.endeavor then
        return true
    end

    if HA.EndeavorsData and HA.EndeavorsData.IsVendorActive then
        return HA.EndeavorsData:IsVendorActive(vendor)
    end

    return true
end

-- Normalize source filter token used in cache keys and filtering checks.
local function NormalizeSourceFilter(sourceFilter)
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

-- HS-158/160 §1/H3: availability (promotion expiry) is day-stamped at the
-- SourceManager layer, but these caches are otherwise only invalidated by
-- ownership/scan/settings EVENTS — a vendor's stats computed before midnight
-- would keep reading the stale unobtainable classification until an
-- unrelated event fired. Folding the server date into every availability-
-- derived cache key here makes them expire naturally at server midnight,
-- no timers required. Falls back to a stable placeholder if the API is
-- unavailable so caching still works (just without the day-of-month split).
local function GetAvailabilityDateStamp()
    local SM = HA.SourceManager
    if SM and SM.GetServerDateStamp then
        return SM:GetServerDateStamp() or "unknown"
    end
    return "unknown"
end

local function BuildVendorFilterCacheKey(vendor, sourceFilter)
    return tostring(vendor.npcID) .. "|" .. NormalizeSourceFilter(sourceFilter) .. "|" .. GetAvailabilityDateStamp()
end

local function ItemMatchesSourceFilter(itemID, sourceFilter)
    local normalizedFilter = NormalizeSourceFilter(sourceFilter)
    if normalizedFilter == "all" then
        return true
    end

    local SM = HA.SourceManager
    if SM and SM.ItemMatchesSourceFilter then
        -- Vendor-scoped context: all vendor inventory items are vendor-eligible.
        return SM:ItemMatchesSourceFilter(itemID, normalizedFilter, true)
    end

    return false
end

-------------------------------------------------------------------------------
-- Collection Status
-------------------------------------------------------------------------------

local UNKNOWN_VENDOR_STATS = {
    hasUncollectedState = "unknown",
    collected = 0,
    purchasable = 0,
    locked = 0,
    unverified = 0,
    unobtainable = 0,
    blockers = nil,
    total = 0,
}

local function BuildVendorStats(vendor, sourceFilter)
    -- Keep a defensive guard here because badge hot paths read stats directly.
    if not vendor or not vendor.npcID then
        return UNKNOWN_VENDOR_STATS
    end

    -- Merge static + scanned items from shared VendorData helper.
    -- Returned map is key-only: {[itemID] = true}. Values are intentionally unused.
    local items = HA.VendorData and HA.VendorData.GetMergedItemSet
        and HA.VendorData:GetMergedItemSet(vendor)
        or {}

    -- If we have no item data at all, status is "unknown" and counts are zero.
    if next(items) == nil then
        return UNKNOWN_VENDOR_STATS
    end

    local hasMatchingItems = false
    local total, collected, purchasable, locked = 0, 0, 0, 0
    local unobtainable = 0
    local provisionalUnverified = 0
    local hasAnyVerifiableRequirements = false
    local lockedBlockerCounts = {}

    local SM = HA.SourceManager

    for itemID in pairs(items) do
        local presentation = nil
        if SM and SM.GetItemPresentation then
            presentation = SM:GetItemPresentation(itemID, {
                context = "badge",
                npcID = vendor.npcID,
                sourceFilter = sourceFilter,
                isVendorContext = true,
            })
        end

        local matchesSourceFilter = presentation and presentation.matchesSourceFilter
            or (not presentation and ItemMatchesSourceFilter(itemID, sourceFilter))

        if matchesSourceFilter then
            hasMatchingItems = true

            local state = presentation and presentation.availabilityState or "purchasable"
            local isUnverified = presentation and presentation.isUnverified or false
            local hasVerifiableRequirement = presentation and presentation.hasVerifiableRequirement or false
            local blockerLabels = presentation and presentation.blockerLabels or nil

            local isOwned = presentation and presentation.isOwned
            if not presentation and HA.CatalogStore and HA.CatalogStore.IsOwnedFresh then
                isOwned = HA.CatalogStore:IsOwnedFresh(itemID) == true
            end

            if isOwned then
                -- Owned items always count toward collected/total, even if
                -- the underlying requirement (e.g. a promotion) is also
                -- unobtainable for other players — the player already has it.
                collected = collected + 1
                total = total + 1
            elseif state == "unobtainable" then
                -- HS-158/160 §3/decision 4: unowned unobtainable items
                -- (promotion-gated, live or expired) are EXCLUDED from total
                -- so collected/total can reach completion. This must be
                -- checked before the locked/purchasable split below.
                unobtainable = unobtainable + 1
            else
                total = total + 1

                if isUnverified then
                    provisionalUnverified = provisionalUnverified + 1
                elseif hasVerifiableRequirement then
                    hasAnyVerifiableRequirements = true
                end

                if state == "locked" then
                    locked = locked + 1
                    if blockerLabels then
                        for _, blockerLabel in ipairs(blockerLabels) do
                            lockedBlockerCounts[blockerLabel] = (lockedBlockerCounts[blockerLabel] or 0) + 1
                        end
                    end
                else
                    purchasable = purchasable + 1
                end
            end
        end
    end

    -- No matching items under this filter is a known empty result, not unknown.
    if not hasMatchingItems then
        return {
            hasUncollectedState = false,
            collected = 0,
            purchasable = 0,
            locked = 0,
            unverified = 0,
            unobtainable = 0,
            blockers = nil,
            total = 0,
        }
    end

    -- Sort blockers by count descending, then alphabetically for stability.
    local blockers = nil
    if next(lockedBlockerCounts) ~= nil then
        blockers = {}
        for label, count in pairs(lockedBlockerCounts) do
            blockers[#blockers + 1] = {
                label = label,
                count = count,
            }
        end
        table.sort(blockers, function(a, b)
            if a.count ~= b.count then
                return a.count > b.count
            end
            return a.label < b.label
        end)
    end

    return {
        hasUncollectedState = (purchasable + locked) > 0,
        collected = collected,
        purchasable = purchasable,
        locked = locked,
        -- Only report unverified when the vendor has at least some verifiable data.
        -- Pure no-data vendors stay optimistic with zero unverified.
        unverified = hasAnyVerifiableRequirements and provisionalUnverified or 0,
        unobtainable = unobtainable,
        blockers = blockers,
        total = total,
    }
end

-- Public vendor stats accessor with caching. All UI consumers should use
-- this instead of re-deriving counts independently.
function BadgeCalculation:GetVendorStats(vendor, sourceFilter)
    if not vendor or not vendor.npcID then
        return UNKNOWN_VENDOR_STATS
    end

    local cacheKey = BuildVendorFilterCacheKey(vendor, sourceFilter)
    local cached = vendorStatsCache[cacheKey]
    if cached then
        return cached
    end

    local stats = BuildVendorStats(vendor, sourceFilter)
    vendorStatsCache[cacheKey] = stats
    return stats
end

-- Local alias for internal callers (aggregate builders) that need
-- the same caching without going through the colon-method dispatch.
local function GetVendorStats(vendor, sourceFilter)
    return BadgeCalculation:GetVendorStats(vendor, sourceFilter)
end

function BadgeCalculation:VendorHasUncollectedItems(vendor, sourceFilter)
    if not vendor or not vendor.npcID then return nil end

    local stats = GetVendorStats(vendor, sourceFilter)
    if stats.hasUncollectedState == "unknown" then
        return nil
    end

    return stats.hasUncollectedState == true
end

-- Backward-compatible wrapper: returns collected, total only.
function BadgeCalculation:GetVendorCollectionCounts(vendor, sourceFilter)
    if not vendor or not vendor.npcID then return 0, 0 end

    local stats = self:GetVendorStats(vendor, sourceFilter)
    return stats.collected or 0, stats.total or 0
end

-- Format count text with inline color escapes: green collected / white total / red locked.
-- Falls back to collected/total when locked == 0.
-- Shared by PinFrameFactory and MapSidePanel.
function BadgeCalculation.FormatCountText(collected, total, locked)
    local ownedText = string.format("|cFF00FF00%d|r", collected or 0)
    local totalText = string.format("|cFFFFFFFF%d|r", total or 0)

    if locked and locked > 0 then
        return ownedText .. "/" .. totalText .. "/" .. string.format("|cFFFF4040%d|r", locked)
    end

    return ownedText .. "/" .. totalText
end

-- Format the tooltip summary line: "Collected: X/Y | Locked: Z".
-- Adds the line directly to the given tooltip. Shared by all vendor/zone tooltips.
-- Optional unverified count shown on a second line when > 0.
function BadgeCalculation.AddSummaryLine(tooltip, collected, total, locked, unverified)
    collected = collected or 0
    total = total or 0
    locked = locked or 0
    unverified = unverified or 0

    if total == 0 then return end

    if locked > 0 then
        tooltip:AddLine(string.format(
            "|cFF00FF00Collected|r: %d/%d | |cFFFF4040Locked|r: %d",
            collected, total, locked
        ), 1, 1, 1)
    else
        tooltip:AddLine(string.format(
            "|cFF00FF00Collected|r: %d/%d",
            collected, total
        ), 1, 1, 1)
    end

    if unverified > 0 then
        tooltip:AddLine(string.format("(%d unverified)", unverified), 1.0, 0.82, 0.0)
    end
end

-------------------------------------------------------------------------------
-- Cache Invalidation
-------------------------------------------------------------------------------

function BadgeCalculation:InvalidateBadgeCache()
    wipe(cachedZoneBadges)
    wipe(cachedContinentBadges)
end

function BadgeCalculation:InvalidateAllCaches()
    wipe(vendorStatsCache)
    self:InvalidateBadgeCache()
end

-- Invalidate all cached vendor stats entries for a specific NPC ID.
function BadgeCalculation:InvalidateVendorCache(npcID)
    if npcID then
        local prefix = tostring(npcID) .. "|"
        for key in pairs(vendorStatsCache) do
            if type(key) == "string" and key:sub(1, #prefix) == prefix then
                vendorStatsCache[key] = nil
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Badge Count Computation
-------------------------------------------------------------------------------

function BadgeCalculation:GetZoneVendorCounts(continentMapID, sourceFilter)
    sourceFilter = NormalizeSourceFilter(sourceFilter)
    local cacheKey = tostring(continentMapID) .. "|" .. sourceFilter .. "|" .. GetAvailabilityDateStamp()
    if cachedZoneBadges[cacheKey] then return cachedZoneBadges[cacheKey] end

    local zoneCounts = {}
    if not HA.VendorData then return zoneCounts end

    local allVendors = HA.VendorData:GetAllVendors()
    local showOpposite = VF.ShouldShowOppositeFaction()

    for _, vendor in ipairs(allVendors) do
        if ShouldIncludeVendorInBadgeCounts(vendor)
                and not VF.ShouldHideVendor(vendor) then
            -- Get best coordinates (scanned preferred over static)
            local coords, zoneMapID = VF.GetBestVendorCoordinates(vendor)

            -- Badge zone override: count vendor under its accessible map (e.g. Dalaran portal)
            -- rather than its inaccessible instance zone. Decoupled from vendor.portal so this
            -- works independently if the portal pin feature is absent or reverted.
            if vendor.badgeMapID then
                zoneMapID = vendor.badgeMapID
            end

            -- Only count vendors with valid coordinates
            if coords and zoneMapID then
                -- Merge vertically-stacked sibling zones into one summary row.
                zoneMapID = BadgeCalculation.GetCanonicalZoneMapID(zoneMapID)
                local continent = BadgeCalculation.GetContinentForZone(zoneMapID)

                if continent == continentMapID then
                    local canAccess = VF.CanAccessVendor(vendor)
                    local isOpposite = VF.IsOppositeFaction(vendor)

                    -- Include vendor if accessible OR if opposite faction and setting enabled
                    if canAccess or (isOpposite and showOpposite) then
                        if not zoneCounts[zoneMapID] then
                            local mapInfo = C_Map.GetMapInfo(zoneMapID)
                            zoneCounts[zoneMapID] = {
                                zoneName = mapInfo and mapInfo.name or "Unknown",
                                vendorCount = 0,
                                uncollectedCount = 0,
                                unknownCount = 0,
                                oppositeFactionCount = 0,
                                dominantFaction = nil,  -- Will be set to "Alliance", "Horde", or nil (mixed/neutral)
                                collectedItems = 0,
                                totalItems = 0,
                                lockedItems = 0,
                                unverifiedItems = 0,
                                unobtainableItems = 0,
                            }
                        end

                        -- Direct stats lookup is intentional in this hot path.
                        -- Vendor validity is already gated above in this loop.
                        local stats = GetVendorStats(vendor, sourceFilter)

                        -- HS-018: gate vendor-context counters on the vendor actually
                        -- contributing at least one item that passes the filter. Prevents
                        -- "N vendors / 0 items" degenerate badges under non-vendor filters.
                        -- For filter == "all" or "vendor" every accessible vendor contributes
                        -- >= 1 item, so this is a no-op vs. prior behavior.
                        if (stats.total or 0) > 0 then
                            zoneCounts[zoneMapID].vendorCount = zoneCounts[zoneMapID].vendorCount + 1

                            if isOpposite then
                                zoneCounts[zoneMapID].oppositeFactionCount = zoneCounts[zoneMapID].oppositeFactionCount + 1
                                -- Track the opposite faction for this zone
                                if vendor.faction then
                                    zoneCounts[zoneMapID].dominantFaction = vendor.faction
                                end
                            end

                            local hasUncollectedState = stats.hasUncollectedState
                            if hasUncollectedState == true then
                                zoneCounts[zoneMapID].uncollectedCount = zoneCounts[zoneMapID].uncollectedCount + 1
                            elseif hasUncollectedState == "unknown" then
                                zoneCounts[zoneMapID].unknownCount = zoneCounts[zoneMapID].unknownCount + 1
                            end
                            -- false means all collected, don't increment uncollected/unknown.

                            zoneCounts[zoneMapID].collectedItems = zoneCounts[zoneMapID].collectedItems + (stats.collected or 0)
                            zoneCounts[zoneMapID].totalItems = zoneCounts[zoneMapID].totalItems + (stats.total or 0)
                            zoneCounts[zoneMapID].lockedItems = zoneCounts[zoneMapID].lockedItems + (stats.locked or 0)
                            zoneCounts[zoneMapID].unverifiedItems = zoneCounts[zoneMapID].unverifiedItems + (stats.unverified or 0)
                            zoneCounts[zoneMapID].unobtainableItems = zoneCounts[zoneMapID].unobtainableItems + (stats.unobtainable or 0)
                        end
                    end
                end
            end
        end
    end

    cachedZoneBadges[cacheKey] = zoneCounts
    return zoneCounts
end

function BadgeCalculation:GetContinentVendorCounts(sourceFilter)
    sourceFilter = NormalizeSourceFilter(sourceFilter)
    local cacheKey = sourceFilter .. "|" .. GetAvailabilityDateStamp()
    if cachedContinentBadges[cacheKey] then return cachedContinentBadges[cacheKey] end

    local continentCounts = {}
    if not HA.VendorData then return continentCounts end

    local allVendors = HA.VendorData:GetAllVendors()
    local showOpposite = VF.ShouldShowOppositeFaction()

    for _, vendor in ipairs(allVendors) do
        if ShouldIncludeVendorInBadgeCounts(vendor)
                and not VF.ShouldHideVendor(vendor) then
            -- Get best coordinates (scanned preferred over static)
            local coords, zoneMapID = VF.GetBestVendorCoordinates(vendor)

            -- Only count vendors with valid coordinates
            if coords and zoneMapID then
                local continentMapID = BadgeCalculation.GetContinentForZone(zoneMapID)

                if continentMapID then
                    local canAccess = VF.CanAccessVendor(vendor)
                    local isOpposite = VF.IsOppositeFaction(vendor)

                    -- Include vendor if accessible OR if opposite faction and setting enabled
                    if canAccess or (isOpposite and showOpposite) then
                        if not continentCounts[continentMapID] then
                            local mapInfo = C_Map.GetMapInfo(continentMapID)
                            continentCounts[continentMapID] = {
                                continentName = mapInfo and mapInfo.name or "Unknown",
                                vendorCount = 0,
                                uncollectedCount = 0,
                                unknownCount = 0,
                                oppositeFactionCount = 0,
                                collectedItems = 0,
                                totalItems = 0,
                                lockedItems = 0,
                                unverifiedItems = 0,
                                unobtainableItems = 0,
                            }
                        end

                        -- Direct stats lookup is intentional in this hot path.
                        -- Vendor validity is already gated above in this loop.
                        local stats = GetVendorStats(vendor, sourceFilter)

                        -- HS-018: gate vendor-context counters on filter contribution
                        -- (see GetZoneVendorCounts for rationale; same behavior at
                        -- continent scope).
                        if (stats.total or 0) > 0 then
                            continentCounts[continentMapID].vendorCount = continentCounts[continentMapID].vendorCount + 1

                            if isOpposite then
                                continentCounts[continentMapID].oppositeFactionCount = continentCounts[continentMapID].oppositeFactionCount + 1
                            end

                            local hasUncollectedState = stats.hasUncollectedState
                            if hasUncollectedState == true then
                                continentCounts[continentMapID].uncollectedCount = continentCounts[continentMapID].uncollectedCount + 1
                            elseif hasUncollectedState == "unknown" then
                                continentCounts[continentMapID].unknownCount = continentCounts[continentMapID].unknownCount + 1
                            end
                            -- false means all collected, don't increment uncollected/unknown.

                            continentCounts[continentMapID].collectedItems = continentCounts[continentMapID].collectedItems + (stats.collected or 0)
                            continentCounts[continentMapID].totalItems = continentCounts[continentMapID].totalItems + (stats.total or 0)
                            continentCounts[continentMapID].lockedItems = continentCounts[continentMapID].lockedItems + (stats.locked or 0)
                            continentCounts[continentMapID].unverifiedItems = continentCounts[continentMapID].unverifiedItems + (stats.unverified or 0)
                            continentCounts[continentMapID].unobtainableItems = continentCounts[continentMapID].unobtainableItems + (stats.unobtainable or 0)
                        end
                    end
                end
            end
        end
    end

    -- Roll child continent counts into their parent (e.g. Argus → Broken Isles)
    for srcID, destID in pairs(BadgeCalculation.continentMergesInto) do
        local src = continentCounts[srcID]
        if src then
            if not continentCounts[destID] then
                local mapInfo = C_Map.GetMapInfo(destID)
                continentCounts[destID] = {
                    continentName = mapInfo and mapInfo.name or "Unknown",
                    vendorCount = 0, uncollectedCount = 0, unknownCount = 0,
                    oppositeFactionCount = 0, collectedItems = 0, totalItems = 0,
                    lockedItems = 0, unverifiedItems = 0, unobtainableItems = 0,
                }
            end
            local dest = continentCounts[destID]
            dest.vendorCount          = dest.vendorCount          + src.vendorCount
            dest.uncollectedCount     = dest.uncollectedCount     + src.uncollectedCount
            dest.unknownCount         = dest.unknownCount         + src.unknownCount
            dest.oppositeFactionCount = dest.oppositeFactionCount + src.oppositeFactionCount
            dest.collectedItems       = dest.collectedItems       + src.collectedItems
            dest.totalItems           = dest.totalItems           + src.totalItems
            dest.lockedItems          = dest.lockedItems          + src.lockedItems
            dest.unverifiedItems      = dest.unverifiedItems      + src.unverifiedItems
            dest.unobtainableItems    = dest.unobtainableItems    + (src.unobtainableItems or 0)
            continentCounts[srcID] = nil
        end
    end

    cachedContinentBadges[cacheKey] = continentCounts
    return continentCounts
end

-------------------------------------------------------------------------------
-- Map Center Helpers (delegated to MapPinProvider)
-------------------------------------------------------------------------------

BadgeCalculation.excludedContinents = MPP.excludedContinents
BadgeCalculation.continentMergesInto = MPP.continentMergesInto
BadgeCalculation.continentZoneBadgesOnParent = MPP.continentZoneBadgesOnParent
BadgeCalculation.continentZoneBadgeExclusionsOnParent = MPP.continentZoneBadgeExclusionsOnParent
BadgeCalculation.offWorldContinentPositions = MPP.offWorldContinentPositions
BadgeCalculation.manualZoneCenters = MPP.manualZoneCenters
BadgeCalculation.zoneNotes = MPP.zoneNotes

function BadgeCalculation:GetContinentCenterOnWorldMap(continentMapID)
    return MPP:GetContinentCenterOnWorldMap(continentMapID)
end

function BadgeCalculation:GetZoneCenterOnMap(zoneMapID, parentMapID)
    return MPP:GetZoneCenterOnMap(zoneMapID, parentMapID)
end

-------------------------------------------------------------------------------
-- Event-Driven Cache Invalidation
-------------------------------------------------------------------------------

if HA.Events then
    HA.Events:RegisterCallback("SOURCE_CACHES_INVALIDATED", function()
        BadgeCalculation:InvalidateAllCaches()
    end)
end
