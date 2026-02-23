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

-- Runtime state
local activeTheme = nil
local activeThemeKnown = false
local eventFrame = nil
local loggedRawTitle = false

-- Normalized title aliases for non-exact title matching fallback
local titleAliasToTheme = {
    ["night elf"] = "Night Elf",
    ["nightelf"] = "Night Elf",
    ["gilnean"] = "Gilnean",
    ["gilneas"] = "Gilnean",
    ["orc"] = "Orc",
    ["mechagnome"] = "Mechagnome",
    ["arakkoa"] = "Arakkoa",
    ["tuskarr"] = "Tuskarr",
}

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

-------------------------------------------------------------------------------
-- Active Theme Detection
-------------------------------------------------------------------------------

local function ResolveCanonicalNPCID(npcID)
    if type(npcID) ~= "number" then return nil end
    local canonical = EndeavorsData.Aliases and EndeavorsData.Aliases[npcID]
    return canonical or npcID
end

local function ResolveThemeFromTitle(title)
    if type(title) ~= "string" or title == "" then return nil end

    local loweredTitle = title:lower()
    local compactTitle = loweredTitle:gsub("[^%a%d]", "")

    -- First pass: exact/substring match against canonical theme names
    for themeName in pairs(EndeavorsData.Endeavors) do
        local loweredTheme = themeName:lower()
        if loweredTitle:find(loweredTheme, 1, true) then
            return themeName
        end

        local compactTheme = loweredTheme:gsub("[^%a%d]", "")
        if compactTheme ~= "" and compactTitle:find(compactTheme, 1, true) then
            return themeName
        end
    end

    -- Second pass: known aliases
    for aliasToken, themeName in pairs(titleAliasToTheme) do
        if aliasToken:find(" ", 1, true) then
            if loweredTitle:find(aliasToken, 1, true) then
                return themeName
            end
        else
            if compactTitle:find(aliasToken, 1, true) then
                return themeName
            end
        end
    end

    -- Third pass: vendor name fallback
    for npcID, vendor in pairs(EndeavorsData.Vendors) do
        if vendor.name and loweredTitle:find(vendor.name:lower(), 1, true) then
            return EndeavorsData.NPCToTheme[npcID]
        end
    end

    return nil
end

local function ResolveThemeFromInitiativeInfo(info)
    if type(info) ~= "table" then return nil, false, nil end

    -- Prefer stable IDs if exposed by API payload.
    local directNPCFields = {
        "vendorNPCID",
        "vendorNpcID",
        "vendorID",
        "npcID",
    }

    for _, fieldName in ipairs(directNPCFields) do
        local npcID = tonumber(info[fieldName])
        if npcID then
            local themeName = EndeavorsData.NPCToTheme[ResolveCanonicalNPCID(npcID)]
            if themeName then
                return themeName, true, info.title
            end
        end
    end

    if type(info.vendor) == "table" then
        for _, fieldName in ipairs({"npcID", "vendorNPCID", "vendorNpcID", "vendorID"}) do
            local npcID = tonumber(info.vendor[fieldName])
            if npcID then
                local themeName = EndeavorsData.NPCToTheme[ResolveCanonicalNPCID(npcID)]
                if themeName then
                    return themeName, true, info.title
                end
            end
        end
    end

    local themeFromTitle = ResolveThemeFromTitle(info.title)
    if themeFromTitle then
        return themeFromTitle, true, info.title
    end

    return nil, false, info.title
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
    local changed = (newTheme ~= activeTheme) or (newKnown ~= activeThemeKnown)

    activeTheme = newTheme
    activeThemeKnown = newKnown

    if rawTitle and rawTitle ~= "" and not loggedRawTitle and HA.Addon and HA.Addon.db
            and HA.Addon.db.profile and HA.Addon.db.profile.debug then
        HA.Addon:Debug("EndeavorsData: Neighborhood initiative title:", rawTitle)
        loggedRawTitle = true
    end

    if HA.Addon and HA.Addon.db and HA.Addon.db.profile and HA.Addon.db.profile.debug then
        if activeThemeKnown then
            HA.Addon:Debug("EndeavorsData: active theme:", activeTheme, "(" .. tostring(reason) .. ")")
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

function EndeavorsData:Initialize()
    if eventFrame then return end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("NEIGHBORHOOD_INITIATIVE_UPDATED")
    eventFrame:SetScript("OnEvent", function(_, event)
        RefreshActiveTheme(event)

        -- Neighborhood API payload can lag behind PLAYER_ENTERING_WORLD.
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(2, function()
                RefreshActiveTheme("PLAYER_ENTERING_WORLD_DELAYED")
            end)
        end
    end)

    RefreshActiveTheme("Initialize")

    if HA.Addon then
        HA.Addon:Debug("EndeavorsData initialized")
    end
end
