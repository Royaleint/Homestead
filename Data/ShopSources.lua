-- ShopSources.lua — Static source data for shop, promotional, and Twitch drop items.
-- Created: 2026-03-22 | Entries: 42
-- Sources: catalog sourceText scan (27 "Shop" items) + Wowhead pack articles + Roofus charity pack
--
-- Schema:
--   [itemID] = {
--       method   = "hearthsteel" | "twitch" | "promo" | "charity"
--       cost     = number or nil (nil = free)
--       name     = string (pack/promo name for display)
--       expires  = "YYYY-MM-DD" or nil (nil = permanent)
--   }
local _, HA = ...

HA.ShopSources = {
    ---------------------------------------------------------------------------
    -- Individual Hearthsteel items (shop-only, not available from gold vendors)
    ---------------------------------------------------------------------------
    [256764] = { method = "hearthsteel", name = "In-Game Shop" },              -- Sanctuary's Horadric Cube
    [258211] = { method = "hearthsteel", name = "In-Game Shop" },              -- Kirin Tor Glass Table
    [259055] = { method = "hearthsteel", name = "In-Game Shop" },              -- Hatred's Wolfpelt Rug
    [259056] = { method = "hearthsteel", name = "In-Game Shop" },              -- Prime Evil's Chest
    [263052] = { method = "hearthsteel", name = "In-Game Shop" },              -- Beloved Lion Plushie
    [263053] = { method = "hearthsteel", name = "In-Game Shop" },              -- Beloved Wolf Plushie
    [263383] = { method = "hearthsteel", name = "In-Game Shop" },              -- Corked Bottle of Liquid Mystery
    [264278] = { method = "hearthsteel", name = "In-Game Shop" },              -- Sturdy Portable Ice Chest
    [264279] = { method = "hearthsteel", name = "In-Game Shop" },              -- Tall Corked Bottle of Liquid Mystery
    [264280] = { method = "hearthsteel", name = "In-Game Shop" },              -- Short Corked Bottle of Liquid Mystery
    [264281] = { method = "hearthsteel", name = "In-Game Shop" },              -- Preserved Gift of Gilneas
    [264282] = { method = "hearthsteel", name = "In-Game Shop" },              -- Bluebird's Golden Cage
    [264283] = { method = "hearthsteel", name = "In-Game Shop" },              -- Backboard and Hoop Playset
    [264384] = { method = "hearthsteel", name = "In-Game Shop" },              -- Zapmaster Viewer 3000

    ---------------------------------------------------------------------------
    -- Spring Blossom Pack (Hearthsteel)
    ---------------------------------------------------------------------------
    [250798] = { method = "hearthsteel", name = "Spring Blossom Pack" },        -- Spring Blossom Shelf
    [250797] = { method = "hearthsteel", name = "Spring Blossom Pack" },        -- Spring Blossom Ceiling Light
    [253547] = { method = "hearthsteel", name = "Spring Blossom Pack" },        -- Spring Blossom Wreath
    [254417] = { method = "hearthsteel", name = "Spring Blossom Pack" },        -- Spring Blossom Hanging Chair
    [258568] = { method = "hearthsteel", name = "Spring Blossom Pack" },        -- Spring Blossom Window
    [258569] = { method = "hearthsteel", name = "Spring Blossom Pack" },        -- Spring Blossom Gazebo
    [263290] = { method = "hearthsteel", name = "Spring Blossom Pack" },        -- Spring Blossom Tree
    [266167] = { method = "hearthsteel", name = "Spring Blossom Pack" },        -- Spring Blossom Pond

    ---------------------------------------------------------------------------
    -- Lush Garden Pack (Hearthsteel)
    ---------------------------------------------------------------------------
    [250793] = { method = "hearthsteel", cost = 250, name = "Lush Garden Trellis" },  -- individual purchase
    [252419] = { method = "hearthsteel", name = "Lush Garden Pack" },           -- Lush Garden Fungal Basin
    [253546] = { method = "hearthsteel", name = "Lush Garden Pack" },           -- Lush Garden Butterfly Sconce
    [258294] = { method = "hearthsteel", name = "Lush Garden Pack" },           -- Lush Garden Gnome-Like Statue
    [258567] = { method = "hearthsteel", name = "Lush Garden Pack" },           -- Lush Garden Fungal Chair
    [258888] = { method = "hearthsteel", name = "Lush Garden Pack" },           -- Lush Garden Fungal Fountain
    [266070] = { method = "hearthsteel", name = "Lush Garden Pack" },           -- Lush Garden Fungal Table
    [266163] = { method = "hearthsteel", name = "Lush Garden Pack" },           -- Lush Garden Fungal Planter

    ---------------------------------------------------------------------------
    -- Starter Pack (Hearthsteel)
    ---------------------------------------------------------------------------
    [260727] = { method = "hearthsteel", name = "Starter Pack" },               -- Alliance Doormat
    [260728] = { method = "hearthsteel", name = "Starter Pack" },               -- Horde Doormat

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
    -- Promotional
    ---------------------------------------------------------------------------
    [264396] = { method = "promo", name = "Zillow for Warcraft" },              -- Naturally Elegant Doormat
    [264397] = { method = "promo", name = "Zillow for Warcraft" },              -- Simply Adorned Vase and Flowers
}
