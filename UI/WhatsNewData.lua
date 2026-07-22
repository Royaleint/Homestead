--[[
    Homestead - WhatsNewData
    Version-keyed feature data for the What's New popup.
    Pure data — no logic. Add new entries at the top for each release.
]]

local _, HA = ...

HA.WhatsNew = {
    ["2.7.0"] = {
        title = "Homestead - What's New in v2.7.0!",
        heroTexture = HA.Constants.TEXTURE_ROOT .. "WhatsNewDecorDrops",
        heroHeight = 280,
        features = {
            {
                -- HS-232: our own drop-pin art (same icon the world-map drop
                -- pin uses — PinFrameFactory:CreateDropPinFrame) instead of a
                -- generic skull icon, so the card and the feature it's
                -- describing visually match. TEXTURE_ROOT keeps this safe
                -- across the CurseForge/DevBuild folder-name split.
                icon = HA.Constants.TEXTURE_ROOT .. "HomesteadDropIcon_32",
                heading = "Find Decor Drops on the Map",
                body = "Decor that drops from dungeon and raid bosses now shows on your map: right on the boss inside the instance, and at the dungeon entrance on the zone map. Pins show your collected count, and the side panel lists every boss and its drops when you're viewing an instance map.",
            },
            {
                -- Requested atlas "worldquest-icon-engineering" is pending an
                -- in-game C_Texture.GetAtlasInfo check — atlas names live in
                -- art data, not UI Lua, so source greps can't verify ANY
                -- atlas (and our Blizzard checkouts are partial besides).
                -- Swap this icon for the atlas once confirmed in-game.
                icon = "Interface\\Icons\\Spell_Nature_TimeStop",
                heading = "Major Performance Work",
                body = "Fixed freezes when opening the world map after a reload, hovering item tooltips, looting with full bags, and flying across zones. The map, bags, and tooltips should all feel smoother.",
            },
        },
    },
    ["2.6.0"] = {
        title = "Homestead - What's New in v2.6.0!",
        features = {
            {
                icon = "Interface\\Icons\\INV_Misc_Key_03",
                heading = "See Why Decor Is Locked",
                body = "Decor gated behind an achievement, reputation, or profession rank now displays as locked with its exact unlock requirement, in the catalog and on vendor views.",
            },
            {
                atlas = "housing-decor-vendor_32",
                heading = "Base Vendor Prices",
                body = "Vendor prices now show each vendor's base price, before any reputation discount. Everyone sees the same price.",
            },
            {
                icon = "Interface\\Icons\\INV_Misc_Note_06",
                heading = "Cleaner Tooltips",
                body = "Buy prices are clearly labeled Vendor Price, and the confusing sell-back price line no longer appears on Homestead tooltips.",
            },
        },
    },
    ["2.5.3"] = {
        title = "Homestead - What's New in v2.5.3!",
        features = {
            {
                icon = "Interface\\Icons\\INV_Misc_Gem_Variety_02",
                heading = "Ownership Display Fixed",
                body = "Some owned decor was incorrectly showing as uncollected in tooltips and the catalog. This is now correct.",
            },
            {
                icon = "Interface\\Icons\\INV_Misc_Note_06",
                heading = "Options Panel Fixed",
                body = "The Homestead options panel was missing from the WoW Settings menu on some sessions. It now appears reliably.",
            },
        },
    },
    ["2.5.2"] = {
        title = "Homestead - What's New in v2.5.2!",
        features = {
            {
                icon = "Interface\\Icons\\INV_Misc_Gem_Variety_02",
                heading = "Decor Ownership Corrected",
                body = "Patch 12.0.7 decor was incorrectly showing as already collected on vendors. Ownership now displays correctly for all decor, new and old.",
            },
            {
                atlas = "housing-decor-vendor_32",
                heading = "Clearer Collection Badges",
                body = "The Homestead badge is easier to read at a glance, and color consistently correct in the vendor window.",
            },
        },
    },
    ["2.5.1"] = {
        title = "Homestead - What's New in v2.5.1!",
        features = {
            {
                atlas = "housing-decor-vendor_32",
                heading = "New Currency Vendor",
                body = "Updated for patch 12.0.7 including Zuronar in the Showdown zones.",
            },
            {
                icon = "Interface\\Icons\\INV_Misc_Gem_Variety_02",
                heading = "Fresh Decor for Patch 12.0.7",
                body = "Added 86+ new items to the Founder's Point and Razorwind Shores vendors, ready the moment patch 12.0.7 goes live.",
            },
        },
    },
    ["2.3.0"] = {
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
                icon = HA.Constants.TEXTURE_ROOT .. "HomesteadPortrait_64",
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
