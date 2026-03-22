-- ShopSources.lua — Static source data for shop, promotional, and Twitch drop items.
-- Created: 2026-03-22 | Entries: 17
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
    -- Spring Blossom Pack (Hearthsteel)
    ---------------------------------------------------------------------------
    [250798] = { method = "hearthsteel", name = "Spring Blossom Pack" },        -- Spring Blossom Shelf
    [250797] = { method = "hearthsteel", name = "Spring Blossom Pack" },        -- Spring Blossom Ceiling Light
    [253547] = { method = "hearthsteel", name = "Spring Blossom Pack" },        -- Spring Blossom Wreath
    [254417] = { method = "hearthsteel", name = "Spring Blossom Pack" },        -- Spring Blossom Hanging Chair
    [258568] = { method = "hearthsteel", name = "Spring Blossom Pack" },        -- Spring Blossom Window
    [258569] = { method = "hearthsteel", name = "Spring Blossom Pack" },        -- Spring Blossom Gazebo
    [263290] = { method = "hearthsteel", name = "Spring Blossom Pack" },        -- Spring Blossom Tree

    ---------------------------------------------------------------------------
    -- Lush Garden Pack (Hearthsteel)
    ---------------------------------------------------------------------------
    [250793] = { method = "hearthsteel", cost = 250, name = "Lush Garden Trellis" },  -- individual purchase
    [252419] = { method = "hearthsteel", name = "Lush Garden Pack" },           -- Lush Garden Fungal Basin
    [253546] = { method = "hearthsteel", name = "Lush Garden Pack" },           -- Lush Garden Butterfly Sconce
    [258294] = { method = "hearthsteel", name = "Lush Garden Pack" },           -- Lush Garden Gnome-Like Statue
    [258567] = { method = "hearthsteel", name = "Lush Garden Pack" },           -- Lush Garden Fungal Chair
    [258888] = { method = "hearthsteel", name = "Lush Garden Pack" },           -- Lush Garden Fungal Fountain

    ---------------------------------------------------------------------------
    -- Starter Pack (Hearthsteel)
    ---------------------------------------------------------------------------
    [260727] = { method = "hearthsteel", name = "Starter Pack" },               -- Alliance Doormat
    [260728] = { method = "hearthsteel", name = "Starter Pack" },               -- Horde Doormat

    ---------------------------------------------------------------------------
    -- Promotional
    ---------------------------------------------------------------------------
    [264397] = { method = "promo", name = "Zillow for Warcraft" },              -- Simply Adorned Vase and Flowers
}
