--[[
    Homestead - Achievement Sources
    Merged: 2026-02-22
    Total entries: 259

    Maps itemID to achievement source information with category and expansion metadata.
    Consolidates data from the original AchievementSources (155 items, API-validated)
    and AchievementDecor (124 achievements, Wowhead/community-sourced).

    Schema per entry:
        [itemID] = {achievementID, achievementName, category, expansion}

    Categories: meta, exploration, quests, pvp, dungeons, professions, reputation,
                class_hall, lorewalking, progression
    Expansions: The War Within, Dragonflight, Shadowlands, Battle for Azeroth, Legion,
                Warlords of Draenor, Mists of Pandaria, Cataclysm, Wrath of the Lich King, Classic, Midnight

    History:
    - Generated 2026-02-01: Original 155 entries from import_all_sources.py
    - Cleaned 2026-02-17: Removed 40 fabricated, 10 nonexistent itemIDs
    - Validated 2026-02-18: Updated 7 achievement names via API, removed 3 NOT_FOUND
    - Added 2026-02-21: 6 entries from Blizzard web API gap analysis
    - Merged 2026-02-22: +104 entries from AchievementDecor, added category/expansion,
      reverse index, helper functions. AchievementDecor.lua retired.
]]

local _, HA = ...

local AchievementSources = {}

-------------------------------------------------------------------------------
-- Achievement Source Data (itemID-keyed)
-------------------------------------------------------------------------------

local sourceData = {

    ---------------------------------------------------------------------------
    -- The War Within (TWW)
    ---------------------------------------------------------------------------

    -- Meta
    [257353] = {achievementID = 61451, achievementName = "Worldsoul-Searching", category = "meta", expansion = "The War Within"},
    [267122] = {achievementID = 61451, achievementName = "Worldsoul-Searching", category = "meta", expansion = "The War Within"},

    -- Exploration
    [245324] = {achievementID = 40894, achievementName = "Sojourner of Undermine", category = "exploration", expansion = "The War Within"},
    [246866] = {achievementID = 40542, achievementName = "Smelling History", category = "exploration", expansion = "The War Within"},
    [246867] = {achievementID = 41186, achievementName = "Slate of the Union", category = "exploration", expansion = "The War Within"},
    [249169] = {achievementID = 20595, achievementName = "Sojourner of Isle of Dorn", category = "exploration", expansion = "The War Within"},
    [249181] = {achievementID = 40504, achievementName = "Rocked to Sleep", category = "exploration", expansion = "The War Within"},
    [249185] = {achievementID = 40859, achievementName = "We're Here All Night", category = "exploration", expansion = "The War Within"},
    [251271] = {achievementID = 40894, achievementName = "Sojourner of Undermine", category = "exploration", expansion = "The War Within"},
    [252532] = {achievementID = 40542, achievementName = "Smelling History", category = "exploration", expansion = "The War Within"},
    [252533] = {achievementID = 41186, achievementName = "Slate of the Union", category = "exploration", expansion = "The War Within"},
    [252757] = {achievementID = 20595, achievementName = "Sojourner of Isle of Dorn", category = "exploration", expansion = "The War Within"},
    [253023] = {achievementID = 40504, achievementName = "Rocked to Sleep", category = "exploration", expansion = "The War Within"},
    [253037] = {achievementID = 40859, achievementName = "We're Here All Night", category = "exploration", expansion = "The War Within"},

    -- Lorewalking
    [245332] = {achievementID = 61467, achievementName = "Lorewalking: The Elves of Quel'Thalas", category = "lorewalking", expansion = "The War Within"},
    [257351] = {achievementID = 42189, achievementName = "Lorewalking: The Lich King", category = "lorewalking", expansion = "The War Within"},
    [257354] = {achievementID = 42187, achievementName = "Lorewalking: Ethereal Wisdom", category = "lorewalking", expansion = "The War Within"},
    [257355] = {achievementID = 42188, achievementName = "Lorewalking: Blade's Bane", category = "lorewalking", expansion = "The War Within"},
    [257400] = {achievementID = 61467, achievementName = "Lorewalking: The Elves of Quel'Thalas", category = "lorewalking", expansion = "The War Within"},
    [258858] = {achievementID = 42187, achievementName = "Lorewalking: Ethereal Wisdom", category = "lorewalking", expansion = "The War Within"},
    [258859] = {achievementID = 42188, achievementName = "Lorewalking: Blade's Bane", category = "lorewalking", expansion = "The War Within"},
    [258860] = {achievementID = 42189, achievementName = "Lorewalking: The Lich King", category = "lorewalking", expansion = "The War Within"},

    -- Professions
    [249237] = {achievementID = 19408, achievementName = "Professional Algari Master", category = "professions", expansion = "The War Within"},
    [253163] = {achievementID = 19408, achievementName = "Professional Algari Master", category = "professions", expansion = "The War Within"},

    -- Progression
    [245302] = {achievementID = 41119, achievementName = "One Rank Higher", category = "progression", expansion = "The War Within"},
    [251121] = {achievementID = 41119, achievementName = "One Rank Higher", category = "progression", expansion = "The War Within"},

    -- PvP
    [243890] = {achievementID = 40612, achievementName = "Sprinting in the Ravine", category = "pvp", expansion = "The War Within"},
    [247750] = {achievementID = 40612, achievementName = "Sprinting in the Ravine", category = "pvp", expansion = "The War Within"},
    [249200] = {achievementID = 40210, achievementName = "Deephaul Ravine Victory", category = "pvp", expansion = "The War Within"},
    [253170] = {achievementID = 40210, achievementName = "Deephaul Ravine Victory", category = "pvp", expansion = "The War Within"},
    [267354] = {achievementID = 61683, achievementName = "Entering Battle", category = "pvp", expansion = "The War Within"},
    [267355] = {achievementID = 61684, achievementName = "Progressing in Battle", category = "pvp", expansion = "The War Within"},
    [267356] = {achievementID = 61685, achievementName = "Proficient in Battle", category = "pvp", expansion = "The War Within"},
    [267357] = {achievementID = 61686, achievementName = "Expert in Battle", category = "pvp", expansion = "The War Within"},
    [267358] = {achievementID = 61687, achievementName = "Champion in Battle", category = "pvp", expansion = "The War Within"},
    [267359] = {achievementID = 61688, achievementName = "Master in Battle", category = "pvp", expansion = "The War Within"},

    ---------------------------------------------------------------------------
    -- Dragonflight (DF)
    ---------------------------------------------------------------------------

    -- Meta
    [248124] = {achievementID = 19458, achievementName = "A World Awoken", category = "meta", expansion = "Dragonflight"},

    -- Exploration
    [248105] = {achievementID = 19507, achievementName = "Fringe Benefits", category = "exploration", expansion = "Dragonflight"},
    [248200] = {achievementID = 19507, achievementName = "Fringe Benefits", category = "exploration", expansion = "Dragonflight"},
    [248656] = {achievementID = 17529, achievementName = "Forbidden Spoils", category = "exploration", expansion = "Dragonflight"},

    -- Quests
    [240857] = {achievementID = 19719, achievementName = "Reclamation of Gilneas", category = "quests", expansion = "Dragonflight"},
    [245520] = {achievementID = 19719, achievementName = "Reclamation of Gilneas", category = "quests", expansion = "Dragonflight"},
    [247900] = {achievementID = 17773, achievementName = "A Blue Dawn", category = "quests", expansion = "Dragonflight"},
    [248104] = {achievementID = 17773, achievementName = "A Blue Dawn", category = "quests", expansion = "Dragonflight"},

    ---------------------------------------------------------------------------
    -- Shadowlands (SL)
    ---------------------------------------------------------------------------

    -- Meta
    [244181] = {achievementID = 20501, achievementName = "Back from the Beyond", category = "meta", expansion = "Shadowlands"},
    [248125] = {achievementID = 20501, achievementName = "Back from the Beyond", category = "meta", expansion = "Shadowlands"},

    ---------------------------------------------------------------------------
    -- Battle for Azeroth (BFA)
    ---------------------------------------------------------------------------

    -- Meta
    [247667] = {achievementID = 40953, achievementName = "A Farewell to Arms", category = "meta", expansion = "Battle for Azeroth"},
    [247668] = {achievementID = 40953, achievementName = "A Farewell to Arms", category = "meta", expansion = "Battle for Azeroth"},

    -- Quests
    [241062] = {achievementID = 12509, achievementName = "Ready for War", category = "quests", expansion = "Battle for Azeroth"},
    [241100] = {achievementID = 12582, achievementName = "Come Sail Away", category = "quests", expansion = "Battle for Azeroth"},
    [241150] = {achievementID = 12997, achievementName = "The Pride of Kul Tiras", category = "quests", expansion = "Battle for Azeroth"},
    [241175] = {achievementID = 13038, achievementName = "Raptari Rider", category = "quests", expansion = "Battle for Azeroth"},
    [241200] = {achievementID = 13049, achievementName = "The Long Con", category = "quests", expansion = "Battle for Azeroth"},
    [241250] = {achievementID = 12614, achievementName = "Loa Expectations", category = "quests", expansion = "Battle for Azeroth"},
    [241300] = {achievementID = 13039, achievementName = "Paku'ai", category = "quests", expansion = "Battle for Azeroth"},
    [241350] = {achievementID = 12509, achievementName = "Ready for War", category = "quests", expansion = "Battle for Azeroth"},
    [241400] = {achievementID = 12479, achievementName = "Zandalar Forever!", category = "quests", expansion = "Battle for Azeroth"},
    [241550] = {achievementID = 12869, achievementName = "Azeroth at War: After Lordaeron", category = "quests", expansion = "Battle for Azeroth"},
    [241600] = {achievementID = 12870, achievementName = "Azeroth at War: Kalimdor on Fire", category = "quests", expansion = "Battle for Azeroth"},
    [241650] = {achievementID = 12867, achievementName = "Azeroth at War: The Barrens", category = "quests", expansion = "Battle for Azeroth"},
    [245271] = {achievementID = 12582, achievementName = "Come Sail Away", category = "quests", expansion = "Battle for Azeroth"},
    [245463] = {achievementID = 12867, achievementName = "Azeroth at War: The Barrens", category = "quests", expansion = "Battle for Azeroth"},
    [245467] = {achievementID = 12869, achievementName = "Azeroth at War: After Lordaeron", category = "quests", expansion = "Battle for Azeroth"},
    [245483] = {achievementID = 12870, achievementName = "Azeroth at War: Kalimdor on Fire", category = "quests", expansion = "Battle for Azeroth"},
    [245487] = {achievementID = 13038, achievementName = "Raptari Rider", category = "quests", expansion = "Battle for Azeroth"},
    [245494] = {achievementID = 13039, achievementName = "Paku'ai", category = "quests", expansion = "Battle for Azeroth"},
    [245497] = {achievementID = 12614, achievementName = "Loa Expectations", category = "quests", expansion = "Battle for Azeroth"},
    [245522] = {achievementID = 12479, achievementName = "Zandalar Forever!", category = "quests", expansion = "Battle for Azeroth"},
    [252653] = {achievementID = 13049, achievementName = "The Long Con", category = "quests", expansion = "Battle for Azeroth"},
    [252654] = {achievementID = 12997, achievementName = "The Pride of Kul Tiras", category = "quests", expansion = "Battle for Azeroth"},

    -- Professions
    [241191] = {achievementID = 12733, achievementName = "Professional Zandalari Master", category = "professions", expansion = "Battle for Azeroth"},
    [241450] = {achievementID = 12746, achievementName = "The Zandalari Menu", category = "professions", expansion = "Battle for Azeroth"},
    [244325] = {achievementID = 12746, achievementName = "The Zandalari Menu", category = "professions", expansion = "Battle for Azeroth"},
    [245490] = {achievementID = 12733, achievementName = "Professional Zandalari Master", category = "professions", expansion = "Battle for Azeroth"},

    -- PvP
    [241500] = {achievementID = 13284, achievementName = "Frontline Warrior", category = "pvp", expansion = "Battle for Azeroth"},
    [245476] = {achievementID = 13284, achievementName = "Frontline Warrior", category = "pvp", expansion = "Battle for Azeroth"},

    -- Exploration
    [241750] = {achievementID = 13473, achievementName = "Diversified Investments", category = "exploration", expansion = "Battle for Azeroth"},
    [241800] = {achievementID = 13018, achievementName = "Dune Rider", category = "exploration", expansion = "Battle for Azeroth"},
    [241850] = {achievementID = 13477, achievementName = "Junkyard Apprentice", category = "exploration", expansion = "Battle for Azeroth"},
    [241900] = {achievementID = 13475, achievementName = "Junkyard Scavenger", category = "exploration", expansion = "Battle for Azeroth"},
    [244326] = {achievementID = 13018, achievementName = "Dune Rider", category = "exploration", expansion = "Battle for Azeroth"},
    [246483] = {achievementID = 13473, achievementName = "Diversified Investments", category = "exploration", expansion = "Battle for Azeroth"},
    [246598] = {achievementID = 13477, achievementName = "Junkyard Apprentice", category = "exploration", expansion = "Battle for Azeroth"},
    [246603] = {achievementID = 13475, achievementName = "Junkyard Scavenger", category = "exploration", expansion = "Battle for Azeroth"},

    -- Dungeons
    [241700] = {achievementID = 13723, achievementName = "M.C., Hammered", category = "dungeons", expansion = "Battle for Azeroth"},
    [246479] = {achievementID = 13723, achievementName = "M.C., Hammered", category = "dungeons", expansion = "Battle for Azeroth"},

    ---------------------------------------------------------------------------
    -- Legion
    ---------------------------------------------------------------------------

    -- Class Hall Campaigns
    [240750] = {achievementID = 42274, achievementName = "The Archmage's Campaign", category = "class_hall", expansion = "Legion"},
    [244042] = {achievementID = 42273, achievementName = "The Huntmaster's Campaign", category = "class_hall", expansion = "Legion"},
    [245126] = {achievementID = 42275, achievementName = "The Grandmaster's Campaign", category = "class_hall", expansion = "Legion"},
    [245128] = {achievementID = 42282, achievementName = "The Battlelord's Campaign", category = "class_hall", expansion = "Legion"},
    [245429] = {achievementID = 42274, achievementName = "The Archmage's Campaign", category = "class_hall", expansion = "Legion"},
    [245527] = {achievementID = 42271, achievementName = "The Slayer's Campaign", category = "class_hall", expansion = "Legion"},
    [245534] = {achievementID = 42281, achievementName = "The Netherlord's Campaign", category = "class_hall", expansion = "Legion"},
    [245878] = {achievementID = 60964, achievementName = "Legendary Research of the Dreamgrove", category = "class_hall", expansion = "Legion"},
    [245882] = {achievementID = 42270, achievementName = "The Deathlord's Campaign", category = "class_hall", expansion = "Legion"},
    [245888] = {achievementID = 42287, achievementName = "Hidden Potential of the Deathlord", category = "class_hall", expansion = "Legion"},
    [245889] = {achievementID = 42288, achievementName = "Hidden Potential of the Slayer", category = "class_hall", expansion = "Legion"},
    [245890] = {achievementID = 42289, achievementName = "Hidden Potential of the Archdruid", category = "class_hall", expansion = "Legion"},
    [245891] = {achievementID = 42290, achievementName = "Hidden Potential of the Huntmaster", category = "class_hall", expansion = "Legion"},
    [245893] = {achievementID = 42292, achievementName = "Hidden Potential of the Grandmaster", category = "class_hall", expansion = "Legion"},
    [245894] = {achievementID = 42293, achievementName = "Hidden Potential of the Highlord", category = "class_hall", expansion = "Legion"},
    [245895] = {achievementID = 42294, achievementName = "Hidden Potential of the High Priest", category = "class_hall", expansion = "Legion"},
    [245896] = {achievementID = 42295, achievementName = "Hidden Potential of the Shadowblade", category = "class_hall", expansion = "Legion"},
    [245897] = {achievementID = 42296, achievementName = "Hidden Potential of the Farseer", category = "class_hall", expansion = "Legion"},
    [245898] = {achievementID = 42297, achievementName = "Hidden Potential of the Netherlord", category = "class_hall", expansion = "Legion"},
    [245899] = {achievementID = 42298, achievementName = "Hidden Potential of the Battlelord", category = "class_hall", expansion = "Legion"},
    [245900] = {achievementID = 60962, achievementName = "Legendary Research of the Ebon Blade", category = "class_hall", expansion = "Legion"},
    [245901] = {achievementID = 60963, achievementName = "Legendary Research of the Illidari", category = "class_hall", expansion = "Legion"},
    [245903] = {achievementID = 60965, achievementName = "Legendary Research of the Unseen Path", category = "class_hall", expansion = "Legion"},
    [245905] = {achievementID = 60967, achievementName = "Legendary Research of Five Dawns", category = "class_hall", expansion = "Legion"},
    [245906] = {achievementID = 60968, achievementName = "Legendary Research of the Silver Hand", category = "class_hall", expansion = "Legion"},
    [245907] = {achievementID = 60969, achievementName = "Legendary Research of the Netherlight Conclave", category = "class_hall", expansion = "Legion"},
    [245908] = {achievementID = 60970, achievementName = "Legendary Research of the Uncrowned", category = "class_hall", expansion = "Legion"},
    [245909] = {achievementID = 60971, achievementName = "Legendary Research of the Maelstrom", category = "class_hall", expansion = "Legion"},
    [245910] = {achievementID = 60972, achievementName = "Legendary Research of the Black Harvest", category = "class_hall", expansion = "Legion"},
    [245911] = {achievementID = 60973, achievementName = "Legendary Research of the Valarjar", category = "class_hall", expansion = "Legion"},
    [247575] = {achievementID = 42276, achievementName = "The Highlord's Campaign", category = "class_hall", expansion = "Legion"},
    [247609] = {achievementID = 42291, achievementName = "Hidden Potential of the Archmage", category = "class_hall", expansion = "Legion"},
    [247824] = {achievementID = 42277, achievementName = "The High Priest's Campaign", category = "class_hall", expansion = "Legion"},
    [248011] = {achievementID = 42273, achievementName = "The Huntmaster's Campaign", category = "class_hall", expansion = "Legion"},
    [248940] = {achievementID = 42297, achievementName = "Hidden Potential of the Netherlord", category = "class_hall", expansion = "Legion"},
    [248942] = {achievementID = 60986, achievementName = "Raise an Army for the Temple of Five Dawns", category = "class_hall", expansion = "Legion"},
    [248958] = {achievementID = 42275, achievementName = "The Grandmaster's Campaign", category = "class_hall", expansion = "Legion"},
    [248960] = {achievementID = 42281, achievementName = "The Netherlord's Campaign", category = "class_hall", expansion = "Legion"},
    [249457] = {achievementID = 42288, achievementName = "Hidden Potential of the Slayer", category = "class_hall", expansion = "Legion"},
    [249458] = {achievementID = 42298, achievementName = "Hidden Potential of the Battlelord", category = "class_hall", expansion = "Legion"},
    [249459] = {achievementID = 42271, achievementName = "The Slayer's Campaign", category = "class_hall", expansion = "Legion"},
    [249461] = {achievementID = 60992, achievementName = "Raise an Army for Skyhold", category = "class_hall", expansion = "Legion"},
    [249466] = {achievementID = 42282, achievementName = "The Battlelord's Campaign", category = "class_hall", expansion = "Legion"},
    [249518] = {achievementID = 60982, achievementName = "Raise an Army for the Fel Hammer", category = "class_hall", expansion = "Legion"},
    [249690] = {achievementID = 60963, achievementName = "Legendary Research of the Illidari", category = "class_hall", expansion = "Legion"},
    [250111] = {achievementID = 60964, achievementName = "Legendary Research of the Dreamgrove", category = "class_hall", expansion = "Legion"},
    [250112] = {achievementID = 60981, achievementName = "Raise an Army for Acherus", category = "class_hall", expansion = "Legion"},
    [250115] = {achievementID = 42270, achievementName = "The Deathlord's Campaign", category = "class_hall", expansion = "Legion"},
    [250123] = {achievementID = 42287, achievementName = "Hidden Potential of the Deathlord", category = "class_hall", expansion = "Legion"},
    [250125] = {achievementID = 42290, achievementName = "Hidden Potential of the Huntmaster", category = "class_hall", expansion = "Legion"},
    [250126] = {achievementID = 60984, achievementName = "Raise an Army for the Trueshot Lodge", category = "class_hall", expansion = "Legion"},
    [250127] = {achievementID = 60965, achievementName = "Legendary Research of the Unseen Path", category = "class_hall", expansion = "Legion"},
    [250131] = {achievementID = 60985, achievementName = "Raise an Army for the Hall of the Guardian", category = "class_hall", expansion = "Legion"},
    [250134] = {achievementID = 42289, achievementName = "Hidden Potential of the Archdruid", category = "class_hall", expansion = "Legion"},
    [250230] = {achievementID = 42293, achievementName = "Hidden Potential of the Highlord", category = "class_hall", expansion = "Legion"},
    [250233] = {achievementID = 60968, achievementName = "Legendary Research of the Silver Hand", category = "class_hall", expansion = "Legion"},
    [250234] = {achievementID = 42276, achievementName = "The Highlord's Campaign", category = "class_hall", expansion = "Legion"},
    [250236] = {achievementID = 60987, achievementName = "Raise an Army for the Sanctum of Light", category = "class_hall", expansion = "Legion"},
    [250306] = {achievementID = 42291, achievementName = "Hidden Potential of the Archmage", category = "class_hall", expansion = "Legion"},
    [250786] = {achievementID = 60989, achievementName = "Raise an Army for the Hall of Shadows", category = "class_hall", expansion = "Legion"},
    [250787] = {achievementID = 42295, achievementName = "Hidden Potential of the Shadowblade", category = "class_hall", expansion = "Legion"},
    [250788] = {achievementID = 60970, achievementName = "Legendary Research of the Uncrowned", category = "class_hall", expansion = "Legion"},
    [250790] = {achievementID = 42294, achievementName = "Hidden Potential of the High Priest", category = "class_hall", expansion = "Legion"},
    [250791] = {achievementID = 60969, achievementName = "Legendary Research of the Netherlight Conclave", category = "class_hall", expansion = "Legion"},
    [250792] = {achievementID = 42277, achievementName = "The High Priest's Campaign", category = "class_hall", expansion = "Legion"},
    [250914] = {achievementID = 42296, achievementName = "Hidden Potential of the Farseer", category = "class_hall", expansion = "Legion"},
    [250915] = {achievementID = 60971, achievementName = "Legendary Research of the Maelstrom", category = "class_hall", expansion = "Legion"},
    [251013] = {achievementID = 60983, achievementName = "Raise an Army for the Dreamgrove", category = "class_hall", expansion = "Legion"},
    [251014] = {achievementID = 60990, achievementName = "Raise an Army for the Maelstrom", category = "class_hall", expansion = "Legion"},
    [251275] = {achievementID = 60966, achievementName = "Legendary Research of the Tirisgarde", category = "class_hall", expansion = "Legion"},
    [251493] = {achievementID = 42280, achievementName = "The Farseer's Campaign", category = "class_hall", expansion = "Legion"},
    [251636] = {achievementID = 60988, achievementName = "Raise an Army for the Netherlight Temple", category = "class_hall", expansion = "Legion"},
    [254358] = {achievementID = 42272, achievementName = "The Archdruid's Campaign", category = "class_hall", expansion = "Legion"},
    [254461] = {achievementID = 42279, achievementName = "The Shadowblade's Campaign", category = "class_hall", expansion = "Legion"},
    [256674] = {achievementID = 60966, achievementName = "Legendary Research of the Tirisgarde", category = "class_hall", expansion = "Legion"},
    [256679] = {achievementID = 60967, achievementName = "Legendary Research of Five Dawns", category = "class_hall", expansion = "Legion"},
    [256907] = {achievementID = 60972, achievementName = "Legendary Research of the Black Harvest", category = "class_hall", expansion = "Legion"},
    [257396] = {achievementID = 60973, achievementName = "Legendary Research of the Valarjar", category = "class_hall", expansion = "Legion"},
    [257403] = {achievementID = 42280, achievementName = "The Farseer's Campaign", category = "class_hall", expansion = "Legion"},
    [260581] = {achievementID = 42272, achievementName = "The Archdruid's Campaign", category = "class_hall", expansion = "Legion"},
    [260584] = {achievementID = 60962, achievementName = "Legendary Research of the Ebon Blade", category = "class_hall", expansion = "Legion"},
    [260776] = {achievementID = 42279, achievementName = "The Shadowblade's Campaign", category = "class_hall", expansion = "Legion"},
    [262619] = {achievementID = 42292, achievementName = "Hidden Potential of the Grandmaster", category = "class_hall", expansion = "Legion"},
    [264242] = {achievementID = 60991, achievementName = "Raise an Army for the Dreadscar Rift", category = "class_hall", expansion = "Legion"},

    -- Reputation
    [250307] = {achievementID = 42318, achievementName = "Court of Farondis", category = "reputation", expansion = "Legion"},
    [250402] = {achievementID = 42658, achievementName = "Valarjar", category = "reputation", expansion = "Legion"},
    [250407] = {achievementID = 42619, achievementName = "Dreamweavers", category = "reputation", expansion = "Legion"},
    [250690] = {achievementID = 42627, achievementName = "Argussian Reach", category = "reputation", expansion = "Legion"},
    [251778] = {achievementID = 61218, achievementName = "The Wardens", category = "reputation", expansion = "Legion"},
    [256677] = {achievementID = 42628, achievementName = "The Nightfallen", category = "reputation", expansion = "Legion"},
    [258299] = {achievementID = 42547, achievementName = "Highmountain Tribe", category = "reputation", expansion = "Legion"},

    -- Quests
    [241881] = {achievementID = 10698, achievementName = "That's Val'sharah Folks!", category = "quests", expansion = "Legion"},
    [243982] = {achievementID = 11340, achievementName = "Insurrection", category = "quests", expansion = "Legion"},
    [245448] = {achievementID = 11124, achievementName = "Good Suramaritan", category = "quests", expansion = "Legion"},
    [245697] = {achievementID = 10698, achievementName = "That's Val'sharah Folks!", category = "quests", expansion = "Legion"},
    [247843] = {achievementID = 11340, achievementName = "Insurrection", category = "quests", expansion = "Legion"},
    [249165] = {achievementID = 42655, achievementName = "The Armies of Legionfall", category = "quests", expansion = "Legion"},
    [252753] = {achievementID = 42655, achievementName = "The Armies of Legionfall", category = "quests", expansion = "Legion"},

    -- Exploration
    [241307] = {achievementID = 11257, achievementName = "Treasures of Highmountain", category = "exploration", expansion = "Legion"},
    [241887] = {achievementID = 11258, achievementName = "Treasures of Val'sharah", category = "exploration", expansion = "Legion"},
    [245460] = {achievementID = 11257, achievementName = "Treasures of Highmountain", category = "exploration", expansion = "Legion"},
    [245703] = {achievementID = 11258, achievementName = "Treasures of Val'sharah", category = "exploration", expansion = "Legion"},
    [247690] = {achievementID = 42674, achievementName = "Broken Isles World Quests V", category = "exploration", expansion = "Legion"},
    [250622] = {achievementID = 42675, achievementName = "Defending the Broken Isles III", category = "exploration", expansion = "Legion"},
    [250689] = {achievementID = 61054, achievementName = "Heroic Broken Isles World Quests III", category = "exploration", expansion = "Legion"},
    [250693] = {achievementID = 42674, achievementName = "Broken Isles World Quests V", category = "exploration", expansion = "Legion"},
    [251315] = {achievementID = 10996, achievementName = "Got to Ketchum All", category = "exploration", expansion = "Legion"},
    [251751] = {achievementID = 10398, achievementName = "Drum Circle", category = "exploration", expansion = "Legion"},
    [256913] = {achievementID = 10996, achievementName = "Got to Ketchum All", category = "exploration", expansion = "Legion"},
    -- [257721] corrected from ach 11341 "Nightborne Armory" (NOT_FOUND) to 10398 "Drum Circle" via crossref
    [257721] = {achievementID = 10398, achievementName = "Drum Circle", category = "exploration", expansion = "Legion"},

    -- Dungeons
    [247624] = {achievementID = 42321, achievementName = "Legion Remix Raids", category = "dungeons", expansion = "Legion"},
    [250403] = {achievementID = 42692, achievementName = "Broken Isles Dungeoneer", category = "dungeons", expansion = "Legion"},
    [250405] = {achievementID = 61060, achievementName = "Power of the Obelisks II", category = "dungeons", expansion = "Legion"},
    [250406] = {achievementID = 42321, achievementName = "Legion Remix Raids", category = "dungeons", expansion = "Legion"},
    [251325] = {achievementID = 62289, achievementName = "Zul'Aman: The Highest Peaks", category = "dungeons", expansion = "Legion"},
    [251779] = {achievementID = 42689, achievementName = "Timeworn Keystone Master", category = "dungeons", expansion = "Legion"},
    [251909] = {achievementID = 11699, achievementName = "Grand Fin-ale", category = "dungeons", expansion = "Legion"},
    [255573] = {achievementID = 62122, achievementName = "Tallest Tree in the Forest", category = "dungeons", expansion = "Legion"},
    [258223] = {achievementID = 11699, achievementName = "Grand Fin-ale", category = "dungeons", expansion = "Legion"},

    ---------------------------------------------------------------------------
    -- Warlords of Draenor (WoD)
    ---------------------------------------------------------------------------

    -- Exploration
    [258740] = {achievementID = 9415, achievementName = "Secrets of Skettis", category = "exploration", expansion = "Warlords of Draenor"},

    ---------------------------------------------------------------------------
    -- Mists of Pandaria (MoP)
    ---------------------------------------------------------------------------

    -- Exploration
    [251300] = {achievementID = 7322, achievementName = "Roll Club", category = "exploration", expansion = "Mists of Pandaria"},

    -- PvP
    [247740] = {achievementID = 6981, achievementName = "Master of Temple of Kotmogu", category = "pvp", expansion = "Mists of Pandaria"},
    [247741] = {achievementID = 6981, achievementName = "Master of Temple of Kotmogu", category = "pvp", expansion = "Mists of Pandaria"},
    [251298] = {achievementID = 6981, achievementName = "Master of Temple of Kotmogu", category = "pvp", expansion = "Mists of Pandaria"},
    [251299] = {achievementID = 6981, achievementName = "Master of Temple of Kotmogu", category = "pvp", expansion = "Mists of Pandaria"},

    -- Dungeons
    [251301] = {achievementID = 8316, achievementName = "Blood in the Snow", category = "dungeons", expansion = "Mists of Pandaria"},
    [256425] = {achievementID = 8316, achievementName = "Blood in the Snow", category = "dungeons", expansion = "Mists of Pandaria"},

    ---------------------------------------------------------------------------
    -- Cataclysm (Cata)
    ---------------------------------------------------------------------------

    -- PvP
    [247727] = {achievementID = 5223, achievementName = "Master of Twin Peaks", category = "pvp", expansion = "Cataclysm"},
    [251296] = {achievementID = 5245, achievementName = "Battle for Gilneas Victory", category = "pvp", expansion = "Cataclysm"},
    [251297] = {achievementID = 5223, achievementName = "Master of Twin Peaks", category = "pvp", expansion = "Cataclysm"},
    [256896] = {achievementID = 5245, achievementName = "Battle for Gilneas Victory", category = "pvp", expansion = "Cataclysm"},

    ---------------------------------------------------------------------------
    -- Wrath of the Lich King (WotLK)
    ---------------------------------------------------------------------------

    -- Quests
    [244842] = {achievementID = 938, achievementName = "The Snows of Northrend", category = "quests", expansion = "Wrath of the Lich King"},
    [248807] = {achievementID = 938, achievementName = "The Snows of Northrend", category = "quests", expansion = "Wrath of the Lich King"},

    ---------------------------------------------------------------------------
    -- Classic
    ---------------------------------------------------------------------------

    -- Quests
    [244813] = {achievementID = 5442, achievementName = "Full Caravan", category = "quests", expansion = "Classic"},
    [244841] = {achievementID = 940, achievementName = "The Green Hills of Stranglethorn", category = "quests", expansion = "Classic"},
    [248796] = {achievementID = 5442, achievementName = "Full Caravan", category = "quests", expansion = "Classic"},
    [248808] = {achievementID = 940, achievementName = "The Green Hills of Stranglethorn", category = "quests", expansion = "Classic"},

    -- Dungeons
    [241216] = {achievementID = 4859, achievementName = "Kings Under the Mountain", category = "dungeons", expansion = "Classic"},
    [241674] = {achievementID = 4405, achievementName = "More Dots! (25 player)", category = "dungeons", expansion = "Classic"},
    [244852] = {achievementID = 4405, achievementName = "More Dots! (25 player)", category = "dungeons", expansion = "Classic"},
    [245426] = {achievementID = 4859, achievementName = "Kings Under the Mountain", category = "dungeons", expansion = "Classic"},

    -- PvP
    [243884] = {achievementID = 231, achievementName = "Wrecking Ball", category = "pvp", expansion = "Classic"},
    [243893] = {achievementID = 1157, achievementName = "Duel-icious", category = "pvp", expansion = "Classic"},
    [243894] = {achievementID = 158, achievementName = "Me and the Cappin' Makin' It Happen", category = "pvp", expansion = "Classic"},
    [243895] = {achievementID = 229, achievementName = "The Grim Reaper", category = "pvp", expansion = "Classic"},
    [243896] = {achievementID = 221, achievementName = "Alterac Grave Robber", category = "pvp", expansion = "Classic"},
    [243897] = {achievementID = 222, achievementName = "Tower Defense", category = "pvp", expansion = "Classic"},
    [243898] = {achievementID = 1153, achievementName = "Overly Defensive", category = "pvp", expansion = "Classic"},
    [243899] = {achievementID = 212, achievementName = "Storm Capper", category = "pvp", expansion = "Classic"},
    [243900] = {achievementID = 213, achievementName = "Stormtrooper", category = "pvp", expansion = "Classic"},
    [243901] = {achievementID = 200, achievementName = "Persistent Defender", category = "pvp", expansion = "Classic"},
    [243902] = {achievementID = 167, achievementName = "Warsong Gulch Veteran", category = "pvp", expansion = "Classic"},
    [247744] = {achievementID = 231, achievementName = "Wrecking Ball", category = "pvp", expansion = "Classic"},
    [247745] = {achievementID = 229, achievementName = "The Grim Reaper", category = "pvp", expansion = "Classic"},
    [247746] = {achievementID = 200, achievementName = "Persistent Defender", category = "pvp", expansion = "Classic"},
    [247747] = {achievementID = 167, achievementName = "Warsong Gulch Veteran", category = "pvp", expansion = "Classic"},
    [247756] = {achievementID = 1157, achievementName = "Duel-icious", category = "pvp", expansion = "Classic"},
    [247757] = {achievementID = 158, achievementName = "Me and the Cappin' Makin' It Happen", category = "pvp", expansion = "Classic"},
    [247758] = {achievementID = 221, achievementName = "Alterac Grave Robber", category = "pvp", expansion = "Classic"},
    [247759] = {achievementID = 1153, achievementName = "Overly Defensive", category = "pvp", expansion = "Classic"},
    [247760] = {achievementID = 222, achievementName = "Tower Defense", category = "pvp", expansion = "Classic"},
    [247761] = {achievementID = 212, achievementName = "Storm Capper", category = "pvp", expansion = "Classic"},
    [247762] = {achievementID = 213, achievementName = "Stormtrooper", category = "pvp", expansion = "Classic"},

    ---------------------------------------------------------------------------
    -- Midnight
    ---------------------------------------------------------------------------

    -- Meta
    [260785] = {achievementID = 62387, achievementName = "It's Nearly Midnight", category = "meta", expansion = "Midnight"},

    -- Professions
    [263997] = {achievementID = 42788, achievementName = "Alchemizing at Midnight", category = "professions", expansion = "Midnight"},
    [263998] = {achievementID = 42792, achievementName = "Blacksmithing at Midnight", category = "professions", expansion = "Midnight"},
    [263999] = {achievementID = 42795, achievementName = "Cooking at Midnight", category = "professions", expansion = "Midnight"},
    [264000] = {achievementID = 42787, achievementName = "Enchanting at Midnight", category = "professions", expansion = "Midnight"},
    [264001] = {achievementID = 42798, achievementName = "Engineering at Midnight", category = "professions", expansion = "Midnight"},
    [264002] = {achievementID = 42797, achievementName = "Fishing at Midnight", category = "professions", expansion = "Midnight"},
    [264003] = {achievementID = 42793, achievementName = "Herbalism at Midnight", category = "professions", expansion = "Midnight"},
    [264004] = {achievementID = 42796, achievementName = "Inscribing at Midnight", category = "professions", expansion = "Midnight"},
    [264005] = {achievementID = 42789, achievementName = "Jewelcrafting at Midnight", category = "professions", expansion = "Midnight"},
    [264006] = {achievementID = 42786, achievementName = "Leatherworking at Midnight", category = "professions", expansion = "Midnight"},
    [264172] = {achievementID = 42791, achievementName = "Mining at Midnight", category = "professions", expansion = "Midnight"},
    [264173] = {achievementID = 42790, achievementName = "Skinning at Midnight", category = "professions", expansion = "Midnight"},
    [264174] = {achievementID = 42794, achievementName = "Tailoring at Midnight", category = "professions", expansion = "Midnight"},
}

-------------------------------------------------------------------------------
-- Copy to HA namespace for direct itemID lookup (backward-compatible)
-------------------------------------------------------------------------------

HA.AchievementSources = sourceData

-------------------------------------------------------------------------------
-- Reverse Index: achievementID -> list of itemIDs (built once at load time)
-------------------------------------------------------------------------------

local achievementToItems = {}

for itemID, data in pairs(sourceData) do
    local achID = data.achievementID
    if not achievementToItems[achID] then
        achievementToItems[achID] = {}
    end
    achievementToItems[achID][#achievementToItems[achID] + 1] = itemID
end

AchievementSources.achievementToItems = achievementToItems

-------------------------------------------------------------------------------
-- API Functions
-------------------------------------------------------------------------------

--- Get achievement info for an item (O(1) lookup, replaces AchievementDecor:GetAchievementForItem)
function AchievementSources:GetAchievementForItem(itemID)
    local data = sourceData[itemID]
    if not data then return nil end

    local _, _, _, completed = GetAchievementInfo(data.achievementID)
    return {
        achievementID = data.achievementID,
        name = data.achievementName,
        category = data.category,
        expansion = data.expansion,
        completed = completed,
    }
end

--- Get all items from a specific achievement
function AchievementSources:GetItemsForAchievement(achievementID)
    return achievementToItems[achievementID] or {}
end

--- Get all items from a specific expansion
function AchievementSources:GetItemsByExpansion(expansion)
    local items = {}
    for itemID, data in pairs(sourceData) do
        if data.expansion == expansion then
            items[#items + 1] = {
                itemID = itemID,
                achievementID = data.achievementID,
                achievementName = data.achievementName,
                category = data.category,
            }
        end
    end
    return items
end

--- Get all items from a specific category
function AchievementSources:GetItemsByCategory(category)
    local items = {}
    for itemID, data in pairs(sourceData) do
        if data.category == category then
            items[#items + 1] = {
                itemID = itemID,
                achievementID = data.achievementID,
                achievementName = data.achievementName,
                expansion = data.expansion,
            }
        end
    end
    return items
end

--- Check if player has completed an achievement
function AchievementSources:IsAchievementCompleted(achievementID)
    local _, _, _, completed = GetAchievementInfo(achievementID)
    return completed
end

--- Get all unique itemIDs
function AchievementSources:GetAllItemIDs()
    local itemIDs = {}
    for itemID in pairs(sourceData) do
        itemIDs[#itemIDs + 1] = itemID
    end
    return itemIDs
end

--- Get stats summary
function AchievementSources:GetStats()
    local totalItems = 0
    local byExpansion = {}
    local byCategory = {}
    local uniqueAchievements = {}

    for _, data in pairs(sourceData) do
        totalItems = totalItems + 1

        local exp = data.expansion or "Unknown"
        byExpansion[exp] = (byExpansion[exp] or 0) + 1

        local cat = data.category or "unknown"
        byCategory[cat] = (byCategory[cat] or 0) + 1

        uniqueAchievements[data.achievementID] = data.achievementName
    end

    local total = 0
    local completed = 0
    for achievementID in pairs(uniqueAchievements) do
        total = total + 1
        if self:IsAchievementCompleted(achievementID) then
            completed = completed + 1
        end
    end

    return {
        total = total,
        completed = completed,
        totalItems = totalItems,
        byExpansion = byExpansion,
        byCategory = byCategory,
    }
end

--- Get uncompleted achievements
function AchievementSources:GetUncompletedAchievements()
    local seen = {}
    for _, data in pairs(sourceData) do
        if not seen[data.achievementID] then
            seen[data.achievementID] = {
                achievementID = data.achievementID,
                name = data.achievementName,
                category = data.category,
                expansion = data.expansion,
                itemIDs = achievementToItems[data.achievementID],
            }
        end
    end

    local uncompleted = {}
    for achievementID, info in pairs(seen) do
        if not self:IsAchievementCompleted(achievementID) then
            uncompleted[#uncompleted + 1] = info
        end
    end

    local expansionOrder = {["The War Within"] = 1, Midnight = 2, Dragonflight = 3, Shadowlands = 4, ["Battle for Azeroth"] = 5, Legion = 6, ["Warlords of Draenor"] = 7, ["Mists of Pandaria"] = 8, Cataclysm = 9, ["Wrath of the Lich King"] = 10, Classic = 11}
    table.sort(uncompleted, function(a, b)
        local orderA = expansionOrder[a.expansion] or 99
        local orderB = expansionOrder[b.expansion] or 99
        if orderA == orderB then
            return a.name < b.name
        end
        return orderA < orderB
    end)
    return uncompleted
end

-------------------------------------------------------------------------------
-- Debug Command
-------------------------------------------------------------------------------

function AchievementSources:DebugPrint()
    local stats = self:GetStats()

    HA.Addon:Debug("=== Achievement Sources Stats ===")
    HA.Addon:Debug(string.format("Total achievements tracked: %d", stats.total))
    HA.Addon:Debug(string.format("Total decor items: %d", stats.totalItems))
    HA.Addon:Debug(string.format("Completed: %d / %d (%.1f%%)",
        stats.completed, stats.total,
        stats.total > 0 and (stats.completed / stats.total * 100) or 0))

    if stats.total > 0 then
        HA.Addon:Debug("By expansion:")
        local expansionOrder = {"The War Within", "Midnight", "Dragonflight", "Shadowlands", "Battle for Azeroth", "Legion", "Warlords of Draenor", "Mists of Pandaria", "Cataclysm", "Wrath of the Lich King", "Classic"}
        for _, exp in ipairs(expansionOrder) do
            local count = stats.byExpansion[exp]
            if count then
                HA.Addon:Debug(string.format("  %s: %d", exp, count))
            end
        end

        HA.Addon:Debug("By category:")
        for cat, count in pairs(stats.byCategory) do
            HA.Addon:Debug(string.format("  %s: %d", cat, count))
        end
    else
        HA.Addon:Debug("No achievement data loaded.")
    end
end

HA.AchievementSourcesModule = AchievementSources
