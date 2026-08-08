-- luacheck: globals assert loadfile print io CreateFrame GetProfessions GetProfessionInfo C_TradeSkillUI C_Traits Enum InCombatLockdown

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-283: verify-then-skip invalidation gates for SKILL_LINES_CHANGED's
-- changed-fingerprint path, TRAIT_CONFIG_UPDATED, and NEW_RECIPE_LEARNED.
--
-- Before this fix: SKILL_LINES_CHANGED fell through to an unconditional
-- invalidate on any genuine fingerprint change (every gathering skill-up);
-- TRAIT_CONFIG_UPDATED invalidated unconditionally once past its type filter;
-- NEW_RECIPE_LEARNED had no gate at all. These tests prove the new combined
-- gate (RunProfessionVerifyThenInvalidate) suppresses when nothing a
-- consumer has seen actually changed, and — the must-FAIL-if-broken half —
-- still invalidates when a professionRank requirement OR a profession-source
-- availability verdict genuinely flips. The profession-availability half is
-- the cycle-1 adversarial review's Critical finding: professionRank alone
-- (GetProfessionInfo-sourced) is blind to the C_TradeSkillUI-sourced data
-- PlayerMeetsSkillLevel reads, which is exactly what TRAIT_CONFIG_UPDATED
-- exists to protect.
-------------------------------------------------------------------------------

-- profIndex -> {name, skillLevel, maxSkillLevel, skillLineID}. Slot 1 is a
-- primary profession (Blacksmithing); slot 4 is Fishing, with slots 2/3/5
-- left nil -- specifically to prove the professionRank ipairs nil-hole fix
-- (the archaeology slot, index 3, being nil used to stop ipairs before it
-- ever reached index 4).
local professionInfo = {
    [1] = { name = "Blacksmithing", skillLevel = 50, maxSkillLevel = 100, skillLineID = 164 },
    [4] = { name = "Fishing", skillLevel = 60, maxSkillLevel = 100, skillLineID = 356 },
}
local professionSlots = { 1, nil, nil, 4, nil }

GetProfessions = function()
    return professionSlots[1], professionSlots[2], professionSlots[3], professionSlots[4], professionSlots[5]
end

GetProfessionInfo = function(profIndex)
    local info = professionInfo[profIndex]
    if not info then return nil end
    return info.name, "icon", info.skillLevel, info.maxSkillLevel, 0, 0, info.skillLineID
end

-- C_TradeSkillUI: a data source EvaluateRequirementMetLive's professionRank
-- branch and BuildProfessionFingerprint never read -- the whole point of the
-- second baseline this ticket adds.
local tradeSkillWindowReady = true
local tradeSkillLines = {
    [356] = { professionName = "Dragonflight Fishing", skillLevel = 30 },
}
C_TradeSkillUI = {
    IsTradeSkillReady = function() return tradeSkillWindowReady end,
    GetAllProfessionTradeSkillLines = function()
        local ids = {}
        for id in pairs(tradeSkillLines) do ids[#ids + 1] = id end
        return ids
    end,
    GetProfessionInfoBySkillLineID = function(id) return tradeSkillLines[id] end,
}

local traitConfigIsProfession = true
Enum = { TraitConfigType = { Profession = 2, Combat = 1 } }
C_Traits = {
    GetConfigInfo = function()
        return { type = traitConfigIsProfession and Enum.TraitConfigType.Profession or Enum.TraitConfigType.Combat }
    end,
}

InCombatLockdown = function() return false end

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
}

assert(loadfile(root .. "/Data/SourceManager.lua"))("Homestead", HA)
HA.SourceManager:Initialize()

local invalidationFrame
for _, frame in ipairs(createdFrames) do
    if frame.events["SKILL_LINES_CHANGED"] then invalidationFrame = frame end
end
assert(invalidationFrame, "invalidation frame not created")
assert(invalidationFrame.events["TRAIT_CONFIG_UPDATED"], "TRAIT_CONFIG_UPDATED not registered")
assert(invalidationFrame.events["NEW_RECIPE_LEARNED"], "NEW_RECIPE_LEARNED not registered")

local function send(event, ...)
    invalidationFrame.scripts.OnEvent(invalidationFrame, event, ...)
end

-------------------------------------------------------------------------------
-- (1) professionRank ipairs nil-hole fix: Fishing sits at slot 4, past the
-- nil archaeology slot (3) that used to stop ipairs before it ever got there.
-------------------------------------------------------------------------------
local fishingRankReq = { type = "professionRank", profession = "Fishing", rank = 50 }
assert(HA.SourceManager:EvaluateRequirementMetLive(fishingRankReq) == true,
    "professionRank must resolve Fishing past the nil archaeology slot (skillLevel 60 >= 50)")

-------------------------------------------------------------------------------
-- (2) SKILL_LINES_CHANGED: fingerprint unchanged -> suppress (pre-existing
-- HS-213 behavior, unaffected by this change).
-------------------------------------------------------------------------------
send("SKILL_LINES_CHANGED")
assert(invalidationFires == 0, "unchanged fingerprint must suppress")

-------------------------------------------------------------------------------
-- (3) SKILL_LINES_CHANGED: fingerprint changes (a genuine skill-up) but no
-- professionRank/profession-availability verdict a consumer has seen is
-- affected -- must now suppress (this is the fix; previously fell through
-- to an unconditional invalidate here).
-------------------------------------------------------------------------------
professionInfo[1].skillLevel = 51
send("SKILL_LINES_CHANGED")
assert(invalidationFires == 0, "changed fingerprint with no flipped verdict must suppress")

-------------------------------------------------------------------------------
-- (4) SKILL_LINES_CHANGED: must-FAIL-if-broken case. Seed a professionRank
-- baseline that's unmet at the current skill level, bump the skill (changing
-- both the fingerprint and the seeded verdict), and confirm it invalidates.
-------------------------------------------------------------------------------
local blacksmithingReq = { type = "professionRank", profession = "Blacksmithing", rank = 52 }
assert(HA.SourceManager:IsRequirementMet(blacksmithingReq) == false, "51 < 52, baseline should be unmet")
professionInfo[1].skillLevel = 52
send("SKILL_LINES_CHANGED")
assert(invalidationFires == 1, "flipped professionRank verdict must invalidate")

-------------------------------------------------------------------------------
-- (5) TRAIT_CONFIG_UPDATED: non-profession trait config (combat spec) stays
-- filtered out entirely -- unaffected by this change.
-------------------------------------------------------------------------------
traitConfigIsProfession = false
send("TRAIT_CONFIG_UPDATED", 1)
assert(invalidationFires == 1, "non-profession trait config must stay filtered")

-------------------------------------------------------------------------------
-- (6) TRAIT_CONFIG_UPDATED: profession config, nothing changed -- must
-- suppress (previously unconditional once past the type filter).
-------------------------------------------------------------------------------
traitConfigIsProfession = true
send("TRAIT_CONFIG_UPDATED", 1)
assert(invalidationFires == 1, "profession trait config with no flipped verdict must suppress")

-------------------------------------------------------------------------------
-- (7) TRAIT_CONFIG_UPDATED: must-FAIL-if-broken case, and the cycle-1
-- adversarial review's Critical finding directly. Seed a profession-source
-- availability baseline via IsSourceAvailableNow, then flip the underlying
-- C_TradeSkillUI-sourced skill level -- data professionRank's baseline never
-- touches. A gate that only re-verified professionRank would silently miss
-- this and suppress; it must invalidate.
-------------------------------------------------------------------------------
local fishingSourceData = { profession = "Fishing", skillTier = "Dragonflight Fishing", skillLevel = 25 }
local available = HA.SourceManager:IsSourceAvailableNow(9001, { type = "profession", data = fishingSourceData })
assert(available == true, "tier 30 >= required 25, should be available")

tradeSkillLines[356].skillLevel = 10  -- drops below the required 25
send("TRAIT_CONFIG_UPDATED", 1)
assert(invalidationFires == 2,
    "flipped profession-source availability verdict (C_TradeSkillUI-sourced, not professionRank) must invalidate")

-------------------------------------------------------------------------------
-- (8) NEW_RECIPE_LEARNED: nothing changed -- must suppress (previously had
-- no gate at all, always invalidated).
-------------------------------------------------------------------------------
send("NEW_RECIPE_LEARNED", 12345, 1, 12345)
assert(invalidationFires == 2, "NEW_RECIPE_LEARNED with no flipped verdict must suppress")

-------------------------------------------------------------------------------
-- (9) NEW_RECIPE_LEARNED: must-FAIL-if-broken case -- a genuine flip still
-- invalidates.
-------------------------------------------------------------------------------
tradeSkillLines[356].skillLevel = 30  -- restore above the required 25 -- flips back
send("NEW_RECIPE_LEARNED", 12345, 1, 12345)
assert(invalidationFires == 3, "flipped verdict on NEW_RECIPE_LEARNED must invalidate")

print("hs283_profession_invalidation_gates: ok")
