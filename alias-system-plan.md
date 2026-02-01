# NPC ID Alias System Implementation Plan

## Problem
Same vendor (e.g., Pascal-K1N6) exists with multiple NPC IDs across zones:
- 248525 (Housing vendor - canonical)
- 150359 (BFA Mechagon)
- 150497 (Midnight Mechagon)

Current system uses NPC ID as primary key, causing vendor mismatch when players encounter alternate IDs.

## Solution
Add alias resolution layer that maps alternate IDs → canonical ID before lookup.

## Files to Modify
1. Data/VendorDatabase.lua
2. Core/core.lua

## Phase 1: Backup
- Create Data/Backups/ directory
- Copy VendorDatabase.lua → VendorDatabase_backup_20260201.lua
- Add header comment explaining backup reason

## Phase 2: VendorDatabase.lua Changes

### 2A: Add Alias Tables (after line 15)
```lua
VendorDatabase.Aliases = {
    [150359] = 248525,  -- Pascal-K1N6 (BFA Mechagon)
    [150497] = 248525,  -- Pascal-K1N6 (Midnight Mechagon)
}
VendorDatabase.AliasLookup = {}  -- Runtime index
```

### 2B: Add New Functions (append to end of file)
- `ResolveNpcID(npcID)` - returns canonical ID or original
- `BuildAliasIndex()` - builds runtime lookup from static + SavedVariables
- `DiscoverAlias(npcID, npcName)` - auto-discovers aliases, stores in SavedVariables
- `GetAliasCount()` - returns static count, discovered count

### 2C: Update GetVendor() (~line 2738)
Add alias resolution before lookup:
```lua
function VendorDatabase:GetVendor(npcID)
    local canonicalID = self:ResolveNpcID(npcID)
    local vendor = self.Vendors[canonicalID]
    if vendor then
        vendor.npcID = canonicalID
        if canonicalID ~= npcID then
            vendor.queriedNpcID = npcID
        end
    end
    return vendor
end
```

### 2D: Update HasVendor() (~line 2747)
Add alias resolution before check.

### 2E: Update BuildIndexes() (~line 2730)
Add call to `self:BuildAliasIndex()` before debug output.

## Phase 3: core.lua Changes

### 3A: Add Slash Commands (in SlashCommandHandler elseif chain)
- `/hs aliases` → calls ShowAliases()
- `/hs clearaliases` → wipes HomesteadDB.global.discoveredAliases

### 3B: Add ShowAliases() Function
Displays static count, discovered count, and details of pending discoveries.

### 3C: Update PrintHelp()
Add help text for new commands.

## Phase 4: Verification
- /reload
- /hs aliases (should show 2 static aliases)
- /hs validate (should pass)
```

---

## STARTER PROMPT (use this to begin)
```
Read the alias-system-plan.md file for context on what we're building.

Start with Phase 1: Create the backup.

1. Create directory Data/Backups/ if it doesn't exist
2. Copy Data/VendorDatabase.lua to Data/Backups/VendorDatabase_backup_20260201.lua
3. Add this comment at the top of the backup file:
   -- BACKUP: Created 2026-02-01 before NPC ID alias system implementation
   -- Reason: Implementing alias system for multi-ID vendors (e.g., Pascal-K1N6)

Confirm when done, then we'll move to Phase 2.
```

---

After Phase 1 completes, your next prompt would be:
```
Phase 2A: Add the Alias tables to Data/VendorDatabase.lua

Insert after line 15 (after `HA.VendorDatabase = VendorDatabase`), before the Vendors section. Include the section header comment, the Aliases table with Pascal-K1N6 entries, and the empty AliasLookup table.