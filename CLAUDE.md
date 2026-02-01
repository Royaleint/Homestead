# Homestead - WoW Housing Addon

A housing collection, vendor, and progress tracker for World of Warcraft Retail (12.0.0+).

## Quick Reference

```bash
# In-Game Commands
/hs              # Toggle main UI
/hs debug        # Toggle debug mode
/hs scan         # Refresh ownership cache
/hs refreshmap   # Refresh world map pins
/hs corrections  # Show NPC ID corrections found
/hs debugglobal  # Debug SavedVariables data
/hs vendors      # List scanned vendors

# Testing
/reload          # Reload UI to test changes
```

## Critical Rules

### 1. Event System: Custom vs WoW Events
`HA.Events` is for inter-module callbacks ONLY. It does NOT hook WoW events.

```lua
-- WRONG:
HA.Events:RegisterCallback("MERCHANT_SHOW", function() end)

-- CORRECT: WoW events need a dedicated frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:SetScript("OnEvent", function(self, event, ...) end)

-- CORRECT: Inter-module events use HA.Events
HA.Events:RegisterCallback("OWNERSHIP_UPDATED", function() end)
HA.Events:Fire("OWNERSHIP_UPDATED")
```

### 2. API Function Caching
Don't cache WoW API functions at file load time—they may not exist yet.

```lua
-- WRONG:
local GetMerchantNumItems = GetMerchantNumItems

-- CORRECT:
local numItems = _G.GetMerchantNumItems()
```

### 3. SavedVariables
- Data persists only on proper logout or `/reload`
- Use `db.global` for cross-character data (ownedDecor, scannedVendors, npcIDCorrections)
- Use `db.profile` for per-character settings

### 4. Original Code Only
No code copied from other addons (CanIMogIt, Housing Vendor, Home Bound, etc.).

### 5. Map/Minimap Icons - HEREBERAGONS ONLY
Never write custom minimap positioning code. Always use HereBeDragons-Pins-2.0.

```lua
-- WRONG: Raw minimap manipulation
local icon = CreateFrame("Frame", nil, Minimap)

-- CORRECT: HereBeDragons minimap pins (HandyNotes style)
local frame = CreateFrame("Frame", nil, UIParent)  -- Parent to UIParent, not Minimap
HBDPins:AddMinimapIconMap(ref, frame, mapID, x, y, 
    true,   -- showArrow (elevation indicator)
    true)   -- floatOnEdge (stays at edge when far)
```

Minimap pins require multi-zone coverage. See `VendorMapPins:RefreshMinimapPins()` for the pattern.

### 6. Housing Catalog API Limitations
```lua
-- DON'T USE (internal Blizzard only):
CreateCatalogSearcher()
GetCatalogSubcategoryInfo()  -- Returns nil/empty

-- DO USE:
C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, true)  -- Ownership checks
C_HousingCatalog.GetDecorTotalOwnedCount()                  -- Total owned count
```

**Critical bug**: API returns stale/incorrect data after `/reload` until Housing UI opens.
**Workaround**: Always check persistent cache (`db.global.ownedDecor`) first, API second.

## Architecture

```
Framework: Ace3 (AceAddon, AceDB, AceEvent, AceConsole, AceConfig)
Map Pins:  HereBeDragons-Pins-2.0
Target:    WoW Retail 12.0.0+ (Midnight)
```

### File Load Order (from TOC)
```
Libs → embeds.xml → Locale → Core (core, constants, events, cache) →
Data (DecorData, VendorDatabase, VendorData) → Utils →
Modules (DecorTracker, CatalogScanner, VendorTracer, VendorScanner) →
Overlay (overlay, Containers, Merchant, Tooltips) →
UI (MainFrame, VendorMapPins, Options)
```

### Module Creation Pattern
1. Create module table: `local MyModule = {}` then `HA.MyModule = MyModule`
2. Implement `Initialize()` function
3. WoW events: Create dedicated frame with `RegisterEvent()`
4. Inter-module events: Use `HA.Events:Fire()` / `HA.Events:RegisterCallback()`
5. Register with addon: `HA.Addon:RegisterModule("MyModule", MyModule)`
6. Add to TOC in correct load order position

### Data Flow
```
Wowhead scrape ──→ VendorDatabase.lua (static)
                          ↓
In-game scanner ──→ scannedVendors (SavedVariables)
                          ↓
              VendorData.lua (unified access)
                          ↓
              UI modules query via HA.VendorData:GetVendorsInMap()
```

## Data Structures

### Vendor Schema
```lua
{
    npcID = number,           -- REQUIRED, primary key
    name = string,            -- REQUIRED
    mapID = number,           -- REQUIRED for map pins
    zone = string,            -- Display name
    coords = {x=0.xx, y=0.xx}, -- Normalized 0-1 (NOT 0-100)
    faction = "Alliance"|"Horde"|"Neutral",
    items = {},               -- Populated by scanner
    notes = string,           -- Optional
}
```

### Ownership Cache
```lua
db.global.ownedDecor[itemID] = {
    name = string,
    firstSeen = timestamp,
    lastSeen = timestamp,
}
```

## Known Blizzard API Bugs

1. **Ownership Detection**: Items in storage return `entrySubtype = 1` (Unowned) incorrectly
2. **Stale Data After Reload**: API returns wrong data until Housing Catalog UI is opened
3. **Workaround**: Persistent cache in `db.global.ownedDecor`, updated when catalog is open

## What NOT To Do

- Don't use `HA.Events:RegisterCallback("WOW_EVENT")` — that's for inter-module only
- Don't cache WoW API functions at file load time
- Don't enumerate categories via `GetCatalogSubcategoryInfo` — returns nil
- Don't parent minimap pin frames to Minimap — use UIParent, let HBD position them
- Don't trust ownership API after `/reload` — check cache first
- Don't use coordinates as 0-100 — always normalized 0-1

## Key Modules

| Module | Purpose |
|--------|---------|
| `VendorScanner` | Auto-scans vendors on MERCHANT_SHOW, detects NPC ID mismatches |
| `VendorMapPins` | World map + minimap pins via HereBeDragons |
| `CatalogScanner` | Item-by-item ownership scanning (workaround for API limitations) |
| `DecorTracker` | Core ownership detection logic |
| `VendorData` | Unified access to vendor database + scanned data |

## Development Status

See `DEVELOPMENT_PLAN.md` for phases and `CHANGELOG.md` for history.

## Task Management

- Read TODO.md at session start
- Update TODO.md at session end
- Summarize: completed, discovered, next steps

## Resources

- [Warcraft Wiki API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)
- [Blizzard UI Source](https://github.com/Gethe/wow-ui-source)
- [HereBeDragons](https://github.com/Nevcairiel/HereBeDragons)
- In-game: `/api C_HousingCatalog` for current API functions
