--[[
    HousingAddon - Constants
    Defines icons, colors, text strings, and configuration defaults
]]

local addonName, HA = ...

-- Addon namespace
HA.Constants = {}
local Constants = HA.Constants

-------------------------------------------------------------------------------
-- Version Info
-------------------------------------------------------------------------------
Constants.VERSION = "0.1.0"
Constants.ADDON_NAME = "HousingAddon"
Constants.ADDON_SHORT = "HA"

-------------------------------------------------------------------------------
-- Icon Definitions
-- These represent the various states a decor item can be in
-------------------------------------------------------------------------------
Constants.Icons = {
    -- Collection status icons
    COLLECTED = "Interface\\RaidFrame\\ReadyCheck-Ready",
    COLLECTED_PLACED = "Interface\\AddOns\\HousingAddon\\Textures\\collected_placed",
    NOT_COLLECTED = "Interface\\RaidFrame\\ReadyCheck-NotReady",

    -- Source type icons (shown when not collected)
    PURCHASABLE = "Interface\\GossipFrame\\VendorGossipIcon",
    CRAFTABLE = "Interface\\ICONS\\Trade_BlackSmithing",
    ACHIEVEMENT_REWARD = "Interface\\AchievementFrame\\UI-Achievement-TinyShield",
    DROP_SOURCE = "Interface\\ICONS\\INV_Misc_Bone_Skull_01",
    QUEST_REWARD = "Interface\\GossipFrame\\AvailableQuestIcon",
    REPUTATION = "Interface\\ICONS\\Achievement_Reputation_01",

    -- Special status icons
    HAS_DYE_SLOTS = "Interface\\ICONS\\INV_Inscription_Pigment_Bug01",
    WARBOUND = "Interface\\ICONS\\Spell_ChargePositive",

    -- UI icons
    MINIMAP = "Interface\\ICONS\\Garrison_Building_Storehouse",
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
            showSource = true,
            showQuantity = true,
            showDyeSlots = true,
        },

        -- Vendor tracer settings
        vendorTracer = {
            showMapPins = true,
            showMinimapPins = false,
            useTomTom = true,
            autoWaypoint = false,
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
    },
}

-------------------------------------------------------------------------------
-- Events to Monitor
-------------------------------------------------------------------------------
Constants.Events = {
    -- Housing events
    "HOUSING_CATALOG_UPDATED",
    "HOUSING_DECOR_PLACE_SUCCESS",
    "HOUSING_DECOR_REMOVE_SUCCESS",

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
    PRIMARY = "/ha",
    SECONDARY = "/housingaddon",
}

-- Make constants accessible globally for the addon
_G[addonName] = HA
