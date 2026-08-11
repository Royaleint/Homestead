-- luacheck: globals assert loadfile print io C_Timer C_Map CreateFrame InCombatLockdown GetTimePreciseSec

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Perf cleanup: HS_VENDOR_STATS_WARMED used to fire on EVERY prewarm batch
-- tick, including ticks that completed zero vendors (a mid-vendor time-box
-- break just accumulates one more item into an in-progress slice, without
-- finishing anything). PinFrameFactory's listener walks every rendered
-- vendor pin on each fire (~50x/s with the map open during a pass), so a
-- zero-progress tick paid that walk for nothing. The fix gates the fire on a
-- per-tick completed-vendor count: a vendor "completes" when its stats are
-- finalized into vendorStatsCache or marked UNKNOWN_VENDOR_STATS.
--
-- Scenario A: a single large vendor whose item list spans multiple ticks
--   under the time-box. Ticks that only accumulate mid-vendor must NOT fire;
--   the tick that finally finishes the vendor (also the LAST tick of the
--   vendor loop here, since there is only one vendor) MUST fire.
-- Scenario B: three single-item vendors, each finishing (and consuming the
--   whole per-tick budget) within its own tick -- no mid-vendor breaks at
--   all. Every tick must fire, matching the pre-existing per-completed-
--   vendor cadence exactly (no over-suppression).
-- Scenario C: a vendor with an empty item list (the UNKNOWN_VENDOR_STATS
--   branch, not the FinalizeVendorStatsAccum branch) must also count as a
--   completion and fire.
-------------------------------------------------------------------------------

CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript() end
    return frame
end

InCombatLockdown = function() return false end

-- Must exist before the loadfile calls below: the module's login ticker is
-- created at load time.
C_Timer = {
    NewTicker = function() return { Cancel = function() end } end,
    NewTimer = function() return { Cancel = function() end } end,
    After = function() end,
}
C_Map = { GetBestMapForUnit = function() return nil end }

local function NewStubHA()
    local h = { fireCount = 0 }

    h.stub = {
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
            Fire = function(_, eventName)
                if eventName == "HS_VENDOR_STATS_WARMED" then
                    h.fireCount = h.fireCount + 1
                end
            end,
        },
        PerformanceTrace = {
            Measure = function(_, _label, _tag, pcallFn, fn) return pcallFn(fn) end,
        },
        CatalogStore = {
            HasPersistedData = function() return true end,
        },
    }

    return h
end

local function NewVendorDataStub(itemsByNpc, vendors)
    return {
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
    }
end

-------------------------------------------------------------------------------
-- Scenario A: one 10-item vendor, 2ms/item simulated clock, 4ms budget --
-- exactly 2 items per tick, 5 ticks to finish. Ticks 1-4 must NOT fire;
-- tick 5 (finishes the vendor AND ends the vendor loop) MUST fire.
-------------------------------------------------------------------------------

do
    local h = NewStubHA()
    local processed = 0
    local presentations = {}
    local items = {}
    for i = 1, 10 do
        local itemID = 94000 + i
        items[i] = itemID
        presentations[itemID] = {
            matchesSourceFilter = true, isOwnershipExcluded = false,
            isOwned = false, availabilityState = "purchasable",
        }
    end

    h.stub.SourceManager = {
        GetItemPresentation = function(_, itemID)
            processed = processed + 1
            return presentations[itemID]
        end,
    }

    local vendor = { npcID = 94100 }
    h.stub.VendorData = NewVendorDataStub({ [vendor.npcID] = items }, { vendor })

    GetTimePreciseSec = function() return processed * 0.002 end

    local capturedTriggerCb, capturedAfterCb
    C_Timer = {
        NewTicker = function() return { Cancel = function() end } end,
        NewTimer = function(_, cb) capturedTriggerCb = cb return { Cancel = function() end } end,
        After = function(_, cb) capturedAfterCb = cb end,
    }

    assert(loadfile(root .. "/UI/BadgeCalculation.lua"))("Homestead", h.stub)
    local BadgeCalc = assert(h.stub.BadgeCalculation, "BadgeCalculation did not load")

    BadgeCalc:RequestPrewarm("fire-gate-test-a")
    assert(capturedTriggerCb, "RequestPrewarm must schedule a debounce timer")
    capturedTriggerCb()
    assert(capturedAfterCb, "StartPrewarmPass must schedule the first ProcessBatch tick")

    local fireCountsByTick = {}
    local ticksUsed = 0
    while BadgeCalc:PeekVendorStats(vendor, "all") == nil and ticksUsed < 20 do
        local before = h.fireCount
        local cb = assert(capturedAfterCb, "no ProcessBatch tick was scheduled")
        capturedAfterCb = nil
        cb()
        ticksUsed = ticksUsed + 1
        fireCountsByTick[ticksUsed] = h.fireCount - before
    end

    assert(ticksUsed == 5,
        "expected exactly 5 ticks (2 items/tick, 10 items, 4ms budget), got " .. ticksUsed)
    for i = 1, 4 do
        assert(fireCountsByTick[i] == 0,
            "tick " .. i .. " made zero completion progress on this single vendor (still mid-slice) -- " ..
            "must not fire, got " .. fireCountsByTick[i] .. " fires")
    end
    assert(fireCountsByTick[5] == 1,
        "tick 5 finishes this vendor (and ends the vendor loop) -- must fire exactly once, got " ..
        fireCountsByTick[5] .. " fires")
    assert(h.fireCount == 1,
        "total fires across the whole vendor loop must be 1 (once, not once per tick), got " .. h.fireCount)

    print("prewarm_fire_gate: scenario A (mid-vendor ticks silent, completion tick fires) ok")
end

-------------------------------------------------------------------------------
-- Scenario B: three single-item vendors. Each item costs 5ms against a 4ms
-- budget, so the loop breaks immediately after completing exactly one
-- vendor -- one vendor per tick, no mid-vendor breaks. Every tick must fire.
-------------------------------------------------------------------------------

do
    local h = NewStubHA()
    local processed = 0
    local presentations = {}
    local vendors = {}
    for i = 1, 3 do
        local npcID = 94200 + i
        local itemID = 94300 + i
        vendors[i] = { npcID = npcID }
        presentations[itemID] = {
            matchesSourceFilter = true, isOwnershipExcluded = false,
            isOwned = false, availabilityState = "purchasable",
        }
    end

    local itemsByNpc = {}
    for i, vendor in ipairs(vendors) do
        itemsByNpc[vendor.npcID] = { 94300 + i }
    end

    h.stub.SourceManager = {
        GetItemPresentation = function(_, itemID)
            processed = processed + 1
            return presentations[itemID]
        end,
    }
    h.stub.VendorData = NewVendorDataStub(itemsByNpc, vendors)

    -- 5ms per processed item vs. a 4ms budget: after completing one vendor's
    -- single item, elapsed already exceeds the budget, so the loop breaks
    -- right there -- exactly one vendor completion per tick.
    GetTimePreciseSec = function() return processed * 0.005 end

    local capturedTriggerCb, capturedAfterCb
    C_Timer = {
        NewTicker = function() return { Cancel = function() end } end,
        NewTimer = function(_, cb) capturedTriggerCb = cb return { Cancel = function() end } end,
        After = function(_, cb) capturedAfterCb = cb end,
    }

    assert(loadfile(root .. "/UI/BadgeCalculation.lua"))("Homestead", h.stub)
    local BadgeCalc = assert(h.stub.BadgeCalculation, "BadgeCalculation did not load")

    BadgeCalc:RequestPrewarm("fire-gate-test-b")
    capturedTriggerCb()

    local function allWarm()
        for _, vendor in ipairs(vendors) do
            if BadgeCalc:PeekVendorStats(vendor, "all") == nil then
                return false
            end
        end
        return true
    end

    local fireCountsByTick = {}
    local ticksUsed = 0
    while not allWarm() and ticksUsed < 20 do
        local before = h.fireCount
        local cb = assert(capturedAfterCb, "no ProcessBatch tick was scheduled")
        capturedAfterCb = nil
        cb()
        ticksUsed = ticksUsed + 1
        fireCountsByTick[ticksUsed] = h.fireCount - before
    end

    assert(ticksUsed == 3, "expected exactly 3 ticks (one vendor completion per tick), got " .. ticksUsed)
    for i = 1, 3 do
        assert(fireCountsByTick[i] == 1,
            "tick " .. i .. " completes exactly one vendor -- must fire exactly once, got " ..
            fireCountsByTick[i] .. " fires")
    end
    assert(h.fireCount == 3,
        "no over-suppression: three completing ticks must produce three fires, got " .. h.fireCount)

    print("prewarm_fire_gate: scenario B (one vendor per tick, every tick fires) ok")
end

-------------------------------------------------------------------------------
-- Scenario C: a vendor with an empty item list hits the UNKNOWN_VENDOR_STATS
-- branch (not FinalizeVendorStatsAccum) -- that branch must also count as a
-- completion and fire.
-------------------------------------------------------------------------------

do
    local h = NewStubHA()

    h.stub.SourceManager = {
        GetItemPresentation = function() return nil end,
    }

    local vendor = { npcID = 94400 }
    h.stub.VendorData = NewVendorDataStub({ [vendor.npcID] = {} }, { vendor })

    GetTimePreciseSec = function() return 0 end

    local capturedTriggerCb, capturedAfterCb
    C_Timer = {
        NewTicker = function() return { Cancel = function() end } end,
        NewTimer = function(_, cb) capturedTriggerCb = cb return { Cancel = function() end } end,
        After = function(_, cb) capturedAfterCb = cb end,
    }

    assert(loadfile(root .. "/UI/BadgeCalculation.lua"))("Homestead", h.stub)
    local BadgeCalc = assert(h.stub.BadgeCalculation, "BadgeCalculation did not load")

    BadgeCalc:RequestPrewarm("fire-gate-test-c")
    capturedTriggerCb()

    assert(h.fireCount == 0, "sanity: nothing must fire before the first tick runs")
    local cb = assert(capturedAfterCb, "no ProcessBatch tick was scheduled")
    cb()

    assert(BadgeCalc:PeekVendorStats(vendor, "all") ~= nil,
        "sanity: the empty-item vendor must be resolved (UNKNOWN_VENDOR_STATS) in one tick")
    assert(h.fireCount == 1,
        "the UNKNOWN_VENDOR_STATS branch must count as a completion and fire, got " .. h.fireCount .. " fires")

    print("prewarm_fire_gate: scenario C (empty-item vendor completion fires) ok")
end

print("prewarm_fire_gate: ok")
