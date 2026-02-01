# Homestead Addon - Feature List

A housing collection, vendor, and progress tracker for World of Warcraft Retail (12.0.0+).

---

## Current Features (Implemented)

### 1. Vendor Map Pins
World map and minimap icons showing housing decor vendor locations across all expansions. Pins are color-coded by faction (neutral/Alliance/Horde) and include tooltips with vendor details, currency requirements, and item counts.

### 2. Vendor Database
Comprehensive database of 187 housing decor vendors spanning Classic through Midnight, including:
- Class Order Hall quartermasters (Legion)
- Reputation vendors
- Event/seasonal vendors (Darkmoon Faire, Dreamsurge, Legion Remix, Midnight pre-patch)
- Zone-specific decor specialists

### 3. Vendor Scanner
Automatically scans vendors when you open their merchant window:
- Detects housing decor items for sale
- Auto-corrects NPC ID mismatches (Wowhead data is often wrong)
- Captures vendor coordinates for database updates
- Stores scan data in SavedVariables for cross-character sharing

### 4. NPC ID Correction System
Detects when a vendor's actual NPC ID differs from the database entry (by matching vendor name) and logs corrections. View with `/hs corrections`.

### 5. Decor Tracker
Core ownership detection using `C_HousingCatalog` API with multiple fallback methods to work around Blizzard API bugs:
- Checks `entrySubtype` for ownership status
- Falls back to `numPlaced`, `remainingRedeemable`, `quantity`
- Uses persistent cache in `db.global.ownedDecor`

### 6. Catalog Scanner
Bulk ownership scanning that refreshes the ownership cache. Triggered manually with `/hs scan` or automatically when the Housing Catalog UI opens.

### 7. Options Panel
In-game settings via `/hs` or Interface Options:
- Enable/disable overlay icons
- Toggle map pins (world/minimap)
- Show/hide opposite faction vendors
- Debug mode toggle
- Developer tools section

### 8. Minimap Button
LibDBIcon integration for quick access to Homestead options and commands.

### 9. Slash Commands
| Command | Description |
|---------|-------------|
| `/hs` | Toggle main UI / open options |
| `/hs debug` | Toggle debug mode |
| `/hs scan` | Force ownership cache refresh |
| `/hs refreshmap` | Refresh world map pins |
| `/hs corrections` | Show detected NPC ID corrections |
| `/hs debugglobal` | Debug SavedVariables data |

---

## Planned Features (Not Yet Implemented)

### 10. Bag/Merchant Overlay Icons
Visual indicators on items in bags and merchant windows showing:
- ✅ Green check = Already owned
- 🏠 House icon = Housing decor item
- Number badge = Quantity owned

### 11. Tooltip Enhancements
Additional tooltip lines for housing items showing:
- Ownership status
- Vendor availability info
- "Available from [Vendor Name] in [Zone]"

### 12. Main UI Frame
A dedicated window for browsing:
- Your decor collection progress
- Missing items by source (vendors, quests, drops)
- Vendor list with filtering

### 13. Endeavours Tracking
Track Neighborhood Initiative (daily/weekly) tasks:
- Current objectives and progress
- Favor currency earned
- Rewards available

### 14. Dye/Recipe Tracking
Track known dye recipes for decor customization using `C_HousingCustomizeMode` APIs.

### 15. Export/Import
Export collection data for sharing or backup; import data from other sources.

### 16. TomTom Integration
Set waypoints directly to vendor locations via TomTom addon (optional dependency).

---

## Technical Infrastructure

| Component | Purpose |
|-----------|---------|
| **Ace3 Framework** | Addon structure, database, events, console commands |
| **HereBeDragons** | World map and minimap pin positioning |
| **LibDBIcon** | Minimap button |
| **SavedVariables** | Persistent storage (global for collection, profile for settings) |

---

## File Structure

```
Homestead/
├── Core/
│   ├── core.lua           # Main addon initialization
│   ├── constants.lua      # Default settings, enums
│   ├── events.lua         # Inter-module event system
│   └── cache.lua          # Ownership cache management
├── Data/
│   ├── DecorData.lua      # Decor item definitions
│   ├── VendorDatabase.lua # Vendor locations & items (187 vendors)
│   └── VendorData.lua     # Vendor data loader
├── Utils/
│   └── utils.lua          # Shared utility functions
├── Modules/
│   ├── DecorTracker.lua   # Ownership detection logic
│   ├── CatalogScanner.lua # Bulk ownership scanning
│   ├── VendorTracer.lua   # Vendor discovery system
│   └── VendorScanner.lua  # Auto-scan on MERCHANT_SHOW
├── Overlay/
│   ├── overlay.lua        # Overlay system base
│   ├── Containers.lua     # Bag overlay icons
│   ├── Merchant.lua       # Merchant window overlay
│   └── Tooltips.lua       # Tooltip enhancements
├── UI/
│   ├── MainFrame.lua      # Main UI window
│   ├── VendorMapPins.lua  # World/minimap pins
│   └── Options.lua        # Settings panel
├── Libs/                  # Embedded libraries
├── Locale/                # Localization files
├── CLAUDE.md              # AI assistant instructions
├── DEVELOPMENT_PLAN.md    # Roadmap & technical notes
├── FEATURES.md            # This file
└── Homestead.toc          # Addon manifest
```
