-- luacheck: globals assert loadfile print table select CreateFrame C_Timer C_HousingCatalog

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-283 sub-item C: HOUSING_DECOR_PLACE_SUCCESS/HOUSING_DECOR_REMOVED are
-- ownership-neutral (placement/removal only moves an item between
-- totalNumStored/remainingRedeemable/totalNumPlaced -- the sum
-- ComputeOwnedFromInfo checks for ownership never changes), so they no
-- longer request a catalog rescan. HOUSING_STORAGE_UPDATED and
-- NEW_HOUSING_ITEM_ACQUIRED still do -- those can carry real ownership
-- changes.
--
-- The observable is a fake C_Timer.NewTimer call count, NOT whether the
-- local RequestScan() wrapper ran -- RequestScan debounces through
-- C_Timer.NewTimer(1.0, ...), so a test that only checks the wrapper would
-- still pass even with the guard deleted (the same loose-test trap sub-item
-- D's Gate 1 review caught on its visibility guard). Loads the REAL
-- Modules/CatalogScanner.lua, captures the real event frame's OnEvent
-- handler, and fires it directly.
-------------------------------------------------------------------------------

local newTimerCalls = 0
C_Timer = {
    After = function() end,
    NewTimer = function()
        newTimerCalls = newTimerCalls + 1
        return { Cancel = function() end }
    end,
}

-- HOUSING_STORAGE_UPDATED's handler calls TryLatchWarmFromCounts(), which
-- reads these two directly (not itself guarded by "C_HousingCatalog and").
C_HousingCatalog = {
    GetDecorTotalOwnedCount = function() return 0 end,
    GetDecorMaxOwnedCount = function() return 0 end,
}

-- Capture every frame created during Initialize(), with its registered
-- events and OnEvent script, so the test can identify the housing-event
-- scanning frame (as opposed to SetupLoginForceLoad's PLAYER_ENTERING_WORLD
-- frame) and deliver events to it by hand.
local createdFrames = {}
CreateFrame = function()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(handler, fn) self.scripts[handler] = fn end
    createdFrames[#createdFrames + 1] = frame
    return frame
end

local debugMessages = {}
local HA = {
    Constants = { Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
    Addon = {
        db = { profile = {}, global = {} },
        RegisterModule = function() end,
        Debug = function(_, ...)
            local parts = {}
            for i = 1, select("#", ...) do
                parts[i] = tostring((select(i, ...)))
            end
            debugMessages[#debugMessages + 1] = table.concat(parts, " ")
        end,
    },
}

assert(loadfile(root .. "/Modules/CatalogScanner.lua"))("Homestead", HA)
HA.CatalogScanner:Initialize()

local eventFrame
for _, frame in ipairs(createdFrames) do
    if frame.events["HOUSING_DECOR_PLACE_SUCCESS"] then eventFrame = frame end
end
assert(eventFrame, "the housing-event scanning frame was not created/captured")
assert(eventFrame.events["HOUSING_STORAGE_UPDATED"], "HOUSING_STORAGE_UPDATED not registered")
assert(eventFrame.events["NEW_HOUSING_ITEM_ACQUIRED"], "NEW_HOUSING_ITEM_ACQUIRED not registered")
assert(eventFrame.events["HOUSING_DECOR_REMOVED"], "HOUSING_DECOR_REMOVED not registered")

local function send(event, ...)
    debugMessages = {}
    eventFrame.scripts.OnEvent(eventFrame, event, ...)
end

-------------------------------------------------------------------------------
-- (1) HOUSING_DECOR_PLACE_SUCCESS / HOUSING_DECOR_REMOVED: ownership-neutral,
-- must NOT request a scan (zero C_Timer.NewTimer calls).
-------------------------------------------------------------------------------
local before = newTimerCalls
send("HOUSING_DECOR_PLACE_SUCCESS")
assert(newTimerCalls == before, "HOUSING_DECOR_PLACE_SUCCESS must not request a catalog scan")
assert(debugMessages[1] and debugMessages[1]:find("skipping scan"),
    "HOUSING_DECOR_PLACE_SUCCESS must log a debug suppression line")

before = newTimerCalls
send("HOUSING_DECOR_REMOVED")
assert(newTimerCalls == before, "HOUSING_DECOR_REMOVED must not request a catalog scan")
assert(debugMessages[1] and debugMessages[1]:find("skipping scan"),
    "HOUSING_DECOR_REMOVED must log a debug suppression line")

-------------------------------------------------------------------------------
-- (2) HOUSING_STORAGE_UPDATED / NEW_HOUSING_ITEM_ACQUIRED: real ownership
-- changes are possible, must still request a scan (one C_Timer.NewTimer call).
-------------------------------------------------------------------------------
before = newTimerCalls
send("HOUSING_STORAGE_UPDATED")
assert(newTimerCalls == before + 1, "HOUSING_STORAGE_UPDATED must still request a catalog scan")

before = newTimerCalls
send("NEW_HOUSING_ITEM_ACQUIRED")
assert(newTimerCalls == before + 1, "NEW_HOUSING_ITEM_ACQUIRED must still request a catalog scan")

print("hs283_catalog_scan_relevance: ok")
