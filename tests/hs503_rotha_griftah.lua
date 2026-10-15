-- luacheck: globals assert loadfile loadstring print io _G

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

-------------------------------------------------------------------------------
-- Second position (HS-503 part 4): Unquestionably Griftah also stands at
-- Founder's Point (map 2352, Breakwater Bight, 0.6249, 0.7922).
-------------------------------------------------------------------------------

local RAZORWIND, FOUNDERS = 2351, 2352
local SKULL = 263875
local HARLOWE, HARLOWE_ITEM = 257897, 264915

-- Maps for the code under test. mapType 3 is a zone; neither has children.
local playerMapID, playerPos
local MAPS = {
    [RAZORWIND] = { name = "Razorwind Shores" },
    [FOUNDERS] = { name = "Founder's Point" },
}
_G.C_Map = {
    GetBestMapForUnit = function() return playerMapID end,
    GetPlayerMapPosition = function() return playerPos end,
    GetMapInfo = function(mapID)
        local row = MAPS[mapID]
        if not row then return nil end
        return { name = row.name, parentMapID = 0, mapType = 3 }
    end,
    GetMapChildrenInfo = function() return {} end,
    GetWorldPosFromMapPos = function(_, pos)
        return 1, { GetXY = function() return pos.x * 1000, pos.y * 1000 end }
    end,
}
_G.CreateVector2D = function(x, y) return { x = x, y = y } end
_G.time = function() return 2000000000 end
_G.GetBuildInfo = function() return "12.0.0", "1", "Jan 1 2026", 120000 end

local function RowsFor(mapID, npcID)
    local rows = {}
    for _, vendor in ipairs(HA.VendorData:GetVendorsInMap(mapID)) do
        if vendor.npcID == npcID then rows[#rows + 1] = vendor end
    end
    return rows
end

-- 7. The map lists: one entry per position, in both a known "no endeavor
--    active" state and the unknown state, with no npcID listed twice.
local function CheckMapLists(state)
    local alt = RowsFor(FOUNDERS, GRIFTAH)
    assert(#alt == 1, state .. ": Griftah must be listed once on Founder's Point, got " .. #alt)
    assert(alt[1].mapID == FOUNDERS and alt[1].x == 0.6249 and alt[1].y == 0.7922,
        state .. ": the Founder's Point entry must carry the second position")
    assert(alt[1].zone == "Founder's Point" and alt[1].subzone == "Breakwater Bight",
        state .. ": the Founder's Point entry must name Breakwater Bight")
    assert(#alt[1].items == 3, state .. ": the Founder's Point entry must carry his three items")
    local primary = RowsFor(RAZORWIND, GRIFTAH)
    assert(#primary == 1, state .. ": Griftah must be listed once on Razorwind Shores, got " .. #primary)
    assert(primary[1].mapID == RAZORWIND and primary[1].x == 0.402 and primary[1].y == 0.7292
            and primary[1].subzone == nil,
        state .. ": the Razorwind Shores entry must stay at the shipped position")
    for _, mapID in ipairs({ RAZORWIND, FOUNDERS }) do
        local seen = {}
        for _, vendor in ipairs(HA.VendorData:GetVendorsInMap(mapID)) do
            assert(not seen[vendor.npcID],
                state .. ": npc " .. vendor.npcID .. " is listed twice on map " .. mapID)
            seen[vendor.npcID] = true
        end
    end
end
CheckMapLists("no endeavor active")
_G.C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo = function() return nil end
ED:RefreshCache()
CheckMapLists("unknown endeavor state")
_G.C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo = function()
    return { isLoaded = true, initiativeID = 0, title = "", progressRequired = 0 }
end
ED:RefreshCache()
-- GetAllVendors and the expansion list carry no second copy.
local allCount = 0
for _, vendor in ipairs(HA.VendorIdentity:GetAllVendors()) do
    if vendor.npcID == GRIFTAH then allCount = allCount + 1 end
end
assert(allCount == 1, "Griftah must be listed once in GetAllVendors, got " .. allCount)

-- 8. The item source names both places. SourceManager is the real module; the
--    tooltip and side-panel renderers are file-local, so their real text is
--    extracted and run.
assert(loadfile(root .. "/Core/constants.lua"))("Homestead", HA)
HA.SourceTextScanner = { GetParsedSource = function() return nil end }
assert(loadfile(root .. "/Data/SourceManager.lua"))("Homestead", HA)

local function VendorSourcesOf(itemID)
    return HA.SourceManager:GetVendorSources(itemID)
end
local skullSources = VendorSourcesOf(SKULL)
assert(#skullSources == 1, "item " .. SKULL .. " must stay one source, got " .. #skullSources)
local skullData = skullSources[1].data
assert(skullData.zone == "Razorwind Shores" and skullData.altZone == "Founder's Point"
        and skullData.altSubzone == "Breakwater Bight" and skullData.altMapID == FOUNDERS,
    "the Hex-Skull source must name Razorwind Shores and Breakwater Bight in Founder's Point")

local function ReadSource(path)
    local file = assert(io.open(root .. path, "r"))
    local text = file:read("*a")
    file:close()
    return text
end

local tooltipText = ReadSource("/Overlay/Tooltips.lua")
local renderText = tooltipText:match("(local function RenderVendorSourceLines%(.-\nend)\n")
assert(renderText, "could not extract RenderVendorSourceLines from Tooltips.lua")
local renderVendorLines = assert(loadstring(
    "local COLOR_YELLOW = {r = 1, g = 0.82, b = 0}\n"
    .. "local COLOR_WHITE = {r = 1, g = 1, b = 1}\n"
    .. "local function FormatCost() return nil end\n"
    .. renderText .. "\nreturn RenderVendorSourceLines", "RenderVendorSourceLines-extract"))()
local function LocationLines(source)
    local tooltip = { lines = {} }
    function tooltip:AddLine(text) self.lines[#self.lines + 1] = text end
    renderVendorLines(tooltip, source, "", nil, nil, true)
    local locations = {}
    for _, line in ipairs(tooltip.lines) do
        if line:find("Location:", 1, true) then locations[#locations + 1] = line end
    end
    return locations
end
local locations = LocationLines(skullSources[1])
assert(#locations == 2, "the Hex-Skull tooltip must carry two Location lines, got " .. #locations)
assert(locations[1] == "  Location: |cFFFFFFFFRazorwind Shores|r",
    "first Location line must be Razorwind Shores, got " .. locations[1])
assert(locations[2] == "  Location: |cFFFFFFFFBreakwater Bight (Founder's Point)|r",
    "second Location line must be Breakwater Bight (Founder's Point), got " .. locations[2])
local rothaSources = VendorSourcesOf(274661)
local rothaLocations
for _, source in ipairs(rothaSources) do
    if source.data.npcID == ROTHA then rothaLocations = LocationLines(source) end
end
assert(rothaLocations and #rothaLocations == 1, "a one-position vendor must keep a single Location line")

local panelText = ReadSource("/UI/MapSidePanel.lua")
local summaryText = panelText:match("(local function GetSourceLocationText%(data%).-\nend)\n\nlocal function GetDisplaySourcesForItem")
assert(summaryText, "could not extract FormatSourceSummary from MapSidePanel.lua")
local formatSummary = assert(loadstring(
    "local function GetSourceTypeLabel() return \"Vendor\" end\n"
    .. summaryText .. "\nreturn FormatSourceSummary", "FormatSourceSummary-extract"))()
local summary = formatSummary(skullSources[1])
assert(summary:find("Razorwind Shores", 1, true) and summary:find("Founder's Point", 1, true),
    "the Hex-Skull summary must name both zones, got " .. summary)
local rothaSummary
for _, source in ipairs(rothaSources) do
    if source.data.npcID == ROTHA then rothaSummary = formatSummary(source) end
end
assert(rothaSummary and rothaSummary:find("The Common, Razorwind Shores", 1, true),
    "a one-position vendor keeps the subzone and zone summary, got " .. tostring(rothaSummary))

-- An endeavor vendor's source carries its other zone too (switch on): Harlowe
-- Marl's primary is Founder's Point, his second position Razorwind Shores.
local harloweItem
for _, item in ipairs(ED.Vendors[HARLOWE].items) do
    local itemID = type(item) == "table" and item[1] or item
    local sellers = HA.VendorData:GetVendorsForItem(itemID)
    if #sellers == 1 and sellers[1].npcID == HARLOWE then harloweItem = itemID break end
end
assert(harloweItem, "Harlowe Marl must sell at least one item nobody else sells")
local harloweSources = VendorSourcesOf(harloweItem)
assert(#harloweSources == 1 and harloweSources[1].data.altZone == "Razorwind Shores"
        and harloweSources[1].data.altMapID == RAZORWIND,
    "item " .. harloweItem .. " (Harlowe Marl only) must name his second zone")

-- 9. The closest vendor, wherever the player stands.
local function Closest(itemID, mapID, x, y)
    playerMapID = mapID
    playerPos = mapID and { x = x, y = y } or nil
    return HA.VendorData:GetClosestVendorForItem(itemID)
end
local atFounders = Closest(SKULL, FOUNDERS, 0.5, 0.5)
assert(atFounders.npcID == GRIFTAH and atFounders.mapID == FOUNDERS and atFounders.x == 0.6249
        and atFounders.y == 0.7922 and atFounders.subzone == "Breakwater Bight",
    "at Founder's Point the closest Griftah must be the Breakwater Bight position")
local atRazorwind = Closest(SKULL, RAZORWIND, 0.5, 0.5)
assert(atRazorwind.mapID == RAZORWIND and atRazorwind.x == 0.402 and atRazorwind.y == 0.7292,
    "at Razorwind Shores the closest Griftah must be the shipped position")
local elsewhere = Closest(SKULL, 9999, 0.5, 0.5)
assert(elsewhere.mapID == RAZORWIND, "away from both, the closest Griftah must be the primary")
local harloweAtRazorwind = Closest(HARLOWE_ITEM, RAZORWIND, 0.5, 0.5)
assert(harloweAtRazorwind.npcID == HARLOWE and harloweAtRazorwind.mapID == RAZORWIND
        and harloweAtRazorwind.x == 0.5431,
    "at Razorwind Shores the closest Harlowe Marl must be his second position")
local harloweAtFounders = Closest(HARLOWE_ITEM, FOUNDERS, 0.5, 0.5)
assert(harloweAtFounders.mapID == FOUNDERS and harloweAtFounders.x == 0.5304,
    "at Founder's Point the closest Harlowe Marl must be his primary position")

-- 10. A scan on one map never moves or hides the other position. VendorFilter
--     is the real module; the scan is a scannedVendors record.
HA.VendorFilter = nil
assert(loadfile(root .. "/UI/VendorFilter.lua"))("Homestead", HA)
local VF = HA.VendorFilter
HA.Addon.db.global.scannedVendors = {}
local scanned = HA.Addon.db.global.scannedVendors
local function Placement(vendor)
    local coords, mapID, source = VF.GetBestVendorCoordinates(vendor)
    return coords and coords.x, mapID, source
end
local primaryRow = RowsFor(RAZORWIND, GRIFTAH)[1]
local copyRow = RowsFor(FOUNDERS, GRIFTAH)[1]

scanned[GRIFTAH] = { name = "Unquestionably Griftah", mapID = FOUNDERS, coords = { x = 0.7, y = 0.6 } }
local x, mapID, source = Placement(primaryRow)
assert(x == 0.402 and mapID == RAZORWIND and source == "static",
    "a Founder's Point scan must leave the Razorwind Shores position static, got " .. tostring(source))
x, mapID, source = Placement(copyRow)
assert(x == 0.7 and mapID == FOUNDERS and source == "scanned",
    "a Founder's Point scan must place the Founder's Point position, got " .. tostring(source))

scanned[GRIFTAH] = { name = "Unquestionably Griftah", mapID = RAZORWIND, coords = { x = 0.41, y = 0.73 } }
x, mapID, source = Placement(primaryRow)
assert(x == 0.41 and mapID == RAZORWIND and source == "scanned",
    "a Razorwind Shores scan must place the Razorwind Shores position, got " .. tostring(source))
x, mapID, source = Placement(copyRow)
assert(x == 0.6249 and mapID == FOUNDERS and source == "static",
    "a Razorwind Shores scan must leave the Founder's Point position static, got " .. tostring(source))
scanned[GRIFTAH] = nil

local minimapText = ReadSource("/UI/MinimapPinCollect.lua")
assert(minimapText:find("not (vendor.endeavor or vendor.altMapID)", 1, true),
    "the minimap scan-map guard must bypass vendors with a second position")

-- 10b. The real minimap collector, player at Razorwind Shores, scan at
--      Founder's Point: the Razorwind position is still collected, from
--      static data.
local collected
local minimapHA = {
    Constants = HA.Constants,
    Addon = HA.Addon,
    VendorData = HA.VendorData,
    VendorFilter = VF,
    PerformanceTrace = { Measure = function(_, _label, _tag, fn) return fn() end },
    HomesteadMinimapOverlay = {
        ShouldHideMinimapPins = function() return false end,
        SetPins = function(_, pins) collected = pins end,
    },
    MapPinProvider = {
        GetContinentForZone = function() return nil end,
        minimapExcludedContinents = {},
        continentToZones = {},
        GetNativeWorldCoordinates = function(mapID_, px, py)
            return py * 1000, px * 1000, 1, mapID_
        end,
    },
    VendorMapPins = {
        IsInitialized = function() return true end,
        IsMinimapPinsEnabled = function() return true end,
        IsMapFilterSourceEnabled = function() return true end,
        ClearMinimapPins = function() end,
        IsMinimapWarmupActive = function() return false end,
        CanAccessVendor = function() return true end,
        IsOppositeFaction = function() return false end,
    },
}
HA.Addon.db.profile.vendorTracer = { minimapCrossZoneMode = "off" }
_G.IsIndoors = function() return false end
assert(loadfile(root .. "/UI/MinimapPinCollect.lua"))("Homestead", minimapHA)
VF.ShouldShowOppositeFaction = VF.ShouldShowOppositeFaction or function() return false end
VF.ShouldHideCompletedVendorPin = function() return false end
local function MinimapPinFor(npcID, scanMapID, scanX)
    scanned[npcID] = scanMapID and { name = "Unquestionably Griftah", mapID = scanMapID, coords = { x = scanX, y = 0.6 } }
        or nil
    playerMapID, playerPos = RAZORWIND, { x = 0.5, y = 0.5 }
    collected = nil
    minimapHA.MinimapPinCollect:RefreshMinimapPins()
    scanned[npcID] = nil
    for _, pin in ipairs(collected or {}) do
        if pin.vendor.npcID == npcID then return pin end
    end
    return nil
end
local pin = MinimapPinFor(GRIFTAH, FOUNDERS, 0.7)
assert(pin, "a Founder's Point scan must not hide Griftah's Razorwind Shores minimap pin")
assert(pin.mapID == RAZORWIND and math.abs(pin.worldX - 729.2) < 1e-6,
    "the Razorwind Shores minimap pin must stay at the static position")

-- 11. One pin per view, from the real world-map vendor collector. Every
--     combination of view map and scan: exactly one Griftah pin, at the scanned
--     spot only when the scan was made on the viewed map.
_G.CreateFrame = function()
    return setmetatable({}, { __index = function() return function() end end })
end
_G.InCombatLockdown = function() return false end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.GetTimePreciseSec = function() return 0 end
_G.C_Timer = {
    NewTicker = function() return { Cancel = function() end } end,
    NewTimer = function() return { Cancel = function() end } end,
    After = function() end,
}
_G.Enum = { UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 } }
HA.Events = { RegisterCallback = function() end, Fire = function() end }
HA.PerformanceTrace = { Measure = function(_, _label, _tag, pcallFn, fn) return pcallFn(fn) end }
HA.BadgeCalculation = {}
HA.Addon.db.profile.vendorTracer = { showMinimapPins = false }
assert(loadfile(root .. "/UI/MapPinProvider.lua"))("Homestead", HA)
assert(loadfile(root .. "/UI/VendorMapPins.lua"))("Homestead", HA)
local VMP = HA.VendorMapPins
VF.ShouldHideCompletedVendorPin = function() return false end
VF.ShouldShowOppositeFaction = function() return true end
VF.CanAccessVendor = function() return true end
VF.IsOppositeFaction = function() return false end
VMP:Initialize()
local collect = VMP.pinSourceProviders.vendor.collect
local function GriftahPins(viewMapID, scanMapID)
    HA.Addon.db.global.scannedVendors = scanMapID
        and { [GRIFTAH] = { name = "Unquestionably Griftah", mapID = scanMapID, coords = { x = 0.7, y = 0.6 } } }
        or {}
    local state = { vendorPins = {} }
    collect(VMP, viewMapID, { [viewMapID] = true }, "all", state)
    local pins = {}
    for _, record in ipairs(state.vendorPins) do
        if record.vendor.npcID == GRIFTAH then pins[#pins + 1] = record end
    end
    return pins
end
local STATIC_X = { [RAZORWIND] = 0.402, [FOUNDERS] = 0.6249 }
for _, viewMapID in ipairs({ RAZORWIND, FOUNDERS }) do
    for _, scanMapID in ipairs({ false, RAZORWIND, FOUNDERS }) do
        local label = "view " .. viewMapID .. ", scan " .. tostring(scanMapID)
        local pins = GriftahPins(viewMapID, scanMapID)
        assert(#pins == 1, label .. ": exactly one Griftah pin, got " .. #pins)
        local expectedX = (scanMapID == viewMapID) and 0.7 or STATIC_X[viewMapID]
        assert(pins[1].vendor.mapID == viewMapID, label .. ": the pin must come from the entry for the viewed map")
        assert(pins[1].mapID == viewMapID and pins[1].x == expectedX,
            label .. ": the pin must sit at x " .. expectedX .. " on map " .. viewMapID
            .. ", got x " .. tostring(pins[1].x) .. " on map " .. tostring(pins[1].mapID))
    end
end
HA.Addon.db.global.scannedVendors = {}

print("hs503_rotha_griftah: ok")
