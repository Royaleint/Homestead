-- luacheck: globals assert loadfile print collectgarbage CreateFrame C_Timer C_HousingCatalog InCombatLockdown

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-276 (Gate 1 cycles 2-3): FUNCTIONAL pins for the login force-load,
-- loading the real Modules/CatalogScanner.lua against stubbed WoW surface and
-- driving its real event handlers.
--
-- These are deliberately not source-text pins. Both reviews found mutations
-- that left the whole suite green because nothing exercised these paths --
-- deleting the latch call from the HOUSING_STORAGE_UPDATED handler, deciding
-- the warm pre-check on the latch call's return value instead of the flags,
-- unwiring SetupLoginForceLoad from Initialize (cycle 2, W1/W3/W4), and
-- deleting the login re-entry guard or the whole combat-deferral block
-- (cycle 3, W6/W7). Each scenario below is written to FAIL under exactly one
-- of them.
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
-- Scenario C (W4): the warm pre-check must read storageResponded's CURRENT
-- value, not the latch call's this-call edge. Deciding on the edge creates a
-- searcher against already-warm storage and dangles pendingSearcher -- the
-- cycle-1 REJECT.
-------------------------------------------------------------------------------

local counts = { total = 0, max = 0 }
h = newHarness(counts)

h:mark()
h:fire("PLAYER_ENTERING_WORLD")
local runForceLoad = h:timerSinceMark()

-- Storage warms up (and latches) while the login timer is still pending, so
-- by the time it runs, the latch call flips no edge of its own.
counts.total, counts.max = 5, 100
h:fire("HOUSING_STORAGE_UPDATED")
assert(h.scanner:HasStorageResponded() == true, "sanity: the event must have latched storageResponded")

runForceLoad()
assert(h.searchersCreated == 0,
    "no searcher may be created once storage is already warm (pre-check must read the flag, not the call's edge)")

print("hs276_login_force_load: C warm pre-check reads current state ok")

-------------------------------------------------------------------------------
-- Scenario D (W1): the pre-check must accept EITHER latch. On a build where
-- GetDecorMaxOwnedCount is unavailable, only dataLoaded latches -- reading
-- storageResponded alone falls through and recreates scenario C's dangle
-- under a different precondition.
-------------------------------------------------------------------------------

counts = { total = 0 } -- no max = GetDecorMaxOwnedCount absent this build
h = newHarness(counts)

h:mark()
h:fire("PLAYER_ENTERING_WORLD")
runForceLoad = h:timerSinceMark()

counts.total = 5
h:fire("HOUSING_STORAGE_UPDATED")
assert(h.scanner:IsWarm() == true, "sanity: dataLoaded must latch off the owned total alone")
assert(h.scanner:HasStorageResponded() == false,
    "sanity: storageResponded must stay false with GetDecorMaxOwnedCount absent")

runForceLoad()
assert(h.searchersCreated == 0,
    "a dataLoaded-only latch is still warm -- no searcher may be created")

print("hs276_login_force_load: D dataLoaded-only warm pre-check ok")

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
