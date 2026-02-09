# Homestead TODO

> **Note:** This file is a living document — update it, don't replace it. It tracks both open tasks and completed work history. Mark items `[x]` when done and add new completed items to the appropriate version section.

## Session Summary (2026-02-08, latest)

**Vendor Scanner Overhaul — VENDOR_Plan.md implementation**
Full plan in `VENDOR_Plan.md`. 5 parts across 3 phases. Status:

- [x] **Part 1: No-Decor Vendor Tracking** (Phase 1) — DONE
  - `noDecorVendors` persistent tracking with scanConfidence ("confirmed"/"unknown") and confirmCount
  - Two-scan threshold: `confirmCount >= 2` before actionable for removal
  - `ClearScannedData()` preserves noDecorVendors; new `ClearNoDecorData()` and `ClearAllData()`
  - `ShouldHideVendor()` rewritten to check noDecorVendors with scanConfidence guard

- [x] **Part 2: Enhanced Scanner Data Capture** (Phase 2) — DONE
  - Location capture (zone, subZone, realZone, parentMapID) in StartScan
  - `isUsable`/`spellID` saved per item; currency inference (primaryCurrency); expansion inference via ContinentToExpansion
  - V2 export extended: 14-field vendor line, 8-field item line, `SanitizeExportField()`, deterministic sort by npcID/itemID, `#` comment headers
  - Import V2 updated with nil fallbacks for new fields

- [x] **Part 2.5: Tooltip Requirement Scraping** (Phase 2) — DONE (awaiting in-game test)
  - Unnamed tooltip (no global namespace pollution), locale-keyed enUS patterns, pcall safety, three-state model, export `R:` format, Options toggle
  - SetOwner timing fix applied; scrape moved inside `if isDecor` block; delimiter-safe serialization (EscapeReqValue/UnescapeReqValue)
  - Awaiting in-game test: visit vendor 252910 with `/hs debug` enabled

- [x] **Part 3: DB Maintenance Tools** (Phase 3) — DONE
  - `/hs suggest`, `/hs nodecor`, `/hs clearnodecor`, `/hs clearall` — all gated behind developer mode
  - `/hs devmode` toggle, `IsDevMode()` helper, help text conditionally shown
  - `/hs suggest` outputs deterministic (sorted npcID) with chat fallback when OutputWindow unavailable

- [x] **Part 4: Export & UI Improvements** (Phase 2) — DONE
  - "Copy All" → "Select All" button in OutputWindow
  - Options panel: updated clearScannedButton description, added resetNoDecorButton with confirm dialog

- [x] **Part 5: Python Comparison Script** (Phase 3) — DONE
  - `scripts/compare_exports.py` — V2 export vs VendorDatabase.lua comparison (NEW/MATCH/UPDATED/FEWER)
  - `EXPORT_COMPARISON_GUIDE.md` — usage manual
  - Empty input warning + non-zero exit on invalid export files

**Code review fixes applied (3 rounds, 13 findings):**
- ShouldHideVendor confidence guard on scannedVendors path
- Unified ClearScannedData as single source of truth (Options/slash/ExportImport all delegate)
- ClearAllData upgraded with full index rebuild + pin refresh
- Unnamed tooltip (no global namespace write)
- Metadata preservation on rescan (6 fields with `or existingData.field` fallback)
- Sort guard for polymorphic item shapes (table vs number)
- ClearNoDecorData pin refresh
- Dev help text hidden from non-dev users
- compare_exports.py empty input warning
- /hs suggest deterministic sort + chat fallback

**Previous sessions (2026-02-08, earlier)**
- First Codex 5.3 code review: 10 findings, 7 bugs confirmed and fixed (commit 1a97fb4)
- Tooltip "Unknown Item" on first hover fix (commit b0f4995)
- V2 export format spec added to CLAUDE.md
- Community export processed: Garnett +6, Auditor Balwurz +4, The Last Architect +1, Lancy Revshon +1 (commit 7fda76b)
- v1.3.0 tag created (a1efc9e), CurseForge upload pending

---

## Known Issues
- Some vendors may still show incorrect item counts (PARTIAL status from audit)
- TBC vendors largely deprecated (items removed from game)

---

## Next — Data Quality Follow-up

### In-game scans needed
- [ ] ~93 high-priority items still needing in-game scans (was 201, reduced by Razorwind import)
- [ ] Events expansion validation (seasonal vendors — defer until events are active)

### Expansion naming inconsistency
- [x] MoP: all 7 active vendors now use "Mists of Pandaria" (no "MoP" abbreviations remain)
- [ ] Check and standardize all other expansions: "TWW" vs "The War Within", etc.
- [ ] Ensure nothing filters or groups by expansion string (would break with inconsistent names)

### Placeholder coordinates
- [x] Nat Pagle (NPC 63509) — removed from DB (not a housing vendor, item deleted from game)
- [ ] Fix vendor at x=0.5, y=0.5 — find which NPC this is, get real coords or mark unverified.

### Zone-specific data sweeps (flagged by Reddit users)
- [ ] Pandaria — Vegetable_Yam_7375 rated accuracy 3/10. Verify all MoP/Mists of Pandaria vendors for correct coordinates and valid items.
- [ ] Kalimdor — OMFGitsBob reported "almost every point" has wrong coordinates.
- [ ] Zuldazar — Same report from Bob. Check all Zuldazar/Dazar'alor vendors.

---

## Feature Requests

### Map icon visibility improvements (Reddit feedback)
- [x] Configurable pin color: 10 presets + custom picker with preview swatch (2026-02-07)
- [x] Fix color fidelity: desaturate icon before tinting so blues/cyans render accurately (2026-02-07)
- [x] Badge count: remove black box, use outlined + shadowed text scaled with pin size (2026-02-07)
- [x] Vendor pins show collected/total ratio (e.g., "3/12") with toggle to disable (2026-02-07)
- [x] Badge count colors: green=all collected, white=partial, red=none collected (2026-02-07)
- [ ] Continent-level pin placement refinement (melaspike666 feedback)

### Hide/recolor fully-collected vendors (requested by OMFGitsBob on r/WoWUI)
- [x] Vendor pins color-coded by collection status (green/white/red ratio text) (2026-02-07)
- [ ] Add option to fully hide completed vendors
- [ ] Default: color change (completionists still want to see where they've been)

### Catalog tooltip enhancements
- [ ] Bob confirmed tooltip info (rep requirements, world quest vs regular quest distinction) is a differentiator vs ATT
- [ ] Expand: more source detail, prerequisite info, currency requirements in tooltip

---

## Ongoing / Systemic

### Community scan pipeline
- [ ] Reddit users are submitting exports. Need efficient merge workflow.
- [ ] Create merge script or process doc so contributed data gets incorporated quickly.
- [ ] Google Forms submission pipeline: first submission received but user copied response ID instead of export data — need to follow up

### Verify imported items are actually housing decor
- [ ] Housing-Vendor merge may have imported non-decor items into vendor item lists
- [ ] This is the likely root cause of Bob's "vendors that don't sell decor" report
- [ ] Cross-reference all imported vendor items against C_HousingCatalog or DecorSources.lua
- [ ] Remove non-decor items from vendor entries

### Duplicate entry technical debt
- [ ] After dedup, verify no pins stack on top of each other
- [x] Alias system: dead AliasLookup infrastructure cleaned up; aliases resolve at scan time only (2026-02-08)

### Remaining low-priority Codex findings (deferred)
- [ ] Zone-to-continent mapping duplicated in VendorDatabase.lua and Validation.lua — consolidate to constants.lua
- [ ] FindVendorByName nondeterministic with duplicate names (low risk, last-write-wins is acceptable)
- [ ] "Closest vendor" tooltip logic picks first match, not geographically closest (cosmetic)

---

### Vendor data investigation needed
- [ ] Botanist Boh'an [255301]: DB has itemID 266243, export has 266443 — possible Blizzard item ID change or data error
- [ ] Jolinth [253086]: Export shows itemID 248656, DB has 248111/256168/256169 — completely different items, needs in-game verification

## Completed (v1.3.0+)
- [x] Fix map pin tooltip "Unknown Item" on first hover — pre-warm cache + GET_ITEM_INFO_RECEIVED event refresh (2026-02-08)
- [x] Add V2 export format specification to CLAUDE.md and MEMORY.md (2026-02-08)
- [x] Process community vendor export: Garnett +6, Auditor Balwurz +4, The Last Architect +1, Captain Lancy Revshon +1 (2026-02-08)

## Completed (v1.3.0)
- [x] Pin color: desaturate-before-tint for accurate cool colors (blues, cyans, purples) (2026-02-07)
- [x] Pin color: 10 presets (added light blue, white, yellow) + custom picker (2026-02-07)
- [x] Pin color: IsCustomPinColor() checks preset name, not RGB values (2026-02-07)
- [x] Badge counts: removed black box, outlined + shadowed text, font scales with pin size (2026-02-07)
- [x] Badge count colors: green=fully collected, white=partial, red=all uncollected (2026-02-07)
- [x] Vendor pins: collected/total ratio display (e.g., "3/12") with "Show collection counts" toggle (2026-02-07)
- [x] Removed misidentified vendors: Mistress Mihi (165780), Chamberlain (172555) (2026-02-07)
- [x] Configurable pin color feature: presets + custom color picker (2026-02-07)
- [x] Pin color preview swatch in Options showing approximate map appearance (2026-02-07)
- [x] Circular backplate using TempPortraitAlphaMask for clean color tinting on world map (2026-02-07)
- [x] Ring tinting + natural white icon for non-default colors (2026-02-07)
- [x] Unverified pins remain orange regardless of color selection (2026-02-07)
- [x] MINIMAP_ICON_SIZE reduced from 14 to 12 (2026-02-07)
- [x] WOW_ADDON_PATTERNS.md expanded: 579→1152 lines, 9 new sections (texture/atlas, Lua 5.1, color/markup, Map API, pcall, TOC, secure hooks, frame pools, 12.0.0 API changes) (2026-02-08)
- [x] CLAUDE.md trimmed and improved: 249→204 lines, added lessons learned, git conventions, session workflow, removed redundancy (2026-02-08)
- [x] Fix stale ScannedByItemID after import/clear — rebuild index in ImportV1, ImportV2, ClearScannedData (2026-02-08)
- [x] Fix partial vendor scans saved as authoritative — add scanComplete flag, discard partial data on merchant close, clear session lock for re-scan (2026-02-08)
- [x] Fix hasDecor false positive in V2 import — check both .items and .decor keys (2026-02-08)
- [x] Fix pin/badge caches not invalidated after import/clear — new InvalidateAllCaches() method (2026-02-08)
- [x] Fix showVendorDetails reading wrong profile path — profile.showVendorDetails → profile.vendorTracer.showVendorDetails (2026-02-08)
- [x] Fix validation false warnings — remove redundant decor check that assumed .itemID on static-format items (2026-02-08)
- [x] Clean up dead AliasLookup infrastructure — remove unused table and misleading BuildAliasIndex comment (2026-02-08)
- [x] Agentic team plan created (AGENTIC_TEAM_PLAN.md) — Claude lead + Codex/Gemini/ChatGPT (2026-02-08)
- [x] First Codex 5.3 code review completed — 10 findings, 7 confirmed and fixed (2026-02-08)

## Completed (v1.2.3)
- [x] MoP vendor cleanup: Sage Whiteheart NPC 77440→64032, mapID/coords fixed; Jojo Ironbrow removed (crafted items); dangling alias cleaned (2026-02-07)
- [x] Sub-zone mapID corrections applied: Val'zuun 627→628, Torv Dubstomp 650→652, Sileas Duskvine 641→680 (2026-02-07)
- [x] Fix missing VendorDatabase:GetAliasCount() — /hs aliases was crashing (2026-02-07)
- [x] Nil-guard mapID in VendorScanner before GetPlayerMapPosition (2026-02-07)
- [x] MoP priority scans fully resolved — all 16 issues closed (2026-02-07)

## Completed (v1.2.1)
- [x] WagoAnalytics local dev fix — added no-op shim stub at Libs/WagoAnalytics/Shim.lua (2026-02-06)
- [x] FPS stutter hotfix — debounce zone changes, cache GetAllVendors/uncollected status, reverse continent index, ByItemID tooltip lookup (2026-02-06)

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
