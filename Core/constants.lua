--[[
    Homestead - Constants
    Defines icons, colors, text strings, and configuration defaults

    A complete housing collection, vendor, and progress tracker for WoW
]]

local _, HA = ...

-- Addon namespace
HA.Constants = {}
local Constants = HA.Constants

-------------------------------------------------------------------------------
-- Version Info
-------------------------------------------------------------------------------
Constants.VERSION = "1.6.0"
Constants.ADDON_NAME = "Homestead"
Constants.ADDON_SHORT = "HS"

-------------------------------------------------------------------------------
-- Icon Definitions
-- These represent the various states a decor item can be in
-- Using WoW housing-style icons where available
-------------------------------------------------------------------------------
Constants.Icons = {
    -- Collection status icons (using housing/furniture style icons)
    COLLECTED = "Interface\\RaidFrame\\ReadyCheck-Ready",               -- Green checkmark
    COLLECTED_PLACED = "Interface\\ICONS\\INV_Misc_Furniture_Chair_03", -- Placed furniture
    NOT_COLLECTED = "Interface\\RaidFrame\\ReadyCheck-NotReady",        -- Red X

    -- Source type icons (shown when not collected)
    PURCHASABLE = "Interface\\GossipFrame\\VendorGossipIcon",           -- Gold bag (vendor)
    CRAFTABLE = "Interface\\ICONS\\INV_Misc_Furniture_Anvil_01",        -- Crafting anvil
    ACHIEVEMENT_REWARD = "Interface\\AchievementFrame\\UI-Achievement-TinyShield",
    DROP_SOURCE = "Interface\\ICONS\\INV_Misc_Bone_Skull_01",
    QUEST_REWARD = "Interface\\GossipFrame\\AvailableQuestIcon",
    REPUTATION = "Interface\\ICONS\\Achievement_Reputation_01",

    -- Special status icons
    HAS_DYE_SLOTS = "Interface\\ICONS\\INV_Inscription_Pigment_Bug01",
    WARBOUND = "Interface\\ICONS\\Spell_ChargePositive",

    -- UI icons
    -- Custom icon in Textures folder (user provides icon.png or icon.tga)
    MINIMAP = "Interface\\AddOns\\Homestead\\Textures\\icon",
}

-- Atlas-based icons (WoW 12.0+ housing atlases if available)
-- These will be checked and used if they exist
Constants.Atlases = {
    COLLECTED = "UI-HUD-MicroMenu-Questlog-Mouseover",  -- fallback atlas
    NOT_COLLECTED = "UI-HUD-MicroMenu-Questlog-Disabled",
}

-------------------------------------------------------------------------------
-- Color Definitions (RGBA format)
-------------------------------------------------------------------------------
Constants.Colors = {
    -- Status colors
    COLLECTED = { r = 0.0, g = 0.8, b = 0.0, a = 1.0 },        -- Green
    COLLECTED_PLACED = { r = 0.0, g = 0.5, b = 1.0, a = 1.0 }, -- Blue
    NOT_COLLECTED = { r = 0.8, g = 0.0, b = 0.0, a = 1.0 },    -- Red

    -- Source colors
    VENDOR = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 },          -- Gold
    CRAFT = { r = 1.0, g = 0.5, b = 0.0, a = 1.0 },            -- Orange
    ACHIEVEMENT = { r = 1.0, g = 1.0, b = 0.0, a = 1.0 },      -- Yellow
    DROP = { r = 0.6, g = 0.6, b = 0.6, a = 1.0 },             -- Gray
    QUEST = { r = 1.0, g = 1.0, b = 0.0, a = 1.0 },            -- Yellow
    REPUTATION = { r = 0.0, g = 0.7, b = 0.0, a = 1.0 },       -- Dark Green

    -- Faction colors
    ALLIANCE = { r = 0.0, g = 0.44, b = 0.87, a = 1.0 },       -- Blue
    HORDE = { r = 0.77, g = 0.12, b = 0.23, a = 1.0 },         -- Red
    NEUTRAL = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 },         -- Gold

    -- UI colors
    HIGHLIGHT = { r = 1.0, g = 1.0, b = 1.0, a = 0.3 },
    BACKGROUND = { r = 0.0, g = 0.0, b = 0.0, a = 0.8 },
}

-------------------------------------------------------------------------------
-- Text Strings (used for tooltip and UI text)
-- These can be localized later via the Locale system
-------------------------------------------------------------------------------
Constants.Text = {
    -- Collection status
    COLLECTED = "Collected",
    COLLECTED_PLACED = "Collected (Placed)",
    NOT_COLLECTED = "Not Collected",

    -- Source descriptions
    SOURCE_VENDOR = "Available from vendor",
    SOURCE_CRAFT = "Can be crafted",
    SOURCE_ACHIEVEMENT = "Achievement reward",
    SOURCE_DROP = "World drop",
    SOURCE_QUEST = "Quest reward",
    SOURCE_REPUTATION = "Reputation reward",

    -- Special status
    HAS_DYE_SLOTS = "Can be dyed",
    COLORABLE = "Colorable",
    WARBOUND = "Warbound",

    -- Tooltip headers
    TOOLTIP_HEADER = "|cFF00FF00[Housing Addon]|r",

    -- UI labels
    UI_DECOR_BROWSER = "Decor Browser",
    UI_VENDOR_TRACER = "Vendor Tracer",
    UI_COLOR_TRACKER = "Color Tracker",
    UI_EXPORT = "Export Data",
    UI_OPTIONS = "Options",
}

-------------------------------------------------------------------------------
-- Source Types
-------------------------------------------------------------------------------
Constants.SourceTypes = {
    VENDOR = "vendor",
    CRAFT = "craft",
    ACHIEVEMENT = "achievement",
    DROP = "drop",
    QUEST = "quest",
    REPUTATION = "reputation",
    EVENT = "event",
    PROMOTION = "promotion",
    UNKNOWN = "unknown",
}

-------------------------------------------------------------------------------
-- Geography Mapping
-------------------------------------------------------------------------------
-- Canonical zone-to-continent map consumed by VendorDatabase, BadgeCalculation,
-- and scanner inference paths.
Constants.ZoneToContinentMap = {
    [17] = 13,
    [21] = 13,
    [23] = 13,
    [24] = 13,
    [25] = 13,
    [27] = 13,
    [32] = 13,
    [36] = 13,
    [48] = 13,
    [50] = 13,     -- Northern Stranglethorn
    [56] = 13,
    [57] = 13,
    [69] = 12,
    [70] = 12,
    [71] = 12,     -- Tanaris
    [77] = 12,     -- Felwood
    [80] = 12,     -- Moonglade (Lunar Festival vendor)
    [84] = 13,
    [85] = 12,
    [87] = 13,
    [88] = 12,
    [89] = 12,
    [90] = 13,
    [94] = 13,
    [95] = 13,
    [97] = 12,     -- Azuremyst Isle
    [102] = 101,   -- Zangarmarsh
    [107] = 101,   -- Nagrand (Outland)
    [110] = 13,
    [111] = 101,   -- Shattrath
    [114] = 113,
    [115] = 113,
    [116] = 113,
    [117] = 113,
    [118] = 113,   -- Icecrown
    [119] = 113,
    [120] = 113,
    [121] = 113,
    [125] = 113,
    [127] = 113,
    [217] = 13,
    [218] = 13,    -- Ruins of Gilneas
    [224] = 13,
    [241] = 13,
    [242] = 13,
    [369] = 13,    -- Bizmo's Brawlpub
    [371] = 424,
    [376] = 424,
    [379] = 424,
    [388] = 424,
    [390] = 424,
    [407] = 12,
    [418] = 424,
    [503] = 12,    -- Brawl'gar Arena
    [504] = 424,   -- Isle of Thunder
    [525] = 572,
    [534] = 572,   -- Tanaan Jungle
    [535] = 572,
    [539] = 572,
    [542] = 572,
    [543] = 572,
    [550] = 572,
    [554] = 424,   -- Timeless Isle
    [582] = 572,
    [590] = 572,
    [622] = 572,
    [624] = 572,
    [626] = 619,
    [627] = 619,
    [628] = 619,   -- Dalaran - The Underbelly
    [630] = 619,
    [634] = 619,
    [641] = 619,
    [646] = 619,   -- Broken Shore
    [647] = 619,
    [650] = 619,
    [652] = 619,   -- Thunder Totem (sub-zone)
    [680] = 619,
    [695] = 619,
    [702] = 619,
    [709] = 619,
    [717] = 619,
    [720] = 619,
    [726] = 619,
    [734] = 619,
    [735] = 619,   -- Hall of the Guardian interior (Mage Order Hall, child of Dalaran 627)
    [739] = 619,
    [745] = 619,   -- Trueshot Lodge
    [747] = 619,
    [750] = 619,   -- Thunder Totem
    [830] = 905,   -- Krokuun (Argus)
    [831] = 905,   -- The Vindicaar (Argus, sub-map of Krokuun)
    [862] = 875,
    [863] = 875,
    [864] = 875,
    [882] = 905,   -- Eredath (Argus)
    [885] = 905,   -- Mac'Aree (Argus)
    [895] = 876,
    [896] = 876,
    [940] = 905,   -- Mac'Aree (Argus)
    [942] = 876,
    [1161] = 876,
    [1164] = 875,  -- Zuldazar
    [1165] = 875,
    [1186] = 13,   -- Blackrock Depths
    [1460] = 876,  -- Mechagon
    [1462] = 876,
    [1473] = 12,   -- Chamber of Heart (Silithus)
    [1525] = 1550,
    [1530] = 424,  -- Shrine of Two Moons
    [1533] = 1550,
    [1536] = 1550,
    [1543] = 1550,
    [1565] = 1550,
    [1670] = 1550,
    [1699] = 1550,
    [1961] = 1550, -- Korthia
    [2022] = 1978,
    [2023] = 1978,
    [2024] = 1978,
    [2025] = 1978,
    [2112] = 1978,
    [2133] = 1978,
    [2151] = 1978,
    [2200] = 1978,
    [2213] = 2274, -- City of Threads
    [2214] = 2274,
    [2215] = 2274,
    [2216] = 2274, -- City of Threads - Lower
    [2239] = 1978,
    [2248] = 2274,
    [2255] = 2274,
    [2338] = 2274, -- Smuggler's Coast
    [2339] = 2274,
    [2346] = 2274,
    [2350] = 2274, -- Arcantina
    [2351] = 2274, -- Hollowed Halls (Housing)
    [2352] = 2274, -- Housing instance
    [2393] = 2537, -- Murder Row (Midnight Silvermoon)
    [2395] = 2537, -- Midnight Silvermoon (zone parent)
    [2405] = 2537, -- Founder's Point (Midnight)
    [2406] = 2274, -- Liberation of Undermine (dungeon)
    [2413] = 2537, -- Harandar sub-zone (Midnight)
    [2437] = 2537, -- Zul'Aman (Midnight)
    [2444] = 2537, -- Slayer's Rise (Midnight)
    [2472] = 2274, -- Tazavesh
    [2576] = 2537, -- The Den / Harandar sub-zone (Midnight)
    [2694] = 2537, -- Harandar (Midnight)
    [15958] = 2537, -- Voidstorm (Midnight)
}

Constants.ContinentNames = {
    [12] = "Kalimdor",
    [13] = "Eastern Kingdoms",
    [101] = "Outland",
    [113] = "Northrend",
    [424] = "Pandaria",
    [572] = "Draenor",
    [619] = "Broken Isles",
    [905] = "Argus",
    [875] = "Zandalar",
    [876] = "Kul Tiras",
    [1550] = "Shadowlands",
    [1978] = "Dragon Isles",
    [2274] = "Khaz Algar",
    [2537] = "Midnight",
}

Constants.ContinentToExpansion = {
    [12] = "Classic",               -- Kalimdor
    [13] = "Classic",               -- Eastern Kingdoms
    [101] = "The Burning Crusade",  -- Outland
    [113] = "Wrath of the Lich King", -- Northrend
    [424] = "Mists of Pandaria",    -- Pandaria
    [572] = "Warlords of Draenor",  -- Draenor
    [619] = "Legion",               -- Broken Isles
    [905] = "Legion",               -- Argus
    [875] = "Battle for Azeroth",   -- Zandalar
    [876] = "Battle for Azeroth",   -- Kul Tiras
    [1550] = "Shadowlands",         -- Shadowlands
    [1978] = "Dragonflight",        -- Dragon Isles
    [2274] = "The War Within",      -- Khaz Algar
    [2537] = "Midnight",            -- Midnight (Silvermoon / Blood Elf zones)
}

-------------------------------------------------------------------------------
-- Vertical Zone Siblings (for minimap elevation arrows)
-- Maps zones that are vertically stacked in the same physical location.
-- Key: player's mapID, Value: { [vendorMapID] = "above"|"below" }
-- "above" means the vendor is above the player; "below" means below.
-------------------------------------------------------------------------------

Constants.VerticalSiblings = {
    -- City of Threads (2213) / City of Threads - Lower (2216)
    [2213] = { [2216] = "below" },
    [2216] = { [2213] = "above" },
    -- Dalaran / Underbelly
    [627] = { [628] = "below" },
    [628] = { [627] = "above" },
}

function Constants.GetElevationDirection(playerMapID, vendorMapID)
    local siblings = Constants.VerticalSiblings[playerMapID]
    return siblings and siblings[vendorMapID]
end

-------------------------------------------------------------------------------
-- Overlay Configuration
-------------------------------------------------------------------------------
Constants.Overlay = {
    -- Default icon size
    ICON_SIZE = 14,

    -- Position anchor (can be: TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT, CENTER)
    DEFAULT_ANCHOR = "TOPLEFT",

    -- Offset from anchor point
    OFFSET_X = 2,
    OFFSET_Y = -2,

    -- Update throttle (seconds between updates)
    UPDATE_THROTTLE = 0.1,

    -- Frame strata for overlays
    STRATA = "HIGH",

    -- Frame level offset from parent
    LEVEL_OFFSET = 10,
}

-------------------------------------------------------------------------------
-- Cache Configuration
-------------------------------------------------------------------------------
Constants.Cache = {
    -- Time to live for cached data (seconds)
    TTL_DECOR_INFO = 300,      -- 5 minutes
    TTL_VENDOR_INFO = 3600,    -- 1 hour
    TTL_DYE_INFO = 300,        -- 5 minutes

    -- Maximum cache entries
    MAX_ENTRIES = 1000,
}

-------------------------------------------------------------------------------
-- Default Options
-------------------------------------------------------------------------------
Constants.Defaults = {
    profile = {
        -- General settings
        enabled = true,
        debug = false,
        useParsedSources = false,  -- Gate parsed sources in tooltip/source display
        minimap = {
            hide = false,
        },

        -- Overlay settings
        overlay = {
            enabled = true,
            showOnBags = true,
            showOnBank = true,
            showOnMerchant = true,
            showOnAuctionHouse = true,
            showOnHousingCatalog = true,
            iconSize = 14,
            iconAnchor = "TOPLEFT",
        },

        -- Tooltip settings
        tooltip = {
            enabled = true,
            showOwned = true,
            showSource = true,
            showAllSources = true,  -- Show all sources vs primary only
            showQuantity = false,  -- off by default, can be noisy
            showDyeSlots = true,
            showRequirements = true,  -- Show acquisition requirements (rep, quest, etc.)
        },

        -- Vendor tracer settings
        vendorTracer = {
            showMapPins = true,
            showMinimapPins = true,
            minimapCrossZoneMode = "auto",            -- auto|off|on for nearby-zone minimap pins
            useTomTom = true,
            useNativeWaypoints = true,
            autoWaypoint = false,
            showVendorDetails = true,
            showMissingAtVendor = true,
            navigateModifier = "shift",  -- shift, ctrl, alt, or none
            showOppositeFaction = true,  -- Show vendors for opposite faction with faction emblem
            pinColorPreset = "default",              -- Color preset key or "custom"
            pinColorCustom = { r = 1, g = 1, b = 1 }, -- RGB for custom pin color
            pinIconSize = 20,                          -- Base icon size for world map pins (12-32)
            minimapIconSize = 12,                      -- Minimap pin size (8-24)
            showPinCounts = true,                      -- Show collected/total counts on vendor pins
            worldMapZoneBadges = false,                -- Show zone-level badges on world map instead of continent totals
            showMapSidePanel = false,                  -- Show vendor list panel on world map
            mapSidePanelSourceFilter = "all",          -- Item source filter for map side panel counts/grid
            integrateMapBorder = true,                 -- Integrate panel with map frame border (disable for custom UIs)
            sidePanelPoppedOut = false,                 -- Panel is detached from world map
            sidePanelPosition = nil,                   -- {point, x, y} saved on drag stop
            sidePanelHeight = nil,                     -- Saved detached height for /reload restore
            showEventVendors = true,                   -- Show seasonal event vendor pins when events are active
            showUnverifiedVendors = false,             -- Hidden by default; orange pins for unconfirmed locations
        },

        -- Vendor scanning settings
        vendorScanning = {
            enabled = true,  -- Auto-scan merchants for housing decor data
        },
    },
    global = {
        -- Cross-character data
        vendorVisited = {},
        dyeRecipesKnown = {},
        -- Persistent ownership cache (workaround for Blizzard API bug)
        -- Items are added here when the API reports them as owned
        -- This data persists even when the API returns stale data after reload
        ownedDecor = {},  -- [itemID] = { recordID, lastSeen, name }
        -- Scanned vendor data from VendorScanner
        scannedVendors = {},  -- [npcID] = { npcID, name, mapID, coords, decor, ... }
        -- Persistent no-decor vendor tracking (survives ClearScannedData)
        noDecorVendors = {},  -- [npcID] = { name, confirmedAt, itemCount, inDatabase, scanConfidence, confirmCount }
        -- Experimental: tooltip-based requirement detection
        enableRequirementScraping = true,
        -- NPC ID corrections detected when visiting vendors
        npcIDCorrections = {},  -- [vendorName] = { oldID, newID, correctedAt }
        -- Runtime parsed source data from CatalogScanner sourceText
        parsedSources = {},          -- [itemID] = { sources, recordID, lastParsed, sourceHash }
        -- Locale-learned vendor names for cross-reference
        vendorNameByLocale = {},     -- [locale] = { [normalizedName] = {npcID, scanCount, lastSeen} }
        -- Canonical per-item store (CatalogStore)
        catalogItems = {},           -- [itemID] = { isOwned, name, decorID, sources, requirements, ... }
        schemaVersion = 1,           -- Incremented by migrations
        lastSeenVersion = "",        -- Last version player acknowledged in What's New
        suppressWhatsNewUntil = "",  -- Skip auto-popup for this specific version
    },
}

-------------------------------------------------------------------------------
-- Events to Monitor
-------------------------------------------------------------------------------
Constants.Events = {
    -- Housing events
    "HOUSING_STORAGE_UPDATED",
    "HOUSING_DECOR_PLACE_SUCCESS",
    "HOUSING_DECOR_REMOVED",

    -- Endeavour events
    "NEIGHBORHOOD_INITIATIVE_UPDATED",
    "INITIATIVE_TASK_COMPLETED",
    "INITIATIVE_COMPLETED",

    -- UI events
    "BAG_UPDATE",
    "BAG_UPDATE_DELAYED",
    "MERCHANT_SHOW",
    "MERCHANT_CLOSED",
    "AUCTION_HOUSE_SHOW",
    "AUCTION_HOUSE_CLOSED",

    -- Player events
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
}

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
Constants.SlashCommands = {
    PRIMARY = "/hs",
    SECONDARY = "/homestead",
}

-- Constants are attached to the addon namespace (HA)
