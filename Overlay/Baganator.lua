--[[
    Homestead - Baganator Overlay Integration
    Adds decor status icons to Baganator item buttons via Corner Widget API
]]

local _, HA = ...

local DecorTracker = HA.DecorTracker
local Constants = HA.Constants
local Overlay = HA.Overlay

local OVERLAY_CONFIG = Constants.Overlay or {
    ICON_SIZE = 14,
}

local WIDGET_ID = "HomesteadDecorStatus"
local WIDGET_NAME = "Homestead: Decor Status"

local isRegistered = false
local waitFrame = nil
local registeredCorner = nil

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function IsAddonLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    elseif IsAddOnLoaded then
        return IsAddOnLoaded(name)
    end
    return false
end

local function GetWidgetCorner()
    local anchor = OVERLAY_CONFIG.DEFAULT_ANCHOR or "TOPLEFT"
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile and HA.Addon.db.profile.overlay then
        anchor = HA.Addon.db.profile.overlay.iconAnchor or anchor
    end

    if anchor == "TOPRIGHT" then
        return "top_right"
    elseif anchor == "BOTTOMLEFT" then
        return "bottom_left"
    elseif anchor == "BOTTOMRIGHT" then
        return "bottom_right"
    end

    return "top_left"
end

local function IsBankBagID(bagID)
    if type(bagID) ~= "number" then
        return false
    end
    if not Enum or not Enum.BagIndex then
        return false
    end

    local bagIndex = Enum.BagIndex
    local characterBankMain = bagIndex.Characterbanktab or bagIndex.CharacterBank
    return bagID == bagIndex.Bank
        or bagID == bagIndex.Reagentbank
        or bagID == bagIndex.BankBag_1
        or bagID == bagIndex.BankBag_2
        or bagID == bagIndex.BankBag_3
        or bagID == bagIndex.BankBag_4
        or bagID == bagIndex.BankBag_5
        or bagID == bagIndex.BankBag_6
        or bagID == bagIndex.BankBag_7
        or (characterBankMain and bagID == characterBankMain)
        or bagID == bagIndex.CharacterBankTab_1
        or bagID == bagIndex.CharacterBankTab_2
        or bagID == bagIndex.CharacterBankTab_3
        or bagID == bagIndex.CharacterBankTab_4
        or bagID == bagIndex.CharacterBankTab_5
        or bagID == bagIndex.CharacterBankTab_6
        or bagID == bagIndex.AccountBankTab_1
        or bagID == bagIndex.AccountBankTab_2
        or bagID == bagIndex.AccountBankTab_3
        or bagID == bagIndex.AccountBankTab_4
        or bagID == bagIndex.AccountBankTab_5
end

local function IsContextEnabled(profile, details)
    local settings = profile and profile.overlay
    if not settings then
        return false
    end

    local bagID = details and details.itemLocation and details.itemLocation.bagID
    if bagID == nil then
        -- Cached/offline data may not include itemLocation; show if either bag
        -- surface is enabled to avoid false negatives.
        return settings.showOnBags or settings.showOnBank
    end

    if IsBankBagID(bagID) then
        return settings.showOnBank
    end

    return settings.showOnBags
end

local function RefreshWidgets()
    if not isRegistered then return end
    if not Baganator or not Baganator.API or not Baganator.API.RequestItemButtonsRefresh then
        return
    end

    if Baganator.Constants and Baganator.Constants.RefreshReason
            and Baganator.Constants.RefreshReason.ItemWidgets then
        Baganator.API.RequestItemButtonsRefresh({ Baganator.Constants.RefreshReason.ItemWidgets })
    else
        Baganator.API.RequestItemButtonsRefresh()
    end
end

-------------------------------------------------------------------------------
-- Corner Widget Callbacks
-------------------------------------------------------------------------------

local function InitWidget(itemButton)
    local tex = itemButton:CreateTexture(nil, "OVERLAY")
    local iconSize = OVERLAY_CONFIG.ICON_SIZE or 14
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile and HA.Addon.db.profile.overlay then
        iconSize = HA.Addon.db.profile.overlay.iconSize or iconSize
    end
    tex:SetSize(iconSize, iconSize)
    return tex
end

local function ClearWidget(cornerFrame)
    if not cornerFrame then
        return
    end
    cornerFrame:SetTexture(nil)
    cornerFrame:SetVertexColor(1, 1, 1, 1)
end

local function UpdateWidget(cornerFrame, details)
    -- Button widgets are recycled by bag addons; clear stale texture state first.
    ClearWidget(cornerFrame)

    if not HA.Addon or not HA.Addon.db or not HA.Addon.db.profile then
        return false
    end

    local profile = HA.Addon.db.profile
    local settings = profile.overlay
    if not settings or not settings.enabled then
        return false
    end

    if not IsContextEnabled(profile, details) then
        return false
    end

    if not DecorTracker then
        return false
    end

    local itemLink = details and details.itemLink
    if not itemLink then
        -- Keep cleared state now, but allow Baganator to retry once link data resolves.
        if details and details.itemID then
            return nil
        end
        return false
    end

    if not DecorTracker:IsDecorItem(itemLink) then
        return false
    end

    local iconTexture = DecorTracker:GetStatusIcon(itemLink)
    if not iconTexture then
        return false
    end

    cornerFrame:SetTexture(iconTexture)
    cornerFrame:SetSize(settings.iconSize or OVERLAY_CONFIG.ICON_SIZE, settings.iconSize or OVERLAY_CONFIG.ICON_SIZE)

    local color = DecorTracker:GetStatusColor(itemLink)
    if color then
        cornerFrame:SetVertexColor(color.r, color.g, color.b, color.a or 1)
    else
        cornerFrame:SetVertexColor(1, 1, 1, 1)
    end

    return true
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

local function RegisterWidget()
    if isRegistered then return true end

    if not Baganator or not Baganator.API or not Baganator.API.RegisterCornerWidget then
        return false
    end

    registeredCorner = GetWidgetCorner()

    local success, err = pcall(function()
        Baganator.API.RegisterCornerWidget(
            WIDGET_NAME,
            WIDGET_ID,
            UpdateWidget,
            InitWidget,
            {
                corner = registeredCorner,
                priority = 5,
            }
        )
    end)

    if not success then
        if HA.Addon then
            HA.Addon:Debug("Failed to register Baganator corner widget:", err)
        end
        return false
    end

    isRegistered = true
    if Overlay and Overlay.RegisterExternalRefresher then
        Overlay:RegisterExternalRefresher("baganator", RefreshWidgets)
    end

    if HA.Addon then
        HA.Addon:Debug("Baganator corner widget registered", registeredCorner)
    end
    return true
end

local function WaitForBaganator()
    if waitFrame then
        return
    end

    waitFrame = CreateFrame("Frame")
    waitFrame:RegisterEvent("ADDON_LOADED")
    waitFrame:SetScript("OnEvent", function(self, _, addonName)
        if addonName ~= "Baganator" then
            return
        end

        RegisterWidget()
        self:UnregisterAllEvents()
        waitFrame = nil
    end)
end

local function Initialize()
    if IsAddonLoaded("Baganator") then
        RegisterWidget()
        return
    end

    WaitForBaganator()
end

if HA.Addon then
    C_Timer.After(0, Initialize)
else
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", Initialize)
end
