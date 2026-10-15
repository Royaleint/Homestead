-- luacheck: globals assert loadfile print _G

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-- HS-503: Jolli Maxiboom is a named, visible vendor at Razorwind Shores with
-- 14 priced items, and Timicky has a Founder's Point position that is shown
-- and hidden with the Kobold endeavor exactly as the Razorwind Shores one is.
-- Loads the REAL Data/VendorIdentity.lua, Data/VendorOffers.lua,
-- Data/VendorData.lua and Data/EndeavorsData.lua.
-- Also: Holly Twinklebright at Founder's Point with 14 priced items (the same set and prices as Jolli), and the Founder's Point positions of Taifa and Roshai Lightstep.
-- Also: the 12 Hallow's End items Jolli and Holly sell have no Data/EventSources.lua row, so no "Not Active" source line; the other 11 rows stay.

local payload = nil
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
    GetNeighborhoodInitiativeInfo = function() return payload end,
}

assert(loadfile(root .. "/Data/VendorIdentity.lua"))("Homestead", HA)
assert(loadfile(root .. "/Data/VendorOffers.lua"))("Homestead", HA)
assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)
assert(loadfile(root .. "/Data/EndeavorsData.lua"))("Homestead", HA)

-- 1. Jolli Maxiboom's vendor row: named, placed, and not held back from the map.
local JOLLI = 271366
local jolli = HA.VendorIdentity:GetVendor(JOLLI)
assert(jolli, "NPC " .. JOLLI .. " must have a vendor row")
assert(jolli.name == "Jolli Maxiboom",
    "NPC " .. JOLLI .. " must be named Jolli Maxiboom, got " .. tostring(jolli.name))
assert(jolli.unreleased == nil and jolli.removed == nil,
    "Jolli Maxiboom must not be marked unreleased or removed")
assert(jolli.mapID == 2351 and jolli.zone == "Razorwind Shores",
    "Jolli Maxiboom must be placed in Razorwind Shores (map 2351)")
assert(jolli.x == 0.5237 and jolli.y == 0.543,
    "Jolli Maxiboom must be at 0.5237, 0.5430")
assert(jolli.faction == nil, "Jolli Maxiboom must carry no faction field")

-- 2. Her 14 items, as the addon resolves them, each at its gold price (in
--    copper) and with no other cost. No item may be missing or added.
local PRICES = {
    [248101] = 1000000, -- Traditional Brewfest Stein
    [280335] = 1000000, -- Brewfest Crate
    [282051] = 1000000, -- Simple Hallow's End Candle
    [282072] = 1000000, -- Enchanted Hallow's End Candle
    [282075] = 1000000, -- Heartsbane Candle
    [282077] = 5000000, -- Spooky Scarecrow
    [282081] = 5000000, -- Candlelit Smiling Jack-o'-Lantern
    [282083] = 5000000, -- Unlit Smiling Jack-o'-Lantern
    [282086] = 2500000, -- Buckled Witch Hat
    [282090] = 1000000, -- Eternally Powered Glowskull
    [282092] = 5000000, -- Heartsbane Ritual Markings
    [282095] = 5000000, -- Ominous Heartsbane Banner
    [282098] = 1000000, -- Elaborate Heartsbane Doom Catcher
    [282100] = 1000000, -- Heartsbane Doom Catcher
}
local offers = HA.VendorData:GetOffers(JOLLI)
assert(offers, "Jolli Maxiboom must have offers")
local offerCount = 0
for itemID in pairs(offers) do
    offerCount = offerCount + 1
    assert(PRICES[itemID], "Jolli Maxiboom lists unexpected item " .. tostring(itemID))
end
for itemID, price in pairs(PRICES) do
    local offer = offers[itemID]
    assert(offer, "Jolli Maxiboom must sell item " .. itemID)
    assert(offer.price == price,
        "item " .. itemID .. " must cost " .. price .. " copper, got " .. tostring(offer.price))
    assert(#(offer.currencies or {}) == 0 and offer.itemCosts == nil and offer.namedCosts == nil,
        "item " .. itemID .. " must be priced in gold only")
end
assert(offerCount == 14, "Jolli Maxiboom must list 14 items, got " .. offerCount)

-- 3. Timicky is indexed in both neighborhoods. The Founder's Point entry sits
--    at its own position and is an endeavor entry of the Kobold theme.
local ED = HA.EndeavorsData
local TIMICKY = 271173
local function EntryOnMap(mapID, npcID)
    for _, vendor in ipairs(ED.ByMapID[mapID] or {}) do
        if vendor.npcID == npcID then return vendor end
    end
end
local razorwind = EntryOnMap(2351, TIMICKY)
local founders = EntryOnMap(2352, TIMICKY)
assert(razorwind, "Timicky must be indexed on map 2351 (Razorwind Shores)")
assert(founders, "Timicky must be indexed on map 2352 (Founder's Point)")
assert(razorwind.x == 0.5489 and razorwind.y == 0.5728,
    "Timicky's Razorwind Shores position must stay 0.5489, 0.5728")
assert(founders.x == 0.5313 and founders.y == 0.3827,
    "Timicky's Founder's Point position must be 0.5313, 0.3827")
assert(founders.zone == "Founder's Point", "Timicky's Founder's Point entry must name its zone")
assert(razorwind.endeavor == true and founders.endeavor == true,
    "both Timicky entries must be endeavor entries")
assert(ED.Endeavors["Kobold"].vendorNPC == TIMICKY, "Timicky must stay the Kobold vendor")
assert(ED:GetThemeForVendor(razorwind) == "Kobold" and ED:GetThemeForVendor(founders) == "Kobold",
    "both Timicky entries must resolve to the Kobold theme")

-- 4. In every theme state the Founder's Point entry is active exactly when
--    the Razorwind Shores entry is. want is the value both must have, so the
--    check cannot pass by both being wrong the same way.
local function Expect(label, want)
    ED:RefreshCache()
    assert(ED:IsVendorActive(TIMICKY) == want,
        label .. ": Timicky expected " .. tostring(want))
    assert(ED:IsVendorActive(razorwind) == want,
        label .. ": Timicky's Razorwind Shores entry expected " .. tostring(want))
    assert(ED:IsVendorActive(founders) == want,
        label .. ": Timicky's Founder's Point entry expected " .. tostring(want))
end

-- Unknown (payload not loaded). Must run first, on the untouched module.
payload = { isLoaded = false }
Expect("unknown", true)

-- Another theme is active.
payload = { isLoaded = true, initiativeID = 15, title = "Artistic Aid", progressRequired = 500 }
Expect("other theme", false)

-- Kobold is active.
payload = { isLoaded = true, initiativeID = 9103, title = "You Take Candle", progressRequired = 500 }
Expect("Kobold active", true)

-- Known: no endeavor active.
payload = { isLoaded = true, initiativeID = 0, title = "", progressRequired = 0 }
Expect("none active", false)

-- Loaded but unrecognised: unknown again.
payload = { isLoaded = true, initiativeID = 9999, title = "Some Unrecognized Future Initiative", progressRequired = 500 }
Expect("unrecognised", true)

-- 5. Holly Twinklebright: named, placed in Founder's Point, visible, and
--    selling exactly Jolli's fourteen items at their gold prices, the Brewfest
--    Stein and Crate among them.
local HOLLY = 271604
local holly = HA.VendorIdentity:GetVendor(HOLLY)
assert(holly, "NPC " .. HOLLY .. " must have a vendor row")
assert(holly.name == "Holly Twinklebright",
    "NPC " .. HOLLY .. " must be named Holly Twinklebright, got " .. tostring(holly.name))
assert(holly.unreleased == nil and holly.removed == nil,
    "Holly Twinklebright must not be marked unreleased or removed")
assert(holly.mapID == 2352 and holly.zone == "Founder's Point",
    "Holly Twinklebright must be placed in Founder's Point (map 2352)")
assert(holly.x == 0.5439 and holly.y == 0.3278,
    "Holly Twinklebright must be at 0.5439, 0.3278")
assert(holly.faction == nil, "Holly Twinklebright must carry no faction field")
local hollyOffers = HA.VendorData:GetOffers(HOLLY)
assert(hollyOffers, "Holly Twinklebright must have offers")
local hollyCount = 0
for itemID, offer in pairs(hollyOffers) do
    hollyCount = hollyCount + 1
    assert(PRICES[itemID],
        "Holly Twinklebright lists unexpected item " .. tostring(itemID))
    assert(offer.price == PRICES[itemID],
        "Holly Twinklebright's item " .. itemID .. " must cost " .. PRICES[itemID]
        .. " copper, got " .. tostring(offer.price))
    assert(#(offer.currencies or {}) == 0 and offer.itemCosts == nil and offer.namedCosts == nil,
        "Holly Twinklebright's item " .. itemID .. " must be priced in gold only")
end
for itemID in pairs(PRICES) do
    assert(hollyOffers[itemID], "Holly Twinklebright must sell item " .. itemID)
end
assert(hollyCount == 14, "Holly Twinklebright must list 14 items, got " .. hollyCount)

-- 6. Taifa and Roshai Lightstep each have a Founder's Point entry at its own
--    position that belongs to the same endeavor as the Razorwind Shores entry
--    and is active in exactly the same states.
local ALT = {
    { npc = 268106, name = "Taifa", theme = "Tortollan", x = 0.5315, y = 0.383 },
    { npc = 265551, name = "Roshai Lightstep", theme = "Maruuk", x = 0.5291, y = 0.3753 },
}
local STATES = {
    { label = "other theme", want = false,
      p = { isLoaded = true, initiativeID = 15, title = "Artistic Aid", progressRequired = 500 } },
    { label = "own theme", want = true, own = true },
    { label = "none active", want = false,
      p = { isLoaded = true, initiativeID = 0, title = "", progressRequired = 0 } },
    { label = "unrecognised", want = true,
      p = { isLoaded = true, initiativeID = 9999, title = "Some Unrecognized Future Initiative", progressRequired = 500 } },
}
for _, v in ipairs(ALT) do
    local rs = EntryOnMap(2351, v.npc)
    local fp = EntryOnMap(2352, v.npc)
    assert(rs, v.name .. " must be indexed on map 2351 (Razorwind Shores)")
    assert(fp, v.name .. " must be indexed on map 2352 (Founder's Point)")
    assert(fp.x == v.x and fp.y == v.y,
        v.name .. "'s Founder's Point position must be " .. v.x .. ", " .. v.y)
    assert(fp.zone == "Founder's Point", v.name .. "'s Founder's Point entry must name its zone")
    assert(rs.endeavor == true and fp.endeavor == true,
        "both " .. v.name .. " entries must be endeavor entries")
    assert(ED.Endeavors[v.theme].vendorNPC == v.npc, v.name .. " must stay the " .. v.theme .. " vendor")
    assert(ED:GetThemeForVendor(rs) == v.theme and ED:GetThemeForVendor(fp) == v.theme,
        "both " .. v.name .. " entries must resolve to the " .. v.theme .. " theme")
    for _, s in ipairs(STATES) do
        payload = s.own and { isLoaded = true, initiativeID = 9200, title = v.theme .. " Test Title", progressRequired = 500 } or s.p
        ED:RefreshCache()
        assert(not s.own or ED:GetActiveTheme() == v.theme,
            v.theme .. " must resolve as the active theme")
        assert(ED:IsVendorActive(rs) == s.want,
            s.label .. ": " .. v.name .. "'s Razorwind Shores entry expected " .. tostring(s.want))
        assert(ED:IsVendorActive(fp) == s.want,
            s.label .. ": " .. v.name .. "'s Founder's Point entry expected " .. tostring(s.want))
    end
end
assert(loadfile(root .. "/Data/EventSources.lua"))("Homestead", HA)
local REMOVED = { 282051, 282072, 282075, 282077, 282081, 282083, 282086, 282090, 282092, 282095, 282098, 282100 }
local KEPT = { 282192, 282194, 282196, 282198, 282200, 282202, 282204, 282206, 282208, 282213, 282289 }
for _, id in ipairs(REMOVED) do
    assert(HA.EventSources[id] == nil, "item " .. id .. " is sold by Jolli or Holly and must have no EventSources row")
end
for _, id in ipairs(KEPT) do
    local row = HA.EventSources[id]
    assert(row and row.event == "Hallow's End", "item " .. id .. " must keep its Hallow's End EventSources row")
end
print("hs503_jolli_timicky: ok")
