--[[
    Homestead - SourceTextScanner
    Processes sourceText from CatalogScanner and stores parsed results

    Data collection module for the player addon. Cross-reference reporting
    lives in Homestead_Dev/ValidationReport.lua (dev addon only).

    Flow: CatalogScanner:ProcessBatch() → SourceTextScanner:ProcessScannedItem()
          → SourceTextParser:ParseSourceText() → db.global.parsedSources
]]

local _, HA = ...

local SourceTextScanner = {}
HA.SourceTextScanner = SourceTextScanner

local string_byte = string.byte

-------------------------------------------------------------------------------
-- djb2 Hash (change detection for sourceText)
-------------------------------------------------------------------------------

local function djb2(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + string_byte(str, i)) % 2147483647
    end
    return hash
end

-------------------------------------------------------------------------------
-- Core Processing
-------------------------------------------------------------------------------

-- Called by CatalogScanner:ProcessBatch() for each scanned item with sourceText
-- Interface contract: result = { itemID, sourceText, recordID }
function SourceTextScanner:ProcessScannedItem(result)
    if not result or not result.itemID or not result.sourceText then return end
    if result.sourceText == "" then return end

    -- Ensure db is available
    if not HA.Addon or not HA.Addon.db then return end
    local parsedSources = HA.Addon.db.global.parsedSources

    -- Compute hash for change detection
    local hash = djb2(result.sourceText)

    -- Skip if unchanged (hash matches existing entry)
    local existing = parsedSources[result.itemID]
    if existing and existing.sourceHash == hash then
        return
    end

    -- Parse the sourceText (lazy-init locale if Initialize() hasn't run yet)
    if not HA.SourceTextParser then return end
    local locale = self.locale or GetLocale()
    local parsed = HA.SourceTextParser:ParseSourceText(result.sourceText, locale)
    if not parsed then return end

    -- Store parsed result
    parsedSources[result.itemID] = {
        sources = parsed.sources,
        recordID = result.recordID,
        lastParsed = time(),
        sourceHash = hash,
        -- Raw sourceText only stored when dev addon is loaded
        raw = HA.DevAddon and result.sourceText or nil,
    }

    -- Dual-write to CatalogStore (Phase 1)
    if HA.CatalogStore then
        HA.CatalogStore:SetSources(result.itemID, parsed.sources, hash)
    end
end

-------------------------------------------------------------------------------
-- Public Queries
-------------------------------------------------------------------------------

-- Direct lookup from parsedSources
function SourceTextScanner:GetParsedSource(itemID)
    if not itemID then return nil end
    if not HA.Addon or not HA.Addon.db then return nil end
    return HA.Addon.db.global.parsedSources[itemID]
end

-- Summary counts for all parsed source types
function SourceTextScanner:GetStats()
    if not HA.Addon or not HA.Addon.db then
        return { total = 0, vendor = 0, quest = 0, achievement = 0, profession = 0, drop = 0, structural = 0, unknown = 0 }
    end

    local stats = { total = 0, vendor = 0, quest = 0, achievement = 0, profession = 0, drop = 0, structural = 0, unknown = 0 }
    local parsedSources = HA.Addon.db.global.parsedSources

    for _, entry in pairs(parsedSources) do
        stats.total = stats.total + 1
        if entry.sources then
            for _, source in ipairs(entry.sources) do
                local t = source.sourceType
                if stats[t] then
                    stats[t] = stats[t] + 1
                end
            end
        end
    end

    return stats
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function SourceTextScanner:Initialize()
    self.locale = GetLocale()
    self.hasTypedParsing = HA.SourceTextParser and HA.SourceTextParser:GetLocaleProfile(self.locale) ~= nil

    if HA.Addon then
        HA.Addon:Debug("SourceTextScanner: locale", self.locale,
            self.hasTypedParsing and "(typed parsing)" or "(structural only)")
    end
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("SourceTextScanner", SourceTextScanner)
end
