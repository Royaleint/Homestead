-- luacheck: globals assert loadfile print _G

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-- HS-503: Rotha and Unquestionably Griftah are named vendors at Razorwind
-- Shores, shown all year. Rotha sells five room plans at 50 Community Coupons
-- that "Fen" Rucket in Founder's Point also sells; Unquestionably Griftah
-- sells three items at 10 Community Coupons. Both stay on the map while no
-- endeavor is active. Loads the REAL
-- Data/VendorIdentity.lua, Data/VendorOffers.lua, Data/VendorData.lua,
-- Data/EndeavorsData.lua and Data/EventSources.lua.

local HA = {
    Addon = {
        db = {
            profile = { debug = false },
            global = { discoveredInitiativeThemes = {} },
        },
        Debug = function() end,
        RegisterModule = function() end,
    },
    Events = { Fire = function() end },
}

_G.C_NeighborhoodInitiative = {
    GetNeighborhoodInitiativeInfo = function() return nil end,
}

assert(loadfile(root .. "/Data/VendorIdentity.lua"))("Homestead", HA)
assert(loadfile(root .. "/Data/VendorOffers.lua"))("Homestead", HA)
assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)
assert(loadfile(root .. "/Data/EndeavorsData.lua"))("Homestead", HA)
assert(loadfile(root .. "/Data/EventSources.lua"))("Homestead", HA)

local COUPONS = 3363
local ROTHA, GRIFTAH, FEN = 254687, 267870, 257297

-- Expected rows, as seen at the vendors on 2026-10-13. Unquestionably Griftah
-- has no subzone.
local VENDORS = {
    {
        npc = ROTHA, name = "Rotha", x = 0.5353, y = 0.566, subzone = "The Common",
        amount = 50, count = 5,
        items = {
            [274661] = "Silvermoon Display Room Plans",
            [274673] = "Orgrimmar Council Room Plans",
            [274674] = "Orgrimmar Theater Plans",
            [274675] = "Orgrimmar Stone Pit Room Plans",
            [274676] = "Orgrimmar Display Room Plans",
        },
    },
    {
        npc = GRIFTAH, name = "Unquestionably Griftah", x = 0.402, y = 0.7292,
        amount = 10, count = 3,
        items = {
            [244344] = "Griftah's Mystical Polter-Urn",
            [263875] = "Griftah's Resizing Hex-Skull",
            [276312] = "Griftah's Torch of Rotation",
        },
    },
}

for _, v in ipairs(VENDORS) do
    -- 1. The vendor row: named, at the scanned spot, not held back from the
    --    map, and with no faction field.
    local row = HA.VendorIdentity:GetVendor(v.npc)
    assert(row, "NPC " .. v.npc .. " must have a vendor row")
    assert(row.name == v.name,
        "NPC " .. v.npc .. " must be named " .. v.name .. ", got " .. tostring(row.name))
    assert(row.unreleased == nil and row.removed == nil,
        v.name .. " must not be marked unreleased or removed")
    assert(row.mapID == 2351 and row.zone == "Razorwind Shores",
        v.name .. " must be placed in Razorwind Shores (map 2351)")
    assert(row.x == v.x and row.y == v.y, v.name .. " must be at " .. v.x .. ", " .. v.y)
    assert(row.subzone == v.subzone,
        v.name .. "'s subzone must be " .. tostring(v.subzone) .. ", got " .. tostring(row.subzone))
    assert(row.faction == nil, v.name .. " must carry no faction field")
    assert(row.expansion == "Midnight", v.name .. " must be listed under Midnight")

    -- 2. Shown all year: not an endeavor vendor and not a holiday vendor.
    assert(HA.EndeavorsData.Vendors[v.npc] == nil, v.name .. " must not be an endeavor vendor")
    assert(HA.EventSources.EventVendors[v.npc] == nil, v.name .. " must not be a holiday vendor")
    assert(HA.EndeavorsData:GetThemeForVendor(v.npc) == nil, v.name .. " must not belong to an endeavor theme")

    -- 3. The items as the addon resolves them: exactly these, each priced in
    --    Community Coupons only, none with a holiday source.
    local offers = HA.VendorData:GetOffers(v.npc)
    assert(offers, v.name .. " must have offers")
    local count = 0
    for itemID in pairs(offers) do
        count = count + 1
        assert(v.items[itemID], v.name .. " lists unexpected item " .. tostring(itemID))
    end
    for itemID, itemName in pairs(v.items) do
        local offer = offers[itemID]
        assert(offer, v.name .. " must sell item " .. itemID .. " (" .. itemName .. ")")
        assert(offer.price == 0 and #(offer.currencies or {}) == 1
                and offer.itemCosts == nil and offer.namedCosts == nil,
            v.name .. "'s item " .. itemID .. " must be priced in one currency only")
        local currency = offer.currencies[1]
        assert(currency.id == COUPONS and currency.amount == v.amount,
            v.name .. "'s item " .. itemID .. " must cost " .. v.amount .. " Community Coupons, got "
            .. tostring(currency.amount) .. " of currency " .. tostring(currency.id))
        assert(HA.EventSources[itemID] == nil, "item " .. itemID .. " must have no holiday source")
    end
    assert(count == v.count, v.name .. " must list " .. v.count .. " items, got " .. count)
end

-- 4. Item to vendor: each room plan resolves to "Fen" Rucket and Rotha, and
--    each of Unquestionably Griftah's items to him alone.
HA.VendorData:BuildOfferIndexes()
local function SellersOf(itemID)
    local list = HA.VendorData:GetVendorsForItem(itemID)
    local set = {}
    for _, vendor in ipairs(list) do set[vendor.npcID] = true end
    return set, #list
end
for itemID in pairs(VENDORS[1].items) do
    local set, n = SellersOf(itemID)
    assert(set[FEN] and set[ROTHA] and n == 2,
        "item " .. itemID .. ' must resolve to "Fen" Rucket and Rotha only, got ' .. n .. " vendor(s)")
end
for itemID in pairs(VENDORS[2].items) do
    local set, n = SellersOf(itemID)
    assert(set[GRIFTAH] and n == 1,
        "item " .. itemID .. " must resolve to Unquestionably Griftah only, got " .. n .. " vendor(s)")
end

-- 5. Unchanged: "Fen" Rucket keeps his seven plans, and the Amani endeavor's
--    Griftah stays a separate endeavor vendor.
local fenCount = 0
for _ in pairs(HA.VendorData:GetOffers(FEN) or {}) do fenCount = fenCount + 1 end
assert(fenCount == 7, '"Fen" Rucket must keep 7 items, got ' .. fenCount)
local ED = HA.EndeavorsData
assert(ED.Vendors[260485] and ED.Vendors[260485].name == "Griftah",
    "the Amani endeavor's Griftah (260485) must stay in EndeavorsData")
assert(ED.Endeavors["Amani"].vendorNPC == 260485, "Griftah (260485) must stay the Amani vendor")

-- 6. The real pin path, in a known "no endeavor active" state: both stay
--    listed and shown on the Razorwind Shores map. The Amani Griftah line is a
--    control, since an unknown state shows every endeavor vendor.
_G.C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo = function()
    return { isLoaded = true, initiativeID = 0, title = "", progressRequired = 0 }
end
ED:RefreshCache()
assert(ED:IsVendorActive(260485) == false,
    "control: the Amani endeavor's Griftah (260485) must be hidden while no endeavor is active")
for _, v in ipairs(VENDORS) do
    local found
    for _, vendor in ipairs(HA.VendorData:GetVendorsInMap(2351)) do
        if vendor.npcID == v.npc then found = vendor end
    end
    assert(found, v.name .. " must be listed on the Razorwind Shores map")
    assert(ED:IsVendorActive(found), v.name .. " must stay shown while no endeavor is active")
end

print("hs503_rotha_griftah: ok")
