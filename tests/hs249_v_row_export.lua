-- luacheck: globals assert loadfile print GetBuildInfo time

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-251 Stage C: the V-row (per-vendor summary line) carried decorCount only,
-- even though items rows post-HS-249 include every housing subclass. Anything
-- reading only V-rows undercounted a housing-only vendor's total stock —
-- exactly the class of vendor HS-251 was filed about. housingCount is
-- appended at the END of the row (append-only: it's positional TSV and other
-- columns are indexed by position downstream, so a mid-row insert would break
-- every existing consumer).
-------------------------------------------------------------------------------

GetBuildInfo = function() return "12.1.0", 68914 end
local fakeClock = 3000
time = function() fakeClock = fakeClock + 1 return fakeClock end

local capturedOutput = nil
local ExportHA = {
    Addon = {
        db = { global = { scannedVendors = {} } },
        Print = function() end,
        RegisterModule = function() end,
    },
    VendorData = {
        HasVendor = function() return false end, -- unknown vendor: never a delist candidate
        GetItemID = function(_, item) return item.itemID end,
    },
    OutputWindow = {
        Show = function(_, _, text) capturedOutput = text end,
    },
}

assert(loadfile(root .. "/Modules/ExportImport.lua"))("Homestead", ExportHA)

local function MakeItem(itemID)
    return { itemID = itemID, name = "Test Item " .. itemID, price = 10, merchantSlot = 1 }
end

-- Vendor 1: modern shape, housingCount (5) != decorCount (3) — the exact
-- shape the missing column made invisible (2 non-decor items undercounted).
ExportHA.Addon.db.global.scannedVendors[7001] = {
    npcID = 7001,
    name = "Modern Housing Vendor",
    mapID = 1,
    coords = { x = 0.5, y = 0.5 },
    faction = "Neutral",
    items = { MakeItem(6001) },
    itemCount = 5,
    decorCount = 3,
    housingCount = 5,
    lastScanned = 100,
    scanConfidence = "confirmed",
}

-- Vendor 2: legacy shape — only decorCount, no housingCount. Must fall back
-- to decorCount (the same fallback idiom the row already uses for itemCount).
ExportHA.Addon.db.global.scannedVendors[7002] = {
    npcID = 7002,
    name = "Legacy Vendor",
    mapID = 1,
    coords = { x = 0.5, y = 0.5 },
    faction = "Neutral",
    items = { MakeItem(6002) },
    itemCount = 4,
    decorCount = 4,
    -- housingCount deliberately absent.
    lastScanned = 200,
    scanConfidence = "confirmed",
}

ExportHA.ExportImport:ExportScannedVendors(true, true) -- fullExport, exportAll

assert(capturedOutput ~= nil, "expected the export to produce output")

local headerLine = capturedOutput:match("(# V:[^\n]*)\n")
assert(headerLine ~= nil, "expected a V-row header line")
assert(headerLine:match("\thousingCount\n?$") or headerLine:sub(-12) == "housingCount",
    "housingCount must be the last column in the V-row header")

local vendor1Line = capturedOutput:match("(V\t7001\t[^\n]*)\n")
assert(vendor1Line ~= nil, "expected a V-row for vendor 7001")
local v1Fields = {}
for field in (vendor1Line .. "\t"):gmatch("([^\t]*)\t") do
    table.insert(v1Fields, field)
end
-- Columns (1-indexed, field 1 is the "V" tag itself):
-- 1 V, 2 npcID, 3 name, 4 mapID, 5 x, 6 y, 7 faction, 8 timestamp,
-- 9 itemCount, 10 decorCount, ... 19 scanConfidence, 20 housingCount (new)
assert(v1Fields[10] == "3", "decorCount column must be unchanged (3), got " .. tostring(v1Fields[10]))
assert(v1Fields[#v1Fields] == "5",
    "housingCount must be the final column and equal 5, got " .. tostring(v1Fields[#v1Fields]))

local vendor2Line = capturedOutput:match("(V\t7002\t[^\n]*)\n")
assert(vendor2Line ~= nil, "expected a V-row for vendor 7002")
local v2Fields = {}
for field in (vendor2Line .. "\t"):gmatch("([^\t]*)\t") do
    table.insert(v2Fields, field)
end
assert(v2Fields[#v2Fields] == "4",
    "a legacy vendor with no housingCount must fall back to decorCount (4) in the new column, got "
    .. tostring(v2Fields[#v2Fields]))

print("hs249_v_row_export: HS-251 V-row housing column ok")
