---
name: Replace HereBeDragons with native WoW API pin system
about: Remove HBD dependency and build unified pin system on native C_Map/C_Minimap APIs
title: "Replace HereBeDragons with native WoW API pin system"
labels: enhancement, architecture
---

## Summary

Remove the HereBeDragons (HBD) library dependency and replace it with a unified pin system built on WoW's native `C_Map`, `C_Minimap`, and `MapCanvasPinMixin` APIs. This is a substantial migration requiring parity testing across all map display modes — not a cleanup.

Full implementation spec will live in `Home_Dev/plans/active/` once this is approved as a direction.

## Motivation

HBD wraps 9 API calls across 2 files. Homestead has built ~130 lines of workaround code to compensate for HBD's limitations — more code than the integration itself. The dual-system (HBD + native fallback) is the primary source of pin-related bugs and debugging difficulty.

### Confirmed problems

1. **Dual pin system** — `MapPinProvider.lua` maintains both HBD pins and native fallback pins in parallel. Every placement branches on `IsMapSupported()`. Every clear must clean both systems. Every future pin feature must work with both paths.
2. **Silent failures** — HBD stores `{0, 0, 0, 0}` for phased/instanced zones and returns nil with no diagnostic. This spawned `IsMapSupported`, `manualZoneCenters`, native pin fallback, excluded continents, and continent merges — all workarounds for one behavior.
3. **Patch fragility** — HBD maintains a hardcoded instance transform table extracted from `UIMapAssignment.db2`. New WoW patches with phased zones risk breaking pins until HBD's maintainer pushes an update. Native APIs return correct data on patch day.
4. **Debugging opacity** — When a pin doesn't appear, it's impossible to distinguish whether HBD rejected it (zero-dimension mapData), WoW rejected it (canvas not ready), or our own logic skipped it.

### Suspected problems (validate during implementation)

5. **Taint risk** — HBD's pin library creates a `MapCanvasDataProviderMixin` and uses `AcquirePin`, which may write to `WorldMapFrame.pinPools`. Our own native fallback pool (`MapPinProvider.lua:252-256`) was specifically built to avoid `pinPools` writes after documenting "secret number value tainted by Homestead" errors. HBD is a suspected taint vector but not yet proven as the source — validate by testing with HBD removed.

## Current HBD Touchpoints

### MapPinProvider.lua (9 call sites)
| Line(s) | Function | HBD Call |
|---------|----------|----------|
| 23-24 | Module load | `LibStub("HereBeDragons-2.0")`, `LibStub("HereBeDragons-Pins-2.0")` |
| 159-163 | `IsMapSupported()` | `HBD:GetWorldCoordinatesFromZone(0.5, 0.5, mapID)` |
| 297-298 | `PlaceWorldMapPin()` | `HBDPins:AddWorldMapIconMap()` |
| 320-322 | `PlaceMinimapPin()` | `HBDPins:AddMinimapIconMap()` |
| 326-328 | `GetWorldCoordinatesForPin()` | `HBD:GetWorldCoordinatesFromZone()` |
| 331-333 | `PlaceMinimapPinWorld()` | `HBDPins:AddMinimapIconWorld()` |
| 337-339 | `PlaceWorldMapPinDirect()` | `HBDPins:AddWorldMapIconMap()` |
| 343-346 | `ClearWorldMapPins()` | `HBDPins:RemoveAllWorldMapIcons()` + `ReleaseAllNativePins()` |
| 349-351 | `ClearMinimapPins()` | `HBDPins:RemoveAllMinimapIcons()` |

### VendorMapPins.lua (7 consumer sites)
| Line(s) | Context |
|---------|---------|
| 1285-1286 | Zone vendor pins (`SHOW_PARENT`) |
| 1326-1327 | Portal badge pins (`SHOW_PARENT`) |
| 1357-1358 | Zone badges on continent (`SHOW_CONTINENT`) |
| 1468-1481 | Zone badges on world map (`SHOW_WORLD` with complex fallback chain) |
| 1537-1544 | Continent badges on world map (native-first, HBD fallback) |
| 1087-1096 | Cross-floor minimap pins (world-coord path) |
| 1103-1106 | Same-zone minimap pins (zone-coord path) |

### Ancillary Files
- `embeds.xml` lines 22-23: Library loading
- `.pkgmeta` line 28: External dependency
- `.luacheckrc` lines 110-112: `HBD_PINS_WORLDMAP_SHOW_*` globals
- `README.md` line 60: Credits

## Native APIs Available (all stable since 9.0.1+)

| Need | Native API | Notes |
|------|-----------|-------|
| Zone → world coords | `C_Map.GetWorldPosFromMapPos(mapID, Vector2D)` | Returns instanceID + world Vector2D. Returns nil for zero-dimension zones — same limitation as HBD. |
| World → zone coords | `C_Map.GetMapPosFromWorldPos(instanceID, Vector2D)` | Returns mapID + map Vector2D |
| Zone rect on parent | `C_Map.GetMapRectOnMap(srcMapID, destMapID)` | Returns degenerate `(0,0,0,0)` for some phased/inaccessible zones — not a universal fix (see Open Questions) |
| Map hierarchy | `C_Map.GetMapInfo(mapID)` | name, mapType, parentMapID |
| Player world position | `UnitPosition("player")` | Returns y, x, z, instanceID |
| Minimap radius | `C_Minimap.GetViewRadius()` | Yards, replaces HBD's fallback lookup tables |
| Player facing | `GetPlayerFacing()` | Radians, for rotating minimap |
| World map pin framework | `MapCanvasPinMixin` | Blizzard's official pin system |
| World map canvas | `WorldMapFrame:GetCanvas()` | Direct frame parenting |

## Design Direction

### World Map Pins

Use Blizzard's `MapCanvasDataProviderMixin` pattern — register a data provider with `WorldMapFrame`, implement `RefreshAllData` to place pins when the map changes. This is how every built-in WoW pin system works (world quests, area POIs, flight paths).

**Coordinate projection:** `C_Map.GetMapRectOnMap(pinMapID, currentViewMapID)` as the primary path. For zones where this returns degenerate rects, fall back to `manualZoneCenters` (see Open Questions for which entries can be retired vs which are permanent).

**Visibility (replaces SHOW_PARENT/CONTINENT/WORLD):** Walk `C_Map.GetMapInfo(mapID).parentMapID` from the pin's zone up to the current view map. Project coordinates at each ancestor level. This also needs to handle the existing business logic: continent merges (`continentMergesInto`), excluded continents, Midnight/Quel'Thalas overlays (`continentZoneBadgesOnParent`), and class hall/off-world zone handling. These are not "~30 lines" — they are substantial and need explicit parity with current behavior.

**Frame management:** Self-managed pool, NOT writing to `WorldMapFrame.pinPools`. Uses the taint-safe pattern already proven in the native fallback code.

### Minimap Pins

Three distinct placement modes must be supported (current behavior):

**Mode 1 — Same-zone pins** (replaces `AddMinimapIconMap`):
- Convert vendor zone coords to world coords via `C_Map.GetWorldPosFromMapPos(vendorMapID, {x, y})`
- If conversion returns nil (zero-dimension zone), pin cannot be placed — same as current HBD behavior
- Store world coords + instanceID per pin
- OnUpdate: compute pixel offset from player world position, apply rotation if enabled

**Mode 2 — Cross-floor pins** (replaces `AddMinimapIconWorld`):
- Caller pre-converts to world coords via `C_Map.GetWorldPosFromMapPos` (same as current `GetWorldCoordinatesForPin`)
- Store world coords + instanceID directly
- Same OnUpdate rendering as Mode 1, with forced edge-floating

**Mode 3 — Visibility filtering:**
- Pin shown when: `pin.instanceID == playerInstanceID` AND (`pin.mapID == playerMapID` OR pin's map is a child/parent of the player's current map)
- This replicates HBD's `UpdateMinimapPins` zone/parent matching logic

**OnUpdate core math:**
```lua
local radius = C_Minimap.GetViewRadius()
local py, px = UnitPosition("player")
-- per pin:
local dx, dy = (pinX - px) / radius, (pinY - py) / radius
if rotateMinimap then
    local f = GetPlayerFacing()
    dx, dy = dx*cos(f) - dy*sin(f), dx*sin(f) + dy*cos(f)
end
local dist = dx*dx + dy*dy
if dist > 1 then
    if pin.floatOnEdge then
        local s = 1 / sqrt(dist)
        dx, dy = dx * s, dy * s
    else
        pin:Hide(); return
    end
end
pin:SetPoint("CENTER", Minimap, "CENTER", dx * halfWidth, -dy * halfHeight)
```

**Fast path:** If zero minimap pins registered, skip the entire OnUpdate.

## Open Questions (must be resolved before implementation)

1. **Which `manualZoneCenters` entries are permanent?** Test each zone with `C_Map.GetMapRectOnMap` on a non-matching class character. Entries where `GetMapRectOnMap` returns valid non-degenerate rects can be retired. Entries where it returns `(0,0,0,0)` or nil must be kept. This is a hypothesis to validate, not an assumed simplification.

2. **Does `C_Map.GetMapRectOnMap` work for Argus zones (830, 882, 885) on continent 905?** If yes, Argus badge placement simplifies. If no, the continent merge + manualZoneCenters pattern must be preserved.

3. **Taint validation:** After removing HBD, test: open world map → interact with Blizzard tooltips and widgets → verify no "tainted by Homestead" errors. This proves or disproves HBD as the taint source.

4. **Instance transforms:** HBD maintains transform offsets for phased zones where `UnitPosition` instanceID doesn't match the parent continent. Homestead currently excludes Draenor and Shadowlands from minimap pins. Validate whether any remaining minimap-eligible zone requires instance transforms. If none do, this complexity can be omitted.

5. **Minimap indoor/outdoor behavior:** HBD tracks indoor status for zoom radius. `C_Minimap.GetViewRadius()` returns the correct radius regardless of indoor/outdoor state (it reads the live value). Validate this in-game.

6. **Allowed regressions:** Are there any current behaviors that are acceptable to lose? Candidates: edge-floating precision in minimap corners, pins on truly unmappable zones that only show with `manualZoneCenters` today. Defining this scope prevents the migration from becoming a zero-regression parity project.

## What Gets Eliminated

- `IsMapSupported()` branching and the `hbdMapSupport` cache
- The dual-path in `PlaceWorldMapPin` (HBD vs native fallback)
- The dual-clear in `ClearWorldMapPins` (HBD + native)
- The complex fallback chain in `ShowZoneBadgesOnWorldMap` lines 1468-1481
- HBD library files (~2,041 lines / 59 KB) from `Libs/` and `embeds.xml`
- `HBD_PINS_WORLDMAP_SHOW_*` globals from `.luacheckrc`
- `manualZoneCenters` entries that `GetMapRectOnMap` handles natively (TBD — see Open Questions)
- `offWorldContinentPositions` table (TBD — see Open Questions)

## What Must Be Preserved

- All existing business logic: continent merges, excluded continents, Midnight overlays, class hall zone handling, badge count aggregation
- The `badgeMapID` redirect pattern for class hall vendors
- Portal badge pin placement
- Cross-floor elevation arrow minimap pins
- Minimap pin cap and warmup behavior
- Pin frame pooling (already implemented, taint-safe)

## Testing Checklist

### World Map Parity
- [ ] Zone view: Vendor pins at correct positions
- [ ] Zone view: Child/sub-zone vendors visible on parent zone map
- [ ] Zone view: Portal badge pins render correctly
- [ ] Continent view: Zone badges at correct zone centers
- [ ] Continent view: Argus zone badges on Broken Isles (merged continent)
- [ ] Continent view: Midnight zone badges on Eastern Kingdoms (overlay)
- [ ] Continent view: Class hall zones — badges appear for all classes (Trueshot Lodge, Dreamgrove, Skyhold, etc.)
- [ ] World map: Continent badges at correct positions
- [ ] World map: Zone-level badges mode (`worldMapZoneBadges` toggle)
- [ ] World map: Excluded continents (Draenor, Shadowlands) — no badges shown

### Minimap Parity
- [ ] Same-zone vendor pins positioned correctly
- [ ] Cross-floor elevation arrow pins with correct direction
- [ ] Parent/child zone visibility — pins from child zone visible on parent
- [ ] Rotating minimap — pins track player facing correctly
- [ ] Indoor vs outdoor — radius adapts correctly
- [ ] Edge floating for distant pins
- [ ] Pin cap enforcement
- [ ] Zero pins registered — verify zero CPU cost (fast path)
- [ ] Excluded continents — no minimap pins in Draenor/Shadowlands/Outland

### Regression Testing
- [ ] Taint: Open world map in combat — no Lua errors
- [ ] Taint: Mouseover Blizzard tooltips/widgets after Homestead pins rendered
- [ ] Performance: Pin placement timing comparable to or better than HBD
- [ ] No new globals introduced (luacheck clean)
- [ ] New expansion zones — pins appear without manual table entries (validate on PTR if available)
