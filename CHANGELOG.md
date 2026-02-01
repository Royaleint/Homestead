# Homestead Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added
- Item-by-item catalog scanning (replaces broken category enumeration)
- Multi-zone minimap pin coverage (HandyNotes-style behavior)
- `floatOnEdge` parameter for minimap pins

### Fixed
- CatalogScanner now finds owned items (was returning 0 due to API limitations)
- Minimap pins now show vendors in adjacent zones
- Event method corrected: `TriggerEvent` → `Fire`

### Changed
- CatalogScanner uses `GetCatalogEntryInfoByItem` instead of category enumeration
- Minimap pin frames parented to UIParent instead of Minimap

### Technical Notes
- Confirmed Blizzard API bug: `CreateCatalogSearcher()` is internal-only
- Confirmed Blizzard API bug: `GetCatalogSubcategoryInfo()` returns nil
- Confirmed Blizzard API bug: Ownership data stale after `/reload`

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
