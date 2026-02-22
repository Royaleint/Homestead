--[[
    Homestead - SourceManager
    Unified source lookup for housing decor items

    Fixed priority order used by GetSource():
    1. Vendor (most actionable - player can go buy it)
    2. Quest (specific acquisition path)
    3. Achievement (specific goal to work toward)
    4. Profession (craftable)
    5. Event (seasonal holiday vendor - time-gated)
    6. Drop (RNG-based)

    For availability-aware selection (requirements met "right now"):
        local source = HA.SourceManager:GetBestAvailableSource(itemID)

    Usage:
        local source = HA.SourceManager:GetSource(itemID)
        if source then
            print(source.type)  -- "vendor", "quest", "achievement", "profession", "event", "drop"
            print(source.data)  -- Source-specific data table
        end
]]

local _, HA = ...

-- Create SourceManager module
local SourceManager = {}
HA.SourceManager = SourceManager

-- Cache for completion status checks used by tooltip rendering.
-- Keys are source-scoped ("achievement:12345", "quest:98765", "profession:54321").
local completionCache = {}
local completionInvalidationFrame = nil

-------------------------------------------------------------------------------
-- Source Lookup
-------------------------------------------------------------------------------

-- Get the primary source for an item
-- Returns: {type = "vendor|quest|achievement|profession|event|drop", data = {...}} or nil
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

    -- Priority 5: Event source (seasonal holiday vendors)
    if HA.EventSources and HA.EventSources[itemID] then
        return {type = "event", data = HA.EventSources[itemID]}
    end

    -- Priority 6: Drop source
    if HA.DropSources and HA.DropSources[itemID] then
        return {type = "drop", data = HA.DropSources[itemID]}
    end

    -- Priority 7: Parsed sourceText (runtime discovery fallback, gated)
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.useParsedSources then
        local parsedSource = self:GetParsedSource(itemID)
        if parsedSource then
            return parsedSource
        end
    end

    return nil
end

-- Check whether a specific source is currently available to this character.
-- Returns:
--   true  = available now
--   false = known blocked (requirements unmet / event inactive / etc.)
--   nil   = unknown (insufficient data)
function SourceManager:IsSourceAvailableNow(itemID, source)
    if not itemID or not source or not source.type then return nil end

    local sourceType = source.type
    local data = source.data or {}

    -- Vendor requirements are the most precise because we can vendor-scope lookup.
    if sourceType == "vendor" then
        local vendorNPCID = data.npcID
        if vendorNPCID then
            local reqs = self:GetRequirements(itemID, vendorNPCID)
            if reqs and #reqs > 0 then
                for _, req in ipairs(reqs) do
                    local met = self:IsRequirementMet(req)
                    if met == false then
                        return false
                    end
                end
            end
        end
        return true
    end

    -- Event sources are unavailable when the event is known inactive.
    if sourceType == "event" then
        if HA.CalendarDetector and data.event then
            local isActive = HA.CalendarDetector:IsHolidayActive(data.event)
            if isActive == false then
                return false
            end
        end
        return true
    end

    -- Quest/Achievement sources are always "available" — they represent the
    -- acquisition path itself, not a gatekeeper.  A player who doesn't own
    -- the item yet needs to see "complete quest X" or "earn achievement Y",
    -- so hiding them when incomplete would be backwards.
    if sourceType == "quest" or sourceType == "achievement" then
        return true
    end

    -- Profession/drop and unknown types: treat as available unless explicitly blocked.
    return true
end

-- Get the highest-priority source that appears available "right now".
-- Falls back to nil if every known source is blocked.
function SourceManager:GetBestAvailableSource(itemID)
    if not itemID then return nil end

    local sources = self:GetAllSources(itemID)
    if #sources == 0 then return nil end

    for _, source in ipairs(sources) do
        local available = self:IsSourceAvailableNow(itemID, source)
        if available ~= false then
            return source
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

    -- Event source (seasonal holiday vendors)
    if HA.EventSources and HA.EventSources[itemID] then
        table.insert(sources, {type = "event", data = HA.EventSources[itemID]})
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
            subzone = vendor.subzone,
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

    local priorityOrder = { vendor = 1, quest = 2, achievement = 3, profession = 4, event = 5, drop = 6 }
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
--   4. Blizzard-confirmed vendor prerequisites: PrerequisiteSources[itemID]
--   5. Static achievement source data: AchievementSources[itemID]
--   6. Static quest source data: QuestSources[itemID]
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

    -- Priority 4: Blizzard-confirmed vendor prerequisites (PrerequisiteSources.lua)
    if HA.PrerequisiteSources and HA.PrerequisiteSources[itemID] then
        return HA.PrerequisiteSources[itemID]
    end

    -- Priority 5: Static achievement source data (AchievementSources.lua)
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

    -- Priority 6: Static quest source data (QuestSources.lua)
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

-- Get detailed reputation progress for a requirement.
-- Returns: {met = bool|nil, currentText = string, requiredText = string,
--           isRenown = bool, factionName = string} or nil
function SourceManager:GetRequirementProgress(req)
    if not req or req.type ~= "reputation" then return nil end
    if not req.faction or not req.standing then return nil end

    local factionID = GetFactionIDByName(req.faction)
    if not factionID then return nil end

    -- Renown-style standing (e.g., "Renown 12")
    local renownLevel = req.standing:match("^[Rr]enown%s+(%d+)$")
    if renownLevel then
        renownLevel = tonumber(renownLevel)
        if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
            local majorData = C_MajorFactions.GetMajorFactionData(factionID)
            if majorData and majorData.renownLevel then
                return {
                    met = majorData.renownLevel >= renownLevel,
                    currentText = tostring(majorData.renownLevel),
                    requiredText = tostring(renownLevel),
                    isRenown = true,
                    factionName = req.faction,
                }
            end
        end
        return nil
    end

    -- Traditional reputation standing
    local standingNames = {
        [1] = "Hated", [2] = "Hostile", [3] = "Unfriendly", [4] = "Neutral",
        [5] = "Friendly", [6] = "Honored", [7] = "Revered", [8] = "Exalted",
    }
    local standingOrder = {
        ["Hated"] = 1, ["Hostile"] = 2, ["Unfriendly"] = 3, ["Neutral"] = 4,
        ["Friendly"] = 5, ["Honored"] = 6, ["Revered"] = 7, ["Exalted"] = 8,
    }

    if C_Reputation and C_Reputation.GetFactionDataByID then
        local factionData = C_Reputation.GetFactionDataByID(factionID)
        if factionData then
            local requiredLevel = standingOrder[req.standing]
            local currentLevel = factionData.reaction
            if requiredLevel and currentLevel then
                return {
                    met = currentLevel >= requiredLevel,
                    currentText = standingNames[currentLevel] or ("Rank " .. currentLevel),
                    requiredText = req.standing,
                    isRenown = false,
                    factionName = req.faction,
                }
            end
        end
    end

    return nil
end

-------------------------------------------------------------------------------
-- Source Type Checkers
-------------------------------------------------------------------------------

-- Canonical source taxonomy used by filtering and reporting.
local SOURCE_TYPE_ORDER = { "vendor", "quest", "achievement", "profession", "event", "drop" }
local CANONICAL_SOURCE_TYPES = {
    vendor = true,
    quest = true,
    achievement = true,
    profession = true,
    event = true,
    drop = true,
}
local SOURCE_TYPE_ALIASES = {
    craft = "profession", -- Legacy constant alias
}

local function ForEachItemID(itemIDs, callback)
    if type(itemIDs) ~= "table" or type(callback) ~= "function" then
        return
    end

    -- Array-style input: {1001, 1002, ...}
    if itemIDs[1] ~= nil then
        for _, itemID in ipairs(itemIDs) do
            callback(itemID)
        end
        return
    end

    -- Set-style input: {[1001] = true, [1002] = true}
    for itemID, included in pairs(itemIDs) do
        if included then
            callback(itemID)
        end
    end
end

-- Normalize source type to canonical values used by SourceManager.
-- Accepts legacy aliases (e.g. "craft" -> "profession").
-- Returns canonical source type or nil if unsupported.
function SourceManager:NormalizeSourceType(sourceType)
    if type(sourceType) ~= "string" then return nil end

    local normalized = sourceType:lower()
    normalized = SOURCE_TYPE_ALIASES[normalized] or normalized

    if CANONICAL_SOURCE_TYPES[normalized] then
        return normalized
    end
    return nil
end

-- Normalize source filter tokens used by UI/cache consumers.
-- Returns:
--   "all" for nil/empty/"all"
--   canonical source type for known values (including aliases)
--   lowercase token for unknown values (forward compatibility)
function SourceManager:NormalizeSourceFilter(sourceFilter)
    if type(sourceFilter) ~= "string" or sourceFilter == "" then
        return "all"
    end

    local lower = sourceFilter:lower()
    if lower == "all" then
        return "all"
    end

    local normalized = self:NormalizeSourceType(lower)
    if normalized then
        return normalized
    end

    return lower
end

-- Return canonical source type list in stable priority order.
function SourceManager:GetCanonicalSourceTypes()
    local copy = {}
    for i, sourceType in ipairs(SOURCE_TYPE_ORDER) do
        copy[i] = sourceType
    end
    return copy
end

-- Return primary source type for an item, normalized to canonical taxonomy.
function SourceManager:GetPrimarySourceType(itemID)
    local source = self:GetSource(itemID)
    if not source or not source.type then return nil end
    return self:NormalizeSourceType(source.type)
end

-- Return per-item source classification flags.
-- isVendorContext=true marks vendor filter as implicit true for vendor-scoped lists
-- (e.g. map panel rows built from a known vendor's inventory).
function SourceManager:GetItemSourceTypes(itemID, isVendorContext)
    local flags = {
        vendor = false,
        quest = false,
        achievement = false,
        profession = false,
        event = false,
        drop = false,
    }
    if not itemID then
        return flags
    end

    flags.vendor = (isVendorContext == true) or self:IsVendorItem(itemID)
    flags.quest = self:IsQuestItem(itemID)
    flags.achievement = self:IsAchievementItem(itemID)
    flags.profession = self:IsProfessionItem(itemID)
    flags.event = self:IsEventItem(itemID)
    flags.drop = self:IsDropItem(itemID)

    return flags
end

-- Inclusive item filter predicate.
-- filterType:
--   "all" or nil -> always true
--   canonical source type -> true when item has that source
--   alias type (e.g. "craft") -> normalized then evaluated
-- isVendorContext=true treats vendor type as implicit true.
function SourceManager:ItemMatchesSourceFilter(itemID, filterType, isVendorContext)
    if filterType == nil then return true end
    if type(filterType) == "string" and filterType:lower() == "all" then return true end
    if not itemID then return false end

    local normalizedType = self:NormalizeSourceType(filterType)
    if not normalizedType then return false end

    if normalizedType == "vendor" and isVendorContext == true then
        return true
    end

    if normalizedType == "vendor" then
        return self:IsVendorItem(itemID)
    elseif normalizedType == "quest" then
        return self:IsQuestItem(itemID)
    elseif normalizedType == "achievement" then
        return self:IsAchievementItem(itemID)
    elseif normalizedType == "profession" then
        return self:IsProfessionItem(itemID)
    elseif normalizedType == "event" then
        return self:IsEventItem(itemID)
    elseif normalizedType == "drop" then
        return self:IsDropItem(itemID)
    end

    return false
end

-- Count items by source type.
-- itemIDs can be either:
--   array form: {1001, 1002, ...}
--   set form: {[1001] = true, [1002] = true}
-- mode:
--   "inclusive" (default): item increments every matching source bucket
--   "primary": item increments only its primary source bucket (GetSource priority)
-- Returns:
--   { vendor=0, quest=0, achievement=0, profession=0, event=0, drop=0, unknown=0 }
function SourceManager:CountItemsBySourceType(itemIDs, mode, isVendorContext)
    local normalizedMode = (mode == "primary") and "primary" or "inclusive"
    local counts = {
        vendor = 0,
        quest = 0,
        achievement = 0,
        profession = 0,
        event = 0,
        drop = 0,
        unknown = 0,
    }
    local seen = {}

    ForEachItemID(itemIDs, function(itemID)
        if not itemID or seen[itemID] then return end
        seen[itemID] = true

        if normalizedMode == "primary" then
            local primaryType = self:GetPrimarySourceType(itemID)
            if primaryType and counts[primaryType] ~= nil then
                counts[primaryType] = counts[primaryType] + 1
            else
                counts.unknown = counts.unknown + 1
            end
            return
        end

        local matched = false
        local flags = self:GetItemSourceTypes(itemID, isVendorContext)
        for _, sourceType in ipairs(SOURCE_TYPE_ORDER) do
            if flags[sourceType] then
                counts[sourceType] = counts[sourceType] + 1
                matched = true
            end
        end
        if not matched then
            counts.unknown = counts.unknown + 1
        end
    end)

    return counts
end

-------------------------------------------------------------------------------
-- Completion Status / Source Cache Helpers
-------------------------------------------------------------------------------

local function CopyCompletionStatus(status)
    if not status then return nil end
    return {
        color = status.color,
        suffix = status.suffix,
        met = status.met,
    }
end

local function ResolveCompletionSource(itemID, sourceType, sourceData)
    local normalizedType = sourceType and SourceManager:NormalizeSourceType(sourceType) or nil
    if normalizedType then
        return normalizedType, sourceData
    end
    if not itemID then
        return nil, nil
    end

    -- Keep legacy priority used by tooltips when sourceType isn't explicit.
    if HA.AchievementSources and HA.AchievementSources[itemID] then
        return "achievement", HA.AchievementSources[itemID]
    end
    if HA.QuestSources and HA.QuestSources[itemID] then
        return "quest", HA.QuestSources[itemID]
    end
    if HA.ProfessionSources and HA.ProfessionSources[itemID] then
        return "profession", HA.ProfessionSources[itemID]
    end

    return nil, nil
end

-- Returns completion state for source types that can be checked at runtime.
-- Response shape:
--   { color = "|cFF......", suffix = " (...)", met = true|false|nil } or nil.
function SourceManager:GetCompletionStatus(itemID, sourceType, sourceData)
    local resolvedType, resolvedData = ResolveCompletionSource(itemID, sourceType, sourceData)
    if not resolvedType then return nil end

    if resolvedType == "achievement" then
        local achievementID = resolvedData and resolvedData.achievementID
        if not achievementID or not GetAchievementInfo then return nil end

        local cacheKey = "achievement:" .. achievementID
        if completionCache[cacheKey] then
            return CopyCompletionStatus(completionCache[cacheKey])
        end

        local id, _, _, completed, _, _, _, _, _, _, _, _, wasEarnedByMe = GetAchievementInfo(achievementID)
        if not id then
            return nil
        end

        local result
        if wasEarnedByMe then
            result = { color = "|cFF00FF00", suffix = " (This Character)", met = true }
        elseif completed then
            result = { color = "|cFF66FF66", suffix = " (Account)", met = true }
        else
            result = { color = "|cFFFF0000", suffix = " (Incomplete)", met = false }
        end

        completionCache[cacheKey] = result
        return CopyCompletionStatus(result)
    end

    if resolvedType == "quest" then
        local questID = resolvedData and resolvedData.questID
        if not questID or not C_QuestLog or not C_QuestLog.IsQuestFlaggedCompleted then return nil end

        local cacheKey = "quest:" .. questID
        if completionCache[cacheKey] then
            return CopyCompletionStatus(completionCache[cacheKey])
        end

        local completed = C_QuestLog.IsQuestFlaggedCompleted(questID)
        local result = completed
            and { color = "|cFF00FF00", suffix = " (Completed)", met = true }
            or { color = "|cFFFF0000", suffix = " (Incomplete)", met = false }

        completionCache[cacheKey] = result
        return CopyCompletionStatus(result)
    end

    if resolvedType == "profession" then
        local spellID = resolvedData and resolvedData.spellID
        if not spellID then return nil end

        local tradeSkillUI = _G and _G.C_TradeSkillUI
        if not tradeSkillUI or not tradeSkillUI.GetRecipeInfo then
            -- API unavailable until profession systems are ready/opened.
            return { color = "|cFF808080", suffix = " (Unknown)", met = nil }
        end

        local recipeInfo = tradeSkillUI.GetRecipeInfo(spellID)
        if not recipeInfo then
            return { color = "|cFF808080", suffix = " (Unknown)", met = nil }
        end

        local result
        if recipeInfo.craftable then
            result = { color = "|cFF00FF00", suffix = " (Can Craft Now)", met = true }
        elseif recipeInfo.learned then
            result = { color = "|cFF66FF66", suffix = " (Recipe Known)", met = true }
        else
            result = { color = "|cFFFF0000", suffix = " (Recipe Unknown)", met = false }
        end

        return CopyCompletionStatus(result)
    end

    return nil
end

-- Build a set of source types that should suppress requirement duplication in tooltips.
function SourceManager:BuildRequirementDedupSet(sourceTypes)
    local dedup = {}
    if type(sourceTypes) ~= "table" then
        return dedup
    end

    for _, sourceType in pairs(sourceTypes) do
        local normalized = self:NormalizeSourceType(sourceType)
        if normalized == "achievement" or normalized == "quest" then
            dedup[normalized] = true
        end
    end

    return dedup
end

function SourceManager:InvalidateCompletionCache()
    completionCache = {}
end

-- Central invalidation entrypoint for source-related caches.
-- Future source/filter caches should be added here so callers have one API.
function SourceManager:InvalidateAllSourceCaches()
    self:InvalidateCompletionCache()
end

local function HookCompletionCacheInvalidation()
    if completionInvalidationFrame then return end

    completionInvalidationFrame = CreateFrame("Frame")
    completionInvalidationFrame:RegisterEvent("ACHIEVEMENT_EARNED")
    completionInvalidationFrame:RegisterEvent("QUEST_TURNED_IN")
    completionInvalidationFrame:RegisterEvent("NEW_RECIPE_LEARNED")
    completionInvalidationFrame:SetScript("OnEvent", function()
        SourceManager:InvalidateAllSourceCaches()
    end)
end

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

function SourceManager:IsEventItem(itemID)
    return HA.EventSources and HA.EventSources[itemID] ~= nil
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
        events = 0,
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

    if HA.EventSources then
        for k in pairs(HA.EventSources) do
            if type(k) == "number" then  -- Skip EventDefinitions key
                stats.events = stats.events + 1
            end
        end
    end

    if HA.DropSources then
        for _ in pairs(HA.DropSources) do
            stats.drops = stats.drops + 1
        end
    end

    -- Count unique items in VendorDatabase + EndeavorsData
    if HA.VendorDatabase and HA.VendorDatabase.ByItemID then
        for _ in pairs(HA.VendorDatabase.ByItemID) do
            stats.vendors = stats.vendors + 1
        end
    end
    if HA.EndeavorsData and HA.EndeavorsData.ByItemID then
        for _ in pairs(HA.EndeavorsData.ByItemID) do
            stats.vendors = stats.vendors + 1
        end
    end

    stats.total = stats.quests + stats.achievements + stats.professions + stats.events + stats.drops + stats.vendors

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
        elseif source.type == "event" then
            HA.Addon:Debug("  Event:", source.data.event)
            HA.Addon:Debug("  Vendor:", source.data.vendorName)
            HA.Addon:Debug("  Zone:", source.data.zone)
            HA.Addon:Debug("  Currency:", source.data.currency)
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
    HookCompletionCacheInvalidation()

    local stats = self:GetStats()

    if HA.Addon then
        HA.Addon:Debug("SourceManager initialized")
        HA.Addon:Debug("  Quest sources:", stats.quests)
        HA.Addon:Debug("  Achievement sources:", stats.achievements)
        HA.Addon:Debug("  Profession sources:", stats.professions)
        HA.Addon:Debug("  Event sources:", stats.events)
        HA.Addon:Debug("  Drop sources:", stats.drops)
    end
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("SourceManager", SourceManager)
end

