--[[
    Homestead - BetterBags Overlay Integration
    Adds decor status icons to BetterBags item buttons using its Events module
]]

local _, HA = ...

local DecorTracker = HA.DecorTracker
local Constants = HA.Constants
local Overlay = HA.Overlay

local OVERLAY_CONFIG = Constants.Overlay or {
    ICON_SIZE = 14,
    DEFAULT_ANCHOR = "TOPLEFT",
    OFFSET_X = 2,
    OFFSET_Y = -2,
}

local eventsModule = nil
local constantsModule = nil
local isHooked = false

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

local function GetModules()
    if not LibStub then
        return nil, nil
    end

    local aceAddon = LibStub("AceAddon-3.0", true)
    if not aceAddon then
        return nil, nil
    end

    local betterBags = aceAddon:GetAddon("BetterBags", true)
    if not betterBags then
        return nil, nil
    end

    return betterBags:GetModule("Events", true), betterBags:GetModule("Constants", true)
end

local function IsBankContext(bagID)
    if type(bagID) ~= "number" then
        return false
    end
    if not constantsModule then
        return false
    end

    if constantsModule.BANK_BAGS and constantsModule.BANK_BAGS[bagID] ~= nil then
        return true
    end
    if constantsModule.ACCOUNT_BANK_BAGS and constantsModule.ACCOUNT_BANK_BAGS[bagID] ~= nil then
        return true
    end

    return false
end

local function GetAnchorOffsets(anchor)
    local offsetX = OVERLAY_CONFIG.OFFSET_X or 2
    local offsetY = OVERLAY_CONFIG.OFFSET_Y or -2

    if anchor == "TOPRIGHT" then
        offsetX = -offsetX
    elseif anchor == "BOTTOMLEFT" then
        offsetY = -offsetY
    elseif anchor == "BOTTOMRIGHT" then
        offsetX = -offsetX
        offsetY = -offsetY
    elseif anchor == "CENTER" then
        offsetX = 0
        offsetY = 0
    end

    return offsetX, offsetY
end

local function EnsureIcon(decoration)
    if decoration.HomesteadDecorIcon then
        return decoration.HomesteadDecorIcon
    end

    local tex = decoration:CreateTexture(nil, "OVERLAY")
    decoration.HomesteadDecorIcon = tex
    return tex
end

local function ClearIcon(decoration)
    if not decoration then return end
    local tex = decoration.HomesteadDecorIcon
    if not tex then return end
    tex:Hide()
    tex:SetTexture(nil)
end

local function RefreshWidgets()
    if not isHooked or not eventsModule or not eventsModule.SendMessage then
        return
    end
    eventsModule:SendMessage("bags/FullRefreshAll")
end

-------------------------------------------------------------------------------
-- BetterBags Event Handlers
-------------------------------------------------------------------------------

local function OnItemUpdated(_, item, decoration)
    if not item or not decoration then return end

    if not HA.Addon or not HA.Addon.db or not HA.Addon.db.profile then
        ClearIcon(decoration)
        return
    end

    local profile = HA.Addon.db.profile
    local settings = profile.overlay
    if not settings or not settings.enabled then
        ClearIcon(decoration)
        return
    end

    if not DecorTracker then
        ClearIcon(decoration)
        return
    end

    local data = item.GetItemData and item:GetItemData()
    local bagID = data and data.bagid
    local contextEnabled
    if bagID == nil then
        contextEnabled = settings.showOnBags or settings.showOnBank
    elseif IsBankContext(bagID) then
        contextEnabled = settings.showOnBank
    else
        contextEnabled = settings.showOnBags
    end

    if not contextEnabled then
        ClearIcon(decoration)
        return
    end

    local itemInfo = data and data.itemInfo
    local itemLink = itemInfo and itemInfo.itemLink
    if not itemLink then
        ClearIcon(decoration)
        return
    end

    if not DecorTracker:IsDecorItem(itemLink) then
        ClearIcon(decoration)
        return
    end

    local iconTexture = DecorTracker:GetStatusIcon(itemLink)
    if not iconTexture then
        ClearIcon(decoration)
        return
    end

    local tex = EnsureIcon(decoration)
    local anchor = settings.iconAnchor or OVERLAY_CONFIG.DEFAULT_ANCHOR or "TOPLEFT"
    local offsetX, offsetY = GetAnchorOffsets(anchor)
    tex:ClearAllPoints()
    tex:SetPoint(anchor, decoration, anchor, offsetX, offsetY)
    tex:SetSize(settings.iconSize or OVERLAY_CONFIG.ICON_SIZE, settings.iconSize or OVERLAY_CONFIG.ICON_SIZE)
    tex:SetTexture(iconTexture)

    local color = DecorTracker:GetStatusColor(itemLink)
    if color then
        tex:SetVertexColor(color.r, color.g, color.b, color.a or 1)
    else
        tex:SetVertexColor(1, 1, 1, 1)
    end

    tex:Show()
end

local function OnItemClearing(_, _, decoration)
    ClearIcon(decoration)
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

local function HookIntegration()
    if isHooked then return true end

    eventsModule, constantsModule = GetModules()
    if not eventsModule or not constantsModule then
        return false
    end

    eventsModule:RegisterMessage("item/Updated", OnItemUpdated)
    eventsModule:RegisterMessage("item/Clearing", OnItemClearing)

    if Overlay and Overlay.RegisterExternalRefresher then
        Overlay:RegisterExternalRefresher("betterbags", RefreshWidgets)
    end

    isHooked = true
    if HA.Addon then
        HA.Addon:Debug("BetterBags overlay integration initialized")
    end
    return true
end

local function Initialize()
    if IsAddonLoaded("BetterBags") then
        HookIntegration()
        return
    end

    local waitFrame = CreateFrame("Frame")
    waitFrame:RegisterEvent("ADDON_LOADED")
    waitFrame:SetScript("OnEvent", function(self, _, addonName)
        if addonName == "BetterBags" then
            if HookIntegration() then
                self:UnregisterAllEvents()
            end
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

