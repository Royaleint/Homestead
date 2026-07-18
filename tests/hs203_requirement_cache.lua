-- luacheck: globals assert loadfile print C_QuestLog

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-203 (1): shared requirement met/unmet cache
--
-- SourceManager:IsRequirementMet is the live-probe entry point used by badge
-- recounts, tooltips, the map side panel, and vendor availability checks
-- (EvaluateRequirementAvailability -> IsRequirementMet per requirement, per
-- item). A "quest" requirement is the simplest to mock: it depends on one
-- global, C_QuestLog.IsQuestFlaggedCompleted. The call counter below proves
-- the second (and third) call for the SAME requirement identity is served
-- from cache, and that InvalidateAllSourceCaches (the function every one of
-- the five trigger-class events already calls) forces a re-evaluation.
-------------------------------------------------------------------------------

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

local req = { type = "quest", id = 500 }

assert(HA.SourceManager:IsRequirementMet(req) == true)
assert(HA.SourceManager:IsRequirementMet(req) == true)
assert(HA.SourceManager:IsRequirementMet(req) == true)
assert(questCheckCalls == 1, "expected the quest check to run once, then be served from cache")

-- A DIFFERENT requirement identity (different questID) must not hit the
-- first requirement's cache entry, and must probe live once for itself.
local otherReq = { type = "quest", id = 999 }
assert(HA.SourceManager:IsRequirementMet(otherReq) == false)
assert(questCheckCalls == 2)

-- InvalidateAllSourceCaches is what every one of the five trigger-class
-- events (ACHIEVEMENT_EARNED, QUEST_TURNED_IN, UPDATE_FACTION /
-- MAJOR_FACTION_RENOWN_LEVEL_CHANGED, NEW_RECIPE_LEARNED / SKILL_LINES_
-- CHANGED, ACTIVE_HOLIDAYS_CHANGED) already calls — confirm it wipes the new
-- cache too, forcing re-evaluation.
HA.SourceManager:InvalidateAllSourceCaches()
assert(HA.SourceManager:IsRequirementMet(req) == true)
assert(questCheckCalls == 3, "expected re-evaluation after invalidation")

-------------------------------------------------------------------------------
-- HS-203 (2): vendorMapPin context never reaches a fresh ownership probe
-- (stub-to-error pattern from the hs200 test)
-------------------------------------------------------------------------------

local freshProbeCalls = 0

local PinHA = {
    Constants = { Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
    Addon = {
        db = { profile = {}, global = { parsedSources = {} } },
        RegisterModule = function() end,
        Debug = function() end,
    },
    CatalogStore = {
        IsOwned = function(_, itemID)
            return itemID == 3001
        end,
        IsOwnedFresh = function()
            freshProbeCalls = freshProbeCalls + 1
            error("vendorMapPin hover must not make a fresh ownership probe")
        end,
        GetRequirements = function() return nil end,
    },
}

assert(loadfile(root .. "/Data/SourceManager.lua"))("Homestead", PinHA)

local ownedPin = PinHA.SourceManager:GetItemPresentation(3001, { context = "vendorMapPin", npcID = 777 })
assert(ownedPin.isOwned == true)

local unownedPin = PinHA.SourceManager:GetItemPresentation(3002, { context = "vendorMapPin", npcID = 777 })
assert(unownedPin.isOwned == false)

assert(freshProbeCalls == 0)

print("hs203_requirement_cache: ok")
