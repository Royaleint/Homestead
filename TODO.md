# Homestead TODO

> **Note:** This file is a living document — update it, don't replace it. It tracks both open tasks and completed work history. Mark items `[x]` when done and add new completed items to the appropriate version section.

## Session Summary (2026-02-12, latest)

**This session completed:**
- Runtime sourceText Parse System — all 6 phases implemented, QA'd, and merged to main
  - Phase 1: SourceTextParser + LocaleProfiles (pure Lua 5.1 string parsing)
  - Phase 2: CatalogScanner mods (sourceText forwarding)
  - Phase 3: SourceTextScanner + ValidationReport (djb2 hash, dev-only reporting)
  - Phase 4: SourceManager integration (gated behind useParsedSources toggle)
  - Phase 5: CatalogDiscoveryScanner (dev addon only, throttled batch scanning)
  - Phase 6: Dev addon assembly (DevCore, ApiTest migration, slash commands)
- Codex QA review fixes: 6 bugs fixed (ValidationReport API paths, SourceTextScanner init, tooltip unverified tags, Options toggle, duplicate vendor names, named frame removal)
- Runtime bug fixes: color code stripping (|cXXXXXXXX/|r), locale fallback in ProcessScannedItem
- ValidationReport cross-reference fix: VendorNameToNPC auto-populated from VendorDatabase (was only ~40 manual entries, now covers all ~248 vendors); table-length check for single vs multi-NPC entries
- DB cleanup: Stuart Fleming item 246426 removed, 13 empty zone strings filled, 7 vendors updated with missing items from parsed sourceText data
- Packaging: Homestead_Dev added to .pkgmeta ignore list

**Previous session (2026-02-12, earlier):**
- Finalized runtime parser starting prompt with Claude.ai collaboration
- Created 3 Claude Code skills (`.claude/commands/`): qa-review, phase-commit, audit-globals

**Previous session (2026-02-11):**
- API sweep: tested Housing Catalog APIs in 4 contexts
- Confirmed `firstAcquisitionBonus == 0` as reliable ownership signal
- Confirmed `GetCatalogEntryInfoByRecordID` works from addon code (not tainted)
- Blizzard API deep analysis: identified decorID errors, discovered new API methods
- **Runtime sourceText Parse System plan created** (`Run_Parser_Upgrade.md`) — 6-phase plan with dev addon split, 4-agent team, Codex review incorporated
- All 30 commits pushed to origin/main (GitHub account restored)

**Still pending:**
- [ ] Upload `Homestead-v1.3.1.zip` to Wago (manual)
- [x] Push to GitHub (account restored Feb 11, 30 commits pushed)
- [ ] Move git tags before push (v1.3.0 and v1.3.1 tags both stale — pushing tags WILL trigger CurseForge/Wago CI)
- [ ] Test new 12.0.1 housing APIs for taint status (`GetMarketInfoForDecor`, `GetNumFloors`, `BulkRefundDecors`)
- [ ] Re-scan vendors that were broken pre-12.0.1 (Blizzard fixed "Decor Vendor" NPCs not showing merchandise)
- [x] **Execute Runtime Parse System** — all 6 phases implemented, QA'd, merged to main (2026-02-12)

---

## Known Issues
- Some vendors may still show incorrect item counts (PARTIAL status from audit)
- TBC vendors largely deprecated (items removed from game)

---

## Verified Database Project (2026-02-11)

### Phase 0: API Testing (COMPLETE)
- [x] Run `/hstest` in-game in 4 contexts (post-reload, post-catalog-open, in-plot, in-city)
- [x] Determine: number vs string input to GetCatalogEntryInfoByItem — REJECTED (all 3 formats work identically)
- [x] Determine: GetCatalogEntryInfoByRecordID(1, decorID, true) usability — WORKS, not tainted, 7/8 decorIDs valid
- [x] Determine: firstAcquisitionBonus == 0 as collection signal — CONFIRMED in all contexts
- Test script: `scripts/api_test.lua` + `scripts/HomesteadAPITest.toc`

### Phase 1: Verification Pipeline (PLANNED)
- [ ] Build ingest parsers (Homestead, community CSV, addon locations)
- [ ] Build normalize + compare + score pipeline
- [ ] Generate reports: verified items, gaps, conflicts, stats
- Pipeline is READ-ONLY — never auto-writes to VendorDatabase.lua
- All changes require human review and explicit approval

### Phase 2: DecorID Integration (PLANNED)
- [ ] Build itemID ↔ decorID mapping from Blizzard API discovery
- [ ] Fix QuestSources.lua mixed keying bug (some entries use decorID, should use itemID)
- [ ] Evaluate GetCatalogEntryInfoByRecordID as taint-free collection detection path

### Phase 3: Gap Filling (PLANNED)
- [ ] Add missing World Quest sources
- [ ] Add missing Treasure/Promotion sources
- [ ] Cross-reference vendor item counts against Blizzard API data

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
- [x] Root cause identified: v1.1.0 data import had bad vendor-to-item mappings (2026-02-11)
- [x] Founder's Point vendors fixed: Xiao Dan, Trevor Grenner, High Tides Ren, Len Splinthoof, Yen Malone (2026-02-11)
- [x] Joruh [254606]: 16 PvP gear items removed, 19 correct housing decor items added (2026-02-11)
- [x] Vendorbot [150716]: 3 wrong items removed, 15 items with real Mechagon costs (2026-02-11)
- [x] Torv Dubstomp [108017]: 15 pre-import items restored (wiped by import, never corrected) (2026-02-11)
- [x] Drac Roughcut [1465]: confirmed correct (1 item, 246422) (2026-02-11)
- [x] Stuart Fleming [3178]: Remove item 246426 (API confirms only 257405 belongs) (2026-02-12)
- [ ] Remaining cost additions: Trader Caerel (9), Pascal-K1N6 (17), Ophinell (3), Bitterbrand (4), Lonomia (5)

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

### New vendors from parsed sourceText (need NPC IDs — in-game or Wowhead lookup)
- [ ] **Construct Ali'a** (Silvermoon City) — ~30 items, Midnight vendor
- [ ] **Void Researcher Anomander** (Voidstorm) — ~12 items, Midnight vendor
- [ ] **Naynar** (Harandar) — ~12 items, new vendor
- [ ] **Sathren Azuredawn** (Eversong Woods) — ~12 items, Midnight/BE zone vendor
- [ ] **Ripley Kiefer** (Teldrassil) — 4 items (was commented out in VendorNameToNPC, needs NPC ID)
- [ ] **Telemancer Astrandis** (Silvermoon City) — 2 items, Midnight vendor
- [ ] **Nael Silvertongue** (Silvermoon City) — 1 item, Midnight vendor
- [ ] **Lifecaller Tzadrak** (The Waking Shores) — 1 item, Dragonflight vendor
- [ ] **Draenor World Vendors** — 4 items (generic vendor, need NPC ID)
- [ ] **Eastern Kingdoms World Vendors** — 1 item (generic vendor, need NPC ID)

### Items added from parsed sourceText validation (2026-02-12)
- [x] Sergeant Grimjaw [79774]: +4 items (244320, 244653, 245438, 245443)
- [x] World Vendors [257633]: +12 items (248337-248339, 256923, 260785, 264249, 264254, 264655, 266244, 266245, 266443, 266444)
- [x] Void Researcher Aemely [259922]: +2 items (267082, 267209)
- [x] Naleidea Rivergleam [242398]: +1 item (246779)
- [x] Provisioner Thom [193659]: +1 item (250912) — was empty, now has 1 item
- [x] Magovu [240279]: +2 items (264333, 264350)
- [x] Wilkinson [44114]: +1 item (256905)

## Completed (v1.3.1)
- [x] TOC updated to 120001 for WoW patch 12.0.1 (2026-02-10)
- [x] CLAUDE.md updated with 12.0.1 APIs and refactoring contract (2026-02-10)
- [x] Homestead-v1.3.1.zip packaged for upload (2026-02-10)
- [x] REFACTOR_CONTRACT.md validated and committed with REFACTOR_SUMMARY.md (2026-02-10)
- [x] Vendor data corrections committed: 20+ vendors updated, 4 removed, 2 marked unverified (2026-02-10)
- [x] Scanner tooltip rewritten to use GameTooltipTemplate with tooltip fallback for decor detection (2026-02-10)
- [x] Auto-hide scanComplete field bug committed (2026-02-10)
- [x] AUDIT_REPORT.md updated: HomesteadScanTooltip as global #8 (2026-02-10)
- [x] Section 1 refactor: UnpackItem helper, npcID stamping in BuildIndexes, GetVendorCount caching (2026-02-10)

## Completed (v1.3.0+)
- [x] Fix auto-hide no-decor vendors — removed nonexistent `scanComplete` field checks, now only uses `scanConfidence` (2026-02-09)
- [x] Tooltip fallback decor detection — scan tooltip for "Housing Decor" when GetCatalogEntryInfoByItem returns nil (2026-02-09)
- [x] GameTooltipTemplate fix — named frame + template for SetMerchantItem in WoW 12.0+ (2026-02-09)
- [x] Comparison script parser fix — brace-depth tracking for nested cost structures (2026-02-09)
- [x] WoD scan verified: 10 vendors match, Brakoss restored, currency corrections applied (2026-02-09)
- [x] Legion Suramar/Val'sharah/Highmountain scan: 12 vendors match, 4 corrected (2026-02-09)
- [x] Stacks Topskimmer: 46 wrong items → 13 confirmed RC items (2026-02-09)
- [x] Eadric the Pure: 16 → 7 confirmed decor items (2026-02-09)
- [x] Ransa Greyfeather: 23 → 8 confirmed items, mapID corrected (2026-02-09)
- [x] Domelius marked unverified (Legion Remix, no longer available) (2026-02-09)
- [x] Removed Sir Finley x2, Captain Lancy Revshon, Smaks Topskimmer (167300) (2026-02-09)
- [x] 14+ vendors updated with cost data from DF/TWW export batch (2026-02-09)
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
- [x] External attribution removed from VendorDatabase.lua header (2026-02-05)
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
- [x] Compare against community data sources (2026-01-31)
- [x] Add 54 missing vendors from community data with coordinate conversion (2026-01-31)
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
