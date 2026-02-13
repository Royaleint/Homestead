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
-- Delegates to CatalogStore:IsOwnedFresh() (Phase 2) — cache + bags + live API
local function IsDecorOwnedByID(itemID)
    if not itemID then return nil end
    if HA.CatalogStore then
        return HA.CatalogStore:IsOwnedFresh(itemID)
    end
    return nil
end

-- Check if a decor item is owned (by itemLink)
-- Delegates to CatalogStore:IsOwnedFresh() (Phase 2)
local function IsDecorOwned(itemLink)
    local itemID = GetItemIDFromLink(itemLink)
    if not itemID then return nil end
    if HA.CatalogStore then
        return HA.CatalogStore:IsOwnedFresh(itemID)
    end
    return nil
end

-------------------------------------------------------------------------------
-- Cost Lookup Functions
-------------------------------------------------------------------------------

-- Fallback cost formatting if VendorData not available
local function FormatCostFallback(cost)
    if not cost then return nil end
    local parts = {}

    if cost.gold and cost.gold > 0 then
        local gold = math.floor(cost.gold / 10000)
        local silver = math.floor((cost.gold % 10000) / 100)
        if gold > 0 then
            table.insert(parts, gold .. "g")
        end
        if silver > 0 then
            table.insert(parts, silver .. "s")
        end
    end

    if cost.currencies then
        for _, currency in ipairs(cost.currencies) do
            if currency.id and currency.amount then
                local name = "Currency"
                if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
                    local info = C_CurrencyInfo.GetCurrencyInfo(currency.id)
                    if info and info.name then name = info.name end
                end
                table.insert(parts, currency.amount .. " " .. name)
            end
        end
    end

    return #parts > 0 and table.concat(parts, " + ") or nil
end

-- Get cost for an item from a specific vendor
local function GetItemCostFromVendor(itemID, npcID)
    if not itemID then return nil end
    if not HA.VendorDatabase or not HA.VendorDatabase.Vendors then return nil end

    -- If npcID provided, check that vendor first
    if npcID then
        local vendor = HA.VendorDatabase.Vendors[npcID]
        if vendor and vendor.items then
            for _, item in ipairs(vendor.items) do
                local vendorItemID = HA.VendorData and HA.VendorData:GetItemID(item) or (type(item) == "number" and item or item[1])
                if vendorItemID == itemID then
                    local cost = HA.VendorData and HA.VendorData:GetItemCost(item) or (type(item) == "table" and item.cost)
                    if cost then
                        return HA.VendorData and HA.VendorData:FormatCost(cost) or FormatCostFallback(cost)
                    end
                    break
                end
            end
        end
    end

    -- Fallback: use ByItemID index to find vendors that sell this item
    if HA.VendorDatabase.ByItemID then
        local npcIDs = HA.VendorDatabase.ByItemID[itemID]
        if npcIDs then
            for _, vendorNpcID in ipairs(npcIDs) do
                local vendor = HA.VendorDatabase.Vendors[vendorNpcID]
                if vendor and vendor.items then
                    for _, item in ipairs(vendor.items) do
                        local vendorItemID = HA.VendorData and HA.VendorData:GetItemID(item) or (type(item) == "number" and item or item[1])
                        if vendorItemID == itemID then
                            local cost = HA.VendorData and HA.VendorData:GetItemCost(item) or (type(item) == "table" and item.cost)
                            if cost then
                                return HA.VendorData and HA.VendorData:FormatCost(cost) or FormatCostFallback(cost)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Fallback: check scanned vendor data
    if HA.VendorData and HA.VendorData.GetScannedItemCost then
        local scannedCost = HA.VendorData:GetScannedItemCost(itemID, npcID)
        if scannedCost then
            return HA.VendorData:FormatCost(scannedCost) or FormatCostFallback(scannedCost)
        end
    end

    return nil
end

-------------------------------------------------------------------------------
-- Source Lookup Functions (Legacy - kept for compatibility)
-------------------------------------------------------------------------------

-- Check if item is from an achievement (legacy AchievementDecor)
local function GetAchievementSourceLegacy(itemID)
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
        return vendors[1]
    end
    return nil
end

-------------------------------------------------------------------------------
-- Shared Tooltip Enhancement (adds source info lines)
-------------------------------------------------------------------------------

-- Add requirement lines to tooltip for an item (optionally vendor-scoped)
-- Yellow=requirements, red=unmet, green=met
local function AddRequirementsToTooltip(tooltip, itemID, npcID)
    if not HA.SourceManager or not HA.SourceManager.GetRequirements then return end

    -- Check if requirements display is enabled
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.tooltip
            and HA.Addon.db.profile.tooltip.showRequirements == false then
        return
    end

    local reqs = HA.SourceManager:GetRequirements(itemID, npcID)
    if not reqs or #reqs == 0 then return end

    for _, req in ipairs(reqs) do
        local text = nil
        if req.type == "reputation" and req.faction and req.standing then
            text = "Requires: " .. req.faction .. " - " .. req.standing
        elseif req.type == "quest" and req.name then
            text = "Requires: " .. req.name
        elseif req.type == "achievement" and req.name then
            text = "Requires: " .. req.name
        elseif req.type == "level" and req.level then
            text = "Requires Level " .. req.level
        elseif req.type == "unknown" and req.text then
            text = req.text
        end

        if text then
            local isMet = HA.SourceManager:IsRequirementMet(req)
            if isMet == true then
                tooltip:AddLine("  " .. text, 0.0, 0.8, 0.0)  -- Green
            elseif isMet == false then
                tooltip:AddLine("  " .. text, 0.8, 0.0, 0.0)  -- Red
            else
                tooltip:AddLine("  " .. text, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)  -- Yellow (unknown)
            end
        end
    end
end

-- Add source information lines to a tooltip (shared between item and catalog tooltips)
-- Uses SourceManager for comprehensive source lookup
local function AddSourceInfoToTooltip(tooltip, itemID, skipOwnership)
    if not itemID then return false end

    -- Use SourceManager if available for comprehensive source lookup
    if HA.SourceManager and HA.SourceManager.GetSource then
        local source = HA.SourceManager:GetSource(itemID)

        if source then
            local parsedTag = source._isParsed and " |cFFAAAAFF(unverified)|r" or ""

            if source.type == "vendor" then
                -- Vendor source
                local vendorName = source.data.name or "Unknown Vendor"
                local zoneName = source.data.zone or "Unknown Location"

                tooltip:AddLine("Source: " .. vendorName .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                tooltip:AddLine("  Location: " .. zoneName, COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)

                -- Show faction if not neutral
                if source.data.faction and source.data.faction ~= "Neutral" then
                    local factionColor = source.data.faction == "Alliance" and "|cFF0078FF" or "|cFFFF0000"
                    tooltip:AddLine("  Faction: " .. factionColor .. source.data.faction .. "|r", COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
                end

                -- Show cost if available
                if source.data.cost then
                    local costStr = HA.VendorData and HA.VendorData:FormatCost(source.data.cost)
                    if costStr then
                        tooltip:AddLine("  Cost: " .. costStr, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                    end
                else
                    -- Try fallback cost lookup
                    local costStr = GetItemCostFromVendor(itemID, source.data.npcID)
                    if costStr then
                        tooltip:AddLine("  Cost: " .. costStr, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                    end
                end

                -- Show requirements (vendor-specific when npcID available)
                AddRequirementsToTooltip(tooltip, itemID, source.data.npcID)

                return true

            elseif source.type == "quest" then
                -- Quest source
                local questName = source.data.questName or "Unknown Quest"
                tooltip:AddLine("Source: Quest" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                tooltip:AddLine("  " .. questName, COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)
                AddRequirementsToTooltip(tooltip, itemID)
                return true

            elseif source.type == "achievement" then
                -- Achievement source
                local achievementName = source.data.achievementName or "Unknown Achievement"
                local achievementID = source.data.achievementID

                -- Check if achievement is completed
                local isCompleted = false
                if achievementID and GetAchievementInfo then
                    local _, _, _, completed = GetAchievementInfo(achievementID)
                    isCompleted = completed
                end

                if isCompleted then
                    tooltip:AddLine("Source: Achievement |cFF00FF00(Completed)|r" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                else
                    tooltip:AddLine("Source: Achievement |cFFFF0000(Incomplete)|r" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                end
                tooltip:AddLine("  " .. achievementName, COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)
                AddRequirementsToTooltip(tooltip, itemID)
                return true

            elseif source.type == "profession" then
                -- Profession source
                local profession = source.data.profession or "Unknown"
                local recipeName = source.data.recipeName or "Unknown Recipe"
                tooltip:AddLine("Source: " .. profession .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                tooltip:AddLine("  Recipe: " .. recipeName, COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)
                AddRequirementsToTooltip(tooltip, itemID)
                return true

            elseif source.type == "drop" then
                -- Drop source
                local mobName = source.data.mobName or "Unknown"
                local zone = source.data.zone or "Unknown Location"
                tooltip:AddLine("Source: Drop" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                tooltip:AddLine("  " .. mobName, COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)
                tooltip:AddLine("  Zone: " .. zone, COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
                if source.data.notes then
                    tooltip:AddLine("  " .. source.data.notes, COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
                end
                AddRequirementsToTooltip(tooltip, itemID)
                return true
            end
        end
    end

    -- Fallback: Legacy source lookup (AchievementDecor + VendorData)
    -- Check for achievement source (legacy AchievementDecor)
    local achievementInfo = GetAchievementSourceLegacy(itemID)
    if achievementInfo then
        local achievementName = achievementInfo.name or "Unknown Achievement"
        local isCompleted = achievementInfo.completed

        if isCompleted then
            tooltip:AddLine("Source: " .. achievementName .. " |cFF00FF00(Completed)|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        else
            tooltip:AddLine("Source: " .. achievementName .. " |cFFFF0000(Incomplete)|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        end

        if achievementInfo.expansion then
            tooltip:AddLine("  Expansion: " .. achievementInfo.expansion, COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        end

        return true
    end

    -- Check for vendor source (fallback)
    local vendorInfo = GetVendorSource(itemID)
    if vendorInfo then
        local vendorName = vendorInfo.name or "Unknown Vendor"
        local zoneName = vendorInfo.zone or "Unknown Location"

        tooltip:AddLine("Source: " .. vendorName, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        tooltip:AddLine("  Location: " .. zoneName, COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)

        if vendorInfo.faction and vendorInfo.faction ~= "Neutral" then
            local factionColor = vendorInfo.faction == "Alliance" and "|cFF0078FF" or "|cFFFF0000"
            tooltip:AddLine("  Faction: " .. factionColor .. vendorInfo.faction .. "|r", COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        end

        local costStr = GetItemCostFromVendor(itemID, vendorInfo.npcID)
        if costStr then
            tooltip:AddLine("  Cost: " .. costStr, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        end

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

    -- No legacy fallback: TooltipDataProcessor is the supported path.
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
