--[[
    Homestead - Constants
    Defines icons, colors, text strings, and configuration defaults

    A complete housing collection, vendor, and progress tracker for WoW
]]

local addonName, HA = ...

-- Addon namespace
HA.Constants = {}
local Constants = HA.Constants

-------------------------------------------------------------------------------
-- Version Info
-------------------------------------------------------------------------------
Constants.VERSION = "1.3.0"
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
    UI_ENDEAVOURS = "Endeavours",
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
            showQuantity = false,  -- off by default, can be noisy
            showDyeSlots = true,
            showRequirements = true,  -- Show acquisition requirements (rep, quest, etc.)
        },

        -- Vendor tracer settings
        vendorTracer = {
            showMapPins = true,
            showMinimapPins = true,
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
        },

        -- Endeavour tracker settings
        endeavourTracker = {
            enabled = true,
            showProgress = true,
        },

        -- Export settings
        export = {
            includeCharacterInfo = true,
            includeDecorList = true,
            includeDyeList = true,
            includeEndeavours = true,
            includeVendorsVisited = true,
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
