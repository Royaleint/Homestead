-- luacheck: globals assert loadfile print io select unpack C_AddOnProfiler GetTimePreciseSec InCombatLockdown C_Timer
--
-- Public performance-trace facade (Core/PerformanceTrace.lua) must always run
-- its callback and preserve every return value. The development-build
-- backend registers with the facade via SetBackend and adds bounded,
-- outside-combat MeasureCall observation on top of that pass-through.
--
-- The backend lives outside this repository, so the caller supplies its
-- directory:  lua tests/hs239_performance_trace.lua <repoRoot> <backendDir>
-- where <backendDir> contains PerformanceTrace.lua.

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")
local backendDir = select(2, ...)
assert(backendDir, "usage: lua tests/hs239_performance_trace.lua <repoRoot> <backendDir>")
backendDir = backendDir:gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The facade must exist. This is the required RED result before
-- Core/PerformanceTrace.lua is written -- a missing-feature assertion, not a
-- nil-harness crash.
-------------------------------------------------------------------------------

local facadeChunk = loadfile(root .. "/Core/PerformanceTrace.lua")
assert(facadeChunk, "Core/PerformanceTrace.lua is missing (facade not yet implemented)")

local HA = {}
facadeChunk("Homestead", HA)

assert(HA.PerformanceTrace, "HA.PerformanceTrace facade must exist")
assert(type(HA.PerformanceTrace.Measure) == "function", "PerformanceTrace:Measure must exist")
assert(type(HA.PerformanceTrace.SetBackend) == "function", "PerformanceTrace:SetBackend must exist")

-------------------------------------------------------------------------------
-- Pass-through contract with NO backend registered (player build).
-- Measure must call the callback directly and preserve every return value.
-------------------------------------------------------------------------------

local first, second = HA.PerformanceTrace:Measure("bag_refresh", 3, function(a, b)
    return a + b, "preserved"
end, 2, 5)

assert(first == 7, "Measure must preserve first callback return")
assert(second == "preserved", "Measure must preserve subsequent callback returns")

-- No profiler API exists in this bare harness at all; if pass-through ever
-- tried to touch it, this would already have errored above.

-------------------------------------------------------------------------------
-- Backend behaviors, loaded from the caller-supplied backend directory.
-------------------------------------------------------------------------------

local backendChunk = loadfile(backendDir .. "/PerformanceTrace.lua")
assert(backendChunk, "PerformanceTrace.lua is missing from the backend directory")

-- Stub profiler surface. MeasureCall is a controllable stub: each test phase
-- below sets `nextResults`/`nextRawReturns` before invoking the traced call.
local measureCallCount = 0
local nextResults
C_AddOnProfiler = {
    MeasureCall = function(fn, ...)
        measureCallCount = measureCallCount + 1
        local raw = { fn(...) }
        if nextResults == "ERROR_IF_CALLED" then
            error("MeasureCall must not be called while disarmed/combat/malformed-skip")
        end
        return nextResults, unpack(raw)
    end,
}

local preciseTime = 1000.0
GetTimePreciseSec = function() return preciseTime end

local inCombat = false
InCombatLockdown = function() return inCombat end

local Backend = {}
backendChunk("HomesteadBackend", Backend)

assert(Backend.PerformanceTrace, "Backend.PerformanceTrace backend must exist")

-- The session marker must be captured at backend LOAD, not at first Arm --
-- a Sentry read before anyone has armed the trace must not see a nil
-- marker (that would be a fourth, unenumerated state alongside missing/
-- malformed/stale/present).
assert(_G.HomesteadPerfSnapshot.sessionMarker == preciseTime,
    "sessionMarker must be captured at backend load, before any Arm() call")

HA.PerformanceTrace:SetBackend(Backend.PerformanceTrace)

-------------------------------------------------------------------------------
-- Disarmed by default: MeasureCall must never be touched, callback still runs.
-------------------------------------------------------------------------------

nextResults = "ERROR_IF_CALLED"
local dOk = HA.PerformanceTrace:Measure("bag_refresh", 1, function() return "disarmed-ok" end)
assert(dOk == "disarmed-ok", "callback must run while disarmed")
assert(measureCallCount == 0, "MeasureCall must not run while the backend trace is disarmed")

-------------------------------------------------------------------------------
-- Arm the trace. 60-second cap: requesting more than 60s clamps to 60.
-------------------------------------------------------------------------------

local armedSeconds = Backend.PerformanceTrace:Arm(120)
assert(armedSeconds == 60, "Arm(120) must clamp to the 60-second cap, got " .. tostring(armedSeconds))

-- Discriminate the clamp from the return value alone: prove the CLAMPED
-- duration is what actually got armed, not the raw requested 120s. At +61s
-- the trace must already read disarmed; if Arm had silently armed for the
-- raw 120s while only returning 60, IsArmed() would still be true here.
preciseTime = preciseTime + 61
assert(not Backend.PerformanceTrace:IsArmed(),
    "Arm(120) must actually arm for the clamped 60s, not the raw requested 120s")
preciseTime = preciseTime - 61

local shortArm = Backend.PerformanceTrace:Arm(10)
assert(shortArm == 10, "Arm(10) must honor an explicit sub-cap duration")

-------------------------------------------------------------------------------
-- Armed + profiler present + no combat: MeasureCall runs, return values
-- preserved, and a result at/above threshold is recorded.
-------------------------------------------------------------------------------

nextResults = { elapsedMilliseconds = 9.5, allocatedBytes = 2048 }
local a1, a2 = HA.PerformanceTrace:Measure("world_map_refresh", 42, function(x, y)
    return x * 2, y .. "!"
end, 5, "hi")
assert(a1 == 10 and a2 == "hi!", "armed measured call must still preserve callback returns")
assert(measureCallCount == 1, "armed call outside combat must invoke MeasureCall")

local snapshot = _G.HomesteadPerfSnapshot
assert(type(snapshot) == "table", "HomesteadPerfSnapshot global data table must exist")
assert(type(snapshot.sessionMarker) ~= "nil", "snapshot must carry a session marker")
assert(type(snapshot.records) == "table", "snapshot must carry a records ring")
assert(type(snapshot.counters) == "table", "snapshot must carry per-operation counters")

local wmrCounters = snapshot.counters.world_map_refresh
assert(wmrCounters, "world_map_refresh counters must exist after a measured call")
assert(wmrCounters.totalCalls == 1, "totalCalls must increment on every measured call")
assert(wmrCounters.slowCalls == 1, "a 9.5ms call must count as slow against the default threshold")
assert(wmrCounters.worstElapsedMs == 9.5)

assert(#snapshot.records == 1, "a slow call must push exactly one ring record")
local rec = snapshot.records[1]
assert(rec.operation == "world_map_refresh")
assert(rec.elapsedMs == 9.5)
assert(rec.allocatedBytes == 2048, "allocatedBytes must be read directly from MeasureCall results when present")
assert(rec.workload == 42, "the caller-supplied workload must be recorded")
assert(rec.capturedAt == preciseTime, "record capture time must come from GetTimePreciseSec")
assert(rec.synthetic == false or rec.synthetic == nil,
    "organic calls must not be flagged synthetic")

-------------------------------------------------------------------------------
-- Per-operation thresholds: a fast call on the SAME operation must not push
-- a ring record, but must still count toward totalCalls/worstElapsedMs.
-------------------------------------------------------------------------------

nextResults = { elapsedMilliseconds = 0.4 }
HA.PerformanceTrace:Measure("world_map_refresh", 1, function() end)
assert(snapshot.counters.world_map_refresh.totalCalls == 2)
assert(snapshot.counters.world_map_refresh.slowCalls == 1, "a fast call must not count as slow")
assert(#snapshot.records == 1, "a fast call must not push a ring record")

-------------------------------------------------------------------------------
-- allocatedBytes omitted (never a GC delta) when the profiler doesn't supply it.
-------------------------------------------------------------------------------

-- Advance the clock first: Sentry's whole join is "within two seconds of
-- the spike," so two slow records must carry DIFFERENT capturedAt values,
-- not the same frozen instant.
preciseTime = preciseTime + 5
nextResults = { elapsedMilliseconds = 12.0 }
HA.PerformanceTrace:Measure("badge_prewarm", 7, function() end)
local badgeRec = snapshot.records[#snapshot.records]
assert(badgeRec.operation == "badge_prewarm")
assert(badgeRec.allocatedBytes == nil, "allocatedBytes must be omitted, never backfilled with a GC delta")
assert(badgeRec.capturedAt == preciseTime, "capturedAt must track the clock at record time")
assert(badgeRec.capturedAt ~= rec.capturedAt,
    "two slow records captured at different times must carry different capturedAt values")

-------------------------------------------------------------------------------
-- Malformed profiler result: observation is skipped (no counters/records
-- touched for this call), but the callback still ran and its return value is
-- still preserved (MeasureCall itself was still invoked).
-------------------------------------------------------------------------------

local totalBefore = 0
for _, c in pairs(snapshot.counters) do totalBefore = totalBefore + c.totalCalls end

nextResults = "not-a-table"
local mOk = HA.PerformanceTrace:Measure("bag_refresh", 1, function() return "malformed-ok" end)
assert(mOk == "malformed-ok", "malformed profiler result must not swallow the callback return")

local totalAfter = 0
for _, c in pairs(snapshot.counters) do totalAfter = totalAfter + c.totalCalls end
assert(totalAfter == totalBefore, "a malformed profiler result must skip observation entirely")

-------------------------------------------------------------------------------
-- Combat: observation skipped, callback still runs, MeasureCall not touched.
-------------------------------------------------------------------------------

local callCountBeforeCombat = measureCallCount
inCombat = true
nextResults = "ERROR_IF_CALLED"
local cOk = HA.PerformanceTrace:Measure("bag_refresh", 1, function() return "combat-ok" end)
assert(cOk == "combat-ok", "callback must still run in combat")
assert(measureCallCount == callCountBeforeCombat, "MeasureCall must not run while InCombatLockdown() is true")
inCombat = false

-------------------------------------------------------------------------------
-- Missing profiler API: observation skipped, callback still runs.
-------------------------------------------------------------------------------

local savedProfiler = C_AddOnProfiler
C_AddOnProfiler = nil
local pOk = HA.PerformanceTrace:Measure("bag_refresh", 1, function() return "no-api-ok" end)
assert(pOk == "no-api-ok", "callback must still run when C_AddOnProfiler is unavailable")
C_AddOnProfiler = savedProfiler

-------------------------------------------------------------------------------
-- Auto-disarm: the arm window expires on its own once its granted duration
-- elapses -- no explicit Disarm() call needed, and no background timer
-- either (lazy expiry check inside IsArmed/Observe).
-------------------------------------------------------------------------------

Backend.PerformanceTrace:Arm(10)
assert(Backend.PerformanceTrace:IsArmed(), "Arm(10) must read as armed immediately")
preciseTime = preciseTime + 11
assert(not Backend.PerformanceTrace:IsArmed(), "the trace must auto-disarm once its granted window elapses")

local callCountBeforeExpiry = measureCallCount
nextResults = "ERROR_IF_CALLED"
local eOk = HA.PerformanceTrace:Measure("bag_refresh", 1, function() return "expired-ok" end)
assert(eOk == "expired-ok", "callback must still run once the arm window has expired")
assert(measureCallCount == callCountBeforeExpiry, "MeasureCall must not run once the arm window has expired")

-- Re-arm for the remaining assertions below.
Backend.PerformanceTrace:Arm(60)

-------------------------------------------------------------------------------
-- Bounded ring: push past the ring's fixed size and confirm it never grows
-- unbounded (oldest evicted).
-------------------------------------------------------------------------------

local ringSizeBefore = #snapshot.records
for i = 1, 200 do
    nextResults = { elapsedMilliseconds = 999 }
    HA.PerformanceTrace:Measure("bag_refresh", i, function() end)
end
assert(#snapshot.records <= 64, "the slow-call ring must stay fixed-size, got " .. #snapshot.records)
assert(#snapshot.records >= ringSizeBefore, "the ring must not shrink below what it already held")
-- Eviction order: the NEWEST record must survive a full wrap -- size alone
-- can't tell oldest-evicted from newest-dropped.
assert(snapshot.records[#snapshot.records].workload == 200,
    "ring eviction must drop the oldest record, keeping the newest (workload 200)")

-------------------------------------------------------------------------------
-- Observation-coverage contract: the snapshot
-- must record WHEN it was observing, so Sentry can refuse the affirmative
-- "nothing was slow" claim for windows nobody was watching.
-------------------------------------------------------------------------------

assert(type(snapshot.armedWindows) == "table", "snapshot must expose armedWindows")
assert(type(snapshot.combatSkips) == "table", "snapshot must expose combatSkips")

local windowCountBefore = #snapshot.armedWindows
Backend.PerformanceTrace:Disarm()
preciseTime = preciseTime + 100
Backend.PerformanceTrace:Arm(30)
local w = snapshot.armedWindows[#snapshot.armedWindows]
assert(#snapshot.armedWindows == windowCountBefore + 1,
    "a fresh Arm after disarm must append a new observation window")
assert(w.armedAt == preciseTime and w.armedUntil == preciseTime + 30,
    "the armed window must record the real observation span")

-- Re-arming while still armed EXTENDS the current window, not a new entry.
preciseTime = preciseTime + 5
Backend.PerformanceTrace:Arm(30)
assert(#snapshot.armedWindows == windowCountBefore + 1,
    "re-arming while armed must extend, not append")
assert(snapshot.armedWindows[#snapshot.armedWindows].armedUntil == preciseTime + 30,
    "the extended window must carry the new deadline")

-- Early disarm truncates the recorded window to the actual disarm moment.
preciseTime = preciseTime + 2
Backend.PerformanceTrace:Disarm()
assert(snapshot.armedWindows[#snapshot.armedWindows].armedUntil == preciseTime,
    "Disarm must truncate the recorded window to the disarm time")

-- A combat-suppressed observation while armed records a skip timestamp.
Backend.PerformanceTrace:Arm(30)
inCombat = true
local skipsBefore = #snapshot.combatSkips
HA.PerformanceTrace:Measure("bag_refresh", 1, function() end)
assert(#snapshot.combatSkips == skipsBefore + 1
        and snapshot.combatSkips[#snapshot.combatSkips] == preciseTime,
    "an armed, combat-suppressed observation must record a combatSkips timestamp")
inCombat = false

-- Synthetic capture mode: Arm(seconds, true) flags records synthetic.
Backend.PerformanceTrace:Arm(30, true)
nextResults = { elapsedMilliseconds = 999 }
HA.PerformanceTrace:Measure("bag_refresh", 42, function() end)
assert(snapshot.records[#snapshot.records].synthetic == true,
    "records captured under Arm(n, true) must carry synthetic = true")
Backend.PerformanceTrace:Arm(30)
nextResults = { elapsedMilliseconds = 999 }
HA.PerformanceTrace:Measure("bag_refresh", 43, function() end)
assert(snapshot.records[#snapshot.records].synthetic == false,
    "a plain re-arm must clear synthetic capture mode")

print("hs239_performance_trace.lua: backend ok")

-------------------------------------------------------------------------------
-- Candidate-boundary wiring. Loading Overlay/overlay.lua,
-- Overlay/BetterBags.lua, and Overlay/Baganator.lua under plain Lua 5.1 would
-- mean stubbing CreateFrame/C_Timer.After/ADDON_LOADED wait-frames across
-- three modules just to reach the call sites -- the existing bag overlay refresh
-- and invalidation gate tests already establish this repo's idiom for
-- exactly this situation: read the file as text and assert the wiring by
-- pattern, reserving real loadfile execution for logic that needs a live
-- callback chain. Each assertion below checks BOTH that the named boundary
-- calls the facade AND that it does so with an existing, already-known
-- workload value (never a value computed by a new scan added just to feed
-- this call).
-------------------------------------------------------------------------------

local function ReadFile(path)
    local f = assert(io.open(path, "r"), "expected file to exist: " .. path)
    local content = f:read("*a")
    f:close()
    return content
end

-- bag_refresh + ownership_update both live in Overlay/overlay.lua:
-- the "all" callback (fed exclusively by OWNERSHIP_UPDATED -> RequestUpdate
-- ("all"), confirmed by grep -- no other RequestUpdate("all")/Fire("all")
-- caller exists anywhere in the worktree) does the actual repaint work and is
-- named bag_refresh; the OWNERSHIP_UPDATED handler itself, which only
-- schedules that deferred repaint, is named ownership_update. The two
-- MeasureCalls are never nested: the "all" callback runs on a later timer
-- pump, not synchronously inside the OWNERSHIP_UPDATED handler.
local overlaySource = ReadFile(root .. "/Overlay/overlay.lua")
assert(overlaySource:find('HA%.PerformanceTrace:Measure%("bag_refresh", overlayCount,') ~= nil,
    'overlay.lua "all" callback must wrap Overlay:RefreshAll via the facade with the existing overlayCount workload')
assert(overlaySource:find('HA%.PerformanceTrace:Measure%("ownership_update", "all",') ~= nil,
    'overlay.lua OWNERSHIP_UPDATED handler must wrap its RequestUpdate("all") via the facade')

-- external_bag_refresh: one operation, two call sites (BetterBags + Baganator
-- each register their own RefreshWidgets as an external refresher).
local betterBagsSource = ReadFile(root .. "/Overlay/BetterBags.lua")
assert(betterBagsSource:find('HA%.PerformanceTrace:Measure%("external_bag_refresh", "betterbags",') ~= nil,
    "BetterBags.lua RefreshWidgets must wrap its refresh via the facade with the existing addon-key workload")

local baganatorSource = ReadFile(root .. "/Overlay/Baganator.lua")
assert(baganatorSource:find('HA%.PerformanceTrace:Measure%("external_bag_refresh", "baganator",') ~= nil,
    "Baganator.lua RefreshWidgets must wrap its refresh via the facade with the existing addon-key workload")

-- world_map_refresh: Provider:RefreshAllData's actual render pass, workload
-- is the already-computed currentMapID local (no new scan).
local worldMapSource = ReadFile(root .. "/UI/HomesteadWorldMapProvider.lua")
assert(worldMapSource:find('HA%.PerformanceTrace:Measure%("world_map_refresh", currentMapID,') ~= nil,
    "HomesteadWorldMapProvider.lua RefreshAllData must wrap its render pass via the facade with the existing currentMapID workload")

-- badge_prewarm: ProcessBatch's pcall'd loop, workload is batchStartIndex --
-- A later change replaced count-boxed batches (a fixed WARMUP_VENDORS_PER_BATCH) with
-- time-boxed ones (WARMUP_BATCH_TIME_MS via GetTimePreciseSec), so how many
-- vendors a batch will process is no longer knowable before the loop runs;
-- Measure's workload argument must be known before the callback executes, so
-- the already-known value carried here is the batch's starting cursor
-- position (currentIndex at batch start), not a post-hoc processed count.
local badgeSource = ReadFile(root .. "/UI/BadgeCalculation.lua")
assert(badgeSource:find('HA%.PerformanceTrace:Measure%("badge_prewarm", batchStartIndex, pcall,') ~= nil,
    "BadgeCalculation.lua ProcessBatch must wrap its pcall'd batch via the facade with the existing batchStartIndex workload")

-- badge_prewarm the aggregate-warming phase
-- appended after the vendor-stats loop is TWO more badge_prewarm call sites,
-- one atomic call per tick each — a fixed
-- "continent_totals" label for the single GetContinentVendorCounts("all")
-- call, and continentMapID (already known, the list this loop already built)
-- for the per-continent GetZoneVendorCounts call.
assert(badgeSource:find('HA%.PerformanceTrace:Measure%("badge_prewarm", "continent_totals", pcall,') ~= nil,
    "BadgeCalculation.lua ProcessBatch must wrap GetContinentVendorCounts(\"all\") via the facade with the \"continent_totals\" workload")
assert(badgeSource:find('HA%.PerformanceTrace:Measure%("badge_prewarm", continentMapID, pcall,') ~= nil,
    "BadgeCalculation.lua ProcessBatch must wrap its per-continent GetZoneVendorCounts call via the facade with the existing continentMapID workload")

print("hs239_performance_trace.lua: wiring ok")
