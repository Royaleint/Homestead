-- luacheck: globals assert loadfile print CreateFrame C_NeighborhoodInitiative C_Timer

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-215: NEIGHBORHOOD_INITIATIVE_UPDATED must never re-request
--
-- Loads the REAL Data/EndeavorsData.lua module against a minimal WoW stub,
-- captures the real OnEvent handler, and fires it directly. Before the fix,
-- every event (including NEIGHBORHOOD_INITIATIVE_UPDATED, the RESPONSE to a
-- request) called RequestNeighborhoodInitiativeInfo again — an infinite
-- server-paced loop. This pins: NEIGHBORHOOD_INITIATIVE_UPDATED consumes
-- (GetNeighborhoodInitiativeInfo) but never requests; PLAYER_ENTERING_WORLD
-- still requests+refreshes plus its two timer retries.
-------------------------------------------------------------------------------

local capturedFrame = nil
local scheduledTimers = {}

CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript(_, handler)
        self.handler = handler
    end
    capturedFrame = frame
    return frame
end

C_Timer = {
    After = function(_, fn)
        table.insert(scheduledTimers, fn)
    end,
}

local requestCalls = 0
local getInfoCalls = 0

C_NeighborhoodInitiative = {
    RequestNeighborhoodInitiativeInfo = function()
        requestCalls = requestCalls + 1
        return true
    end,
    -- nil is a valid response (RefreshActiveTheme early-returns on it) —
    -- keeps this test focused on request-vs-refresh call counts, not theme
    -- parsing.
    GetNeighborhoodInitiativeInfo = function()
        getInfoCalls = getInfoCalls + 1
        return nil
    end,
    IsInitiativeEnabled = function() return true end,
    PlayerHasInitiativeAccess = function() return true end,
}

local HA = {
    Addon = {
        db = { profile = {}, global = {} },
        RegisterModule = function() end,
        Debug = function() end,
    },
}

assert(loadfile(root .. "/Data/EndeavorsData.lua"))("Homestead", HA)
HA.EndeavorsData:Initialize()

assert(capturedFrame ~= nil, "Initialize must create and register the event frame")
assert(capturedFrame.handler ~= nil, "OnEvent handler must be set")

-- Initialize() itself requests+refreshes once synchronously.
assert(requestCalls == 1, "Initialize must request once")
assert(getInfoCalls == 1, "Initialize must refresh once")

-- The response arriving: NEIGHBORHOOD_INITIATIVE_UPDATED must consume
-- (refresh) WITHOUT issuing a new request — this is the fix under test.
capturedFrame.handler(capturedFrame, "NEIGHBORHOOD_INITIATIVE_UPDATED")
assert(requestCalls == 1, "NEIGHBORHOOD_INITIATIVE_UPDATED must NOT request — it IS the response")
assert(getInfoCalls == 2, "NEIGHBORHOOD_INITIATIVE_UPDATED must still refresh/consume the data")

-- Firing it repeatedly (simulating the confirmed live loop symptom) must
-- never accumulate additional requests.
capturedFrame.handler(capturedFrame, "NEIGHBORHOOD_INITIATIVE_UPDATED")
capturedFrame.handler(capturedFrame, "NEIGHBORHOOD_INITIATIVE_UPDATED")
assert(requestCalls == 1, "repeated NEIGHBORHOOD_INITIATIVE_UPDATED fires must never request")
assert(getInfoCalls == 4, "each fire still refreshes")

-- PLAYER_ENTERING_WORLD keeps request+refresh plus its two timer retries.
capturedFrame.handler(capturedFrame, "PLAYER_ENTERING_WORLD")
assert(requestCalls == 2, "PLAYER_ENTERING_WORLD must still request")
assert(getInfoCalls == 5, "PLAYER_ENTERING_WORLD must still refresh")
assert(#scheduledTimers == 2, "PLAYER_ENTERING_WORLD must still schedule its two retries")

for _, fn in ipairs(scheduledTimers) do
    fn()
end
assert(requestCalls == 4, "both PLAYER_ENTERING_WORLD retries must still request")
assert(getInfoCalls == 7, "both PLAYER_ENTERING_WORLD retries must still refresh")

print("hs215_endeavor_loop: ok")
