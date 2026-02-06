# Homestead TODO

## Known Issues
- Some vendors may still show incorrect item counts (PARTIAL status from audit)
- TBC vendors largely deprecated (items removed from game)

---

## Next — Data Quality Follow-up

### In-game scans needed
- [ ] ~93 high-priority items still needing in-game scans (was 201, reduced by Razorwind import)
- [ ] Events expansion validation (seasonal vendors — defer until events are active)

### Expansion naming inconsistency
- [ ] Standardize: "MoP" (10 vendors) vs "Mists of Pandaria" (14 vendors) — pick one, update all
- [ ] Check and standardize all other expansions: "TWW" vs "The War Within", etc.
- [ ] Ensure nothing filters or groups by expansion string (would break with inconsistent names)

### Placeholder coordinates
- [ ] Fix Nat Pagle (NPC 63509) — currently x=0.7, y=0.3 in Krasarang Wilds. Get real coords or mark unverified.
- [ ] Fix vendor at x=0.5, y=0.5 — find which NPC this is, get real coords or mark unverified.

### Zone-specific data sweeps (flagged by Reddit users)
- [ ] Pandaria — Vegetable_Yam_7375 rated accuracy 3/10. Verify all MoP/Mists of Pandaria vendors for correct coordinates and valid items.
- [ ] Kalimdor — OMFGitsBob reported "almost every point" has wrong coordinates.
- [ ] Zuldazar — Same report from Bob. Check all Zuldazar/Dazar'alor vendors.

---

## Feature Requests

### Map icon visibility improvements (Reddit feedback)
- [ ] Icons blend into map — need better contrast or outline (multiple reports)
- [ ] Continent-level pin placement refinement (melaspike666 feedback)

### Hide/recolor fully-collected vendors (requested by OMFGitsBob on r/WoWUI)
- [ ] When all items from a vendor are owned, change pin color (green/dimmed) instead of removing
- [ ] Add option to fully hide completed vendors
- [ ] Default: color change (completionists still want to see where they've been)

### Catalog tooltip enhancements
- [ ] Bob confirmed tooltip info (rep requirements, world quest vs regular quest distinction) is a differentiator vs ATT
- [ ] Expand: more source detail, prerequisite info, currency requirements in tooltip

### WagoAnalytics local dev fix
- [ ] Blocked: WagoAnalyticsShim only downloads during BigWigs packaging, not local dev
- [ ] Option A: clone shim repo locally
- [ ] Option B: add defensive nil checks around all analytics calls
- [ ] Pick one and implement so local dev doesn't throw 16 Lua errors

---

## Ongoing / Systemic

### Community scan pipeline
- [ ] Reddit users are submitting exports. Need efficient merge workflow.
- [ ] Create merge script or process doc so contributed data gets incorporated quickly.

### Verify imported items are actually housing decor
- [ ] Housing-Vendor merge may have imported non-decor items into vendor item lists
- [ ] This is the likely root cause of Bob's "vendors that don't sell decor" report
- [ ] Cross-reference all imported vendor items against C_HousingCatalog or DecorSources.lua
- [ ] Remove non-decor items from vendor entries

### Duplicate entry technical debt
- [ ] After dedup, verify no pins stack on top of each other
- [ ] Verify alias system correctly resolves all merged NPC IDs

---

## Completed (v1.2.0)
- [x] v1.2.0 data quality audit — full Hub validation, Classic through TWW (2026-02-05)
- [x] Hub validation: 275 vendors validated across 11 expansions (2026-02-05)
- [x] Razorwind Shores vendor population — 24 Housing area vendors with zone names and items (2026-02-05)
- [x] Currency corrections — 64 currency-related changes across all expansions (2026-02-05)
- [x] Coordinate fixes — 4 coordinate updates from in-game scan data (2026-02-05)
- [x] Unverified vendor system — 85 imported vendors flagged, hidden by default (2026-02-05)
- [x] Duplicate vendors audit — 41 duplicate names audited, 13 aliased to canonical NPCs (2026-02-05)
- [x] 17 vendor entries removed (13 aliased, 4 deleted as empty/unverifiable) (2026-02-05)
- [x] Non-decor vendor hiding verified (2026-02-05)
- [x] Default visibility setting confirmed hidden for unverified vendors (2026-02-05)
- [x] Housing-Vendor attribution removed from VendorDatabase.lua header (2026-02-05)
- [x] Changelog: v1.2.0 section written (2026-02-05)
- [x] Scan data imported: Tethalash, Tuuran, Jorid, Velerd, and 11 Razorwind Shores vendors (2026-02-05)

## Completed (v1.1.3 and earlier)
- [x] Code audit: Global namespace compliance (10 -> 7 justified globals) (2026-02-05)
- [x] Code audit: Deprecated API replacement (GetContainerItemLink, GameTooltip:HookScript) (2026-02-05)
- [x] Fix ESC-to-close for export dialog (HomesteadExportDialog) (2026-02-05)
- [x] Updated WelcomeFrame branding — new tagline, Quick Start, Housing Catalog warning (2026-02-05)
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
- [x] Create reusable OutputWindow for /hs validate and /hs corrections (2026-01-31)
- [x] Fix deprecated WoW API SetMinResize/SetMaxResize → SetResizeBounds (2026-01-31)
- [x] Fix Validation.lua case mismatches (.vendors → .Vendors, .zoneToContinent → .ZoneToContinentMap)
- [x] Fix Validation.lua iteration (ipairs → pairs for NPC-keyed hash table)
- [x] Add missing vendor name [145695] "Bad Luck" Symmes (2026-01-31)
- [x] Fix NPC 78564: Sergeant Grimjaw → Sergeant Crowler, Horde → Alliance, mapID 525 → 539 (2026-02-05)
- [x] Add global reference _G.Homestead for /dump debugging (2026-01-31)
- [x] Fix /hs export blank window - pipe delimiter, OutputWindow integration, table.concat pattern (2026-01-31)
- [x] Merge scanned items into VendorDatabase for 10 vendors (2026-01-31)
- [x] Update Homestead.toc with release metadata (Author: Nubs, Version: 0.1.0-alpha) (2026-01-31)
