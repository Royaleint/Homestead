# Housing Addon - Development Guide

## Project Overview

A World of Warcraft Retail addon for housing/decor completionism tracking. This addon helps players track their decor collection, find vendors selling housing items, track endeavour progress, and manage dye colors.

**IMPORTANT**: All code must be original. No code may be copied or derived from other addons (including CanIMogIt, Housing Vendor, Home Bound, Decor Vendor, etc.).

## Features

1. **Decor Tracking** - Track owned/unowned decor items with overlay icons
2. **Decor Vendor Tracer** - Navigate to vendors selling housing decor items
   - **Click-to-Navigate**: Clicking a decor item automatically shows directions to the vendor
   - **Vendor Info Panel**: Shows all items the vendor sells and required currencies
   - **TomTom Integration**: Optional waypoint support via TomTom addon
   - Uses Blizzard map waypoints as primary, TomTom as optional enhancement
3. **Endeavour Tracker** - Track housing endeavour progress across characters
4. **Decor Color Tracker** - Track dye colors and color variants
5. **Data Export** - Export collection data to external sites (wowdb, etc.)

## Architecture

- **Framework**: Ace3 (AceAddon, AceDB, AceEvent, AceConsole, AceConfig)
- **Pattern**: Module-based with event-driven updates
- **Target**: WoW Retail 11.2.7+ (Housing feature)

## Key WoW APIs

### Decor Collection
- `C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, true)` - Get decor info with ownership
- `C_HousingCatalog.GetDecorTotalOwnedCount()` - Total owned count
- `C_HousingCatalog.CreateCatalogSearcher()` - Search/filter decor
- `C_HousingCatalog.GetCatalogCategoryInfo()` - Categories for browsing

### Dye/Color System
- `C_HousingCustomizeMode.GetRecentlyUsedDyes()` - Recently used dyes
- `C_HousingCustomizeMode.GetPreviewDyesOnSelectedDecor()` - Preview colors

### Endeavours
- `C_NeighborhoodInitiative` - Endeavour task tracking
- Events: `NEIGHBORHOOD_INITIATIVE_UPDATED`, `INITIATIVE_TASK_COMPLETED`

### Housing State
- `C_Housing.GetCurrentHouseInfo()` - Current house details
- `C_Housing.IsInsideHouse()` - Location detection

## File Structure

```
HousingAddon/
├── CLAUDE.md                     # This file
├── HousingAddon.toc              # Addon manifest
├── embeds.xml                    # Ace3 library includes
├── Libs/                         # Ace3 libraries
├── Locale/
│   └── enUS.lua                  # English localization
├── Core/
│   ├── core.lua                  # Addon initialization
│   ├── constants.lua             # Icons, colors, text strings
│   ├── events.lua                # Event system with throttling
│   └── cache.lua                 # Caching layer
├── Data/
│   ├── DecorData.lua             # Decor item data class
│   ├── VendorData.lua            # Vendor locations database
│   ├── DyeData.lua               # Dye/color data class
│   └── EndeavourData.lua         # Endeavour tracking data
├── Modules/
│   ├── DecorTracker.lua          # Core decor collection logic
│   ├── VendorTracer.lua          # Vendor navigation system
│   ├── EndeavourTracker.lua      # Endeavour progress tracking
│   ├── ColorTracker.lua          # Dye collection tracking
│   └── DataExport.lua            # Export data for external sites
├── Overlay/
│   ├── overlay.lua               # Core overlay framework
│   ├── Containers.lua            # Bags/bank overlays
│   ├── Merchant.lua              # Vendor window overlays
│   ├── AuctionHouse.lua          # AH overlays
│   ├── HousingCatalog.lua        # Housing catalog overlays
│   └── Tooltips.lua              # Tooltip enhancements
├── UI/
│   ├── MainFrame.lua             # Main addon window
│   ├── DecorBrowser.lua          # Decor collection browser
│   ├── VendorPanel.lua           # Vendor list/map panel
│   ├── EndeavourPanel.lua        # Endeavour dashboard
│   ├── ColorPanel.lua            # Dye collection panel
│   └── Options.lua               # Settings/configuration
├── Utils/
│   └── waypoints.lua             # Waypoint/navigation utilities
└── Textures/
    └── (overlay icons)
```

## Code Standards

### Performance
- Use `local` variables for frequently accessed globals
- Throttle frame updates (0.1s minimum between updates)
- Cache API responses where appropriate
- Use `C_Timer.After()` for delayed operations

### Naming Conventions
- Addon namespace: `HousingAddon` or `HA`
- Local functions: `camelCase`
- Constants: `UPPER_SNAKE_CASE`
- Class methods: `ClassName:MethodName()`

### Event Handling
- Register events through AceEvent
- Unregister events when not needed
- Use smart event system for UI-heavy operations

### Overlay System
- All overlay code must be original (not derived from any other addon)
- Use `CreateFrame()` for overlay frames
- Hook Blizzard frames with `HookScript` and `hooksecurefunc`
- Implement custom throttling for performance

## Events to Monitor

```lua
-- Housing collection events
"HOUSING_CATALOG_UPDATED"
"HOUSING_DECOR_PLACE_SUCCESS"
"HOUSING_DECOR_REMOVE_SUCCESS"

-- Endeavour events
"NEIGHBORHOOD_INITIATIVE_UPDATED"
"INITIATIVE_TASK_COMPLETED"
"INITIATIVE_COMPLETED"

-- UI events for overlay updates
"BAG_UPDATE"
"MERCHANT_SHOW"
"AUCTION_HOUSE_SHOW"
```

## Slash Commands

- `/ha` or `/housingaddon` - Toggle main UI
- `/ha export` - Export collection data to clipboard
- `/ha vendor [search]` - Search for vendor by name
- `/ha config` - Open options panel

## Testing

1. Test on PTR/Live with housing access (11.2.7+)
2. Verify overlays appear on bags, vendors, AH, housing catalog
3. Check for Lua errors via `/console`
4. Test waypoint creation with and without TomTom
5. Verify SavedVariables persist correctly

## Dependencies

### Required (Embedded)
- LibStub
- CallbackHandler-1.0
- AceAddon-3.0
- AceDB-3.0
- AceEvent-3.0
- AceConsole-3.0
- AceConfig-3.0
- AceConfigDialog-3.0
- LibDataBroker-1.1
- LibDBIcon-1.0

### Optional
- TomTom (enhanced waypoints)
- Auctionator/TSM (AH price data - future)

## SavedVariables

```lua
HousingAddonDB = {
    global = {
        vendorDatabase = {},    -- Cached vendor data
        dyeCollection = {},     -- Known dyes per character
    },
    char = {
        settings = {},
        cache = {},
        endeavourProgress = {},
    },
}
```

## Data Export Format

```lua
ExportData = {
    version = "1.0",
    timestamp = time(),
    character = {name, realm, faction, class},
    decor = {
        collected = {itemID, ...},
        placed = {itemID, ...},
        total = count,
    },
    dyes = {
        owned = {dyeID, ...},
        recipes = {recipeID, ...},
    },
    endeavours = {
        completed = {...},
        progress = {...},
    },
    vendors = {
        visited = {npcID, ...},
    },
}
```
