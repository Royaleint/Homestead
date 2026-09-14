-- luacheck: globals assert loadfile loadstring print io ipairs pairs table string CreateFrame InCombatLockdown HA Enum C_Timer C_Map pcall next tostring

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-338: a plans-only vendor (every filter-matching item ownership-excluded,
-- total == 0, excluded > 0) must name its stock ("11 room plans, 1
-- customization") instead of the dim "No item data" guard, which reads as an
-- absence it isn't.
--
-- Part 1: BadgeCalculation's excludedBySubclass accumulator field, via the
--   public GetVendorStats accessor and parity against the extracted
--   accumulator helpers (hs278 pattern). Includes the mandatory
--   CatalogStore.GetHousingSubclass nil-guard.
-- Part 2: the extracted FormatOwnershipExcludedInventoryText formatter,
--   unit-tested standalone (hs291 extract-and-loadstring pattern).
-- Part 3: string-presence gates on the RefreshSearchResults call site and
--   the forward-reference ordering.
-------------------------------------------------------------------------------

local function readFile(path)
    local f = assert(io.open(path, "r"))
    local content = f:read("*a")
    f:close()
    return content
end

CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript() end
    return frame
end

InCombatLockdown = function() return false end

-- Inert by default -- StartPrewarmPass's loginWarmupTicker fires this once at
-- module load time, so C_Timer must exist before any loadfile call.
C_Timer = {
    NewTicker = function() return { Cancel = function() end } end,
    NewTimer = function() return { Cancel = function() end } end,
    After = function() end,
}
C_Map = { GetBestMapForUnit = function() return nil end }

local badgeSource = readFile(root .. "/UI/BadgeCalculation.lua")
local panelSource = readFile(root .. "/UI/MapSidePanel.lua")

local function extract(source, pattern, label)
    local text = source:match(pattern)
    assert(text, "could not extract " .. label)
    return text
end

-------------------------------------------------------------------------------
-- Part 1: BadgeCalculation excludedBySubclass accumulator
-------------------------------------------------------------------------------

local function NewStubHA(catalogStore)
    return {
        Constants = { VerticalSiblings = {}, ContinentNames = {} },
        MapPinProvider = {
            continentToZones = {}, excludedContinents = {}, continentMergesInto = {},
            continentZoneBadgesOnParent = {}, continentZoneBadgeExclusionsOnParent = {},
            offWorldContinentPositions = {}, manualZoneCenters = {}, zoneNotes = {},
            GetContinentForZone = function() return nil end,
        },
        VendorFilter = {
            GetBestVendorCoordinates = function() return nil, nil end,
        },
        Events = {
            RegisterCallback = function() end,
            Fire = function() end,
        },
        PerformanceTrace = {
            Measure = function(_, _label, _tag, pcallFn, fn) return pcallFn(fn) end,
        },
        CatalogStore = catalogStore,
    }
end

local function LoadBadgeCalculation(HAStub)
    assert(loadfile(root .. "/UI/BadgeCalculation.lua"))("Homestead", HAStub)
    return HAStub.BadgeCalculation
end

local function NewVendorDataStub(itemsByNpc)
    return {
        GetAllVendors = function() return {} end,
        GetMergedItemSet = function(_, vendor, includeOrderedIDs)
            local ids = itemsByNpc[vendor.npcID] or {}
            local set = {}
            for _, id in ipairs(ids) do
                set[id] = true
            end
            if includeOrderedIDs then
                return set, ids
            end
            return set
        end,
    }
end

-- 1a: whole-file load, plans-only vendor with 3 excluded items across two
-- subclasses (Room=2 x2, ExteriorCustomization=4 x1).
local subclassByItem1 = { [96101] = 2, [96102] = 2, [96103] = 4 }
local HA1 = NewStubHA({
    HasPersistedData = function() return true end,
    GetHousingSubclass = function(_, itemID) return subclassByItem1[itemID] end,
})

local presentationFixtures1 = {
    [96101] = { matchesSourceFilter = true, isOwnershipExcluded = true },
    [96102] = { matchesSourceFilter = true, isOwnershipExcluded = true },
    [96103] = { matchesSourceFilter = true, isOwnershipExcluded = true },
}
HA1.SourceManager = {
    GetItemPresentation = function(_, itemID) return presentationFixtures1[itemID] end,
}
local vendor1 = { npcID = 96001 }
HA1.VendorData = NewVendorDataStub({ [vendor1.npcID] = { 96101, 96102, 96103 } })

local BadgeCalc1 = LoadBadgeCalculation(HA1)
local realStats1 = BadgeCalc1:GetVendorStats(vendor1, "all")

assert(realStats1.total == 0, "plans-only vendor must have total == 0")
assert(realStats1.excluded == 3, "plans-only vendor must have excluded == 3")
assert(realStats1.hasUncollectedState == "unknown",
    "plans-only vendor must read as unknown, not false")
assert(realStats1.excludedBySubclass ~= nil, "excludedBySubclass must be present on the early-return path")
assert(realStats1.excludedBySubclass[2] == 2, "expected 2 items under subclass 2 (Room)")
assert(realStats1.excludedBySubclass[4] == 1, "expected 1 item under subclass 4 (ExteriorCustomization)")

-- Parity: extract the three accumulator helpers (plus IsOwnershipExcluded /
-- IsItemVendorOnly, which AccumulateVendorItem calls as upvalues) straight
-- from source, the same technique tests/hs278_item_sliced_prewarm.lua uses,
-- and assert the manually-driven accumulator produces the identical map.
-- This is the mutation catch for "dropping the field from the early-return
-- table" -- assertStatsEqual-style field lists elsewhere ignore new fields,
-- so this direct comparison is what actually pins it.
local isOwnershipExcludedSrc = extract(badgeSource,
    "(local function IsOwnershipExcluded%(itemID, presentation%).-\nend)", "IsOwnershipExcluded")
local isItemVendorOnlySrc = extract(badgeSource,
    "(local function IsItemVendorOnly%(itemID, sources%).-\nend)", "IsItemVendorOnly")
local newVendorStatsAccumSrc = extract(badgeSource,
    "(local function NewVendorStatsAccum%(%).-\nend)", "NewVendorStatsAccum")
local accumulateVendorItemSrc = extract(badgeSource,
    "(local function AccumulateVendorItem%(accum, itemID, vendor, sourceFilter%).-\nend)", "AccumulateVendorItem")
local finalizeVendorStatsAccumSrc = extract(badgeSource,
    "(local function FinalizeVendorStatsAccum%(accum%).-\nend)", "FinalizeVendorStatsAccum")

local extractChunk = table.concat({
    isOwnershipExcludedSrc,
    isItemVendorOnlySrc,
    newVendorStatsAccumSrc,
    accumulateVendorItemSrc,
    finalizeVendorStatsAccumSrc,
    "return NewVendorStatsAccum, AccumulateVendorItem, FinalizeVendorStatsAccum",
}, "\n")

local extractedFn = assert(loadstring(extractChunk, "hs338-accum-extract"))

-- HA is a free (global) variable inside the extracted chunk (the real file
-- scopes it via `local _, HA = ...`, not carried over by extraction).
HA = HA1
local NewVendorStatsAccum, AccumulateVendorItem, FinalizeVendorStatsAccum = extractedFn()

local accum1 = NewVendorStatsAccum()
AccumulateVendorItem(accum1, 96101, vendor1, "all")
AccumulateVendorItem(accum1, 96102, vendor1, "all")
AccumulateVendorItem(accum1, 96103, vendor1, "all")
local manualStats1 = FinalizeVendorStatsAccum(accum1)

assert(manualStats1.excludedBySubclass[2] == realStats1.excludedBySubclass[2],
    "manual accumulator subclass 2 count must match the real GetVendorStats result")
assert(manualStats1.excludedBySubclass[4] == realStats1.excludedBySubclass[4],
    "manual accumulator subclass 4 count must match the real GetVendorStats result")
assert(manualStats1.excluded == realStats1.excluded, "manual/real excluded counts must match")
assert(manualStats1.total == realStats1.total, "manual/real total counts must match")

-- 1b: CatalogStore without GetHousingSubclass -- the mandatory nil-guard.
-- Must not error, and excludedBySubclass must stay empty (mutation caught:
-- an unguarded CS:GetHousingSubclass(itemID) call).
local HA2 = NewStubHA({
    HasPersistedData = function() return true end,
})
local presentationFixtures2 = {
    [96201] = { matchesSourceFilter = true, isOwnershipExcluded = true },
    [96202] = { matchesSourceFilter = true, isOwnershipExcluded = true },
    [96203] = { matchesSourceFilter = true, isOwnershipExcluded = true },
}
HA2.SourceManager = {
    GetItemPresentation = function(_, itemID) return presentationFixtures2[itemID] end,
}
local vendor2 = { npcID = 96002 }
HA2.VendorData = NewVendorDataStub({ [vendor2.npcID] = { 96201, 96202, 96203 } })

local BadgeCalc2 = LoadBadgeCalculation(HA2)
local ok2, realStats2OrErr = pcall(function() return BadgeCalc2:GetVendorStats(vendor2, "all") end)
assert(ok2, "GetVendorStats must not error when CatalogStore lacks GetHousingSubclass: " .. tostring(realStats2OrErr))

local realStats2 = realStats2OrErr
assert(realStats2.excluded == 3, "excluded must still be 3 when subclass resolution is unavailable")
assert(next(realStats2.excludedBySubclass) == nil,
    "excludedBySubclass must stay empty when CatalogStore has no GetHousingSubclass")

print("hs338_plans_only_vendor_row: part 1 (BadgeCalculation accumulator) ok")

-------------------------------------------------------------------------------
-- Part 2: FormatOwnershipExcludedInventoryText (extracted, standalone)
-------------------------------------------------------------------------------

local formatSrc = extract(panelSource,
    "(local function FormatOwnershipExcludedInventoryText%(stats%).-\nend)",
    "FormatOwnershipExcludedInventoryText")

Enum = {
    ItemHousingSubclass = {
        Decor = 0, Dye = 1, Room = 2, RoomCustomization = 3, ExteriorCustomization = 4, ServiceItem = 5,
    },
}

local formatChunk = formatSrc .. "\nreturn FormatOwnershipExcludedInventoryText"
local FormatOwnershipExcludedInventoryText = assert(loadstring(formatChunk, "hs338-format-extract"))()

assert(FormatOwnershipExcludedInventoryText({ excluded = 12, excludedBySubclass = { [2] = 11, [4] = 1 } })
    == "11 room plans, 1 customization",
    "expected Room + ExteriorCustomization merged under 'customization', sorted by count desc")

assert(FormatOwnershipExcludedInventoryText({ excluded = 1, excludedBySubclass = { [2] = 1 } })
    == "1 room plan",
    "expected singular 'room plan' for count == 1")

assert(FormatOwnershipExcludedInventoryText({ excluded = 3, excludedBySubclass = { [1] = 1 } })
    == "1 dye, 2 housing items",
    "expected the unresolved remainder to fall back to 'housing items'")

assert(FormatOwnershipExcludedInventoryText({ excluded = 2, excludedBySubclass = nil })
    == "2 housing items",
    "expected a nil excludedBySubclass map to fall back entirely to 'housing items'")

assert(FormatOwnershipExcludedInventoryText({ excluded = 0 }) == nil,
    "expected nil when nothing is excluded")

print("hs338_plans_only_vendor_row: part 2 (formatter) ok")

-------------------------------------------------------------------------------
-- Part 3: string-presence gates
-------------------------------------------------------------------------------

local refreshSearchResultsBody = extract(panelSource,
    "(function MapSidePanel:RefreshSearchResults%(%).-)\nfunction MapSidePanel:RefreshInstanceDropSources",
    "RefreshSearchResults")
assert(refreshSearchResultsBody:find("FormatOwnershipExcludedInventoryText(stats)", 1, true) ~= nil,
    "RefreshSearchResults must call FormatOwnershipExcludedInventoryText(stats)")

local refreshContentBody = extract(panelSource,
    "(function MapSidePanel:RefreshContent%(%).-)\nfunction ",
    "RefreshContent")
assert(refreshContentBody:find("FormatOwnershipExcludedInventoryText(stats)", 1, true) ~= nil,
    "RefreshContent's zone-list rows must call FormatOwnershipExcludedInventoryText(stats)")

-- Lua 5.1 forward-reference: the helper must be defined textually above
-- RefreshSearchResults, which calls it.
local formatDefPos = panelSource:find("local function FormatOwnershipExcludedInventoryText%(stats%)")
local refreshSearchResultsPos = panelSource:find("function MapSidePanel:RefreshSearchResults%(%)")
assert(formatDefPos and refreshSearchResultsPos and formatDefPos < refreshSearchResultsPos,
    "FormatOwnershipExcludedInventoryText must be defined above RefreshSearchResults")

print("hs338_plans_only_vendor_row: part 3 (string gates) ok")

print("hs338_plans_only_vendor_row: ok")
