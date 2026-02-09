# Vendor Scanning System Overhaul

## Context

The vendor scanning system detects which merchants sell housing decor. Vendors with **no decor items** should not be in the database and should be flagged for removal. This overhaul addresses:

1. **No-decor vendors reappear after clearing scan data** — `ClearScannedData()` wipes `db.global.scannedVendors`, losing `hasDecor == false`
2. **~45 vendors in VendorDatabase.lua have `items = {}`** — need hiding and flagging for removal
3. **Scanner discards useful data** — `isUsable`, `spellID` extracted but never saved; no location/expansion/currency metadata
4. **No DB maintenance tooling** — comparing export data against VendorDatabase.lua is manual
5. **"Copy All" button misleading** — only selects text (WoW can't access clipboard)

**WoW API limitation**: No API for reputation/quest/achievement requirements on merchant items.

## Implementation Phases

Break into 3 sequential phases to minimize risk:

| Phase | Scope | Risk |
|-------|-------|------|
| **Phase 1** | No-decor tracking + ClearScannedData fix (Parts 1, 4c-4d) | Core bug fix, ships independently |
| **Phase 2** | Enhanced scanner fields + export format (Parts 2, 4a) | New data capture, no behavior change |
| **Phase 2.5** | Experimental tooltip requirement scraping (Part 2.5) | Experimental, user-togglable, degrades gracefully |
| **Phase 3** | Developer tools — `/hs suggest`, `/hs nodecor`, comparison tool (Parts 3, 5) | QoL, gated behind developer mode |

## Files Modified

| File | Changes |
|------|---------|
| `Core/constants.lua` | Add `noDecorVendors = {}`, `developerMode`, `enableRequirementScraping` to global defaults |
| `Modules/VendorScanner.lua` | noDecorVendors tracking (scanConfidence, confirmCount), ClearScannedData fix, ClearNoDecorData, ClearAllData, expansion/currency inference, new item fields, location capture, hidden tooltip requirement scraping |
| `UI/VendorMapPins.lua` | ShouldHideVendor checks `noDecorVendors` with scanConfidence guard |
| `Modules/ExportImport.lua` | ClearScannedData preserves no-decor, V2 format extended (string escaping, sorted items), self-documenting header, requirements field |
| `UI/OutputWindow.lua` | Rename "Copy All" → "Select All" |
| `UI/Options.lua` | Update clear button desc, add "Reset Hidden Vendors" (routes through ClearNoDecorData), add "Scan item requirements" toggle |
| `Core/core.lua` | Add `/hs nodecor`, `/hs clearnodecor`, `/hs clearall`, `/hs suggest`, `/hs devmode`; developer mode gating |
| `scripts/compare_exports.py` | NEW: Python comparison script (extends existing scripts/, excluded from .pkgmeta) |

### Existing functions referenced (verified to exist):
- `VendorDatabase:HasVendor(npcID)` — `Data/VendorDatabase.lua:3016`
- `VendorDatabase:GetVendor(npcID)` — `Data/VendorDatabase.lua:3007`
- `VendorData:GetItemID(item)` — `Data/VendorData.lua:111`
- `VendorDatabase.ZoneToContinentMap` — `Data/VendorDatabase.lua:2789`
- `VendorDatabase.ContinentNames` — `Data/VendorDatabase.lua:2926`

---

## Developer Mode

Phase 3 commands (`/hs suggest`, `/hs nodecor`, `/hs clearnodecor`, `/hs clearall`) are developer tools that should not be exposed to normal users. They are gated behind a developer mode check.

### Enabling developer mode

Use a SavedVariables flag: `db.global.developerMode`. This survives addon updates and doesn't require committing a hardcoded constant.

```lua
-- In Core/constants.lua global defaults:
developerMode = false,
```

To enable locally: `/hs devmode` toggles the flag and prints the new state. Alternatively, manually set in SavedVariables after a `/reload`:
```
HomesteadDB.global.developerMode = true
```

No file-based approach (e.g., checking for `dev_config.lua`) — SavedVariables is simpler, doesn't require TOC changes, and is already the pattern used for other persistent flags.

### Gating commands

In the slash command handler (`Core/core.lua`), wrap Phase 3 commands:

```lua
local function IsDevMode()
    return HA.Addon.db and HA.Addon.db.global and HA.Addon.db.global.developerMode
end

-- In the handler:
elseif input == "devmode" then
    if self.db and self.db.global then
        self.db.global.developerMode = not self.db.global.developerMode
        self:Print("Developer mode: " .. (self.db.global.developerMode and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    end
elseif input == "nodecor" or input == "suggest" or input == "clearnodecor" or input == "clearall" then
    if not IsDevMode() then
        self:Print("Developer mode required. Enable with /hs devmode")
        return
    end
    -- ... existing handlers ...
```

### What is NOT gated

- The **Options UI "Reset Hidden Vendors" button** (Part 4b) is user-facing and ships to everyone. It only clears no-decor flags — a safe, reversible action.
- The `noDecorVendors` write path in `SaveVendorData()` (Part 1b) runs for all users — hiding no-decor vendors is core functionality, not a developer tool.
- The `ShouldHideVendor()` check (Part 1e) runs for all users.

### Python comparison script packaging

The `scripts/` directory is already excluded from `.pkgmeta` packaging (confirmed: line 8 of `.pkgmeta` lists `- scripts`). The comparison tool (`scripts/compare_exports.py`) will not be distributed to users.

---

## Part 1: Persistent No-Decor Vendor Tracking (Phase 1)

### 1a. Add SavedVariables default — `Core/constants.lua`

Inside `global = { ... }`, after the `scannedVendors` entry, add:

```lua
noDecorVendors = {},  -- [npcID] = { name, confirmedAt, itemCount, inDatabase, scanConfidence, confirmCount }
```

### 1b. Maintain noDecorVendors in `SaveVendorData()` — `Modules/VendorScanner.lua`

After the line that saves to `scannedVendors[npcID]`, add:

```lua
-- Maintain persistent no-decor tracking (survives ClearScannedData)
if not HA.Addon.db.global.noDecorVendors then
    HA.Addon.db.global.noDecorVendors = {}
end

-- Determine scan confidence: "confirmed" only if scan completed AND all item
-- slots returned valid data. "unknown" if scan completed but any
-- GetMerchantItemInfo() call returned nil during ProcessScanQueue().
local scanConfidence = "unknown"
if scanData.scanComplete and not scanData.hadNilSlots then
    scanConfidence = "confirmed"
end

if vendorRecord.hasDecor == false and scanConfidence == "confirmed" then
    -- Only flag when scan is fully confirmed (no interruption, no nil slots)
    local existing = HA.Addon.db.global.noDecorVendors[scanData.npcID]
    local confirmCount = (existing and existing.confirmCount or 0) + 1
    local inStaticDB = HA.VendorDatabase and HA.VendorDatabase:HasVendor(scanData.npcID)
    HA.Addon.db.global.noDecorVendors[scanData.npcID] = {
        name = vendorRecord.name,
        confirmedAt = time(),
        itemCount = vendorRecord.itemCount,
        inDatabase = inStaticDB,       -- snapshot; /hs nodecor uses live check
        scanConfidence = "confirmed",  -- tri-state: "confirmed" or "unknown"
        confirmCount = confirmCount,   -- must reach 2 before inDatabase is actionable
    }
    if inStaticDB and confirmCount >= 2 then
        HA.Addon:Print(string.format(
            "|cffff9900No-Decor:|r %s (NPC %d) has %d items but 0 decor. Flagged for removal (confirmed %dx).",
            vendorRecord.name, scanData.npcID, vendorRecord.itemCount, confirmCount
        ))
    elseif inStaticDB then
        HA.Addon:Print(string.format(
            "|cffff9900No-Decor:|r %s (NPC %d) has %d items but 0 decor. Needs 1 more scan to flag for removal.",
            vendorRecord.name, scanData.npcID, vendorRecord.itemCount
        ))
    end
elseif vendorRecord.hasDecor == true then
    -- Re-scan found decor: unhide vendor
    HA.Addon.db.global.noDecorVendors[scanData.npcID] = nil
end
```

**Scan confidence model**: `scanComplete` only means the merchant window didn't close early — it does NOT mean every item slot returned valid data. Items can fail to load (slow connection, server lag) while the scan still "completes." The `scanConfidence` field captures this distinction:

- `"confirmed"` — scan completed normally (`scanComplete == true`) AND every `GetMerchantItemInfo()` call returned valid data (`hadNilSlots == false`). Safe to persist as no-decor.
- `"unknown"` — scan completed but one or more item slots returned nil/incomplete data. The vendor may have decor items that simply failed to load.

`hadNilSlots` is determined by tracking whether any `GetMerchantItemInfo()` call returned nil during `ProcessScanQueue()`. Only `"confirmed"` scans are persisted to `noDecorVendors`.

**Two-scan threshold**: A single confirmed scan is sufficient to HIDE a vendor (reversible via `/hs clearnodecor`). But flagging `inDatabase = true` (which tells a developer to DELETE a static DB entry) only becomes actionable when `confirmCount >= 2`, guarding against API variability across sessions.

### 1c. Fix `ClearScannedData()` and add targeted clear functions — `Modules/VendorScanner.lua`

Replace the function body. Key change: do NOT clear `noDecorVendors`.

```lua
function VendorScanner:ClearScannedData()
    if HA.Addon.db and HA.Addon.db.global then
        HA.Addon.db.global.scannedVendors = {}
        -- noDecorVendors intentionally preserved
    end
    scannedVendorsThisSession = {}
    HA.Addon:Debug("Cleared scanned vendor data (no-decor flags preserved)")
end
```

Add `ClearNoDecorData()` — clears ONLY the no-decor list (used by `/hs clearnodecor` and Options button):

```lua
function VendorScanner:ClearNoDecorData()
    local count = 0
    if HA.Addon.db and HA.Addon.db.global and HA.Addon.db.global.noDecorVendors then
        for _ in pairs(HA.Addon.db.global.noDecorVendors) do count = count + 1 end
        HA.Addon.db.global.noDecorVendors = {}
    end
    if HA.VendorMapPins then
        HA.VendorMapPins:InvalidateAllCaches()
    end
    HA.Addon:Print(string.format("Cleared %d no-decor flag(s). Hidden vendors will reappear.", count))
end
```

Add `ClearAllData()` — nuclear option, clears both tables (used by `/hs clearall`):

```lua
function VendorScanner:ClearAllData()
    if HA.Addon.db and HA.Addon.db.global then
        HA.Addon.db.global.scannedVendors = {}
        HA.Addon.db.global.noDecorVendors = {}
    end
    scannedVendorsThisSession = {}
    if HA.VendorMapPins then
        HA.VendorMapPins:InvalidateAllCaches()
    end
    HA.Addon:Debug("Cleared ALL vendor data including no-decor flags")
end
```

### 1d. Fix `ClearScannedData()` in ExportImport — `Modules/ExportImport.lua`

Update the print message in the existing `ClearScannedData()` to note preservation:

```lua
HA.Addon:Print(string.format("Cleared %d scanned vendor(s). No-decor flags preserved.", count))
```

### 1e. Update `ShouldHideVendor()` — `UI/VendorMapPins.lua`

Add `noDecorVendors` check before the existing `scannedVendors` check:

```lua
local function ShouldHideVendor(vendor)
    if not vendor then return true end
    if vendor.unreleased then return true end

    local npcID = vendor.npcID
    if not npcID then return false end

    local db = HA.Addon and HA.Addon.db and HA.Addon.db.global
    if not db then return false end

    -- Persistent no-decor list (survives ClearScannedData)
    if db.noDecorVendors and db.noDecorVendors[npcID] then
        local data = db.noDecorVendors[npcID]
        -- Defensive: only trust confirmed entries (guards against corrupted SVs)
        if data.scanConfidence == "confirmed" or data.scanComplete then
            return true
        end
    end

    -- Current scan data
    if db.scannedVendors then
        local scannedData = db.scannedVendors[npcID]
        if scannedData then
            if scannedData.hasDecor == false then
                return true
            elseif scannedData.hasDecor == nil then
                local scannedItems = scannedData.items or scannedData.decor
                if scannedItems and #scannedItems == 0 then
                    return true
                end
            end
        end
    end

    return false
end
```

---

## Part 2: Enhanced Scanner Data Capture (Phase 2)

### Important: Do NOT cache global API functions at file load time

`GetSubZoneText()`, `GetRealZoneText()`, `C_Map.GetMapInfo()` must be called inline at runtime, never upvalued at the top of the file. This is an existing anti-pattern in the codebase — see CLAUDE.md Rule #2.

### 2a. Capture location data — `Modules/VendorScanner.lua`

In `StartScan()`, after capturing mapID and position, add:

```lua
-- Get location context (called inline — NOT cached at file load time)
local mapInfo = mapID and C_Map.GetMapInfo(mapID) or nil
local zoneName = mapInfo and mapInfo.name or nil
local parentMapID = mapInfo and mapInfo.parentMapID or nil
local subZone = GetSubZoneText() or nil    -- Global WoW API, do NOT upvalue
local realZone = GetRealZoneText() or nil  -- Global WoW API, do NOT upvalue
```

Add to `scanQueue` initialization:
```lua
zone = zoneName,
subZone = subZone,
realZone = realZone,
parentMapID = parentMapID,
```

In `SaveVendorData()`, add to vendor record:
```lua
zone = scanData.zone,
subZone = scanData.subZone,
realZone = scanData.realZone,
parentMapID = scanData.parentMapID,
```

### 2b. Save additional fields per item — `Modules/VendorScanner.lua`

In `ProcessScanQueue()`, add `isUsable` and `spellID` to the decor item insertion:

```lua
isUsable = isUsable,    -- NEW: whether player can use/buy this
spellID = spellID,      -- NEW: associated spell if any
```

In `SaveVendorData()`, include them in the saved item record:

```lua
isUsable = item.isUsable,
spellID = item.spellID,
```

**Note on ownership data**: `CheckIfDecorItem()` calls `C_HousingCatalog.GetCatalogEntryInfoByItem()` which is listed as tainted in CLAUDE.md. However, it's wrapped in `pcall` and the scanner currently uses it successfully for decor detection. Ownership fields (`isOwned`, `quantityOwned`) from `catalogInfo` may or may not be available depending on taint context. **Do NOT add ownership fields in this phase** — defer until we can confirm they're reliably populated during merchant window context.

### 2c. Infer expansion from continent — `Modules/VendorScanner.lua`

Use the existing `VendorDatabase.ContinentNames` and `ZoneToContinentMap` tables. Add a local mapping from continent mapID to expansion name:

```lua
-- Continent mapID → expansion (derived from VendorDatabase.ContinentNames)
-- Note: EK (13) and Kalimdor (12) default to "Classic" but may contain
-- TBC/Cataclysm vendors — this is best-effort. Static DB expansion is authoritative.
local ContinentToExpansion = {
    [12]   = "Classic",              -- Kalimdor
    [13]   = "Classic",              -- Eastern Kingdoms
    [113]  = "Wrath of the Lich King", -- Northrend
    [424]  = "Mists of Pandaria",    -- Pandaria
    [572]  = "Warlords of Draenor",  -- Draenor
    [619]  = "Legion",               -- Broken Isles
    [875]  = "Battle for Azeroth",   -- Zandalar
    [876]  = "Battle for Azeroth",   -- Kul Tiras
    [1550] = "Shadowlands",          -- Shadowlands
    [1978] = "Dragonflight",         -- Dragon Isles
    [2274] = "The War Within",       -- Khaz Algar
}
```

**Verified**: These 11 continent IDs match exactly with `VendorDatabase.ContinentNames` (line 2926). TBC/Outland and Cataclysm-specific continents are NOT in the table because their zones map to EK/Kalimdor parents.

In `StartScan()`, resolve expansion:
```lua
local expansion = nil
if parentMapID then
    expansion = ContinentToExpansion[parentMapID]
end
if not expansion and mapID and HA.VendorDatabase and HA.VendorDatabase.ZoneToContinentMap then
    local continentID = HA.VendorDatabase.ZoneToContinentMap[mapID]
    if continentID then
        expansion = ContinentToExpansion[continentID]
    end
end
```

### 2d. Infer primary currency — `Modules/VendorScanner.lua`

After building item records in `SaveVendorData()`, derive the dominant currency:

```lua
local currencyCounts = {}
for _, item in ipairs(vendorRecord.items) do
    if item.currencies then
        for _, c in ipairs(item.currencies) do
            local key = c.name or ("Currency " .. tostring(c.currencyID or "?"))
            currencyCounts[key] = (currencyCounts[key] or 0) + 1
        end
    end
end
local maxCount, primaryCurrency = 0, nil
for name, count in pairs(currencyCounts) do
    if count > maxCount then
        maxCount = count
        primaryCurrency = name
    end
end
vendorRecord.currency = primaryCurrency
vendorRecord.expansion = scanData.expansion  -- from 2c
```

### 2e. Deterministic export order + self-documenting V2 header — `Modules/ExportImport.lua`

In `ExportScannedVendors()`, sort vendor keys before iteration (currently uses `pairs()` which is non-deterministic):

```lua
-- Collect and sort npcIDs for deterministic output
local sortedNPCs = {}
for npcID in pairs(scannedVendors) do
    table.insert(sortedNPCs, npcID)
end
table.sort(sortedNPCs)
-- Then iterate: for _, npcID in ipairs(sortedNPCs) do ...
```

Within each vendor's item loop, sort items by itemID for deterministic output:

```lua
-- Sort items within each vendor for stable diffs
local sortedItems = {}
for _, item in ipairs(vendor.items or {}) do
    table.insert(sortedItems, item)
end
table.sort(sortedItems, function(a, b) return (a.itemID or 0) < (b.itemID or 0) end)
-- Then iterate sortedItems instead of vendor.items
```

After the version prefix line, add field-name comments:

```lua
table.insert(output, EXPORT_PREFIX .. "\n")
table.insert(output, "# V: npcID\tname\tmapID\tx\ty\tfaction\ttimestamp\titemCount\tdecorCount\tzone\tsubZone\tparentMapID\texpansion\tcurrency\n")
table.insert(output, "# I: npcID\titemID\tname\tprice\tcostData\tisUsable\tspellID\n")
```

In import parsing loop, skip `#` comment lines:

```lua
if lineType == "#" then
    -- Skip header comments
```

### 2f. Extend V2 export/import format — `Modules/ExportImport.lua`

**Vendor line** — append zone, subZone, parentMapID, expansion, currency (backward-compatible trailing fields):

**Item line** — append isUsable, spellID

Import reads new fields with nil defaults for missing positions.

### 2g. String field escaping in export — `Modules/ExportImport.lua`

New string fields (zone, subZone, expansion, currency) are tab-delimited. To prevent parsing errors:

- **On export**: Replace any tab characters in string fields with spaces. Replace any newline characters with spaces. Apply before writing each field.
- **On import**: No un-escaping needed — the replacement is lossy but safe.
- **Helper function**:

```lua
local function SanitizeExportField(value)
    if type(value) ~= "string" then return value or "" end
    return value:gsub("[\t\n\r]", " ")
end
```

Document this in the V2 header comments alongside the field definitions.

---

## Part 2.5: Experimental Tooltip Requirement Scraping (Phase 2)

> **Warning: EXPERIMENTAL** — Tooltip scraping depends on Blizzard's tooltip format remaining stable. This feature includes a user-facing toggle and will degrade gracefully if tooltip format changes.

### Context

WoW has no API to get reputation, quest, or achievement requirements for merchant items. The only way to extract this data is by reading tooltip text from a hidden scanning tooltip frame. This WILL break if Blizzard changes tooltip formatting, so it must be built to fail gracefully.

### 2.5a. Create hidden scanning tooltip — `Modules/VendorScanner.lua`

Create a dedicated hidden tooltip frame. Do NOT use `GameTooltip` — that would interfere with the player's visible tooltips.

```lua
local scanTooltip = CreateFrame("GameTooltip", "HomesteadScanTooltip", UIParent, "GameTooltipTemplate")
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
```

This frame is created once at module initialization and reused for all scans.

### 2.5b. Read tooltip lines during ProcessScanQueue() — `Modules/VendorScanner.lua`

After identifying each item in `ProcessScanQueue()`, set the hidden tooltip and read requirement lines. All tooltip reading must be wrapped in `pcall`.

```lua
local function ScrapeItemRequirements(slotIndex)
    -- Check if scraping is enabled
    local db = HA.Addon and HA.Addon.db and HA.Addon.db.global
    if not db or db.enableRequirementScraping == false then
        return nil  -- nil = "could not check" (feature disabled)
    end

    -- Check locale support
    local locale = GetLocale()
    if not RequirementPatterns[locale] then
        return nil  -- nil = "could not check" (unsupported locale)
    end

    local ok, requirements = pcall(function()
        scanTooltip:ClearLines()
        scanTooltip:SetMerchantItem(slotIndex)

        local numLines = scanTooltip:NumLines()
        if numLines == 0 then
            return nil  -- tooltip failed to populate
        end

        local reqs = {}
        local patterns = RequirementPatterns[locale]

        for i = 1, numLines do
            local line = _G["HomesteadScanTooltipTextLeft" .. i]
            if line then
                local text = line:GetText()
                local r, g, b = line:GetTextColor()

                -- Red text indicates unmet requirements (r > 0.9, g < 0.2, b < 0.2)
                if text and r and r > 0.9 and g < 0.2 and b < 0.2 then
                    local matched = false

                    -- Try each pattern type
                    for _, patternDef in ipairs(patterns) do
                        local captures = { text:match(patternDef.pattern) }
                        if #captures > 0 then
                            local req = patternDef.build(captures)
                            if req then
                                table.insert(reqs, req)
                                matched = true
                                break
                            end
                        end
                    end

                    -- Unrecognized red text — store raw for developer review
                    if not matched then
                        table.insert(reqs, { type = "unknown", text = text })
                    end
                end
            end
        end

        return reqs  -- {} = "checked, found none"; populated = requirements found
    end)

    if ok then
        return requirements
    else
        return nil  -- pcall failed — treat as "could not check"
    end
end
```

### 2.5c. Requirement patterns (locale-keyed) — `Modules/VendorScanner.lua`

Structure patterns in a locale-keyed table. Only enUS is populated initially. Each entry has a regex pattern and a builder function that creates the requirement record.

```lua
-- Locale-keyed requirement patterns.
-- Only enUS is populated. Future locales: deDE, frFR, esES, ptBR, ruRU, koKR, zhCN, zhTW
local RequirementPatterns = {
    enUS = {
        {
            -- "Requires The Undying Army - Honored"
            pattern = "^Requires (.+) %- (.+)$",
            build = function(c) return { type = "reputation", faction = c[1], standing = c[2] } end,
        },
        {
            -- "Requires: Completion of quest 'Example'" or "Requires: Something"
            pattern = "^Requires: (.+)$",
            build = function(c) return { type = "quest", name = c[1] } end,
        },
        {
            -- "Requires Raise an Army (12345)" — achievement with ID
            pattern = "^Requires (.+) %((%d+)%)$",
            build = function(c) return { type = "achievement", name = c[1], id = tonumber(c[2]) } end,
        },
        {
            -- "Requires Level 70"
            pattern = "^Requires Level (%d+)$",
            build = function(c) return { type = "level", level = tonumber(c[1]) } end,
        },
    },
    -- deDE = { ... },
    -- frFR = { ... },
}
```

### 2.5d. Integrate into scan flow — `Modules/VendorScanner.lua`

In `ProcessScanQueue()`, after the existing `CheckIfDecorItem()` call:

```lua
-- Scrape requirements from hidden tooltip (experimental)
local requirements = ScrapeItemRequirements(slotIndex)
-- requirements: nil = could not check, {} = no requirements, table = has requirements
```

Add to the item record being built:
```lua
requirements = requirements,
```

In `SaveVendorData()`, include in the saved item record:
```lua
requirements = item.requirements,
```

### 2.5e. SavedVariables toggle — `Core/constants.lua`

Add to global defaults:
```lua
enableRequirementScraping = true,  -- experimental: tooltip-based requirement detection
```

### 2.5f. Options toggle — `UI/Options.lua`

Add a toggle in the scanning section:

```lua
enableRequirementScraping = {
    type = "toggle",
    name = "Scan item requirements (experimental)",
    desc = "Reads tooltip text to detect reputation, quest, and achievement requirements. May break after WoW patches.",
    order = 25,
    get = function() return HA.Addon.db.global.enableRequirementScraping end,
    set = function(_, val) HA.Addon.db.global.enableRequirementScraping = val end,
},
```

### 2.5g. V2 export format for requirements — `Modules/ExportImport.lua`

Requirements are variable-length structured data. Tab-delimited fields won't work cleanly, so encode as a JSON-like string in the export.

**Export**: Append a requirements field to the item line. Format: `R:` prefix followed by semicolon-separated requirement entries. Each entry is `type=value` pairs joined by commas.

```
I  npcID  itemID  name  price  costData  isUsable  spellID  R:reputation,faction=The Undying Army,standing=Honored;level,level=70
```

- If `requirements == nil`: omit the field entirely (or write empty string)
- If `requirements == {}`: write `R:none` (explicitly checked, no requirements)
- If requirements present: write `R:` followed by encoded entries

**Import**: Parse the `R:` field back into the requirements table structure. Missing field → `nil`. `R:none` → `{}`.

### Distinction: nil vs {} vs populated

This three-state model is critical:
- `requirements = nil` — could not check (feature disabled, unsupported locale, pcall failed, tooltip empty)
- `requirements = {}` — checked and confirmed: no requirements on this item
- `requirements = { ... }` — checked and found: specific requirements detected

Code that reads requirements must handle all three states.

### Performance

One hidden tooltip read per item during scan. This adds ~1-2ms per item. For a vendor with 50 items, that's 50-100ms total, spread across the existing batched scan queue. No ongoing cost outside of active scanning. No new timers, frames (beyond the one-time tooltip creation), or OnUpdate hooks.

---

## Part 3: DB Maintenance Tools (Phase 3)

### 3a. `/hs suggest` — Generate VendorDatabase.lua entries — `Core/core.lua`

New `GenerateDBSuggestions()` function that outputs paste-ready Lua code.

**Important: Lua 5.1 has no `goto` keyword**. Use if/else flag pattern instead:

```lua
function HousingAddon:GenerateDBSuggestions()
    local scanned = self.db.global.scannedVendors
    if not scanned or not next(scanned) then
        self:Print("No scanned data. Visit vendors first.")
        return
    end

    local output = {}
    local newVendors, updatedVendors = 0, 0

    for npcID, vendor in pairs(scanned) do
        local shouldProcess = vendor.hasDecor == true or
            (vendor.items and #vendor.items > 0)

        if shouldProcess then
            local existing = HA.VendorDatabase and HA.VendorDatabase:GetVendor(npcID)
            local items = vendor.items or {}

            if not existing then
                -- NEW vendor: generate full entry
                newVendors = newVendors + 1
                table.insert(output, string.format("    -- NEW VENDOR (scanned %s)",
                    date("%Y-%m-%d", vendor.lastScanned or 0)))
                table.insert(output, string.format("    [%d] = {", npcID))
                table.insert(output, string.format('        name = "%s",',
                    (vendor.name or "?"):gsub('"', '\\"')))
                table.insert(output, string.format("        mapID = %d,", vendor.mapID or 0))
                table.insert(output, string.format("        x = %.4f, y = %.4f,",
                    vendor.coords and vendor.coords.x or 0,
                    vendor.coords and vendor.coords.y or 0))
                table.insert(output, string.format('        zone = "%s",', vendor.zone or ""))
                table.insert(output, string.format('        faction = "%s",',
                    vendor.faction or "Neutral"))
                table.insert(output, string.format('        expansion = "%s",',
                    vendor.expansion or "Unknown"))
                table.insert(output, string.format('        currency = "%s",',
                    vendor.currency or "Gold"))
                table.insert(output, "        items = {")
                for _, item in ipairs(items) do
                    if item.currencies and #item.currencies > 0 then
                        local currParts = {}
                        for _, c in ipairs(item.currencies) do
                            table.insert(currParts, string.format(
                                "{id = %s, amount = %d}",
                                c.currencyID and tostring(c.currencyID) or "nil",
                                c.amount or 0))
                        end
                        local goldPart = (item.price and item.price > 0)
                            and string.format("gold = %d, ", item.price) or ""
                        table.insert(output, string.format(
                            "            {%d, cost = {%scurrencies = {%s}}}, -- %s",
                            item.itemID, goldPart,
                            table.concat(currParts, ", "),
                            item.name or ""))
                    elseif item.price and item.price > 0 then
                        table.insert(output, string.format(
                            "            {%d, cost = {gold = %d}}, -- %s",
                            item.itemID, item.price, item.name or ""))
                    else
                        table.insert(output, string.format(
                            "            %d, -- %s", item.itemID, item.name or ""))
                    end
                end
                table.insert(output, "        },")
                table.insert(output, "    },")
                table.insert(output, "")
            else
                -- EXISTING vendor: show new items not in static DB
                local existingItems = {}
                if existing.items then
                    for _, item in ipairs(existing.items) do
                        local id = HA.VendorData and HA.VendorData:GetItemID(item)
                        if id then existingItems[id] = true end
                    end
                end
                local newItems = {}
                for _, item in ipairs(items) do
                    if item.itemID and not existingItems[item.itemID] then
                        table.insert(newItems, item)
                    end
                end
                if #newItems > 0 then
                    updatedVendors = updatedVendors + 1
                    table.insert(output, string.format("    -- %s [%d]: ADD %d item(s)",
                        vendor.name or "?", npcID, #newItems))
                    for _, item in ipairs(newItems) do
                        table.insert(output, string.format("    --   + %d (%s)",
                            item.itemID, item.name or "?"))
                    end
                    table.insert(output, "")
                end
            end
        end
    end

    if #output == 0 then
        self:Print("No DB changes suggested. Scanned data matches VendorDatabase.")
    else
        local header = string.format(
            "-- DB Suggestions: %d new vendors, %d vendors with new items\n\n",
            newVendors, updatedVendors)
        if HA.OutputWindow then
            HA.OutputWindow:Show("DB Suggestions", header .. table.concat(output, "\n"))
        end
    end
end
```

### 3b. `/hs nodecor` — Report non-decor vendors — `Core/core.lua`

```lua
elseif input == "nodecor" then
    local noDecor = self.db and self.db.global and self.db.global.noDecorVendors
    if not noDecor or not next(noDecor) then
        self:Print("No vendors flagged as non-decor.")
    else
        local lines = {}
        local dbCount, totalCount = 0, 0
        for npcID, data in pairs(noDecor) do
            totalCount = totalCount + 1
            local prefix = ""
            -- Live check: inDatabase snapshot may be stale after DB updates ship
            local isInDB = HA.VendorDatabase and HA.VendorDatabase:HasVendor(npcID)
            if isInDB and (data.confirmCount or 1) >= 2 then
                dbCount = dbCount + 1
                prefix = "|cffff0000[REMOVE]|r "
            elseif isInDB then
                prefix = "|cffff9900[1 SCAN]|r "
            end
            table.insert(lines, string.format(
                "%s%s (NPC %d) — %d items, 0 decor — confirmed %s",
                prefix, data.name or "?", npcID, data.itemCount or 0,
                date("%Y-%m-%d", data.confirmedAt or 0)))
        end
        table.sort(lines)
        local header = string.format(
            "Non-Decor Vendors: %d total, %d in VendorDatabase (need removal)\n\n",
            totalCount, dbCount)
        if HA.OutputWindow then
            HA.OutputWindow:Show("Non-Decor Vendors", header .. table.concat(lines, "\n"))
        else
            self:Print(header)
            for _, line in ipairs(lines) do self:Print(line) end
        end
    end
```

### 3c. Slash command registration — `Core/core.lua`

After the `clearscans` handler, add:
```lua
elseif input == "nodecor" then ...
elseif input == "clearnodecor" then
    -- Clears ONLY the no-decor list (hidden vendors reappear)
    if HA.VendorScanner and HA.VendorScanner.ClearNoDecorData then
        HA.VendorScanner:ClearNoDecorData()
    end
elseif input == "clearall" then
    -- Nuclear: clears BOTH scannedVendors AND noDecorVendors
    if HA.VendorScanner and HA.VendorScanner.ClearAllData then
        HA.VendorScanner:ClearAllData()
    end
elseif input == "suggest" then
    self:GenerateDBSuggestions()
```

Add to help text:
```lua
self:Print("  /hs nodecor - List non-decor vendors (flagged for removal)")
self:Print("  /hs suggest - Generate VendorDatabase.lua entries from scans")
self:Print("  /hs clearnodecor - Clear no-decor flags (hidden vendors reappear)")
self:Print("  /hs clearall - Clear ALL vendor data including no-decor flags")
```

---

## Part 4: Export & UI Improvements (Phase 2)

### 4a. Fix "Copy All" button — `UI/OutputWindow.lua`

Change button text and message in `CreateOutputWindow()`:

```lua
copyBtn:SetText("Select All")
-- ...
HA.Addon:Print("All text selected. Press Ctrl+C to copy to clipboard.")
```

### 4b. Update clear button in Options — `UI/Options.lua`

Update existing `clearScannedButton` description:
```lua
desc = "Remove all scanned vendor data. No-decor vendor hiding is preserved.",
```

Add `resetNoDecorButton` after `clearScannedButton` (order = 17):

```lua
resetNoDecorButton = {
    type = "execute",
    name = "|cffff0000Reset Hidden Vendors|r",
    desc = "Clear the persistent no-decor list. Hidden vendors reappear until re-scanned.",
    order = 17,
    confirm = true,
    confirmText = "Un-hide all vendors confirmed as non-decor. They reappear until re-scanned.",
    func = function()
        -- Route through shared function (handles count, print, cache invalidation)
        if HA.VendorScanner and HA.VendorScanner.ClearNoDecorData then
            HA.VendorScanner:ClearNoDecorData()
        end
    end,
},
```

---

## Part 5: Developer Comparison Tool (Phase 3)

### New file: `scripts/compare_exports.py`

Python script extending the existing `scripts/` tooling (9 scripts already exist). Uses patterns from `scripts/compare_addon_vendors.py` which already parses VendorDatabase.lua with regex.

**Rationale**: Python over Lua because (a) existing scripts use Python, (b) Python has `json`, `re`, `argparse` stdlib, (c) VendorDatabase.lua regex parsing is already solved in `compare_addon_vendors.py`.

**Usage**: `python scripts/compare_exports.py export_data.txt [--db Data/VendorDatabase.lua]`

**Implementation approach**:
- Parse V2 export: Split on newlines, skip `#` comments, parse `V`/`I` lines by tab-splitting
- Parse VendorDatabase.lua: Reuse regex patterns from `compare_addon_vendors.py` — `\[(\d+)\] = \{` for vendor blocks, brace-depth tracking for block boundaries, `(\d+),` and `\{(\d+),` for polymorphic item IDs
- Compare: For each exported vendor, check if npcID exists in DB. For matching vendors, compare item ID sets. Flag: NEW (not in DB), MATCH (same items), UPDATED (has new items), FEWER (DB has items not in export)
- Output: Summary counts + per-vendor diff report to stdout
- Optional `--json` flag for machine-readable output (useful for Claude processing)

---

## Performance Impact

- `noDecorVendors` check: O(1) hash lookup in `ShouldHideVendor()`
- New fields (`isUsable`, `spellID`, `zone`, `expansion`, `currency`): negligible additional API calls — three calls (`GetMapInfo()`, `GetSubZoneText()`, `GetRealZoneText()`) once per scan start for location data
- `ContinentToExpansion` lookup: 11-entry static table, one lookup per scan
- `/hs suggest`, `/hs nodecor`: only on explicit user action
- No new timers, frames, or OnUpdate hooks

---

## Migration & Compatibility

### Old exports (V1) imported after V2 ships
New trailing fields (`zone`, `subZone`, `parentMapID`, `expansion`, `currency`, `isUsable`, `spellID`) default to nil when not present in the import data. The import parser must handle missing trailing fields gracefully — split the line and read positionally, treating any missing positions as nil.

### Exports with # header comments
The import parser skips lines where the first field is `#`. This is already specified in Part 2e but restated here for completeness.

### Existing scannedVendors records missing new keys
Code must nil-check new fields (`zone`, `expansion`, `currency`, `scanConfidence`) everywhere they're read. No backfill on upgrade — old records simply lack the fields. The export format writes `""` for nil string fields and omits nil numeric fields.

### noDecorVendors schema changes
Existing entries (from before this overhaul) won't have `confirmCount` or `scanConfidence`. Fallback behavior:
- Missing `confirmCount` → treat as `1` (one prior confirmed scan assumed)
- Missing `scanConfidence` → treat as `"unknown"` (conservative; entry was written before the guard existed)
- The `scanComplete` field is retained for backward compatibility in `ShouldHideVendor()` — entries with `scanComplete = true` but no `scanConfidence` are still trusted

---

## Verification

### Phase 1 (Core fix)
1. `/reload` — no errors
2. Visit non-decor vendor → hidden from map, flagged in chat
3. `/hs clearscans` → vendor stays hidden
4. `/hs clearnodecor` → vendor reappears
5. Re-scan vendor that now has decor → auto-unhides

### Phase 2 (Enhanced data)
6. Visit decor vendor → check `isUsable`, `spellID`, `zone`, `expansion`, `currency` in scan data
7. `/hs export` → verify "Select All" button, new V2 fields present, `#` header comments
8. Import an export → verify new fields preserved

### Phase 2.5 (Tooltip scraping — experimental)
9. Visit a vendor with rep-locked items → check scan data shows `requirements` populated
10. Visit a vendor with no requirements → check `requirements = {}` (empty table, not nil)
11. Disable "Scan item requirements" in Options → check `requirements = nil` on next scan
12. Test on a non-enUS client → confirm scraping is skipped gracefully (requirements = nil)

### Phase 3 (Developer tools)
13. Enable developer mode: `/hs devmode` → confirm ON message
14. `/hs suggest` → generates paste-ready Lua for new/updated vendors
15. `/hs nodecor` → lists non-decor vendors with `[REMOVE]` tags (live HasVendor check)
16. `/hs clearnodecor` → clears only no-decor flags, vendor reappears
17. `/hs clearall` → clears both scannedVendors and noDecorVendors
18. Disable developer mode: `/hs devmode` → confirm OFF, then `/hs suggest` → "Developer mode required"
19. `python scripts/compare_exports.py` → outputs diff report

## Static DB Cleanup (Manual Follow-up)

After scanning vendors in-game, use `/hs nodecor` to identify which VendorDatabase.lua entries to remove. Currently ~45 vendors have `items = {}` — many may not sell decor and should be removed after in-game confirmation.
