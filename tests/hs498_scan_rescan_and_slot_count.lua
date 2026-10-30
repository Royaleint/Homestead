-- luacheck: globals assert loadfile print io time Enum CreateFrame UnitGUID UnitName UnitFactionGroup GetLocale GetSubZoneText GetRealZoneText C_Map C_Item C_MerchantFrame C_Timer GetMerchantNumItems GetMerchantItemLink GetMerchantItemID

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- A scan that finishes with empty merchant slots is saved "unknown",
-- and the vendor must be scannable again on the next visit. A confirmed scan
-- keeps the once-per-session lock. The saved record also carries the slot
-- total. Drives the real DecorClassifier, ScanPersistence and VendorScanner
-- through the captured frame handlers. Also covers closing the window before
-- the scan starts, and the per-session rescan cap for vendors that keep
-- returning empty slots.
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

-- Timer callbacks are captured, never run on their own; a case runs the
-- closure its own MERCHANT_SHOW queued.
local timers = {}
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
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
local knownVendors = {}  -- npcIDs the stubbed shipped data knows about
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
        HasVendor = function(_, npcID) return knownVendors[npcID] == true end,
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

-- Show/Update split out of Open so a case can close before the update.
local function Show(npcID)
    currentNpc = npcID
    Fire("MERCHANT_SHOW")
end

local function Update() Fire("MERCHANT_UPDATE") end

local function ResetTimers() timers = {} end

local function EmptySlotFill(count)
    FillSlots(count)
    slots[count].id = nil
end

local function SeedFiveItemRecord(npcID)
    local items = {}
    for i = 1, 5 do
        items[i] = { itemID = 9000 + i, name = "Seed " .. i, subclassID = Enum.ItemHousingSubclass.Decor, merchantSlot = i }
    end
    realSave(SP, {
        npcID = npcID, vendorName = "Test Vendor " .. npcID, coords = { x = 0.5, y = 0.5 },
        housingItems = items, allItems = items, totalItems = 5, scanComplete = true, hadNilSlots = false,
    })
end

-- f. Empty slots on a vendor that already has a confirmed record: the record
--    and its date stay, the had-housing mark stays true, the attempt is
--    logged. Once with the vendor in shipped data, once without.
for _, shipped in ipairs({ true, false }) do
    local npcID = shipped and 4006 or 4007
    local label = "case f (" .. (shipped and "shipped" or "not shipped") .. "): "
    knownVendors[npcID] = shipped or nil
    SeedFiveItemRecord(npcID)
    local seedStamp = Record(npcID).lastScanned
    slots = {}
    for i = 1, 5 do slots[i] = { id = nil, info = {} } end
    assert(Open(npcID), label .. "first open must start a scan")
    PumpToEnd()
    assert(#Record(npcID).items == 5, label .. "items must be kept")
    assert(Record(npcID).lastScanned == seedStamp, label .. "lastScanned must not move")
    assert(Record(npcID).lastScanHadHousing == true, label .. "had-housing mark must stay true")
    assert(Record(npcID).lastScanAttempt ~= nil, label .. "the attempt must be recorded")
    Close()
end

-- g. Closed before the scan started (no update yet): the next full open scans
--    and saves once.
FillSlots(8)
saveCount = 0
ResetTimers()
Show(4008)
Close()
assert(not scanFrame.shown, "case g: nothing scanned yet")
assert(Open(4008), "case g: a vendor closed before its scan started must scan on reopen")
PumpToEnd()
assert(saveCount == 1, "case g: expected one save")
Close()

-- h. Show vendor, close, run that open's timer with slots now filled: no
--    scan and no save. A full open then scans.
FillSlots(8)
saveCount = 0
ResetTimers()
Show(4014)
Close()
timers[1]()
assert(not scanFrame.shown, "case h: a timer from a closed open must not start a scan")
assert(saveCount == 0, "case h: no save from the stale timer")
assert(Open(4014), "case h: a full open must scan")
PumpToEnd()
assert(saveCount == 1, "case h: expected one save")
Close()

-- i. Zero slots, several updates, then close: the leftover retry closure does
--    nothing even with slots filled, and a full open scans.
slots = {}
saveCount = 0
ResetTimers()
Show(4015)
Update()
Update()
Update()
assert(#timers == 4, "case i: the empty updates must queue four retry timers (one fallback, three retries)")
Close()
FillSlots(8)
timers[#timers]()
assert(not scanFrame.shown, "case i: a retry closure after close must not start a scan")
assert(saveCount == 0, "case i: no save from the retry closure")
assert(Open(4015), "case i: a full open must scan")
PumpToEnd()
assert(saveCount == 1, "case i: expected one save")
Close()

-- j. Rescan cap: three empty-slot scans of one vendor, the third says
--    rescanning stopped and the lock stays; another vendor is unaffected.
EmptySlotFill(6)
saveCount = 0
for attempt = 1, 3 do
    assert(Open(4010), "case j: scan " .. attempt .. " must start")
    PumpToEnd()
    local line = LastScanLine()
    if attempt < 3 then
        assert(line:find("will rescan on reopen", 1, true), "case j: scan " .. attempt .. " must say it will rescan: " .. line)
    else
        assert(line:find("rescanning stopped for this session", 1, true), "case j: scan 3 must say rescanning stopped: " .. line)
        assert(not line:find("will rescan", 1, true), "case j: scan 3 must not say it will rescan: " .. line)
    end
    Close()
end
assert(saveCount == 3, "case j: expected three saves")
assert(not Open(4010), "case j: the capped vendor must not scan a fourth time")
assert(saveCount == 3, "case j: no fourth save")
Close()
assert(Open(4016), "case j: another vendor still scans")
PumpToEnd()
assert(LastScanLine():find("will rescan on reopen", 1, true), "case j: another vendor's first empty scan still says it will rescan")
Close()

-- k. Show then close with no update on the capped vendor, then a full open:
--    the lock the cap holds is not released by the close.
FillSlots(6)
ResetTimers()
Show(4010)
Close()
assert(not Open(4010), "case k: a capped vendor must not rescan after a show and close")
Close()
-- Same for a vendor locked by a confirmed scan (case a).
FillSlots(7)
Show(4001)
Close()
assert(not Open(4001), "case k: a confirmed vendor must not rescan after a show and close")
Close()

-- l. Aborted scans do not count toward the cap. Each aborted scan had already
--    read an empty slot (slot 1) before the merchant closed.
FillSlots(12)
slots[1].id = nil
for _ = 1, 3 do
    assert(Open(4011), "case l: scan must start")
    Pump()
    Close()
end
assert(Open(4011), "case l: scan must start after the aborts")
PumpToEnd()
assert(LastScanLine():find("will rescan on reopen", 1, true), "case l: the first completed empty scan must still say it will rescan: " .. LastScanLine())
Close()

-- m. Both reset functions clear the counter.
for index, resetName in ipairs({ "ClearScannedData", "ClearAllData" }) do
    local npcID = 4020 + index
    EmptySlotFill(6)
    for _ = 1, 3 do
        assert(Open(npcID), "case m (" .. resetName .. "): scan must start")
        PumpToEnd()
        Close()
    end
    assert(not Open(npcID), "case m (" .. resetName .. "): vendor must be capped before the reset")
    Close()
    HA.VendorScanner[resetName](HA.VendorScanner)
    assert(Open(npcID), "case m (" .. resetName .. "): reset vendor must scan")
    PumpToEnd()
    assert(LastScanLine():find("will rescan on reopen", 1, true),
        "case m (" .. resetName .. "): first empty scan after the reset must say it will rescan: " .. LastScanLine())
    Close()
    assert(Open(npcID), "case m (" .. resetName .. "): reopen must scan")
    PumpToEnd()
    Close()
end

-- g2. Show, close, show the same vendor again: the first open's timer starts
--     the one scan, the second open's timer then does nothing.
FillSlots(8)
saveCount = 0
ResetTimers()
Show(4009)
Close()
Show(4009)
assert(#timers == 2, "case g2: each open must queue one timer")
local firstTimer, secondTimer = timers[1], timers[2]
firstTimer()
assert(scanFrame.shown, "case g2: the first open's timer must start the scan")
PumpToEnd()
assert(saveCount == 1, "case g2: expected one save")
secondTimer()
assert(not scanFrame.shown, "case g2: the second open's timer must not start another scan")
assert(saveCount == 1, "case g2: still one save after the second timer")
Close()

print("hs498_scan_rescan_and_slot_count: all cases ok")
