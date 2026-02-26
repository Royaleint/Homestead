--[[
    Homestead - BadgeCalculation
    Zone/continent badge counts and collection status calculation

    Extracted from VendorMapPins.lua to reduce file size.
    Consumes canonical zone-to-continent mapping from HA.Constants, then builds
    collection caches and badge counts. All data flows through VendorFilter.

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

-------------------------------------------------------------------------------
-- Zone to Parent Map Mapping
-------------------------------------------------------------------------------
local zoneToContinent = (Constants and Constants.ZoneToContinentMap) or {}

-- Reverse index: continent → list of zone mapIDs (built once at load time)
-- Exposed as module field for VendorMapPins:RefreshMinimapPins() sibling zone lookup
BadgeCalculation.continentToZones = {}
for zoneMapID, contID in pairs(zoneToContinent) do
    if not BadgeCalculation.continentToZones[contID] then
        BadgeCalculation.continentToZones[contID] = {}
    end
    local t = BadgeCalculation.continentToZones[contID]
    t[#t + 1] = zoneMapID
end

function BadgeCalculation.GetContinentForZone(zoneMapID)
    return zoneToContinent[zoneMapID] or nil
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
local cachedZoneBadges = {}       -- [continentMapID] = zoneCounts table
local cachedContinentBadges = nil -- continentCounts table

-------------------------------------------------------------------------------
-- Ownership Helper
-------------------------------------------------------------------------------

-- Helper function to check if a specific item is owned
-- Delegates to CatalogStore:IsOwnedFresh() — cache + bags + live API
local function IsItemOwned(itemID)
    if not itemID then return false end
    if HA.CatalogStore then
        return HA.CatalogStore:IsOwnedFresh(itemID)
    end
    return false
end

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

local function BuildVendorFilterCacheKey(vendor, sourceFilter)
    return tostring(vendor.npcID) .. "|" .. NormalizeSourceFilter(sourceFilter)
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
    local hasUncollected = false
    local total, collected = 0, 0

    for itemID in pairs(items) do
        if ItemMatchesSourceFilter(itemID, sourceFilter) then
            hasMatchingItems = true
            total = total + 1
            if IsItemOwned(itemID) then
                collected = collected + 1
            else
                hasUncollected = true
            end
        end
    end

    -- No matching items under this filter is a known empty result, not unknown.
    if not hasMatchingItems then
        return {
            hasUncollectedState = false,
            collected = 0,
            total = 0,
        }
    end

    return {
        hasUncollectedState = hasUncollected,
        collected = collected,
        total = total,
    }
end

local function GetVendorStats(vendor, sourceFilter)
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

function BadgeCalculation:VendorHasUncollectedItems(vendor, sourceFilter)
    if not vendor or not vendor.npcID then return nil end

    local stats = GetVendorStats(vendor, sourceFilter)
    if stats.hasUncollectedState == "unknown" then
        return nil
    end

    return stats.hasUncollectedState == true
end

function BadgeCalculation:GetVendorCollectionCounts(vendor, sourceFilter)
    if not vendor or not vendor.npcID then return 0, 0 end

    local stats = GetVendorStats(vendor, sourceFilter)
    return stats.collected or 0, stats.total or 0
end

-------------------------------------------------------------------------------
-- Cache Invalidation
-------------------------------------------------------------------------------

function BadgeCalculation:InvalidateBadgeCache()
    wipe(cachedZoneBadges)
    cachedContinentBadges = nil
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

function BadgeCalculation:GetZoneVendorCounts(continentMapID)
    if cachedZoneBadges[continentMapID] then return cachedZoneBadges[continentMapID] end

    local zoneCounts = {}
    if not HA.VendorData then return zoneCounts end

    local allVendors = HA.VendorData:GetAllVendors()
    local showOpposite = VF.ShouldShowOppositeFaction()
    local showUnverified = VF.ShouldShowUnverifiedVendors()

    for _, vendor in ipairs(allVendors) do
        -- Include only vendors not hidden by scan state and visible under verification settings.
        if ShouldIncludeVendorInBadgeCounts(vendor)
                and not VF.ShouldHideVendor(vendor)
                and (showUnverified or VF.IsVendorVerified(vendor)) then
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
                            }
                        end

                        zoneCounts[zoneMapID].vendorCount = zoneCounts[zoneMapID].vendorCount + 1

                        if isOpposite then
                            zoneCounts[zoneMapID].oppositeFactionCount = zoneCounts[zoneMapID].oppositeFactionCount + 1
                            -- Track the opposite faction for this zone
                            if vendor.faction then
                                zoneCounts[zoneMapID].dominantFaction = vendor.faction
                            end
                        end

                        -- Direct stats lookup is intentional in this hot path.
                        -- Vendor validity is already gated above in this loop.
                        local stats = GetVendorStats(vendor, "all")
                        local hasUncollectedState = stats.hasUncollectedState
                        if hasUncollectedState == true then
                            zoneCounts[zoneMapID].uncollectedCount = zoneCounts[zoneMapID].uncollectedCount + 1
                        elseif hasUncollectedState == "unknown" then
                            zoneCounts[zoneMapID].unknownCount = zoneCounts[zoneMapID].unknownCount + 1
                        end
                        -- false means all collected, don't increment uncollected/unknown.

                        zoneCounts[zoneMapID].collectedItems = zoneCounts[zoneMapID].collectedItems + (stats.collected or 0)
                        zoneCounts[zoneMapID].totalItems = zoneCounts[zoneMapID].totalItems + (stats.total or 0)
                    end
                end
            end
        end
    end

    cachedZoneBadges[continentMapID] = zoneCounts
    return zoneCounts
end

function BadgeCalculation:GetContinentVendorCounts()
    if cachedContinentBadges then return cachedContinentBadges end

    local continentCounts = {}
    if not HA.VendorData then return continentCounts end

    local allVendors = HA.VendorData:GetAllVendors()
    local showOpposite = VF.ShouldShowOppositeFaction()
    local showUnverified = VF.ShouldShowUnverifiedVendors()

    for _, vendor in ipairs(allVendors) do
        -- Include only vendors not hidden by scan state and visible under verification settings.
        if ShouldIncludeVendorInBadgeCounts(vendor)
                and not VF.ShouldHideVendor(vendor)
                and (showUnverified or VF.IsVendorVerified(vendor)) then
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
                            }
                        end

                        continentCounts[continentMapID].vendorCount = continentCounts[continentMapID].vendorCount + 1

                        if isOpposite then
                            continentCounts[continentMapID].oppositeFactionCount = continentCounts[continentMapID].oppositeFactionCount + 1
                        end

                        -- Direct stats lookup is intentional in this hot path.
                        -- Vendor validity is already gated above in this loop.
                        local stats = GetVendorStats(vendor, "all")
                        local hasUncollectedState = stats.hasUncollectedState
                        if hasUncollectedState == true then
                            continentCounts[continentMapID].uncollectedCount = continentCounts[continentMapID].uncollectedCount + 1
                        elseif hasUncollectedState == "unknown" then
                            continentCounts[continentMapID].unknownCount = continentCounts[continentMapID].unknownCount + 1
                        end
                        -- false means all collected, don't increment uncollected/unknown.

                        continentCounts[continentMapID].collectedItems = continentCounts[continentMapID].collectedItems + (stats.collected or 0)
                        continentCounts[continentMapID].totalItems = continentCounts[continentMapID].totalItems + (stats.total or 0)
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
                }
            end
            local dest = continentCounts[destID]
            dest.vendorCount          = dest.vendorCount          + src.vendorCount
            dest.uncollectedCount     = dest.uncollectedCount     + src.uncollectedCount
            dest.unknownCount         = dest.unknownCount         + src.unknownCount
            dest.oppositeFactionCount = dest.oppositeFactionCount + src.oppositeFactionCount
            dest.collectedItems       = dest.collectedItems       + src.collectedItems
            dest.totalItems           = dest.totalItems           + src.totalItems
            continentCounts[srcID] = nil
        end
    end

    cachedContinentBadges = continentCounts
    return continentCounts
end

-------------------------------------------------------------------------------
-- Map Center Helpers
-------------------------------------------------------------------------------

-- Continents NOT physically on the Azeroth world map — skip their badges entirely.
BadgeCalculation.excludedContinents = {
    [572] = true,   -- Draenor (alternate dimension, HBD works at zone level)
    [1550] = true,  -- Shadowlands (afterlife dimension)
}

-- Continents whose vendor counts and zone badges roll into a parent continent.
-- Argus is accessed via Dalaran (Broken Isles) — logically part of BI on the world map.
BadgeCalculation.continentMergesInto = {
    [905] = 619,   -- Argus → Broken Isles
}

-- Off-world continents with manual positions on the Azeroth world map (mapID 947).
-- These are NOT in excludedContinents — they get badges via native pin fallback.
-- Argus zones (830, 882, 885) map to continent 905 in zoneToContinent.
BadgeCalculation.offWorldContinentPositions = {
    -- [905] removed — Argus counts merge into Broken Isles (continentMergesInto)
    -- [2537] removed — Midnight/Quel'Thalas handed to HBD; manual position was incorrect
}

function BadgeCalculation:GetContinentCenterOnWorldMap(continentMapID)
    -- Off-world continents use manual positions on the Azeroth world map
    local manualPos = self.offWorldContinentPositions[continentMapID]
    if manualPos then
        return manualPos
    end

    -- Use C_Map.GetMapRectOnMap to dynamically calculate continent position on world map
    -- This is the same approach used by GetZoneCenterOnMap() for zones on continents
    local AZEROTH_WORLD_MAP = 947
    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(continentMapID, AZEROTH_WORLD_MAP)
    if minX and maxX and minY and maxY then
        return { x = (minX + maxX) / 2, y = (minY + maxY) / 2 }
    end

    return nil
end

-- Manual zone center positions for cross-instance maps where GetMapRectOnMap returns nil.
-- Coordinates are normalized 0-1 on the parent continent map. Positions are approximate.
-- Only used as fallback when C_Map.GetMapRectOnMap() returns nil.
BadgeCalculation.manualZoneCenters = {
    -- Argus zones on Argus continent (905)
    [830] = { [905] = { x = 0.33, y = 0.60 } },  -- Krokuun
    [882] = { [905] = { x = 0.60, y = 0.65 } },  -- Eredath
    [885] = { [905] = { x = 0.68, y = 0.30 } },  -- Mac'Aree
    [831] = { [619] = { x = 0.84, y = 0.14 } },  -- The Vindicaar (Krokuun area, Argus — approximate, verify in-game)

    -- Legion class halls on Broken Isles (619) — fallback for instanced zones
    -- Physically on Broken Isles
    [739] = { [619] = { x = 0.35, y = 0.26 } },  -- Trueshot Lodge (Highmountain)
    [747] = { [619] = { x = 0.16, y = 0.50 } },  -- The Dreamgrove (Val'sharah)
    [647] = { [619] = { x = 0.40, y = 0.78 } },  -- Acherus: The Ebon Hold (above Broken Shore)
    [695] = { [619] = { x = 0.67, y = 0.16 } },  -- Skyhold (above Stormheim)
    -- Under/inside Dalaran
    [626] = { [619] = { x = 0.49, y = 0.44 } },  -- The Hall of Shadows (Dalaran sewers)
    [734] = { [619] = { x = 0.46, y = 0.48 } },  -- Hall of the Guardian (beneath Dalaran)
    -- Off-world, accessed via Dalaran portals — clustered near Dalaran
    [24]  = { [619] = { x = 0.52, y = 0.40 } },  -- Light's Hope Chapel (Paladin)
    [702] = { [619] = { x = 0.44, y = 0.40 } },  -- Netherlight Temple (Priest)
    [709] = { [619] = { x = 0.52, y = 0.50 } },  -- The Wandering Isle (Monk)
    [717] = { [619] = { x = 0.44, y = 0.52 } },  -- Dreadscar Rift (Warlock)
    [720] = { [619] = { x = 0.54, y = 0.45 } },  -- The Fel Hammer (Demon Hunter)
    [726] = { [619] = { x = 0.42, y = 0.45 } },  -- The Maelstrom (Shaman)
}

-- Notes shown in zone badge tooltips for special locations (class halls, etc.)
BadgeCalculation.zoneNotes = {
    -- Class halls physically on the Broken Isles
    [739] = "Hunter Order Hall — Trueshot Lodge in Highmountain",
    [747] = "Druid Order Hall — Dreamwalk spell",
    [647] = "Death Knight Order Hall — Death Gate spell",
    [695] = "Warrior Order Hall — Jump from Krasus' Landing, Dalaran",
    -- Class halls under/inside Dalaran
    [626] = "Rogue Order Hall — Entrance in Dalaran sewers",
    [734] = "Mage Order Hall — Portal from Dalaran",
    -- Class halls off-world, accessed via Dalaran
    [24]  = "Paladin Order Hall — Portal from Dalaran",
    [702] = "Priest Order Hall — Portal from Dalaran",
    [709] = "Monk Order Hall — Zen Pilgrimage spell",
    [717] = "Warlock Order Hall — Portal from Dalaran",
    [720] = "Demon Hunter Order Hall — Portal from Krasus' Landing, Dalaran",
    [726] = "Shaman Order Hall — Portal from Dalaran",
}

function BadgeCalculation:GetZoneCenterOnMap(zoneMapID, parentMapID)
    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(zoneMapID, parentMapID)
    -- Guard against degenerate rects (e.g. 0,0,0,0 returned for phased/instanced zones
    -- that the current character cannot access). In Lua, 0 is truthy, so we must
    -- explicitly reject a collapsed rect to avoid placing badges at (0, 0).
    if minX and maxX and minY and maxY and (minX ~= maxX or minY ~= maxY) then
        return { x = (minX + maxX) / 2, y = (minY + maxY) / 2 }
    end
    -- Fallback for cross-instance/phased maps (e.g. Argus zones on Argus continent,
    -- or Trueshot Lodge on Broken Isles for non-hunters)
    local manual = self.manualZoneCenters[zoneMapID]
    if manual and manual[parentMapID] then
        return manual[parentMapID]
    end
    return nil
end
