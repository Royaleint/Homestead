-- luacheck: globals assert loadfile print GetBuildInfo time Enum

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-- Export format v3 appends subclassID to each positional TSV item row. Existing
-- column indexes remain unchanged, while legacy items without subclassID emit
-- an empty trailing field.

GetBuildInfo = function() return "12.1.0", 68914 end
local fakeClock = 3000
time = function() fakeClock = fakeClock + 1 return fakeClock end

Enum = {
    ItemHousingSubclass = {
        Decor = 0,
        Dye = 1,
        Room = 2,
    },
}

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

-- Vendor 1: one item with subclassID set (a room plan), one legacy item with
-- no subclassID at all (legacy persisted shape).
ExportHA.Addon.db.global.scannedVendors[7101] = {
    npcID = 7101,
    name = "Subclass Test Vendor",
    mapID = 1,
    coords = { x = 0.5, y = 0.5 },
    faction = "Neutral",
    items = {
        {
            itemID = 6201,
            name = "Test Room Plan",
            price = 10,
            merchantSlot = 1,
            subclassID = Enum.ItemHousingSubclass.Room,
        },
        {
            itemID = 6202,
            name = "Legacy Item No Subclass",
            price = 20,
            merchantSlot = 2,
            -- subclassID deliberately absent from this legacy record.
        },
    },
    itemCount = 2,
    decorCount = 2,
    housingCount = 2,
    lastScanned = 100,
    scanConfidence = "confirmed",
}

ExportHA.ExportImport:ExportScannedVendors(true, true) -- fullExport, exportAll

assert(capturedOutput ~= nil, "expected the export to produce output")

-- (a) header declares exportFormatVersion 3.
assert(capturedOutput:match("# exportFormatVersion: 3\n"),
    "expected exportFormatVersion to be bumped to 3")

-- (a) I-row header lists subclassID as the last column.
local headerLine = capturedOutput:match("(# I:[^\n]*)\n")
assert(headerLine ~= nil, "expected an I-row header line")
assert(headerLine:sub(-10) == "subclassID",
    "subclassID must be the last column in the I-row header, got: " .. tostring(headerLine))

local function SplitFields(line)
    local fields = {}
    for field in (line .. "\t"):gmatch("([^\t]*)\t") do
        table.insert(fields, field)
    end
    return fields
end

-- Columns (1-indexed, field 1 is the "I" tag itself):
-- 1 I, 2 npcID, 3 itemID, 4 name, 5 price, 6 costData, 7 isUsable,
-- 8 isPurchasable, 9 spellID, 10 requirements, 11 decorID, 12 merchantSlot,
-- 13 hasExtendedCost, 14 subclassID (new)

-- (b) item with subclassID set exports it correctly as the final field.
local item1Line = capturedOutput:match("(I\t7101\t6201\t[^\n]*)\n")
assert(item1Line ~= nil, "expected an I-row for item 6201")
local item1Fields = SplitFields(item1Line)
assert(#item1Fields == 14,
    "expected exactly 14 fields (append-only: one new trailing column, nothing inserted mid-row), got "
    .. #item1Fields)
assert(item1Fields[#item1Fields] == tostring(Enum.ItemHousingSubclass.Room),
    "subclassID must be the final column and equal Room (2), got " .. tostring(item1Fields[#item1Fields]))

-- (c) item with no subclassID (legacy shape) exports an empty trailing
-- field, not a crash or a wrong value, and the row still has the right
-- total field count — the backward-compatibility case append-only exists
-- to protect.
local item2Line = capturedOutput:match("(I\t7101\t6202\t[^\n]*)\n")
assert(item2Line ~= nil, "expected an I-row for item 6202")
local item2Fields = SplitFields(item2Line)
assert(#item2Fields == 14,
    "a legacy item with no subclassID must still produce 14 fields (empty trailing column), got "
    .. #item2Fields)
assert(item2Fields[#item2Fields] == "",
    "a legacy item with no subclassID must export an empty trailing field, got "
    .. "'" .. tostring(item2Fields[#item2Fields]) .. "'")

print("i_row_subclass_export: v3 subclassID column ok")
