-- luacheck: globals assert loadfile print CreateFrame GetProfessions GetProfessionInfo C_QuestLog

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-213: fingerprint-gate SKILL_LINES_CHANGED
--
-- Loads the REAL Data/SourceManager.lua module against a minimal WoW stub
-- (CreateFrame + GetProfessions/GetProfessionInfo, both mutable across the
-- test so the profession snapshot can be changed between fires), captures
-- the frame's real OnEvent handler, and fires it directly — this executes
-- the actual gating logic, not a source-grep.
--
-- Cycle 1 fix: the stub now models the REAL 5-fixed-slot GetProfessions()
-- shape (primary1, primary2, archaeology, fishing, cooking) WITH a hole in
-- the middle (archaeology empty, as on virtually every character) — a
-- 2-contiguous-value stub is exactly what hid the ipairs()-stops-at-the-
-- first-nil-hole bug Argus caught in cycle 1.
-------------------------------------------------------------------------------

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

-- Mutable profession snapshot the stubbed API reports. archaeology (slot 3)
-- stays nil throughout — the realistic hole that hid the bug. fishing/
-- cooking (slots 4/5) are populated so a slot-5 change can be exercised.
local professionState = {
    primary1 = { name = "Blacksmithing", skillLevel = 50, maxSkillLevel = 100, skillLine = 164 },
    primary2 = nil,
    archaeology = nil,
    fishing = { name = "Fishing", skillLevel = 1, maxSkillLevel = 1, skillLine = 356 },
    cooking = { name = "Cooking", skillLevel = 1, maxSkillLevel = 1, skillLine = 185 },
}
local slotOrder = { "primary1", "primary2", "archaeology", "fishing", "cooking" }

GetProfessions = function()
    -- Real API: 5 fixed positional returns (prof1, prof2, archaeology,
    -- fishing, cooking), nil for an empty slot. The "index" values here are
    -- just each slot's fixed position (1-5) — GetProfessionInfo(index)
    -- resolves via that same position, mirroring the real by-index contract.
    local results = {}
    for i, slotName in ipairs(slotOrder) do
        results[i] = professionState[slotName] and i or nil
    end
    return results[1], results[2], results[3], results[4], results[5]
end

GetProfessionInfo = function(index)
    local slotName = slotOrder[index]
    local p = slotName and professionState[slotName]
    if not p then return nil end
    return p.name, nil, p.skillLevel, p.maxSkillLevel, nil, nil, p.skillLine
end

local invalidateCalls = 0
local questCheckCalls = 0

C_QuestLog = {
    IsQuestFlaggedCompleted = function(questID)
        questCheckCalls = questCheckCalls + 1
        return questID == 500
    end,
}

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

-- Wrap InvalidateAllSourceCaches with a counter (method lookup is dynamic —
-- this replacement is honored by everything that calls self:InvalidateAllSourceCaches()).
local realInvalidate = HA.SourceManager.InvalidateAllSourceCaches
HA.SourceManager.InvalidateAllSourceCaches = function(...)
    invalidateCalls = invalidateCalls + 1
    return realInvalidate(...)
end

-- Fire 1: first-ever SKILL_LINES_CHANGED — must invalidate regardless of
-- fingerprint (lazy init, cold-correctness over cleverness).
capturedFrame.handler(capturedFrame, "SKILL_LINES_CHANGED")
assert(invalidateCalls == 1, "first-ever SKILL_LINES_CHANGED must always invalidate")

-- Plant a real requirementMetCache entry via the public API (mirrors the
-- HS-203 test pattern): evaluating this quest requirement caches its result,
-- observable via the underlying C_QuestLog call count.
assert(HA.SourceManager:IsRequirementMet({ type = "quest", id = 500 }) == true)
assert(questCheckCalls == 1)

-- Fire 2: SAME profession snapshot (profession-window-open false trigger) —
-- must NOT invalidate, and the planted cache entry must survive (no new
-- C_QuestLog call on re-evaluation).
capturedFrame.handler(capturedFrame, "SKILL_LINES_CHANGED")
assert(invalidateCalls == 1, "same-fingerprint SKILL_LINES_CHANGED must be suppressed, not invalidate")
assert(HA.SourceManager:IsRequirementMet({ type = "quest", id = 500 }) == true)
assert(questCheckCalls == 1, "the planted cache entry must survive a same-fingerprint (suppressed) fire")

-- Fire 3: genuine rank change on the PRIMARY profession (slot 1) — must
-- invalidate, and the planted cache entry must NOT survive.
professionState.primary1.skillLevel = 55
capturedFrame.handler(capturedFrame, "SKILL_LINES_CHANGED")
assert(invalidateCalls == 2, "a real primary-profession skillLevel change must invalidate")
assert(HA.SourceManager:IsRequirementMet({ type = "quest", id = 500 }) == true)
assert(questCheckCalls == 2, "the planted cache entry must NOT survive a real profession change")

-- Fire 4: back to the (now current) unchanged snapshot — must NOT invalidate.
capturedFrame.handler(capturedFrame, "SKILL_LINES_CHANGED")
assert(invalidateCalls == 2, "unchanged snapshot after a real change must still be suppressed")

-- Fire 5: a SECONDARY profession's (slot 5, cooking) skillLevel change —
-- must invalidate. This is exactly the class of change the cycle-1
-- ipairs()-stops-at-the-first-nil-hole bug silently dropped, since
-- archaeology (slot 3) sits empty between the primary professions and
-- fishing/cooking.
professionState.cooking.skillLevel = 25
capturedFrame.handler(capturedFrame, "SKILL_LINES_CHANGED")
assert(invalidateCalls == 3, "a secondary-profession (slot 5, cooking) skillLevel change must invalidate")

-- Fire 6: a second primary profession appearing (slot 2) changes the
-- fingerprint shape — must invalidate.
professionState.primary2 = { name = "Leatherworking", skillLevel = 25, maxSkillLevel = 100, skillLine = 165 }
capturedFrame.handler(capturedFrame, "SKILL_LINES_CHANGED")
assert(invalidateCalls == 4, "a profession-set change must invalidate")

-- Fire 7: nil-API fail-open. Simulate the profession API becoming
-- unavailable (e.g. very early login) by removing the globals; the gate
-- must fail OPEN (always invalidate), never fail closed.
GetProfessions = nil
GetProfessionInfo = nil
capturedFrame.handler(capturedFrame, "SKILL_LINES_CHANGED")
assert(invalidateCalls == 5, "a nil profession API must fail OPEN (always invalidate), never fail closed")
capturedFrame.handler(capturedFrame, "SKILL_LINES_CHANGED")
assert(invalidateCalls == 6, "fail-open must persist across repeated fires while the API stays unavailable")

-- Other registered events stay unconditional — never gated, regardless of
-- the profession fingerprint's state.
capturedFrame.handler(capturedFrame, "ACHIEVEMENT_EARNED")
assert(invalidateCalls == 7, "ACHIEVEMENT_EARNED must remain unconditional")
capturedFrame.handler(capturedFrame, "NEW_RECIPE_LEARNED")
assert(invalidateCalls == 8, "NEW_RECIPE_LEARNED must remain unconditional")

print("hs213_skill_lines_gate: ok")
