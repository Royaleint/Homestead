-- luacheck: globals assert loadfile print C_Timer GetTime time

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Shared C_Timer.After stub: records scheduled callbacks instead of running
-- them on a real clock, so the test can "pump" them deterministically.
-------------------------------------------------------------------------------

local scheduledTimers

local function ResetTimerStub()
    scheduledTimers = {}
end

-- Runs exactly the timers queued AS OF THIS CALL — one "pass." A callback
-- that schedules a NEW timer while running (e.g. RequestUpdate calling
-- C_Timer.After for the next ProcessPendingUpdates) queues it for the NEXT
-- PumpTimers() call, not this one; that distinction is exactly what the
-- dispatcher-mutation test below needs to observe "this pass vs next pass."
local function PumpTimers()
    local queue = scheduledTimers
    scheduledTimers = {}
    for _, fn in ipairs(queue) do
        fn()
    end
end

ResetTimerStub()
C_Timer = {
    After = function(_, fn)
        table.insert(scheduledTimers, fn)
    end,
}
GetTime = function() return 1000 end

-------------------------------------------------------------------------------
-- HS-209 (1) H1: Overlay:Initialize() registration ACTUALLY runs and its
-- OWNERSHIP_UPDATED -> RequestUpdate("all") -> ExecuteUpdate("all") chain
-- lands on Overlay:RefreshAll(). This is the class of test that would have
-- caught H1 (zero call sites) — it executes the real registration path
-- (loadfile events.lua + overlay.lua together, call Initialize() the way
-- core.lua's OnEnable now does), not a source-grep.
-------------------------------------------------------------------------------

local WiringHA = {
    Constants = { Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
    Addon = {
        db = { profile = {}, global = {} },
        RegisterModule = function() end,
        Debug = function() end,
    },
}

assert(loadfile(root .. "/Core/events.lua"))("Homestead", WiringHA)
assert(loadfile(root .. "/Overlay/overlay.lua"))("Homestead", WiringHA)

local refreshAllCalls = 0
WiringHA.Overlay.RefreshAll = function(...)
    refreshAllCalls = refreshAllCalls + 1
end

WiringHA.Overlay:Initialize()

-- Calling Initialize() a second time (simulating a re-entered OnEnable) must
-- not double-register — fire OWNERSHIP_UPDATED once below and confirm
-- RefreshAll runs exactly once, not twice.
WiringHA.Overlay:Initialize()

WiringHA.Events:Fire("OWNERSHIP_UPDATED")
PumpTimers()

assert(refreshAllCalls == 1,
    "OWNERSHIP_UPDATED -> RequestUpdate('all') -> ExecuteUpdate('all') must land on RefreshAll exactly once "
    .. "(got " .. refreshAllCalls .. "); this is the H1 wiring + double-Initialize guard together")

print("hs209_wiring_batch: H1 registration path ok")

-------------------------------------------------------------------------------
-- HS-209 (2) M6: dispatcher-mutation — a callback that calls RequestUpdate
-- for a NEW update type mid-dispatch must not error (Lua 5.1 UB from
-- mutating pendingUpdates during pairs() traversal), and the new type must
-- be processed on the NEXT pass, not silently dropped or double-processed
-- on this one.
-------------------------------------------------------------------------------

ResetTimerStub()

local DispatchHA = {
    Addon = { Debug = function() end },
}
assert(loadfile(root .. "/Core/events.lua"))("Homestead", DispatchHA)

local bagsRuns, merchantRuns = 0, 0

DispatchHA.Events:RegisterCallback("bags", function()
    bagsRuns = bagsRuns + 1
    -- Mid-dispatch mutation: request a DIFFERENT, not-yet-pending update type
    -- while ProcessPendingUpdates' own traversal (over "bags") is still in
    -- flight.
    DispatchHA.Events:RequestUpdate("merchant")
end)
DispatchHA.Events:RegisterCallback("merchant", function()
    merchantRuns = merchantRuns + 1
end)

DispatchHA.Events:RequestUpdate("bags")
PumpTimers()

assert(bagsRuns == 1)
-- "merchant" was requested mid-dispatch of THIS pass — must not have run
-- yet (it wasn't in the snapshot this pass took), and must not have errored.
assert(merchantRuns == 0, "merchant requested mid-dispatch must not run within the SAME pass")

-- The mid-dispatch RequestUpdate schedules its own next pass — pump it.
PumpTimers()
assert(merchantRuns == 1, "merchant requested mid-dispatch must run on the NEXT pass")
assert(bagsRuns == 1, "bags must not re-run just because merchant was processed afterward")

print("hs209_wiring_batch: M6 dispatcher-mutation ok")

-------------------------------------------------------------------------------
-- HS-209 (2) item 6: update-type vs event-name storage split — a callback
-- registered under an update-type name (throttled path) and one registered
-- under an event name (Fire path) must never cross-fire each other.
-------------------------------------------------------------------------------

ResetTimerStub()
local SplitHA = { Addon = { Debug = function() end } }
assert(loadfile(root .. "/Core/events.lua"))("Homestead", SplitHA)

local updateTypeCalls, eventNameCalls = 0, 0
SplitHA.Events:RegisterCallback("bags", function() updateTypeCalls = updateTypeCalls + 1 end)
SplitHA.Events:RegisterCallback("OWNERSHIP_UPDATED", function() eventNameCalls = eventNameCalls + 1 end)

SplitHA.Events:Fire("bags")
assert(updateTypeCalls == 0, "Fire() must not reach an update-type registration")

SplitHA.Events:RequestUpdate("OWNERSHIP_UPDATED")
PumpTimers()
assert(eventNameCalls == 0, "RequestUpdate()/ExecuteUpdate() must not reach an event-name registration")

SplitHA.Events:RequestUpdate("bags")
PumpTimers()
assert(updateTypeCalls == 1)

SplitHA.Events:Fire("OWNERSHIP_UPDATED")
assert(eventNameCalls == 1)

print("hs209_wiring_batch: item 6 storage split ok")

-------------------------------------------------------------------------------
-- HS-209 (3) H3: CatalogStore batch reentrancy — nested Begin/End with a
-- mid-scan interleave (simulating CatalogScanner's scan batch and
-- ProfessionOverlay's reconcile batch both open at once) asserts exactly
-- one trailing OWNERSHIP_UPDATED fire, from the OUTERMOST EndBatch only.
-------------------------------------------------------------------------------

local ownershipFires = 0

time = function() return 1000 end

local CatalogHA = {
    Addon = {
        db = { global = { catalogItems = {}, schemaVersion = 4 } },
        RegisterModule = function() end,
        Debug = function() end,
    },
    Events = {
        Fire = function(_, eventName)
            if eventName == "OWNERSHIP_UPDATED" then
                ownershipFires = ownershipFires + 1
            end
        end,
    },
}

assert(loadfile(root .. "/Data/CatalogStore.lua"))("Homestead", CatalogHA)
CatalogHA.CatalogStore:Initialize()

-- Outer batch (e.g. CatalogScanner's scan) begins...
CatalogHA.CatalogStore:BeginBatch()
CatalogHA.CatalogStore:SetOwned(1001, "Outer Item")

-- ...an inner batch (e.g. ProfessionOverlay's reconcile) opens WHILE the
-- outer one is still active...
CatalogHA.CatalogStore:BeginBatch()
CatalogHA.CatalogStore:SetOwned(1002, "Inner Item")
CatalogHA.CatalogStore:EndBatch()  -- inner End: must NOT fire yet

assert(ownershipFires == 0, "an inner EndBatch must not fire while the outer batch is still open")

-- ...outer batch continues after the inner one closed...
CatalogHA.CatalogStore:SetOwned(1003, "Outer Item 2")
CatalogHA.CatalogStore:EndBatch()  -- outer End: depth back to 0, must fire exactly once

assert(ownershipFires == 1, "the outermost EndBatch must fire exactly once for the whole nested sequence")

-- A zero-change batch must not fire at all.
CatalogHA.CatalogStore:BeginBatch()
CatalogHA.CatalogStore:EndBatch()
assert(ownershipFires == 1, "a batch with no ownership changes must not fire")

-- Underflow (End with no matching Begin) must not error and must not go
-- negative (floor at 0, Debug-warn instead).
CatalogHA.CatalogStore:EndBatch()
CatalogHA.CatalogStore:BeginBatch()
CatalogHA.CatalogStore:SetOwned(1004, "Post-Underflow Item")
CatalogHA.CatalogStore:EndBatch()
assert(ownershipFires == 2, "underflow must not leave depth negative and block the next real batch's fire")

print("hs209_wiring_batch: H3 batch reentrancy ok")

-------------------------------------------------------------------------------
-- HS-209 (4) M10a: a non-number schemaVersion (hand-edited WTF, downgrade
-- artifact) must not crash RunMigrations/Initialize — it must repair to 1
-- and proceed, not abort the enable chain.
-------------------------------------------------------------------------------

local CorruptSchemaHA = {
    Addon = {
        -- A hand-edited/downgraded WTF could plausibly leave schemaVersion as
        -- a string ("4") as easily as some other stray type; a string is the
        -- most realistic corruption to pin here.
        db = { global = { catalogItems = {}, schemaVersion = "corrupt" } },
        RegisterModule = function() end,
        Debug = function() end,
    },
}

assert(loadfile(root .. "/Data/CatalogStore.lua"))("Homestead", CorruptSchemaHA)

local initOk, initErr = pcall(function()
    CorruptSchemaHA.CatalogStore:Initialize()
end)
assert(initOk, "Initialize() must not throw on a non-number schemaVersion: " .. tostring(initErr))

-- Repaired to a real number and migrations ran to completion (idempotent
-- migrations still advance schemaVersion to the current version — 5 as of
-- HS-205's parsedSources/catalogItems dedup migration).
assert(type(CorruptSchemaHA.Addon.db.global.schemaVersion) == "number")
assert(CorruptSchemaHA.Addon.db.global.schemaVersion == 5)

print("hs209_wiring_batch: M10a schemaVersion guard ok")
