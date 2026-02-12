# Homestead - WoW Housing Addon

A housing collection, vendor, and progress tracker for World of Warcraft Retail (12.0.1+).
Current version: v1.3.1

## Quick Reference

```bash
/hs              # Toggle main UI
/hs debug        # Toggle debug mode
/hs scan         # Refresh ownership cache
/hs refreshmap   # Refresh world map pins
/hs corrections  # Show NPC ID corrections found
/hs debugglobal  # Debug SavedVariables data
/hs vendors      # List scanned vendors
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
Don't cache WoW API functions at file load time — they may not exist yet.
Upvaluing Lua standard library (`table.insert`, `math.floor`, `pairs`) is fine.

```lua
-- WRONG:
local GetMerchantNumItems = GetMerchantNumItems

-- CORRECT: Call directly when needed
local numItems = GetMerchantNumItems()
```

### 3. SavedVariables
- Data persists only on proper logout or `/reload`
- Use `db.global` for cross-character data (ownedDecor, scannedVendors, npcIDCorrections)
- Use `db.profile` for per-character settings

### 4. Original Code Only
No code copied from other addons (CanIMogIt, Housing Vendor, Home Bound, etc.).

### 5. Map/Minimap Icons — HereBeDragons ONLY
Never write custom minimap positioning code. Always use HereBeDragons-Pins-2.0.
Parent pin frames to UIParent, not Minimap. Coordinates always normalized 0-1.
Don't mix static `SetScale()` with HBD's `SetScalingLimits()` — let HBD handle zoom.

### 6. Housing Catalog API — Taint & Stale Data
Most C_HousingCatalog functions are `AllowedWhenUntainted` — addon code gets nil/errors.

```lua
-- SAFE (addons CAN call):
C_HousingCatalog.CreateCatalogSearcher()
C_HousingCatalog.GetDecorTotalOwnedCount()
C_HousingCatalog.GetDecorMaxOwnedCount()
searcher:GetCatalogSearchResults()
searcher:RunSearch()
C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, true)   -- Works! (string, number, or item link)
C_HousingCatalog.GetCatalogEntryInfoByRecordID(1, decorID, true) -- Works! (direct decorID lookup)

-- TAINTED (returns nil from addon code):
C_HousingCatalog.GetCatalogEntryInfo(entryID)       -- Has sourceText but unreachable
-- All Set*/Toggle* methods on searcher are tainted
```

**Stale data after /reload**: `quantity` and `numPlaced` return 0 for owned items until Housing Catalog UI is opened.
**Workaround**: `firstAcquisitionBonus == 0` reliably detects ownership in ALL contexts (post-reload, any zone).
Also check persistent cache (`db.global.ownedDecor`) as backup.
See `HOUSING_API_REFERENCE.md` for full API surface (343 functions, 125 events).

**New in 12.0.1** (not yet taint-tested):
- `C_HousingCatalog.GetMarketInfoForDecor` — market info for decorations
- `C_HousingLayout.GetNumFloors` — floor count for layouts
- `C_CatalogShop.BulkRefundDecors` / `GetVCProductInfos` / `FindBestCurrencyProductForNeededAmount`

## Lessons Learned (Common Mistakes)

- `SetDesaturated(true)` before `SetVertexColor()` for accurate tinting on colored atlases
- `SetAtlas(name, false)` — `true` overrides `SetSize()` with atlas native dimensions
- Local functions must be defined before callers in Lua 5.1 (no forward references)
- `HOUSING_DECOR_REMOVED` not `REMOVE_SUCCESS`; `HOUSING_STORAGE_UPDATED` not `CATALOG_UPDATED`
- Lua 5.1: no `goto`, no bitwise operators (use `bit.band`/`bit.bor`), `#` undefined on sparse tables
- After modifying `scannedVendors`, always rebuild `ScannedByItemID` index AND call `InvalidateAllCaches()`
- Profile settings are nested: `profile.vendorTracer.showVendorDetails`, not `profile.showVendorDetails`
- Alias system resolves at scan time only (VendorScanner); runtime lookups use canonical NPC IDs
- `vendor.npcID` is stamped once in `VendorDatabase:BuildIndexes()` — query functions don't set it
- Dual-format items: use `VendorData.UnpackItem(item)` — returns `itemID, cost`; don't inline `type(item) == "table"` checks
- `GameTooltipTemplate` is required for custom hidden tooltips that call `SetMerchantItem()` in 12.0+
- `scanComplete` field doesn't exist; use `scanConfidence == "confirmed"` for hide logic
- `entrySubtype` is nil from addon context — not usable for ownership detection
- Refactoring and behavior changes must be in separate commits (see REFACTOR_CONTRACT.md)
- See `WOW_ADDON_PATTERNS.md` for comprehensive Lua/WoW development patterns

## Architecture

```
Framework: Ace3 (AceAddon, AceDB, AceEvent, AceConsole, AceConfig)
Map Pins:  HereBeDragons-Pins-2.0
Target:    WoW Retail 12.0.1+ (Midnight pre-patch)
TOC:       120001
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

### V2 Export Format
Vendor export data format used by `/hs export` command (see ExportImport.lua:339-371).

**Format:**
```
V    npcID    name    mapID    x    y    faction    lastScanned    itemCount    decorCount
I    npcID    itemID    name    price    costData
```

**Vendor Line Fields:**
- `itemCount`: Total merchant items (including non-housing items)
- `decorCount`: Housing decor items only (subset of itemCount)
- `lastScanned`: Unix timestamp of last scan
- `coords`: Normalized 0-1 (not 0-100)

**Item Line Fields:**
- `price`: In copper (1,000,000 copper = 100 gold)
- `costData`: Format `c3363:100,i12345:5,nHonor:500`
  - `c` prefix: Currency by ID (e.g., c3363 = Kej)
  - `i` prefix: Item cost by ID
  - `n` prefix: Currency by name (when ID unavailable)

**Example:**
```
V    255278    Gronthul    2351    0.5410    0.5907    Alliance    1770251675    59    59
I    255278    244662    Closed Leather Curtains    500000
I    255278    250094    Empty Orgrimmar Bathtub    750000
I    255278    250231    Silver Hand Banner    0    c1220:500
```

## Known Blizzard API Behaviors

1. **Taint on Catalog Functions**: Most `GetCatalogEntryInfo*` are `AllowedWhenUntainted` — addon code gets nil/errors
2. **Stale Data After Reload**: API returns wrong data until Housing Catalog UI is opened. Use persistent cache first.
3. **Ownership Detection**: `entrySubtype = 1` (Unowned) may be correct when calling from tainted context

## Housing Events Worth Monitoring
```lua
HOUSING_STORAGE_UPDATED              -- Storage changed
HOUSING_STORAGE_ENTRY_UPDATED        -- Specific entry changed (has entryID)
HOUSE_DECOR_ADDED_TO_CHEST           -- Decor returned (has decorGUID, decorID)
HOUSING_DECOR_PLACE_SUCCESS          -- Decor placed
HOUSING_DECOR_REMOVED                -- Decor removed from world
MERCHANT_SHOW / MERCHANT_UPDATE / MERCHANT_CLOSED  -- Vendor lifecycle
```

## Key Modules

| Module | Purpose |
|--------|---------|
| `VendorScanner` | Auto-scans vendors on MERCHANT_SHOW, detects NPC ID mismatches |
| `VendorMapPins` | World map + minimap pins via HereBeDragons |
| `CatalogScanner` | Item-by-item ownership scanning (API limitation workaround) |
| `DecorTracker` | Core ownership detection logic |
| `VendorData` | Unified access to vendor database + scanned data |

## Git Conventions

- Co-author: `Co-Authored-By: Royaleint and Claude Code` (no email)
- GitHub account restored — pushes OK when requested

## Session Workflow

- **Start**: Read `TODO.md` and `CHANGELOG.md` to understand current state
- **During**: Update `TODO.md` as tasks are completed or discovered
- **End**: Update `TODO.md` with session summary; update `CHANGELOG.md` if version-worthy changes were made
- Review `CHANGELOG.md` regularly to avoid duplicating completed work or reopening resolved issues

## Global Namespace Rules
- Only 8 globals are permitted (see AUDIT_REPORT.md Global Allowlist)
- Do NOT add new _G writes without updating the allowlist
- All new frames should be unnamed unless UISpecialFrames requires it
- Run luacheck before releases (.luacheckrc is in project root)

## Refactoring
All refactoring work must follow REFACTOR_CONTRACT.md in the project root.
Do not begin any refactor without reading that document first.

## Resources

- [Warcraft Wiki API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)
- [Townlong Yak FrameXML](https://www.townlong-yak.com/framexml/live) — Authoritative API source
- [Blizzard UI Source](https://github.com/Gethe/wow-ui-source)
- [HereBeDragons](https://github.com/Nevcairiel/HereBeDragons)
- `HOUSING_API_REFERENCE.md` — Full Housing API (343 functions, 125 events, taint analysis)
- `WOW_ADDON_PATTERNS.md` — Comprehensive WoW/Lua development patterns reference
