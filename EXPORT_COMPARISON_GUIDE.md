# Export Comparison Guide

How to use `compare_exports.py` to validate vendor data from in-game scans against the static VendorDatabase.

---

## Purpose

The `compare_exports.py` script compares V2 export data (from `/hs export`) against `VendorDatabase.lua` to identify:

- **NEW vendors** — Not in the static database (candidates for addition)
- **UPDATED vendors** — Export has items not in the database (DB needs update)
- **MATCH vendors** — Identical item sets (no action needed)
- **PARTIAL SCANS** — Database has items not in the export (incomplete scan or items removed from game)

This helps maintain data quality by catching missing vendors, outdated item lists, and scan errors.

---

## Prerequisites

- **Python 3.7+** installed
- **V2 export file** from in-game (`/hs export`, copy to `.txt` file)
- **VendorDatabase.lua** in `Data/` directory (default location)

---

## Basic Usage

### 1. Export Vendor Data In-Game

1. Visit vendors in-game to scan their items
2. Run `/hs export` to open the export dialog
3. Click **"Select All"** button
4. Press `Ctrl+C` to copy the data
5. Paste into a text file (e.g., `my_scan.txt`)

**Export format (V2):**
```
# Homestead V2 Vendor Export
# Generated: 2026-02-08
V	252910	Gronthul	2351	0.5410	0.5907	Alliance	1770251675	59	59
I	252910	244662	Closed Leather Curtains	500000
I	252910	250094	Empty Orgrimmar Bathtub	750000
```

### 2. Run the Comparison Script

**Basic command:**
```bash
python scripts/compare_exports.py my_scan.txt
```

**Output:**
```
Reading export: my_scan.txt...
  Parsed 47 vendors, 523 items total

Reading database: Data/VendorDatabase.lua...
  Parsed 261 vendors, 2847 items total

======================================================================
COMPARING EXPORT vs DATABASE
======================================================================

======================================================================
EXPORT vs DATABASE COMPARISON REPORT
======================================================================

SUMMARY
----------------------------------------------------------------------
Vendors in export:           47
Vendors in database:         261
NEW (not in DB):             2
MATCH (identical):           22
UPDATED (new items):         4
FEWER (DB has more):         19
```

---

## Command-Line Options

### Custom Database Path

If `VendorDatabase.lua` is in a non-standard location:

```bash
python scripts/compare_exports.py my_scan.txt --db /path/to/VendorDatabase.lua
```

### JSON Output

For automation or LLM processing:

```bash
python scripts/compare_exports.py my_scan.txt --json
```

**JSON structure:**
```json
{
  "summary": {
    "export_vendor_count": 47,
    "db_vendor_count": 261,
    "new_count": 2,
    "match_count": 22,
    "updated_count": 4,
    "fewer_count": 19
  },
  "new_vendors": [...],
  "updated_vendors": [...],
  "partial_scans": [...],
  "matched_vendors": [...]
}
```

### Help

```bash
python scripts/compare_exports.py --help
```

---

## Understanding the Report

### NEW VENDORS

**What it means:** Vendor exists in the export but not in `VendorDatabase.lua`.

**Example:**
```
[255278] Gronthul
  Items: 59
  Item IDs: 244662, 250094, 250231, 256330, 256905, ...
```

**Action:** Add this vendor to `VendorDatabase.lua` using `/hs suggest` command (requires developer mode).

---

### UPDATED VENDORS

**What it means:** Vendor exists in DB, but the export has items not in the DB.

**Example:**
```
[252910] Auditor Balwurz
  Export: 48 items | DB: 44 items
  New items (+4): 256330, 256905, 257403, 257404
```

**Action:** Add the new item IDs to the vendor's `items = {}` array in `VendorDatabase.lua`.

---

### MATCHED VENDORS

**What it means:** Vendor's item list in the export exactly matches the database.

**Example:**
```
MATCHED VENDORS: 22 vendors have identical item sets
```

**Action:** None — data is already correct.

---

### PARTIAL SCANS (DB has more)

**What it means:** The database has items that are NOT in the export.

**Possible causes:**
1. **Incomplete scan** — You closed the merchant window before all items loaded
2. **Conditional items** — Vendor has reputation/quest-locked items you can't see
3. **Items removed from game** — Blizzard removed items in a patch
4. **Phased vendor** — Different phase shows different items

**Example:**
```
[93550] Quartermaster Ozorg
  Export: 12 items | DB: 17 items
  Missing from export (-5): 248808, 248809, 248810, 248811, 248812
```

**Action:**
- Re-scan the vendor (wait for all items to load)
- Check if you meet requirements (reputation, quests)
- If items were removed from game, use `/hs suggest` to generate updated DB entry

---

## Common Workflows

### Workflow 1: Adding New Vendors

**Goal:** Add vendors discovered in-game to the static database.

**Steps:**
1. Visit new vendors in-game (scan automatically)
2. Export data: `/hs export` → copy to `new_vendors.txt`
3. Compare: `python scripts/compare_exports.py new_vendors.txt`
4. Review **NEW VENDORS** section in report
5. Enable developer mode: `/hs devmode`
6. Generate Lua: `/hs suggest` (in-game)
7. Copy generated Lua code
8. Paste into `Data/VendorDatabase.lua`
9. Test: `/reload` → verify vendors appear on map

---

### Workflow 2: Updating Existing Vendors

**Goal:** Add missing items to existing vendors in the database.

**Steps:**
1. Visit vendors in-game (re-scan)
2. Export data: `/hs export` → copy to `updates.txt`
3. Compare: `python scripts/compare_exports.py updates.txt`
4. Review **UPDATED VENDORS** section
5. For each vendor:
   - Open `Data/VendorDatabase.lua`
   - Find the vendor by NPC ID (e.g., `[252910]`)
   - Add new item IDs to `items = {}` array
   - Follow existing format (simple IDs or `{id, cost = {...}}`)
6. Test: `/reload` → verify items show in tooltips

---

### Workflow 3: Verifying Community Submissions

**Goal:** Validate export data from users before merging.

**Steps:**
1. Receive export file from user (via Google Forms, GitHub, etc.)
2. Save as `community_export.txt`
3. Compare: `python scripts/compare_exports.py community_export.txt`
4. Review report:
   - **NEW vendors** → high priority (fresh data)
   - **UPDATED vendors** → add new items
   - **PARTIAL SCANS** → request re-scan if many missing
   - **MATCH vendors** → no action needed
5. Use `/hs suggest` to generate Lua for NEW vendors
6. Manually add items for UPDATED vendors
7. Commit changes with clear message:
   ```
   Add community vendor data: 2 new vendors, 4 updates

   - Gronthul [255278]: +59 items (new vendor)
   - Auditor Balwurz [252910]: +4 items

   Co-Authored-By: Royaleint and Claude Code
   ```

---

## Troubleshooting

### Error: "Export file not found"

**Cause:** File path is incorrect or file doesn't exist.

**Fix:**
```bash
# Use absolute path
python scripts/compare_exports.py C:\Users\You\Desktop\export.txt

# Or relative path from project root
python scripts/compare_exports.py ../export.txt
```

---

### Error: "Could not find VendorDatabase.Vendors table"

**Cause:** Database file path is wrong or file is corrupted.

**Fix:**
```bash
# Verify file exists
ls Data/VendorDatabase.lua

# Specify full path
python scripts/compare_exports.py export.txt --db Data/VendorDatabase.lua
```

---

### Many "PARTIAL SCANS" reported

**Cause:** Likely incomplete scans (closed merchant window too quickly).

**Fix:**
1. Re-visit vendors in-game
2. Wait for all items to load (no "..." loading text)
3. Export again
4. Re-run comparison

---

### No vendors parsed from export

**Cause:** Export file is not in V2 format (missing `V` and `I` lines).

**Fix:**
1. Check export file starts with:
   ```
   # Homestead V2 Vendor Export
   V	<npcID>	<name>	...
   I	<npcID>	<itemID>	...
   ```
2. Re-export from in-game using **latest addon version** (v1.3.0+)

---

## Advanced Usage

### Compare Specific Vendor Subset

Extract specific vendors from a large export:

```bash
# Export only TWW vendors (mapID 2601-2700 range)
grep -E "^V\t.*\t2[67][0-9]{2}\t" full_export.txt > tww_only.txt
grep -E "^I\t" full_export.txt >> tww_only.txt
python scripts/compare_exports.py tww_only.txt
```

---

### Diff Against Previous Export

Track changes between two scans:

```bash
# First scan
python scripts/compare_exports.py scan1.txt --json > results1.json

# Second scan (after patch or new data)
python scripts/compare_exports.py scan2.txt --json > results2.json

# Compare JSON outputs
diff results1.json results2.json
```

---

### Automate with Developer Mode

Combine with in-game commands for full workflow:

**In-game:**
1. `/hs devmode` (enable developer mode)
2. Visit vendors, scan automatically
3. `/hs export` → copy to `latest_scan.txt`

**On command line:**
```bash
# Compare
python scripts/compare_exports.py latest_scan.txt

# Review NEW and UPDATED vendors
# Then go back in-game...
```

**In-game:**
4. `/hs suggest` → generates Lua for NEW vendors
5. Copy suggested code
6. Paste into `VendorDatabase.lua`
7. `/reload`

---

## Output File Examples

### Text Report (Default)

**Good for:** Human review, documentation, commit messages

**Characteristics:**
- Clear section headers
- Sorted by NPC ID
- Shows first 10 items per vendor (truncates long lists)
- Summary counts at top

**When to use:**
- Initial review of scan data
- Generating patch notes
- Identifying high-priority updates

---

### JSON Output (`--json`)

**Good for:** Automation, LLM processing, scripting

**Characteristics:**
- Structured data (arrays, objects)
- All items included (no truncation)
- Machine-parseable

**When to use:**
- Piping to another script
- Storing results for later analysis
- Processing with Claude/GPT for recommendations
- Building dashboards or reports

**Example:**
```bash
python scripts/compare_exports.py scan.txt --json | jq '.new_vendors[].npcID'
# Output: List of new vendor NPC IDs
```

---

## Best Practices

### 1. Scan Completely
- Wait for all items to load before closing merchant window
- Look for "..." or loading indicators
- Re-scan if `itemCount` seems low

### 2. Regular Comparisons
- Compare after every major scan session
- Compare before committing DB changes
- Compare after WoW patches (items may change)

### 3. Document Changes
- Save comparison reports with commit
- Reference NPC IDs and item counts in commit messages
- Note source of data (in-game scan, community submission, etc.)

### 4. Verify Before Merging
- Always run comparison on community submissions
- Check for suspicious patterns (all vendors PARTIAL)
- Request re-scan if data looks incomplete

### 5. Keep Exports Organized
```
scans/
  2026-02-08_tww_vendors.txt
  2026-02-08_classic_vendors.txt
  2026-02-09_community_razorwind.txt
```

---

## Related Commands

**In-game developer commands** (require `/hs devmode` first):
- `/hs suggest` — Generate VendorDatabase.lua entries from scans
- `/hs nodecor` — List vendors with zero decor items (flagged for removal)
- `/hs clearnodecor` — Clear no-decor flags (unhide vendors)
- `/hs clearall` — Clear all scan data (nuclear option)

**See also:**
- `VENDOR_Plan.md` — Full vendor scanning system design
- `CLAUDE.md` — Project conventions and patterns
- `TODO.md` — Current session status and next steps

---

## Example Session

```bash
# 1. Compare fresh export
$ python scripts/compare_exports.py tww_scan.txt

Reading export: tww_scan.txt...
  Parsed 28 vendors, 347 items total

Reading database: Data/VendorDatabase.lua...
  Parsed 261 vendors, 2847 items total

======================================================================
COMPARING EXPORT vs DATABASE
======================================================================

SUMMARY
----------------------------------------------------------------------
Vendors in export:           28
Vendors in database:         261
NEW (not in DB):             3
MATCH (identical):           18
UPDATED (new items):         5
FEWER (DB has more):         2

NEW VENDORS (not in database)
----------------------------------------------------------------------
[255278] Gronthul
  Items: 59
  Item IDs: 244662, 250094, 250231, 256330, 256905, ...

[255280] Merchant Kaljir
  Items: 12
  Item IDs: 248808, 248809, 248810, ...

[255290] Groundskeeper Durven
  Items: 8
  Item IDs: 257403, 257404, 257405, ...

UPDATED VENDORS (export has new items)
----------------------------------------------------------------------
[252910] Auditor Balwurz
  Export: 48 items | DB: 44 items
  New items (+4): 256330, 256905, 257403, 257404

# 2. Generate Lua in-game
# /hs devmode
# /hs suggest
# Copy output

# 3. Update VendorDatabase.lua with generated code

# 4. Verify
$ git diff Data/VendorDatabase.lua
# Review changes

# 5. Test
# /reload in-game
# Check map pins appear

# 6. Commit
$ git add Data/VendorDatabase.lua
$ git commit -m "Add 3 TWW vendors, update 5 with new items

- Gronthul [255278]: +59 items
- Merchant Kaljir [255280]: +12 items
- Groundskeeper Durven [255290]: +8 items
- Auditor Balwurz [252910]: +4 items

Co-Authored-By: Royaleint and Claude Code"
```

---

## Summary

The `compare_exports.py` script is the **bridge between in-game scans and the static database**. Use it to:

✅ Find new vendors to add
✅ Identify missing items on existing vendors
✅ Validate community submissions
✅ Catch scan errors early
✅ Maintain data quality

**Typical workflow:** Scan → Export → Compare → Review → Update DB → Test → Commit

For questions or issues, see `VENDOR_Plan.md` or run `python scripts/compare_exports.py --help`.
