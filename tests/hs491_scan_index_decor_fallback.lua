-- luacheck: globals assert loadfile print io time Enum CreateFrame UnitGUID UnitName UnitFactionGroup GetLocale GetSubZoneText GetRealZoneText C_Map C_Item C_MerchantFrame C_Timer GetMerchantNumItems GetMerchantItemLink GetMerchantItemID GetBuildInfo C_HousingCatalog

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Decor whose client item class is not Housing is still recorded when the
-- decor index knows its item ID: forced to the Decor subclass, with the
-- indexed decor ID. Housing items keep their catalog decor ID and are never
-- looked up; an item in neither is skipped; a slot whose data arrives late is
-- recovered; the export row carries the indexed decor ID. Drives the real
-- DecorClassifier, ScanPersistence and VendorScanner through the captured
-- frame handlers.
-------------------------------------------------------------------------------

local fakeClock = 1000
time = function()
    fakeClock = fakeClock + 1
    return fakeClock
end
GetBuildInfo = function() return "12.1.0", 68914 end

Enum = {
    ItemClass = { Housing = 20 },
    ItemHousingSubclass = {
        Decor = 0, Dye = 1, Room = 2, RoomCustomization = 3,
        ExteriorCustomization = 4, ServiceItem = 5,
    },
    UIMapType = { Continent = 2 },
}

local QUEST = 12

local frames = {}
CreateFrame = function()
    local frame = { shown = false, scripts = {} }
    function frame:RegisterEvent() end
    function frame:SetScript(name, handler) self.scripts[name] = handler end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    frames[#frames + 1] = frame
    return frame
end

C_Timer = { After = function() end }
C_Map = {
    GetBestMapForUnit = function() return nil end,
    GetPlayerMapPosition = function() return nil end,
    GetMapInfo = function() return nil end,
}
GetLocale = function() return "enUS" end
GetSubZoneText = function() return "Test Subzone" end
GetRealZoneText = function() return "Test Zone" end
UnitFactionGroup = function() return "Neutral" end

local currentNpc = nil
UnitGUID = function() return "Creature-0-1-1-1-" .. currentNpc .. "-0000000001" end
UnitName = function() return "Test Vendor " .. currentNpc end

-- slots[i] = { id = n, info = table|false, noMerchantID = true|nil }
local slots = {}
GetMerchantNumItems = function() return #slots end
GetMerchantItemLink = function(i)
    local slot = slots[i]
    return slot and slot.id and ("item:" .. slot.id) or nil
end
GetMerchantItemID = function(i)
    local slot = slots[i]
    if not slot or slot.noMerchantID then return nil end
    return slot.id
end
C_MerchantFrame = {
    GetItemInfo = function(i)
        local slot = slots[i]
        if not slot or slot.info == false then return nil end
        return { name = "Test Decor " .. slot.id, price = 100, stackCount = 1, isPurchasable = true }
    end,
}

-- itemClass[id] = { classID, subclassID }; absent = Housing/Decor; false = returns nothing
local itemClass = {}
C_Item = {
    GetItemInfoInstant = function(link)
        local id = tonumber(link:match("item:(%d+)"))
        local class = itemClass[id]
        if class == false then return end
        if class == nil then
            return id, nil, nil, nil, nil, Enum.ItemClass.Housing, Enum.ItemHousingSubclass.Decor
        end
        return id, nil, nil, nil, nil, class[1], class[2]
    end,
}

-- The catalog resolves an entry for 8101 only.
C_HousingCatalog = {
    GetCatalogEntryInfoByItem = function(link)
        if tonumber(link:match("item:(%d+)")) == 8101 then
            return { entryID = { recordID = 9101 }, name = "Cat 8101" }
        end
        return nil
    end,
}

local decorIndex, lookups, saved = {}, {}, {}
local debugLines = {}
local HA = {
    Addon = {
        db = {
            profile = { vendorScanning = { enabled = true } },
            global = { vendorNameByLocale = {}, scannedVendors = {} },
        },
        Debug = function(_, ...)
            local parts = { ... }
            for i = 1, #parts do parts[i] = tostring(parts[i]) end
            debugLines[#debugLines + 1] = table.concat(parts, " ")
        end,
        RegisterModule = function() end,
        Print = function() end,
    },
    VendorData = {
        HasVendor = function() return false end,
        BuildScannedIndex = function() end,
        InvalidateVendorCaches = function() end,
    },
    CatalogStore = {
        GetDecorIDFromItemID = function(_, itemID)
            if itemID == nil then return nil end
            lookups[itemID] = (lookups[itemID] or 0) + 1
            return decorIndex[itemID]
        end,
        Save = function(_, itemID, data) saved[itemID] = data and data.decorID end,
        SetRequirements = function() end,
        BeginBatch = function() end,
        EndBatch = function() end,
    },
    Events = { Fire = function() end },
    DevAddon = true,
}

assert(loadfile(root .. "/Modules/DecorClassifier.lua"))("Homestead", HA)
assert(loadfile(root .. "/Modules/ScanPersistence.lua"))("Homestead", HA)
assert(loadfile(root .. "/Modules/VendorScanner.lua"))("Homestead", HA)

HA.VendorScanner:Initialize()
local scanFrame, eventFrame = frames[1], frames[2]
assert(scanFrame and scanFrame.scripts.OnUpdate, "scan frame OnUpdate not captured")
assert(eventFrame and eventFrame.scripts.OnEvent, "event frame OnEvent not captured")

local function Fire(event) eventFrame.scripts.OnEvent(eventFrame, event) end
local function Pump() scanFrame.scripts.OnUpdate(scanFrame, 1) end

local function Open(npcID)
    currentNpc = npcID
    Fire("MERCHANT_SHOW")
    Fire("MERCHANT_UPDATE")
    return scanFrame.shown
end

local function PumpToEnd()
    local guard = 0
    while scanFrame.shown do
        Pump()
        guard = guard + 1
        assert(guard < 200, "scan never finished")
    end
end

local function Close() Fire("MERCHANT_CLOSED") end

local function LastScanLine()
    for i = #debugLines, 1, -1 do
        if debugLines[i]:find("^Scan complete:") then return debugLines[i] end
    end
end

local function Record(npcID) return HA.Addon.db.global.scannedVendors[npcID] end

local function RowFor(npcID, itemID)
    for _, item in ipairs(Record(npcID).items) do
        if item.itemID == itemID then return item end
    end
end

local DECOR = Enum.ItemHousingSubclass.Decor

-- a1. Mixed vendor: a Housing decor item, two indexed non-Housing items (one
--     with no merchant item ID), and a Housing non-decor item.
slots = {
    { id = 8101, info = {} },
    { id = 8102, info = {} },
    { id = 8103, info = {} },
    { id = 8104, info = {}, noMerchantID = true },
}
itemClass[8102] = { QUEST, 3 }
itemClass[8103] = { Enum.ItemClass.Housing, Enum.ItemHousingSubclass.Room }
itemClass[8104] = { QUEST, 3 }
decorIndex[8102], decorIndex[8103], decorIndex[8104] = 5102, 5103, 5104
assert(Open(5101), "case a1: open must start a scan")
PumpToEnd()
assert(Record(5101).scanConfidence == "confirmed", "case a1: expected confirmed")
assert(Record(5101).itemCount == 4 and #Record(5101).items == 4, "case a1: all four slots must be recorded")
assert(Record(5101).decorCount == 3, "case a1: expected three decor rows")
local row = RowFor(5101, 8101)
assert(row.subclassID == DECOR and row.decorID == 9101, "case a1: 8101 keeps the catalog decor ID")
row = RowFor(5101, 8102)
assert(row.subclassID == DECOR and row.decorID == 5102 and row.merchantSlot == 2, "case a1: 8102 forced to Decor with the indexed decor ID")
row = RowFor(5101, 8104)
assert(row and row.itemID == 8104 and row.subclassID == DECOR and row.decorID == 5104, "case a1: 8104 recorded without a merchant item ID")
row = RowFor(5101, 8103)
assert(row.subclassID == Enum.ItemHousingSubclass.Room and row.decorID == nil, "case a1: 8103 keeps its Housing subclass and no decor ID")
assert(saved[8101] == 9101 and saved[8102] == 5102 and saved[8104] == 5104, "case a1: decor IDs saved to the catalog store")
assert(saved[8103] == nil, "case a1: a non-decor housing item is not saved to the catalog store")
assert(lookups[8101] == nil and lookups[8103] == nil, "case a1: Housing items are never looked up in the index")
assert(LastScanLine():find("4/4 slots recorded, 4 housing items", 1, true), "case a1: " .. tostring(LastScanLine()))
Close()

-- a2. A single non-Housing decor item.
slots = { { id = 244778, info = {} } }
itemClass[244778] = { QUEST, 0 }
decorIndex[244778] = 1482
assert(Open(5102), "case a2: open must start a scan")
PumpToEnd()
assert(Record(5102).scanConfidence == "confirmed", "case a2: expected confirmed")
row = RowFor(5102, 244778)
assert(row and row.subclassID == DECOR and row.decorID == 1482 and row.merchantSlot == 1, "case a2: row forced to Decor with decor ID 1482")
assert(Record(5102).itemCount == #Record(5102).items, "case a2: itemCount must equal the item rows")
assert(saved[244778] == 1482, "case a2: decor ID saved to the catalog store")
Close()

-- b. A non-Housing item the index does not know is still skipped.
slots = { { id = 8301, info = {} }, { id = 8302, info = {} } }
itemClass[8302] = { QUEST, 0 }
assert(Open(5103), "case b: open must start a scan")
PumpToEnd()
assert(Record(5103).scanConfidence == "confirmed", "case b: expected confirmed")
assert(Record(5103).itemCount == 2 and #Record(5103).items == 1, "case b: one slot counted, not recorded")
assert(RowFor(5103, 8302) == nil, "case b: unindexed item must not be recorded")
assert((lookups[8302] or 0) >= 1, "case b: the index must be consulted")
Close()

-- c1. Indexed non-Housing slot whose info arrives late is recovered.
slots = { { id = 8401, info = {} }, { id = 8402, info = false } }
itemClass[8402] = { QUEST, 3 }
decorIndex[8402] = 5402
assert(Open(5104), "case c1: open must start a scan")
Pump()
slots[2].info = {}
PumpToEnd()
assert(Record(5104).scanConfidence == "confirmed", "case c1: expected confirmed")
row = RowFor(5104, 8402)
assert(row and row.subclassID == DECOR and row.decorID == 5402 and row.name == "Test Decor 8402", "case c1: recovered row")
assert(LastScanLine():find("1 slot(s) recovered", 1, true), "case c1: " .. tostring(LastScanLine()))
Close()

-- c2. Index learns the item between the walk and the re-read: the slot is
--     never marked complete, the scan is unknown, and the next scan records it.
slots = { { id = 8501, info = {} }, { id = 8502, info = false } }
itemClass[8502] = { QUEST, 0 }
assert(Open(5105), "case c2: open must start a scan")
Pump()
decorIndex[8502] = 5502
slots[2].info = {}
PumpToEnd()
assert(Record(5105).scanConfidence == "unknown", "case c2: expected unknown")
assert(#Record(5105).items == 1, "case c2: one row")
assert(RowFor(5105, 8502) == nil, "case c2: the changed slot is not recorded")
assert(LastScanLine():find("not complete: 2", 1, true), "case c2: " .. tostring(LastScanLine()))
assert(LastScanLine():find("ended: bound reached", 1, true), "case c2: " .. tostring(LastScanLine()))
Close()
assert(Open(5105), "case c2: the unknown vendor must rescan on reopen")
PumpToEnd()
assert(Record(5105).scanConfidence == "confirmed", "case c2: rescan must be confirmed")
assert(#Record(5105).items == 2, "case c2: rescan records both rows")
row = RowFor(5105, 8502)
assert(row and row.decorID == 5502, "case c2: rescan records 8502 with decor ID 5502")
Close()

-- f. GetItemInfoInstant returns nothing; the merchant item ID is used.
slots = { { id = 8601, info = {} } }
itemClass[8601] = false
decorIndex[8601] = 5601
assert(Open(5106), "case f: open must start a scan")
PumpToEnd()
assert(Record(5106).scanConfidence == "confirmed", "case f: expected confirmed")
row = RowFor(5106, 8601)
assert(row and row.itemID == 8601 and row.subclassID == DECOR and row.decorID == 5601 and row.merchantSlot == 1, "case f: row recorded")
assert(saved[8601] == 5601, "case f: decor ID saved to the catalog store")
Close()

-- g. No catalog store: no error, the non-Housing item is skipped.
local catalogStore = HA.CatalogStore
HA.CatalogStore = nil
slots = { { id = 8701, info = {} }, { id = 8702, info = {} } }
itemClass[8702] = { QUEST, 0 }
decorIndex[8702] = 5702
assert(Open(5107), "case g: open must start a scan")
PumpToEnd()
assert(Record(5107).scanConfidence == "confirmed", "case g: expected confirmed")
assert(#Record(5107).items == 1, "case g: one row")
assert(RowFor(5107, 8702) == nil, "case g: no lookup without the catalog store")
Close()
HA.CatalogStore = catalogStore

-- d. The export I-row carries the indexed decor ID and the Decor subclass.
local capturedOutput = nil
local ExportHA = {
    Addon = {
        db = { global = { scannedVendors = { [5101] = Record(5101) } } },
        Print = function() end,
        RegisterModule = function() end,
    },
    VendorData = {
        HasVendor = function() return false end,
        GetItemID = function(_, item) return item.itemID end,
    },
    OutputWindow = {
        Show = function(_, _, text) capturedOutput = text end,
    },
}
assert(loadfile(root .. "/Modules/ExportImport.lua"))("Homestead", ExportHA)
ExportHA.ExportImport:ExportScannedVendors(true, true)
assert(capturedOutput ~= nil, "case d: expected export output")

local function SplitFields(line)
    local fields = {}
    for field in (line .. "\t"):gmatch("([^\t]*)\t") do
        table.insert(fields, field)
    end
    return fields
end

local line = capturedOutput:match("(I\t5101\t8102\t[^\n]*)\n")
assert(line ~= nil, "case d: expected an I-row for 8102")
local fields = SplitFields(line)
assert(#fields == 14, "case d: expected 14 fields, got " .. #fields)
assert(fields[11] == "5102", "case d: decorID field, got " .. tostring(fields[11]))
assert(fields[14] == "0", "case d: subclassID field, got " .. tostring(fields[14]))

print("hs491_scan_index_decor_fallback: all cases ok")
