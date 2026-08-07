-- luacheck: globals assert loadfile print io loadstring time Enum

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-250: a known vendor selling only non-decor housing must export its items,
-- not a delist row.
--
-- HS-249 deliberately keeps decorCount / hasDecor / lastScanHadDecor meaning
-- decor only, because decorCount is a wire format archived scans already carry.
-- The consequence is that a vendor selling nothing but room plans or dyes has
-- lastScanHadDecor == false while having scanned perfectly well and captured
-- items. IsDelistCandidate read that flag as "this vendor had nothing", emitted
-- a D row, and suppressed every I row — so freshly captured stock never reached
-- the pipeline, and the pipeline was told to consider retiring a vendor that
-- had just proved it has inventory.
--
-- ExportImport.lua runs WoW-API-heavy work and IsDelistCandidate is file-local,
-- so this extracts and executes the real function body (the hs202 pattern)
-- rather than asserting on source text alone.
-------------------------------------------------------------------------------

local exportSource = assert(io.open(root .. "/Modules/ExportImport.lua", "r")):read("*a")

local functionText = exportSource:match(
    '(local function IsDelistCandidate%(vendor, npcID%).-\nend)')
assert(functionText ~= nil,
    "could not extract IsDelistCandidate function text from ExportImport.lua")

local knownNpcIDs = { [100] = true, [101] = true, [102] = true, [103] = true }
local MockHA = {
    VendorData = {
        HasVendor = function(_, npcID) return knownNpcIDs[npcID] == true end,
    },
}

local chunk = "local _, HA = ...\n" .. functionText .. "\nreturn IsDelistCandidate"
local IsDelistCandidate = assert(loadstring(chunk, "IsDelistCandidate-extract"))("Homestead", MockHA)

local function MakeItems(count)
    local items = {}
    for i = 1, count do items[i] = { itemID = 4000 + i } end
    return items
end

-- 1. THE BUG. A known vendor selling only room plans: eight housing items
--    captured, none of them decor. Must NOT delist.
assert(IsDelistCandidate({
    npcID = 100,
    items = MakeItems(8),
    itemCount = 8,
    decorCount = 0,
    hasDecor = false,
    lastScanHadDecor = false,   -- correct, and not the question being asked
    housingCount = 8,
    hasHousing = true,
    lastScanHadHousing = true,
}, 100) == false,
    "a known vendor selling only non-decor housing must not be a delist candidate")

-- 2. The behaviour being protected must survive. A known vendor that genuinely
--    scanned empty still delists.
assert(IsDelistCandidate({
    npcID = 101,
    items = {},
    itemCount = 0,
    decorCount = 0,
    hasDecor = false,
    lastScanHadDecor = false,
    housingCount = 0,
    hasHousing = false,
    lastScanHadHousing = false,
}, 101) == true,
    "a known vendor that scanned zero housing items must still delist")

-- 3. Legacy record: saved before lastScanHadHousing existed. The decor flag IS
--    the housing answer on those, because decor was the only subclass the old
--    capture gate could see. A legacy vendor that had decor must not delist...
assert(IsDelistCandidate({
    npcID = 102,
    items = MakeItems(5),
    itemCount = 5,
    decorCount = 5,
    hasDecor = true,
    lastScanHadDecor = true,
    -- housingCount / hasHousing / lastScanHadHousing absent — the legacy shape.
}, 102) == false,
    "a legacy record that had decor must not delist via the fallback")

-- ...and a legacy vendor that scanned empty must still delist.
assert(IsDelistCandidate({
    npcID = 103,
    items = {},
    itemCount = 0,
    decorCount = 0,
    hasDecor = false,
    lastScanHadDecor = false,
}, 103) == true,
    "a legacy record that scanned empty must still delist via the fallback")

-- 4. Unknown vendors are never delist candidates regardless of contents. This
--    is why the bug hid: "Fen" Rucket, the vendor that prompted HS-249, is
--    unknown, so it exits here before reaching the flag test and looked fine
--    while already-tracked vendors were silently losing their items.
assert(IsDelistCandidate({
    npcID = 999,
    items = {},
    itemCount = 12,
    lastScanHadDecor = false,
    lastScanHadHousing = false,
}, 999) == false,
    "an unknown vendor is never a delist candidate")

-- 5. The second condition is untouched: stock present but nothing captured is
--    still a genuine review signal.
assert(IsDelistCandidate({
    npcID = 100,
    items = {},
    itemCount = 20,
    lastScanHadDecor = true,
    lastScanHadHousing = true,
}, 100) == true,
    "a known vendor with stock but zero captured items must still delist")

print("hs250_delist_gate: housing-only vendors export instead of delisting ok")

-------------------------------------------------------------------------------
-- The producer half. The section above proves IsDelistCandidate asks the right
-- question; this proves ScanPersistence actually answers it. Without this,
-- deleting either preserve-branch assignment leaves the whole suite green while
-- re-breaking the empty-vendor delist for known vendors — which is the exact
-- behaviour HS-250 is most at risk of destroying while fixing itself.
-------------------------------------------------------------------------------

local fakeClock = 2000
time = function() fakeClock = fakeClock + 1 return fakeClock end

Enum = { ItemHousingSubclass = { Decor = 0, Dye = 1, Room = 2 } }

local isKnownVendor = false
local ScanHA = {
    Addon = { db = { global = {} }, Debug = function() end },
    VendorData = {
        HasVendor = function() return isKnownVendor end,
        BuildScannedIndex = function() end,
        InvalidateVendorCaches = function() end,
    },
    CatalogStore = { SetRequirements = function() end, Save = function() end },
    Events = { Fire = function() end },
    DevAddon = true,
}
assert(loadfile(root .. "/Modules/ScanPersistence.lua"))("Homestead", ScanHA)

-- 6. A housing-only vendor records "this scan found housing" while correctly
--    recording "this scan found no decor". Those two answers must not agree.
ScanHA.ScanPersistence:SaveVendorData({
    npcID = 200,
    vendorName = "Room Plan Vendor",
    mapID = 1,
    coords = { x = 0.4, y = 0.4 },
    faction = "Neutral",
    housingItems = {
        { itemID = 7001, name = "Room Plan A", subclassID = Enum.ItemHousingSubclass.Room, merchantSlot = 1 },
        { itemID = 7002, name = "Room Plan B", subclassID = Enum.ItemHousingSubclass.Room, merchantSlot = 2 },
    },
    scanComplete = true,
    hadNilSlots = false,
})

local housingOnly = ScanHA.Addon.db.global.scannedVendors[200]
assert(housingOnly ~= nil, "a housing-only vendor must persist")
assert(housingOnly.lastScanHadHousing == true,
    "a scan that captured room plans must record lastScanHadHousing true")
assert(housingOnly.lastScanHadDecor == false,
    "the same scan must still record lastScanHadDecor false — it found no decor")

-- 7. Preserve branch: a KNOWN vendor scanning zero housing. The record is kept
--    (an empty scan of a known vendor is treated as an API failure, not truth),
--    but the observation flag must go false so the export can still delist it.
isKnownVendor = true
ScanHA.Addon.db.global.scannedVendors[201] = {
    npcID = 201, vendorName = "Known Vendor", mapID = 1,
    items = { { itemID = 7101, subclassID = 0, decorID = 9101 } },
    decorCount = 1, hasDecor = true, housingCount = 1, hasHousing = true,
    lastScanHadDecor = true, lastScanHadHousing = true,
    itemCount = 1, lastScanned = 900, scanConfidence = "confirmed",
}
ScanHA.ScanPersistence:SaveVendorData({
    npcID = 201,
    vendorName = "Known Vendor",
    mapID = 1,
    coords = { x = 0.4, y = 0.4 },
    faction = "Neutral",
    housingItems = {},
    scanComplete = true,
    hadNilSlots = false,
})

local knownEmpty = ScanHA.Addon.db.global.scannedVendors[201]
assert(knownEmpty ~= nil and #knownEmpty.items == 1,
    "a known vendor scanning empty must keep its existing items")
assert(knownEmpty.lastScanHadHousing == false,
    "the known-vendor preserve branch must record that the scan found no housing")

-- 8. Preserve branch: an UNKNOWN vendor that previously had housing and now
--    scans zero. Same requirement, different branch.
isKnownVendor = false
ScanHA.Addon.db.global.scannedVendors[202] = {
    npcID = 202, vendorName = "Formerly Stocked", mapID = 1,
    items = { { itemID = 7201, subclassID = 2 } },
    decorCount = 0, hasDecor = false, housingCount = 1, hasHousing = true,
    lastScanHadDecor = false, lastScanHadHousing = true,
    itemCount = 1, lastScanned = 900, scanConfidence = "confirmed",
}
ScanHA.ScanPersistence:SaveVendorData({
    npcID = 202,
    vendorName = "Formerly Stocked",
    mapID = 1,
    coords = { x = 0.4, y = 0.4 },
    faction = "Neutral",
    housingItems = {},
    scanComplete = true,
    hadNilSlots = false,
})

local wentEmpty = ScanHA.Addon.db.global.scannedVendors[202]
assert(wentEmpty ~= nil and #wentEmpty.items == 1,
    "a vendor that previously had housing must keep its items when it scans empty")
assert(wentEmpty.lastScanHadHousing == false,
    "the previously-had-housing preserve branch must record that the scan found no housing")

print("hs250_delist_gate: ScanPersistence records the housing observation flag ok")
