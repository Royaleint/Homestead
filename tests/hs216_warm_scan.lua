-- luacheck: globals assert loadfile print io C_NeighborhoodInitiative

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-216 item A: the initial (3s) catalog scan must not run cold.
--
-- A full functional harness for CatalogScanner's Initialize() is impractical
-- (heavy WoW surface: CreateFrame event registration, C_Timer chains,
-- C_HousingCatalog per-item probing) — per the handoff, a source-text pin on
-- the warm-check inside the timer callback is the pragmatic minimum. Escaped
-- parens throughout (unescaped parens silently never match Lua patterns).
-------------------------------------------------------------------------------

local scannerSource = assert(io.open(root .. "/Modules/CatalogScanner.lua", "r")):read("*a")

-- The 3s initial-scan timer body must check IsWarm%(%) and return before
-- ever reaching ScanFullCatalog when cold.
local timerBody = scannerSource:match(
    'C_Timer%.After%(3, function%(%)(.-)\n    end%)')
assert(timerBody ~= nil, "could not isolate the 3s initial-scan timer callback in CatalogScanner.lua")
assert(timerBody:find('CatalogScanner:IsWarm%(%)', 1) ~= nil,
    "the 3s initial-scan timer must check CatalogScanner:IsWarm()")
assert(timerBody:find('return', 1) ~= nil,
    "the 3s initial-scan timer must return (skip the scan) when not warm")

print("hs216_warm_scan: item A warm-check pin ok")

-------------------------------------------------------------------------------
-- HS-216 item B: RefreshActiveTheme logs "active theme" only when it
-- CHANGED. Loads the REAL Data/EndeavorsData.lua, captures the real
-- NEIGHBORHOOD_INITIATIVE_UPDATED handler, and fires it with controllable
-- C_NeighborhoodInitiative responses — this executes the actual logging
-- gate, not a source-grep.
-------------------------------------------------------------------------------

-- luacheck: globals CreateFrame
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

local currentInfo = { isLoaded = true, title = "T1", vendorNPCID = 111 }

C_NeighborhoodInitiative = {
    GetNeighborhoodInitiativeInfo = function() return currentInfo end,
    IsInitiativeEnabled = function() return true end,
    PlayerHasInitiativeAccess = function() return true end,
}

local themeLogCalls = 0

local HA = {
    Addon = {
        db = { profile = { debug = true }, global = {} },
        RegisterModule = function() end,
        Debug = function(_, msg)
            if msg == "EndeavorsData: active theme:" or msg == "EndeavorsData: active theme unknown" then
                themeLogCalls = themeLogCalls + 1
            end
        end,
    },
}

assert(loadfile(root .. "/Data/EndeavorsData.lua"))("Homestead", HA)
HA.EndeavorsData.NPCToTheme[111] = "ThemeA"
HA.EndeavorsData.NPCToTheme[222] = "ThemeB"

HA.EndeavorsData:Initialize()
assert(capturedFrame ~= nil and capturedFrame.handler ~= nil, "Initialize must capture the event handler")

-- Initialize() itself calls RefreshActiveTheme("Initialize") once, resolving
-- ThemeA for the first time (activeTheme nil -> "ThemeA") — that's the
-- initial changed=true log.
assert(themeLogCalls == 1, "the first-ever theme resolution must log once")

-- Same info, same NPC (a NEIGHBORHOOD_INITIATIVE_UPDATED consume with no
-- actual theme change — the unsolicited-spam case this fix targets) must
-- NOT log again.
capturedFrame.handler(capturedFrame, "NEIGHBORHOOD_INITIATIVE_UPDATED")
assert(themeLogCalls == 1, "an unchanged-theme consume must not log again")
capturedFrame.handler(capturedFrame, "NEIGHBORHOOD_INITIATIVE_UPDATED")
assert(themeLogCalls == 1, "repeated unchanged-theme consumes must never log")

-- A real theme change (different NPC/title) must log again.
currentInfo = { isLoaded = true, title = "T2", vendorNPCID = 222 }
capturedFrame.handler(capturedFrame, "NEIGHBORHOOD_INITIATIVE_UPDATED")
assert(themeLogCalls == 2, "a real theme change must log")

-- Back to the (now current) unchanged theme — no further log.
capturedFrame.handler(capturedFrame, "NEIGHBORHOOD_INITIATIVE_UPDATED")
assert(themeLogCalls == 2, "an unchanged theme after a real change must still not log")

print("hs216_warm_scan: item B theme-change-only logging ok")
