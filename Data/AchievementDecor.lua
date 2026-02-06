--[[
    Homestead - Achievement Decor Data
    Maps achievements to their housing decor rewards

    Structure:
    [achievementID] = {
        name = "Achievement Name",
        category = "category",  -- exploration, quests, pvp, dungeons, reputation, events, professions, class_hall
        expansion = "TWW",      -- TWW, DF, SL, BFA, Legion, WoD, MoP, Cata, WotLK, Classic
        items = {
            {itemID = number, name = "Item Name"},
        },
    }

    Data Sources:
    - https://www.wowhead.com/news/decorate-your-home-with-achievements-in-patch-11-2-7-379454
    - https://www.wowhead.com/news/finish-these-retro-achievements-now-to-get-free-housing-decor-in-midnight-378720
    - https://www.wowhead.com/guide/player-housing/decor-farming-the-war-within-quests-drops-achievements-vendors
    - https://housing.wowdb.com/decor/?source_types=Achievement
    - https://blizzardwatch.com/2025/12/05/recreate-legion-class-halls-player-housing-achievements/

    To find achievement IDs:
    /run print(GetAchievementLink(ACHIEVEMENT_ID))

    To check if completed:
    /run print(select(4, GetAchievementInfo(ACHIEVEMENT_ID)))
]]

local addonName, HA = ...

local AchievementDecor = {}
HA.AchievementDecor = AchievementDecor

-- Achievement data table
local achievementData = {
    ---------------------------------------------------------------------------
    -- The War Within (TWW)
    -- Source: https://www.wowhead.com/guide/player-housing/decor-farming-the-war-within-quests-drops-achievements-vendors
    ---------------------------------------------------------------------------

    -- Meta Achievement
    -- Source: https://www.wowhead.com/achievement=61451/worldsoul-searching
    [61451] = {
        name = "Worldsoul-Searching",
        category = "meta",
        expansion = "TWW",
        items = {
            {itemID = 257353, name = "Drained Dark Heart of Galakrond"},
        },
    },

    -- Exploration
    [41186] = {
        name = "Slate of the Union",
        category = "exploration",
        expansion = "TWW",
        items = {
            {itemID = 252533, name = "Tome of Earthen Directives"},
        },
    },
    [40542] = {
        name = "Smelling History",
        category = "exploration",
        expansion = "TWW",
        items = {
            {itemID = 252532, name = "Kaheti Scribe's Records"},
        },
    },
    [20595] = {
        name = "Sojourner of Isle of Dorn",
        category = "exploration",
        expansion = "TWW",
        items = {
            {itemID = 249169, name = "Boulder Springs Recliner"},
        },
    },
    [40859] = {
        name = "We're Here All Night",
        category = "exploration",
        expansion = "TWW",
        items = {
            {itemID = 249185, name = "Dornogal Brazier"},
        },
    },
    [40504] = {
        name = "Rocked to Sleep",
        category = "exploration",
        expansion = "TWW",
        items = {
            {itemID = 249181, name = "Rambleshire Resting Platform"},
        },
    },
    [40894] = {
        name = "Sojourner of Undermine",
        category = "exploration",
        expansion = "TWW",
        items = {
            {itemID = 251271, name = "Rocket-Powered Fountain"},
        },
    },

    -- Professions
    [19408] = {
        name = "Professional Algari Master",
        category = "professions",
        expansion = "TWW",
        items = {
            {itemID = 249237, name = "Fallside Storage Tent"},
        },
    },

    -- Progression
    [41119] = {
        name = "One Rank Higher",
        category = "progression",
        expansion = "TWW",
        items = {
            {itemID = 251121, name = "Gallagio L.U.C.K. Spinner"},
        },
    },

    -- PvP
    [40612] = {
        name = "Sprinting in the Ravine",
        category = "pvp",
        expansion = "TWW",
        items = {
            {itemID = 243890, name = "Deephaul Crystal"},
        },
    },
    [40210] = {
        name = "Deephaul Ravine Victory",
        category = "pvp",
        expansion = "TWW",
        items = {
            {itemID = 249200, name = "Earthen Contender's Target"},
        },
    },

    -- Lorewalking
    [61467] = {
        name = "Lorewalking: The Elves of Quel'Thalas",
        category = "lorewalking",
        expansion = "TWW",
        items = {
            {itemID = 257400, name = "Tome of Silvermoon Intrigue"},
        },
    },
    [42187] = {
        name = "Lorewalking: Ethereal Wisdom",
        category = "lorewalking",
        expansion = "TWW",
        items = {
            {itemID = 257354, name = "Tale of Ethereal Wisdom"},
            {itemID = 258858, name = "K'aresh Historian"},
        },
    },
    [42188] = {
        name = "Lorewalking: Blade's Bane",
        category = "lorewalking",
        expansion = "TWW",
        items = {
            {itemID = 257355, name = "Tale of Blade's Bane"},
            {itemID = 258859, name = "Survivor's Tale"},
        },
    },
    [42189] = {
        name = "Lorewalking: The Lich King",
        category = "lorewalking",
        expansion = "TWW",
        items = {
            {itemID = 257351, name = "Tale of the Penultimate Lich King"},
            {itemID = 258860, name = "Lich King Lore"},
        },
    },

    ---------------------------------------------------------------------------
    -- Dragonflight (DF)
    -- Source: https://www.wowhead.com/news/finish-these-retro-achievements-now-to-get-free-housing-decor-in-midnight-378720
    ---------------------------------------------------------------------------

    -- Meta Achievement
    -- Source: https://housing.wowdb.com/decor/4180/the-great-hoard-4180/
    [19458] = {
        name = "A World Awoken",
        category = "meta",
        expansion = "DF",
        items = {
            {itemID = 248124, name = "The Great Hoard"},
        },
    },

    -- Zone Achievements
    [17773] = {
        name = "A Blue Dawn",
        category = "quests",
        expansion = "DF",
        items = {
            {itemID = 247900, name = "Pentagonal Stone Table"},
        },
    },
    [19507] = {
        name = "Fringe Benefits",
        category = "exploration",
        expansion = "DF",
        items = {
            {itemID = 248200, name = "Valdrakken Sconce"},
        },
    },
    [19719] = {
        name = "Reclamation of Gilneas",
        category = "quests",
        expansion = "DF",
        items = {
            {itemID = 240857, name = "Gilnean Celebration Keg"},
        },
    },
    [17529] = {
        name = "Forbidden Spoils",
        category = "exploration",
        expansion = "DF",
        items = {
            {itemID = 244482, name = "Dragon's Hoard Chest"},
        },
    },

    ---------------------------------------------------------------------------
    -- Shadowlands (SL)
    -- Source: https://www.wowhead.com/achievement=20501/back-from-the-beyond
    ---------------------------------------------------------------------------

    -- Meta Achievement
    [20501] = {
        name = "Back from the Beyond",
        category = "meta",
        expansion = "SL",
        items = {
            {itemID = 244181, name = "Portal to Damnation"},
        },
    },

    ---------------------------------------------------------------------------
    -- Battle for Azeroth (BFA)
    -- Source: https://www.wowhead.com/achievement=40953/a-farewell-to-arms
    ---------------------------------------------------------------------------

    -- Meta Achievement
    [40953] = {
        name = "A Farewell to Arms",
        category = "meta",
        expansion = "BFA",
        items = {
            {itemID = 247667, name = "MOTHER's Titanic Brazier"},
            {itemID = 247668, name = "N'Zoth's Captured Eye"},
        },
    },

    -- Zone/Quest Achievements
    [12582] = {
        name = "Come Sail Away",
        category = "quests",
        expansion = "BFA",
        items = {
            {itemID = 241100, name = "Old Salt's Fireplace"},
        },
    },
    [12997] = {
        name = "The Pride of Kul Tiras",
        category = "quests",
        expansion = "BFA",
        items = {
            {itemID = 241150, name = "Proudmoore Green Drape"},
        },
    },
    [13049] = {
        name = "The Long Con",
        category = "quests",
        expansion = "BFA",
        items = {
            {itemID = 241200, name = "Tiragarde Treasure Chest"},
        },
    },
    [12614] = {
        name = "Loa Expectations",
        category = "quests",
        expansion = "BFA",
        items = {
            {itemID = 241250, name = "Golden Loa's Altar"},
        },
    },
    [13039] = {
        name = "Paku'ai",
        category = "quests",
        expansion = "BFA",
        items = {
            {itemID = 241300, name = "Idol of Pa'ku, Master of Winds"},
        },
    },
    [13038] = {
        name = "Raptari Rider",
        category = "quests",
        expansion = "BFA",
        items = {
            {itemID = 241175, name = "Bookcase of Gonk"},
        },
    },
    [12509] = {
        name = "Ready for War",
        category = "quests",
        expansion = "BFA",
        items = {
            {itemID = 241350, name = "Lordaeron Rectangular Rug"},
        },
    },
    [12479] = {
        name = "Zandalar Forever!",
        category = "quests",
        expansion = "BFA",
        items = {
            {itemID = 241400, name = "Grand Mask of Bwonsamdi, Loa of Graves"},
        },
    },

    -- Professions
    [12733] = {
        name = "Professional Zandalari Master",
        category = "professions",
        expansion = "BFA",
        items = {
            {itemID = 241191, name = "Dazar'alor Forge"},
        },
    },
    [12746] = {
        name = "The Zandalari Menu",
        category = "professions",
        expansion = "BFA",
        items = {
            {itemID = 241450, name = "Zuldazar Cook's Griddle"},
        },
    },

    -- Warfronts/War Campaign
    [13284] = {
        name = "Frontline Warrior",
        category = "pvp",
        expansion = "BFA",
        items = {
            {itemID = 241500, name = "Large Forsaken War Tent"},
        },
    },
    [12869] = {
        name = "Azeroth at War: After Lordaeron",
        category = "quests",
        expansion = "BFA",
        items = {
            {itemID = 241550, name = "Lordaeron Banded Crate"},
        },
    },
    [12870] = {
        name = "Azeroth at War: Kalimdor on Fire",
        category = "quests",
        expansion = "BFA",
        items = {
            {itemID = 241600, name = "Lordaeron Spiked Weapon Rack"},
        },
    },
    [12867] = {
        name = "Azeroth at War: The Barrens",
        category = "quests",
        expansion = "BFA",
        items = {
            {itemID = 241650, name = "Lordaeron Banded Barrel"},
        },
    },

    -- Mechagon/Nazjatar
    [13723] = {
        name = "M.C., Hammered",
        category = "dungeons",
        expansion = "BFA",
        items = {
            {itemID = 241700, name = "Gnomish T.O.O.L.B.O.X."},
        },
    },
    [13473] = {
        name = "Diversified Investments",
        category = "exploration",
        expansion = "BFA",
        items = {
            {itemID = 241750, name = "Redundant Reclamation Rig"},
        },
    },
    [13018] = {
        name = "Dune Rider",
        category = "exploration",
        expansion = "BFA",
        items = {
            {itemID = 241800, name = "Zandalari Wall Shelf"},
        },
    },
    [13477] = {
        name = "Junkyard Apprentice",
        category = "exploration",
        expansion = "BFA",
        items = {
            {itemID = 241850, name = "Screw-Sealed Stembarrel"},
        },
    },
    [13475] = {
        name = "Junkyard Scavenger",
        category = "exploration",
        expansion = "BFA",
        items = {
            {itemID = 241900, name = "Gnomish Cog Stack"},
        },
    },

    -- Dungeons/Raids
    [4859] = {
        name = "Kings Under the Mountain",
        category = "dungeons",
        expansion = "Classic",  -- Blackrock Depths achievement
        items = {
            {itemID = 241216, name = "Dark Iron Brazier"},
        },
    },

    ---------------------------------------------------------------------------
    -- Legion - Class Hall Campaign Achievements
    -- Source: https://blizzardwatch.com/2025/12/05/recreate-legion-class-halls-player-housing-achievements/
    ---------------------------------------------------------------------------

    -- Death Knight
    [42270] = {
        name = "The Deathlord's Campaign",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245882, name = "Ebon Blade Weapon Rack"},
        },
    },
    [42287] = {
        name = "Hidden Potential of the Deathlord",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245888, name = "Replica Acherus Soul Forge"},
        },
    },
    [60962] = {
        name = "Legendary Research of the Ebon Blade",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245900, name = "Replica Libram of the Dead"},
        },
    },
    [60981] = {
        name = "Raise an Army for Acherus",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 250112, name = "Ebon Blade Planning Map"},
        },
    },

    -- Demon Hunter
    [42271] = {
        name = "The Slayer's Campaign",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245527, name = "Illidari Glaiverest"},
        },
    },
    [42288] = {
        name = "Hidden Potential of the Slayer",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245889, name = "Replica Cursed Forge of the Nathrezim"},
        },
    },
    [60963] = {
        name = "Legendary Research of the Illidari",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245901, name = "Replica Tome of Fel Secrets"},
        },
    },
    [60982] = {
        name = "Raise an Army for the Fel Hammer",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 249518, name = "Fel Hammer Scouting Map"},
        },
    },

    -- Druid
    [42272] = {
        name = "The Archdruid's Campaign",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 254358, name = "Brazier of Elune"},
        },
    },
    [42289] = {
        name = "Hidden Potential of the Archdruid",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245890, name = "Seed of Ages Cutting"},
        },
    },
    [60964] = {
        name = "Legendary Research of the Dreamgrove",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245878, name = "Replica Tome of the Ancients"},
        },
    },
    [60983] = {
        name = "Raise an Army for the Dreamgrove",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 251013, name = "Cenarion Arch"},
        },
    },

    -- Hunter
    [42273] = {
        name = "The Huntmaster's Campaign",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 244042, name = "Trueshot Skeletal Dragon Trophy"},
        },
    },
    [42290] = {
        name = "Hidden Potential of the Huntmaster",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245891, name = "Replica Altar of the Eternal Hunt"},
        },
    },
    [60965] = {
        name = "Legendary Research of the Unseen Path",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245903, name = "Replica Tome of the Unseen Path"},
        },
    },
    [60984] = {
        name = "Raise an Army for the Trueshot Lodge",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 250126, name = "Unseen Path Archer's Gallery"},
        },
    },

    -- Mage
    [42274] = {
        name = "The Archmage's Campaign",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 240750, name = "Tirisgarde Book Tempest"},
        },
    },
    [42291] = {
        name = "Hidden Potential of the Archmage",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 247609, name = "Conjured Altar of the Guardian"},
        },
    },
    [60966] = {
        name = "Legendary Research of the Tirisgarde",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 251275, name = "Conjured Archive of the Tirisgarde"},
        },
    },
    [60985] = {
        name = "Raise an Army for the Hall of the Guardian",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 250131, name = "Tirisgarde War Map"},
        },
    },

    -- Monk
    [42275] = {
        name = "The Grandmaster's Campaign",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245126, name = "Monastery Gong"},
        },
    },
    [42292] = {
        name = "Hidden Potential of the Grandmaster",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245893, name = "Replica Altar of the Tiger"},
        },
    },
    [60967] = {
        name = "Legendary Research of the Peak of Serenity",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245905, name = "Replica Tome of Pandaria"},
        },
    },
    [60986] = {
        name = "Raise an Army for the Temple of Five Dawns",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 248942, name = "Five Dawns Planning Table"},
        },
    },

    -- Paladin
    [42276] = {
        name = "The Highlord's Campaign",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 247575, name = "Sanctum of Light Candelabra"},
        },
    },
    [42293] = {
        name = "Hidden Potential of the Highlord",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245894, name = "Replica Altar of Ancient Kings"},
        },
    },
    [60968] = {
        name = "Legendary Research of the Silver Hand",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245906, name = "Replica Tome of the Silver Hand"},
        },
    },
    [60987] = {
        name = "Raise an Army for the Sanctum of Light",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 250236, name = "Silver Hand Weapon Rack"},
        },
    },

    -- Priest
    [42277] = {
        name = "The High Priest's Campaign",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 247824, name = "Scroll of the Conclave"},
        },
    },
    [42294] = {
        name = "Hidden Potential of the High Priest",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245895, name = "Replica Light's Wrath Altar"},
        },
    },
    [60969] = {
        name = "Legendary Research of the Conclave",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245907, name = "Replica Tome of the Light"},
        },
    },
    [60988] = {
        name = "Raise an Army for the Netherlight Temple",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 251636, name = "Netherlight Command Map"},
        },
    },

    -- Rogue
    [42279] = {
        name = "The Shadowblade's Campaign",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 254461, name = "Uncrowned Market Stall"},
        },
    },
    [42295] = {
        name = "Hidden Potential of the Shadowblade",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245896, name = "Replica Altar of the Fangs"},
        },
    },
    [60970] = {
        name = "Legendary Research of the Uncrowned",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245908, name = "Replica Tome of Shadows"},
        },
    },
    [60989] = {
        name = "Raise an Army for the Hall of Shadows",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 250786, name = "Uncrowned Planning Table"},
        },
    },

    -- Shaman
    [42280] = {
        name = "The Farseer's Campaign",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 251493, name = "Maelstrom Lava Lamp"},
        },
    },
    [42296] = {
        name = "Hidden Potential of the Farseer",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245897, name = "Replica Altar of the Elements"},
        },
    },
    [60971] = {
        name = "Legendary Research of the Earthen Ring",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245909, name = "Replica Tome of the Elements"},
        },
    },
    [60990] = {
        name = "Raise an Army for the Maelstrom",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 251014, name = "Earthen Ring Scouting Map"},
        },
    },

    -- Warlock
    [42282] = {
        name = "The Netherlord's Campaign",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245128, name = "Dreadscar Dais"},
        },
    },
    [42297] = {
        name = "Hidden Potential of the Netherlord",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245898, name = "Replica Altar of Damnation"},
        },
    },
    [60972] = {
        name = "Legendary Research of the Black Harvest",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245910, name = "Replica Tome of Fel Mastery"},
        },
    },
    [60991] = {
        name = "Raise an Army for the Dreadscar Rift",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 264242, name = "Dreadscar Battle Planning Map"},
        },
    },

    -- Warrior
    [42281] = {
        name = "The Battlelord's Campaign",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245534, name = "Valarjar Shield Wall"},
        },
    },
    [42298] = {
        name = "Hidden Potential of the Battlelord",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245899, name = "Replica Altar of the Valorous"},
        },
    },
    [60973] = {
        name = "Legendary Research of the Valarjar",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 245911, name = "Replica Tome of the Valarjar"},
        },
    },
    [60992] = {
        name = "Raise an Army for Skyhold",
        category = "class_hall",
        expansion = "Legion",
        items = {
            {itemID = 249461, name = "Skyhold War Table"},
        },
    },

    ---------------------------------------------------------------------------
    -- Legion - Zone/Quest Achievements
    ---------------------------------------------------------------------------

    [11124] = {
        name = "Good Suramaritan",
        category = "quests",
        expansion = "Legion",
        items = {
            {itemID = 240752, name = "\"Night on the Jeweled Estate\" Painting"},
        },
    },
    [11340] = {
        name = "Insurrection",
        category = "quests",
        expansion = "Legion",
        items = {
            {itemID = 243982, name = "Deluxe Suramar Sleeper"},
        },
    },
    [11341] = {
        name = "Nightborne Armory",
        category = "quests",
        expansion = "Legion",
        items = {
            {itemID = 257721, name = "Nightborne Armory Display"},
        },
    },
    [10698] = {
        name = "That's Val'sharah Folks!",
        category = "quests",
        expansion = "Legion",
        items = {
            {itemID = 241881, name = "Shala'nir Feather Bed"},
        },
    },
    [11257] = {
        name = "Treasures of Highmountain",
        category = "exploration",
        expansion = "Legion",
        items = {
            {itemID = 241307, name = "Skyhorn Storage Chest"},
        },
    },
    [11258] = {
        name = "Treasures of Val'sharah",
        category = "exploration",
        expansion = "Legion",
        items = {
            {itemID = 241887, name = "Kaldorei Treasure Trove"},
        },
    },
    [10398] = {
        name = "Drum Circle",
        category = "exploration",
        expansion = "Legion",
        items = {
            {itemID = 251751, name = "Skyhorn Arrow Kite"},
        },
    },
    [10996] = {
        name = "Got to Ketchum All",
        category = "exploration",
        expansion = "Legion",
        items = {
            {itemID = 251315, name = "Tauren Jeweler's Roller"},
        },
    },
    [11699] = {
        name = "Grand Fin-ale",
        category = "dungeons",
        expansion = "Legion",
        items = {
            {itemID = 251909, name = "Murloc's Wind Chimes"},
        },
    },

    -- World Quests
    [42674] = {
        name = "Broken Isles World Quests V",
        category = "exploration",
        expansion = "Legion",
        items = {
            {itemID = 247690, name = "Altar of the Corrupted Flames"},
        },
    },
    [42655] = {
        name = "The Armies of Legionfall",
        category = "quests",
        expansion = "Legion",
        items = {
            {itemID = 249165, name = "Demonic Storage Chest"},
        },
    },
    [42321] = {
        name = "Legion Remix Raids",
        category = "dungeons",
        expansion = "Legion",
        items = {
            {itemID = 247624, name = "Corruption Pit"},
        },
    },

    ---------------------------------------------------------------------------
    -- PvP Achievements (All Expansions)
    ---------------------------------------------------------------------------

    [1157] = {
        name = "Duel-icious",
        category = "pvp",
        expansion = "Classic",
        items = {
            {itemID = 243893, name = "Challenger's Dueling Flag"},
        },
    },
    [229] = {
        name = "The Grim Reaper",
        category = "pvp",
        expansion = "Classic",
        items = {
            {itemID = 243895, name = "Horde Dueling Flag"},
        },
    },
    [231] = {
        name = "Wrecking Ball",
        category = "pvp",
        expansion = "Classic",
        items = {
            {itemID = 243884, name = "Alliance Dueling Flag"},
        },
    },
    [221] = {
        name = "Alterac Grave Robber",
        category = "pvp",
        expansion = "Classic",
        items = {
            {itemID = 243896, name = "Fortified Alliance Banner"},
        },
    },
    [222] = {
        name = "Tower Defense",
        category = "pvp",
        expansion = "Classic",
        items = {
            {itemID = 243897, name = "Fortified Horde Banner"},
        },
    },
    [158] = {
        name = "Me and the Cappin' Makin' It Happen",
        category = "pvp",
        expansion = "Classic",
        items = {
            {itemID = 243894, name = "Alliance Battlefield Banner"},
        },
    },
    [1153] = {
        name = "Overly Defensive",
        category = "pvp",
        expansion = "Classic",
        items = {
            {itemID = 243898, name = "Horde Battlefield Banner"},
        },
    },
    [212] = {
        name = "Storm Capper",
        category = "pvp",
        expansion = "Classic",
        items = {
            {itemID = 243899, name = "Uncontested Battlefield Banner"},
        },
    },
    [213] = {
        name = "Stormtrooper",
        category = "pvp",
        expansion = "Classic",
        items = {
            {itemID = 243900, name = "Netherstorm Battlefield Flag"},
        },
    },
    [200] = {
        name = "Persistent Defender",
        category = "pvp",
        expansion = "Classic",
        items = {
            {itemID = 243901, name = "Silverwing Sentinels Flag"},
        },
    },
    [167] = {
        name = "Warsong Gulch Veteran",
        category = "pvp",
        expansion = "Classic",
        items = {
            {itemID = 243902, name = "Warsong Outriders Flag"},
        },
    },
    [5245] = {
        name = "Battle for Gilneas Victory",
        category = "pvp",
        expansion = "Cata",
        items = {
            {itemID = 251296, name = "Smoke Lamppost"},
        },
    },
    [5223] = {
        name = "Master of Twin Peaks",
        category = "pvp",
        expansion = "Cata",
        items = {
            {itemID = 251297, name = "Iron Dragonmaw Gate"},
        },
    },
    [6981] = {
        name = "Master of Temple of Kotmogu",
        category = "pvp",
        expansion = "MoP",
        items = {
            {itemID = 251298, name = "Kotmogu Orb of Power"},
            {itemID = 251299, name = "Kotmogu Pedestal"},
        },
    },

    ---------------------------------------------------------------------------
    -- Classic / Vanilla
    ---------------------------------------------------------------------------

    [940] = {
        name = "The Green Hills of Stranglethorn",
        category = "quests",
        expansion = "Classic",
        items = {
            {itemID = 244841, name = "Nesingwary Mounted Elk Head"},
        },
    },
    [5442] = {
        name = "Full Caravan",
        category = "quests",
        expansion = "Classic",
        items = {
            {itemID = 244813, name = "Goldshire Food Cart"},
        },
    },
    [4405] = {
        name = "More Dots! (25 player)",
        category = "dungeons",
        expansion = "Classic",
        items = {
            {itemID = 241674, name = "Head of the Broodmother"},
            {itemID = 244852, name = "Head of the Broodmother"},
        },
    },

    ---------------------------------------------------------------------------
    -- Wrath of the Lich King (WotLK)
    ---------------------------------------------------------------------------

    [938] = {
        name = "The Snows of Northrend",
        category = "quests",
        expansion = "WotLK",
        items = {
            {itemID = 244842, name = "Nesingwary Shoveltusk Trophy"},
        },
    },

    ---------------------------------------------------------------------------
    -- Mists of Pandaria (MoP)
    ---------------------------------------------------------------------------

    [7322] = {
        name = "Roll Club",
        category = "exploration",
        expansion = "MoP",
        items = {
            {itemID = 251300, name = "Kun-Lai Lacquered Rickshaw"},
        },
    },
    [8316] = {
        name = "Blood in the Snow",
        category = "dungeons",
        expansion = "MoP",
        items = {
            {itemID = 251301, name = "Shadowforge Stone Chair"},
        },
    },

    ---------------------------------------------------------------------------
    -- Zul'Aman (Legion Remix / Timewalking)
    ---------------------------------------------------------------------------

    [62289] = {
        name = "Zul'Aman: The Highest Peaks",
        category = "dungeons",
        expansion = "Legion",
        items = {
            {itemID = 251325, name = "Amani Spearhunter's Spit"},
        },
    },
    [62122] = {
        name = "Tallest Tree in the Forest",
        category = "dungeons",
        expansion = "Legion",
        items = {
            {itemID = 255573, name = "Colossal Amani Stone Visage"},
        },
    },
}

-- Copy achievement data to main table for backward compatibility
for achievementID, data in pairs(achievementData) do
    AchievementDecor[achievementID] = data
end

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

-- Get all items from a specific expansion
function AchievementDecor:GetItemsByExpansion(expansion)
    local items = {}
    for achievementID, data in pairs(achievementData) do
        if data.expansion == expansion then
            for _, item in ipairs(data.items or {}) do
                table.insert(items, {
                    itemID = item.itemID,
                    name = item.name,
                    achievementID = achievementID,
                    achievementName = data.name,
                })
            end
        end
    end
    return items
end

-- Get all items from a specific category
function AchievementDecor:GetItemsByCategory(category)
    local items = {}
    for achievementID, data in pairs(achievementData) do
        if data.category == category then
            for _, item in ipairs(data.items or {}) do
                table.insert(items, {
                    itemID = item.itemID,
                    name = item.name,
                    achievementID = achievementID,
                    achievementName = data.name,
                })
            end
        end
    end
    return items
end

-- Check if player has completed an achievement
function AchievementDecor:IsAchievementCompleted(achievementID)
    local _, _, _, completed = GetAchievementInfo(achievementID)
    return completed
end

-- Get achievement info for an item
function AchievementDecor:GetAchievementForItem(itemID)
    for achievementID, data in pairs(achievementData) do
        if data.items then
            for _, item in ipairs(data.items) do
                if item.itemID == itemID then
                    return {
                        achievementID = achievementID,
                        name = data.name,
                        category = data.category,
                        expansion = data.expansion,
                        completed = self:IsAchievementCompleted(achievementID),
                    }
                end
            end
        end
    end
    return nil
end

-- Get all item IDs (for CatalogScanner integration)
function AchievementDecor:GetAllItemIDs()
    local itemIDs = {}
    for achievementID, data in pairs(achievementData) do
        if data.items then
            for _, item in ipairs(data.items) do
                if item.itemID then
                    table.insert(itemIDs, item.itemID)
                end
            end
        end
    end
    return itemIDs
end

-- Get achievement data by ID
function AchievementDecor:GetAchievementData(achievementID)
    return achievementData[achievementID]
end

-- Get stats
function AchievementDecor:GetStats()
    local total = 0
    local completed = 0
    local byExpansion = {}
    local byCategory = {}
    local totalItems = 0

    for achievementID, data in pairs(achievementData) do
        total = total + 1

        if self:IsAchievementCompleted(achievementID) then
            completed = completed + 1
        end

        local exp = data.expansion or "Unknown"
        byExpansion[exp] = (byExpansion[exp] or 0) + 1

        local cat = data.category or "unknown"
        byCategory[cat] = (byCategory[cat] or 0) + 1

        -- Count items
        if data.items then
            totalItems = totalItems + #data.items
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

-- Get uncompleted achievements
function AchievementDecor:GetUncompletedAchievements()
    local uncompleted = {}
    for achievementID, data in pairs(achievementData) do
        if not self:IsAchievementCompleted(achievementID) then
            table.insert(uncompleted, {
                achievementID = achievementID,
                name = data.name,
                category = data.category,
                expansion = data.expansion,
                items = data.items,
            })
        end
    end
    -- Sort by expansion (newest first)
    local expansionOrder = {TWW = 1, DF = 2, SL = 3, BFA = 4, Legion = 5, WoD = 6, MoP = 7, Cata = 8, WotLK = 9, Classic = 10}
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

-- /hs achievements - Show achievement decor stats
function AchievementDecor:DebugPrint()
    local stats = self:GetStats()

    HA.Addon:Print("=== Achievement Decor Stats ===")
    HA.Addon:Print(string.format("Total achievements tracked: %d", stats.total))
    HA.Addon:Print(string.format("Total decor items: %d", stats.totalItems))
    HA.Addon:Print(string.format("Completed: %d / %d (%.1f%%)",
        stats.completed, stats.total,
        stats.total > 0 and (stats.completed / stats.total * 100) or 0))

    if stats.total > 0 then
        HA.Addon:Print("By expansion:")
        local expansionOrder = {"TWW", "DF", "SL", "BFA", "Legion", "WoD", "MoP", "Cata", "WotLK", "Classic"}
        for _, exp in ipairs(expansionOrder) do
            local count = stats.byExpansion[exp]
            if count then
                HA.Addon:Print(string.format("  %s: %d", exp, count))
            end
        end

        HA.Addon:Print("By category:")
        for cat, count in pairs(stats.byCategory) do
            HA.Addon:Print(string.format("  %s: %d", cat, count))
        end
    else
        HA.Addon:Print("No achievement data loaded.")
    end
end
