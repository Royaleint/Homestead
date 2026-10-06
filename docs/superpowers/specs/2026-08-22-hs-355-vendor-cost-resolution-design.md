# HS-355 Vendor Cost Resolution Design

**Status:** Approved by Rawb on 2026-08-22

## Goal

Make vendor costs consistent across the map-pin and item-tooltip surfaces. A player's
recent scan is authoritative by default, while an older scan may yield to newer Blizzard
source-text pricing when the lower value matches the known previous-expansion decor
discount policy.

## Decisions

- A scan is considered severely outdated at **60 days**.
- For a scan older than 60 days, a newer lower Blizzard source-text price is sufficient
  evidence of the known previous-expansion decor discount. The text does not need to
  contain an explicit discount label.
- The map-pin tooltip and item tooltip must use the same resolution rule.
- Existing copper storage and cost formatting remain unchanged.

## Current evidence

- `VendorData:GetMergedItemSet` resolves corrected NPC IDs, but
  `UI/VendorPinTooltips.lua` currently reads the original NPC ID directly.
- Pin-tooltip cost selection currently prefers curated static cost and uses scan cost
  only for static rows with no cost.
- Scan records persist `lastScanned` timestamps.
- The two tooltip paths do not currently share a single cost-resolution helper.

## Design

Add a shared VendorData cost resolver that:

1. Resolves the vendor's effective scanned record, including corrected NPC IDs.
2. Finds the item in the scanned record and normalizes its cost.
3. Compares scan age against the 60-day threshold.
4. Selects the scanned cost unless the scan is stale and newer lower source-text pricing
   is available for the known discount case.
5. Falls back to curated/static cost when no applicable scanned or source-text cost exists.

Both tooltip surfaces will call this resolver. Existing source rendering and formatting
remain otherwise unchanged.

## Verification

Add focused regression coverage for:

- corrected-NPC-ID scan lookup;
- fresh scan winning over static/source-text cost;
- stale scan yielding to lower newer source-text cost;
- stale scan falling back safely when no source-text cost exists;
- identical result selection from both tooltip surfaces.

Run the focused Lua tests, `luacheck` on changed Lua files, and the project test suite
available in the HS-355 worktree. Gate 1 review remains required before Gate 2.

## Scope boundary

No SavedVariables schema migration, vendor-data promotion, release work, minimap work,
or unrelated tooltip refactor is included.
