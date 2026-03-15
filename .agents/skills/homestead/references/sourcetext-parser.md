# sourceText Parser & Two-Addon Architecture

## Overview

Homestead uses a two-addon architecture to separate player-facing features
from developer/data-mining tools.

### Homestead (Published)
- Player-facing addon, published to CurseForge/Wago
- All collection tracking, map pins, vendor scanning, UI
- `/hs` slash commands for players
- `/hs debug` stays here (useful for player bug reports)

### Homestead_Dev (Never Published)
- Developer tools, data mining, validation
- CatalogDiscoveryScanner (Phase 5)
- Cross-reference reporting (ValidationReport.lua)
- All devmode commands: `suggest`, `nodecor`, `clearnodecor`, `clearall`
- All debug commands: `debugscan`, `testlookup`, `testsource`, `achievements`, `aliases`, `clearaliases`, `debugglobal`
- `/hstest` suite (18 commands, migrated from Home_Dev/scripts/api_test.lua)
- `/hsdev` slash command namespace
- Own SavedVariables: `HomesteadDevDB`
- Dev addon presence = dev mode active (`HA.DevAddon` check)

### Rationale for Split
- Hide dev methods from competitors
- Reduce player code bloat
- Cleaner `/hs help` for end users
- Raw sourceText only stored when dev addon loaded

## sourceText Parser System (6 Phases)

Original plan file deleted (implemented; preserved in git history).

### Phase 1: Parser
- Pure Lua 5.1 string parsing, zero WoW API dependencies
- Codex-eligible (can be developed independently)
- Two-tier parsing:
  - **Structural** (all locales): field/block separation
  - **Typed** (enUS/enGB only): source type extraction

### Phase 2: CatalogScanner Modifications
- Integration hooks for sourceText capture
- Modified scan flow to capture additional data

### Phase 3: SourceTextScanner
- Active scanning module
- Cross-reference reporting → Home_Dev/Homestead_Dev/ValidationReport.lua

### Phase 4: SourceManager Integration
- Unified source data access
- `useParsedSources` toggle gates UI influence (default OFF)

### Phase 5: CatalogDiscoveryScanner
- Full catalog enumeration via decorID iteration
- Lives in Homestead_Dev only
- SavedVariables pruning: 10K cap, 90-day age limit for discoveredItems

### Phase 6: Dev Addon Assembly
- Package all dev-only modules into Homestead_Dev
- Team lead handles integration

## sourceText Format Details

When accessible (from Blizzard UI context, not addon code):
- `|n` field separator within a block
- `|n|n` block separator
- `|Hcurrency:ID|h` hyperlinks for currencies
- No NPC hyperlinks in vendor references

## Key Design Decisions

- **Report-only cross-reference**: No runtime mutation of VendorNameToNPC
- **djb2 rolling hash**: For sourceText change detection between scans
- **Cost format**: `{gold = N*10000, currencies = {{id=N, amount=N}}}` — matches FormatCost()
- **Composite dedupe**: sourceType + name + zone (preserves multi-vendor items)
- **Navigate-to-vendor**: Already fully implemented (waypoints.lua + VendorTracer.lua + VendorMapPins.lua)

## Agent Team Structure (For Parser Development)

4-agent team:
1. **team-lead**: Integration + Phase 6
2. **parser-dev**: Phase 1 (pure Lua parsing)
3. **scanner-dev**: Phases 2, 3, 5 (WoW API interaction)
4. **qa-reviewer**: Read-only review role
