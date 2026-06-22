--[[
    Homestead - SourceManager
    Unified source lookup for housing decor items

    Fixed priority order used by GetSource():
    1. Vendor (most actionable - player can go buy it)
    2. Quest (specific acquisition path)
    3. Achievement (specific goal to work toward)
    4. Profession (craftable)
    5. Event (seasonal holiday vendor - time-gated)
    6. Shop (in-game shop)
    7. Drop (RNG-based)

    For availability-aware selection (requirements met "right now"):
        local source = HA.SourceManager:GetBestAvailableSource(itemID)

    Usage:
        local source = HA.SourceManager:GetSource(itemID)
        if source then
            print(source.type)  -- "vendor", "quest", "achievement", "profession", "event", "shop", "drop"
            print(source.data)  -- Source-specific data table
        end
]]

local _, HA = ...

-- Create SourceManager module
local SourceManager = {}
HA.SourceManager = SourceManager

-- Source provider registry (internal).
-- Each provider: { getSource = fn(itemID), getSources = fn(itemID) }
-- Provider closures are allocated once at registration time; result tables
-- ({type, data}) are allocated per call — acceptable for tooltip-frequency paths.
local sourceProviders = {}  -- name → provider table
local providerOrder = {}    -- ordered list of provider names (rebuilt on registration)
local providersRegistered = false
local sourceManagerInitialized = false
local SOURCE_TYPE_ORDER = { "vendor", "quest", "achievement", "profession", "event", "shop", "drop" }
local EMPTY_SOURCES = {}

-- Cache for completion status checks used by tooltip rendering.
-- Keys are source-scoped ("achievement:12345", "quest:98765", "profession:54321").
local completionCache = {}
local completionInvalidationFrame = nil

-------------------------------------------------------------------------------
-- Provider Registry
-------------------------------------------------------------------------------

-- Register a source provider. Provider table must have:
--   getSource(itemID)  → {type, data} or nil  (single best result)
--   getSources(itemID) → {{type, data}, ...}   (all results)
-- Provider closures are created once at registration; result tables are per-call.
function SourceManager:RegisterProvider(name, provider)
    sourceProviders[name] = provider
    -- Rebuild ordered list from SOURCE_TYPE_ORDER
    -- to maintain priority sequence. Only includes registered types.
    providerOrder = {}
    for _, stype in ipairs(SOURCE_TYPE_ORDER) do
        if sourceProviders[stype] then
            providerOrder[#providerOrder + 1] = stype
        end
    end
end

-- Register the 6 built-in source types as providers.
-- Called once from Initialize(). Each closure captures its data source
-- reference at call time — no per-lookup allocation.
local function RegisterDefaultProviders()
    if providersRegistered then return end
    providersRegistered = true

    SourceManager:RegisterProvider("vendor", {
        getSource = function(itemID)
            local vendorData = SourceManager:GetVendorSource(itemID)
            if vendorData then
                return {type = "vendor", data = vendorData}
            end
        end,
        getSources = function(itemID)
            return SourceManager:GetVendorSources(itemID)
        end,
    })

    SourceManager:RegisterProvider("quest", {
        getSource = function(itemID)
            if HA.QuestSources and HA.QuestSources[itemID] then
                return {type = "quest", data = HA.QuestSources[itemID]}
            end
        end,
        getSources = function(itemID)
            if HA.QuestSources and HA.QuestSources[itemID] then
                return {{type = "quest", data = HA.QuestSources[itemID]}}
            end
            return EMPTY_SOURCES
        end,
    })

    SourceManager:RegisterProvider("achievement", {
        getSource = function(itemID)
            if HA.AchievementSources and HA.AchievementSources[itemID] then
                return {type = "achievement", data = HA.AchievementSources[itemID]}
            end
        end,
        getSources = function(itemID)
            if HA.AchievementSources and HA.AchievementSources[itemID] then
                return {{type = "achievement", data = HA.AchievementSources[itemID]}}
            end
            return EMPTY_SOURCES
        end,
    })

    SourceManager:RegisterProvider("profession", {
        getSource = function(itemID)
            if HA.ProfessionSources and HA.ProfessionSources[itemID] then
                return {type = "profession", data = HA.ProfessionSources[itemID]}
            end
        end,
        getSources = function(itemID)
            if HA.ProfessionSources and HA.ProfessionSources[itemID] then
                return {{type = "profession", data = HA.ProfessionSources[itemID]}}
            end
            return EMPTY_SOURCES
        end,
    })

    SourceManager:RegisterProvider("event", {
        getSource = function(itemID)
            if HA.EventSources and HA.EventSources[itemID] then
                return {type = "event", data = HA.EventSources[itemID]}
            end
        end,
        getSources = function(itemID)
            if HA.EventSources and HA.EventSources[itemID] then
                return {{type = "event", data = HA.EventSources[itemID]}}
            end
            return EMPTY_SOURCES
        end,
    })

    SourceManager:RegisterProvider("drop", {
        getSource = function(itemID)
            if HA.DropSources and HA.DropSources[itemID] then
                return {type = "drop", data = HA.DropSources[itemID]}
            end
        end,
        getSources = function(itemID)
            if HA.DropSources and HA.DropSources[itemID] then
                return {{type = "drop", data = HA.DropSources[itemID]}}
            end
            return EMPTY_SOURCES
        end,
    })

    SourceManager:RegisterProvider("shop", {
        getSource = function(itemID)
            if HA.ShopSources and HA.ShopSources[itemID] then
                return {type = "shop", data = HA.ShopSources[itemID]}
            end
        end,
        getSources = function(itemID)
            if HA.ShopSources and HA.ShopSources[itemID] then
                return {{type = "shop", data = HA.ShopSources[itemID]}}
            end
            return EMPTY_SOURCES
        end,
    })
end

local function EnsureProvidersRegistered()
    if not providersRegistered then
        RegisterDefaultProviders()
    end
end

-------------------------------------------------------------------------------
-- Source Lookup
-------------------------------------------------------------------------------

-- Get the primary source for an item.
-- Primary source policy: first provider with a singular result wins.
-- This intentionally does NOT derive the result from GetAllSources()[1].
-- Vendor primary selection remains proximity-based via GetClosestVendorForItem().
-- Walks registered providers in priority order (SOURCE_TYPE_ORDER).
-- Returns: {type = "vendor|quest|achievement|profession|event|shop|drop", data = {...}} or nil
function SourceManager:GetSource(itemID)
    if not itemID then return nil end
    EnsureProvidersRegistered()

    -- Walk registered providers in priority order
    for _, name in ipairs(providerOrder) do
        local provider = sourceProviders[name]
        if provider and provider.getSource then
            local source = provider.getSource(itemID)
            if source then return source end
        end
    end

    -- Fallback: Parsed sourceText (runtime discovery, gated by profile setting).
    -- Not a registered provider — requires profile gating and dedup logic.
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.useParsedSources then
        local parsedSource = self:GetParsedSource(itemID)
        if parsedSource then
            return parsedSource
        end
    end

    return nil
end

local PROFESSION_NAME_TO_SKILLLINE_ID = {
    Alchemy = 171,
    Blacksmithing = 164,
    Cooking = 185,
    Enchanting = 333,
    Engineering = 202,
    Fishing = 356,
    Herbalism = 182,
    Inscription = 773,
    Jewelcrafting = 755,
    Leatherworking = 165,
    Mining = 186,
    Skinning = 393,
    Tailoring = 197,
}

local SECONDARY_PROFESSION_SKILL_LINES = {
    [185] = true, -- Cooking
    [356] = true, -- Fishing
}

local activeHolidayInvalidationRegistered = false

local function ResolveProfessionSkillLineID(sourceData)
    if type(sourceData) ~= "table" then return nil end
    if sourceData.skillLineID then return sourceData.skillLineID end

    local professionName = sourceData.profession
    if not professionName or professionName == "Miscellaneous" then
        return nil
    end

    return PROFESSION_NAME_TO_SKILLLINE_ID[professionName]
end

-- Check whether the player has the profession required by a source row.
-- Prefers locale-neutral skillLineID and falls back to a small canonical mapping
-- for existing profession source records that only store English names.
-- Returns true if the profession is available to the player, false otherwise.
function SourceManager:PlayerHasProfession(sourceData)
    local skillLineID = ResolveProfessionSkillLineID(sourceData)
    if not skillLineID then return nil end
    if SECONDARY_PROFESSION_SKILL_LINES[skillLineID] then return true end

    local getProfessions = _G and _G.GetProfessions
    local getProfessionInfo = _G and _G.GetProfessionInfo
    if not getProfessions or not getProfessionInfo then return nil end

    local prof1, prof2 = getProfessions()

    if prof1 then
        local _, _, _, _, _, _, skillLine = getProfessionInfo(prof1)
        if skillLine == skillLineID then return true end
    end

    if prof2 then
        local _, _, _, _, _, _, skillLine = getProfessionInfo(prof2)
        if skillLine == skillLineID then return true end
    end

    return false
end

-- Check whether the player meets the expansion-tier skill level for a recipe.
-- Uses C_TradeSkillUI to query expansion-specific skill levels (works without UI open).
-- Returns true if met, false if not, nil if can't determine.
function SourceManager:PlayerMeetsSkillLevel(sourceData)
    if type(sourceData) ~= "table" then return nil end
    local requiredTier = sourceData.skillTier
    local requiredLevel = sourceData.skillLevel
    if not requiredTier or not requiredLevel then return nil end

    local tradeSkillUI = _G and _G.C_TradeSkillUI
    if not tradeSkillUI or not tradeSkillUI.GetAllProfessionTradeSkillLines
            or not tradeSkillUI.GetProfessionInfoBySkillLineID then
        return nil
    end

    local skillLines = tradeSkillUI.GetAllProfessionTradeSkillLines()
    if not skillLines then return nil end

    for _, skillLineID in ipairs(skillLines) do
        local info = tradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
        if info and info.professionName == requiredTier then
            return (info.skillLevel or 0) >= requiredLevel
        end
    end

    -- Tier not found in player's skill lines — haven't trained this expansion tier
    return false
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

    -- Quest sources are always "available" — they represent the acquisition
    -- path itself, not a gatekeeper.
    if sourceType == "quest" then
        return true
    end

    -- Achievement sources: check whether the achievement is actually completed.
    -- Incomplete achievements mean the item isn't obtainable right now → blocked.
    -- The tooltip still shows the achievement name so the player knows the path.
    if sourceType == "achievement" then
        if data.achievementID and GetAchievementInfo then
            local _, _, _, completed = GetAchievementInfo(data.achievementID)
            return completed == true
        end
        return true  -- No achievementID to check → assume available
    end

    -- Profession sources: check whether the player has the required profession
    -- AND meets the expansion-tier skill level requirement.
    -- Uses C_TradeSkillUI.GetAllProfessionTradeSkillLines + GetProfessionInfoBySkillLineID
    -- to query expansion-specific skill levels (works without trade skill UI open).
    -- Secondary professions and miscellaneous recipes remain available to everyone.
    if sourceType == "profession" then
        local hasProf = self:PlayerHasProfession(data)
        if hasProf == false then
            return false
        end
        -- Check expansion-tier skill level when we have the required data.
        -- e.g., skillTier = "Midnight Leatherworking", skillLevel = 50
        if hasProf == true then
            local meetsLevel = self:PlayerMeetsSkillLevel(data)
            if meetsLevel == false then
                return false
            end
        end
        return true
    end

    -- Drop and unknown types: treat as available unless explicitly blocked.
    return true
end

-- Get the highest-priority source that appears available "right now".
-- Evaluates the full GetAllSources() result set, including multi-vendor rows,
-- and returns the first source not known to be blocked.
-- Falls back to nil if every known source is blocked.
-- Single-source tooltip policy: "best available" — returns the first source not
-- known to be blocked, not the first in priority order. This is the contract
-- used by showAllSources=false in AddSourceInfoToTooltip().
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

-- Get all sources for an item (for items with multiple acquisition methods).
-- Walks registered providers via getSources(), then appends parsed sources.
-- Unlike GetSource(), this returns every vendor location emitted by GetVendorSources().
-- Returns: array of {type = "...", data = {...}}
function SourceManager:GetAllSources(itemID)
    if not itemID then return {} end
    EnsureProvidersRegistered()

    local sources = {}

    -- Walk registered providers in priority order
    for _, name in ipairs(providerOrder) do
        local provider = sourceProviders[name]
        if provider and provider.getSources then
            local providerSources = provider.getSources(itemID)
            for _, source in ipairs(providerSources) do
                sources[#sources + 1] = source
            end
        end
    end

    -- Parsed sources fallback (gated, with composite dedup against static sources)
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
                        sources[#sources + 1] = { type = s.sourceType, data = s, _isParsed = true }
                    end
                end
            end
        end
    end

    return sources
end

local function GetPlacedCount(itemID)
    if not itemID then return 0 end
    if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
        local itemLink = "item:" .. tostring(itemID)
        local success, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, itemLink, true)
        if success and info then
            return info.numPlaced or 0
        end
    end
    return 0
end

function SourceManager:GetPlacedCountForItem(itemID)
    return GetPlacedCount(itemID)
end

local function BuildVendorSourceData(itemID, vendor)
    if not itemID or not vendor then return nil end

    local cost = nil
    if vendor.items and HA.VendorData then
        for _, item in ipairs(vendor.items) do
            local vendorItemID = HA.VendorData:GetItemID(item) or item.itemID
            if vendorItemID == itemID then
                cost = HA.VendorData:GetItemCost(item)
                if not cost and vendor._isScanned then
                    cost = HA.VendorData:NormalizeScannedCost(item)
                end
                break
            end
        end
    end

    return {
        vendor = vendor,
        npcID = vendor.npcID,
        name = vendor.name,
        vendorName = vendor.name,
        zone = vendor.zone,
        subzone = vendor.subzone,
        mapID = vendor.mapID,
        faction = vendor.faction,
        coords = vendor.coords or (vendor.x and vendor.y and {x = vendor.x, y = vendor.y}),
        cost = cost,
    }
end

-- Helper: Get vendor source from VendorData
function SourceManager:GetVendorSource(itemID)
    if not HA.VendorData or not HA.VendorData.GetClosestVendorForItem then
        return nil
    end

    local vendor = HA.VendorData:GetClosestVendorForItem(itemID)
    return BuildVendorSourceData(itemID, vendor)
end

-- Get ALL vendor sources for an item (not just the closest).
-- Returns array of {type = "vendor", data = {...}} entries.
function SourceManager:GetVendorSources(itemID)
    if not itemID or not HA.VendorData or not HA.VendorData.GetVendorsForItem then
        return EMPTY_SOURCES
    end

    local vendors = HA.VendorData:GetVendorsForItem(itemID)
    if not vendors or #vendors == 0 then
        return EMPTY_SOURCES
    end

    local sources = {}
    for _, vendor in ipairs(vendors) do
        local vendorData = BuildVendorSourceData(itemID, vendor)
        if vendorData then
            sources[#sources + 1] = { type = "vendor", data = vendorData }
        end
    end

    return sources
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

-- Try to convert a raw-text requirement into a structured reputation requirement.
-- Handles two formats from Blizzard's Housing Catalog requirement text:
--   Renown:     "Requires Renown Rank 15 with the Silvermoon Court."
--   Friendship: "Requires the Socialite rank or above with the Blood Knights of Silvermoon"
-- Returns structured {type="reputation", faction=..., standing=...} or nil.
local function parseRawRequirementText(text)
    if not text then return nil end

    -- Renown: "Requires Renown Rank 15 with the Silvermoon Court."
    -- (trailing period optional, "Rank"/"rank" case-insensitive)
    local renownLevel, renownFaction = text:match("^Requires Renown [Rr]ank (%d+) with the (.+)$")
    if not renownLevel then
        renownLevel, renownFaction = text:match("^Requires Renown [Rr]ank (%d+) with (.+)$")
    end
    if renownLevel and renownFaction then
        renownFaction = renownFaction:gsub("%.$", "")  -- strip trailing period
        return { type = "reputation", faction = renownFaction, standing = "Renown " .. renownLevel }
    end

    -- Friendship: "Requires the Socialite rank or above with the Blood Knights of Silvermoon"
    local rank, faction = text:match("^Requires the (.+) rank or above with the (.+)$")
    if rank and faction then
        return { type = "reputation", faction = faction, standing = rank }
    end

    return nil
end

-- Normalize a requirement and check whether it has enough data to be actionable.
-- Unknown-type requirements with parseable text are converted IN PLACE to
-- structured reputation requirements (mutates req.type, req.faction, req.standing,
-- clears req.text). This is a deliberate one-way upgrade of scanned data.
local function normalizeAndValidateRequirement(req)
    if not req or not req.type then return false end
    if req.type == "reputation" and req.faction then return true end
    if req.type == "achievement" and (req.id or req.name) then return true end
    if req.type == "quest" and (req.id or req.name) then return true end
    if req.type == "level" and req.level then return true end
    if req.type == "unknown" and req.text then
        -- Try to parse raw text into structured reputation data
        local parsed = parseRawRequirementText(req.text)
        if parsed then
            req.type = parsed.type
            req.faction = parsed.faction
            req.standing = parsed.standing
            req.text = nil
            return true
        end
        return true
    end
    return false
end

-- Deduplication key for a requirement. Higher-priority source's version wins
-- (first-seen kept; later duplicates with the same key are discarded).
local function getRequirementDedupeKey(req)
    if req.type == "reputation" then
        return "reputation:" .. (req.faction or "")
    elseif req.type == "achievement" then
        return "achievement:" .. tostring(req.id or req.name or "")
    elseif req.type == "quest" then
        return "quest:" .. tostring(req.id or req.name or "")
    elseif req.type == "level" then
        return "level"
    elseif req.type == "unknown" then
        return "unknown:" .. (req.text or "")
    end
    return nil -- unrecognized type: no dedup (always added)
end

-- Get acquisition requirements for an item, optionally scoped to a vendor.
-- Collects from prerequisite sources (higher priority wins on duplicates):
--   1. Vendor-specific: scannedVendors[npcID].items[i].requirements (tooltip scraping)
--   2. Item-level: CatalogStore:GetRequirements(itemID)
--   3. Parsed sourceText: parsedSources[itemID].sources[].faction/standing
--   4. Blizzard-confirmed vendor prerequisites: PrerequisiteSources[itemID]
-- Note: AchievementSources and QuestSources are acquisition paths (the item IS
-- the reward), not vendor prerequisites — they render as peer sources via
-- GetAllSources(), not as "Requires:" lines.
-- Deduplicates by type + identifying key (faction, achievement ID, quest ID).
-- NOT gated by useParsedSources — requirements are always surfaced.
-- Returns: array of requirement tables, or nil if none found
function SourceManager:GetRequirements(itemID, npcID)
    if not itemID then return nil end

    local merged = {}
    local seen = {}

    local function addReq(req)
        if not normalizeAndValidateRequirement(req) then return end
        local key = getRequirementDedupeKey(req)
        if key then
            if seen[key] then return end
            seen[key] = true
        end
        table.insert(merged, req)
    end

    local function addReqs(reqs)
        if not reqs then return end
        -- Safety: if source returned a single requirement object instead of
        -- an array, wrap it. A single object has a .type field directly.
        if reqs.type then
            addReq(reqs)
            return
        end
        for _, req in ipairs(reqs) do
            addReq(req)
        end
    end

    -- Priority 1: Vendor-specific requirements from scanned data
    if npcID and HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
        local vendor = HA.Addon.db.global.scannedVendors[npcID]
        if vendor and vendor.items then
            for _, item in ipairs(vendor.items) do
                if HA.VendorData:GetItemID(item) == itemID then
                    addReqs(item.requirements)
                end
            end
        end
    end

    -- Priority 2: Item-level from CatalogStore
    if HA.CatalogStore then
        addReqs(HA.CatalogStore:GetRequirements(itemID))
    end

    -- Priority 3: Faction/standing from parsed sourceText (no vendor visit needed)
    if HA.Addon and HA.Addon.db and HA.Addon.db.global.parsedSources then
        local parsed = HA.Addon.db.global.parsedSources[itemID]
        if parsed and parsed.sources then
            for _, source in ipairs(parsed.sources) do
                if source.faction and source.standing then
                    addReq({
                        type = "reputation",
                        faction = source.faction,
                        standing = source.standing,
                    })
                end
            end
        end
    end

    -- Priority 4: vendor requirements — offerKey (npcID:itemID) takes precedence over bare
    -- itemID, so a vendor-specific entry overrides a global one for the same item.
    if HA.PrerequisiteSources then
        local offerKey = npcID and (tostring(npcID) .. ":" .. tostring(itemID)) or nil
        if offerKey and HA.PrerequisiteSources[offerKey] then
            addReqs(HA.PrerequisiteSources[offerKey])
        elseif HA.PrerequisiteSources[itemID] then
            addReqs(HA.PrerequisiteSources[itemID])
        end
    end

    -- AchievementSources and QuestSources are acquisition paths (the item IS the
    -- reward), not vendor prerequisites. They are rendered as peer sources via
    -- GetAllSources(), not as "Requires:" lines. Vendor prerequisites are covered
    -- by PrerequisiteSources (tier 4) which is generated from the Blizzard web API.

    return #merged > 0 and merged or nil
end

-- Midnight friendship sub-faction rank order (Silvermoon Court sub-factions).
-- Used by IsRequirementMet, GetRequirementProgress, and Tooltips.lua for
-- friendship rank comparison and display classification.
-- Exposed as SourceManager.FRIENDSHIP_RANK_ORDER for cross-module access.
local FRIENDSHIP_RANK_ORDER = {
    ["Interloper"] = 1, ["Guest"] = 2, ["Socialite"] = 3,
    ["Trendsetter"] = 4, ["Host"] = 5, ["Luminary"] = 6,
}
SourceManager.FRIENDSHIP_RANK_ORDER = FRIENDSHIP_RANK_ORDER

-- Lazy-built cache: faction name → factionID (populated on first use)
local factionNameToID = nil

-- Build faction name→ID cache from Mainline major factions.
local function GetFactionIDByName(name)
    if not name then return nil end

    -- Build cache on first call. Homestead is Retail-only, so do not enumerate
    -- legacy reputation-panel APIs that are unavailable on Mainline.
    if not factionNameToID then
        factionNameToID = {}
        if C_MajorFactions and C_MajorFactions.GetMajorFactionIDs then
            for _, factionID in ipairs(C_MajorFactions.GetMajorFactionIDs()) do
                local data = C_MajorFactions.GetMajorFactionData(factionID)
                if data and data.name then
                    factionNameToID[data.name] = factionID
                end
            end
        end
    end

    -- Normalize: strip trailing period (SavedVariables may have "Silvermoon Court."
    -- from in-place mutation of scanned requirement text).
    local cleaned = name:gsub("%.$", "")

    local id = factionNameToID[cleaned]
    if id then return id end

    -- Fallback: strip " of <Location>" suffix and retry.
    -- Blizzard vendor tooltips append location context to faction names
    -- (e.g., "Blood Knights of Silvermoon" → API name "Blood Knights").
    local baseName = cleaned:match("^(.+) of .+$")
    if baseName then
        id = factionNameToID[baseName]
        if id then return id end
    end

    return nil
end

-- Check if a specific requirement is met by the player.
-- Returns: true (met), false (unmet), nil (cannot determine)
function SourceManager:IsRequirementMet(req)
    if not req or not req.type then return nil end

    if req.type == "reputation" then
        -- Integer fast-path: when factionID is pre-populated, skip name→ID resolution
        -- and the standing string-parse entirely. Uses C_MajorFactions.GetMajorFactionData
        -- (returns current renownLevel for the player) — called at runtime only.
        if type(req.factionID) == "number" and C_MajorFactions and C_MajorFactions.GetMajorFactionData then
            local factionData = C_MajorFactions.GetMajorFactionData(req.factionID)
            if factionData and type(req.renownLevel) == "number" then
                return (factionData.renownLevel or 0) >= req.renownLevel
            end
        end

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

            -- Friendship sub-faction standings (Midnight: Silvermoon Court sub-factions).
            -- C_GossipInfo.GetFriendshipReputation returns the rank NAME in .reaction
            -- (e.g., "Interloper"), NOT the numeric standing from C_Reputation.
            if FRIENDSHIP_RANK_ORDER[req.standing] then
                if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
                    local info = C_GossipInfo.GetFriendshipReputation(factionID)
                    if info and info.friendshipFactionID and info.friendshipFactionID > 0 then
                        local currentRank = FRIENDSHIP_RANK_ORDER[info.reaction]
                        local requiredRank = FRIENDSHIP_RANK_ORDER[req.standing]
                        if currentRank and requiredRank then
                            return currentRank >= requiredRank
                        end
                    end
                end
                return nil
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

    -- Friendship sub-faction standings (Midnight: Silvermoon Court sub-factions).
    -- Friendship sub-faction standings — uses FRIENDSHIP_RANK_ORDER (module-level).
    if FRIENDSHIP_RANK_ORDER[req.standing] then
        if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
            local info = C_GossipInfo.GetFriendshipReputation(factionID)
            if info and info.friendshipFactionID and info.friendshipFactionID > 0 then
                local currentRank = FRIENDSHIP_RANK_ORDER[info.reaction]
                local requiredRank = FRIENDSHIP_RANK_ORDER[req.standing]
                if currentRank and requiredRank then
                    return {
                        met = currentRank >= requiredRank,
                        currentText = info.reaction or "Unknown",
                        requiredText = req.standing,
                        isRenown = false,
                        factionName = req.faction,
                    }
                end
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
-- Availability Classification
-------------------------------------------------------------------------------

-- Build a human-readable blocker label from a single requirement.
local function GetRequirementBlockerLabel(req)
    if not req then return nil end

    if req.type == "reputation" then
        local standing = req.standing or "Required"
        local faction = req.faction or "Unknown Faction"
        if standing:match("^Renown") then
            return standing .. " " .. faction
        end
        return standing .. " with " .. faction
    end

    if req.type == "achievement" then
        return "Achievement: " .. (req.name or "Unknown Achievement")
    end

    if req.type == "quest" then
        return "Quest: " .. (req.name or "Unknown Quest")
    end

    if req.type == "profession" then
        return req.profession and ("Profession: " .. req.profession) or "Profession requirement"
    end

    if req.text then
        return req.text
    end

    return "Other requirements"
end

-- Append a blocker label to a list, deduplicating by string equality.
local function AppendUniqueBlockerLabel(labels, label)
    if not label then return labels end

    labels = labels or {}
    for _, existing in ipairs(labels) do
        if existing == label then
            return labels
        end
    end

    labels[#labels + 1] = label
    return labels
end

-- Classify an item's availability based on its requirements.
-- Returns: state, isUnverified, hasVerifiableRequirement, blockerLabels
--   state: "purchasable" or "locked"
--   isUnverified: true when all requirements are unknown type
--   hasVerifiableRequirement: true when at least one req has a known type
--   blockerLabels: array of human-readable strings (only when locked), or nil
local function EvaluateRequirementAvailability(reqs)
    if not reqs or #reqs == 0 then
        return "purchasable", false, false, nil
    end

    local hasVerifiableRequirement = false
    local blockerLabels = nil
    for _, req in ipairs(reqs) do
        if req.type ~= "unknown" then
            hasVerifiableRequirement = true
        end

        if SourceManager:IsRequirementMet(req) ~= true then
            blockerLabels = AppendUniqueBlockerLabel(blockerLabels, GetRequirementBlockerLabel(req))
        end
    end

    if blockerLabels then
        return "locked", false, hasVerifiableRequirement, blockerLabels
    end

    return "purchasable", not hasVerifiableRequirement, hasVerifiableRequirement, nil
end

local function GetScannedVendorItem(itemID, npcID)
    if not itemID or not npcID then return nil end
    if not HA.Addon or not HA.Addon.db or not HA.Addon.db.global.scannedVendors then
        return nil
    end

    local vendor = HA.Addon.db.global.scannedVendors[npcID]
    if not vendor or not vendor.items then return nil end

    for _, item in ipairs(vendor.items) do
        local scannedItemID = HA.VendorData and HA.VendorData.GetItemID
            and HA.VendorData:GetItemID(item)
            or item.itemID
        if scannedItemID == itemID then
            return item
        end
    end

    return nil
end

-- Vendor-scoped availability: classifies an item in a specific vendor context.
-- Returns: state, isUnverified, hasVerifiableRequirement, blockerLabels
function SourceManager:GetVendorItemAvailabilityState(itemID, npcID)
    if not itemID then return "unknown", false, false, nil end

    -- Intentional duplicate ownership guard for standalone callers such as tooltips.
    if HA.CatalogStore and HA.CatalogStore:IsOwnedFresh(itemID) then
        return "owned", false, false, nil
    end

    if not npcID then
        return "unknown", false, false, nil
    end

    local reqs = self:GetRequirements(itemID, npcID)
    local state, isUnverified, hasVerifiableRequirement, blockerLabels = EvaluateRequirementAvailability(reqs)
    if state == "purchasable" then
        local scannedItem = GetScannedVendorItem(itemID, npcID)
        if scannedItem and scannedItem.isPurchasable == false then
            return "locked", false, false, { "Purchase gated" }
        end
    end

    return state, isUnverified, hasVerifiableRequirement, blockerLabels
end

-- Generic availability: uses vendor scope when npcID is given, otherwise
-- falls back to source-level availability checks.
-- Returns: state, isUnverified, hasVerifiableRequirement, blockerLabels
function SourceManager:GetItemAvailabilityState(itemID, npcID)
    if not itemID then return "unknown", false, false, nil end

    if npcID then
        return self:GetVendorItemAvailabilityState(itemID, npcID)
    end

    if HA.CatalogStore and HA.CatalogStore:IsOwnedFresh(itemID) then
        return "owned", false, false, nil
    end

    if self:GetBestAvailableSource(itemID) then
        return "available", false, false, nil
    end

    if self:GetSource(itemID) then
        return "blocked", false, false, nil
    end

    return "unknown", false, false, nil
end

-------------------------------------------------------------------------------
-- Source Type Checkers
-------------------------------------------------------------------------------

-- Canonical source taxonomy used by filtering and reporting.
local CANONICAL_SOURCE_TYPES = {
    vendor = true,
    quest = true,
    achievement = true,
    profession = true,
    event = true,
    shop = true,
    drop = true,
}
local SOURCE_TYPE_ALIASES = {
    craft = "profession", -- Legacy constant alias
}
local SOURCE_TYPE_ICONS = {
    vendor = HA.Constants.Icons.PURCHASABLE,
    profession = HA.Constants.Icons.CRAFTABLE,
    achievement = HA.Constants.Icons.ACHIEVEMENT_REWARD,
    drop = HA.Constants.Icons.DROP_SOURCE,
    quest = HA.Constants.Icons.QUEST_REWARD,
    event = HA.Constants.Icons.PURCHASABLE,
    shop = HA.Constants.Icons.PURCHASABLE,
    reputation = HA.Constants.Icons.REPUTATION,
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

-- Return registered provider types in stable priority order.
function SourceManager:GetRegisteredSourceTypes()
    EnsureProvidersRegistered()

    local copy = {}
    for i, sourceType in ipairs(providerOrder) do
        copy[i] = sourceType
    end
    return copy
end

function SourceManager:GetSourceTypeIcon(sourceType)
    local icons = HA.Constants and HA.Constants.Icons
    if not icons then return nil end

    local normalizedType = self:NormalizeSourceType(sourceType) or sourceType
    return SOURCE_TYPE_ICONS[normalizedType] or icons.NOT_COLLECTED
end

-- Get status icon for a decor item without constructing a heavyweight wrapper.
-- Preserves the owned / placed / unowned icon behavior used by overlays.
function SourceManager:GetItemStatusIcon(itemID)
    if not itemID then return nil end

    local icons = HA.Constants and HA.Constants.Icons
    local catalogStore = HA.CatalogStore
    if not icons or not catalogStore then return nil end

    if catalogStore:IsOwnedFresh(itemID) then
        if GetPlacedCount(itemID) > 0 then
            return icons.COLLECTED_PLACED
        end
        return icons.COLLECTED
    end

    local source = self:GetSource(itemID)
    if source then
        return self:GetSourceTypeIcon(source.type)
    end

    return icons.NOT_COLLECTED
end

-- Get status color for a decor item without constructing a heavyweight wrapper.
-- Preserves the owned / placed / unowned color behavior used by overlays.
function SourceManager:GetItemStatusColor(itemID)
    if not itemID then return nil end

    local colors = HA.Constants and HA.Constants.Colors
    local catalogStore = HA.CatalogStore
    if not colors or not catalogStore then return nil end

    if catalogStore:IsOwnedFresh(itemID) then
        if GetPlacedCount(itemID) > 0 then
            return colors.COLLECTED_PLACED
        end
        return colors.COLLECTED
    end

    return colors.NOT_COLLECTED
end

-- Inventory render paths already know the slot contains this item.
-- If the catalog does not report ownership, the item is present but unlearned.
function SourceManager:GetInventoryItemStatus(itemID)
    if not itemID then return nil end

    local catalogStore = HA.CatalogStore
    local status
    if catalogStore and catalogStore:IsOwnedFresh(itemID) then
        status = "owned"
    else
        status = "in_bags_unlearned"
    end
    return status
end

function SourceManager:GetMerchantItemStatus(itemID)
    if not itemID then return nil end

    local catalogStore = HA.CatalogStore
    local status
    if catalogStore and catalogStore:IsOwnedFresh(itemID) then
        status = "owned"
    else
        status = "unowned"
    end
    return status
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
        shop = false,
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
    flags.shop = self:IsShopItem(itemID)
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
    elseif normalizedType == "shop" then
        return self:IsShopItem(itemID)
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
        shop = 0,
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
        -- When sourceData is nil but type is known, resolve data from source tables.
        -- Supports callers that know the type but not the data (e.g., catalog sourceText blocks).
        if not sourceData and itemID then
            if normalizedType == "achievement" and HA.AchievementSources then
                sourceData = HA.AchievementSources[itemID]
            elseif normalizedType == "quest" and HA.QuestSources then
                sourceData = HA.QuestSources[itemID]
            elseif normalizedType == "profession" and HA.ProfessionSources then
                sourceData = HA.ProfessionSources[itemID]
            end
        end
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

        -- wasEarnedByMe is the 13th return value from GetAchievementInfo.
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
        -- Check if the player has this profession before querying recipe status.
        local hasProf = self:PlayerHasProfession(resolvedData)
        if hasProf == false then
            return { color = "|cFFFF0000", suffix = " (Not Your Profession)", met = false }
        end

        -- Check expansion-tier skill level (e.g., Midnight Leatherworking 50)
        local meetsLevel = self:PlayerMeetsSkillLevel(resolvedData)
        if meetsLevel == false then
            return { color = "|cFFFF0000", suffix = " (Skill Too Low)", met = false }
        end

        -- A profession block was recognized but we can't resolve recipe state
        -- (no ProfessionSources row for this item, or the row lacks a spellID).
        -- Return a definite "(Unknown)" rather than nil so every profession décor
        -- renders a consistent suffix — never a bare line with no status (HS-111).
        local spellID = resolvedData and resolvedData.spellID
        if not spellID then
            return { color = "|cFF808080", suffix = " (Unknown)", met = nil }
        end

        local tradeSkillUI = _G and _G.C_TradeSkillUI
        if not tradeSkillUI or not tradeSkillUI.GetRecipeInfo then
            -- API unavailable until profession systems are ready/opened.
            return { color = "|cFF808080", suffix = " (Unknown)", met = nil }
        end

        local recipeInfo = tradeSkillUI.GetRecipeInfo(spellID)
        if not recipeInfo then
            return { color = "|cFF808080", suffix = " (Unknown)", met = nil }
        end

        -- Report only what we KNOW: whether the recipe is learned. NOT "Can Craft
        -- Now" — recipeInfo.craftable is recipe/context state (station-dependent),
        -- not material availability, and no API exposes whether the player has the
        -- reagents. A learned recipe reads "(Recipe Known)" regardless of craftable.
        local result
        if recipeInfo.learned then
            result = { color = "|cFF00FF00", suffix = " (Recipe Known)", met = true }
        else
            result = { color = "|cFFFF0000", suffix = " (Recipe Unknown)", met = false }
        end

        return CopyCompletionStatus(result)
    end

    return nil
end

-- Build a set of source types that should suppress requirement duplication in tooltips.
-- Build a dedup set to suppress requirement lines that duplicate rendered sources.
-- sourceTypes: array of type strings (broad suppression, used by sourceText path)
-- renderedSources (optional): array of source objects from GetAllSources(). When
--   provided, builds specific keys ("quest:QuestName") instead of broad type keys,
--   so only the exact rendered quest/achievement is suppressed as a requirement.
function SourceManager:BuildRequirementDedupSet(sourceTypes, renderedSources)
    local dedup = {}
    if type(sourceTypes) ~= "table" then
        return dedup
    end

    if renderedSources then
        -- Specific dedup: suppress only the exact quest/achievement that was rendered
        for _, source in ipairs(renderedSources) do
            if source.type == "quest" and source.data and source.data.questName then
                dedup["quest:" .. source.data.questName] = true
            elseif source.type == "achievement" and source.data and source.data.achievementName then
                dedup["achievement:" .. source.data.achievementName] = true
            end
        end
    else
        -- Broad dedup: suppress all quest/achievement requirements (sourceText path)
        for _, sourceType in pairs(sourceTypes) do
            local normalized = self:NormalizeSourceType(sourceType)
            if normalized == "achievement" or normalized == "quest" then
                dedup[normalized] = true
            end
        end
    end

    return dedup
end

function SourceManager:InvalidateCompletionCache()
    completionCache = {}
end

-- Central invalidation entrypoint for source-related caches.
-- Future source/filter caches should be added here so callers have one API.
-- Fires SOURCE_CACHES_INVALIDATED so UI modules can repaint without
-- duplicating WoW event registrations.
function SourceManager:InvalidateAllSourceCaches()
    self:InvalidateCompletionCache()
    factionNameToID = nil

    if HA.Events then
        HA.Events:Fire("SOURCE_CACHES_INVALIDATED")
    end
end

local function HookCompletionCacheInvalidation()
    if completionInvalidationFrame then return end

    completionInvalidationFrame = CreateFrame("Frame")
    completionInvalidationFrame:RegisterEvent("ACHIEVEMENT_EARNED")
    completionInvalidationFrame:RegisterEvent("QUEST_TURNED_IN")
    completionInvalidationFrame:RegisterEvent("NEW_RECIPE_LEARNED")
    completionInvalidationFrame:RegisterEvent("SKILL_LINES_CHANGED")
    completionInvalidationFrame:RegisterEvent("UPDATE_FACTION")
    completionInvalidationFrame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
    completionInvalidationFrame:SetScript("OnEvent", function()
        SourceManager:InvalidateAllSourceCaches()
    end)

    if HA.Events and not activeHolidayInvalidationRegistered then
        HA.Events:RegisterCallback("ACTIVE_HOLIDAYS_CHANGED", function()
            SourceManager:InvalidateAllSourceCaches()
        end)
        activeHolidayInvalidationRegistered = true
    end
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

function SourceManager:IsShopItem(itemID)
    return HA.ShopSources and HA.ShopSources[itemID] ~= nil
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
    if sourceManagerInitialized then return end
    sourceManagerInitialized = true

    EnsureProvidersRegistered()
    HookCompletionCacheInvalidation()

    local stats = self:GetStats()

    if HA.Addon then
        HA.Addon:Debug("SourceManager initialized (" .. #providerOrder .. " providers)")
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

