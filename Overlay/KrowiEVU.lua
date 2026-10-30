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

-- Slots handed to us by Krowi, mapped to the merchant index it last drew in
-- them (false for an empty slot), so ownership changes can repaint them.
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
    trackedSlots[slot] = index or false
    PaintSlot(slot, index)
end

local function RefreshSlots()
    if not (MerchantFrame and MerchantFrame:IsShown()) then return end

    for slot, index in pairs(trackedSlots) do
        if slot:IsVisible() then
            PaintSlot(slot, index or nil)
        end
    end
end

local function Register()
    if isRegistered then return true end

    local api = KrowiEVU and KrowiEVU.PluginsApi
    if not api or not api.RegisterPlugin then return false end

    local success, err = pcall(api.RegisterPlugin, api, "Homestead", plugin)
    if not success then
        if HA.Addon then
            HA.Addon:Debug("Failed to register Krowi's Extended Vendor UI plugin:", err)
        end
        return false
    end

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
