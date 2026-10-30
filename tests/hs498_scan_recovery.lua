-- luacheck: globals assert loadfile print io time Enum CreateFrame UnitGUID UnitName UnitFactionGroup GetLocale GetSubZoneText GetRealZoneText C_Map C_Item C_MerchantFrame C_Timer GetMerchantNumItems GetMerchantItemLink GetMerchantItemID

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Slots that return no data are read again, a bounded number of times
-- and only after a wait, before the scan is saved. A scan that still ends short
-- is saved unknown and, in a dev build, says so in chat. A new merchant opening
-- ends a running or waiting scan. Drives the real DecorClassifier,
-- ScanPersistence and VendorScanner through the captured frame handlers.
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

local frames = {}
local registrations = {}
CreateFrame = function()
    local frame = { shown = false, scripts = {} }
    function frame:RegisterEvent(event) registrations[#registrations + 1] = event end
    function frame:SetScript(name, handler) self.scripts[name] = handler end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    frames[#frames + 1] = frame
    return frame
end

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

-- slots[i] = { id = number|nil, info = table|false }: a nil id is no link, and
-- info == false makes GetItemInfo return nil.
local slots = {}
local linkReads = {}
local numItemsCalls = 0
GetMerchantNumItems = function()
    numItemsCalls = numItemsCalls + 1
    return #slots
end
GetMerchantItemLink = function(i)
    linkReads[#linkReads + 1] = i
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
local nonHousing = {}
C_Item = {
    GetItemInfoInstant = function(link)
        local id = tonumber(link:match("item:(%d+)"))
        if nonHousing[id] then
            return id, nil, nil, nil, nil, 2, 0
        end
        return id, nil, nil, nil, nil, Enum.ItemClass.Housing, Enum.ItemHousingSubclass.Decor
    end,
    RequestLoadItemDataByID = function() error("no item requests by ID") end,
}

local debugLines = {}
local chat = {}
local knownVendors = {}
local function Join(...)
    local parts = { ... }
    for i = 1, #parts do parts[i] = tostring(parts[i]) end
    return table.concat(parts, " ")
end
local HA = {
    Addon = {
        db = {
            profile = { vendorScanning = { enabled = true }, debug = false },
            global = { vendorNameByLocale = {}, scannedVendors = {} },
        },
        Print = function(_, ...)
            chat[#chat + 1] = Join(...)
        end,
        RegisterModule = function() end,
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
-- Debug prints through Print only in debug mode, like the real one.
function HA.Addon:Debug(...)
    local text = Join(...)
    debugLines[#debugLines + 1] = text
    if self.db.profile.debug then
        chat[#chat + 1] = "[Debug] " .. text
    end
end

assert(loadfile(root .. "/Modules/DecorClassifier.lua"))("Homestead", HA)
assert(loadfile(root .. "/Modules/ScanPersistence.lua"))("Homestead", HA)
assert(loadfile(root .. "/Modules/VendorScanner.lua"))("Homestead", HA)

local SP = HA.ScanPersistence
local realSave = SP.SaveVendorData
local saveCount = 0
local lastScan = nil
SP.SaveVendorData = function(self, scanData)
    saveCount = saveCount + 1
    lastScan = scanData
    return realSave(self, scanData)
end

HA.VendorScanner:Initialize()
local scanFrame, eventFrame = frames[1], frames[2]
assert(#frames == 2, "Initialize must create exactly two frames")
assert(scanFrame.scripts.OnUpdate and eventFrame.scripts.OnEvent, "frame scripts not captured")
assert(#registrations == 3 and registrations[1] == "MERCHANT_SHOW" and registrations[2] == "MERCHANT_UPDATE"
    and registrations[3] == "MERCHANT_CLOSED", "exactly the three merchant events are registered")

-------------------------------------------------------------------------------
-- Harness
-------------------------------------------------------------------------------

local function Fire(event) eventFrame.scripts.OnEvent(eventFrame, event) end
local function Show(npcID)
    currentNpc = npcID
    Fire("MERCHANT_SHOW")
end
local function Update() Fire("MERCHANT_UPDATE") end
local function Open(npcID)
    Show(npcID)
    Update()
    return scanFrame.shown
end
local function Close() Fire("MERCHANT_CLOSED") end

-- One frame of the scan handler. Returns how many slots it read, and which.
local function Tick(dt)
    local before = #linkReads
    scanFrame.scripts.OnUpdate(scanFrame, dt or 0.0625)
    local read = {}
    for i = before + 1, #linkReads do read[#read + 1] = linkReads[i] end
    return #read, read
end

local function Walk(n)
    for _ = 1, math.ceil(n / 5) do Tick(0.0625) end
end

local function RunOut()
    local guard = 0
    while scanFrame.shown do
        Tick(0.5)
        guard = guard + 1
        assert(guard < 400, "scan never finished")
    end
end

-- Frames delivered after a scan ended; in game a hidden frame gets none, so
-- this is the stronger form.
local function Quiet()
    for _ = 1, 20 do scanFrame.scripts.OnUpdate(scanFrame, 0.25) end
end

local function AllTimers()
    local snapshot = {}
    for i = 1, #timers do snapshot[i] = timers[i] end
    for i = 1, #snapshot do snapshot[i]() end
end

local function Fill(n, base)
    slots = {}
    for i = 1, n do slots[i] = { id = (base or 9000) + i, info = {} } end
end

local function Rec(npcID) return HA.Addon.db.global.scannedVendors[npcID] end

local function LastScanLine()
    for i = #debugLines, 1, -1 do
        if debugLines[i]:find("^Scan complete:") then return debugLines[i] end
    end
end

local function Notices()
    local out = {}
    for _, line in ipairs(chat) do
        if line:find("scan incomplete", 1, true) then out[#out + 1] = line end
    end
    return out
end

local function Eq(actual, expected, message)
    if actual ~= expected then
        error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function SlotList(list)
    local parts = {}
    for i = 1, #list do parts[i] = tostring(list[i]) end
    return table.concat(parts, ",")
end

local function HousingRows(slot)
    local out = {}
    for _, row in ipairs(lastScan.housingItems) do
        if row.merchantSlot == slot then out[#out + 1] = row end
    end
    return out
end

local function RowsWithItem(list, itemID)
    local n = 0
    for _, row in ipairs(list) do
        if row.itemID == itemID then n = n + 1 end
    end
    return n
end

local function ResetCounters()
    saveCount = 0
    lastScan = nil
    linkReads = {}
    numItemsCalls = 0
    chat = {}
    debugLines = {}
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

-------------------------------------------------------------------------------
-- Cases
-------------------------------------------------------------------------------

-- T13. Every slot complete at the walk: no wait, no re-read, no total read, the
-- tip's debug text, no notice.
do
    ResetCounters()
    Fill(14)
    Show(4101)
    local timersAfterShow = #timers
    Update()
    local callsAtStart = numItemsCalls
    Eq(Tick(), 5, "T13 first tick")
    Eq(Tick(), 5, "T13 second tick")
    Eq(saveCount, 0, "T13 no save before the last batch")
    Eq(Tick(), 4, "T13 third tick")
    Eq(saveCount, 1, "T13 saved on the walk-end frame")
    Eq(numItemsCalls, callsAtStart, "T13 no slot total read after the scan started")
    Eq(#timers, timersAfterShow, "T13 no timer queued")
    Eq(LastScanLine(), "Scan complete: 14/14 slots recorded, 14 housing items", "T13 debug line")
    Eq(#Notices(), 0, "T13 no notice on a confirmed scan")
    Eq(Rec(4101).scanConfidence, "confirmed", "T13 confidence")
    Close()
end

-- T2. Slots 11-14 fill after the walk; nothing is read before 0.5 s.
do
    ResetCounters()
    Fill(14)
    for i = 11, 14 do slots[i].id = nil end
    assert(Open(4102), "T2 scan must start")
    Walk(14)
    Eq(saveCount, 0, "T2 nothing saved at the walk end")
    assert(scanFrame.shown, "T2 scan still active in the wait")
    Eq(Tick(0.25), 0, "T2 read during the wait (0.25)")
    Eq(Tick(0.125), 0, "T2 read during the wait (0.375)")
    Eq(Tick(0.0625), 0, "T2 read during the wait (0.4375)")
    for i = 11, 14 do slots[i] = { id = 9000 + i, info = {} } end
    local count, read = Tick(0.0625)
    Eq(count, 4, "T2 pass size")
    Eq(SlotList(read), "11,12,13,14", "T2 slots re-read")
    Eq(saveCount, 1, "T2 one save")
    Eq(Rec(4102).scanConfidence, "confirmed", "T2 confidence")
    Eq(Rec(4102).itemCount, 14, "T2 itemCount")
    Eq(Rec(4102).slotCount, 14, "T2 slotCount")
    for i, row in ipairs(lastScan.housingItems) do
        Eq(row.merchantSlot, i, "T2 housing rows in slot order")
    end
    Eq(#lastScan.housingItems, 14, "T2 housing rows")
    local line = LastScanLine()
    assert(line:find("1 re-read pass(es), 4 slot(s) recovered", 1, true), "T2 recovered text: " .. line)
    assert(not line:find("rescan", 1, true), "T2 no rescan text: " .. line)
    Eq(#Notices(), 0, "T2 no notice")
    Close()
    assert(not Open(4102), "T2 a recovered vendor must not rescan on reopen")
    Close()
end

-- T3a. A link without info is upgraded in place, not inserted twice.
do
    ResetCounters()
    Fill(6)
    slots[3].info = false
    assert(Open(4103), "T3a scan must start")
    Walk(6)
    slots[3].info = {}
    Eq(Tick(0.25), 0, "T3a read during the wait")
    local count, read = Tick(0.25)
    Eq(count, 1, "T3a pass size")
    Eq(SlotList(read), "3", "T3a slot re-read")
    Eq(saveCount, 1, "T3a one save")
    Eq(Rec(4103).scanConfidence, "confirmed", "T3a confidence")
    Eq(#lastScan.allItems, 6, "T3a all-items rows")
    Eq(#HousingRows(3), 1, "T3a one housing row for slot 3")
    Eq(HousingRows(3)[1].price, 100, "T3a row carries the price")
    Close()
end

-- T3b. Empty on the walk, a link without info on pass 1, info on pass 2.
do
    ResetCounters()
    Fill(6)
    slots[3].id = nil
    assert(Open(4104), "T3b scan must start")
    Walk(6)
    slots[3] = { id = 9003, info = false }
    Tick(0.5)
    slots[3].info = {}
    Tick(0.5)
    Eq(saveCount, 1, "T3b one save")
    Eq(Rec(4104).scanConfidence, "confirmed", "T3b confidence")
    Eq(#lastScan.housingItems, 6, "T3b housing rows")
    for i, row in ipairs(lastScan.housingItems) do
        Eq(row.merchantSlot, i, "T3b housing rows sorted by slot")
    end
    Eq(HousingRows(3)[1].price, 100, "T3b row upgraded")
    local line = LastScanLine()
    assert(line:find("2 re-read pass(es), 1 slot(s) recovered", 1, true), "T3b recovered text: " .. line)
    Close()
end

-- T4. Nothing ever fills: six passes of five reads a frame, one save at the end.
do
    ResetCounters()
    Fill(12)
    for _, i in ipairs({ 2, 9, 10, 11, 12 }) do slots[i].id = nil end
    slots[7].info = false
    assert(Open(4105), "T4 scan must start")
    Walk(12)
    local readsAfterWalk = #linkReads
    for pass = 1, 6 do
        Eq(Tick(0.25), 0, "T4 pass " .. pass .. " wait 0.25")
        Eq(Tick(0.125), 0, "T4 pass " .. pass .. " wait 0.375")
        Eq(Tick(0.0625), 0, "T4 pass " .. pass .. " wait 0.4375")
        Eq(saveCount, 0, "T4 no save before pass 6 ends")
        local count, read = Tick(0.0625)
        Eq(count, 5, "T4 pass " .. pass .. " first batch")
        Eq(SlotList(read), "2,7,9,10,11", "T4 pass " .. pass .. " first batch slots")
        local count2, read2 = Tick(0.0625)
        Eq(count2, 1, "T4 pass " .. pass .. " second batch")
        Eq(SlotList(read2), "12", "T4 pass " .. pass .. " second batch slot")
        if pass < 6 then
            Eq(saveCount, 0, "T4 no save after pass " .. pass)
        end
    end
    Eq(saveCount, 1, "T4 one save after pass 6")
    Eq(#linkReads - readsAfterWalk, 36, "T4 re-read link reads")
    local readsAtEnd = #linkReads
    for _ = 1, 20 do Tick(0.25) end
    Eq(#linkReads, readsAtEnd, "T4 nothing read after the scan ended")
    Eq(Rec(4105).scanConfidence, "unknown", "T4 confidence")
    Eq(Rec(4105).itemCount, 7, "T4 itemCount")
    Eq(Rec(4105).slotCount, 12, "T4 slotCount")
    Eq(#HousingRows(7), 1, "T4 slot 7 housing rows")
    Eq(RowsWithItem(lastScan.allItems, 9007), 1, "T4 slot 7 all-items rows")
    Eq(LastScanLine(), "Scan complete: 7/12 slots recorded, 7 housing items, 6 slot(s) returned no data; will rescan on reopen; "
        .. "6 re-read pass(es), 0 slot(s) recovered; not complete: 2, 7, 9-12; ended: bound reached", "T4 debug line")
    local notices = Notices()
    Eq(#notices, 1, "T4 one notice")
    Eq(notices[1], "Test Vendor 4105 scan incomplete (6 of 12 slots complete). Reopen the vendor to finish.", "T4 notice")
    Close()
    assert(Open(4105), "T4 an unknown vendor scans on reopen")
    RunOut()
    Close()
end

-- T18. The wait is counted on every frame, not only frames past the 0.01 s
-- throttle: at 1/128 s frames it still lasts 0.5 s.
do
    ResetCounters()
    Fill(12)
    for i = 7, 12 do slots[i].id = nil end
    assert(Open(4106), "T18 scan must start")
    Walk(12)
    for tick = 1, 63 do
        Eq(Tick(1 / 128), 0, "T18 frame " .. tick .. " of the wait")
    end
    Eq(Tick(1 / 128), 5, "T18 pass starts on frame 64")
    Eq(Tick(1 / 128), 0, "T18 throttled frame")
    Eq(Tick(1 / 128), 1, "T18 second batch")
    RunOut()
    Close()
end

-- T5. A close during the re-reads saves what was read; no later callback or
-- frame touches a newer scan.
do
    ResetCounters()
    Fill(10)
    slots[4].info = false
    for _, i in ipairs({ 6, 8, 10 }) do slots[i].id = nil end
    local timersBefore = #timers
    assert(Open(4107), "T5 scan must start")
    Walk(10)
    slots[6] = { id = 9006, info = {} }
    slots[8] = { id = 9008, info = false }
    Tick(0.5)
    Tick(0.25)
    Eq(saveCount, 0, "T5 nothing saved yet")
    Close()
    Eq(saveCount, 1, "T5 one save at the close")
    Eq(#timers - timersBefore, 1, "T5 only the fallback timer was queued")
    Eq(#lastScan.housingItems, 9, "T5 housing rows")
    for i, row in ipairs(lastScan.housingItems) do
        Eq(row.merchantSlot, i, "T5 housing rows sorted by slot")
    end
    Eq(HousingRows(4)[1].price, nil, "T5 slot 4 has no price")
    Eq(HousingRows(8)[1].price, nil, "T5 slot 8 has no price")
    Eq(HousingRows(6)[1].price, 100, "T5 slot 6 has its price")
    Eq(Rec(4107).scanConfidence, "unknown", "T5 confidence")
    Eq(Rec(4107).itemCount, 9, "T5 itemCount")
    local line = LastScanLine()
    assert(line:find("not complete: 4, 8, 10; ended: merchant closed", 1, true), "T5 line: " .. line)
    local notices = Notices()
    Eq(#notices, 1, "T5 one notice")
    assert(notices[1]:find("(7 of 10 slots complete)", 1, true), "T5 notice: " .. notices[1])

    -- Another vendor's slots are present; every callback and frame delivered
    -- now reads nothing.
    Fill(20, 5000)
    local readsBefore, callsBefore, savesBefore = #linkReads, numItemsCalls, saveCount
    AllTimers()
    Quiet()
    Eq(#linkReads, readsBefore, "T5 stale: no slot read")
    Eq(numItemsCalls, callsBefore, "T5 stale: no total read")
    Eq(saveCount, savesBefore, "T5 stale: no save")

    -- A newer scan of the same vendor in its own wait is not advanced by them.
    Fill(10)
    slots[10].id = nil
    assert(Open(4107), "T5 the vendor scans again")
    Walk(10)
    Tick(0.25)
    readsBefore = #linkReads
    AllTimers()
    Eq(#linkReads, readsBefore, "T5 stale: callbacks read nothing for the newer scan")
    Eq(Tick(0.125), 0, "T5 newer scan still waiting")
    Eq(Tick(0.125), 1, "T5 newer scan starts its pass at its own 0.5 s")
    RunOut()
    Eq(#linkReads - readsBefore, 6, "T5 newer scan makes six passes")
    Eq(saveCount, 2, "T5 second save")
    Close()
end

-- T5c. A link without info is kept even when the scan closes before any pass.
do
    ResetCounters()
    Fill(6)
    slots[3].info = false
    assert(Open(4108), "T5c scan must start")
    Walk(6)
    Tick(0.25)
    Close()
    Eq(#lastScan.allItems, 6, "T5c all-items rows")
    Eq(#lastScan.housingItems, 6, "T5c housing rows")
    Eq(Rec(4108).itemCount, 6, "T5c itemCount")
    Eq(Rec(4108).scanConfidence, "unknown", "T5c confidence")
end

-- T5d. A close between two batches of a pass keeps the slots already read and
-- leaves the ones the pass had not reached not complete.
do
    ResetCounters()
    Fill(12)
    for i = 7, 12 do slots[i].id = nil end
    assert(Open(5109), "T5d scan must start")
    Walk(12)
    slots[7] = { id = 9007, info = {} }
    Eq(Tick(0.5), 5, "T5d the pass reads its first batch")
    assert(scanFrame.shown, "T5d the scan is mid-pass")
    Close()
    Eq(saveCount, 1, "T5d one save at the close")
    Eq(Rec(5109).scanConfidence, "unknown", "T5d confidence")
    Eq(#lastScan.housingItems, 7, "T5d housing rows")
    Eq(#HousingRows(7), 1, "T5d the recovered slot has its row")
    local line = LastScanLine()
    assert(line:find("1 re-read pass(es), 1 slot(s) recovered; not complete: 8-12; ended: merchant closed", 1, true),
        "T5d line: " .. line)
    Eq(Notices()[1], "Test Vendor 5109 scan incomplete (7 of 12 slots complete). Reopen the vendor to finish.", "T5d notice")
end

-- T10. The slot total is checked before each pass and when the re-reads end.
do
    ResetCounters()
    Fill(5)
    slots[5].id = nil
    assert(Open(4109), "T10 i scan must start")
    Walk(5)
    slots[5] = { id = 9005, info = {} }
    slots[6] = { id = 9006, info = {} }
    Eq(Tick(0.5), 0, "T10 i no slot read")
    Eq(saveCount, 1, "T10 i one save")
    Eq(Rec(4109).scanConfidence, "unknown", "T10 i confidence")
    Eq(LastScanLine(), "Scan complete: 4/5 slots recorded, 4 housing items, 1 slot(s) returned no data; will rescan on reopen; "
        .. "0 re-read pass(es), 0 slot(s) recovered; not complete: 5; ended: slot total changed (5 -> 6)", "T10 i line")
    Eq(Notices()[1], "Test Vendor 4109 scan incomplete (4 of 5 slots complete; slot total changed 5 -> 6). Reopen the vendor to finish.", "T10 i notice")
    Close()

    ResetCounters()
    Fill(6)
    slots[3].id = nil
    assert(Open(4110), "T10 ii scan must start")
    Walk(6)
    Eq(Tick(0.5), 1, "T10 ii pass 1 reads slot 3")
    slots[6] = nil
    slots[3] = { id = 9003, info = {} }
    Eq(Tick(0.5), 0, "T10 ii no slot read at pass 2")
    Eq(saveCount, 1, "T10 ii one save")
    Eq(Rec(4110).scanConfidence, "unknown", "T10 ii confidence")
    Eq(LastScanLine(), "Scan complete: 5/6 slots recorded, 5 housing items, 1 slot(s) returned no data; will rescan on reopen; "
        .. "1 re-read pass(es), 0 slot(s) recovered; not complete: 3; ended: slot total changed (6 -> 5)", "T10 ii line")
    Eq(Notices()[1], "Test Vendor 4110 scan incomplete (5 of 6 slots complete; slot total changed 6 -> 5). Reopen the vendor to finish.", "T10 ii notice")
    Close()

    ResetCounters()
    Fill(5)
    slots[5].id = nil
    assert(Open(4111), "T10 iii scan must start")
    Walk(5)
    slots = {}
    Eq(Tick(0.5), 0, "T10 iii no slot read")
    Eq(saveCount, 1, "T10 iii one save")
    Eq(#lastScan.allItems, 4, "T10 iii rows kept")
    assert(LastScanLine():find("ended: slot total changed (5 -> 0)", 1, true), "T10 iii line: " .. LastScanLine())
    Close()

    ResetCounters()
    Fill(12)
    for i = 7, 12 do slots[i].id = nil end
    assert(Open(4112), "T10 iv scan must start")
    Walk(12)
    for i = 7, 12 do slots[i] = { id = 9000 + i, info = {} } end
    Eq(Tick(0.5), 5, "T10 iv pass 1 reads five")
    slots[13] = { id = 9013, info = {} }
    Eq(Tick(0.0625), 1, "T10 iv last slot read")
    Eq(saveCount, 1, "T10 iv one save")
    Eq(Rec(4112).scanConfidence, "unknown", "T10 iv confidence")
    Eq(Rec(4112).itemCount, 12, "T10 iv itemCount")
    Eq(LastScanLine(), "Scan complete: 12/12 slots recorded, 12 housing items; will rescan on reopen; "
        .. "1 re-read pass(es), 6 slot(s) recovered; ended: slot total changed (12 -> 13)", "T10 iv line")
    Eq(Notices()[1], "Test Vendor 4112 scan incomplete (12 of 12 slots complete; slot total changed 12 -> 13). Reopen the vendor to finish.", "T10 iv notice")
    Close()

    ResetCounters()
    for attempt = 1, 3 do
        Fill(6)
        slots[6].id = nil
        assert(Open(4113), "T10 cap scan " .. attempt .. " must start")
        Walk(6)
        slots[7] = { id = 9007, info = {} }
        Tick(0.5)
        Close()
    end
    local notices = Notices()
    Eq(#notices, 3, "T10 cap notices")
    Eq(notices[3], "Test Vendor 4113 scan incomplete (5 of 6 slots complete; slot total changed 6 -> 7). Rescans stopped for this session; /reload to scan again.", "T10 cap notice")
    Fill(6)
    assert(not Open(4113), "T10 cap: the capped vendor must not scan again")
    Close()
end

-- T14. MERCHANT_UPDATE, the clear command and the scanning setting do not
-- disturb a scan in its re-reads.
do
    ResetCounters()
    Fill(12)
    for i = 6, 12 do slots[i].id = nil end
    assert(Open(4114), "T14 a scan must start")
    Walk(12)
    Update()
    Eq(Tick(0.25), 0, "T14 a read during the wait")
    Update()
    Eq(Tick(0.125), 0, "T14 a read during the wait (0.375)")
    Eq(Tick(0.0625), 0, "T14 a the wait is not shortened")
    Eq(Tick(0.0625), 5, "T14 a pass starts at 0.5 s")
    Update()
    Eq(Tick(0.0625), 2, "T14 a the pass finishes its remaining slots")
    RunOut()
    Close()

    ResetCounters()
    Fill(6)
    slots[6].id = nil
    assert(Open(4115), "T14 b scan must start")
    Walk(6)
    HA.VendorScanner:ClearScannedData()
    RunOut()
    Eq(saveCount, 1, "T14 b the scan still saved")
    assert(Rec(4115) ~= nil, "T14 b the record landed")
    Close()
    assert(Open(4115), "T14 b the next open scans")
    RunOut()
    Close()

    ResetCounters()
    Fill(6)
    slots[6].id = nil
    assert(Open(4116), "T14 c scan must start")
    Walk(6)
    HA.Addon.db.profile.vendorScanning.enabled = false
    RunOut()
    HA.Addon.db.profile.vendorScanning.enabled = true
    Eq(saveCount, 1, "T14 c the scan still saved")
    Close()
end

-- T15. A re-read that reports another item, or another classification, never
-- overwrites the row the walk recorded and never completes the slot.
do
    ResetCounters()
    Fill(6)
    slots[3].info = false
    assert(Open(4117), "T15 scan must start")
    Walk(6)
    slots[3] = { id = 9999, info = {} }
    RunOut()
    Eq(Rec(4117).scanConfidence, "unknown", "T15 confidence")
    assert(LastScanLine():find("0 slot(s) recovered", 1, true), "T15 a changed slot is not recovered: " .. LastScanLine())
    Eq(#HousingRows(3), 1, "T15 one row for slot 3")
    Eq(HousingRows(3)[1].itemID, 9003, "T15 the walk's row is kept")
    Eq(HousingRows(3)[1].price, nil, "T15 the row gained no price")
    Eq(RowsWithItem(lastScan.allItems, 9999), 0, "T15 no all-items row for the other item")
    Eq(RowsWithItem(lastScan.housingItems, 9999), 0, "T15 no housing row for the other item")
    Close()

    ResetCounters()
    Fill(6)
    slots[3].info = false
    assert(Open(4118), "T15b scan must start")
    Walk(6)
    slots[3] = { id = 9999, info = {} }
    Tick(0.5)
    slots[3] = { id = 9003, info = {} }
    RunOut()
    Eq(Rec(4118).scanConfidence, "unknown", "T15b a changed slot stays not complete")
    Eq(HousingRows(3)[1].price, nil, "T15b the row gained no price")
    Close()

    ResetCounters()
    Fill(6)
    slots[3].info = false
    assert(Open(4119), "T15c scan must start")
    Walk(6)
    nonHousing[9003] = true
    slots[3].info = {}
    RunOut()
    nonHousing[9003] = nil
    Eq(Rec(4119).scanConfidence, "unknown", "T15c confidence")
    Eq(#HousingRows(3), 1, "T15c the housing row is kept")
    Eq(HousingRows(3)[1].price, nil, "T15c the housing row gained no price")
    Close()

    ResetCounters()
    Fill(6)
    slots[3].info = false
    nonHousing[9003] = true
    assert(Open(4120), "T15d scan must start")
    Walk(6)
    nonHousing[9003] = nil
    slots[3].info = {}
    RunOut()
    Eq(Rec(4120).scanConfidence, "unknown", "T15d confidence")
    Eq(#lastScan.housingItems, 5, "T15d housing rows")
    Eq(#lastScan.allItems, 6, "T15d all-items rows")
    Close()
end

-- T17. The list of slots in the scan line is bounded.
do
    ResetCounters()
    Fill(40)
    for i = 1, 39, 2 do slots[i].id = nil end
    assert(Open(4121), "T17 scan must start")
    Walk(40)
    RunOut()
    assert(LastScanLine():find("not complete: 1, 3, 5, 7, 9, 11, 13, 15, 17, 19, +10 more; ended: bound reached", 1, true),
        "T17 line: " .. LastScanLine())
    Close()

    ResetCounters()
    slots = {}
    for i = 1, 200 do slots[i] = { id = nil, info = {} } end
    assert(Open(4122), "T17 200 slots scan must start")
    Walk(200)
    RunOut()
    assert(LastScanLine():find("not complete: 1-200; ended: bound reached", 1, true), "T17 200 line: " .. LastScanLine())
    Close()
end

-- T6. The notice follows the scan, not the save branch, and ignores debug mode.
do
    ResetCounters()
    SeedFiveItemRecord(4201)
    Fill(5)
    slots[4].id, slots[5].id = nil, nil
    assert(Open(4201), "T6a scan must start")
    Walk(5)
    RunOut()
    Eq(#Rec(4201).items, 5, "T6a the larger record is preserved")
    assert(Rec(4201).lastScanAttempt ~= nil, "T6a the attempt is recorded")
    Eq(#chat, 1, "T6a exactly one chat line")
    assert(Notices()[1]:find("(3 of 5 slots complete)", 1, true), "T6a notice: " .. tostring(Notices()[1]))
    Close()

    for index, shipped in ipairs({ true, false }) do
        local npcID = 4201 + index
        ResetCounters()
        knownVendors[npcID] = shipped or nil
        slots = {}
        for i = 1, 5 do slots[i] = { id = nil, info = {} } end
        assert(Open(npcID), "T6c scan must start")
        Walk(5)
        RunOut()
        Eq(Rec(npcID), nil, "T6c nothing stored for a vendor with no link anywhere")
        Eq(#Notices(), 1, "T6c one notice")
        assert(Notices()[1]:find("(0 of 5 slots complete)", 1, true), "T6c notice: " .. Notices()[1])
        Close()
    end
end

-- T6d. A scan that ends short in its re-read phase with no housing rows, at a
-- known vendor with a saved record, moves the record's map and coords together
-- when the scan has its own position, and changes nothing else about what was
-- observed. Every other case here stubs the map to nil, so this one gives it a
-- map and a position.
do
    local mapA, mapB = 1000, 2351
    local function PositionedVendor(npcID, finish)
        ResetCounters()
        knownVendors[npcID] = true
        SeedFiveItemRecord(npcID)
        local seeded = Rec(npcID)
        seeded.mapID, seeded.coords = mapA, { x = 0.4, y = 0.6 }
        seeded.lastScanned = 500
        local seededItems, seededCount, seededHousing = seeded.items, #seeded.items, seeded.housingCount
        local seededConfidence = seeded.scanConfidence
        Eq(seededConfidence, "confirmed", "T6d seed is confirmed")

        local savedMap = C_Map
        C_Map = {
            GetBestMapForUnit = function() return mapB end,
            GetPlayerMapPosition = function() return { x = 0.25, y = 0.75 } end,
            GetMapInfo = function(id)
                if id == mapB then return { name = "Map B", parentMapID = 2274, mapType = 3 } end
                if id == 2274 then return { name = "Continent", parentMapID = 0, mapType = Enum.UIMapType.Continent } end
                return nil
            end,
        }
        slots = {}
        for i = 1, 5 do slots[i] = { id = nil, info = {} } end
        local started = Open(npcID)
        C_Map = savedMap
        assert(started, "T6d scan must start")
        Walk(5)
        Tick(0.25)
        assert(scanFrame.shown, "T6d scan is waiting to re-read")
        Eq(saveCount, 0, "T6d no save before the end")
        finish()

        Eq(saveCount, 1, "T6d exactly one save")
        local record = Rec(npcID)
        assert(record == seeded, "T6d the stored record is the seeded table")
        Eq(record.mapID, mapB, "T6d mapID is this scan's")
        Eq(record.coords.x, 0.25, "T6d coords.x is this scan's")
        Eq(record.coords.y, 0.75, "T6d coords.y is this scan's")
        Eq(record.parentMapID, 2274, "T6d parentMapID is this scan's")
        Eq(record.continentMapID, 2274, "T6d continentMapID is this scan's")
        Eq(table.concat(record.mapChain, ","), mapB .. ",2274", "T6d mapChain is this scan's")
        Eq(record.lastScanned, 500, "T6d lastScanned is not re-dated")
        assert(record.lastScanAttempt ~= nil and record.lastScanAttempt ~= 500, "T6d the attempt is recorded")
        assert(record.items == seededItems and #record.items == seededCount, "T6d items unchanged")
        Eq(record.itemCount, seeded.itemCount, "T6d itemCount unchanged")
        Eq(record.housingCount, seededHousing, "T6d housingCount unchanged")
        Eq(record.scanConfidence, seededConfidence, "T6d scanConfidence unchanged")
        Eq(#Notices(), 1, "T6d the notice is printed once")
        Eq(#chat, 1, "T6d exactly one chat line")
    end

    PositionedVendor(4271, function() Close() end)
    PositionedVendor(4272, function() Show(4273) end)
    Close()
end

-- T7. A new merchant opening ends a scan that is waiting to re-read, before the
-- setting and lock checks.
do
    local function FirstVendorInWait(npcID)
        ResetCounters()
        Fill(10)
        slots[9].id, slots[10].id = nil, nil
        assert(Open(npcID), "T7 first scan must start")
        Walk(10)
        Tick(0.25)
    end

    FirstVendorInWait(4210)
    Fill(6, 7000)
    local readsBefore = #linkReads
    Show(4211)
    Eq(#linkReads, readsBefore, "T7 i no slot read at the show")
    Eq(saveCount, 1, "T7 i one save at the show")
    Eq(#lastScan.allItems, 8, "T7 i only the first vendor's rows")
    Eq(lastScan.allItems[1].itemID, 9001, "T7 i first vendor's item IDs")
    assert(LastScanLine():find("ended: new merchant opened", 1, true), "T7 i line: " .. LastScanLine())
    assert(Notices()[1]:find("Test Vendor 4210", 1, true), "T7 i notice names the first vendor")
    Update()
    Walk(6)
    Eq(Rec(4211).scanConfidence, "confirmed", "T7 i second vendor confirmed")
    Eq(lastScan.allItems[1].itemID, 7001, "T7 i second vendor's own item IDs")
    Close()

    ResetCounters()
    Fill(6, 7100)
    assert(Open(4212), "T7 ii lock scan must start")
    Walk(6)
    Close()
    FirstVendorInWait(4213)
    Show(4212)
    Eq(saveCount, 1, "T7 ii the first scan ended at the show")
    assert(not scanFrame.shown, "T7 ii no second scan")
    readsBefore = #linkReads
    Update()
    Quiet()
    Eq(#linkReads, readsBefore, "T7 ii nothing read")
    Close()

    FirstVendorInWait(4214)
    HA.Addon.db.profile.vendorScanning.enabled = false
    Show(4215)
    HA.Addon.db.profile.vendorScanning.enabled = true
    Eq(saveCount, 1, "T7 iii the first scan ended with scanning off")
    Eq(#lastScan.allItems, 8, "T7 iii own rows")
    readsBefore = #linkReads
    AllTimers()
    Quiet()
    Eq(#linkReads, readsBefore, "T7 iii nothing read")
    Eq(Rec(4215), nil, "T7 iii no record for the second vendor")
    Close()
end

-- T8. A new merchant opening during the walk discards the scan.
do
    ResetCounters()
    Fill(12)
    assert(Open(4220), "T8 i scan must start")
    Tick()
    Fill(6, 7200)
    Show(4221)
    Eq(saveCount, 0, "T8 i no save")
    Eq(Rec(4220), nil, "T8 i no record")
    Eq(#Notices(), 0, "T8 i no notice")
    local aborted = 0
    for _, line in ipairs(debugLines) do
        if line:find("Scan aborted", 1, true) then aborted = aborted + 1 end
    end
    Eq(aborted, 1, "T8 i one abort line")
    Update()
    Walk(6)
    Eq(Rec(4221).scanConfidence, "confirmed", "T8 i second vendor scanned")
    Eq(lastScan.allItems[1].itemID, 7201, "T8 i second vendor's own item IDs")
    Close()
    Fill(12)
    assert(Open(4220), "T8 i the first vendor scans on its next open")
    Walk(12)
    Eq(Rec(4220).scanConfidence, "confirmed", "T8 i first vendor scanned later")
    Close()

    ResetCounters()
    Fill(6, 7300)
    assert(Open(4222), "T8 ii lock scan must start")
    Walk(6)
    Close()
    Fill(12)
    assert(Open(4223), "T8 ii scan must start")
    Tick()
    Show(4222)
    Eq(saveCount, 1, "T8 ii only the lock scan saved")
    Eq(Rec(4223), nil, "T8 ii no record")
    assert(not scanFrame.shown, "T8 ii no second scan")
    local readsBefore = #linkReads
    Update()
    Quiet()
    Eq(#linkReads, readsBefore, "T8 ii nothing read")
    Close()
end

-- T9 and T11a. The same vendor shown again, and the rescan cap.
do
    ResetCounters()
    Fill(12)
    assert(Open(4230), "T9 i scan must start")
    Tick()
    Show(4230)
    Update()
    Walk(12)
    Eq(saveCount, 1, "T9 i one save")
    Eq(Rec(4230).scanConfidence, "confirmed", "T9 i confidence")
    Eq(#lastScan.housingItems, 12, "T9 i twelve rows")
    Close()

    ResetCounters()
    Fill(10)
    slots[10].id = nil
    assert(Open(4231), "T9 ii scan must start")
    for ended = 1, 3 do
        Walk(10)
        Tick(0.25)
        Show(4231)
        Eq(saveCount, ended, "T9 ii save " .. ended)
        if ended < 3 then
            Update()
            assert(scanFrame.shown, "T9 ii a new scan starts after end " .. ended)
        end
    end
    local notices = Notices()
    Eq(#notices, 3, "T11 a three notices")
    Eq(notices[1], "Test Vendor 4231 scan incomplete (9 of 10 slots complete). Reopen the vendor to finish.", "T9 ii notice")
    Eq(notices[3], "Test Vendor 4231 scan incomplete (9 of 10 slots complete). Rescans stopped for this session; /reload to scan again.", "T11 a capped notice")
    assert(LastScanLine():find("rescanning stopped for this session", 1, true), "T11 a line: " .. LastScanLine())
    Update()
    assert(not scanFrame.shown, "T11 a the capped vendor does not scan again")
    Close()
end

-- TP. A second merchant opening releases a first vendor still waiting to start.
do
    ResetCounters()
    Fill(8)
    local timersBefore = #timers
    Show(4240)
    Show(4241)
    timers[timersBefore + 1]()
    assert(not scanFrame.shown, "TP i the first vendor's fallback starts nothing")
    Fill(6, 7400)
    Update()
    assert(scanFrame.shown, "TP i the second vendor scans")
    Walk(6)
    Eq(lastScan.npcID, 4241, "TP i scan under the second vendor's ID")
    Eq(lastScan.vendorName, "Test Vendor 4241", "TP i second vendor's name")
    Eq(lastScan.allItems[1].itemID, 7401, "TP i second vendor's items")
    Eq(Rec(4240), nil, "TP i no record for the first vendor")
    Close()
    Fill(8)
    assert(Open(4240), "TP i the first vendor scans on its next open")
    Walk(8)
    Eq(Rec(4240).scanConfidence, "confirmed", "TP i first vendor's own record")
    Close()

    ResetCounters()
    Fill(6, 7500)
    assert(Open(4242), "TP ii lock scan must start")
    Walk(6)
    Close()
    Fill(8)
    Show(4243)
    Show(4242)
    local readsBefore, savesBefore = #linkReads, saveCount
    Update()
    AllTimers()
    Quiet()
    assert(not scanFrame.shown, "TP ii nothing starts")
    Eq(#linkReads, readsBefore, "TP ii nothing read")
    Eq(saveCount, savesBefore, "TP ii nothing saved")
    Eq(Rec(4243), nil, "TP ii no record for the first vendor")
    assert(Open(4243), "TP ii the first vendor scans on its next open")
    Walk(8)
    Eq(lastScan.vendorName, "Test Vendor 4243", "TP ii first vendor's own name")
    Eq(lastScan.allItems[1].itemID, 9001, "TP ii first vendor's own items")
    Close()

    ResetCounters()
    Fill(8)
    Show(4244)
    HA.Addon.db.profile.vendorScanning.enabled = false
    Show(4245)
    Update()
    AllTimers()
    Quiet()
    HA.Addon.db.profile.vendorScanning.enabled = true
    assert(not scanFrame.shown, "TP iii nothing starts")
    Eq(#linkReads, 0, "TP iii nothing read")
    Eq(Rec(4244), nil, "TP iii no record for the first vendor")
    assert(Open(4244), "TP iii the first vendor scans once scanning is back on")
    Walk(8)
    Eq(saveCount, 1, "TP iii one save")
    Close()

    ResetCounters()
    Fill(8)
    timersBefore = #timers
    Show(4246)
    Show(4246)
    Eq(#timers - timersBefore, 2, "TP iv two timers queued")
    Update()
    assert(scanFrame.shown, "TP iv the update starts the scan")
    Walk(8)
    Eq(saveCount, 1, "TP iv one save")
    AllTimers()
    assert(not scanFrame.shown, "TP iv the timers start nothing")
    Eq(saveCount, 1, "TP iv still one save")
    Close()
    assert(not Open(4246), "TP iv the vendor stays locked")
    Close()
end

-- T11. The cap counts short scans however they end, and not recovered ones.
do
    local function ShortFill()
        Fill(6)
        slots[6].id = nil
    end

    ResetCounters()
    for _ = 1, 2 do
        ShortFill()
        assert(Open(4250), "T11 b short scan must start")
        Walk(6)
        RunOut()
        Close()
    end
    ShortFill()
    assert(Open(4250), "T11 b third scan must start")
    Walk(6)
    slots[6] = { id = 9006, info = {} }
    RunOut()
    Eq(Rec(4250).scanConfidence, "confirmed", "T11 b recovered")
    assert(not LastScanLine():find("rescan", 1, true), "T11 b no rescan text: " .. LastScanLine())
    Eq(#Notices(), 2, "T11 b no notice for the recovered scan")
    Close()
    assert(not Open(4250), "T11 b the lock is kept")
    Close()

    ResetCounters()
    ShortFill()
    assert(Open(4251), "T11 c scan must start")
    Walk(6)
    HA.VendorScanner:ClearScannedData()
    slots[6] = { id = 9006, info = {} }
    RunOut()
    Close()
    for k = 1, 3 do
        ShortFill()
        assert(Open(4251), "T11 c short scan " .. k .. " must start")
        Walk(6)
        RunOut()
        local line = LastScanLine()
        if k < 3 then
            assert(line:find("will rescan on reopen", 1, true), "T11 c scan " .. k .. ": " .. line)
        else
            assert(line:find("rescanning stopped for this session", 1, true), "T11 c scan 3: " .. line)
        end
        Close()
    end

    ResetCounters()
    for k = 1, 3 do
        ShortFill()
        assert(Open(4252), "T11 d scan " .. k .. " must start")
        Walk(6)
        Tick(0.25)
        Close()
        local line = LastScanLine()
        assert(line:find("ended: merchant closed", 1, true), "T11 d line " .. k .. ": " .. line)
        if k < 3 then
            assert(line:find("will rescan on reopen", 1, true), "T11 d scan " .. k .. ": " .. line)
        else
            assert(line:find("rescanning stopped for this session", 1, true), "T11 d scan 3: " .. line)
        end
    end
    ShortFill()
    assert(not Open(4252), "T11 d the fourth open does not scan")
    Close()
end

-- T12. What reaches chat under each combination of dev build and debug mode.
do
    local function Matching(pattern)
        local n = 0
        for _, line in ipairs(chat) do
            if line:find(pattern, 1, true) then n = n + 1 end
        end
        return n
    end
    local npcID = 4260
    local function Short(early)
        npcID = npcID + 1
        Fill(6)
        slots[6].id = nil
        assert(Open(npcID), "T12 scan must start")
        Walk(6)
        if early then
            Tick(0.25)
        else
            RunOut()
        end
        Close()
    end
    local function Confirmed()
        npcID = npcID + 1
        Fill(6)
        assert(Open(npcID), "T12 scan must start")
        Walk(6)
        Close()
    end

    for _, early in ipairs({ false, true }) do
        local tag = early and "closed in the re-reads" or "bound reached"
        ResetCounters()
        HA.DevAddon, HA.Addon.db.profile.debug = nil, false
        Short(early)
        Eq(#chat, 0, "T12 dev off, debug off (" .. tag .. ")")

        ResetCounters()
        HA.DevAddon, HA.Addon.db.profile.debug = nil, true
        Short(early)
        Eq(#chat, 2, "T12 dev off, debug on (" .. tag .. ")")
        assert(chat[1]:find("Scan complete:", 1, true) and chat[2]:find("Scanned vendor:", 1, true),
            "T12 dev off, debug on lines (" .. tag .. ")")

        ResetCounters()
        HA.DevAddon, HA.Addon.db.profile.debug = true, false
        Short(early)
        Eq(#chat, 1, "T12 dev on, debug off (" .. tag .. ")")
        assert(chat[1]:find("scan incomplete", 1, true) and not chat[1]:find("[Debug]", 1, true),
            "T12 dev on, debug off line (" .. tag .. ")")

        ResetCounters()
        HA.DevAddon, HA.Addon.db.profile.debug = true, true
        Short(early)
        Eq(Matching("scan incomplete"), 1, "T12 dev on, debug on notice (" .. tag .. ")")
        Eq(Matching("Scan complete:"), 1, "T12 dev on, debug on scan line (" .. tag .. ")")
    end

    ResetCounters()
    HA.DevAddon, HA.Addon.db.profile.debug = true, false
    Confirmed()
    Eq(#chat, 0, "T12 confirmed scan, dev on, debug off")

    ResetCounters()
    HA.DevAddon, HA.Addon.db.profile.debug = nil, true
    SeedFiveItemRecord(4290)
    Fill(5)
    slots[4].id, slots[5].id = nil, nil
    assert(Open(4290), "T12 protection scan must start")
    Walk(5)
    RunOut()
    Close()
    Eq(#chat, 3, "T12 dev off, debug on over a larger record")
    assert(chat[3]:find("Scan protection:", 1, true), "T12 third line: " .. tostring(chat[3]))
    HA.DevAddon, HA.Addon.db.profile.debug = true, false
end

print("hs498_scan_recovery: all cases ok")
