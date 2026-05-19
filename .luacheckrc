std = "none"
max_line_length = false

globals = {
    -- Addon globals (intentionally written)
    "Homestead",
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
    "CreateDataProvider",
    "CreateFromMixins",
    "CreateScrollBoxListLinearView",
    "CreateFramePool", "CreateUnsecuredRegionPoolInstance",
    "EventRegistry",
    "GameFontHighlight", "GameFontHighlightSmall",
    "GameFontNormal", "GameFontNormalLarge", "GameFontNormalHuge2", "GameFontNormalSmall",
    "GameTooltip", "GameTooltip_Hide",
    "GameTooltip_AddNormalLine", "GameTooltip_SetTitle",
    "ItemRefTooltip",
    "MerchantFrame", "MerchantFrameTab1", "MerchantFrameTab2",
    "MerchantNextPageButton", "MerchantPrevPageButton",
    "InterfaceOptions_AddCategory",
    "Settings",
    "ShoppingTooltip1", "ShoppingTooltip2",
    "ScrollUtil",
    "TooltipDataProcessor",
    "UIParent", "UISpecialFrames",
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
    "C_Container",
    "C_CurrencyInfo",
    "C_DateInfo",
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
