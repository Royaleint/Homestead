--[[
    Homestead - ScanPersistence
    Vendor scan data storage, retrieval, clearing, and export

    Extracted from VendorScanner.lua to reduce file size.
    Manages all SavedVariables reads/writes for scanned vendor data.

    Reusable by VendorScanner, ExportImport, Options, etc.
]]

local _, HA = ...

local ScanPersistence = {}
HA.ScanPersistence = ScanPersistence

-------------------------------------------------------------------------------
-- Data Storage
-------------------------------------------------------------------------------

-- HS-251 Stage C: the aggregate housingCount guard (existingHousingCount vs
-- vendorRecord.housingCount below) misses a rescan that loses items from one
-- subclass while gaining items in another — same total, real data loss. This
-- generalizes it per subclass. subclassCounts is sparse (only subclasses
-- actually present get a key), so only the EXISTING record's keys are worth
-- walking: a subclass appearing for the first time in the new scan is growth,
-- never loss, and needs no comparison.
local function SubclassCountsRegressed(existingCounts, newCounts)
    if not existingCounts then return false end
    for subclassID, count in pairs(existingCounts) do
        if count > ((newCounts and newCounts[subclassID]) or 0) then
            return true
        end
    end
    return false
end

function ScanPersistence:SaveVendorData(scanData)
    -- Ensure SavedVariables structure exists
    if not HA.Addon.db or not HA.Addon.db.global then
        HA.Addon:Debug("SavedVariables not ready, cannot save vendor data")
        return
    end

    -- Initialize scanned vendors storage
    if not HA.Addon.db.global.scannedVendors then
        HA.Addon.db.global.scannedVendors = {}
    end

    local existingData = HA.Addon.db.global.scannedVendors[scanData.npcID]

    -- HS-249: records written before the housing gate carry no housingCount.
    -- On those, decorCount IS the housing count — decor was the only subclass
    -- the old gate could capture. Falling back to 0 instead would make the
    -- partial-scan guard below never fire for any pre-existing record, so the
    -- first laggy rescan after updating would destroy it.
    local existingHousingCount = existingData
        and (existingData.housingCount or existingData.decorCount or 0)
        or 0

    -- HS-251 Stage C: a record with no subclassCounts is one of two shapes,
    -- and they need different fallbacks. Pre-housing-gate records (written
    -- before 6e5d82f) carry items with no subclassID at all — decor was the
    -- only subclass the old gate could ever see, so attribute the whole
    -- legacy housing count to Decor. But records written by 6e5d82f onward
    -- DO carry per-item subclassID (they just predate the subclassCounts
    -- summary field itself) — for those, deriving the tally from the items
    -- is exact, not a guess, and using the Decor-only fallback on THIS shape
    -- both hides real subclass loss (same aggregate, different mix — the
    -- exact bug this guard exists to catch) and permanently blocks a
    -- non-decor vendor's legitimate unconfirmed rescans, since it never
    -- self-heals (subclassCounts is only written when a save lands).
    local existingSubclassCounts = existingData and existingData.subclassCounts
    if existingData and not existingSubclassCounts then
        local derivedFromItems, anySubclassID = {}, false
        for _, item in ipairs(existingData.items or {}) do
            if item.subclassID ~= nil then
                anySubclassID = true
                derivedFromItems[item.subclassID] = (derivedFromItems[item.subclassID] or 0) + 1
            end
        end
        existingSubclassCounts = anySubclassID
            and derivedFromItems
            or { [Enum.ItemHousingSubclass.Decor] = existingHousingCount }
    end

    -- Build vendor record with enhanced data. decorCount/hasDecor keep
    -- counting subclass 0 (Decor) only — decorCount is a consumed wire format
    -- read by downstream tooling and by every archived scan on disk, so its
    -- meaning must not change. housingCount/hasHousing cover every housing
    -- subclass captured by the gate in DecorClassifier.
    local housingCount = scanData.housingItems and #scanData.housingItems or 0
    local itemCount = scanData.allItems and #scanData.allItems or scanData.totalItems or 0

    local decorCount = 0
    for _, item in ipairs(scanData.housingItems or {}) do
        if item.subclassID == Enum.ItemHousingSubclass.Decor then
            decorCount = decorCount + 1
        end
    end

    local vendorRecord = {
        npcID = scanData.npcID,
        name = scanData.vendorName,
        mapID = scanData.mapID,
        coords = scanData.coords,
        faction = scanData.faction or "Neutral",
        zone = scanData.zone,
        subZone = scanData.subZone,
        realZone = scanData.realZone,
        parentMapID = scanData.parentMapID,
        mapChain = scanData.mapChain,
        continentMapID = scanData.continentMapID,
        lastScanned = time(),
        itemCount = itemCount,          -- Total items at vendor
        decorCount = decorCount,        -- Housing decor items (subclass 0 only)
        hasDecor = decorCount > 0,      -- Flag to identify if vendor sells housing decor
        lastScanHadDecor = decorCount > 0, -- Last observed scan result, even if old items are preserved
        housingCount = housingCount,    -- All housing items, any subclass
        hasHousing = housingCount > 0,  -- Flag to identify if vendor sells any housing item
        -- subclassCounts is NOT set here — it's derived once from the final
        -- vendorRecord.items below (after decorID enrichment / merge logic),
        -- the same way decorCount/housingCount already are. Setting it here
        -- too would just be overwritten there, unread in between.
        -- HS-250: housing-wide counterpart to lastScanHadDecor; see IsDelistCandidate.
        lastScanHadHousing = housingCount > 0,
        items = {},                     -- Enhanced item data
    }

    -- Add housing items (all subclasses) with full enhanced data
    for _, item in ipairs(scanData.housingItems or {}) do
        local itemRecord = {
            itemID = item.itemID,
            name = item.name,
            subclassID = item.subclassID,
            decorID = item.decorID,
            price = item.price,
            stackCount = item.stackCount,
            isPurchasable = item.isPurchasable,
            isUsable = item.isUsable,
            spellID = item.spellID,
            requirements = item.requirements,
            merchantSlot = item.merchantSlot,
            hasExtendedCost = item.hasExtendedCost,
        }

        -- Add currency data if present
        if item.currencies and #item.currencies > 0 then
            itemRecord.currencies = item.currencies
        end

        -- Add item cost data if present (tokens, reagents, etc.)
        if item.itemCosts and #item.itemCosts > 0 then
            itemRecord.itemCosts = item.itemCosts
        end

        table.insert(vendorRecord.items, itemRecord)
    end

    -- Infer primary currency from item cost data
    local currencyCounts = {}
    for _, item in ipairs(vendorRecord.items) do
        if item.currencies then
            for _, c in ipairs(item.currencies) do
                local key = c.name or ("Currency " .. tostring(c.currencyID or "?"))
                currencyCounts[key] = (currencyCounts[key] or 0) + 1
            end
        end
    end
    local maxCount, primaryCurrency = 0, nil
    for name, count in pairs(currencyCounts) do
        if count > maxCount then
            maxCount = count
            primaryCurrency = name
        end
    end
    vendorRecord.currency = primaryCurrency
    vendorRecord.expansion = scanData.expansion

    -- Merge with existing data if present (keep more complete record)
    if existingData then
        -- Use newer coords if available
        if scanData.coords and scanData.coords.x and scanData.coords.y
            and scanData.coords.x ~= 0.5 and scanData.coords.y ~= 0.5 then
            vendorRecord.coords = scanData.coords
        elseif existingData.coords then
            vendorRecord.coords = existingData.coords
        end

        -- Preserve faction from existing data if current scan didn't capture it
        if not vendorRecord.faction or vendorRecord.faction == "Neutral" then
            if existingData.faction and existingData.faction ~= "Neutral" then
                vendorRecord.faction = existingData.faction
            end
        end

        -- Preserve metadata when new scan has nil (don't overwrite good data)
        vendorRecord.zone = vendorRecord.zone or existingData.zone
        vendorRecord.subZone = vendorRecord.subZone or existingData.subZone
        vendorRecord.realZone = vendorRecord.realZone or existingData.realZone
        vendorRecord.parentMapID = vendorRecord.parentMapID or existingData.parentMapID
        vendorRecord.mapChain = vendorRecord.mapChain or existingData.mapChain
        vendorRecord.continentMapID = vendorRecord.continentMapID or existingData.continentMapID
        vendorRecord.expansion = vendorRecord.expansion or existingData.expansion
        vendorRecord.currency = vendorRecord.currency or existingData.currency

        -- HS-249: decorID is now produced by an enrichment step rather than by
        -- the capture test itself, so a cold housing catalog yields genuine
        -- decor items carrying no decorID. Before this ticket such an item
        -- failed capture outright and the preserve branches below kept the old
        -- record intact; now it IS captured, the housing counts match, and a
        -- good row would be overwritten by one that had silently lost its
        -- decorID. Carry a known decorID forward per item.
        --
        -- This is not a merge of the item lists — an item absent from the
        -- current scan stays absent. Only a field the scan could not resolve
        -- is refilled, in the same spirit as the metadata preservation above.
        local knownDecorIDs = nil
        for _, item in ipairs(existingData.items or {}) do
            if item.itemID and item.decorID then
                knownDecorIDs = knownDecorIDs or {}
                knownDecorIDs[item.itemID] = item.decorID
            end
        end
        if knownDecorIDs then
            for _, item in ipairs(vendorRecord.items) do
                if item.itemID and not item.decorID then
                    item.decorID = knownDecorIDs[item.itemID]
                end
            end
        end

        -- DON'T merge item lists - use the current scan as authoritative
        -- The current scan is the source of truth for what the vendor sells NOW
    end

    -- Recalculate counts based on final data
    local finalSubclassCounts = {}
    for _, item in ipairs(vendorRecord.items) do
        if item.subclassID ~= nil then
            finalSubclassCounts[item.subclassID] = (finalSubclassCounts[item.subclassID] or 0) + 1
        end
    end
    vendorRecord.subclassCounts = finalSubclassCounts
    vendorRecord.decorCount = finalSubclassCounts[Enum.ItemHousingSubclass.Decor] or 0
    vendorRecord.hasDecor = vendorRecord.decorCount > 0
    vendorRecord.housingCount = #vendorRecord.items
    vendorRecord.hasHousing = vendorRecord.housingCount > 0

    -- Determine if this vendor is in any static data source (known decor vendor)
    local isKnownVendor = HA.VendorData and HA.VendorData:HasVendor(scanData.npcID) or false

    -- Determine scan confidence BEFORE the save decision below (moved up from
    -- its old post-save position): "confirmed" only if the scan completed AND
    -- every item slot returned valid data. "unknown" if the scan completed but
    -- any C_MerchantFrame.GetItemInfo() call returned nil during
    -- ProcessScanQueue() — e.g. a laggy partial scan with no retry.
    local scanConfidence = "unknown"
    if scanData.scanComplete and not scanData.hadNilSlots then
        scanConfidence = "confirmed"
    end
    vendorRecord.scanConfidence = scanConfidence

    if vendorRecord.hasHousing
            and existingData and scanConfidence ~= "confirmed"
            and (existingHousingCount > vendorRecord.housingCount
                or SubclassCountsRegressed(existingSubclassCounts, vendorRecord.subclassCounts)) then
        -- An unconfirmed (laggy/partial) scan found fewer items than the
        -- existing record — either in aggregate or, HS-251 Stage C, within a
        -- single subclass while the total happened to match (e.g. 3 fewer
        -- decor, 3 more room plans: same housingCount, real data loss). The
        -- aggregate check alone missed that case. The two checks are NOT
        -- redundant, and both stay: the per-subclass tally only counts items
        -- with a resolved subclassID, so a scan that loses an item whose
        -- subclass never resolved moves housingCount without moving any
        -- subclass count — only the aggregate check catches that one.
        -- Saving would clobber a larger, cleaner record with a worse one.
        -- Preserve the existing
        -- record entirely — do NOT touch lastScanned here: that field means
        -- "these items were observed at this time," and this attempt
        -- observed neither the full item set nor confirmed data. Re-dating it
        -- would tell every recency consumer (UI staleness, HS-151
        -- consolidation, scan-timestamp provenance) that the unobserved rows
        -- were freshly re-verified. Record the attempt separately instead.
        existingData.lastScanAttempt = vendorRecord.lastScanned
        -- Debug (already debug-gated) rather than DevAddon-gated: a rejected
        -- scan is evidence loss the user should be able to see with debug on.
        HA.Addon:Debug(string.format(
            "Scan protection: %s (NPC %d) unconfirmed scan found %d housing items, "
            .. "fewer than the existing %d. Preserving existing scan data.",
            scanData.vendorName or "?", scanData.npcID,
            vendorRecord.housingCount, existingHousingCount
        ))
    elseif vendorRecord.hasHousing then
        -- Good scan: save new data
        HA.Addon.db.global.scannedVendors[scanData.npcID] = vendorRecord
    elseif isKnownVendor then
        -- Known housing vendor scanned with 0 housing items = API failure,
        -- not truth. Preserve existing scan data; record the latest scan
        -- result separately.
        if existingData then
            existingData.lastScanned = vendorRecord.lastScanned
            existingData.lastScanHadDecor = false
            existingData.lastScanHadHousing = false
            if vendorRecord.coords and vendorRecord.coords.x ~= 0.5 and vendorRecord.coords.y ~= 0.5 then
                existingData.coords = vendorRecord.coords
            end
            existingData.zone = vendorRecord.zone or existingData.zone
            existingData.subZone = vendorRecord.subZone or existingData.subZone
        end
        if HA.DevAddon then
            HA.Addon:Debug(string.format(
                "Scan protection: %s (NPC %d) is a known vendor but scan found 0 housing items. "
                .. "Preserving existing scan data.",
                scanData.vendorName or "?", scanData.npcID
            ))
        end
    elseif existingData and (existingData.hasHousing or existingData.hasDecor) then
        -- Previously scanned with housing items, now 0. Suspicious — preserve
        -- old data. The hasDecor fallback covers records saved before this
        -- field existed: hasDecor=true on an old record still means it had
        -- housing items (decor is a housing subclass), so it must not fall
        -- through to the delete branch below just because hasHousing is nil.
        existingData.lastScanned = vendorRecord.lastScanned
        existingData.lastScanHadDecor = false
        existingData.lastScanHadHousing = false
        if HA.DevAddon then
            HA.Addon:Debug(string.format(
                "Scan protection: %s (NPC %d) previously had housing items but new scan found 0. "
                .. "Preserving previous scan data.",
                scanData.vendorName or "?", scanData.npcID
            ))
        end
    else
        -- Unknown vendor, no prior good data, 0 housing items: don't persist
        HA.Addon.db.global.scannedVendors[scanData.npcID] = nil
        -- Deletion path fires no VENDOR_SCANNED, so rebuild the reverse
        -- index directly to drop stale (itemID -> npcID) entries pointing
        -- at the removed record.
        if HA.VendorData and HA.VendorData.BuildScannedIndex then
            HA.VendorData:BuildScannedIndex()
        end
    end

    if HA.DevAddon then
        HA.Addon:Debug("Saved vendor data for " .. scanData.vendorName ..
            " - " .. vendorRecord.decorCount .. "/" .. vendorRecord.itemCount ..
            " decor items (" .. vendorRecord.housingCount .. " housing items total), faction: "
            .. vendorRecord.faction)
    end

    -- Maintain persistent no-decor tracking (survives ClearScannedData)
    if not HA.Addon.db.global.noDecorVendors then
        HA.Addon.db.global.noDecorVendors = {}
    end

    if vendorRecord.hasHousing == false and scanConfidence == "confirmed" then
        if isKnownVendor then
            -- Never flag known vendors as no-decor. Clear any stale entry (recovery).
            HA.Addon.db.global.noDecorVendors[scanData.npcID] = nil
            if HA.DevAddon then
                HA.Addon:Debug(string.format(
                    "No-Decor BLOCKED: %s (NPC %d) is in static database. Refusing to flag.",
                    vendorRecord.name or "?", scanData.npcID
                ))
            end
        else
            -- Unknown vendor: flag normally
            local existing = HA.Addon.db.global.noDecorVendors[scanData.npcID]
            local confirmCount = (existing and existing.confirmCount or 0) + 1
            HA.Addon.db.global.noDecorVendors[scanData.npcID] = {
                name = vendorRecord.name,
                confirmedAt = time(),
                itemCount = vendorRecord.itemCount,
                inDatabase = false,
                scanConfidence = "confirmed",
                confirmCount = confirmCount,
            }
            if HA.DevAddon and confirmCount >= 2 then
                HA.Addon:Debug(string.format(
                    "No-Decor: %s (NPC %d) has %d items but 0 decor (confirmed %dx).",
                    vendorRecord.name or "?", scanData.npcID, vendorRecord.itemCount, confirmCount
                ))
            end
        end
    elseif vendorRecord.hasHousing == true then
        -- Re-scan found housing items: unhide vendor
        HA.Addon.db.global.noDecorVendors[scanData.npcID] = nil
    end

    -- Persist item-level data to CatalogStore (requirements + decorID)
    -- hadRequirementDiscovery is tracked as a local, NOT a vendorRecord field —
    -- vendorRecord is the exact table written to SavedVariables above, and a
    -- field on it would persist into the save file. It's passed as a second
    -- argument on the VENDOR_SCANNED fire below instead.
    local hadRequirementDiscovery = false
    if HA.CatalogStore then
        for _, item in ipairs(vendorRecord.items) do
            -- Containment: never create a catalogItems record for a non-decor
            -- housing item. CatalogStore:IsDecorItem gate 1 keys off catalog
            -- membership — giving a room plan an entry would switch on bag/
            -- merchant/tooltip ownership overlays we cannot compute for it
            -- yet (Phase 2), printing "Not Owned" on an item whose ownership
            -- is genuinely unknown.
            if item.itemID and item.subclassID == Enum.ItemHousingSubclass.Decor then
                if item.requirements and #item.requirements > 0 then
                    HA.CatalogStore:SetRequirements(item.itemID, item.requirements)
                    -- Newly discovered requirements can affect availability/lock
                    -- state for this item on OTHER vendors too, not just this one —
                    -- VENDOR_SCANNED listeners need this so a per-vendor cache
                    -- invalidation isn't treated as sufficient.
                    hadRequirementDiscovery = true
                end
                if item.decorID then
                    HA.CatalogStore:Save(item.itemID, { decorID = item.decorID })
                end
            end
        end
    end

    -- Track vendor scan
    if HA.Analytics then
        HA.Analytics:IncrementCounter("VendorScans")
    end

    -- Invalidate cached vendor data (new scan data may affect results)
    if HA.VendorData and HA.VendorData.InvalidateVendorCaches then
        HA.VendorData:InvalidateVendorCaches()
    end

    -- Fire callback for other modules. The second arg must never be nil —
    -- Fire packs varargs and unpack truncates at nil holes; the local is
    -- initialized false and only ever set true, which this contract relies on.
    if HA.Events then
        HA.Events:Fire("VENDOR_SCANNED", vendorRecord, hadRequirementDiscovery)
    end
end

-------------------------------------------------------------------------------
-- Data Retrieval
-------------------------------------------------------------------------------

function ScanPersistence:GetScannedVendors()
    if HA.Addon.db and HA.Addon.db.global and HA.Addon.db.global.scannedVendors then
        return HA.Addon.db.global.scannedVendors
    end
    return {}
end

function ScanPersistence:GetScannedVendor(npcID)
    local vendors = self:GetScannedVendors()
    return vendors[npcID]
end

-------------------------------------------------------------------------------
-- NPC ID Corrections
-------------------------------------------------------------------------------

-- Get the corrected NPC ID for a vendor name (used at runtime)
function ScanPersistence:GetCorrectedNPCID(vendorName)
    if HA.Addon.db and HA.Addon.db.global.npcIDCorrections then
        local correction = HA.Addon.db.global.npcIDCorrections[vendorName]
        if correction then
            return correction.newID
        end
    end
    return nil
end

-- Export NPC ID corrections for manual database updates
function ScanPersistence:ExportNPCIDCorrections()
    if not HA.Addon.db or not HA.Addon.db.global.npcIDCorrections then
        HA.Addon:Print("No NPC ID corrections recorded.")
        return ""
    end

    local output = "-- Homestead NPC ID Corrections\n"
    output = output .. "-- Generated: " .. date("%Y-%m-%d %H:%M:%S") .. "\n\n"

    local count = 0
    for name, correction in pairs(HA.Addon.db.global.npcIDCorrections) do
        output = output .. string.format("-- %s: %d -> %d\n", name, correction.oldID, correction.newID)
        count = count + 1
    end

    if count == 0 then
        HA.Addon:Print("No NPC ID corrections recorded.")
        return ""
    end

    HA.Addon:Print("Found " .. count .. " NPC ID correction(s). Copy from chat or use /hs exportcorrections")
    return output
end

-------------------------------------------------------------------------------
-- Data Clearing
-------------------------------------------------------------------------------

-- Helper: refresh map pins after data changes
local function RefreshMapPins()
    if HA.VendorData then
        HA.VendorData:BuildScannedIndex()
    end
    if HA.VendorMapPins then
        HA.VendorMapPins:InvalidateAllCaches()
        if WorldMapFrame and WorldMapFrame:IsShown() then
            HA.VendorMapPins:RefreshPins()
        end
        HA.VendorMapPins:RefreshMinimapPins()
    end
end

function ScanPersistence:ClearScannedData()
    if not HA.Addon.db or not HA.Addon.db.global then return end

    local count = 0
    if HA.Addon.db.global.scannedVendors then
        for _ in pairs(HA.Addon.db.global.scannedVendors) do count = count + 1 end
    end

    HA.Addon.db.global.scannedVendors = {}
    -- noDecorVendors intentionally preserved
    HA.Addon.db.global.lastExportTimestamp = nil

    RefreshMapPins()

    HA.Addon:Print(string.format("Cleared %d scanned vendor(s). No-decor flags preserved.", count))
    return count
end

function ScanPersistence:ClearNoDecorData()
    local count = 0
    if HA.Addon.db and HA.Addon.db.global and HA.Addon.db.global.noDecorVendors then
        for _ in pairs(HA.Addon.db.global.noDecorVendors) do count = count + 1 end
        HA.Addon.db.global.noDecorVendors = {}
    end

    RefreshMapPins()

    HA.Addon:Print(string.format("Cleared %d no-decor flag(s). Hidden vendors will reappear.", count))
    return count
end

function ScanPersistence:ClearAllData()
    if not HA.Addon.db or not HA.Addon.db.global then return end

    HA.Addon.db.global.scannedVendors = {}
    HA.Addon.db.global.noDecorVendors = {}
    HA.Addon.db.global.lastExportTimestamp = nil

    RefreshMapPins()

    HA.Addon:Print("Cleared ALL vendor data including no-decor flags.")
end

-------------------------------------------------------------------------------
-- Export
-------------------------------------------------------------------------------

-- DEPRECATED: legacy debug renderer, not the canonical export path.
-- Canonical export = ExportImport:ExportScannedVendors() (format version 2).
-- Output is stripped (itemID + name only; no cost data, no currencies).
-- Candidate for removal after HS-135 (T2-5 VendorDatabase migration) is confirmed complete.
function ScanPersistence:ExportScannedData()
    local vendors = self:GetScannedVendors()
    local export = {
        version = 1,
        timestamp = time(),
        vendors = {},
    }

    for npcID, data in pairs(vendors) do
        table.insert(export.vendors, {
            npcID = data.npcID,
            name = data.name,
            mapID = data.mapID,
            coords = data.coords,
            items = data.items,
        })
    end

    -- Convert to Lua table format string
    local output = "-- Homestead Vendor Scanner Export\n"
    output = output .. "-- Generated: " .. date("%Y-%m-%d %H:%M:%S") .. "\n"
    output = output .. "-- Vendors: " .. #export.vendors .. "\n\n"

    for _, vendor in ipairs(export.vendors) do
        output = output .. "-- " .. vendor.name .. " (NPC ID: " .. vendor.npcID .. ")\n"
        output = output .. "{\n"
        output = output .. "    npcID = " .. vendor.npcID .. ",\n"
        output = output .. "    name = \"" .. (vendor.name or "") .. "\",\n"
        output = output .. "    mapID = " .. (vendor.mapID or 0) .. ",\n"
        output = output .. "    coords = { x = " .. string.format("%.3f", vendor.coords.x) .. ", y = " .. string.format("%.3f", vendor.coords.y) .. " },\n"
        output = output .. "    items = {\n"
        for _, item in ipairs(vendor.items or {}) do
            output = output .. "        { itemID = " .. (item.itemID or 0) .. ", name = \"" .. (item.name or "") .. "\" },\n"
        end
        output = output .. "    },\n"
        output = output .. "},\n\n"
    end

    return output
end
