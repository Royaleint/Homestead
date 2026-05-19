--[[
    Homestead - Options bootstrap
    Registers the native Blizzard Options frame and Settings bridge.
]]

local _, HA = ...

local function RegisterOptions()
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
