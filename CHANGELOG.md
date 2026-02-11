# Homestead Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## v1.3.1 (2026-02-10) — Patch 12.0.1 Compatibility

### Changed
- **TOC updated to 120001** for WoW patch 12.0.1 (Second Midnight Pre-Expansion Update)

### Fixed
- **Auto-hide no-decor vendors not working** — `ShouldHideVendor()` checked nonexistent `scanComplete` field; now correctly uses only `scanConfidence == "confirmed"`
- **Decor detection for achievement-gated items** — Added tooltip fallback: when `GetCatalogEntryInfoByItem()` returns nil, scans merchant tooltip for "Housing Decor" text (catches items like Counterfeit Dark Heart of Galakrond)
- **GameTooltipTemplate for scan tooltip** — Named frame (`HomesteadScanTooltip`) with `GameTooltipTemplate` inherits font strings required by `SetMerchantItem()` in WoW 12.0+
- **Comparison script parser** — Fixed nested brace handling and depth-aware item ID extraction in `compare_exports.py`

### Database — Vendor Corrections (scan-verified)
- **Removed 4 vendors**: Sir Finley Mrrgglton x2 (219460, 208070 — no decor items), Captain Lancy Revshon (45389, empty duplicate), Smaks Topskimmer (167300, empty unverified duplicate)
- **Domelius** (251042, 251179): Marked unverified — Legion Remix vendor, no longer available in game; decor moved to Val'zuun
- **Stacks Topskimmer** (251911): Replaced 46 incorrect gold-priced items with 13 confirmed Resonance Crystal items
- **Eadric the Pure** (100196): Trimmed from 16 to 7 confirmed decor items with proper Order Resources costs
- **Ransa Greyfeather** (106902): Trimmed from 23 to 8 confirmed items, mapID 650→750 (Thunder Totem), removed altCurrency
- **Sylvia Hartshorn** (106901): Replaced 6 wrong items with 5 confirmed items, fixed zone/subzone/coords/currency
- **Selfira Ambergrove** (253387): Removed 2 non-decor items, updated costs and coords from export
- **Sileas Duskvine** (253434): Replaced 5 wrong items with 1 confirmed item (245701), updated coords, added subzone
- **Shadow-Sage Brakoss** (85946): Restored after incorrect deletion — confirmed 3 Apexis Crystal items from export
- **14+ vendors** updated with cost data from in-game export scans (Rae'ana, Cataloger Jakes, Unatos, Ellandrieth, Blair Bass, Rocco Razzboom, and others)
- **Multiple currency corrections**: Ruuan the Seer and Duskcaller Erthix Gold→Apexis Crystal; various altCurrency fixes
- **WoD scan**: 10 vendors verified as MATCH
- **Legion Suramar/Val'sharah/Highmountain scan**: 12 vendors verified as MATCH

---

## v1.3.0 (2026-02-08) — Pin Colors, Collection Tracking, Vendor Scanner Overhaul

This release overhauls map pin visuals, adds collection progress tracking directly
on the map, introduces a full vendor scanner overhaul with developer maintenance
tools, and delivers a wave of performance improvements and bug fixes. Pins are now
customizable, color-accurate, and show at-a-glance collection status so you always
know what you still need.

### Added — Pin Color System
- **10 color presets** for map and minimap pins: Default (Gold), Bright Green, Ice Blue, Light Blue, Cyan, Purple, Pink, Red, Yellow, White
- **Custom color picker** for full RGB control beyond presets
- **Color preview swatch** in Options showing approximate in-game appearance
- Unverified pins always stay orange regardless of color selection
- Opposite-faction pins dim the chosen color for visual distinction

### Added — Collection Progress on Map
- **Collected/total ratio** displayed on vendor pins (e.g., "3/12") when viewing zone maps
- **Color-coded badge counts** on continent and zone maps: green = all collected, white = partial, red = none collected
- **"Show collection counts" toggle** in Options to disable vendor pin ratios for a cleaner map
- **Independent size sliders** for world map pins (12-32, default 20) and minimap pins (8-24, default 12)

### Added — Vendor Scanner Overhaul
- **No-decor vendor tracking**: Vendors confirmed to sell no housing decor are now persistently tracked with a two-scan confirmation threshold before they're hidden from the map
- **Enhanced scan data capture**: Location (zone, subZone, parentMapID), `isUsable`/`spellID` per item, automatic currency inference, expansion inference from continent
- **Tooltip requirement scraping**: Red tooltip text (reputation, profession, achievement gates) is captured during vendor scans and exported in `R:` format
- **Scan confidence model**: Scans tagged with `scanConfidence` ("confirmed"/"unknown") — untrusted single-scans no longer hide vendors from the map
- **Metadata preservation**: Rescanning a vendor no longer overwrites zone, expansion, or currency data with nil
- **"Select All" button** in output window replaces "Copy All" with proper text selection
- **"Reset Hidden Vendors" button** in Options to clear no-decor flags

### Added — Developer Mode & Maintenance Tools
- **Developer mode** (`/hs devmode`) — Toggle that gates maintenance commands
- `/hs suggest` — Generate VendorDatabase.lua entry snippets from scan data (deterministic output, chat fallback)
- `/hs nodecor` — List all vendors flagged as non-decor with removal status
- `/hs clearnodecor` — Clear no-decor flags so hidden vendors reappear on the map
- `/hs clearall` — Nuclear option: clear all scan data and no-decor flags

### Improved — Pin Rendering
- **Desaturate-before-tint**: Custom colors now desaturate the atlas icon to neutral grey before applying vertex color, so blues, cyans, and purples render accurately instead of being warped to teal by the gold atlas
- **Circular backplate** using TempPortraitAlphaMask for clean color tinting behind icons
- **Ring border tinting** subdued to keep icon as focal point
- **Badge count text** uses outlined + shadowed font instead of a black rectangle, scaled proportionally with pin size (min 8px)
- **Zoom behavior restored** by removing static SetScale — HereBeDragons SetScalingLimits handles map zoom naturally
- Default pin size (20) matches Blizzard POI icons for visual consistency

### Improved — Performance
- **Badge count caching** with cache-miss pattern — computed once, invalidated on ownership changes, vendor scans, merchant close, and settings toggles
- **Catalog scan coalescing** through a single RequestScan() debounce with scan-while-scanning flag
- **Minimap dedup guard** skips redundant zone-change refreshes when mapID is unchanged
- **World map dedup guard** skips redundant SetMapID refreshes
- Unverified vendors excluded from badge counts when hidden by settings

### Improved — Chat Output Cleanup
- **85+ diagnostic messages** routed through `Debug()` — scan details, NPC ID mismatches, confidence values, requirement scraping output, and test command results are now silent unless debug mode (`/hs debug`) is enabled
- **Debug/test commands** (`/hs testlookup`, `/hs testsource`, `/hs debugscan`, `/hs achievements`, `/hs aliases`) hidden from `/hs help` unless debug mode is on
- Removed placeholder "not yet implemented" messages from Options panel and dead code stubs

### Fixed — Bugs
- **Tooltip "Unknown Item" on first hover** — Pre-warms item info cache via `GetItemInfo()` when pins load; `GET_ITEM_INFO_RECEIVED` event auto-refreshes the tooltip with a 0.05s debounce
- **Housing event names**: Replace nonexistent HOUSING_CATALOG_UPDATED with HOUSING_STORAGE_UPDATED; rename HOUSING_DECOR_REMOVE_SUCCESS to HOUSING_DECOR_REMOVED
- **Vendor faction tagging**: Use UnitFactionGroup("npc") instead of "player"
- **Taint safety**: Wrap CheckIfDecorItem and C_HousingCatalog calls in pcall
- **Waypoint guards**: Add CanSetUserWaypointOnMap check before SetUserWaypoint; fix settings path for TomTom preference
- **Scanner fixes**: CatalogScanner now reads vendor.items (was only checking legacy .decor); VendorScanner no longer caches API at load time; scan retry clears session flag correctly
- **Export fixes**: Remove broken V1 export path; V2 is now the single format; clear OnEnterPressed handler to prevent sticking; delimiter-safe requirement serialization (`%2C`/`%3B` encoding); sort guard for polymorphic item shapes (table vs number)
- **V2 export format**: Extended with 'n' token for name-only currency costs
- **Currency recording**: Handle nil-link currency costs from GetMerchantItemCostItem with name fallback
- **Ownership detection**: Check top-level entrySubtype first, then entryID nested
- **Nil guards**: mapID in VendorScanner before GetPlayerMapPosition; entrySubtype in Tooltips
- **Missing method**: Add VendorDatabase:GetAliasCount() (/hs aliases was crashing)
- **UI polish**: Title bar layering, version text clipping, truncated toggle labels
- **Stale ScannedByItemID index** after import or clear — tooltip "sold by" lookups now rebuild the index immediately
- **hasDecor false positive** in V2 import — now checks both `.items` and `.decor` keys when computing flag
- **Pin and badge caches not invalidated** after import/clear — new `InvalidateAllCaches()` ensures map UI reflects imported data immediately
- **Partial scans saved as authoritative** — if merchant is closed mid-scan, partial data is now discarded and session lock cleared so vendor can be re-scanned
- **showVendorDetails wrong profile path** — was `profile.showVendorDetails` (always nil), now correctly reads `profile.vendorTracer.showVendorDetails`
- **Validation false warnings** for static-format items — removed redundant decor check that assumed `.itemID` key on positional format
- **Dead AliasLookup infrastructure** cleaned up — removed unused table; aliases resolve at scan time only
- **Unified ClearScannedData path** — Options button, `/hs clearscans`, and ExportImport all route through a single source of truth with proper index rebuild, cache invalidation, and pin refresh
- **ClearNoDecorData** now refreshes world map and minimap pins immediately

### Database — Vendor Cleanup
- **Removed 5 vendors**: Jojo Ironbrow (65066, crafted items not vendor-sold), Mistress Mihi (165780, misnamed — actually Mistress Mihaela, no decor), Chamberlain (172555, actually Lord Chamberlain, no decor), and 2 stale aliases
- **MoP cleanup**: Sage Whiteheart corrected from test NPC 77440 to real NPC 64032 with proper mapID/coords; dangling alias cleaned

### Database — Location Corrections
- **Sub-zone mapIDs**: Val'zuun 627 to 628 (Underbelly), Torv Dubstomp 650 to 652 (Thunder Totem), Sileas Duskvine 641 to 680 (Suramar)
- **Scan-verified coordinates** updated for Cinnabar, Cendvin, Faarden the Builder, Maaria

### Database — Item Updates
- **Faarden the Builder (255213)**: 22 incorrect items replaced with 35 scan-verified items (old items belonged to nearby vendor Xiao Dan)
- **Silvrath (253067)**: 6 new items added with Dragon Isles Supplies costs (now 14 total)
- **Cinnabar (252901)**: Populated with 3 Resonance Crystal items (was empty)
- **Cendvin (226205)**: Populated with 1 item (was empty)
- **Maaria (85427)**: Added Telredor Recliner, updated coords from scan data
- **Auditor Balwurz (235250)**: Expanded from 1 to 5 items with full Resonance Crystal costs
- **Garnett (50277)**: +1 item (253168) from community export scan
- **The Last Architect (254591)**: +1 item, currency corrected to Kej with Gold alt-currency
- **Celestine of the Harvest (210608)**: Added note — location is not static, moves with dreamsurge event

---

## v1.2.1 (2026-02-06)

### Fixed
- Hotfix for FPS stutter in vendor-dense locations
  - Debounce zone change events so rapid transitions only trigger one minimap refresh
  - Cache GetAllVendors
  - Cache per-vendor uncollected status to avoid repeated pcall/API hits on every refresh
  - Build reverse continent-to-zones index at load time.
  - Use existing ByItemID index for tooltip cost lookup.

---

## v1.2.0 (2026-02-05) — The Great Vendor Audit

Thanks everyone for being patient while we worked out the non-decor vendor issue!
Your reports helped us realize the database needed more than a quick fix — it needed
a proper audit.

So that's what we did. Every vendor in the database got verified for accuracy. We
corrected currencies, fixed coordinates, and cleaned up item lists across all
expansions from Classic through The War Within. Vendors we couldn't verify are now
hidden by default, so you'll only see pins for confirmed housing decor vendors.

The result: cleaner maps, accurate tooltips, and way fewer "why is this vendor here?" moments.

### Database — Vendors
- **17 vendor entries removed** (13 aliased to canonical NPCs, 4 deleted as empty/unverifiable)
- **12 new aliases added** to merge duplicate/phased NPC variants (24 total aliases)
- **275 vendor entries** validated across 11 expansions
- Unverified vendors now hidden by default (v1.1.3 system)

### Database — Currency Corrections
- **64 currency-related changes** across all expansions:
  - 43 direct currency field corrections (Gold to correct currency)
  - 20 altCurrency additions for mixed-currency vendors
  - 1 spelling correction (Seafarer's Doubloons to Seafarer's Dubloon)
- New currencies cataloged: Community Coupons, Sizzling Cinderpollen, "Gold" Fish,
  Brimming Arcana, Voidlight Marl, Twilight's Blade Insignia

### Database — Location & Metadata
- **34 zone field populations** (empty zone names filled in from Hub data)
- **24 Housing area vendors** assigned to Razorwind Shores (Horde) or Founder's Point (Alliance)
- **3 expansion tag corrections** (vendors tagged to wrong expansion)
- **3 faction corrections** (Alliance/Horde/Neutral mismatches)
- **1 vendor name fix** (NPC 242724 corrected from "Caeris Fairdawn" to "Ranger Allorn")
- **4 coordinate updates** from in-game scan data
- **9 duplicate itemIDs removed** from 3 vendor item arrays (scanner artifacts)

### Database — Items & Sources
- **8 items imported** from in-game scan data (Tethalash, Tuuran, Jorid, Velerd)
- **1 misattributed item** (244852 Head of the Broodmother) moved from vendor entries
  to AchievementDecor.lua under "More Dots! (25 player)"
- **16 achievement-to-decor mappings added** to AchievementDecor.lua:
  - 12 Raise an Army class hall achievements
  - 3 Lorewalking achievements
  - 1 Nightborne Armory achievement

---

## v1.1.3 (2026-02-05)
### Fixed � Namespace Compliance
- Removed duplicate _G[addonName] write in constants.lua
- Made UpdateAllMerchantOverlays local in Merchant.lua
- Removed unnecessary global name from CopyFrame
- Added ESC-to-close for export dialog (HomesteadExportDialog)
- Replaced deprecated GetContainerItemLink with C_Container.GetContainerItemLink
- Removed legacy GameTooltip:HookScript fallback

### Changed
- Updated WelcomeFrame branding and Quick Start
- Fixed UTF-8 encoding issues in WelcomeFrame

### Added
- AUDIT_REPORT.md � full compliance audit documentation
- .luacheckrc for static analysis
- Global Allowlist (7 justified globals)

---

## [1.1.2] - 2026-02-03

### New Features
- **WagoAnalytics integration** — Anonymous usage tracking to help improve the addon
- **17 new vendors added** — Orgrimmar, Dornogal, Hallowfall, Azj-Kahet, and Ringing Deeps
- **Unreleased vendor filtering** — Datamined Midnight vendors now hidden until content goes live

### Bug Fixes
- **Fixed missing/misplaced vendor pins:**
  - Nalina Ironsong (was showing in wrong zone)
  - Thripps (now correctly in City of Threads)
  - Cinnabar (now correctly in Isle of Dorn)
  - Shadow-Sage Brakoss (corrected coordinates)
  - Shadow Hunter Denjai, Mender Naemee, Kelsey Steelspark, Jackson Watkins, Arcanist Peroleth
- **Refined coordinates** for Velerd, Jorid, Waxmonger Squick, Cendvin, Lars Bronsmaelt, Chert, and Gabbun
- **Removed non-decor vendors** Krinn and Kradan from database
- **Fixed minimap pins** in Outland/Draenor/Shadowlands zones collapsing onto player position
- **Added 15 missing zone mappings** for proper minimap pin display across older content

### Improvements
- Welcome screen redesigned: larger, easier to read, includes feedback form link
- Internal code cleanup for vendor visibility checks

---

## [1.1.1] - 2026-02-03

### Fixed
- **Map pin tooltips not updating after vendor scan** — VendorMapPins was reading `scannedData.decor` (old field name) instead of `scannedData.items` (new field name from v1.1.0 scanner changes). Tooltips, collection status badges, and vendor filtering now check both `.items` and `.decor` for backward compatibility.

### Database Updates
- **Balen Starfinder** (NPC 255216) — Updated with 46 items and full gold pricing, corrected coords and faction
- **Argan Hammerfist** (NPC 255218) — Updated with 13 items and full gold pricing, corrected coords and faction
- **Ta'sam** (NPC 235314) — Added 1 Resonance Crystal item (Cartel Collector's Cage)
- **Om'sirik** (NPC 235252) — Added 12 Resonance Crystal items (K'areshi pipes, portal, warp platform/cannon)

---

## [1.1.0] - 2026-02-03 — The "Help Us Build the Database" Update

### Added
- **Welcome Screen** — First-run onboarding popup; re-open with `/hs welcome`
- **V2 Vendor Export** — Enhanced format with full pricing data (gold, currencies, item costs)
- **Differential Export** — Timestamp-based filtering; only exports vendors scanned since last export
- **Source Data System** — Quest, achievement, profession, and drop source lookups
- **Enhanced Tooltips** — Decor tooltips now show source info and cost when available (WIP)
- **Vendor Name Mapping** — Cross-references C_HousingCatalog source names with VendorDatabase
- New commands: `/hs welcome`, `/hs exportall`, `/hs clearscans`

### Fixed
- **Vendor scanning not capturing prices** — Migrated from deprecated `GetMerchantItemInfo()` to `C_MerchantFrame.GetItemInfo()` (WoW 11.0+)
- **Scan timing issues** — Scans now wait for `MERCHANT_UPDATE` with retry logic before capturing
- **Lua 5.1 compatibility** — Replaced `goto` with flag pattern in ExportImport
- **WelcomeFrame not auto-showing** — Added missing `Initialize()` call in `OnEnable`

### Changed
- Item format now supports plain integers or tables with embedded cost data
- All modules updated for new item format (CatalogScanner, Validation, VendorTracer, VendorMapPins)
- Export dialog offers a single unified export option (legacy V1 export removed)
- Vendor records now store faction, itemCount, decorCount, and full cost data per item

### Database Updates
- Major VendorDatabase refresh with populated item lists and corrected coordinates
- Added vendor name cross-referencing for better source detection

### Previous Unreleased
- Item-by-item catalog scanning (replaces broken category enumeration)
- Multi-zone minimap pin coverage (HandyNotes-style behavior)
- `floatOnEdge` parameter for minimap pins
- CatalogScanner now finds owned items (was returning 0 due to API limitations)
- Minimap pins now show vendors in adjacent zones
- Event method corrected: `TriggerEvent` → `Fire`
- CatalogScanner uses `GetCatalogEntryInfoByItem` instead of category enumeration
- Minimap pin frames parented to UIParent instead of Minimap



