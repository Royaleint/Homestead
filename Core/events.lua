--[[
    Homestead - Events
    Smart event system with throttling for performance
]]

local _, HA = ...

local Events = {}
HA.Events = Events

-- Local references (Lua stdlib only; WoW API called directly at runtime per project rules)
local pairs = pairs

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

-- Minimum time between updates for each update type (seconds)
-- MAINTAINER WARNING: these keys (plus "all") define the closed update-type
-- namespace — RegisterCallback classifies names against this set to route
-- between throttled updates and immediate Fire events (see UPDATE_TYPES
-- below). Never name a Fire event after a key here; adding a key here
-- reclassifies any existing Fire registration of that name.
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

-- HS-209 (item 6): update types and Fire event names used to share one
-- updateCallbacks table with two different calling conventions —
-- ExecuteUpdate invokes callback() (no args), Fire invokes
-- callback(unpack(args)). Nothing collides today, but nothing PREVENTED it
-- either: a same-named update type and event would have silently shared one
-- callback list dispatched by whichever mechanism fired first. RegisterCallback
-- can't know a caller's intent from the name alone at registration time, but
-- the update-type namespace IS a fixed, closed set (UPDATE_THROTTLE's keys
-- plus "all", the broadcast-all-throttled-updates type used by
-- Overlay/overlay.lua) — every other name is, by construction, a Fire event
-- name. That's a deterministic, zero-ambiguity classification rule, so
-- RegisterCallback stays the single public entry point and routes to the
-- correct table by that rule; ExecuteUpdate only ever reads updateCallbacks,
-- Fire only ever reads eventCallbacks. A same-named collision is now
-- structurally impossible instead of merely unobserved.
local UPDATE_TYPES = {}
for updateType in pairs(UPDATE_THROTTLE) do
    UPDATE_TYPES[updateType] = true
end
UPDATE_TYPES.all = true

-- Registered callbacks for update types (throttled dispatch, ExecuteUpdate)
local updateCallbacks = {}
-- Registered callbacks for custom event names (immediate dispatch, Fire)
local eventCallbacks = {}

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
--
-- HS-209 M6: a callback invoked from ExecuteUpdate below can itself call
-- RequestUpdate, which inserts a NEW key into pendingUpdates — doing that
-- while a `pairs(pendingUpdates)` traversal over the SAME table is still in
-- flight is undefined behavior in Lua 5.1 (the manual: "the behavior of next
-- is undefined if... you assign any value to a non-existent field"). Snapshot
-- the keys pending as of the start of this pass, then iterate the snapshot;
-- anything requested mid-dispatch lands in pendingUpdates for the NEXT pass
-- (RequestUpdate's own "schedule if not already scheduled" logic, unchanged,
-- already guarantees a pass will run to pick it up).
function Events:ProcessPendingUpdates()
    updateScheduled = false

    local currentTime = GetTime()

    local snapshot = {}
    local snapshotCount = 0
    for updateType, isPending in pairs(pendingUpdates) do
        if isPending then
            snapshotCount = snapshotCount + 1
            snapshot[snapshotCount] = updateType
        end
    end

    for i = 1, snapshotCount do
        local updateType = snapshot[i]
        -- Re-check: still pending as of THIS iteration (always true in
        -- practice — nothing in this loop can clear another snapshot
        -- entry's flag — but this keeps the loop body honest about what it
        -- depends on rather than assuming it).
        if pendingUpdates[updateType] then
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

-- Register a callback for an update type OR a custom event name — single
-- public entry point, see the UPDATE_TYPES note above for how storage splits.
function Events:RegisterCallback(name, callbackFunc)
    local target = UPDATE_TYPES[name] and updateCallbacks or eventCallbacks
    if not target[name] then
        target[name] = {}
    end
    table.insert(target[name], callbackFunc)
end

-- Unregister all callbacks for an update type or event name.
function Events:UnregisterCallbacks(name)
    updateCallbacks[name] = nil
    eventCallbacks[name] = nil
end

-- Fire an event immediately (bypass throttling for custom events)
function Events:Fire(eventName, ...)
    -- Fail loud on the one mistake the closed-set classification permits:
    -- Firing an update-type name is a no-op (its callbacks live in the
    -- throttled table) and would otherwise be silent.
    if UPDATE_TYPES[eventName] and HA.Addon then
        HA.Addon:Debug("Events:Fire called with update-type name", eventName,
            "- use RequestUpdate; this Fire is a no-op")
    end
    local callbacks = eventCallbacks[eventName]
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
-- Smart Event Registration
-------------------------------------------------------------------------------
--
-- HS-209 (item 5): this module used to also carry a loading-screen busy gate
-- (SetLoading/IsLoading/RunIfNotBusy, a LOADING_SCREEN_ENABLED/DISABLED frame
-- in an Events:Initialize(), self-invoked at file scope) with zero callers —
-- RunIfNotBusy was never called anywhere, and the LOADING_SCREEN_DISABLED
-- handler's "process pending updates after loading" was a no-op flush (the
-- normal RequestUpdate/ProcessPendingUpdates path already runs regardless of
-- loading state; nothing in this file ever checked isLoading except
-- RunIfNotBusy and this FireSmartEvent guard below). Deleted rather than
-- wired in: half-built loading-gate state is worse than none — if load-screen
-- gating is needed later it should be designed against a real caller, not
-- resurrected from this dead scaffold. FireSmartEvent's isLoading check is
-- removed for the same reason (the flag it read no longer exists).
-- RegisterSmartEvent/FireSmartEvent themselves also have zero current
-- callers — separate item, left alone (not part of this batch's ask).

local smartEventHandlers = {}

function Events:RegisterSmartEvent(eventName, handler)
    smartEventHandlers[eventName] = smartEventHandlers[eventName] or {}
    table.insert(smartEventHandlers[eventName], handler)
end

function Events:FireSmartEvent(eventName, ...)
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
