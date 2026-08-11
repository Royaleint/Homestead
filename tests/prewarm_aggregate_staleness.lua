-- luacheck: globals assert loadfile print io C_Timer C_Map CreateFrame InCombatLockdown GetTimePreciseSec wipe

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The prewarm pass' aggregate ticks (GetContinentVendorCounts / per-continent
-- GetZoneVendorCounts) are ATOMIC -- the 4ms time-box sits between them, never
-- inside one. The sliced vendor loop that runs before them never revisits a
-- vendor behind its cursor, so a cache wipe landing mid-pass leaves every
-- already-warmed vendor cold while the pass walks on. The aggregates then
-- re-walk ALL of those vendors inside one un-timeboxed call and recompute the
-- whole cold prefix in a single frame -- the freeze this fix removes.
--
-- Scenario A: wipe (generation bump) before the first aggregate tick, with the
--   prewarm-request debounce deliberately NOT fired -- so ONLY the generation
--   arm of the staleness check can catch it. Also drives the rerun to
--   completion and asserts the aggregates end up warm-computed.
-- Scenario B: warmupPendingRerun set with NO generation change -- the other
--   arm on its own.
-- Scenario C: wipe AFTER the continent-totals tick but before the
--   per-continent tick -- pins "before EACH aggregate tick", not just the
--   first.
-------------------------------------------------------------------------------

CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript() end
    return frame
end

InCombatLockdown = function() return false end

wipe = function(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end

-- Must exist before the loadfile calls below: the module's login ticker is
-- created at load time.
C_Timer = {
    NewTicker = function() return { Cancel = function() end } end,
    NewTimer = function() return { Cancel = function() end } end,
    After = function() end,
}
C_Map = {
    GetBestMapForUnit = function() return nil end,
    GetMapInfo = function(mapID) return { name = "Map" .. tostring(mapID) } end,
}

local TEST_CONTINENT = 1000
local TEST_ZONE = 1001

-------------------------------------------------------------------------------
-- Harness: two 3-item vendors, both in one zone on one continent, a 2ms-per-
-- item simulated clock (so the 4ms budget yields after 2 items), and a
-- PerformanceTrace stub that records every batch unit's tag alongside how many
-- item presentations it cost -- a recorded aggregate tag with a non-zero cost
-- IS the cold recompute this fix prevents.
-------------------------------------------------------------------------------

local function NewHarness()
    local h = { processed = 0, traces = {} }

    local vendors = { { npcID = 70001 }, { npcID = 70002 } }
    local itemsByNpc = { [70001] = {}, [70002] = {} }
    local presentations = {}
    for v, vendor in ipairs(vendors) do
        for i = 1, 3 do
            local itemID = 70000 + v * 100 + i
            itemsByNpc[vendor.npcID][i] = itemID
            presentations[itemID] = {
                matchesSourceFilter = true, isOwnershipExcluded = false,
                isOwned = false, availabilityState = "purchasable",
            }
        end
    end
    h.vendors = vendors

    local stubHA = {
        Constants = { VerticalSiblings = {}, ContinentNames = { [TEST_CONTINENT] = "Testlands" } },
        MapPinProvider = {
            continentToZones = {}, excludedContinents = {}, continentMergesInto = {},
            continentZoneBadgesOnParent = {}, continentZoneBadgeExclusionsOnParent = {},
            offWorldContinentPositions = {}, manualZoneCenters = {}, zoneNotes = {},
            GetContinentForZone = function(zoneMapID)
                return zoneMapID == TEST_ZONE and TEST_CONTINENT or nil
            end,
        },
        VendorFilter = {
            GetBestVendorCoordinates = function() return { x = 0.5, y = 0.5 }, TEST_ZONE end,
            ShouldShowOppositeFaction = function() return false end,
            ShouldHideVendor = function() return false end,
            CanAccessVendor = function() return true end,
            IsOppositeFaction = function() return false end,
        },
        Events = {
            RegisterCallback = function() end,
            Fire = function() end,
        },
        PerformanceTrace = {
            Measure = function(_, label, tag, pcallFn, fn)
                local before = h.processed
                local ok = pcallFn(fn)
                h.traces[#h.traces + 1] = { label = label, tag = tag, cost = h.processed - before }
                return ok
            end,
        },
        CatalogStore = {
            HasPersistedData = function() return true end,
        },
        SourceManager = {
            GetItemPresentation = function(_, itemID)
                h.processed = h.processed + 1
                return presentations[itemID]
            end,
        },
        VendorData = {
            GetAllVendors = function() return vendors end,
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
        },
    }

    GetTimePreciseSec = function() return h.processed * 0.002 end

    C_Timer = {
        NewTicker = function() return { Cancel = function() end } end,
        NewTimer = function(_, cb) h.debounceCb = cb return { Cancel = function() end } end,
        After = function(_, cb) h.tickCb = cb end,
    }

    assert(loadfile(root .. "/UI/BadgeCalculation.lua"))("Homestead", stubHA)
    h.BadgeCalc = assert(stubHA.BadgeCalculation, "BadgeCalculation did not load")

    function h:Tick()
        local cb = assert(self.tickCb, "no ProcessBatch tick was scheduled")
        self.tickCb = nil
        cb()
    end

    function h:AllVendorsWarm()
        for _, vendor in ipairs(self.vendors) do
            if self.BadgeCalc:PeekVendorStats(vendor, "all") == nil then
                return false
            end
        end
        return true
    end

    -- Drives ticks until every vendor is cached; the NEXT tick is then the
    -- first aggregate tick.
    function h:RunVendorLoop()
        local ticks = 0
        while not self:AllVendorsWarm() and ticks < 30 do
            self:Tick()
            ticks = ticks + 1
        end
        assert(self:AllVendorsWarm(), "vendor loop never finished warming both vendors")
        assert(ticks > 1, "the vendor loop must span multiple ticks for this test to be meaningful")
        return ticks
    end

    function h:StartPass()
        self.BadgeCalc:RequestPrewarm("staleness-test")
        assert(self.debounceCb, "RequestPrewarm must schedule a debounce timer")
        local cb = self.debounceCb
        self.debounceCb = nil
        cb()
        assert(self.tickCb, "StartPrewarmPass must schedule the first ProcessBatch tick")
    end

    function h:TraceCount(tag)
        local n = 0
        for _, trace in ipairs(self.traces) do
            if trace.tag == tag then
                n = n + 1
            end
        end
        return n
    end

    function h:FindTrace(tag)
        for _, trace in ipairs(self.traces) do
            if trace.tag == tag then
                return trace
            end
        end
        return nil
    end

    return h
end

-------------------------------------------------------------------------------
-- Scenario A: generation arm alone, plus the rerun's end-to-end behavior
-------------------------------------------------------------------------------

local A = NewHarness()
A:StartPass()
A:RunVendorLoop()

assert(A:TraceCount("continent_totals") == 0, "no aggregate should have run yet")

-- The wipe: every vendor warmed above is now cold, and the pass is sitting
-- exactly one tick short of the continent-totals aggregate. InvalidateAllCaches
-- also requests a fresh prewarm, but its debounce timer is deliberately left
-- unfired -- warmupPendingRerun is therefore still false, so ONLY the
-- generation arm can catch this.
A.BadgeCalc:InvalidateAllCaches()
assert(not A:AllVendorsWarm(), "InvalidateAllCaches must leave the warmed vendors cold")

local processedBeforeSkip = A.processed
A:Tick()

assert(A:TraceCount("continent_totals") == 0,
    "the continent-totals aggregate must be SKIPPED when the cache was wiped mid-pass -- " ..
    "without the staleness check it runs here and recomputes every cold vendor in one frame")
assert(A:TraceCount(TEST_CONTINENT) == 0, "the per-continent aggregate must be skipped too")
assert(A.processed == processedBeforeSkip,
    "the skipped tick must not recompute a single item presentation, got " ..
    (A.processed - processedBeforeSkip))

-- ...and the rerun still happens: a full fresh pass, re-warming the vendors and
-- only then running the aggregates.
assert(A.tickCb ~= nil, "the skip must hand off to a rerun, not end the prewarm chain")
A:RunVendorLoop()

local ticks = 0
while A:TraceCount(TEST_CONTINENT) == 0 and ticks < 10 do
    A:Tick()
    ticks = ticks + 1
end

local totalsTrace = A:FindTrace("continent_totals")
local continentTrace = A:FindTrace(TEST_CONTINENT)
assert(totalsTrace, "the rerun must eventually warm the continent totals")
assert(continentTrace, "the rerun must eventually warm the per-continent zone counts")
assert(totalsTrace.cost == 0,
    "the continent-totals aggregate must only ever run against a warm cache (0 presentation " ..
    "calls), cost was " .. totalsTrace.cost)
assert(continentTrace.cost == 0,
    "the per-continent aggregate must only ever run against a warm cache, cost was " .. continentTrace.cost)

print("prewarm_aggregate_staleness: scenario A (generation arm + rerun) ok")

-------------------------------------------------------------------------------
-- Scenario B: warmupPendingRerun arm alone (no generation change)
-------------------------------------------------------------------------------

local B = NewHarness()
B:StartPass()
B:RunVendorLoop()

-- A second prewarm request lands mid-pass and its debounce fires: the
-- reentrancy guard coalesces it into warmupPendingRerun. Nothing was
-- invalidated, so the generation is unchanged -- this is the other arm.
B.BadgeCalc:RequestPrewarm("second-trigger")
assert(B.debounceCb, "the second request must schedule its own debounce timer")
local coalesceCb = B.debounceCb
B.debounceCb = nil
coalesceCb()

B:Tick()

assert(B:TraceCount("continent_totals") == 0,
    "with a rerun already pending, the aggregate ticks must be skipped -- the pending full " ..
    "pass is about to redo them anyway")
assert(B.tickCb ~= nil, "the pending rerun must still be started")

-- Nothing was invalidated here, so the rerun's vendor loop finds every vendor
-- already cached and walks straight through to the aggregates.
local ticksB = 0
while B:TraceCount(TEST_CONTINENT) == 0 and ticksB < 20 do
    B:Tick()
    ticksB = ticksB + 1
end
assert(B:FindTrace("continent_totals"), "the rerun must warm the continent totals")
assert(B:FindTrace(TEST_CONTINENT), "the rerun must warm the per-continent zone counts")

print("prewarm_aggregate_staleness: scenario B (pending-rerun arm) ok")

-------------------------------------------------------------------------------
-- Scenario C: the wipe lands BETWEEN the two aggregate ticks
-------------------------------------------------------------------------------

local C = NewHarness()
C:StartPass()
C:RunVendorLoop()

C:Tick() -- continent-totals tick, warm cache
local totalsC = C:FindTrace("continent_totals")
assert(totalsC and totalsC.cost == 0, "the first aggregate tick must run warm here")
assert(C:TraceCount(TEST_CONTINENT) == 0, "the per-continent tick has not run yet")

C.BadgeCalc:InvalidateAllCaches()
local processedBeforeC = C.processed
C:Tick()

assert(C:TraceCount(TEST_CONTINENT) == 0,
    "a wipe landing between aggregate ticks must skip the REMAINING ticks -- checking " ..
    "staleness only before the first one leaves this per-continent tick recomputing cold")
assert(C.processed == processedBeforeC,
    "the skipped per-continent tick must not recompute any item presentation, got " ..
    (C.processed - processedBeforeC))

print("prewarm_aggregate_staleness: scenario C (each tick, not just the first) ok")

print("prewarm_aggregate_staleness: ok")
