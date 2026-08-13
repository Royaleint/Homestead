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

    10 vendors, 140 items total. The four Midnight 12.1 theme vendors were
    promoted visible for the 12.1 release (HS-310, 2026-08-11).
]]

local _, HA = ...

local EndeavorsData = {}
HA.EndeavorsData = EndeavorsData

-- Runtime state
local activeTheme = nil
local activeThemeKnown = false
local eventFrame = nil
local loggedRawTitle = false

-- Cached initiative data (populated by RefreshActiveTheme)
local cachedInitiativeInfo = nil   -- processed fields from last successful API response
local cachedMilestones = nil       -- milestone array from API payload
local cachedTasks = nil            -- task array from API payload

-- NPC field names to probe on initiative info objects (hoisted to avoid per-call allocation)
local DIRECT_NPC_FIELDS = {"vendorNPCID", "vendorNpcID", "vendorID", "npcID"}

-- Vendor name lookup for theme resolution third pass (built after Vendors table)
local lowerVendorNameToNpcID = {}

local function IsDebugEnabled()
    return HA.Addon and HA.Addon.db and HA.Addon.db.profile and HA.Addon.db.profile.debug
end

-- Cultural keyword → theme resolution (fallback for description/title parsing).
-- Keys are lowercase; matched against lowered text via substring search.
-- Only include keywords that wouldn't substring-match an Endeavors key name
-- (those are handled by the first pass in ResolveThemeFromText).
local culturalKeywordToTheme = {
    ["kafa"] = "Grummle",
    ["luckydo"] = "Grummle",
    ["sin'dorei"] = "Blood Elf",
    ["silvermoon"] = "Blood Elf",
    ["thalassian"] = "Blood Elf",
    ["draconic"] = "Dracthyr",
    ["reaching beyond"] = "Dracthyr",
    ["mechagon"] = "Mechagnome",
    ["mechanization"] = "Mechagnome",
    ["mechanizaton"] = "Mechagnome",   -- intentional typo catch
    ["ethereal"] = "K'areshi",
    ["consortium"] = "K'areshi",
    ["loamm"] = "Niffen",
    ["smell sensation"] = "Niffen",
    ["olfactory"] = "Niffen",
    ["you take candle"] = "Kobold",
    -- Future themes (planned; not yet confirmed to exist)
    ["sporeggar"] = "Sporeggar",
    ["deeperholm"] = "Earthen",
    ["therazane"] = "Earthen",
    ["holm sweet holm"] = "Earthen",
}

-- Initiative title → theme (exact match, most reliable after hardcoded IDs).
-- HIGH confidence: matches from this table are persisted to SavedVariables.
local initiativeTitleToTheme = {
    ["Artistic Aid"] = "Blood Elf",
    ["Moderate Mechanization"] = "Mechagnome",
    ["Friend of the Grummles"] = "Grummle",
    ["Reaching Beyond the Possible"] = "Dracthyr",
    ["Consortium Consternation"] = "K'areshi",
    ["Smell Sensation"] = "Niffen",
    ["You Take Candle"] = "Kobold",
    -- Future planned titles (Amani/Maruuk/Tortollan quest titles not yet observed;
    -- ResolveThemeFromText falls back to matching the Endeavors key names directly)
    ["With Regards to Sporeggar"] = "Sporeggar",
    ["Deeperholm"] = "Earthen",
    ["Holm Sweet Holm"] = "Earthen",
}

-- Stable initiative IDs observed in-game.
-- Extend as additional themes are observed.
local initiativeIDToTheme = {
    [15] = "Blood Elf",
    [17] = "Mechagnome",
}

-------------------------------------------------------------------------------
-- Endeavor Theme Metadata (for future C_NeighborhoodInitiative integration)
-------------------------------------------------------------------------------

EndeavorsData.Endeavors = {
    ["Grummle"]    = { vendorNPC = 249684 },
    ["Blood Elf"]  = { vendorNPC = 256202 },
    ["Dracthyr"]   = { vendorNPC = 250820 },
    ["Mechagnome"] = { vendorNPC = 248525 },
    ["K'areshi"]   = { vendorNPC = 252605 },
    ["Niffen"]     = { vendorNPC = 257897 },
    -- Midnight 12.1 themes (promoted visible for the 12.1 release, HS-310)
    ["Amani"]      = { vendorNPC = 260485 },
    ["Maruuk"]     = { vendorNPC = 265551 },
    ["Tortollan"]  = { vendorNPC = 268106 },
    ["Kobold"]     = { vendorNPC = 271173 },
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
    -- Niffen theme
    [257897] = {
        name = "Harlowe Marl",
        mapID = 2352,
        x = 0.5304, y = 0.3805,
        zone = "Founder's Point",
        altMapID = 2351,
        altX = 0.5431, altY = 0.5610,
        altZone = "Razorwind Shores",
        faction = "Neutral",
        currency = "Community Coupons",
        expansion = "The War Within",
        endeavor = true,
        scanConfirmed = "2026-04-10",
        items = {
            {264915, cost = {currencies = {{id = 3363, amount = 15}}}},
            {264916, cost = {currencies = {{id = 3363, amount = 20}}}},
            {264917, cost = {currencies = {{id = 3363, amount = 5}}}},
            {264918, cost = {currencies = {{id = 3363, amount = 2}}}},
            {264919, cost = {currencies = {{id = 3363, amount = 20}}}},
            {264920, cost = {currencies = {{id = 3363, amount = 5}}}},
            {264921, cost = {currencies = {{id = 3363, amount = 20}}}},
            {264922, cost = {currencies = {{id = 3363, amount = 2}}}},
            {264923, cost = {currencies = {{id = 3363, amount = 15}}}},
            {264924, cost = {currencies = {{id = 3363, amount = 10}}}},
            {264925, cost = {currencies = {{id = 3363, amount = 5}}}},
            {265032, cost = {currencies = {{id = 3363, amount = 5}}}},
            {265541, cost = {currencies = {{id = 3363, amount = 1}}}},
        },
    },

    -- Mechagnome theme
    [248525] = {
        name = "Pascal-K1N6",
        mapID = 2351,
        x = 0.543, y = 0.561,
        zone = "Razorwind Shores",
        altMapID = 2352,
        altX = 0.530, altY = 0.382,
        altZone = "Founder's Point",
        faction = "Neutral",
        currency = "Community Coupons",
        expansion = "The War Within",
        endeavor = true,
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

    -- Grummle theme
    [249684] = {
        name = "Brother Dovetail",
        mapID = 2351,
        x = 0.5436, y = 0.5612,
        zone = "Razorwind Shores",
        altMapID = 2352,
        altX = 0.5302, altY = 0.3809,
        altZone = "Founder's Point",
        faction = "Neutral",
        currency = "Community Coupons",
        expansion = "The War Within",
        endeavor = true,
        scanConfirmed = "2026-04-10",
        items = {
            {246686, cost = {currencies = {{id = 3363, amount = 10}}}},
            {246741, cost = {currencies = {{id = 3363, amount = 10}}}},
            {246838, cost = {currencies = {{id = 3363, amount = 10}}}},
            {248402, cost = {currencies = {{id = 3363, amount = 15}}}},
            {248403, cost = {currencies = {{id = 3363, amount = 10}}}},
            {248405, cost = {currencies = {{id = 3363, amount = 5}}}},
            {248406, cost = {currencies = {{id = 3363, amount = 10}}}},
            {248407, cost = {currencies = {{id = 3363, amount = 10}}}},
            {251472, cost = {currencies = {{id = 3363, amount = 10}}}},
            {251473, cost = {currencies = {{id = 3363, amount = 5}}}},
            {251474, cost = {currencies = {{id = 3363, amount = 5}}}},
            {251475, cost = {currencies = {{id = 3363, amount = 10}}}},
            {252039, cost = {currencies = {{id = 3363, amount = 5}}}},
            {252040, cost = {currencies = {{id = 3363, amount = 5}}}},
            {252041, cost = {currencies = {{id = 3363, amount = 15}}}},
        },
    },

    -- Dracthyr theme
    [250820] = {
        name = "Hordranin",
        mapID = 2351,
        x = 0.543, y = 0.561,
        zone = "Razorwind Shores",
        altMapID = 2352,
        altX = 0.530, altY = 0.382,
        altZone = "Founder's Point",
        faction = "Neutral",
        currency = "Community Coupons",
        expansion = "The War Within",
        endeavor = true,
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

    -- K'areshi theme
    [252605] = {
        name = "Aeeshna",
        mapID = 2351,
        x = 0.544, y = 0.562,
        zone = "Razorwind Shores",
        altMapID = 2352,
        altX = 0.5300, altY = 0.3990,
        altZone = "Founder's Point",
        faction = "Neutral",
        currency = "Community Coupons",
        expansion = "The War Within",
        endeavor = true,
        scanConfirmed = "2026-04-10",
        items = {
            {262664, cost = {currencies = {{id = 3363, amount = 5}}}},
            {262665, cost = {currencies = {{id = 3363, amount = 5}}}},
            {262666, cost = {currencies = {{id = 3363, amount = 2}}}},
            {262667, cost = {currencies = {{id = 3363, amount = 5}}}},
            {262884, cost = {currencies = {{id = 3363, amount = 10}}}},
            {262907, cost = {currencies = {{id = 3363, amount = 10}}}},
            {263043, cost = {currencies = {{id = 3363, amount = 10}}}},
            {263044, cost = {currencies = {{id = 3363, amount = 5}}}},
            {263045, cost = {currencies = {{id = 3363, amount = 20}}}},
            {263046, cost = {currencies = {{id = 3363, amount = 10}}}},
            {263047, cost = {currencies = {{id = 3363, amount = 5}}}},
            {263048, cost = {currencies = {{id = 3363, amount = 15}}}},
        },
    },

    -- Blood Elf theme
    -- Hesta Forlath also exists as [252916] in VendorDatabase.lua (static Gold vendor).
    -- This entry is her rotating Endeavor incarnation with different NPC ID, currency, and items.
    [256202] = {
        name = "Hesta Forlath",
        mapID = 2352,
        x = 0.5311, y = 0.3829,
        zone = "Founder's Point",
        subzone = "Town Center",
        faction = "Neutral",
        currency = "Community Coupons",
        expansion = "The War Within",
        endeavor = true,
        notes = "Neighborhood Endeavor vendor (Blood Elf theme)",
        items = {
            {253522, cost = {currencies = {{id = 3363, amount = 5}}}},
            {253523, cost = {currencies = {{id = 3363, amount = 5}}}},
            {253524, cost = {currencies = {{id = 3363, amount = 10}}}},
            {253525, cost = {currencies = {{id = 3363, amount = 10}}}},
            {253526, cost = {currencies = {{id = 3363, amount = 15}}}},
            {253599, cost = {currencies = {{id = 3363, amount = 15}}}},
            {253600, cost = {currencies = {{id = 3363, amount = 5}}}},
            {253601, cost = {currencies = {{id = 3363, amount = 5}}}},
            {254235, cost = {currencies = {{id = 3363, amount = 5}}}},
        },
    },

    -- =========================================================================
    -- Midnight 12.1 endeavor vendors. Promoted visible for the 12.1 release
    -- (HS-310, 2026-08-11): `unreleased = true` removed from all four per the
    -- validation this block already recorded -- costs verified against the
    -- release matrix (HS-311 patch-discovery, PTR build 12.1.0.69189)
    -- and, for Griftah, a real in-game PTR scan (2026-08-09, build
    -- 12.1.0.69189, scanConfidence: confirmed). Griftah has confirmed
    -- altMapID/altX/altY (real PTR scans placed him in both neighborhoods);
    -- the other 3 do not yet -- their alternate-neighborhood rotation has not
    -- been observed. First live sightings should confirm coords (Gate 2).
    -- =========================================================================

    -- Amani theme
    -- Real in-game PTR scans place him in BOTH neighborhoods depending on
    -- build/date -- normal alt-neighborhood rotation, not conflicting data:
    -- Founder's Point (2026-07-13 build 68914, 2026-08-02 build 68914) vs.
    -- Razorwind Shores (2026-08-09 build 69189, newest -- used as primary).
    [260485] = {
        name = "Griftah",
        mapID = 2351,
        x = 0.5421, y = 0.5596,
        zone = "Razorwind Shores",
        altMapID = 2352,
        altX = 0.5307, altY = 0.3806,
        altZone = "Founder's Point",
        faction = "Neutral",
        currency = "Community Coupons",
        expansion = "Midnight",
        endeavor = true,
        scanConfirmed = "2026-08-09",
        notes = "Neighborhood Endeavor vendor (Amani theme)",
        items = {
            {255649, cost = {currencies = {{id = 3363, amount = 15}}}},
            {263317, cost = {currencies = {{id = 3363, amount = 10}}}},
            {263708, cost = {currencies = {{id = 3363, amount = 15}}}},
            {274505, cost = {currencies = {{id = 3363, amount = 30}}}},
            {274518, cost = {currencies = {{id = 3363, amount = 20}}}},
            {274521, cost = {currencies = {{id = 3363, amount = 15}}}},
            {274523, cost = {currencies = {{id = 3363, amount = 15}}}},
            {274525, cost = {currencies = {{id = 3363, amount = 10}}}},
            {274527, cost = {currencies = {{id = 3363, amount = 2}}}},
            {274529, cost = {currencies = {{id = 3363, amount = 15}}}},
            {274531, cost = {currencies = {{id = 3363, amount = 10}}}},
            {274533, cost = {currencies = {{id = 3363, amount = 15}}}},
            {274535, cost = {currencies = {{id = 3363, amount = 30}}}},
            {274537, cost = {currencies = {{id = 3363, amount = 30}}}},
            {274539, cost = {currencies = {{id = 3363, amount = 30}}}},
            -- "Bag of Totally Legitimate Amani Goods": 1 Griftah's Token of
            -- Appreciation (Blizzard's own 12.1 endeavor post, 2026-08-10).
            -- Task-completion reward currency, distinct from Community
            -- Coupons -- no numeric currency ID published; do not model as
            -- currency 3363. Left bare pending confirmation.
            {269029},
        },
    },

    -- Maruuk (Ohn'ahran centaur) theme
    [265551] = {
        name = "Roshai Lightstep",
        mapID = 2351,
        x = 0.5420, y = 0.5597,
        zone = "Razorwind Shores",
        faction = "Neutral",
        currency = "Community Coupons",
        expansion = "Midnight",
        endeavor = true,
        notes = "Neighborhood Endeavor vendor (Maruuk/Ohn'ahran centaur theme)",
        items = {
            {276626, cost = {currencies = {{id = 3363, amount = 10}}}},
            {276650, cost = {currencies = {{id = 3363, amount = 10}}}},
            {276652, cost = {currencies = {{id = 3363, amount = 10}}}},
            {276654, cost = {currencies = {{id = 3363, amount = 5}}}},
            {276656, cost = {currencies = {{id = 3363, amount = 10}}}},
            {276658, cost = {currencies = {{id = 3363, amount = 10}}}},
            {276661, cost = {currencies = {{id = 3363, amount = 15}}}},
            {276663, cost = {currencies = {{id = 3363, amount = 10}}}},
            {276665, cost = {currencies = {{id = 3363, amount = 10}}}},
            {276667, cost = {currencies = {{id = 3363, amount = 10}}}},
            {276669, cost = {currencies = {{id = 3363, amount = 5}}}},
            {276671, cost = {currencies = {{id = 3363, amount = 5}}}},
            {276673, cost = {currencies = {{id = 3363, amount = 5}}}},
            {276675, cost = {currencies = {{id = 3363, amount = 5}}}},
            {276677, cost = {currencies = {{id = 3363, amount = 10}}}},
        },
    },

    -- Tortollan theme
    [268106] = {
        name = "Taifa",
        mapID = 2351,
        x = 0.5487, y = 0.5730,
        zone = "Razorwind Shores",
        faction = "Neutral",
        currency = "Community Coupons",
        expansion = "Midnight",
        endeavor = true,
        notes = "Neighborhood Endeavor vendor (Tortollan theme)",
        items = {
            {280215, cost = {currencies = {{id = 3363, amount = 20}}}},
            {280221, cost = {currencies = {{id = 3363, amount = 10}}}},
            {280223, cost = {currencies = {{id = 3363, amount = 25}}}},
            {280225, cost = {currencies = {{id = 3363, amount = 25}}}},
            {280227, cost = {currencies = {{id = 3363, amount = 25}}}},
            {280230, cost = {currencies = {{id = 3363, amount = 20}}}},
            {280232, cost = {currencies = {{id = 3363, amount = 15}}}},
            {280234, cost = {currencies = {{id = 3363, amount = 15}}}},
            {280236, cost = {currencies = {{id = 3363, amount = 30}}}},
            {280238, cost = {currencies = {{id = 3363, amount = 10}}}},
            {280240, cost = {currencies = {{id = 3363, amount = 20}}}},
            {280242, cost = {currencies = {{id = 3363, amount = 15}}}},
            {280244, cost = {currencies = {{id = 3363, amount = 5}}}},
            {280873, cost = {currencies = {{id = 3363, amount = 5}}}}, -- Protected Tortollan Scroll Case
            -- Beguiling Memories of the Sea: CSV-attributed (external_resolved,
            -- add_or_complete_vendor_offer), no published price -- left bare
            -- pending confirmation, same as Griftah's 269029.
            {280846},
        },
    },

    -- Kobold theme
    [271173] = {
        name = "Timicky",
        mapID = 2351,
        x = 0.5489, y = 0.5728,
        zone = "Razorwind Shores",
        faction = "Neutral",
        currency = "Community Coupons",
        expansion = "Midnight",
        endeavor = true,
        notes = "Neighborhood Endeavor vendor (Kobold theme)",
        items = {
            {280246, cost = {currencies = {{id = 3363, amount = 30}}}},
            {280249, cost = {currencies = {{id = 3363, amount = 10}}}},
            {280251, cost = {currencies = {{id = 3363, amount = 10}}}},
            {280253, cost = {currencies = {{id = 3363, amount = 20}}}},
            {280255, cost = {currencies = {{id = 3363, amount = 10}}}},
            {280257, cost = {currencies = {{id = 3363, amount = 15}}}},
            {280259, cost = {currencies = {{id = 3363, amount = 20}}}},
            {280261, cost = {currencies = {{id = 3363, amount = 25}}}},
            {280263, cost = {currencies = {{id = 3363, amount = 20}}}},
            {280265, cost = {currencies = {{id = 3363, amount = 25}}}},
            {280267, cost = {currencies = {{id = 3363, amount = 30}}}},
            {280269, cost = {currencies = {{id = 3363, amount = 10}}}},
            {280271, cost = {currencies = {{id = 3363, amount = 10}}}},
            {280273, cost = {currencies = {{id = 3363, amount = 10}}}},
            {280275, cost = {currencies = {{id = 3363, amount = 10}}}},
            {280513, cost = {currencies = {{id = 3363, amount = 20}}}}, -- Color-Curious Candle
        },
    },
}

-------------------------------------------------------------------------------
-- Indexes (built at load time, same pattern as EventSources)
-------------------------------------------------------------------------------

EndeavorsData.ByMapID = {}
EndeavorsData.ByItemID = {}
EndeavorsData.VendorCount = 0
EndeavorsData.NPCToTheme = {}

for themeName, themeData in pairs(EndeavorsData.Endeavors) do
    local vendorNPC = themeData and themeData.vendorNPC
    if vendorNPC then
        EndeavorsData.NPCToTheme[vendorNPC] = themeName
    end
end

for npcID, vendor in pairs(EndeavorsData.Vendors) do
    vendor.npcID = npcID
    EndeavorsData.VendorCount = EndeavorsData.VendorCount + 1

    -- Index by primary mapID
    local mapID = vendor.mapID
    if mapID then
        if not EndeavorsData.ByMapID[mapID] then
            EndeavorsData.ByMapID[mapID] = {}
        end
        table.insert(EndeavorsData.ByMapID[mapID], vendor)
    end

    -- Index by alt mapID (endeavor vendors rotate between neighborhoods)
    if vendor.altMapID then
        local altEntry = {}
        for k, v in pairs(vendor) do altEntry[k] = v end
        altEntry.mapID = vendor.altMapID
        altEntry.x = vendor.altX
        altEntry.y = vendor.altY
        altEntry.zone = vendor.altZone or vendor.zone
        if not EndeavorsData.ByMapID[vendor.altMapID] then
            EndeavorsData.ByMapID[vendor.altMapID] = {}
        end
        table.insert(EndeavorsData.ByMapID[vendor.altMapID], altEntry)
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

    -- Build vendor name lookup for ResolveThemeFromText third pass
    if vendor.name then
        lowerVendorNameToNpcID[vendor.name:lower()] = npcID
    end
end

-------------------------------------------------------------------------------
-- Active Theme Detection
-------------------------------------------------------------------------------

local function ResolveCanonicalNPCID(npcID)
    if type(npcID) ~= "number" then return nil end
    local canonical = EndeavorsData.Aliases and EndeavorsData.Aliases[npcID]
    return canonical or npcID
end

local function ResolveThemeFromText(text)
    if type(text) ~= "string" or text == "" then return nil end

    local loweredText = text:lower()
    local compactText = loweredText:gsub("[^%a%d]", "")

    -- First pass: exact/substring match against canonical theme names
    for themeName in pairs(EndeavorsData.Endeavors) do
        local loweredTheme = themeName:lower()
        if loweredText:find(loweredTheme, 1, true) then
            return themeName
        end

        local compactTheme = loweredTheme:gsub("[^%a%d]", "")
        if compactTheme ~= "" and compactText:find(compactTheme, 1, true) then
            return themeName
        end
    end

    -- Second pass: cultural keyword aliases
    for aliasToken, themeName in pairs(culturalKeywordToTheme) do
        if aliasToken:find(" ", 1, true) then
            if loweredText:find(aliasToken, 1, true) then
                return themeName
            end
        else
            if compactText:find(aliasToken, 1, true) then
                return themeName
            end
        end
    end

    -- Third pass: vendor name fallback (uses pre-computed lookup)
    for lowerName, npcID in pairs(lowerVendorNameToNpcID) do
        if loweredText:find(lowerName, 1, true) then
            return EndeavorsData.NPCToTheme[npcID]
        end
    end

    return nil
end

-------------------------------------------------------------------------------
-- Initiative ID Persistence (SavedVariables)
-------------------------------------------------------------------------------

local function PersistInitiativeMapping(initiativeID, themeName)
    if not HA.Addon or not HA.Addon.db then return end
    local stored = HA.Addon.db.global.discoveredInitiativeThemes
    if not stored then return end
    if stored[initiativeID] == themeName then return end  -- already correct
    stored[initiativeID] = themeName
end

local function LookupPersistedTheme(initiativeID)
    if not HA.Addon or not HA.Addon.db then return nil end
    local stored = HA.Addon.db.global.discoveredInitiativeThemes
    return stored and stored[initiativeID] or nil
end

-------------------------------------------------------------------------------
-- Initiative Info Resolution (6-step confidence chain)
-------------------------------------------------------------------------------

local function ResolveThemeFromInitiativeInfo(info)
    if type(info) ~= "table" then return nil, false, nil end
    if info.isLoaded ~= true then
        return nil, nil, info.title
    end

    local initiativeID = tonumber(info.initiativeID)

    -- Step 1: Hardcoded initiative ID (HIGH confidence)
    if initiativeID and initiativeIDToTheme[initiativeID] then
        return initiativeIDToTheme[initiativeID], true, info.title
    end

    -- Step 2: Persisted SavedVariables mapping (HIGH confidence)
    if initiativeID then
        local persisted = LookupPersistedTheme(initiativeID)
        if persisted then
            return persisted, true, info.title
        end
    end

    -- Step 3: Exact title match (HIGH confidence — persists)
    if type(info.title) == "string" and initiativeTitleToTheme[info.title] then
        local theme = initiativeTitleToTheme[info.title]
        if initiativeID then
            PersistInitiativeMapping(initiativeID, theme)
        end
        return theme, true, info.title
    end

    -- NPC field probing (locale-safe, HIGH confidence)
    for _, fieldName in ipairs(DIRECT_NPC_FIELDS) do
        local npcID = tonumber(info[fieldName])
        if npcID then
            local themeName = EndeavorsData.NPCToTheme[ResolveCanonicalNPCID(npcID)]
            if themeName then
                return themeName, true, info.title
            end
        end
    end

    if type(info.vendor) == "table" then
        for _, fieldName in ipairs(DIRECT_NPC_FIELDS) do
            local npcID = tonumber(info.vendor[fieldName])
            if npcID then
                local themeName = EndeavorsData.NPCToTheme[ResolveCanonicalNPCID(npcID)]
                if themeName then
                    return themeName, true, info.title
                end
            end
        end
    end

    -- Step 4: Cultural keyword scan of description (not persisted — session only)
    local themeFromDescription = ResolveThemeFromText(info.description)
    if themeFromDescription then
        return themeFromDescription, true, info.title
    end

    -- Step 5: Cultural keyword scan of title (not persisted — session only)
    local themeFromTitle = ResolveThemeFromText(info.title)
    if themeFromTitle then
        return themeFromTitle, true, info.title
    end

    -- Step 6: Vendor name fallback handled inside ResolveThemeFromText (not persisted)

    -- HS-313: a neighborhood with NO active endeavour returns a LOADED payload
    -- with initiativeID 0, empty title, and progressRequired 0 (live-probed
    -- 2026-08-11). That exact shape means "definitively none active" — a
    -- known state, not unknown. Anything else falls through to unknown below.
    if (tonumber(info.initiativeID) or 0) == 0
            and (info.title == nil or info.title == "")
            and (tonumber(info.progressRequired) or 0) == 0 then
        return nil, true, info.title
    end

    return nil, false, info.title
end

local requestingInitiative = false
local function RequestInitiativeInfo(reason)
    local neighborhoodAPI = _G.C_NeighborhoodInitiative
    if not neighborhoodAPI or not neighborhoodAPI.RequestNeighborhoodInitiativeInfo then
        return
    end
    if requestingInitiative then return end

    requestingInitiative = true
    local ok = pcall(neighborhoodAPI.RequestNeighborhoodInitiativeInfo)
    requestingInitiative = false
    if ok and IsDebugEnabled() then
        HA.Addon:Debug("EndeavorsData: requested initiative info", "(" .. tostring(reason) .. ")")
    end
end

local function UpdateCachedPayload(info)
    cachedInitiativeInfo = {
        initiativeID = info.initiativeID,
        title = info.title,
        description = info.description,
        currentProgress = info.currentProgress,
        progressRequired = info.progressRequired,
        duration = info.duration,
        currentCycleID = info.currentCycleID,
        playerTotalContribution = info.playerTotalContribution,
        neighborhoodGUID = info.neighborhoodGUID,
    }
    -- Shallow-copy arrays so we don't hold references into the API's returned table
    if info.milestones then
        cachedMilestones = {}
        for i, m in ipairs(info.milestones) do cachedMilestones[i] = m end
    else
        cachedMilestones = nil
    end
    if info.tasks then
        cachedTasks = {}
        for i, t in ipairs(info.tasks) do cachedTasks[i] = t end
    else
        cachedTasks = nil
    end
end

local function RefreshActiveTheme(reason)
    local neighborhoodAPI = _G.C_NeighborhoodInitiative
    if not neighborhoodAPI or not neighborhoodAPI.GetNeighborhoodInitiativeInfo then
        return
    end

    local ok, info = pcall(neighborhoodAPI.GetNeighborhoodInitiativeInfo)
    if not ok or not info then
        return
    end

    local newTheme, newKnown, rawTitle = ResolveThemeFromInitiativeInfo(info)
    if newKnown == nil then
        -- API responded but initiative payload is not loaded yet; keep prior state.
        return
    end
    local changed = (newTheme ~= activeTheme) or (newKnown ~= activeThemeKnown)

    activeTheme = newTheme
    activeThemeKnown = newKnown

    UpdateCachedPayload(info)

    if rawTitle and rawTitle ~= "" and not loggedRawTitle and IsDebugEnabled() then
        HA.Addon:Debug("EndeavorsData: Neighborhood initiative title:", rawTitle)
        loggedRawTitle = true
    end

    -- HS-216: log the "active theme" line only when the resolved theme
    -- actually CHANGED (same `changed` this function already computes to
    -- decide whether to fire ACTIVE_ENDEAVOR_CHANGED) — unsolicited
    -- NEIGHBORHOOD_INITIATIVE_UPDATED fires (every consume, no theme change)
    -- were logging this line every time.
    if changed and IsDebugEnabled() then
        if activeThemeKnown and activeTheme then
            HA.Addon:Debug("EndeavorsData: active theme:", activeTheme, "(" .. tostring(reason) .. ")")
        elseif activeThemeKnown then
            -- HS-313: known-but-none state (no endeavour active). activeTheme
            -- is nil here; passing it to Debug's varargs would leave a hole
            -- in the {...} array Print builds, so log it explicitly instead.
            HA.Addon:Debug("EndeavorsData: active theme: none", "(" .. tostring(reason) .. ")")
        else
            HA.Addon:Debug("EndeavorsData: active theme unknown", "(" .. tostring(reason) .. ")")
        end
    end

    if changed and HA.Events then
        HA.Events:Fire("ACTIVE_ENDEAVOR_CHANGED")
    end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function EndeavorsData:GetActiveTheme()
    if not activeThemeKnown then return nil end
    return activeTheme
end

-- Returns true/false when known, nil when unknown.
function EndeavorsData:IsThemeActive(themeName)
    if type(themeName) ~= "string" or themeName == "" then
        return nil
    end
    if not activeThemeKnown then
        return nil
    end
    return activeTheme == themeName
end

function EndeavorsData:GetThemeForVendor(vendorOrNPCID)
    local npcID = vendorOrNPCID
    if type(vendorOrNPCID) == "table" then
        npcID = vendorOrNPCID.npcID
    end
    npcID = tonumber(npcID)
    if not npcID then return nil end

    local canonicalNPC = ResolveCanonicalNPCID(npcID)
    return canonicalNPC and EndeavorsData.NPCToTheme[canonicalNPC] or nil
end

-- Fail-open while active theme is unknown.
function EndeavorsData:IsVendorActive(vendorOrNPCID)
    local themeName = self:GetThemeForVendor(vendorOrNPCID)
    if not themeName then
        return true
    end

    local isActive = self:IsThemeActive(themeName)
    if isActive == nil then
        return true
    end
    return isActive
end

-------------------------------------------------------------------------------
-- Initiative Data Helpers (cached from C_NeighborhoodInitiative API)
-------------------------------------------------------------------------------

function EndeavorsData:RefreshCache()
    RefreshActiveTheme("cache_refresh")
end

function EndeavorsData:GetCurrentInitiativeInfo()
    return cachedInitiativeInfo
end

function EndeavorsData:GetMilestoneProgress()
    if not cachedInitiativeInfo or not cachedMilestones then return nil end
    local current = cachedInitiativeInfo.currentProgress or 0
    local total = cachedInitiativeInfo.progressRequired or 0
    local nextMilestone = nil
    local prevMilestone = 0

    for _, m in ipairs(cachedMilestones) do
        if current < m.requiredContributionAmount then
            if not nextMilestone or m.requiredContributionAmount < nextMilestone.requiredContributionAmount then
                nextMilestone = m
            end
        else
            if m.requiredContributionAmount > prevMilestone then
                prevMilestone = m.requiredContributionAmount
            end
        end
    end

    return {
        currentProgress = current,
        progressRequired = total,
        previousMilestone = prevMilestone,
        nextMilestoneAmount = nextMilestone and nextMilestone.requiredContributionAmount or total,
        nextMilestoneIndex = nextMilestone and nextMilestone.milestoneOrderIndex and (nextMilestone.milestoneOrderIndex + 1) or nil,
        remaining = nextMilestone and (nextMilestone.requiredContributionAmount - current) or 0,
        allMilestonesComplete = (nextMilestone == nil),
        milestoneCount = cachedMilestones and #cachedMilestones or 0,
    }
end

function EndeavorsData:GetTasks()
    return cachedTasks
end

function EndeavorsData:GetPlayerContribution()
    return cachedInitiativeInfo and cachedInitiativeInfo.playerTotalContribution or 0
end

function EndeavorsData:GetTimeRemaining()
    return cachedInitiativeInfo and cachedInitiativeInfo.duration or 0
end

local function CallInitiativeAPI(methodName)
    local api = _G.C_NeighborhoodInitiative
    if not api or not api[methodName] then return false end
    local ok, result = pcall(api[methodName])
    return ok and result == true
end

function EndeavorsData:IsEnabled()
    return CallInitiativeAPI("IsInitiativeEnabled")
end

function EndeavorsData:HasAccess()
    return CallInitiativeAPI("PlayerHasInitiativeAccess")
end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

function EndeavorsData:Initialize()
    if eventFrame then return end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("NEIGHBORHOOD_INITIATIVE_UPDATED")
    eventFrame:SetScript("OnEvent", function(_, event)
        -- HS-215: NEIGHBORHOOD_INITIATIVE_UPDATED is the RESPONSE to
        -- RequestNeighborhoodInitiativeInfo — calling RequestInitiativeInfo
        -- again here was requesting a new response inside the handler for
        -- the previous one, an infinite server-paced request loop (confirmed
        -- live). This event only needs to CONSUME the data that just
        -- arrived; it never requests.
        if event == "NEIGHBORHOOD_INITIATIVE_UPDATED" then
            RefreshActiveTheme(event)
            return
        end

        RequestInitiativeInfo(event)
        RefreshActiveTheme(event)

        -- Neighborhood API payload can lag behind PLAYER_ENTERING_WORLD.
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(0.5, function()
                RequestInitiativeInfo("PLAYER_ENTERING_WORLD_RETRY_0_5")
                RefreshActiveTheme("PLAYER_ENTERING_WORLD_RETRY_0_5")
            end)
            C_Timer.After(2, function()
                RequestInitiativeInfo("PLAYER_ENTERING_WORLD_DELAYED")
                RefreshActiveTheme("PLAYER_ENTERING_WORLD_DELAYED")
            end)
        end
    end)

    RequestInitiativeInfo("Initialize")
    RefreshActiveTheme("Initialize")

    if HA.Addon then
        HA.Addon:Debug("EndeavorsData initialized")
    end
end
