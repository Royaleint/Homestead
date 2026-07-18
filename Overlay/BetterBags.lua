--[[
    Homestead - BetterBags Overlay Integration
    Adds decor status icons to BetterBags item buttons using its Events module
]]

local _, HA = ...

local CatalogStore = HA.CatalogStore
local Constants = HA.Constants
local Overlay = HA.Overlay
local SourceManager = HA.SourceManager

local OVERLAY_CONFIG = Constants.Overlay or {
    ICON_SIZE = 14,
    DEFAULT_ANCHOR = "TOPLEFT",
    OFFSET_X = 2,
    OFFSET_Y = -2,
}

local eventsModule = nil
local constantsModule = nil
local isHooked = false

-- HS-204(d): SetHomestoneState only reads opts.* synchronously within the
-- call (it copies values into its own per-overlay table) and never retains
-- this table afterward, so one reused scratch table is safe across the many
-- OnItemUpdated calls per bag refresh instead of a fresh table per item.
local homestoneOptionsScratch = {}

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

local function ClearIcon(decoration)
    if not decoration then return end
    if Overlay and Overlay.ClearHomestoneTextures then
        Overlay:ClearHomestoneTextures(decoration)
    end
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

    if not CatalogStore or not SourceManager then
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

    local itemID = (itemInfo and itemInfo.itemID) or C_Item.GetItemInfoInstant(itemLink)
    if not itemID or not CatalogStore:IsDecorItem(itemLink) then
        ClearIcon(decoration)
        return
    end

    local status = SourceManager:GetInventoryItemStatus(itemID)
    if not status then
        ClearIcon(decoration)
        return
    end

    local anchor = settings.iconAnchor or OVERLAY_CONFIG.DEFAULT_ANCHOR or "TOPLEFT"
    -- Reuse the scratch table in place; both fields are always overwritten
    -- below so neither can carry a stale value from a previous item.
    homestoneOptionsScratch.size = settings.iconSize or OVERLAY_CONFIG.ICON_SIZE
    homestoneOptionsScratch.anchor = anchor
    Overlay:SetHomestoneState(decoration, status, homestoneOptionsScratch)
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
    waitFrame:SetScript("OnEvent", function(self)
        -- HS-211: ADDON_LOADED firing for BetterBags specifically is not a
        -- readiness guarantee — its AceAddon Events/Constants modules can
        -- still be unregistered at that exact moment, and BetterBags's own
        -- ADDON_LOADED never fires again to retry. Gating on
        -- addonName == "BetterBags" was therefore a one-shot dead end if
        -- that first attempt failed (the same class of bug already fixed in
        -- Overlay/Baganator.lua's WaitForBaganator). Reattempt on every
        -- subsequent ADDON_LOADED instead — HookIntegration self-guards
        -- (isHooked), so this is a cheap no-op after success and stops the
        -- moment it succeeds.
        if HookIntegration() then
            self:UnregisterAllEvents()
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

