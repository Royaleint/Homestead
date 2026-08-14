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

    Known error sources (a budget estimate for prioritization, not an exact
    memory accounting -- do not quote these numbers as authoritative):
      1. ENTRY_OVERHEAD_BYTES approximates Lua 5.1's table hash-node layout
         (TValue key + TValue value + next pointer) on a 64-bit client. Not
         derived from an allocator trace -- real overhead varies with a
         table's array-vs-hash part split and its current load
         factor/rehash state, neither of which pairs() exposes.
      2. Strings are deduplicated (Lua interns them) WITHIN one top-level
         EstimateTableSizeBytes call via the `seen` set, so a literal
         referenced many times inside one subsystem is charged once, not
         once per reference. Dedup does NOT cross separate calls -- each
         subsystem is measured with its own fresh `seen` set, so a string
         shared BETWEEN two subsystems (e.g. a zone name appearing in both
         VendorIdentity and DecorMapping) is charged to both. This overstates
         the sum of all subsystem lines relative to the addon's true total
         heap footprint; it does not affect the accuracy of any single
         subsystem line taken alone.
      3. Cycles and repeated table references WITHIN one call are correctly
         deduplicated via the same `seen` set -- a table reached a second
         time in the same walk contributes 0 bytes on that second visit.
      4. Numbers/booleans are charged a flat per-slot estimate, not Lua's
         actual tagged-value representation (architecture-dependent, and not
         introspectable from pure Lua) -- this undercounts numeric-heavy
         tables like VendorOffers' price/currency fields relative to their
         real cost.
      5. Functions/userdata/threads are rare in these data tables (they show
         up only in module tables that mix methods with data, e.g.
         VendorIdentity) and are charged a flat placeholder -- this walker
         estimates data, not code.
]]

local _, HA = ...

local MemoryEstimator = {}
HA.MemoryEstimator = MemoryEstimator

local STRING_HEADER_BYTES = 24
local ENTRY_OVERHEAD_BYTES = 40
local NUMBER_BYTES = 8
local BOOLEAN_BYTES = 4
local OTHER_VALUE_BYTES = 8

local EstimateValueBytes

local function EstimateTableBytes(t, seen)
    if seen[t] then
        return 0
    end
    seen[t] = true

    local bytes = 0
    for k, v in pairs(t) do
        bytes = bytes + ENTRY_OVERHEAD_BYTES
        bytes = bytes + EstimateValueBytes(k, seen)
        bytes = bytes + EstimateValueBytes(v, seen)
    end
    return bytes
end

EstimateValueBytes = function(v, seen)
    local vt = type(v)
    if vt == "table" then
        return EstimateTableBytes(v, seen)
    elseif vt == "string" then
        if seen[v] then
            return 0
        end
        seen[v] = true
        return STRING_HEADER_BYTES + #v
    elseif vt == "number" then
        return NUMBER_BYTES
    elseif vt == "boolean" then
        return BOOLEAN_BYTES
    elseif vt == "nil" then
        return 0
    else
        return OTHER_VALUE_BYTES
    end
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
