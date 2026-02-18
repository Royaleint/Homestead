--[[
    Homestead - Validation Module
    Validates database integrity and catches data problems early
    
    Usage: /hs validate
]]

local addonName, HA = ...

local Validation = {}
HA.Validation = Validation

-------------------------------------------------------------------------------
-- Validation Rules
-------------------------------------------------------------------------------

-- Validate coordinates (handles both old coords.x/y and new x/y formats)
local function ValidateCoordinates(x, y, context)
    local errors = {}

    if x == nil and y == nil then
        return errors  -- Coords are optional
    end

    if x == nil or y == nil then
        table.insert(errors, context .. ": coords missing x or y")
        return errors
    end

    -- Check for 0-100 format (should be 0-1)
    if x > 1 or y > 1 then
        table.insert(errors, string.format(
            "%s: coords appear to be 0-100 format (%.2f, %.2f) - should be 0-1",
            context, x, y
        ))
    end

    -- Check for negative or invalid
    if x < 0 or y < 0 then
        table.insert(errors, string.format(
            "%s: coords are negative (%.4f, %.4f)",
            context, x, y
        ))
    end

    -- Check for zero coords (often indicates missing data)
    if x == 0 and y == 0 then
        table.insert(errors, context .. ": coords are 0,0 (likely missing data)")
    end

    return errors
end

local function ValidateVendor(vendor, source)
    local errors = {}
    local warnings = {}
    local context = string.format("%s vendor %s", source, vendor.npcID or "unknown")
    
    -- Required fields
    if not vendor.npcID then
        table.insert(errors, context .. ": missing npcID")
    elseif type(vendor.npcID) ~= "number" then
        table.insert(errors, context .. ": npcID is not a number")
    end
    
    if not vendor.name or vendor.name == "" then
        table.insert(errors, context .. ": missing name")
    end
    
    if not vendor.mapID then
        table.insert(warnings, context .. ": missing mapID (won't show on map)")
    elseif type(vendor.mapID) ~= "number" then
        table.insert(errors, context .. ": mapID is not a number")
    end
    
    -- Coordinate validation (handles both old coords.x/y and new x/y formats)
    local vendorX = vendor.x or (vendor.coords and vendor.coords.x)
    local vendorY = vendor.y or (vendor.coords and vendor.coords.y)
    local coordErrors = ValidateCoordinates(vendorX, vendorY, context)
    for _, err in ipairs(coordErrors) do
        table.insert(errors, err)
    end
    
    -- Faction validation
    if vendor.faction then
        local validFactions = {Alliance = true, Horde = true, Neutral = true}
        if not validFactions[vendor.faction] then
            table.insert(warnings, string.format(
                "%s: invalid faction '%s' (should be Alliance/Horde/Neutral)",
                context, vendor.faction
            ))
        end
    end
    
    -- Items validation (handles multiple formats):
    -- 1. Plain number: 245603
    -- 2. Table with cost: {245603, cost = {...}}
    -- 3. Legacy format: {itemID = 245603, name = "..."}
    if vendor.items then
        for i, item in ipairs(vendor.items) do
            if type(item) == "number" then
                -- Plain itemID number
                if item <= 0 then
                    table.insert(warnings, string.format(
                        "%s: item #%d has invalid itemID %d", context, i, item
                    ))
                end
            elseif type(item) == "table" then
                -- New format with cost: {itemID, cost = {...}} where itemID is at [1]
                -- Or legacy format: {itemID = 123, name = "..."}
                local itemID = item[1] or item.itemID
                if not itemID then
                    table.insert(warnings, string.format(
                        "%s: item #%d missing itemID", context, i
                    ))
                elseif type(itemID) ~= "number" or itemID <= 0 then
                    table.insert(warnings, string.format(
                        "%s: item #%d has invalid itemID %s", context, i, tostring(itemID)
                    ))
                end
            end
        end
    end

    return errors, warnings
end

-------------------------------------------------------------------------------
-- Validation Functions
-------------------------------------------------------------------------------

function Validation:ValidateVendorDatabase()
    local errors = {}
    local warnings = {}
    local vendorCount = 0
    
    if not HA.VendorDatabase or not HA.VendorDatabase.Vendors then
        table.insert(errors, "VendorDatabase not loaded or empty")
        return errors, warnings, 0
    end

    local seenNPCIDs = {}

    for npcID, vendor in pairs(HA.VendorDatabase.Vendors) do
        vendorCount = vendorCount + 1

        -- Ensure vendor has npcID set (from key)
        if not vendor.npcID then
            vendor.npcID = npcID
        end

        -- Check for duplicates
        if vendor.npcID then
            if seenNPCIDs[vendor.npcID] then
                table.insert(errors, string.format(
                    "Duplicate npcID %d (%s and %s)",
                    vendor.npcID, seenNPCIDs[vendor.npcID], vendor.name or "unknown"
                ))
            else
                seenNPCIDs[vendor.npcID] = vendor.name or "unknown"
            end
        end
        
        local vErrors, vWarnings = ValidateVendor(vendor, "Static")
        for _, e in ipairs(vErrors) do table.insert(errors, e) end
        for _, w in ipairs(vWarnings) do table.insert(warnings, w) end
    end
    
    return errors, warnings, vendorCount
end

function Validation:ValidateScannedVendors()
    local errors = {}
    local warnings = {}
    local vendorCount = 0
    
    if not HA.Addon or not HA.Addon.db or not HA.Addon.db.global.scannedVendors then
        return errors, warnings, 0
    end
    
    for npcID, vendor in pairs(HA.Addon.db.global.scannedVendors) do
        vendorCount = vendorCount + 1
        
        -- Ensure npcID matches key
        if vendor.npcID and vendor.npcID ~= npcID then
            table.insert(warnings, string.format(
                "Scanned vendor key/npcID mismatch: key=%d, npcID=%d",
                npcID, vendor.npcID
            ))
        end
        
        local vErrors, vWarnings = ValidateVendor(vendor, "Scanned")
        for _, e in ipairs(vErrors) do table.insert(errors, e) end
        for _, w in ipairs(vWarnings) do table.insert(warnings, w) end
    end
    
    return errors, warnings, vendorCount
end

function Validation:ValidateOwnershipCache()
    local errors = {}
    local warnings = {}
    local itemCount = 0

    -- Prefer catalogItems if CatalogStore is available
    if HA.CatalogStore and HA.Addon and HA.Addon.db and HA.Addon.db.global.catalogItems then
        for itemID, record in pairs(HA.Addon.db.global.catalogItems) do
            if record.isOwned then
                itemCount = itemCount + 1

                if type(itemID) ~= "number" then
                    table.insert(errors, string.format(
                        "catalogItems: key '%s' is not a number", tostring(itemID)
                    ))
                end

                if not record.name then
                    table.insert(warnings, string.format(
                        "catalogItems[%s]: missing name", tostring(itemID)
                    ))
                end

                if not record.firstSeen then
                    table.insert(warnings, string.format(
                        "catalogItems[%s]: missing firstSeen timestamp", tostring(itemID)
                    ))
                end
            end
        end

        return errors, warnings, itemCount
    end

    -- Fallback to legacy ownedDecor
    if not HA.Addon or not HA.Addon.db or not HA.Addon.db.global.ownedDecor then
        return errors, warnings, 0
    end

    for itemID, data in pairs(HA.Addon.db.global.ownedDecor) do
        itemCount = itemCount + 1

        if type(itemID) ~= "number" then
            table.insert(errors, string.format(
                "ownedDecor: key '%s' is not a number", tostring(itemID)
            ))
        end

        if not data.name then
            table.insert(warnings, string.format(
                "ownedDecor[%s]: missing name", tostring(itemID)
            ))
        end

        if not data.firstSeen then
            table.insert(warnings, string.format(
                "ownedDecor[%s]: missing firstSeen timestamp", tostring(itemID)
            ))
        end
    end

    return errors, warnings, itemCount
end

function Validation:ValidateZoneToContinentMapping()
    local errors = {}
    local warnings = {}

    local canonicalMap = HA.Constants and HA.Constants.ZoneToContinentMap
    local vendorDBMap = HA.VendorDatabase and HA.VendorDatabase.ZoneToContinentMap
    local zoneToContinent = canonicalMap or vendorDBMap

    if not zoneToContinent then
        table.insert(warnings, "ZoneToContinentMap mapping not found")
        return errors, warnings
    end

    if canonicalMap and vendorDBMap and canonicalMap ~= vendorDBMap then
        table.insert(warnings, "VendorDatabase.ZoneToContinentMap is not aliased to canonical constants map")
    end

    -- Check that all vendor mapIDs have continent mappings
    if HA.VendorDatabase and HA.VendorDatabase.Vendors then
        local missingMaps = {}
        for npcID, vendor in pairs(HA.VendorDatabase.Vendors) do
            if vendor.mapID and not zoneToContinent[vendor.mapID] then
                missingMaps[vendor.mapID] = (missingMaps[vendor.mapID] or 0) + 1
            end
        end
        
        for mapID, count in pairs(missingMaps) do
            table.insert(warnings, string.format(
                "mapID %d used by %d vendors but missing from zoneToContinent",
                mapID, count
            ))
        end
    end

    -- Check that every continent referenced in the zone map has a name
    local continentNames = HA.Constants and HA.Constants.ContinentNames or {}
    local seenContinents = {}
    for _, continentID in pairs(zoneToContinent) do
        if not seenContinents[continentID] then
            seenContinents[continentID] = true
            if not continentNames[continentID] then
                table.insert(warnings, string.format(
                    "continent %d referenced in ZoneToContinentMap but missing from ContinentNames",
                    continentID
                ))
            end
        end
    end

    return errors, warnings
end

-------------------------------------------------------------------------------
-- Main Validation Command
-------------------------------------------------------------------------------

function Validation:RunFullValidation()
    local output = {}
    table.insert(output, "=== Homestead Data Validation ===\n")

    local totalErrors = 0
    local totalWarnings = 0

    -- Validate static vendor database
    table.insert(output, "Checking VendorDatabase...")
    local dbErrors, dbWarnings, dbCount = self:ValidateVendorDatabase()
    totalErrors = totalErrors + #dbErrors
    totalWarnings = totalWarnings + #dbWarnings
    table.insert(output, string.format("  %d vendors, %d errors, %d warnings\n",
        dbCount, #dbErrors, #dbWarnings))

    -- Validate scanned vendors
    table.insert(output, "Checking scannedVendors...")
    local scErrors, scWarnings, scCount = self:ValidateScannedVendors()
    totalErrors = totalErrors + #scErrors
    totalWarnings = totalWarnings + #scWarnings
    table.insert(output, string.format("  %d vendors, %d errors, %d warnings\n",
        scCount, #scErrors, #scWarnings))

    -- Validate ownership cache
    table.insert(output, "Checking ownership cache...")
    local owErrors, owWarnings, owCount = self:ValidateOwnershipCache()
    totalErrors = totalErrors + #owErrors
    totalWarnings = totalWarnings + #owWarnings
    table.insert(output, string.format("  %d items, %d errors, %d warnings\n",
        owCount, #owErrors, #owWarnings))

    -- Validate zone mappings
    table.insert(output, "Checking zoneToContinent mappings...")
    local zmErrors, zmWarnings = self:ValidateZoneToContinentMapping()
    totalErrors = totalErrors + #zmErrors
    totalWarnings = totalWarnings + #zmWarnings
    table.insert(output, string.format("  %d errors, %d warnings\n",
        #zmErrors, #zmWarnings))

    -- Summary
    table.insert(output, "---\n")
    if totalErrors == 0 and totalWarnings == 0 then
        table.insert(output, "Validation passed! No issues found.\n")
    else
        if totalErrors > 0 then
            table.insert(output, string.format("%d errors found\n", totalErrors))
        end
        if totalWarnings > 0 then
            table.insert(output, string.format("%d warnings found\n", totalWarnings))
        end
    end

    -- Store results for details command
    self.lastResults = {
        errors = {},
        warnings = {},
    }
    for _, e in ipairs(dbErrors) do table.insert(self.lastResults.errors, e) end
    for _, e in ipairs(scErrors) do table.insert(self.lastResults.errors, e) end
    for _, e in ipairs(owErrors) do table.insert(self.lastResults.errors, e) end
    for _, e in ipairs(zmErrors) do table.insert(self.lastResults.errors, e) end
    for _, w in ipairs(dbWarnings) do table.insert(self.lastResults.warnings, w) end
    for _, w in ipairs(scWarnings) do table.insert(self.lastResults.warnings, w) end
    for _, w in ipairs(owWarnings) do table.insert(self.lastResults.warnings, w) end
    for _, w in ipairs(zmWarnings) do table.insert(self.lastResults.warnings, w) end

    -- Add details if there are issues
    if totalErrors > 0 or totalWarnings > 0 then
        table.insert(output, "\n=== Details ===\n")

        if #self.lastResults.errors > 0 then
            table.insert(output, "\nERRORS:\n")
            for _, err in ipairs(self.lastResults.errors) do
                table.insert(output, "  " .. err .. "\n")
            end
        end

        if #self.lastResults.warnings > 0 then
            table.insert(output, "\nWARNINGS:\n")
            for _, warn in ipairs(self.lastResults.warnings) do
                table.insert(output, "  " .. warn .. "\n")
            end
        end
    end

    -- Show output window
    if HA.OutputWindow then
        HA.OutputWindow:Show("Validation Results", table.concat(output))
    else
        -- Fallback to chat
        for _, line in ipairs(output) do
            HA.Addon:Print(line)
        end
    end
end

function Validation:ShowDetails()
    if not self.lastResults then
        HA.Addon:Print("Run /hs validate first.")
        return
    end

    local output = {}
    table.insert(output, "=== Validation Details ===\n\n")

    if #self.lastResults.errors > 0 then
        table.insert(output, "ERRORS:\n")
        for _, err in ipairs(self.lastResults.errors) do
            table.insert(output, "  " .. err .. "\n")
        end
        table.insert(output, "\n")
    end

    if #self.lastResults.warnings > 0 then
        table.insert(output, "WARNINGS:\n")
        for _, warn in ipairs(self.lastResults.warnings) do
            table.insert(output, "  " .. warn .. "\n")
        end
    end

    if #self.lastResults.errors == 0 and #self.lastResults.warnings == 0 then
        table.insert(output, "No issues found.\n")
    end

    -- Show output window
    if HA.OutputWindow then
        HA.OutputWindow:Show("Validation Details", table.concat(output))
    else
        -- Fallback to chat
        for _, line in ipairs(output) do
            HA.Addon:Print(line)
        end
    end
end

-------------------------------------------------------------------------------
-- DecorID Validation — batch-resolve all known itemIDs to decorIDs via
-- catalog API. Tracks ALL sources per item. Only actionable findings
-- (not-decor, zero-decorID, errors) persisted in db.global.decorIDValidation.
-------------------------------------------------------------------------------

-- Collect all unique itemIDs and accumulate ALL sources each appears in.
-- Returns: byItemID = { [itemID] = { sources = {"vendor","quest",...} } }
--          ordered  = { itemID1, itemID2, ... } (sorted for deterministic output)
local function CollectAllSourceItemIDs()
    local byItemID = {}

    local function Add(id, source)
        if not id or type(id) ~= "number" or id <= 0 then return end
        if not byItemID[id] then
            byItemID[id] = { sources = {} }
        end
        -- Avoid duplicate source tags for the same item
        local entry = byItemID[id]
        for _, s in ipairs(entry.sources) do
            if s == source then return end
        end
        table.insert(entry.sources, source)
    end

    -- VendorDatabase (static)
    if HA.VendorData and HA.VendorData.GetAllVendors then
        for _, vendor in ipairs(HA.VendorData:GetAllVendors()) do
            if vendor.items then
                for _, item in ipairs(vendor.items) do
                    local itemID = HA.VendorData:GetItemID(item)
                    Add(itemID, "vendor")
                end
            end
        end
    end

    -- Scanned vendors (SavedVariables)
    if HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
        for _, vendorData in pairs(HA.Addon.db.global.scannedVendors) do
            if vendorData.items then
                for _, item in ipairs(vendorData.items) do
                    Add(item.itemID, "scanned")
                end
            end
        end
    end

    -- Static source files
    if HA.DropSources then
        for itemID in pairs(HA.DropSources) do Add(itemID, "drop") end
    end
    if HA.QuestSources then
        for itemID in pairs(HA.QuestSources) do Add(itemID, "quest") end
    end
    if HA.AchievementSources then
        for itemID in pairs(HA.AchievementSources) do Add(itemID, "achievement") end
    end
    if HA.ProfessionSources then
        for itemID in pairs(HA.ProfessionSources) do Add(itemID, "profession") end
    end

    -- Build sorted list of unique itemIDs
    local ordered = {}
    for itemID in pairs(byItemID) do
        table.insert(ordered, itemID)
    end
    table.sort(ordered)

    return byItemID, ordered
end

-- Batch-resolve itemIDs to decorIDs via GetCatalogEntryInfoByItem.
-- Shows report in OutputWindow; persists actionable findings to SavedVariables.
function Validation:ExportDecorIDs()
    if not C_HousingCatalog or not C_HousingCatalog.GetCatalogEntryInfoByItem then
        HA.Addon:Print("C_HousingCatalog API not available.")
        return
    end

    local byItemID, ordered = CollectAllSourceItemIDs()
    local totalItems = #ordered

    if totalItems == 0 then
        HA.Addon:Print("No items found to scan.")
        return
    end

    HA.Addon:Print(string.format("Scanning %d unique items for decorIDs...", totalItems))

    local BATCH_SIZE = 20
    local BATCH_DELAY = 0.01
    local currentIndex = 1

    -- Result buckets
    local confirmed = {}  -- { {itemID, decorID, name, sources} }
    local notDecor = {}   -- { {itemID, sources} }
    local apiErrors = {}  -- { {itemID, sources} }

    local function ProcessBatch()
        local batchEnd = math.min(currentIndex + BATCH_SIZE - 1, totalItems)

        for i = currentIndex, batchEnd do
            local itemID = ordered[i]
            local entry = byItemID[itemID]
            local itemLink = "item:" .. tostring(itemID)

            local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, itemLink, true)

            if ok and info then
                local decorID = 0
                if info.entryID and type(info.entryID) == "table" then
                    decorID = info.entryID.recordID or 0
                end
                table.insert(confirmed, {
                    itemID = itemID,
                    decorID = decorID,
                    name = info.name or "",
                    sources = entry.sources,
                })
            elseif ok and not info then
                table.insert(notDecor, {itemID = itemID, sources = entry.sources})
            else
                table.insert(apiErrors, {itemID = itemID, sources = entry.sources})
            end
        end

        currentIndex = batchEnd + 1

        if currentIndex <= totalItems then
            C_Timer.After(BATCH_DELAY, ProcessBatch)
        else
            self:PersistDecorIDs(confirmed, notDecor, apiErrors)
            self:ShowDecorIDResults(confirmed, notDecor, apiErrors, totalItems)
        end
    end

    ProcessBatch()
end

-- Persist only actionable findings to db.global.decorIDValidation
-- Keeps SavedVariables lightweight — only stores not-decor items and zero-decorID
-- warnings, not the full confirmed mapping (which can be re-resolved any time).
function Validation:PersistDecorIDs(confirmed, notDecor, apiErrors)
    if not HA.Addon or not HA.Addon.db then return end

    local now = time()
    local result = {
        scannedAt = now,
        totalConfirmed = #confirmed,
        notDecor = {},
        zeroDecorID = {},
        apiErrors = {},
    }

    for _, entry in ipairs(notDecor) do
        result.notDecor[entry.itemID] = entry.sources
    end

    for _, entry in ipairs(confirmed) do
        if entry.decorID == 0 then
            result.zeroDecorID[entry.itemID] = { name = entry.name, sources = entry.sources }
        end
    end

    for _, entry in ipairs(apiErrors) do
        result.apiErrors[entry.itemID] = entry.sources
    end

    HA.Addon.db.global.decorIDValidation = result
end

-- Format and display the validation report
function Validation:ShowDecorIDResults(confirmed, notDecor, apiErrors, totalItems)
    local lines = {}
    local function L(s) table.insert(lines, s .. "\n") end

    L("=== DecorID Validation Report ===")
    L(string.format("Total unique items scanned: %d", totalItems))
    L(string.format("Confirmed decor: %d", #confirmed))
    L(string.format("NOT decor (API returned nil): %d", #notDecor))
    if #apiErrors > 0 then
        L(string.format("API errors: %d", #apiErrors))
    end
    L(string.format("Findings saved to: db.global.decorIDValidation"))
    L("")

    -- Summary by source
    local sourceCounts = {}
    for _, entry in ipairs(confirmed) do
        for _, src in ipairs(entry.sources) do
            sourceCounts[src] = (sourceCounts[src] or 0) + 1
        end
    end
    L("-- Confirmed decor by source:")
    for _, src in ipairs({"vendor", "scanned", "drop", "quest", "achievement", "profession"}) do
        if sourceCounts[src] then
            L(string.format("--   %-12s %d items", src, sourceCounts[src]))
        end
    end
    L("")

    -- Multi-source items (items appearing in 2+ source files)
    local multiSource = {}
    for _, entry in ipairs(confirmed) do
        if #entry.sources > 1 then
            table.insert(multiSource, entry)
        end
    end
    if #multiSource > 0 then
        L(string.format("-- Multi-source items (%d):", #multiSource))
        for _, entry in ipairs(multiSource) do
            L(string.format("--   %d (%s) — %s",
                entry.itemID, entry.name, table.concat(entry.sources, ", ")))
        end
        L("")
    end

    -- Zero-decorID items (info returned but no recordID)
    local zeroDecor = {}
    for _, entry in ipairs(confirmed) do
        if entry.decorID == 0 then
            table.insert(zeroDecor, entry)
        end
    end
    if #zeroDecor > 0 then
        L(string.format("-- WARNING: %d items returned catalog info but decorID=0:", #zeroDecor))
        for _, entry in ipairs(zeroDecor) do
            L(string.format("--   %d (%s) — sources: %s",
                entry.itemID, entry.name, table.concat(entry.sources, ", ")))
        end
        L("")
    end

    -- NOT DECOR — actionable: these should be removed from source files
    if #notDecor > 0 then
        L("-- ACTION REQUIRED: NOT DECOR ITEMS (remove from source files):")
        for _, entry in ipairs(notDecor) do
            L(string.format("--   itemID %d — sources: %s",
                entry.itemID, table.concat(entry.sources, ", ")))
        end
        L("")
    end

    -- API errors
    if #apiErrors > 0 then
        L("-- API ERRORS (may need retry or manual check):")
        for _, entry in ipairs(apiErrors) do
            L(string.format("--   itemID %d — sources: %s",
                entry.itemID, table.concat(entry.sources, ", ")))
        end
    end

    local text = table.concat(lines)

    if HA.OutputWindow then
        HA.OutputWindow:Show("DecorID Validation", text)
    else
        HA.Addon:Print(text)
    end

    HA.Addon:Print(string.format(
        "DecorID validation complete: %d confirmed, %d not-decor, %d errors.",
        #confirmed, #notDecor, #apiErrors
    ))
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("Validation", Validation)
end
