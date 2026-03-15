# Housing Catalog API Constraints Reference

> **See also:**
> - `Home_Dev/reference/HOUSING_API_REFERENCE.md` — Full in-game API reference (819 lines): all namespaces, taint status, events, enums, field dumps, test results
> - `Home_Dev/reference/BLIZZARD_WEB_API_AND_DATA_STRATEGY.md` — Blizzard web API endpoints, export pipeline, combined data sources, strategic analysis
> - `.claude/skills/homestead/known-patterns.md` — Promoted project-specific
>   findings and gotchas

## Taint System Overview

WoW's taint system prevents addon code from calling certain "secure" functions.
The Housing Catalog API is heavily affected — most catalog browsing functions
are marked `AllowedWhenUntainted`, meaning they work in Blizzard's UI code
but return nil or error when called from addon context.

## Complete Function Classification

### SAFE — Addons Can Call These

```lua
-- Searcher creation and execution
C_HousingCatalog.CreateCatalogSearcher()
searcher:GetCatalogSearchResults()
searcher:RunSearch()

-- Global counts
C_HousingCatalog.GetDecorTotalOwnedCount()
C_HousingCatalog.GetDecorMaxOwnedCount()

-- Item-based lookup (PRIMARY METHOD for addons)
C_HousingCatalog.GetCatalogEntryInfoByItem(itemIdentifier, includeOwnership)
-- Accepts: itemID (number), item name (string), or item link (string)
-- All three input formats produce identical results

-- DecorID-based lookup (CONFIRMED WORKING from addon code)
C_HousingCatalog.GetCatalogEntryInfoByRecordID(1, decorID, includeOwnership)
-- First arg is always 1 (catalog type)
-- 7/8 tested decorIDs returned valid data
-- decorID 4903 was invalid; 2241 mapped to wrong item (Vamoose data errors)
```

### TAINTED — Return nil from Addon Code

```lua
C_HousingCatalog.GetCatalogEntryInfo(entryID)
-- This HAS sourceText data but is unreachable from addon context

-- All filter/toggle methods on searcher objects
searcher:SetSearchText()        -- Tainted
searcher:SetCategoryFilter()    -- Tainted
searcher:ToggleOwnedFilter()    -- Tainted
-- etc.
```

### NEW IN 12.0.1 (Not Yet Taint-Tested)

```lua
C_HousingCatalog.GetMarketInfoForDecor    -- Market info for decorations
C_HousingLayout.GetNumFloors              -- Floor count for layouts
C_CatalogShop.BulkRefundDecors
C_CatalogShop.GetVCProductInfos
C_CatalogShop.FindBestCurrencyProductForNeededAmount
C_HousingPhotoSharing.*                   -- 8 photo sharing functions (not relevant)
```

## Ownership Detection

### The Reliable Method: firstAcquisitionBonus

```lua
local info = C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, true)
if info then
    if info.firstAcquisitionBonus == 0 then
        -- OWNED: Player has acquired this item
    else
        -- UNOWNED: firstAcquisitionBonus > 0
    end
end
```

This works in ALL contexts:
- Immediately after `/reload`
- In any zone (not just housing)
- Without Housing Catalog UI being open
- On first login

### Why Other Fields Fail

| Field | Problem |
|-------|---------|
| `quantity` | Returns 0 after `/reload` until Housing UI opened |
| `numPlaced` | Same stale-data issue as quantity |
| `entrySubtype` | Returns nil from addon context entirely |
| `entrySubtype == 1` | May indicate "Unowned" but unreliable from tainted context |

### Fallback Chain

1. Call `GetCatalogEntryInfoByItem` → check `firstAcquisitionBonus`
2. If API returns nil → check persistent cache `db.global.catalogItems[itemID]`
3. If cache miss → item ownership unknown (not necessarily unowned)

### Achievement-Gated Items

Some items return nil from `GetCatalogEntryInfoByItem` despite being in the
Housing Catalog. These are typically gated behind achievements the player
hasn't completed.

Workaround: tooltip fallback using `TooltipDataProcessor` to detect "Housing Decor"
text when the API won't confirm ownership.

```lua
-- DO NOT use GameTooltipTemplate with SetMerchantItem() — this taints
-- GameTooltipMoneyFrame and breaks the merchant UI. Use TooltipDataProcessor
-- or C_TooltipInfo instead. See commit f0aef71 for the taint removal.
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if tooltip == GameTooltip then
        -- Check tooltip lines for "Housing Decor" text
    end
end)
```

## Stale Data After /reload

The core problem: after `/reload`, the Housing Catalog API returns stale
(often zero) values for `quantity` and `numPlaced` until the player manually
opens the Housing Catalog UI in-game.

Homestead works around this with:
1. `firstAcquisitionBonus` — reliable in all contexts
2. Persistent ownership cache in SavedVariables
3. Aggressive caching when fresh data IS available
4. `RequestScan()` with debouncing to avoid hammering the API

## sourceText — The Locked Treasure

`C_HousingCatalog.GetCatalogEntryInfo(entryID)` returns a `sourceText` field
that contains human-readable source information ("Sold by Vendor Name",
"Quest: Quest Name", etc.). This would be extremely valuable for automated
source detection.

However, this function is tainted and returns nil from addon code. The
sourceText parser system (see `references/sourcetext-parser.md`) is designed
to work around this by capturing sourceText through alternative means.

### sourceText Format (When Accessible)

- `|n` separates fields within a block
- `|n|n` separates blocks
- `|Hcurrency:ID|h` hyperlinks for currencies
- No NPC hyperlinks in vendor references
- Two-tier parsing: structural (all locales) + typed (enUS/enGB only)

## Housing Events

Events that Homestead monitors:

```lua
HOUSING_STORAGE_UPDATED              -- Storage changed
HOUSING_STORAGE_ENTRY_UPDATED        -- Specific entry changed (has entryID)
HOUSE_DECOR_ADDED_TO_CHEST           -- Decor returned (has decorGUID, decorID)
HOUSING_DECOR_PLACE_SUCCESS          -- Decor placed
HOUSING_DECOR_REMOVED                -- Decor removed from world (NOT "REMOVE_SUCCESS")
MERCHANT_SHOW / MERCHANT_UPDATE / MERCHANT_CLOSED  -- Vendor lifecycle
```

All housing events are coalesced through `RequestScan()` with a 1-second
debounce to prevent scan storms.

## API Test Results (Feb 11, 2026)

Tested across 4 contexts:

1. **Number vs String input**: All 3 input formats work identically for `GetCatalogEntryInfoByItem`
2. **GetCatalogEntryInfoByRecordID**: WORKS from addon code (7/8 decorIDs valid). NOT tainted.
3. **firstAcquisitionBonus**: CONFIRMED reliable in ALL contexts post-reload
4. **Vamoose decorID data**: Has errors (2/8 tested wrong) — always validate external decorID data
