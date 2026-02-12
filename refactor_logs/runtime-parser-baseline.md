# Runtime Parser — Pre-Implementation Baseline

**Date:** 2026-02-12
**Branch:** feature/runtime-parser (created from main @ 8dbe07e)
**Addon Version:** v1.3.1

## Luacheck Baseline

- **Full repo:** 1116 warnings / 3 errors in 85 files
- **Excluding scripts/:** 380 warnings / 3 errors in 78 files
- Errors are in non-addon files (missing_vendors.lua etc.), not in addon .lua files

## db.global Default Keys (constants.lua)

```lua
global = {
    vendorVisited = {},
    dyeRecipesKnown = {},
    ownedDecor = {},           -- [itemID] = { recordID, lastSeen, name }
    scannedVendors = {},       -- [npcID] = { npcID, name, mapID, coords, decor, ... }
    noDecorVendors = {},       -- [npcID] = { name, confirmedAt, itemCount, inDatabase, scanConfidence, confirmCount }
    enableRequirementScraping = true,
    developerMode = false,     -- TO BE REMOVED in Phase 6 cleanup
    npcIDCorrections = {},     -- [vendorName] = { oldID, newID, correctedAt }
}
```

## db.profile Default Keys (constants.lua)

```lua
profile = {
    enabled = true,
    debug = false,
    minimap = { hide = false },
    overlay = {
        enabled = true,
        showOnBags = true,
        showOnBank = true,
        showOnMerchant = true,
        showOnAuctionHouse = true,
        showOnHousingCatalog = true,
        iconSize = 14,
        iconAnchor = "TOPLEFT",
    },
    tooltip = {
        enabled = true,
        showOwned = true,
        showSource = true,
        showQuantity = false,
        showDyeSlots = true,
    },
    vendorTracer = {
        showMapPins = true,
        showMinimapPins = true,
        useTomTom = true,
        useNativeWaypoints = true,
        autoWaypoint = false,
        showVendorDetails = true,
        showMissingAtVendor = true,
        navigateModifier = "shift",
        showOppositeFaction = true,
        pinColorPreset = "default",
        pinColorCustom = { r = 1, g = 1, b = 1 },
        pinIconSize = 20,
        minimapIconSize = 12,
        showPinCounts = true,
    },
    endeavourTracker = {
        enabled = true,
        showProgress = true,
    },
    export = {
        includeCharacterInfo = true,
        includeDecorList = true,
        includeDyeList = true,
        includeEndeavours = true,
        includeVendorsVisited = true,
    },
}
```

## Approved SV Changes (Plan)

- **db.global +parsedSources** = {} — [itemID] = { sources, recordID, lastParsed, sourceHash }
- **db.global +vendorNameByLocale** = {} — [locale] = { [normalizedName] = {npcID, scanCount, lastSeen} }
- **db.profile +useParsedSources** = false — Gate parsed sources in tooltip display
- **db.global -developerMode** — Removed in Phase 6 cleanup
