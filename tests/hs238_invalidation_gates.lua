-- luacheck: globals assert loadfile print io C_QuestLog C_MajorFactions CreateFrame InCombatLockdown GetAchievementInfo

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-238: verify-then-skip invalidation gates
--
-- The seven trigger-class WoW events all funnel into
-- SourceManager:InvalidateAllSourceCaches, and since HS-234 every
-- invalidation costs a full vendor-stats pre-warm pass. These tests prove
-- the two high-frequency triggers no longer invalidate unless a verdict
-- actually changed:
--   UPDATE_FACTION  -> re-evaluates the reputation verdicts consumers have
--                      seen (requirementEvalBaseline) and skips when none
--                      flipped, including via the combat-exit deferred path.
--   QUEST_TURNED_IN -> skips quests that are neither in QuestSources nor
--                      present in any cache; fails OPEN (invalidates) on a
--                      non-number payload.
--
-- HS-283 (second pass) adds two more gated triggers, covered in sections
-- (8)-(9) below:
--   ACHIEVEMENT_EARNED               -> probes completionCache directly first
--                                        (id-keyed only -- see (8c), the
--                                        mutation-critical case), then runs a
--                                        SCOPED SCAN of requirementEvalBaseline:
--                                        achievement-type entries only, each
--                                        matched to the earned achievementID
--                                        via the addon-internal id-or-name
--                                        resolution (ResolveAchievementID --
--                                        req.id direct, or req.name against
--                                        HA.AchievementSources, English vs
--                                        English). The live GetAchievementInfo
--                                        NAME never enters any comparison --
--                                        it is locale-translated, and Argus
--                                        Gate 1 cycle 3 caught a draft
--                                        building a lookup key from it, which
--                                        silently missed every name-only
--                                        requirement on non-English clients
--                                        (see (8f)). Never scans the shared
--                                        UPDATE_FACTION/profession counter
--                                        (Argus Gate 1 cycle 1 rejected an
--                                        earlier draft that widened it to
--                                        cover achievements, costing every
--                                        one of THOSE events a full
--                                        achievement-corpus re-evaluation for
--                                        zero information -- see (8g)).
--   MAJOR_FACTION_RENOWN_LEVEL_CHANGED -> renown is already type="reputation",
--                                          so it reuses the counter directly.
-------------------------------------------------------------------------------

-- Mutable WoW API state the handlers read.
local renownByFaction = { [100] = 3 }   -- factionID -> current renown level
local completedQuests = { [500] = true }
local inCombat = false
local achievementCompletion = {}   -- achievementID -> {completed, wasEarnedByMe}
local achievementNames = {}        -- achievementID -> LIVE (locale-translated) name the stub
                                   -- returns; (8f) deliberately sets one that DIFFERS from the
                                   -- addon-internal English name to prove locale independence
local achievementInfoCalls = 0

C_QuestLog = {
    IsQuestFlaggedCompleted = function(questID)
        return completedQuests[questID] == true
    end,
}

C_MajorFactions = {
    GetMajorFactionData = function(factionID)
        local renown = renownByFaction[factionID]
        if renown == nil then return nil end
        return { renownLevel = renown }
    end,
    GetMajorFactionIDs = function() return {} end,
}

InCombatLockdown = function() return inCombat end

GetAchievementInfo = function(achievementID)
    achievementInfoCalls = achievementInfoCalls + 1
    local state = achievementCompletion[achievementID]
    if not state then return nil end
    -- Real signature: id, name, points, completed, ..., wasEarnedByMe (13th).
    return achievementID, achievementNames[achievementID] or "Test Achievement", 10, state.completed,
        nil, nil, nil, nil, nil, nil, nil, nil, state.wasEarnedByMe
end

-- Capture every frame created by the hook installer, with its registered
-- events and OnEvent script, so the test can deliver events by hand.
local createdFrames = {}
CreateFrame = function()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(handler, fn) self.scripts[handler] = fn end
    createdFrames[#createdFrames + 1] = frame
    return frame
end

local invalidationFires = 0
local lastDebugMessage = nil

local HA = {
    Constants = { Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
    Addon = {
        db = { profile = {}, global = { parsedSources = {} } },
        RegisterModule = function() end,
        Debug = function(_, ...)
            local parts = {}
            for i = 1, select("#", ...) do
                parts[i] = tostring((select(i, ...)))
            end
            lastDebugMessage = table.concat(parts, " ")
        end,
    },
    Events = {
        RegisterCallback = function() end,
        Fire = function(_, eventName)
            if eventName == "SOURCE_CACHES_INVALIDATED" then
                invalidationFires = invalidationFires + 1
            end
        end,
    },
    QuestSources = {
        [245263] = { questID = 500, questName = "Tracked Quest" },
    },
    -- Mirrors Data/AchievementSources.lua's shape enough to exercise
    -- EvaluateRequirementMetLive's name->id resolution walk for name-only
    -- requirements (the Data/PrerequisiteSources.lua shape -- see (8f)).
    AchievementSources = {
        [950] = { achievementName = "Zandalar Forever!", achievementID = 950 },
    },
}

assert(loadfile(root .. "/Data/SourceManager.lua"))("Homestead", HA)
HA.SourceManager:Initialize()

-- Locate the two frames the hook installs: the deferral frame registers
-- PLAYER_REGEN_ENABLED, the invalidation frame registers UPDATE_FACTION.
local deferralFrame, invalidationFrame
for _, frame in ipairs(createdFrames) do
    if frame.events["PLAYER_REGEN_ENABLED"] then deferralFrame = frame end
    if frame.events["UPDATE_FACTION"] then invalidationFrame = frame end
end
assert(deferralFrame, "combat deferral frame not created")
assert(invalidationFrame, "invalidation frame not created")
assert(invalidationFrame.events["QUEST_TURNED_IN"], "QUEST_TURNED_IN not registered")
assert(invalidationFrame.events["ACHIEVEMENT_EARNED"], "ACHIEVEMENT_EARNED not registered")
assert(invalidationFrame.events["MAJOR_FACTION_RENOWN_LEVEL_CHANGED"],
    "MAJOR_FACTION_RENOWN_LEVEL_CHANGED not registered")

local function send(event, ...)
    invalidationFrame.scripts.OnEvent(invalidationFrame, event, ...)
end

local function combatExit()
    deferralFrame.scripts.OnEvent(deferralFrame)
end

-------------------------------------------------------------------------------
-- (1) UPDATE_FACTION with no evaluated reputation verdicts: nothing cached,
-- nothing can be stale — must suppress.
-------------------------------------------------------------------------------
send("UPDATE_FACTION")
assert(invalidationFires == 0, "UPDATE_FACTION with empty baseline must suppress")

-------------------------------------------------------------------------------
-- (2) Seed a reputation verdict, then fire UPDATE_FACTION with the verdict
-- unchanged — must suppress.
-------------------------------------------------------------------------------
local repReq = { type = "reputation", factionID = 100, renownLevel = 5 }
assert(HA.SourceManager:IsRequirementMet(repReq) == false)  -- renown 3 < 5
send("UPDATE_FACTION")
assert(invalidationFires == 0, "unchanged reputation verdict must suppress")

-------------------------------------------------------------------------------
-- (3) The verdict flips (renown crosses the threshold) — must invalidate.
-------------------------------------------------------------------------------
renownByFaction[100] = 5
send("UPDATE_FACTION")
assert(invalidationFires == 1, "flipped reputation verdict must invalidate")

-- And the baseline updated: an immediate repeat with no further change
-- must suppress again.
send("UPDATE_FACTION")
assert(invalidationFires == 1, "verdict already re-baselined — repeat must suppress")

-------------------------------------------------------------------------------
-- (4) nil -> determinate counts as a flip. A faction the API cannot resolve
-- yields verdict nil (never enters requirementMetCache); when it becomes
-- resolvable the cached-counts consumers built on nil are stale.
-------------------------------------------------------------------------------
local nilReq = { type = "reputation", factionID = 200, renownLevel = 2 }
assert(HA.SourceManager:IsRequirementMet(nilReq) == nil)
send("UPDATE_FACTION")
assert(invalidationFires == 1, "nil verdict unchanged must suppress")

renownByFaction[200] = 4
send("UPDATE_FACTION")
assert(invalidationFires == 2, "nil -> determinate must invalidate")

-------------------------------------------------------------------------------
-- (5) Combat deferral: UPDATE_FACTION in combat does nothing; the combat
-- exit runs the SAME verify — suppressing when nothing changed, and
-- invalidating when a verdict flipped while fighting.
-------------------------------------------------------------------------------
inCombat = true
send("UPDATE_FACTION")
assert(invalidationFires == 2, "in-combat UPDATE_FACTION must defer, not invalidate")

inCombat = false
combatExit()
assert(invalidationFires == 2, "deferred verify with unchanged verdicts must suppress")

inCombat = true
send("UPDATE_FACTION")
renownByFaction[100] = 6  -- 6 >= 5: met stays true — no flip
renownByFaction[200] = 1  -- 1 < 2: met flips true -> false
inCombat = false
combatExit()
assert(invalidationFires == 3, "deferred verify with a flipped verdict must invalidate")

-- Combat exit with nothing pending is a no-op.
combatExit()
assert(invalidationFires == 3, "combat exit with no pending deferral must be a no-op")

-------------------------------------------------------------------------------
-- (6) QUEST_TURNED_IN gates.
-------------------------------------------------------------------------------
-- Untracked, never-cached quest: suppress.
send("QUEST_TURNED_IN", 777001, 100, 100)
assert(invalidationFires == 3, "untracked, uncached quest must suppress")

-- QuestSources-tracked quest: invalidate.
send("QUEST_TURNED_IN", 500, 100, 100)
assert(invalidationFires == 4, "QuestSources-tracked quest must invalidate")

-- A quest known only through a cached requirement verdict (e.g. from
-- scanned/CatalogStore data): invalidate once its key exists.
local questReq = { type = "quest", id = 777002 }
assert(HA.SourceManager:IsRequirementMet(questReq) == false)
send("QUEST_TURNED_IN", 777002, 100, 100)
assert(invalidationFires == 5, "quest with cached requirement verdict must invalidate")

-- The baseline (not just requirementMetCache) must catch it: wipe the
-- caches, then turn in the same quest again — verdict cache is empty but
-- the baseline remembers consumers saw this quest.
HA.SourceManager:InvalidateAllSourceCaches()
local firesAfterDirectWipe = invalidationFires
send("QUEST_TURNED_IN", 777002, 100, 100)
assert(invalidationFires == firesAfterDirectWipe + 1,
    "baseline-remembered quest must invalidate after cache wipe")

-- The completionCache arm: a quest whose ID entered ONLY through
-- GetCompletionStatus (caller-supplied sourceData — the provenance hole
-- that superseded the HS-237 static-set gate). Not in QuestSources, never
-- a requirement — but its completion suffix is cached, so its turn-in must
-- invalidate.
local completionStatus = HA.SourceManager:GetCompletionStatus(999123, "quest", { questID = 888003 })
assert(completionStatus and completionStatus.met == false,
    "completion status for the uncompleted quest should cache as unmet")
local firesBeforeCompletionArm = invalidationFires
send("QUEST_TURNED_IN", 888003, 100, 100)
assert(invalidationFires == firesBeforeCompletionArm + 1,
    "quest present only in completionCache must invalidate")

-- Fail open: non-number payload must invalidate (current behavior), never
-- silently skip.
local firesBeforeFailOpen = invalidationFires
send("QUEST_TURNED_IN", "unexpected", 100, 100)
assert(invalidationFires == firesBeforeFailOpen + 1,
    "non-number questID payload must fail open and invalidate")

-------------------------------------------------------------------------------
-- (8) ACHIEVEMENT_EARNED gates (HS-283, second pass).
-------------------------------------------------------------------------------
-- (8a) Nothing cached or baselined for this achievement at all: must
-- suppress, and the debug line must name ACHIEVEMENT_EARNED, not
-- UPDATE_FACTION (Argus Gate 1 cycle 1 spec-compliance finding: the
-- SUPPRESS path is the common one and the one Gate 2 actually reads --
-- asserting only the invalidate-path debug string left this unpinned).
achievementCompletion[700] = { completed = false, wasEarnedByMe = false }
local firesBeforeAchNoop = invalidationFires
send("ACHIEVEMENT_EARNED", 700)
assert(invalidationFires == firesBeforeAchNoop,
    "ACHIEVEMENT_EARNED for a wholly untracked achievement must suppress")
assert(lastDebugMessage and lastDebugMessage:find("ACHIEVEMENT_EARNED") and not lastDebugMessage:find("UPDATE_FACTION"),
    "the suppress-path debug line for an untracked achievement must name ACHIEVEMENT_EARNED, not UPDATE_FACTION")

-- (8b) Seed a baseline via the availability path (IsRequirementMet, same as
-- line ~398's real caller), unmet. A flip (now completed) must invalidate,
-- and the debug line must name ACHIEVEMENT_EARNED, not UPDATE_FACTION —
-- checked on BOTH the suppress and invalidate paths.
local achReq = { type = "achievement", id = 700 }
assert(HA.SourceManager:IsRequirementMet(achReq) == false)
local firesBeforeAchFlip = invalidationFires
send("ACHIEVEMENT_EARNED", 700)
assert(invalidationFires == firesBeforeAchFlip,
    "re-firing before the underlying completion actually changes must still suppress")
assert(lastDebugMessage and lastDebugMessage:find("ACHIEVEMENT_EARNED") and not lastDebugMessage:find("UPDATE_FACTION"),
    "the suppress-path debug line for an unflipped baseline must name ACHIEVEMENT_EARNED, not UPDATE_FACTION")
achievementCompletion[700].completed = true
send("ACHIEVEMENT_EARNED", 700)
assert(invalidationFires == firesBeforeAchFlip + 1,
    "a flipped achievement-availability baseline must invalidate")
assert(lastDebugMessage and lastDebugMessage:find("ACHIEVEMENT_EARNED") and not lastDebugMessage:find("UPDATE_FACTION"),
    "the invalidate-path debug line for a flipped baseline must name ACHIEVEMENT_EARNED, not UPDATE_FACTION")

-- MUTATION-CRITICAL (Argus Gate 1 cycle 2 Warning): the baseline write-back
-- (`idBaseline.met = live`) is the only thing that makes this a ONE-TIME
-- invalidate. Without it, `baseline.met` stays stale forever and every
-- subsequent fire for this achievement re-invalidates. A third fire with no
-- further underlying change must suppress.
local firesAfterAchFlip = invalidationFires
send("ACHIEVEMENT_EARNED", 700)
assert(invalidationFires == firesAfterAchFlip,
    "re-firing after the baseline was already re-verified must suppress (baseline write-back)")

-- (8c) MUTATION-CRITICAL: the completionCache-only blocker this fix closes.
-- Populate completionCache ONLY via GetCompletionStatus (mirrors the quest
-- completionCache arm above) -- NOT through IsRequirementMet, so there is
-- deliberately no requirementEvalBaseline entry for this achievement. A
-- prior draft of this fix suppressed this case forever (0/0 checked/changed
-- in the counter); this test must fail if that regresses.
achievementCompletion[900] = { completed = false, wasEarnedByMe = false }
local achCompletionStatus = HA.SourceManager:GetCompletionStatus(999124, "achievement", { achievementID = 900 })
assert(achCompletionStatus and achCompletionStatus.met == false,
    "completion status for the incomplete achievement should cache as unmet")
-- No requirementEvalBaseline entry exists for 900 (GetCompletionStatus never
-- calls IsRequirementMet) -- requirementEvalBaseline is a private module
-- local, not inspectable from here, so this is proven behaviorally below:
-- if the completionCache arm regressed, this invalidate would not fire.
achievementCompletion[900].completed = true
local firesBeforeCompletionOnlyArm = invalidationFires
send("ACHIEVEMENT_EARNED", 900)
assert(invalidationFires == firesBeforeCompletionOnlyArm + 1,
    "an achievement present ONLY in completionCache (no baseline) must still invalidate when earned")
assert(lastDebugMessage and lastDebugMessage:find("ACHIEVEMENT_EARNED") and not lastDebugMessage:find("UPDATE_FACTION"),
    "the debug line for the completionCache-arm invalidate must name ACHIEVEMENT_EARNED, not UPDATE_FACTION")

-- Re-firing for the same already-earned achievement must now suppress: the
-- completionCache arm only fires on a stale (met == false / " (Account)")
-- entry, and no baseline exists.
local firesAfterCompletionOnlyArm = invalidationFires
send("ACHIEVEMENT_EARNED", 900)
assert(invalidationFires == firesAfterCompletionOnlyArm,
    "re-firing for an achievement already reflected as complete must suppress")

-- (8c2) The Account -> This Character transition (Argus Gate 1 cycle 1
-- Warning): GetCompletionStatus renders THREE states from two `met` values
-- -- "(This Character)" and "(Account)" are both met == true, only
-- "(Incomplete)" is met == false. A cached "(Account)" entry (earned by
-- another character) must still invalidate when ACHIEVEMENT_EARNED fires for
-- THIS character, even though met was already true.
achievementCompletion[901] = { completed = true, wasEarnedByMe = false }
local acctStatus = HA.SourceManager:GetCompletionStatus(999125, "achievement", { achievementID = 901 })
assert(acctStatus and acctStatus.met == true and acctStatus.suffix == " (Account)",
    "an account-earned-elsewhere achievement should cache as met with the Account suffix")
achievementCompletion[901].wasEarnedByMe = true
local firesBeforeAcctPromotion = invalidationFires
send("ACHIEVEMENT_EARNED", 901)
assert(invalidationFires == firesBeforeAcctPromotion + 1,
    "an Account -> This Character promotion must invalidate even though the cached met value was already true")

-- Re-firing once the cache reflects "(This Character)" must suppress.
local newAcctStatus = HA.SourceManager:GetCompletionStatus(999125, "achievement", { achievementID = 901 })
assert(newAcctStatus and newAcctStatus.suffix == " (This Character)",
    "the completion cache must be refreshed to This Character after the invalidate wipe")
local firesAfterAcctPromotion = invalidationFires
send("ACHIEVEMENT_EARNED", 901)
assert(invalidationFires == firesAfterAcctPromotion,
    "re-firing once the cache already reflects This Character must suppress")

-- (8d) Fail open: non-number payload must invalidate, never silently skip.
local firesBeforeAchFailOpen = invalidationFires
send("ACHIEVEMENT_EARNED", "unexpected")
assert(invalidationFires == firesBeforeAchFailOpen + 1,
    "non-number achievementID payload must fail open and invalidate")

-- (8f) MUTATION-CRITICAL (Argus Gate 1 cycles 2 AND 3): a NAME-ONLY
-- achievement requirement -- the shape 100% of Data/PrerequisiteSources.lua's
-- 109 achievement requirements use (consumed via Tooltips.lua's prerequisite
-- display, not the availability path) -- baselines under
-- "achievement:"..name, never "achievement:"..id. Cycle 2: an id-only lookup
-- silently missed these entirely. Cycle 3: the "fix" resolved the name from
-- GetAchievementInfo's LIVE return value -- which is locale-translated,
-- while req.name is Homestead's hardcoded English -- so on any non-English
-- client the two strings never matched and the bug reproduced exactly.
--
-- To prove locale independence, the stub's live name for 950 deliberately
-- DIFFERS from the addon-internal English name ("Zandalar Forever!", stored
-- in both the requirement and HA.AchievementSources) -- simulating a
-- non-English client. Invalidation must arrive through the addon-internal
-- English-to-English name->id resolution ONLY; any implementation that
-- builds a key or comparison from the live API name fails here. (Cycle 3's
-- meta-lesson, baked in: the old version of this test fed ONE string into
-- both sides of the comparison, which can never prove the two sides agree.)
achievementNames[950] = "LIVE-LOCALE Zandalar (nicht Englisch)"
achievementCompletion[950] = { completed = false, wasEarnedByMe = false }
local nameOnlyReq = { type = "achievement", name = "Zandalar Forever!" }
assert(HA.SourceManager:IsRequirementMet(nameOnlyReq) == false)
local firesBeforeNameFlip = invalidationFires
send("ACHIEVEMENT_EARNED", 950)
assert(invalidationFires == firesBeforeNameFlip,
    "re-firing before the underlying completion actually changes must still suppress (name-keyed baseline)")
assert(lastDebugMessage and lastDebugMessage:find("ACHIEVEMENT_EARNED") and not lastDebugMessage:find("UPDATE_FACTION"),
    "the suppress-path debug line for an unflipped name-keyed baseline must name ACHIEVEMENT_EARNED, not UPDATE_FACTION")
achievementCompletion[950].completed = true
send("ACHIEVEMENT_EARNED", 950)
assert(invalidationFires == firesBeforeNameFlip + 1,
    "a flipped NAME-KEYED achievement baseline must invalidate")

-- Re-firing after the name-keyed baseline was re-verified must suppress
-- (same write-back discipline as the id-keyed case above).
local firesAfterNameFlip = invalidationFires
send("ACHIEVEMENT_EARNED", 950)
assert(invalidationFires == firesAfterNameFlip,
    "re-firing after the name-keyed baseline was already re-verified must suppress")

-- (8g) COST REGRESSION PIN (Argus Gate 1 cycle 1 CRITICAL): with achievement
-- baselines seeded above (700, and the availability-path baseline it left
-- behind), UPDATE_FACTION must NOT re-evaluate any of them -- achievement
-- verdicts are looked up by their OWN key from the ACHIEVEMENT_EARNED branch
-- only, never via the shared reputation/professionRank counter every
-- UPDATE_FACTION/profession-event fire runs. A prior draft added
-- "achievement" to that shared counter's type filter, which called
-- GetAchievementInfo once per achievement baseline on EVERY UPDATE_FACTION
-- fire for zero information (measured: 158 calls/fire on the real
-- AchievementSources corpus) -- this pins that it stays at zero here.
local achievementInfoCallsBeforeUpdateFaction = achievementInfoCalls
send("UPDATE_FACTION")
assert(achievementInfoCalls == achievementInfoCallsBeforeUpdateFaction,
    "UPDATE_FACTION must never call GetAchievementInfo -- achievement baselines are not in its scan scope")

-------------------------------------------------------------------------------
-- (9) MAJOR_FACTION_RENOWN_LEVEL_CHANGED gates (HS-283, second pass). Renown
-- is already type="reputation" (Gate 0), so this reuses the same counter
-- UPDATE_FACTION uses -- these tests confirm the debug line correctly
-- attributes the event instead of misreporting it as UPDATE_FACTION, on
-- both the suppress and invalidate paths.
-------------------------------------------------------------------------------
local renownReq = { type = "reputation", factionID = 300, renownLevel = 5 }
renownByFaction[300] = 3
assert(HA.SourceManager:IsRequirementMet(renownReq) == false)

local firesBeforeRenownNoop = invalidationFires
send("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
assert(invalidationFires == firesBeforeRenownNoop,
    "MAJOR_FACTION_RENOWN_LEVEL_CHANGED with an unchanged renown baseline must suppress")
assert(lastDebugMessage and lastDebugMessage:find("MAJOR_FACTION_RENOWN_LEVEL_CHANGED") and not lastDebugMessage:find("UPDATE_FACTION"),
    "the suppress-path debug line for renown must name MAJOR_FACTION_RENOWN_LEVEL_CHANGED, not UPDATE_FACTION")

renownByFaction[300] = 5
send("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
assert(invalidationFires == firesBeforeRenownNoop + 1,
    "a flipped renown baseline must invalidate")
assert(lastDebugMessage and lastDebugMessage:find("MAJOR_FACTION_RENOWN_LEVEL_CHANGED") and not lastDebugMessage:find("UPDATE_FACTION"),
    "the invalidate-path debug line for a renown-triggered invalidate must name MAJOR_FACTION_RENOWN_LEVEL_CHANGED, not UPDATE_FACTION")

-------------------------------------------------------------------------------
-- (10) Source pins: the pre-warm combat pause and the factionNameToID reset.
-------------------------------------------------------------------------------
local function readFile(path)
    local f = assert(io.open(path, "r"))
    local content = f:read("*a")
    f:close()
    return content
end

local badgeSource = readFile(root .. "/UI/BadgeCalculation.lua")
assert(badgeSource:find("if _G%.InCombatLockdown%(%) then%s+C_Timer%.After%(WARMUP_COMBAT_RETRY_DELAY, ProcessBatch%)") ~= nil,
    "ProcessBatch must reschedule (not run) while InCombatLockdown()")

local sourceManagerSource = readFile(root .. "/Data/SourceManager.lua")
assert(sourceManagerSource:find("local function RunFactionVerifyThenInvalidate%(eventName%)%s+eventName = eventName or \"UPDATE_FACTION\"%s+factionNameToID = nil") ~= nil,
    "verify pass must default eventName to UPDATE_FACTION and reset factionNameToID before comparing verdicts")

print("hs238_invalidation_gates: ok")
