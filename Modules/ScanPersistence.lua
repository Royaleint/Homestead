--[[
    Homestead - ScanPersistence
    Vendor scan data storage, retrieval, clearing, and export

    Extracted from VendorScanner.lua to reduce file size.
    Manages all SavedVariables reads/writes for scanned vendor data.

    Reusable by VendorScanner, ExportImport, Options, etc.
]]

local addonName, HA = ...

local ScanPersistence = {}
HA.ScanPersistence = ScanPersistence

-------------------------------------------------------------------------------
-- Data Storage
-------------------------------------------------------------------------------

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

    -- Build vendor record with enhanced data
    local decorCount = scanData.decorItems and #scanData.decorItems or 0
    local itemCount = scanData.allItems and #scanData.allItems or scanData.totalItems or 0

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
        lastScanned = time(),
        itemCount = itemCount,      -- Total items at vendor
        decorCount = decorCount,    -- Housing decor items
        hasDecor = decorCount > 0,  -- Flag to identify if vendor sells housing decor
        items = {},                 -- Enhanced item data
    }

    -- Add decor items with full enhanced data
    for _, item in ipairs(scanData.decorItems or {}) do
        local itemRecord = {
            itemID = item.itemID,
            name = item.name,
            price = item.price,
            stackCount = item.stackCount,
            isPurchasable = item.isPurchasable,
            isUsable = item.isUsable,
            spellID = item.spellID,
            requirements = item.requirements,
            isDecor = true,
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
        if scanData.coords.x ~= 0.5 and scanData.coords.y ~= 0.5 then
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
        vendorRecord.expansion = vendorRecord.expansion or existingData.expansion
        vendorRecord.currency = vendorRecord.currency or existingData.currency

        -- DON'T merge item lists - use the current scan as authoritative
        -- The current scan is the source of truth for what the vendor sells NOW
    end

    -- Recalculate counts based on final data
    vendorRecord.decorCount = #vendorRecord.items
    vendorRecord.hasDecor = vendorRecord.decorCount > 0

    -- Save the record
    HA.Addon.db.global.scannedVendors[scanData.npcID] = vendorRecord

    HA.Addon:Debug("Saved vendor data for " .. scanData.vendorName ..
        " - " .. vendorRecord.decorCount .. "/" .. vendorRecord.itemCount ..
        " decor items, faction: " .. vendorRecord.faction)

    -- Maintain persistent no-decor tracking (survives ClearScannedData)
    if not HA.Addon.db.global.noDecorVendors then
        HA.Addon.db.global.noDecorVendors = {}
    end

    -- Determine scan confidence: "confirmed" only if scan completed AND all item
    -- slots returned valid data. "unknown" if scan completed but any
    -- C_MerchantFrame.GetItemInfo() call returned nil during ProcessScanQueue().
    local scanConfidence = "unknown"
    if scanData.scanComplete and not scanData.hadNilSlots then
        scanConfidence = "confirmed"
    end

    if vendorRecord.hasDecor == false and scanConfidence == "confirmed" then
        -- Only flag when scan is fully confirmed (no interruption, no nil slots)
        local existing = HA.Addon.db.global.noDecorVendors[scanData.npcID]
        local confirmCount = (existing and existing.confirmCount or 0) + 1
        local inStaticDB = HA.VendorDatabase and HA.VendorDatabase:HasVendor(scanData.npcID)
        HA.Addon.db.global.noDecorVendors[scanData.npcID] = {
            name = vendorRecord.name,
            confirmedAt = time(),
            itemCount = vendorRecord.itemCount,
            inDatabase = inStaticDB,       -- snapshot; /hs nodecor uses live check
            scanConfidence = "confirmed",  -- tri-state: "confirmed" or "unknown"
            confirmCount = confirmCount,   -- must reach 2 before inDatabase is actionable
        }
        if inStaticDB and confirmCount >= 2 then
            HA.Addon:Debug(string.format(
                "No-Decor: %s (NPC %d) has %d items but 0 decor. Flagged for removal (confirmed %dx).",
                vendorRecord.name, scanData.npcID, vendorRecord.itemCount, confirmCount
            ))
        elseif inStaticDB then
            HA.Addon:Debug(string.format(
                "No-Decor: %s (NPC %d) has %d items but 0 decor. Needs 1 more scan to flag for removal.",
                vendorRecord.name, scanData.npcID, vendorRecord.itemCount
            ))
        end
    elseif vendorRecord.hasDecor == true then
        -- Re-scan found decor: unhide vendor
        HA.Addon.db.global.noDecorVendors[scanData.npcID] = nil
    end

    -- Track vendor scan
    if HA.Analytics then
        HA.Analytics:IncrementCounter("VendorScans")
    end

    -- Invalidate cached vendor list (new scan data may affect results)
    if HA.VendorDatabase and HA.VendorDatabase.InvalidateVendorCache then
        HA.VendorDatabase:InvalidateVendorCache()
    end

    -- Fire callback for other modules
    if HA.Events then
        HA.Events:Fire("VENDOR_SCANNED", vendorRecord)
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
