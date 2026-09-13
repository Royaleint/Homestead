-- luacheck: globals assert loadfile print CreateFrame C_Timer C_HousingCatalog InCombatLockdown GetTime

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-- Mirrors Modules/CatalogScanner.lua's SCAN_COOLDOWN, which isn't exposed on
-- HA -- lets scenario 2 compute an expected cooldown-remaining value the same
-- way the production code does, instead of hardcoding the result.
local SCAN_COOLDOWN = 5

-------------------------------------------------------------------------------
-- HS-305: the scanRequestedDuringActive completion rescan re-enters
-- ScanFullCatalog through RequestScan's 1.0s debounce. Before this fix,
-- ScanFullCatalog's SCAN_COOLDOWN guard just logged a debug line and
-- returned nothing on a blocked call — RequestScan's callback had no way to
-- tell the scan didn't start, so a completion rescan landing inside the 5s
-- cooldown (any ordinary sub-4s scan with a mid-scan storage event) was
-- dropped permanently, not merely delayed.
--
-- This test loads the REAL Modules/CatalogScanner.lua, drives a real
-- multi-batch scan (21 items, ITEMS_PER_BATCH=20, so the batch loop yields
-- once via C_Timer.After), injects a mid-scan rescan request through the
-- real NEW_HOUSING_ITEM_ACQUIRED event handler (exactly how
-- scanRequestedDuringActive gets set in production), lets the scan finish
-- (arming the real completion-rescan call at the "scan complete" branch),
-- and drives fake time by hand so the completion rescan's own RequestScan()
-- call lands inside the cooldown window. Timers are fired in the order the
-- scenario needs (not necessarily insertion order) since this harness is a
-- recorded-closure queue, not a real scheduler — GetTime is the only clock
-- the module itself consults.
-------------------------------------------------------------------------------

local function newHarness()
    local h = { frames = {}, timers = {}, scanStarts = 0, timeNow = 100 }

    CreateFrame = function()
        local frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:SetScript(_, handler) self.handler = handler end
        h.frames[#h.frames + 1] = frame
        return frame
    end

    -- Timers are recorded, never auto-run — the test fires each one by hand,
    -- same convention as tests/hs276_login_force_load.lua.
    C_Timer = {
        After = function(delay, fn) h.timers[#h.timers + 1] = { delay = delay, fn = fn } end,
        NewTimer = function(delay, fn)
            h.timers[#h.timers + 1] = { delay = delay, fn = fn }
            return { Cancel = function() end }
        end,
    }

    InCombatLockdown = function() return false end
    GetTime = function() return h.timeNow end

    -- Present but deliberately bare: ScanItem's byItem/RecordID probes both
    -- no-op (no GetCatalogEntryInfoByItem, no CatalogStore), so every scanned
    -- item is a harmless nil result — only the scan's start/finish bookkeeping
    -- matters here, not ownership derivation.
    C_HousingCatalog = {}

    local HA = {
        Addon = {
            Debug = function() end,
            RegisterModule = function() end,
        },
        VendorData = {
            -- GetAllVendors is CollectAllKnownItemIDs' first call, made
            -- exactly once per ScanFullCatalog invocation that clears the
            -- isScanning/cooldown/C_HousingCatalog guards — the observable
            -- for "a scan actually started" vs. "blocked before starting".
            GetAllVendors = function()
                h.scanStarts = h.scanStarts + 1
                return { "vendor1" }
            end,
            GetItemsForVendor = function()
                local items = {}
                for i = 1, 21 do -- > ITEMS_PER_BATCH (20): forces one batch yield
                    items[i] = { itemID = i }
                end
                return items
            end,
            GetItemID = function(_, item) return item.itemID end,
        },
    }
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

    return h
end

-------------------------------------------------------------------------------
-- (1) Direct contract pin: a call landing inside SCAN_COOLDOWN must report
-- back that it did not start, plus how long remains, instead of returning
-- nothing (the shape RequestScan's fix now depends on).
-------------------------------------------------------------------------------
do
    local h = newHarness()

    h.scanner:ScanFullCatalog() -- t=100: scan starts, batch 1 yields (21 items)
    local continuation = h.timers[#h.timers]
    h.timeNow = 100.05
    continuation.fn() -- drains item 21, scan complete
    assert(h.scanStarts == 1, "sanity: exactly one scan should have started")

    local started, remaining = h.scanner:ScanFullCatalog() -- still t=100.05, on cooldown
    assert(started == false, "a call inside SCAN_COOLDOWN must report started == false")
    assert(type(remaining) == "number" and remaining > 0 and remaining <= 5,
        "a blocked call must report the remaining cooldown, got " .. tostring(remaining))
    assert(h.scanStarts == 1, "the blocked direct call must not have started a second scan")
end

-------------------------------------------------------------------------------
-- (2) Full mechanism pin: mid-scan event -> scanRequestedDuringActive ->
-- completion rescan lands inside cooldown -> reschedules -> eventually fires.
-------------------------------------------------------------------------------
do
    local h = newHarness()

    local scan1StartTime = h.timeNow -- t=100, the lastScanTime the cooldown is measured against
    h.scanner:ScanFullCatalog() -- t=100: scan #1 starts, batch 1 yields
    local batch1Continuation = h.timers[#h.timers]
    assert(h.scanStarts == 1, "scan #1 should have started")

    -- Mid-scan: a real storage event arrives while isScanning is still true.
    h:fire("NEW_HOUSING_ITEM_ACQUIRED") -- schedules RequestScan's 1.0s debounce
    local midScanDebounce = h.timers[#h.timers]

    h.timeNow = 100.5
    midScanDebounce.fn() -- isScanning is true -> only flags scanRequestedDuringActive
    assert(h.scanStarts == 1, "a mid-scan request must not itself start a second scan")

    -- Finish scan #1. The "scan complete" branch finds scanRequestedDuringActive
    -- true and calls RequestScan() itself — the exact mechanism HS-305 covers.
    h.timeNow = 101.0
    batch1Continuation.fn()
    local completionDebounce = h.timers[#h.timers]
    assert(completionDebounce ~= midScanDebounce,
        "scan completion must have armed its own completion-rescan debounce")
    assert(h.scanStarts == 1, "the completion rescan must not have started yet")

    -- That debounce lands ~1s after a scan that started <5s earlier (101 -> 102,
    -- against lastScanTime == 100) — exactly the silent-drop window HS-305
    -- describes.
    h.timeNow = 102.0
    local timerCountBeforeBlock = #h.timers
    completionDebounce.fn()
    assert(h.scanStarts == 1, "the cooldown-blocked completion rescan must not start a scan")
    assert(#h.timers > timerCountBeforeBlock,
        "HS-305: a cooldown-blocked completion rescan must reschedule a retry, not drop silently")
    local retry = h.timers[#h.timers]

    -- The harness ignores each timer's delay when firing it by hand, so a
    -- wrong-magnitude cooldownRemaining (e.g. off by a constant factor) would
    -- still pass every assertion above. Pin the retry's delay to the same
    -- SCAN_COOLDOWN - (currentTime - lastScanTime) formula ScanFullCatalog
    -- itself uses.
    local expectedRemaining = SCAN_COOLDOWN - (h.timeNow - scan1StartTime)
    assert(retry.delay == expectedRemaining,
        "HS-305: retry delay must equal the actual remaining cooldown, got "
            .. tostring(retry.delay) .. " expected " .. tostring(expectedRemaining))

    -- Advance past the remaining cooldown and let the retry re-arm through
    -- RequestScan's own debounce (the file's existing retry-until-clear idiom).
    h.timeNow = 105.5
    retry.fn()
    local retryDebounce = h.timers[#h.timers]
    assert(retryDebounce ~= retry, "the retry must re-arm through RequestScan, scheduling its own debounce")

    h.timeNow = 106.5 -- 106.5 - 100 == 6.5 >= SCAN_COOLDOWN: cleared
    retryDebounce.fn()
    assert(h.scanStarts == 2,
        "HS-305: the blocked completion rescan must eventually fire a real scan")

    -- Drain scan #2's own batch-2 continuation so nothing is left dangling.
    local batch2Continuation = h.timers[#h.timers]
    batch2Continuation.fn()
end

print("hs305_cooldown_reschedule: ok")
