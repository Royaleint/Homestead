-- luacheck: globals assert loadfile print collectgarbage string arg io os

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-282: MemoryEstimator walker smoke test.
--
-- MemoryEstimator is the fallback measurement technique for every /hs debug
-- membudget subsystem that has no safe wipe-delta rebuild path (see
-- Core/MemoryEstimator.lua's header and core.lua's DebugMemBudgetReport for
-- why). This pins its load-bearing properties: sane nonzero output for a
-- known literal table, cycle-safety (a self-referencing table must not
-- infinite-loop or double-count its own reference), shared-reference
-- awareness both within one call and across a multi-root group, and
-- nil-in/0-out so callers can pass a possibly-unbuilt index without a
-- separate type check.
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

-- Empty table: still charged the per-table header (Lua allocates a Table
-- struct + GC header for every table regardless of content) -- NOT 0.
local emptyBytes = ME.EstimateTableSizeBytes({})
assert(emptyBytes > 0, "expected a nonzero per-table header charge even for an empty table")

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
assert(literalBytes > emptyBytes, "expected a populated table to exceed the empty-table header charge")
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

-- Shared-reference awareness WITHIN one call: a table nested twice under
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

-- Array part vs hash part: a contiguous 1..n sequence must estimate cheaper
-- per entry than the same entry count keyed sparsely (hash part), since the
-- array part has no per-entry key storage.
local sequence = {}
for i = 1, 20 do
    sequence[i] = i
end
local sparse = {}
for i = 1, 20 do
    sparse[i * 1000] = i
end
local sequenceBytes = ME.EstimateTableSizeBytes(sequence)
local sparseBytes = ME.EstimateTableSizeBytes(sparse)
assert(sequenceBytes < sparseBytes,
    "a contiguous 1..n sequence must estimate cheaper than the same entry count keyed sparsely")

-- KB helper is a straight bytes/1024 conversion.
assert(ME.EstimateTableSizeKB(literal) == literalBytes / 1024)

-------------------------------------------------------------------------------
-- Multi-root grouping (EstimateTablesSizeBytes/KB): a subsystem reported as
-- one line but backed by more than one root table (e.g. badge caches,
-- CatalogStore's identity caches in core.lua) must share ONE `seen` set
-- across every root, so structure shared between roots isn't double-counted
-- the way two separate EstimateTableSizeBytes calls would.
-------------------------------------------------------------------------------

local sharedAcrossRoots = { x = "shared-string-content" }
local rootA = { own = "a-only", ref = sharedAcrossRoots }
local rootB = { own = "b-only", ref = sharedAcrossRoots }

local groupedBytes = ME.EstimateTablesSizeBytes({ rootA, rootB })
local separateBytes = ME.EstimateTableSizeBytes(rootA) + ME.EstimateTableSizeBytes(rootB)
assert(groupedBytes < separateBytes,
    "grouping two roots that share structure must cost less than measuring them separately")

-- Non-table entries in the group are skipped, not errors.
local groupedWithNil = ME.EstimateTablesSizeBytes({ rootA, nil, "not a table", rootB })
assert(groupedWithNil == groupedBytes, "non-table group entries must be skipped, not counted or errored")

assert(ME.EstimateTablesSizeKB({ rootA, rootB }) == groupedBytes / 1024)

print("hs282_memory_estimator: ok")

-------------------------------------------------------------------------------
-- HS-282 Argus Gate 1 finding #1: calibration check.
--
-- Each target file is measured by SPAWNING tests/hs282_calibrate_one.lua as
-- its own fresh lua5.1 subprocess (via io.popen), not by loading multiple
-- files in this process. That worker file's header explains why: loading
-- several Data/ files sequentially in one process lets Lua's global
-- string-intern table's order-dependent growth pollute later files'
-- measured deltas -- confirmed empirically while building this test
-- (QuestSources.lua measured ~24KB loaded 10th after nine larger files in
-- one process, vs ~9-11KB isolated, the latter matching both this
-- estimator and Argus's own reference figure). A fresh process per file has
-- no prior growth to absorb.
--
-- Both "actual" (live collectgarbage("count") delta) and "est" are computed
-- fresh every run inside the worker -- nothing here is a hardcoded prior
-- measurement, so this test can't rot as the Data/ files grow.
--
-- Requires being run via the lua CLI (uses arg[-1]/arg[0] to locate the
-- interpreter and the worker script without a hardcoded path) -- if `arg`
-- isn't available in whatever invoked this file, the calibration section is
-- skipped with a note rather than failing the whole test, since the
-- structural tests above already ran and passed.
-------------------------------------------------------------------------------

if not (arg and arg[-1] and arg[0]) then
    print("hs282_memory_estimator_calibration: skipped (arg[-1]/arg[0] unavailable -- not run via the lua CLI)")
    os.exit(0)
end

-- Windows-native backslash paths from arg[-1]/arg[0] don't survive being
-- embedded in an io.popen command string on this platform (confirmed
-- empirically: cmd.exe silently drops backslash-letter sequences it
-- doesn't recognize as an escape). lua5.1.exe and cmd.exe both accept
-- forward slashes in a path, so normalize before building any command.
local function toForwardSlash(path)
    return (path:gsub("\\", "/"))
end

local interpreter = toForwardSlash(arg[-1])
local workerScript = toForwardSlash(arg[0]):gsub("hs282_memory_estimator%.lua$", "hs282_calibrate_one.lua")

local function measureIsolated(fileBaseName)
    -- The outer quote pair is required on Windows: cmd.exe strips a single
    -- leading-quoted executable path from the command line entirely (a
    -- long-documented cmd.exe quirk), so a command starting with "exe" "arg"
    -- fails with "The system cannot find the path specified" even though
    -- the same command runs fine typed directly at a shell. Wrapping the
    -- whole command in one more quote pair is the standard workaround.
    local cmd = string.format('""%s" "%s" "%s" %s"', interpreter, workerScript, root, fileBaseName)
    local proc = assert(io.popen(cmd, "r"))
    local resultLine = proc:read("*l")
    local ok, _, exitType, exitCode = proc:close()
    assert(resultLine, "calibration worker produced no output for " .. fileBaseName
        .. " (exit " .. tostring(exitType) .. " " .. tostring(exitCode) .. ")")
    assert(ok ~= false, "calibration worker failed for " .. fileBaseName)

    local actualKB, estKB = resultLine:match("^(%S+)%s+(%S+)$")
    assert(actualKB and estKB, "could not parse calibration worker output for "
        .. fileBaseName .. ": " .. tostring(resultLine))
    return tonumber(actualKB), tonumber(estKB)
end

local function checkBand(fileBaseName, minRatio, maxRatio)
    local actualKB, estKB = measureIsolated(fileBaseName)
    local ratio = estKB / actualKB
    print(string.format("  calibration %-22s actual=%9.1fKB est=%9.1fKB ratio=%.3f (band [%.2f, %.2f])",
        fileBaseName, actualKB, estKB, ratio, minRatio, maxRatio))
    assert(ratio >= minRatio and ratio <= maxRatio,
        string.format("%s estimator ratio %.3f outside [%.2f, %.2f] (actual=%.1fKB est=%.1fKB)",
            fileBaseName, ratio, minRatio, maxRatio, actualKB, estKB))
    return ratio
end

-- Strictly gated: these seven land inside [0.85, 1.15] reliably (verified
-- during this ticket's calibration work) and represent the normal case the
-- 0.85-1.15 tolerance band targets.
local STRICT_MIN, STRICT_MAX = 0.85, 1.15
for _, fileBaseName in ipairs({
    "VendorIdentity", "ProfessionSources", "PrerequisiteSources",
    "DecorMapping", "EndeavorsData", "DropSources", "QuestSources",
}) do
    checkBand(fileBaseName, STRICT_MIN, STRICT_MAX)
end

-- Documented exceptions, checked with a wider sanity band instead of the
-- strict one -- both are still asserted (a gross regression still fails the
-- test), just not held to the same tolerance, for reasons specific to each
-- file rather than a general estimator weakness:
--
-- VendorOffers and ShopSources sit at opposite ends of this corpus's size
-- range (~1.06MB vs ~11KB) from the seven files above. MemoryEstimator's
-- three constants are a single flat linear fit (see its header); a wide
-- grid search during this ticket's calibration work found NO single
-- (header, array, hash) triple that lands all nine of these files inside
-- [0.85, 1.15] simultaneously -- the best joint fit gets seven, and pushes
-- these two to roughly 1.18 and 1.21 respectively, both over-estimates
-- (the safe direction: it doesn't cause this pair to be UNDER-ranked
-- against another subsystem).
checkBand("VendorOffers", 0.85, 1.30)
checkBand("ShopSources", 0.85, 1.30)

-- AchievementSources.lua builds a reverse index (achievementToItems) as a
-- plain local captured only via closure upvalue in the module's API
-- functions -- never assigned as a field on HA.AchievementSources or
-- HA.AchievementSourcesModule -- so it is structurally invisible to a
-- table walker (MemoryEstimator error source #6). The file is
-- pipeline-generated ("DO NOT EDIT" in its own header), so this can't be
-- fixed by exposing the index as a field. This is a genuine, understood
-- gap, not tuned away with looser constants that would then misrepresent
-- every other file -- the wide band below still catches a total collapse
-- (e.g. the estimator returning ~0) without asserting a tolerance the
-- underlying data structure doesn't support.
checkBand("AchievementSources", 0.5, 1.0)

print("hs282_memory_estimator_calibration: ok")
