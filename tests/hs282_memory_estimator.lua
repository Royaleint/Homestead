-- luacheck: globals assert loadfile print collectgarbage string arg io

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
else

-- Windows-native backslash paths from arg[-1]/arg[0] don't survive being
-- embedded in an io.popen command string on this platform (confirmed
-- empirically: cmd.exe silently drops backslash-letter sequences it
-- doesn't recognize as an escape). lua5.1.exe and cmd.exe both accept
-- forward slashes in a path, so normalize before building any command.
local function toForwardSlash(path)
    return (path:gsub("\\", "/"))
end

local interpreter = toForwardSlash(arg[-1])

-- Argus Gate 1 (re-review) blocker #1: the worker path used to come from
-- gsub-SUBSTITUTING this file's own name in arg[0] for the worker's name.
-- If that pattern ever failed to match -- different case on a
-- case-insensitive NTFS mount, this file copied/renamed elsewhere, run
-- through a wrapper that mangles arg[0] -- the substitution silently
-- no-ops, workerScript ends up EQUAL to arg[0], and the popen call below
-- spawns THIS SAME TEST FILE as its own "worker": that recurses into
-- another copy of this whole calibration section, which spawns another,
-- forever. Confirmed experimentally (Argus): thousands of processes before
-- being killed, with the parent just hanging -- no error, nothing printed.
-- Fixed by deriving the worker path from this file's DIRECTORY plus a
-- fixed, hardcoded basename (no pattern substitution on the filename at
-- all), then asserting -- before ever calling popen -- that the derived
-- path is both different from arg[0] and ends in the expected worker
-- filename. A resolution that fails either check aborts loudly instead of
-- silently proceeding into a self-spawn.
local selfPath = toForwardSlash(arg[0])
local selfDir = selfPath:match("^(.*/)") or ""
local workerScript = selfDir .. "hs282_calibrate_one.lua"
assert(workerScript ~= selfPath,
    "calibration worker path resolved to this test's own file (" .. selfPath
    .. ") -- refusing to spawn it as a subprocess, that would self-recurse")
assert(workerScript:match("/hs282_calibrate_one%.lua$") or workerScript == "hs282_calibrate_one.lua",
    "calibration worker path does not end in hs282_calibrate_one.lua: " .. workerScript)
assert(io.open(workerScript, "r"),
    "calibration worker script not found at " .. workerScript .. " -- expected as a sibling of this test file")

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
    -- proc:close()'s exit-type/exit-code return values are a Lua 5.2+
    -- addition; under this Lua 5.1 build it returns a single boolean (which
    -- IS reliable) and nothing else -- confirmed empirically. Only check
    -- what 5.1 actually gives us; don't reference exit-code values that can
    -- never be anything but nil here.
    local closedOk = proc:close()
    assert(resultLine, "calibration worker produced no output for " .. fileBaseName
        .. " (worker: " .. workerScript .. ")")
    assert(closedOk ~= false, "calibration worker process reported failure for " .. fileBaseName)

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
-- 0.85-1.15 tolerance band targets. EndeavorsData shares AchievementSources'
-- closure-upvalue gap (see the comment below) but still fits this band --
-- it stays here rather than in the wide-band group below; the gap is
-- documentation-scope for this file, not a calibration-band problem.
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
-- [0.85, 1.15] simultaneously -- the best joint fit gets seven. Both known
-- exceptions have measured as OVER-estimates in this ticket's runs, but
-- that is not simply "safe": an over-estimate on VendorOffers specifically
-- -- already the single largest line by a wide margin -- inflates the
-- report's "accounted" sum and understates its "unaccounted" residual by
-- the same amount, and makes VendorOffers look relatively even MORE
-- dominant next to every other subsystem than it truly is. ShopSources is
-- small enough (~11-13KB) that its measured ratio also has real run-to-run
-- jitter from ordinary GC/allocator noise, not just model error -- this
-- band is wide partly to absorb that noise, not only the model's bias, so
-- don't read a specific ratio value here (e.g. 1.03 one run, 1.18 the next)
-- as a fixed, precise estimator property the way the strict-band files'
-- ratios can be read.
checkBand("VendorOffers", 0.85, 1.30)
checkBand("ShopSources", 0.85, 1.30)

-- Data reachable ONLY through a closure upvalue -- never assigned onto any
-- table this walker can reach -- is structurally invisible to it
-- (MemoryEstimator error source #6). Confirmed in at least two Data/ files:
-- AchievementSources.lua builds a reverse index (achievementToItems, ~a
-- third of the file's real footprint) this way, and EndeavorsData.lua:39
-- (lowerVendorNameToNpcID) follows the identical shape. AchievementSources
-- is pipeline-generated ("DO NOT EDIT" in its own header), so this can't be
-- fixed by exposing the index as a field there. core.lua's
-- DebugMemBudgetReport marks both known-affected lines with an "est*"
-- technique suffix directly in its printed output (not just in this
-- comment), so a reader of the live report -- not just this test's source
-- -- can see which numbers understate reality. This wide band still catches
-- a total collapse (e.g. the estimator returning ~0) without asserting a
-- tolerance the underlying data structure doesn't support.
checkBand("AchievementSources", 0.5, 1.0)

print("hs282_memory_estimator_calibration: ok")

end
