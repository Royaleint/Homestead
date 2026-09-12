-- luacheck: globals assert loadfile print io CreateFrame GetProfessions GetProfessionInfo C_TradeSkillUI InCombatLockdown

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-306: RunProfessionVerifyThenInvalidate's profSourceAvail baseline used to
-- get seeded and re-verified regardless of whether C_TradeSkillUI's profession
-- data had actually loaded this session. Live testing (Leatherworking,
-- skillLineID 165, 2026-09-12) confirmed GetProfessionInfoBySkillLineID
-- returns a HOLLOW record (skillLevel=0) for a genuinely-trained profession
-- before the trade skill window is ever opened, and real data (skillLevel=173)
-- after -- persisting even once the window closes again. Cycle-1's fix gated
-- on C_TradeSkillUI.IsTradeSkillReady() (the window's live open/closed UI
-- state), which review caught reading false in BOTH the pre-load case AND the
-- loaded-then-closed case -- it cannot tell them apart, so that gate was
-- checking the wrong signal entirely.
--
-- This test proves the redesigned gate, driven by a TRADE_SKILL_SHOW-flipped
-- professionDataLoaded flag instead:
--   (1) a pre-load live evaluation (the badge-prewarm pass) sees the hollow
--       skillLevel=0 read and must NOT seed the verify-gate baseline;
--   (2) a gated event firing before TRADE_SKILL_SHOW has ever fired suppresses
--       outright (nothing to compare yet, no crash);
--   (3) Critical (cycle-1 review): once TRADE_SKILL_SHOW fires and real data
--       is available, a fresh availability check must return the CORRECTED
--       answer with NO test-only manual cache-clear -- the fix's own
--       one-time invalidate must be what corrects it;
--   (4) TRADE_SKILL_SHOW firing again later (window reopened) must not
--       re-invalidate a second time -- the flip is one-time only;
--   (5) must-FAIL-if-broken: post-load, no change, a gated event suppresses;
--   (6) must-FAIL-if-broken: post-load, a genuine skill-level drop still
--       invalidates -- the verify-then-skip gate itself still works, it is
--       not just disabled;
--   (7) CYCLE-2 REVIEW (Argus mutation, cycle 2): cases (1)-(6) alone don't
--       cover the professionDataLoaded gate itself -- case (3) always calls
--       IsSourceAvailableNow right after TRADE_SKILL_SHOW, which re-seeds
--       professionAvailBaseline with the correct post-load verdict before
--       any gated event runs, papering over a missing gate. This isolated
--       case (own fresh module load, no read between the load transition
--       and the next gated event) proves the gate itself is load-bearing:
--       with it removed, a stale pre-load baseline produces a second,
--       spurious invalidate that this case must catch.
-------------------------------------------------------------------------------

-- One primary profession (Blacksmithing), matching hs283's setup --
-- window-independent per GetProfessions/GetProfessionInfo, unaffected by
-- this bug (PlayerHasProfession never reads C_TradeSkillUI).
GetProfessions = function() return 1, nil, nil, nil, nil end
GetProfessionInfo = function(profIndex)
    if profIndex ~= 1 then return nil end
    return "Blacksmithing", "icon", 50, 100, 0, 0, 164
end

-- C_TradeSkillUI: skillLevel (player progress) reads hollow (0) until the
-- profession data loads, matching the live probe exactly -- that's the
-- field PlayerMeetsSkillLevel actually reads and compares. professionName is
-- kept intact throughout as a simplifying stub choice (its own pre-load
-- behavior wasn't part of what the live probe measured), so the stub isn't
-- overclaiming beyond what was confirmed. IsTradeSkillReady tracks the
-- window's own open/closed state, independent of whether the data has
-- loaded (also confirmed live -- it read false in both the pre-load and
-- loaded-then-closed cases).
local tradeSkillWindowOpen = false
local tradeSkillLines = {
    [9001] = { professionName = "Test Tier", skillLevel = 0 },
}
C_TradeSkillUI = {
    IsTradeSkillReady = function() return tradeSkillWindowOpen end,
    GetAllProfessionTradeSkillLines = function()
        local ids = {}
        for id in pairs(tradeSkillLines) do ids[#ids + 1] = id end
        return ids
    end,
    GetProfessionInfoBySkillLineID = function(id) return tradeSkillLines[id] end,
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

local gatedEventFrame, tradeSkillShowFrame
for _, frame in ipairs(createdFrames) do
    if frame.events["SKILL_LINES_CHANGED"] then gatedEventFrame = frame end
    if frame.events["TRADE_SKILL_SHOW"] then tradeSkillShowFrame = frame end
end
assert(gatedEventFrame, "gated-event invalidation frame not created")
assert(tradeSkillShowFrame, "TRADE_SKILL_SHOW frame not created")

local function sendGatedEvent(event, ...)
    gatedEventFrame.scripts.OnEvent(gatedEventFrame, event, ...)
end

local function sendTradeSkillShow()
    tradeSkillShowFrame.scripts.OnEvent(tradeSkillShowFrame)
end

local sourceData = { profession = "Blacksmithing", skillTier = "Test Tier", skillLevel = 20 }
local source = { type = "profession", data = sourceData }

-------------------------------------------------------------------------------
-- (1) Login, profession data NOT yet loaded: the badge-prewarm pass
-- evaluates this source. skillLevel reads 0 (hollow) -- available reads
-- false. Must NOT seed the profSourceAvail verify-gate baseline.
-------------------------------------------------------------------------------
local prewarmAvailable = HA.SourceManager:IsSourceAvailableNow(9001, source)
assert(prewarmAvailable == false,
    "pre-load read should see the hollow skillLevel=0 and treat the tier as unmet")

-------------------------------------------------------------------------------
-- (2) A gated event fires before TRADE_SKILL_SHOW has ever fired. With no
-- baseline seeded yet, the gate must suppress outright (not crash, not
-- false-positive on empty data).
-------------------------------------------------------------------------------
sendGatedEvent("NEW_RECIPE_LEARNED", 1, 1, 1)
assert(invalidationFires == 0, "gated event pre-load, nothing captured yet, must suppress")

-------------------------------------------------------------------------------
-- (3) CRITICAL (cycle-1 review): the trade skill window opens for the first
-- time this session. Real data becomes available (skillLevel jumps to 25,
-- genuinely meeting the required 20) -- simulating what the live probe
-- observed. TRADE_SKILL_SHOW must trigger the fix's own one-time invalidate;
-- a fresh read of the SAME item, with NO test-only manual cache-clear, must
-- come back corrected.
-------------------------------------------------------------------------------
tradeSkillWindowOpen = true
tradeSkillLines[9001].skillLevel = 25
sendTradeSkillShow()
assert(invalidationFires == 1,
    "TRADE_SKILL_SHOW must invalidate once on the load transition to correct any pre-load-derived cache entries")

local postLoadAvailable = HA.SourceManager:IsSourceAvailableNow(9001, source)
assert(postLoadAvailable == true,
    "post-load read of the SAME item must come back corrected via the fix's own invalidate, " ..
    "not a manually-forced cache clear (tier now genuinely met: 25 >= 20)")

-------------------------------------------------------------------------------
-- (4) TRADE_SKILL_SHOW fires again later (window reopened, nothing changed).
-- The one-time flag must not invalidate a second time.
-------------------------------------------------------------------------------
tradeSkillWindowOpen = false
sendTradeSkillShow()
tradeSkillWindowOpen = true
sendTradeSkillShow()
assert(invalidationFires == 1, "TRADE_SKILL_SHOW must only invalidate once per session, not on every fire")

-------------------------------------------------------------------------------
-- (5) Must-FAIL-if-broken: post-load, closing the window and firing a gated
-- event with nothing actually changed must still suppress (the verify-gate
-- baseline itself, now populated with real data, must behave correctly).
-------------------------------------------------------------------------------
tradeSkillWindowOpen = false
sendGatedEvent("NEW_RECIPE_LEARNED", 2, 1, 1)
assert(invalidationFires == 1, "post-load, window closed, nothing changed -- must suppress")

-------------------------------------------------------------------------------
-- (6) Must-FAIL-if-broken: a genuine skill-level drop, post-load, must still
-- invalidate -- proves the gate is a real verify-then-skip, not disabled.
-------------------------------------------------------------------------------
tradeSkillLines[9001].skillLevel = 10 -- drops below the required 20
sendGatedEvent("NEW_RECIPE_LEARNED", 3, 1, 1)
assert(invalidationFires == 2,
    "a genuine post-load profession-availability flip must still invalidate")

-------------------------------------------------------------------------------
-- (7) CYCLE-2 REVIEW (Argus mutation, cycle 2): isolated fresh module load
-- so this case isn't helped by any earlier case's own live reads. Cases
-- (1)-(6) above all call IsSourceAvailableNow right after TRADE_SKILL_SHOW,
-- which re-seeds professionAvailBaseline with the correct post-load verdict
-- BEFORE any gated event runs -- papering over a missing gate. This case
-- reproduces Argus's exact discriminating sequence instead: a pre-load
-- IsSourceAvailableNow call, then the underlying skill genuinely changes,
-- then TRADE_SKILL_SHOW fires (the one-time load invalidate), then a gated
-- event fires with NO IsSourceAvailableNow call in between. Without the
-- professionDataLoaded gate on the baseline write/compare, the stale
-- pre-load baseline (available=false) would still be sitting in
-- professionAvailBaseline and would compare against the fresh live read
-- (available=true) inside CountChangedProfessionAvailability, producing a
-- SECOND, spurious invalidate -- confirmed by Argus via mutation
-- (`if professionDataLoaded then` -> `if true then` at the baseline write,
-- and deleting CountChangedProfessionAvailability's own
-- `if not professionDataLoaded then return 0, 0 end` short-circuit: fires
-- went 1 -> 2). invalidationFires must stay at 1 here (only the load
-- transition's own invalidate).
-------------------------------------------------------------------------------
do
    GetProfessions = function() return 1, nil, nil, nil, nil end
    GetProfessionInfo = function(profIndex)
        if profIndex ~= 1 then return nil end
        return "Blacksmithing", "icon", 50, 100, 0, 0, 164
    end

    local lines = { [9002] = { professionName = "Case7 Tier", skillLevel = 0 } }
    local windowOpen = false
    C_TradeSkillUI = {
        IsTradeSkillReady = function() return windowOpen end,
        GetAllProfessionTradeSkillLines = function()
            local ids = {}
            for id in pairs(lines) do ids[#ids + 1] = id end
            return ids
        end,
        GetProfessionInfoBySkillLineID = function(id) return lines[id] end,
    }

    local frames = {}
    CreateFrame = function()
        local frame = { events = {}, scripts = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:SetScript(handler, fn) self.scripts[handler] = fn end
        frames[#frames + 1] = frame
        return frame
    end

    local fires = 0
    local caseHA = {
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
                    fires = fires + 1
                end
            end,
        },
    }

    assert(loadfile(root .. "/Data/SourceManager.lua"))("Homestead", caseHA)
    caseHA.SourceManager:Initialize()

    local caseGatedFrame, caseLoadFrame
    for _, frame in ipairs(frames) do
        if frame.events["SKILL_LINES_CHANGED"] then caseGatedFrame = frame end
        if frame.events["TRADE_SKILL_SHOW"] then caseLoadFrame = frame end
    end
    assert(caseGatedFrame, "case 7: gated-event frame not created")
    assert(caseLoadFrame, "case 7: TRADE_SKILL_SHOW frame not created")

    local caseSourceData = { profession = "Blacksmithing", skillTier = "Case7 Tier", skillLevel = 20 }
    local caseSource = { type = "profession", data = caseSourceData }

    -- Pre-load read: hollow skillLevel=0, tier not met -> available=false.
    -- Must NOT seed professionAvailBaseline (professionDataLoaded is false).
    local preLoad = caseHA.SourceManager:IsSourceAvailableNow(9002, caseSource)
    assert(preLoad == false, "case 7: pre-load read should see the hollow skillLevel=0")

    -- The underlying skill genuinely changes while still pre-load -- nothing
    -- has re-read it yet, so nothing observes this change until later.
    lines[9002].skillLevel = 25

    -- Window opens: TRADE_SKILL_SHOW fires the one-time load invalidate.
    windowOpen = true
    caseLoadFrame.scripts.OnEvent(caseLoadFrame)
    assert(fires == 1, "case 7: TRADE_SKILL_SHOW must invalidate exactly once on the load transition")

    -- A gated event fires immediately -- deliberately NO IsSourceAvailableNow
    -- call in between, so professionAvailBaseline is exactly whatever the
    -- write-side gate left it as.
    caseGatedFrame.scripts.OnEvent(caseGatedFrame, "NEW_RECIPE_LEARNED", 1, 1, 1)
    assert(fires == 1,
        "case 7: a gated event right after the load transition, with no intervening " ..
        "IsSourceAvailableNow call, must NOT invalidate a second time -- the " ..
        "professionDataLoaded gate on the baseline write is what prevents the stale " ..
        "pre-load baseline from ever existing to be compared")

    print("hs306_verify_gate_window_state: case 7 (professionDataLoaded gate itself) ok")
end

print("hs306_verify_gate_window_state: ok")
