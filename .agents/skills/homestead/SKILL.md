---
name: homestead
version: "1.6"
author: Royaleint
description: >
  Homestead addon workflows — vendor data maintenance, export processing,
  ownership debugging, zone mapping, and release packaging. Use when editing
  VendorDatabase.lua, processing scan exports, debugging housing API issues,
  updating map pins or zone mappings, or doing vendor validation. Also trigger
  on mentions of Homestead, vendor scanning, ownership cache, NPC ID corrections,
  VendorData, firstAcquisitionBonus, or C_HousingCatalog functions.
  DO NOT use for general WoW addon patterns — use the Studio-Bawr
  wow-addon-dev platform skill instead.
---

# Homestead — Addon Workflows

## Session Workflow

1. **Start**: Run `/start-session` skill — it handles git status, BACKLOG
   In Progress summary, recent changelog, and session brief.
2. **During**: Keep `../Studio-Bawr/BACKLOG.md` updated with current scope and
   next action on In Progress items. Promote new findings to the correct
   long-lived destination: Homestead-specific findings to
   `.claude/skills/homestead/known-patterns.md`, general WoW addon patterns to
   `../Studio-Bawr/.claude/skills/wow-addon-dev/`.
3. **End**: Run `/end-session` skill — it handles COMPLETED.md, skill
   promotion, BACKLOG status updates, changelog check, and release reminders.

## Workflow: Add or Update a Vendor

1. **Verify NPC ID** — Target the NPC in-game: `/run print(UnitGUID("target"))`. Extract the NPC ID from the GUID (6th field, dash-separated). Wowhead NPC IDs are frequently wrong.
2. **Get mapID** — `/run print(C_Map.GetBestMapForUnit("player"))` while standing at the vendor. Use the sub-zone mapID, not the parent zone (e.g., Thunder Totem 652, not Highmountain 650).
3. **Normalize coordinates** — Wowhead coords divide by 100: `45.1, 52.3` → `x=0.451, y=0.523`. Must be 0-1 range.
4. **Edit VendorDatabase.lua** — Find the expansion section, add/update the vendor entry. Required fields: `npcID`, `name`, `mapID`, `zone`, `coords`, `faction`, `expansion`, `items`.
5. **Check zone mapping** — Verify the mapID exists in `Constants.ZoneToContinentMap` (`Core/constants.lua`). If the continent is new, also add it to `Constants.ContinentNames` and `Constants.ContinentToExpansion`.
6. **Handle phased variants** — If the NPC has multiple IDs (phase-dependent), add alias in `VendorDatabase.Aliases[aliasNpcID] = canonicalNpcID`. Remove the duplicate vendor entry.
7. **Stacked/overlapping pins** — If multiple vendors share near-identical coords, offset one slightly (±0.001) so pins don't stack.
8. **Quality check** — Run through the Data Quality Checklist below before committing.

## Workflow: Process Community Export Data

1. **Save export** — User pastes export text into a file in `Home_Dev/scripts/exports/`
2. **Run review** — `python Home_Dev/scripts/compare_exports.py <export_file>` outputs a report-only review
3. **Interpret results** — Primary actions are:
   - **APPLY**: strong candidate for DB change after human review
   - **VERIFY**: requires manual confirmation before any DB edit
   - **BLOCK**: malformed export or unsafe input; stop first
   - **IGNORE**: parsed successfully, no actionable DB change
4. **Review protections** — Delists (`D` lines) are always `VERIFY`. Non-vendor source conflicts are always `VERIFY`. Stale exports downgrade `APPLY` to `VERIFY` unless explicitly overridden.
5. **Cross-reference** — Review against VendorDatabase, EndeavorsData, EventSources, aliases, and non-vendor source tables before touching DB data.
6. **Apply changes** — Update VendorDatabase.lua per the Add/Update Vendor workflow above only after manual confirmation.

For the full pipeline documentation: read `references/vendor-data-pipeline.md`

## Workflow: Debug Ownership Detection

Decision tree when an item shows as unowned or data is wrong:

```
Item shows unowned?
├─ Call GetCatalogEntryInfoByItem(itemID, true)
│  ├─ Returns nil → Item not in Housing Catalog at all
│  │  └─ Check: Is the itemID correct? Is it actually housing decor?
│  ├─ info.firstAcquisitionBonus == 0 → API says OWNED
│  │  └─ Bug is in display code or cache, not detection
│  └─ info.firstAcquisitionBonus > 0 → API says UNOWNED
│     └─ Check db.global.catalogItems[itemID] — cached from CatalogStore?
│        ├─ Cached → Stale cache (player may have refunded)
│        └─ Not cached → Genuinely unowned, or API stale after /reload
│           └─ Has player opened Housing Catalog UI this session?
│              ├─ Yes → Data is fresh, item truly unowned
│              └─ No → quantity/numPlaced may be stale, but
│                      firstAcquisitionBonus should still be reliable
```

Key facts:
- `firstAcquisitionBonus == 0` is the ONLY reliable ownership signal
- `quantity` and `numPlaced` return 0 after `/reload` until Housing UI opens
- `entrySubtype` returns nil from addon context — never use it
- Some achievement-gated items return nil from `GetCatalogEntryInfoByItem` — use tooltip fallback

For full in-game API constraints: read `references/housing-api-constraints.md`
For web API endpoints, export pipeline, and data strategy: read `Home_Dev/reference/BLIZZARD_WEB_API_AND_DATA_STRATEGY.md`
For comprehensive in-game API reference (taint, events, enums, fields): read `Home_Dev/reference/HOUSING_API_REFERENCE.md`

## Workflow: Run Blizzard Web API Export

1. **Update in-game TSV** — Run `/hsdev exportsources all` in-game, save output to `Home_Dev/scripts/exports/in_game_sources.tsv`
2. **Run export** — `powershell -ExecutionPolicy Bypass -File .\Home_Dev\scripts\run_hybrid_export.ps1 -ClientId "..." -ClientSecret "..." -InGameTsv .\Home_Dev\scripts\exports\in_game_sources.tsv`
3. **With discovery** — Add `--discover-recipes --discover-achievements` flags to find crafting/achievement sources (~5 min)
4. **Review outputs** — CSVs in `Home_Dev/scripts/exports/blizzard_latest/` (vendor summary, sources, ownership, recipes, achievements)
5. **Gap analysis** — Compare discovery CSVs against addon Lua source tables to find missing entries

For full pipeline docs, CLI args, matching strategies: read `Home_Dev/reference/BLIZZARD_WEB_API_AND_DATA_STRATEGY.md`

## Workflow: Validate Vendor Data

Validation follows a 3-phase process:
1. **Hub-First Discovery** — Fetch housing.wowdb.com/vendors/ for the expansion, build canonical NPC list
2. **DB Validation** — Search Hub per vendor, classify as MATCH/PARTIAL/NOT_ON_HUB/EMPTY_IN_DB/NEW_FROM_HUB
3. **Quest/Achievement Sweep** — Check Hub for non-vendor sources, cross-reference QuestSources/AchievementSources/AchievementDecor

For the full process with examples: read `references/vendor-data-pipeline.md`

## Zone-to-Continent Mapping Maintenance

Canonical source: `Core/constants.lua` — three tables:
- `Constants.ZoneToContinentMap` — zone mapID → continent mapID
- `Constants.ContinentNames` — continent mapID → display name
- `Constants.ContinentToExpansion` — continent mapID → expansion string

Consumers alias this data (do NOT maintain separate copies):
- `VendorDatabase.ZoneToContinentMap` / `.ContinentNames` — aliases set in `Data/VendorDatabase.lua`
- `BadgeCalculation` — local `zoneToContinent` aliased in `UI/BadgeCalculation.lua`
- `VendorScanner` — local upvalues aliased in `Modules/VendorScanner.lua`

When adding a new zone mapping, edit `Constants.ZoneToContinentMap` in `Core/constants.lua` only. All consumers pick it up automatically.

**Symptoms of stale/missing mappings:**
- Vendors missing from zone badges on the world map
- Wrong inferred expansion on scanned vendors
- Validation warnings for unmapped mapIDs (run `/hs validate`)

**Argus special case:** Argus zones map to continent 905 (not Broken Isles 619). Zone pins and badges work via HBD fallback + `manualZoneCenters`. Continent badge on Azeroth world map (947) remains unsolved — HBD can't place pins on maps without worldMapData.

## Two-Addon Architecture

- **Homestead** — player-facing, published to CurseForge/Wago
- **Homestead_Dev** — developer tools, never published. Contains: CatalogDiscoveryScanner, cross-reference reporting, all devmode commands, API test suite

Dev features gate on `HA.DevAddon` (truthy when Homestead_Dev is loaded). Verbose debug calls in recurring code paths (OnUpdate, event handlers) must be gated behind this flag.

For sourceText parser architecture: read `references/sourcetext-parser.md`

## Data Quality Checklist

Before committing data changes:
- NPC ID verified in-game (not from Wowhead)
- `mapID` verified in-game (sub-zone, not parent)
- Coordinates are normalized 0-1
- Faction is correct (Alliance/Horde/Neutral)
- Currency and cost format validated (gold in copper, currency IDs)
- Zone mapping exists in both mapping tables
- No stacked pins with other vendors at same coords
- Related cache/index invalidation paths still valid

## Quick In-Game Commands

```lua
-- Target NPC ID
/run print(UnitGUID("target"))

-- Map ID at player location
/run print(C_Map.GetBestMapForUnit("player"))

-- Map info (ID + name)
/run local m=C_Map.GetBestMapForUnit("player") local i=C_Map.GetMapInfo(m) print(m, i and i.name)

-- Check cached ownership
/run print(HomesteadDB.global.catalogItems[ITEMID] and "Owned" or "Not cached")

-- List scanned vendors
/run for id,v in pairs(HomesteadDB.global.scannedVendors) do print(id, v.name) end
```

## Performance Invariants

These patterns are already implemented. Do not regress them:

- **Badge count caching** — cache-miss pattern, invalidated on OWNERSHIP_UPDATED / VENDOR_SCANNED / MERCHANT_CLOSED / settings changes
- **Scan coalescing** — all housing events → `RequestScan()` with 1s debounce
- **Minimap/world map dedup** — `lastMinimapMapID` / `lastWorldMapID` guards skip redundant refreshes
- **Frame pools** — used for dynamic pin elements
- **Unverified filter** — badge counts exclude unverified vendors when hidden
- **Debug gating** — verbose recurring debug calls gated behind `HA.DevAddon`
