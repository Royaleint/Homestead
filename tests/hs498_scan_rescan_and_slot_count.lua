-- luacheck: globals assert loadfile print io time Enum CreateFrame UnitGUID UnitName UnitFactionGroup GetLocale GetSubZoneText GetRealZoneText C_Map C_Item C_MerchantFrame C_Timer GetMerchantNumItems GetMerchantItemLink GetMerchantItemID

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-498: a scan that finishes with empty merchant slots is saved "unknown",
-- and the vendor must be scannable again on the next visit. A confirmed scan
-- keeps the once-per-session lock. The saved record also carries the slot
-- total. Drives the real DecorClassifier, ScanPersistence and VendorScanner
-- through the captured frame handlers.
-------------------------------------------------------------------------------

local fakeClock = 1000
time = function()
    fakeClock = fakeClock + 1
    return fakeClock
end

Enum = {
    ItemClass = { Housing = 20 },
    ItemHousingSubclass = {
        Decor = 0, Dye = 1, Room = 2, RoomCustomization = 3,
        ExteriorCustomization = 4, ServiceItem = 5,
    },
    UIMapType = { Continent = 2 },
}

-- Frames: capture the scripts and track Show/Hide.
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

-- Test-owned merchant. slots[i] = { id = number|nil, info = table|false }.
-- A nil id means no link; info == false means GetItemInfo returns nil.
local slots = {}
GetMerchantNumItems = function() return #slots end
GetMerchantItemLink = function(i)
    local slot = slots[i]
    return slot and slot.id and ("item:" .. slot.id) or nil
end
GetMerchantItemID = function(i) return slots[i] and slots[i].id end
C_MerchantFrame = {
    GetItemInfo = function(i)
        local slot = slots[i]
        if not slot or slot.info == false then return nil end
        return { name = "Test Decor " .. slot.id, price = 100, stackCount = 1, isPurchasable = true }
    end,
}
C_Item = {
    GetItemInfoInstant = function(link)
        local id = tonumber(link:match("item:(%d+)"))
        return id, nil, nil, nil, nil, Enum.ItemClass.Housing, Enum.ItemHousingSubclass.Decor
    end,
}

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
    },
    VendorData = {
        HasVendor = function() return false end,
        BuildScannedIndex = function() end,
        InvalidateVendorCaches = function() end,
    },
    CatalogStore = {
        SetRequirements = function() end,
        Save = function() end,
        BeginBatch = function() end,
        EndBatch = function() end,
    },
    Events = { Fire = function() end },
    DevAddon = true,
}

assert(loadfile(root .. "/Modules/DecorClassifier.lua"))("Homestead", HA)
assert(loadfile(root .. "/Modules/ScanPersistence.lua"))("Homestead", HA)
assert(loadfile(root .. "/Modules/VendorScanner.lua"))("Homestead", HA)

local SP = HA.ScanPersistence
local realSave = SP.SaveVendorData
local saveCount = 0
local function CountingSave(self, scanData)
    saveCount = saveCount + 1
    return realSave(self, scanData)
end
SP.SaveVendorData = CountingSave

HA.VendorScanner:Initialize()
local scanFrame, eventFrame = frames[1], frames[2]
assert(scanFrame and scanFrame.scripts.OnUpdate, "scan frame OnUpdate not captured")
assert(eventFrame and eventFrame.scripts.OnEvent, "event frame OnEvent not captured")

local function Fire(event) eventFrame.scripts.OnEvent(eventFrame, event) end
local function Pump() scanFrame.scripts.OnUpdate(scanFrame, 1) end

-- Opens the vendor; returns true when a scan started.
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

local function FillSlots(count)
    slots = {}
    for i = 1, count do slots[i] = { id = 9000 + i, info = {} } end
end

local function LastScanLine()
    for i = #debugLines, 1, -1 do
        if debugLines[i]:find("^Scan complete:") then return debugLines[i] end
    end
end

local function Record(npcID) return HA.Addon.db.global.scannedVendors[npcID] end

-- a. Every slot has data: confirmed, one save, reopen does not rescan.
FillSlots(7)
assert(Open(4001), "case a: first open must start a scan")
PumpToEnd()
assert(saveCount == 1, "case a: expected one save")
assert(Record(4001).scanConfidence == "confirmed", "case a: expected confirmed")
assert(Record(4001).itemCount == 7 and Record(4001).slotCount == 7, "case a: itemCount and slotCount must be 7")
assert(LastScanLine():find("7/7 slots recorded", 1, true), "case a: debug line must show 7/7: " .. tostring(LastScanLine()))
assert(not LastScanLine():find("rescan", 1, true), "case a: no rescan text on a confirmed scan")
Close()
assert(not Open(4001), "case a: a confirmed vendor must not rescan on reopen")
assert(saveCount == 1, "case a: reopen must not save again")
Close()

-- b. Nil links: unknown, slotCount keeps the total, reopen rescans until clean.
FillSlots(17)
for i = 11, 17 do slots[i].id = nil end
saveCount = 0
assert(Open(4002), "case b: first open must start a scan")
PumpToEnd()
assert(saveCount == 1, "case b: expected one save")
assert(Record(4002).scanConfidence == "unknown", "case b: expected unknown")
assert(Record(4002).slotCount == 17, "case b: slotCount must be the slot total")
assert(Record(4002).itemCount == 10, "case b: itemCount must exclude empty slots")
assert(LastScanLine():find("10/17 slots recorded", 1, true), "case b: debug line must show 10/17: " .. tostring(LastScanLine()))
assert(LastScanLine():find("7 slot(s) returned no data", 1, true), "case b: debug line must report 7 empty slots")
assert(LastScanLine():find("will rescan on reopen", 1, true), "case b: debug line must say it will rescan")
Close()
assert(Open(4002), "case b: unknown vendor must rescan on reopen")
PumpToEnd()
assert(saveCount == 2, "case b: expected a second save")
Close()
FillSlots(17)
assert(Open(4002), "case b: still-unknown vendor must rescan again")
PumpToEnd()
assert(saveCount == 3, "case b: expected a third save")
assert(Record(4002).scanConfidence == "confirmed", "case b: clean rescan must store confirmed")
assert(Record(4002).itemCount == 17 and Record(4002).slotCount == 17, "case b: clean rescan must record all 17")
Close()
assert(not Open(4002), "case b: confirmed vendor must not rescan")
assert(saveCount == 3, "case b: no save after the lock holds")
Close()

-- c. Link present, GetItemInfo nil: still recorded, unknown, rescans.
FillSlots(6)
slots[3].info = false
saveCount = 0
assert(Open(4003), "case c: first open must start a scan")
PumpToEnd()
assert(saveCount == 1, "case c: expected one save")
assert(Record(4003).scanConfidence == "unknown", "case c: expected unknown")
assert(Record(4003).itemCount == 6 and Record(4003).slotCount == 6, "case c: the slot with a link is still recorded")
assert(LastScanLine():find("6/6 slots recorded", 1, true), "case c: debug line must show 6/6: " .. tostring(LastScanLine()))
assert(LastScanLine():find("1 slot(s) returned no data", 1, true), "case c: the slot counts once")
Close()
assert(Open(4003), "case c: unknown vendor must rescan on reopen")
PumpToEnd()
assert(saveCount == 2, "case c: expected a second save")
Close()

-- d. An unknown scan with fewer items keeps the confirmed record and unlocks.
FillSlots(5)
local seedItems = {}
for i = 1, 5 do
    seedItems[i] = { itemID = 9000 + i, name = "Seed " .. i, subclassID = Enum.ItemHousingSubclass.Decor, merchantSlot = i }
end
realSave(SP, {
    npcID = 4004, vendorName = "Test Vendor 4004", coords = { x = 0.5, y = 0.5 },
    housingItems = seedItems, totalItems = 5, scanComplete = true, hadNilSlots = false,
})
assert(Record(4004).scanConfidence == "confirmed" and #Record(4004).items == 5, "case d: seed record")
local seedScanned = Record(4004).lastScanned
saveCount = 0
slots[4].id, slots[5].id = nil, nil
assert(Open(4004), "case d: first open must start a scan")
PumpToEnd()
assert(saveCount == 1, "case d: expected one save call")
assert(#Record(4004).items == 5, "case d: the larger record must be preserved")
assert(Record(4004).scanConfidence == "confirmed", "case d: confidence must stay confirmed")
assert(Record(4004).lastScanned == seedScanned, "case d: lastScanned must not move")
assert(Record(4004).lastScanAttempt ~= nil, "case d: the attempt must be recorded")
Close()
assert(Open(4004), "case d: lock must be cleared after the unknown scan")
PumpToEnd()
assert(saveCount == 2, "case d: expected a second save call")
Close()

-- e. Merchant closed mid-scan: no save, reopen scans.
FillSlots(12)
saveCount = 0
assert(Open(4005), "case e: first open must start a scan")
Pump()
assert(scanFrame.shown, "case e: scan must still be running after one batch")
Close()
assert(saveCount == 0, "case e: an aborted scan must not save")
assert(Record(4005) == nil, "case e: no record from an aborted scan")
assert(Open(4005), "case e: aborted vendor must rescan on reopen")
PumpToEnd()
assert(saveCount == 1, "case e: the rescan saves once")
assert(Record(4005).scanConfidence == "confirmed", "case e: completed rescan is confirmed")
Close()

print("hs498_scan_rescan_and_slot_count: all cases ok")
