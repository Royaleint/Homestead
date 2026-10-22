-- luacheck: globals assert loadfile print io UIParent CreateFrame InCombatLockdown C_Timer wipe UnitFactionGroup GetBuildInfo
-- Run from the repo root:  lua tests/hs534_browser_faction_label.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-534: the Decor Browser tags an opposite-faction vendor with its faction.
-- A vendor with no faction (or "Neutral") standing in a faction-owned map is
-- opposite through the zone map, so the tag must name that effective faction
-- and must never reach format as nil. Real Constants, VendorFilter, Adapter,
-- Shops.InitVendorRow and Item.Show; the rest of the browser is stubbed.
-------------------------------------------------------------------------------

local function noop() end
local function Stub() return setmetatable({}, { __index = function() return noop end }) end
UIParent = { GetWidth = function() return 1365 end, GetHeight = function() return 768 end }
CreateFrame = function() return Stub() end
InCombatLockdown = function() return false end
C_Timer = { After = noop }
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
UnitFactionGroup = function() return "Alliance" end
GetBuildInfo = function() return "12.0.0", "60000", "", 120000 end

local HA = {
    Constants = { TEXTURE_ROOT = "Textures/" },
    Addon = { _enabled = true, db = { profile = {}, global = {} } },
    Events = { RegisterCallback = noop },
    PerformanceTrace = { Measure = function(_, _, _, fn, ...) return fn(...) end },
}
assert(loadfile(root .. "/Core/constants.lua"))("Homestead", HA)
assert(loadfile(root .. "/UI/VendorFilter.lua"))("Homestead", HA)
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)

local f = assert(io.open(root .. "/Homestead.toc", "rb"))
local toc = f:read("*a")
f:close()
for line in toc:gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI.Browser.[%w_]+%.lua)%s*$")
    if entry then assert(loadfile(root .. "/" .. entry:gsub(string.char(92), "/")))("Homestead", HA) end
end
local B, D = HA.DecorBrowser, HA.DecorBrowser.Data

-- A map owned by each faction, taken from the real zone table.
local allianceMap, hordeMap
for mapID, faction in pairs(HA.Constants.ZoneToFactionMap) do
    if faction == "Alliance" then allianceMap = allianceMap or mapID end
    if faction == "Horde" then hordeMap = hordeMap or mapID end
end
assert(allianceMap and hordeMap, "ZoneToFactionMap has no Alliance and Horde map")

local CASES = {
    { name = "nil faction, Horde map", vendor = { npcID = 1, name = "Grog", mapID = hordeMap }, tag = "Horde" },
    { name = "Neutral faction, Horde map", vendor = { npcID = 2, name = "Zug", mapID = hordeMap, faction = "Neutral" }, tag = "Horde" },
    { name = "plain Horde vendor", vendor = { npcID = 3, name = "Vol", mapID = allianceMap, faction = "Horde" }, tag = "Horde" },
    { name = "nil faction, own-faction map", vendor = { npcID = 4, name = "Ann", mapID = allianceMap }, tag = nil },
    { name = "Neutral, unmapped", vendor = { npcID = 5, name = "Nem", faction = "Neutral" }, tag = nil },
    { name = "plain Alliance vendor", vendor = { npcID = 6, name = "Bob", mapID = hordeMap, faction = "Alliance" }, tag = nil },
}

-- Label helper: effective faction, nil when none resolves.
assert(D.VendorFactionLabel(CASES[1].vendor) == "Horde", "nil-faction vendor must label its map's faction")
assert(D.VendorFactionLabel(CASES[2].vendor) == "Horde", "Neutral vendor must not label as Neutral")
assert(D.VendorFactionLabel({ npcID = 9 }) == nil, "no faction and no map must give no label")

-- Shop page requirement line: effective faction, same source as the warning.
assert(D.VendorRequirements(CASES[3].vendor, {})[1] == "Horde", "faction vendor must list its faction")
assert(D.VendorRequirements(CASES[2].vendor, {})[1] == "Horde", "Neutral vendor in a Horde map must list Horde")
assert(D.VendorRequirements({ npcID = 7, mapID = allianceMap, faction = "Neutral" }, {})[1] == "Alliance", "Neutral vendor in an Alliance map must list Alliance")
assert(#D.VendorRequirements(CASES[5].vendor, {}) == 0, "Neutral vendor in no faction map must list no faction")
assert(#D.VendorRequirements(CASES[4].vendor, {}) == 1 and D.VendorRequirements(CASES[4].vendor, {})[1] == "Alliance", "nil faction in an Alliance map lists Alliance")
assert(#D.VendorRequirements({ npcID = 8 }, {}) == 0, "nil faction and no map must list no faction")

-- Shops row.
local shops = B.pages.shops
D.VendorCounts = function() return 1, 2 end
D.VendorNote = function() return nil end
D.VendorLocation = function() return nil end
shops.CountsText = shops.CountsText or function() return "1/2" end
for _, c in ipairs(CASES) do
    local row = { view = { Set = function(self, spec) self.spec = spec end } }
    local ok, err = pcall(shops.InitVendorRow, row, { vendor = c.vendor })
    assert(ok, c.name .. ": InitVendorRow raised: " .. tostring(err))
    local name = row.view.spec.name
    local want = c.tag and (c.vendor.name .. " (" .. c.tag .. ")") or c.vendor.name
    assert(name == want, c.name .. ": row name '" .. tostring(name) .. "' expected '" .. want .. "'")
end

-- Item page sold line.
local item = B.pages.item
local current
D.MemoVersion = function() return 1 end
D.ItemSources = function(itemID) return { { type = "vendor", npcID = current.npcID } } end
D.Vendor = function() return current end
D.IsListedVendor = function() return true end
D.ItemName = function() return "Thing" end
D.ItemStatus = function() return { state = "owned" } end
D.Requirements = function() return {} end
D.Price = function() return nil end
D.SourceLine = function() return "" end
D.CatalogInfo = function() return nil end
item.RenderModel = noop
for _, name in ipairs({ "header", "toggle", "status", "statusNote", "price", "req", "soldMore", "otherMore", "noOther" }) do
    item[name] = Stub()
end
item.header = { text = Stub(), right = Stub() }
local shown
local btn = { text = { SetText = function(_, t) shown = t end } }
item.soldRows = { { btn = btn, wp = Stub(), Show = noop, Hide = noop } }
item.otherRows = {}
for i, c in ipairs(CASES) do
    current = c.vendor
    c.vendor.zone, c.vendor.subzone = "Zone", nil
    shown = nil
    local ok, err = pcall(item.Show, { itemID = 1000 + i, npcID = nil })
    assert(ok, c.name .. ": Item.Show raised: " .. tostring(err))
    local want = c.tag and ("Zone (" .. c.tag .. ")") or "Zone"
    assert(shown and shown:find(want, 1, true) and (c.tag or not shown:find("(", 1, true)),
        c.name .. ": sold line '" .. tostring(shown) .. "' expected to contain '" .. want .. "'")
end

print("hs534_browser_faction_label: ok")
