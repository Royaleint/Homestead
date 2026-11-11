-- ShopSources.lua — Static source data for shop, promotional, and charity items.
-- Created: 2026-03-22 | Entries: 95
-- Sources: in-game shop listing (prices as of 2026-11-10), promotion announcements, Roofus charity pack
--
-- Schema:
--   [itemID] = {
--       method   = "hearthsteel" | "twitch" | "promo" | "charity" | "unlisted"
--                  ("unlisted" = marked as a shop item by the game but not on sale; no name)
--       cost     = number or nil (nil = free)
--       name     = string (pack/promo name for display)
--       expires  = "YYYY-MM-DD" or nil (nil = permanent)
--   }
local _, HA = ...

HA.ShopSources = {
    ---------------------------------------------------------------------------
    -- Individual Hearthsteel items (shop-only, not available from gold vendors)
    ---------------------------------------------------------------------------
    [263052] = { method = "hearthsteel", cost = 100, name = "In-Game Shop" },   -- Beloved Lion Plushie
    [263053] = { method = "hearthsteel", cost = 100, name = "In-Game Shop" },   -- Beloved Wolf Plushie
    [250794] = { method = "hearthsteel", cost = 10, name = "In-Game Shop" },    -- Colorful Shroomic Egg
    [250795] = { method = "hearthsteel", cost = 10, name = "In-Game Shop" },    -- Colorful Dotted Egg
    [250796] = { method = "hearthsteel", cost = 10, name = "In-Game Shop" },    -- Colorful Striped Egg
    [281372] = { method = "hearthsteel", cost = 100, name = "In-Game Shop" },   -- Zhevraskin Rug

    ---------------------------------------------------------------------------
    -- Sanctuary Chess Set (Diablo IV: Lord of Hatred purchase bonus; extra copies sold by decor vendors for gold)
    ---------------------------------------------------------------------------
    [259057] = { method = "promo", name = "Diablo IV: Lord of Hatred" },    -- Sanctuary's Chess Match
    [259058] = { method = "promo", name = "Diablo IV: Lord of Hatred" },    -- Sanctuary's Chess Board
    [259059] = { method = "promo", name = "Diablo IV: Lord of Hatred" },    -- Sanctuary Chess Dark Bishop
    [259060] = { method = "promo", name = "Diablo IV: Lord of Hatred" },    -- Sanctuary Chess Dark Rook
    [259061] = { method = "promo", name = "Diablo IV: Lord of Hatred" },    -- Sanctuary Chess Dark Queen
    [259062] = { method = "promo", name = "Diablo IV: Lord of Hatred" },    -- Sanctuary Chess Dark Pawn
    [259063] = { method = "promo", name = "Diablo IV: Lord of Hatred" },    -- Sanctuary Chess Dark Knight
    [259064] = { method = "promo", name = "Diablo IV: Lord of Hatred" },    -- Sanctuary Chess Dark King
    [259065] = { method = "promo", name = "Diablo IV: Lord of Hatred" },    -- Sanctuary Chess Light Bishop
    [259066] = { method = "promo", name = "Diablo IV: Lord of Hatred" },    -- Sanctuary Chess Light Rook
    [259067] = { method = "promo", name = "Diablo IV: Lord of Hatred" },    -- Sanctuary Chess Light Queen
    [259068] = { method = "promo", name = "Diablo IV: Lord of Hatred" },    -- Sanctuary Chess Light Pawn
    [259069] = { method = "promo", name = "Diablo IV: Lord of Hatred" },    -- Sanctuary Chess Light Knight
    [259070] = { method = "promo", name = "Diablo IV: Lord of Hatred" },    -- Sanctuary Chess Light King

    ---------------------------------------------------------------------------
    -- Spring Blossom (Hearthsteel, sold individually)
    ---------------------------------------------------------------------------
    [250798] = { method = "hearthsteel", cost = 250, name = "In-Game Shop" },  -- Spring Blossom Shelf
    [250797] = { method = "hearthsteel", cost = 100, name = "In-Game Shop" },  -- Spring Blossom Ceiling Light
    [253547] = { method = "hearthsteel", cost = 100, name = "In-Game Shop" },  -- Spring Blossom Wreath
    [254417] = { method = "hearthsteel", cost = 250, name = "In-Game Shop" },  -- Spring Blossom Hanging Chair
    [258568] = { method = "hearthsteel", cost = 100, name = "In-Game Shop" },  -- Spring Blossom Window
    [258569] = { method = "hearthsteel", cost = 800, name = "In-Game Shop" },  -- Spring Blossom Gazebo
    [263290] = { method = "hearthsteel", cost = 250, name = "In-Game Shop" },  -- Spring Blossom Tree
    [266167] = { method = "hearthsteel", cost = 600, name = "In-Game Shop" },  -- Spring Blossom Pond
    [263291] = { method = "hearthsteel", cost = 300, name = "In-Game Shop" },   -- Spring Blossom Tree Pond
    [265555] = { method = "hearthsteel", cost = 10, name = "In-Game Shop" },    -- Spring Blossom Stepping Stone
    [265556] = { method = "hearthsteel", cost = 300, name = "In-Game Shop" },   -- Spring Blossom Privacy Screen
    [265557] = { method = "hearthsteel", cost = 20, name = "In-Game Shop" },    -- Spring Blossom Stepping Stone Duo
    [265558] = { method = "hearthsteel", cost = 30, name = "In-Game Shop" },    -- Spring Blossom Stepping Stone Trio
    [265559] = { method = "hearthsteel", cost = 50, name = "In-Game Shop" },    -- Spring Blossom Stepping Stone Collection
    [266068] = { method = "hearthsteel", cost = 100, name = "In-Game Shop" },   -- Spring Blossom Tea Set
    [266069] = { method = "hearthsteel", cost = 300, name = "In-Game Shop" },   -- Spring Blossom Table
    [266165] = { method = "hearthsteel", cost = 100, name = "In-Game Shop" },   -- Spring Blossom Lantern
    [266166] = { method = "hearthsteel", cost = 500, name = "In-Game Shop" },   -- Spring Blossom Tranquility Garden

    ---------------------------------------------------------------------------
    -- Lush Garden (Hearthsteel, sold individually)
    ---------------------------------------------------------------------------
    [250793] = { method = "hearthsteel", cost = 250, name = "In-Game Shop" },  -- Lush Garden Trellis
    [252419] = { method = "hearthsteel", cost = 250, name = "In-Game Shop" },  -- Lush Garden Fungal Basin
    [253546] = { method = "hearthsteel", cost = 100, name = "In-Game Shop" },  -- Lush Garden Butterfly Sconce
    [258294] = { method = "hearthsteel", cost = 50, name = "In-Game Shop" },  -- Lush Garden Gnome-Like Statue
    [258567] = { method = "hearthsteel", cost = 250, name = "In-Game Shop" },  -- Lush Garden Fungal Chair
    [258888] = { method = "hearthsteel", cost = 500, name = "In-Game Shop" },  -- Lush Garden Fungal Fountain
    [266070] = { method = "hearthsteel", cost = 300, name = "In-Game Shop" },  -- Lush Garden Fungal Table
    [266163] = { method = "hearthsteel", cost = 100, name = "In-Game Shop" },  -- Lush Garden Fungal Planter
    [264692] = { method = "hearthsteel", cost = 100, name = "In-Game Shop" },   -- Lush Garden Window
    [266162] = { method = "hearthsteel", cost = 100, name = "In-Game Shop" },   -- Lush Garden Hedge
    [266164] = { method = "hearthsteel", cost = 200, name = "In-Game Shop" },   -- Lush Garden Fungal Picnic
    [267203] = { method = "hearthsteel", cost = 500, name = "In-Game Shop" },   -- Lush Garden Stable
    [268550] = { method = "hearthsteel", cost = 200, name = "In-Game Shop" },   -- Lush Garden Rug

    ---------------------------------------------------------------------------
    -- Doormats (Hearthsteel, sold individually)
    ---------------------------------------------------------------------------
    [260727] = { method = "hearthsteel", cost = 200, name = "In-Game Shop" },   -- Alliance Doormat
    [260728] = { method = "hearthsteel", cost = 200, name = "In-Game Shop" },   -- Horde Doormat

    ---------------------------------------------------------------------------
    -- Grimtide (Hearthsteel)
    ---------------------------------------------------------------------------
    [285105] = { method = "hearthsteel", cost = 200, name = "In-Game Shop" },   -- Grimtide Grand Table
    [285107] = { method = "hearthsteel", cost = 100, name = "In-Game Shop" },   -- Grimtide Side Table
    [285109] = { method = "hearthsteel", cost = 50, name = "In-Game Shop" },    -- Grimtide Dining Chair
    [285114] = { method = "hearthsteel", cost = 200, name = "In-Game Shop" },   -- Grimtide Couch
    [285116] = { method = "hearthsteel", cost = 100, name = "In-Game Shop" },   -- Small Grimtide Rug
    [285118] = { method = "hearthsteel", cost = 100, name = "In-Game Shop" },   -- Grimtide Rug
    [285120] = { method = "hearthsteel", cost = 100, name = "In-Game Shop" },   -- Grimtide Coffee Table
    [285122] = { method = "hearthsteel", cost = 300, name = "In-Game Shop" },   -- Grimtide Grand Piano
    [285124] = { method = "hearthsteel", cost = 50, name = "In-Game Shop" },    -- Grimtide Tentacle
    [285126] = { method = "hearthsteel", cost = 50, name = "In-Game Shop" },    -- Grimtide Display Anchor
    [285128] = { method = "hearthsteel", cost = 30, name = "In-Game Shop" },    -- Grimtide Enchanted Candles
    [285130] = { method = "hearthsteel", cost = 300, name = "In-Game Shop" },   -- Grimtide Chandelier
    [285132] = { method = "hearthsteel", cost = 50, name = "In-Game Shop" },    -- Grimtide Sconce
    [285134] = { method = "hearthsteel", cost = 50, name = "In-Game Shop" },    -- Grimtide Candelabra
    [285136] = { method = "hearthsteel", cost = 200, name = "In-Game Shop" },   -- Grimtide Bookcase
    [285138] = { method = "hearthsteel", cost = 50, name = "In-Game Shop" },    -- Grimtide Floor Hatch
    [285140] = { method = "hearthsteel", cost = 10, name = "In-Game Shop" },    -- Grimtide Tall Enchanted Candle
    [285142] = { method = "hearthsteel", cost = 10, name = "In-Game Shop" },    -- Grimtide Enchanted Candle
    [285144] = { method = "hearthsteel", cost = 10, name = "In-Game Shop" },    -- Grimtide Small Enchanted Candle
    [286002] = { method = "hearthsteel", cost = 50, name = "In-Game Shop" },    -- Nighttime Grimtide Window
    [286004] = { method = "hearthsteel", cost = 50, name = "In-Game Shop" },    -- Daytime Grimtide Window

    ---------------------------------------------------------------------------
    -- Roofus Charity Pack
    ---------------------------------------------------------------------------
    [259044] = { method = "charity", name = "Roofus Charity Pack" },            -- Paw Pal Water Dish
    [259045] = { method = "charity", name = "Roofus Charity Pack" },            -- Paw Pal Bed and Blanket
    [259046] = { method = "charity", name = "Roofus Charity Pack" },            -- Paw Pal Bed
    [259093] = { method = "charity", name = "Roofus Charity Pack" },            -- Paw Pal Dog House Frame
    [259094] = { method = "charity", name = "Roofus Charity Pack" },            -- Paw Pal Dog House Elwynn Roof
    [264275] = { method = "charity", name = "Roofus Charity Pack" },            -- Paw Pal Dog House Durotar Roof
    [264276] = { method = "charity", name = "Roofus Charity Pack" },            -- Paw Pal Dog House Eversong Roof
    [264277] = { method = "charity", name = "Roofus Charity Pack" },            -- Paw Pal Dog House Shadowglen Roof

    ---------------------------------------------------------------------------
    -- Promotional and purchase-bonus items (not sold for Hearthsteel)
    ---------------------------------------------------------------------------
    [256764] = { method = "promo", name = "Diablo II: Resurrected - Reign of the Warlock" },  -- Sanctuary's Horadric Cube
    [259055] = { method = "promo", name = "Diablo IV: Lord of Hatred" },    -- Hatred's Wolfpelt Rug
    [259056] = { method = "promo", name = "Diablo IV: Lord of Hatred" },    -- Prime Evil's Chest
    [263383] = { method = "promo", name = "Fanta" },                        -- Corked Bottle of Liquid Mystery
    [264278] = { method = "promo", name = "Fanta" },                        -- Sturdy Portable Ice Chest
    [264279] = { method = "promo", name = "Fanta" },                        -- Tall Corked Bottle of Liquid Mystery
    [264280] = { method = "promo", name = "Fanta" },                        -- Short Corked Bottle of Liquid Mystery
    [264281] = { method = "promo", name = "Pinterest" },                    -- Preserved Gift of Gilneas
    [264282] = { method = "promo", name = "Pinterest" },                    -- Bluebird's Golden Cage
    [264283] = { method = "promo", name = "Pinterest" },                    -- Backboard and Hoop Playset
    [264396] = { method = "promo", name = "Zillow for Warcraft" },              -- Naturally Elegant Doormat
    [264397] = { method = "promo", name = "Zillow for Warcraft" },              -- Simply Adorned Vase and Flowers

    ---------------------------------------------------------------------------
    -- Marked as a shop item by the game, but not on sale and origin unknown
    ---------------------------------------------------------------------------
    [264384] = { method = "unlisted" },           -- Zapmaster Viewer 3000
}
