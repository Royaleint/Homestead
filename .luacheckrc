std = "none"
max_line_length = false

globals = {
    -- Addon globals (intentionally written)
    "Homestead",
    "HomesteadMinimapButton",
    "HomesteadMapSidePanelTooltip",
    "HomesteadVendorMapPinsTooltip",
    "SlashCmdList",
    "SLASH_HOMESTEAD1", "SLASH_HOMESTEAD2",
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
    "issecretvalue", -- Midnight combat-secrecy probe (HS-168)
    "GetBuildInfo",

    -- WoW constants
    "BANK_CONTAINER",
    "MERCHANT_ITEMS_PER_PAGE",
    "NUM_BANKGENERIC_SLOTS",

    -- WoW frames/UI
    "BackdropTemplateMixin",
    "BankFrame",
    "ChatFontNormal",
    "ContainerFrameCombinedBags", "ContainerFrameContainer",
    "CreateFrame",
    "DEFAULT_CHAT_FRAME",
    "CreateDataProvider",
    "CreateFromMixins",
    "CreateScrollBoxListLinearView",
    "CreateFramePool", "CreateUnsecuredRegionPoolInstance",
    "EventRegistry",
    "GameFontHighlight", "GameFontHighlightSmall",
    "GameFontNormal", "GameFontNormalLarge", "GameFontNormalHuge2", "GameFontNormalSmall",
    "GameTooltip", "GameTooltip_Hide",
    "GameTooltip_AddNormalLine", "GameTooltip_SetTitle",
    "GameTooltip_AddColoredLine", "GameTooltip_AddColoredDoubleLine",
    "NORMAL_FONT_COLOR", "Item",
    "ItemRefTooltip",
    "MerchantFrame", "MerchantFrameTab1", "MerchantFrameTab2",
    "MerchantNextPageButton", "MerchantPrevPageButton",
    "InterfaceOptions_AddCategory",
    "Settings",
    "ShoppingTooltip1", "ShoppingTooltip2",
    "ScrollUtil",
    "ScrollBoxListViewMixin",
    "TooltipDataProcessor",
    "UIParent", "UISpecialFrames",
    "MapCanvasDataProviderMixin",
    "Menu",
    "MenuUtil",
    "Mixin",
    "NineSliceUtil",
    "PlaySound",
    "WorldMapFrame",
    -- Templates
    "BackdropTemplate",
    "InputBoxTemplate",
    "UIPanelButtonTemplate", "UIPanelCloseButton",
    "UIPanelScrollFrameTemplate",

    -- WoW API (C_ namespaces)
    "C_AddOns",
    "C_AchievementInfo",
    "C_Calendar",
    "C_ChatInfo",
    "C_Container",
    "C_CurrencyInfo",
    "C_DateAndTime",
    "C_DateInfo",
    "C_EncounterJournal",  -- HS-229: EJ-anchored drop pins
    "C_GossipInfo",
    "C_Housing",
    "C_AreaPoiInfo",
    "C_HousingCatalog",
    "C_Item",
    "C_Map",
    "C_MerchantFrame",
    "C_MajorFactions",
    "C_QuestLog",
    "C_Reputation",
    "C_SuperTrack",
    "C_Timer",
    "C_TooltipInfo",
    "C_TradeSkillUI",
    "Enum",
    "UiMapPoint",

    -- WoW API (functions)
    "GetAchievementCriteriaInfo", "GetAchievementInfo",
    "GetItemCount", "GetItemInfo", "GetItemInfoInstant",
    "GetCoinTextureString",
    "GetMerchantItemInfo", "GetMerchantItemLink", "GetMerchantNumItems",
    "GetLocale",
    "GetProfessions", "GetProfessionInfo", -- HS-158/160 professionRank requirements
    "GetRealZoneText",
    "GetSubZoneText",
    "GetScreenWidth", "GetScreenHeight",
    "GetRealmName",
    "GetTime",
    "HideUIPanel",
    "InCombatLockdown",
    "HousingModelPreviewFrame",
    "hooksecurefunc",
    "IsAddOnLoaded",
    "IsAltKeyDown", "IsControlKeyDown", "IsShiftKeyDown",
    "IsIndoors",
    "IsInGroup", "IsInRaid", "IsInInstance", "IsInGuild",
    "OpenAllBags",
    "SOUNDKIT",
    "ToggleAllBags", "ToggleBag", "ToggleWorldMap",
    "UnitFactionGroup", "UnitGUID", "UnitLevel", "UnitName",

    -- Ace3 / Libraries
    "LibStub",

    -- Optional external addons
    "Baganator",
    "TomTom",
}

ignore = {"21[23]"}  -- Ace3 callback patterns

-- Vendored third-party libraries are linted in their own repos, not here. The
-- Foundry-1.0 embed (HS-120) is the one tracked lib in Libs/; exclude the whole
-- Libs/ tree so `luacheck .` covers only Homestead's own files.
exclude_files = {"Libs/"}
