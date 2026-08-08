-- luacheck: globals assert loadfile print io C_Traits Enum CreateFrame time LibStub C_AddOns C_Timer GetProfessions GetProfessionInfo

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-214: TRAIT_CONFIG_UPDATED invalidation trigger, filtered to
-- Enum.TraitConfigType.Profession. Loads the REAL Data/SourceManager.lua,
-- captures the real event frame's OnEvent handler, and fires it directly.
--
-- HS-283: past the type filter, a profession-type config update no longer
-- invalidates unconditionally — it routes through the same professionRank/
-- profession-availability verify-then-skip gate SKILL_LINES_CHANGED's
-- changed-fingerprint path and NEW_RECIPE_LEARNED use. A minimal profession
-- stub + a seeded professionRank baseline below let the "must invalidate"
-- case demonstrate a real flip, same pattern as
-- tests/hs213_skill_lines_gate.lua and tests/hs283_profession_invalidation_gates.lua.
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

Enum = { TraitConfigType = { Invalid = 0, Combat = 1, Profession = 2, Generic = 3 } }

local blacksmithingSkillLevel = 50
GetProfessions = function() return 1, nil, nil, nil, nil end
GetProfessionInfo = function(profIndex)
    if profIndex ~= 1 then return nil end
    return "Blacksmithing", "icon", blacksmithingSkillLevel, 100, 0, 0, 164
end

-- Mutable per-configID response the mocked C_Traits API reports.
local configResponses = {
    [100] = { type = Enum.TraitConfigType.Profession },
    [200] = { type = Enum.TraitConfigType.Combat },
}

C_Traits = {
    GetConfigInfo = function(configID)
        local response = configResponses[configID]
        if response == "error" then
            error("simulated API failure")
        end
        return response
    end,
}

local invalidateCalls = 0
local HA214 = {
    Constants = { Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
    Addon = {
        db = { profile = {}, global = { parsedSources = {} } },
        RegisterModule = function() end,
        Debug = function() end,
    },
}

assert(loadfile(root .. "/Data/SourceManager.lua"))("Homestead", HA214)
HA214.SourceManager:Initialize()

assert(capturedFrame ~= nil and capturedFrame.handler ~= nil, "the invalidation frame's OnEvent handler must be captured")

local realInvalidate = HA214.SourceManager.InvalidateAllSourceCaches
HA214.SourceManager.InvalidateAllSourceCaches = function(...)
    invalidateCalls = invalidateCalls + 1
    return realInvalidate(...)
end

-- Baseline established by Initialize()'s own SKILL_LINES_CHANGED-adjacent
-- setup; reset the counter to isolate TRAIT_CONFIG_UPDATED behavior.
invalidateCalls = 0

-- HS-283: seed a professionRank baseline unmet at the current skill level,
-- then bump the skill so the first "must invalidate" fire below also flips
-- a consumer-visible verdict — otherwise the new verify-then-skip gate would
-- correctly (and silently) suppress an event with nothing baselined.
assert(HA214.SourceManager:IsRequirementMet({ type = "professionRank", profession = "Blacksmithing", rank = 51 }) == false)
blacksmithingSkillLevel = 51

-- Profession-type config that also flips a seeded verdict: must invalidate.
capturedFrame.handler(capturedFrame, "TRAIT_CONFIG_UPDATED", 100)
assert(invalidateCalls == 1, "a profession-type trait config update that flips a verdict must invalidate")

-- Combat-type config: must NOT invalidate (this is the noise the filter exists to exclude).
capturedFrame.handler(capturedFrame, "TRAIT_CONFIG_UPDATED", 200)
assert(invalidateCalls == 1, "a combat-type trait config update must NOT invalidate")

-- Nil info (unknown configID): must NOT invalidate (fail closed on the filter).
capturedFrame.handler(capturedFrame, "TRAIT_CONFIG_UPDATED", 999)
assert(invalidateCalls == 1, "a nil configInfo must NOT invalidate")

-- API failure (GetConfigInfo throws): must NOT invalidate, and must not
-- propagate the error (pcall-guarded).
configResponses[300] = "error"
local ok = pcall(function()
    capturedFrame.handler(capturedFrame, "TRAIT_CONFIG_UPDATED", 300)
end)
assert(ok, "a throwing GetConfigInfo must not propagate an error out of the event handler")
assert(invalidateCalls == 1, "a failed GetConfigInfo read must NOT invalidate")

-- Other registered events remain unconditional, unaffected by this filter.
capturedFrame.handler(capturedFrame, "ACHIEVEMENT_EARNED")
assert(invalidateCalls == 2, "ACHIEVEMENT_EARNED must remain unconditional")

print("hs_x1_batch: HS-214 TRAIT_CONFIG_UPDATED filter ok")

-------------------------------------------------------------------------------
-- HS-220: the Blizzard_Housing ADDON_LOADED one-shot scan must route through
-- RequestScan(), not a direct separately-timed ScanFullCatalog() call.
-- (Extends the ground tests/hs216_warm_scan.lua covers for the 3s timer with
-- a pin for this second scan trigger.)
-------------------------------------------------------------------------------

local scannerSource = assert(io.open(root .. "/Modules/CatalogScanner.lua", "r")):read("*a")

local addonLoadedBody = scannerSource:match(
    'if loadedAddon and loadedAddon:match%("%^Blizzard_Housing"%) then(.-)\n            end')
assert(addonLoadedBody ~= nil, "could not isolate the Blizzard_Housing ADDON_LOADED branch")
assert(addonLoadedBody:find('RequestScan%(%)', 1) ~= nil,
    "the Blizzard_Housing one-shot scan must route through RequestScan()")
assert(addonLoadedBody:find('CatalogScanner:ScanFullCatalog%(%)', 1) == nil,
    "the Blizzard_Housing one-shot scan must NOT call ScanFullCatalog() directly anymore")

print("hs_x1_batch: HS-220 Blizzard_Housing scan routing pin ok")

-------------------------------------------------------------------------------
-- HS-221: InitializeMinimapButton must be gated on HA.__collisionStandDown;
-- nothing else in OnInitialize should be newly gated by this batch.
-------------------------------------------------------------------------------

local coreSource = assert(io.open(root .. "/Core/core.lua", "r")):read("*a")

local minimapGateBody = coreSource:match(
    '%-%- Initialize minimap button%.(.-)\n    end')
assert(minimapGateBody ~= nil, "could not isolate the InitializeMinimapButton call site")
assert(minimapGateBody:find('if not HA%.__collisionStandDown then', 1) ~= nil,
    "InitializeMinimapButton must be gated on HA.__collisionStandDown")
assert(minimapGateBody:find('self:InitializeMinimapButton%(%)', 1) ~= nil,
    "the gate must actually wrap the InitializeMinimapButton call")

print("hs_x1_batch: HS-221 collision-standdown gate pin ok")

-------------------------------------------------------------------------------
-- HS-211: BetterBags registration retry — VERDICT: the pre-existing shape
-- was the Baganator-style DEAD RETRY (gated on addonName == "BetterBags", a
-- one-shot event that never fires again on failure), NOT "retry until
-- success" as Argus's cycle-1 note claimed. Fixed to mirror
-- Overlay/Baganator.lua's WaitForBaganator: reattempt on ANY subsequent
-- ADDON_LOADED, relying on HookIntegration's own isHooked self-guard.
-- Executable: loads the REAL Overlay/BetterBags.lua, simulates BetterBags's
-- own AceAddon modules being unavailable on the FIRST unrelated
-- ADDON_LOADED fire (proving the old addonName=="BetterBags" gate would
-- have missed this), then available on a LATER, unrelated ADDON_LOADED fire
-- — confirming the fix actually retries and then stops.
-------------------------------------------------------------------------------

local bbCapturedFrame = nil
local unregisterAllEventsCalls = 0

CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:UnregisterAllEvents()
        unregisterAllEventsCalls = unregisterAllEventsCalls + 1
    end
    function frame:SetScript(_, handler)
        self.handler = handler
    end
    if not bbCapturedFrame then
        bbCapturedFrame = frame
    end
    return frame
end

local modulesAvailable = false

LibStub = function(name, silent)
    if name ~= "AceAddon-3.0" then return nil end
    return {
        GetAddon = function(_, addonName, silentInner)
            if addonName ~= "BetterBags" or not modulesAvailable then return nil end
            return {
                GetModule = function(_, moduleName)
                    return {
                        RegisterMessage = function() end,
                        SendMessage = function() end,
                    }
                end,
            }
        end,
    }
end

C_AddOns = { IsAddOnLoaded = function() return false end }
C_Timer = { After = function(_, fn) fn() end }

local BBHA = {
    Constants = { Overlay = { ICON_SIZE = 14 } },
    Addon = {
        db = { profile = {} },
        RegisterModule = function() end,
        Debug = function() end,
    },
}

assert(loadfile(root .. "/Overlay/BetterBags.lua"))("Homestead", BBHA)

assert(bbCapturedFrame ~= nil and bbCapturedFrame.handler ~= nil,
    "BetterBags' wait frame OnEvent handler must be captured")

-- First fire: an UNRELATED addon loads (not "BetterBags"), and BetterBags'
-- own modules are still unavailable. Old code ignored this entirely
-- (gated on addonName == "BetterBags"); fixed code retries and, since
-- modules aren't ready, does NOT unregister.
bbCapturedFrame.handler(bbCapturedFrame, "ADDON_LOADED", "SomeOtherAddon")
assert(unregisterAllEventsCalls == 0,
    "must not unregister while BetterBags' own modules are still unavailable")

-- BetterBags' modules become available later (simulating its own deferred
-- AceAddon module registration) — but note NO ADDON_LOADED("BetterBags")
-- ever fires again in this scenario, matching the confirmed dead-retry gap:
-- the OLD code (gated on addonName == "BetterBags") would never retry here.
modulesAvailable = true

-- A LATER, unrelated ADDON_LOADED fire must still retry successfully and
-- THEN unregister — proving the fix actually retries on any subsequent
-- ADDON_LOADED, not just BetterBags' own.
bbCapturedFrame.handler(bbCapturedFrame, "ADDON_LOADED", "AnotherAddon")
assert(unregisterAllEventsCalls == 1,
    "a later, unrelated ADDON_LOADED must succeed once modules are available and then unregister")
-- (In-game, UnregisterAllEvents() means this handler simply stops receiving
-- ADDON_LOADED at all, so there's no real "double-unregister" case to
-- simulate here by calling the captured handler function directly again.)

print("hs_x1_batch: HS-211 BetterBags retry-on-any-ADDON_LOADED ok")
