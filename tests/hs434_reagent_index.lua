-- luacheck: globals assert loadfile print io pcall error setmetatable C_Timer C_TradeSkillUI C_SpellBook InCombatLockdown CreateFrame Enum wipe
--
-- HS-434: reverse reagent index behind the reagent tooltip line
-- (Data/ReagentIndex.lua). Pins the learned-state invariant (the spell book
-- is read at every count, nothing is cached, GetRecipeInfo is never called),
-- the Basic-slot resolution rule, ownership readiness, chunked priming with
-- its combat pause, the debounced fallback, and error containment.
--
-- Every scenario loads a fresh copy of the module against fresh stubs.
-- Timer callbacks are collected, never run on their own; tests drain them
-- explicitly.

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

local function readFile(path)
    local f = assert(io.open(path, "r"))
    local content = f:read("*a")
    f:close()
    return content
end

local BASIC, FINISHING = 1, 2
local CURRENCY_SLOT = 3

-- Harness ---------------------------------------------------------------------

local env

-- Builds a schematic: slots = { { type = 1|2|nil, items = {...}, currency = bool } }
local function Schematic(slots)
    local out = {}
    for i, s in ipairs(slots) do
        local reagents = {}
        for _, itemID in ipairs(s.items or {}) do
            reagents[#reagents + 1] = { itemID = itemID }
        end
        if s.currency then
            reagents[#reagents + 1] = { currencyID = 3008 }
        end
        out[i] = {
            reagentType = s.type,
            dataSlotType = s.currency and CURRENCY_SLOT or 1,
            reagents = reagents,
        }
    end
    return { reagentSlotSchematics = out }
end

-- opts.sources = { [decorItemID] = spellID }
local function NewEnv(opts)
    opts = opts or {}
    env = {
        after = {},          -- { delay, fn } in schedule order
        newTimers = {},
        frame = nil,
        registered = {},
        registerCalls = 0,
        debug = {},
        measures = {},
        reads = {},          -- spellID -> GetRecipeSchematic call count
        totalReads = 0,
        schematics = {},     -- spellID -> schematic table, or function
        known = {},          -- spellID -> bool
        knownCalls = {},     -- spellID -> IsSpellKnown call count
        totalKnownCalls = 0,
        inCombat = false,
        records = {},
        ownedCount = 0,
        storageResponded = false,
        warm = false,
    }

    wipe = function(t)
        for k in pairs(t) do t[k] = nil end
        return t
    end

    C_Timer = {
        After = function(delay, fn)
            env.after[#env.after + 1] = { delay = delay, fn = fn }
        end,
        NewTimer = function(delay, fn)
            local timer = { delay = delay, fn = fn, cancelled = false }
            function timer:Cancel() self.cancelled = true end
            env.newTimers[#env.newTimers + 1] = timer
            return timer
        end,
    }

    InCombatLockdown = function() return env.inCombat end

    CreateFrame = function()
        local frame = {}
        env.frame = frame
        function frame:RegisterEvent(event)
            env.registered[event] = true
            env.registerCalls = env.registerCalls + 1
        end
        function frame:UnregisterEvent(event) env.registered[event] = nil end
        function frame:SetScript(name, fn)
            if name == "OnEvent" then frame.onEvent = fn end
        end
        return frame
    end

    Enum = { TradeskillSlotDataType = { Reagent = 1, ModifiedReagent = 2, Currency = CURRENCY_SLOT } }

    -- Any C_TradeSkillUI member other than GetRecipeSchematic (GetRecipeInfo
    -- included) errors the test.
    C_TradeSkillUI = setmetatable({
        GetRecipeSchematic = function(spellID, isRecraft)
            assert(isRecraft == false, "schematic must be read with isRecraft=false")
            env.reads[spellID] = (env.reads[spellID] or 0) + 1
            env.totalReads = env.totalReads + 1
            local s = env.schematics[spellID]
            if type(s) == "function" then return s() end
            return s
        end,
    }, {
        __index = function(_, key)
            error("C_TradeSkillUI." .. tostring(key) .. " must not be read", 2)
        end,
    })

    C_SpellBook = {
        IsSpellKnown = function(spellID)
            env.knownCalls[spellID] = (env.knownCalls[spellID] or 0) + 1
            env.totalKnownCalls = env.totalKnownCalls + 1
            return env.known[spellID] == true
        end,
    }

    local sources = {}
    for decorItemID, spellID in pairs(opts.sources or {}) do
        sources[decorItemID] = { profession = "Tailoring", recipeName = "r" .. decorItemID, spellID = spellID }
    end
    -- Non-numeric keys and entries without a spellID are never seeded.
    sources.meta = { spellID = 999999 }
    sources[777777] = { profession = "Tailoring", recipeName = "no spell" }

    local HA = {
        Addon = {
            db = { profile = { debug = true } },
            Debug = function(_, message) env.debug[#env.debug + 1] = message end,
        },
        DevAddon = {},
        PerformanceTrace = {
            Measure = function(_, operation, workload, callback, ...)
                env.measures[#env.measures + 1] = { operation = operation, workload = workload }
                return callback(...)
            end,
        },
        CatalogStore = {
            Get = function(_, itemID) return env.records[itemID] end,
            GetOwnedCount = function() return env.ownedCount end,
        },
        CatalogScanner = {
            HasStorageResponded = function() return env.storageResponded end,
            IsWarm = function() return env.warm end,
        },
        ProfessionSources = sources,
    }
    env.HA = HA

    local chunk = assert(loadfile(root .. "/Data/ReagentIndex.lua"))
    chunk("Homestead", HA)
    env.index = HA.ReagentIndex
    return env
end

-- Runs the oldest scheduled C_Timer.After callback; returns its delay.
local function RunNextTick()
    local entry = table.remove(env.after, 1)
    assert(entry, "expected a scheduled tick")
    entry.fn()
    return entry.delay
end

local function Drain()
    local guard = 0
    while #env.after > 0 do
        guard = guard + 1
        assert(guard < 1000, "drain did not settle")
        RunNextTick()
    end
end

local function FireEvent(event)
    assert(env.frame and env.frame.onEvent, "no event frame")
    assert(env.registered[event], event .. " fired while not registered")
    env.frame.onEvent(env.frame, event)
end

-- Fires the live (last, uncancelled) fallback timer.
local function ExpireFallbackTimer()
    local live = nil
    for _, t in ipairs(env.newTimers) do
        if not t.cancelled and not t.fired then live = t end
    end
    assert(live, "no live fallback timer")
    assert(live.delay == 1, "fallback debounce must be 1 s")
    live.fired = true
    live.fn()
end

local function DebugCount(pattern)
    local n = 0
    for _, line in ipairs(env.debug) do
        if line:find(pattern) then n = n + 1 end
    end
    return n
end

local function LastRunLine()
    local last
    for _, line in ipairs(env.debug) do
        if line:find("run complete", 1, true) then last = line end
    end
    return last
end

local function Count(itemID)
    return env.index:GetMissingDecorCount(itemID)
end

local function Owned(decorItemID)
    env.records[decorItemID] = { isOwned = true }
end

local function Unowned(decorItemID)
    env.records[decorItemID] = { isOwned = false }
end

-- Counting --------------------------------------------------------------------

do
    NewEnv({ sources = { [1001] = 5001, [1002] = 5002, [1003] = 5003 } })

    -- Before Initialize: empty index.
    assert(Count(900) == 0, "count before Initialize must be 0")

    -- Two quality tiers (900, 901) in one Basic slot, a Finishing slot (950),
    -- and a Basic-typed currency slot on 1001.
    env.schematics[5001] = Schematic({
        { type = BASIC, items = { 900, 901 } },
        { type = FINISHING, items = { 950 } },
        { type = BASIC, currency = true },
    })
    -- nil reagentType is Basic too.
    env.schematics[5002] = Schematic({ { type = nil, items = { 900, 901 } } })
    -- 1003 lists reagent 930 in two Basic slots.
    env.schematics[5003] = Schematic({
        { type = BASIC, items = { 930 } },
        { type = BASIC, items = { 930 } },
    })

    env.index:Initialize()
    assert(env.totalReads == 0, "no read may run in the Initialize frame")
    Drain()
    assert(LastRunLine():find("trigger=login ops=3 chunks=1 pending=0", 1, true),
        "a currency slot must not block resolution: " .. tostring(LastRunLine()))
    assert(env.reads[999999] == nil, "non-numeric source keys are not seeded")

    env.ownedCount = 1
    Owned(1001)
    Unowned(1002)
    Unowned(1003)
    env.known[5001] = true
    env.known[5002] = true
    env.known[5003] = true

    assert(Count(900) == 1, "one owned + one known unowned decor must give 1")
    assert(Count(901) == 1, "every quality tier in a Basic slot maps")
    assert(Count(950) == 0, "Finishing reagents contribute nothing")
    assert(Count(930) == 1, "a reagent in two Basic slots of one recipe counts once")

    env.known[5002] = false
    assert(Count(900) == 0, "an unknown recipe spell contributes nothing")

    local before = env.totalKnownCalls
    assert(Count(nil) == 0, "nil itemID gives 0")
    assert(Count(123456) == 0, "unmapped itemID gives 0")
    assert(env.totalKnownCalls == before, "nil/unmapped itemIDs must not call IsSpellKnown")
end

-- No cache: the spell book is read on every count ------------------------------

do
    NewEnv({ sources = { [1001] = 5001 } })
    env.schematics[5001] = Schematic({ { type = BASIC, items = { 900 } } })
    env.index:Initialize()
    Drain()
    env.ownedCount = 1
    Unowned(1001)

    assert(Count(900) == 0, "not known gives 0")
    env.known[5001] = true -- no event fired
    assert(Count(900) == 1, "flipping the spell book result must show on the next count")
    env.known[5001] = false
    assert(Count(900) == 0, "flipping back must show on the next count")
end

-- Ownership is checked before the spell book ------------------------------------

do
    NewEnv({ sources = { [1001] = 5001, [1002] = 5002 } })
    env.schematics[5001] = Schematic({ { type = BASIC, items = { 900 } } })
    env.schematics[5002] = Schematic({ { type = BASIC, items = { 900 } } })
    env.index:Initialize()
    Drain()
    env.ownedCount = 1
    Owned(1001)
    Unowned(1002)
    env.known[5001] = true
    env.known[5002] = true
    assert(Count(900) == 1)
    assert(env.knownCalls[5001] == nil, "an owned decor's spell must never reach IsSpellKnown")
    assert(env.knownCalls[5002] == 1)
end

-- No GetRecipeInfo anywhere ------------------------------------------------------

do
    local indexSource = readFile(root .. "/Data/ReagentIndex.lua")
    local tooltipSource = readFile(root .. "/Overlay/Tooltips.lua")
    assert(not indexSource:find("GetRecipeInfo", 1, true), "ReagentIndex.lua must not use GetRecipeInfo")
    assert(not tooltipSource:find("GetRecipeInfo"), "Tooltips.lua must not use GetRecipeInfo")
end

-- Absent spell book API ------------------------------------------------------------

do
    NewEnv({ sources = { [1001] = 5001 } })
    env.schematics[5001] = Schematic({ { type = BASIC, items = { 900 } } })
    env.index:Initialize()
    Drain()
    env.ownedCount = 1
    Unowned(1001)
    env.known[5001] = true

    C_SpellBook = nil
    assert(Count(900) == 0, "absent C_SpellBook gives 0")
    assert(Count(900) == 0)
    C_SpellBook = {}
    assert(Count(900) == 0, "absent IsSpellKnown gives 0")
    assert(DebugCount("IsSpellKnown absent") == 1, "the absent-API notice prints once per session")
end

-- Readiness ----------------------------------------------------------------------

do
    NewEnv({ sources = { [1001] = 5001, [1002] = 5002 } })
    env.schematics[5001] = Schematic({ { type = BASIC, items = { 920 } } })
    env.schematics[5002] = Schematic({ { type = BASIC, items = { 920 } } })
    env.index:Initialize()
    Drain()
    env.known[5001] = true
    env.known[5002] = true

    -- Ownership unknown: records present, nothing owned, storage silent.
    Unowned(1001)
    Unowned(1002)
    assert(Count(920) == 0, "unknown ownership must count nothing")

    -- A owned lands; B has no record yet.
    env.records = {}
    Owned(1001)
    env.ownedCount = 1
    assert(Count(920) == 0, "a decor with no record is not counted")
    Unowned(1002)
    assert(Count(920) == 1, "an unowned record counts once it lands")

    -- ownedCount > 0 with storage answered but not warm keeps the per-item rule.
    env.records = {}
    Owned(1001)
    env.storageResponded = true
    env.warm = false
    assert(Count(920) == 0, "per-item rule must hold while ownedCount > 0")

    -- Confirmed zero: nothing owned, storage answered, not warm, no records.
    env.records = {}
    env.ownedCount = 0
    assert(Count(920) == 2, "confirmed zero counts every known recipe")
    env.known[5002] = false
    assert(Count(920) == 1)

    -- Storage answered and warm but ownedCount still 0 is a mid-scan owner.
    env.warm = true
    assert(Count(920) == 0, "warm with ownedCount 0 is not a confirmed zero")
end

-- Resolution rule -------------------------------------------------------------------

do
    NewEnv({ sources = { [1003] = 5003, [1004] = 5004 } })
    env.schematics[5003] = Schematic({ { type = FINISHING, items = { 940 } } })
    env.schematics[5004] = Schematic({
        { type = BASIC, items = { 910 } },
        { type = BASIC, items = {} },
    })
    env.index:Initialize()
    Drain()
    assert(LastRunLine():find("pending=2", 1, true),
        "no Basic slot, or an empty Basic slot, stays pending: " .. tostring(LastRunLine()))

    env.ownedCount = 1
    Unowned(1004)
    env.known[5004] = true
    assert(Count(910) == 1, "items read from a partially filled schematic are indexed")
    assert(Count(911) == 0)

    env.schematics[5004] = Schematic({
        { type = BASIC, items = { 910 } },
        { type = BASIC, items = { 911 } },
    })
    FireEvent("TRADE_SKILL_LIST_UPDATE")
    ExpireFallbackTimer()
    Drain()
    assert(LastRunLine():find("trigger=fallback ops=2 chunks=1 pending=1", 1, true), tostring(LastRunLine()))
    assert(Count(911) == 1, "the second slot's items are indexed once filled")
end

-- Chunking ------------------------------------------------------------------------------

do
    local sources = {}
    for i = 1, 45 do sources[2000 + i] = 6000 + i end
    NewEnv({ sources = sources })
    for i = 1, 45 do
        env.schematics[6000 + i] = Schematic({ { type = BASIC, items = { 3000 + i } } })
    end

    env.index:Initialize()
    assert(env.totalReads == 0, "Initialize must not read in its own frame")
    assert(#env.after == 1, "Initialize schedules exactly one tick")
    assert(RunNextTick() == 0.01)
    assert(env.totalReads == 20, "first chunk reads 20")
    RunNextTick()
    assert(env.totalReads == 40, "second chunk reads 20")
    RunNextTick()
    assert(env.totalReads == 45, "third chunk reads the last 5")
    assert(#env.after == 0, "run finished")

    local primeMeasures = {}
    for _, m in ipairs(env.measures) do
        if m.operation == "reagent_index_prime" then primeMeasures[#primeMeasures + 1] = m.workload end
    end
    assert(#primeMeasures == 3 and primeMeasures[1] == 1 and primeMeasures[2] == 2 and primeMeasures[3] == 3,
        "Measure once per chunk with the chunk index as workload")
    assert(LastRunLine():find("chunks=3 pending=0", 1, true), tostring(LastRunLine()))
    for i = 1, 45 do
        assert(env.reads[6000 + i] == 1, "every recipe read exactly once")
    end

    env.index:Initialize()
    assert(#env.after == 0 and env.totalReads == 45, "a second Initialize is a no-op")
    assert(env.registerCalls == 0, "nothing registers when nothing is pending")
end

-- Mid-run enqueue drains in the same run ---------------------------------------------------

do
    local sources = {}
    for i = 1, 25 do sources[2000 + i] = 6000 + i end
    NewEnv({ sources = sources }) -- no schematics: every recipe stays pending
    env.index:Initialize()
    assert(not env.registered.TRADE_SKILL_LIST_UPDATE, "nothing registers before a run completes")
    RunNextTick()
    assert(not env.registered.TRADE_SKILL_LIST_UPDATE, "nothing registers mid-run")
    Drain()
    assert(LastRunLine():find("trigger=login ops=25 chunks=2 pending=25", 1, true), tostring(LastRunLine()))
    assert(env.registered.TRADE_SKILL_LIST_UPDATE and env.registered.PLAYER_ENTERING_WORLD,
        "a run completing with residue registers the fallback events")

    FireEvent("PLAYER_ENTERING_WORLD")
    ExpireFallbackTimer()
    RunNextTick() -- 20 of 25
    local runLines = DebugCount("run complete")
    FireEvent("TRADE_SKILL_LIST_UPDATE")
    ExpireFallbackTimer() -- re-enqueues the 20 read; the 5 still queued dedupe
    Drain()
    assert(DebugCount("run complete") == runLines + 1, "mid-run enqueue drains in the same run")
    assert(LastRunLine():find("trigger=fallback ops=45 chunks=3 pending=25", 1, true), tostring(LastRunLine()))
end

-- Combat pause ---------------------------------------------------------------------------------

do
    local sources = {}
    for i = 1, 45 do sources[2000 + i] = 6000 + i end
    NewEnv({ sources = sources })
    for i = 1, 45 do
        env.schematics[6000 + i] = Schematic({ { type = BASIC, items = { 3000 + i } } })
    end
    env.index:Initialize()
    RunNextTick()
    assert(env.totalReads == 20)

    env.inCombat = true
    RunNextTick()
    assert(env.totalReads == 20, "no reads in combat")
    assert(#env.after == 1 and env.after[1].delay == 1.0, "one 1.0 s combat retry")
    assert(DebugCount("paused for combat") == 1)
    RunNextTick()
    assert(env.totalReads == 20 and #env.after == 1 and env.after[1].delay == 1.0, "still in combat: rescheduled")
    assert(DebugCount("paused for combat") == 1, "one pause line per run")

    env.inCombat = false
    Drain()
    assert(env.totalReads == 45, "resumes and finishes")
    for i = 1, 45 do
        assert(env.reads[6000 + i] == 1, "resume at the same cursor: none repeated or skipped")
    end
end

do
    -- Enqueue during a pause leaves exactly one pending tick.
    local sources = {}
    for i = 1, 25 do sources[2000 + i] = 6000 + i end
    NewEnv({ sources = sources })
    env.index:Initialize()
    Drain()
    FireEvent("TRADE_SKILL_LIST_UPDATE")
    ExpireFallbackTimer()
    RunNextTick()
    env.inCombat = true
    RunNextTick()
    assert(#env.after == 1)
    FireEvent("TRADE_SKILL_LIST_UPDATE")
    ExpireFallbackTimer()
    assert(#env.after == 1, "enqueue during a combat pause must not schedule a second tick")
    env.inCombat = false
    Drain()
    assert(LastRunLine():find("ops=45", 1, true), tostring(LastRunLine()))
end

-- Fallback -------------------------------------------------------------------------------------------

do
    NewEnv({ sources = { [1001] = 5001, [1002] = 5002 } })
    env.schematics[5001] = Schematic({ { type = BASIC, items = { 900 } } })
    env.index:Initialize()
    Drain()
    assert(LastRunLine():find("pending=1", 1, true), "the unresolved spell stays pending")
    assert(env.registered.TRADE_SKILL_LIST_UPDATE and env.registered.PLAYER_ENTERING_WORLD)

    local runLines = DebugCount("run complete")
    for _ = 1, 5 do FireEvent("TRADE_SKILL_LIST_UPDATE") end
    local cancelled = 0
    for _, t in ipairs(env.newTimers) do
        if t.cancelled then cancelled = cancelled + 1 end
    end
    assert(#env.newTimers == 5 and cancelled == 4, "each event restarts the debounce timer")
    ExpireFallbackTimer()
    Drain()
    assert(DebugCount("run complete") == runLines + 1, "five events within 1 s give one run")
    assert(env.reads[5001] == 1, "a resolved spell is never re-read")
    assert(env.reads[5002] == 2)

    env.schematics[5002] = Schematic({ { type = BASIC, items = { 901 } } })
    FireEvent("PLAYER_ENTERING_WORLD")
    ExpireFallbackTimer()
    Drain()
    assert(LastRunLine():find("pending=0", 1, true))
    assert(not env.registered.TRADE_SKILL_LIST_UPDATE and not env.registered.PLAYER_ENTERING_WORLD,
        "resolving the last spell unregisters both events")
    assert(env.reads[5001] == 1, "a resolved spell is never re-read")
end

-- Errors ---------------------------------------------------------------------------------------------

do
    -- A schematic read that throws or returns nil leaves the spell pending.
    NewEnv({ sources = { [1001] = 5001, [1002] = 5002 } })
    env.schematics[5001] = function() error("schematic unavailable") end
    env.schematics[5002] = nil
    env.index:Initialize()
    Drain()
    assert(LastRunLine():find("ops=2 chunks=1 pending=2", 1, true), tostring(LastRunLine()))
    assert(DebugCount("op dropped") == 0, "a caught schematic error is not a dropped op")
end

do
    -- ProcessChunk throws on op 3 of 5.
    local sources = {}
    for i = 1, 5 do sources[2000 + i] = 6000 + i end
    NewEnv({ sources = sources })
    for i = 1, 5 do
        env.schematics[6000 + i] = Schematic({ { type = BASIC, items = { 3000 + i } } })
    end
    local poisoned = setmetatable({}, { __index = function() error("malformed slot") end })
    env.schematics[6003] = { reagentSlotSchematics = { poisoned } }

    env.index:Initialize()
    local ok, err = pcall(RunNextTick)
    assert(not ok and tostring(err):find("malformed slot"), "the chunk error propagates")
    assert(#env.after == 1, "the next tick is scheduled before the error propagates")
    assert(DebugCount("op dropped") == 1)
    Drain()
    for _, spellID in ipairs({ 6001, 6002, 6003, 6004, 6005 }) do
        assert(env.reads[spellID] == 1, "only the throwing op is lost; the rest process once")
    end
    assert(LastRunLine():find("pending=1", 1, true), tostring(LastRunLine()))
    assert(DebugCount("op dropped") == 1, "one op-dropped line")

    -- running was cleared: a later enqueue starts a new run.
    env.schematics[6003] = Schematic({ { type = BASIC, items = { 3003 } } })
    FireEvent("TRADE_SKILL_LIST_UPDATE")
    ExpireFallbackTimer()
    assert(#env.after == 1, "a later enqueue starts a new run")
    Drain()
    assert(LastRunLine():find("trigger=fallback ops=1 chunks=1 pending=0", 1, true), tostring(LastRunLine()))
end

-- Hover measurement -----------------------------------------------------------------------------------

do
    NewEnv({ sources = { [1001] = 5001 } })
    env.schematics[5001] = Schematic({ { type = BASIC, items = { 900 } } })
    env.index:Initialize()
    Drain()
    env.measures = {}
    Count(123456)
    assert(#env.measures == 0, "a hash miss is never measured")
    Count(900)
    assert(#env.measures == 1 and env.measures[1].operation == "reagent_tooltip_count"
        and env.measures[1].workload == 900, "a mapped hover is measured with the itemID")

    env.HA.PerformanceTrace = nil
    env.ownedCount = 1
    Unowned(1001)
    env.known[5001] = true
    assert(Count(900) == 1, "works without the trace facade")
end

-- Debug gating -----------------------------------------------------------------------------------------

do
    NewEnv({ sources = { [1001] = 5001 } })
    env.HA.DevAddon = nil
    env.index:Initialize()
    Drain()
    assert(#env.debug == 0, "no debug output without the dev addon")

    NewEnv({ sources = { [1001] = 5001 } })
    env.HA.Addon.db.profile.debug = false
    env.index:Initialize()
    Drain()
    assert(#env.debug == 0, "no debug output with debug off")

    NewEnv({ sources = { [1001] = 5001 } })
    env.index:Initialize()
    Drain()
    assert(#env.debug > 0, "debug output with both set")
end

print("hs434_reagent_index.lua: ok")
