--[[
    Homestead - Options bootstrap
    Registers the native Blizzard Options frame and Settings bridge.
]]

local _, HA = ...

local function RegisterOptions()
    -- HS-217: this bootstrap runs on its own C_Timer.After(0, ...), independent
    -- of the Foundry.Lifecycle OnEnable chain (see core.lua's OnEnable gate) —
    -- a DevBuild-collision session would otherwise still reach
    -- OptionsFrame:Initialize() here and throw on the duplicate
    -- F.Settings:New("Homestead") registration. OptionsFrame:Initialize()
    -- carries the same gate for any other call path (Open/Toggle).
    if HA.__collisionStandDown then
        return
    end
    if HA.OptionsFrame and HA.OptionsFrame.Initialize then
        HA.OptionsFrame:Initialize()
    end
    if HA.Addon and HA.Addon.Debug then
        HA.Addon:Debug("Native options registered")
    end
end

if HA.Addon then
    C_Timer.After(0, RegisterOptions)
else
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        RegisterOptions()
    end)
end
