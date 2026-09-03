--[[
    Homestead - MemoryEstimator

    Cycle-safe Lua table size estimator, built for the HS-282 umbrella
    per-subsystem memory-budget breakdown (/hs debug membudget, Core/core.lua).
    Most subsystems that ticket needs measured have no safe way to wipe and
    force a synchronous full rebuild mid-session (badge caches, the search
    index, CatalogStore's identity caches all repopulate lazily on the next
    player action, not on demand) -- GetAddOnMemoryUsage delta measurement
    (see core.lua's MeasureAllSourcesCacheIsolatedKB, the one subsystem that
    DOES have such a path) isn't usable for those. This walker estimates
    retained size directly from the table graph instead: non-destructive,
    safe to run on anything, at the cost of being an approximation rather
    than an exact accounting.

    Accounting model (calibrated against real Data/ files loaded under
    desktop Lua 5.1 with collectgarbage("count") bracketing -- see
    tests/hs282_memory_estimator.lua's calibration section, which asserts
    every sampled file lands within a stated tolerance band of its live
    measured size):
      - HEADER_BYTES is charged once per table (the Table struct + GC header
        Lua allocates for every table, empty or not).
      - Array-part entries (keys that are integers in the range 1..#t, the
        same "sequence" any table's Lua length operator recognizes) are
        charged ARRAY_SLOT_BYTES each: one TValue slot, no separate key
        storage, matching Lua's array-part layout.
      - Everything else goes through the hash part and is charged
        HASH_ENTRY_BYTES each: the Node struct (key TValue + value TValue +
        next pointer), with an average slack allowance baked in for Lua's
        power-of-two hash-part sizing (a table with, say, 6 hash entries
        still allocates 8 Node slots; this walker cannot see the actual
        rehash boundary from pairs() alone, so it charges the historically
        measured AVERAGE per-used-entry cost across many real tables rather
        than the exact slot count of any one table).
      - A slot (array or hash) already carries a number/boolean/nil value
        fully inline -- no separate charge. A slot that instead references a
        string or table is charged only that referenced object's OWN
        storage (via EstimateHeapRefBytes), since the slot itself already
        accounted for the pointer.
      - This is an approximation of Lua's array-part boundary, not a
        reimplementation of luaH_resize's density heuristic -- a table whose
        real array part Lua chose not to fill fully (sparse insertion
        history) can be misclassified here. Tables keyed by arbitrary
        integers with gaps (e.g. itemID-keyed data) correctly fall through
        to the hash-part charge, since #t is 0 or small for those.

    Known error sources (a budget estimate for prioritization, not an exact
    memory accounting -- do not quote these numbers as authoritative):
      1. HASH_ENTRY_BYTES is a measured average, not an exact per-table
         count -- real overhead varies with a table's specific load
         factor/rehash state, which pairs() cannot expose.
      2. Strings are deduplicated (Lua interns them) WITHIN one top-level
         EstimateTableSizeBytes/EstimateTablesSizeBytes call via the `seen`
         set, so a literal referenced many times inside one call is charged
         once, not once per reference. Dedup does NOT cross separate calls
         -- each subsystem line in core.lua's DebugMemBudgetReport is
         measured with its own fresh `seen` set (unless explicitly grouped
         via EstimateTablesSizeBytes, which shares one `seen` set across its
         whole group), so a string shared BETWEEN two separately-measured
         subsystem lines (e.g. a zone name appearing in both VendorIdentity
         and DecorMapping) is charged to both. This overstates the SUM of
         all subsystem lines relative to the addon's true total heap
         footprint; it does not affect the accuracy of any single line's
         own accounting, and it is a distinct effect from #1's per-table
         calibration error -- the two can push the total in opposite
         directions and neither is assumed to dominate.
      3. Cycles and repeated table references WITHIN one call are correctly
         deduplicated via the same `seen` set -- a table reached a second
         time in the same walk contributes 0 bytes on that second visit.
      4. The array-part/hash-part split is a #t-based approximation (see
         "Accounting model" above), not Lua's actual insertion-order-
         dependent density heuristic -- a real table can retain some
         non-contiguous integer keys in its array part, or leave some
         contiguous ones in the hash part, depending on how it was built.
      5. Functions/userdata/threads referenced from a slot are rare in these
         data tables (they show up only in module tables that mix methods
         with data, e.g. VendorIdentity) and are charged a flat placeholder
         for the referenced object -- this walker estimates data, not code.
      6. Data reachable ONLY through a function's closure upvalue -- not
         stored as a field on any table this walker can reach -- is
         completely invisible to it. This is not a single-file quirk --
         confirmed in at least two Data/ files so far:
           - Data/AchievementSources.lua builds a reverse index
             (achievementToItems, ~a third of the file's real footprint) as
             a plain `local`, captured by the module's API functions as an
             upvalue but never assigned onto HA.AchievementSources or
             HA.AchievementSourcesModule as a field.
           - Data/EndeavorsData.lua:39 (lowerVendorNameToNpcID) follows the
             identical shape -- a vendor-name reverse-lookup local, built
             after the Vendors table loads, never exposed as a field.
         core.lua's DebugMemBudgetReport marks any subsystem line known to
         have this gap with an "est*" technique suffix directly in its
         output (not just in this comment or the calibration test), since a
         reader of the live report has no way to see a source comment. The
         AchievementSources file is pipeline-generated ("DO NOT EDIT" in its
         own header), so exposing the index as a field isn't a fix this
         ticket can make; the calibration test documents both known cases
         rather than silently absorbing them into the tolerance band.
      7. The three constants above are a single flat linear fit across a
         calibration corpus spanning roughly 11KB to 1.06MB of real Data/
         files -- at the extremes of that range (a single very large table,
         or a file built from many very small tables), the model's relative
         error can exceed the calibration test's per-file tolerance band
         even though the absolute KB error stays small. The calibration test
         documents which sampled files this affects and why.
]]

local _, HA = ...

local MemoryEstimator = {}
HA.MemoryEstimator = MemoryEstimator

local type = type
local pairs = pairs
local math_floor = math.floor

-- Argus's initial single-file measurement (Gate 1, HS-282) suggested ~80-90
-- bytes/table for the header and ~50 bytes/entry for the hash part. This
-- module's calibration test (tests/hs282_memory_estimator.lua) jointly fits
-- all three constants against a corpus of real Data/ files spanning roughly
-- 11KB to 1.06MB, and 76/53 is the best joint fit found across that range --
-- a flat linear model can't hit every file in [0.85, 1.15] simultaneously at
-- this scale spread (see the calibration test's comments for the two known
-- outliers and why). ARRAY_SLOT_BYTES=16 matches Argus's stated figure
-- directly (a TValue slot with no separate key storage) and wasn't found to
-- need adjustment.
local HEADER_BYTES = 76
local ARRAY_SLOT_BYTES = 16
local HASH_ENTRY_BYTES = 53
local STRING_HEADER_BYTES = 24
local OTHER_VALUE_BYTES = 40

local EstimateTableBytes
local EstimateHeapRefBytes

-- Charges the storage of a value REFERENCED from a slot (array or hash) --
-- the slot itself already paid for the pointer/inline-value cost, so this
-- only adds bytes for values that live in their own separate heap
-- allocation (tables, interned strings). Numbers/booleans/nil are fully
-- represented inline in the slot that holds them, so they add nothing here.
EstimateHeapRefBytes = function(v, seen)
    local vt = type(v)
    if vt == "table" then
        return EstimateTableBytes(v, seen)
    elseif vt == "string" then
        if seen[v] then
            return 0
        end
        seen[v] = true
        return STRING_HEADER_BYTES + #v
    elseif vt == "number" or vt == "boolean" or vt == "nil" then
        return 0
    else
        -- function/userdata/thread: rough placeholder for the referenced
        -- object -- this walker estimates data, not code (see error #5).
        return OTHER_VALUE_BYTES
    end
end

EstimateTableBytes = function(t, seen)
    if seen[t] then
        return 0
    end
    seen[t] = true

    local bytes = HEADER_BYTES
    local n = #t -- Lua 5.1 border; used as the array-part boundary approximation

    for k, v in pairs(t) do
        if type(k) == "number" and k >= 1 and k <= n and k == math_floor(k) then
            -- Array part: one TValue slot, no stored key.
            bytes = bytes + ARRAY_SLOT_BYTES
            bytes = bytes + EstimateHeapRefBytes(v, seen)
        else
            -- Hash part: the Node struct already covers both the key and
            -- value slots (see HASH_ENTRY_BYTES above).
            bytes = bytes + HASH_ENTRY_BYTES
            bytes = bytes + EstimateHeapRefBytes(k, seen)
            bytes = bytes + EstimateHeapRefBytes(v, seen)
        end
    end

    return bytes
end

-- Estimates the retained size of `t` in bytes, cycle-safe within this one
-- call (a table or string reached more than once counts only on first
-- sighting -- see error source #2/#3 above for what that does and doesn't
-- cover). Non-table input returns 0 so callers can pass a possibly-nil
-- reference (e.g. a lazily-built index) without a separate type check --
-- callers that need to distinguish "empty" from "not built yet" should
-- check for nil themselves before calling this.
function MemoryEstimator.EstimateTableSizeBytes(t)
    if type(t) ~= "table" then
        return 0
    end
    return EstimateTableBytes(t, {})
end

function MemoryEstimator.EstimateTableSizeKB(t)
    return MemoryEstimator.EstimateTableSizeBytes(t) / 1024
end

-- Same as EstimateTableSizeBytes, but for a GROUP of tables measured as one
-- logical subsystem line (e.g. a cache split across two or three separate
-- root tables). Shares ONE `seen` set across every root in the group, so a
-- sub-table or string referenced from more than one root in the same group
-- is charged once, not once per root -- this is what keeps a multi-root
-- line (badge caches, identity caches) from double-counting shared
-- structure the way two SEPARATE calls would (see error source #2).
-- Non-table entries in `tables` are skipped rather than erroring.
function MemoryEstimator.EstimateTablesSizeBytes(tables)
    local seen = {}
    local bytes = 0
    for _, t in pairs(tables) do
        if type(t) == "table" then
            bytes = bytes + EstimateTableBytes(t, seen)
        end
    end
    return bytes
end

function MemoryEstimator.EstimateTablesSizeKB(tables)
    return MemoryEstimator.EstimateTablesSizeBytes(tables) / 1024
end

-------------------------------------------------------------------------------
-- HS-282 sub-item I: full-reachability ownership sweep (/hs debug memfloor,
-- Core/DevMemoryDiagnostics.lua). Itemizes membudget's "unaccounted" remainder
-- by walking the addon's ENTIRE reachable table graph from a fixed, ordered
-- list of owned/shared roots, instead of the curated per-subsystem list above.
--
-- This is a SIBLING walker, not a mode of EstimateTableBytes: that function is
-- pinned byte-identical by tests/hs282_memory_estimator.lua's calibration (see
-- its header) and must stay comparable across existing membudget captures.
-- SweepTableBytes below duplicates the same #t array/hash classification and
-- reuses the same five constants so the byte model itself cannot drift
-- between the two call sites; everything sweep-only (multi-root sharing via
-- one `ctx.seen`, per-owner table/function/widget counts, the widget
-- boundary, the node cap) lives only here.
--
-- Accuracy: a relative-magnitude ranking instrument, not an accurate byte
-- count -- see the technique key DebugMemFloorReport prints for the full
-- disclaim (a module table's function values are charged an uncalibrated
-- placeholder, error source #5 above).
-------------------------------------------------------------------------------

local rawget = rawget

-- 1,000,000 distinct tables = 76 MB at HEADER_BYTES alone. Reaching this means
-- the ownership boundary (the foreign-root pre-seed) leaked into Blizzard's or
-- another addon's table graph -- a bug, not a result worth reporting.
local SWEEP_NODE_CAP = 1000000

-- A WoW widget carries its C-side object at table key 0 (rawget so a mixin's
-- __index chain can never intercept this check); GetObjectType is the
-- fallback for the rare widget shape that doesn't. The fallback is a plain
-- index, so it is taken ONLY when the table's __index cannot execute code:
-- a function-valued __index anywhere in the walked graph (CallbackHandler's
-- events registry materializes a new entry on ANY missing-key read; Foundry's
-- db controller refuses deny-listed keys) would otherwise mutate live state
-- or raise mid-sweep. A __metatable field shadows getmetatable (LDB's domt
-- returns the string "access denied"), so any metatable we cannot inspect is
-- treated the same as a function __index: don't probe. Widget mixin chains
-- use plain table __index, so real widgets still reach the fallback; the only
-- shape given up is a widget that BOTH lacks key 0 AND locks its metatable.
-- No method is ever called on the table.
local function IsWidget(t)
    if rawget(t, 0) ~= nil then
        return true
    end
    local mt = getmetatable(t)
    if mt ~= nil and (type(mt) ~= "table" or type(rawget(mt, "__index")) == "function") then
        return false
    end
    return t.GetObjectType ~= nil
end

local SweepTableBytes
local SweepHeapRefBytes

-- Same contract as EstimateHeapRefBytes, plus: functions are tallied (deduped
-- via ctx.fnSeen) as a COUNT, never a size -- a Lua function object and its
-- upvalue array cannot be sized from Lua, so no byte figure is derived from
-- one. The byte charge for a function reference stays OTHER_VALUE_BYTES,
-- undeduped, matching EstimateHeapRefBytes's existing (uncalibrated, error
-- source #5) treatment -- this walker does not change the byte model.
SweepHeapRefBytes = function(v, ctx)
    local vt = type(v)
    if vt == "table" then
        return SweepTableBytes(v, ctx)
    elseif vt == "string" then
        if ctx.seen[v] then
            return 0
        end
        ctx.seen[v] = true
        return STRING_HEADER_BYTES + #v
    elseif vt == "number" or vt == "boolean" or vt == "nil" then
        return 0
    elseif vt == "function" then
        if not ctx.fnSeen[v] then
            ctx.fnSeen[v] = true
            ctx.functions = ctx.functions + 1
        end
        return OTHER_VALUE_BYTES
    else
        -- userdata/thread: same flat placeholder as EstimateHeapRefBytes.
        return OTHER_VALUE_BYTES
    end
end

-- Full-reachability walk over ONE shared `ctx.seen` (see NewSweepContext):
-- first-owner-wins attribution falls straight out of that shared set -- once
-- a root has claimed a table, every later root's walk sees it in `seen` and
-- contributes 0 for it, so each owner's byte count is only what's new at that
-- point in the fixed root order the caller walks in (design §2).
SweepTableBytes = function(t, ctx)
    if ctx.aborted then
        return 0
    end
    if ctx.seen[t] then
        return 0
    end
    ctx.seen[t] = true

    ctx.nodes = ctx.nodes + 1
    if ctx.nodes > ctx.nodeCap then
        ctx.aborted = true
        return 0
    end
    ctx.tables = ctx.tables + 1

    if IsWidget(t) then
        ctx.widgets = ctx.widgets + 1
        if not ctx.walkWidgets then
            -- Default: counted, not walked. A widget's field graph is where a
            -- table walker silently attributes Blizzard's bytes to us (hooked
            -- bag/merchant buttons, template regions, canvas children) --
            -- their Lua-side storage lands in the remainder and is named
            -- there instead (design §1d).
            return HEADER_BYTES
        end
    end

    local bytes = HEADER_BYTES
    local n = #t

    for k, v in pairs(t) do
        if type(k) == "number" and k >= 1 and k <= n and k == math_floor(k) then
            bytes = bytes + ARRAY_SLOT_BYTES
            bytes = bytes + SweepHeapRefBytes(v, ctx)
        else
            bytes = bytes + HASH_ENTRY_BYTES
            bytes = bytes + SweepHeapRefBytes(k, ctx)
            bytes = bytes + SweepHeapRefBytes(v, ctx)
        end
        if ctx.aborted then
            break
        end
    end

    return bytes
end

-- Fresh sweep state for one full /hs debug memfloor run. opts.walkWidgets
-- (default false) selects 'deep' mode (design §1d); opts.nodeCap (default
-- SWEEP_NODE_CAP) is overridable for tests only.
function MemoryEstimator.NewSweepContext(opts)
    opts = opts or {}
    return {
        seen = {},
        fnSeen = {},
        nodes = 0,
        nodeCap = opts.nodeCap or SWEEP_NODE_CAP,
        walkWidgets = opts.walkWidgets or false,
        aborted = false,
        tables = 0,
        functions = 0,
        widgets = 0,
    }
end

-- Boundary rule (design §1c): pre-seed `ctx.seen` with every table that is a
-- direct value of a global, except ours (any string global key starting with
-- "Homestead" -- the same prefix .luacheckrc's globals allowlist confirms
-- every Homestead-created global carries). A table in `seen` contributes 0
-- and is never descended into, so this one _G pass blocks _G itself, every
-- Blizzard namespace/frame, every other addon's namespace, SlashCmdList, and
-- the Lua standard libraries with no hand-maintained blocklist to rot.
--
-- foundryEmbedded is supplied by the caller (DevMemoryDiagnostics.lua, which
-- already needs the C_AddOns.IsAddOnLoaded check for its own Foundry-1.0
-- provenance line) rather than decided here -- this file has no reason to
-- know about addon-loaded detection. LibStub is always unseeded: its
-- registry (LibDataBroker-1.1, CallbackHandler-1.0, WagoAnalytics) is a
-- shared root regardless of which copy of Foundry is serving.
function MemoryEstimator.SeedForeignRoots(ctx, foundryEmbedded)
    for k, v in pairs(_G) do
        if type(v) == "table" and not (type(k) == "string" and k:sub(1, 9) == "Homestead") then
            ctx.seen[v] = true
        end
    end
    -- t[nil] = nil RAISES in Lua 5.1 ("table index is nil"), so a missing
    -- library must be skipped here, not just handled by the caller's
    -- "skipped (unavailable)" branch downstream.
    if _G.LibStub ~= nil then
        ctx.seen[_G.LibStub] = nil
    end
    if foundryEmbedded and _G.Foundry_1_0 ~= nil then
        ctx.seen[_G.Foundry_1_0] = nil
    end
end

-- Walks one root, returning the bytes/tables/functions/widgets NEW at this
-- point in the sweep (deltas for this root only -- see SweepTableBytes for
-- the first-owner-wins mechanics that make this meaningful). Non-table root
-- returns zeros, the same nil-tolerant contract as EstimateTableSizeBytes, so
-- callers can pass a possibly-nil root (e.g. sv:HomesteadDB before first
-- save) without a separate type check.
function MemoryEstimator.SweepRoot(ctx, root)
    if type(root) ~= "table" then
        return 0, 0, 0, 0
    end
    local tablesBefore, functionsBefore, widgetsBefore = ctx.tables, ctx.functions, ctx.widgets
    local bytes = SweepTableBytes(root, ctx)
    return bytes, ctx.tables - tablesBefore, ctx.functions - functionsBefore, ctx.widgets - widgetsBefore
end
