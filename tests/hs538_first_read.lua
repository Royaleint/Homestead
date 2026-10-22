-- luacheck: globals assert loadfile print CreateFrame C_Timer C_HousingCatalog InCombatLockdown GetTime

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-- Mirrors Modules/CatalogScanner.lua's FIRST_READ_TIMEOUT. No other timer the
-- scanner schedules uses this delay, so it identifies the first-read timer.
local FIRST_READ_TIMEOUT = 60

-------------------------------------------------------------------------------
-- Loads the real Modules/CatalogScanner.lua against stubbed WoW surface and
-- drives its real event handlers and timers, pinning when this session's
-- first collection read counts as done (HasFirstReadCompleted) or as tried
-- and failed (HasFirstReadAttempted). Same harness shape as
-- tests/hs276_login_force_load.lua and tests/hs305_cooldown_reschedule.lua:
-- timers are recorded and fired by hand, and GetTime is the only clock.
-------------------------------------------------------------------------------

-- opts.total / opts.max: the aggregate counts (max = nil means the accessor
-- is missing). opts.items: how many items a scan walks (21 forces one batch
-- yield, since ITEMS_PER_BATCH is 20).
local function newHarness(opts)
    local h = { frames = {}, timers = {}, log = {}, readFires = 0, warmFires = 0,
        timeNow = 100, inCombat = false, counts = opts }

    CreateFrame = function()
        local frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:SetScript(_, handler) self.handler = handler end
        h.frames[#h.frames + 1] = frame
        return frame
    end

    C_Timer = {
        After = function(delay, fn) h.timers[#h.timers + 1] = { delay = delay, fn = fn } end,
        NewTimer = function(delay, fn)
            h.timers[#h.timers + 1] = { delay = delay, fn = fn }
            return { Cancel = function() end }
        end,
    }

    InCombatLockdown = function() return h.inCombat end
    GetTime = function() return h.timeNow end

    C_HousingCatalog = {
        GetDecorTotalOwnedCount = function() return h.counts.total end,
        CreateCatalogSearcher = function() return { RunSearch = function() end } end,
        GetCatalogEntryInfoByItem = function()
            return { totalNumStored = 0, totalNumPlaced = 0, remainingRedeemable = 0 }
        end,
    }
    if opts.max ~= nil then
        C_HousingCatalog.GetDecorMaxOwnedCount = function() return h.counts.max end
    end

    local items = {}
    for i = 1, opts.items or 1 do items[i] = { itemID = 1000 + i } end

    local HA = {
        Addon = { Debug = function() end, RegisterModule = function() end },
        Events = {
            Fire = function(_, event)
                if event == "HS_CATALOG_READ_STATE" then
                    h.readFires = h.readFires + 1
                    h.log[#h.log + 1] = "read"
                elseif event == "HS_CATALOG_TRUE_WARM" then
                    h.warmFires = h.warmFires + 1
                end
            end,
        },
        VendorData = {
            GetAllVendors = function() return { "vendor1" } end,
            GetItemsForVendor = function() return items end,
            GetItemID = function(_, item) return item.itemID end,
        },
        CatalogStore = {
            BeginBatch = function() h.log[#h.log + 1] = "begin" end,
            EndBatch = function() h.log[#h.log + 1] = "end" end,
            ComputeOwnedFromInfo = function() return false end,
            IsOwned = function() return false end,
            SetOwned = function() end,
            SetUnowned = function() end,
            Save = function() end,
            GetOwnedCount = function() return 0 end,
        },
    }
    h.HA = HA

    assert(loadfile(root .. "/Modules/CatalogScanner.lua"))("Homestead", HA)
    h.scanner = HA.CatalogScanner
    h.scanner:Initialize()

    function h:fire(event, ...)
        for _, frame in ipairs(self.frames) do
            if frame.events[event] then
                return frame.handler(frame, event, ...)
            end
        end
        error("no frame registered for " .. event)
    end

    function h:mark() self.timerMark = #self.timers end

    -- The first-read timers scheduled since the last mark.
    function h:readTimersSinceMark()
        local found = {}
        for i = self.timerMark + 1, #self.timers do
            if self.timers[i].delay == FIRST_READ_TIMEOUT then found[#found + 1] = self.timers[i] end
        end
        return found
    end

    -- Runs the login force-load to its success path and returns its 60 s timer.
    function h:loginSuccess()
        self:mark()
        self:fire("PLAYER_ENTERING_WORLD")
        local runForceLoad = self.timers[self.timerMark + 1].fn
        self:mark()
        runForceLoad()
        local armed = self:readTimersSinceMark()
        assert(#armed == 1, "the force-load success path must arm exactly one first-read timer, got " .. #armed)
        return armed[1]
    end

    -- Fires a first-read timer and returns the timers it re-armed.
    function h:runReadTimer(timer)
        self:mark()
        timer.fn()
        return self:readTimersSinceMark()
    end

    function h:state()
        return self.scanner:HasFirstReadCompleted(), self.scanner:HasFirstReadAttempted()
    end

    return h
end

-- The read-state fire must come after the scan's EndBatch.
local function assertReadAfterEnd(h, what)
    local lastEnd, firstRead
    for i, entry in ipairs(h.log) do
        if entry == "end" then lastEnd = i end
        if entry == "read" and not firstRead then firstRead = i end
    end
    assert(firstRead and lastEnd and lastEnd < firstRead,
        what .. ": the first read must latch after CatalogStore:EndBatch(), log: " .. table.concat(h.log, ","))
end

-------------------------------------------------------------------------------
-- Latches
-------------------------------------------------------------------------------

-- L1: a warm-started scan latches on its completion path, after EndBatch, and
-- not while its batches are still running.
do
    local h = newHarness({ total = 5, max = 100, items = 21 })
    assert(h.scanner:HasFirstReadCompleted() == false and h.scanner:HasFirstReadAttempted() == false,
        "sanity: both flags start false")
    h:fire("HOUSING_STORAGE_UPDATED")
    assert(h.scanner:IsWarm() == true, "sanity: the event must latch dataLoaded")
    assert(h.warmFires == 2, "the two HS_CATALOG_TRUE_WARM edges are unchanged, got " .. h.warmFires)
    assert(h.readFires == 0, "a storage event alone must not latch the first read")

    h:mark()
    h.scanner:ScanFullCatalog()
    assert(h.scanner:HasFirstReadCompleted() == false, "a scan still in its batches must not latch")
    h.timers[h.timerMark + 1].fn() -- the last batch: scan complete
    assert(h.scanner:HasFirstReadCompleted() == true, "a warm-started scan must latch on completion")
    assert(h.readFires == 1, "exactly one HS_CATALOG_READ_STATE per flip, got " .. h.readFires)
    assertReadAfterEnd(h, "completion path")

    -- A second warm scan is not a second flip.
    h.timeNow = 200
    h:mark()
    h.scanner:ScanFullCatalog()
    h.timers[h.timerMark + 1].fn()
    assert(h.readFires == 1, "a later scan must not fire HS_CATALOG_READ_STATE again, got " .. h.readFires)
    print("hs538_first_read: L1 completion-path latch ok")
end

-- L2: the empty-list path latches too, after its EndBatch.
do
    local h = newHarness({ total = 5, max = 100, items = 0 })
    h:fire("HOUSING_STORAGE_UPDATED")
    h.scanner:ScanFullCatalog()
    assert(h.scanner:HasFirstReadCompleted() == true, "a warm-started scan with no items must latch")
    assert(h.readFires == 1, "exactly one HS_CATALOG_READ_STATE, got " .. h.readFires)
    assertReadAfterEnd(h, "empty-list path")
    print("hs538_first_read: L2 empty-list latch ok")
end

-- L3: storageResponded alone never latches (per-item counts may be stale-0),
-- and neither does a scan that started cold even if dataLoaded latches midway.
do
    local h = newHarness({ total = 0, max = 100, items = 1 })
    h:fire("HOUSING_STORAGE_UPDATED") -- genuine event: no login force-load in flight
    assert(h.scanner:HasStorageResponded() == true and h.scanner:IsWarm() == false,
        "sanity: storage answered but dataLoaded did not latch")
    h.scanner:ScanFullCatalog()
    assert(h.scanner:HasFirstReadCompleted() == false,
        "a scan started with only storageResponded must not latch")
    assert(h.readFires == 0, "no HS_CATALOG_READ_STATE without a flip, got " .. h.readFires)

    h = newHarness({ total = 0, max = 100, items = 21 })
    h:mark()
    h.scanner:ScanFullCatalog() -- starts cold
    h.counts.total = 5
    h:fire("HOUSING_STORAGE_UPDATED") -- dataLoaded latches mid-scan
    assert(h.scanner:IsWarm() == true, "sanity: dataLoaded latched mid-scan")
    h.timers[h.timerMark + 1].fn() -- finish the cold-started scan
    assert(h.scanner:HasFirstReadCompleted() == false,
        "a scan that started before dataLoaded must not latch, even if it latched midway")
    print("hs538_first_read: L3 storageResponded-only and cold-started scans do not latch ok")
end

-- L4: the login-forced zero-decor skip latches when storage answered, and only
-- sets attempted when it did not.
do
    local h = newHarness({ total = 0, max = 1000 })
    h:loginSuccess()
    h:fire("HOUSING_STORAGE_UPDATED") -- the forced event
    assert(h.scanner:HasFirstReadCompleted() == true,
        "the zero-decor skip with storageResponded must latch: that player owns nothing")
    assert(h.readFires == 1, "exactly one HS_CATALOG_READ_STATE, got " .. h.readFires)

    h = newHarness({ total = 0, max = nil })
    h:loginSuccess()
    h:fire("HOUSING_STORAGE_UPDATED")
    assert(h.scanner:HasStorageResponded() == false, "sanity: storage never answered")
    local done, attempted = h:state()
    assert(done == false and attempted == true,
        "the zero-decor skip without storageResponded must set attempted, not done")
    assert(h.readFires == 1, "exactly one HS_CATALOG_READ_STATE, got " .. h.readFires)
    print("hs538_first_read: L4 zero-decor login skip ok")
end

-- L5: no latch on the already-scanning, cooldown or no-API returns.
do
    local h = newHarness({ total = 0, max = 100, items = 21 })
    h.scanner:ScanFullCatalog() -- cold, mid-batch
    h.counts.total = 5
    h:fire("HOUSING_STORAGE_UPDATED")
    h.scanner:ScanFullCatalog() -- already scanning
    assert(h.scanner:HasFirstReadCompleted() == false, "the already-scanning return must not latch")

    h = newHarness({ total = 0, max = 100, items = 1 })
    h.scanner:ScanFullCatalog() -- cold, completes at t=100
    h.counts.total = 5
    h:fire("HOUSING_STORAGE_UPDATED")
    h.timeNow = 101
    local started = h.scanner:ScanFullCatalog()
    assert(started == false, "sanity: blocked by the cooldown")
    assert(h.scanner:HasFirstReadCompleted() == false, "the cooldown return must not latch")

    h = newHarness({ total = 5, max = 100, items = 1 })
    h:fire("HOUSING_STORAGE_UPDATED")
    C_HousingCatalog = nil
    h.scanner:ScanFullCatalog()
    assert(h.scanner:HasFirstReadCompleted() == false, "the no-API return must not latch")
    assert(h.readFires == 0, "no HS_CATALOG_READ_STATE on any guard return, got " .. h.readFires)
    print("hs538_first_read: L5 guard returns do not latch ok")
end

-------------------------------------------------------------------------------
-- Attempted
-------------------------------------------------------------------------------

-- A1: each early return past the combat deferral sets attempted at once and
-- arms no timer.
do
    local cases = {
        { "no C_HousingCatalog", function() C_HousingCatalog = nil end },
        { "no CreateCatalogSearcher", function() C_HousingCatalog.CreateCatalogSearcher = nil end },
        { "CreateCatalogSearcher fails", function()
            C_HousingCatalog.CreateCatalogSearcher = function() error("boom") end
        end },
        { "CreateCatalogSearcher returns nil", function()
            C_HousingCatalog.CreateCatalogSearcher = function() return nil end
        end },
        { "RunSearch fails", function()
            C_HousingCatalog.CreateCatalogSearcher = function()
                return { RunSearch = function() error("boom") end }
            end
        end },
    }
    for _, case in ipairs(cases) do
        local h = newHarness({ total = 0, max = 0 })
        h:mark()
        h:fire("PLAYER_ENTERING_WORLD")
        local runForceLoad = h.timers[h.timerMark + 1].fn
        case[2]()
        h:mark()
        runForceLoad()
        local done, attempted = h:state()
        assert(done == false and attempted == true, case[1] .. ": the early return must set attempted")
        assert(h.readFires == 1, case[1] .. ": exactly one HS_CATALOG_READ_STATE, got " .. h.readFires)
        assert(#h:readTimersSinceMark() == 0, case[1] .. ": an early return must not arm the first-read timer")
    end
    print("hs538_first_read: A1 early returns set attempted ok")
end

-- A2: the combat deferral arms nothing and sets nothing; the resumed success
-- path arms the timer.
do
    local h = newHarness({ total = 0, max = 0 })
    h.inCombat = true
    h:mark()
    h:fire("PLAYER_ENTERING_WORLD")
    local runForceLoad = h.timers[h.timerMark + 1].fn
    h:mark()
    runForceLoad()
    assert(#h:readTimersSinceMark() == 0, "the combat deferral must not arm the first-read timer")
    local done, attempted = h:state()
    assert(done == false and attempted == false, "the combat deferral must not set either flag")

    h.inCombat = false
    h:mark()
    h:fire("PLAYER_REGEN_ENABLED")
    assert(#h:readTimersSinceMark() == 1, "the resumed force-load's success path must arm the timer")
    print("hs538_first_read: A2 timer armed only on the success path ok")
end

-- A3: the timer re-arms while a scan is running or queued, isolating each
-- condition the scanner can reach on its own, then flips once idle.
do
    -- isScanning alone: a long (combat-paused) scan, well past its cooldown,
    -- with no debounce pending.
    local h = newHarness({ total = 0, max = 100, items = 21 })
    local timer = h:loginSuccess()
    h:mark()
    h.scanner:ScanFullCatalog() -- cold, t=100
    local scanBatch = h.timers[h.timerMark + 1]
    h.inCombat = true
    scanBatch.fn() -- pauses in combat, isScanning stays true
    local combatRetry = h.timers[#h.timers]
    h.timeNow = 200
    local rearmed = h:runReadTimer(timer)
    assert(#rearmed == 1, "a running scan must re-arm the first-read timer")
    assert(h.scanner:HasFirstReadAttempted() == false and h.readFires == 0, "a re-arm must not flip")

    -- Combat drops; the scan completes cold. The cooldown has long passed.
    h.inCombat = false
    combatRetry.fn()
    assert(h.scanner:GetStats().isScanning == false, "sanity: the scan finished")
    h.timeNow = 300
    assert(#h:runReadTimer(rearmed[1]) == 0, "an idle scanner must not re-arm")
    local done, attempted = h:state()
    assert(done == false and attempted == true, "an idle scanner that is not done must flip to attempted")
    assert(h.readFires == 1, "exactly one HS_CATALOG_READ_STATE, got " .. h.readFires)

    -- pendingScanTimer alone: a debounced request not yet run.
    h = newHarness({ total = 0, max = 100 })
    timer = h:loginSuccess()
    h:fire("NEW_HOUSING_ITEM_ACQUIRED") -- RequestScan: pendingScanTimer set
    assert(#h:runReadTimer(timer) == 1, "a pending scan request must re-arm the first-read timer")
    assert(h.scanner:HasFirstReadAttempted() == false, "a re-arm must not flip")

    -- Cooldown gap alone: a scan finished under SCAN_COOLDOWN ago, where
    -- RequestScan's cooldown retry leaves pendingScanTimer nil.
    h = newHarness({ total = 0, max = 100, items = 1 })
    timer = h:loginSuccess()
    h.scanner:ScanFullCatalog() -- cold, completes at t=100
    h.timeNow = 101
    rearmed = h:runReadTimer(timer)
    assert(#rearmed == 1, "a pending cooldown retry must re-arm the first-read timer")
    assert(h.scanner:HasFirstReadAttempted() == false, "a re-arm must not flip")
    h.timeNow = 110
    assert(#h:runReadTimer(rearmed[1]) == 0 and h.scanner:HasFirstReadAttempted() == true,
        "once the cooldown has passed and nothing is queued, the timer flips to attempted")

    -- scanRequestedDuringActive: only ever true while isScanning is, so it
    -- is exercised together with it.
    h = newHarness({ total = 0, max = 100, items = 21 })
    timer = h:loginSuccess()
    h.scanner:ScanFullCatalog()
    h:fire("NEW_HOUSING_ITEM_ACQUIRED")
    h.timers[#h.timers].fn() -- the debounce runs mid-scan: flags a rescan
    h.timeNow = 200
    assert(#h:runReadTimer(timer) == 1, "a rescan flagged during a scan must re-arm the first-read timer")
    assert(h.scanner:HasFirstReadAttempted() == false, "a re-arm must not flip")
    print("hs538_first_read: A3 timer re-arms while a scan is running or queued ok")
end

-- A4: a later real latch moves the state on, and the timer then does nothing.
do
    local h = newHarness({ total = 0, max = 100, items = 1 })
    local timer = h:loginSuccess()
    h.timeNow = 200
    h:runReadTimer(timer)
    assert(h.scanner:HasFirstReadAttempted() == true and h.readFires == 1, "sanity: attempted after the timeout")

    h.counts.total = 5
    h:fire("HOUSING_STORAGE_UPDATED")
    h.scanner:ScanFullCatalog()
    assert(h.scanner:HasFirstReadCompleted() == true, "a later warm scan must still latch after attempted")
    assert(h.readFires == 2, "the later latch is its own flip and fires once more, got " .. h.readFires)

    h = newHarness({ total = 5, max = 100, items = 1 })
    timer = h:loginSuccess()
    h:fire("HOUSING_STORAGE_UPDATED")
    h.scanner:ScanFullCatalog()
    assert(h.readFires == 1, "sanity: latched once")
    h.timeNow = 200
    assert(#h:runReadTimer(timer) == 0, "once done, the timer must not re-arm")
    assert(h.scanner:HasFirstReadAttempted() == false and h.readFires == 1,
        "once done, the timer must not set attempted or fire")
    print("hs538_first_read: A4 a later latch moves the state on ok")
end

print("hs538_first_read: ok")
