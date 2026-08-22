# HS-355 Vendor Cost Resolution Implementation Plan

> **For agentic workers:** Execute this plan task-by-task with a fresh-context implementation pass and an Argus review checkpoint before each commit.

**Goal:** Make the map-pin and item-tooltip vendor prices agree by resolving fresh scans first and allowing a newer Blizzard source-text price to replace a scan older than 60 days when it reflects the known previous-expansion decor discount.

**Architecture:** `VendorData` owns the shared cost decision. `SourceManager` supplies the item’s parsed Blizzard vendor cost and timestamp, while both tooltip surfaces consume the same resolved result. Corrected NPC-ID lookup is centralized so a scan stored under the corrected ID is visible everywhere.

**Tech Stack:** Lua 5.1, WoW SavedVariables, existing standalone Lua source-extraction tests, `luacheck`.

---

## Plan Gate 0 — confirmed source evidence

| File | Lines read | Key facts confirmed |
|---|---:|---|
| `Data/VendorData.lua` | 109-248 | `GetItemCost`, `NormalizeScannedCost`, and the legacy/static cost shapes exist; scanned `price` is copper and becomes `cost.gold`. |
| `Data/VendorData.lua` | 260-307 | `GetMergedItemSet` already falls back through `VendorScanner:GetCorrectedNPCID`; this lookup logic can be reused by the cost resolver. |
| `Data/VendorData.lua` | 1209-1229 | `GetItemsForVendor` returns scanned rows for `_isScanned` vendors and projected static offers otherwise. |
| `Modules/ScanPersistence.lua` | 101-127, 257-295 | Scanned records persist `lastScanned = time()` and `scanConfidence`; rejected partial scans preserve the prior timestamp. |
| `Data/SourceTextParser.lua` | 69-101, 238-240 | Parsed Blizzard source text produces normalized gold/currency `cost` tables; gold values are converted to copper. |
| `Modules/SourceTextScanner.lua` | 88-109 | Parsed source records expose `sources` and `lastParsed` through `GetParsedSource(itemID)`. |
| `Data/CatalogStore.lua` | 192-209, 450-452 | Parsed source payloads are owned by `catalogItems`; `CatalogStore:Get(itemID)` returns the raw record. |
| `Data/SourceManager.lua` | 568-630 | Vendor source data currently derives cost from the vendor item list, and all vendor tooltip sources pass through `BuildVendorSourceData`. |
| `UI/VendorPinTooltips.lua` | 310-375 | Pin tooltip currently reads `scannedVendors[vendor.npcID]` directly and lets static cost win over a scanned cost when both exist. |
| `Overlay/Tooltips.lua` | 560-569, 920-925, 1147-1162 | Item tooltip displays `source.data.cost`; its presentation path is supplied by `SourceManager`. |
| `tests/hs074b_scanned_cost_probe.lua` | 1-180 | Existing tests extract the real gather block and use standalone Lua fixtures with `loadfile`/`loadstring`; this is the established cost-test idiom. |

### Confirmed interfaces

- `VendorData:NormalizeScannedCost(scannedItem)` returns a normalized `{gold, currencies, items}` cost or `nil`.
- `VendorData:GetItemCost(item)` returns a static/offer cost or `nil`.
- `VendorScanner:GetCorrectedNPCID(vendorName)` delegates to the persisted correction table.
- `SourceTextScanner:GetParsedSource(itemID)` returns `{sources = ..., lastParsed = ...}` or `nil`.
- `SourceManager` builds `{type = "vendor", data = {..., cost = cost}}` records consumed by `Overlay/Tooltips.lua`.

### Module/load safety

The new code will use runtime `time()` and existing module tables inside methods only. No WoW API will be upvalued or called at file scope. No TOC entry is needed because all modified files already load.

## Plan Gate 1 — implementation

### Task 1: Add the failing shared-resolution test

**Files:**
- Create: `tests/hs355_vendor_cost_resolution.lua`
- Read only: `Data/VendorData.lua`, `Data/SourceManager.lua`

- [ ] **Step 1: Build a standalone fixture around the real modules.** Load `Data/VendorData.lua` and `Data/SourceManager.lua` with a minimal `HA`, inject a corrected-ID map, a static item cost, a scanned item cost, and parsed source records with `lastParsed` timestamps.

```lua
local NOW = 2000000000
local DAY = 24 * 60 * 60
local NPC_STATIC = 990355
local NPC_SCANNED = 990356
local ITEM = 290355

local HA = {
    Addon = { RegisterModule = function() end, db = { global = {} } },
    VendorOffers = { GeneratedBase = { [NPC_STATIC] = {
        [ITEM] = { price = 1000000 },
    } }, ManualOverrides = {}, StagedAdditions = {}, Tombstones = {} },
    VendorScanner = { GetCorrectedNPCID = function() return NPC_SCANNED end },
    SourceTextScanner = { GetParsedSource = function()
        return { lastParsed = NOW, sources = {
            { sourceType = "vendor", name = "Test Vendor", cost = { gold = 800000 } },
        } }
    end },
}
```

- [ ] **Step 2: Assert the desired behaviors before implementation.** The test must assert corrected-ID lookup, fresh-scan precedence, stale-scan discount precedence, and static fallback. It must call the public resolver that the implementation will expose: `HA.VendorData:ResolveVendorItemCost(vendor, itemID, sourceText)`, returning `cost, provenance`.

```lua
local vendor = { npcID = NPC_STATIC, name = "Test Vendor", items = {{itemID = ITEM, cost = {gold = 1000000}}} }

HA.Addon.db.global.scannedVendors = {
    [NPC_SCANNED] = {
        lastScanned = NOW - (30 * DAY),
        items = {{itemID = ITEM, price = 900000}},
    },
}
local cost, provenance = HA.VendorData:ResolveVendorItemCost(vendor, ITEM, {
    cost = {gold = 800000}, lastParsed = NOW,
})
assert(cost.gold == 900000 and provenance == "scanned", "fresh scan must win")

HA.Addon.db.global.scannedVendors[NPC_SCANNED].lastScanned = NOW - (61 * DAY)
cost, provenance = HA.VendorData:ResolveVendorItemCost(vendor, ITEM, {
    cost = {gold = 800000}, lastParsed = NOW,
})
assert(cost.gold == 800000 and provenance == "sourceText-discount", "stale scan must yield to lower newer source text")

HA.Addon.db.global.scannedVendors[NPC_SCANNED].items = {{itemID = ITEM}}
cost, provenance = HA.VendorData:ResolveVendorItemCost(vendor, ITEM, nil)
assert(cost.gold == 1000000 and provenance == "static", "missing scan cost must fall back to static")
```

- [ ] **Step 3: Run the new test and verify the failure is about the missing resolver.**

Run: `lua tests/hs355_vendor_cost_resolution.lua`

Expected: FAIL with the resolver absent or the expected precedence not implemented; do not proceed on a syntax or fixture-loading error.

### Task 2: Implement the shared cost resolver

**Files:**
- Modify: `Data/VendorData.lua` near `NormalizeScannedCost` and the merge helpers

- [ ] **Step 1: Define constants and helpers.** Add `VENDOR_COST_STALE_SECONDS = 60 * 24 * 60 * 60`, a corrected-record lookup helper, and an item lookup helper. The corrected lookup must try `scannedVendors[vendor.npcID]` first, then call `VendorScanner:GetCorrectedNPCID(vendor.name)` and retry with the returned ID.

- [ ] **Step 2: Add the minimal resolver.** Implement this exact contract:

```lua
function VendorData:ResolveVendorItemCost(vendor, itemID, sourceText)
    -- returns normalizedCost, provenance
    -- provenance: "scanned", "sourceText-discount", "sourceText", "static", or nil
end
```

The method will:

1. Read the corrected scanned record and normalize the matching scanned row.
2. Return the scanned cost when `lastScanned` is present and no older than 60 days.
3. Return `sourceText.cost` as the second source when no scanned cost exists; when a scanned gold-only cost exists, use source text to replace it only when `sourceText.lastParsed > scanned.lastScanned`, the scan is older than 60 days, the source-text cost is lower, and both values are comparable gold costs.
4. Otherwise return the scanned cost when one exists.
5. Return static cost from the vendor’s item row or projected offer.
6. Return `nil, nil` when no cost exists.

Currency-only and item-token costs remain scanned-first and do not enter the gold-discount comparison, because there is no valid numeric gold comparison.

- [ ] **Step 3: Run the focused test and verify green.**

Run: `lua tests/hs355_vendor_cost_resolution.lua`

Expected: PASS for corrected IDs, fresh scan precedence, 60-day stale boundary, lower newer source-text discount selection, and static fallback.

### Task 3: Feed source-text costs through the shared resolver

**Files:**
- Modify: `Data/SourceManager.lua:568-597`

- [ ] **Step 1: Add a vendor-scoped parsed-source lookup.** Read `HA.SourceTextScanner:GetParsedSource(itemID)`, select the vendor source matching the vendor name when available, and return `{cost = source.cost, lastParsed = parsed.lastParsed}`. Do not use a non-vendor source’s cost.

- [ ] **Step 2: Replace the local cost cascade in `BuildVendorSourceData`.** Call `HA.VendorData:ResolveVendorItemCost(vendor, itemID, parsedVendorCost)` and assign the returned cost. Preserve all existing vendor metadata and source shape.

- [ ] **Step 3: Extend the focused test to exercise `SourceManager`’s vendor source payload.** Assert the payload returned for the same vendor/item contains the same selected cost and provenance as the direct resolver. Run the test and require PASS.

### Task 4: Make map-pin tooltip use the same resolver

**Files:**
- Modify: `UI/VendorPinTooltips.lua:310-375`
- Test: `tests/hs355_vendor_cost_resolution.lua`

- [ ] **Step 1: Replace the pin tooltip’s direct `scannedVendors[vendor.npcID]` lookup with the corrected-record scan-cost map.** Build that normalized map and known-item set once per tooltip, then pass each row’s precomputed scan state and static cost into `VendorData:ResolveVendorItemCost` through `SourceManager`, so the shared decision is used without rescanning the vendor or static list for every row.

- [ ] **Step 2: Preserve the item-details toggle behavior.** Do not normalize or resolve costs when `itemDetailsEnabled` is false, because the renderer does not read `item.cost` in that mode.

- [ ] **Step 3: Add a source-level assertion that both surfaces call the shared resolver.** The test must locate the resolver call in the pin gather block and verify the `SourceManager` vendor payload is populated by the same `VendorData` method. Run the focused test and require PASS.

### Task 5: Full verification and review packet

**Files:**
- Modify: `tests/hs355_vendor_cost_resolution.lua` only if a test gap is found

- [ ] **Step 1: Run the focused HS-355 test.**

Run: `lua tests/hs355_vendor_cost_resolution.lua`

Expected: PASS with no warnings.

- [ ] **Step 2: Run related cost tests.**

Run: `lua tests/hs074b_scanned_cost_probe.lua`

Expected: PASS; existing normalization/backfill behavior remains intact.

- [ ] **Step 3: Run Lua static analysis on changed Lua.**

Run: `luacheck Data/VendorData.lua Data/SourceManager.lua UI/VendorPinTooltips.lua tests/hs355_vendor_cost_resolution.lua`

Expected: zero new errors.

- [ ] **Step 4: Inspect the final diff for scope and confidentiality.** Confirm no SavedVariables migration, no vendor-data edits, no source-attribution leakage, and no unrelated tooltip refactor.

- [ ] **Step 5: Request Argus Gate 1 review before committing implementation.** The review must cover specification compliance, Lua 5.1 correctness, cost-unit preservation, stale-time comparison, corrected-ID coverage, and hot-path allocation/caching impact.

## Plan Gate 2 — self-review

- [x] Shared resolver covers all approved policy decisions.
- [x] Corrected-ID asymmetry is explicitly tested.
- [x] Existing copper normalization is preserved.
- [x] Both tooltip surfaces consume the same decision.
- [x] No TOC or load-order change is required.
- [x] No new WoW API call or file-scope API access is introduced.
- [x] Existing cost regression test is retained.
- [x] Rollback is a normal Git revert; no SavedVariables migration exists.

## Plan Gate 3 — open questions

None — Rawb approved the 60-day threshold, the known previous-expansion discount interpretation, and shared behavior across both tooltip surfaces.

## Plan Gate 4 — commit and rollback

### Worktree

`C:/Projects/Homestead/.worktrees/HS-355`, branch `feature-HS-355-vendor-cost-resolution`.

### Commits

1. `test(hs-355): lock vendor cost precedence` — `tests/hs355_vendor_cost_resolution.lua`
2. `feat(vendor): resolve scanned and discounted source costs` — `Data/VendorData.lua`, `Data/SourceManager.lua`, `UI/VendorPinTooltips.lua`

Every commit must include:

```text
Co-Authored-By: Royaleint and Codex
```

Argus review is the Tier 2 commit gate. If the implementation regresses, revert the implementation commit first; the test commit may remain as a regression guard. No SavedVariables rollback is needed.
