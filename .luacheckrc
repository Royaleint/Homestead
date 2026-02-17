std = "none"
max_line_length = false

globals = {
    -- Addon globals (intentionally written)
    "Homestead",
    "SlashCmdList",
    "SLASH_HOMESTEAD1", "SLASH_HOMESTEAD2",
    "StaticPopupDialogs",
    -- SavedVariables (created by WoW, read/written by addon)
    "HomesteadDB",
}

read_globals = {
    -- Lua builtins
    "_G", "next",
    "pairs", "ipairs", "type", "select", "unpack",
    "tonumber", "tostring", "print", "format",
    "tinsert", "tremove", "wipe", "strsplit",
    "time", "date", "math", "string", "table",
    "error", "pcall", "rawget", "rawset", "setmetatable", "getmetatable",

    -- WoW constants
    "BANK_CONTAINER",
    "MERCHANT_ITEMS_PER_PAGE",
    "NUM_BANKGENERIC_SLOTS",

    -- WoW frames/UI
    "BankFrame",
    "ChatFontNormal",
    "ContainerFrameCombinedBags", "ContainerFrameContainer",
    "CreateFrame",
    "EventRegistry",
    "GameFontHighlight", "GameFontHighlightSmall",
    "GameFontNormal", "GameFontNormalLarge", "GameFontNormalHuge2",
    "GameTooltip", "GameTooltip_Hide",
    "ItemRefTooltip",
    "MerchantFrame", "MerchantFrameTab1", "MerchantFrameTab2",
    "MerchantNextPageButton", "MerchantPrevPageButton",
    "Settings",
    "ShoppingTooltip1", "ShoppingTooltip2",
    "TooltipDataProcessor",
    "UIParent", "UISpecialFrames",
    "WorldMapFrame",
    -- Templates
    "BackdropTemplate",
    "InputBoxTemplate",
    "UIPanelButtonTemplate", "UIPanelCloseButton",
    "UIPanelScrollFrameTemplate",

    -- WoW API (C_ namespaces)
    "C_AddOns",
    "C_AchievementInfo",
    "C_Container",
    "C_CurrencyInfo",
    "C_Housing",
    "C_HousingCatalog",
    "C_Item",
    "C_Map",
    "C_MerchantFrame",
    "C_SuperTrack",
    "C_Timer",
    "Enum",
    "UiMapPoint",

    -- WoW API (functions)
    "GetAchievementCriteriaInfo", "GetAchievementInfo",
    "GetItemCount", "GetItemInfo", "GetItemInfoInstant",
    "GetMerchantItemInfo", "GetMerchantItemLink", "GetMerchantNumItems",
    "GetLocale",
    "GetRealZoneText",
    "GetScreenWidth", "GetScreenHeight",
    "GetRealmName",
    "GetTime",
    "hooksecurefunc",
    "IsAddOnLoaded",
    "IsAltKeyDown", "IsControlKeyDown", "IsShiftKeyDown",
    "IsIndoors",
    "OpenAllBags",
    "StaticPopup_Show",
    "ToggleAllBags", "ToggleBag", "ToggleWorldMap",
    "UnitFactionGroup", "UnitGUID", "UnitName",

    -- Ace3 / Libraries
    "LibStub",

    -- HereBeDragons library
    "HBD_PINS_WORLDMAP_SHOW_CONTINENT",
    "HBD_PINS_WORLDMAP_SHOW_PARENT",
    "HBD_PINS_WORLDMAP_SHOW_WORLD",

    -- Optional external addons
    "TomTom",
}

ignore = {"21[23]"}  -- Ace3 callback patterns
