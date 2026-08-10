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
local itemIDToDecor = {}    -- forward index: itemID → decorID (for byRecordID fallback probes)
local ownedCount = 0        -- cached count of owned items (incremented in SetOwned)
-- HS-209 H3: nesting depth for BeginBatch/EndBatch, not a boolean. Two
-- independent callers can hold a batch open at once (CatalogScanner's scan
-- and ProfessionOverlay's reconcile pass, Overlay/ProfessionOverlay.lua:334-357)
-- — a plain boolean let the inner EndBatch prematurely clear batchMode and
-- fire the outer batch's suppressed events early. Suppression is active
-- whenever batchDepth > 0; the transition fire + flag-clear happens only
-- when depth returns to zero (outermost EndBatch).
local batchDepth = 0
local batchOwnershipChanged = false
local batchDataChanged = false
local negativeGeneration = 0  -- bumped on SetOwned/ClearAll to bust negative cache

-- HS-180: session-only "confirmed not decor" cache for CatalogStore:IsDecorItem.
-- Positive results never need this (a positive is trustworthy at any time);
-- this only holds itemIDs a live, warm probe has confirmed are NOT decor, so
-- repeat overlay refreshes for the same non-decor bag/bank slot skip the API
-- call. Never persisted, and busted on any negativeGeneration bump (see
-- IsDecorItem) so a snapshot verdict can't outlive the catalog scan that
-- would revise it.
local identityNegativeCache = {}
local identityNegativeCacheGen = -1

-- HS-180: session-only positive-identity memo for the same probe. Covers the
-- rare decor item that is in the live catalog but absent from both ci and the
-- static DecorMapping index (new-patch item before the mapping regenerates) —
-- without this it would re-probe the API on every refresh. A positive identity
-- is trustworthy at any temperature and never revoked, so no generation bust.
local identityPositiveCache = {}

-- HS-249: session memo for GetHousingSubclass. An item's class/subclass is a
-- fixed property of the item record, so unlike the identity caches above this
-- one needs no generation bust — a resolved verdict is never revised.
-- One table rather than the positive/negative pair used above, because both
-- verdicts are equally permanent and there is no negative to expire: values
-- are the subclass number, or false for "resolved, not a housing item".
-- An unresolved probe (GetItemInfoInstant's documented MayReturnNothing) is
-- deliberately NOT memoized, so a malformed itemID re-probes instead of
-- freezing a non-answer for the session.
local housingSubclassCache = {}

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

    -- Update decor index (both directions) if decorID present
    if fields.decorID and fields.decorID ~= 0 then
        decorToItemID[fields.decorID] = itemID
        itemIDToDecor[itemID] = fields.decorID
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
        if batchDepth > 0 then
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
--   5. Event: fire OWNERSHIP_UPDATED on transition only; respect batch depth
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
        if batchDepth > 0 then
            batchOwnershipChanged = true
        elseif HA.Events then
            HA.Events:Fire("OWNERSHIP_UPDATED")
        end
    end
end

-- Store parsed source data for an item. HS-205: catalogItems is the single
-- owner of parsed-source data (ITEM_SNAPSHOT_CONTRACT.md Open Question #1,
-- resolved: "persist in catalogItems"). db.global.parsedSources now stores
-- ONLY the sourceHash/lastParsed stamp SourceTextScanner's change-detection
-- needs — the full `sources` payload used to be written to BOTH tables on
-- every parse, roughly doubling the bytes for source data.
-- rawSourceText is optional and dev-only (Homestead_Dev's /hsdev exportsources
-- diagnostic) — SourceTextScanner passes it only when HA.DevAddon is loaded,
-- so it never affects a normal player's SavedVariables size.
function CatalogStore:SetSources(itemID, sources, hash, rawSourceText)
    if not ci or not itemID then return end

    _save(itemID, {
        sources = sources,
        sourceHash = hash,
        lastParsed = time(),
        rawSourceText = rawSourceText,
    })

    if batchDepth > 0 then
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

    if batchDepth > 0 then
        batchDataChanged = true
    elseif HA.Events then
        HA.Events:Fire("CATALOG_ITEM_UPDATED")
    end
end

-- General-purpose save (catch-all for metadata fields)
function CatalogStore:Save(itemID, fields)
    if not ci or not itemID or not fields then return end

    _save(itemID, fields)

    if batchDepth > 0 then
        batchDataChanged = true
    elseif HA.Events then
        HA.Events:Fire("CATALOG_ITEM_UPDATED")
    end
end

-------------------------------------------------------------------------------
-- Batch Mode (suppress per-item events during catalog scan)
-------------------------------------------------------------------------------

-- HS-209 H3: reentrant. Two independent callers can hold a batch open at
-- once (CatalogScanner's scan, ProfessionOverlay's reconcile pass) — only
-- the OUTERMOST BeginBatch resets the accumulated-change flags, so a nested
-- Begin can never clobber an outer batch's already-accumulated
-- batchOwnershipChanged/batchDataChanged.
function CatalogStore:BeginBatch()
    batchDepth = batchDepth + 1
    if batchDepth == 1 then
        batchOwnershipChanged = false
        batchDataChanged = false
    end
end

-- HS-209 H3: reentrant counterpart to BeginBatch. Only the outermost
-- EndBatch (the one that brings batchDepth back to 0) fires the transition
-- events and clears the flags — an inner EndBatch just decrements and
-- returns, leaving the outer batch's suppression and accumulated flags
-- intact. An EndBatch with no matching BeginBatch (depth already 0) is a
-- caller bug: floor at 0 and warn instead of going negative, which would
-- require an extra BeginBatch just to return to a suppressing state.
function CatalogStore:EndBatch()
    if batchDepth <= 0 then
        if HA.Addon then
            HA.Addon:Debug("CatalogStore: EndBatch called with no matching BeginBatch (underflow)")
        end
        batchDepth = 0
        return
    end

    batchDepth = batchDepth - 1
    if batchDepth > 0 then
        return
    end

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

-- Derive ownership from a catalog entry info table.
-- This is Blizzard's exact ownership contract: GetEntryTotalOwned(entryInfo) =
-- totalNumStored + remainingRedeemable + totalNumPlaced, styled "owned" when > 0
-- (Blizzard_HousingCatalogEntry.lua). totalNumStored/totalNumPlaced are the
-- source-confirmed field names; the older quantity/numPlaced are current aliases.
-- firstAcquisitionBonus is display-only (a tooltip favor line) and is 0 for both
-- owned items AND new décor that carry no favor — it is NOT an ownership signal.
-- These count fields are stale-0 cold (before storage data loads), so a "false"
-- result is only authoritative when storage data is loaded — callers that erase
-- ownership must warm-gate accordingly. nil-safe.
function CatalogStore:ComputeOwnedFromInfo(info)
    return (info and ((info.totalNumStored or 0) + (info.remainingRedeemable or 0) + (info.totalNumPlaced or 0)) > 0) or false
end

-- Check if an item is a housing decor item.
-- Cache-first, four gates before any API call:
--   1. ci[itemID] — this store is canonical per-item state for decor items
--      only (see module header), so an existing record is already a positive
--      identification.
--   2. itemIDToDecor[itemID] — the static DecorMapping index (seeded at
--      Initialize, ~1710 known decor itemIDs) is a second positive gate; it
--      also covers the HS-059 byItem-gap items that GetCatalogEntryInfoByItem
--      can return nil for even when owned.
--   3. identityPositiveCache[itemID] — session-only positive memo for decor
--      items found only by live probe (see declaration).
--   4. identityNegativeCache[itemID] — a session-only "confirmed not decor"
--      verdict from a prior warm probe (see below).
-- HS-180: overlay refresh paths (bags/merchant) call this per-slot, per-tick;
-- non-decor bag/bank items (the majority of a bag) used to miss all caching
-- and re-fire the API every refresh. Only itemIDs unresolved by any of the
-- four gates reach the live API probe.
function CatalogStore:IsDecorItem(itemLink)
    if not itemLink then return false end

    local itemID = C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(itemLink)
    if not itemID then
        if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
            local success, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, itemLink, false)
            return success and info ~= nil
        end
        return false
    end

    if ci and ci[itemID] then
        return true
    end

    if itemIDToDecor[itemID] then
        return true
    end

    if identityPositiveCache[itemID] then
        return true
    end

    -- A "not decor" verdict is a snapshot, not a permanent fact — bust it on
    -- any ownership generation change so it gets revalidated as the catalog
    -- scan progresses, rather than potentially outliving a scan that would
    -- have reclassified the item.
    if negativeGeneration ~= identityNegativeCacheGen then
        wipe(identityNegativeCache)
        identityNegativeCacheGen = negativeGeneration
    end

    if identityNegativeCache[itemID] then
        return false
    end

    if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
        local success, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, itemLink, false)
        if success and info ~= nil then
            identityPositiveCache[itemID] = true
            return true
        end

        -- Negative-caching hazard (HS-060): a nil/cold API result is not
        -- authoritative on its own — GetCatalogEntryInfoByItem returns nil
        -- both for genuinely non-decor items AND for cold/unloaded catalog
        -- data. Only memoize the negative verdict once the catalog is warm
        -- (CatalogScanner's dataLoaded latch); never off a cold/nil probe.
        if HA.CatalogScanner and HA.CatalogScanner.IsWarm and HA.CatalogScanner:IsWarm() then
            identityNegativeCache[itemID] = true
        end
        return false
    end

    return false
end

-- HS-249: which housing subclass an item belongs to, or nil if it is not a
-- housing-class item at all. Reads classID/subClassID as the 6th and 7th
-- returns of C_Item.GetItemInfoInstant — the same call Blizzard's own
-- MerchantFrame.lua uses to classify a merchant row. It is synchronous and
-- needs no server query, so it is safe on render paths, but it is documented
-- MayReturnNothing: a malformed itemID yields no values at all, which lands
-- here as a nil classID. That is treated as "unknown, not housing" (nil), and
-- is not memoized.
--
-- Memoized because the badge recount loops call this per item per recount —
-- the same hot path HS-234's prewarm exists to defend.
function CatalogStore:GetHousingSubclass(itemID)
    if not itemID then return nil end

    local cached = housingSubclassCache[itemID]
    if cached ~= nil then
        return cached or nil
    end

    if not (C_Item and C_Item.GetItemInfoInstant) then return nil end

    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    if classID == nil then
        return nil
    end

    if classID ~= Enum.ItemClass.Housing or subClassID == nil then
        housingSubclassCache[itemID] = false
        return nil
    end

    housingSubclassCache[itemID] = subClassID
    return subClassID
end

-- HS-249: true when this item is a housing item whose ownership Homestead
-- cannot yet resolve. Only ItemHousingSubclass.Decor maps to a housing catalog
-- entry, so every other housing subclass (Dye, Room, RoomCustomization,
-- ExteriorCustomization, ServiceItem) falls through IsOwned's hard `false` and
-- would be counted as "not owned" — a badge telling the player to buy a room
-- they already own. Such items must be left out of ownership-derived counts
-- entirely rather than defaulted to unowned.
--
-- Everything else — decor, and any non-housing item — answers false, so the
-- existing counts are unchanged. Phase 2 resolves itemID → recordID for the
-- other subclasses and this predicate goes away with it.
function CatalogStore:IsOwnershipUnknowable(itemID)
    local subclassID = self:GetHousingSubclass(itemID)
    if subclassID == nil then return false end

    -- Guarded, unlike the bare Enum reads elsewhere: a nil here would make
    -- every decor item compare unequal and exclude the entire catalog, and it
    -- would do so silently rather than erroring.
    local decorSubclassID = Enum.ItemHousingSubclass and Enum.ItemHousingSubclass.Decor
    if decorSubclassID == nil then return false end

    return subclassID ~= decorSubclassID
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
-- IsOwned() + live byItem probe + byRecordID fallback
-- Use this for VendorMapPins, Tooltips, VendorTracer — NOT for badge counts or export
-- readOnly=true: skip ALL cache writes (SetOwned / ProbeByDecorID). Use from
-- render / OnUpdate paths (e.g. the catalog overlay accessibility badge) where a
-- write would fire OWNERSHIP_UPDATED mid-render, wipe the overlay cache and thrash.
-- The scanner remains the authoritative cache writer.
function CatalogStore:IsOwnedFresh(itemID, readOnly)
    if not itemID then return false end

    -- Fast path: cache says owned
    if self:IsOwned(itemID) then
        return true
    end

    -- Live byItem probe (handles post-purchase before next scan)
    if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
        local itemLink = "item:" .. tostring(itemID)
        local success, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, itemLink, true)
        if success and info then
            -- Ownership = GetEntryTotalOwned > 0 (Blizzard's contract)
            if self:ComputeOwnedFromInfo(info) then
                if not readOnly then
                    local recordID = nil
                    if info.entryID and type(info.entryID) == "table" then
                        recordID = info.entryID.recordID
                    end
                    self:SetOwned(itemID, info.name, recordID)
                end
                return true
            end
        end
    end

    -- Stage 4: byRecordID fallback via reverse index.
    -- GetCatalogEntryInfoByItem returns nil for some items on 12.0.1 (HS-059:
    -- itemID 244778 Sethraliss Priest's Pillow). GetCatalogEntryInfoByRecordID
    -- indexes the catalog directly without requiring item-cache data and is reliable.
    -- In readOnly mode: probe without writing to cache.
    -- In write mode: ProbeByDecorID handles the probe and SetOwned cache write together.
    local decorID = itemIDToDecor[itemID]
    if decorID then
        if not readOnly then
            local info = self:ProbeByDecorID(decorID)
            if self:ComputeOwnedFromInfo(info) then
                return true
            end
        else
            local CHC = _G.C_HousingCatalog
            if CHC and CHC.GetCatalogEntryInfoByRecordID then
                local ok, info = pcall(CHC.GetCatalogEntryInfoByRecordID, 1, decorID, true)
                if ok and self:ComputeOwnedFromInfo(info) then
                    return true
                end
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

-- Forward lookup: itemID → decorID (checks runtime record first, then static index)
function CatalogStore:GetDecorIDFromItemID(itemID)
    if not itemID then return nil end
    if ci then
        local record = ci[itemID]
        if record and record.decorID and record.decorID ~= 0 then
            return record.decorID
        end
    end
    return itemIDToDecor[itemID]
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

    ownedCount = 0

    -- Bust negative cache
    negativeGeneration = negativeGeneration + 1

    if HA.Events then
        HA.Events:Fire("OWNERSHIP_UPDATED")
    end
end

-- Rebuild decorID ↔ itemID indexes (both directions)
-- Seeds from static DecorMapping first, then overlays runtime discoveries
function CatalogStore:BuildDecorIndex()
    decorToItemID = {}
    itemIDToDecor = {}

    -- Seed from static mapping (generated from Blizzard web API)
    local staticMapping = HA.DecorMapping
    if staticMapping then
        for decorID, itemID in pairs(staticMapping) do
            decorToItemID[decorID] = itemID
            itemIDToDecor[itemID] = decorID
        end
    end

    -- Overlay runtime discoveries from catalogItems (may contain newer data)
    if ci then
        for itemID, record in pairs(ci) do
            if record.decorID and record.decorID ~= 0 then
                decorToItemID[record.decorID] = itemID
                itemIDToDecor[itemID] = record.decorID
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
        if itemID and self:ComputeOwnedFromInfo(info) then
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
            -- Map parsedSources recordID to decorID.
            -- Route through _save so the reverse index (itemIDToDecor /
            -- decorToItemID) is updated structurally rather than
            -- depending on BuildDecorIndex ordering.
            if data.recordID and not record.decorID then
                _save(itemID, { decorID = data.recordID })
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

-- Migration 4→5: parsedSources → catalogItems single ownership (HS-205)
-- Moves the full parsed-source payload (sources/lastParsed/sourceHash, plus
-- recordID→decorID where still missing, same mapping Migration_1_to_2 already
-- performs) out of db.global.parsedSources and into catalogItems, then
-- rewrites parsedSources to the stamp-only shape (sourceHash + lastParsed)
-- SourceTextScanner's change-detection needs. See CatalogStore:SetSources'
-- comment and ITEM_SNAPSHOT_CONTRACT.md Open Question #1 for the design
-- authority (resolved: catalogItems persists parsed source data).
--
-- Newer-wins when both sides have data and disagree: verified the CURRENT
-- write path (SourceTextScanner:ProcessScannedItem) writes both tables
-- atomically in one call, so real divergence is only possible from
-- pre-dual-write history — comparing lastParsed timestamps picks the
-- objectively newer payload rather than assuming a fixed write order.
--
-- Idempotent (M10a rule — every migration must survive a re-run untouched):
-- an entry already rewritten to the stamp-only shape has no .sources field,
-- so the migrate-in branch below is skipped entirely and the stamp is
-- rewritten to itself (a no-op value-wise).
local function Migration_4_to_5(db)
    local global = db.global
    local parsedSources = global.parsedSources
    if parsedSources then
        for itemID, data in pairs(parsedSources) do
            -- Idempotence guard: an already-migrated (stamp-only) entry has
            -- no .sources field — nothing left to move for this item.
            if data.sources then
                local record = ci[itemID]
                local recordHasSources = record and record.sources ~= nil

                local takeParsed = not recordHasSources
                if recordHasSources and record.sourceHash ~= data.sourceHash then
                    takeParsed = (data.lastParsed or 0) > (record.lastParsed or 0)
                end

                if takeParsed then
                    if not record then
                        ci[itemID] = {}
                        record = ci[itemID]
                    end
                    record.sources = data.sources
                    record.sourceHash = data.sourceHash
                    record.lastParsed = data.lastParsed
                end

                -- Preserve dev raw sourceText regardless of which side won
                -- (Argus HS-205 cycle 1): the common dual-write-era state is
                -- EQUAL hashes, where takeParsed is false — copying raw only
                -- inside that branch destroyed the whole dev raw corpus in the
                -- common case while the stamp rewrite below deletes data.raw.
                -- Idempotence holds: the second run has no data.raw to copy.
                if data.raw and record and record.rawSourceText == nil then
                    record.rawSourceText = data.raw
                end

                -- Map parsedSources recordID to decorID (mirrors Migration_1_to_2;
                -- harmless to repeat for a record that still lacks one). Route
                -- through _save so the reverse index updates structurally.
                if data.recordID and not (ci[itemID] and ci[itemID].decorID) then
                    _save(itemID, { decorID = data.recordID })
                end
            end

            -- Rewrite to the stamp-only shape. Must mirror whichever payload
            -- actually ended up authoritative in catalogItems (ci[itemID]),
            -- NOT parsedSources' own original values unconditionally — when
            -- catalogItems won (it was newer), stamping with parsedSources'
            -- stale hash would make a future live reparse compare the fresh
            -- sourceText hash against a hash that was never authoritative,
            -- triggering a spurious reparse.
            local finalRecord = ci[itemID]
            parsedSources[itemID] = {
                sourceHash = finalRecord and finalRecord.sourceHash or data.sourceHash,
                lastParsed = finalRecord and finalRecord.lastParsed or data.lastParsed,
            }
        end
    end

    global.schemaVersion = 5

    if HA.Addon then
        HA.Addon:Debug("CatalogStore: Migration 4→5 complete")
    end
end

function CatalogStore:RunMigrations()
    if not HA.Addon or not HA.Addon.db then return end
    local db = HA.Addon.db

    -- HS-209 M10a: schemaVersion has no type guarantee — a hand-edited WTF or
    -- a downgrade artifact can leave it as a non-number, and `version < 2`
    -- below would throw uncaught ("attempt to compare number with <type>"),
    -- aborting RunMigrations and, with it, the whole OnEnable chain silently.
    -- Coerce and repair rather than trust the stored value; every migration
    -- here is idempotent (each guards its own already-applied state), so
    -- falling back to 1 and re-running is safe even if the corrupt value
    -- meant "already migrated."
    local storedVersion = db.global.schemaVersion
    local version = tonumber(storedVersion)
    if not version then
        version = 1
        if HA.Addon then
            HA.Addon:Debug("CatalogStore: schemaVersion was not a number ("
                .. tostring(storedVersion) .. ") — repairing to 1 and re-running migrations")
        end
        db.global.schemaVersion = version
    end

    if version < 2 then
        Migration_1_to_2(db)
    end

    if version < 3 then
        Migration_2_to_3(db)
    end

    if version < 4 then
        Migration_3_to_4(db)
    end

    if version < 5 then
        Migration_4_to_5(db)
    end
end

function CatalogStore:Initialize()
    if not HA.Addon or not HA.Addon.db then return end

    -- Bind local reference to catalogItems table
    ci = HA.Addon.db.global.catalogItems

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

-- HS-273 R3 (predicate corrected at Gate 1 closure): whether the persistent
-- cache holds an OWNERSHIP SIGNAL worth computing badge stats from. Record
-- presence is not that signal: a cold full scan writes name-only records for
-- every item ("Checked: 1624 Owned: 0", HS-216), and the /hs clear-ownership
-- command empties isOwned on every record while leaving the records in
-- place — under a mere next(ci) check both states let a prewarm confidently
-- cache "0 owned" everywhere for a player who owns plenty. ownedCount > 0 is
-- the O(1) truth the counters already maintain. The escape hatch admits the
-- one other state where a zero is CONFIRMED true rather than unknown:
-- storage answered this session AND the live total was zero (a genuine
-- zero-decor player — HasStorageResponded true, IsWarm false, since IsWarm's
-- latch needs total > 0). A decor owner mid-first-scan is the opposite shape
-- (IsWarm true, ownedCount still 0) and stays gated to the honest "..."
-- until the scan records ownership. Not "IsWarm or" — that polarity is
-- unreachable for the zero-decor player and opens exactly the wrong window
-- (Argus Gate 1 closure finding).
function CatalogStore:HasPersistedData()
    if ci == nil then return false end
    if ownedCount > 0 then return true end
    local scanner = HA.CatalogScanner
    return scanner ~= nil
        and scanner.HasStorageResponded ~= nil and scanner:HasStorageResponded() == true
        and scanner.IsWarm ~= nil and not scanner:IsWarm()
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("CatalogStore", CatalogStore)
end
