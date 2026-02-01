--[[
    Homestead - VendorMapPins
    World map integration for housing decor vendor locations

    Uses HereBeDragons-Pins-2.0 library for reliable map pin management.
    Applies SetScale() to counter canvas scaling for proper icon sizes.

    Features:
    - Zone view: Shows pin icons at vendor locations
    - Continent view: Shows zone badges with vendor counts
    - World map: Shows continent badges with vendor counts
    - Pin tooltips: Shows vendor name, items sold, collection status
    - Click to set waypoint (with TomTom support if available)
    - Minimap pins: Shows nearby vendors HandyNotes-style (with elevation arrows)
]]

local addonName, HA = ...

-- Create VendorMapPins module
local VendorMapPins = {}
HA.VendorMapPins = VendorMapPins

-- Load HereBeDragons
local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

-- Local references
local Constants = HA.Constants
local VendorData = HA.VendorData

-- State
local isInitialized = false
local pinsEnabled = true

-- Pin frame pools (we create the actual frames, HBD manages their position)
local vendorPinFrames = {}
local badgePinFrames = {}
local minimapPinFrames = {}

-- Scale factor to counter canvas scaling (adjust if icons are too big/small)
local ICON_SCALE = 0.4
-- Minimap icon size - 12 is HandyNotes standard, we use 14 for visibility
local MINIMAP_ICON_SIZE = 14

-- Minimap pins enabled state
local minimapPinsEnabled = true

-------------------------------------------------------------------------------
-- Zone to Parent Map Mapping
-------------------------------------------------------------------------------

local zoneToContinent = {
    -- The War Within / Khaz Algar (2274)
    [2339] = 2274, -- Dornogal
    [2248] = 2274, -- Isle of Dorn
    [2214] = 2274, -- The Ringing Deeps
    [2215] = 2274, -- Hallowfall
    [2255] = 2274, -- Azj-Kahet
    [2346] = 2274, -- Undermine
    [2406] = 2274, -- Liberation of Undermine (dungeon)
    [2472] = 2274, -- Tazavesh (K'aresh)

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

    -- Kul Tiras (876)
    [895] = 876,   -- Tiragarde Sound
    [896] = 876,   -- Drustvar
    [942] = 876,   -- Stormsong Valley
    [1161] = 876,  -- Boralus
    [1462] = 876,  -- Mechagon

    -- Zandalar (875)
    [862] = 875,   -- Zuldazar
    [863] = 875,   -- Nazmir
    [864] = 875,   -- Vol'dun
    [1165] = 875,  -- Dazar'alor

    -- Broken Isles / Legion (619)
    [24] = 619,    -- Light's Hope Chapel (Paladin)
    [626] = 619,   -- The Hall of Shadows (Rogue)
    [627] = 619,   -- Dalaran (Legion)
    [630] = 619,   -- Azsuna
    [634] = 619,   -- Stormheim
    [641] = 619,   -- Val'sharah
    [647] = 619,   -- Acherus (Death Knight)
    [650] = 619,   -- Highmountain
    [680] = 619,   -- Suramar
    [695] = 619,   -- Skyhold (Warrior)
    [702] = 619,   -- Netherlight Temple (Priest)
    [709] = 619,   -- Wandering Isle (Monk)
    [717] = 619,   -- Dreadscar Rift (Warlock)
    [720] = 619,   -- Fel Hammer (Demon Hunter)
    [726] = 619,   -- The Maelstrom (Shaman)
    [734] = 619,   -- Hall of the Guardian (Mage)
    [739] = 619,   -- Trueshot Lodge (Hunter)
    [747] = 619,   -- The Dreamgrove (Druid)
    [830] = 619,   -- Krokuun (Argus)
    [882] = 619,   -- Eredath (Argus)
    [885] = 619,   -- Mac'Aree (Argus)

    -- Draenor (572)
    [525] = 572,   -- Frostfire Ridge
    [535] = 572,   -- Talador
    [539] = 572,   -- Shadowmoon Valley (Draenor)
    [542] = 572,   -- Spires of Arak
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

    -- Northrend (113)
    [114] = 113,   -- Borean Tundra
    [115] = 113,   -- Dragonblight
    [116] = 113,   -- Grizzly Hills
    [117] = 113,   -- Howling Fjord
    [119] = 113,   -- Sholazar Basin
    [120] = 113,   -- The Storm Peaks
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

    -- Kalimdor (12)
    [69] = 12,     -- Feralas / Darkmoon Island
    [70] = 12,     -- Dustwallow Marsh
    [85] = 12,     -- Orgrimmar
    [88] = 12,     -- Thunder Bluff
    [89] = 12,     -- Darnassus
    [407] = 12,    -- Darkmoon Island

    -- Special Instances
    [369] = 13,    -- Bizmo's Brawlpub (Eastern Kingdoms)
    [503] = 12,    -- Brawl'gar Arena (Kalimdor)
    [1473] = 12,   -- Chamber of Heart (Silithus)
}

local function GetContinentForZone(zoneMapID)
    return zoneToContinent[zoneMapID] or nil
end

-------------------------------------------------------------------------------
-- Pin Frame Creation
-------------------------------------------------------------------------------

local function CreateVendorPinFrame(vendor, isOppositeFaction)
    local frame = CreateFrame("Frame", nil, UIParent)

    -- Apply scale to counter canvas scaling
    frame:SetScale(ICON_SCALE)

    -- Base size (will appear smaller due to scale)
    local baseSize = 32
    frame:SetSize(baseSize, baseSize)
    frame:EnableMouse(true)

    -- Dark circular background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetPoint("CENTER")
    frame.bg:SetSize(baseSize + 4, baseSize + 4)
    frame.bg:SetAtlas("auctionhouse-itemicon-border-white", false)
    frame.bg:SetVertexColor(0.1, 0.08, 0.02, 1)

    -- Golden ring border (dimmed for opposite faction)
    frame.ring = frame:CreateTexture(nil, "BORDER")
    frame.ring:SetPoint("CENTER")
    frame.ring:SetSize(baseSize + 8, baseSize + 8)
    frame.ring:SetAtlas("auctionhouse-itemicon-border-artifact", false)
    if isOppositeFaction then
        frame.ring:SetVertexColor(0.5, 0.5, 0.5, 0.8)  -- Dim the ring for opposite faction
    end

    -- Housing icon (dimmed for opposite faction)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("CENTER")
    frame.icon:SetSize(baseSize - 8, baseSize - 8)
    frame.icon:SetAtlas("housing-dashboard-homestone-icon", true)
    if isOppositeFaction then
        frame.icon:SetVertexColor(0.6, 0.6, 0.6, 0.9)  -- Slightly dimmed
    end

    -- Faction emblem for opposite faction vendors
    if isOppositeFaction and vendor.faction then
        frame.factionEmblem = frame:CreateTexture(nil, "ARTWORK", nil, 2)
        frame.factionEmblem:SetSize(16, 16)
        frame.factionEmblem:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, 6)

        if vendor.faction == "Alliance" then
            frame.factionEmblem:SetAtlas("ui-frame-alliancecrest-portrait", true)
        elseif vendor.faction == "Horde" then
            frame.factionEmblem:SetAtlas("ui-frame-hordecrest-portrait", true)
        end
    end

    -- Store vendor data and faction status
    frame.vendor = vendor
    frame.isOppositeFaction = isOppositeFaction

    -- Tooltip handlers
    frame:SetScript("OnEnter", function(self)
        VendorMapPins:ShowVendorTooltip(self, self.vendor)
    end)
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            VendorMapPins:SetWaypointToVendor(self.vendor)
        end
    end)

    return frame
end

local function CreateBadgePinFrame(badgeData)
    local frame = CreateFrame("Frame", nil, UIParent)

    -- Apply scale to counter canvas scaling
    frame:SetScale(ICON_SCALE)

    -- Base size (will appear smaller due to scale)
    local baseSize = 32
    frame:SetSize(baseSize, baseSize)
    frame:EnableMouse(true)

    -- Determine if this zone/continent is primarily opposite faction
    local isOppositeFactionOnly = badgeData.oppositeFactionCount and badgeData.oppositeFactionCount > 0
        and badgeData.oppositeFactionCount == badgeData.vendorCount

    -- Dark circular background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetPoint("CENTER")
    frame.bg:SetSize(baseSize + 4, baseSize + 4)
    frame.bg:SetAtlas("auctionhouse-itemicon-border-white", false)
    frame.bg:SetVertexColor(0.1, 0.08, 0.02, 1)

    -- Golden ring border (dimmed if opposite faction only)
    frame.ring = frame:CreateTexture(nil, "BORDER")
    frame.ring:SetPoint("CENTER")
    frame.ring:SetSize(baseSize + 8, baseSize + 8)
    frame.ring:SetAtlas("auctionhouse-itemicon-border-artifact", false)
    if isOppositeFactionOnly then
        frame.ring:SetVertexColor(0.6, 0.6, 0.6, 0.8)  -- Dim the ring for opposite faction
    end

    -- Housing icon
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("CENTER")
    frame.icon:SetSize(baseSize - 8, baseSize - 8)
    frame.icon:SetAtlas("housing-dashboard-homestone-icon", true)
    if isOppositeFactionOnly then
        frame.icon:SetVertexColor(0.7, 0.7, 0.7, 0.9)  -- Slightly dimmed
    end

    -- Faction emblem (shown if zone has opposite faction vendors)
    if badgeData.dominantFaction or (badgeData.oppositeFactionCount and badgeData.oppositeFactionCount > 0) then
        frame.factionEmblem = frame:CreateTexture(nil, "ARTWORK", nil, 2)
        frame.factionEmblem:SetSize(14, 14)
        frame.factionEmblem:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)

        -- Determine which faction emblem to show
        local factionToShow = badgeData.dominantFaction
        if not factionToShow then
            -- For continent badges, show the opposite faction
            local playerFaction = UnitFactionGroup("player")
            factionToShow = playerFaction == "Alliance" and "Horde" or "Alliance"
        end

        if factionToShow == "Alliance" then
            frame.factionEmblem:SetAtlas("ui-frame-alliancecrest-portrait", true)
        elseif factionToShow == "Horde" then
            frame.factionEmblem:SetAtlas("ui-frame-hordecrest-portrait", true)
        else
            frame.factionEmblem:Hide()
        end
    end

    -- Count text background for better visibility
    frame.countBg = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    frame.countBg:SetColorTexture(0, 0, 0, 0.8)
    frame.countBg:SetSize(20, 16)
    frame.countBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 6, -6)

    -- Count text (scaled up to compensate for frame scale)
    frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal", 2)
    frame.count:SetPoint("CENTER", frame.countBg, "CENTER", 0, 0)
    local fontPath, _, fontFlags = frame.count:GetFont()
    frame.count:SetFont(fontPath, 14, "OUTLINE")

    -- Store badge data
    frame.badgeData = badgeData

    -- Update appearance
    frame.count:SetText(tostring(badgeData.vendorCount or 0))
    if isOppositeFactionOnly then
        -- Opposite faction only - show in faction color but dimmed
        local factionColor = badgeData.dominantFaction == "Alliance" and {0.2, 0.4, 0.8} or {0.8, 0.2, 0.2}
        frame.count:SetTextColor(factionColor[1], factionColor[2], factionColor[3])
    elseif badgeData.uncollectedCount and badgeData.uncollectedCount > 0 then
        frame.count:SetTextColor(0.2, 1, 0.2)  -- Green = has uncollected items
    elseif badgeData.unknownCount and badgeData.unknownCount > 0 then
        frame.count:SetTextColor(1, 0.82, 0)  -- Yellow = unknown status (no item data)
    else
        frame.count:SetTextColor(0.5, 0.5, 0.5)  -- Gray = all collected
    end

    -- Tooltip handlers
    frame:SetScript("OnEnter", function(self)
        VendorMapPins:ShowZoneBadgeTooltip(self, self.badgeData)
    end)
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.badgeData and self.badgeData.mapID then
            WorldMapFrame:SetMapID(self.badgeData.mapID)
        end
    end)

    return frame
end

local function CreateMinimapPinFrame(vendor, isOppositeFaction)
    -- Parent to UIParent for consistency with world map pins
    -- HereBeDragons handles positioning relative to minimap
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(MINIMAP_ICON_SIZE, MINIMAP_ICON_SIZE)
    frame:EnableMouse(true)

    -- Use BACKGROUND strata so player arrow renders on top
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(2)

    -- Simple housing icon only - no decorative borders for minimap
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()
    frame.icon:SetAtlas("housing-dashboard-homestone-icon", true)
    if isOppositeFaction then
        frame.icon:SetVertexColor(0.5, 0.5, 0.5, 0.8)
    end

    -- Store vendor data
    frame.vendor = vendor
    frame.isOppositeFaction = isOppositeFaction

    -- Simple tooltip on hover
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(self.vendor.name, 1, 1, 1)
        if self.vendor.zone then
            GameTooltip:AddLine(self.vendor.zone, 0.7, 0.7, 0.7)
        end
        if self.isOppositeFaction then
            GameTooltip:AddLine("Opposite faction", 0.8, 0.3, 0.3)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click to set waypoint", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            VendorMapPins:SetWaypointToVendor(self.vendor)
        end
    end)

    return frame
end

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

-- Check if coordinates are placeholder values (0.5, 0.5 indicates unverified location)
local function AreValidCoordinates(x, y)
    if not x or not y then
        return false
    end
    -- Skip placeholder coordinates (exactly 0.5, 0.5)
    if x == 0.5 and y == 0.5 then
        return false
    end
    -- Also skip coordinates of exactly 0.50 (string comparison edge case)
    if x == 0.50 and y == 0.50 then
        return false
    end
    return true
end

-- Check if a vendor has been scanned and confirmed to have NO decor items
-- Returns true if vendor should be hidden (was scanned with no decor)
-- Returns false if vendor should be shown (has decor OR hasn't been scanned yet)
local function IsVendorScannedWithNoDecor(vendor)
    if not vendor or not vendor.npcID then
        return false
    end

    -- Check scanned vendor data
    if HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
        local npcID = vendor.npcID
        local scannedData = HA.Addon.db.global.scannedVendors[npcID]

        if scannedData then
            -- hasDecor can be: true (has decor), false (no decor), or nil (old data before flag was added)
            -- Only hide if explicitly false (not nil, which means unknown/old data)
            if scannedData.hasDecor == false then
                if HA.Addon.db.profile.debug then
                    HA.Addon:Debug(string.format("Vendor %s (NPC %d): HIDING - scanned with hasDecor=false",
                        vendor.name or "Unknown", npcID))
                end
                return true
            elseif scannedData.hasDecor == true then
                -- Explicitly has decor, show it
                if HA.Addon.db.profile.debug then
                    HA.Addon:Debug(string.format("Vendor %s (NPC %d): showing - scanned with hasDecor=true",
                        vendor.name or "Unknown", npcID))
                end
                return false
            else
                -- hasDecor is nil (old scan data before flag was added)
                -- Check if decor table is empty as fallback
                if scannedData.decor and #scannedData.decor == 0 then
                    if HA.Addon.db.profile.debug then
                        HA.Addon:Debug(string.format("Vendor %s (NPC %d): HIDING - old scan data with empty decor table",
                            vendor.name or "Unknown", npcID))
                    end
                    return true
                end
            end
        end
    end

    return false
end

-- Helper to extract coordinates from vendor data (handles both old and new formats)
-- Old format: vendor.coords = {x = 0.5, y = 0.5}
-- New format: vendor.x = 0.5, vendor.y = 0.5
local function GetVendorXY(vendor)
    if not vendor then return nil, nil end
    -- New format: x, y directly on vendor
    if vendor.x and vendor.y then
        return vendor.x, vendor.y
    end
    -- Old format: coords table
    if vendor.coords then
        return vendor.coords.x, vendor.coords.y
    end
    return nil, nil
end

-- Check if a vendor has valid coordinates (static data only - legacy function)
local function HasValidCoordinates(vendor)
    local x, y = GetVendorXY(vendor)
    if not x or not y then
        return false
    end
    return AreValidCoordinates(x, y)
end

-- Get the best coordinates for a vendor, preferring scanned data over static data
-- Returns: coords table {x, y}, mapID, source ("scanned" or "static")
local function GetBestVendorCoordinates(vendor)
    if not vendor or not vendor.npcID then
        return nil, nil, nil
    end

    -- First check scanned vendor data (uses old coords format)
    if HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
        local scannedData = HA.Addon.db.global.scannedVendors[vendor.npcID]
        if scannedData and scannedData.coords then
            local scannedX = scannedData.coords.x
            local scannedY = scannedData.coords.y
            local scannedMapID = scannedData.mapID

            -- Use scanned coords if they're valid and mapID matches (or we have a mapID)
            if AreValidCoordinates(scannedX, scannedY) and scannedMapID then
                -- Debug output
                if HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug then
                    local staticX, staticY = GetVendorXY(vendor)
                    staticX = staticX or "nil"
                    staticY = staticY or "nil"
                    if staticX ~= scannedX or staticY ~= scannedY then
                        HA.Addon:Debug(string.format("Vendor %s (%d): using SCANNED coords (%.2f, %.2f) instead of static (%.2f, %.2f)",
                            vendor.name or "Unknown", vendor.npcID,
                            scannedX, scannedY,
                            tonumber(staticX) or 0, tonumber(staticY) or 0))
                    end
                end
                return {x = scannedX, y = scannedY}, scannedMapID, "scanned"
            end
        end
    end

    -- Fall back to static vendor data (handles both old and new formats)
    local staticX, staticY = GetVendorXY(vendor)
    if staticX and staticY and AreValidCoordinates(staticX, staticY) and vendor.mapID then
        return {x = staticX, y = staticY}, vendor.mapID, "static"
    end

    return nil, nil, nil
end

-- Check if vendor has any valid coordinates (scanned or static)
local function VendorHasValidCoordinates(vendor)
    local coords, mapID, source = GetBestVendorCoordinates(vendor)
    return coords ~= nil and mapID ~= nil
end

-- Check if vendor is accessible to player's faction
function VendorMapPins:CanAccessVendor(vendor)
    if not vendor.faction or vendor.faction == "Neutral" then
        return true
    end
    local playerFaction = UnitFactionGroup("player")
    return vendor.faction == playerFaction
end

-- Check if vendor is opposite faction (not neutral, not player's faction)
function VendorMapPins:IsOppositeFaction(vendor)
    if not vendor.faction or vendor.faction == "Neutral" then
        return false
    end
    local playerFaction = UnitFactionGroup("player")
    return vendor.faction ~= playerFaction
end

-- Get the setting for showing opposite faction vendors
local function ShouldShowOppositeFaction()
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.vendorTracer then
        return HA.Addon.db.profile.vendorTracer.showOppositeFaction
    end
    return true  -- Default to showing
end

-- Helper function to cache an owned item
local function CacheOwnedItem(itemID, name)
    if not itemID then return end
    if HA.Addon and HA.Addon.db then
        if not HA.Addon.db.global.ownedDecor then
            HA.Addon.db.global.ownedDecor = {}
        end
        if not HA.Addon.db.global.ownedDecor[itemID] then
            HA.Addon.db.global.ownedDecor[itemID] = {
                name = name,
                firstSeen = time(),
                lastSeen = time(),
            }
        end
    end
end

-- Helper function to check if a specific item is owned
local function IsItemOwned(itemID)
    if not itemID then return false end

    -- First check our persistent cache (most reliable after /reload)
    if HA.Addon and HA.Addon.db and HA.Addon.db.global.ownedDecor then
        if HA.Addon.db.global.ownedDecor[itemID] then
            return true
        end
    end

    -- Check if item is in player's bags (newly purchased items)
    local bagCount = _G.GetItemCount and _G.GetItemCount(itemID, true) or 0
    if bagCount > 0 then
        CacheOwnedItem(itemID, nil)
        return true
    end

    -- Try the live API if available (unreliable after /reload, but works when catalog is open)
    if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
        -- Create a simple item link to check
        local itemLink = "item:" .. itemID
        local success, info = pcall(function()
            return C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, true)
        end)

        if success and info then
            -- Check ownership indicators
            local quantity = info.quantity or 0
            local numPlaced = info.numPlaced or 0
            local remainingRedeemable = info.remainingRedeemable or 0

            if quantity > 0 or numPlaced > 0 or remainingRedeemable > 0 then
                CacheOwnedItem(itemID, info.name)
                return true
            end

            -- Check entrySubtype (2 = OwnedModifiedStack, 3 = OwnedUnmodifiedStack)
            local entrySubtype = nil
            if info.entryID and type(info.entryID) == "table" then
                entrySubtype = info.entryID.entrySubtype
                if not entrySubtype then
                    for k, v in pairs(info.entryID) do
                        if k == "entrySubtype" then
                            entrySubtype = v
                            break
                        end
                    end
                end
            end

            if entrySubtype and entrySubtype >= 2 then
                CacheOwnedItem(itemID, info.name)
                return true
            end

            -- Check isOwned field directly if present
            if info.isOwned then
                CacheOwnedItem(itemID, info.name)
                return true
            end
        end
    end

    return false
end

function VendorMapPins:VendorHasUncollectedItems(vendor)
    -- Get items from multiple sources:
    -- 1. Static data from VendorDatabase (vendor.items)
    -- 2. Dynamic data from VendorScanner (scannedVendors)

    local items = {}

    -- Add static items from vendor database (new format: items = {itemID, itemID, ...})
    if vendor.items and #vendor.items > 0 then
        for _, itemID in ipairs(vendor.items) do
            -- In new format, item IS the itemID (a number)
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

        if scannedData and scannedData.decor then
            for _, item in ipairs(scannedData.decor) do
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
        return nil  -- Unknown - no item data available
    end

    -- Check if any items are uncollected
    for itemID, _ in pairs(items) do
        if not IsItemOwned(itemID) then
            return true  -- Has uncollected items
        end
    end

    return false  -- All items collected
end

function VendorMapPins:GetZoneVendorCounts(continentMapID)
    local zoneCounts = {}
    if not HA.VendorData then return zoneCounts end

    local allVendors = HA.VendorData:GetAllVendors()
    local showOpposite = ShouldShowOppositeFaction()

    for _, vendor in ipairs(allVendors) do
        -- Skip vendors that have been scanned and confirmed to have no decor items
        if IsVendorScannedWithNoDecor(vendor) then
            -- Vendor was scanned and has no housing decor - don't count
        else
            -- Get best coordinates (scanned preferred over static)
            local coords, zoneMapID, source = GetBestVendorCoordinates(vendor)

            -- Only count vendors with valid coordinates
            if coords and zoneMapID then
                local continent = GetContinentForZone(zoneMapID)

                if continent == continentMapID then
                    local canAccess = self:CanAccessVendor(vendor)
                    local isOpposite = self:IsOppositeFaction(vendor)

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

    return zoneCounts
end

function VendorMapPins:GetContinentVendorCounts()
    local continentCounts = {}
    if not HA.VendorData then return continentCounts end

    local allVendors = HA.VendorData:GetAllVendors()
    local showOpposite = ShouldShowOppositeFaction()

    for _, vendor in ipairs(allVendors) do
        -- Skip vendors that have been scanned and confirmed to have no decor items
        if IsVendorScannedWithNoDecor(vendor) then
            -- Vendor was scanned and has no housing decor - don't count
        else
            -- Get best coordinates (scanned preferred over static)
            local coords, zoneMapID, source = GetBestVendorCoordinates(vendor)

            -- Only count vendors with valid coordinates
            if coords and zoneMapID then
                local continentMapID = GetContinentForZone(zoneMapID)

                if continentMapID then
                    local canAccess = self:CanAccessVendor(vendor)
                    local isOpposite = self:IsOppositeFaction(vendor)

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

    return continentCounts
end

function VendorMapPins:GetContinentCenterOnWorldMap(continentMapID)
    -- Continents that exist in different dimensions and are NOT on the Azeroth world map
    -- These should never show badges on the world map
    local excludedContinents = {
        [572] = true,   -- Draenor (alternate dimension)
        [1550] = true,  -- Shadowlands (afterlife dimension)
        [830] = true,   -- Krokuun (Argus)
        [882] = true,   -- Mac'Aree (Argus)
        [885] = true,   -- Antoran Wastes (Argus)
    }

    if excludedContinents[continentMapID] then
        return nil
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

function VendorMapPins:GetZoneCenterOnMap(zoneMapID, parentMapID)
    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(zoneMapID, parentMapID)
    if minX and maxX and minY and maxY then
        return { x = (minX + maxX) / 2, y = (minY + maxY) / 2 }
    end
    return nil
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

    local isOpposite = self:IsOppositeFaction(vendor)

    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(vendor.name, 1, 1, 1)

    if vendor.zone then
        GameTooltip:AddLine(vendor.zone, 0.7, 0.7, 0.7)
    end

    if vendor.faction and vendor.faction ~= "Neutral" then
        local factionColor = vendor.faction == "Alliance" and {0, 0.44, 0.87} or {0.77, 0.12, 0.23}
        GameTooltip:AddLine(vendor.faction, unpack(factionColor))
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

    -- Add static items (new format: items = {itemID, itemID, ...})
    if vendor.items then
        for _, itemID in ipairs(vendor.items) do
            -- In new format, item IS the itemID (a number)
            if itemID and not itemsSeen[itemID] then
                itemsSeen[itemID] = true
                table.insert(allItems, {itemID = itemID})
            end
        end
    end

    -- Add scanned items (old format: decor = {{itemID=..., name=...}, ...})
    if vendor.npcID and HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
        local scannedData = HA.Addon.db.global.scannedVendors[vendor.npcID]
        if scannedData and scannedData.decor then
            for _, item in ipairs(scannedData.decor) do
                if item.itemID and not itemsSeen[item.itemID] then
                    itemsSeen[item.itemID] = true
                    table.insert(allItems, item)
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
                -- Debug: Check if item is in cache
                if HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug then
                    local inCache = HA.Addon.db.global.ownedDecor and HA.Addon.db.global.ownedDecor[item.itemID]
                    HA.Addon:Debug("Item", item.itemID, itemName, "owned:", isOwned, "inCache:", inCache and "yes" or "no")
                end
            end

            if isOwned then
                collectedCount = collectedCount + 1
            else
                table.insert(uncollectedItems, itemName)
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
                GameTooltip:AddLine(string.format("  ... and %d collected item(s)", collectedCount), 0.5, 0.5, 0.5)
            end
        end

        GameTooltip:AddLine(" ")
        local statusColor = collectedCount == #allItems and {0.5, 0.5, 0.5} or {0, 1, 0}
        GameTooltip:AddLine(string.format("Collected: %d/%d", collectedCount, #allItems), unpack(statusColor))
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
    GameTooltip:AddLine(string.format("Decor Vendors: %d", zoneInfo.vendorCount), 1, 0.82, 0)

    -- Show faction breakdown if there are opposite faction vendors
    if zoneInfo.oppositeFactionCount and zoneInfo.oppositeFactionCount > 0 then
        local accessibleCount = zoneInfo.vendorCount - zoneInfo.oppositeFactionCount
        local playerFaction = UnitFactionGroup("player")
        local oppositeFaction = playerFaction == "Alliance" and "Horde" or "Alliance"

        if accessibleCount > 0 then
            GameTooltip:AddLine(string.format("  %s: %d", playerFaction, accessibleCount), 0.7, 0.7, 0.7)
        end

        local factionColor = oppositeFaction == "Alliance" and {0.2, 0.4, 0.8} or {0.8, 0.2, 0.2}
        GameTooltip:AddLine(string.format("  %s: %d", oppositeFaction, zoneInfo.oppositeFactionCount),
            factionColor[1], factionColor[2], factionColor[3])
    end

    -- Show collection status
    if zoneInfo.uncollectedCount and zoneInfo.uncollectedCount > 0 then
        GameTooltip:AddLine(string.format("With uncollected items: %d", zoneInfo.uncollectedCount), 0, 1, 0)
    end

    if zoneInfo.unknownCount and zoneInfo.unknownCount > 0 then
        GameTooltip:AddLine(string.format("Unknown status: %d (visit to scan)", zoneInfo.unknownCount), 1, 0.82, 0)
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

    -- Add sibling zones in the same continent for cross-zone visibility
    -- This is what makes pins appear when you're near a zone boundary
    local continentID = GetContinentForZone(playerMapID)
    if continentID then
        for zoneMapID, contID in pairs(zoneToContinent) do
            if contID == continentID and not mapsToCheckSet[zoneMapID] then
                mapsToCheck[#mapsToCheck + 1] = zoneMapID
                mapsToCheckSet[zoneMapID] = true
            end
        end
    end

    local showOpposite = ShouldShowOppositeFaction()
    local addedVendors = {}  -- Prevent duplicate pins for same vendor

    for _, mapID in ipairs(mapsToCheck) do
        local vendors = HA.VendorData:GetVendorsInMap(mapID)
        if vendors then
            for _, vendor in ipairs(vendors) do
                -- Use npcID for deduplication (vendor tables may be different objects)
                if vendor.npcID and not addedVendors[vendor.npcID] then
                    -- Skip vendors that have been scanned and confirmed to have no decor items
                    if IsVendorScannedWithNoDecor(vendor) then
                        -- Vendor was scanned and has no housing decor - don't show pin
                    else
                        -- Get best coordinates (scanned preferred over static)
                        local coords, vendorMapID, source = GetBestVendorCoordinates(vendor)

                        -- Only show pins for vendors with valid coordinates
                        if coords and vendorMapID then
                            local canAccess = self:CanAccessVendor(vendor)
                            local isOpposite = self:IsOppositeFaction(vendor)

                            -- Show vendor if accessible OR if opposite faction and setting enabled
                            if canAccess or (isOpposite and showOpposite) then
                                local frame = CreateMinimapPinFrame(vendor, isOpposite)
                                minimapPinFrames[vendor] = frame
                                addedVendors[vendor.npcID] = true

                                -- AddMinimapIconMap parameters:
                                -- ref: unique identifier for this addon's pins
                                -- icon: the frame to display
                                -- mapID: the map the coordinates are relative to
                                -- x, y: normalized coordinates (0-1)
                                -- showArrow: true = show arrow when out of range (elevation indicator)
                                -- floatOnEdge: true = pin stays at minimap edge when far (HandyNotes style)
                                HBDPins:AddMinimapIconMap("HomesteadMinimapVendors", frame, vendorMapID,
                                    coords.x, coords.y,
                                    true,   -- showArrow: enables up/down elevation arrows
                                    true)   -- floatOnEdge: keeps icon at edge when out of range
                            end
                        end
                    end
                end
            end
        end
    end

    -- Debug output
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug then
        local count = 0
        for _ in pairs(addedVendors) do count = count + 1 end
        HA.Addon:Debug("RefreshMinimapPins: playerMapID=" .. playerMapID .. 
            ", continentID=" .. (continentID or "nil") ..
            ", mapsChecked=" .. #mapsToCheck .. 
            ", vendorsAdded=" .. count)
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

    -- Helper function to process a vendor
    local function ProcessVendor(vendor)
        if not vendor or not vendor.npcID then return end
        if addedVendors[vendor.npcID] then return end

        -- Skip vendors that have been scanned and confirmed to have no decor items
        if IsVendorScannedWithNoDecor(vendor) then
            -- Mark as processed to avoid re-checking in scanned vendors loop
            addedVendors[vendor.npcID] = true
            return
        end

        -- Get best coordinates (scanned preferred over static)
        local coords, vendorMapID, source = GetBestVendorCoordinates(vendor)

        -- Only show pins for vendors with valid coordinates on THIS map
        -- This is the key check - vendorMapID comes from scanned data if available
        if coords and vendorMapID == mapID then
            local canAccess = self:CanAccessVendor(vendor)
            local isOpposite = self:IsOppositeFaction(vendor)

            -- Show vendor if accessible OR if opposite faction and setting enabled
            if canAccess or (isOpposite and showOpposite) then
                local frame = CreateVendorPinFrame(vendor, isOpposite)
                vendorPinFrames[vendor] = frame
                addedVendors[vendor.npcID] = true

                -- Add to world map using HereBeDragons
                HBDPins:AddWorldMapIconMap("HomesteadVendors", frame, mapID,
                    coords.x, coords.y,
                    HBD_PINS_WORLDMAP_SHOW_PARENT)
            end
        end
    end

    -- First, process vendors from static database for this map
    local staticVendors = HA.VendorData:GetVendorsInMap(mapID)
    if staticVendors then
        for _, vendor in ipairs(staticVendors) do
            local shouldSkip = false
            local skipReason = nil

            -- Check 1: Skip if vendor scanned with no decor (hasDecor=false)
            if IsVendorScannedWithNoDecor(vendor) then
                shouldSkip = true
                skipReason = "no decor"
            end

            -- Check 2: Skip if vendor was scanned on a DIFFERENT map
            if not shouldSkip and HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
                local scannedData = HA.Addon.db.global.scannedVendors[vendor.npcID]
                if scannedData and scannedData.mapID and scannedData.mapID ~= mapID then
                    shouldSkip = true
                    skipReason = string.format("scanned on map %d", scannedData.mapID)
                end
            end

            if shouldSkip then
                -- Mark as processed to prevent re-check in scanned vendors loop
                addedVendors[vendor.npcID] = true
                if HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug then
                    HA.Addon:Debug(string.format("Skipping static vendor %s (%d) on map %d - %s",
                        vendor.name or "Unknown", vendor.npcID, mapID, skipReason or "unknown"))
                end
            else
                ProcessVendor(vendor)
            end
        end
    end

    -- Second, check ALL scanned vendors - they may have been scanned on a different map
    -- than their static entry (e.g., Quackenbush: static=Stormwind, scanned=BrawlersGuild)
    if HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
        for npcID, scannedData in pairs(HA.Addon.db.global.scannedVendors) do
            -- Only process if this scanned vendor's mapID matches the current map
            -- AND we haven't already added this vendor from static data
            if scannedData.mapID == mapID and not addedVendors[npcID] then
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
                }

                local frame = CreateBadgePinFrame(badgeData)
                badgePinFrames[zoneMapID] = frame

                -- Add badge to the continent map
                HBDPins:AddWorldMapIconMap("HomesteadVendors", frame, continentMapID,
                    zoneCenter.x, zoneCenter.y,
                    HBD_PINS_WORLDMAP_SHOW_CONTINENT)
            end
        end
    end
end

function VendorMapPins:ShowContinentBadges()
    local continentCounts = self:GetContinentVendorCounts()

    -- Continents that exist in different dimensions and are NOT on the Azeroth world map
    local excludedContinents = {
        [572] = true,   -- Draenor (alternate dimension)
        [1550] = true,  -- Shadowlands (afterlife dimension)
        [830] = true,   -- Krokuun (Argus)
        [882] = true,   -- Mac'Aree (Argus)
        [885] = true,   -- Antoran Wastes (Argus)
    }

    for continentMapID, continentData in pairs(continentCounts) do
        -- Skip continents not on Azeroth world map
        if continentData.vendorCount > 0 and not excludedContinents[continentMapID] then
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

            -- Place badge at center of the continent map (0.5, 0.5)
            -- and let HereBeDragons handle the world map positioning
            -- by using the continent's mapID with SHOW_WORLD flag
            HBDPins:AddWorldMapIconMap("HomesteadVendors", frame, continentMapID,
                0.5, 0.5,
                HBD_PINS_WORLDMAP_SHOW_WORLD)
        end
    end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function VendorMapPins:Enable()
    pinsEnabled = true
    if isInitialized then
        self:RefreshPins()
    end
end

function VendorMapPins:Disable()
    pinsEnabled = false
    self:ClearAllPins()
end

function VendorMapPins:Toggle()
    pinsEnabled = not pinsEnabled
    if pinsEnabled then
        self:RefreshPins()
    else
        self:ClearAllPins()
    end
    return pinsEnabled
end

function VendorMapPins:IsEnabled()
    return pinsEnabled
end

function VendorMapPins:EnableMinimapPins()
    minimapPinsEnabled = true
    if isInitialized then
        self:RefreshMinimapPins()
    end
end

function VendorMapPins:DisableMinimapPins()
    minimapPinsEnabled = false
    self:ClearMinimapPins()
end

function VendorMapPins:ToggleMinimapPins()
    minimapPinsEnabled = not minimapPinsEnabled
    if minimapPinsEnabled then
        self:RefreshMinimapPins()
    else
        self:ClearMinimapPins()
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

    -- Hook WorldMapFrame to refresh pins when map changes
    WorldMapFrame:HookScript("OnShow", function()
        self:RefreshPins()
    end)

    hooksecurefunc(WorldMapFrame, "SetMapID", function()
        -- Small delay to let the map update first
        C_Timer.After(0, function()
            self:RefreshPins()
        end)
    end)

    -- Listen for vendor scan events to refresh pins with new data
    if HA.Events then
        HA.Events:RegisterCallback("VENDOR_SCANNED", function(vendorRecord)
            -- Refresh pins if the world map is currently open
            if WorldMapFrame:IsShown() then
                C_Timer.After(0.1, function()
                    self:RefreshPins()
                end)
            end
            -- Also refresh minimap pins
            C_Timer.After(0.1, function()
                self:RefreshMinimapPins()
            end)
        end)

        -- Also listen for ownership cache updates
        HA.Events:RegisterCallback("OWNERSHIP_UPDATED", function()
            if WorldMapFrame:IsShown() then
                C_Timer.After(0.1, function()
                    self:RefreshPins()
                end)
            end
        end)
    end

    -- Register for MERCHANT_CLOSED to refresh pins after visiting a vendor
    local merchantFrame = CreateFrame("Frame")
    merchantFrame:RegisterEvent("MERCHANT_CLOSED")
    merchantFrame:SetScript("OnEvent", function()
        -- Small delay to ensure scanned data is saved
        C_Timer.After(0.3, function()
            if WorldMapFrame:IsShown() then
                self:RefreshPins()
            end
            self:RefreshMinimapPins()
        end)
    end)

    -- Register for zone change events to update minimap pins
    local zoneFrame = CreateFrame("Frame")
    zoneFrame:RegisterEvent("ZONE_CHANGED")
    zoneFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    zoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    zoneFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    zoneFrame:SetScript("OnEvent", function(self, event)
        -- Small delay to ensure map data is available
        C_Timer.After(0.5, function()
            VendorMapPins:RefreshMinimapPins()
        end)
    end)

    isInitialized = true

    -- Initial minimap pin refresh
    C_Timer.After(1, function()
        self:RefreshMinimapPins()
    end)

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
