--[[
    Homestead - SourceTextLocaleProfiles
    Locale-specific prefix tables for SourceTextParser

    Each profile maps sourceText prefixes (e.g., "Vendor:", "Zone:") to
    semantic field names used by the typed parser. Adding support for a
    new locale requires only a new entry in the Profiles table.

    No WoW API calls. Pure data.
]]

local addonName, HA = ...

local SourceTextLocaleProfiles = {}
HA.SourceTextLocaleProfiles = SourceTextLocaleProfiles

-- Prefix tables for typed parsing
-- Each profile maps sourceText prefixes to semantic field names
SourceTextLocaleProfiles.Profiles = {
    enUS = {
        -- Source type prefixes (first line of each block)
        sourceTypes = {
            ["Vendor:"] = "vendor",
            ["Quest:"] = "quest",
            ["Achievement:"] = "achievement",
            ["Profession:"] = "profession",
            ["Drop:"] = "drop",
        },
        -- Field prefixes (subsequent lines within a block)
        fields = {
            ["Zone:"] = "zone",
            ["Faction:"] = "faction",
            ["Cost:"] = "cost",
            ["Category:"] = "category",
        },
    },
}

-- enGB uses the same prefixes as enUS
SourceTextLocaleProfiles.Profiles.enGB = SourceTextLocaleProfiles.Profiles.enUS
