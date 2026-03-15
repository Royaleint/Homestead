# Vendor Data Pipeline Reference

## Pipeline Summary

Community members submit vendor scan exports. No data enters VendorDatabase.lua
without confirmation from multiple sources. Past issues were caused by trusting
single-source data — this pipeline enforces multi-source validation.

```
IMPORT → PARSE → REVIEW → VERIFY → COMMIT
```

## Step 1 — Import

Intake sources: Google Form, Discord, direct messages.

Export format: `HOMESTEAD_EXPORT:` header, tab-separated V/I/D lines. Parser accepts V1, legacy V2, and current V2-style exports.

Save raw text to:
```
Home_Dev/scripts/exports/<submitter>_<date>.txt
```

## Step 2 — Parse

```bash
python Home_Dev/scripts/compare_exports.py Home_Dev/scripts/exports/<file>.txt
```

Primary output actions:
- **APPLY** — strong candidate for DB update after human review
- **VERIFY** — requires manual confirmation before any DB edit
- **BLOCK** — malformed export or unsafe input; stop first
- **IGNORE** — parsed successfully, no actionable DB change

Extra protections:
- `D` delist lines are always `VERIFY`
- non-vendor source conflicts are always `VERIFY`
- stale exports downgrade `APPLY` to `VERIFY` unless `--allow-stale` is used
- the tool is report-only and never edits Lua data files

## Step 3 — Review (Multi-Source Cross-Reference)

No data enters VendorDatabase.lua without confirmation from multiple sources.

### Source Priority

| Priority | Source | How to Check |
|----------|--------|-------------|
| 1st | sourceText | `/hsdev testsource ITEMID` — Blizzard's own attribution (most authoritative) |
| 2nd | Housing Hub | housing.wowdb.com — search vendor, compare item list |
| 3rd | Wowhead | wowhead.com/item=ITEMID — confirm Housing Decor type + "Sold by" tab |
| 4th | In-game | Visit vendor, confirm items present and purchasable |

**Minimum threshold**: 2 of 4 sources must agree.

### Confidence Tiers

| Confidence | Criteria | Destination |
|------------|----------|-------------|
| HIGH | 3+ sources agree | Change report — review first |
| MEDIUM | 2 sources agree | Change report — flagged for review |
| LOW | Single source only | `Low_Conf_Vendors.txt` (separate file) |

**Exception**: LOW items may stay in the change report with outlier justification
(new patch, expansion launch, known Hub/Wowhead lag).

### Change Report Format

Saved to `Home_Dev/scripts/exports/<submitter>_<date>_review.txt`:

```
PROPOSED CHANGES — <submitter> export (<date>)
======================================

--- HIGH CONFIDENCE (review first) ---
[HIGH] Add item 264915 to Harlowe Marl [257897]
  - Export: present in scan
  - Wowhead: confirmed Housing Decor, sold by Harlowe Marl
  - Hub: listed under Harlowe Marl

--- MEDIUM CONFIDENCE (flagged for review) ---
[MEDIUM] Add item 250094 to Gronthul [255278]
  - Export: present in scan
  - Wowhead: confirmed Housing Decor
  - Hub: NOT listed (Hub may be stale)
  ⚠ Flagged: only 2 sources confirm

--- LOW CONFIDENCE → see Low_Conf_Vendors.txt ---
3 items deferred
```

### Low Confidence File

`Home_Dev/scripts/exports/Low_Conf_Vendors.txt` — cumulative, persists across sessions:

```
[2026-02-15] From <submitter> export:
  Item 999999 → Gronthul [255278]
    - Export only, Wowhead page doesn't exist
```

## Step 4 — Verify

Developer manually reviews the change report and decides what to apply.
HIGH first, then MEDIUM. **No automated writes to VendorDatabase.lua.**

For UPDATED vendors: add confirmed item IDs to existing entry's items array.
For NEW vendors: add full entry with `unverified = true`, all required fields.

Post-apply:
```bash
python Home_Dev/scripts/verify_vendor_data.py
```
In-game: `/reload`, check map pins for new/updated vendors.

## Step 5 — Commit

```
data(vendors): add 3 items to Gronthul from community scan (wowhead+hub confirmed)
```

Always cite sources in commit message.

## Script Inventory

| Script | Purpose |
|--------|---------|
| `Home_Dev/scripts/compare_exports.py` | Review export file with APPLY/VERIFY/BLOCK/IGNORE output |
| `Home_Dev/scripts/verify_vendor_data.py` | Post-edit validation of VendorDatabase.lua |
| `Home_Dev/scripts/export_blizzard_sourcetext.py` | Blizzard web API export: decor catalog, sources, ownership, recipe/achievement discovery |
| `Home_Dev/scripts/run_hybrid_export.ps1` | PowerShell wrapper for the web API export script |

For the web API export pipeline, CLI args, and data strategy: see `Home_Dev/reference/BLIZZARD_WEB_API_AND_DATA_STRATEGY.md`

## File Structure

```
Home_Dev/scripts/exports/
├── .gitkeep
├── Low_Conf_Vendors.txt          # Cumulative low-confidence items (tracked)
├── submitter_2026-02-15.txt      # Raw exports (gitignored)
└── submitter_2026-02-15_review.txt  # Change reports (gitignored)
```

`.gitignore` pattern: `Home_Dev/scripts/exports/*.txt` with `!Home_Dev/scripts/exports/Low_Conf_Vendors.txt`

## Verification Tier System (Database-Wide)

Separate from the per-submission confidence tiers above, the database as a whole
uses a tiered verification system for cross-source validation:

### Platinum — Fully Verified / Community Confirmed
ALL of these match across sources:
- NPC ID
- Item IDs
- Number of items
- Location within ±0.5 of Homestead coordinates
- Cost data

### Gold — Verified, Not Community Confirmed
4 of 5 Platinum fields match.

### Silver — Verified, With Questions
3 of 5 Platinum fields match.

### Bronze — Low Confidence
Fewer than 3 of 5 fields match.

## 3-Phase Validation Process (Full DB Audit)

For periodic full-database validation (not per-submission):

### Phase 1: Hub-First Discovery
1. Fetch `housing.wowdb.com/vendors/` for each expansion
2. Build canonical NPC list from Hub data
3. Cross-reference against Homestead database
4. Identify: new vendors not in DB, DB vendors not on Hub

### Phase 2: DB Validation
1. Search Hub per vendor in Homestead DB
2. Classify: MATCH / PARTIAL / NOT_ON_HUB / EMPTY_IN_DB / NEW_FROM_HUB
3. Log all discrepancies

### Phase 3: Quest/Achievement Sweep
1. Check Hub for quest/achievement/crafting/drop sources
2. Cross-reference against `QuestSources`, `AchievementSources`, `AchievementDecor`
3. Flag missing source data

## Validation Progress

Completed: Classic (40), TBC (5), Wrath (7), Cataclysm (6), MoP (7),
WoD (scan-verified), Legion (scan-verified), BfA (16), Shadowlands (11),
Dragonflight (25), TWW (74, 48 validated)

Remaining: TWW remaining vendors, Events category

## V2 Export Format

The interchange format for community data sharing. Used by `/hs export`.

### Format
```
V    npcID    name    mapID    x    y    faction    lastScanned    itemCount    decorCount
I    npcID    itemID    name    price    costData
```

### Field Details

**Vendor line (V):**
- `npcID`: Canonical NPC ID (aliases already resolved)
- `mapID`: Zone map ID for pin placement
- `x, y`: Normalized 0-1 coordinates
- `faction`: Alliance, Horde, or Neutral
- `lastScanned`: Unix timestamp
- `itemCount`: Total merchant items (including non-housing)
- `decorCount`: Housing decor items only (subset of itemCount)

**Item line (I):**
- `npcID`: Parent vendor NPC ID
- `itemID`: WoW item ID
- `price`: In copper (1,000,000 copper = 100 gold; 0 if no gold cost)
- `costData`: Encoded cost string
  - `c3363:100` — Currency by ID (e.g., Kej)
  - `i12345:5` — Item cost by ID
  - `nHonor:500` — Currency by name (when ID unavailable)

### Example
```
V    255278    Gronthul    2351    0.5410    0.5907    Alliance    1770251675    59    59
I    255278    244662    Closed Leather Curtains    500000
I    255278    250094    Empty Orgrimmar Bathtub    750000
I    255278    250231    Silver Hand Banner    0    c1220:500
```

## Data Sources (Reliability Ranking)

| Source | Type | Reliability |
|--------|------|-------------|
| Homestead scanned data | In-game scan | Highest |
| Homestead static DB | Curated | High |
| HomeBound addon | External addon | Medium |
| DecorVendor addon | External addon | Medium |
| Qithe's Spreadsheet | Community | Medium |
| WoW Housing Hub | Community site | Medium |
| Vamoose's Guide | Community | Low-Medium |
| Wowhead | External DB | Low (NPC IDs often wrong) |

## Common Data Pitfalls

### NPC ID Issues
- Wowhead NPC IDs are frequently wrong — always verify in-game scan data
- Phased NPC variants (same name, different IDs) → add to Aliases table
- Hub search may return wrong vendor's items (name similarity confusion)

### Item Count Discrepancies
- Hub may not show achievement-gated items (e.g., Val'zuun shows 2/17)
- Some vendors have non-housing items mixed in (`itemCount > decorCount`)
- "Extra" items may belong to nearby vendors (Ransa/Torv overlap)

### Coordinate Issues
- Always normalize: Wowhead uses 0-100, Homestead uses 0-1
- Sub-zone vs zone mapID matters (Val'zuun → Underbelly 628, not Dalaran 627)

### Currency Patterns
- `altCurrency` field for vendors with mixed currencies
- Legion class hall vendors often have Gold + Order Resources
- Cost format: `{gold = N*10000, currencies = {{id=N, amount=N}}}`

### Deletion Safety
- Never delete vendors based on "empty" status alone
- Always check export data first (Brakoss was incorrectly deleted, had 3 items)
- "Empty" vendors may have items gated behind achievements, reputation, or quests

## Expansion Tags

Use full canonical names:
```
"Classic", "The Burning Crusade", "Wrath of the Lich King",
"Cataclysm", "Mists of Pandaria", "Warlords of Draenor",
"Legion", "Battle for Azeroth", "Shadowlands",
"Dragonflight", "The War Within"
```

## Scan Confidence Levels

Set by VendorScanner during MERCHANT_SHOW processing:
- `"confirmed"` — Scanner verified items in-game
- Absence of `scanConfidence` — not yet scanned
- Note: `scanComplete` field does NOT exist. Never check for it.
