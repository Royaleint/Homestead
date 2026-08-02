--[[
    Homestead - SourceTextScanner
    Processes sourceText from CatalogScanner and stores parsed results

    Data collection module for the player addon. Cross-reference reporting
    lives in Homestead_Dev/ValidationReport.lua (dev addon only).

    Flow: CatalogScanner:ProcessBatch() → SourceTextScanner:ProcessScannedItem()
          → SourceTextParser:ParseSourceText() → CatalogStore:SetSources()

    HS-205: db.global.parsedSources used to store the full parsed payload
    (sources/recordID/lastParsed/sourceHash/raw) on every parse, duplicating
    it byte-for-byte into catalogItems via the CatalogStore:SetSources dual-
    write. catalogItems is now the single owner (see CatalogStore:SetSources'
    comment); parsedSources stores ONLY {sourceHash, lastParsed} — the stamp
    change-detection below needs to know whether a sourceText changed since
    last parse, nothing else. GetParsedSource reads the full payload back
    from CatalogStore:Get(itemID) so every caller's return shape is unchanged.
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

    -- Stamp only: sourceHash + lastParsed is everything change-detection
    -- above needs on the next parse. The full parsed payload is owned by
    -- catalogItems (CatalogStore:SetSources below) — see file header.
    parsedSources[result.itemID] = {
        lastParsed = time(),
        sourceHash = hash,
    }

    if HA.CatalogStore then
        HA.CatalogStore:SetSources(result.itemID, parsed.sources, hash,
            HA.DevAddon and result.sourceText or nil)
    end
end

-------------------------------------------------------------------------------
-- Public Queries
-------------------------------------------------------------------------------

-- HS-205: returns the full parsed-source shape callers expect
-- ({sources, lastParsed, sourceHash, raw}), read from catalogItems (the
-- single owner) instead of the now-stamp-only parsedSources table. recordID
-- is intentionally NOT reconstructed here — nothing reads it live (only a
-- historical one-time migration ever did; decorID on the catalogItems record
-- is the modern, independently-maintained equivalent, set by CatalogScanner).
function SourceTextScanner:GetParsedSource(itemID)
    if not itemID then return nil end
    if not HA.Addon or not HA.Addon.db then return nil end

    -- A stamp must exist (this item was actually parsed) before we treat
    -- catalogItems' sources as parsed-source data — catalogItems can carry
    -- .sources from other origins too (e.g. future providers), and an item
    -- never parsed here must still return nil, matching prior behavior.
    local stamp = HA.Addon.db.global.parsedSources[itemID]
    if not stamp then return nil end

    local record = HA.CatalogStore and HA.CatalogStore:Get(itemID)
    if not record then return nil end

    return {
        sources = record.sources,
        lastParsed = record.lastParsed or stamp.lastParsed,
        sourceHash = record.sourceHash or stamp.sourceHash,
        raw = record.rawSourceText,
    }
end

-- Summary counts for all parsed source types
function SourceTextScanner:GetStats()
    if not HA.Addon or not HA.Addon.db then
        return { total = 0, vendor = 0, quest = 0, achievement = 0, profession = 0, drop = 0, structural = 0, unknown = 0 }
    end

    local stats = { total = 0, vendor = 0, quest = 0, achievement = 0, profession = 0, drop = 0, structural = 0, unknown = 0 }
    local parsedSources = HA.Addon.db.global.parsedSources

    for itemID in pairs(parsedSources) do
        stats.total = stats.total + 1
        local record = HA.CatalogStore and HA.CatalogStore:Get(itemID)
        if record and record.sources then
            for _, source in ipairs(record.sources) do
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
