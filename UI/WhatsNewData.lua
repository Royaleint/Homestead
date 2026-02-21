--[[
    Homestead - WhatsNewData
    Version-keyed feature data for the What's New popup.
    Pure data — no logic. Add new entries at the top for each release.
]]

local _, HA = ...

HA.WhatsNew = {
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
            {
                icon = "Interface\\Icons\\Calendar_WinterVeil",
                heading = "Event Vendor Pins",
                body = "Holiday vendors now appear on the map automatically when their event is active.",
            },
            {
                icon = "Interface\\Icons\\Trade_Engineering",
                heading = "Bug Fixes & Performance",
                body = "Fixed combat taint, scanner errors, and panel displacement. Reorganized settings and improved performance.",
            },
        },
    },
    ["1.4.0"] = {
        heroTexture = "Interface\\AddOns\\Homestead\\Textures\\HomesteadPanel",
        heroHeight = 250,  -- 1024x256 source at ~750px display width
        title = "Homestead -What's New in v1.4.0!",
        features = {
            {
                icon = "Interface\\Icons\\INV_Misc_Map_01",
                heading = "Homestead Panel Launch!",
                body = "A vendor panel now docks to the left side of your world map. Open the map in any zone and see every decor vendor there alongside your collection progress",
            },
            {
                icon = "Interface\\Icons\\Achievement_Zone_GarrisonMap",
                heading = "Indoor Vendor Pins",
                body = "Vendor pins now display correctly in indoor maps like Dalaran Underbelly, Thunder Totem, Suramar City, and other interior zones that use their own map layer.",
            },
            {
                icon = "Interface\\Icons\\INV_Misc_Note_06",
                heading = "Bug Fixes",
                body = "Fixed an error when opening certain vendors in instanced content, such as mount merchants after holiday bosses. (Thanks kittywulfe!).",
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
