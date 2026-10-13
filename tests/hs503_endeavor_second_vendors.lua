-- luacheck: globals assert loadfile print _G

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-- HS-503: a theme can have more than one vendor. Loads the REAL
-- Data/EndeavorsData.lua and checks that every vendor row is tied to a theme
-- and that a theme's extra vendor is active exactly when its main vendor is.

local payload = nil
local HA = {
    Addon = {
        db = {
            profile = { debug = false },
            global = { discoveredInitiativeThemes = {} },
        },
        Debug = function() end,
    },
    Events = { Fire = function() end },
}

_G.C_NeighborhoodInitiative = {
    GetNeighborhoodInitiativeInfo = function() return payload end,
}

assert(loadfile(root .. "/Data/EndeavorsData.lua"))("Homestead", HA)
local ED = HA.EndeavorsData

-- 1. Every vendor row is flagged as an endeavor vendor and resolves to a theme.
--    A row with no theme link is treated as always active (IsVendorActive
--    fails open), so it would show on the map all year.
local rowCount = 0
for npcID, vendor in pairs(ED.Vendors) do
    rowCount = rowCount + 1
    assert(vendor.endeavor == true,
        "vendor " .. npcID .. " is missing endeavor = true")
    assert(ED:GetThemeForVendor(npcID) ~= nil,
        "vendor " .. npcID .. " has no theme: list it as a theme's vendorNPC or in its extraVendorNPCs")
end

-- 2. Every NPC a theme names has a vendor row, and no NPC is named twice.
local linkCount = 0
local seen = {}
local function CheckLink(themeName, npcID)
    assert(ED.Vendors[npcID] ~= nil,
        themeName .. " names NPC " .. tostring(npcID) .. " but EndeavorsData.Vendors has no such row")
    assert(not seen[npcID], "NPC " .. tostring(npcID) .. " is named by more than one theme entry")
    seen[npcID] = true
    linkCount = linkCount + 1
end
for themeName, themeData in pairs(ED.Endeavors) do
    CheckLink(themeName, themeData.vendorNPC)
    for _, extraNPC in ipairs(themeData.extraVendorNPCs or {}) do
        CheckLink(themeName, extraNPC)
    end
end
assert(linkCount == rowCount,
    "theme entries name " .. linkCount .. " vendors but there are " .. rowCount .. " vendor rows")

-- 3. Each theme keeps its main vendor (the Housing Dashboard reads it), and
--    the extra vendor resolves to the same theme.
local PAIRS = {
    { theme = "Tortollan", main = 268106, extra = 257168 },
    { theme = "Grummle", main = 249684, extra = 263258 },
}
for _, p in ipairs(PAIRS) do
    assert(ED.Endeavors[p.theme].vendorNPC == p.main, p.theme .. " main vendor changed")
    assert(ED:GetThemeForVendor(p.extra) == p.theme,
        "NPC " .. p.extra .. " should resolve to " .. p.theme)
end

-- 4. In every theme state the extra vendor is active exactly when the main
--    vendor is. expected holds the value both must have, so the check cannot
--    pass by both being wrong the same way. The gate is asked both by NPC ID
--    and with the per-map entries the map layer hands out, the way shipped
--    callers call it.
local function EntryOnMap(mapID, npcID)
    for _, vendor in ipairs(ED.ByMapID[mapID] or {}) do
        if vendor.npcID == npcID then return vendor end
    end
end
local MAPS = { 2351, 2352 }

for _, p in ipairs(PAIRS) do
    for _, mapID in ipairs(MAPS) do
        local entry = EntryOnMap(mapID, p.extra)
        assert(entry, "NPC " .. p.extra .. " must be indexed on map " .. mapID)
        assert(entry.endeavor == true,
            "NPC " .. p.extra .. " entry on map " .. mapID .. " is missing endeavor = true")
    end
    assert(EntryOnMap(2351, p.main) or EntryOnMap(2352, p.main),
        "main vendor " .. p.main .. " of " .. p.theme .. " must be indexed on map 2351 or 2352")
end

local function Expect(label, expected)
    ED:RefreshCache()
    for _, p in ipairs(PAIRS) do
        local want = expected[p.theme]
        assert(ED:IsVendorActive(p.main) == want,
            label .. ": main vendor of " .. p.theme .. " expected " .. tostring(want))
        assert(ED:IsVendorActive(p.extra) == want,
            label .. ": extra vendor of " .. p.theme .. " expected " .. tostring(want))
        for _, mapID in ipairs(MAPS) do
            local extraEntry = EntryOnMap(mapID, p.extra)
            assert(ED:IsVendorActive(extraEntry) == want,
                label .. ": extra vendor entry of " .. p.theme .. " on map " .. mapID .. " expected " .. tostring(want))
            local mainEntry = EntryOnMap(mapID, p.main)
            if mainEntry then
                assert(ED:IsVendorActive(mainEntry) == want,
                    label .. ": main vendor entry of " .. p.theme .. " on map " .. mapID .. " expected " .. tostring(want))
            end
        end
    end
end

-- Unknown (payload not loaded). Must run first, on the untouched module.
payload = { isLoaded = false }
Expect("unknown", { Tortollan = true, Grummle = true })

-- Another theme is active.
payload = { isLoaded = true, initiativeID = 15, title = "Artistic Aid", progressRequired = 500 }
Expect("other theme", { Tortollan = false, Grummle = false })

-- Grummle is active.
payload = { isLoaded = true, initiativeID = 9101, title = "Friend of the Grummles", progressRequired = 500 }
Expect("Grummle active", { Tortollan = false, Grummle = true })

-- Tortollan is active.
payload = { isLoaded = true, initiativeID = 9102, title = "Tortollan Test Title", progressRequired = 500 }
Expect("Tortollan active", { Tortollan = true, Grummle = false })

-- Known: no endeavor active.
payload = { isLoaded = true, initiativeID = 0, title = "", progressRequired = 0 }
Expect("none active", { Tortollan = false, Grummle = false })

-- Loaded but unrecognised: unknown again.
payload = { isLoaded = true, initiativeID = 9999, title = "Some Unrecognized Future Initiative", progressRequired = 500 }
Expect("unrecognised", { Tortollan = true, Grummle = true })

-- 5. Both new vendors are indexed in both neighborhoods and their items carry
--    the base price in Community Coupons (currency 3363).
local PRICES = {
    [257168] = { [247776] = 5, [279455] = 5, [279458] = 5 },
    [263258] = { [248404] = 10 },
}
for npcID, prices in pairs(PRICES) do
    local row = ED.Vendors[npcID]
    local razorwind = EntryOnMap(2351, npcID)
    local founders = EntryOnMap(2352, npcID)
    assert(razorwind and founders, "NPC " .. npcID .. " must be indexed on maps 2351 and 2352")
    assert(founders.x == row.altX and founders.y == row.altY,
        "NPC " .. npcID .. " Founder's Point entry must use altX/altY")
    for _, entry in ipairs({ razorwind, founders }) do
        assert(entry.x > 0 and entry.x < 1 and entry.y > 0 and entry.y < 1,
            "NPC " .. npcID .. " coordinates must be normalized 0-1")
    end
    local expectedCount = 0
    for _ in pairs(prices) do expectedCount = expectedCount + 1 end
    assert(#row.items == expectedCount, "NPC " .. npcID .. " must list " .. expectedCount .. " items")
    for _, item in ipairs(row.items) do
        local itemID = item[1]
        local want = prices[itemID]
        assert(want, "NPC " .. npcID .. " lists unexpected item " .. tostring(itemID))
        local currency = item.cost and item.cost.currencies and item.cost.currencies[1]
        assert(currency and currency.id == 3363 and currency.amount == want,
            "item " .. itemID .. " must cost " .. want .. " of currency 3363")
        local indexed = false
        for _, sellerID in ipairs(ED.ByItemID[itemID] or {}) do
            if sellerID == npcID then indexed = true end
        end
        assert(indexed, "item " .. itemID .. " must be indexed to NPC " .. npcID)
    end
end

print("hs503_endeavor_second_vendors: ok")
