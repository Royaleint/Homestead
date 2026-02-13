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

    -- Priority 6: Parsed sourceText (runtime discovery fallback, gated)
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.useParsedSources then
        local parsedSource = self:GetParsedSource(itemID)
        if parsedSource then
            return parsedSource
        end
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

    -- Parsed sources (gated behind useParsedSources)
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.useParsedSources then
        if HA.SourceTextScanner then
            local parsed = HA.SourceTextScanner:GetParsedSource(itemID)
            if parsed and parsed.sources then
                -- Composite dedupe: sourceType + name + zone
                local seen = {}
                for _, existing in ipairs(sources) do
                    local key = (existing.type or "") .. "|" .. (existing.data and existing.data.name or "") .. "|" .. (existing.data and existing.data.zone or "")
                    seen[key] = true
                end
                for _, s in ipairs(parsed.sources) do
                    local key = (s.sourceType or "") .. "|" .. (s.name or "") .. "|" .. (s.zone or "")
                    if not seen[key] then
                        seen[key] = true
                        table.insert(sources, { type = s.sourceType, data = s, _isParsed = true })
                    end
                end
            end
        end
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

        -- Try to get cost data for this item (handles both static and scanned formats)
        local cost = nil
        if vendor.items then
            for _, item in ipairs(vendor.items) do
                local vendorItemID = HA.VendorData:GetItemID(item) or item.itemID
                if vendorItemID == itemID then
                    cost = HA.VendorData:GetItemCost(item)
                    -- If no static-format cost, try scanned format normalization
                    if not cost and vendor._isScanned then
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

-- Helper: Get best parsed source for an item (from SourceTextScanner)
function SourceManager:GetParsedSource(itemID)
    if not HA.SourceTextScanner then return nil end
    local parsed = HA.SourceTextScanner:GetParsedSource(itemID)
    if not parsed or not parsed.sources or #parsed.sources == 0 then return nil end

    local priorityOrder = { vendor = 1, quest = 2, achievement = 3, profession = 4, drop = 5 }
    local best, bestP = nil, 999
    for _, s in ipairs(parsed.sources) do
        local p = priorityOrder[s.sourceType] or 6
        if p < bestP then bestP = p; best = s end
    end
    if best then
        return { type = best.sourceType, data = best, _isParsed = true }
    end
    return nil
end

-------------------------------------------------------------------------------
-- Requirements Lookup
-------------------------------------------------------------------------------

-- Get acquisition requirements for an item, optionally scoped to a vendor.
-- Resolution priority (per plan gap #7):
--   1. Vendor-specific: scannedVendors[npcID].items[i].requirements
--   2. Item-level fallback: CatalogStore:GetRequirements(itemID)
-- NOT gated by useParsedSources — requirements are always surfaced.
-- Returns: array of requirement tables, or nil if none found
function SourceManager:GetRequirements(itemID, npcID)
    if not itemID then return nil end

    -- Priority 1: Vendor-specific requirements from scanned data
    if npcID and HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
        local vendor = HA.Addon.db.global.scannedVendors[npcID]
        if vendor then
            local items = vendor.items
            if items then
                for _, item in ipairs(items) do
                    local vendorItemID = item.itemID or (type(item) == "table" and item[1]) or (type(item) == "number" and item)
                    if vendorItemID == itemID and item.requirements and #item.requirements > 0 then
                        return item.requirements
                    end
                end
            end
        end
    end

    -- Priority 2: Item-level from CatalogStore
    if HA.CatalogStore then
        local reqs = HA.CatalogStore:GetRequirements(itemID)
        if reqs and #reqs > 0 then
            return reqs
        end
    end

    return nil
end

-- Check if a specific requirement is met by the player.
-- Returns: true (met), false (unmet), nil (cannot determine)
function SourceManager:IsRequirementMet(req)
    if not req or not req.type then return nil end

    if req.type == "reputation" then
        -- Check faction standing
        if req.faction and req.standing and C_Reputation and C_Reputation.GetFactionDataByName then
            local factionData = C_Reputation.GetFactionDataByName(req.faction)
            if factionData then
                -- Standing names in order: Hated(1) → Exalted(8) for old, or renown for new
                local standingOrder = {
                    ["Hated"] = 1, ["Hostile"] = 2, ["Unfriendly"] = 3, ["Neutral"] = 4,
                    ["Friendly"] = 5, ["Honored"] = 6, ["Revered"] = 7, ["Exalted"] = 8,
                }
                local requiredLevel = standingOrder[req.standing]
                local currentLevel = factionData.reaction
                if requiredLevel and currentLevel then
                    return currentLevel >= requiredLevel
                end
            end
        end
        return nil  -- Cannot determine

    elseif req.type == "level" then
        if req.level and UnitLevel then
            return UnitLevel("player") >= req.level
        end
        return nil

    elseif req.type == "achievement" then
        if req.id and GetAchievementInfo then
            local _, _, _, completed = GetAchievementInfo(req.id)
            return completed
        end
        return nil
    end

    return nil  -- Unknown requirement type
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
