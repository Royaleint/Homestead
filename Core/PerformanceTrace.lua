--[[
    Homestead - Performance Trace Facade (HS-239)

    Public, always-shipped facade for measuring bounded Homestead operations.
    In player builds this is a transparent pass-through: Measure() always
    runs its callback directly and preserves every return value unchanged.
    It does not measure, retain history, allocate a ring, or change callback
    behavior on its own -- it adds no SavedVariables and does nothing but
    forward the call until a backend is registered.

    The Homestead_DevBuild's Homestead_Dev addon registers a measurement
    backend via SetBackend at load time. Only then does Measure route
    through bounded, outside-combat C_AddOnProfiler observation. Player
    builds never load that backend, so this file is the whole story for
    them.
]]

local _, HA = ...

local PerformanceTrace = {}
HA.PerformanceTrace = PerformanceTrace

-- nil until a DevBuild registers one (see Home_Dev/Homestead_Dev/PerformanceTrace.lua).
local backend = nil

-- Register (or clear, with nil) the DevBuild measurement backend. Only the
-- DevBuild's own PerformanceTrace module ever calls this.
function PerformanceTrace:SetBackend(newBackend)
    backend = newBackend
end

-- Measure(operation, workload, callback, ...) ALWAYS runs callback(...) and
-- preserves every return value, in every build. `operation` names the
-- approved boundary (e.g. "bag_refresh"); `workload` is whatever cheap,
-- already-known value the call site can supply describing this invocation
-- (a count, an id, a label) -- never a value computed by a new scan just to
-- feed this call.
function PerformanceTrace:Measure(operation, workload, callback, ...)
    if backend then
        return backend:Observe(operation, workload, callback, ...)
    end
    return callback(...)
end
