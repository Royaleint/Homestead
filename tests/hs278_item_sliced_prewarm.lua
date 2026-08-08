-- luacheck: globals assert loadfile loadstring print io C_Timer C_Map CreateFrame InCombatLockdown HA GetTimePreciseSec

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-278: the prewarm pass' vendor-stats item loop is now resumable mid-vendor
-- so the 4ms time-box can interrupt it between ITEMS, not just between
-- vendors -- zoning into a housing-dense zone used to run one huge vendor's
-- whole item list synchronously regardless of the time-box (the freeze this
-- ticket fixes).
--
-- Part 1: parity -- BuildVendorStats (via the public GetVendorStats
--   accessor) vs manually driving the extracted NewVendorStatsAccum /
--   AccumulateVendorItem / FinalizeVendorStatsAccum helpers across multiple
--   simulated slices, for an empty vendor, an all-excluded vendor, and a
--   mixed collected/purchasable/locked/unobtainable/excluded vendor.
-- Part 2: mid-vendor interruption -- the actual fix, must fail if reverted.
-- Part 3: invalidation-safety -- a generation bump mid-slice must discard
--   the in-progress accumulator, never blend pre/post-invalidation state.
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
-- module load time (line ~1217), so C_Timer must exist and support NewTicker
-- before ANY of the three loadfile calls below, even the ones (Part 1) that
-- never drive a prewarm pass.
C_Timer = {
    NewTicker = function() return { Cancel = function() end } end,
    NewTimer = function() return { Cancel = function() end } end,
    After = function() end,
}
C_Map = { GetBestMapForUnit = function() return nil end }

local badgeSource = readFile(root .. "/UI/BadgeCalculation.lua")

-------------------------------------------------------------------------------
-- Part 0: source-pattern pins on the HS-278 mechanism itself.
-------------------------------------------------------------------------------

assert(badgeSource:find("local vendorStatsCacheGeneration = 0", 1, true) ~= nil,
    "expected the vendorStatsCacheGeneration counter local")

local invalidateAllBody = badgeSource:match("function BadgeCalculation:InvalidateAllCaches%(%)(.-)\nend")
assert(invalidateAllBody and invalidateAllBody:find("vendorStatsCacheGeneration = vendorStatsCacheGeneration %+ 1", 1) ~= nil,
    "InvalidateAllCaches must bump vendorStatsCacheGeneration")

local invalidateVendorBody = badgeSource:match("function BadgeCalculation:InvalidateVendorCache%(npcID%)(.-)\nend")
assert(invalidateVendorBody and invalidateVendorBody:find("vendorStatsCacheGeneration = vendorStatsCacheGeneration %+ 1", 1) ~= nil,
    "InvalidateVendorCache must bump vendorStatsCacheGeneration")

-- Lua 5.1 forward-reference: the three accumulator helpers must be defined
-- textually ABOVE BuildVendorStats, which calls them.
local accumDefPos = badgeSource:find("local function NewVendorStatsAccum%(%)")
local buildVendorStatsPos = badgeSource:find("local function BuildVendorStats%(vendor, sourceFilter%)")
assert(accumDefPos and buildVendorStatsPos and accumDefPos < buildVendorStatsPos,
    "NewVendorStatsAccum/AccumulateVendorItem/FinalizeVendorStatsAccum must be defined above BuildVendorStats")

-- BuildVendorStats must use the stable ORDERED item array (shared iteration
-- order with the sliced prewarm loop), not the old unordered pairs(items).
local buildVendorStatsBody = badgeSource:match("local function BuildVendorStats%(vendor, sourceFilter%)(.-)\nend")
assert(buildVendorStatsBody and buildVendorStatsBody:find("GetMergedItemSet(vendor, true)", 1, true) ~= nil,
    "BuildVendorStats must request the ordered item array via GetMergedItemSet(vendor, true)")
assert(buildVendorStatsBody and buildVendorStatsBody:find("pairs(items)", 1, true) == nil,
    "BuildVendorStats must no longer iterate the key-only items map with pairs()")

-------------------------------------------------------------------------------
-- Shared stub builders
-------------------------------------------------------------------------------

local function NewStubHA()
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
        CatalogStore = {
            HasPersistedData = function() return true end,
        },
    }
end

local function LoadBadgeCalculation(HA)
    assert(loadfile(root .. "/UI/BadgeCalculation.lua"))("Homestead", HA)
    return HA.BadgeCalculation
end

-- Builds a fixture-driven VendorData stub: itemsByNpc maps npcID -> ordered
-- item ID array.
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

local function assertStatsEqual(a, b, label)
    for _, field in ipairs({
        "hasUncollectedState", "collected", "purchasable", "locked",
        "unverified", "unobtainable", "excluded", "total",
    }) do
        assert(a[field] == b[field],
            label .. ": field '" .. field .. "' mismatch (" .. tostring(a[field]) .. " vs " .. tostring(b[field]) .. ")")
    end
    if a.blockers == nil or b.blockers == nil then
        assert(a.blockers == b.blockers, label .. ": blockers nil-ness mismatch")
    else
        assert(#a.blockers == #b.blockers, label .. ": blockers length mismatch")
        for i = 1, #a.blockers do
            assert(a.blockers[i].label == b.blockers[i].label and a.blockers[i].count == b.blockers[i].count,
                label .. ": blockers[" .. i .. "] mismatch")
        end
    end
end

-------------------------------------------------------------------------------
-- Part 1: parity
-------------------------------------------------------------------------------

-- Extract the three accumulator helpers plus the one local they call
-- (IsOwnershipExcluded) straight from source -- the same extract-and-load
-- technique tests/hs210_guards.lua and tests/hs208_minimap_pin_spikes.lua use
-- for logic embedded in local functions. ItemMatchesSourceFilter is only
-- reached via AccumulateVendorItem's `not presentation and ...` fallback,
-- which short-circuits away entirely when every fixture below supplies a
-- presentation -- no need to extract it too.
local function extract(pattern, label)
    local text = badgeSource:match(pattern)
    assert(text, "could not extract " .. label .. " from BadgeCalculation.lua")
    return text
end

local isOwnershipExcludedSrc = extract(
    "(local function IsOwnershipExcluded%(itemID, presentation%).-\nend)", "IsOwnershipExcluded")
local newVendorStatsAccumSrc = extract(
    "(local function NewVendorStatsAccum%(%).-\nend)", "NewVendorStatsAccum")
local accumulateVendorItemSrc = extract(
    "(local function AccumulateVendorItem%(accum, itemID, vendor, sourceFilter%).-\nend)", "AccumulateVendorItem")
local finalizeVendorStatsAccumSrc = extract(
    "(local function FinalizeVendorStatsAccum%(accum%).-\nend)", "FinalizeVendorStatsAccum")

local extractChunk = table.concat({
    isOwnershipExcludedSrc,
    newVendorStatsAccumSrc,
    accumulateVendorItemSrc,
    finalizeVendorStatsAccumSrc,
    "return NewVendorStatsAccum, AccumulateVendorItem, FinalizeVendorStatsAccum",
}, "\n")

local extractedFn = assert(loadstring(extractChunk, "hs278-accum-extract"))

local HA1 = NewStubHA()

local presentationFixtures1 = {
    -- All-excluded vendor's two items.
    [91101] = { matchesSourceFilter = true, isOwnershipExcluded = true },
    [91102] = { matchesSourceFilter = true, isOwnershipExcluded = true },
    -- Mixed vendor's five items: collected, purchasable, locked (w/ blocker), unobtainable, excluded.
    [91201] = { matchesSourceFilter = true, isOwnershipExcluded = false, isOwned = true, availabilityState = "owned" },
    [91202] = { matchesSourceFilter = true, isOwnershipExcluded = false, isOwned = false, availabilityState = "purchasable" },
    [91203] = { matchesSourceFilter = true, isOwnershipExcluded = false, isOwned = false, availabilityState = "locked", blockerLabels = { "Reputation" } },
    [91204] = { matchesSourceFilter = true, isOwnershipExcluded = false, isOwned = false, availabilityState = "unobtainable" },
    [91205] = { matchesSourceFilter = true, isOwnershipExcluded = true },
}

HA1.SourceManager = {
    GetItemPresentation = function(_, itemID) return presentationFixtures1[itemID] end,
}
HA1.VendorData = NewVendorDataStub({
    [91002] = { 91101, 91102 },
    [91003] = { 91201, 91202, 91203, 91204, 91205 },
})

local BadgeCalc1 = LoadBadgeCalculation(HA1)

-- HA is a free (global) variable inside the extracted chunk's functions
-- (the real file scopes it via `local _, HA = ...` at the top, which the
-- extraction above deliberately does not carry over) -- point it at the
-- SAME stub the real module above uses so both paths see identical data.
HA = HA1
local NewVendorStatsAccum, AccumulateVendorItem, FinalizeVendorStatsAccum = extractedFn()

-- 1a: fully empty vendor (no item data at all) -- BuildVendorStats short-
-- circuits to UNKNOWN_VENDOR_STATS before ever touching the accumulator.
-- This is the OTHER early-exit shape from 1b below.
local vendorEmpty = { npcID = 91001 }
local realEmpty = BadgeCalc1:GetVendorStats(vendorEmpty, "all")
assert(realEmpty.hasUncollectedState == "unknown" and realEmpty.total == 0
    and realEmpty.excluded == 0 and realEmpty.blockers == nil,
    "a vendor with no item data must return the UNKNOWN_VENDOR_STATS shape")

-- 1b: all-excluded vendor -- known-empty ("unknown", since excluded > 0),
-- driven through the extracted accumulator across two simulated slices
-- (one item per tick).
local vendorExcluded = { npcID = 91002 }
local realExcluded = BadgeCalc1:GetVendorStats(vendorExcluded, "all")

local accumExcluded = NewVendorStatsAccum()
AccumulateVendorItem(accumExcluded, 91101, vendorExcluded, "all") -- slice 1
AccumulateVendorItem(accumExcluded, 91102, vendorExcluded, "all") -- slice 2 (resumed)
local manualExcluded = FinalizeVendorStatsAccum(accumExcluded)

assertStatsEqual(realExcluded, manualExcluded, "all-excluded vendor")
assert(realExcluded.hasUncollectedState == "unknown", "all-excluded vendor must read as unknown, not false")

-- 1c: mixed vendor -- full populated shape with a sorted blocker list,
-- driven across two simulated slices of different sizes.
local vendorMixed = { npcID = 91003 }
local realMixed = BadgeCalc1:GetVendorStats(vendorMixed, "all")

local accumMixed = NewVendorStatsAccum()
AccumulateVendorItem(accumMixed, 91201, vendorMixed, "all") -- slice 1
AccumulateVendorItem(accumMixed, 91202, vendorMixed, "all") -- slice 1
AccumulateVendorItem(accumMixed, 91203, vendorMixed, "all") -- slice 2 (resumed)
AccumulateVendorItem(accumMixed, 91204, vendorMixed, "all") -- slice 2
AccumulateVendorItem(accumMixed, 91205, vendorMixed, "all") -- slice 2
local manualMixed = FinalizeVendorStatsAccum(accumMixed)

assertStatsEqual(realMixed, manualMixed, "mixed vendor")
assert(realMixed.collected == 1 and realMixed.purchasable == 1 and realMixed.locked == 1
    and realMixed.unobtainable == 1 and realMixed.excluded == 1 and realMixed.total == 3,
    "sanity: mixed vendor fixture must produce one of each counted state")

print("hs278_item_sliced_prewarm: part 1 (parity) ok")

-------------------------------------------------------------------------------
-- Part 2: mid-vendor interruption (the actual fix -- must fail if reverted)
-------------------------------------------------------------------------------

local HA2 = NewStubHA()

local processedCount2 = 0
local presentationFixtures2 = {}
local vendor2Items = {}
for i = 1, 10 do
    local itemID = 92000 + i
    vendor2Items[i] = itemID
    presentationFixtures2[itemID] = {
        matchesSourceFilter = true, isOwnershipExcluded = false, isOwned = false, availabilityState = "purchasable",
    }
end

HA2.SourceManager = {
    GetItemPresentation = function(_, itemID)
        processedCount2 = processedCount2 + 1
        return presentationFixtures2[itemID]
    end,
}

local vendor2 = { npcID = 92100 }
HA2.VendorData = NewVendorDataStub({ [vendor2.npcID] = vendor2Items })
HA2.VendorData.GetAllVendors = function() return { vendor2 } end

-- Simulated clock: 2ms of "cost" per SM.GetItemPresentation call.
-- WARMUP_BATCH_TIME_MS is 4ms, so the budget should trip after 2 items --
-- nowhere near this vendor's 10.
GetTimePreciseSec = function() return processedCount2 * 0.002 end

local capturedTriggerCb2, capturedAfterCb2
C_Timer = {
    NewTicker = function() return { Cancel = function() end } end,
    NewTimer = function(_, cb) capturedTriggerCb2 = cb return { Cancel = function() end } end,
    After = function(_, cb) capturedAfterCb2 = cb end,
}

local BadgeCalc2 = LoadBadgeCalculation(HA2)

BadgeCalc2:RequestPrewarm("hs278-test")
assert(capturedTriggerCb2, "RequestPrewarm must schedule a debounce timer")
capturedTriggerCb2()
assert(capturedAfterCb2, "StartPrewarmPass must schedule the first ProcessBatch tick")

capturedAfterCb2() -- first tick

assert(BadgeCalc2:PeekVendorStats(vendor2, "all") == nil,
    "a single 4ms-budget tick must NOT finish this 10-item vendor in one call -- " ..
    "reverting to the unsliced per-vendor loop would finish (and cache) it right here")
assert(processedCount2 > 0 and processedCount2 < 10,
    "the first tick must process SOME but not ALL of this vendor's items before yielding, got " .. processedCount2)

local ticksUsed = 1
while BadgeCalc2:PeekVendorStats(vendor2, "all") == nil and ticksUsed < 20 do
    capturedAfterCb2()
    ticksUsed = ticksUsed + 1
end

assert(BadgeCalc2:PeekVendorStats(vendor2, "all") ~= nil,
    "the vendor must eventually finish warming across multiple resumed ticks")
assert(ticksUsed > 1, "finishing this vendor must take more than one tick")

print("hs278_item_sliced_prewarm: part 2 (mid-vendor interruption) ok")

-------------------------------------------------------------------------------
-- Part 3: invalidation-safety
-------------------------------------------------------------------------------

local HA3 = NewStubHA()

local processedCount3 = 0
local presentationFixtures3 = {}
local vendor3Items = {}
for i = 1, 6 do
    local itemID = 93000 + i
    vendor3Items[i] = itemID
    presentationFixtures3[itemID] = {
        matchesSourceFilter = true, isOwnershipExcluded = false, isOwned = false, availabilityState = "purchasable",
    }
end

HA3.SourceManager = {
    GetItemPresentation = function(_, itemID)
        processedCount3 = processedCount3 + 1
        return presentationFixtures3[itemID]
    end,
}

local vendor3 = { npcID = 93100 }
HA3.VendorData = NewVendorDataStub({ [vendor3.npcID] = vendor3Items })
HA3.VendorData.GetAllVendors = function() return { vendor3 } end

GetTimePreciseSec = function() return processedCount3 * 0.002 end

local capturedTriggerCb3, capturedAfterCb3
C_Timer = {
    NewTicker = function() return { Cancel = function() end } end,
    NewTimer = function(_, cb) capturedTriggerCb3 = cb return { Cancel = function() end } end,
    After = function(_, cb) capturedAfterCb3 = cb end,
}

local BadgeCalc3 = LoadBadgeCalculation(HA3)

BadgeCalc3:RequestPrewarm("hs278-test")
capturedTriggerCb3()
capturedAfterCb3() -- tick 1: processes exactly 2 of the 6 items (2ms/item, 4ms budget)

assert(BadgeCalc3:PeekVendorStats(vendor3, "all") == nil, "vendor must still be mid-slice after tick 1")
assert(processedCount3 == 2,
    "tick 1 must process exactly 2 of the 6 items given the 2ms/item clock and 4ms budget, got " .. processedCount3)

-- Mid-slice invalidation: bump the generation via the public
-- InvalidateVendorCache, AND change what item 1 now reports -- simulating a
-- live ownership change landing while the slice sits paused between ticks.
presentationFixtures3[93001].availabilityState = "locked"
presentationFixtures3[93001].blockerLabels = { "TestBlocker" }
BadgeCalc3:InvalidateVendorCache(vendor3.npcID)

-- Resume: must restart from item 1 under its NEW state, not continue from
-- item 3 with the old item 1-2 accumulation baked in.
local resumeTicks = 0
while BadgeCalc3:PeekVendorStats(vendor3, "all") == nil and resumeTicks < 20 do
    capturedAfterCb3()
    resumeTicks = resumeTicks + 1
end

local finalStats = BadgeCalc3:PeekVendorStats(vendor3, "all")
assert(finalStats ~= nil, "vendor must eventually finish warming after the invalidation")

-- Correct (post-fix) behavior: item 1 is reprocessed under its NEW ("locked")
-- state, so exactly 1 locked + 5 purchasable. A blend bug (no generation
-- check) would instead keep the two pre-invalidation items' OLD
-- ("purchasable") reading baked into the accumulator, reporting 6
-- purchasable and 0 locked instead.
assert(finalStats.locked == 1,
    "expected exactly 1 locked item (item 1's post-invalidation state), got " .. tostring(finalStats.locked))
assert(finalStats.purchasable == 5,
    "expected exactly 5 purchasable items, got " .. tostring(finalStats.purchasable))
assert(finalStats.total == 6, "expected all 6 items counted exactly once, got " .. tostring(finalStats.total))
assert(finalStats.blockers and finalStats.blockers[1].label == "TestBlocker" and finalStats.blockers[1].count == 1,
    "expected the post-invalidation blocker label to appear in the final cached stats")

print("hs278_item_sliced_prewarm: part 3 (invalidation-safety) ok")

print("hs278_item_sliced_prewarm: ok")
