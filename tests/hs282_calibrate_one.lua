-- luacheck: globals assert loadfile print collectgarbage string

-------------------------------------------------------------------------------
-- HS-282: isolated single-Data-file memory calibration worker, spawned as
-- its own fresh lua5.1 process by tests/hs282_memory_estimator.lua's
-- calibration section (Argus Gate 1 finding #1) -- NOT meant to be run
-- directly as a top-level test.
--
-- Why a fresh process per file: Lua's global string-intern table grows (and
-- occasionally rehashes) as more unique strings accumulate over a process's
-- lifetime. Measuring several Data/ files sequentially in ONE process
-- attributes that shared, order-dependent growth cost to whichever file
-- happens to be loaded when a rehash threshold is crossed -- confirmed
-- empirically during this ticket's calibration work: QuestSources.lua
-- measured a ~24KB delta when loaded 10th after nine much larger files in
-- one process, but ~9-11KB when loaded alone in a fresh process (matching
-- both this walker's estimate and Argus's own reference figure). A fresh
-- process per file has no prior string-table growth to absorb, so its delta
-- reflects only that file's own contribution.
--
-- Usage: lua5.1 tests/hs282_calibrate_one.lua <repoRoot> <DataFileBaseName>
-- Prints one line "<actualKB> <estKB>" and exits 0 on success, or raises an
-- uncaught assertion (nonzero exit) if the file/table couldn't be measured.
-- DataFileBaseName must match both the Data/<name>.lua filename and the
-- HA.<name> table it populates (true for every file this ticket's
-- calibration targets -- see the orchestrator for the exact list).
-------------------------------------------------------------------------------

local root, fileBaseName = ...
assert(root and fileBaseName, "usage: hs282_calibrate_one.lua <repoRoot> <DataFileBaseName>")

local HA = {}
assert(loadfile(root .. "/Core/MemoryEstimator.lua"))("Homestead", HA)
local ME = HA.MemoryEstimator

collectgarbage("collect")
collectgarbage("collect")
local beforeKB = collectgarbage("count")

assert(loadfile(root .. "/Data/" .. fileBaseName .. ".lua"))("Homestead", HA)

collectgarbage("collect")
collectgarbage("collect")
local afterKB = collectgarbage("count")
local actualKB = afterKB - beforeKB

local tbl = HA[fileBaseName]
assert(tbl, fileBaseName .. " did not populate HA." .. fileBaseName)

local estKB = ME.EstimateTableSizeKB(tbl)

print(string.format("%.4f %.4f", actualKB, estKB))
