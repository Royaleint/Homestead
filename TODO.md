# Homestead TODO

## Current Version: v1.1.3 (released 2026-02-05)

## High Priority
- [x] **Scanned cost data not used in tooltips** � VendorScanner captures full cost data (gold, currencies, item costs) and stores it in `db.global.scannedVendors`, but `VendorData:GetVendorsForItem()` and `GetItemCostFromVendor()` only query the static VendorDatabase. Scanned costs are orphaned. Fix: add scannedVendors as a fallback/overlay in the lookup chain so dynamically discovered prices appear in housing catalog and item tooltips. (2026-02-05)
- [ ] Verify 3 name mismatches in-game: [64001], [64032], [127151]
- [ ] Fix 15 vendors with placeholder coordinates via in-game scanning
- [ ] Review 32 MapID mismatches (see VENDOR_VERIFICATION_SUMMARY.md)
- [ ] Scan remaining vendors for item data (many now populated from Housing-Vendor import)

## Normal
- [ ] Bag overlays (Phase 9)
- [ ] Completionist dashboard / Main UI Browser (Phase 8)
- [ ] Endeavours tracking (Phase 7)
- [ ] Multi-source display in tooltips (items available from vendor + drop)

## Tech Debt
- [ ] Migrate legacy merchant APIs to C_MerchantFrame when Blizzard completes modern API
- [ ] Address luacheck code quality warnings (~40 unused variables, 8 shadowed self, 5 empty if branches)
- [ ] Consolidate zoneToContinent tables (VendorMapPins.lua local + VendorDatabase.ZoneToContinentMap) into single source of truth
- [ ] Add version migration system for SavedVariables
- [ ] Currency type database (currencyTypeID → name mapping) for better cost display

## Adoption / Marketing
- [ ] Post to r/wowaddons
- [ ] Join WOWKEA Discord and share addon
- [ ] Comment on Wowhead housing articles

## Future Enhancements
- [ ] Reputation requirements for vendor items
- [ ] GitHub Issue Template for data submissions (.github/ISSUE_TEMPLATE/)
- [ ] Google Form for player-friendly data submission
- [ ] External API verification of vendor data

## Completed
- [x] Code audit: Global namespace compliance (10 -> 7 justified globals) (2026-02-05)
- [x] Code audit: Deprecated API replacement (GetContainerItemLink, GameTooltip:HookScript) (2026-02-05)
- [x] Fix ESC-to-close for export dialog (HomesteadExportDialog) (2026-02-05)
- [x] Updated WelcomeFrame branding � new tagline, Quick Start, Housing Catalog warning (2026-02-05)
- [x] Fixed UTF-8 encoding in WelcomeFrame (2026-02-05)
- [x] Rewrite CurseForge and Wago descriptions (2026-02-05)
- [x] Add screenshots to CurseForge and Wago listings (2026-02-05)
- [x] Clean up generated artifacts from git tracking (2026-02-05)
- [x] AUDIT_REPORT.md and .luacheckrc added to repo (2026-02-05)
- [x] Updated README.md branding and fixed MIT->GPL-3.0 license reference (2026-02-05)
- [x] Added Global Namespace Rules to CLAUDE.md (2026-02-05)
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



