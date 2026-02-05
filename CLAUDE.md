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

### 6. Housing Catalog API — Taint Restrictions
Most C_HousingCatalog functions are tainted (`AllowedWhenUntainted`), meaning addon code
cannot call them directly. This is a Blizzard access restriction, not a bug.

```lua
-- UNTAINTED (addons CAN call):
C_HousingCatalog.CreateCatalogSearcher()    -- Returns a searcher ScriptObject
C_HousingCatalog.GetDecorTotalOwnedCount()  -- Total owned count
C_HousingCatalog.GetDecorMaxOwnedCount()    -- Max storage capacity
C_HousingCatalog.GetAllFilterTagGroups()    -- Category/filter tag info
C_HousingCatalog.GetCartSizeLimit()
C_HousingCatalog.GetFeaturedBundles()
C_HousingCatalog.GetFeaturedDecor()
C_HousingCatalog.HasFeaturedEntries()
C_HousingCatalog.RequestHousingMarketInfoRefresh()
-- Searcher read methods (on instance):
searcher:GetCatalogSearchResults()          -- Returns table<HousingCatalogEntryID>
searcher:GetAllSearchItems()                -- Source collection being searched
searcher:RunSearch()                        -- Execute search
searcher:GetNumSearchItems()
searcher:GetSearchCount()
searcher:IsSearchInProgress()

-- TAINTED (addons CANNOT call — returns nil or errors from addon context):
C_HousingCatalog.GetCatalogEntryInfo(entryID)             -- Has sourceText field!
C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, bool) -- itemID->decor mapping
C_HousingCatalog.GetCatalogEntryInfoByRecordID(type, id, bool)
C_HousingCatalog.GetCatalogCategoryInfo(categoryID)
C_HousingCatalog.GetCatalogSubcategoryInfo(subcategoryID)
-- Searcher filter setters (on instance):
searcher:SetUncollected(bool)               -- Would show unowned items
searcher:SetCollected(bool)
searcher:SetSearchText(string)
searcher:SetFilteredCategoryID(id)
-- (all Set*/Toggle* methods on searcher are tainted)
```

**Key insight**: `HousingCatalogEntryInfo` contains `sourceText` (cstring, non-nilable) which
describes where items come from (e.g., vendor names, quest names). But `GetCatalogEntryInfo()`
is tainted, so we can't access it from addon code. This is why vendor scanning exists.

**Stale data after /reload**: API may return incorrect data until Housing Catalog UI opens.
**Workaround**: Always check persistent cache (`db.global.ownedDecor`) first, API second.

See `HOUSING_API_REFERENCE.md` for the complete API surface (343 functions, 125 events).

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

## Known Blizzard API Behaviors

1. **Taint on Catalog Functions**: Most `GetCatalogEntryInfo*` functions are `AllowedWhenUntainted` — addon code gets nil/errors. If a function "suddenly stops working," check if taint propagated.
2. **Ownership Detection Caveat**: `entrySubtype = 1` (Unowned) may be correct behavior when calling with `tryGetOwnedInfo = false` or from tainted context. Not necessarily a bug.
3. **Stale Data After Reload**: API returns wrong data until Housing Catalog UI is opened
4. **Workaround**: Persistent cache in `db.global.ownedDecor`, updated when catalog is open

## What NOT To Do

- Don't use `HA.Events:RegisterCallback("WOW_EVENT")` — that's for inter-module only
- Don't cache WoW API functions at file load time
- Don't call tainted C_HousingCatalog functions and expect results — check taint list in section 6
- Don't parent minimap pin frames to Minimap — use UIParent, let HBD position them
- Don't trust ownership API after `/reload` — check cache first
- Don't use coordinates as 0-100 — always normalized 0-1

## Housing Events Worth Monitoring
```lua
-- Ownership/Storage (consider registering for real-time cache updates):
HOUSING_STORAGE_UPDATED              -- Storage changed (UniqueEvent)
HOUSING_STORAGE_ENTRY_UPDATED        -- Specific entry changed (has entryID payload)
HOUSE_DECOR_ADDED_TO_CHEST           -- Decor returned (has decorGUID, decorID)

-- Placement tracking:
HOUSING_DECOR_PLACE_SUCCESS          -- Decor placed (has decorGUID, size, isNew, isPreview)
HOUSING_DECOR_REMOVED                -- Decor removed from world

-- Merchant (already in use):
MERCHANT_SHOW                        -- Vendor opened
MERCHANT_UPDATE                      -- Vendor data loaded
MERCHANT_CLOSED                      -- Vendor closed
```

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
- [Townlong Yak FrameXML](https://www.townlong-yak.com/framexml/live) — Authoritative API source (direct Blizzard FrameXML mirror)
- [Blizzard UI Source](https://github.com/Gethe/wow-ui-source)
- [HereBeDragons](https://github.com/Nevcairiel/HereBeDragons)
- `HOUSING_API_REFERENCE.md` — Parsed Housing API docs (343 functions, 125 events, taint analysis)
- In-game: `/api C_HousingCatalog` for current API functions

## Global Namespace Rules
- Only 7 globals are permitted (see AUDIT_REPORT.md Global Allowlist)
- Do NOT add new _G writes without updating the allowlist
- All new frames should be unnamed unless UISpecialFrames requires it
- Run luacheck before releases (.luacheckrc is in project root)
