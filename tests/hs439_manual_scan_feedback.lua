-- luacheck: globals assert loadfile print CreateFrame C_Timer C_HousingCatalog InCombatLockdown GetTime

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- ManualScan used to drop a request silently when ScanFullCatalog was
-- blocked by SCAN_COOLDOWN or an already-running scan. This drives the real
-- Modules/CatalogScanner.lua and checks what the player is told, that no
-- second scan starts, and that the automatic callers print nothing.
-------------------------------------------------------------------------------

local function newHarness()
    local h = { frames = {}, timers = {}, scanStarts = 0, timeNow = 100, prints = {} }

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
            Print = function(_, ...) h.prints[#h.prints + 1] = table.concat({ ... }, " ") end,
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


local function contains(list, text)
    for _, line in ipairs(list) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

-- (1) Cooldown: the scan started at t=100, so a manual request at t=101.5 is
-- still inside the cooldown; the message carries no number.
do
    local h = newHarness()
    h.scanner:ScanFullCatalog()
    h.timeNow = 100.05
    h.timers[#h.timers].fn() -- scan #1 completes
    assert(h.scanStarts == 1, "sanity: one scan started")

    h.timeNow = 101.5
    local timersBefore = #h.timers
    h.scanner:ManualScan()
    assert(#h.prints == 1, "cooldown: exactly one message expected, got " .. #h.prints)
    assert(h.prints[1] == "Catalog scan is on cooldown. Try again in a few seconds.",
        "cooldown: wrong message: " .. tostring(h.prints[1]))
    assert(not h.prints[1]:find("%d"), "cooldown: message must not contain a digit")
    assert(h.scanStarts == 1, "cooldown: no second scan may start")
    assert(#h.timers == timersBefore, "cooldown: nothing may be queued")

    -- Cooldown unchanged: it still clears 5s after scan #1's start (t=105).
    h.timeNow = 104.9
    h.scanner:ManualScan()
    assert(h.prints[2] == "Catalog scan is on cooldown. Try again in a few seconds.",
        "cooldown: sub-second remainder must show the same message, got " .. tostring(h.prints[2]))
    assert(not h.prints[2]:find("%d"), "cooldown: message must not contain a digit")
    h.timeNow = 105.0
    h.scanner:ManualScan()
    assert(h.scanStarts == 2, "cooldown must clear at the original 5s mark")
    assert(#h.prints == 2, "starting a scan must not print a cooldown message")
end

-- (2) Already running: scan #1 is mid-batch.
do
    local h = newHarness()
    h.scanner:ScanFullCatalog() -- yields after batch 1, isScanning stays true
    local timersBefore = #h.timers
    h.scanner:ManualScan()
    assert(#h.prints == 1 and h.prints[1] == "A catalog scan is already in progress.",
        "running: wrong output: " .. tostring(h.prints[1]))
    assert(h.scanStarts == 1, "running: no second scan may start")
    assert(#h.timers == timersBefore, "running: nothing may be queued")
end

-- (3) Normal case: scan starts, callback prints the completion summary.
do
    local h = newHarness()
    h.scanner:ManualScan()
    assert(h.scanStarts == 1, "normal: scan should start")
    assert(#h.prints == 0, "normal: nothing printed before completion")
    h.timeNow = 100.05
    h.timers[#h.timers].fn()
    assert(contains(h.prints, "Catalog scan complete."), "normal: completion callback must print")
    assert(not contains(h.prints, "cooldown") and not contains(h.prints, "already in progress"),
        "normal: no cooldown/in-progress message")
end

-- (4) Automatic callers stay silent: a cooldown-blocked RequestScan retry
-- (event path) and an in-progress event print nothing.
do
    local h = newHarness()
    h.scanner:ScanFullCatalog()
    h.timeNow = 100.05
    h.timers[#h.timers].fn() -- scan #1 complete

    h.timeNow = 101.0
    h:fire("NEW_HOUSING_ITEM_ACQUIRED")
    h.timers[#h.timers].fn() -- RequestScan debounce lands inside cooldown
    assert(h.scanStarts == 1, "auto: cooldown-blocked request must not start a scan")

    local h2 = newHarness()
    h2.scanner:ScanFullCatalog() -- mid-scan
    h2:fire("NEW_HOUSING_ITEM_ACQUIRED")
    h2.timers[#h2.timers].fn()
    assert(h2.scanStarts == 1, "auto: in-progress request must not start a scan")

    assert(#h.prints == 0 and #h2.prints == 0, "auto callers must print nothing")
end

-- (5) No known items: ScanFullCatalog runs the callback, then returns nil.
-- ManualScan must treat only an explicit false as "blocked".
do
    local h = newHarness()
    h.HA.VendorData.GetAllVendors = function()
        h.scanStarts = h.scanStarts + 1
        return {}
    end
    h.scanner:ManualScan()
    assert(h.scanStarts == 1, "empty: the scan should have run")
    assert(contains(h.prints, "Catalog scan complete."), "empty: summary must print")
    assert(not contains(h.prints, "already in progress"),
        "empty: a completed empty scan must not report one in progress")
    assert(not contains(h.prints, "cooldown"), "empty: no cooldown message")
end

-- (6) The 3s initial-scan timer reaches ScanFullCatalog while a storage
-- event's scan is still running; that already-running branch must stay silent.
do
    local h = newHarness()
    C_HousingCatalog.GetCatalogEntryInfoByItem = function() return nil end
    C_HousingCatalog.GetDecorTotalOwnedCount = function() return 5 end
    local initial
    for _, timer in ipairs(h.timers) do
        if timer.delay == 3 then initial = timer end
    end
    assert(initial, "auto: initial-scan timer (delay 3) not found")
    h:fire("HOUSING_STORAGE_UPDATED") -- latches warm
    h.scanner:ScanFullCatalog() -- scan runs, yields mid-batch
    assert(h.scanStarts == 1, "auto: sanity: one scan running")
    initial.fn()
    assert(h.scanStarts == 1, "auto: initial timer must not start a second scan")
    assert(#h.prints == 0, "auto: initial timer hitting a running scan must print nothing")
end

print("hs439_manual_scan_feedback: ok")
