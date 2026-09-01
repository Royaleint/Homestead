-- luacheck: globals assert loadfile print

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-282 sub-item I: full-reachability sweep engine smoke test.
--
-- MemoryEstimator.NewSweepContext/SeedForeignRoots/SweepRoot back /hs debug
-- memfloor (Core/DevMemoryDiagnostics.lua), the full-reachability sibling to
-- EstimateTableBytes's curated-subsystem walk. This pins: the sweep's byte
-- model stays identical to the calibrated walker on a pure-data fixture (the
-- drift guard tests/hs282_memory_estimator.lua's calibration depends on),
-- first-owner-wins attribution across a shared `ctx.seen`, the foreign-root
-- pre-seed boundary, the widget non-recursion default (and 'deep' opt-in),
-- function dedup, the node cap, and cycle safety.
-------------------------------------------------------------------------------

local HA = {}
assert(loadfile(root .. "/Core/MemoryEstimator.lua"))("Homestead", HA)

local ME = HA.MemoryEstimator
assert(ME, "MemoryEstimator did not register itself on HA")
assert(ME.NewSweepContext, "NewSweepContext missing")
assert(ME.SeedForeignRoots, "SeedForeignRoots missing")
assert(ME.SweepRoot, "SweepRoot missing")

-------------------------------------------------------------------------------
-- 1. Drift guard (design §4a): SweepRoot on a fresh unseeded context must
-- equal EstimateTableSizeBytes exactly for a pure-data fixture (no functions,
-- no widgets) -- the sweep walker reuses the same constants and #t
-- classification as the calibrated walker, so the two must never disagree on
-- a shape neither widget-boundary nor cap logic ever touches.
-------------------------------------------------------------------------------

local pureData = {
    name = "Stormwind",
    tags = { "capital", "human", "alliance" },
    counts = { 1, 2, 3, 4, 5 },
    nested = { a = "x", b = "y", c = { deep = "value" } },
}

do
    local ctx = ME.NewSweepContext()
    local sweepBytes = ME.SweepRoot(ctx, pureData)
    local estBytes = ME.EstimateTableSizeBytes(pureData)
    assert(sweepBytes == estBytes,
        "SweepRoot on a fresh context must equal EstimateTableSizeBytes exactly for pure data ("
            .. tostring(sweepBytes) .. " vs " .. tostring(estBytes) .. ")")
end

print("hs282i_drift_guard: ok")

-------------------------------------------------------------------------------
-- 2. First-owner-wins: two roots sharing a subtable -- the FIRST root walked
-- carries the shared subtable's bytes, the second does not. Swapping walk
-- order swaps which root carries it. This is the attribution rule the whole
-- report's ordered root list depends on (design §2).
-------------------------------------------------------------------------------

-- The shared subtable is array-part-only numeric content (no strings
-- anywhere in it), and rootA/rootB use entirely DISJOINT key names and
-- numeric (not string) "own" values. Both exclusions matter: strings are
-- deduplicated by a SEPARATE mechanism (ctx.seen keyed on the string value,
-- inside SweepHeapRefBytes) that survives even if table-level first-owner-
-- wins is broken -- a shared VALUE string, or even just same-named KEY
-- strings ("own"/"own", "ref"/"ref") reused across both roots, dedup on
-- their own and produce a smaller-but-still-nonzero bytesA/bytesB gap purely
-- from string interning, independent of whether table dedup works at all.
-- With every string eliminated from the comparison, the only remaining
-- source of a bytesA/bytesB gap is the shared TABLE reference itself, which
-- isolates exactly what this test means to pin.
local function makeSharedPair()
    local shared = { 111, 222, 333 }
    local rootA = { aOwn = 1, aRef = shared }
    local rootB = { bOwn = 2, bRef = shared }
    return rootA, rootB
end

do
    local rootA, rootB = makeSharedPair()
    local ctx = ME.NewSweepContext()
    local bytesA = ME.SweepRoot(ctx, rootA)
    local bytesB = ME.SweepRoot(ctx, rootB)
    assert(bytesA > bytesB,
        "the first-walked root must carry the shared subtable's bytes, the second must not")
end

do
    local rootA, rootB = makeSharedPair()
    local ctx = ME.NewSweepContext()
    local bytesB = ME.SweepRoot(ctx, rootB)
    local bytesA = ME.SweepRoot(ctx, rootA)
    assert(bytesB > bytesA,
        "swapping walk order must swap which root carries the shared subtable's bytes")
end

print("hs282i_first_owner_wins: ok")

-------------------------------------------------------------------------------
-- 3. Pre-seed blocks: a table placed in ctx.seen BEFORE the walk contributes
-- 0 bytes and is not descended into -- this is the mechanism SeedForeignRoots
-- uses to block every Blizzard/foreign table reached from _G (design §1c).
-------------------------------------------------------------------------------

do
    local blocked = { big = "content that would show up in a nonzero byte count if walked" }
    local ctx = ME.NewSweepContext()
    ctx.seen[blocked] = true
    local bytes, tables = ME.SweepRoot(ctx, blocked)
    assert(bytes == 0, "a pre-seeded table must contribute 0 bytes")
    assert(tables == 0, "a pre-seeded table must not be descended into (0 new tables)")
end

print("hs282i_preseed_blocks: ok")

-------------------------------------------------------------------------------
-- 4. Widget non-recursion: a table shaped like a WoW widget (rawget(t, 0) ~=
-- nil) is charged HEADER_BYTES only by default -- counted as a widget, added
-- to `seen`, its field graph never walked. With opts.walkWidgets = true it IS
-- walked like any other table (design §1d).
-------------------------------------------------------------------------------

local function makeWidgetFixture()
    local bigInner = {}
    for i = 1, 50 do
        bigInner[i] = "padding-entry-" .. i
    end
    return { [0] = "userdata-stand-in", big = bigInner }
end

local headerOnlyBytes = ME.EstimateTableSizeBytes({})

do
    local widget = makeWidgetFixture()
    local ctx = ME.NewSweepContext()
    local bytes, tables, _, widgets = ME.SweepRoot(ctx, widget)
    assert(widgets == 1, "the widget itself must be counted once")
    assert(tables == 1, "the widget's field graph must not be descended -- only the widget table itself is a new table")
    assert(bytes == headerOnlyBytes,
        "default mode must charge a widget HEADER_BYTES only (" .. tostring(bytes) .. " vs " .. tostring(headerOnlyBytes) .. ")")
end

do
    local widget = makeWidgetFixture()
    local ctx = ME.NewSweepContext({ walkWidgets = true })
    local bytes, tables, _, widgets = ME.SweepRoot(ctx, widget)
    assert(widgets == 1, "'deep' mode must still count the widget once")
    assert(tables == 2, "'deep' mode must descend into the widget's field graph (widget + big = 2 tables)")
    assert(bytes > headerOnlyBytes, "'deep' mode must charge more than HEADER_BYTES once it walks the big field")
end

print("hs282i_widget_non_recursion: ok")

-------------------------------------------------------------------------------
-- 5. Function dedup: the same function value referenced from three slots
-- counts once -- fn is a COUNT of distinct function objects, never a size
-- (design §3).
-------------------------------------------------------------------------------

do
    local fn = function() end
    local fixture = { a = fn, b = fn, c = fn }
    local ctx = ME.NewSweepContext()
    local _, _, functions = ME.SweepRoot(ctx, fixture)
    assert(functions == 1, "the same function value in three slots must count once, not three times")
end

print("hs282i_function_dedup: ok")

-------------------------------------------------------------------------------
-- 6. Node cap: nodeCap = 5 over a BRANCHING graph (100 sibling subtables
-- under one root) must set ctx.aborted and actually stop. The fixture
-- branches (a linear chain has nothing left to iterate after an abort, so
-- a flag-but-keep-walking mutant is indistinguishable from a stop). The
-- walker's two stop mechanisms -- the entry return-on-aborted and the
-- pairs-loop break -- are mutually redundant: removing either ONE alone
-- leaves nodes <= 6 because the other fully compensates (measured, both
-- single mutants survive; that is defense in depth, not a coverage gap).
-- What this part pins: the cap check itself, and that removing BOTH stop
-- mechanisms is caught (nodes reaches 101; measured KILLED).
-------------------------------------------------------------------------------

do
    local branchRoot = {}
    for i = 1, 100 do
        branchRoot[i] = {}
    end

    local ctx = ME.NewSweepContext({ nodeCap = 5 })
    ME.SweepRoot(ctx, branchRoot)
    assert(ctx.aborted == true, "exceeding nodeCap over 100 sibling subtables must set ctx.aborted")
    assert(ctx.nodes <= 6, "the walk must stop at the cap, not merely flag it (nodes = " .. tostring(ctx.nodes) .. ")")
end

print("hs282i_node_cap: ok")

-------------------------------------------------------------------------------
-- 7. Cycle safety: a self-referencing graph must terminate (not infinite
-- loop) and still count the cyclic table's own entries.
-------------------------------------------------------------------------------

do
    local cyclic = { name = "self-referencing" }
    cyclic.self = cyclic
    local ctx = ME.NewSweepContext()
    local bytes = ME.SweepRoot(ctx, cyclic)
    assert(bytes > 0, "a cyclic root's own entries must still be counted")
end

print("hs282i_cycle_safety: ok")

-------------------------------------------------------------------------------
-- 8. IsWidget metatable guard: the sweep must never execute a walked table's
-- __index (regression for the HS-282-I Gate 1 Critical). Three shapes, all
-- found live in this addon's reachable graph: CallbackHandler's materializing
-- __index (creates a permanent entry on ANY missing-key read), a raising
-- __index (Foundry db controller's refuse()), and LDB's __metatable-shadowed
-- function __index (getmetatable returns a string, hiding the hazard).
-- Reverting the guard in IsWidget must fail this part.
-------------------------------------------------------------------------------

do
    -- CallbackHandler-1.0.lua:7, verbatim shape.
    local events = setmetatable({}, { __index = function(tbl, key)
        tbl[key] = {}
        return tbl[key]
    end })
    local ctx = ME.NewSweepContext()
    ME.SweepRoot(ctx, { events = events })
    assert(rawget(events, "GetObjectType") == nil,
        "sweeping a materializing-__index table must not create keys in it")
    assert(next(events) == nil, "the materializing-__index table must stay empty after the sweep")

    -- Foundry DB.lua controllerMeta shape: __index that raises.
    local raising = setmetatable({}, { __index = function()
        error("deny-listed key")
    end })
    local ok = pcall(function()
        ME.SweepRoot(ME.NewSweepContext(), { controller = raising })
    end)
    assert(ok, "sweeping a raising-__index table must not propagate the raise")

    -- LibDataBroker-1.1.lua domt shape: __metatable shadowing hides a
    -- function __index from getmetatable entirely.
    local executed = false
    local shadowed = setmetatable({}, {
        __metatable = "access denied",
        __index = function()
            executed = true
            return nil
        end,
    })
    ME.SweepRoot(ME.NewSweepContext(), { dataObj = shadowed })
    assert(executed == false,
        "a __metatable-shadowed function __index must never execute during the sweep")
end

print("hs282i_iswidget_metatable_guard: ok")

print("hs282i_memory_floor_sweep: ok")
