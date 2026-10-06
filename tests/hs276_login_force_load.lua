-- luacheck: globals assert loadfile print collectgarbage CreateFrame C_Timer C_HousingCatalog InCombatLockdown GetTime time

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-276 (Gate 1 cycles 2-3): FUNCTIONAL pins for the login force-load,
-- loading the real Modules/CatalogScanner.lua against stubbed WoW surface and
-- driving its real event handlers.
--
-- These are deliberately not source-text pins. Both reviews found mutations
-- that left the whole suite green because nothing exercised these paths --
-- deleting the latch call from the HOUSING_STORAGE_UPDATED handler,
-- unwiring SetupLoginForceLoad from Initialize (cycle 2, W1/W3/W4), and
-- deleting the login re-entry guard or the whole combat-deferral block
-- (cycle 3, W6/W7). Each scenario below is written to FAIL under exactly one
-- of them.
--
-- Gate 2 redesign (2026-08-09): the original design had a "warm pre-check"
-- that skipped the searcher when storage already looked warm by the
-- aggregate counters -- live testing proved that false twice (see
-- RunLoginStorageForceLoad's own comment in CatalogScanner.lua for the full
-- history) and it was removed. Scenarios C and D below now pin the opposite
-- invariant: the searcher is created every time, and the login path never
-- itself latches dataLoaded/storageResponded.
-------------------------------------------------------------------------------

-- Builds a fresh module instance (all of CatalogScanner's latch state is
-- file-local, so every scenario must re-load it) over stubs that record
-- rather than act. `counts.max = nil` models a build where
-- GetDecorMaxOwnedCount does not exist at all.
local function newHarness(counts, catalogAvailable)
    local h = { frames = {}, timers = {}, warmFires = 0, searchersCreated = 0, inCombat = false }

    -- Weak-valued, so scenario F can observe whether the module still holds a
    -- created searcher: pendingSearcher is write-only by design (no accessor
    -- to read it through), and "released to the collector" is precisely the
    -- contract the GC-insurance hold exists to bound.
    h.searcherRefs = setmetatable({}, { __mode = "v" })

    CreateFrame = function()
        local frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:SetScript(_, handler) self.handler = handler end
        h.frames[#h.frames + 1] = frame
        return frame
    end

    -- Timers are recorded, never run on their own -- each scenario fires the
    -- one it means to exercise.
    C_Timer = {
        After = function(delay, fn) h.timers[#h.timers + 1] = { delay = delay, fn = fn } end,
        NewTimer = function(delay, fn)
            h.timers[#h.timers + 1] = { delay = delay, fn = fn }
            return { Cancel = function() end }
        end,
    }

    InCombatLockdown = function() return h.inCombat end

    if catalogAvailable == false then
        C_HousingCatalog = nil
    else
        C_HousingCatalog = {
            GetDecorTotalOwnedCount = function() return counts.total end,
            CreateCatalogSearcher = function()
                h.searchersCreated = h.searchersCreated + 1
                local searcher = { RunSearch = function() end }
                h.searcherRefs[h.searchersCreated] = searcher
                return searcher
            end,
        }
        if counts.max ~= nil then
            C_HousingCatalog.GetDecorMaxOwnedCount = function() return counts.max end
        end
    end

    local HA = {
        Addon = {
            Debug = function() end,
            RegisterModule = function() end,
        },
        Events = {
            Fire = function(_, event)
                if event == "HS_CATALOG_TRUE_WARM" then h.warmFires = h.warmFires + 1 end
            end,
        },
    }

    -- Exposed so a scenario can inject CatalogStore/ProfessionSources AFTER
    -- load -- CatalogScanner.lua reads HA.<field> dynamically at call time,
    -- not as a load-time local, so a post-load mutation is visible to it.
    h.HA = HA

    assert(loadfile(root .. "/Modules/CatalogScanner.lua"))("Homestead", HA)
    h.scanner = HA.CatalogScanner
    h.scanner:Initialize()

    function h:frameFor(event)
        for _, frame in ipairs(self.frames) do
            if frame.events[event] then return frame end
        end
    end

    function h:fire(event, ...)
        local frame = assert(self:frameFor(event), "no frame registered for " .. event)
        frame.handler(frame, event, ...)
    end

    -- Returns the timer scheduled by the call made since the last mark --
    -- avoids pinning LOGIN_FORCE_LOAD_DELAY's value, which is Gate-2-tunable.
    function h:mark() self.timerMark = #self.timers end
    function h:timerSinceMark()
        assert(#self.timers > self.timerMark, "expected a timer to have been scheduled")
        return self.timers[self.timerMark + 1].fn
    end

    return h
end

-------------------------------------------------------------------------------
-- Scenario A (W3): the HOUSING_STORAGE_UPDATED handler must actually invoke
-- the latch. HS-273's own pin degraded to "this text exists somewhere in the
-- file" when the latch body was extracted into TryLatchWarmFromCounts --
-- deleting the call from the handler left the suite green while breaking the
-- warm gate entirely.
-------------------------------------------------------------------------------

local h = newHarness({ total = 5, max = 100 })

assert(h.scanner:IsWarm() == false, "sanity: must start cold")
assert(h.scanner:HasStorageResponded() == false, "sanity: storage must start unanswered")

h:fire("HOUSING_STORAGE_UPDATED")

assert(h.scanner:IsWarm() == true,
    "HOUSING_STORAGE_UPDATED must latch dataLoaded (SetUnowned's erase authorization)")
assert(h.scanner:HasStorageResponded() == true,
    "HOUSING_STORAGE_UPDATED must latch storageResponded")
assert(h.warmFires == 2,
    "a first fully-loaded storage event trips both one-shot edges, firing HS_CATALOG_TRUE_WARM twice, got "
        .. h.warmFires)

print("hs276_login_force_load: A event-path latch ok")

-------------------------------------------------------------------------------
-- Scenario B (W4): SetupLoginForceLoad must be wired into Initialize.
-- Removing the call unwires the entire feature; nothing else in the suite
-- noticed.
-------------------------------------------------------------------------------

h = newHarness({ total = 0, max = 0 })

local loginFrame = h:frameFor("PLAYER_ENTERING_WORLD")
assert(loginFrame ~= nil,
    "Initialize must wire SetupLoginForceLoad (a frame registered for PLAYER_ENTERING_WORLD)")
assert(loginFrame.events["PLAYER_REGEN_ENABLED"],
    "the login frame must also take PLAYER_REGEN_ENABLED for the combat-deferral retry")
assert(h:frameFor("HOUSING_STORAGE_UPDATED") ~= loginFrame,
    "the login frame must be SEPARATE from the scanning frame, whose OnEvent scans on every event")

h:mark()
h:fire("PLAYER_ENTERING_WORLD")
h:timerSinceMark() -- asserts internally that PEW scheduled the force-load

print("hs276_login_force_load: B Initialize wiring ok")

-------------------------------------------------------------------------------
-- Scenario C (HS-276 Gate 2 redesign, 2026-08-09): the login force-load must
-- create a searcher EVERY time, even when storage already looks warm by the
-- aggregate counters. A pre-check short-circuit here (skip the searcher when
-- GetDecorTotalOwnedCount/GetDecorMaxOwnedCount already read nonzero) was the
-- root cause of two live REJECTs: those counters can read nonzero while
-- per-item data (GetCatalogEntryInfoByItem) is still stale, and
-- HOUSING_STORAGE_UPDATED was confirmed live to never fire on its own to
-- correct it. Forcing the searcher unconditionally is what makes the real,
-- trustworthy event fire.
-------------------------------------------------------------------------------

local counts = { total = 5, max = 100 }
h = newHarness(counts)

h:mark()
h:fire("PLAYER_ENTERING_WORLD")
local runForceLoad = h:timerSinceMark()

-- Storage already looks warm by the aggregate counters before the login
-- timer even fires -- e.g. C++ engine state survived a /reload.
h:fire("HOUSING_STORAGE_UPDATED")
assert(h.scanner:HasStorageResponded() == true, "sanity: the event must have latched storageResponded")

runForceLoad()
assert(h.searchersCreated == 1,
    "the login force-load must create a searcher even when storage already looks warm -- "
        .. "a pre-check short-circuit here caused two live data-loss REJECTs (2026-08-09)")

print("hs276_login_force_load: C searcher created unconditionally, even when already warm ok")

-------------------------------------------------------------------------------
-- Scenario D (HS-276 Gate 2 redesign, 2026-08-09): the login force-load must
-- never itself latch dataLoaded/storageResponded -- only the real
-- HOUSING_STORAGE_UPDATED handler may. This is the invariant decision C's
-- removal depends on: erasure-authorization must never come from anything
-- but a genuine engine signal. A regression that re-adds any
-- TryLatchWarmFromCounts() call to the login path would defeat this even if
-- it still created a searcher every time.
-------------------------------------------------------------------------------

h = newHarness({ total = 5, max = 100 })

h:mark()
h:fire("PLAYER_ENTERING_WORLD")
runForceLoad = h:timerSinceMark()

assert(h.scanner:IsWarm() == false, "sanity: must start cold")
assert(h.scanner:HasStorageResponded() == false, "sanity: must start unanswered")

runForceLoad()

assert(h.searchersCreated == 1, "sanity: the force-load must actually have run, not been a no-op")
assert(h.scanner:IsWarm() == false,
    "the login force-load must not itself latch dataLoaded -- only the real HOUSING_STORAGE_UPDATED "
        .. "handler may (this is what keeps erasure-authorization trustworthy)")
assert(h.scanner:HasStorageResponded() == false,
    "the login force-load must not itself latch storageResponded either")

print("hs276_login_force_load: D login force-load never self-latches warm state ok")

-------------------------------------------------------------------------------
-- Scenario E (W2): the login path runs off an unconditional timer, so it
-- must survive C_HousingCatalog not existing at all -- the guard has to sit
-- above every dereference reachable from it, the latch call included.
-------------------------------------------------------------------------------

h = newHarness({ total = 0, max = 0 }, false)

h:mark()
h:fire("PLAYER_ENTERING_WORLD")
runForceLoad = h:timerSinceMark()
local ok, err = pcall(runForceLoad)
assert(ok, "the login force-load must not dereference C_HousingCatalog before guarding it: " .. tostring(err))

print("hs276_login_force_load: E missing-namespace guard ok")

-------------------------------------------------------------------------------
-- Scenario F (W6): the GC-insurance hold must be released on EITHER latch.
-- Releasing only inside the storageResponded branch stranded the searcher for
-- the rest of the session on a build where GetDecorMaxOwnedCount is absent --
-- the same precondition as scenario D, on the release side instead of the
-- pre-check side. pendingSearcher has no accessor, so this observes the
-- contract the hold actually makes: the object becomes collectable.
-------------------------------------------------------------------------------

counts = { total = 0 } -- no max = GetDecorMaxOwnedCount absent this build
h = newHarness(counts)

h:mark()
h:fire("PLAYER_ENTERING_WORLD")
runForceLoad = h:timerSinceMark()
runForceLoad()
assert(h.searchersCreated == 1, "sanity: a cold force-load must create a searcher")

collectgarbage("collect")
assert(next(h.searcherRefs) ~= nil,
    "sanity: the searcher must be held against collection while storage has not answered")

counts.total = 5
h:fire("HOUSING_STORAGE_UPDATED")
assert(h.scanner:IsWarm() == true, "sanity: dataLoaded must latch off the owned total alone")
assert(h.scanner:HasStorageResponded() == false,
    "sanity: storageResponded must stay false with GetDecorMaxOwnedCount absent")

collectgarbage("collect")
assert(next(h.searcherRefs) == nil,
    "a dataLoaded-only latch must release the searcher hold too -- gating the release on "
        .. "storageResponded alone strands it for the session")

print("hs276_login_force_load: F GC-insurance release on either latch ok")

-------------------------------------------------------------------------------
-- Scenario G (W7): the loginForceLoadAttempted re-entry guard. PLAYER_ENTERING_WORLD
-- fires on every loading screen, not just initial login (HS-218). Without the
-- guard each subsequent one reschedules the force-load, and once storage is
-- warm each of those short-circuits into a full ~1,600-call RequestScan().
-------------------------------------------------------------------------------

h = newHarness({ total = 0, max = 0 })

h:mark()
h:fire("PLAYER_ENTERING_WORLD")
h:fire("PLAYER_ENTERING_WORLD")
assert(#h.timers == h.timerMark + 1,
    "a second PLAYER_ENTERING_WORLD (zone change, instance, hearth) must not schedule a second "
        .. "force-load; got " .. (#h.timers - h.timerMark) .. " scheduled")

print("hs276_login_force_load: G one-shot login guard ok")

-------------------------------------------------------------------------------
-- Scenario H (W7): the combat deferral must actually defer and then resume.
-- Scenario B only proves PLAYER_REGEN_ENABLED is registered; deleting the whole
-- InCombatLockdown() block left the suite green, which would fire the force-load
-- straight into combat.
-------------------------------------------------------------------------------

h = newHarness({ total = 0, max = 0 })
h.inCombat = true

h:mark()
h:fire("PLAYER_ENTERING_WORLD")
h:timerSinceMark()()
assert(h.searchersCreated == 0, "the force-load must defer out of combat, not run during it")

h.inCombat = false
h:fire("PLAYER_REGEN_ENABLED")
assert(h.searchersCreated == 1, "PLAYER_REGEN_ENABLED must run the deferred force-load")

h:fire("PLAYER_REGEN_ENABLED")
assert(h.searchersCreated == 1,
    "a later PLAYER_REGEN_ENABLED must not re-run it -- the pending-combat flag is one-shot")

print("hs276_login_force_load: H combat deferral and resume ok")

-------------------------------------------------------------------------------
-- Scenario I (Argus Gate 2 cycle 2 WARNING): the erase gate itself (dataLoaded
-- and ...IsOwned... then SetUnowned, ScanFullCatalog's per-item loop) must
-- stay functionally pinned. Cycle 1's scenario I (deleted, tested the
-- superseded skipErasure mechanism) was the ONLY test in the repo that ever
-- reached a SetUnowned call -- deleting it left this gate, the exact thing
-- this whole ticket's REJECT history is about, unexercised. Proves both
-- halves: a cold read must not erase (item stays owned even though the
-- per-item read says it isn't); the SAME item must erase once the real event
-- genuinely latches dataLoaded. Half 2 is required -- without it the gate
-- could be a constant false and half 1 would still pass.
--
-- Calls CatalogScanner:ScanFullCatalog() directly, bypassing RequestScan's
-- debounce, to isolate the erase gate from timer plumbing already covered by
-- other scenarios. That means it needs GetTime/time stubbed locally -- no
-- scenario drives ScanFullCatalog through the login path anymore (Gate 2
-- redesign removed that call site), so the harness no longer stubs them
-- globally.
-------------------------------------------------------------------------------

h = newHarness({ total = 5, max = 100 })
h.HA.ProfessionSources = { [12345] = true }

local timeCounter = 0
GetTime = function() timeCounter = timeCounter + 10 return timeCounter end
time = function() return 0 end

local ownedItems = { [12345] = true }
local setUnownedCalls = 0
h.HA.CatalogStore = {
    BeginBatch = function() end,
    EndBatch = function() end,
    ComputeOwnedFromInfo = function() return false end, -- per-item data still stale-0
    IsOwned = function(_, itemID) return ownedItems[itemID] == true end,
    SetOwned = function(_, itemID) ownedItems[itemID] = true end,
    SetUnowned = function(_, itemID) setUnownedCalls = setUnownedCalls + 1; ownedItems[itemID] = false end,
    Save = function() end,
}
C_HousingCatalog.GetCatalogEntryInfoByItem = function()
    return { totalNumStored = 0, totalNumPlaced = 0, remainingRedeemable = 0 }
end

-- Half 1: cold. Store says item 12345 is owned; the per-item read says it
-- isn't. Must NOT erase.
assert(h.scanner:IsWarm() == false, "sanity: must start cold")
h.scanner:ScanFullCatalog()
assert(setUnownedCalls == 0,
    "a cold scan must not erase ownership from a per-item read it can't yet trust, got "
        .. setUnownedCalls .. " SetUnowned call(s)")
assert(ownedItems[12345] == true, "item 12345 must still read owned after the cold scan")

-- Half 2: the real event latches dataLoaded. The SAME stale-0 read must now
-- erase.
h:fire("HOUSING_STORAGE_UPDATED")
assert(h.scanner:IsWarm() == true, "sanity: the event must have latched dataLoaded")
h.scanner:ScanFullCatalog()
assert(setUnownedCalls == 1,
    "once dataLoaded is genuinely latched, the same stale-0 read must erase, got "
        .. setUnownedCalls .. " SetUnowned call(s)")
assert(ownedItems[12345] == false, "item 12345 must now read unowned")

print("hs276_login_force_load: I erase gate functionally pinned (cold skips, warm erases) ok")

-------------------------------------------------------------------------------
-- Scenario J (Corner A): ScanFullCatalog's batch loop must PAUSE in combat and
-- RESUME where it stopped. RunLoginStorageForceLoad already defers itself past
-- combat, but the ~85 batches of probes and store writes its forced event
-- triggers had no combat gate at all -- a mid-fight /reload landed every one of
-- them on combat frames a few seconds later. Straddling the pause must not
-- restart the pass either, so every item is asserted probed exactly once.
--
-- Drives ScanFullCatalog directly (as scenario I does, and needs I's local
-- GetTime/time stubs for the same reason), and counts probes rather than
-- batches: ITEMS_PER_BATCH is an internal tunable, so the scenario only relies
-- on 60 items taking more than one batch.
-------------------------------------------------------------------------------

h = newHarness({ total = 5, max = 100 })

timeCounter = 0
GetTime = function() timeCounter = timeCounter + 10 return timeCounter end
time = function() return 0 end

local SCAN_ITEM_COUNT = 60
local probeCounts = {}
local probeTotal = 0
local scanItems = {}
for itemID = 90001, 90000 + SCAN_ITEM_COUNT do scanItems[itemID] = true end
h.HA.ProfessionSources = scanItems
h.HA.CatalogStore = {
    BeginBatch = function() end,
    EndBatch = function() end,
    ComputeOwnedFromInfo = function() return false end,
    IsOwned = function() return false end,
    SetOwned = function() end,
    SetUnowned = function() end,
    Save = function() end,
}
C_HousingCatalog.GetCatalogEntryInfoByItem = function(itemLink)
    probeCounts[itemLink] = (probeCounts[itemLink] or 0) + 1
    probeTotal = probeTotal + 1
    return { totalNumStored = 0, totalNumPlaced = 0, remainingRedeemable = 0 }
end

h:mark()
local nextTimer = h.timerMark
local function runNextTimer(what)
    nextTimer = nextTimer + 1
    assert(h.timers[nextTimer], "expected a timer to have been scheduled for " .. what)
    h.timers[nextTimer].fn()
end

h.scanner:ScanFullCatalog()
local afterFirstBatch = probeTotal
assert(afterFirstBatch > 0 and afterFirstBatch < SCAN_ITEM_COUNT,
    "sanity: the scan must batch rather than probe all " .. SCAN_ITEM_COUNT .. " items in one pass, got "
        .. afterFirstBatch)

h.inCombat = true
runNextTimer("the next batch")
assert(probeTotal == afterFirstBatch,
    "a batch boundary reached in combat must probe nothing -- a mid-fight /reload would otherwise land "
        .. "the whole forced rescan on combat frames; got " .. (probeTotal - afterFirstBatch) .. " probe(s)")
assert(h.timers[nextTimer + 1] ~= nil,
    "the paused batch must reschedule itself -- pausing without a retry abandons the scan, it does not defer it")

h.inCombat = false
while h.timers[nextTimer + 1] do
    runNextTimer("a resumed batch")
end

assert(probeTotal == SCAN_ITEM_COUNT,
    "the scan must resume after combat and finish every item, got " .. probeTotal .. " of " .. SCAN_ITEM_COUNT)
for itemID in pairs(scanItems) do
    local link = "item:" .. itemID
    assert(probeCounts[link] == 1,
        "item " .. itemID .. " must be probed exactly once across the pause -- the loop resumes from where "
            .. "it stopped, it does not restart; got " .. (probeCounts[link] or 0))
end

print("hs276_login_force_load: J scan batches pause in combat and resume in place ok")

-------------------------------------------------------------------------------
-- Scenario K (Corner B): the login force-load's synthesized
-- HOUSING_STORAGE_UPDATED must not trigger the full ~1,600-probe rescan on an
-- account that owns zero decor -- there is nothing there to find, and before
-- HS-276 those accounts ran no login scan at all. The gate is scoped to that
-- one forced event: K2/K3/K4 pin the invariant it must never break, which is a
-- GENUINE storage change on the very same zero-decor account -- gate that and
-- HS-276's staleness bug comes back on precisely the accounts this targets.
--
-- The observable is a scheduled timer, not a call to the file-local
-- RequestScan wrapper: RequestScan debounces through C_Timer.NewTimer, and the
-- harness records every timer, so "did a scan get requested" is exactly "did a
-- new timer appear" (same reasoning as tests/hs283_catalog_scan_relevance.lua).
--
-- A zero-decor account is modelled as total = 0 with a live storage cap
-- (max = 1000): the cap is static and non-zero the instant storage loads,
-- ownership-independent (see TryLatchWarmFromCounts). max = 0 would model
-- "storage never answered", which is a different scenario.
-------------------------------------------------------------------------------

counts = { total = 0, max = 1000 }
h = newHarness(counts)

h:mark()
h:fire("PLAYER_ENTERING_WORLD")
runForceLoad = h:timerSinceMark()
runForceLoad()
assert(h.searchersCreated == 1, "sanity: the force-load must still create its searcher on a zero-decor account")

-- K1: the forced event itself.
h:mark()
h:fire("HOUSING_STORAGE_UPDATED")
assert(#h.timers == h.timerMark,
    "the login-forced storage event must not request a rescan when the account owns zero decor; got "
        .. (#h.timers - h.timerMark) .. " timer(s) scheduled")
assert(h.scanner:HasStorageResponded() == true,
    "the skip must sit AFTER the latch -- storageResponded (and the searcher release it drives) must "
        .. "still happen on a zero-decor account")

-- K2: the flag is one-shot. A SECOND event is not the forced one, so it scans
-- even though the account still owns zero decor.
h:mark()
h:fire("HOUSING_STORAGE_UPDATED")
assert(#h.timers > h.timerMark,
    "only the login-forced event may be skipped -- a later genuine storage event must still scan, or the "
        .. "flag has latched on and every future event inherits the skip")

-- K3: first-ever acquisition on that same account. This is the exact staleness
-- class HS-276 shipped to fix, on the exact account type the gate targets.
counts.total = 1
h:mark()
h:fire("HOUSING_STORAGE_UPDATED")
assert(#h.timers > h.timerMark,
    "a zero-decor account acquiring its first decor item must still scan")

-- K4: the gate is scoped to the forced path, not to the handler. A genuine
-- event on a zero-decor account with no force-load in flight scans.
h = newHarness({ total = 0, max = 1000 })
h:mark()
h:fire("HOUSING_STORAGE_UPDATED")
assert(#h.timers > h.timerMark,
    "a genuine storage event with no login force-load in flight must scan even at zero decor -- the gate "
        .. "belongs on the forced login path, not on the HOUSING_STORAGE_UPDATED handler")

print("hs276_login_force_load: K forced zero-decor rescan gated, genuine events untouched ok")

-- K5: no decor count to read is not the same as a count of zero. Writing the
-- gate with TryLatchWarmFromCounts's `... and ...() or 0` idiom would collapse
-- the two: that idiom fails safe there (no latch, no erasure) and dangerous
-- here (skip the session's only scan on an account whose count we could not
-- read). A build without the accessor must scan.
h = newHarness({ total = 0, max = 1000 })
C_HousingCatalog.GetDecorTotalOwnedCount = nil

h:mark()
h:fire("PLAYER_ENTERING_WORLD")
h:timerSinceMark()()
h:mark()
h:fire("HOUSING_STORAGE_UPDATED")
assert(#h.timers > h.timerMark,
    "a missing GetDecorTotalOwnedCount is no information about the account, not a zero -- the forced "
        .. "event must still scan")

print("hs276_login_force_load: K5 missing decor-count accessor scans rather than skips ok")
