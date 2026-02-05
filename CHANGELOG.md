# Homestead Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

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
- Export dialog offers V2 (recommended) and V1 (legacy) options
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

---

## [0.3.0-alpha] - 2025-01-XX

### Added
- Vendor Map Pins on world map and minimap
- HereBeDragons integration for accurate pin positioning
- Color-coded pins by faction
- Vendor tooltips with item counts and currency info

### Fixed
- NPC ID auto-correction system working

---

## [0.2.0-alpha] - 2025-01-XX

### Added
- Vendor Scanner auto-captures vendor data on MERCHANT_SHOW
- NPC ID correction detection
- SavedVariables persistence for scanned data
- `/hs corrections` command

---

## [0.1.0-alpha] - 2025-01-XX

### Added
- Initial addon structure with Ace3 framework
- Core module system
- Basic vendor database (187 vendors)
- Options panel
- Minimap button via LibDBIcon
- Slash commands

---

## Version Numbering

- **Major.Minor.Patch**
- Major: Breaking changes or major features
- Minor: New features, backward compatible
- Patch: Bug fixes

## Upgrade Notes

### From 0.2.x to 0.3.x
- No SavedVariables migration needed
- Map pins are new, no action required

### From 0.1.x to 0.2.x
- New SavedVariables structure for scannedVendors
- Old scan data will be lost (expected during alpha)

