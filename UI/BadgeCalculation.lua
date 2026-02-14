--[[
    Homestead - BadgeCalculation
    Zone/continent badge counts and collection status calculation

    Extracted from VendorMapPins.lua to reduce file size.
    Owns zone-to-continent mapping, collection caches, and badge count
    computation. All data flows through VendorFilter for visibility checks.

    External callers should use VendorMapPins delegation wrappers
    (InvalidateAllCaches, InvalidateBadgeCache, GetVendorCollectionCounts)
    to ensure dedup guards are also reset.
]]

local addonName, HA = ...

local BadgeCalculation = {}
HA.BadgeCalculation = BadgeCalculation

-- VendorFilter reference (loaded before this file per TOC order)
local VF = HA.VendorFilter

-------------------------------------------------------------------------------
-- Zone to Parent Map Mapping
-------------------------------------------------------------------------------

local zoneToContinent = {
    -- The War Within / Khaz Algar (2274)
    [2339] = 2274, -- Dornogal
    [2248] = 2274, -- Isle of Dorn
    [2214] = 2274, -- The Ringing Deeps
    [2215] = 2274, -- Hallowfall
    [2213] = 2274, -- The City of Threads
    [2255] = 2274, -- Azj-Kahet
    [2338] = 2274, -- Smuggler's Coast
    [2346] = 2274, -- Undermine
    [2350] = 2274, -- Arcantina
    [2406] = 2274, -- Liberation of Undermine (dungeon)
    [2393] = 2274, -- Murder Row
    [2472] = 2274, -- Tazavesh (K'aresh)
    [2694] = 2274, -- Harandar
    [15958] = 2274, -- Voidstorm

    -- Housing Instances (mapped to Khaz Algar for TWW content)
    [2351] = 2274, -- Hollowed Halls (Housing)
    [2352] = 2274, -- Housing instance

    -- Dragon Isles (1978)
    [2022] = 1978, -- The Waking Shores
    [2023] = 1978, -- Ohn'ahran Plains
    [2024] = 1978, -- The Azure Span
    [2025] = 1978, -- Thaldraszus
    [2112] = 1978, -- Valdrakken
    [2133] = 1978, -- Zaralek Cavern
    [2151] = 1978, -- Forbidden Reach
    [2200] = 1978, -- Emerald Dream
    [2239] = 1978, -- Amirdrassil/Bel'ameth

    -- Shadowlands (1550)
    [1525] = 1550, -- Revendreth
    [1533] = 1550, -- Bastion
    [1536] = 1550, -- Maldraxxus
    [1543] = 1550, -- The Maw
    [1565] = 1550, -- Ardenweald
    [1670] = 1550, -- Oribos
    [1699] = 1550, -- Sinfall
    [1961] = 1550, -- Korthia

    -- Kul Tiras (876)
    [895] = 876,   -- Tiragarde Sound
    [896] = 876,   -- Drustvar
    [942] = 876,   -- Stormsong Valley
    [1161] = 876,  -- Boralus
    [1460] = 876,  -- Mechagon
    [1462] = 876,  -- Mechagon

    -- Zandalar (875)
    [862] = 875,   -- Zuldazar
    [863] = 875,   -- Nazmir
    [864] = 875,   -- Vol'dun
    [1164] = 875,  -- Zuldazar
    [1165] = 875,  -- Dazar'alor

    -- Broken Isles / Legion (619)
    [24] = 619,    -- Light's Hope Chapel (Paladin)
    [626] = 619,   -- The Hall of Shadows (Rogue)
    [627] = 619,   -- Dalaran (Legion)
    [628] = 619,   -- Dalaran - The Underbelly (sub-zone of 627)
    [630] = 619,   -- Azsuna
    [634] = 619,   -- Stormheim
    [641] = 619,   -- Val'sharah
    [647] = 619,   -- Acherus (Death Knight)
    [650] = 619,   -- Highmountain
    [652] = 619,   -- Thunder Totem (sub-zone of 650)
    [680] = 619,   -- Suramar
    [695] = 619,   -- Skyhold (Warrior)
    [702] = 619,   -- Netherlight Temple (Priest)
    [709] = 619,   -- Wandering Isle (Monk)
    [717] = 619,   -- Dreadscar Rift (Warlock)
    [720] = 619,   -- Fel Hammer (Demon Hunter)
    [726] = 619,   -- The Maelstrom (Shaman)
    [734] = 619,   -- Hall of the Guardian (Mage)
    [739] = 619,   -- Trueshot Lodge (Hunter)
    [745] = 619,   -- Trueshot Lodge (Hunter, alternate)
    [747] = 619,   -- The Dreamgrove (Druid)
    [750] = 619,   -- Thunder Totem (alternate mapID)
    [830] = 905,   -- Krokuun (Argus)
    [882] = 905,   -- Eredath (Argus)
    [885] = 905,   -- Mac'Aree (Argus)
    [940] = 905,   -- Mac'Aree (Argus)

    -- Draenor (572)
    [525] = 572,   -- Frostfire Ridge
    [535] = 572,   -- Talador
    [539] = 572,   -- Shadowmoon Valley (Draenor)
    [542] = 572,   -- Spires of Arak
    [534] = 572,   -- Tanaan Jungle
    [543] = 572,   -- Gorgrond
    [550] = 572,   -- Nagrand (Draenor)
    [582] = 572,   -- Lunarfall (Alliance Garrison)
    [590] = 572,   -- Frostwall (Horde Garrison)
    [622] = 572,   -- Stormshield
    [624] = 572,   -- Warspear

    -- Pandaria (424)
    [371] = 424,   -- The Jade Forest
    [376] = 424,   -- Valley of the Four Winds
    [379] = 424,   -- Kun-Lai Summit
    [388] = 424,   -- Townlong Steppes
    [390] = 424,   -- Vale of Eternal Blossoms
    [418] = 424,   -- Krasarang Wilds
    [504] = 424,   -- Isle of Thunder
    [554] = 424,   -- Timeless Isle
    [1530] = 424,  -- Shrine of Two Moons

    -- Northrend (113)
    [114] = 113,   -- Borean Tundra
    [115] = 113,   -- Dragonblight
    [116] = 113,   -- Grizzly Hills
    [117] = 113,   -- Howling Fjord
    [119] = 113,   -- Sholazar Basin
    [120] = 113,   -- The Storm Peaks
    [118] = 113,   -- Icecrown
    [121] = 113,   -- Zul'Drak
    [125] = 113,   -- Dalaran (Northrend)
    [127] = 113,   -- Crystalsong Forest

    -- Eastern Kingdoms (13)
    [17] = 13,     -- Blasted Lands
    [21] = 13,     -- Silverpine Forest
    [23] = 13,     -- Eastern Plaguelands
    [25] = 13,     -- Hillsbrad Foothills
    [27] = 13,     -- Dun Morogh
    [32] = 13,     -- Searing Gorge
    [36] = 13,     -- Burning Steppes
    [48] = 13,     -- Loch Modan
    [50] = 13,     -- Northern Stranglethorn
    [56] = 13,     -- Wetlands
    [57] = 13,     -- Duskwood
    [84] = 13,     -- Stormwind
    [87] = 13,     -- Ironforge
    [90] = 13,     -- Undercity
    [94] = 13,     -- Eversong Woods
    [95] = 13,     -- Ghostlands
    [110] = 13,    -- Silvermoon
    [217] = 13,    -- Gilneas
    [218] = 13,    -- Ruins of Gilneas
    [224] = 13,    -- Stranglethorn Vale
    [241] = 13,    -- Twilight Highlands
    [242] = 13,    -- Blackrock Depths (dungeon)
    [2437] = 13,   -- Zul'Aman
    [1186] = 13,   -- Blackrock Depths
    [2395] = 13,   -- Eversong Woods
    [2405] = 13,   -- Founder's Point (Stormwind)

    -- Kalimdor (12)
    [69] = 12,     -- Feralas / Darkmoon Island
    [70] = 12,     -- Dustwallow Marsh
    [71] = 12,     -- Tanaris
    [85] = 12,     -- Orgrimmar
    [88] = 12,     -- Thunder Bluff
    [89] = 12,     -- Darnassus
    [97] = 12,     -- Azuremyst Isle
    [407] = 12,    -- Darkmoon Island

    -- Outland (101)
    [102] = 101,   -- Zangarmarsh
    [107] = 101,   -- Nagrand (Outland)
    [111] = 101,   -- Shattrath

    -- Special Instances
    [369] = 13,    -- Bizmo's Brawlpub (Eastern Kingdoms)
    [503] = 12,    -- Brawl'gar Arena (Kalimdor)
    [1473] = 12,   -- Chamber of Heart (Silithus)
}

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

-------------------------------------------------------------------------------
-- Caches
-------------------------------------------------------------------------------

-- Cached uncollected status per vendor (invalidated on ownership changes)
local uncollectedCache = {}

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

-------------------------------------------------------------------------------
-- Collection Status
-------------------------------------------------------------------------------

function BadgeCalculation:VendorHasUncollectedItems(vendor)
    if not vendor or not vendor.npcID then return nil end

    -- Return cached result if available
    local cached = uncollectedCache[vendor.npcID]
    if cached ~= nil then
        -- Cache stores "unknown" string for nil results (nil can't be stored as a value)
        if cached == "unknown" then return nil end
        return cached
    end

    -- Get items from multiple sources:
    -- 1. Static data from VendorDatabase (vendor.items)
    -- 2. Dynamic data from VendorScanner (scannedVendors)

    local items = {}

    -- Add static items from vendor database
    -- New format: items can be plain integers OR tables with cost data
    if vendor.items and #vendor.items > 0 then
        for _, item in ipairs(vendor.items) do
            -- Handle both formats: plain number or table with cost
            local itemID = HA.VendorData:GetItemID(item)
            if itemID then
                items[itemID] = {itemID = itemID}
            end
        end
    end

    -- Add/merge scanned items from VendorScanner
    -- Check both original npcID and any corrected npcID
    if vendor.npcID and HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
        local scannedData = HA.Addon.db.global.scannedVendors[vendor.npcID]

        -- Also check if there's a corrected NPC ID for this vendor
        if not scannedData and vendor.name and HA.VendorScanner then
            local correctedID = HA.VendorScanner:GetCorrectedNPCID(vendor.name)
            if correctedID then
                scannedData = HA.Addon.db.global.scannedVendors[correctedID]
            end
        end

        local scannedItems = scannedData and (scannedData.items)
        if scannedItems then
            for _, item in ipairs(scannedItems) do
                if item.itemID then
                    items[item.itemID] = item
                end
            end
        end
    end

    -- If we have no item data at all, return nil to indicate "unknown status"
    local hasAnyItems = false
    for _ in pairs(items) do
        hasAnyItems = true
        break
    end

    if not hasAnyItems then
        uncollectedCache[vendor.npcID] = "unknown"
        return nil  -- Unknown - no item data available
    end

    -- Check if any items are uncollected
    for itemID, _ in pairs(items) do
        if not IsItemOwned(itemID) then
            uncollectedCache[vendor.npcID] = true
            return true  -- Has uncollected items
        end
    end

    uncollectedCache[vendor.npcID] = false
    return false  -- All items collected
end

function BadgeCalculation:GetVendorCollectionCounts(vendor)
    if not vendor or not vendor.npcID then return 0, 0 end

    local items = {}

    -- Static items from vendor database
    if vendor.items and #vendor.items > 0 then
        for _, item in ipairs(vendor.items) do
            local itemID = HA.VendorData:GetItemID(item)
            if itemID then
                items[itemID] = true
            end
        end
    end

    -- Scanned items from VendorScanner
    if vendor.npcID and HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
        local scannedData = HA.Addon.db.global.scannedVendors[vendor.npcID]
        if not scannedData and vendor.name and HA.VendorScanner then
            local correctedID = HA.VendorScanner:GetCorrectedNPCID(vendor.name)
            if correctedID then
                scannedData = HA.Addon.db.global.scannedVendors[correctedID]
            end
        end
        local scannedItems = scannedData and (scannedData.items)
        if scannedItems then
            for _, item in ipairs(scannedItems) do
                if item.itemID then
                    items[item.itemID] = true
                end
            end
        end
    end

    local total, collected = 0, 0
    for itemID in pairs(items) do
        total = total + 1
        if IsItemOwned(itemID) then
            collected = collected + 1
        end
    end
    return collected, total
end

-------------------------------------------------------------------------------
-- Cache Invalidation
-------------------------------------------------------------------------------

function BadgeCalculation:InvalidateBadgeCache()
    wipe(cachedZoneBadges)
    cachedContinentBadges = nil
end

function BadgeCalculation:InvalidateAllCaches()
    wipe(uncollectedCache)
    self:InvalidateBadgeCache()
end

-- Invalidate a specific vendor's uncollected cache entry
function BadgeCalculation:InvalidateVendorCache(npcID)
    if npcID then
        uncollectedCache[npcID] = nil
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
        -- Skip vendors that have been scanned and confirmed to have no decor items
        if VF.ShouldHideVendor(vendor) then
            -- Vendor is unreleased or was scanned with no housing decor - don't count
        elseif not showUnverified and not VF.IsVendorVerified(vendor) then
            -- Unverified vendor hidden by user setting - don't count
        else
            -- Get best coordinates (scanned preferred over static)
            local coords, zoneMapID = VF.GetBestVendorCoordinates(vendor)

            -- Only count vendors with valid coordinates
            if coords and zoneMapID then
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

                        local hasUncollected = self:VendorHasUncollectedItems(vendor)
                        if hasUncollected == true then
                            zoneCounts[zoneMapID].uncollectedCount = zoneCounts[zoneMapID].uncollectedCount + 1
                        elseif hasUncollected == nil then
                            zoneCounts[zoneMapID].unknownCount = zoneCounts[zoneMapID].unknownCount + 1
                        end
                        -- hasUncollected == false means all collected, don't increment anything
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
        -- Skip vendors that have been scanned and confirmed to have no decor items
        if VF.ShouldHideVendor(vendor) then
            -- Vendor is unreleased or was scanned with no housing decor - don't count
        elseif not showUnverified and not VF.IsVendorVerified(vendor) then
            -- Unverified vendor hidden by user setting - don't count
        else
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
                            }
                        end

                        continentCounts[continentMapID].vendorCount = continentCounts[continentMapID].vendorCount + 1

                        if isOpposite then
                            continentCounts[continentMapID].oppositeFactionCount = continentCounts[continentMapID].oppositeFactionCount + 1
                        end

                        local hasUncollected = self:VendorHasUncollectedItems(vendor)
                        if hasUncollected == true then
                            continentCounts[continentMapID].uncollectedCount = continentCounts[continentMapID].uncollectedCount + 1
                        elseif hasUncollected == nil then
                            continentCounts[continentMapID].unknownCount = continentCounts[continentMapID].unknownCount + 1
                        end
                        -- hasUncollected == false means all collected, don't increment anything
                    end
                end
            end
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

-- Off-world continents with manual positions on the Azeroth world map (mapID 947).
-- These are NOT in excludedContinents — they get badges via native pin fallback.
-- Argus zones (830, 882, 885) map to continent 905 in zoneToContinent.
BadgeCalculation.offWorldContinentPositions = {
    [905] = { x = 0.82, y = 0.18 },  -- Argus (separate planet, upper-right of world map)
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

-- Child continents: shown as aggregate badges on the parent continent map.
-- e.g. when viewing Broken Isles (619), also show a badge for Argus (905).
-- Each entry has the child continent ID and its position on the parent map (normalized 0-1).
BadgeCalculation.childContinents = {
    [619] = {
        { id = 905, x = 0.85, y = 0.12 },  -- Argus (upper-right of Broken Isles map)
    },
}

function BadgeCalculation:GetZoneCenterOnMap(zoneMapID, parentMapID)
    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(zoneMapID, parentMapID)
    if minX and maxX and minY and maxY then
        return { x = (minX + maxX) / 2, y = (minY + maxY) / 2 }
    end
    -- Fallback for cross-instance maps (e.g. Argus zones on Argus continent)
    local manual = self.manualZoneCenters[zoneMapID]
    if manual and manual[parentMapID] then
        return manual[parentMapID]
    end
    return nil
end
