-- WagoAnalytics shim — no-op stub for CurseForge and local-dev builds.
-- On Wago distributions the real WagoAnalytics library loads via
-- OptionalDependencies and this file is not needed.
if LibStub:GetLibrary("WagoAnalytics", true) then return end

local lib = LibStub:NewLibrary("WagoAnalytics", 1)
if not lib then return end

function lib:Register()
    return {}
end
