std = "none"
max_line_length = false

globals = {
    "Homestead",
    "SlashCmdList",
    "SLASH_HOMESTEAD1", "SLASH_HOMESTEAD2",
    "StaticPopupDialogs",
}

read_globals = {
    -- Lua builtins
    "pairs", "ipairs", "type", "select", "unpack",
    "tonumber", "tostring", "print", "format",
    "tinsert", "tremove", "wipe", "strsplit",
    "time", "date", "math", "string", "table",
    "error", "pcall", "rawget", "rawset", "setmetatable", "getmetatable",

    -- WoW frames/UI
    "UIParent", "GameTooltip", "CreateFrame",
    "UISpecialFrames", "BackdropTemplate",
    "UIPanelButtonTemplate", "UIPanelCloseButton",
    "InputBoxTemplate", "UIPanelScrollFrameTemplate",
    "GameFontNormal", "GameFontNormalLarge",
    "GameFontNormalHuge2", "GameFontHighlight",
    "GameFontHighlightSmall",

    -- WoW API
    "C_Timer", "C_Map", "C_HousingCatalog",
    "C_Item", "C_AchievementInfo",
    "GetItemInfo", "GetAchievementInfo",
    "GetAchievementCriteriaInfo",
    "hooksecurefunc", "IsShiftKeyDown",
    "GetMerchantNumItems", "GetMerchantItemInfo",
    "GetMerchantItemLink", "UnitGUID",

    -- Ace3 / Libraries
    "LibStub",
}

ignore = {"21[23]"}  -- Ace3 callback patterns
