-- luacheck: globals assert loadfile loadstring io print tonumber wipe time C_Item C_HousingCatalog Enum

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

local fakeClock = 1000
time = function()
    fakeClock = fakeClock + 1
    return fakeClock
end

-------------------------------------------------------------------------------
-- HS-451: room-plan ownership resolves only through the static RoomMapping
-- index and GetCatalogEntryInfoByRecordID(2, roomRecordID) -- rooms carry no
-- itemID, so there is no runtime discovery path. A1-A6 below cover: the
-- unknowable predicate, the readOnly probe, the write-mode probe and its
-- cache shape, the erasure guard (a mapped plan's ownership only ever moves
-- unowned -> owned), the entryType/decorID-collision traps that a byte-copy
-- of the decor probe would fall into, and the scanner's ScanItem Room branch.
-------------------------------------------------------------------------------

wipe = function(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end

Enum = {
    ItemClass = { Housing = 20 },
    ItemHousingSubclass = {
        Decor = 0, Dye = 1, Room = 2, RoomCustomization = 3,
        ExteriorCustomization = 4, ServiceItem = 5,
    },
}

-- itemID -> {classID, subClassID}.
local itemClassByItemID = {
    [9001] = { Enum.ItemClass.Housing, Enum.ItemHousingSubclass.Decor },               -- Housing/Decor
    [9002] = { Enum.ItemClass.Housing, Enum.ItemHousingSubclass.Dye },                 -- Housing/Dye
    [9003] = { Enum.ItemClass.Housing, Enum.ItemHousingSubclass.Room },                -- Housing/Room (mapped)
    [9004] = { Enum.ItemClass.Housing, Enum.ItemHousingSubclass.Room },                -- Housing/Room (unmapped)
    [9005] = { Enum.ItemClass.Housing, Enum.ItemHousingSubclass.ExteriorCustomization }, -- Housing/ExteriorCustomization
    [9006] = { 0, 0 },                                                                -- non-housing
}

C_Item = {
    GetItemInfoInstant = function(x)
        local id = type(x) == "number" and x or tonumber(tostring(x):match("(%d+)"))
        local fixture = itemClassByItemID[id]
        if not fixture then return end -- MayReturnNothing: no values at all
        return id, nil, nil, nil, nil, fixture[1], fixture[2]
    end,
}

-- entryType/recordID -> response, keyed by both arguments (the collision
-- trap this whole feature exists to avoid). (2,288) is the real room read;
-- (1,288) is a decoy that would falsely read positive if entryType were
-- ever hardcoded to 1; (1,500) is the real decor read for the DecorMapping
-- control item (9001/500). entryID mirrors what the deprecation shim adds.
local function MakeCatalogStub(calls)
    return {
        GetCatalogEntryInfoByItem = function() return nil end,
        GetCatalogEntryInfoByRecordID = function(entryType, recordID)
            table.insert(calls, { entryType, recordID })
            if entryType == 2 and recordID == 288 then
                return {
                    name = "Bel'ameth Meeting Room", totalNumStored = 1, remainingRedeemable = 0,
                    totalNumPlaced = 0, sourceText = "Vendor: Test", entryID = { recordID = 288, entryType = 2 },
                }
            end
            if entryType == 1 and recordID == 288 then
                return { totalNumStored = 0, remainingRedeemable = 0, totalNumPlaced = 0 }
            end
            if entryType == 1 and recordID == 500 then
                return { totalNumStored = 1 }
            end
            return nil
        end,
    }
end

local calls = {}
C_HousingCatalog = MakeCatalogStub(calls)

local HA = {
    Addon = {
        db = { global = { catalogItems = {}, schemaVersion = 7 } },
        RegisterModule = function() end,
        Debug = function() end,
    },
    Constants = { VERSION = "test" },
    Events = { Fire = function() end },
    DecorMapping = { [500] = 9001 },
    RoomMapping = { [288] = 9003 },
}

assert(loadfile(root .. "/Data/CatalogStore.lua"))("Homestead", HA)
HA.CatalogStore:Initialize()

-------------------------------------------------------------------------------
-- A1: the unknowable predicate and the room index, right after Initialize.
-------------------------------------------------------------------------------
assert(HA.CatalogStore:IsOwnershipUnknowable(9001) == false, "A1: Decor must resolve")
assert(HA.CatalogStore:IsOwnershipUnknowable(9003) == false, "A1: a mapped Room plan must resolve")
assert(HA.CatalogStore:IsOwnershipUnknowable(9002) == true, "A1: Dye stays unknowable")
assert(HA.CatalogStore:IsOwnershipUnknowable(9004) == true, "A1: an unmapped Room plan stays unknowable")
assert(HA.CatalogStore:IsOwnershipUnknowable(9005) == true, "A1: ExteriorCustomization stays unknowable")
assert(HA.CatalogStore:GetRoomIDFromItemID(9003) == 288, "A1: mapped plan resolves its roomID")
assert(HA.CatalogStore:GetRoomIDFromItemID(9004) == nil, "A1: unmapped plan has no roomID")
print("hs451_room_ownership: A1 ok")

-------------------------------------------------------------------------------
-- A2: readOnly probe. No cache write, and the live call used entryType 2.
-------------------------------------------------------------------------------
assert(HA.CatalogStore:IsOwnedFresh(9003, true) == true, "A2: readOnly probe reads owned")
local lastCall = calls[#calls]
assert(lastCall and lastCall[1] == 2 and lastCall[2] == 288, "A2: readOnly probe must read entryType 2, recordID 288")
assert(HA.CatalogStore:IsOwned(9003) == false, "A2: readOnly must not write the cache")
assert(HA.CatalogStore:Get(9003) == nil, "A2: readOnly must create no record")
print("hs451_room_ownership: A2 ok")

-------------------------------------------------------------------------------
-- A3: write-mode probe. Cache write with no decorID, no decor-index entry.
-------------------------------------------------------------------------------
assert(HA.CatalogStore:IsOwnedFresh(9003) == true, "A3: write-mode probe reads owned")
assert(HA.CatalogStore:IsOwned(9003) == true, "A3: write-mode probe writes the cache")
assert(HA.CatalogStore:Get(9003).decorID == nil, "A3: a room record must carry no decorID")
assert(HA.CatalogStore:GetItemIDFromDecorID(288) == nil, "A3: a roomID must never enter the decor reverse index")
assert(HA.CatalogStore:GetDecorIDFromItemID(9003) == nil, "A3: a room plan has no decorID")
assert(HA.CatalogStore:IsDecorItem("item:9003") == false, "A3: a room-plan ci record must not read as decor")
print("hs451_room_ownership: A3 ok")

-------------------------------------------------------------------------------
-- A4 (erasure guard, R1): a mapped plan's ownership only ever moves
-- unowned -> owned. A decor control confirms SetUnowned still works normally
-- for everything else.
-------------------------------------------------------------------------------
local ownedBefore = HA.CatalogStore:GetOwnedCount()
HA.CatalogStore:SetUnowned(9003)
assert(HA.CatalogStore:IsOwned(9003) == true, "A4: SetUnowned must not erase a mapped room plan")
assert(HA.CatalogStore:GetOwnedCount() == ownedBefore, "A4: SetUnowned on a mapped plan must not move the counter")

HA.CatalogStore:SetOwned(9001, "d", 500)
HA.CatalogStore:SetUnowned(9001)
assert(HA.CatalogStore:IsOwned(9001) == false, "A4 control: SetUnowned must still erase an ordinary decor item")
print("hs451_room_ownership: A4 ok")

-------------------------------------------------------------------------------
-- A5 (decoy HA): a fresh store where recordID 288 answers backwards --
-- entryType 2 (the real room read) is zero, entryType 1 (a decoy) is
-- positive. Catches entryType hardcoded to 1, and catches a copy of
-- ProbeByDecorID's unconditional-save branch leaking into ProbeByRoomID.
-------------------------------------------------------------------------------
local decoyCalls = {}
C_HousingCatalog = {
    GetCatalogEntryInfoByItem = function() return nil end,
    GetCatalogEntryInfoByRecordID = function(entryType, recordID)
        table.insert(decoyCalls, { entryType, recordID })
        if entryType == 2 and recordID == 288 then
            return { totalNumStored = 0, remainingRedeemable = 0, totalNumPlaced = 0 }
        end
        if entryType == 1 and recordID == 288 then
            return { totalNumStored = 1 }
        end
        return nil
    end,
}

local DecoyHA = {
    Addon = {
        db = { global = { catalogItems = {}, schemaVersion = 7 } },
        RegisterModule = function() end,
        Debug = function() end,
    },
    Constants = { VERSION = "test" },
    Events = { Fire = function() end },
    DecorMapping = {},
    RoomMapping = { [288] = 9003 },
}
assert(loadfile(root .. "/Data/CatalogStore.lua"))("Homestead", DecoyHA)
DecoyHA.CatalogStore:Initialize()

assert(DecoyHA.CatalogStore:IsOwnedFresh(9003, true) == false,
    "A5a: entryType must not be hardcoded to 1 -- the real (entryType 2) read is the zero one")

assert(DecoyHA.CatalogStore:IsOwnedFresh(9003) == false, "A5b: write-mode probe must not read the decoy positive")
assert(DecoyHA.CatalogStore:Get(9003) == nil,
    "A5b: an unowned room probe must save nothing -- no copy of ProbeByDecorID's unconditional _save branch")
assert(DecoyHA.CatalogStore:GetItemIDFromDecorID(288) == nil,
    "A5b: an unowned room probe must not seed the decor reverse index either")
print("hs451_room_ownership: A5 ok")

-------------------------------------------------------------------------------
-- A6 (behavioral ScanItem, R3): extract and run the real ScanItem against
-- the A1 store, whose ci[9003] is already owned from A3. Uses the
-- extract-and-loadstring idiom (hs074b, hs202), not a source-text pin.
-------------------------------------------------------------------------------
C_HousingCatalog = MakeCatalogStub(calls)

local scannerSource = assert(io.open(root .. "/Modules/CatalogScanner.lua", "r")):read("*a")
local scanItemBody = scannerSource:match(
    "(local function IsOwned%(info%).-\nlocal function ScanItem%(itemID%).-\nend)")
assert(scanItemBody ~= nil, "could not extract IsOwned..ScanItem from CatalogScanner.lua")

local chunk = "local HA = ...\n" .. scanItemBody .. "\nreturn ScanItem"
local ScanItem = assert(loadstring(chunk, "ScanItem-extract"))(HA)

local roomScan = ScanItem(9003)
assert(roomScan ~= nil, "A6: ScanItem must resolve a mapped room plan")
assert(roomScan.isOwned == true, "A6: the owned room must scan as owned")
assert(roomScan.recordID == nil, "A6: a room scan result must carry no recordID")
assert(roomScan.sourceText == nil, "A6: a room scan result must carry no sourceText")
assert(roomScan.itemID == 9003, "A6: the scan result must carry the plan's itemID")

assert(ScanItem(9004) == nil, "A6: an unmapped room plan must scan as unresolved")

local decorScan = ScanItem(9001)
assert(decorScan and decorScan.recordID == 500, "A6: the decor scan path must stay unchanged")

print("hs451_room_ownership: A6 ok")
print("hs451_room_ownership: room-plan ownership resolution ok")
