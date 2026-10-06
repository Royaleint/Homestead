-- luacheck: globals assert loadfile print CreateFrame GetProfessions GetProfessionInfo C_QuestLog

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-213/HS-215: fingerprint-gate SKILL_LINES_CHANGED
--
-- Loads the REAL Data/SourceManager.lua module against a minimal WoW stub
-- (CreateFrame + GetProfessions/GetProfessionInfo, both mutable across the
-- test so the profession snapshot can be changed between fires), captures
-- the frame's real OnEvent handler, and fires it directly — this executes
-- the actual gating logic, not a source-grep. Each part below loads a FRESH
-- SourceManager instance (loadfile returns a new closure each call, with its
-- own module-local lastProfessionFingerprint/completionInvalidationFrame),
-- since the eager-seed behavior (HS-215) depends on what the profession
-- state looked like at Initialize()/install time specifically.
--
-- HS-213 cycle 1 fix: the stub models the REAL 5-fixed-slot GetProfessions()
-- shape (primary1, primary2, archaeology, fishing, cooking) WITH a hole in
-- the middle (archaeology empty, as on virtually every character) — a
-- 2-contiguous-value stub is exactly what hid the ipairs()-stops-at-the-
-- first-nil-hole bug Argus caught in cycle 1.
--
-- HS-215: lastProfessionFingerprint is now seeded EAGERLY at
-- HookCompletionCacheInvalidation install time (Initialize()), not lazily
-- on the first fire — so a first fire with an UNCHANGED profession state is
-- now suppressed (this used to always invalidate under lazy init, which was
-- the cold-open gap Gate 2 re-test caught). A nil profession API at install
-- time still fails open (HS-283 preserved this explicitly — see below).
--
-- HS-283: a CHANGED fingerprint no longer invalidates unconditionally — it
-- now routes through the same professionRank/profession-availability
-- verify-then-skip gate TRAIT_CONFIG_UPDATED and NEW_RECIPE_LEARNED use, so
-- a skill-up that flips no cached verdict is suppressed too. This file
-- keeps testing that each profession-slot shape correctly registers as
-- "fingerprint changed" (its actual job); each fire below seeds a matching
-- professionRank baseline first so "changed" and "a consumer-visible verdict
-- flipped" coincide, keeping the original invalidateCalls() assertions
-- meaningful under the new gate. The verify-then-skip gate's own
-- correctness (including the profession-availability half the fingerprint
-- can't see) is covered by tests/hs283_profession_invalidation_gates.lua.
-------------------------------------------------------------------------------

local function MakeProfessionStubs(initialState)
    local slotOrder = { "primary1", "primary2", "archaeology", "fishing", "cooking" }
    local professionState = initialState

    local function getProfessions()
        local results = {}
        for i, slotName in ipairs(slotOrder) do
            results[i] = professionState[slotName] and i or nil
        end
        return results[1], results[2], results[3], results[4], results[5]
    end

    local function getProfessionInfo(index)
        local slotName = slotOrder[index]
        local p = slotName and professionState[slotName]
        if not p then return nil end
        return p.name, nil, p.skillLevel, p.maxSkillLevel, nil, nil, p.skillLine
    end

    return professionState, getProfessions, getProfessionInfo
end

local function LoadSourceManager()
    local capturedFrame = nil
    CreateFrame = function()
        local frame = {}
        function frame:RegisterEvent() end
        function frame:SetScript(_, handler)
            self.handler = handler
        end
        capturedFrame = frame
        return frame
    end

    local invalidateCalls = 0
    local HA = {
        Constants = { Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
        Addon = {
            db = { profile = {}, global = { parsedSources = {} } },
            RegisterModule = function() end,
            Debug = function() end,
        },
    }

    assert(loadfile(root .. "/Data/SourceManager.lua"))("Homestead", HA)
    HA.SourceManager:Initialize()

    assert(capturedFrame ~= nil, "HookCompletionCacheInvalidation must have created and captured the event frame")
    assert(capturedFrame.handler ~= nil, "OnEvent handler must be set")

    local realInvalidate = HA.SourceManager.InvalidateAllSourceCaches
    HA.SourceManager.InvalidateAllSourceCaches = function(...)
        invalidateCalls = invalidateCalls + 1
        return realInvalidate(...)
    end

    return HA, capturedFrame, function() return invalidateCalls end
end

-------------------------------------------------------------------------------
-- Part 1: eager seed at install time, UNCHANGED state — first fire must be
-- SUPPRESSED (the HS-215 fix; this is what a cold profession-window open
-- with no actual profession progress looks like).
-------------------------------------------------------------------------------

local professionState, getProfessions, getProfessionInfo = MakeProfessionStubs({
    primary1 = { name = "Blacksmithing", skillLevel = 50, maxSkillLevel = 100, skillLine = 164 },
    primary2 = nil,
    archaeology = nil,
    fishing = { name = "Fishing", skillLevel = 1, maxSkillLevel = 1, skillLine = 356 },
    cooking = { name = "Cooking", skillLevel = 1, maxSkillLevel = 1, skillLine = 185 },
})
GetProfessions = getProfessions
GetProfessionInfo = getProfessionInfo

local HA, capturedFrame, invalidateCalls = LoadSourceManager()

local questCheckCalls = 0
C_QuestLog = {
    IsQuestFlaggedCompleted = function(questID)
        questCheckCalls = questCheckCalls + 1
        return questID == 500
    end,
}

-- Fire 1: profession state unchanged since the eager seed at Initialize() —
-- must be SUPPRESSED, not invalidate. This is the HS-215 fix under test.
capturedFrame.handler(capturedFrame, "SKILL_LINES_CHANGED")
assert(invalidateCalls() == 0,
    "a first SKILL_LINES_CHANGED fire matching the eager-seeded baseline must be suppressed (HS-215)")

-- Plant a real requirementMetCache entry via the public API (mirrors the
-- HS-203 test pattern): evaluating this quest requirement caches its result,
-- observable via the underlying C_QuestLog call count.
assert(HA.SourceManager:IsRequirementMet({ type = "quest", id = 500 }) == true)
assert(questCheckCalls == 1)

-- Fire 2: SAME profession snapshot again (profession-window-open false
-- trigger) — must NOT invalidate, and the planted cache entry must survive.
capturedFrame.handler(capturedFrame, "SKILL_LINES_CHANGED")
assert(invalidateCalls() == 0, "same-fingerprint SKILL_LINES_CHANGED must be suppressed, not invalidate")
assert(HA.SourceManager:IsRequirementMet({ type = "quest", id = 500 }) == true)
assert(questCheckCalls == 1, "the planted cache entry must survive a same-fingerprint (suppressed) fire")

-- HS-283: seed a professionRank baseline per profession this part changes,
-- each unmet at the CURRENT skill level, so the fingerprint-changing fires
-- below also flip a consumer-visible verdict — keeping "fingerprint changed"
-- and "must invalidate" the same event under the new verify-then-skip gate.
-- Leatherworking doesn't exist yet at seed time (primary2 is nil) — its
-- requirement evaluates to met == nil, and nil -> determinate counts as a
-- flip once it appears (Fire 6), same as HS-238's reputation baseline.
assert(HA.SourceManager:IsRequirementMet({ type = "professionRank", profession = "Blacksmithing", rank = 52 }) == false)
assert(HA.SourceManager:IsRequirementMet({ type = "professionRank", profession = "Cooking", rank = 2 }) == false)
assert(HA.SourceManager:IsRequirementMet({ type = "professionRank", profession = "Leatherworking", rank = 1 }) == nil)

-- Fire 3: genuine rank change on the PRIMARY profession (slot 1), which also
-- flips the seeded Blacksmithing baseline — must invalidate, and the planted
-- cache entry must NOT survive.
professionState.primary1.skillLevel = 55
capturedFrame.handler(capturedFrame, "SKILL_LINES_CHANGED")
assert(invalidateCalls() == 1, "a real primary-profession skillLevel change that flips a verdict must invalidate")
assert(HA.SourceManager:IsRequirementMet({ type = "quest", id = 500 }) == true)
assert(questCheckCalls == 2, "the planted cache entry must NOT survive a real profession change")

-- Fire 4: back to the (now current) unchanged snapshot — must NOT invalidate.
capturedFrame.handler(capturedFrame, "SKILL_LINES_CHANGED")
assert(invalidateCalls() == 1, "unchanged snapshot after a real change must still be suppressed")

-- Fire 5: a SECONDARY profession's (slot 5, cooking) skillLevel change,
-- which also flips the seeded Cooking baseline — must invalidate. This is
-- exactly the class of change the cycle-1 ipairs()-stops-at-the-first-
-- nil-hole bug silently dropped, since archaeology (slot 3) sits empty
-- between the primary professions and fishing/cooking.
professionState.cooking.skillLevel = 25
capturedFrame.handler(capturedFrame, "SKILL_LINES_CHANGED")
assert(invalidateCalls() == 2, "a secondary-profession (slot 5, cooking) change that flips a verdict must invalidate")

-- Fire 6: a second primary profession appearing (slot 2), which flips the
-- seeded Leatherworking baseline from nil (undeterminable) to true — must
-- invalidate.
professionState.primary2 = { name = "Leatherworking", skillLevel = 25, maxSkillLevel = 100, skillLine = 165 }
capturedFrame.handler(capturedFrame, "SKILL_LINES_CHANGED")
assert(invalidateCalls() == 3, "a profession-set change that flips a verdict must invalidate")

-- HS-283 (second pass) gated ACHIEVEMENT_EARNED too, but a fire with no
-- payload (as below) is a non-number achievementID, which fails open and
-- still invalidates — see tests/hs238_invalidation_gates.lua for coverage
-- of the gated (real achievementID, cache-probe, and verify-then-skip)
-- cases this file doesn't exercise.
capturedFrame.handler(capturedFrame, "ACHIEVEMENT_EARNED")
assert(invalidateCalls() == 4, "ACHIEVEMENT_EARNED with a non-number payload must fail open and invalidate")

-- NEW_RECIPE_LEARNED is now gated too (HS-283) — with every seeded baseline
-- already re-verified as current (the ACHIEVEMENT_EARNED wipe above doesn't
-- touch requirementEvalBaseline, which is deliberately never cleared by
-- invalidation), nothing has flipped since the last check — must suppress.
capturedFrame.handler(capturedFrame, "NEW_RECIPE_LEARNED")
assert(invalidateCalls() == 4, "NEW_RECIPE_LEARNED with no flipped verdict must now suppress (HS-283)")

print("hs213_skill_lines_gate: part 1 (eager seed, unchanged-state suppression) ok")

-------------------------------------------------------------------------------
-- Part 2: profession state CHANGES between the eager seed (Initialize()) and
-- the first SKILL_LINES_CHANGED fire, AND that change flips a verdict a
-- consumer has seen — must still invalidate. Fresh instance so its own seed
-- is captured independently of part 1.
-------------------------------------------------------------------------------

local professionState2, getProfessions2, getProfessionInfo2 = MakeProfessionStubs({
    primary1 = { name = "Tailoring", skillLevel = 20, maxSkillLevel = 100, skillLine = 197 },
    primary2 = nil,
    archaeology = nil,
    fishing = nil,
    cooking = nil,
})
GetProfessions = getProfessions2
GetProfessionInfo = getProfessionInfo2

local HA2, capturedFrame2, invalidateCalls2 = LoadSourceManager()

-- HS-283: seed a baseline at the current (post-eager-seed) skill level, same
-- reasoning as Part 1 — otherwise a changed fingerprint with nothing
-- baselined would correctly suppress under the new gate, and this part
-- would no longer be testing what it claims to.
assert(HA2.SourceManager:IsRequirementMet({ type = "professionRank", profession = "Tailoring", rank = 21 }) == false)

-- Profession state changes AFTER the eager seed was captured, BEFORE the
-- first event fire (e.g. player trained a rank between login and the first
-- SKILL_LINES_CHANGED the addon observes) — flipping the seeded baseline.
professionState2.primary1.skillLevel = 21
capturedFrame2.handler(capturedFrame2, "SKILL_LINES_CHANGED")
assert(invalidateCalls2() == 1,
    "a first fire with a state CHANGED from the eager-seeded baseline, flipping a verdict, must still invalidate")

print("hs213_skill_lines_gate: part 2 (changed-state first fire) ok")

-------------------------------------------------------------------------------
-- Part 3: profession API is nil at install time — seed is nil, first (and
-- every subsequent) fire must fail OPEN, never fail closed.
-------------------------------------------------------------------------------

GetProfessions = nil
GetProfessionInfo = nil

local _, capturedFrame3, invalidateCalls3 = LoadSourceManager()

capturedFrame3.handler(capturedFrame3, "SKILL_LINES_CHANGED")
assert(invalidateCalls3() == 1, "a nil profession API at install time must fail OPEN on the first fire")
capturedFrame3.handler(capturedFrame3, "SKILL_LINES_CHANGED")
assert(invalidateCalls3() == 2, "fail-open must persist across repeated fires while the API stays unavailable")

print("hs213_skill_lines_gate: part 3 (nil-API seed fail-open) ok")
