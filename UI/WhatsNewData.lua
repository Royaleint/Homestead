--[[
    Homestead - WhatsNewData
    Version-keyed feature data for the What's New popup.
    Pure data — no logic. Add new entries at the top for each release.
]]

local _, HA = ...

HA.WhatsNew = {
    ["2.3.0"] = {
        heroTexture = "Interface\\AddOns\\Homestead\\Textures\\WhatsNew_v230",
        heroHeight = 250,
        title = "Homestead - What's New in v2.3!",
        features = {
            {
                atlas = "housing-decor-vendor_32",
                heading = "Decor Availability",
                body = "Every decor vendor now shows how many items you've collected, versus how many decor items are available to buy, and how many are locked behind reputation, quests, or other requirements. The progress bar fills in three colors so you can see your status at a glance.",
            },
            {
                icon = "Interface\\Icons\\INV_Misc_Map_01",
                heading = "Unified Tooltips",
                body = "Vendor pin tooltips now list every item colored by status: green for collected, white for available, red for locked. The summary line is consistent everywhere you hover.",
            },
        },
    },
    ["2.0.0"] = {
        title = "Homestead - What's New in v2.0!",
        features = {
            {
                icon = "Interface\\Icons\\INV_Misc_Gem_Variety_02",
                heading = "Catalog Glow",
                body = "Catalog items now glow by status: green if you own it, yellow if you can get it now, red if something's blocking you.",
            },
            {
                icon = "Interface\\AddOns\\Homestead\\Textures\\HomesteadPortrait_64",
                heading = "Endeavor Dashboard",
                body = "See how much XP you need for your next Endeavor milestone and how much of the vendor's stock you've collected, right on the progress bar.",
            },
        },
    },
    ["1.6.0"] = {
        title = "Homestead - What's New in v1.6!",
        features = {
            {
                icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
                heading = "Panel Search & Source Filter",
                body = "Search for any item, vendor, or zone directly from the panel. A new source filter lets you focus on Vendor, Quest, Achievement, Profession, Event, or Drop sources. Item counts and grids update instantly.",
            },
            {
                icon = "Interface\\Icons\\INV_Misc_Note_06",
                heading = "Smarter Tooltips",
                body = "Tooltips now show every known source for an item, adapt to context (compact at vendors, detailed in the panel), and show completion status per source. Hold Shift anywhere to flip between modes.",
            },
        },
    },
    ["1.5.0"] = {
        title = "Homestead - What's New in v1.5!",
        features = {
            {
                icon = "Interface\\Icons\\INV_Misc_Map_01",
                heading = "Homestead Panel",
                body = "A vendor panel now docks to your world map. Open the map (M) and click the Homestead tracking option to toggle it. Right-click the minimap button to open it as a standalone window. Click vendors to browse items, check ownership, and preview decor in 3D.",
            },
            {
                icon = "Interface\\Icons\\INV_Misc_Note_06",
                heading = "Enhanced Tooltips",
                body = "Tooltips now show where to find items, what's required to unlock them, and whether you've completed the requirements.",
            },
        },
    },
    ["1.3.0"] = {
        heroTexture = nil,
        title = "v1.3.0 Highlights",
        features = {
            {
                icon = "Interface\\Icons\\INV_Misc_Bag_27",
                heading = "Pin Colors, Collection Tracking, and Vendor Scanner Overhaul",
                body = "This release overhauls map pin visuals, adds collection progress tracking directly on the map.",
            },
            {
                icon = "Interface\\Icons\\Ability_Spy",
                heading = "Vendor Scanner",
                body = "Ownership indicators now appear directly on merchant window item slots.",
            },
        },
    },
    -- Add new entries here for each release. Oldest entries can be pruned after several versions.
}
