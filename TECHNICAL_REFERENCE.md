# Homestead Technical Reference

Detailed technical documentation for Homestead addon development.

---

## Data Source Tracking

### Unified Item Info Schema

When returning item information, include source metadata for transparency:

```lua
-- DecorDatabase:GetItemInfo(itemID) should return:
{
    itemID = number,
    name = "Item Name",
    sources = {
        {
            type = "vendor",           -- vendor/achievement/quest/reputation/drop/addon/unknown
            sourceID = 219318,         -- npcID, achievementID, questID, factionID, or nil
            sourceName = "Jorid",      -- Human-readable name
            sourceZone = "Dornogal",   -- Where to find it (optional)
            confidence = "verified",   -- verified/scraped/imported
            importedFrom = nil,        -- "HousingVendor" if from another addon
        },
        -- Items can have multiple sources
        {
            type = "achievement",
            sourceID = 40123,
            sourceName = "Decorator's Delight",
            confidence = "scraped",
        },
    },
}
```

### Source Types

| Type | sourceID | Description |
|------|----------|-------------|
| `vendor` | npcID | Purchasable from vendor |
| `achievement` | achievementID | Achievement reward |
| `quest` | questID | Quest reward |
| `reputation` | factionID | Reputation vendor |
| `drop` | creatureID or nil | World/dungeon drop |
| `crafted` | recipeID | Player-crafted |
| `addon` | nil | Imported from another addon |
| `unknown` | nil | Source not yet identified |

### Confidence Levels

| Level | Meaning |
|-------|---------|
| `verified` | Confirmed in-game by developer or trusted user |
| `scraped` | From Wowhead/external source, not verified |
| `imported` | From user export or other addon |
| `user-reported` | Community submission, unverified |

### Importing from Other Addons

```lua
-- Check for other addon's SavedVariables after ADDON_LOADED
local function ImportFromOtherAddons()
    -- Housing Vendor
    if HousingVendorDB and HousingVendorDB.ownedItems then
        for itemID, data in pairs(HousingVendorDB.ownedItems) do
            ImportItem(itemID, {
                type = "addon",
                sourceName = "Housing Vendor",
                confidence = "imported",
                importedFrom = "HousingVendor",
                importedAt = time(),
            })
        end
    end
    
    -- Home Bound (achievement data)
    if HomeBoundDB and HomeBoundDB.achievements then
        -- Cross-reference their achievement mappings
    end
end
```

---

## Housing Catalog API

### Working Functions

```lua
-- Get total owned/max counts
C_HousingCatalog.GetDecorTotalOwnedCount() : number
C_HousingCatalog.GetDecorMaxOwnedCount() : number

-- Get category list (returns array of category IDs)
C_HousingCatalog.SearchCatalogCategories("") : table

-- Get item info by itemLink (RELIABLE - use this)
C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, includeOwnership) : CatalogEntryInfo

-- Get category info (limited data)
C_HousingCatalog.GetCatalogCategoryInfo(categoryID) : CatalogCategoryInfo
```

### Broken/Internal Functions

```lua
-- DO NOT USE - Internal Blizzard only
C_HousingCatalog.CreateCatalogSearcher() : userdata (unusable)

-- DO NOT USE - Returns nil
C_HousingCatalog.GetCatalogSubcategoryInfo(subcategoryID) : nil
```

### CatalogEntryInfo Structure

```lua
{
    name = string,              -- Item name
    itemID = number,            -- Item ID
    quantity = number,          -- Owned count (unreliable after /reload)
    numPlaced = number,         -- Currently placed count
    remainingRedeemable = number,
    entryID = {
        entrySubtype = number,  -- See enum below
        recordID = number,
    },
    -- ... other fields
}
```

### HousingCatalogEntrySubtype Enum

```lua
Enum.HousingCatalogEntrySubtype = {
    Invalid = 0,
    Unowned = 1,           -- API returns this incorrectly for stored items
    OwnedModifiedStack = 2,
    OwnedUnmodifiedStack = 3,
}

-- Ownership check:
local isOwned = (entrySubtype >= 2) or (quantity > 0) or (numPlaced > 0)
```

### API Bug Details

**Bug**: Items in decor storage return `entrySubtype = 1` (Unowned) and `quantity = 0`.

**Workaround**: 
1. Cache ownership in SavedVariables when API returns correct data
2. API only returns correct data when Housing Catalog UI is open
3. Always check cache before API
4. Trigger scan when `Blizzard_HousingDashboard` addon loads

---

## Map API Reference

### Get Current Map

```lua
local mapID = C_Map.GetBestMapForUnit("player")
local mapInfo = C_Map.GetMapInfo(mapID)
-- mapInfo.name, mapInfo.mapType, mapInfo.parentMapID
```

### Get Player Position

```lua
local position = C_Map.GetPlayerMapPosition(mapID, "player")
if position then
    local x, y = position:GetXY()  -- Normalized 0-1
end
```

### Map Types

```lua
Enum.UIMapType = {
    Cosmic = 0,
    World = 1,
    Continent = 2,
    Zone = 3,
    Dungeon = 4,
    Micro = 5,
    Orphan = 6,
}
```

### HereBeDragons Pin API

```lua
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

-- Add world map pin
HBDPins:AddWorldMapIconMap(
    reference,      -- String identifier for your pins
    frame,          -- The icon frame
    mapID,          -- uiMapID
    x, y,           -- Normalized 0-1 coordinates
    showFlag,       -- HBD_PINS_WORLDMAP_SHOW_*
    frameLevel      -- Optional frame level
)

-- Add minimap pin (with edge behavior)
HBDPins:AddMinimapIconMap(
    reference,      -- String identifier
    frame,          -- The icon frame (parent should be UIParent)
    mapID,          -- uiMapID where pin is located
    x, y,           -- Normalized coordinates
    showArrow,      -- true = show direction arrow when out of range
    floatOnEdge     -- true = pin stays at edge when far (HandyNotes style)
)

-- Remove pins
HBDPins:RemoveAllWorldMapIcons(reference)
HBDPins:RemoveAllMinimapIcons(reference)
```

---

## SavedVariables Schema

### File: `HomesteadDB.lua`

```lua
HomesteadDB = {
    global = {
        -- Schema version for migrations
        schemaVersion = 1,
        
        -- First-run tracking
        firstRunComplete = false,
        
        -- Ownership cache (persists across sessions)
        ownedDecor = {
            [itemID] = {
                name = "Item Name",
                firstSeen = 1706640000,  -- Unix timestamp
                lastSeen = 1706726400,
            },
        },
        
        -- Scanned vendor data
        scannedVendors = {
            [npcID] = {
                npcID = 219318,
                name = "Jorid",
                mapID = 2339,
                coords = {x = 0.45, y = 0.52},
                decor = {
                    {
                        itemID = 228912,
                        name = "Cozy Chair",
                        price = 500,
                        currencyType = 0,
                    },
                },
                lastScanned = 1706640000,
                importedFrom = nil,  -- "community" if imported
                importedAt = nil,
            },
        },
        
        -- NPC ID corrections found
        npcIDCorrections = {
            ["Vendor Name"] = {
                oldID = 227392,
                newID = 219318,
                correctedAt = 1706640000,
            },
        },
    },
    
    profiles = {
        ["CharacterName - RealmName"] = {
            -- Per-profile settings
            showMapPins = true,
            showMinimapPins = true,
            showOppositeFaction = false,
            debugMode = false,
            minimapIcon = {
                hide = false,
            },
        },
    },
}
```

### Schema Migration Pattern

```lua
local CURRENT_SCHEMA = 1

function MigrateSchema()
    local db = HA.Addon.db.global
    local version = db.schemaVersion or 0
    
    if version < 1 then
        -- Migration from pre-versioned to v1
        -- Add any data transformations here
        db.schemaVersion = 1
    end
    
    -- Future migrations:
    -- if version < 2 then
    --     -- v1 → v2 migration
    --     db.schemaVersion = 2
    -- end
end
```

---

## Event Reference

### Housing-Related WoW Events

```lua
"HOUSING_CATALOG_UPDATED"        -- Catalog data may have changed
"NEW_HOUSING_ITEM_ACQUIRED"      -- Player acquired new decor
"HOUSING_DECOR_PLACE_SUCCESS"    -- Decor placed
"HOUSING_DECOR_REMOVE_SUCCESS"   -- Decor removed
"ADDON_LOADED"                   -- Check for "Blizzard_HousingDashboard"
```

### Custom Inter-Module Events (HA.Events)

```lua
"OWNERSHIP_UPDATED"   -- Ownership cache was updated
"VENDOR_SCANNED"      -- Vendor scan completed
"REFRESH_MAP_PINS"    -- Map pins need refresh
```

---

## Export/Import Format

### Version 1 Format

```
HOMESTEAD_EXPORT_V1:npcID|name|mapID|x|y|lastScanned|itemCount|itemID1,itemID2,...;nextVendor...
```

**Fields (pipe-delimited per vendor):**
1. npcID (number)
2. name (string, pipes escaped)
3. mapID (number)
4. x coordinate (4 decimal places)
5. y coordinate (4 decimal places)
6. lastScanned (unix timestamp)
7. itemCount (number)
8. itemIDs (comma-separated)

**Vendors separated by semicolons.**

### Example

```
HOMESTEAD_EXPORT_V1:219318|Jorid|2339|0.4500|0.5200|1706640000|3|228912,228913,228914;219400|Kroto|2339|0.5100|0.4800|1706650000|2|229001,229002
```

---

## Debugging

### In-Game Commands

```lua
/hs debug           -- Toggle debug mode
/hs scan            -- Force ownership scan
/hs corrections     -- Show NPC ID corrections
/hs debugglobal     -- Dump SavedVariables
/hs export          -- Export scanned vendors
/hs import          -- Import vendor data
/hs validate        -- Validate database integrity
/hs achievements    -- Show achievement decor stats

/reload             -- Reload UI
/console scriptErrors 1  -- Show Lua errors
```

### API Exploration

```lua
-- List all C_HousingCatalog functions
/run for k,v in pairs(C_HousingCatalog) do print(k, type(v)) end

-- Check API totals
/run print("Owned:", C_HousingCatalog.GetDecorTotalOwnedCount())

-- Test item lookup
/run local i=C_HousingCatalog.GetCatalogEntryInfoByItem("item:228912",true) if i then print(i.name, i.quantity) end
```
