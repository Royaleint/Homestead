--[[
    Homestead - Baganator Overlay Integration
    Adds decor status icons to Baganator item buttons via Corner Widget API
]]

local _, HA = ...

local CatalogStore = HA.CatalogStore
local Constants = HA.Constants
local Overlay = HA.Overlay
local SourceManager = HA.SourceManager

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
    local frame = CreateFrame("Frame", nil, itemButton)
    local iconSize = OVERLAY_CONFIG.ICON_SIZE or 14
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile and HA.Addon.db.profile.overlay then
        iconSize = HA.Addon.db.profile.overlay.iconSize or iconSize
    end
    frame:SetSize(iconSize, iconSize)
    -- Baganator insets corner widgets by (2, -2) by default (multiplied by
    -- this `padding` field). Setting it to 0 places our frame flush with the
    -- bag slot's corner so the OFFSET_X/Y constants control the outset.
    frame.padding = 0
    if Overlay and Overlay.EnsureHomestoneTextures then
        Overlay:EnsureHomestoneTextures(frame)
    end
    return frame
end

local function ClearWidget(cornerFrame)
    if not cornerFrame then
        return
    end
    if Overlay and Overlay.ClearHomestoneTextures then
        Overlay:ClearHomestoneTextures(cornerFrame)
    end
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

    if not CatalogStore or not SourceManager then
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

    local itemID = (details and details.itemID) or C_Item.GetItemInfoInstant(itemLink)
    if not itemID or not CatalogStore:IsDecorItem(itemLink) then
        return false
    end

    local status = SourceManager:GetInventoryItemStatus(itemID)
    if not status then
        return false
    end

    local iconSize = settings.iconSize or OVERLAY_CONFIG.ICON_SIZE
    cornerFrame:SetSize(iconSize, iconSize)
    -- No anchor override: SetHomestoneState picks up the profile's iconAnchor
    -- and the OFFSET_X/Y constants, so the texture pokes outside Baganator's
    -- corner widget the same way it does on Containers/Merchant/BetterBags.
    Overlay:SetHomestoneState(cornerFrame, status, {
        size = iconSize,
    })

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
