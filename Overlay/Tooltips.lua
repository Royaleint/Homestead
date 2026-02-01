--[[
    Homestead - Tooltip Enhancements
    Add decor collection status and source info to item tooltips

    Supports:
    - Standard item tooltips (bags, merchants, etc.) via TooltipDataProcessor
    - Housing Catalog UI tooltips via EventRegistry "HousingCatalogEntry.TooltipCreated"

    Note: WoW 10.0.2+ uses TooltipDataProcessor instead of OnTooltipSetItem
]]

local addonName, HA = ...

-- Local references
local Constants = HA.Constants
local L = HA.L or {}

-- Local state
local isHooked = false
local isCatalogHooked = false

-- Colors
local COLOR_GREEN = {r = 0, g = 1, b = 0}
local COLOR_RED = {r = 1, g = 0, b = 0}
local COLOR_YELLOW = {r = 1, g = 0.82, b = 0}
local COLOR_WHITE = {r = 1, g = 1, b = 1}
local COLOR_GRAY = {r = 0.5, g = 0.5, b = 0.5}

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

-- Extract item ID from item link
local function GetItemIDFromLink(itemLink)
    if not itemLink then return nil end
    local itemID = itemLink:match("item:(%d+)")
    return itemID and tonumber(itemID)
end

-- Check if an item is a housing decor item using the Housing Catalog API
local function IsDecorItem(itemLink)
    if not itemLink then return false end
    if not C_HousingCatalog or not C_HousingCatalog.GetCatalogEntryInfoByItem then
        return false
    end

    local success, info = pcall(function()
        return C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, false)
    end)

    return success and info ~= nil
end

-- Check if a decor item is owned (by itemID)
local function IsDecorOwnedByID(itemID)
    if not itemID then return nil end

    -- Check persistent cache first as workaround for API bug
    if HA.Addon and HA.Addon.db and HA.Addon.db.global.ownedDecor then
        if HA.Addon.db.global.ownedDecor[itemID] then
            return true
        end
    end

    -- Try API with item link
    if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
        local itemLink = "item:" .. itemID
        local success, info = pcall(function()
            return C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, true)
        end)

        if success and info then
            -- entrySubtype: 0 = Invalid, 1 = Unowned, 2+ = Owned variants
            return info.entrySubtype >= 2 or (info.quantity and info.quantity > 0)
        end
    end

    return nil
end

-- Check if a decor item is owned (by itemLink)
local function IsDecorOwned(itemLink)
    if not C_HousingCatalog or not C_HousingCatalog.GetCatalogEntryInfoByItem then
        return nil -- Unknown
    end

    local success, info = pcall(function()
        return C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, true)
    end)

    if success and info then
        -- Check persistent cache first as workaround for API bug
        local itemID = GetItemIDFromLink(itemLink)
        if itemID and HA.Addon and HA.Addon.db and HA.Addon.db.global.ownedDecor then
            if HA.Addon.db.global.ownedDecor[itemID] then
                return true
            end
        end

        -- Fall back to API checks
        -- Check quantity first (most reliable indicator of ownership)
        if info.quantity and info.quantity > 0 then
            return true
        end

        -- Check numPlaced (items placed in housing)
        if info.numPlaced and info.numPlaced > 0 then
            return true
        end

        -- entrySubtype >= 2 means owned (but field may not exist)
        if info.entrySubtype and info.entrySubtype >= 2 then
            return true
        end

        return false
    end

    return nil
end

-------------------------------------------------------------------------------
-- Source Lookup Functions
-------------------------------------------------------------------------------

-- Check if item is from an achievement
local function GetAchievementSource(itemID)
    if not HA.AchievementDecor or not HA.AchievementDecor.GetAchievementForItem then
        return nil
    end

    return HA.AchievementDecor:GetAchievementForItem(itemID)
end

-- Check if item is from a vendor
local function GetVendorSource(itemID)
    if not HA.VendorData or not HA.VendorData.GetVendorsForItem then
        return nil
    end

    local vendors = HA.VendorData:GetVendorsForItem(itemID)
    if vendors and #vendors > 0 then
        return vendors[1] -- Return first vendor
    end

    return nil
end

-------------------------------------------------------------------------------
-- Shared Tooltip Enhancement (adds source info lines)
-------------------------------------------------------------------------------

-- Add source information lines to a tooltip (shared between item and catalog tooltips)
local function AddSourceInfoToTooltip(tooltip, itemID, skipOwnership)
    if not itemID then return false end

    local addedLines = false

    -- Check for achievement source
    local achievementInfo = GetAchievementSource(itemID)
    if achievementInfo then
        local achievementName = achievementInfo.name or "Unknown Achievement"
        local isCompleted = achievementInfo.completed

        if isCompleted then
            tooltip:AddLine("Source: " .. achievementName .. " |cFF00FF00(Completed)|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        else
            tooltip:AddLine("Source: " .. achievementName .. " |cFFFF0000(Incomplete)|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        end

        -- Show expansion if available
        if achievementInfo.expansion then
            tooltip:AddLine("  Expansion: " .. achievementInfo.expansion, COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        end

        return true
    end

    -- Check for vendor source
    local vendorInfo = GetVendorSource(itemID)
    if vendorInfo then
        local vendorName = vendorInfo.name or "Unknown Vendor"
        local zoneName = vendorInfo.zone or "Unknown Location"

        tooltip:AddLine("Source: " .. vendorName, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        tooltip:AddLine("  Location: " .. zoneName, COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)

        -- Show faction if not neutral
        if vendorInfo.faction and vendorInfo.faction ~= "Neutral" then
            local factionColor = vendorInfo.faction == "Alliance" and "|cFF0078FF" or "|cFFFF0000"
            tooltip:AddLine("  Faction: " .. factionColor .. vendorInfo.faction .. "|r", COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        end

        -- Show vendor notes if present (e.g., garrison requirements, rep requirements)
        if vendorInfo.notes then
            tooltip:AddLine("  " .. vendorInfo.notes, COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        end

        return true
    end

    return false
end

-------------------------------------------------------------------------------
-- Standard Item Tooltip Enhancement (bags, merchants, etc.)
-------------------------------------------------------------------------------

local function AddDecorInfoToTooltip(tooltip, itemLink)
    if not itemLink then return end

    -- Check if tooltip additions are enabled
    local db = HA.Addon and HA.Addon.db and HA.Addon.db.profile.tooltip
    if db and not db.enabled then return end

    -- Check if this is a decor item
    if not IsDecorItem(itemLink) then
        return
    end

    local itemID = GetItemIDFromLink(itemLink)
    if not itemID then return end

    -- Add blank line separator
    tooltip:AddLine(" ")

    -- Add header
    tooltip:AddLine("|cFFFFD700[Homestead]|r")

    -- Check ownership status (always check, but only display if setting enabled)
    local isOwned = IsDecorOwned(itemLink)
    if not db or db.showOwned ~= false then
        if isOwned == true then
            tooltip:AddLine("Status: Owned", COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
        elseif isOwned == false then
            tooltip:AddLine("Status: Not Owned", COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
        else
            tooltip:AddLine("Status: Unknown", COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        end
    end

    -- Show quantity if owned and setting enabled
    if isOwned and db and db.showQuantity then
        local success, info = pcall(function()
            return C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, true)
        end)
        if success and info and info.quantity and info.quantity > 0 then
            tooltip:AddLine("Quantity: " .. info.quantity, COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)
        end
    end

    -- Add source info (if enabled - default true)
    if not db or db.showSource ~= false then
        local hasSource = AddSourceInfoToTooltip(tooltip, itemID)

        if not hasSource then
            tooltip:AddLine("Source: Unknown", COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        end
    end

    tooltip:Show()
end

-------------------------------------------------------------------------------
-- Housing Catalog Tooltip Enhancement
-------------------------------------------------------------------------------

-- Handle Housing Catalog tooltips via EventRegistry
-- The catalog fires "HousingCatalogEntry.TooltipCreated" with (entryFrame, tooltip)
-- Note: EventRegistry callbacks receive (ownerID, ...) where ... are the TriggerEvent args
local function OnHousingCatalogTooltipCreated(ownerID, entryFrame, tooltip)
    -- Debug logging
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug then
        HA.Addon:Debug("Catalog tooltip callback fired")
    end

    if not entryFrame or not tooltip then
        if HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug then
            HA.Addon:Debug("Catalog tooltip: missing entryFrame or tooltip")
        end
        return
    end

    -- Check if tooltip additions are enabled
    local db = HA.Addon and HA.Addon.db and HA.Addon.db.profile.tooltip
    if db and not db.enabled then return end

    -- Get entry info from the catalog entry frame
    local entryInfo = entryFrame.entryInfo
    if not entryInfo then
        if HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug then
            HA.Addon:Debug("Catalog tooltip: no entryInfo on frame")
        end
        return
    end

    -- Get item ID from entry info (may be itemID or nested in entryID)
    local itemID = entryInfo.itemID
    if not itemID and entryInfo.entryID then
        -- Some entries store itemID differently
        itemID = entryInfo.entryID.itemID or entryInfo.entryID
    end

    if not itemID then
        if HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug then
            HA.Addon:Debug("Catalog tooltip: no itemID found in entryInfo")
        end
        return
    end

    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug then
        HA.Addon:Debug("Catalog tooltip: processing itemID", itemID)
    end

    -- Add blank line separator
    tooltip:AddLine(" ")

    -- Add header
    tooltip:AddLine("|cFFFFD700[Homestead]|r")

    -- Add source info (ownership is already shown by the catalog UI)
    -- Only show if enabled (default true)
    if not db or db.showSource ~= false then
        local hasSource = false

        -- Priority 1: Check Blizzard's sourceText from catalog entry (authoritative for owned items)
        if entryInfo.sourceText and entryInfo.sourceText ~= "" then
            tooltip:AddLine("Source: " .. entryInfo.sourceText, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
            hasSource = true
            if HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug then
                HA.Addon:Debug("Catalog tooltip: using Blizzard sourceText")
            end
        end

        -- Priority 2: Fall back to our VendorDatabase/AchievementDecor
        if not hasSource then
            hasSource = AddSourceInfoToTooltip(tooltip, itemID, true)
            if hasSource and HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug then
                HA.Addon:Debug("Catalog tooltip: using VendorDatabase/AchievementDecor")
            end
        end

        -- Priority 3: Show unknown if both failed
        if not hasSource then
            tooltip:AddLine("Source: Unknown", COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        end
    end

    -- Refresh tooltip to show new lines
    tooltip:Show()
end

-------------------------------------------------------------------------------
-- Tooltip Hooking (Modern API - TooltipDataProcessor)
-------------------------------------------------------------------------------

local function OnTooltipSetItem(tooltip, data)
    if not data then return end

    -- Get item link from tooltip data
    local itemLink
    if data.guid then
        itemLink = C_Item.GetItemLinkByGUID(data.guid)
    elseif data.id then
        -- Try to get full item link
        local _, link = C_Item.GetItemInfo(data.id)
        itemLink = link or ("item:" .. data.id)
    end

    if itemLink then
        AddDecorInfoToTooltip(tooltip, itemLink)
    end
end

local function HookTooltips()
    if isHooked then return end

    -- Use TooltipDataProcessor for modern WoW (10.0.2+)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            -- Only process GameTooltip and similar tooltips
            if tooltip == GameTooltip or tooltip == ItemRefTooltip or tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2 then
                OnTooltipSetItem(tooltip, data)
            end
        end)

        isHooked = true
        if HA.Addon then
            HA.Addon:Debug("Tooltips hooked via TooltipDataProcessor")
        end
        return
    end

    -- Fallback for older API (shouldn't be needed in 12.0)
    if GameTooltip and GameTooltip.HookScript then
        local success = pcall(function()
            GameTooltip:HookScript("OnTooltipSetItem", function(self)
                local _, itemLink = self:GetItem()
                if itemLink then
                    AddDecorInfoToTooltip(self, itemLink)
                end
            end)
        end)

        if success then
            isHooked = true
            if HA.Addon then
                HA.Addon:Debug("Tooltips hooked via legacy HookScript")
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Housing Catalog Hook via EventRegistry
-------------------------------------------------------------------------------

local function HookHousingCatalog()
    if isCatalogHooked then return end

    -- EventRegistry is the modern way to hook into Blizzard UI events
    if EventRegistry and EventRegistry.RegisterCallback then
        local success, err = pcall(function()
            EventRegistry:RegisterCallback("HousingCatalogEntry.TooltipCreated", OnHousingCatalogTooltipCreated, HA)
        end)

        if success then
            isCatalogHooked = true
            if HA.Addon then
                HA.Addon:Debug("Housing Catalog tooltips hooked via EventRegistry")
            end
        else
            if HA.Addon then
                HA.Addon:Debug("Failed to hook Housing Catalog tooltips:", err)
            end
        end
    else
        if HA.Addon then
            HA.Addon:Debug("EventRegistry not available for Housing Catalog hook")
        end
    end
end

-- Hook when Blizzard_HousingDashboard addon loads (it may load on-demand)
local function OnAddonLoaded(loadedAddonName)
    if loadedAddonName == "Blizzard_HousingDashboard" or loadedAddonName == "Blizzard_HousingTemplates" then
        if HA.Addon then
            HA.Addon:Debug("Housing addon loaded:", loadedAddonName)
        end
        HookHousingCatalog()
    end
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

-- Helper to check if addon is loaded (compatible with different WoW versions)
local function IsAddonLoaded(addonName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(addonName)
    elseif IsAddOnLoaded then
        return IsAddOnLoaded(addonName)
    end
    return false
end

local function Initialize()
    -- Hook standard item tooltips
    HookTooltips()

    -- Try to hook Housing Catalog if already loaded
    if IsAddonLoaded("Blizzard_HousingDashboard") or IsAddonLoaded("Blizzard_HousingTemplates") then
        if HA.Addon then
            HA.Addon:Debug("Housing addon already loaded, hooking now")
        end
        HookHousingCatalog()
    end

    -- Register for addon load events to hook Housing Catalog when it loads
    local addonFrame = CreateFrame("Frame")
    addonFrame:RegisterEvent("ADDON_LOADED")
    addonFrame:SetScript("OnEvent", function(self, event, loadedAddon)
        OnAddonLoaded(loadedAddon)
    end)

    if HA.Addon then
        HA.Addon:Debug("Tooltip enhancement module initialized")
    end
end

-- Initialize when addon loads
if HA.Addon then
    C_Timer.After(0, Initialize)
else
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function()
        Initialize()
        initFrame:UnregisterAllEvents()
    end)
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

HA.Tooltips = {
    -- Manual refresh (re-hook if needed)
    Refresh = function()
        if not isHooked then
            HookTooltips()
        end
        if not isCatalogHooked then
            HookHousingCatalog()
        end
    end,

    -- Check if tooltips are hooked
    IsHooked = function()
        return isHooked
    end,

    -- Check if catalog tooltips are hooked
    IsCatalogHooked = function()
        return isCatalogHooked
    end,

    -- Manually add decor info to a tooltip (for custom UI)
    AddDecorInfo = function(tooltip, itemLink)
        AddDecorInfoToTooltip(tooltip, itemLink)
    end,

    -- Add source info only (for external use)
    AddSourceInfo = function(tooltip, itemID)
        return AddSourceInfoToTooltip(tooltip, itemID)
    end,
}
