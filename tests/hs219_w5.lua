-- luacheck: globals assert loadfile print io loadstring C_Timer mockWelcomeFrame

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-219 Item 1: WelcomeFrame's "Don't show this again" checkbox must
-- actually gate the seen flag. WelcomeFrame.lua never calls CreateFrame at
-- file scope (only inside CreateWelcomeFrame(), invoked from :Show()), so
-- the full file isn't practical to load standalone here — but Hide() itself
-- is self-contained. Extract-and-execute it (same technique as hs202's
-- IsDecorItem test) against a fake welcomeFrame table instead of a real
-- frame, avoiding the need to mock the whole CreateFrame chrome.
-------------------------------------------------------------------------------

local welcomeSource = assert(io.open(root .. "/UI/WelcomeFrame.lua", "r")):read("*a")

local hideText = welcomeSource:match('(function WelcomeFrame:Hide%(%).-\nend)')
assert(hideText ~= nil, "could not extract WelcomeFrame:Hide from WelcomeFrame.lua")

-- Sanity: the fixed Hide() must read the checkbox, not unconditionally write true.
assert(hideText:find('dontShowCheck', 1) ~= nil,
    "expected Hide() to read the checkbox (dontShowCheck) rather than write unconditionally")
assert(hideText:find('HA%.Addon%.db%.global%[SV_KEY%] = true%s*\n%s*%-%- Set lastSeenVersion') == nil,
    "Hide() must not unconditionally set SV_KEY = true before the lastSeenVersion write")

mockWelcomeFrame = {
    Hide = function() end,
    dontShowCheck = { GetChecked = function() return false end },
}

local hideChunk = "local _, HA = ...\n"
    .. "local WelcomeFrame = {}\n"
    .. "local welcomeFrame = mockWelcomeFrame\n"
    .. 'local SV_KEY = "hasSeenWelcomeV4"\n'
    .. hideText
    .. "\nreturn WelcomeFrame"
local hideLoader = assert(loadstring(hideChunk, "WelcomeFrame-Hide-extract"))

local HA = {
    Addon = { db = { global = {} } },
    Constants = { VERSION = "2.6.0" },
}
local ExtractedWelcomeFrame = hideLoader("Homestead", HA)

-- Unchecked close: SV_KEY must stay unset so CheckFirstRun re-shows next login.
mockWelcomeFrame.dontShowCheck.GetChecked = function() return false end
HA.Addon.db.global = {}
ExtractedWelcomeFrame:Hide()
assert(HA.Addon.db.global["hasSeenWelcomeV4"] == nil,
    "an unchecked close must NOT set the seen flag — welcome must re-show next login")
assert(HA.Addon.db.global.lastSeenVersion == "2.6.0",
    "lastSeenVersion should still update regardless of the checkbox (unrelated to the reshow gate)")

-- Checked close: SV_KEY must be set.
mockWelcomeFrame.dontShowCheck.GetChecked = function() return true end
HA.Addon.db.global = {}
ExtractedWelcomeFrame:Hide()
assert(HA.Addon.db.global["hasSeenWelcomeV4"] == true,
    "a checked close MUST set the seen flag")

print("hs219_w5: Item 1 welcome checkbox gate ok")

-------------------------------------------------------------------------------
-- HS-219 Item 2: onboarding stacking gate. WhatsNewFrame.lua also never calls
-- CreateFrame at file scope (CreateWhatsNewFrame() only runs from :Show()),
-- and Initialize()'s gate check runs and returns BEFORE the first
-- C_Timer.After call when Welcome is due/shown — so the whole file loads
-- standalone, and the gate is provable just by asserting whether
-- C_Timer.After ever got called, without ever needing Show() to actually run
-- (which would require full frame mocking).
-------------------------------------------------------------------------------

local capturedCallback
C_Timer = {
    After = function(_, callback)
        capturedCallback = callback
    end,
}

local WNHA = {
    Constants = { VERSION = "2.6.0", WELCOME_SEEN_VERSION_MAX = 4, TEXTURE_ROOT = "Interface\\AddOns\\Homestead\\Textures\\" },
    Addon = { db = { global = {} }, Debug = function() end, RegisterModule = function() end },
    WhatsNew = { ["2.6.0"] = { title = "t", features = {} } },
    WelcomeFrame = { IsShown = function() return false end },
}
assert(loadfile(root .. "/UI/WhatsNewFrame.lua"))("Homestead", WNHA)

-- Case A: Welcome is DUE (current welcome version not yet seen). WhatsNew's
-- auto-popup must be skipped entirely this login — no timer scheduled.
WNHA.Addon.db.global = { lastSeenVersion = "2.5.0", suppressWhatsNewUntil = "" }
capturedCallback = nil
WNHA.WhatsNewFrame:Initialize()
assert(capturedCallback == nil,
    "WhatsNew must not schedule its auto-popup while Welcome is due")

-- Case B: Welcome is currently SHOWN (IsShown() true), even if its seen flag
-- happens to already be set. Still gated.
WNHA.Addon.db.global = { lastSeenVersion = "2.5.0", suppressWhatsNewUntil = "", ["hasSeenWelcomeV4"] = true }
WNHA.WelcomeFrame.IsShown = function() return true end
capturedCallback = nil
WNHA.WhatsNewFrame:Initialize()
assert(capturedCallback == nil,
    "WhatsNew must not schedule its auto-popup while Welcome is currently shown")

-- Case C (no-deadlock check): Welcome has been seen AND dismissed (seen flag
-- set, not currently shown) — WhatsNew must auto-popup NORMALLY, proving the
-- gate resolves rather than permanently wedging the popup off.
WNHA.WelcomeFrame.IsShown = function() return false end
capturedCallback = nil
WNHA.WhatsNewFrame:Initialize()
assert(capturedCallback ~= nil,
    "once Welcome is seen+dismissed, WhatsNew must auto-popup normally (no deadlock)")

print("hs219_w5: Item 2 onboarding stacking gate ok")

-------------------------------------------------------------------------------
-- HS-219 Item 3: v2.3.0's hero texture fields are gone, and the outgoing
-- texture file itself has been removed from disk (git rm'd), per the
-- documented asset-lifecycle rule (Textures/README.md § What's New hero
-- lifecycle).
-------------------------------------------------------------------------------

local whatsNewDataSource = assert(io.open(root .. "/UI/WhatsNewData.lua", "r")):read("*a")

local v230Block = whatsNewDataSource:match('%["2%.3%.0"%] = {(.-)\n    },')
assert(v230Block ~= nil, "could not locate the 2.3.0 WhatsNew entry")
assert(v230Block:find("heroTexture", 1) == nil, "2.3.0 entry must no longer set heroTexture")
assert(v230Block:find("heroHeight", 1) == nil, "2.3.0 entry must no longer set heroHeight")
assert(whatsNewDataSource:find("WhatsNew_v230", 1, true) == nil,
    "no reference to the retired WhatsNew_v230 texture path should remain")

local textureFile = io.open(root .. "/Textures/WhatsNew_v230.tga", "r")
assert(textureFile == nil, "Textures/WhatsNew_v230.tga must be deleted from the worktree")

print("hs219_w5: Item 3 v2.3.0 hero texture retirement ok")

-------------------------------------------------------------------------------
-- HS-219 Item 4: MinimapButton:Refresh (zero callers, confirmed via grep of
-- both this repo and Homestead_Dev) is deleted.
-------------------------------------------------------------------------------

local minimapButtonSource = assert(io.open(root .. "/UI/MinimapButton.lua", "r")):read("*a")
assert(minimapButtonSource:find("function MinimapButton:Refresh", 1, true) == nil,
    "MinimapButton:Refresh must be deleted (zero callers in the public repo or Homestead_Dev)")

print("hs219_w5: Item 4 MinimapButton:Refresh deletion ok")
