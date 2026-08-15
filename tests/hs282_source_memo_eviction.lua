-- luacheck: globals assert loadfile loadstring print io C_Timer C_Map CreateFrame InCombatLockdown GetTimePreciseSec wipe

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-282: insert-site eviction caps for the two prewarm-filled memo caches
-- that otherwise grow unbounded across a long session -- SourceManager's
-- allSourcesCache (Cache A, 512-entry cap, unit = distinct itemID) and
-- VendorData's VendorItemsMemo (Cache H, 512-entry cap, unit = vendor
-- npcID -- Argus Gate 1: raised from an initial 64, which sat BELOW the
-- ~225-vendor static working set and produced permanent zero cross-walk
-- reuse) -- plus BadgeCalculation's end-of-prewarm-pass flush of both.
-- Wholesale wipe-on-overflow enforced at the sole/two insert sites (never on
-- read), reusing each cache's existing narrow invalidator so the counter
-- reset comes for free through the same path InvalidateAllSourceCaches / a
-- future broad VendorData wipe would compose.
--
-- Part 1: Cache A (allSourcesCache) eviction cap.
-- Part 2: Cache H (VendorItemsMemo) eviction cap, both insert sites.
-- Part 3: InvalidateSourcesMemo counter-reset coherence.
-- Part 4: BadgeCalculation end-of-pass flush -- clean completion, the
--   pending-rerun branch, and the pcall-abort branch.
-- Part 5: corpus-level parity -- against the REAL static vendor DB (loaded
--   via Data/VendorOffers.lua, same as every other module load in this
--   suite), with VENDOR_ITEMS_MEMO_MAX_ENTRIES overridden low in this test's
--   own loaded copy of VendorData.lua (the SHIPPED constant stays 512) to
--   force repeated eviction cycles across the whole corpus in one pass.
--   Proves eviction is memory-only and behavior-neutral: every vendor's
--   GetVendorItems result is identical in content whether served from a
--   warm memo entry or rebuilt after an eviction wipe.
-------------------------------------------------------------------------------

CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript() end
    return frame
end

-- WoW API global (table.wipe equivalent); Part 4b's InvalidateAllCaches call
-- needs it.
wipe = function(t)
    for k in pairs(t) do t[k] = nil end
    return t
end

-------------------------------------------------------------------------------
-- Part 1: Cache A -- allSourcesCache eviction cap (SourceManager.lua)
-------------------------------------------------------------------------------

do
    local HA = {
        Constants = { Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
        Addon = {
            db = { profile = {}, global = { parsedSources = {} } },
            RegisterModule = function() end,
            Debug = function() end,
        },
        Events = {
            RegisterCallback = function() end,
            Fire = function() end,
        },
    }

    assert(loadfile(root .. "/Data/SourceManager.lua"))("Homestead", HA)
    HA.SourceManager:Initialize()

    local BASE_ITEM_ID = 700000
    local CAP = 512

    assert(HA.SourceManager:GetSourcesMemoEntryCount() == 0, "entry count must start at 0")

    -- Pre-wipe identity: two queries for the same itemID, well under the
    -- cap, must return the SAME table (memo contract intact under the cap).
    local preA = HA.SourceManager:GetAllSources(BASE_ITEM_ID + 5)
    local preB = HA.SourceManager:GetAllSources(BASE_ITEM_ID + 5)
    assert(preA == preB, "a cache hit under the cap must return the identical table")

    -- Fill to the cap, tracking that population never exceeds it at any point.
    local maxSeen = 0
    for i = 1, CAP do
        HA.SourceManager:GetAllSources(BASE_ITEM_ID + i)
        local count = HA.SourceManager:GetSourcesMemoEntryCount()
        if count > maxSeen then maxSeen = count end
        assert(count <= CAP, "population must never exceed the cap, got " .. count .. " at item " .. i)
    end
    assert(maxSeen == CAP, "population must reach the cap exactly, got max " .. maxSeen)

    -- The overflow item (CAP + 1) triggers the wholesale wipe, then lands as
    -- the sole resident entry -- resident immediately after the wipe.
    local overflowItemID = BASE_ITEM_ID + CAP + 1
    local overflowFirst = HA.SourceManager:GetAllSources(overflowItemID)
    assert(HA.SourceManager:GetSourcesMemoEntryCount() == 1,
        "the wipe-then-insert must leave exactly 1 entry resident (the overflow entry itself)")
    local overflowSecond = HA.SourceManager:GetAllSources(overflowItemID)
    assert(overflowFirst == overflowSecond,
        "the overflow-triggering entry must be memoized immediately after the wipe")

    -- Every pre-overflow entry (including the identity-check query above) is
    -- gone -- re-querying one produces a NEW table object, not a hit.
    local evicted = HA.SourceManager:GetAllSources(BASE_ITEM_ID + 5)
    assert(evicted ~= preA, "an entry present before the overflow wipe must have been evicted")

    print("hs282_source_memo_eviction: Part 1 (allSourcesCache eviction cap) ok")
end

-------------------------------------------------------------------------------
-- Part 2: Cache H -- VendorItemsMemo eviction cap (VendorData.lua), both
-- insert sites (the built-items path and the empty-offers path) counting
-- toward the same cap.
-------------------------------------------------------------------------------

do
    local CAP = 512
    local NPC_BASE = 800000

    local function buildOffers(itemCount)
        local generatedBase = {}
        for i = 1, itemCount do
            generatedBase[NPC_BASE + i] = { [500000 + i] = { price = 10 * i } }
        end
        return {
            GeneratedBase = generatedBase,
            ManualOverrides = {},
            StagedAdditions = nil,
            Tombstones = {},
        }
    end

    -- CAP - 1 vendors with a real offer (the built-items insert site), so
    -- the one no-offers vendor queried below (the empty-offers insert site)
    -- lands as the CAP-th entry -- proving both sites count toward one cap.
    local HA = { Addon = { RegisterModule = function() end } }
    HA.VendorOffers = buildOffers(CAP - 1)
    assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)

    local function memoCount()
        local n = 0
        for _ in pairs(HA.VendorData.VendorItemsMemo or {}) do n = n + 1 end
        return n
    end

    -- Not yet lazily initialized (no GetVendorItems call has happened, and
    -- this standalone harness never calls Initialize() -- matches the
    -- hs281_vendor_items_memo.lua standalone-load pattern).
    assert(memoCount() == 0, "VendorItemsMemo must start empty")

    for i = 1, CAP - 1 do
        HA.VendorData:GetVendorItems(NPC_BASE + i)
        assert(memoCount() <= CAP, "population must never exceed the cap")
    end
    assert(memoCount() == CAP - 1, "expected " .. (CAP - 1) .. " entries after the built-items fill")

    -- The CAP-th insert: a vendor with NO offers at all -- the empty-offers
    -- insert site (GetOffers returns nil).
    local NPC_EMPTY = NPC_BASE + 999
    local emptyFirst = HA.VendorData:GetVendorItems(NPC_EMPTY)
    assert(#emptyFirst == 0, "a no-offers vendor must return an empty item list")
    assert(memoCount() == CAP, "the empty-offers insert must count toward the cap, reaching it exactly")

    -- Overflow: one more vendor triggers the wholesale wipe.
    local NPC_OVERFLOW = NPC_BASE + 1000
    HA.VendorOffers.GeneratedBase[NPC_OVERFLOW] = { [600001] = { price = 77 } }
    local overflowFirst = HA.VendorData:GetVendorItems(NPC_OVERFLOW)
    assert(memoCount() == 1, "overflow must wipe the memo down to just the new entry")
    assert(type(overflowFirst[1]) == "table" and overflowFirst[1][1] == 600001,
        "the overflow vendor's items must be correct after the wipe")
    local overflowSecond = HA.VendorData:GetVendorItems(NPC_OVERFLOW)
    assert(overflowFirst == overflowSecond,
        "the overflow vendor's items must be memoized on immediate re-query")

    print("hs282_source_memo_eviction: Part 2 (VendorItemsMemo eviction cap, both insert sites) ok")
end

-------------------------------------------------------------------------------
-- Part 3: InvalidateSourcesMemo counter-reset coherence -- fill to cap-1,
-- invalidate, fill to cap-1 again, and confirm no overflow-triggered wipe
-- fired (proving the counter, not just the cache table, was reset).
-------------------------------------------------------------------------------

do
    local HA = {
        Constants = { Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
        Addon = {
            db = { profile = {}, global = { parsedSources = {} } },
            RegisterModule = function() end,
            Debug = function() end,
        },
        Events = { RegisterCallback = function() end, Fire = function() end },
    }
    assert(loadfile(root .. "/Data/SourceManager.lua"))("Homestead", HA)
    HA.SourceManager:Initialize()

    local CAP = 512
    local BASE_A = 710000
    local BASE_B = 720000

    for i = 1, CAP - 1 do
        HA.SourceManager:GetAllSources(BASE_A + i)
    end
    assert(HA.SourceManager:GetSourcesMemoEntryCount() == CAP - 1,
        "expected " .. (CAP - 1) .. " entries before the explicit invalidate")

    HA.SourceManager:InvalidateSourcesMemo()
    assert(HA.SourceManager:GetSourcesMemoEntryCount() == 0,
        "InvalidateSourcesMemo must reset the entry count to 0")

    for i = 1, CAP - 1 do
        HA.SourceManager:GetAllSources(BASE_B + i)
    end
    assert(HA.SourceManager:GetSourcesMemoEntryCount() == CAP - 1,
        "a second cap-1 fill after an explicit invalidate must land at cap-1 exactly, not trigger " ..
        "a spurious overflow wipe (proves the counter, not just the table, was reset)")

    print("hs282_source_memo_eviction: Part 3 (InvalidateSourcesMemo counter-reset coherence) ok")
end

-------------------------------------------------------------------------------
-- Part 4: BadgeCalculation end-of-prewarm-pass flush -- the branch that
-- clears warmupInProgress WITHOUT scheduling a rerun. Mirrors the
-- prewarm_fire_gate.lua / hs278_item_sliced_prewarm.lua mock-pass harness.
-------------------------------------------------------------------------------

local function NewStubHA()
    local h = {}
    h.stub = {
        Constants = { VerticalSiblings = {}, ContinentNames = {} },
        MapPinProvider = {
            continentToZones = {}, excludedContinents = {}, continentMergesInto = {},
            continentZoneBadgesOnParent = {}, continentZoneBadgeExclusionsOnParent = {},
            offWorldContinentPositions = {}, manualZoneCenters = {}, zoneNotes = {},
            GetContinentForZone = function() return nil end,
        },
        VendorFilter = {
            GetBestVendorCoordinates = function() return nil, nil end,
            -- Called unconditionally by GetContinentVendorCounts before and
            -- during its per-vendor loop (which then skips every vendor
            -- here anyway, since GetBestVendorCoordinates above returns no
            -- coordinates).
            ShouldShowOppositeFaction = function() return false end,
            ShouldHideVendor = function() return false end,
        },
        Events = {
            RegisterCallback = function() end,
            Fire = function() end,
        },
        PerformanceTrace = {
            Measure = function(_, _label, _tag, pcallFn, fn) return pcallFn(fn) end,
        },
        CatalogStore = {
            HasPersistedData = function() return true end,
        },
    }
    return h
end

local function NewVendorDataStub(itemsByNpc, vendors)
    return {
        GetAllVendors = function() return vendors end,
        GetMergedItemSet = function(_, vendor, includeOrderedIDs)
            local ids = itemsByNpc[vendor.npcID] or {}
            local set = {}
            for _, id in ipairs(ids) do set[id] = true end
            if includeOrderedIDs then return set, ids end
            return set
        end,
    }
end

-- Part 4a: a pass that completes cleanly (nothing pending) flushes both
-- memos exactly once.
do
    local h = NewStubHA()
    local sourcesFlushCount, vendorFlushCount = 0, 0
    h.stub.SourceManager = {
        GetItemPresentation = function()
            return {
                matchesSourceFilter = true, isOwnershipExcluded = false,
                isOwned = false, availabilityState = "purchasable",
            }
        end,
        InvalidateSourcesMemo = function() sourcesFlushCount = sourcesFlushCount + 1 end,
    }

    local vendor = { npcID = 96100 }
    local vendorData = NewVendorDataStub({ [vendor.npcID] = { 96101 } }, { vendor })
    vendorData.InvalidateVendorItemsMemo = function() vendorFlushCount = vendorFlushCount + 1 end
    h.stub.VendorData = vendorData

    GetTimePreciseSec = function() return 0 end
    InCombatLockdown = function() return false end

    local capturedTriggerCb, capturedAfterCb
    C_Timer = {
        NewTicker = function() return { Cancel = function() end } end,
        NewTimer = function(_, cb) capturedTriggerCb = cb return { Cancel = function() end } end,
        After = function(_, cb) capturedAfterCb = cb end,
    }
    C_Map = { GetBestMapForUnit = function() return nil end }

    assert(loadfile(root .. "/UI/BadgeCalculation.lua"))("Homestead", h.stub)
    local BadgeCalc = assert(h.stub.BadgeCalculation, "BadgeCalculation did not load")

    BadgeCalc:RequestPrewarm("hs282-flush-clean")
    assert(capturedTriggerCb, "RequestPrewarm must schedule a debounce timer")
    capturedTriggerCb()

    local ticks = 0
    while capturedAfterCb and ticks < 50 do
        local cb = capturedAfterCb
        capturedAfterCb = nil
        cb()
        ticks = ticks + 1
    end
    assert(ticks < 50, "pass did not terminate")

    assert(sourcesFlushCount == 1,
        "a clean, nothing-pending pass completion must flush SourceManager's memo exactly once, got " ..
        sourcesFlushCount)
    assert(vendorFlushCount == 1,
        "a clean, nothing-pending pass completion must flush VendorData's memo exactly once, got " ..
        vendorFlushCount)

    print("hs282_source_memo_eviction: Part 4a (clean completion flushes exactly once) ok")
end

-- Part 4b: a pass that hits the pending-rerun (staleMidPass) branch must NOT
-- flush on that tick -- only the rerun's own eventual clean completion may
-- flush, and only once.
do
    local h = NewStubHA()
    local sourcesFlushCount, vendorFlushCount = 0, 0
    h.stub.SourceManager = {
        GetItemPresentation = function()
            return {
                matchesSourceFilter = true, isOwnershipExcluded = false,
                isOwned = false, availabilityState = "purchasable",
            }
        end,
        InvalidateSourcesMemo = function() sourcesFlushCount = sourcesFlushCount + 1 end,
    }

    local vendor = { npcID = 96200 }
    local vendorData = NewVendorDataStub({ [vendor.npcID] = { 96201 } }, { vendor })
    vendorData.InvalidateVendorItemsMemo = function() vendorFlushCount = vendorFlushCount + 1 end
    h.stub.VendorData = vendorData

    GetTimePreciseSec = function() return 0 end
    InCombatLockdown = function() return false end

    local capturedTriggerCb, capturedAfterCb
    C_Timer = {
        NewTicker = function() return { Cancel = function() end } end,
        NewTimer = function(_, cb) capturedTriggerCb = cb return { Cancel = function() end } end,
        After = function(_, cb) capturedAfterCb = cb end,
    }
    C_Map = { GetBestMapForUnit = function() return nil end }

    assert(loadfile(root .. "/UI/BadgeCalculation.lua"))("Homestead", h.stub)
    local BadgeCalc = assert(h.stub.BadgeCalculation, "BadgeCalculation did not load")

    BadgeCalc:RequestPrewarm("hs282-flush-rerun")
    capturedTriggerCb()

    -- Tick 1: the vendor loop's only tick, finishing the sole vendor.
    do
        local cb = assert(capturedAfterCb, "no ProcessBatch tick was scheduled")
        capturedAfterCb = nil
        cb()
    end

    -- Between tick 1 and tick 2, an invalidation lands mid-pass -- bumps
    -- vendorStatsCacheGeneration out from under passGeneration, forcing
    -- staleMidPass true for the rest of THIS pass.
    BadgeCalc:InvalidateAllCaches()

    -- Tick 2: currentIndex is already past totalVendors, so this tick lands
    -- straight in the post-loop staleMidPass check -- true -- taking the
    -- rerun branch, not the flush branch.
    do
        local cb = assert(capturedAfterCb, "no post-loop tick was scheduled")
        capturedAfterCb = nil
        cb()
    end

    assert(sourcesFlushCount == 0 and vendorFlushCount == 0,
        "the pending-rerun (staleMidPass) branch must not flush -- got sources=" ..
        sourcesFlushCount .. " vendor=" .. vendorFlushCount)

    -- StartPrewarmPass's rerun schedules its own fresh tick chain (a new
    -- generation, so nothing forces staleMidPass again) -- drain it to its
    -- own clean completion, which SHOULD flush exactly once.
    local ticks = 0
    while capturedAfterCb and ticks < 50 do
        local cb = capturedAfterCb
        capturedAfterCb = nil
        cb()
        ticks = ticks + 1
    end
    assert(ticks < 50, "the rerun pass did not terminate")

    assert(sourcesFlushCount == 1 and vendorFlushCount == 1,
        "the rerun's own clean completion must flush exactly once, got sources=" ..
        sourcesFlushCount .. " vendor=" .. vendorFlushCount)

    print("hs282_source_memo_eviction: Part 4b (pending-rerun branch skips flush; " ..
        "rerun's own clean completion flushes once) ok")
end

-- Part 4c: a pass that aborts via pcall (a broken accumulator call) must
-- never flush -- the caps remain the bound on that path by construction.
do
    local h = NewStubHA()
    local sourcesFlushCount, vendorFlushCount = 0, 0
    h.stub.SourceManager = {
        GetItemPresentation = function()
            return {
                matchesSourceFilter = true, isOwnershipExcluded = false,
                isOwned = false, availabilityState = "purchasable",
            }
        end,
        InvalidateSourcesMemo = function() sourcesFlushCount = sourcesFlushCount + 1 end,
    }

    local vendor = { npcID = 96300 }
    h.stub.VendorData = {
        GetAllVendors = function() return { vendor } end,
        GetMergedItemSet = function() error("hs282 test: forced GetMergedItemSet failure") end,
        InvalidateVendorItemsMemo = function() vendorFlushCount = vendorFlushCount + 1 end,
    }

    GetTimePreciseSec = function() return 0 end
    InCombatLockdown = function() return false end

    local capturedTriggerCb, capturedAfterCb
    C_Timer = {
        NewTicker = function() return { Cancel = function() end } end,
        NewTimer = function(_, cb) capturedTriggerCb = cb return { Cancel = function() end } end,
        After = function(_, cb) capturedAfterCb = cb end,
    }
    C_Map = { GetBestMapForUnit = function() return nil end }

    assert(loadfile(root .. "/UI/BadgeCalculation.lua"))("Homestead", h.stub)
    local BadgeCalc = assert(h.stub.BadgeCalculation, "BadgeCalculation did not load")

    BadgeCalc:RequestPrewarm("hs282-flush-abort")
    capturedTriggerCb()

    local cb = assert(capturedAfterCb, "no ProcessBatch tick was scheduled")
    capturedAfterCb = nil
    cb()

    assert(not capturedAfterCb, "a pcall-aborted pass must not reschedule another tick")
    assert(sourcesFlushCount == 0 and vendorFlushCount == 0,
        "a pcall-aborted pass must never flush either memo, got sources=" ..
        sourcesFlushCount .. " vendor=" .. vendorFlushCount)

    print("hs282_source_memo_eviction: Part 4c (pcall abort never flushes) ok")
end

-------------------------------------------------------------------------------
-- Part 5: corpus-level parity -- real static vendor DB, forced eviction
-- cycles via a locally-overridden (test-only) cap, deep-compared before and
-- after.
-------------------------------------------------------------------------------

do
    local function readFile(path)
        local f = assert(io.open(path, "r"))
        local content = f:read("*a")
        f:close()
        return content
    end

    local function deepEqual(a, b)
        if a == b then return true end
        if type(a) ~= "table" or type(b) ~= "table" then return false end
        for k, v in pairs(a) do
            if not deepEqual(v, b[k]) then return false end
        end
        for k in pairs(b) do
            if a[k] == nil then return false end
        end
        return true
    end

    -- Load the REAL static vendor DB, same as HS-282 Step 0's calibration
    -- script and every other module-under-test in this suite.
    local HA = { Addon = { RegisterModule = function() end } }
    assert(loadfile(root .. "/Data/VendorOffers.lua"))("Homestead", HA)

    -- Patch VendorData.lua's OWN loaded copy to use a tiny cap, forcing many
    -- eviction cycles across one pass over the real ~233-vendor corpus. The
    -- SHIPPED constant (512) is untouched -- this override only ever exists
    -- in this test's in-memory chunk.
    local source = readFile(root .. "/Data/VendorData.lua")
    local patched, subCount = source:gsub(
        "local VENDOR_ITEMS_MEMO_MAX_ENTRIES = 512",
        "local VENDOR_ITEMS_MEMO_MAX_ENTRIES = 5")
    assert(subCount == 1,
        "expected exactly one VENDOR_ITEMS_MEMO_MAX_ENTRIES declaration to override, got " .. subCount)

    local chunk = assert(loadstring(patched, "@" .. root .. "/Data/VendorData.lua (hs282 cap-override test copy)"))
    chunk("Homestead", HA)

    -- Spy on the invalidator to prove eviction actually fired -- not a
    -- vacuous pass where the corpus happens to fit under the override.
    local invalidateCount = 0
    local realInvalidate = HA.VendorData.InvalidateVendorItemsMemo
    HA.VendorData.InvalidateVendorItemsMemo = function(self)
        invalidateCount = invalidateCount + 1
        return realInvalidate(self)
    end

    -- Corpus: every distinct npcID with at least one offer row, same
    -- enumeration as the Step 0 calibration script.
    local corpus = {}
    local seen = {}
    local function addNPC(npcID)
        if not seen[npcID] then
            seen[npcID] = true
            corpus[#corpus + 1] = npcID
        end
    end
    for npcID in pairs(HA.VendorOffers.GeneratedBase or {}) do addNPC(npcID) end
    for npcID in pairs(HA.VendorOffers.ManualOverrides or {}) do addNPC(npcID) end
    for npcID in pairs(HA.VendorOffers.StagedAdditions or {}) do addNPC(npcID) end
    assert(#corpus > 50, "sanity: expected a real-sized vendor corpus, got " .. #corpus)

    -- Pass 1: populate. Under the 5-entry override against a 200+-vendor
    -- corpus, this single linear pass already forces many wipes.
    local baseline = {}
    for _, npcID in ipairs(corpus) do
        baseline[npcID] = HA.VendorData:GetVendorItems(npcID)
    end
    assert(invalidateCount > 0,
        "expected at least one eviction wipe forcing this pass, got " .. invalidateCount)

    -- Pass 2: re-query every vendor. Virtually every entry here is a
    -- rebuild, not a cache hit -- deep-compare against pass 1's content
    -- proves the rebuild is identical to what a warm cache would have
    -- served (eviction is memory-only and behavior-neutral).
    local mismatches = 0
    for _, npcID in ipairs(corpus) do
        local rebuilt = HA.VendorData:GetVendorItems(npcID)
        if not deepEqual(baseline[npcID], rebuilt) then
            mismatches = mismatches + 1
        end
    end
    assert(mismatches == 0,
        mismatches .. " of " .. #corpus .. " vendors' GetVendorItems content changed across an " ..
        "eviction cycle -- eviction must be memory-only and behavior-neutral")

    print("hs282_source_memo_eviction: Part 5 (corpus-level parity, " .. invalidateCount ..
        " forced wipes over " .. #corpus .. " vendors) ok")
end

print("hs282_source_memo_eviction: done")
