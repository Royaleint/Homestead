-- luacheck: globals assert loadfile print io IsShiftKeyDown IsControlKeyDown IsAltKeyDown C_HousingCatalog C_Item Enum

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Item 1 + 2 + 3: SourceTextParser — self-contained, fully executable.
-------------------------------------------------------------------------------

local ParserHA = {}
assert(loadfile(root .. "/Data/SourceTextLocaleProfiles.lua"))("Homestead", ParserHA)
assert(loadfile(root .. "/Data/SourceTextParser.lua"))("Homestead", ParserHA)

-- Item 3: the built-in self-test suite (with its 7-digit color-code fixture
-- typo fixed to the real 8-digit form) must fully pass.
local pass, failCount = ParserHA.SourceTextParser:RunTests()
assert(pass == true and failCount == 0,
    "SourceTextParser:RunTests() must pass cleanly (failCount=" .. tostring(failCount) .. ")")

-- Item 1: |cn named-color form (WoW 10.x+) must strip and parse identically
-- to the |cAARRGGBB form — Overlay/Tooltips.lua already strips this same
-- form from the same sourceText data.
local namedColorInput = "|cnPlayerName:Vendor:|r Meridelle Lightspark|n|cnPlayerName:Zone:|r Dornogal"
local namedColorResult = ParserHA.SourceTextParser:ParseSourceText(namedColorInput, "enUS")
assert(namedColorResult ~= nil)
local ncSource = namedColorResult.sources[1]
assert(ncSource.sourceType == "vendor", "expected vendor, got " .. tostring(ncSource.sourceType))
assert(ncSource.name == "Meridelle Lightspark", "expected clean name, got " .. tostring(ncSource.name))
assert(ncSource.zone == "Dornogal", "expected clean zone, got " .. tostring(ncSource.zone))

-- Item 2: comma-grouped currency amounts must parse in full, not just the
-- digits after the last comma ("1,000" must not become 0).
local commaInput = "Vendor: Bulk Trader|nZone: Ironforge|nCost: 1,000|Hcurrency:1560|h|h"
local commaResult = ParserHA.SourceTextParser:ParseSourceText(commaInput, "enUS")
assert(commaResult ~= nil)
local commaSource = commaResult.sources[1]
assert(commaSource.cost and commaSource.cost.currencies and commaSource.cost.currencies[1].amount == 1000,
    "comma-grouped currency amount must parse as 1000, got "
    .. tostring(commaSource.cost and commaSource.cost.currencies and commaSource.cost.currencies[1].amount))

print("hs218_w4: item 1/2/3 SourceTextParser ok")

-------------------------------------------------------------------------------
-- Item 4: CalendarDetector — grep-pins (standalone load impractical: heavy
-- CreateFrame/C_Calendar/C_DateAndTime surface for a taint-sensitive module).
-------------------------------------------------------------------------------

local calendarSource = assert(io.open(root .. "/Modules/CalendarDetector.lua", "r")):read("*a")

-- Viewed-month vs real-month guard inside ScanTodaysHolidays.
local scanBody = calendarSource:match(
    'local function ScanTodaysHolidays%(%)(.-)\nend')
assert(scanBody ~= nil, "could not isolate ScanTodaysHolidays")
assert(scanBody:find('C_Calendar%.GetMonthInfo', 1) ~= nil,
    "ScanTodaysHolidays must check C_Calendar.GetMonthInfo against the real current month")
assert(scanBody:find('monthInfo%.month ~= today%.month', 1) ~= nil or scanBody:find('today%.month', 1) ~= nil,
    "ScanTodaysHolidays must compare the viewed month against today's real month")

-- OpenCalendar gated to once per session.
assert(calendarSource:find('hasOpenedCalendarThisSession', 1) ~= nil,
    "OpenCalendar must be gated by a once-per-session flag")
assert(calendarSource:find('not hasOpenedCalendarThisSession and C_Calendar and C_Calendar%.OpenCalendar', 1) ~= nil,
    "the once-per-session flag must actually guard the C_Calendar.OpenCalendar call")

print("hs218_w4: item 4 CalendarDetector pin ok")

-------------------------------------------------------------------------------
-- Item 5: Utils/waypoints.lua — grep-pins (standalone load impractical:
-- CreateFrame/C_Map/C_SuperTrack/TomTom surface).
-------------------------------------------------------------------------------

local waypointsSource = assert(io.open(root .. "/Utils/waypoints.lua", "r")):read("*a")

assert(waypointsSource:find('RegisterEvent%("USER_WAYPOINT_UPDATED"%)', 1) ~= nil,
    "Waypoints must register USER_WAYPOINT_UPDATED")
assert(waypointsSource:find('function IsNativeWaypointOurs%(%)', 1) ~= nil,
    "Waypoints must have a comparison against what it actually set")
-- The external-change handler must clear internal state but must NEVER call
-- ClearNativeWaypoint/RemoveTomTomWaypoint (that would touch the player's pin).
local handlerBody = waypointsSource:match(
    'local function OnUserWaypointUpdated%(%)(.-)\nend')
assert(handlerBody ~= nil, "could not isolate OnUserWaypointUpdated")
assert(handlerBody:find('currentWaypoint = nil', 1) ~= nil)
assert(handlerBody:find('StopArrivalCheck%(%)', 1) ~= nil)
-- Require an actual CALL (identifier immediately followed by "("), not just
-- the identifier appearing in this function's own explanatory comment text.
assert(handlerBody:find('ClearNativeWaypoint%(', 1) == nil,
    "the external-change handler must never call ClearNativeWaypoint (would touch the player's pin)")
assert(handlerBody:find('RemoveTomTomWaypoint%(', 1) == nil,
    "the external-change handler must never call RemoveTomTomWaypoint (would touch the player's pin)")

-- The three dead "configurable" settings must be gone from UpdateConfig.
local updateConfigBody = waypointsSource:match(
    'function Waypoints:UpdateConfig%(%)(.-)\nend')
assert(updateConfigBody ~= nil, "could not isolate Waypoints:UpdateConfig")
assert(updateConfigBody:find('profile%.announceWaypoint', 1) == nil,
    "the dead profile.announceWaypoint branch must be removed")
assert(updateConfigBody:find('profile%.autoRemoveOnArrival', 1) == nil,
    "the dead profile.autoRemoveOnArrival branch must be removed")
assert(updateConfigBody:find('profile%.arrivalDistance', 1) == nil,
    "the dead profile.arrivalDistance branch must be removed")

print("hs218_w4: item 5 Waypoints pin ok")

-------------------------------------------------------------------------------
-- Item 6: VendorTracer — executable check for the modifier-path fix (module
-- loads standalone cleanly), grep-pins for the rest (dead-fallback removal,
-- arrival-check rewrite, GetVendorDecor wrapper removal).
-------------------------------------------------------------------------------

IsShiftKeyDown = function() return false end
IsControlKeyDown = function() return true end
IsAltKeyDown = function() return false end

local TracerHA = {
    Addon = {
        db = { profile = { vendorTracer = { navigateModifier = "ctrl" } } },
        RegisterModule = function() end,
        Print = function() end,
    },
}

assert(loadfile(root .. "/Modules/VendorTracer.lua"))("Homestead", TracerHA)

local navigateCalls = 0
TracerHA.VendorTracer.NavigateToItemVendor = function(_, itemID)
    navigateCalls = navigateCalls + 1
    return true
end

-- User configured "ctrl" (profile.vendorTracer.navigateModifier); only Ctrl
-- is held (Shift is not). Before the fix, this read the wrong (top-level,
-- always-nil) key and defaulted to "shift", so a Ctrl-click would NOT have
-- navigated. After the fix, it must navigate.
TracerHA.VendorTracer:OnDecorItemClick(12345, "LeftButton")
assert(navigateCalls == 1,
    "a Ctrl-click with navigateModifier=\"ctrl\" configured must navigate (reads profile.vendorTracer.navigateModifier)")

print("hs218_w4: item 6 VendorTracer modifier-path executable check ok")

local tracerSource = assert(io.open(root .. "/Modules/VendorTracer.lua", "r")):read("*a")

-- Dead fallback stack removed.
assert(tracerSource:find('function SetNativeWaypoint', 1) == nil,
    "the dead SetNativeWaypoint fallback must be removed")
-- ClearNativeWaypoint (the only place ClearAllSuperTracked was ever called
-- from — confirmed by direct read during this review) must be gone
-- entirely, not just repaired.
assert(tracerSource:find('function ClearNativeWaypoint', 1) == nil,
    "the dead ClearNativeWaypoint fallback (ClearAllSuperTracked, cancels the player's tracked quest) must be removed")
assert(tracerSource:find('function SetTomTomWaypoint', 1) == nil,
    "the dead SetTomTomWaypoint fallback must be removed")

-- IsTomTomAvailable must survive (still used by Initialize's startup log).
assert(tracerSource:find('function IsTomTomAvailable%(%)', 1) ~= nil,
    "IsTomTomAvailable must still exist")

-- Arrival-check now consults the Waypoints utility, matched by npcID.
local onMerchantShowBody = tracerSource:match(
    'function VendorTracer:OnMerchantShow%(%)(.-)\nend')
assert(onMerchantShowBody ~= nil, "could not isolate OnMerchantShow")
assert(onMerchantShowBody:find('HA%.Waypoints:GetCurrent%(%)', 1) ~= nil,
    "OnMerchantShow must consult HA.Waypoints:GetCurrent() instead of the dead local")
assert(onMerchantShowBody:find('waypoint%.data%.npcID == vendor%.npcID', 1) ~= nil,
    "OnMerchantShow must match by npcID, not a fragile title substring")

print("hs218_w4: item 6 VendorTracer dead-code removal pin ok")

-------------------------------------------------------------------------------
-- Item 6 (core.lua wrapper): GetVendorDecor delegates to a nonexistent
-- method — must be gone.
-------------------------------------------------------------------------------

local coreSource = assert(io.open(root .. "/Core/core.lua", "r")):read("*a")
assert(coreSource:find('function HousingAddon:GetVendorDecor', 1) == nil,
    "the dead GetVendorDecor wrapper (delegates to a nonexistent VendorTracer method) must be removed")

print("hs218_w4: item 6 core.lua wrapper removal pin ok")

-------------------------------------------------------------------------------
-- Item 7: DecorClassifier — executable (self-contained, no WoW-API surface
-- beyond what's easily mocked).
-------------------------------------------------------------------------------

C_HousingCatalog = {
    GetCatalogEntryInfoByItem = function()
        return { entryID = { recordID = 1 }, name = "Test Decor", isOwned = true, quantityOwned = 3 }
    end,
}
Enum = {
    ItemClass = { Housing = 20 },
    ItemHousingSubclass = { Decor = 0 },
}
C_Item = {
    -- GetItemInfoInstant returns itemID, itemType, itemSubType, itemEquipLoc,
    -- icon, classID, subClassID. HS-249's gate reads the 6th/7th returns, so
    -- the mock must supply all seven or the gate tests as permanently false.
    GetItemInfoInstant = function()
        return 99999, "Housing", "Decor", "", 134400, Enum.ItemClass.Housing, Enum.ItemHousingSubclass.Decor
    end,
}

local ClassifierHA = {}
assert(loadfile(root .. "/Modules/DecorClassifier.lua"))("Homestead", ClassifierHA)

local isHousing, subclassID, decorInfo = ClassifierHA.DecorClassifier.ClassifyHousingItem("item:99999")
assert(isHousing == true)
assert(subclassID == Enum.ItemHousingSubclass.Decor)
assert(decorInfo.isOwned == nil, "isOwned must not be present on the returned table (never a real field)")
assert(decorInfo.quantityOwned == nil, "quantityOwned must not be present on the returned table (never a real field)")
assert(decorInfo.name == "Test Decor")

print("hs218_w4: item 7 DecorClassifier ok")
