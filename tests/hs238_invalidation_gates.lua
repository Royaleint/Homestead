-- luacheck: globals assert loadfile print io C_QuestLog C_MajorFactions CreateFrame InCombatLockdown

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
-------------------------------------------------------------------------------

-- Mutable WoW API state the handlers read.
local renownByFaction = { [100] = 3 }   -- factionID -> current renown level
local completedQuests = { [500] = true }
local inCombat = false

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

local HA = {
    Constants = { Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
    Addon = {
        db = { profile = {}, global = { parsedSources = {} } },
        RegisterModule = function() end,
        Debug = function() end,
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
-- (7) Source pins: the pre-warm combat pause and the factionNameToID reset.
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
assert(sourceManagerSource:find("local function RunFactionVerifyThenInvalidate%(%)%s+factionNameToID = nil") ~= nil,
    "verify pass must reset factionNameToID before comparing verdicts")

print("hs238_invalidation_gates: ok")
