--[[
    Homestead - WhatsNewData
    Version-keyed feature data for the What's New popup.
    Pure data — no logic. Add new entries at the top for each release.
]]

local _, HA = ...

HA.WhatsNew = {
    ["1.6.0"] = {
        heroTexture = "Interface\\AddOns\\Homestead\\Textures\\Midnight",
        heroHeight = 190,
        title = "Homestead - What's New in v1.6!",
        features = {
            {
                icon = "Interface\\AddOns\\Homestead\\Textures\\HomesteadPortrait_64",
                heading = "In by Midnight!",
                body = "Homestead is updated for Midnight with NEW badge icons for Midnight and all the vendors scanned and \"hopefully\" verified.",
            },
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
        heroTexture = "Interface\\AddOns\\Homestead\\Textures\\HomesteadPanel",
        heroHeight = 250,
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
