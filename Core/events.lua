--[[
    Homestead - Events
    Smart event system with throttling for performance
]]

local addonName, HA = ...

-- Create events module
local Events = {}
HA.Events = Events

-- Local references for performance
local pairs = pairs
local GetTime = GetTime
local C_Timer = C_Timer

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

-- Minimum time between updates for each update type (seconds)
local UPDATE_THROTTLE = {
    bags = 0.2,
    bank = 0.2,
    merchant = 0.1,
    auctionHouse = 0.3,
    housingCatalog = 0.2,
    tooltips = 0.05,
    default = 0.1,
}

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

-- Track last update time for each type
local lastUpdateTime = {}

-- Queue of pending updates
local pendingUpdates = {}

-- Is an update currently scheduled?
local updateScheduled = false

-- Registered callbacks for update types
local updateCallbacks = {}

-------------------------------------------------------------------------------
-- Throttled Update System
-------------------------------------------------------------------------------

-- Request an update for a specific type
function Events:RequestUpdate(updateType)
    updateType = updateType or "default"

    -- Mark this update type as pending
    pendingUpdates[updateType] = true

    -- Schedule processing if not already scheduled
    if not updateScheduled then
        updateScheduled = true
        C_Timer.After(0, function()
            Events:ProcessPendingUpdates()
        end)
    end
end

-- Process all pending updates
function Events:ProcessPendingUpdates()
    updateScheduled = false

    local currentTime = GetTime()

    for updateType, isPending in pairs(pendingUpdates) do
        if isPending then
            local throttle = UPDATE_THROTTLE[updateType] or UPDATE_THROTTLE.default
            local lastTime = lastUpdateTime[updateType] or 0

            if currentTime - lastTime >= throttle then
                -- Enough time has passed, execute the update
                lastUpdateTime[updateType] = currentTime
                pendingUpdates[updateType] = false
                self:ExecuteUpdate(updateType)
            else
                -- Not enough time passed, reschedule
                if not updateScheduled then
                    updateScheduled = true
                    local delay = throttle - (currentTime - lastTime)
                    C_Timer.After(delay, function()
                        Events:ProcessPendingUpdates()
                    end)
                end
            end
        end
    end
end

-- Execute callbacks for an update type
function Events:ExecuteUpdate(updateType)
    local callbacks = updateCallbacks[updateType]
    if callbacks then
        for _, callback in pairs(callbacks) do
            local success, err = pcall(callback)
            if not success then
                HA.Addon:Debug("Error in update callback for", updateType, ":", err)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Callback Registration
-------------------------------------------------------------------------------

-- Register a callback for an update type
function Events:RegisterCallback(updateType, callbackFunc)
    if not updateCallbacks[updateType] then
        updateCallbacks[updateType] = {}
    end
    table.insert(updateCallbacks[updateType], callbackFunc)
end

-- Unregister all callbacks for an update type
function Events:UnregisterCallbacks(updateType)
    updateCallbacks[updateType] = nil
end

-- Fire an event immediately (bypass throttling for custom events)
function Events:Fire(eventName, ...)
    local callbacks = updateCallbacks[eventName]
    if callbacks then
        local args = {...}
        for _, callback in pairs(callbacks) do
            local success, err = pcall(function()
                callback(unpack(args))
            end)
            if not success and HA.Addon then
                HA.Addon:Debug("Error in event callback for", eventName, ":", err)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Frame-Based Update System
-- For UI elements that need per-frame updates with throttling
-------------------------------------------------------------------------------

local frameUpdateData = {}

-- Check if a frame should update (used in OnUpdate handlers)
function Events:ShouldFrameUpdate(frameID, elapsed)
    local data = frameUpdateData[frameID]
    if not data then
        frameUpdateData[frameID] = {
            elapsed = 0,
            throttle = UPDATE_THROTTLE.default,
        }
        data = frameUpdateData[frameID]
    end

    data.elapsed = data.elapsed + elapsed
    if data.elapsed >= data.throttle then
        data.elapsed = 0
        return true
    end
    return false
end

-- Set the throttle rate for a specific frame
function Events:SetFrameThrottle(frameID, throttle)
    if not frameUpdateData[frameID] then
        frameUpdateData[frameID] = {
            elapsed = 0,
            throttle = throttle,
        }
    else
        frameUpdateData[frameID].throttle = throttle
    end
end

-- Clean up frame data when frame is no longer needed
function Events:CleanupFrameData(frameID)
    frameUpdateData[frameID] = nil
end

-------------------------------------------------------------------------------
-- Busy/Loading Detection
-- Prevent updates during loading screens
-------------------------------------------------------------------------------

local isLoading = false

function Events:SetLoading(loading)
    isLoading = loading
end

function Events:IsLoading()
    return isLoading
end

-- Run a function only if not loading
function Events:RunIfNotBusy(func)
    if isLoading then
        -- Schedule for later
        C_Timer.After(0.5, function()
            Events:RunIfNotBusy(func)
        end)
    else
        func()
    end
end

-------------------------------------------------------------------------------
-- Smart Event Registration
-- Wraps standard event registration with loading awareness
-------------------------------------------------------------------------------

local smartEventHandlers = {}

function Events:RegisterSmartEvent(eventName, handler)
    smartEventHandlers[eventName] = smartEventHandlers[eventName] or {}
    table.insert(smartEventHandlers[eventName], handler)
end

function Events:FireSmartEvent(eventName, ...)
    if isLoading then return end

    local handlers = smartEventHandlers[eventName]
    if handlers then
        for _, handler in pairs(handlers) do
            local success, err = pcall(handler, ...)
            if not success then
                HA.Addon:Debug("Error in smart event handler for", eventName, ":", err)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function Events:Initialize()
    -- Register for loading screen events
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("LOADING_SCREEN_ENABLED")
    frame:RegisterEvent("LOADING_SCREEN_DISABLED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "LOADING_SCREEN_ENABLED" then
            Events:SetLoading(true)
        elseif event == "LOADING_SCREEN_DISABLED" then
            Events:SetLoading(false)
            -- Process any pending updates after loading
            C_Timer.After(0.5, function()
                Events:ProcessPendingUpdates()
            end)
        end
    end)
end

-- Initialize immediately
Events:Initialize()
