--[[
    Homestead - VendorDatabase
    Database of housing decor vendors with locations and items

    This file contains the actual vendor data for housing decor vendors.
    Data is loaded by VendorData.lua on initialization.

    Data sources:
    - Wowhead Housing Guides (https://www.wowhead.com/guide/player-housing/)
    - In-game research

    Map IDs Reference:
    - Dornogal: 2339
    - Isle of Dorn: 2248
    - The Ringing Deeps: 2214
    - Hallowfall: 2215
    - Undermine: 2346
    - Tazavesh (K'aresh): 2472
    - Stormwind City: 84
    - Orgrimmar: 85
    - Ironforge: 87
    - Darnassus: 89
    - Boralus: 1161
    - Dazar'alor: 1165
    - Valdrakken: 2112
    - Amirdrassil/Bel'ameth: 2239
]]

local addonName, HA = ...

-- Create VendorDatabase module
local VendorDatabase = {}
HA.VendorDatabase = VendorDatabase

-------------------------------------------------------------------------------
-- The War Within Vendors (Patch 11.0+)
-------------------------------------------------------------------------------

VendorDatabase.TWW = {
    -- Dornogal
    {
        npcID = 223728,
        name = "Auditor Balwurz",
        mapID = 2339,
        coords = { x = 0.392, y = 0.242 },
        zone = "Dornogal - Foundation Hall",
        faction = "Neutral",
        currency = "Resonance Crystals",
        items = {
            { itemID = 245295, name = "Literature of Dornogal" },
            { itemID = 245296, name = "Literature of Taelloch" },
            { itemID = 245297, name = "Literature of Gundargaz" },
            { itemID = 245561, name = "Ornate Ochre Window" },
            { itemID = 253168, name = "Earthen Storage Crate" },
        },
    },
    {
        npcID = 252910,
        name = "Garnett",
        mapID = 2339,
        coords = { x = 0.544, y = 0.572 },
        zone = "Dornogal - The Forgegrounds",
        faction = "Neutral",
        currency = "Resonance Crystals",
        items = {
            { itemID = 252756, name = "Stonelight Countertop" },
            { itemID = 252757, name = "Boulder Springs Recliner" },
            { itemID = 253023, name = "Rambleshire Resting Platform" },
            { itemID = 253034, name = "Fallside Lantern" },
            { itemID = 253037, name = "Dornogal Brazier" },
            { itemID = 253038, name = "Dornogal Hanging Lantern" },
            { itemID = 253163, name = "Fallside Storage Tent" },
        },
    },
    {
        npcID = 219318,  -- Corrected from 227392
        name = "Jorid",
        mapID = 2339,
        coords = { x = 0.572, y = 0.606 },
        zone = "Dornogal - General Goods",
        faction = "Neutral",
        currency = "Gold",
        items = {
            { itemID = 230099, name = "Earthen Writing Quill" },
        },
    },
    {
        npcID = 252312,  -- Corrected from 223952
        name = "Second Chair Pawdo",
        mapID = 2339,
        coords = { x = 0.530, y = 0.681 },
        zone = "Dornogal",
        faction = "Neutral",
        currency = "Gold",
        items = {
            -- 10 items scanned
        },
    },
    {
        npcID = 219217,  -- Corrected from 229414
        name = "Velerd",
        mapID = 2339,
        coords = { x = 0.561, y = 0.755 },
        zone = "Dornogal - Honor Quartermaster",
        faction = "Neutral",
        currency = "Honor",
        items = {
            -- 2 items scanned
        },
    },
    {
        npcID = 252887,
        name = "Chert",
        mapID = 2339,
        coords = { x = 0.50, y = 0.50 },  -- Needs coordinates
        zone = "Dornogal",
        faction = "Neutral",
        currency = "Gold",
        items = {
            -- 4 items scanned
        },
    },
    {
        npcID = 217642,
        name = "Nalina Ironsong",
        mapID = 2339,
        coords = { x = 0.50, y = 0.50 },  -- Needs coordinates
        zone = "Dornogal",
        faction = "Neutral",
        currency = "Gold",
        items = {
            -- 1 item scanned
        },
    },

    -- Isle of Dorn
    {
        npcID = 226205,
        name = "Cendvin",
        mapID = 2248,
        coords = { x = 0.744, y = 0.452 },
        zone = "Isle of Dorn - Cinderbrew Meadery",
        faction = "Neutral",
        currency = "Gold",
        items = {
            -- 1 item scanned
        },
    },

    -- The Ringing Deeps
    {
        npcID = 221390,
        name = "Waxmonger Squick",
        mapID = 2214,
        coords = { x = 0.432, y = 0.328 },
        zone = "The Ringing Deeps - Gundargaz",
        faction = "Neutral",
        currency = "Resonance Crystals",
        items = {
            { itemID = 253162, name = "Earthen Chain Wall Shelf" },
        },
    },

    -- Hallowfall
    {
        npcID = 240852,
        name = "Lars Bronsmaelt",
        mapID = 2215,
        coords = { x = 0.282, y = 0.562 },
        zone = "Hallowfall - Flame's Radiance Camp",
        faction = "Neutral",
        currency = "Resonance Crystals",
        items = {
            { itemID = 245293, name = "Collection of Arathi Scripture" },
        },
    },

    -- Azj-Kahet
    {
        npcID = 218202,  -- Corrected from 252167
        name = "Thripps",
        mapID = 2255,
        coords = { x = 0.487, y = 0.317 },
        zone = "Azj-Kahet - Web Furnishings",
        faction = "Neutral",
        currency = "Resonance Crystals",
        items = {},
    },
    {
        npcID = 239333,
        name = "Street Food Vendor",
        mapID = 2255,
        coords = { x = 0.50, y = 0.50 },  -- Needs coordinates
        zone = "Azj-Kahet",
        faction = "Neutral",
        currency = "Gold",
        items = {
            -- 1 item scanned
        },
    },
    {
        npcID = 256783,
        name = "Gabbun",
        mapID = 2255,
        coords = { x = 0.50, y = 0.50 },  -- Needs coordinates
        zone = "Azj-Kahet",
        faction = "Neutral",
        currency = "Gold",
        items = {
            -- 4 items scanned
        },
    },
}

-------------------------------------------------------------------------------
-- Undermine Vendors (Patch 11.1.5)
-------------------------------------------------------------------------------

VendorDatabase.Undermine = {
    {
        npcID = 231405,
        name = "Boatswain Hardee",
        mapID = 2346,
        coords = { x = 0.632, y = 0.168 },
        zone = "Undermine - Blackwater Marina",
        faction = "Neutral",
        currency = "Resonance Crystals",
        items = {
            { itemID = 248758, name = "Relaxing Goblin Beach Chair with Cup Gripper" },
            { itemID = 255642, name = "Undermine Alleyway Sconce" },
        },
    },
    {
        npcID = 231406,
        name = "Rocco Razzboom",
        mapID = 2346,
        coords = { x = 0.390, y = 0.220 },
        zone = "Undermine - Hovel Hill",
        faction = "Neutral",
        currency = "Resonance Crystals",
        items = {
            { itemID = 245313, name = "Spring-Powered Undermine Chair" },
            { itemID = 255674, name = "Incontinental Table Lamp" },
        },
    },
    {
        npcID = 231396,
        name = "Sitch Lowdown",
        mapID = 2346,
        coords = { x = 0.306, y = 0.388 },
        zone = "Undermine - Hovel Hill",
        faction = "Neutral",
        currency = "Resonance Crystals",
        items = {
            { itemID = 245307, name = "Undermine Bookcase" },
            { itemID = 256327, name = "Open Rust-Plated Storage Crate" },
        },
    },
    {
        npcID = 231409,
        name = "Smaks Topskimmer",
        mapID = 2346,
        coords = { x = 0.436, y = 0.508 },
        zone = "Undermine - Incontinental Hotel",
        faction = "Neutral",
        currency = "Resonance Crystals",
        items = {
            { itemID = 243312, name = "Undermine Rectangular Table" },
            { itemID = 245314, name = "Undermine Round Table" },
            { itemID = 245318, name = "Undermine Fence" },
            { itemID = 245319, name = "Undermine Fencepost" },
        },
    },
    {
        npcID = 251911,
        name = "Stacks Topskimmer",
        mapID = 2346,
        coords = { x = 0.50, y = 0.50 },  -- Needs coordinates
        zone = "Undermine - Incontinental Hotel",
        faction = "Neutral",
        currency = "Resonance Crystals",
        items = {
            -- 12 items scanned
        },
    },
    {
        npcID = 231407,
        name = "Shredz the Scrapper",
        mapID = 2346,
        coords = { x = 0.532, y = 0.726 },
        zone = "Undermine - The Heaps",
        faction = "Neutral",
        currency = "Resonance Crystals",
        items = {
            { itemID = 245311, name = "Undermine Wall Shelf" },
            { itemID = 255647, name = "Spring-Powered Pointer" },
        },
    },
    {
        npcID = 226994,
        name = "Blair Bass",
        mapID = 2346,
        coords = { x = 0.342, y = 0.716 },
        zone = "Undermine - The Vatworks",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 231408,
        name = "Lab Assistant Laszly",
        mapID = 2346,
        coords = { x = 0.272, y = 0.724 },
        zone = "Undermine - The Vatworks",
        faction = "Neutral",
        currency = "Resonance Crystals",
        items = {
            { itemID = 245321, name = "Rust-Plated Storage Barrel" },
            { itemID = 255641, name = "Undermine Mechanic's Hanging Lamp" },
        },
    },
    -- Dungeon vendor
    {
        npcID = 235621,
        name = "Ando the Gat",
        mapID = 2346,
        coords = { x = 0.50, y = 0.50 },
        zone = "Liberation of Undermine - Incontinental Hotel",
        faction = "Neutral",
        currency = "Gold",
        notes = "Inside dungeon",
        items = {},
    },
}

-------------------------------------------------------------------------------
-- K'aresh (Tazavesh) Vendors
-------------------------------------------------------------------------------

VendorDatabase.Karesh = {
    {
        npcID = 235252,
        name = "Om'sirik",
        mapID = 2472,
        coords = { x = 0.406, y = 0.292 },
        zone = "Tazavesh",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 235314,
        name = "Ta'sam",
        mapID = 2472,
        coords = { x = 0.432, y = 0.352 },
        zone = "Tazavesh",
        faction = "Neutral",
        currency = "Resonance Crystals",
        items = {},
    },
}

-------------------------------------------------------------------------------
-- Dragonflight Vendors
-------------------------------------------------------------------------------

VendorDatabase.Dragonflight = {
    -- Amirdrassil / Bel'ameth
    {
        npcID = 216285,
        name = "Ellandrieth",
        mapID = 2239,
        coords = { x = 0.484, y = 0.536 },
        zone = "Bel'ameth - The Silver Feather Inn",
        faction = "Alliance",
        currency = "Dragon Isles Supplies",
        items = {},
    },
    {
        npcID = 216284,
        name = "Mythrin'dir",
        mapID = 2239,
        coords = { x = 0.541, y = 0.608 },
        zone = "Bel'ameth - East",
        faction = "Alliance",
        currency = "Dragon Isles Supplies",
        items = {},
    },
    {
        npcID = 216286,
        name = "Moon Priestess Lasara",
        mapID = 2239,
        coords = { x = 0.465, y = 0.707 },
        zone = "Bel'ameth - Terrace of the Moon",
        faction = "Alliance",
        currency = "Dragon Isles Supplies",
        notes = "Quartermaster",
        items = {},
    },

    -- Thaldraszus
    {
        npcID = 209192,
        name = "Provisioner Aristta",
        mapID = 2025,
        coords = { x = 0.614, y = 0.314 },
        zone = "Thaldraszus - Algeth'ar Academy",
        faction = "Neutral",
        currency = "Mysterious Fragment",
        items = {},
    },

    -- Waking Shores
    {
        npcID = 188265,
        name = "Rae'ana",
        mapID = 2022,
        coords = { x = 0.478, y = 0.820 },
        zone = "The Waking Shores - Dragonscale Basecamp",
        faction = "Neutral",
        currency = "Dragon Isles Supplies",
        items = {},
    },

    -- Valdrakken
    {
        npcID = 196637,
        name = "Tethalash",
        mapID = 2112,
        coords = { x = 0.256, y = 0.336 },
        zone = "Valdrakken - Behind Obsidian Enclave",
        faction = "Neutral",
        currency = "Gold",
        notes = "Dracthyr only",
        items = {},
    },
    {
        npcID = 193015,
        name = "Unatos",
        mapID = 2112,
        coords = { x = 0.580, y = 0.354 },
        zone = "Valdrakken - Seat of the Aspects",
        faction = "Neutral",
        currency = "Dragon Isles Supplies",
        items = {},
    },
    {
        npcID = 198444,
        name = "Evantkis",
        mapID = 2112,
        coords = { x = 0.582, y = 0.578 },
        zone = "Valdrakken - Treasury Hoard Bank",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },

    -- Emerald Dream
    {
        npcID = 252901,  -- Corrected from 208471
        name = "Cinnabar",
        mapID = 2200,
        coords = { x = 0.421, y = 0.731 },
        zone = "Emerald Dream - Freywold Village",
        faction = "Neutral",
        currency = "Gold",
        items = {
            -- 3 items scanned
        },
    },
}

-------------------------------------------------------------------------------
-- Shadowlands Vendors
-------------------------------------------------------------------------------

VendorDatabase.Shadowlands = {
    -- Venthyr - Sinfall (placeholder - instance map, coords vary)
    {
        npcID = 174710,
        name = "Chachi the Artiste",
        mapID = 1699, -- Sinfall
        coords = { x = 0.326, y = 0.436 },
        zone = "Sinfall",
        faction = "Neutral",
        currency = "Reservoir Anima",
        covenant = "Venthyr",
        items = {},
    },
    -- The Maw
    {
        npcID = 162804,
        name = "Ve'nari",
        mapID = 1543, -- The Maw
        coords = { x = 0.469, y = 0.418 },
        zone = "The Maw - Ve'nari's Refuge",
        faction = "Neutral",
        currency = "Stygia",
        items = {},
    },
    -- Kyrian - Bastion
    {
        npcID = 160470,
        name = "Adjutant Nikos",
        mapID = 1533, -- Bastion
        coords = { x = 0.522, y = 0.462 },
        zone = "Bastion - Elysian Hold",
        faction = "Neutral",
        currency = "Reservoir Anima",
        covenant = "Kyrian",
        items = {},
    },
    -- Necrolord - Maldraxxus
    {
        npcID = 171821,
        name = "Nalcorn Talsen",
        mapID = 1536, -- Maldraxxus
        coords = { x = 0.504, y = 0.536 },
        zone = "Maldraxxus - Seat of the Primus",
        faction = "Neutral",
        currency = "Reservoir Anima",
        covenant = "Necrolord",
        items = {},
    },
    -- Night Fae - Ardenweald
    {
        npcID = 163714,
        name = "Elwyn",
        mapID = 1565, -- Ardenweald
        coords = { x = 0.486, y = 0.544 },
        zone = "Ardenweald - Heart of the Forest",
        faction = "Neutral",
        currency = "Reservoir Anima",
        covenant = "Night Fae",
        items = {},
    },
    -- Oribos
    {
        npcID = 164095,
        name = "Host Ta'rela",
        mapID = 1670, -- Oribos
        coords = { x = 0.392, y = 0.688 },
        zone = "Oribos - Ring of Fates",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },
}

-------------------------------------------------------------------------------
-- Battle for Azeroth Vendors
-------------------------------------------------------------------------------

VendorDatabase.BFA = {
    -- Boralus (Alliance)
    {
        npcID = 135808,
        name = "Provisioner Fray",
        mapID = 1161,
        coords = { x = 0.676, y = 0.216 },
        zone = "Boralus - Harbormaster's Office",
        faction = "Alliance",
        currency = "War Resources",
        items = {},
    },
    {
        npcID = 246721,
        name = "Janey Forrest",
        mapID = 1161,
        coords = { x = 0.560, y = 0.460 },
        zone = "Boralus - Hull'n'Home",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 138223,
        name = "Pearl Barlow",
        mapID = 1161,
        coords = { x = 0.708, y = 0.157 },
        zone = "Boralus - Port",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 253421,
        name = "Fiona",
        mapID = 1161,
        coords = { x = 0.679, y = 0.413 },
        zone = "Boralus - Tradewinds Market",
        faction = "Alliance",
        currency = "Gold",
        notes = "Requires Eastern Plaguelands caravan questline completion",
        items = {},
    },

    -- Stormsong Valley
    {
        npcID = 252313,
        name = "Caspian",
        mapID = 942,
        coords = { x = 0.594, y = 0.696 },
        zone = "Stormsong Valley - Brennadam",
        faction = "Alliance",
        currency = "War Resources",
        items = {},
    },

    -- Tiragarde Sound
    {
        npcID = 252316,
        name = "Delphine",
        mapID = 895,
        coords = { x = 0.534, y = 0.313 },
        zone = "Tiragarde Sound - Norwington Estate",
        faction = "Alliance",
        currency = "Gold",
        notes = "Chandelier Maker",
        items = {},
    },

    -- Mechagon
    {
        npcID = 150716,
        name = "Stolen Royal Vendorbot",
        mapID = 1462,
        coords = { x = 0.736, y = 0.366 },
        zone = "Mechagon - Rustbolt",
        faction = "Neutral",
        currency = "Gold",
        notes = "Also accepts Energy Cells, S.P.A.R.E. Crates, Chain Ignitercoils, Spare Parts, Galvanic Oscillators",
        items = {},
    },

    -- Dazar'alor (Horde)
    {
        npcID = 251921,
        name = "Arcanist Peroleth",
        mapID = 862,
        coords = { x = 0.580, y = 0.626 },
        zone = "Dazar'alor - The Docks",
        faction = "Horde",
        currency = "War Resources",
        items = {},
    },
    {
        npcID = 148923,
        name = "Captain Zen'taga",
        mapID = 1165,
        coords = { x = 0.444, y = 0.872 },
        zone = "Dazar'alor - Grand Bazaar",
        faction = "Horde",
        currency = "Seafarer's Doubloons",
        items = {},
    },
    {
        npcID = 148924,
        name = "Provisioner Mukra",
        mapID = 1165,
        coords = { x = 0.512, y = 0.952 },
        zone = "Dazar'alor - Grand Bazaar",
        faction = "Horde",
        currency = "Honorbound Service Medals",
        items = {},
    },
    {
        npcID = 252326,
        name = "T'lama",
        mapID = 1165,
        coords = { x = 0.386, y = 0.168 },
        zone = "Dazar'alor - Hall of Chroniclers",
        faction = "Horde",
        currency = "War Resources",
        items = {},
    },

    -- Nazmir
    {
        npcID = 135459,
        name = "Provisioner Lija",
        mapID = 863,
        coords = { x = 0.392, y = 0.542 },
        zone = "Nazmir - Zul'jan Ruins",
        faction = "Horde",
        currency = "War Resources",
        items = {},
    },
    {
        npcID = 136189,
        name = "Mako",
        mapID = 863,
        coords = { x = 0.668, y = 0.416 },
        zone = "Nazmir - Gloom Hollow",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },

    -- Vol'dun
    {
        npcID = 135793,
        name = "Jenoh",
        mapID = 864,
        coords = { x = 0.566, y = 0.496 },
        zone = "Vol'dun - Vulpera Hideaway",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },

    -- 7th Legion / Honorbound
    {
        npcID = 135446,
        name = "Quartermaster Alcorn",
        mapID = 1161,
        coords = { x = 0.696, y = 0.264 },
        zone = "Boralus - 7th Legion Hub",
        faction = "Alliance",
        currency = "7th Legion Service Medals",
        items = {},
    },

    -- Drustvar
    {
        npcID = 139635,
        name = "Quartermaster Prichard",
        mapID = 896,
        coords = { x = 0.374, y = 0.506 },
        zone = "Drustvar - Fallhaven",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },

    -- Zuldazar (Horde Zone)
    {
        npcID = 128258,
        name = "Trader Sanjeh",
        mapID = 862,
        coords = { x = 0.434, y = 0.378 },
        zone = "Zuldazar - Tal'gurub",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 131845,
        name = "Trader Haw'li",
        mapID = 862,
        coords = { x = 0.672, y = 0.266 },
        zone = "Zuldazar - Dazar'alor",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },
}

-------------------------------------------------------------------------------
-- Warlords of Draenor Vendors
-------------------------------------------------------------------------------

VendorDatabase.WoD = {
    -- Horde Garrison (Frostfire Ridge)
    {
        npcID = 79812,
        name = "Moz'def",
        mapID = 525, -- Frostfire Ridge (not garrison instance)
        coords = { x = 0.364, y = 0.401 },
        zone = "Frostwall (Horde Garrison)",
        faction = "Horde",
        currency = "Garrison Resources",
        items = {},
    },
    {
        npcID = 76872,
        name = "Supplymaster Eri",
        mapID = 525, -- Frostfire Ridge
        coords = { x = 0.365, y = 0.401 },
        zone = "Frostwall (Horde Garrison)",
        faction = "Horde",
        currency = "Garrison Resources",
        items = {},
    },
    {
        npcID = 78564,
        name = "Sergeant Grimjaw",
        mapID = 525,
        coords = { x = 0.365, y = 0.401 },
        zone = "Frostwall (Horde Garrison)",
        faction = "Horde",
        currency = "Garrison Resources",
        items = {},
    },

    -- Alliance Garrison (Shadowmoon Valley)
    {
        npcID = 85427,
        name = "Maaria",
        mapID = 539, -- Shadowmoon Valley (Draenor)
        coords = { x = 0.296, y = 0.162 },
        zone = "Lunarfall (Alliance Garrison)",
        faction = "Alliance",
        currency = "Apexis Crystal",
        items = {},
    },
    {
        npcID = 88220,
        name = "Peter",
        mapID = 539,
        coords = { x = 0.296, y = 0.162 },
        zone = "Lunarfall (Alliance Garrison)",
        faction = "Alliance",
        currency = "Garrison Resources",
        items = {},
    },
    {
        npcID = 78564,
        name = "Sergeant Crowler",
        mapID = 539,
        coords = { x = 0.296, y = 0.162 },
        zone = "Lunarfall (Alliance Garrison)",
        faction = "Alliance",
        currency = "Garrison Resources",
        items = {},
    },

    -- Ashran - Stormshield (Alliance)
    {
        npcID = 85950,
        name = "Trader Caerel",
        mapID = 622, -- Stormshield
        coords = { x = 0.411, y = 0.596 },
        zone = "Stormshield",
        faction = "Alliance",
        currency = "Apexis Crystal",
        items = {},
    },
    {
        npcID = 85932,
        name = "Vindicator Nuurem",
        mapID = 622,
        coords = { x = 0.463, y = 0.766 },
        zone = "Stormshield",
        faction = "Alliance",
        currency = "Garrison Resources",
        items = {},
    },
    {
        npcID = 86698,
        name = "Shadow-Sage Brakoss",
        mapID = 622,
        coords = { x = 0.444, y = 0.752 },
        zone = "Stormshield - Town Hall",
        faction = "Alliance",
        currency = "Apexis Crystal",
        notes = "Arakkoa Outcasts Quartermaster",
        items = {},
    },

    -- Ashran - Warspear (Horde)
    {
        npcID = 86037,
        name = "Ravenspeaker Skeega",
        mapID = 624, -- Warspear
        coords = { x = 0.533, y = 0.601 },
        zone = "Warspear",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },

    -- Shadowmoon Valley
    {
        npcID = 81133,
        name = "Artificer Kallaes",
        mapID = 539, -- Shadowmoon Valley (Draenor)
        coords = { x = 0.466, y = 0.382 },
        zone = "Shadowmoon Valley - Embaari Village",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },

    -- Talador
    {
        npcID = 256946,
        name = "Duskcaller Erthix",
        mapID = 535,
        coords = { x = 0.50, y = 0.50 },
        zone = "Talador - Refuge",
        faction = "Neutral",
        currency = "Gold",
        notes = "Repairs vendor, sells Scroll of the Adherent",
        items = {},
    },

    -- Frostwall Garrison (Horde)
    {
        npcID = 79774,
        name = "Sergeant Grimjaw",
        mapID = 525,
        coords = { x = 0.50, y = 0.50 },
        zone = "Frostwall - Garrison",
        faction = "Horde",
        currency = "Garrison Resources",
        notes = "Garrison Quartermaster",
        items = {},
    },
    {
        npcID = 87312,
        name = "Vora Strongarm",
        mapID = 525,
        coords = { x = 0.50, y = 0.50 },
        zone = "Frostwall - Tavern",
        faction = "Horde",
        currency = "Garrison Resources",
        notes = "Bartender, sells Wooden Mug",
        items = {},
    },
    {
        npcID = 86776,
        name = "Ribchewer",
        mapID = 525,
        coords = { x = 0.50, y = 0.50 },
        zone = "Frostwall - Trading Post",
        faction = "Horde",
        currency = "Garrison Resources",
        notes = "Trading Post trader, requires Trading Post building",
        items = {},
    },
    {
        npcID = 87015,
        name = "Kil'rip",
        mapID = 525,
        coords = { x = 0.50, y = 0.50 },
        zone = "Frostwall - Garrison",
        faction = "Horde",
        currency = "Apexis Crystals",
        notes = "Laughing Skull Quartermaster",
        items = {},
    },

    -- Lunarfall Garrison (Alliance) - Trading Post traders
    {
        npcID = 86778,
        name = "Pyxni Pennypocket",
        mapID = 582,
        coords = { x = 0.50, y = 0.50 },
        zone = "Lunarfall - Trading Post",
        faction = "Alliance",
        currency = "Garrison Resources",
        notes = "Trading Post trader, requires Trading Post building",
        items = {},
    },

    -- Spires of Arak
    {
        npcID = 87775,
        name = "Ruuan the Seer",
        mapID = 542,
        coords = { x = 0.50, y = 0.50 },
        zone = "Spires of Arak",
        faction = "Neutral",
        currency = "Gold",
        notes = "Reagents and Repairs, quest-locked items",
        items = {},
    },

    -- Stormshield (Alliance Hub)
    {
        npcID = 85946,
        name = "Shadow-Sage Brakoss",
        mapID = 622,
        coords = { x = 0.50, y = 0.50 },
        zone = "Stormshield",
        faction = "Alliance",
        currency = "Gold",
        notes = "Arakkoa Outcasts Quartermaster",
        items = {},
    },
}

-------------------------------------------------------------------------------
-- Mists of Pandaria Vendors
-------------------------------------------------------------------------------

VendorDatabase.MoP = {
    -- Jade Forest
    {
        npcID = 58414,
        name = "San Redscale",
        mapID = 371,
        coords = { x = 0.566, y = 0.444 },
        zone = "The Jade Forest - The Arboretum",
        faction = "Neutral",
        currency = "Gold",
        notes = "Some items require Order of the Cloud Serpent reputation",
        items = {},
    },
    {
        npcID = 55143,
        name = "Supplier Xin",
        mapID = 371,
        coords = { x = 0.472, y = 0.454 },
        zone = "The Jade Forest - Dawn's Blossom",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },

    -- Valley of the Four Winds
    {
        npcID = 58706,
        name = "Gina Mudclaw",
        mapID = 376,
        coords = { x = 0.532, y = 0.516 },
        zone = "Valley of the Four Winds - Halfhill",
        faction = "Neutral",
        currency = "Gold",
        notes = "Requires Good Friend status with Gina Mudclaw",
        items = {
            { itemID = 245508, name = "Pandaren Cooking Table" },
            { itemID = 247670, name = "Pandaren Pantry" },
            { itemID = 247734, name = "Paw'don Well" },
            { itemID = 247737, name = "Stormstout Brew Keg" },
            { itemID = 248663, name = "Wooden Doghouse" },
        },
    },
    {
        npcID = 64001,
        name = "Farmer Yoon",
        mapID = 376,
        coords = { x = 0.522, y = 0.488 },
        zone = "Valley of the Four Winds - Sunsong Ranch",
        faction = "Neutral",
        currency = "Gold",
        notes = "Unlocked through Tillers storyline",
        items = {},
    },

    -- Kun-Lai Summit
    {
        npcID = 59698,
        name = "Brother Furtrim",
        mapID = 379,
        coords = { x = 0.572, y = 0.610 },
        zone = "Kun-Lai Summit - One Keg",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },

    -- Townlong Steppes
    {
        npcID = 64599,
        name = "Supplier Towson",
        mapID = 388,
        coords = { x = 0.485, y = 0.698 },
        zone = "Townlong Steppes - Longying Outpost",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },

    -- Vale of Eternal Blossoms
    {
        npcID = 64605,
        name = "Tan Shin Tiao",
        mapID = 390,
        coords = { x = 0.822, y = 0.294 },
        zone = "Vale of Eternal Blossoms - Mogushan Palace",
        faction = "Neutral",
        currency = "Gold",
        notes = "Items require Lorewalkers reputation",
        items = {},
    },

    -- Krasarang Wilds
    {
        npcID = 62127,
        name = "Sentinel Commander Qipan",
        mapID = 418,
        coords = { x = 0.124, y = 0.564 },
        zone = "Krasarang Wilds - Lion's Landing",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 62126,
        name = "General Nazgrim",
        mapID = 418,
        coords = { x = 0.082, y = 0.528 },
        zone = "Krasarang Wilds - Domination Point",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },

    -- Additional MoP Vendors (from DecorVendor)
    {
        npcID = 64032,
        name = "Jogu the Drunk",
        mapID = 376,
        coords = { x = 0.532, y = 0.516 },
        zone = "Valley of the Four Winds - Halfhill",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },
}

-------------------------------------------------------------------------------
-- Wrath of the Lich King Vendors
-------------------------------------------------------------------------------

VendorDatabase.WotLK = {
    {
        npcID = 25206,
        name = "Ahlurglgr",
        mapID = 114, -- Borean Tundra
        coords = { x = 0.432, y = 0.556 },
        zone = "Borean Tundra - Winterfin Retreat",
        faction = "Neutral",
        currency = "Gold",
        notes = "Sells Murloc Driftwood Hut",
        items = {},
    },
    {
        npcID = 28038,
        name = "Purser Boulian",
        mapID = 119, -- Sholazar Basin
        coords = { x = 0.268, y = 0.586 },
        zone = "Sholazar Basin - Nesingwary Base Camp",
        faction = "Neutral",
        currency = "Gold",
        notes = "Sells Nesingwary Mounted Shoveltusk Head",
        items = {},
    },
    {
        npcID = 27391,
        name = "Woodsman Drake",
        mapID = 116, -- Grizzly Hills
        coords = { x = 0.326, y = 0.596 },
        zone = "Grizzly Hills - Amberpine Lodge",
        faction = "Alliance",
        currency = "Gold",
        notes = "Sells Wooden Outhouse (425g)",
        items = {},
    },
    {
        npcID = 31557,
        name = "Braeg Stoutbeard",
        mapID = 125, -- Dalaran (Northrend)
        coords = { x = 0.344, y = 0.454 },
        zone = "Dalaran - The Filthy Animal",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 31916,
        name = "Arille Azuregaze",
        mapID = 125, -- Dalaran (Northrend)
        coords = { x = 0.490, y = 0.360 },
        zone = "Dalaran - The Legerdemain Lounge",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },
    -- Howling Fjord
    {
        npcID = 24028,
        name = "Black Kingsnake",
        mapID = 117,
        coords = { x = 0.603, y = 0.626 },
        zone = "Howling Fjord - Valgarde",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },
    -- Zul'Drak
    {
        npcID = 32540,
        name = "Tainted Sentry",
        mapID = 121,
        coords = { x = 0.416, y = 0.416 },
        zone = "Zul'Drak - Zim'Torga",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },
    -- Dragonblight
    {
        npcID = 26079,
        name = "Vendor Moonfeather",
        mapID = 115,
        coords = { x = 0.286, y = 0.558 },
        zone = "Dragonblight - Wintergarde Keep",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 26097,
        name = "Vendor Berryfizz",
        mapID = 115,
        coords = { x = 0.364, y = 0.466 },
        zone = "Dragonblight - Agmar's Hammer",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 28699,
        name = "Cielstrasza",
        mapID = 115, -- Dragonblight (where Wyrmrest Temple is)
        coords = { x = 0.598, y = 0.532 },
        zone = "Dragonblight - Wyrmrest Temple",
        faction = "Neutral",
        currency = "Gold",
        notes = "Requires Wyrmrest Accord reputation",
        items = {},
    },
    {
        npcID = 32763,
        name = "Lillehoff",
        mapID = 120, -- The Storm Peaks
        coords = { x = 0.666, y = 0.614 },
        zone = "The Storm Peaks - K3",
        faction = "Neutral",
        currency = "Gold",
        notes = "Requires Sons of Hodir reputation",
        items = {},
    },
}

-------------------------------------------------------------------------------
-- Cataclysm Vendors
-------------------------------------------------------------------------------

VendorDatabase.Cataclysm = {
    {
        npcID = 253227,
        name = "Breana Bitterbrand",
        mapID = 241, -- Twilight Highlands
        coords = { x = 0.497, y = 0.296 },
        zone = "Twilight Highlands",
        faction = "Alliance",
        currency = "Gold",
        notes = "Decor Specialist, requires Wildhammer Clan reputation",
        items = {},
    },
}

-------------------------------------------------------------------------------
-- Classic / Vanilla & Cataclysm Vendors
-------------------------------------------------------------------------------

VendorDatabase.Classic = {
    -- Alliance Capital Cities
    {
        npcID = 50309,
        name = "Captain Stonehelm",
        mapID = 87,
        coords = { x = 0.558, y = 0.478 },
        zone = "Ironforge - The Great Forge",
        faction = "Alliance",
        currency = "Gold",
        items = {
            { itemID = 246426, name = "Ornate Ironforge Table" },
            { itemID = 246490, name = "Ironforge Fencepost" },
            { itemID = 246491, name = "Ironforge Fence" },
            { itemID = 252010, name = "Ornate Ironforge Bench" },
            { itemID = 256333, name = "Ornate Dwarven Wardrobe" },
        },
    },
    {
        npcID = 253232,
        name = "Inge Brightview",
        mapID = 87,
        coords = { x = 0.754, y = 0.096 },
        zone = "Ironforge - Hall of Explorers",
        faction = "Alliance",
        currency = "Gold",
        items = {
            { itemID = 246411, name = "Ironforge Bookcase" },
            { itemID = 246412, name = "Small Ironforge Bookcase" },
        },
    },
    {
        npcID = 5124,
        name = "Tilli Thistlefuzz",
        mapID = 87,
        coords = { x = 0.608, y = 0.448 },
        zone = "Ironforge - Tinker Town",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 256071,
        name = "Solelo",
        mapID = 84,
        coords = { x = 0.496, y = 0.802 },
        zone = "Stormwind - The Mage Quarter",
        faction = "Alliance",
        currency = "Gold",
        items = {
            { itemID = 239177, name = "Open Tome of Twilight Nihilism" },
            { itemID = 239179, name = "Tome of Twilight Nihilism" },
            { itemID = 246845, name = "Tome of Shadowforge Cunning" },
            { itemID = 246847, name = "Tome of Draenei Faith" },
            { itemID = 246848, name = "Scribe's Working Notes" },
            { itemID = 246860, name = "Tome of Forsaken Resilience" },
        },
        notes = "Rotating stock - check daily",
    },
    {
        npcID = 49877,
        name = "Captain Lancy Revshon",
        mapID = 84,
        coords = { x = 0.676, y = 0.728 },
        zone = "Stormwind - Trade District",
        faction = "Alliance",
        currency = "Gold",
        items = {
            { itemID = 248333, name = "Stormwind Large Wooden Table" },
            { itemID = 248336, name = "Stormwind Wooden Table" },
            { itemID = 248617, name = "Stormwind Keg Stand" },
            { itemID = 248618, name = "Westfall Woven Basket" },
            { itemID = 248619, name = "Stormwind Gazebo" },
            { itemID = 248620, name = "Stormwind Trellis and Basin" },
            { itemID = 248621, name = "Stormwind Arched Trellis" },
            { itemID = 248662, name = "Jewelcrafter's Tent" },
            { itemID = 248665, name = "Stormwind Peddler's Cart" },
            { itemID = 248794, name = "Elwynn Fence" },
            { itemID = 248795, name = "Elwynn Fencepost" },
            { itemID = 248797, name = "City Wanderer's Candleholder" },
            { itemID = 248798, name = "Northshire Barrel" },
            { itemID = 248801, name = "Stormwind Weapon Rack" },
            { itemID = 248938, name = "Hooded Iron Lantern" },
            { itemID = 248939, name = "Stormwind Lamppost" },
            { itemID = 253168, name = "Earthen Storage Crate" },
            { itemID = 256673, name = "Stormwind Forge" },
        },
    },
    {
        npcID = 50307,
        name = "Lord Candren",
        mapID = 84,
        coords = { x = 0.562, y = 0.134 },
        zone = "Stormwind Embassy",
        faction = "Alliance",
        currency = "Gold",
        notes = "Also found in Darnassus Temple Gardens at 37.0, 47.4",
        items = {
            { itemID = 245518, name = "Worgen's Chicken Coop" },
            { itemID = 245603, name = "Gilnean Noble's Trellis" },
            { itemID = 245605, name = "Gilnean Stone Wall" },
            { itemID = 245620, name = "Little Wolf's Loo" },
        },
    },
    {
        npcID = 1286,
        name = "Edna Mullby",
        mapID = 84,
        coords = { x = 0.672, y = 0.662 },
        zone = "Stormwind - Trade District",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 1257,
        name = "Lisbeth Schneider",
        mapID = 84,
        coords = { x = 0.524, y = 0.754 },
        zone = "Stormwind - Mage Quarter",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 254603,
        name = "Riica",
        mapID = 84,
        coords = { x = 0.778, y = 0.656 },
        zone = "Stormwind - Old Town (Champion's Hall)",
        faction = "Alliance",
        currency = "Honor",
        items = {
            { itemID = 247740, name = "Kotmogu Pedestal" },
            { itemID = 247741, name = "Kotmogu Orb of Power" },
            { itemID = 247744, name = "Alliance Dueling Flag" },
            { itemID = 247746, name = "Silverwing Sentinels Flag" },
            { itemID = 247750, name = "Deephaul Crystal" },
            { itemID = 247756, name = "Challenger's Dueling Flag" },
            { itemID = 247757, name = "Alliance Battlefield Banner" },
            { itemID = 247758, name = "Fortified Alliance Banner" },
            { itemID = 247761, name = "Uncontested Battlefield Banner" },
            { itemID = 247762, name = "Netherstorm Battlefield Flag" },
            { itemID = 247763, name = "Berserker's Empowerment" },
            { itemID = 247765, name = "Healer's Empowerment" },
            { itemID = 247766, name = "Runner's Empowerment" },
            { itemID = 247768, name = "Guardian's Empowerment" },
            { itemID = 247769, name = "Chaotic Empowerment" },
            { itemID = 247770, name = "Mysterious Empowerment" },
            { itemID = 253170, name = "Earthen Contender's Target" },
            { itemID = 256896, name = "Smoke Lamppost" },
        },
        notes = "PvP Decor Specialist - items require achievement completion",
    },
    {
        npcID = 261231,
        name = "Tuuran",
        mapID = 84,
        coords = { x = 0.726, y = 0.556 },
        zone = "Stormwind - Near Trading Post",
        faction = "Alliance",
        currency = "Gold",
        items = {
            { itemID = 260785, name = "Miniature Replica Dark Portal" },
        },
        notes = "Promotional Decor Resupply - Twitch drop items",
    },

    -- Alliance Zones
    {
        npcID = 1247,
        name = "Innkeeper Belm",
        mapID = 27,
        coords = { x = 0.544, y = 0.508 },
        zone = "Dun Morogh - Kharanos",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 211065,
        name = "Marie Allen",
        mapID = 217,
        coords = { x = 0.604, y = 0.924 },
        zone = "Gilneas - Stormglen Village",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 49386,
        name = "Craw MacGraw",
        mapID = 241,
        coords = { x = 0.486, y = 0.306 },
        zone = "Twilight Highlands - Thundermar",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 3178,
        name = "Stuart Fleming",
        mapID = 56,
        coords = { x = 0.064, y = 0.576 },
        zone = "Wetlands - Menethil Harbor",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 6574,
        name = "Jaquilina Dramet",
        mapID = 224,
        coords = { x = 0.268, y = 0.736 },
        zone = "Stranglethorn Vale - Booty Bay",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 46359,
        name = "Maurice Essman",
        mapID = 17,
        coords = { x = 0.444, y = 0.122 },
        zone = "Blasted Lands - Surwich",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 9636,
        name = "Kiara Holterman",
        mapID = 32,
        coords = { x = 0.652, y = 0.224 },
        zone = "Searing Gorge - Thorium Point",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 14624,
        name = "Master Smith Burninate",
        mapID = 32,
        coords = { x = 0.387, y = 0.287 },
        zone = "Searing Gorge - Iron Summit",
        faction = "Neutral",
        currency = "Gold",
        notes = "Requires Thorium Brotherhood reputation",
        items = {},
    },
    -- Burning Steppes
    {
        npcID = 142192,
        name = "Hoddruc Bladebender",
        mapID = 36,
        coords = { x = 0.467, y = 0.448 },
        zone = "Burning Steppes - Morgan's Vigil",
        faction = "Neutral",
        currency = "Gold",
        notes = "Requires quest completion for some items",
        items = {},
    },
    {
        npcID = 5128,
        name = "Bombus Finespindle",
        mapID = 48,
        coords = { x = 0.344, y = 0.462 },
        zone = "Loch Modan - Thelsamar",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 4891,
        name = "Harlown Darkweave",
        mapID = 57,
        coords = { x = 0.256, y = 0.426 },
        zone = "Duskwood - Darkshire",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 253419,
        name = "Wilkinson",
        mapID = 57,
        coords = { x = 0.202, y = 0.584 },
        zone = "Duskwood - Raven Hill",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 7947,
        name = "Thanthaldis Snowgleam",
        mapID = 25,
        coords = { x = 0.510, y = 0.540 },
        zone = "Hillsbrad Foothills",
        faction = "Alliance",
        currency = "Gold",
        items = {},
    },

    -- Horde Capital Cities
    {
        npcID = 256119,
        name = "Lonalo",
        mapID = 85,
        coords = { x = 0.586, y = 0.506 },
        zone = "Orgrimmar - The Drag",
        faction = "Horde",
        currency = "Gold",
        items = {
            { itemID = 239177, name = "Open Tome of Twilight Nihilism" },
            { itemID = 239179, name = "Tome of Twilight Nihilism" },
            { itemID = 246845, name = "Tome of Shadowforge Cunning" },
            { itemID = 246847, name = "Tome of Draenei Faith" },
            { itemID = 246848, name = "Scribe's Working Notes" },
            { itemID = 246860, name = "Tome of Forsaken Resilience" },
        },
        notes = "Rotating stock - check daily",
    },
    {
        npcID = 3364,
        name = "Borya",
        mapID = 85,
        coords = { x = 0.606, y = 0.516 },
        zone = "Orgrimmar - The Drag",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 3366,
        name = "Taur Stonehoof",
        mapID = 85,
        coords = { x = 0.600, y = 0.520 },
        zone = "Orgrimmar - The Drag",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 50305,
        name = "Stone Guard Nargol",
        mapID = 85,
        coords = { x = 0.476, y = 0.712 },
        zone = "Orgrimmar - Valley of Strength",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 261262,
        name = "Gabbi",
        mapID = 85,
        coords = { x = 0.483, y = 0.811 },
        zone = "Orgrimmar - Near Trading Post",
        faction = "Horde",
        currency = "Gold",
        items = {
            { itemID = 260785, name = "Miniature Replica Dark Portal" },
        },
        notes = "Promotional Decor Resupply - Twitch drop items",
    },
    {
        npcID = 254606,
        name = "Joruh",
        mapID = 85,
        coords = { x = 0.388, y = 0.719 },
        zone = "Orgrimmar - Hall of Legends",
        faction = "Horde",
        currency = "Honor",
        items = {
            { itemID = 247727, name = "Iron Dragonmaw Gate" },
            { itemID = 247740, name = "Kotmogu Pedestal" },
            { itemID = 247741, name = "Kotmogu Orb of Power" },
            { itemID = 247745, name = "Horde Dueling Flag" },
            { itemID = 247747, name = "Warsong Outriders Flag" },
            { itemID = 247750, name = "Deephaul Crystal" },
            { itemID = 247756, name = "Challenger's Dueling Flag" },
            { itemID = 247759, name = "Horde Battlefield Banner" },
            { itemID = 247760, name = "Fortified Horde Banner" },
            { itemID = 247761, name = "Uncontested Battlefield Banner" },
            { itemID = 247762, name = "Netherstorm Battlefield Flag" },
            { itemID = 247763, name = "Berserker's Empowerment" },
            { itemID = 247765, name = "Healer's Empowerment" },
            { itemID = 247766, name = "Runner's Empowerment" },
            { itemID = 247768, name = "Guardian's Empowerment" },
            { itemID = 247769, name = "Chaotic Empowerment" },
            { itemID = 247770, name = "Mysterious Empowerment" },
            { itemID = 253170, name = "Earthen Contender's Target" },
            { itemID = 256896, name = "Smoke Lamppost" },
        },
        notes = "PvP Decor Specialist - items require achievement completion",
    },
    {
        npcID = 8403,
        name = "Shadi Mistrunner",
        mapID = 88,
        coords = { x = 0.452, y = 0.454 },
        zone = "Thunder Bluff - High Rise",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 8401,
        name = "Mahu",
        mapID = 88,
        coords = { x = 0.456, y = 0.458 },
        zone = "Thunder Bluff - High Rise",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 50483,
        name = "Brave Tuho",
        mapID = 88,
        coords = { x = 0.469, y = 0.502 },
        zone = "Thunder Bluff - Wind Rider Roost",
        faction = "Horde",
        currency = "Gold",
        items = {
            { itemID = 243335, name = "Tauren Bluff Rug" },
        },
        notes = "Requires 'Walk With The Earth Mother' achievement",
    },
    {
        npcID = 4558,
        name = "Martine Tramblay",
        mapID = 90,
        coords = { x = 0.632, y = 0.478 },
        zone = "Undercity - Trade Quarter",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },

    -- Horde Zones
    {
        npcID = 16528,
        name = "Provisioner Vredigar",
        mapID = 95,
        coords = { x = 0.476, y = 0.322 },
        zone = "Ghostlands - Tranquillien",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },

    -- Eversong Woods - Saltheril's Haven (Blood Elf racial vendors)
    {
        npcID = 253283,
        name = "Apprentice Diell",
        mapID = 94, -- Eversong Woods
        coords = { x = 0.435, y = 0.475 },
        zone = "Eversong Woods - Saltheril's Haven",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 253284,
        name = "Armorer Goldcrest",
        mapID = 94,
        coords = { x = 0.435, y = 0.475 },
        zone = "Eversong Woods - Saltheril's Haven",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 253285,
        name = "Caeris Fairdawn",
        mapID = 94,
        coords = { x = 0.435, y = 0.475 },
        zone = "Eversong Woods - Saltheril's Haven",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 253286,
        name = "Neriv",
        mapID = 94,
        coords = { x = 0.435, y = 0.477 },
        zone = "Eversong Woods - Saltheril's Haven",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 253287,
        name = "Ranger Allorn",
        mapID = 94,
        coords = { x = 0.434, y = 0.476 },
        zone = "Eversong Woods - Saltheril's Haven",
        faction = "Horde",
        currency = "Gold",
        items = {},
    },

    -- Silvermoon City - Bazaar (Painting vendors)
    {
        npcID = 256201,
        name = "Corlen Hordralin",
        mapID = 110,
        coords = { x = 0.441, y = 0.628 },
        zone = "Silvermoon City - The Bazaar",
        faction = "Horde",
        currency = "Gold",
        notes = "Master Painter - Paintings of Eversong, lore figures",
        items = {},
    },
    {
        npcID = 256202,
        name = "Hesta Forlath",
        mapID = 110,
        coords = { x = 0.441, y = 0.628 },
        zone = "Silvermoon City - The Bazaar",
        faction = "Horde",
        currency = "Gold",
        notes = "Painter Apprentice - Some items require Deed of Patronage",
        items = {},
    },
    -- Neutral Zones
    {
        npcID = 2838,
        name = "Wizbang Cranktoggle",
        mapID = 23,
        coords = { x = 0.492, y = 0.304 },
        zone = "Eastern Plaguelands - Light's Hope Chapel",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 15419,
        name = "Krek Cragcrush",
        mapID = 32,
        coords = { x = 0.386, y = 0.266 },
        zone = "Searing Gorge - Iron Summit",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 45417,
        name = "Fiona",
        mapID = 23,
        coords = { x = 0.090, y = 0.665 },
        zone = "Eastern Plaguelands - Caravan",
        faction = "Neutral",
        currency = "Gold",
        notes = "Roams Eastern Plaguelands road; requires Full Caravan achievement",
        items = {},
    },
    -- Dustwallow Marsh
    {
        npcID = 23995,
        name = "Axle",
        mapID = 70, -- Dustwallow Marsh
        coords = { x = 0.419, y = 0.742 },
        zone = "Dustwallow Marsh - Mudsprocket",
        faction = "Neutral",
        currency = "Gold",
        notes = "Innkeeper",
        items = {},
    },

    -- Dungeon Vendors
    {
        npcID = 144129,
        name = "Plugger Spazzring",
        mapID = 242, -- Blackrock Depths
        coords = { x = 0.50, y = 0.50 },
        zone = "Blackrock Depths - The Grim Guzzler",
        faction = "Neutral",
        currency = "Gold",
        notes = "Inside dungeon",
        items = {},
    },

    -- Additional Classic Vendors (from DecorVendor)
    -- Loch Modan
    {
        npcID = 1465,
        name = "Drac Roughcut",
        mapID = 48, -- Loch Modan
        coords = { x = 0.354, y = 0.462 },
        zone = "Loch Modan - Thelsamar",
        faction = "Alliance",
        currency = "Gold",
        notes = "Tradesman, requires Axis of Awful quest",
        items = {},
    },
    -- Northern Stranglethorn
    {
        npcID = 2483,
        name = "Jaquilina Dramet",
        mapID = 50, -- Northern Stranglethorn
        coords = { x = 0.435, y = 0.230 },
        zone = "Northern Stranglethorn - Nesingwary's Expedition",
        faction = "Neutral",
        currency = "Gold",
        notes = "Superior Axecrafter, requires Green Hills of Stranglethorn achievement",
        items = {},
    },
    -- Undercity Quartermaster
    {
        npcID = 50304,
        name = "Captain Donald Adams",
        mapID = 90, -- Undercity
        coords = { x = 0.626, y = 0.492 },
        zone = "Tirisfal Glades - Ruins of Lordaeron",
        faction = "Horde",
        currency = "Gold",
        notes = "Undercity Quartermaster, requires Lordaeron quest",
        items = {},
    },
    -- Silverpine Forest (Edwin Harly is already listed above, 2140 is different location)
    {
        npcID = 2140,
        name = "Edwin Harly",
        mapID = 21, -- Silverpine Forest
        coords = { x = 0.455, y = 0.423 },
        zone = "Silverpine Forest - Pyrewood Village",
        faction = "Horde",
        currency = "Gold",
        notes = "General Supplies, requires Pyrewood's Fall quest",
        items = {},
    },
    -- Orgrimmar Quartermaster
    {
        npcID = 50488,
        name = "Stone Guard Nargol",
        mapID = 85, -- Orgrimmar
        coords = { x = 0.484, y = 0.710 },
        zone = "Orgrimmar",
        faction = "Horde",
        currency = "Gold",
        notes = "Orgrimmar Quartermaster",
        items = {},
    },
    -- Duskwood
    {
        npcID = 44114,
        name = "Wilkinson",
        mapID = 47, -- Duskwood
        coords = { x = 0.176, y = 0.560 },
        zone = "Duskwood - Darkshire",
        faction = "Alliance",
        currency = "Gold",
        notes = "General Goods, requires Cry for the Moon quest",
        items = {},
    },
}

-------------------------------------------------------------------------------
-- Legion Class Order Hall Vendors
-------------------------------------------------------------------------------

VendorDatabase.OrderHalls = {
    -- NOTE: Class Order Hall maps are instanced, so these won't show on world map
    -- They are included for vendor search functionality, not map pins

    -- Death Knight - Acherus (uses Eastern Plaguelands map for display)
    {
        npcID = 93550,
        name = "Quartermaster Ozorg",
        mapID = 23, -- Eastern Plaguelands (for continent display)
        coords = { x = 0.838, y = 0.498 }, -- Acherus location on EPL map
        zone = "Acherus: The Ebon Hold",
        faction = "Neutral",
        currency = "Order Resources",
        class = "DEATHKNIGHT",
        items = {
            { itemID = 250112, name = "Ebon Blade Planning Map" },
            { itemID = 250113, name = "Ebon Blade Tome" },
            { itemID = 250114, name = "Acherus Worktable" },
            { itemID = 250115, name = "Ebon Blade Weapon Rack" },
            { itemID = 250123, name = "Replica Acherus Soul Forge" },
            { itemID = 250124, name = "Ebon Blade Banner" },
            { itemID = 260584, name = "Replica Libram of the Dead" },
        },
    },
    -- Demon Hunter - The Fel Hammer (instance)
    {
        npcID = 112407,
        name = "Falara Nightsong",
        mapID = 720,
        coords = { x = 0.582, y = 0.512 },
        zone = "The Fel Hammer",
        faction = "Neutral",
        currency = "Order Resources",
        class = "DEMONHUNTER",
        notes = "Class Order Hall (instanced)",
        items = {},
    },
    -- Druid - The Dreamgrove (Val'sharah)
    {
        npcID = 112323,
        name = "Amurra Thistledew",
        mapID = 641, -- Val'sharah
        coords = { x = 0.446, y = 0.326 },
        zone = "The Dreamgrove",
        faction = "Neutral",
        currency = "Order Resources",
        class = "DRUID",
        notes = "Proprietor",
        items = {},
    },
    -- Hunter - Trueshot Lodge (Highmountain)
    {
        npcID = 103693,
        name = "Outfitter Reynolds",
        mapID = 650, -- Highmountain
        coords = { x = 0.356, y = 0.356 },
        zone = "Trueshot Lodge",
        faction = "Neutral",
        currency = "Order Resources",
        class = "HUNTER",
        items = {},
    },
    -- Mage - Hall of the Guardian (instance in Dalaran)
    {
        npcID = 112440,
        name = "Jackson Watkins",
        mapID = 627, -- Dalaran (Legion)
        coords = { x = 0.286, y = 0.492 },
        zone = "Hall of the Guardian",
        faction = "Neutral",
        currency = "Order Resources",
        class = "MAGE",
        notes = "Tirisgarde Quartermaster (instanced)",
        items = {},
    },
    -- Monk - The Wandering Isle (instance)
    {
        npcID = 112338,
        name = "Caydori Brightstar",
        mapID = 709,
        coords = { x = 0.508, y = 0.428 },
        zone = "The Wandering Isle",
        faction = "Neutral",
        currency = "Order Resources",
        class = "MONK",
        notes = "Purveyor of Rare Goods (instanced)",
        items = {},
    },
    -- Paladin - Sanctum of Light (Eastern Plaguelands, under Light's Hope)
    {
        npcID = 100196,
        name = "Eadric the Pure",
        mapID = 23, -- Eastern Plaguelands
        coords = { x = 0.757, y = 0.522 },
        zone = "Sanctum of Light",
        faction = "Neutral",
        currency = "Order Resources",
        class = "PALADIN",
        notes = "Silver Hand Quartermaster",
        items = {},
    },
    -- Priest - Netherlight Temple (instance)
    {
        npcID = 112401,
        name = "Meridelle Lightspark",
        mapID = 702,
        coords = { x = 0.512, y = 0.482 },
        zone = "Netherlight Temple",
        faction = "Neutral",
        currency = "Order Resources",
        class = "PRIEST",
        notes = "Conclave Logistics (instanced)",
        items = {},
    },
    -- Rogue - The Hall of Shadows (Dalaran Sewers)
    {
        npcID = 105986,
        name = "Kelsey Steelspark",
        mapID = 627, -- Dalaran
        coords = { x = 0.546, y = 0.606 },
        zone = "The Hall of Shadows",
        faction = "Neutral",
        currency = "Order Resources",
        class = "ROGUE",
        notes = "Uncrowned Quartermaster, Dalaran Underbelly",
        items = {},
    },
    -- Shaman - The Maelstrom (instance)
    {
        npcID = 112318,
        name = "Flamesmith Lanying",
        mapID = 726,
        coords = { x = 0.296, y = 0.526 },
        zone = "The Maelstrom",
        faction = "Neutral",
        currency = "Order Resources",
        class = "SHAMAN",
        notes = "Earthen Ring Quartermaster (instanced)",
        items = {},
    },
    -- Warlock - Dreadscar Rift (instance)
    {
        npcID = 112434,
        name = "Gigi Gigavoid",
        mapID = 717,
        coords = { x = 0.586, y = 0.382 },
        zone = "Dreadscar Rift",
        faction = "Neutral",
        currency = "Order Resources",
        class = "WARLOCK",
        notes = "Black Harvest Quartermaster (instanced)",
        items = {},
    },
    -- Warrior - Skyhold (instance)
    {
        npcID = 112392,
        name = "Quartermaster Durnolf",
        mapID = 695,
        coords = { x = 0.588, y = 0.126 },
        zone = "Skyhold",
        faction = "Neutral",
        currency = "Order Resources",
        class = "WARRIOR",
        notes = "Valarjar Quartermaster (instanced)",
        items = {},
    },

    -- Other Legion Vendors
    {
        npcID = 112716,  -- Corrected from 119486
        name = "Rasil Fireborne",
        mapID = 627, -- Dalaran (Legion)
        coords = { x = 0.426, y = 0.512 },
        zone = "Dalaran - Photonic Playground",
        faction = "Neutral",
        currency = "Gold",
        notes = "Art Dealer, requires Vereesa's Tale quest",
        items = {},
    },
    {
        npcID = 105333,  -- Corrected from 97017
        name = "Val'zuun",
        mapID = 627,
        coords = { x = 0.595, y = 0.476 },
        zone = "Dalaran - The Underbelly",
        faction = "Neutral",
        currency = "Veiled Argunite",
        notes = "Also accepts Order Resources after Legion Remix",
        items = {},
    },
    {
        npcID = 111587,
        name = "Halenthos Brightstride",
        mapID = 627,
        coords = { x = 0.612, y = 0.264 },
        zone = "Dalaran - The Filthy Animal",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },
    {
        npcID = 106902,
        name = "Ransa Greyfeather",
        mapID = 650, -- Highmountain
        coords = { x = 0.380, y = 0.461 },
        zone = "Highmountain - Thunder Totem",
        faction = "Neutral",
        currency = "Order Resources",
        notes = "Requires Highmountain Tribe reputation",
        items = {
            { itemID = 243290, name = "Tauren Waterwheel" },
            { itemID = 243359, name = "Tauren Windmill" },
            { itemID = 245270, name = "Thunder Totem Kiln" },
            { itemID = 245450, name = "Highmountain Totem" },
            { itemID = 245452, name = "Stonebull Canoe" },
            { itemID = 245454, name = "Small Highmountain Drum" },
            { itemID = 245458, name = "Riverbend Jar" },
            { itemID = 248985, name = "Tauren Hanging Brazier" },
        },
    },
    {
        npcID = 108017,
        name = "Torv Dubstomp",
        mapID = 650,
        coords = { x = 0.545, y = 0.778 },
        zone = "Highmountain - Thunder Totem Basement",
        faction = "Neutral",
        currency = "Order Resources",
        notes = "Decor Specialist - Take elevator down",
        items = {
            { itemID = 245405, name = "Large Highmountain Drum" },
            { itemID = 245409, name = "Dried Whitewash Corn" },
            { itemID = 245453, name = "Whitewash River Basket" },
            { itemID = 245456, name = "Warbrave's Brazier" },
            { itemID = 245457, name = "Riverbend Netting" },
            { itemID = 245460, name = "Skyhorn Storage Chest" },
            { itemID = 245461, name = "Tauren Vertical Windmill" },
            { itemID = 256913, name = "Tauren Jeweler's Roller" },
            { itemID = 257397, name = "Tauren Storyteller's Frame" },
            { itemID = 257401, name = "Skyhorn Banner" },
            { itemID = 257721, name = "Skyhorn Arrow Kite" },
            { itemID = 257722, name = "Hanging Arrow Kite" },
            { itemID = 257723, name = "Skyhorn Eagle Kite" },
            { itemID = 260698, name = "Kobold Trassure Pile" },
            { itemID = 264477, name = "Thunder Totem Mailbox" },
        },
    },
    {
        npcID = 108537,  -- Corrected from 120098
        name = "Crafty Palu",
        mapID = 650,
        coords = { x = 0.380, y = 0.465 },
        zone = "Highmountain - Shipwreck Cove",
        faction = "Neutral",
        currency = "Gold",
        notes = "Repairs vendor, requires Grand Fin-ale achievement",
        items = {},
    },
    -- Val'sharah
    {
        npcID = 106887,
        name = "Sylvia Hartshorn",
        mapID = 641, -- Val'sharah
        coords = { x = 0.547, y = 0.733 },
        zone = "Val'sharah - Lorlathil",
        faction = "Neutral",
        currency = "Order Resources",
        notes = "Requires Dreamweavers reputation",
        items = {},
    },
    {
        npcID = 120899,
        name = "Selfira Ambergrove",
        mapID = 641,
        coords = { x = 0.543, y = 0.724 },
        zone = "Val'sharah - Lorlathil",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },
    -- Suramar
    {
        npcID = 107109,
        name = "Leyweaver Inondra",
        mapID = 680, -- Suramar
        coords = { x = 0.406, y = 0.695 },
        zone = "Suramar - Grand Promenade",
        faction = "Neutral",
        currency = "Ancient Mana",
        notes = "Requires Nightfallen reputation",
        items = {},
    },
    {
        npcID = 97140,
        name = "First Arcanist Thalyssra",
        mapID = 680,
        coords = { x = 0.370, y = 0.468 },
        zone = "Suramar - Shal'Aran",
        faction = "Neutral",
        currency = "Ancient Mana",
        notes = "Requires Nightfallen reputation",
        items = {},
    },
    {
        npcID = 120897,
        name = "Jocenna",
        mapID = 680,
        coords = { x = 0.496, y = 0.628 },
        zone = "Suramar - Concourse of Destiny",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },
    -- Azsuna
    {
        npcID = 107135,
        name = "Veridis Fallon",
        mapID = 630, -- Azsuna
        coords = { x = 0.466, y = 0.438 },
        zone = "Azsuna - Nar'thalas Academy",
        faction = "Neutral",
        currency = "Order Resources",
        notes = "Requires Court of Farondis reputation",
        items = {},
    },
    {
        npcID = 116305,
        name = "Berazus",
        mapID = 630,
        coords = { x = 0.478, y = 0.233 },
        zone = "Azsuna - Illidari Stand",
        faction = "Neutral",
        currency = "Gold",
        items = {},
    },
    -- Stormheim
    {
        npcID = 106904,
        name = "Valdemar Stormseeker",
        mapID = 634, -- Stormheim
        coords = { x = 0.602, y = 0.516 },
        zone = "Stormheim - Valdisdall",
        faction = "Neutral",
        currency = "Order Resources",
        notes = "Requires Valarjar reputation",
        items = {},
    },
    -- Argus - Krokuun (The Vindicaar)
    {
        npcID = 125346,
        name = "Toraan the Revered",
        mapID = 830, -- Krokuun
        coords = { x = 0.681, y = 0.570 },
        zone = "Krokuun - The Vindicaar",
        faction = "Neutral",
        currency = "Veiled Argunite",
        notes = "Requires Army of the Light reputation",
        items = {},
    },
    -- Argus - Mac'Aree
    {
        npcID = 127151,
        name = "Chieftain Hatuun",
        mapID = 885, -- Mac'Aree
        coords = { x = 0.420, y = 0.764 },
        zone = "Mac'Aree - Argussian Reach camp",
        faction = "Neutral",
        currency = "Veiled Argunite",
        notes = "Requires Argussian Reach reputation",
        items = {},
    },
}

-------------------------------------------------------------------------------
-- Housing Neighborhood Vendors
-------------------------------------------------------------------------------

VendorDatabase.Neighborhoods = {
    -- NOTE: Housing neighborhood maps are instanced, vendors won't show on world map
    -- These are included for completeness but use placeholder coords
}

-------------------------------------------------------------------------------
-- Event / Holiday Vendors
-------------------------------------------------------------------------------

VendorDatabase.Events = {
    -- Brawler's Guild vendors are in instanced areas, use Orgrimmar/Stormwind coords
    -- Brawler's Guild - Horde (Brawl'gar Arena entrance in Orgrimmar)
    {
        npcID = 68364,
        name = "Paul North",
        mapID = 85, -- Orgrimmar
        coords = { x = 0.478, y = 0.616 },
        zone = "Brawl'gar Arena (Orgrimmar)",
        faction = "Horde",
        currency = "Gold",
        notes = "Brawler's Guild vendor - requires Rank progression",
        items = {},
    },
    {
        npcID = 145695,
        name = '"Bad Luck" Symmes',
        mapID = 85, -- Orgrimmar
        coords = { x = 0.478, y = 0.616 },
        zone = "Brawl'gar Arena (Orgrimmar)",
        faction = "Horde",
        currency = "Gold",
        notes = "Brawler's Guild vendor",
        items = {},
    },

    -- Brawler's Guild - Alliance (Bizmo's Brawlpub entrance in Stormwind)
    {
        npcID = 68363,
        name = "Quackenbush",
        mapID = 84, -- Stormwind
        coords = { x = 0.688, y = 0.172 },
        zone = "Bizmo's Brawlpub (Stormwind)",
        faction = "Alliance",
        currency = "Gold",
        notes = "Brawler's Guild vendor - requires Rank progression",
        items = {},
    },
    {
        npcID = 151941,
        name = "Dershway the Triggered",
        mapID = 84, -- Stormwind
        coords = { x = 0.688, y = 0.172 },
        zone = "Bizmo's Brawlpub (Stormwind)",
        faction = "Alliance",
        currency = "Gold",
        notes = "Brawler's Guild vendor",
        items = {},
    },

    -- Darkmoon Faire
    {
        npcID = 4577,
        name = "Lhara",
        mapID = 407, -- Darkmoon Island
        coords = { x = 0.482, y = 0.694 },
        zone = "Darkmoon Island",
        faction = "Neutral",
        currency = "Darkmoon Prize Tickets",
        seasonal = "Darkmoon Faire",
        items = {},
    },

    -- Lorewalking
    {
        npcID = 62088,
        name = "Lali the Assistant",
        mapID = 390, -- Vale of Eternal Blossoms
        coords = { x = 0.836, y = 0.318 },
        zone = "Vale of Eternal Blossoms - Seat of Knowledge",
        faction = "Neutral",
        currency = "Gold",
        notes = "Sells decor earned through Lorewalking achievements",
        items = {},
    },

    -- Dreamsurge Event (Dragonflight)
    {
        npcID = 210608,
        name = "Celestine of the Harvest",
        mapID = 2025, -- Thaldraszus (one of the locations)
        coords = { x = 0.512, y = 0.432 },
        zone = "Dragon Isles - Dreamsurge (Rotating)",
        faction = "Neutral",
        currency = "Dreamsurge Coalescence",
        notes = "Moves between 4 zones every 30 min",
        seasonal = "Dreamsurge",
        items = {},
    },

    -- Legion Remix (Timewalking)
    {
        npcID = 251179,
        name = "Domelius",
        mapID = 627, -- Dalaran (Legion)
        coords = { x = 0.486, y = 0.622 },
        zone = "Dalaran - Infinite Bazaar",
        faction = "Neutral",
        currency = "Bronze",
        notes = "Legion Remix event vendor",
        seasonal = "Legion Remix",
        items = {},
    },

    -- Midnight Pre-patch Event (Twilight Ascension)
    {
        npcID = 249196,
        name = "Materialist Ophinell",
        mapID = 241, -- Twilight Highlands
        coords = { x = 0.498, y = 0.813 },
        zone = "Twilight Highlands - Twilight Ascension Camp",
        faction = "Neutral",
        currency = "Twilight's Blade Insignia",
        notes = "Midnight pre-patch event quartermaster",
        seasonal = "Midnight Pre-patch",
        items = {},
    },
}

-------------------------------------------------------------------------------
-- Zone to Continent Mapping (for map pins)
-------------------------------------------------------------------------------

VendorDatabase.ZoneToContinentMap = {
    -- Eastern Kingdoms (Continent MapID: 13)
    [17] = 13,   -- Blasted Lands
    [21] = 13,   -- Silverpine Forest
    [23] = 13,   -- Eastern Plaguelands
    [25] = 13,   -- Hillsbrad Foothills
    [27] = 13,   -- Dun Morogh
    [32] = 13,   -- Searing Gorge
    [36] = 13,   -- Burning Steppes
    [48] = 13,   -- Loch Modan
    [56] = 13,   -- Wetlands
    [57] = 13,   -- Duskwood
    [84] = 13,   -- Stormwind
    [87] = 13,   -- Ironforge
    [90] = 13,   -- Undercity
    [94] = 13,   -- Eversong Woods
    [95] = 13,   -- Ghostlands
    [110] = 13,  -- Silvermoon City
    [217] = 13,  -- Gilneas
    [224] = 13,  -- Stranglethorn Vale (Northern)
    [241] = 13,  -- Twilight Highlands
    [242] = 13,  -- Blackrock Depths (dungeon)

    -- Kalimdor (Continent MapID: 12)
    [69] = 12,   -- Feralas / Darkmoon Island
    [70] = 12,   -- Dustwallow Marsh
    [85] = 12,   -- Orgrimmar
    [88] = 12,   -- Thunder Bluff
    [89] = 12,   -- Darnassus
    [407] = 12,  -- Darkmoon Island

    -- Northrend (Continent MapID: 113)
    [114] = 113, -- Borean Tundra
    [115] = 113, -- Dragonblight
    [116] = 113, -- Grizzly Hills
    [117] = 113, -- Howling Fjord
    [119] = 113, -- Sholazar Basin
    [120] = 113, -- The Storm Peaks
    [121] = 113, -- Zul'Drak
    [127] = 113, -- Crystalsong Forest
    [125] = 113, -- Dalaran (Northrend)

    -- Pandaria (Continent MapID: 424)
    [371] = 424, -- The Jade Forest
    [376] = 424, -- Valley of the Four Winds
    [379] = 424, -- Kun-Lai Summit
    [388] = 424, -- Townlong Steppes
    [390] = 424, -- Vale of Eternal Blossoms
    [418] = 424, -- Krasarang Wilds

    -- Draenor (Continent MapID: 572)
    [539] = 572, -- Shadowmoon Valley (Draenor)
    [542] = 572, -- Spires of Arak
    [543] = 572, -- Gorgrond
    [550] = 572, -- Nagrand (Draenor)
    [582] = 572, -- Lunarfall (Alliance Garrison)
    [590] = 572, -- Frostwall (Horde Garrison)
    [622] = 572, -- Stormshield
    [624] = 572, -- Warspear
    [525] = 572, -- Frostfire Ridge
    [535] = 572, -- Talador

    -- Broken Isles (Continent MapID: 619)
    [24] = 619,  -- Light's Hope Chapel (Paladin)
    [626] = 619, -- The Hall of Shadows (Rogue)
    [627] = 619, -- Dalaran (Legion)
    [630] = 619, -- Azsuna
    [634] = 619, -- Stormheim
    [641] = 619, -- Val'sharah
    [647] = 619, -- Acherus (Death Knight)
    [650] = 619, -- Highmountain
    [680] = 619, -- Suramar
    [695] = 619, -- Skyhold (Warrior)
    [702] = 619, -- Netherlight Temple (Priest)
    [709] = 619, -- Wandering Isle (Monk)
    [717] = 619, -- Dreadscar Rift (Warlock)
    [720] = 619, -- Fel Hammer (Demon Hunter)
    [726] = 619, -- The Maelstrom (Shaman)
    [734] = 619, -- Hall of the Guardian (Mage)
    [739] = 619, -- Trueshot Lodge (Hunter)
    [747] = 619, -- The Dreamgrove (Druid)
    [885] = 619, -- Mac'Aree (Argus)
    [882] = 619, -- Eredath (Argus)
    [830] = 619, -- Krokuun (Argus)

    -- Shadowlands (Continent MapID: 1550)
    [1525] = 1550, -- Revendreth
    [1533] = 1550, -- Bastion
    [1536] = 1550, -- Maldraxxus
    [1543] = 1550, -- The Maw
    [1565] = 1550, -- Ardenweald
    [1670] = 1550, -- Oribos
    [1699] = 1550, -- Sinfall

    -- Kul Tiras (Continent MapID: 876)
    [895] = 876,   -- Tiragarde Sound
    [896] = 876,   -- Drustvar
    [942] = 876,   -- Stormsong Valley
    [1161] = 876,  -- Boralus
    [1462] = 876,  -- Mechagon

    -- Zandalar (Continent MapID: 875)
    [862] = 875,   -- Zuldazar
    [863] = 875,   -- Nazmir
    [864] = 875,   -- Vol'dun
    [1165] = 875,  -- Dazar'alor

    -- Dragon Isles (Continent MapID: 1978)
    [2022] = 1978, -- The Waking Shores
    [2023] = 1978, -- Ohn'ahran Plains
    [2024] = 1978, -- The Azure Span
    [2025] = 1978, -- Thaldraszus
    [2112] = 1978, -- Valdrakken
    [2133] = 1978, -- Zaralek Cavern
    [2151] = 1978, -- Forbidden Reach
    [2200] = 1978, -- Emerald Dream
    [2239] = 1978, -- Amirdrassil / Bel'ameth

    -- Khaz Algar / The War Within (Continent MapID: 2274)
    [2214] = 2274, -- The Ringing Deeps
    [2215] = 2274, -- Hallowfall
    [2248] = 2274, -- Isle of Dorn
    [2255] = 2274, -- Azj-Kahet
    [2339] = 2274, -- Dornogal
    [2346] = 2274, -- Undermine
    [2472] = 2274, -- Tazavesh (K'aresh)
}

-- Continent names for display
VendorDatabase.ContinentNames = {
    [12] = "Kalimdor",
    [13] = "Eastern Kingdoms",
    [113] = "Northrend",
    [424] = "Pandaria",
    [572] = "Draenor",
    [619] = "Broken Isles",
    [875] = "Zandalar",
    [876] = "Kul Tiras",
    [1550] = "Shadowlands",
    [1978] = "Dragon Isles",
    [2274] = "Khaz Algar",
}

-------------------------------------------------------------------------------
-- Load All Vendors Function
-------------------------------------------------------------------------------

function VendorDatabase:GetAllVendors()
    local allVendors = {}

    local function AddVendors(vendorList)
        if vendorList then
            for _, vendor in ipairs(vendorList) do
                table.insert(allVendors, vendor)
            end
        end
    end

    AddVendors(self.TWW)
    AddVendors(self.Undermine)
    AddVendors(self.Karesh)
    AddVendors(self.Dragonflight)
    AddVendors(self.Shadowlands)
    AddVendors(self.BFA)
    AddVendors(self.WoD)
    AddVendors(self.MoP)
    AddVendors(self.WotLK)
    AddVendors(self.Classic)
    AddVendors(self.OrderHalls)
    AddVendors(self.Neighborhoods)
    AddVendors(self.Events)

    return allVendors
end

-- Get vendors by continent
function VendorDatabase:GetVendorsByContinent(continentMapID)
    local vendors = {}
    for _, vendor in ipairs(self:GetAllVendors()) do
        local vendorContinent = self.ZoneToContinentMap[vendor.mapID]
        if vendorContinent == continentMapID then
            table.insert(vendors, vendor)
        end
    end
    return vendors
end

-- Get vendors by zone
function VendorDatabase:GetVendorsByZone(zoneMapID)
    local vendors = {}
    for _, vendor in ipairs(self:GetAllVendors()) do
        if vendor.mapID == zoneMapID then
            table.insert(vendors, vendor)
        end
    end
    return vendors
end

-- Get vendors by faction
function VendorDatabase:GetVendorsByFaction(faction)
    local vendors = {}
    local playerFaction = UnitFactionGroup("player")
    for _, vendor in ipairs(self:GetAllVendors()) do
        if vendor.faction == "Neutral" or vendor.faction == faction or vendor.faction == playerFaction then
            table.insert(vendors, vendor)
        end
    end
    return vendors
end

-- Get continent for a zone
function VendorDatabase:GetContinentForZone(zoneMapID)
    return self.ZoneToContinentMap[zoneMapID]
end

-- Get continent name
function VendorDatabase:GetContinentName(continentMapID)
    return self.ContinentNames[continentMapID] or "Unknown"
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("VendorDatabase", VendorDatabase)
end
