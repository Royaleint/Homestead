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
    if not HA.VendorData or not HA.VendorData.GetClosestVendorForItem then
        return nil
    end

    local vendor = HA.VendorData:GetClosestVendorForItem(itemID)
    if vendor then

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
-- Resolution priority:
--   1. Vendor-specific: scannedVendors[npcID].items[i].requirements (tooltip scraping)
--   2. Item-level fallback: CatalogStore:GetRequirements(itemID)
--   3. Parsed sourceText: parsedSources[itemID].sources[].faction/standing
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
                    local vendorItemID = HA.VendorData:GetItemID(item)
                    if vendorItemID == itemID and item.requirements and #item.requirements > 0 then
                        -- Validate requirements are usable (have type + id/name/faction)
                        local usable = false
                        for _, req in ipairs(item.requirements) do
                            if req.type == "reputation" and req.faction then
                                usable = true; break
                            elseif req.type == "achievement" and (req.id or req.name) then
                                usable = true; break
                            elseif req.type == "quest" and (req.id or req.name) then
                                usable = true; break
                            elseif req.type == "level" and req.level then
                                usable = true; break
                            end
                        end
                        if usable then
                            return item.requirements
                        end
                        -- Unusable requirements (type="unknown", no data) — fall through
                    end
                end
            end
        end
    end

    -- Priority 2: Item-level from CatalogStore
    if HA.CatalogStore then
        local reqs = HA.CatalogStore:GetRequirements(itemID)
        if reqs and #reqs > 0 then
            -- Validate at least one requirement is usable
            for _, req in ipairs(reqs) do
                if (req.type == "reputation" and req.faction)
                    or (req.type == "achievement" and (req.id or req.name))
                    or (req.type == "quest" and (req.id or req.name))
                    or (req.type == "level" and req.level) then
                    return reqs
                end
            end
            -- All unusable — fall through to other sources
        end
    end

    -- Priority 3: Faction/standing from parsed sourceText (no vendor visit needed)
    if HA.Addon and HA.Addon.db and HA.Addon.db.global.parsedSources then
        local parsed = HA.Addon.db.global.parsedSources[itemID]
        if parsed and parsed.sources then
            for _, source in ipairs(parsed.sources) do
                if source.faction and source.standing then
                    return {{
                        type = "reputation",
                        faction = source.faction,
                        standing = source.standing,
                    }}
                end
            end
        end
    end

    -- Priority 4: Static achievement source data (AchievementSources.lua)
    if HA.AchievementSources and HA.AchievementSources[itemID] then
        local src = HA.AchievementSources[itemID]
        if src.achievementID then
            return {{
                type = "achievement",
                id = src.achievementID,
                name = src.achievementName or ("Achievement #" .. src.achievementID),
            }}
        end
    end

    -- Priority 5: Static quest source data (QuestSources.lua)
    if HA.QuestSources and HA.QuestSources[itemID] then
        local src = HA.QuestSources[itemID]
        if src.questID then
            return {{
                type = "quest",
                id = src.questID,
                name = src.questName or ("Quest #" .. src.questID),
            }}
        end
    end

    return nil
end

-- Lazy-built cache: faction name → factionID (populated on first use)
local factionNameToID = nil

-- Build faction name→ID cache from the player's reputation panel + major factions
local function GetFactionIDByName(name)
    if not name then return nil end

    -- Build cache on first call
    if not factionNameToID then
        factionNameToID = {}
        -- Scan reputation panel entries
        if C_Reputation and C_Reputation.GetNumFactions then
            for i = 1, C_Reputation.GetNumFactions() do
                local data = C_Reputation.GetFactionDataByIndex(i)
                if data and data.name and data.factionID then
                    factionNameToID[data.name] = data.factionID
                end
            end
        end
        -- Also scan major factions (renown-based, DF/TWW)
        if C_MajorFactions and C_MajorFactions.GetMajorFactionIDs then
            for _, factionID in ipairs(C_MajorFactions.GetMajorFactionIDs()) do
                local data = C_MajorFactions.GetMajorFactionData(factionID)
                if data and data.name then
                    factionNameToID[data.name] = factionID
                end
            end
        end
    end

    return factionNameToID[name]
end

-- Check if a specific requirement is met by the player.
-- Returns: true (met), false (unmet), nil (cannot determine)
function SourceManager:IsRequirementMet(req)
    if not req or not req.type then return nil end

    if req.type == "reputation" then
        if req.faction and req.standing then
            local factionID = GetFactionIDByName(req.faction)
            if not factionID then return nil end

            -- Check for renown-style standing (e.g., "Renown 12")
            local renownLevel = req.standing:match("^[Rr]enown%s+(%d+)$")
            if renownLevel then
                renownLevel = tonumber(renownLevel)
                if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
                    local majorData = C_MajorFactions.GetMajorFactionData(factionID)
                    if majorData and majorData.renownLevel then
                        return majorData.renownLevel >= renownLevel
                    end
                end
                return nil  -- Cannot determine renown
            end

            -- Traditional reputation standing (Hated → Exalted)
            if C_Reputation and C_Reputation.GetFactionDataByID then
                local factionData = C_Reputation.GetFactionDataByID(factionID)
                if factionData then
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
        end
        return nil  -- Cannot determine

    elseif req.type == "level" then
        if req.level and UnitLevel then
            return UnitLevel("player") >= req.level
        end
        return nil

    elseif req.type == "achievement" then
        local achID = req.id
        -- If no ID but we have a name, try to find the ID from AchievementSources
        if not achID and req.name and HA.AchievementSources then
            for _, src in pairs(HA.AchievementSources) do
                if src.achievementName == req.name then
                    achID = src.achievementID
                    break
                end
            end
        end
        if achID and GetAchievementInfo then
            local _, _, _, completed = GetAchievementInfo(achID)
            return completed
        end
        return nil

    elseif req.type == "quest" then
        if req.id and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
            return C_QuestLog.IsQuestFlaggedCompleted(req.id)
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
