--[[
    Homestead - AchievementSources
    Generated: 2026-08-18 22:24:20
    Total entries: 305
    Hand-corrected under HS-405 (2026-09-01): four refuted entries removed to
    mirror the overrides file. Do NOT regenerate without reading HS-392's
    crossref disposition §5 first — the current export vintage lost rows and
    a regen would silently drop five still-valid entries.

    Achievement source data for housing decor items.
    Regenerate with: python Home_Dev/scripts/generate_source_tables.py --table achievement
    DO NOT EDIT — changes will be overwritten. Use overrides file instead:
    Home_Dev/scripts/overrides/achievement_sources_overrides.lua
--]]

local _, HA = ...

local AchievementSources = {}

local sourceData = {
    -- Midnight
    [244656] = {achievementID = 62185, achievementName = "Ever Painting", category = "Midnight"},
    [251325] = {achievementID = 62289, achievementName = "Zul'Aman: The Highest Peaks", category = "Midnight"},
    [251909] = {achievementID = 62186, achievementName = "The Party Must Go On", category = "Midnight"},
    [254773] = {achievementID = 62288, achievementName = "Eversong Woods: The Highest Peaks", category = "Midnight"},
    [255573] = {achievementID = 62122, achievementName = "Tallest Tree in the Forest", category = "Midnight"},
    [256925] = {achievementID = 62289, achievementName = "Zul'Aman: The Highest Peaks", category = "Midnight"},
    [257367] = {achievementID = 61507, achievementName = "A Bloody Song", category = "Midnight"},
    [264259] = {achievementID = 61574, achievementName = "Legends Never Die", category = "Midnight"},
    [264266] = {achievementID = 61264, achievementName = "Leaf None Behind", category = "Midnight"},
    [264335] = {achievementID = 62122, achievementName = "Tallest Tree in the Forest", category = "Midnight"},
    [264493] = {achievementID = 62130, achievementName = "The Ultimate Predator", category = "Midnight"},
    [264656] = {achievementID = 62291, achievementName = "Voidstorm: The Highest Peaks", category = "Midnight"},
    [265792] = {achievementID = 62290, achievementName = "Harandar: The Highest Peaks", category = "Midnight"},

    -- Void Assaults
    [276083] = {achievementID = 63325, achievementName = "Omnium Folio Studies", category = "Void Assaults"},

    -- War Within
    [245324] = {achievementID = 40894, achievementName = "Sojourner of Undermine", category = "War Within"},
    [246866] = {achievementID = 40542, achievementName = "Smelling History", category = "War Within"},
    [246867] = {achievementID = 41186, achievementName = "Slate of the Union", category = "War Within"},
    [249169] = {achievementID = 20595, achievementName = "Sojourner of Isle of Dorn", category = "War Within"},
    [249181] = {achievementID = 40504, achievementName = "Rocked to Sleep", category = "War Within"},
    [249185] = {achievementID = 40859, achievementName = "We're Here All Night", category = "War Within"},
    [251271] = {achievementID = 40894, achievementName = "Sojourner of Undermine", category = "War Within"},
    [252532] = {achievementID = 40542, achievementName = "Smelling History", category = "War Within"},
    [252533] = {achievementID = 41186, achievementName = "Slate of the Union", category = "War Within"},
    [252757] = {achievementID = 20595, achievementName = "Sojourner of Isle of Dorn", category = "War Within"},
    [253023] = {achievementID = 40504, achievementName = "Rocked to Sleep", category = "War Within"},
    [253037] = {achievementID = 40859, achievementName = "We're Here All Night", category = "War Within"},

    -- Dragonflight
    [240857] = {achievementID = 19719, achievementName = "Reclamation of Gilneas", category = "Dragonflight"},
    [245520] = {achievementID = 19719, achievementName = "Reclamation of Gilneas", category = "Dragonflight"},
    [247900] = {achievementID = 17773, achievementName = "A Blue Dawn", category = "Dragonflight"},
    [248104] = {achievementID = 17773, achievementName = "A Blue Dawn", category = "Dragonflight"},
    [248105] = {achievementID = 19507, achievementName = "Fringe Benefits", category = "Dragonflight"},
    [248200] = {achievementID = 19507, achievementName = "Fringe Benefits", category = "Dragonflight"},

    -- Battle for Azeroth
    [241062] = {achievementID = 12509, achievementName = "Ready for War", category = "Battle for Azeroth"},
    [241100] = {achievementID = 12582, achievementName = "Come Sail Away", category = "Battle for Azeroth"},
    [241150] = {achievementID = 12997, achievementName = "The Pride of Kul Tiras", category = "Battle for Azeroth"},
    [241175] = {achievementID = 13038, achievementName = "Raptari Rider", category = "Battle for Azeroth"},
    [241200] = {achievementID = 13049, achievementName = "The Long Con", category = "Battle for Azeroth"},
    [241250] = {achievementID = 12614, achievementName = "Loa Expectations", category = "Battle for Azeroth"},
    [241300] = {achievementID = 13039, achievementName = "Paku'ai", category = "Battle for Azeroth"},
    [241350] = {achievementID = 12509, achievementName = "Ready for War", category = "Battle for Azeroth"},
    [241400] = {achievementID = 12479, achievementName = "Zandalar Forever!", category = "Battle for Azeroth"},
    [241500] = {achievementID = 13284, achievementName = "Frontline Warrior", category = "Battle for Azeroth"},
    [241750] = {achievementID = 13473, achievementName = "Diversified Investments", category = "Battle for Azeroth"},
    [241800] = {achievementID = 13018, achievementName = "Dune Rider", category = "Battle for Azeroth"},
    [241850] = {achievementID = 13477, achievementName = "Junkyard Apprentice", category = "Battle for Azeroth"},
    [241900] = {achievementID = 13475, achievementName = "Junkyard Scavenger", category = "Battle for Azeroth"},
    [244326] = {achievementID = 13018, achievementName = "Dune Rider", category = "Battle for Azeroth"},
    [245271] = {achievementID = 12582, achievementName = "Come Sail Away", category = "Battle for Azeroth"},
    [245476] = {achievementID = 13284, achievementName = "Frontline Warrior", category = "Battle for Azeroth"},
    [245487] = {achievementID = 13038, achievementName = "Raptari Rider", category = "Battle for Azeroth"},
    [245494] = {achievementID = 13039, achievementName = "Paku'ai", category = "Battle for Azeroth"},
    [245497] = {achievementID = 12614, achievementName = "Loa Expectations", category = "Battle for Azeroth"},
    [245522] = {achievementID = 12479, achievementName = "Zandalar Forever!", category = "Battle for Azeroth"},
    [246483] = {achievementID = 13473, achievementName = "Diversified Investments", category = "Battle for Azeroth"},
    [246598] = {achievementID = 13477, achievementName = "Junkyard Apprentice", category = "Battle for Azeroth"},
    [246603] = {achievementID = 13475, achievementName = "Junkyard Scavenger", category = "Battle for Azeroth"},
    [252653] = {achievementID = 13049, achievementName = "The Long Con", category = "Battle for Azeroth"},
    [252654] = {achievementID = 12997, achievementName = "The Pride of Kul Tiras", category = "Battle for Azeroth"},

    -- Legion
    [241307] = {achievementID = 11257, achievementName = "Treasures of Highmountain", category = "Legion"},
    [241881] = {achievementID = 10698, achievementName = "That's Val'sharah Folks!", category = "Legion"},
    [241887] = {achievementID = 11258, achievementName = "Treasures of Val'sharah", category = "Legion"},
    [243982] = {achievementID = 11340, achievementName = "Insurrection", category = "Legion"},
    [245448] = {achievementID = 11124, achievementName = "Good Suramaritan", category = "Legion"},
    [245460] = {achievementID = 11257, achievementName = "Treasures of Highmountain", category = "Legion"},
    [245697] = {achievementID = 10698, achievementName = "That's Val'sharah Folks!", category = "Legion"},
    [245703] = {achievementID = 11258, achievementName = "Treasures of Val'sharah", category = "Legion"},
    [247843] = {achievementID = 11340, achievementName = "Insurrection", category = "Legion"},
    [251751] = {achievementID = 10398, achievementName = "Drum Circle", category = "Legion"},
    [257721] = {achievementID = 10398, achievementName = "Drum Circle", category = "Legion"},

    -- Expansion Features
    [244181] = {achievementID = 20501, achievementName = "Back from the Beyond", category = "Expansion Features"},
    [247667] = {achievementID = 40953, achievementName = "A Farewell to Arms", category = "Expansion Features"},
    [247668] = {achievementID = 40953, achievementName = "A Farewell to Arms", category = "Expansion Features"},
    [248124] = {achievementID = 19458, achievementName = "A World Awoken", category = "Expansion Features"},
    [248125] = {achievementID = 20501, achievementName = "Back from the Beyond", category = "Expansion Features"},
    [257353] = {achievementID = 61451, achievementName = "Worldsoul-Searching", category = "Expansion Features"},
    [267122] = {achievementID = 61451, achievementName = "Worldsoul-Searching", category = "Expansion Features"},

    -- Archaeology
    [241216] = {achievementID = 4859, achievementName = "Kings Under the Mountain", category = "Archaeology"},
    [245426] = {achievementID = 4859, achievementName = "Kings Under the Mountain", category = "Archaeology"},
    [258740] = {achievementID = 9415, achievementName = "Secrets of Skettis", category = "Archaeology"},

    -- Cooking
    [241450] = {achievementID = 12746, achievementName = "The Zandalari Menu", category = "Cooking"},
    [244325] = {achievementID = 12746, achievementName = "The Zandalari Menu", category = "Cooking"},

    -- Legion Class Hall
    [240750] = {achievementID = 42274, achievementName = "The Archmage's Campaign", category = "Legion Class Hall"},
    [244042] = {achievementID = 42273, achievementName = "The Huntmaster's Campaign", category = "Legion Class Hall"},
    [245126] = {achievementID = 42275, achievementName = "The Grandmaster's Campaign", category = "Legion Class Hall"},
    [245128] = {achievementID = 42282, achievementName = "The Battlelord's Campaign", category = "Legion Class Hall"},
    [245429] = {achievementID = 42274, achievementName = "The Archmage's Campaign", category = "Legion Class Hall"},
    [245527] = {achievementID = 42271, achievementName = "The Slayer's Campaign", category = "Legion Class Hall"},
    [245878] = {achievementID = 60964, achievementName = "Legendary Research of the Dreamgrove", category = "Legion Class Hall"},
    [245882] = {achievementID = 42270, achievementName = "The Deathlord's Campaign", category = "Legion Class Hall"},
    [245888] = {achievementID = 42287, achievementName = "Hidden Potential of the Deathlord", category = "Legion Class Hall"},
    [245889] = {achievementID = 42288, achievementName = "Hidden Potential of the Slayer", category = "Legion Class Hall"},
    [245890] = {achievementID = 42289, achievementName = "Hidden Potential of the Archdruid", category = "Legion Class Hall"},
    [245891] = {achievementID = 42290, achievementName = "Hidden Potential of the Huntmaster", category = "Legion Class Hall"},
    [245893] = {achievementID = 42292, achievementName = "Hidden Potential of the Grandmaster", category = "Legion Class Hall"},
    [245894] = {achievementID = 42293, achievementName = "Hidden Potential of the Highlord", category = "Legion Class Hall"},
    [245895] = {achievementID = 42294, achievementName = "Hidden Potential of the High Priest", category = "Legion Class Hall"},
    [245896] = {achievementID = 42295, achievementName = "Hidden Potential of the Shadowblade", category = "Legion Class Hall"},
    [245897] = {achievementID = 42296, achievementName = "Hidden Potential of the Farseer", category = "Legion Class Hall"},
    [245898] = {achievementID = 42297, achievementName = "Hidden Potential of the Netherlord", category = "Legion Class Hall"},
    [245899] = {achievementID = 42298, achievementName = "Hidden Potential of the Battlelord", category = "Legion Class Hall"},
    [245900] = {achievementID = 60962, achievementName = "Legendary Research of the Ebon Blade", category = "Legion Class Hall"},
    [245901] = {achievementID = 60963, achievementName = "Legendary Research of the Illidari", category = "Legion Class Hall"},
    [245903] = {achievementID = 60965, achievementName = "Legendary Research of the Unseen Path", category = "Legion Class Hall"},
    [245905] = {achievementID = 60967, achievementName = "Legendary Research of Five Dawns", category = "Legion Class Hall"},
    [245906] = {achievementID = 60968, achievementName = "Legendary Research of the Silver Hand", category = "Legion Class Hall"},
    [245907] = {achievementID = 60969, achievementName = "Legendary Research of the Netherlight Conclave", category = "Legion Class Hall"},
    [245908] = {achievementID = 60970, achievementName = "Legendary Research of the Uncrowned", category = "Legion Class Hall"},
    [245909] = {achievementID = 60971, achievementName = "Legendary Research of the Maelstrom", category = "Legion Class Hall"},
    [245910] = {achievementID = 60972, achievementName = "Legendary Research of the Black Harvest", category = "Legion Class Hall"},
    [245911] = {achievementID = 60973, achievementName = "Legendary Research of the Valarjar", category = "Legion Class Hall"},
    [247575] = {achievementID = 42276, achievementName = "The Highlord's Campaign", category = "Legion Class Hall"},
    [247609] = {achievementID = 42291, achievementName = "Hidden Potential of the Archmage", category = "Legion Class Hall"},
    [247824] = {achievementID = 42277, achievementName = "The High Priest's Campaign", category = "Legion Class Hall"},
    [248011] = {achievementID = 42273, achievementName = "The Huntmaster's Campaign", category = "Legion Class Hall"},
    [248940] = {achievementID = 42297, achievementName = "Hidden Potential of the Netherlord", category = "Legion Class Hall"},
    [248942] = {achievementID = 60986, achievementName = "Raise an Army for the Temple of Five Dawns", category = "Legion Class Hall"},
    [248958] = {achievementID = 42275, achievementName = "The Grandmaster's Campaign", category = "Legion Class Hall"},
    [248960] = {achievementID = 42281, achievementName = "The Netherlord's Campaign", category = "Legion Class Hall"},
    [249457] = {achievementID = 42288, achievementName = "Hidden Potential of the Slayer", category = "Legion Class Hall"},
    [249458] = {achievementID = 42298, achievementName = "Hidden Potential of the Battlelord", category = "Legion Class Hall"},
    [249459] = {achievementID = 42271, achievementName = "The Slayer's Campaign", category = "Legion Class Hall"},
    [249461] = {achievementID = 60992, achievementName = "Raise an Army for Skyhold", category = "Legion Class Hall"},
    [249466] = {achievementID = 42282, achievementName = "The Battlelord's Campaign", category = "Legion Class Hall"},
    [249518] = {achievementID = 60982, achievementName = "Raise an Army for the Fel Hammer", category = "Legion Class Hall"},
    [249690] = {achievementID = 60963, achievementName = "Legendary Research of the Illidari", category = "Legion Class Hall"},
    [250111] = {achievementID = 60964, achievementName = "Legendary Research of the Dreamgrove", category = "Legion Class Hall"},
    [250112] = {achievementID = 60981, achievementName = "Raise an Army for Acherus", category = "Legion Class Hall"},
    [250115] = {achievementID = 42270, achievementName = "The Deathlord's Campaign", category = "Legion Class Hall"},
    [250123] = {achievementID = 42287, achievementName = "Hidden Potential of the Deathlord", category = "Legion Class Hall"},
    [250125] = {achievementID = 42290, achievementName = "Hidden Potential of the Huntmaster", category = "Legion Class Hall"},
    [250126] = {achievementID = 60984, achievementName = "Raise an Army for the Trueshot Lodge", category = "Legion Class Hall"},
    [250127] = {achievementID = 60965, achievementName = "Legendary Research of the Unseen Path", category = "Legion Class Hall"},
    [250131] = {achievementID = 60985, achievementName = "Raise an Army for the Hall of the Guardian", category = "Legion Class Hall"},
    [250134] = {achievementID = 42289, achievementName = "Hidden Potential of the Archdruid", category = "Legion Class Hall"},
    [250230] = {achievementID = 42293, achievementName = "Hidden Potential of the Highlord", category = "Legion Class Hall"},
    [250233] = {achievementID = 60968, achievementName = "Legendary Research of the Silver Hand", category = "Legion Class Hall"},
    [250234] = {achievementID = 42276, achievementName = "The Highlord's Campaign", category = "Legion Class Hall"},
    [250236] = {achievementID = 60987, achievementName = "Raise an Army for the Sanctum of Light", category = "Legion Class Hall"},
    [250306] = {achievementID = 42291, achievementName = "Hidden Potential of the Archmage", category = "Legion Class Hall"},
    [250786] = {achievementID = 60989, achievementName = "Raise an Army for the Hall of Shadows", category = "Legion Class Hall"},
    [250787] = {achievementID = 42295, achievementName = "Hidden Potential of the Shadowblade", category = "Legion Class Hall"},
    [250788] = {achievementID = 60970, achievementName = "Legendary Research of the Uncrowned", category = "Legion Class Hall"},
    [250790] = {achievementID = 42294, achievementName = "Hidden Potential of the High Priest", category = "Legion Class Hall"},
    [250791] = {achievementID = 60969, achievementName = "Legendary Research of the Netherlight Conclave", category = "Legion Class Hall"},
    [250792] = {achievementID = 42277, achievementName = "The High Priest's Campaign", category = "Legion Class Hall"},
    [250914] = {achievementID = 42296, achievementName = "Hidden Potential of the Farseer", category = "Legion Class Hall"},
    [250915] = {achievementID = 60971, achievementName = "Legendary Research of the Maelstrom", category = "Legion Class Hall"},
    [251013] = {achievementID = 60983, achievementName = "Raise an Army for the Dreamgrove", category = "Legion Class Hall"},
    [251014] = {achievementID = 60990, achievementName = "Raise an Army for the Maelstrom", category = "Legion Class Hall"},
    [251275] = {achievementID = 60966, achievementName = "Legendary Research of the Tirisgarde", category = "Legion Class Hall"},
    [251636] = {achievementID = 60988, achievementName = "Raise an Army for the Netherlight Temple", category = "Legion Class Hall"},
    [254358] = {achievementID = 42272, achievementName = "The Archdruid's Campaign", category = "Legion Class Hall"},
    [254461] = {achievementID = 42279, achievementName = "The Shadowblade's Campaign", category = "Legion Class Hall"},
    [256674] = {achievementID = 60966, achievementName = "Legendary Research of the Tirisgarde", category = "Legion Class Hall"},
    [256679] = {achievementID = 60967, achievementName = "Legendary Research of Five Dawns", category = "Legion Class Hall"},
    [256907] = {achievementID = 60972, achievementName = "Legendary Research of the Black Harvest", category = "Legion Class Hall"},
    [257396] = {achievementID = 60973, achievementName = "Legendary Research of the Valarjar", category = "Legion Class Hall"},
    [257403] = {achievementID = 42280, achievementName = "The Farseer's Campaign", category = "Legion Class Hall"},
    [260581] = {achievementID = 42272, achievementName = "The Archdruid's Campaign", category = "Legion Class Hall"},
    [260584] = {achievementID = 60962, achievementName = "Legendary Research of the Ebon Blade", category = "Legion Class Hall"},
    [260776] = {achievementID = 42279, achievementName = "The Shadowblade's Campaign", category = "Legion Class Hall"},
    [262619] = {achievementID = 42292, achievementName = "Hidden Potential of the Grandmaster", category = "Legion Class Hall"},
    [264242] = {achievementID = 60991, achievementName = "Raise an Army for the Dreadscar Rift", category = "Legion Class Hall"},

    -- Legion Remix
    [247624] = {achievementID = 42321, achievementName = "Legion Remix Raids", category = "Legion Remix"},
    [247690] = {achievementID = 42674, achievementName = "Broken Isles World Quests V", category = "Legion Remix"},
    [249165] = {achievementID = 42655, achievementName = "The Armies of Legionfall", category = "Legion Remix"},
    [250307] = {achievementID = 42318, achievementName = "Court of Farondis", category = "Legion Remix"},
    [250402] = {achievementID = 42658, achievementName = "Valarjar", category = "Legion Remix"},
    [250403] = {achievementID = 42692, achievementName = "Broken Isles Dungeoneer", category = "Legion Remix"},
    [250405] = {achievementID = 61060, achievementName = "Power of the Obelisks II", category = "Legion Remix"},
    [250406] = {achievementID = 42321, achievementName = "Legion Remix Raids", category = "Legion Remix"},
    [250407] = {achievementID = 42619, achievementName = "Dreamweavers", category = "Legion Remix"},
    [250622] = {achievementID = 42675, achievementName = "Defending the Broken Isles III", category = "Legion Remix"},
    [250689] = {achievementID = 61054, achievementName = "Heroic Broken Isles World Quests III", category = "Legion Remix"},
    [250690] = {achievementID = 42627, achievementName = "Argussian Reach", category = "Legion Remix"},
    [250693] = {achievementID = 42674, achievementName = "Broken Isles World Quests V", category = "Legion Remix"},
    [251778] = {achievementID = 61218, achievementName = "The Wardens", category = "Legion Remix"},
    [251779] = {achievementID = 42689, achievementName = "Timeworn Keystone Master", category = "Legion Remix"},
    [252753] = {achievementID = 42655, achievementName = "The Armies of Legionfall", category = "Legion Remix"},
    [256677] = {achievementID = 42628, achievementName = "The Nightfallen", category = "Legion Remix"},
    [258299] = {achievementID = 42547, achievementName = "Highmountain Tribe", category = "Legion Remix"},

    -- Lorewalking
    [245332] = {achievementID = 61467, achievementName = "Lorewalking: The Elves of Quel'Thalas", category = "Lorewalking"},
    [257351] = {achievementID = 42189, achievementName = "Lorewalking: The Lich King", category = "Lorewalking"},
    [257354] = {achievementID = 42187, achievementName = "Lorewalking: Ethereal Wisdom", category = "Lorewalking"},
    [257355] = {achievementID = 42188, achievementName = "Lorewalking: Blade's Bane", category = "Lorewalking"},
    [258858] = {achievementID = 42187, achievementName = "Lorewalking: Ethereal Wisdom", category = "Lorewalking"},
    [258859] = {achievementID = 42188, achievementName = "Lorewalking: Blade's Bane", category = "Lorewalking"},
    [258860] = {achievementID = 42189, achievementName = "Lorewalking: The Lich King", category = "Lorewalking"},
    [271971] = {achievementID = 61442, achievementName = "Lorewalking: The Loa", category = "Lorewalking"},

    -- Prey
    [265681] = {achievementID = 62167, achievementName = "Prey: Mad Magisters (Nightmare)", category = "Prey"},
    [265682] = {achievementID = 62168, achievementName = "Prey: Insane Inventors (Nightmare)", category = "Prey"},
    [265683] = {achievementID = 62173, achievementName = "Prey: Ethereal Assassins (Nightmare)", category = "Prey"},
    [265685] = {achievementID = 62175, achievementName = "Prey: Sadistic Shamans (Nightmare)", category = "Prey"},
    [265686] = {achievementID = 62177, achievementName = "Prey: Bloody Green Thumbs (Nightmare)", category = "Prey"},
    [265687] = {achievementID = 62178, achievementName = "Prey: Blinded By The Light (Nightmare)", category = "Prey"},
    [265688] = {achievementID = 62179, achievementName = "Prey: Outsmarting the Schemers (Nightmare)", category = "Prey"},
    [265689] = {achievementID = 62180, achievementName = "Prey: Dominating the Void (Nightmare)", category = "Prey"},
    [265690] = {achievementID = 62181, achievementName = "Prey: Chasing Death (Nightmare)", category = "Prey"},
    [265691] = {achievementID = 62182, achievementName = "Prey: No Rest for the Wretched (Nightmare)", category = "Prey"},
    [265692] = {achievementID = 62183, achievementName = "Prey: A Thorn in the Side (Nightmare)", category = "Prey"},
    [265694] = {achievementID = 62184, achievementName = "Prey: Breaking the Blade (Nightmare)", category = "Prey"},
    [265696] = {achievementID = 62144, achievementName = "Prey: Mad Magisters (Hard)", category = "Prey"},
    [265697] = {achievementID = 62153, achievementName = "Prey: Insane Inventors (Hard)", category = "Prey"},
    [265698] = {achievementID = 62155, achievementName = "Prey: Ethereal Assassins (Hard)", category = "Prey"},
    [265699] = {achievementID = 62156, achievementName = "Prey: Anger Management (Hard)", category = "Prey"},
    [265700] = {achievementID = 62157, achievementName = "Prey: Sadistic Shamans (Hard)", category = "Prey"},
    [265701] = {achievementID = 62159, achievementName = "Prey: Bloody Green Thumbs (Hard)", category = "Prey"},
    [265702] = {achievementID = 62160, achievementName = "Prey: Blinded By The Light (Hard)", category = "Prey"},
    [265703] = {achievementID = 62161, achievementName = "Prey: Outsmarting the Schemers (Hard)", category = "Prey"},
    [265704] = {achievementID = 62162, achievementName = "Prey: Dominating the Void (Hard)", category = "Prey"},
    [265705] = {achievementID = 62163, achievementName = "Prey: Chasing Death (Hard)", category = "Prey"},
    [265706] = {achievementID = 62164, achievementName = "Prey: No Rest for the Wretched (Hard)", category = "Prey"},
    [265707] = {achievementID = 62165, achievementName = "Prey: A Thorn in the Side (Hard)", category = "Prey"},
    [265708] = {achievementID = 62166, achievementName = "Prey: Breaking the Blade (Hard)", category = "Prey"},
    [265796] = {achievementID = 62169, achievementName = "Prey: A Different Kind of Void (Nightmare)", category = "Prey"},
    [265797] = {achievementID = 62176, achievementName = "Prey: The Fallen Farstriders (Nightmare)", category = "Prey"},
    [265798] = {achievementID = 62154, achievementName = "Prey: A Different Kind of Void (Hard)", category = "Prey"},
    [265799] = {achievementID = 62158, achievementName = "Prey: The Fallen Farstriders (Hard)", category = "Prey"},

    -- Professions
    [241191] = {achievementID = 12733, achievementName = "Professional Zandalari Master", category = "Professions"},
    [245490] = {achievementID = 12733, achievementName = "Professional Zandalari Master", category = "Professions"},
    [249237] = {achievementID = 19408, achievementName = "Professional Algari Master", category = "Professions"},
    [253163] = {achievementID = 19408, achievementName = "Professional Algari Master", category = "Professions"},
    [263997] = {achievementID = 42788, achievementName = "Alchemizing at Midnight", category = "Professions"},
    [263998] = {achievementID = 42792, achievementName = "Blacksmithing at Midnight", category = "Professions"},
    [263999] = {achievementID = 42795, achievementName = "Cooking at Midnight", category = "Professions"},
    [264000] = {achievementID = 42787, achievementName = "Enchanting at Midnight", category = "Professions"},
    [264001] = {achievementID = 42798, achievementName = "Engineering at Midnight", category = "Professions"},
    [264002] = {achievementID = 42797, achievementName = "Fishing at Midnight", category = "Professions"},
    [264003] = {achievementID = 42793, achievementName = "Herbalism at Midnight", category = "Professions"},
    [264004] = {achievementID = 42796, achievementName = "Inscribing at Midnight", category = "Professions"},
    [264005] = {achievementID = 42789, achievementName = "Jewelcrafting at Midnight", category = "Professions"},
    [264006] = {achievementID = 42786, achievementName = "Leatherworking at Midnight", category = "Professions"},
    [264172] = {achievementID = 42791, achievementName = "Mining at Midnight", category = "Professions"},
    [264173] = {achievementID = 42790, achievementName = "Skinning at Midnight", category = "Professions"},
    [264174] = {achievementID = 42794, achievementName = "Tailoring at Midnight", category = "Professions"},

    -- War Effort
    [241550] = {achievementID = 12869, achievementName = "Azeroth at War: After Lordaeron", category = "War Effort"},
    [241600] = {achievementID = 12870, achievementName = "Azeroth at War: Kalimdor on Fire", category = "War Effort"},
    [241650] = {achievementID = 12867, achievementName = "Azeroth at War: The Barrens", category = "War Effort"},
    [245463] = {achievementID = 12867, achievementName = "Azeroth at War: The Barrens", category = "War Effort"},
    [245467] = {achievementID = 12869, achievementName = "Azeroth at War: After Lordaeron", category = "War Effort"},
    [245483] = {achievementID = 12870, achievementName = "Azeroth at War: Kalimdor on Fire", category = "War Effort"},

    -- Battle Dungeon
    [241700] = {achievementID = 13723, achievementName = "M.C., Hammered", category = "Battle Dungeon"},
    [246479] = {achievementID = 13723, achievementName = "M.C., Hammered", category = "Battle Dungeon"},

    -- Legion Dungeon
    [251315] = {achievementID = 10996, achievementName = "Got to Ketchum All", category = "Legion Dungeon"},
    [256913] = {achievementID = 10996, achievementName = "Got to Ketchum All", category = "Legion Dungeon"},

    -- Legion Raid
    [258223] = {achievementID = 11699, achievementName = "Grand Fin-ale", category = "Legion Raid"},

    -- Lich King Raid
    [241674] = {achievementID = 4405, achievementName = "More Dots! (25 player)", category = "Lich King Raid"},
    [244852] = {achievementID = 4405, achievementName = "More Dots! (25 player)", category = "Lich King Raid"},

    -- War Within Raid
    [245302] = {achievementID = 41119, achievementName = "One Rank Higher", category = "War Within Raid"},
    [251121] = {achievementID = 41119, achievementName = "One Rank Higher", category = "War Within Raid"},

    -- Dragon Isles
    [248656] = {achievementID = 17529, achievementName = "Forbidden Spoils", category = "Dragon Isles"},

    -- Eastern Kingdoms
    [244813] = {achievementID = 5442, achievementName = "Full Caravan", category = "Eastern Kingdoms"},
    [244841] = {achievementID = 940, achievementName = "The Green Hills of Stranglethorn", category = "Eastern Kingdoms"},
    [248796] = {achievementID = 5442, achievementName = "Full Caravan", category = "Eastern Kingdoms"},
    [248808] = {achievementID = 940, achievementName = "The Green Hills of Stranglethorn", category = "Eastern Kingdoms"},

    -- Northrend
    [244842] = {achievementID = 938, achievementName = "The Snows of Northrend", category = "Northrend"},
    [248807] = {achievementID = 938, achievementName = "The Snows of Northrend", category = "Northrend"},

    -- Pandaria Scenarios
    [251300] = {achievementID = 7322, achievementName = "Roll Club", category = "Pandaria Scenarios"},
    [251301] = {achievementID = 8316, achievementName = "Blood in the Snow", category = "Pandaria Scenarios"},
    [256425] = {achievementID = 8316, achievementName = "Blood in the Snow", category = "Pandaria Scenarios"},

    -- Alterac Valley
    [243896] = {achievementID = 221, achievementName = "Alterac Grave Robber", category = "Alterac Valley"},
    [243897] = {achievementID = 222, achievementName = "Tower Defense", category = "Alterac Valley"},
    [247758] = {achievementID = 221, achievementName = "Alterac Grave Robber", category = "Alterac Valley"},
    [247760] = {achievementID = 222, achievementName = "Tower Defense", category = "Alterac Valley"},

    -- Arathi Basin
    [243894] = {achievementID = 158, achievementName = "Me and the Cappin' Makin' It Happen", category = "Arathi Basin"},
    [243898] = {achievementID = 1153, achievementName = "Overly Defensive", category = "Arathi Basin"},
    [247757] = {achievementID = 158, achievementName = "Me and the Cappin' Makin' It Happen", category = "Arathi Basin"},
    [247759] = {achievementID = 1153, achievementName = "Overly Defensive", category = "Arathi Basin"},

    -- Battle for Gilneas
    [251296] = {achievementID = 5245, achievementName = "Battle for Gilneas Victory", category = "Battle for Gilneas"},
    [256896] = {achievementID = 5245, achievementName = "Battle for Gilneas Victory", category = "Battle for Gilneas"},

    -- Deephaul Ravine
    [243890] = {achievementID = 40612, achievementName = "Sprinting in the Ravine", category = "Deephaul Ravine"},
    [247750] = {achievementID = 40612, achievementName = "Sprinting in the Ravine", category = "Deephaul Ravine"},
    [249200] = {achievementID = 40210, achievementName = "Deephaul Ravine Victory", category = "Deephaul Ravine"},

    -- Eye of the Storm
    [243899] = {achievementID = 212, achievementName = "Storm Capper", category = "Eye of the Storm"},
    [243900] = {achievementID = 213, achievementName = "Stormtrooper", category = "Eye of the Storm"},
    [247761] = {achievementID = 212, achievementName = "Storm Capper", category = "Eye of the Storm"},
    [247762] = {achievementID = 213, achievementName = "Stormtrooper", category = "Eye of the Storm"},

    -- Player vs. Player
    [243884] = {achievementID = 231, achievementName = "Wrecking Ball", category = "Player vs. Player"},
    [243893] = {achievementID = 1157, achievementName = "Duel-icious", category = "Player vs. Player"},
    [243895] = {achievementID = 229, achievementName = "The Grim Reaper", category = "Player vs. Player"},
    [247744] = {achievementID = 231, achievementName = "Wrecking Ball", category = "Player vs. Player"},
    [247745] = {achievementID = 229, achievementName = "The Grim Reaper", category = "Player vs. Player"},
    [247756] = {achievementID = 1157, achievementName = "Duel-icious", category = "Player vs. Player"},
    [247763] = {achievementID = 61683, achievementName = "Entering Battle", category = "Player vs. Player"},
    [247765] = {achievementID = 61687, achievementName = "Champion in Battle", category = "Player vs. Player"},
    [247766] = {achievementID = 61688, achievementName = "Master in Battle", category = "Player vs. Player"},
    [247768] = {achievementID = 61684, achievementName = "Progressing in Battle", category = "Player vs. Player"},
    [247769] = {achievementID = 61685, achievementName = "Proficient in Battle", category = "Player vs. Player"},
    [247770] = {achievementID = 61686, achievementName = "Expert in Battle", category = "Player vs. Player"},
    [267354] = {achievementID = 61683, achievementName = "Entering Battle", category = "Player vs. Player"},
    [267356] = {achievementID = 61685, achievementName = "Proficient in Battle", category = "Player vs. Player"},
    [267357] = {achievementID = 61686, achievementName = "Expert in Battle", category = "Player vs. Player"},
    [267358] = {achievementID = 61687, achievementName = "Champion in Battle", category = "Player vs. Player"},
    [267359] = {achievementID = 61688, achievementName = "Master in Battle", category = "Player vs. Player"},

    -- Temple of Kotmogu
    [247740] = {achievementID = 6981, achievementName = "Master of Temple of Kotmogu", category = "Temple of Kotmogu"},
    [247741] = {achievementID = 6981, achievementName = "Master of Temple of Kotmogu", category = "Temple of Kotmogu"},
    [251298] = {achievementID = 6981, achievementName = "Master of Temple of Kotmogu", category = "Temple of Kotmogu"},
    [251299] = {achievementID = 6981, achievementName = "Master of Temple of Kotmogu", category = "Temple of Kotmogu"},

    -- Twin Peaks
    [247727] = {achievementID = 5223, achievementName = "Master of Twin Peaks", category = "Twin Peaks"},
    [251297] = {achievementID = 5223, achievementName = "Master of Twin Peaks", category = "Twin Peaks"},

    -- Warsong Gulch
    [243901] = {achievementID = 200, achievementName = "Persistent Defender", category = "Warsong Gulch"},
    [243902] = {achievementID = 167, achievementName = "Warsong Gulch Veteran", category = "Warsong Gulch"},
    [247746] = {achievementID = 200, achievementName = "Persistent Defender", category = "Warsong Gulch"},
    [247747] = {achievementID = 167, achievementName = "Warsong Gulch Veteran", category = "Warsong Gulch"},

    -- Events
    [260785] = {achievementID = 62387, achievementName = "It's Nearly Midnight", category = "Events"},
}

-------------------------------------------------------------------------------
-- Category → Expansion derivation (Blizzard's 33 achievement categories)
-- Cross-expansion categories (PvP battlegrounds, Professions, etc.) return nil
-------------------------------------------------------------------------------

local CATEGORY_EXPANSION = {
    -- The War Within
    ["War Within"]       = "The War Within",
    ["War Within Raid"]  = "The War Within",
    ["Deephaul Ravine"]  = "The War Within",
    ["Prey"]             = "The War Within",
    -- Midnight
    ["Midnight"]         = "Midnight",
    ["Void Assaults"]    = "Midnight",
    -- Dragonflight
    ["Dragonflight"]     = "Dragonflight",
    ["Dragon Isles"]     = "Dragonflight",
    -- Battle for Azeroth
    ["Battle for Azeroth"] = "Battle for Azeroth",
    ["War Effort"]       = "Battle for Azeroth",
    ["Battle Dungeon"]   = "Battle for Azeroth",
    -- Legion
    ["Legion"]           = "Legion",
    ["Legion Class Hall"] = "Legion",
    ["Legion Dungeon"]   = "Legion",
    ["Legion Raid"]      = "Legion",
    ["Legion Remix"]     = "Legion",
    -- Wrath of the Lich King
    ["Lich King Raid"]   = "Wrath of the Lich King",
    -- Cross-expansion categories return nil:
    -- Alterac Valley, Arathi Basin, Archaeology, Battle for Gilneas, Cooking,
    -- Eastern Kingdoms, Events, Expansion Features, Eye of the Storm,
    -- Lorewalking, Northrend, Pandaria Scenarios, Player vs. Player,
    -- Professions, Temple of Kotmogu, Twin Peaks, Warsong Gulch
}

-- Expansion display order (single source of truth for sort and debug output)
local EXPANSION_ORDER = {
    "The War Within", "Midnight", "Dragonflight",
    "Battle for Azeroth", "Legion", "Wrath of the Lich King",
    "Cross-expansion",
}

-- Pre-compute expansion priority for sorting (static, built once)
local EXPANSION_PRIORITY = {}
for i, name in ipairs(EXPANSION_ORDER) do
    EXPANSION_PRIORITY[name] = i
end

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
    local list = achievementToItems[achID]
    list[#list + 1] = itemID
end

-------------------------------------------------------------------------------
-- API Functions
-------------------------------------------------------------------------------

--- Get achievement info for an item (O(1) lookup)
function AchievementSources:GetAchievementForItem(itemID)
    local data = sourceData[itemID]
    if not data then return nil end

    local _, _, _, completed = GetAchievementInfo(data.achievementID)
    return {
        achievementID = data.achievementID,
        name = data.achievementName,
        category = data.category,
        expansion = CATEGORY_EXPANSION[data.category],
        completed = completed,
    }
end

--- Get all items from a specific achievement
function AchievementSources:GetItemsForAchievement(achievementID)
    return achievementToItems[achievementID] or {}
end

--- Get all items from a specific expansion (derived from category)
function AchievementSources:GetItemsByExpansion(expansion)
    local items = {}
    for itemID, data in pairs(sourceData) do
        local itemExpansion = CATEGORY_EXPANSION[data.category] or "Cross-expansion"
        if itemExpansion == expansion then
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

--- Get uncompleted achievements (sorted by expansion, then name)
function AchievementSources:GetUncompletedAchievements()
    local uncompleted = {}
    for achievementID, itemIDs in pairs(achievementToItems) do
        if not self:IsAchievementCompleted(achievementID) then
            -- Look up metadata from the first item in this achievement
            local data = sourceData[itemIDs[1]]
            if data then
                uncompleted[#uncompleted + 1] = {
                    achievementID = achievementID,
                    name = data.achievementName,
                    category = data.category,
                    expansion = CATEGORY_EXPANSION[data.category] or "Cross-expansion",
                    itemIDs = itemIDs,
                }
            end
        end
    end

    table.sort(uncompleted, function(a, b)
        local orderA = EXPANSION_PRIORITY[a.expansion] or 99
        local orderB = EXPANSION_PRIORITY[b.expansion] or 99
        if orderA == orderB then
            return a.name < b.name
        end
        return orderA < orderB
    end)
    return uncompleted
end

HA.AchievementSourcesModule = AchievementSources
