--[[
    Homestead - ScanPersistence
    Vendor scan data storage, retrieval, and clearing

    Extracted from VendorScanner.lua to reduce file size.
    Manages all SavedVariables reads/writes for scanned vendor data.

    Reusable by VendorScanner, Options, etc.
]]

local _, HA = ...

local ScanPersistence = {}
HA.ScanPersistence = ScanPersistence

-------------------------------------------------------------------------------
-- Data Storage
-------------------------------------------------------------------------------

-- the aggregate housingCount guard (existingHousingCount vs
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

-------------------------------------------------------------------------------
-- Cost Evidence Sidecar
-- db.global.vendorCostEvidence[npcID][itemID] = {
--     selected   = {cost, observedAt, environment, witness} -- a complete
--                  single-bundle snapshot that replaces the shipped set,
--     unresolved = {[claimKey] = witness},                  -- raw claims,
--     changed    = merge serial of the last retained change,
-- }
-- Independent of scannedVendors: replacing or deleting a vendor record never
-- erases it. Only explicit clears do. Ordinary single-cost items never enter
-- it. A witness is one item's frozen rows from one listing observation plus
-- that observation's identity; its fields never change once retained.
--
-- db.global.costEvidenceCounters holds the allocators and survives clears:
-- origin (opaque, per install), nextContext, captureSerial, mergeSerial and
-- exportCursor. db.char.costEvidenceContext is this character's opaque
-- context ID. Neither is derived from any name or GUID.
-------------------------------------------------------------------------------

local MAX_SCANNED_SLOTS = 200

local function EvidenceCounters(global)
    local counters = global.costEvidenceCounters
    if not counters then
        counters = {
            origin = string.format("o%x", time()),
            nextContext = 0,
            captureSerial = 0,
            mergeSerial = 0,
            exportCursor = 0,
        }
        global.costEvidenceCounters = counters
    end
    return counters
end

-- Opaque identity for one bounded listing observation, allocated once when
-- the observation starts and never rewritten afterwards.
function ScanPersistence:AllocateCostGroup(npcID, mapID)
    local db = HA.Addon and HA.Addon.db
    if not db or not db.global then return nil end
    local counters = EvidenceCounters(db.global)
    local charData = db.char
    local context = charData and charData.costEvidenceContext
    if charData and not context then
        counters.nextContext = counters.nextContext + 1
        context = "c" .. counters.nextContext
        charData.costEvidenceContext = context
    end
    counters.captureSerial = counters.captureSerial + 1

    local version, build
    if GetBuildInfo then version, build = GetBuildInfo() end
    local environment = (IsPublicTestClient and IsPublicTestClient()) and "ptr" or "retail"
    return {
        origin = counters.origin,
        context = context or "c0",
        vendor = npcID,
        serial = counters.captureSerial,
        epoch = time(),
        build = (version and build) and (version .. "." .. build) or nil,
        environment = environment,
        locale = GetLocale and GetLocale() or nil,
        mapID = mapID,
    }
end

local function GroupKey(group)
    return table.concat({group.origin, group.context, tostring(group.vendor),
        tostring(group.serial), tostring(group.epoch)}, ":")
end

local function CopyComponents(components)
    local copy = {}
    for i, component in ipairs(components or {}) do
        copy[i] = {kind = component.kind, id = component.id, amount = component.amount, name = component.name}
    end
    return copy
end

local function FreezeRow(row)
    return {
        slot = row.merchantSlot,
        itemID = row.itemID,
        price = row.price,
        quantity = row.stackCount,
        extended = row.hasExtendedCost,
        costCount = row.costCount,
        components = CopyComponents(row.costComponents),
        purchasable = row.isPurchasable,
        usable = row.isUsable,
        complete = row.costComplete == true,
    }
end

-- The bundle a complete frozen row pays, or nil for an incomplete row.
local function RowBundle(row)
    if not row.complete then return nil end
    local bundle = {purchaseQuantity = row.quantity}
    if row.price and row.price > 0 then bundle.gold = row.price end
    for _, component in ipairs(row.components) do
        local field = component.kind == "currency" and "currencies" or "items"
        bundle[field] = bundle[field] or {}
        table.insert(bundle[field], {id = component.id, amount = component.amount})
    end
    return bundle
end

-- Partial-data signature of any row, used only to notice distinct bundles.
local function RowSignature(row)
    local parts = {tostring(row.price), tostring(row.quantity), tostring(row.extended)}
    local tokens = {}
    for _, component in ipairs(row.components) do
        tokens[#tokens + 1] = tostring(component.kind) .. tostring(component.id or component.name)
            .. "x" .. tostring(component.amount)
    end
    table.sort(tokens)
    parts[#parts + 1] = table.concat(tokens, ",")
    return table.concat(parts, "|")
end

local function CoverageOf(scanData, terminationReason)
    local total = scanData.originalTotal or scanData.totalItems
    local capped = total ~= nil and total > MAX_SCANNED_SLOTS
    local coherent = not scanData.coherenceInvalidated
    local complete = total ~= nil and not capped and coherent and terminationReason == nil
        and scanData.scanComplete == true and not scanData.hadNilSlots
    return {
        total = total,
        capped = capped,
        coherent = coherent,
        complete = complete,
        reason = terminationReason,
    }
end

-- Merge the relevant cost evidence of one listing attempt into the sidecar.
-- Relevant: an item seen with several distinct bundles, or a pair already
-- tracked (shipped whole-set data or retained evidence). Never touches
-- scannedVendors, lastScanned or scan confidence. Returns true when the
-- retained evidence changed. Callers invalidate (SaveCostEvidence below).
function ScanPersistence:MergeCostEvidence(scanData, terminationReason)
    local db = HA.Addon and HA.Addon.db
    local group = scanData and scanData.costGroup
    if not db or not db.global or not group or not scanData.housingItems then return false end

    local byItem, order = {}, {}
    for _, row in ipairs(scanData.housingItems) do
        if row.itemID then
            if not byItem[row.itemID] then
                byItem[row.itemID] = {}
                order[#order + 1] = row.itemID
            end
            table.insert(byItem[row.itemID], FreezeRow(row))
        end
    end
    if #order == 0 then return false end

    local VD = HA.VendorData
    if not VD or not VD.CostBundleSignature then return false end
    local npcID = scanData.npcID
    local vendorRef = {npcID = npcID, name = scanData.vendorName}
    local coverage = CoverageOf(scanData, terminationReason)
    local key = GroupKey(group)
    local changedEntries = {}

    for _, itemID in ipairs(order) do
        local rows = byItem[itemID]
        table.sort(rows, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
        local distinct, seen = 0, {}
        local bundles, bundleSeen, allComplete = {}, {}, true
        for _, row in ipairs(rows) do
            local signature = RowSignature(row)
            if not seen[signature] then
                seen[signature] = true
                distinct = distinct + 1
            end
            local bundle = RowBundle(row)
            if bundle then
                local bundleSignature = VD:CostBundleSignature(bundle)
                if not bundleSeen[bundleSignature] then
                    bundleSeen[bundleSignature] = true
                    bundles[#bundles + 1] = bundle
                end
            end
            if not row.complete or row.quantity == nil then allComplete = false end
        end

        local state = VD:GetCostSetState(vendorRef, itemID)
        if distinct > 1 or state then
            local evidence = db.global.vendorCostEvidence
            if not evidence then
                evidence = {}
                db.global.vendorCostEvidence = evidence
            end
            evidence[npcID] = evidence[npcID] or {}
            local entry = evidence[npcID][itemID]
            if not entry then
                entry = {unresolved = {}}
                evidence[npcID][itemID] = entry
            end

            local witness = {
                group = group,
                groupKey = key,
                coverage = coverage,
                itemID = itemID,
                rows = rows,
                bundles = bundles,
                observedAt = group.epoch,
            }

            if coverage.complete and allComplete and #bundles == 1 then
                -- A complete coherent listing showing one bundle replaces the
                -- whole set; older comparable claims are settled by it.
                if not entry.selected or (entry.selected.observedAt or 0) < group.epoch then
                    entry.selected = {
                        cost = bundles[1],
                        observedAt = group.epoch,
                        environment = group.environment,
                        witness = witness,
                    }
                    for claimKey, older in pairs(entry.unresolved) do
                        if older.observedAt and older.observedAt < group.epoch
                                and older.group.environment == group.environment then
                            entry.unresolved[claimKey] = nil
                        end
                    end
                    changedEntries[#changedEntries + 1] = entry
                end
            else
                local bundleSignatures = {}
                for i, bundle in ipairs(bundles) do
                    bundleSignatures[i] = VD:CostBundleSignature(bundle)
                end
                table.sort(bundleSignatures)
                local setSignature = table.concat(bundleSignatures, "||")
                -- Incomplete rows never contradict a set, but their raw shape
                -- is part of what was observed: attempts that read different
                -- incomplete values stay separate witnesses.
                local incompleteShapes = {}
                for _, row in ipairs(rows) do
                    if not row.complete then incompleteShapes[#incompleteShapes + 1] = RowSignature(row) end
                end
                table.sort(incompleteShapes)
                local claimKey = table.concat({tostring(group.vendor), tostring(group.build),
                    group.environment, group.context, tostring(itemID), setSignature,
                    tostring(#rows), coverage.complete and "complete" or "partial",
                    allComplete and "rows" or "incomplete", table.concat(incompleteShapes, ";")}, "#")
                if not entry.unresolved[claimKey] then
                    entry.unresolved[claimKey] = witness
                    changedEntries[#changedEntries + 1] = entry
                end
            end
        end
    end

    if #changedEntries == 0 then return false end
    local counters = EvidenceCounters(db.global)
    counters.mergeSerial = counters.mergeSerial + 1
    for _, entry in ipairs(changedEntries) do
        entry.changed = counters.mergeSerial
    end
    return true
end

-- Evidence-only save (aborted or superseded attempt): merges, and on change
-- invalidates the vendor indexes and source memo. It is not a scan save, so
-- the VENDOR_SCANNED callback is left to SaveVendorData.
function ScanPersistence:SaveCostEvidence(scanData, terminationReason)
    local changed = self:MergeCostEvidence(scanData, terminationReason)
    if changed then
        if HA.VendorData and HA.VendorData.InvalidateVendorCaches then
            HA.VendorData:InvalidateVendorCaches()
        end
        if HA.SourceManager and HA.SourceManager.InvalidateSourcesMemo then
            HA.SourceManager:InvalidateSourcesMemo()
        end
    end
    return changed
end

function ScanPersistence:SaveVendorData(scanData)
    -- Ensure SavedVariables structure exists
    if not HA.Addon.db or not HA.Addon.db.global then
        HA.Addon:Debug("SavedVariables not ready, cannot save vendor data")
        return
    end

    -- Cost evidence first, against the indexes as they stand; the single
    -- invalidation below covers it.
    local evidenceChanged = self:MergeCostEvidence(scanData, scanData.endReason)

    -- Initialize scanned vendors storage
    if not HA.Addon.db.global.scannedVendors then
        HA.Addon.db.global.scannedVendors = {}
    end

    local existingData = HA.Addon.db.global.scannedVendors[scanData.npcID]

    -- records written before the housing gate carry no housingCount.
    -- On those, decorCount IS the housing count — decor was the only subclass
    -- the old gate could capture. Falling back to 0 instead would make the
    -- partial-scan guard below never fire for any pre-existing record, so the
    -- first laggy rescan after updating would destroy it.
    local existingHousingCount = existingData
        and (existingData.housingCount or existingData.decorCount or 0)
        or 0

    -- a record with no subclassCounts is one of two shapes,
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
        itemCount = itemCount,          -- Slots that returned an item link
        slotCount = scanData.totalItems, -- Merchant slots the scan walked (capped at 200)
        decorCount = decorCount,        -- Housing decor items (subclass 0 only)
        hasDecor = decorCount > 0,      -- Flag to identify if vendor sells housing decor
        lastScanHadDecor = decorCount > 0, -- Last observed scan result, even if old items are preserved
        housingCount = housingCount,    -- All housing items, any subclass
        hasHousing = housingCount > 0,  -- Flag to identify if vendor sells any housing item
        -- subclassCounts is NOT set here — it's derived once from the final
        -- vendorRecord.items below (after decorID enrichment / merge logic),
        -- the same way decorCount/housingCount already are. Setting it here
        -- too would just be overwritten there, unread in between.
        -- housing-wide counterpart to lastScanHadDecor; see IsDelistCandidate.
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
            -- false when the scan could not read the whole cost; such a row
            -- never confirms or contradicts a cost set. Absent on older saves.
            costComplete = item.costComplete,
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

    -- This scan's own position. StartScan stores 0.5/0.5 when the client gave
    -- none, so either coordinate at exactly 0.5 means no position.
    local scanHasPosition = scanData.coords and scanData.coords.x and scanData.coords.y
        and scanData.coords.x ~= 0.5 and scanData.coords.y ~= 0.5

    -- Merge with existing data if present (keep more complete record)
    if existingData then
        -- Use newer coords if available
        if scanHasPosition then
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

        -- decorID is now produced by an enrichment step rather than by
        -- the capture test itself, so a cold housing catalog yields genuine
        -- decor items carrying no decorID. Previously such an item
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
    -- every slot had its link and item info by the end of the scan, re-reads
    -- included. "unknown" if any slot was still missing either at that point,
    -- or the scan ended early during its re-reads or on a slot total change.
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
        -- existing record — either in aggregate or within a
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
        -- would tell every recency consumer (UI staleness,
        -- consolidation, scan-timestamp provenance) that the unobserved rows
        -- were freshly re-verified. Record the attempt separately instead.
        existingData.lastScanAttempt = vendorRecord.lastScanned
        -- What this scan did see still counts: a housing item is on the
        -- vendor, so a stale "had nothing" mark from an earlier zero scan is
        -- wrong. Raise the marks only, never lower them.
        existingData.lastScanHadHousing = true
        if vendorRecord.hasDecor then
            existingData.lastScanHadDecor = true
        end
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
        -- Known housing vendor scanned with 0 housing items. The stored
        -- items are kept either way. Only a confirmed scan (every slot read)
        -- may say "had nothing" and re-date the record; an unconfirmed one
        -- just logs the attempt.
        if existingData then
            if scanConfidence == "confirmed" then
                existingData.lastScanned = vendorRecord.lastScanned
                existingData.lastScanHadDecor = false
                existingData.lastScanHadHousing = false
            else
                existingData.lastScanAttempt = vendorRecord.lastScanned
            end
            -- Coords and map move together, and only on this scan's own
            -- position; the other location fields take the values merged above.
            if scanHasPosition then
                existingData.coords = scanData.coords
                existingData.mapID = scanData.mapID
                existingData.realZone = vendorRecord.realZone
                existingData.parentMapID = vendorRecord.parentMapID
                existingData.mapChain = vendorRecord.mapChain
                existingData.continentMapID = vendorRecord.continentMapID
                existingData.expansion = vendorRecord.expansion
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
        -- As above, only a confirmed scan may mark the vendor empty or
        -- re-date it.
        if scanConfidence == "confirmed" then
            existingData.lastScanned = vendorRecord.lastScanned
            existingData.lastScanHadDecor = false
            existingData.lastScanHadHousing = false
        else
            existingData.lastScanAttempt = vendorRecord.lastScanned
        end
        if HA.DevAddon then
            HA.Addon:Debug(string.format(
                "Scan protection: %s (NPC %d) previously had housing items but new scan found 0. "
                .. "Preserving previous scan data.",
                scanData.vendorName or "?", scanData.npcID
            ))
        end
    else
        -- Unknown vendor, no prior good data, 0 housing items: don't persist.
        -- No direct BuildScannedIndex() call needed here -- the unconditional
        -- InvalidateVendorCaches() call a few lines down runs regardless of
        -- which branch above ran, and rebuilds this index as part of that.
        HA.Addon.db.global.scannedVendors[scanData.npcID] = nil
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
        -- a vendor with several requirement-bearing decor items was
        -- firing CATALOG_ITEM_UPDATED once per item on every ordinary vendor
        -- scan instead of once per scan. BeginBatch/EndBatch suppresses the
        -- per-item fires the same way CatalogScanner's own ProcessBatch does.
        HA.CatalogStore:BeginBatch()
        for _, item in ipairs(vendorRecord.items) do
            -- Containment: this path writes catalogItems records for
            -- Decor-subclass items only. Room-plan records come from the
            -- catalog scanner, and IsDecorItem never treats a non-Decor
            -- housing record as decor, so bag/merchant/tooltip overlays stay
            -- off for them.
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
        HA.CatalogStore:EndBatch()
    end

    -- Track vendor scan
    if HA.Analytics then
        HA.Analytics:IncrementCounter("VendorScans")
    end

    -- Invalidate cached vendor data (new scan data may affect results)
    -- Ordering is load-bearing: this rebuild must run BEFORE the VENDOR_SCANNED
    -- fire below, so any listener observes a freshly-rebuilt index, never a
    -- stale one between save and rebuild.
    --
    -- Perf cleanup: this is now the ONLY place that rebuilds the scanned-items
    -- index. VendorData used to also rebuild it on its own VENDOR_SCANNED
    -- listener, but that was always redundant with this call (it fires
    -- immediately after this one every time) and has been removed. If a
    -- future call site fires VENDOR_SCANNED without going through
    -- InvalidateVendorCaches() first, the index will NOT be rebuilt
    -- automatically -- route any new scan-save path through here (or call
    -- VendorData:BuildScannedIndex() directly) rather than assuming the event
    -- itself triggers a rebuild.
    if HA.VendorData and HA.VendorData.InvalidateVendorCaches then
        HA.VendorData:InvalidateVendorCaches()
    end

    -- a decor-bearing vendor scan discovers new sources for items
    -- (a vendor selling an item nothing else pointed to yet), which
    -- SourceManager's GetAllSources memoization would otherwise cache stale
    -- forever -- the rep/quest/achievement/holiday trigger set behind
    -- InvalidateAllSourceCaches never covers vendor-scan discovery. Uses the
    -- NARROW memo-only wipe (InvalidateSourcesMemo), not the full
    -- InvalidateAllSourceCaches -- the full version's SearchProvider wipe +
    -- SOURCE_CACHES_INVALIDATED broadcast would restart the badge prewarm
    -- pass on every vendor scan, which is exactly the over-invalidation
    -- fixed once already. Skipped entirely for a decor-less vendor
    -- (vendorRecord.hasDecor, computed above from scanData.decorItems) --
    -- nothing was discovered for the memo to be stale about.
    if vendorRecord.hasDecor and HA.SourceManager and HA.SourceManager.InvalidateSourcesMemo then
        HA.SourceManager:InvalidateSourcesMemo()
    elseif evidenceChanged and HA.SourceManager and HA.SourceManager.InvalidateSourcesMemo then
        -- Retained cost evidence changes a pair's resolved cost.
        HA.SourceManager:InvalidateSourcesMemo()
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

    -- All three
    -- clear-data entry points below route through here, so invalidating the
    -- GetAllSources memo here covers ClearScannedData/ClearNoDecorData/
    -- ClearAllData in one place. Without this, GetAllSources would keep
    -- returning sources for vendors the player just told the addon to
    -- forget -- ghost sources surviving a data clear.
    --
    -- BROAD wipe here, unlike the deliberately narrow one at the vendor-scan
    -- site above, and the difference is frequency. That site is kept narrow
    -- because the broadcasting version restarts the badge prewarm, and paying
    -- that on every first-visit merchant is over-invalidation.
    -- These three functions run only from the /hs clear* commands, where a
    -- full repaint is both affordable and what "forget my scan data" ought to
    -- mean. The narrow wipe also announced nothing, so caches downstream that
    -- key off source data -- CatalogOverlay's per-item verdicts, the search
    -- index -- kept serving the cleared vendors until something unrelated
    -- invalidated them. InvalidateAllSourceCaches composes the narrow wipe,
    -- so nothing the narrow wipe provided is lost.
    if HA.SourceManager and HA.SourceManager.InvalidateAllSourceCaches then
        HA.SourceManager:InvalidateAllSourceCaches()
    end
end

function ScanPersistence:ClearScannedData()
    if not HA.Addon.db or not HA.Addon.db.global then return end

    local count = 0
    if HA.Addon.db.global.scannedVendors then
        for _ in pairs(HA.Addon.db.global.scannedVendors) do count = count + 1 end
    end

    HA.Addon.db.global.scannedVendors = {}
    -- noDecorVendors intentionally preserved. Local cost evidence goes with
    -- the scans, orphan entries included; its allocators do not rewind.
    HA.Addon.db.global.vendorCostEvidence = nil
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
    HA.Addon.db.global.vendorCostEvidence = nil
    HA.Addon.db.global.lastExportTimestamp = nil

    RefreshMapPins()

    HA.Addon:Print("Cleared ALL vendor data including no-decor flags.")
end
