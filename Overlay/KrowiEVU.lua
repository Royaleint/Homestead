--[[
    Homestead - Krowi's Extended Vendor UI Overlays
    Paints merchant markers on the item slots Krowi's Extended Vendor UI draws
    in place of Blizzard's MerchantItem buttons. Inert when it is not installed.
]]

local _, HA = ...

local Overlay = HA.Overlay

local pairs = pairs

local ADDON_NAME = "Krowi_ExtendedVendorUI"
local BUYBACK_TAB = 2

-- Slots handed to us by Krowi, kept so ownership changes can repaint them.
local trackedSlots = {}
local isRegistered = false
local waitFrame

local function IsAddonLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    elseif IsAddOnLoaded then
        return IsAddOnLoaded(name)
    end
    return false
end

local function PaintSlot(slot, index)
    local button = slot.ItemButton
    if not button then return end

    local merchant = Overlay.Merchant
    if not merchant then return end

    -- Buyback indices are not vendor stock; never decorate them as decor wares.
    if index and MerchantFrame and MerchantFrame.selectedTab == BUYBACK_TAB then
        index = nil
    end

    merchant.UpdateButton(button, index)
end

local plugin = {}

function plugin:OnItemSlotUpdated(slot, index)
    if not slot then return end
    trackedSlots[slot] = true
    PaintSlot(slot, index)
end

local function RefreshSlots()
    for slot in pairs(trackedSlots) do
        if slot:IsShown() and slot.ItemButton then
            local index = slot.ItemButton:GetID()
            if not index or index < 1 then
                index = nil
            end
            PaintSlot(slot, index)
        end
    end
end

local function Register()
    if isRegistered then return true end

    local api = KrowiEVU and KrowiEVU.PluginsApi
    if not api or not api.RegisterPlugin then return false end

    api:RegisterPlugin("Homestead", plugin)
    isRegistered = true
    Overlay:RegisterExternalRefresher("krowiEVU", RefreshSlots)

    if HA.Addon then
        HA.Addon:Debug("Krowi's Extended Vendor UI plugin registered")
    end
    return true
end

local function Initialize()
    if isRegistered or waitFrame then return end

    if IsAddonLoaded(ADDON_NAME) and Register() then
        return
    end

    waitFrame = CreateFrame("Frame")
    waitFrame:RegisterEvent("ADDON_LOADED")
    waitFrame:SetScript("OnEvent", function(self, _, addonName)
        if addonName == ADDON_NAME and Register() then
            self:UnregisterAllEvents()
            waitFrame = nil
        end
    end)
end

if HA.Addon then
    C_Timer.After(0, Initialize)
else
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", Initialize)
end
