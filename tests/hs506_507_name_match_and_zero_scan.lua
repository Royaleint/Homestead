-- luacheck: globals assert loadfile print time Enum CreateFrame C_Timer C_Map GetLocale GetSubZoneText GetRealZoneText UnitFactionGroup UnitGUID UnitName GetMerchantNumItems GetMerchantItemLink GetMerchantItemID C_MerchantFrame C_Item GetBuildInfo C_NeighborhoodInitiative

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")
local onlyCase = select(2, ...)

-------------------------------------------------------------------------------
-- Two things, checked against the real shipped data and modules:
--
-- 1. The vendor-name match that runs when a merchant window opens records a
--    differing NPC ID and missing coordinates in saved data only. It never
--    writes to a vendor row it was handed, because some callers hand out the
--    shipped rows themselves.
-- 2. An empty scan of a known vendor, made at a usable position, moves the
--    saved map and location fields together with the coordinates; without a
--    usable position it moves none of them.
--
-- Cases O2 to O7 drive the real scanner through its captured event handler;
-- O8 to O10 call SaveVendorData directly. Pass a case name as the second
-- argument to run only that case.
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
CreateFrame = function()
    local frame = { shown = false, scripts = {} }
    function frame:RegisterEvent() end
    function frame:SetScript(name, handler) self.scripts[name] = handler end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    frames[#frames + 1] = frame
    return frame
end

-- Timer callbacks are captured and never run.
C_Timer = { After = function() end }

-- The player's current map and position; a case sets these and puts them back.
local loc = { map = 2351, pos = nil }
C_Map = {
    GetBestMapForUnit = function() return loc.map end,
    GetPlayerMapPosition = function() return loc.pos end,
    GetMapInfo = function() return nil end,
}
GetLocale = function() return "enUS" end
GetSubZoneText = function() return "Test Subzone" end
GetRealZoneText = function() return "Test Zone" end
UnitFactionGroup = function() return "Neutral" end
GetBuildInfo = function() return "12.1.0", "1", "Jan 1 2026", 120100 end

local currentNpc, currentName = nil, nil
UnitGUID = function() return "Creature-0-1-1-1-" .. currentNpc .. "-0000000001" end
UnitName = function() return currentName end

-- Test-owned merchant: slots is a list of item IDs.
local slots = {}
local nonHousing = { [7001] = true, [7002] = true, [7003] = true }
GetMerchantNumItems = function() return #slots end
GetMerchantItemLink = function(i) return slots[i] and ("item:" .. slots[i]) or nil end
GetMerchantItemID = function(i) return slots[i] end
C_MerchantFrame = {
    GetItemInfo = function(i)
        local id = slots[i]
        if not id then return nil end
        return { name = "Test Item " .. id, price = 100, stackCount = 1, isPurchasable = true }
    end,
}
C_Item = {
    GetItemInfoInstant = function(link)
        local id = tonumber(link:match("item:(%d+)"))
        local classID = nonHousing[id] and 0 or Enum.ItemClass.Housing
        return id, nil, nil, nil, nil, classID, Enum.ItemHousingSubclass.Decor
    end,
}

local payload = nil
C_NeighborhoodInitiative = {
    GetNeighborhoodInitiativeInfo = function() return payload end,
}

local holidayActive = nil
local HA = {
    Addon = {
        db = {
            profile = { vendorScanning = { enabled = true }, debug = false },
            global = {
                vendorNameByLocale = {},
                scannedVendors = {},
                discoveredInitiativeThemes = {},
            },
        },
        Debug = function() end,
        Print = function() end,
        RegisterModule = function() end,
    },
    CatalogStore = {
        SetRequirements = function() end,
        Save = function() end,
        BeginBatch = function() end,
        EndBatch = function() end,
    },
    Events = { Fire = function() end },
    DevAddon = true,
    CalendarDetector = { IsHolidayActive = function() return holidayActive end },
}
local db = HA.Addon.db.global

for _, file in ipairs({
    "Data/VendorIdentity.lua", "Data/VendorData.lua", "Data/EndeavorsData.lua",
    "Data/EventSources.lua", "Modules/DecorClassifier.lua",
    "Modules/ScanPersistence.lua", "Modules/VendorScanner.lua", "UI/VendorFilter.lua",
}) do
    assert(loadfile(root .. "/" .. file))("Homestead", HA)
end

local ED, VD, VF, SP = HA.EndeavorsData, HA.VendorData, HA.VendorFilter, HA.ScanPersistence

local saveCount = 0
local realSave = SP.SaveVendorData
SP.SaveVendorData = function(self, scanData)
    saveCount = saveCount + 1
    return realSave(self, scanData)
end

local firstFrame = #frames + 1
HA.VendorScanner:Initialize()
local scanFrame, eventFrame = frames[firstFrame], frames[firstFrame + 1]
assert(scanFrame and scanFrame.scripts.OnUpdate, "scan frame OnUpdate not captured")
assert(eventFrame and eventFrame.scripts.OnEvent, "event frame OnEvent not captured")

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function Fire(event) eventFrame.scripts.OnEvent(eventFrame, event) end

local function Show(id, name)
    currentNpc, currentName = id, name
    Fire("MERCHANT_SHOW")
end

local function Close() Fire("MERCHANT_CLOSED") end

-- Opens the vendor with the given items and runs the scan to its end.
local function Scan(id, name, items)
    slots = items
    Show(id, name)
    Fire("MERCHANT_UPDATE")
    local guard = 0
    while scanFrame.shown do
        scanFrame.scripts.OnUpdate(scanFrame, 1)
        guard = guard + 1
        assert(guard < 200, "scan never finished")
    end
end

local nextID = 990000
local function NewID()
    nextID = nextID + 1
    assert(not VD:HasVendor(nextID), "test ID " .. nextID .. " is a shipped vendor")
    assert(not VD:ResolveAlias(nextID), "test ID " .. nextID .. " is a shipped alias")
    return nextID
end

local function ClearSaved()
    db.npcIDCorrections = {}
    db.coordsUpdates = {}
    db.scannedVendors = {}
    db.noDecorVendors = {}
end

local themeSerial = 0
local function SetTheme(name)
    themeSerial = themeSerial + 1
    payload = {
        isLoaded = true,
        initiativeID = 9000 + themeSerial,
        npcID = ED.Endeavors[name].vendorNPC,
        progressRequired = 500,
    }
    ED:RefreshCache()
    assert(ED:GetActiveTheme() == name,
        "theme setup: wanted " .. name .. ", got " .. tostring(ED:GetActiveTheme()))
end

local function OtherTheme(theme)
    return theme == "Kobold" and "Niffen" or "Kobold"
end

-- A copy of a table two levels deep: its fields, and the fields of each
-- table-valued field.
local function Snap(t)
    local snap = { top = {}, sub = {} }
    for k, v in pairs(t) do
        snap.top[k] = v
        if type(v) == "table" then
            local inner = {}
            for k2, v2 in pairs(v) do inner[k2] = v2 end
            snap.sub[k] = inner
        end
    end
    return snap
end

-- Name of the first field where t differs from the snapshot, or nil.
local function Diff(t, snap)
    for k, v in pairs(t) do
        if snap.top[k] ~= v then return tostring(k) end
    end
    for k in pairs(snap.top) do
        if t[k] == nil then return tostring(k) end
    end
    for k, inner in pairs(snap.sub) do
        for k2, v2 in pairs(t[k]) do
            if inner[k2] ~= v2 then return tostring(k) .. "." .. tostring(k2) end
        end
        for k2 in pairs(inner) do
            if t[k][k2] == nil then return tostring(k) .. "." .. tostring(k2) end
        end
    end
    return nil
end

local function SortedRowKeys()
    local keys = {}
    for key in pairs(ED.Vendors) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

-- The row itself plus, for a row with a second map, the copy indexed there.
local function EntriesFor(key)
    local row = ED.Vendors[key]
    local primary = false
    for _, entry in ipairs(ED.ByMapID[row.mapID] or {}) do
        if entry == row then primary = true end
    end
    assert(primary, "row " .. key .. " is not indexed as itself on map " .. row.mapID)
    local entries = { row }
    if row.altMapID then
        for _, entry in ipairs(ED.ByMapID[row.altMapID] or {}) do
            if entry.npcID == key and entry ~= row then entries[2] = entry end
        end
        assert(entries[2], "row " .. key .. " has no alt entry on map " .. row.altMapID)
    end
    return entries
end

-- The ID of the shipped identity row with this name, or nil.
local function IdentityKeyFor(name)
    local found, count = nil, 0
    for _, vendor in ipairs(HA.VendorIdentity:GetAllVendors()) do
        if vendor.name and vendor.name:lower() == name:lower() then
            found, count = vendor.npcID, count + 1
        end
    end
    assert(count <= 1, "more than one identity row is named " .. name)
    return found
end

local function ListedOnMap(row)
    for _, vendor in ipairs(VD:GetVendorsInMap(row.mapID)) do
        if vendor == row then return true end
    end
    return false
end

local function RunRows(label, keys, rowFn)
    local failures = {}
    for _, key in ipairs(keys) do
        local reason = rowFn(key)
        if reason then
            failures[#failures + 1] = ED.Vendors[key].name .. " (" .. reason .. ")"
        end
    end
    assert(#failures == 0, label .. ": " .. #failures .. " row(s) failed: " .. table.concat(failures, "; "))
end

-------------------------------------------------------------------------------
-- O2: the name match leaves every endeavor row, and the entries indexed from
-- it, exactly as shipped.
-------------------------------------------------------------------------------

local function O2Row(key)
    local row = ED.Vendors[key]
    local own = ED:GetThemeForVendor(key)
    local entries = EntriesFor(key)
    if #entries ~= (row.altMapID and 2 or 1) then return "entry count " .. #entries end
    local snaps = {}
    for i, entry in ipairs(entries) do snaps[i] = Snap(entry) end

    SetTheme(OtherTheme(own))
    for _, entry in ipairs(entries) do
        if ED:IsVendorActive(entry) then return "active under another theme before the open" end
    end
    if ED:IsVendorActive(key) then return "key active under another theme before the open" end

    local opened = NewID()
    Show(opened, row.name)
    Close()

    local correction = db.npcIDCorrections[row.name]
    if not (correction and correction.newID == opened) then return "no correction to the opened ID" end
    for i, entry in ipairs(entries) do
        local changed = Diff(entry, snaps[i])
        if changed then return "entry " .. i .. " field " .. changed .. " changed" end
        if ED:IsVendorActive(entry) then return "entry " .. i .. " active under another theme after the open" end
    end
    if ListedOnMap(row) then return "listed on its map under another theme" end

    SetTheme(own)
    for i, entry in ipairs(entries) do
        if not ED:IsVendorActive(entry) then return "entry " .. i .. " inactive under its own theme" end
    end
    return nil
end

local function CaseO2()
    RunRows("O2 name match must not change shipped rows", SortedRowKeys(), O2Row)
end

-------------------------------------------------------------------------------
-- O3: the correction is recorded and re-recorded on every open, and the scan
-- under the opened ID stays reachable from the shipped row.
-------------------------------------------------------------------------------

local function O3Row(key)
    local row = ED.Vendors[key]
    local name = row.name
    local expectedOld = IdentityKeyFor(name) or key
    SetTheme(OtherTheme(ED:GetThemeForVendor(key)))

    local opened = NewID()
    Scan(opened, name, { 8001, 8002 })
    Close()
    local correction = db.npcIDCorrections[name]
    if not correction then return "no correction after the first open" end
    if correction.oldID ~= expectedOld or correction.newID ~= opened then
        return "correction " .. tostring(correction.oldID) .. " -> " .. tostring(correction.newID)
    end
    local saved = db.scannedVendors[opened]
    if not saved then return "no scan record under the opened ID" end
    if VD:GetScannedVendorRecord(row) ~= saved then return "row does not reach the scan record" end
    if ED:IsVendorActive(row) ~= ED:IsVendorActive(key) then return "row and key disagree on active" end

    local stamp = correction.correctedAt
    local savesBefore = saveCount
    Show(opened, name)
    Fire("MERCHANT_UPDATE")
    local locked = not scanFrame.shown and saveCount == savesBefore
    Close()
    if not locked then return "second open scanned again" end
    local again = db.npcIDCorrections[name]
    if not (again and again.correctedAt > stamp) then return "correctedAt did not move on the second open" end
    if again.oldID ~= expectedOld or again.newID ~= opened then return "correction changed on the second open" end

    local result = HA.VendorScanner:VerifyAndUpdateDatabaseEntry(opened, name)
    if not (result and result.corrected == true and result.oldID == expectedOld
            and result.newID == opened and result.coordsUpdated == false
            and result.vendor and result.vendor.name == name) then
        return "direct verify result"
    end
    return nil
end

local function CaseO3()
    assert(IdentityKeyFor("Hesta Forlath") == 252916, "O3: Hesta Forlath's identity row is not 252916")
    RunRows("O3 correction and scan reachability", SortedRowKeys(), O3Row)
end

-------------------------------------------------------------------------------
-- O4: a confirmed no-decor scan under the opened ID does not hide the row.
-- Hesta Forlath is left out: her name matches a shipped identity row.
-------------------------------------------------------------------------------

local function O4Row(key)
    local row = ED.Vendors[key]
    SetTheme(ED:GetThemeForVendor(key))
    if VF.ShouldHideVendor(row) then return "hidden before the visit" end

    local opened = NewID()
    Scan(opened, row.name, { 7001, 7002, 7003 })
    Close()
    local flag = db.noDecorVendors[opened]
    if not (flag and flag.scanConfidence == "confirmed") then
        return "no confirmed no-decor flag under the opened ID"
    end
    if VF.ShouldHideVendor(row) then return "hidden after the visit" end
    if not ListedOnMap(row) then return "not listed on its map" end
    if ED:IsVendorActive(row) ~= ED:IsVendorActive(key) then return "row and key disagree on active" end
    return nil
end

local function CaseO4()
    local keys = {}
    for _, key in ipairs(SortedRowKeys()) do
        if not IdentityKeyFor(ED.Vendors[key].name) then keys[#keys + 1] = key end
    end
    assert(#keys > 0, "O4: no rows to check")
    RunRows("O4 no-decor flag must not hide the row", keys, O4Row)
end

-------------------------------------------------------------------------------
-- O5: missing coordinates are recorded in saved data, not on the shipped row.
-------------------------------------------------------------------------------

local function CaseO5()
    local row = ED.Vendors[268106]
    assert(row and row.name == "Taifa", "O5: expected the Taifa row")
    local shipped = { x = row.x, y = row.y, mapID = row.mapID }
    row.x, row.y = 0.5, 0.5
    loc.map, loc.pos = 2352, { x = 0.25, y = 0.75 }

    Show(268106, "Taifa")
    Close()

    local after = { x = row.x, y = row.y, mapID = row.mapID }
    row.x, row.y, row.mapID = shipped.x, shipped.y, shipped.mapID
    loc.map, loc.pos = 2351, nil

    local update = db.coordsUpdates.Taifa
    assert(update and update.mapID == 2352 and update.x == 0.25 and update.y == 0.75,
        "O5: the coordinate update must be saved with map 2352 at 0.25, 0.75")
    assert(after.x == 0.5 and after.y == 0.5, "O5: the row's coordinates must stay as they were, got "
        .. tostring(after.x) .. ", " .. tostring(after.y))
    assert(after.mapID == shipped.mapID, "O5: the row's map must stay " .. shipped.mapID
        .. ", got " .. tostring(after.mapID))
    assert(db.npcIDCorrections.Taifa == nil, "O5: the ID matches, so no correction is recorded")
end

-------------------------------------------------------------------------------
-- O6: an active event vendor's row is left alone.
-------------------------------------------------------------------------------

local function CaseO6()
    local row = HA.EventSources.EventVendors[15864]
    holidayActive = true
    local listed = false
    for _, vendor in ipairs(VD:GetAllVendors()) do
        if vendor.npcID == row.npcID then listed = true end
    end
    assert(listed, "O6: the event row must be in the vendor list while its holiday is active")
    local snap = Snap(row)

    local opened = NewID()
    Show(opened, "Valadar Starsong")
    Close()
    holidayActive = nil

    local correction = db.npcIDCorrections["Valadar Starsong"]
    assert(correction and correction.oldID == 15864 and correction.newID == opened,
        "O6: the correction must record 15864 -> the opened ID")
    assert(row.npcID == 15864, "O6: the event row's npcID must stay 15864, got " .. tostring(row.npcID))
    local changed = Diff(row, snap)
    assert(not changed, "O6: the event row field " .. tostring(changed) .. " changed")
end

-------------------------------------------------------------------------------
-- O7: nothing the vendor list hands out is written, whether it is a copy or a
-- shipped row, and an alias still resolves before the name match.
-------------------------------------------------------------------------------

local function CaseO7()
    local realList = VD.GetAllVendors
    local captured = {}
    VD.GetAllVendors = function(self)
        local list = realList(self)
        local call = { list = list, snaps = {} }
        for i, vendor in ipairs(list) do call.snaps[i] = Snap(vendor) end
        captured[#captured + 1] = call
        return list
    end

    local function CapturedHas(name)
        for _, vendor in ipairs(captured[#captured].list) do
            if vendor.name == name then return true end
        end
        return false
    end
    local function FirstCapturedChange()
        for _, call in ipairs(captured) do
            for i, vendor in ipairs(call.list) do
                local changed = Diff(vendor, call.snaps[i])
                if changed then return tostring(vendor.name) .. "." .. changed end
            end
        end
        return nil
    end

    -- a. A name that matches a shipped identity row.
    local named = 0
    for _, vendor in ipairs(realList(VD)) do
        if vendor.name == "Innkeeper Belm" then named = named + 1 end
    end
    assert(named == 1, "O7 a: expected exactly one vendor named Innkeeper Belm, found " .. named)
    local identityRow = HA.VendorIdentity.Vendors[1247]
    local identitySnap = Snap(identityRow)
    local opened = NewID()
    Show(opened, "Innkeeper Belm")
    Close()
    assert(#captured == 1, "O7 a: expected one vendor list per open, got " .. #captured)
    assert(CapturedHas("Innkeeper Belm"), "O7 a: the list must contain Innkeeper Belm")
    local correction = db.npcIDCorrections["Innkeeper Belm"]
    assert(correction and correction.oldID == 1247 and correction.newID == opened,
        "O7 a: the correction must record 1247 -> the opened ID")
    assert(not Diff(identityRow, identitySnap),
        "O7 a: the identity row field " .. tostring(Diff(identityRow, identitySnap)) .. " changed")
    assert(not FirstCapturedChange(), "O7 a: a listed vendor was written: " .. tostring(FirstCapturedChange()))

    -- b. A name that matches a shipped endeavor row.
    captured = {}
    local griftah = ED.Vendors[260485]
    local griftahSnap = Snap(griftah)
    Show(NewID(), "Griftah")
    Close()
    assert(#captured == 1, "O7 b: expected one vendor list per open, got " .. #captured)
    assert(CapturedHas("Griftah"), "O7 b: the list must contain Griftah")
    assert(not FirstCapturedChange(), "O7 b: a listed vendor was written: " .. tostring(FirstCapturedChange()))
    assert(not Diff(griftah, griftahSnap),
        "O7 b: the Griftah row field " .. tostring(Diff(griftah, griftahSnap)) .. " changed")

    -- c, d. The shipped ID itself: no correction.
    ClearSaved()
    Show(1247, "Innkeeper Belm")
    Close()
    assert(db.npcIDCorrections["Innkeeper Belm"] == nil, "O7 c: the shipped ID must not be corrected")
    Show(260485, "Griftah")
    Close()
    assert(db.npcIDCorrections.Griftah == nil, "O7 d: the shipped ID must not be corrected")

    -- e. An alias resolves to its canonical ID before the name match.
    Scan(150359, "Pascal-K1N6", { 8001, 8002 })
    Close()
    assert(db.npcIDCorrections["Pascal-K1N6"] == nil, "O7 e: an alias must not be corrected")
    local record = db.scannedVendors[248525]
    assert(record and record.npcID == 248525, "O7 e: the scan must be saved under 248525")
    assert(db.scannedVendors[150359] == nil, "O7 e: nothing may be saved under the alias")
    local localeEntry = db.vendorNameByLocale.enUS["pascal-k1n6"]
    assert(localeEntry and localeEntry.npcID == 248525, "O7 e: the locale name entry must carry 248525")

    VD.GetAllVendors = realList
end

-------------------------------------------------------------------------------
-- O8 to O10: an empty scan of a known vendor.
-------------------------------------------------------------------------------

local KNOWN = 260485

-- A record saved from map 2352 with a confirmed scan.
local function SeedKnown()
    local record = {
        npcID = KNOWN, name = "Griftah", mapID = 2352, coords = { x = 0.53, y = 0.38 },
        faction = "Neutral", zone = "A Zone", subZone = "A Sub", realZone = "A Real",
        parentMapID = 7001, mapChain = { 2352, 7001, 7002 }, continentMapID = 7002,
        expansion = "A Exp", lastScanned = 900, itemCount = 3, slotCount = 3,
        decorCount = 1, hasDecor = true, lastScanHadDecor = true,
        housingCount = 1, hasHousing = true, lastScanHadHousing = true,
        subclassCounts = { [0] = 1 }, scanConfidence = "confirmed",
        items = { { itemID = 8001, name = "Seed", subclassID = 0, merchantSlot = 1 } },
    }
    db.scannedVendors[KNOWN] = record
    return record
end

-- An empty scan from map 2351 at 0.54, 0.56.
local function ZeroScan(unconfirmed)
    return {
        npcID = KNOWN, vendorName = "Griftah", mapID = 2351, coords = { x = 0.54, y = 0.56 },
        faction = "Neutral", zone = "Razorwind Shores", subZone = "B Sub", realZone = "B Real",
        parentMapID = 8001, mapChain = { 2351, 8001, 8002 }, continentMapID = 8002,
        expansion = "B Exp", housingItems = {}, allItems = { { itemID = 7001, name = "Other" } },
        totalItems = 4, scanComplete = true, hadNilSlots = unconfirmed,
    }
end

local function CheckKeptRecord(label, record, seed)
    assert(record.items == seed.items, label .. ": items must be the seeded list")
    assert(record.itemCount == 3 and record.slotCount == 3 and record.housingCount == 1
        and record.decorCount == 1, label .. ": counts must stay as seeded")
    assert(record.scanConfidence == "confirmed", label .. ": confidence must stay confirmed")
end

local function CaseO8()
    for _, unconfirmed in ipairs({ false, true }) do
        local label = "O8 " .. (unconfirmed and "unconfirmed" or "confirmed")
        local seed = SeedKnown()
        local before = {}
        for k in pairs(seed) do before[k] = true end
        local scan = ZeroScan(unconfirmed)
        SP:SaveVendorData(scan)

        local record = db.scannedVendors[KNOWN]
        assert(record == seed, label .. ": the stored record must be the seeded table")
        for k in pairs(record) do
            assert(before[k] or (unconfirmed and k == "lastScanAttempt"), label .. ": new field " .. tostring(k))
        end
        for k in pairs(before) do
            assert(record[k] ~= nil, label .. ": field " .. tostring(k) .. " was removed")
        end
        assert(record.coords == scan.coords, label .. ": coords must be this scan's")
        assert(record.mapID == scan.mapID, label .. ": mapID must be this scan's, got " .. tostring(record.mapID))
        assert(record.realZone == "B Real", label .. ": realZone must be this scan's, got " .. tostring(record.realZone))
        assert(record.parentMapID == 8001, label .. ": parentMapID must be this scan's, got " .. tostring(record.parentMapID))
        assert(record.mapChain == scan.mapChain, label .. ": mapChain must be this scan's")
        assert(record.continentMapID == 8002, label .. ": continentMapID must be this scan's, got " .. tostring(record.continentMapID))
        assert(record.expansion == "B Exp", label .. ": expansion must be this scan's, got " .. tostring(record.expansion))
        assert(record.zone == "Razorwind Shores" and record.subZone == "B Sub", label .. ": zone and subZone must be this scan's")
        CheckKeptRecord(label, record, seed)
        if unconfirmed then
            assert(record.lastScanned == 900, label .. ": lastScanned must not move")
            assert(record.lastScanAttempt ~= nil, label .. ": the attempt must be recorded")
            assert(record.lastScanHadDecor == true and record.lastScanHadHousing == true,
                label .. ": the had-marks must stay true")
        else
            assert(record.lastScanned ~= 900, label .. ": lastScanned must be re-dated")
            assert(record.lastScanAttempt == nil, label .. ": no attempt is recorded on a confirmed scan")
            assert(record.lastScanHadDecor == false and record.lastScanHadHousing == false,
                label .. ": the had-marks must be cleared")
        end
        ClearSaved()
    end
end

local function CaseO9()
    local seed = SeedKnown()
    local scan = ZeroScan(false)
    scan.realZone, scan.parentMapID, scan.continentMapID, scan.expansion = nil, nil, nil, nil
    scan.mapChain = { 2351, 8001 }
    SP:SaveVendorData(scan)

    local record = db.scannedVendors[KNOWN]
    assert(record == seed, "O9: the stored record must be the seeded table")
    assert(record.coords == scan.coords, "O9: coords must be this scan's")
    assert(record.mapID == 2351, "O9: mapID must be this scan's, got " .. tostring(record.mapID))
    assert(record.mapChain == scan.mapChain, "O9: mapChain must be this scan's")
    assert(record.realZone == "A Real", "O9: realZone must keep the record's value, got " .. tostring(record.realZone))
    assert(record.parentMapID == 7001, "O9: parentMapID must keep the record's value, got " .. tostring(record.parentMapID))
    assert(record.continentMapID == 7002,
        "O9: continentMapID must keep the record's value, got " .. tostring(record.continentMapID))
    assert(record.expansion == "A Exp", "O9: expansion must keep the record's value, got " .. tostring(record.expansion))
end

local function CaseO10()
    for _, coords in ipairs({ { x = 0.5, y = 0.5 }, { x = 0.5, y = 0.3 } }) do
        local label = "O10 coords " .. coords.x .. ", " .. coords.y
        local seed = SeedKnown()
        local expected = Snap(seed)
        expected.top.zone, expected.top.subZone = "Razorwind Shores", "B Sub"
        expected.top.lastScanHadDecor, expected.top.lastScanHadHousing = false, false

        local scan = ZeroScan(false)
        scan.coords = coords
        SP:SaveVendorData(scan)

        local record = db.scannedVendors[KNOWN]
        assert(record == seed, label .. ": the stored record must be the seeded table")
        assert(record.lastScanned ~= 900, label .. ": lastScanned must be re-dated")
        expected.top.lastScanned = record.lastScanned
        local changed = Diff(record, expected)
        assert(not changed, label .. ": field " .. tostring(changed) .. " changed; location must stay as seeded")
        ClearSaved()
    end
end

-------------------------------------------------------------------------------
-- Run
-------------------------------------------------------------------------------

local CASES = {
    { "O2", CaseO2 }, { "O3", CaseO3 }, { "O4", CaseO4 }, { "O5", CaseO5 }, { "O6", CaseO6 },
    { "O7", CaseO7 }, { "O8", CaseO8 }, { "O9", CaseO9 }, { "O10", CaseO10 },
}

local ran = 0
for _, case in ipairs(CASES) do
    if not onlyCase or onlyCase == case[1] then
        ClearSaved()
        loc.map, loc.pos = 2351, nil
        holidayActive = nil
        case[2]()
        ran = ran + 1
    end
end
assert(ran > 0, "no such case: " .. tostring(onlyCase))

if onlyCase then
    print("hs506_507_name_match_and_zero_scan: case " .. onlyCase .. " ok")
else
    print("hs506_507_name_match_and_zero_scan: all cases ok")
end
