--[[
    Homestead - CatalogStore
    Canonical per-item state store for housing decor items

    Single source of truth for item ownership, metadata, sources, and requirements.
    All writes go through this module. Read API provides cache-only and fresh paths.

    Phase 1-10: catalogItems is the canonical ownership store.

    Event contract:
      _save()            — internal table merge, NEVER fires events
      SetOwned()         — _save() + OWNERSHIP_UPDATED (only if newly owned)
      SetSources()       — _save() + CATALOG_ITEM_UPDATED
      SetRequirements()  — _save() + CATALOG_ITEM_UPDATED
      Save()             — _save() + CATALOG_ITEM_UPDATED

    Batch mode (BeginBatch/EndBatch):
      All per-item events suppressed. EndBatch fires one of each if needed.
]]

local _, HA = ...

local CatalogStore = {}
HA.CatalogStore = CatalogStore

-- Local references
local pairs = pairs
local time = time
local type = type
local tostring = tostring
local pcall = pcall

-- Internal state
local ci = nil              -- shorthand for db.global.catalogItems (set on Initialize)
local decorToItemID = {}    -- reverse index: decorID → itemID
local ownedCount = 0        -- cached count of owned items (incremented in SetOwned)
local batchMode = false     -- true during catalog scan batches
local batchOwnershipChanged = false
local batchDataChanged = false
local negativeGeneration = 0  -- bumped on SetOwned/ClearAll to bust negative cache

-------------------------------------------------------------------------------
-- Internal: Table Merge (no events, no side effects beyond storage)
-------------------------------------------------------------------------------

local function _save(itemID, fields)
    if not ci or not itemID then return end

    local record = ci[itemID]
    if not record then
        record = {}
        ci[itemID] = record
    end

    -- Merge fields into existing record
    for k, v in pairs(fields) do
        record[k] = v
    end

    -- Update decorToItemID reverse index if decorID present
    if fields.decorID and fields.decorID ~= 0 then
        decorToItemID[fields.decorID] = itemID
    end
end

-------------------------------------------------------------------------------
-- Write API
-------------------------------------------------------------------------------

-- Mark an item as owned.
-- Fires OWNERSHIP_UPDATED only if newly owned (not on repeated calls).
function CatalogStore:SetOwned(itemID, name, decorID)
    if not ci or not itemID then return end

    local record = ci[itemID]
    local wasOwned = record and record.isOwned

    local now = time()
    local fields = {
        isOwned = true,
        name = name or (record and record.name),
        lastSeen = now,
    }
    if decorID then
        fields.decorID = decorID
    end
    if not wasOwned then
        fields.firstSeen = now
    end

    _save(itemID, fields)

    -- Bump negative cache generation and owned counter on new ownership
    if not wasOwned then
        negativeGeneration = negativeGeneration + 1
        ownedCount = ownedCount + 1
    end

    -- Fire event (or defer in batch mode)
    if not wasOwned then
        if batchMode then
            batchOwnershipChanged = true
        elseif HA.Events then
            HA.Events:Fire("OWNERSHIP_UPDATED")
        end
    end
end

-- Mark an item as no longer owned.
-- Symmetric with SetOwned: maintains ownedCount, negativeGeneration, events.
-- Idempotent: second call on same item is a no-op (no counter/gen/event changes).
-- Used for manual ownership corrections.
--
-- Contract:
--   1. State check: wasOwned from catalogItems.isOwned (primary truth for counter)
--   2. Data: clear isOwned/firstSeen/lastSeen in catalogItems; keep name/decorID
--   3. Counter: decrement ownedCount only if catalogItems had isOwned=true
--   4. Cache: bump negativeGeneration on effective ownership change
--   5. Event: fire OWNERSHIP_UPDATED on transition only; respect batchMode
function CatalogStore:SetUnowned(itemID)
    if not itemID then return end

    -- 1. Detect current ownership state (catalogItems is counter authority)
    local wasOwnedInCatalog = false
    if ci and ci[itemID] then
        wasOwnedInCatalog = ci[itemID].isOwned == true
    end

    -- No-op if not owned in catalogItems (idempotent).
    if not wasOwnedInCatalog then return end

    -- 2. Clear catalogItems ownership (keep metadata: name, decorID)
    if ci and ci[itemID] then
        ci[itemID].isOwned = false
        ci[itemID].firstSeen = nil
        ci[itemID].lastSeen = nil
    end

    -- 3-4. Counter and cache generation (only from catalogItems authority)
    if wasOwnedInCatalog then
        ownedCount = ownedCount - 1
        negativeGeneration = negativeGeneration + 1
    end

    -- 5. Event on effective ownership transition
    if wasOwnedInCatalog then
        if batchMode then
            batchOwnershipChanged = true
        elseif HA.Events then
            HA.Events:Fire("OWNERSHIP_UPDATED")
        end
    end
end

-- Store parsed source data for an item
function CatalogStore:SetSources(itemID, sources, hash)
    if not ci or not itemID then return end

    _save(itemID, {
        sources = sources,
        sourceHash = hash,
        lastParsed = time(),
    })

    if batchMode then
        batchDataChanged = true
    elseif HA.Events then
        HA.Events:Fire("CATALOG_ITEM_UPDATED")
    end
end

-- Store requirements for an item (item-level "best-known")
function CatalogStore:SetRequirements(itemID, requirements)
    if not ci or not itemID then return end

    _save(itemID, {
        requirements = requirements,
    })

    if batchMode then
        batchDataChanged = true
    elseif HA.Events then
        HA.Events:Fire("CATALOG_ITEM_UPDATED")
    end
end

-- General-purpose save (catch-all for metadata fields)
function CatalogStore:Save(itemID, fields)
    if not ci or not itemID or not fields then return end

    _save(itemID, fields)

    if batchMode then
        batchDataChanged = true
    elseif HA.Events then
        HA.Events:Fire("CATALOG_ITEM_UPDATED")
    end
end

-------------------------------------------------------------------------------
-- Batch Mode (suppress per-item events during catalog scan)
-------------------------------------------------------------------------------

function CatalogStore:BeginBatch()
    batchMode = true
    batchOwnershipChanged = false
    batchDataChanged = false
end

function CatalogStore:EndBatch()
    batchMode = false

    if HA.Events then
        if batchOwnershipChanged then
            HA.Events:Fire("OWNERSHIP_UPDATED")
        end
        if batchDataChanged then
            HA.Events:Fire("CATALOG_ITEM_UPDATED")
        end
    end

    batchOwnershipChanged = false
    batchDataChanged = false
end

-------------------------------------------------------------------------------
-- Read API
-------------------------------------------------------------------------------

-- Check if an item is a housing decor item.
-- Safe runtime probe used by overlays and compatibility APIs.
function CatalogStore:IsDecorItem(itemLink)
    if not itemLink then return false end
    if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
        local success, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, itemLink, false)
        return success and info ~= nil
    end
    return false
end

-- Raw record access (no allocation, direct table reference)
function CatalogStore:Get(itemID)
    if not ci or not itemID then return nil end
    return ci[itemID]
end

-- Cache-only ownership check (fast, no API calls)
function CatalogStore:IsOwned(itemID)
    if not itemID then return false end

    if ci then
        local record = ci[itemID]
        if record and record.isOwned then
            return true
        end
    end

    return false
end

-- Fresh ownership check for UI display paths
-- IsOwned() + bag check + live API probe
-- Use this for VendorMapPins, Tooltips, VendorTracer — NOT for badge counts or export
function CatalogStore:IsOwnedFresh(itemID)
    if not itemID then return false end

    -- Fast path: cache says owned
    if self:IsOwned(itemID) then
        return true
    end

    -- Check bags (immediate purchase detection)
    if GetItemCount then
        local bagCount = GetItemCount(itemID)
        if bagCount and bagCount > 0 then
            -- Found in bags — cache it for next time
            self:SetOwned(itemID, nil, nil)
            return true
        end
    end

    -- Live API probe (handles post-purchase before next scan)
    if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
        local itemLink = "item:" .. tostring(itemID)
        local success, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, itemLink, true)
        if success and info then
            -- firstAcquisitionBonus == 0 reliably detects ownership
            if info.firstAcquisitionBonus == 0 then
                local recordID = nil
                if info.entryID and type(info.entryID) == "table" then
                    recordID = info.entryID.recordID
                end
                self:SetOwned(itemID, info.name, recordID)
                return true
            end
        end
    end

    return false
end

-- Get decorID for an item
function CatalogStore:GetDecorID(itemID)
    if not ci or not itemID then return nil end
    local record = ci[itemID]
    return record and record.decorID
end

-- Reverse lookup: decorID → itemID
function CatalogStore:GetItemIDFromDecorID(decorID)
    if not decorID then return nil end
    return decorToItemID[decorID]
end

-- Get item-level requirements
function CatalogStore:GetRequirements(itemID)
    if not ci or not itemID then return nil end
    local record = ci[itemID]
    return record and record.requirements
end

-- Count of owned items in catalogItems (cached, O(1))
function CatalogStore:GetOwnedCount()
    return ownedCount
end

-- Get owned-item source counts using SourceManager taxonomy.
-- mode:
--   "primary" (default)   -> one bucket per owned item
--   "inclusive"           -> item may count in multiple source buckets
function CatalogStore:GetOwnedItemsBySourceType(mode)
    local counts = {
        vendor = 0,
        quest = 0,
        achievement = 0,
        profession = 0,
        event = 0,
        drop = 0,
        unknown = 0,
    }
    if not ci then return counts end

    local sourceManager = HA.SourceManager
    if not sourceManager or not sourceManager.CountItemsBySourceType then
        return counts
    end

    local ownedItemSet = {}
    for itemID, record in pairs(ci) do
        if record and record.isOwned then
            ownedItemSet[itemID] = true
        end
    end

    local normalizedMode = (mode == "inclusive") and "inclusive" or "primary"
    return sourceManager:CountItemsBySourceType(ownedItemSet, normalizedMode)
end

-- Get negative cache generation (for external negative cache consumers)
function CatalogStore:GetGeneration()
    return negativeGeneration
end

-------------------------------------------------------------------------------
-- Maintenance
-------------------------------------------------------------------------------

-- Clear all ownership data.
function CatalogStore:ClearAll()
    -- Clear catalogItems ownership flags
    if ci then
        for _, record in pairs(ci) do
            record.isOwned = false
            record.firstSeen = nil
            record.lastSeen = nil
        end
    end

    -- Reset cached counter
    ownedCount = 0

    -- Bust negative cache
    negativeGeneration = negativeGeneration + 1

    if HA.Events then
        HA.Events:Fire("OWNERSHIP_UPDATED")
    end
end

-- Rebuild decorID → itemID reverse index
-- Seeds from static DecorMapping first, then overlays runtime discoveries
function CatalogStore:BuildDecorIndex()
    decorToItemID = {}

    -- Seed from static mapping (generated from Blizzard web API)
    local staticMapping = HA.DecorMapping
    if staticMapping then
        for decorID, itemID in pairs(staticMapping) do
            decorToItemID[decorID] = itemID
        end
    end

    -- Overlay runtime discoveries from catalogItems (may contain newer data)
    if ci then
        for itemID, record in pairs(ci) do
            if record.decorID and record.decorID ~= 0 then
                decorToItemID[record.decorID] = itemID
            end
        end
    end
end

-- Probe ownership by decorID using the safe GetCatalogEntryInfoByRecordID API.
-- Use for edge cases where we have a decorID but need ownership confirmation.
-- Returns: info table from API, or nil
function CatalogStore:ProbeByDecorID(decorID)
    if not decorID then return nil end

    local CHC = _G.C_HousingCatalog
    if not CHC or not CHC.GetCatalogEntryInfoByRecordID then return nil end

    local ok, info = pcall(CHC.GetCatalogEntryInfoByRecordID, 1, decorID, true)
    if ok and info then
        -- Cache the result in catalogItems if we can resolve the itemID
        local itemID = decorToItemID[decorID]
        if itemID and info.firstAcquisitionBonus == 0 then
            self:SetOwned(itemID, info.name, decorID)
        elseif itemID then
            _save(itemID, { decorID = decorID })
        end
        return info
    end

    return nil
end

-------------------------------------------------------------------------------
-- Migrations (sequential, schema-versioned)
-------------------------------------------------------------------------------

-- Migration 1→2: Backfill from parsedSources
local function Migration_1_to_2(db)
    local global = db.global

    -- Backfill from parsedSources
    local parsedSources = global.parsedSources
    if parsedSources then
        for itemID, data in pairs(parsedSources) do
            if not ci[itemID] then
                ci[itemID] = {}
            end
            local record = ci[itemID]
            record.sources = record.sources or data.sources
            record.sourceHash = record.sourceHash or data.sourceHash
            record.lastParsed = record.lastParsed or data.lastParsed
            -- Map parsedSources recordID to decorID
            if data.recordID and not record.decorID then
                record.decorID = data.recordID
            end
        end
    end

    -- Scan scannedVendors for additional item data
    local scannedVendors = global.scannedVendors
    if scannedVendors then
        for _, vendor in pairs(scannedVendors) do
            local items = vendor.items or vendor.decor or {}
            for _, item in ipairs(items) do
                if item.itemID then
                    if not ci[item.itemID] then
                        ci[item.itemID] = {}
                    end
                    local record = ci[item.itemID]
                    record.name = record.name or item.name
                    record.lastScanned = record.lastScanned or time()
                end
            end
        end
    end

    global.schemaVersion = 2

    if HA.Addon then
        HA.Addon:Debug("CatalogStore: Migration 1→2 complete")
    end
end

-- Migration 2→3: Convert scannedVendors .decor to .items
local function Migration_2_to_3(db)
    local scannedVendors = db.global.scannedVendors
    if scannedVendors then
        local migrated = 0
        for npcID, vendor in pairs(scannedVendors) do
            if vendor.decor and not vendor.items then
                vendor.items = vendor.decor
                vendor.decor = nil
                migrated = migrated + 1
            elseif vendor.decor and vendor.items then
                -- Both exist: prefer .items (newer), remove .decor
                vendor.decor = nil
                migrated = migrated + 1
            end
        end

        if HA.Addon and migrated > 0 then
            HA.Addon:Debug("CatalogStore: Migration 2→3 migrated " .. migrated .. " vendors from .decor to .items")
        end
    end

    db.global.schemaVersion = 3

    if HA.Addon then
        HA.Addon:Debug("CatalogStore: Migration 2→3 complete")
    end
end

-- Migration 3→4: Clean up orphaned ownedDecor table
local function Migration_3_to_4(db)
    if db.global.ownedDecor then
        db.global.ownedDecor = nil
        if HA.Addon then
            HA.Addon:Debug("CatalogStore: Migration 3→4 removed orphaned ownedDecor")
        end
    end

    db.global.schemaVersion = 4

    if HA.Addon then
        HA.Addon:Debug("CatalogStore: Migration 3→4 complete")
    end
end

function CatalogStore:RunMigrations()
    if not HA.Addon or not HA.Addon.db then return end
    local db = HA.Addon.db
    local version = db.global.schemaVersion or 1

    if version < 2 then
        Migration_1_to_2(db)
    end

    if version < 3 then
        Migration_2_to_3(db)
    end

    if version < 4 then
        Migration_3_to_4(db)
    end
end

function CatalogStore:Initialize()
    if not HA.Addon or not HA.Addon.db then return end

    -- Bind local reference to catalogItems table
    ci = HA.Addon.db.global.catalogItems

    -- Run schema migrations
    self:RunMigrations()

    -- Build reverse index (seeds from DecorMapping + runtime data)
    self:BuildDecorIndex()

    -- Initialize owned count from full table scan (one-time at startup)
    ownedCount = 0
    local totalItems = 0
    if ci then
        for _, record in pairs(ci) do
            totalItems = totalItems + 1
            if record.isOwned then
                ownedCount = ownedCount + 1
            end
        end
    end

    local staticCount = 0
    if HA.DecorMapping then
        for _ in pairs(HA.DecorMapping) do staticCount = staticCount + 1 end
    end

    local indexSize = 0
    for _ in pairs(decorToItemID) do indexSize = indexSize + 1 end

    if HA.Addon then
        HA.Addon:Debug("CatalogStore: Initialized with", totalItems, "items,",
            ownedCount, "owned,", indexSize, "decorID mappings (" .. staticCount .. " static),",
            "schema v" .. (HA.Addon.db.global.schemaVersion or 1))
    end
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("CatalogStore", CatalogStore)
end
