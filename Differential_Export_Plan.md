# Differential Export Plan

## Goal
Modify ExportImport:ExportScannedVendors() to only export vendors that are:
1. NOT in VendorDatabase (new discoveries)
2. IN VendorDatabase but scanned items include items not in VendorDatabase.Vendors[npcID].items

## Files
- Modules/ExportImport.lua

## Changes

### 1. Add helper function after line 15 (after EXPORT_PREFIX)

local function GetNewItems(scannedDecor, existingItems)
    if not scannedDecor or #scannedDecor == 0 then
        return {}
    end
    
    -- Build lookup of existing items
    local existingLookup = {}
    if existingItems then
        for _, itemID in ipairs(existingItems) do
            existingLookup[itemID] = true
        end
    end
    
    -- Find items in scanned that aren't in existing
    local newItems = {}
    for _, item in ipairs(scannedDecor) do
        if item.itemID and not existingLookup[item.itemID] then
            table.insert(newItems, item.itemID)
        end
    end
    
    return newItems
end

### 2. Modify ExportScannedVendors function signature (around line 107)

Change:
    function ExportImport:ExportScannedVendors()

To:
    function ExportImport:ExportScannedVendors(fullExport)

### 3. Replace the export loop logic (inside ExportScannedVendors, the for loop)

Replace the existing for loop with differential logic:
- Check VendorDatabase:GetVendor(npcID) for each scanned vendor
- If no match: new vendor, export all items
- If match: compare items, export only if new items found
- Track: newVendors, updatedVendors, skippedVendors counts

### 4. Update the /hs export command in core.lua

Find where "export" command is handled and change to pass parameter:
    elseif input == "export" then
        if HA.ExportImport then
            HA.ExportImport:ExportScannedVendors(false)  -- differential
        end
    elseif input == "export full" then
        if HA.ExportImport then
            HA.ExportImport:ExportScannedVendors(true)   -- full export
        end

### 5. Update PrintHelp in core.lua

    self:Print("  /hs export - Export NEW vendor data (differential)")
    self:Print("  /hs export full - Export ALL scanned vendor data")