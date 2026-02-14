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
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("Validation", Validation)
end
