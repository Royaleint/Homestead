--[[
    HousingAddon - Tooltip Enhancements
    Add decor collection status to item tooltips
]]

local addonName, HA = ...

-- Local references
local DecorTracker = HA.DecorTracker
local Constants = HA.Constants
local L = HA.L or {}

-- Local state
local isHooked = false

-------------------------------------------------------------------------------
-- Tooltip Enhancement
-------------------------------------------------------------------------------

local function AddDecorInfoToTooltip(tooltip, itemLink)
    if not itemLink then return end

    -- Check if tooltip additions are enabled
    local db = HA.Addon and HA.Addon.db and HA.Addon.db.profile.tooltip
    if not db or not db.enabled then return end

    -- Check if this is a decor item
    if not DecorTracker or not DecorTracker:IsDecorItem(itemLink) then
        return
    end

    -- Get decor data
    local decorData = DecorTracker:GetDecorInfo(itemLink)
    if not decorData or not decorData:IsValid() then return end

    -- Add blank line separator
    tooltip:AddLine(" ")

    -- Add header
    local headerText = L["[Housing Addon]"] or "|cFF00FF00[Housing Addon]|r"
    tooltip:AddLine(headerText)

    -- Get tooltip lines from DecorData
    local lines = decorData:GetTooltipLines()
    for _, lineData in ipairs(lines) do
        local r, g, b = 1, 1, 1
        if lineData.color then
            r = lineData.color.r or 1
            g = lineData.color.g or 1
            b = lineData.color.b or 1
        end
        tooltip:AddLine(lineData.text, r, g, b)
    end

    -- Add source information if enabled and not owned
    if db.showSource and not decorData.isOwned then
        if decorData.sourceText then
            local sourceLabel = L["Source:"] or "Source:"
            tooltip:AddLine(sourceLabel .. " " .. decorData.sourceText, 1, 0.82, 0)
        end

        -- Add vendor navigation hint if from vendor
        if decorData.sourceType == Constants.SourceTypes.VENDOR then
            local navHint = L["Click to set waypoint"] or "Click to set waypoint"
            tooltip:AddLine("|cFF888888" .. navHint .. "|r")
        end
    end

    tooltip:Show()
end

-------------------------------------------------------------------------------
-- Tooltip Hooking
-------------------------------------------------------------------------------

local function OnTooltipSetItem(tooltip)
    local _, itemLink = tooltip:GetItem()
    if itemLink then
        AddDecorInfoToTooltip(tooltip, itemLink)
    end
end

local function HookTooltips()
    if isHooked then return end

    -- Hook GameTooltip
    if GameTooltip then
        GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    end

    -- Hook ItemRefTooltip (for linked items in chat)
    if ItemRefTooltip then
        ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    end

    -- Hook shopping comparison tooltips
    for i = 1, 2 do
        local shoppingTooltip = _G["ShoppingTooltip" .. i]
        if shoppingTooltip then
            shoppingTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
        end
    end

    -- Hook embedded item tooltip (for item buttons that show tooltips)
    if EmbeddedItemTooltip then
        -- EmbeddedItemTooltip uses a different method
        hooksecurefunc(EmbeddedItemTooltip, "SetItemByID", function(self, itemID)
            if itemID then
                local itemLink = "item:" .. itemID
                AddDecorInfoToTooltip(self, itemLink)
            end
        end)
    end

    isHooked = true
    HA.Addon:Debug("Tooltips hooked")
end

-------------------------------------------------------------------------------
-- Click Handler for Vendor Navigation
-------------------------------------------------------------------------------

-- This will be called when a user clicks on a decor item to navigate to vendor
local function HandleDecorItemClick(itemLink)
    if not itemLink then return end

    -- Check if this is a decor item from a vendor
    local decorData = DecorTracker:GetDecorInfo(itemLink)
    if not decorData then return end

    -- Only handle vendor items
    if decorData.sourceType ~= Constants.SourceTypes.VENDOR then return end

    -- Get vendor info and navigate
    -- This will be implemented when VendorTracer module is complete
    if HA.VendorTracer then
        HA.VendorTracer:NavigateToVendorForItem(itemLink)
    end
end

-- Hook item click handlers (optional enhancement)
local function HookItemClicks()
    -- Hook GameTooltip click
    -- Note: This requires additional handling for modifier keys
    -- Will be implemented with VendorTracer module
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

local function Initialize()
    -- Hook tooltips on load
    HookTooltips()

    HA.Addon:Debug("Tooltip module initialized")
end

-- Initialize when addon loads
if HA.Addon then
    C_Timer.After(0, Initialize)
else
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", Initialize)
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

-- Expose click handler for other modules to use
HA.TooltipClickHandler = HandleDecorItemClick
