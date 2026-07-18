-- luacheck: globals assert loadfile print io next

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-217 Item B: staged-only vendors must survive the map-pin getters.
-- BuildIndexes() already indexes StagedAdditions vendors into ByMapID/
-- ByExpansion; the getters' render-time lookup used to check self.Vendors
-- alone and silently drop them. VendorIdentity.lua is self-contained (only
-- reads HA.Constants optionally), so this loads and exercises it directly
-- rather than via source-text assertion.
-------------------------------------------------------------------------------

local HA = {}
assert(loadfile(root .. "/Data/VendorIdentity.lua"))("Homestead", HA)

local VI = HA.VendorIdentity
assert(VI ~= nil, "expected VendorIdentity.lua to register HA.VendorIdentity")

-- Inject a staged-only vendor (no baseline Vendors[9999001] row), exactly the
-- shape VendorStagedAdditions.lua produces, then rebuild indexes the same way
-- that file does after appending rows.
local STAGED_NPC_ID = 9999001
VI.StagedAdditions = {
    [STAGED_NPC_ID] = {
        name = "Test Staged Vendor",
        mapID = 2351,
        x = 0.5, y = 0.5,
        faction = "Neutral",
        expansion = "Midnight",
        unreleased = true,
    },
}
VI:BuildIndexes()

-- Sanity: GetVendor already had the StagedAdditions fallback before this fix —
-- confirms the injected row is visible at all before testing the two getters
-- that were missing it.
assert(VI:GetVendor(STAGED_NPC_ID) ~= nil, "sanity: GetVendor should already see the staged vendor")

local byMap = VI:GetVendorsByMapID(2351)
local foundByMap = false
for _, v in ipairs(byMap) do
    if v.name == "Test Staged Vendor" then foundByMap = true end
end
assert(foundByMap, "GetVendorsByMapID must return a staged-only vendor indexed under its mapID")

local byExpansion = VI:GetVendorsByExpansion("Midnight")
local foundByExpansion = false
for _, v in ipairs(byExpansion) do
    if v.name == "Test Staged Vendor" then foundByExpansion = true end
end
assert(foundByExpansion, "GetVendorsByExpansion must return a staged-only vendor indexed under its expansion")

-- Regression: a baseline (non-staged) vendor must still resolve — the fix
-- must not have inverted lookup priority (self.Vendors first, StagedAdditions
-- only as fallback, matching GetVendor's own order).
local anyBaselineNpcID = next(VI.Vendors)
assert(anyBaselineNpcID ~= nil, "expected at least one baseline vendor in VendorIdentity.Vendors to test against")
local baselineVendor = VI.Vendors[anyBaselineNpcID]
if baselineVendor.mapID then
    local baselineByMap = VI:GetVendorsByMapID(baselineVendor.mapID)
    local foundBaseline = false
    for _, v in ipairs(baselineByMap) do
        if v == baselineVendor then foundBaseline = true end
    end
    assert(foundBaseline, "GetVendorsByMapID must still return baseline (non-staged) vendors")
end

print("hs217_w3: Item B staged-vendor map-pin fallback ok")

-------------------------------------------------------------------------------
-- HS-217 Item A: VersionCheck no longer registers the guild hello on
-- PLAYER_LOGIN (dead: Initialize() itself runs from within PLAYER_LOGIN's own
-- dispatch via core.lua OnEnable, so a frame registering for PLAYER_LOGIN
-- there never receives that firing). The hello now sends from
-- PLAYER_ENTERING_WORLD behind a once-per-session flag, and the reply delay
-- is jittered instead of a fixed 3s.
-------------------------------------------------------------------------------

local versionCheckSource = assert(io.open(root .. "/Modules/VersionCheck.lua", "r")):read("*a")

assert(versionCheckSource:find('frame:RegisterEvent%("PLAYER_LOGIN"%)', 1) == nil,
    "VersionCheck must no longer register a frame for PLAYER_LOGIN (it never fires there)")

assert(versionCheckSource:find('frame:RegisterEvent%("PLAYER_ENTERING_WORLD"%)', 1) ~= nil,
    "expected PLAYER_ENTERING_WORLD to still be registered")

assert(versionCheckSource:find('guildHelloSent', 1) ~= nil,
    "expected a once-per-session guildHelloSent flag (PLAYER_ENTERING_WORLD re-fires every loading screen)")

-- Argus cycle 1: the flag must be consumed only INSIDE the guild check, so a
-- cold-login IsInGuild()==false doesn't spend it and skip the hello all session.
assert(versionCheckSource:find('if not guildHelloSent and IsInGuild and IsInGuild%(%) then%s+guildHelloSent = true%s+SendHello%("GUILD"%)', 1) ~= nil,
    "expected the guildHelloSent flag to be set only inside the IsInGuild branch")
assert(versionCheckSource:find('if not guildHelloSent then%s+guildHelloSent = true', 1) == nil,
    "the flag-before-guild-check shape must not return (cold-login lag would spend the flag)")

-- Jitter: REPLY_DELAY_MIN/MAX replace the old fixed REPLY_DELAY, and OnHello
-- computes a randomized delay rather than passing a constant to C_Timer.After.
assert(versionCheckSource:find('REPLY_DELAY_MIN', 1) ~= nil and versionCheckSource:find('REPLY_DELAY_MAX', 1) ~= nil,
    "expected a min/max jitter range to replace the fixed REPLY_DELAY")
assert(versionCheckSource:find('math%.random%(%)', 1) ~= nil,
    "expected OnHello to compute a randomized reply delay")
assert(versionCheckSource:find('C_Timer%.After%(REPLY_DELAY,', 1) == nil,
    "OnHello must no longer schedule against the old fixed REPLY_DELAY constant")

-- Per-channel suppression must still be intact (replyScheduled set before the
-- timer, cleared inside it) — jitter must not have disturbed the guard.
assert(versionCheckSource:find('if replyScheduled%[channel%] then return end', 1) ~= nil,
    "expected the per-channel reply-scheduled suppression guard to still be present")

print("hs217_w3: Item A guild-hello event move + jitter ok")

-------------------------------------------------------------------------------
-- HS-217 Item C: DevBuild collision poison flag consumers.
-- The generator (Home_Dev/scripts/generate-devbuild-toc.mjs, nested repo —
-- not testable from this harness) now emits HA.__collisionStandDown = true
-- into the generated DevBuildGuard.lua. These are the bootstrap consumers
-- that must early-return on it.
-------------------------------------------------------------------------------

local coreSource = assert(io.open(root .. "/Core/core.lua", "r")):read("*a")
assert(coreSource:find('function HousingAddon:OnEnable%(%)%s+%-%- HS%-217', 1) ~= nil,
    "expected OnEnable's poison-flag gate to be the first thing in the function")
assert(coreSource:find('if HA%.__collisionStandDown then%s+return%s+end', 1) ~= nil,
    "expected OnEnable to early-return on HA.__collisionStandDown")

local optionsSource = assert(io.open(root .. "/UI/Options.lua", "r")):read("*a")
assert(optionsSource:find('if HA%.__collisionStandDown then%s+return%s+end', 1) ~= nil,
    "expected the Options.lua RegisterOptions bootstrap to early-return on HA.__collisionStandDown")

local optionsFrameSource = assert(io.open(root .. "/UI/OptionsFrame.lua", "r")):read("*a")
assert(optionsFrameSource:find('function OptionsFrame:Initialize%(%)%s+%-%- HS%-217', 1) ~= nil,
    "expected OptionsFrame:Initialize to gate on the poison flag as its first action")
assert(optionsFrameSource:find('if HA%.__collisionStandDown then%s+return frame%s+end', 1) ~= nil,
    "expected OptionsFrame:Initialize to early-return on HA.__collisionStandDown")

-- (Low) F.Settings binding now fails loud like the List/Menu/Lifecycle/DB
-- call sites, instead of silently degrading with a still-logged "success".
assert(optionsFrameSource:find('local Settings = F:RequireModule%("Settings", 1%)', 1) ~= nil,
    "expected the Settings module binding to use RequireModule (fail loud)")
assert(optionsFrameSource:find('Settings:New%({', 1) ~= nil,
    "expected settingsController to be built from the RequireModule-bound Settings, not F.Settings directly")

print("hs217_w3: Item C poison-flag consumers + Settings fail-loud ok")
