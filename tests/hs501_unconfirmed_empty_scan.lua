-- luacheck: globals assert loadfile print io loadstring time Enum

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- A scan with empty merchant slots can prove a housing item is there,
-- but never that none is. Only a confirmed scan (every slot read) may store
-- "had nothing" or re-date a record; an unconfirmed one writes lastScanAttempt
-- only. An unconfirmed scan that does see housing raises the had-housing
-- mark so a stale false mark cannot keep the vendor on the delist path.
--
-- Drives the real SaveVendorData and the real IsDelistCandidate body.
-------------------------------------------------------------------------------

local exportSource = assert(io.open(root .. "/Modules/ExportImport.lua", "r")):read("*a")
local functionText = exportSource:match(
    '(local function IsDelistCandidate%(vendor, npcID%).-\nend)')
assert(functionText ~= nil, "could not extract IsDelistCandidate function text from ExportImport.lua")

local knownNpcIDs = {}
local ExtractHA = {
    VendorData = {
        HasVendor = function(_, npcID) return knownNpcIDs[npcID] == true end,
    },
}
local IsDelistCandidate = assert(loadstring(
    "local _, HA = ...\n" .. functionText .. "\nreturn IsDelistCandidate",
    "IsDelistCandidate-extract"))("Homestead", ExtractHA)

local fakeClock = 5000
time = function() fakeClock = fakeClock + 1 return fakeClock end

Enum = { ItemHousingSubclass = { Decor = 0, Dye = 1, Room = 2 } }

local HA = {
    Addon = { db = { global = {} }, Debug = function() end },
    VendorData = {
        HasVendor = function(_, npcID) return knownNpcIDs[npcID] == true end,
        BuildScannedIndex = function() end,
        InvalidateVendorCaches = function() end,
    },
    CatalogStore = {
        SetRequirements = function() end, Save = function() end,
        BeginBatch = function() end, EndBatch = function() end,
    },
    Events = { Fire = function() end },
    DevAddon = true,
}
assert(loadfile(root .. "/Modules/ScanPersistence.lua"))("Homestead", HA)
local SP = HA.ScanPersistence

local function Items(subclassID, count, firstID)
    local items = {}
    for i = 1, count do
        items[i] = { itemID = firstID + i, name = "Item " .. (firstID + i),
            subclassID = subclassID, merchantSlot = i }
    end
    return items
end

local function Concat(a, b)
    local out = {}
    for _, item in ipairs(a) do out[#out + 1] = item end
    for _, item in ipairs(b) do out[#out + 1] = item end
    return out
end

local function Save(npcID, items, confirmed, coords, zone)
    SP:SaveVendorData({
        npcID = npcID, vendorName = "Vendor " .. npcID, mapID = 1,
        coords = coords or { x = 0.4, y = 0.4 }, zone = zone or "Zone One",
        faction = "Neutral", housingItems = items, allItems = items, totalItems = #items,
        scanComplete = true, hadNilSlots = not confirmed,
    })
end

local function Record(npcID) return HA.Addon.db.global.scannedVendors[npcID] end
local function IsDelist(npcID) return IsDelistCandidate(Record(npcID), npcID) end

local Decor, Room = Enum.ItemHousingSubclass.Decor, Enum.ItemHousingSubclass.Room

-- 1. Known vendor, confirmed record, then an unconfirmed zero scan from a
--    different spot: nothing is marked empty or re-dated, the attempt and the
--    new location are stored.
knownNpcIDs[300] = true
Save(300, Items(Decor, 5, 100), true)
local stamp = Record(300).lastScanned
Save(300, {}, false, { x = 0.7, y = 0.3 }, "Zone Two")
local r = Record(300)
assert(#r.items == 5, "case 1: items must be kept")
assert(r.lastScanned == stamp, "case 1: lastScanned must not move")
assert(r.lastScanHadHousing == true and r.lastScanHadDecor == true, "case 1: marks must stay true")
assert(r.lastScanAttempt ~= nil and r.lastScanAttempt ~= stamp, "case 1: the attempt must be recorded")
assert(r.scanConfidence == "confirmed", "case 1: confidence must stay confirmed")
assert(IsDelist(300) == false, "case 1: must not be a delist candidate")
assert(r.coords.x == 0.7 and r.coords.y == 0.3, "case 1: new coords must be stored")
assert(r.zone == "Zone Two", "case 1: new zone must be stored")

-- 2. Then an unconfirmed partial scan: still not a delist candidate. A
--    confirmed zero scan afterwards is.
Save(300, Items(Decor, 2, 100), false)
assert(IsDelist(300) == false, "case 2: a partial scan must not make it a delist candidate")
assert(Record(300).lastScanned == stamp, "case 2: lastScanned must not move")
assert(#Record(300).items == 5, "case 2: items must be kept")
Save(300, {}, true)
assert(IsDelist(300) == true, "case 2: a confirmed zero scan must be a delist candidate again")
assert(Record(300).lastScanned ~= stamp, "case 2: a confirmed zero scan re-dates")

-- 2b. A real confirmed zero scan followed by a partial scan that sees
--     housing: the mark is raised, the record is otherwise untouched.
knownNpcIDs[301] = true
Save(301, Items(Decor, 5, 200), true)
Save(301, {}, true)
local zeroStamp = Record(301).lastScanned
assert(IsDelist(301) == true, "case 2b: setup, confirmed zero scan delists")
Save(301, Items(Decor, 2, 200), false)
r = Record(301)
assert(IsDelist(301) == false, "case 2b: seeing housing must clear the delist candidate")
assert(r.lastScanned == zeroStamp, "case 2b: lastScanned must stay at the zero scan time")
assert(#r.items == 5 and r.itemCount == 5, "case 2b: items must be unchanged")
assert(r.scanConfidence == "confirmed", "case 2b: confidence must be unchanged")

-- 3. Hand-seeded false marks: an unconfirmed scan that sees decor raises
--    them. Second seed is the legacy shape (housing mark absent).
local function SeedKnown(npcID, marks)
    knownNpcIDs[npcID] = true
    local record = {
        npcID = npcID, name = "Vendor " .. npcID, mapID = 1,
        items = Items(Decor, 5, 300),
        decorCount = 5, hasDecor = true, housingCount = 5, hasHousing = true,
        itemCount = 5, lastScanned = 900, scanConfidence = "confirmed",
    }
    for key, value in pairs(marks) do record[key] = value end
    HA.Addon.db.global.scannedVendors[npcID] = record
end

SeedKnown(310, { lastScanHadHousing = false, lastScanHadDecor = false })
Save(310, Items(Decor, 2, 300), false)
r = Record(310)
assert(r.lastScanHadHousing == true and r.lastScanHadDecor == true, "case 3: both marks must be raised")
assert(r.lastScanned == 900 and #r.items == 5 and r.scanConfidence == "confirmed", "case 3: record otherwise unchanged")
assert(IsDelist(310) == false, "case 3: must not be a delist candidate")

SeedKnown(311, { lastScanHadDecor = false })
Record(311).hasHousing = nil
Record(311).housingCount = nil
assert(Record(311).lastScanHadHousing == nil, "case 3: legacy seed has no housing mark")
assert(IsDelist(311) == true, "case 3: legacy seed with a false decor mark delists before the scan")
Save(311, Items(Decor, 2, 300), false)
r = Record(311)
assert(r.lastScanHadHousing == true and r.lastScanHadDecor == true, "case 3: legacy seed marks must be raised")
assert(r.lastScanned == 900 and #r.items == 5, "case 3: legacy seed record otherwise unchanged")
assert(IsDelist(311) == false, "case 3: legacy seed must not be a delist candidate")

-- 4. Mixed record, unconfirmed scan sees one room plan only: the housing
--    mark rises, the decor mark is left alone whichever way it stood.
local function SeedMixed(npcID, decorMark)
    knownNpcIDs[npcID] = true
    HA.Addon.db.global.scannedVendors[npcID] = {
        npcID = npcID, name = "Vendor " .. npcID, mapID = 1,
        items = Concat(Items(Decor, 3, 400), Items(Room, 2, 450)),
        subclassCounts = { [Decor] = 3, [Room] = 2 },
        decorCount = 3, hasDecor = true, housingCount = 5, hasHousing = true,
        lastScanHadHousing = false, lastScanHadDecor = decorMark,
        itemCount = 5, lastScanned = 900, scanConfidence = "confirmed",
    }
end
SeedMixed(320, false)
Save(320, Items(Room, 1, 450), false)
assert(Record(320).lastScanHadHousing == true, "case 4: housing mark must be raised")
assert(Record(320).lastScanHadDecor == false, "case 4: decor mark must stay false when no decor was seen")
SeedMixed(321, true)
Save(321, Items(Room, 1, 450), false)
assert(Record(321).lastScanHadHousing == true, "case 4: housing mark must be raised (decor true seed)")
assert(Record(321).lastScanHadDecor == true, "case 4: decor mark must stay true when no decor was seen")

-- 5. Not in shipped data, record with housing, unconfirmed zero scan.
Save(330, Items(Decor, 3, 500), true)
local before = Record(330).lastScanned
Save(330, {}, false)
r = Record(330)
assert(r ~= nil and #r.items == 3, "case 5: record must be kept")
assert(r.lastScanned == before, "case 5: lastScanned must not move")
assert(r.lastScanHadHousing == true and r.lastScanHadDecor == true, "case 5: marks must stay true")
assert(r.lastScanAttempt ~= nil and r.lastScanAttempt ~= before, "case 5: the attempt must be recorded")

-- 6. Controls: a confirmed zero scan still re-dates and marks empty.
knownNpcIDs[340] = true
Save(340, Items(Decor, 4, 600), true)
before = Record(340).lastScanned
Save(340, {}, true)
r = Record(340)
assert(r.lastScanned ~= before, "case 6: confirmed zero scan on a known vendor must re-date")
assert(r.lastScanHadHousing == false and r.lastScanHadDecor == false, "case 6: marks must go false")
assert(#r.items == 4, "case 6: items must be kept")
assert(IsDelist(340) == true, "case 6: must be a delist candidate")

Save(341, Items(Decor, 4, 700), true)
before = Record(341).lastScanned
Save(341, {}, true)
r = Record(341)
assert(r ~= nil and r.lastScanned ~= before, "case 6: confirmed zero scan on a previously-stocked vendor must re-date")
assert(r.lastScanHadHousing == false and r.lastScanHadDecor == false, "case 6: marks must go false (previously-stocked)")

-- 7. Known vendor with no stored record: nothing is created, no error.
knownNpcIDs[350] = true
Save(350, {}, false)
assert(Record(350) == nil, "case 7: no record must be created")

print("hs501_unconfirmed_empty_scan: all cases ok")
