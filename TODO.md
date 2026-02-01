# Homestead TODO

## Critical (blocks release)
- [x] Resolve duplicate NPC 78564 (Grimjaw/Crowler) - FIXED 2026-01-31
- [ ] Verify 3 name mismatches in-game: [64001], [64032], [127151]

## High Priority
- [ ] Fix 15 vendors with placeholder coordinates via in-game scanning
- [ ] Review 32 MapID mismatches (see VENDOR_VERIFICATION_SUMMARY.md)
- [ ] Scan items for remaining vendors (44 of 54 still need items)

## Normal
- [ ] Housing Catalog tooltip integration
- [ ] Bag overlays (Phase 9)
- [ ] Completionist dashboard

## Deferred (post-release)
- [ ] External API verification
- [ ] Crowdsourced data submission

## Completed
- [x] VendorDatabase migration to NPC-keyed structure (2026-01-31)
- [x] Fix empty vendor filtering
- [x] Fix scanned coords override
- [x] Fix subzone mapID handling
- [x] Options menu consolidation
- [x] AchievementDecor data populated (97 achievements)
- [x] Compare against HomeBound/DecorVendor addons (2026-01-31)
- [x] Add 54 missing vendors from HomeBound/DecorVendor with coordinate conversion (2026-01-31)
- [x] Fix Lisbeth Schneider NPC ID (1299 → 1257) - Already corrected
- [x] Remove vendors with hasDecor: false from static database (2026-01-31)
  - Removed [1257] Lisbeth Schneider, [1286] Edna Mullby
- [x] Create reusable OutputWindow for /hs validate and /hs corrections (2026-01-31)
  - Scrollable, resizable, copyable text output
  - Replaces chat spam with clean popup window
- [x] Fix deprecated WoW API SetMinResize/SetMaxResize → SetResizeBounds (2026-01-31)
- [x] Fix Validation.lua case mismatches (.vendors → .Vendors, .zoneToContinent → .ZoneToContinentMap)
- [x] Fix Validation.lua iteration (ipairs → pairs for NPC-keyed hash table)
- [x] Add missing vendor name [145695] "Bad Luck" Symmes (2026-01-31)
- [x] Fix NPC 78564: Sergeant Grimjaw → Sergeant Crowler, Horde → Alliance, mapID 525 → 539 (2026-01-31)
- [x] Add global reference _G.Homestead for /dump debugging (2026-01-31)
- [x] Fix /hs export blank window - pipe delimiter, OutputWindow integration, table.concat pattern (2026-01-31)
- [x] Merge scanned items into VendorDatabase for 10 vendors (2026-01-31)
- [x] Update Homestead.toc with release metadata (Author: Nubs, Version: 0.1.0-alpha) (2026-01-31)

## Session Summary (2026-01-31) - Morning

### Completed
- ✓ Scanned installed WoW addons (HomeBound, DecorVendor)
- ✓ Created vendor comparison tool (`scripts/compare_addon_vendors.py`)
- ✓ Generated comprehensive comparison report
- ✓ Added 54 missing vendors to VendorDatabase.lua (240 total, up from 186)
- ✓ Converted coordinates from 0-100 to 0-1 format (HereBeDragons compatible)
- ✓ Added expansion tags to all new vendors
- ✓ Fixed vendor names with escaped quotes (High Tides Ren, Len Splinthoof, Yen Malone)

### Discovered
- HomeBound and DecorVendor use 0-100 coordinate format (different library)
- Our 0-1 normalized format is CORRECT for HereBeDragons (do not change)
- 5 name mismatches need in-game verification
- 32 mapID mismatches need testing (likely instance/phasing differences)
- 2 vendors couldn't be added (not in HomeBound data): [142115] Fiona, [253602] Frederick
- AllTheThings doesn't track housing vendors (tracks collectibles only)

### Next Steps
1. Test new vendors in-game (verify map pins display correctly)
2. Visit vendors and use `/hs scan` to populate items arrays
3. Priority: Scan Siren Isle event vendors before they rotate out
4. Verify the 5 name mismatches in-game
5. Test mapID mismatches to find correct values

### Files Created
- `scripts/compare_addon_vendors.py` - Reusable comparison tool
- `scripts/generate_missing_vendors.py` - Generate vendor entries with coordinate conversion
- `scripts/merge_missing_vendors.py` - Merge vendors while maintaining sort order
- `addon_vendor_comparison.txt` - Full comparison report
- `VENDOR_VERIFICATION_SUMMARY.md` - Analysis and recommendations

## Session Summary (2026-01-31) - Afternoon

### Bug Fixes
- ✓ Fixed deprecated WoW API in OutputWindow.lua (SetMinResize/SetMaxResize → SetResizeBounds)
- ✓ Fixed Validation.lua case mismatches causing "0 vendors" error
  - `.vendors` → `.Vendors`, `.zoneToContinent` → `.ZoneToContinentMap`
  - Changed `ipairs()` → `pairs()` for NPC-keyed hash table iteration
- ✓ Fixed /hs export blank window issue (multiple causes):
  - Added OnTextChanged height handler for EditBox
  - Switched from custom frame to OutputWindow
  - Changed delimiter from `|` (WoW escape char) to `\t` (tabs)
  - Fixed string building to match Validation.lua pattern

### Data Corrections
- ✓ Added missing name for [145695] "Bad Luck" Symmes
- ✓ Fixed [78564] Sergeant Crowler (was incorrectly "Sergeant Grimjaw")
  - Updated: name, faction (Horde→Alliance), mapID (525→539), zone
- ✓ Confirmed [79774] Sergeant Grimjaw is correct (Horde counterpart)

### Scanned Items Merged (10 vendors, 46 items total)
- [68363] Quackenbush: 3 items
- [78564] Sergeant Crowler: 8 items
- [81133] Artificer Kallaes: 1 item
- [85427] Maaria: 2 items
- [85932] Vindicator Nuurem: 8 items
- [85946] Shadow-Sage Brakoss: 3 items
- [85950] Trader Caerel: 8 items
- [88220] Peter: 1 item
- [219217] Velerd: 2 items (updated coords)
- [252312] Second Chair Pawdo: 10 items (updated coords)

### Verified (No Changes Needed)
- [49877] Captain Lancy Revshon: 18 items match
- [254603] Riica: 18 items match
- [58706] Gina Mudclaw: 5 items match
- [261231] Tuuran: 1 item matches

### Infrastructure
- ✓ Added `_G.Homestead = HA` for /dump debugging access
- ✓ Updated Homestead.toc metadata:
  - Author: Nubs
  - Version: 0.1.0-alpha
  - Notes: Updated description
  - X-Website: https://github.com/Royaleint/Homestead

### Next Steps
1. Continue scanning vendors in-game to populate items arrays
2. Verify remaining 3 name mismatches: [64001], [64032], [127151]
3. Test /hs export with new tab-delimited format
4. Review 32 MapID mismatches
