-- luacheck: globals assert loadfile print

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-282: MemoryEstimator walker smoke test.
--
-- MemoryEstimator is the fallback measurement technique for every /hs debug
-- membudget subsystem that has no safe wipe-delta rebuild path (see
-- Core/MemoryEstimator.lua's header and core.lua's DebugMemBudgetReport for
-- why). This pins its three load-bearing properties: sane nonzero output for
-- a known literal table, cycle-safety (a self-referencing table must not
-- infinite-loop or double-count its own reference), and nil-in/0-out so
-- callers can pass a possibly-unbuilt index without a separate type check.
-------------------------------------------------------------------------------

local HA = {}
assert(loadfile(root .. "/Core/MemoryEstimator.lua"))("Homestead", HA)

local ME = HA.MemoryEstimator
assert(ME, "MemoryEstimator did not register itself on HA")

-- Non-table input returns 0, not an error -- callers pass a possibly-nil
-- lazily-built index (e.g. SearchProvider's searchIndex before first build).
assert(ME.EstimateTableSizeBytes(nil) == 0)
assert(ME.EstimateTableSizeBytes("not a table") == 0)
assert(ME.EstimateTableSizeBytes(42) == 0)

-- Empty table: entry-overhead only from the table itself, i.e. 0 (no
-- entries to charge overhead for).
assert(ME.EstimateTableSizeBytes({}) == 0)

-- Known literal: 3 entries, each a number key + string value. Sane nonzero
-- output -- not pinning the exact byte count (that's the point of the
-- documented estimator error sources), just that it scales with content
-- and stays in a plausible ballpark for ~3 short strings.
local literal = {
    [1] = "Stormwind",
    [2] = "Ironforge",
    [3] = "Darnassus",
}
local literalBytes = ME.EstimateTableSizeBytes(literal)
assert(literalBytes > 0, "expected nonzero size for a populated table")
assert(literalBytes < 1024, "expected a small literal to stay well under 1KB")

-- Growing the table must grow the estimate monotonically.
local bigger = {}
for i = 1, 50 do
    bigger[i] = "item-" .. i
end
local biggerBytes = ME.EstimateTableSizeBytes(bigger)
assert(biggerBytes > literalBytes, "a 50-entry table must estimate larger than a 3-entry table")

-- Cycle safety: a table referencing itself must terminate and must not
-- double-count the self-reference (the second visit contributes 0).
local cyclic = { name = "self-referencing" }
cyclic.self = cyclic
local cyclicBytes = ME.EstimateTableSizeBytes(cyclic)
assert(cyclicBytes > 0, "expected the cyclic table's own entries to still be counted")

-- Shared-reference awareness within one call: a table nested twice under
-- two different keys is charged once, not twice.
local shared = { a = "x", b = "y" }
local sharedParent = { first = shared, second = shared }
local sharedBytes = ME.EstimateTableSizeBytes(sharedParent)
local soloBytes = ME.EstimateTableSizeBytes({ only = shared })
-- sharedParent has 2 entries pointing at the SAME table (charged once) plus
-- its own 2-entry overhead; soloBytes has 1 entry pointing at the same
-- table plus its own 1-entry overhead. The shared table's own cost must not
-- be doubled just because two keys reference it.
assert(sharedBytes < soloBytes * 2, "a table referenced twice in one call must not be charged twice")

-- KB helper is a straight bytes/1024 conversion.
assert(ME.EstimateTableSizeKB(literal) == literalBytes / 1024)

print("hs282_memory_estimator: ok")
