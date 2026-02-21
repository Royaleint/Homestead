--[[
    Homestead - Endeavors Data
    Neighborhood Initiative (Endeavor) vendors

    These vendors rotate monthly and appear inside player neighborhoods.
    Each endeavor has a unique theme and vendor who sells decor items
    purchasable with Community Coupons (currency 3363).

    Separate from VendorDatabase because:
    - Monthly rotation (not always available)
    - Neighborhood-specific spawning (no fixed world map location)
    - 4-tier milestone progression gates item availability
    - Dedicated API: C_NeighborhoodInitiative

    6 vendors, 73 items total.
]]

local _, HA = ...

local EndeavorsData = {}
HA.EndeavorsData = EndeavorsData

-------------------------------------------------------------------------------
-- Endeavor Theme Metadata (for future C_NeighborhoodInitiative integration)
-------------------------------------------------------------------------------

EndeavorsData.Endeavors = {
    ["Night Elf"]  = { vendorNPC = 249684 },
    ["Gilnean"]    = { vendorNPC = 256202 },
    ["Orc"]        = { vendorNPC = 250820 },
    ["Mechagnome"] = { vendorNPC = 248525 },
    ["Arakkoa"]    = { vendorNPC = 252605 },
    ["Tuskarr"]    = { vendorNPC = 257897 },
}

-------------------------------------------------------------------------------
-- NPC ID Aliases
-------------------------------------------------------------------------------

EndeavorsData.Aliases = {
    [150359] = 248525,  -- Pascal-K1N6 variant
    [150497] = 248525,  -- Pascal-K1N6 variant
    [252917] = 256202,  -- Hesta Forlath variant
}

-------------------------------------------------------------------------------
-- Vendor Entries (same schema as VendorDatabase.Vendors)
-------------------------------------------------------------------------------

EndeavorsData.Vendors = {
    -- Tuskarr theme
    [257897] = {
        name = "Harlowe Marl",
        mapID = 2352,
        x = 0.5304, y = 0.3805,
        zone = "Founder's Point",
        faction = "Neutral",
        currency = "Community Coupons",
        expansion = "The War Within",
        endeavor = true,
        notes = "Neighborhood Endeavor vendor (Tuskarr theme). Also appears at Razorwind Shores at 54.3, 56.1",
        items = {264915, 264916, 264917, 264918, 264919, 264920, 264921, 264922, 264923, 264924, 264925, 265032, 265541},
    },

    -- Mechagnome theme
    [248525] = {
        name = "Pascal-K1N6",
        mapID = 2351,
        x = 0.179, y = 0.175,
        zone = "Razorwind Shores",
        faction = "Neutral",
        currency = "Community Coupons",
        expansion = "The War Within",
        endeavor = true,
        notes = "Neighborhood Endeavor vendor (Mechagnome theme)",
        items = {
            {254400, cost = {currencies = {{id = 3363, amount = 2}}}},
            {254401, cost = {currencies = {{id = 3363, amount = 5}}}},
            {254402, cost = {currencies = {{id = 3363, amount = 5}}}},
            {254403, cost = {currencies = {{id = 3363, amount = 10}}}},
            {254404, cost = {currencies = {{id = 3363, amount = 2}}}},
            {254405, cost = {currencies = {{id = 3363, amount = 2}}}},
            {254406, cost = {currencies = {{id = 3363, amount = 2}}}},
            {254407, cost = {currencies = {{id = 3363, amount = 2}}}},
            {254408, cost = {currencies = {{id = 3363, amount = 2}}}},
            {254409, cost = {currencies = {{id = 3363, amount = 2}}}},
            {254410, cost = {currencies = {{id = 3363, amount = 5}}}},
            {254411, cost = {currencies = {{id = 3363, amount = 10}}}},
            {254412, cost = {currencies = {{id = 3363, amount = 2}}}},
            {254413, cost = {currencies = {{id = 3363, amount = 2}}}},
            {254415, cost = {currencies = {{id = 3363, amount = 20}}}},
            {254416, cost = {currencies = {{id = 3363, amount = 15}}}},
            {254766, cost = {currencies = {{id = 3363, amount = 10}}}},
        },
    },

    -- Night Elf theme
    [249684] = {
        name = "Brother Dovetail",
        mapID = 2351,
        x = 0.5436, y = 0.5612,
        zone = "Razorwind Shores",
        faction = "Neutral",
        currency = "Community Coupons",
        expansion = "The War Within",
        endeavor = true,
        notes = "Neighborhood Endeavor vendor (Night Elf theme)",
        items = {246686, 246741, 246838, 248402, 248403, 248405, 248406, 248407, 251472, 251473, 251474, 251475, 252039, 252040, 252041},
    },

    -- Orc theme
    [250820] = {
        name = "Hordranin",
        mapID = 2351,
        x = 0.542, y = 0.562,
        zone = "Razorwind Shores",
        faction = "Neutral",
        currency = "Community Coupons",
        expansion = "The War Within",
        endeavor = true,
        notes = "Neighborhood Endeavor vendor (Orc theme)",
        items = {
            {250627, cost = {currencies = {{id = 3363, amount = 5}}}},
            {250694, cost = {currencies = {{id = 3363, amount = 15}}}},
            {250695, cost = {currencies = {{id = 3363, amount = 10}}}},
            {250696, cost = {currencies = {{id = 3363, amount = 10}}}},
            {250697, cost = {currencies = {{id = 3363, amount = 10}}}},
            {250698, cost = {currencies = {{id = 3363, amount = 10}}}},
            {250699, cost = {currencies = {{id = 3363, amount = 10}}}},
            {250700, cost = {currencies = {{id = 3363, amount = 5}}}},
            {250701, cost = {currencies = {{id = 3363, amount = 20}}}},
            {250702, cost = {currencies = {{id = 3363, amount = 5}}}},
            {250703, cost = {currencies = {{id = 3363, amount = 10}}}},
            {250704, cost = {currencies = {{id = 3363, amount = 15}}}},
        },
    },

    -- Arakkoa theme
    [252605] = {
        name = "Aeeshna",
        mapID = 2351,
        x = 0.544, y = 0.562,
        zone = "Razorwind Shores",
        faction = "Neutral",
        currency = "Community Coupons",
        expansion = "The War Within",
        endeavor = true,
        notes = "Neighborhood Endeavor vendor (Arakkoa theme)",
        items = {262907, 263043, 263044, 263045, 263046, 263047, 263048},
    },

    -- Gilnean theme
    [256202] = {
        name = "Hesta Forlath",
        mapID = 110,
        x = 0.441, y = 0.628,
        zone = "Silvermoon City",
        subzone = "The Bazaar",
        faction = "Horde",
        currency = "Community Coupons",
        expansion = "Midnight",
        endeavor = true,
        unreleased = true,
        notes = "Neighborhood Endeavor vendor (Gilnean theme)",
        items = {253522, 253523, 253524, 253525, 253526, 253599, 253600, 253601, 254235},
    },
}

-------------------------------------------------------------------------------
-- Indexes (built at load time, same pattern as EventSources)
-------------------------------------------------------------------------------

EndeavorsData.ByMapID = {}
EndeavorsData.ByItemID = {}
EndeavorsData.VendorCount = 0

for npcID, vendor in pairs(EndeavorsData.Vendors) do
    vendor.npcID = npcID
    EndeavorsData.VendorCount = EndeavorsData.VendorCount + 1

    -- Index by mapID
    local mapID = vendor.mapID
    if mapID then
        if not EndeavorsData.ByMapID[mapID] then
            EndeavorsData.ByMapID[mapID] = {}
        end
        table.insert(EndeavorsData.ByMapID[mapID], vendor)
    end

    -- Index by itemID
    if vendor.items then
        for _, item in ipairs(vendor.items) do
            local itemID = type(item) == "table" and item[1] or item
            if itemID then
                if not EndeavorsData.ByItemID[itemID] then
                    EndeavorsData.ByItemID[itemID] = {}
                end
                table.insert(EndeavorsData.ByItemID[itemID], npcID)
            end
        end
    end
end
