# Section 1 Data Layer Refactor Log (2026-02-11)

## Scope
- Target files: `Data/VendorData.lua`, `Data/VendorDatabase.lua`
- Requested changes:
- 1) Extract `UnpackItem(item)` helper in `VendorData.lua` and route dual-format item access through it.
- 2) Move `vendor.npcID = npcID` stamping to `BuildIndexes()` in `VendorDatabase.lua` and cache vendor count there for `GetVendorCount()`.

## Tier Classification
- Change 1: Tier 1 (pure helper extraction, no side effects)
- Change 2: Tier 1 (data indexing placement/caching only; no event/frame/SV schema changes)

## Layer 0 Baselines (pre-change)
- Vendor count: `248` (static table count in `VendorDatabase.Vendors`)
- Pin count per zone: `N/A (requires in-game map render)`
- Memory usage: `N/A (requires in-game API call)`
- luacheck: `2 warnings / 0 errors` on `Data/VendorData.lua` and `Data/VendorDatabase.lua`
- BugSack errors: `N/A (requires in-game)`

## Post-change Verification
- Vendor count: `248` (unchanged)
- Pin count per zone: `N/A (requires in-game map render)`
- Memory usage: `N/A (requires in-game API call)`
- luacheck: `2 warnings / 0 errors` on `Data/VendorData.lua` and `Data/VendorDatabase.lua` (unchanged)
- BugSack errors: `N/A (requires in-game)`

## Automated Verification Gates
- luacheck warning/error count: `2/0 -> 2/0` (unchanged)
- New globals found: `0`
- SavedVariables schema fingerprint: `unchanged` (no `db.global`/`db.profile` edits)
- Diff audit: `flagged` — GetItemCost truthiness gate removed via UnpackItem
  delegation (old code: `if type(item) == "table" and item.cost then` rejected
  falsy values; new code: returns `item.cost` directly). Unreachable edge case
  — `item.cost` is never `false` in the codebase (always table or nil). No
  real-world impact.
