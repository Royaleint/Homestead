--[[
    Homestead - SourceManager
    Unified source lookup for housing decor items

    Priority order when multiple sources exist:
    1. Vendor (most actionable - player can go buy it)
    2. Quest (specific acquisition path)
    3. Achievement (specific goal to work toward)
    4. Profession (craftable)
    5. Drop (RNG-based)

    Usage:
        local source = HA.SourceManager:GetSource(itemID)
        if source then
            print(source.type)  -- "vendor", "quest", "achievement", "profession", "drop"
            print(source.data)  -- Source-specific data table
        end
]]

local addonName, HA = ...

-- Create SourceManager module
local SourceManager = {}
HA.SourceManager = SourceManager

-------------------------------------------------------------------------------
-- Source Lookup
-------------------------------------------------------------------------------

-- Get the primary source for an item
-- Returns: {type = "vendor|quest|achievement|profession|drop", data = {...}} or nil
function SourceManager:GetSource(itemID)
    if not itemID then return nil end

    -- Priority 1: Vendor source (from VendorDatabase)
    local vendorSource = self:GetVendorSource(itemID)
    if vendorSource then
        return {type = "vendor", data = vendorSource}
    end

    -- Priority 2: Quest source
    if HA.QuestSources and HA.QuestSources[itemID] then
        return {type = "quest", data = HA.QuestSources[itemID]}
    end

    -- Priority 3: Achievement source
    if HA.AchievementSources and HA.AchievementSources[itemID] then
        return {type = "achievement", data = HA.AchievementSources[itemID]}
    end

    -- Priority 4: Profession source
    if HA.ProfessionSources and HA.ProfessionSources[itemID] then
        return {type = "profession", data = HA.ProfessionSources[itemID]}
    end

    -- Priority 5: Drop source
    if HA.DropSources and HA.DropSources[itemID] then
        return {type = "drop", data = HA.DropSources[itemID]}
    end

    return nil
end

-- Get all sources for an item (for items with multiple acquisition methods)
-- Returns: array of {type = "...", data = {...}}
function SourceManager:GetAllSources(itemID)
    if not itemID then return {} end

    local sources = {}

    -- Vendor source
    local vendorSource = self:GetVendorSource(itemID)
    if vendorSource then
        table.insert(sources, {type = "vendor", data = vendorSource})
    end

    -- Quest source
    if HA.QuestSources and HA.QuestSources[itemID] then
        table.insert(sources, {type = "quest", data = HA.QuestSources[itemID]})
    end

    -- Achievement source
    if HA.AchievementSources and HA.AchievementSources[itemID] then
        table.insert(sources, {type = "achievement", data = HA.AchievementSources[itemID]})
    end

    -- Profession source
    if HA.ProfessionSources and HA.ProfessionSources[itemID] then
        table.insert(sources, {type = "profession", data = HA.ProfessionSources[itemID]})
    end

    -- Drop source
    if HA.DropSources and HA.DropSources[itemID] then
        table.insert(sources, {type = "drop", data = HA.DropSources[itemID]})
    end

    return sources
end

-- Helper: Get vendor source from VendorData
function SourceManager:GetVendorSource(itemID)
    if not HA.VendorData or not HA.VendorData.GetVendorsForItem then
        return nil
    end

    local vendors = HA.VendorData:GetVendorsForItem(itemID)
    if vendors and #vendors > 0 then
        local vendor = vendors[1]  -- Return first/closest vendor

        -- Try to get cost data for this item
        local cost = nil
        if vendor.items and HA.VendorData then
            for _, item in ipairs(vendor.items) do
                -- Handle both static format (number or {itemID, cost=...})
                -- and scanned format ({itemID=123, price=..., currencies=...})
                local vendorItemID = HA.VendorData:GetItemID(item) or item.itemID
                if vendorItemID == itemID then
                    cost = HA.VendorData:GetItemCost(item)
                    -- If no static-format cost, try scanned format
                    if not cost and vendor._isScanned and HA.VendorData.NormalizeScannedCost then
                        cost = HA.VendorData:NormalizeScannedCost(item)
                    end
                    break
                end
            end
        end

        return {
            npcID = vendor.npcID,
            name = vendor.name,
            zone = vendor.zone,
            mapID = vendor.mapID,
            faction = vendor.faction,
            coords = vendor.coords or (vendor.x and vendor.y and {x = vendor.x, y = vendor.y}),
            cost = cost,
        }
    end

    return nil
end

-------------------------------------------------------------------------------
-- Source Type Checkers
-------------------------------------------------------------------------------

function SourceManager:IsVendorItem(itemID)
    return self:GetVendorSource(itemID) ~= nil
end

function SourceManager:IsQuestItem(itemID)
    return HA.QuestSources and HA.QuestSources[itemID] ~= nil
end

function SourceManager:IsAchievementItem(itemID)
    return HA.AchievementSources and HA.AchievementSources[itemID] ~= nil
end

function SourceManager:IsProfessionItem(itemID)
    return HA.ProfessionSources and HA.ProfessionSources[itemID] ~= nil
end

function SourceManager:IsDropItem(itemID)
    return HA.DropSources and HA.DropSources[itemID] ~= nil
end

-------------------------------------------------------------------------------
-- Statistics
-------------------------------------------------------------------------------

function SourceManager:GetStats()
    local stats = {
        quests = 0,
        achievements = 0,
        professions = 0,
        drops = 0,
        vendors = 0,
    }

    if HA.QuestSources then
        for _ in pairs(HA.QuestSources) do
            stats.quests = stats.quests + 1
        end
    end

    if HA.AchievementSources then
        for _ in pairs(HA.AchievementSources) do
            stats.achievements = stats.achievements + 1
        end
    end

    if HA.ProfessionSources then
        for _ in pairs(HA.ProfessionSources) do
            stats.professions = stats.professions + 1
        end
    end

    if HA.DropSources then
        for _ in pairs(HA.DropSources) do
            stats.drops = stats.drops + 1
        end
    end

    -- Count unique items in VendorDatabase
    if HA.VendorDatabase and HA.VendorDatabase.ByItemID then
        for _ in pairs(HA.VendorDatabase.ByItemID) do
            stats.vendors = stats.vendors + 1
        end
    end

    stats.total = stats.quests + stats.achievements + stats.professions + stats.drops + stats.vendors

    return stats
end

-------------------------------------------------------------------------------
-- Debug Commands
-------------------------------------------------------------------------------

function SourceManager:DebugItem(itemID)
    if not HA.Addon then return end

    HA.Addon:Debug("=== Source Debug for itemID:", itemID, "===")

    local source = self:GetSource(itemID)
    if source then
        HA.Addon:Debug("Primary source:", source.type)
        if source.type == "vendor" then
            HA.Addon:Debug("  Vendor:", source.data.name)
            HA.Addon:Debug("  Zone:", source.data.zone)
            if source.data.cost then
                local costStr = HA.VendorData and HA.VendorData:FormatCost(source.data.cost) or "has cost"
                HA.Addon:Debug("  Cost:", costStr)
            end
        elseif source.type == "quest" then
            HA.Addon:Debug("  Quest:", source.data.questName)
            HA.Addon:Debug("  Quest ID:", source.data.questID)
        elseif source.type == "achievement" then
            HA.Addon:Debug("  Achievement:", source.data.achievementName)
            HA.Addon:Debug("  Achievement ID:", source.data.achievementID)
        elseif source.type == "profession" then
            HA.Addon:Debug("  Profession:", source.data.profession)
            HA.Addon:Debug("  Recipe:", source.data.recipeName)
        elseif source.type == "drop" then
            HA.Addon:Debug("  Mob:", source.data.mobName)
            HA.Addon:Debug("  Zone:", source.data.zone)
            if source.data.notes then
                HA.Addon:Debug("  Notes:", source.data.notes)
            end
        end
    else
        HA.Addon:Debug("No source found for this item")
    end

    -- Show all sources
    local allSources = self:GetAllSources(itemID)
    if #allSources > 1 then
        HA.Addon:Debug("All sources:", #allSources)
        for i, src in ipairs(allSources) do
            HA.Addon:Debug("  ", i, "-", src.type)
        end
    end
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function SourceManager:Initialize()
    local stats = self:GetStats()

    if HA.Addon then
        HA.Addon:Debug("SourceManager initialized")
        HA.Addon:Debug("  Quest sources:", stats.quests)
        HA.Addon:Debug("  Achievement sources:", stats.achievements)
        HA.Addon:Debug("  Profession sources:", stats.professions)
        HA.Addon:Debug("  Drop sources:", stats.drops)
    end
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("SourceManager", SourceManager)
end
