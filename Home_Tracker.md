# Homestead — Tracker

Active and queued work for the Homestead addon. Completed items live in
`Home_Completed.md`. Cross-project status rollup lives in
`BawrLabs/INDEX.md`.

## Backlog

### Next Release

*(None — populated by Rawb as scope decisions are made.)*

### Bugs

### HS-052 World map panel taint — ShiftMapRight / UnifyTopBorder
- **Type:** Bug
- **Priority:** High
- **Status:** Backlog
- **Acceptance criteria:** No taint errors when hovering Blizzard world map POIs (area POI, quest POI, world quest, quest offers) with the side panel open and docked.
- **Session context:** `ShiftMapRight()` calls `WorldMapFrame:SetPoint()` directly, tainting the protected frame's layout. `UnifyTopBorder()` reads `GetTop()`/`GetBottom()` from protected children (NavBar, BorderFrame, ScrollContainer) and modifies `TopEdge:SetPoint()`. `ApplyContentInset()` reads `GetBottom()` from protected children. The `HomesteadWorldMapProvider` ticker reads `canvas:GetWidth()` every 0.1s. All in `UI/MapSidePanel.lua` and `UI/HomesteadWorldMapProvider.lua`. Taint cascades to `GameTooltip` widget system (`GameTooltip_AddWidgetSet`, `GameTooltip_InsertFrame`), quest frame, and tooltip layout. Latest 2026-03-28 user-reported secret-number stacks matched the now-fixed UISpecialFrames taint, so this item remains unconfirmed until reproduced with `09e93ad` in place.
- **Notes:** Separate from the UISpecialFrames taint, which was fully removed in `09e93ad` after the original partial fix in `8f906ff`. Pre-existing since panel border integration was built. Requires reworking how the panel docks to the map — cannot directly call SetPoint/GetTop/GetBottom on WorldMapFrame or its protected children. Needs PLAN_TEMPLATE.md.

### HS-062 ADDON_ACTION_FORBIDDEN on world map toggle in PvP (PerformEmote taint)
- **Type:** Bug
- **Priority:** Medium
- **Status:** Backlog
- **GitHub:** [#33](https://github.com/Royaleint/Homestead/issues/33)
- **Reported:** 2026-04-13, via BugGrabber capture during a PvP match (Homestead v2.3.1).
- **Symptom:** `ADDON_ACTION_FORBIDDEN: AddOn 'Homestead' tried to call the protected function 'PerformEmote()'` fires when the user opens the world map in PvP. Map still opens; error is noise, not a functional block.
- **Stack:** Entirely Blizzard code — `TOGGLEWORLDMAP` → `ToggleWorldMap` → `HandleUserActionToggleSelf` → `SetDisplayState` → `ShowUIPanel` → `SetAttribute` → `Show` → `Blizzard_WorldMap.lua:352` (anon handler) → `PerformEmote`. Homestead does not appear in the stack. This is a **taint cascade**, not a direct call — Blizzard attributes blame to the most-recently-tainted addon in the execution context.
- **Suspect code paths (`UI/MapSidePanel.lua`):**
  - `hooksecurefunc(WorldMapFrame, "HandleUserActionMaximizeSelf", ...)` at 4074 and `"MinimizeSelf"` at 4093 — siblings to the `HandleUserActionToggleSelf` in the stack.
  - `hooksecurefunc(WorldMapFrame, "SetMapID", ...)` at 4019.
  - `hooksecurefunc(WorldMapFrame, "RefreshOverlayFrames", ...)` at 2208.
  - `WorldMapFrame:SetPoint(...)` in `ShiftMapRight` (~3120) for side-panel nudge.
  - `SetParent(panelFrame)` on Blizzard-owned subframes (`portraitContainer`, `navBar`, `tutorial`) at 3207–3278 for integrated mode.
- **Acceptance criteria:** BugGrabber no longer captures `ADDON_ACTION_FORBIDDEN / PerformEmote` attributed to Homestead when opening the world map, in PvP and in all other contexts verified during the investigation. Side-panel integration still works on default UI.
- **Investigation plan (Gate 0, before any fix):**
  1. Reproduce without PvP — dungeon, raid, arena lobby, BG waiting room, open world. PvP may just be first-noticed, not causal.
  2. Test with `integrateMapBorder = false` (standalone mode) — if error disappears, the reparenting of Blizzard subframes is the taint source. Standalone mode doesn't reparent.
  3. If standalone mode still errors, the `hooksecurefunc` closures on `HandleUserActionMaximizeSelf`/`MinimizeSelf` become prime suspects — disable those hooks and retest.
  4. Investigate replacing `SetParent` on Blizzard subframes with cross-parent anchoring (positioning-only) — would remove the most taint-heavy operation while preserving the visual integration.
- **Notes:** Not player-blocking but eroding trust (error spam during PvP). Do not start a fix until the investigation pinpoints the taint source — this is exactly the class of bug that gets "fixed" by a plausible change that doesn't actually address the root cause.

### HS-054 World-level continent summary should scope to current map view
- **Type:** Bug
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** Continent summary count and progress bar at world level only includes continents visible on the current map view. Azeroth shows only Azeroth continents, Draenor shows only Draenor zones, cosmic map shows all.
- **Session context:** Discovered during HS-023 Phase 1 verification. Pre-existing: `GetContinentVendorCounts()` counts every continent globally regardless of which world map is open. Summary line said "11 continents" on the Azeroth view when only 9 are Azeroth continents.
- **Notes:** Requires passing the current world-map parent mapID into the continent refresh path and filtering by ancestry.

### HS-056 Dalaran class hall icons — use real ClassHallFrames atlas
- **Type:** Bug / Polish
- **Priority:** Low
- **Status:** Backlog
- **Summary:** Dalaran Order Hall portal pins currently use placeholder icons. Replace with the real class hall icons from the `ClassHallFrames` atlas (viewable in-game via `/tav` under `ClassHallFrames`).

### Features

### HS-017 Currency requirements display
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** Per-item currency requirements visible in side panel and detailed tooltip view.
- **Session context:** None.
- **Notes:** Applies to both side panel and tooltip surfaces.

### HS-018 Source-aware map filtering
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** (1) Map-level filter dropdown controls which pins appear on the world map. (2) Badge counts respect active source filter instead of hardcoded "all". (3) Non-vendor sources get map presence (quest zones, achievement locations, profession trainers). (4) Zone summaries count items by source type.
- **Session context:** A source filter dropdown already exists in the side panel (MapSidePanel.lua lines 280-326) but only affects panel display. `panelSourceFilter` is ignored by `GetZoneVendorCounts`/`GetContinentVendorCounts` (hardcoded `"all"` in `BadgeCalculation.lua:314`). VendorFilter handles faction/verification visibility but has no source-type filtering.
- **Notes:** Significant feature — requires PLAN_TEMPLATE.md. Consolidated from HS-018 + HS-020.

### HS-019 Search: highlight/scroll to matched item in panel
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** Selecting a search result scrolls to and highlights the matched item in the expanded vendor grid.
- **Session context:** Currently dims non-matches; vendor rows only. Item-first rows use separate expansion via v2.0 vendor-as-peer Phase 8. No auto-scroll behavior exists.
- **Notes:** None.

### HS-021 Continent-level pin placement refinement
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** Continent-level pins placed at visually appropriate locations (melaspike666 feedback addressed).
- **Session context:** None.
- **Notes:** Community feedback item.

### HS-022 Option to fully hide completed vendors
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** Setting available to hide completed vendor pins entirely (default remains color change only).
- **Session context:** None.
- **Notes:** None.

### HS-024 Ambient Profession Awareness suite
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** (1) Profession window overlay annotates craftable housing decor recipes. (2) Tooltips show "Craftable: [Profession] ([Skill Tier])" for ProfessionSources items. (3) Catalog overlay shows profession badge for craftable items.
- **Session context:** ProfessionSources is a registered v2.0 provider. `GetAllSources()` and `GetSourceTypeIcon("profession")` handle it. Existing `CatalogOverlay.lua` can be extended. Current tooltip code in `Overlay/Tooltips.lua` may partially surface this — audit first. Needs reverse mapping from spellID/recipeID to identify recipe rows in profession frame. Design constraint: overlay only, no new windows.
- **Notes:** Depends on HS-014 (ProfessionSources skillTier backfill). Requires plan. Three sub-features can be phased.

### HS-025 House dashboard tooltip updates
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** House dashboard tooltips show prerequisite and DecorMapping data.
- **Session context:** None.
- **Notes:** None.

### HS-026 Housing API exploration
- **Type:** Investigation
- **Priority:** Low
- **Status:** Backlog
- **Acceptance criteria:** Each sub-item investigated and either promoted to a feature ticket or documented as not viable.
- **Sub-items:**
  - **Interaction type monitoring** (was HS-026): Detect housing UI context (cornerstone, bulletin board, pedestal) via `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` types 70-78. May enable context-sensitive features.
  - **Catalog category display** (was HS-027): Filter/category UI powered by `GetAllFilterTagGroups()` data (6 groups, 82 tags). See HOUSING_API_REFERENCE.md §Quick Taint Reference.
  - **SuperTrackingMapPinType.HousingPlot** (was HS-028): Determine if type 4 can integrate with navigate-to-vendor waypoint system. See HOUSING_API_REFERENCE.md §SuperTrackingMapPinType.
- **Notes:** All exploratory — may not result in features. Consolidated from HS-026 + HS-027 + HS-028.

### HS-029 Data pipeline report improvements
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** `vendor_mismatch_rescan.csv` report generated. `/hsdev` one-screen coverage report available. Confidence guidance documented in output.
- **Session context:** vendor_mismatch_rescan.csv: DB vs scan/API mismatch shortlist. /hsdev coverage report: targeted scan queue, no DB mutation.
- **Notes:** Three sub-items; can be done independently.

### HS-050 Add ownership data to discovery scanner + export pipeline
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** (1) CatalogDiscoveryScanner passes `tryGetOwnedInfo = true` and stores `firstAcquisitionBonus` per entry. (2) `exportsources` TSV includes `owned` column. (3) Python pipeline scripts parse the new column. (4) Validation reports can filter/flag by ownership status. (5) `/hsdev shoplist` removed as redundant.
- **Session context:** Discovered during HS-049 (shop source type) that the discover scanner passes `tryGetOwnedInfo = false`, missing ownership data. The shoplist command built for HS-049 proved ownership scanning works. Full pipeline update needed: CatalogDiscoveryScanner.lua → SavedVariables schema → DevCommands exportsources → Python scripts.
- **Notes:** Makes `/hsdev shoplist` obsolete. Ownership data enables collection-gap reports and shop item filtering in the Python pipeline instead of in-game.

### HS-030 Validation tool: EndeavorsData coverage
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** `/hsdev validate sources` checks EndeavorsData.Vendors, eliminating ~60 false positive NEW_VENDOR rows.
- **Session context:** Currently only checks VendorDatabase.
- **Notes:** None.

### HS-031 ExportImport.lua import side — parse decorID
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** Import parses new `decorID` field from I: lines (field 9, 0-indexed). Currently export-only.
- **Session context:** None.
- **Notes:** None.

### HS-032 Reduce /parse-export VERIFY noise
- **Type:** Feature
- **Priority:** Low
- **Status:** Backlog
- **Acceptance criteria:** Large real exports produce fewer false-positive VERIFY lines through improved vendor suppression and matching heuristics.
- **Session context:** Parser hardening is implemented; output remains intentionally conservative and report-only.
- **Notes:** None.

### HS-051 Wago analytics — meaningful switches and counters
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** (1) Replace always-true switches with behavior-differentiating ones. (2) Add counters that track real usage patterns. (3) Dashboard shows actionable development priority data.
- **Session context:** Current switches (WelcomeScreenSeen, MapPinsEnabled, MinimapPinsEnabled) are all 100% — no signal. Region/locale overview data is useful (EU+RU > Americas). Class distribution is not actionable for a housing addon.
- **Switches to add:** Panel mode (docked vs floating), source filter usage, custom pin color usage.
- **Counters to add:** Pin hover frequency, waypoints set, panel search usage, vendors scanned per session.
- **Notes:** Existing Wago integration is via WagoAnalytics module. Keep counters lightweight — no per-frame tracking. Session-level aggregates preferred.

### HS-040 Wago Analytics — vendor counters
- **Type:** Feature
- **Priority:** Low
- **Status:** Backlog
- **Acceptance criteria:** (1) `Counter("vendor:" .. npcID, 1)` fires on MERCHANT_SHOW — vendor visit frequency on Wago dashboard. (2) `Counter("vendor:{npcID}:{mapID}:{x}:{y}", 1)` fires on vendor visit — crowdsources coordinate verification via Wago.
- **Session context:** HA.Analytics already integrated (registered as `aNDMQ86o`). Current counters: VendorScans, Exports, WelcomeScreenClosed, WhatsNewClosed. 128-char name limit, 512 counter limit per addon, no item data. Both counters use the same MERCHANT_SHOW hook.
- **Notes:** Consolidated from HS-040 + HS-041.

### HS-044 Dynamic event pin positioning
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** (1) API identified for detecting active rotating-event zones (Dreamsurge, Abundance). (2) Celestine of the Harvest pin moves to active Dreamsurge zone. (3) Only the active Chel the Chip location shows a pin.
- **Session context:**
  - Celestine [210608]: DB has mapID 2025 (Dragon Isles) with placeholder coords. Scan captured at mapID 2024 (Azure Span). DB has 2 items but scan shows 1 (255673 only, not 257352).
  - Chel the Chip: 4 NPC IDs at 4 Abundance locations (241928, 248658, 257632, 257633). All show static pins currently.
  - `C_AreaPoiInfo.GetAreaPOIForMap()` already used in HomesteadWorldMapProvider for POI dodge — likely the same API detects active event zones.
- **Notes:** Same API pattern applies to both Dreamsurge and Abundance. Consolidated from HS-044 + HS-045.

### HS-053 Shift-expand vendor pin tooltips for per-item requirement detail
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** Holding Shift on a vendor map pin tooltip expands it to show per-item availability states and requirement details, similar to how item tooltips show detailed info on Shift.
- **Session context:** Identified during HS-023 Phase 1 verification. The purchasability summary (Collected/Purchasable/Locked + blocker groups) gives a good overview, but there is no way to drill into per-item requirement detail from a map pin hover. Design questions: what does the expanded view show (per-item states? full requirement lists?), tooltip size management.
- **Notes:** Depends on HS-023 Phase 1 being complete. Follow-up feature, not a Phase 1 blocker.

### HS-057 Update Wago.io landing page
- **Reclassified:** Originally logged as HS-051 (duplicate ID). Renumbered to HS-057 in STU-023.
- **Type:** Community
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** Wago.io addon page updated with compelling description, screenshots, and feature highlights to attract more downloads.
- **Notes:** Current page may be using default/minimal description. Review competitor addon pages for what works.

### Data

### HS-007 In-game vendor verification queue
- **Type:** Data
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** All queued vendors scanned and confirmed against live game. Item lists, costs, and scan metadata up to date.
- **Active — need in-game verification:**
  - Jolinth [253086]: 3 items (248656, 256168, 256169). 248111 removed as profession item (`45c6782`). Items 256168/256169 were not in export — need scan to confirm full list.
  - ~~Trader Caerel [85950]~~: costs added from export (Apexis Crystal + Garrison Resources, `df29cff`).
  - Lunar Festival [15864]: 13 items in EventSources but 0/13 in DecorMapping. Need to verify these are actually housing decor items before adding DecorMapping entries. Seasonal — Lunar Festival window only.
- **Low priority — garrison-gated legacy content:**
  - Moz'def [79812]: 2 items (245437, 245442), no costs. WoD Horde garrison, requires building-level configs to verify.
  - Vora Strongarm [87312]: 1 item (239162), no costs. WoD Horde garrison tavern, same building-level gating.
  - Noblegarden: 3 items clean in EventSources + DecorMapping. Multi-location vendor limitation is by design. Seasonal.
- **Resolved — removed from queue:**
  - ~~Dennia Silvertongue [256828]~~: scanConfirmed 2026-02-28, scanCoverage full. 22→9 triage completed by Midnight overhaul (`ab55127`). 264396 is a dead item ID. 263301 is an orphaned DecorMapping entry (no vendor source) — separate data hygiene issue.
  - ~~Ransa Greyfeather [106902]~~: 11→8 explained — 11 contaminated items from Torv Dubstomp removed (`45c6782`). Remaining 8 are consistent (all Tauren-themed, all have costs, all in DecorMapping).
- **Notes:** Consolidated from HS-007 + HS-009 + HS-010. Audit 2026-03-22 resolved 2 vendors, downgraded 3.

### HS-012 Source data gaps
- **Type:** Data
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** Remaining PARSED_ONLY items either added to static tables or documented as intentionally excluded.
- **Session context:** ~70 "Decor Treasure Hunt" quests (TWW weekly rotation, low priority), ~6 PvP "Battle" achievement items (247763-247770, not in AchievementSources but most are in VendorDatabase as PvP vendor items), ~24 "Prey:" achievement items (265681-265799, in PrerequisiteSources/DecorMapping but not AchievementSources), misc quest sources. ~~Draenor World Vendors: 4 items (244321, 244322, 245444, 245445)~~ — resolved, all in VendorDatabase. AchievementSources regenerated 2026-03-03 with 263 entries.
- **Added 2026-04-10:** 7 orphaned Harandar/Rutaani items removed from Naynar (263019 Haranir Pennant, 263039 Harandar Flowering Lamp, 263194 Harandar Glowvine Sconce, 263195 Harandar Glowvine Lamppost, 264267 Rutaani Birdfeeder, 264268 Rutaani Birdbath, 264269 Rutaani Bird Perch) — in DecorMapping but sourced nowhere. Likely sold by an unscanned vendor in Harandar zone. Wowhead has no source data.
- **Notes:** Counts reduced since Feb 18. Some categories are low priority (weekly rotation quests).

### HS-014 ProfessionSources skillTier backfill
- **Type:** Data
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** All 170 ProfessionSources entries have correct skillTier values.
- **Session context:** Three-step process: (1) Dev addon exports spellID→skillLineAbilityID, (2) Web API script saves full recipe_id→skill_tier lookup (~11k recipes), (3) merge script joins on skillLineAbilityID=recipe_id. See KNOWLEDGE.md 2026-03-06 entry.
- **Notes:** Required for Ambient Profession Awareness features (HS-024).

### HS-016 Pre-Midnight faction IDs in VendorDatabase
- **Type:** Data
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** Rep-gated vendors display faction requirement correctly in-game.
- **Session context:** Faction IDs: 2696 Amani Tribe, 2699 The Singularity, 2704 Hara'ti, 2710 Silvermoon Court.
- **Notes:** None.

### HS-039 Side panel data gaps
- **Type:** Data
- **Priority:** Low
- **Status:** Backlog
- **Acceptance criteria:** Second Chair Pawdo quest source identified and added. Gap in uncaptured requirements documented.
- **Session context:** Second Chair Pawdo [252312]: 2 items locked by quest but quest not in QuestSources. Some items may have requirements not captured by any automated source.
- **Notes:** None.

### HS-046 Audit `altCurrency` vendors for stale gold costs
- **Type:** Data
- **Priority:** Low
- **Status:** Backlog
- **Acceptance criteria:** All vendors with `altCurrency = "Gold"` verified — remove gold cost if scan confirms price=0.
- **Session context:** Scanner correctly captures both gold and currency costs. T'lama and Peroleth had stale `gold=100000` that was wrong — scan confirmed WR-only. Other `altCurrency` vendors may have the same stale data.
- **Notes:** Not a scanner bug. Finding promoted to known-patterns.md.

### Maintenance

### HS-036 VendorMapPins runtime lifecycle QA
- **Type:** Maintenance
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** Event registration, indoor ticker cancel/recreate behave correctly across all map/minimap pin toggle states.
- **Session context:** In-game QA item. Files: `UI/VendorMapPins.lua`.
- **Notes:** Requires in-game testing.

### HS-042 Slim Scanner — Prune and Export Refactor
- **Type:** Refactor
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** ScanPersistence prunes stale scanner data on
  init without affecting valid scan records; export output is unchanged;
  no regression to scanConfidence or decorCount fields; /hs validate
  returns same vendor count as baseline.
- **Session context:** Full 10-section plan exists at
  `Home_Dev/plans/active/slim-scanner-prune-export.md`. Worktree created
  2026-04-10 at `../Homestead-slim-scanner` on branch `refactor/slim-scanner`
  (not `feature/` per project convention for refactors). Implementation
  has not started — next action is Phase 1 (slim persistence in
  `Modules/ScanPersistence.lua`).
- **Validated 2026-04-03:** Plan fully validated against current codebase.
  All 4 phases confirmed sound. Section 7 open questions resolved:
  Q1 — keep `name` (runtime consumers confirmed). Q2 — prune before
  `VendorTracer:Initialize()` at core.lua line 125. Phase 2 simplified:
  dev addon already has ExportImport.lua + commands (commit `862bc17`),
  so Phase 2 reduces to deleting the public copy. Two additional runtime
  consumers found (core.lua, VendorFilter.lua) but both only access
  fields on the keep list — no code changes needed. `spellID` in
  SourceManager reads from ProfessionSources (static), not scanned items.
- **Notes:**
  - Plan is ready to implement — no open blockers.
  - Do not start implementation until a worktree is created per the
    refactor protocol.

### HS-060 Audit: Housing Catalog byItem API coverage + ownership-cascade parity
- **Type:** Maintenance (Audit)
- **Priority:** High (upgraded from Low after Argus Gate 1 review)
- **Status:** Backlog
- **GitHub:** [#32](https://github.com/Royaleint/Homestead/issues/32)
- **Scope (consolidated from HS-059 follow-ups FU-1, FU-2, and FU-3 per Argus Gate 1):**
  1. **API coverage audit.** Across all `DecorMapping` items, count where `GetCatalogEntryInfoByItem` returns nil/empty while `GetCatalogEntryInfoByRecordID` returns populated data. If prevalence is high, promote byRecordID to the primary probe in `CatalogScanner` and `IsOwnedFresh` rather than a fallback.
  2. **CatalogScanner parity.** Verify the scanner handles the byItem-nil case (the same 12.0.1 bug HS-059 hit). If the scanner has the same blind spot with no fallback, every downstream feature inherits wrong ownership data — players see "0 owned" on items they actually own. Highest-impact part of the audit.
  3. **Predicate breadth.** `ProbeByDecorID` and `IsOwnedFresh`'s Stage 4 use only `firstAcquisitionBonus == 0` as ownership signal. `CatalogScanner.IsOwned` accepts six signals. Decide whether to broaden the probe path to match the scanner — affects items where `numPlaced > 0` or `quantity > 0` but `firstAcquisitionBonus ~= 0`. Cosmetic-impact gap (tooltip vs catalog badge disagreement) but real if it surfaces.
  4. **Documentation output.** Once 1–3 are resolved, update `Home_Dev/reference/HOUSING_API_REFERENCE.md` and the `wow-api` MCP `ownership_patterns` entry with the 12.0.1 byItem-nil finding so future code doesn't reintroduce the bug.
- **Acceptance criteria:** Report of affected items (count + list); explicit decision on whether to flip byRecordID to primary; scanner audited and patched if affected; docs updated.
- **Discovered:** While fixing HS-059 we confirmed `GetCatalogEntryInfoByItem("item:244778", true)` returns nil on 12.0.1, while `GetCatalogEntryInfoByRecordID(1, 1482, true)` returns a full populated struct.
- **Session context:** None yet. Pick up after HS-059 ships and the `/hsdev hs059record` probe is removed.
- **Notes:** Likely produces both player-visible fixes (if scanner is broken) and internal hygiene (docs). HS-061 (migration write hardening) is a separate low-priority item, not folded here.

### HS-061 Route Migration 1→2 decorID write through `_save`
- **Type:** Maintenance (Hardening)
- **Priority:** Low
- **Status:** Backlog
- **Discovered:** Argus Gate 1 review of HS-059 (originally proposed as HS-059-FU-4).
- **Acceptance criteria:** In `Data/CatalogStore.lua`, the Migration 1→2 path that writes `record.decorID = data.recordID` directly is refactored to route through `_save` (or an equivalent helper that also updates the `itemIDToDecor` reverse index). Reverse-index invariant is enforced structurally, not by `Initialize` ordering.
- **Session context:** Currently safe by ordering — `BuildDecorIndex` runs after migrations in `Initialize`, so the rebuild captures the migration's writes. If a future code path runs `BuildDecorIndex` before migrations, the reverse index drifts silently.
- **Notes:** A trap, not a current bug. Zero player impact today. Fold into the next refactor that touches migrations or the catalog store.

### Stale

### HS-006 Apply pipeline data corrections
- **Type:** Data
- **Priority:** High
- **Status:** Stale — needs full pipeline rerun before resuming
- **Acceptance criteria:** All pipeline-flagged fixes applied. New items, mapID/coordinate corrections, DecorMapping entries, and source tables reflected correctly in-game.
- **Stale notice (2026-04-10):** Last pipeline run was 2026-03-23. All remaining items below are based on that run's output and may no longer be accurate. A fresh pipeline run with current Blizzard API data + in-game export is required before acting on any remaining corrections.
- **Completed (2026-03-23 and prior):**
  - Nael Silvertongue mapID fix, Ransa Greyfeather alias, full table regeneration
  - Chel the Chip aliases, Telemancer Astrandis item + DecorMapping, Voidlight Marl costs
- **Remaining (stale — revalidate after pipeline rerun):**
  - 11 Ransa Greyfeather items — parked pending NPC scan
  - Ripley Kiefer / Samantha Buckley mapID corrections — need scans
  - 4 missing zoneToContinent mappings — need scans
  - Aeeshna spawn pattern investigation
  - ProfessionSources 134 conflicts, 2 fixture failures
  - Irodalmin placeholder coords, Reddit-reported coordinate issues
- **Notes:** Pipeline results at `Home_Dev/scripts/exports/blizzard_latest/`. All session analysis files from March 2026 are stale — do not use without a fresh pipeline run.

### HS-015 Collect Hearthsteel itemIDs
- **Type:** Data
- **Priority:** Medium
- **Status:** Consolidated into HS-049
- **Notes:** Data collection scope absorbed by HS-049 (Shop source type). HS-049 covers collection + source type + tooltip integration.

## In Progress

### HS-038 FloorHints for same-mapID hubs
- **Type:** Feature
- **Priority:** Low
- **Status:** In Progress (worktree)
- **Acceptance criteria:** Vendors in same-mapID hubs (e.g. Dornogal) display on correct floor.
- **Session context:** Implemented on worktree branch `feature/dynamic-floor-detection` at `../Homestead-feature-dynamic-floors`. Two commits: dynamic floor detection API in MapPinProvider + consumer wiring. VerticalSiblings manual overrides + dynamic map group detection.
- **Notes:** Not merged to main. Needs in-game verification before merge.

### HS-058 Investigate 12.0.5 housing changes
- **Reclassified:** Originally logged as HS-052 (duplicate ID). Renumbered to HS-058 in STU-023.
- **Type:** Investigation
- **Priority:** High
- **Status:** In Progress
- **Acceptance criteria:** All 12.0.5 housing-related changes documented — new APIs, new items, vendor changes, UI changes. Impact on Homestead assessed with action items created for any required updates.
- **Session context:** PTR live since March 12, expected live April 21 2026. PTR Build 66741 is Release Candidate (2026-03-31).
- **Data implementation (2026-04-09):** All vendor data additions implemented on worktree branch `feature/12-0-5-vendors` (commit `8c14663`). 2 new vendors with `unreleased = true`, 3 existing vendors updated, 26 DecorMappings, 3 ShopSources. Plan at `Home_Dev/plans/active/12-0-5-vendor-additions.md`. Spec review + luacheck passed.
- **Blocked:** Housing Catalog disabled on PTR — CatalogOverlay compatibility (steps 1, 2, 3, 6, 7) cannot be tested until patch goes live.
- **Next action:** On patch day (April 21): remove `unreleased = true` from Rae'ana [255495] and Disguised Decor Duel Vendor [264056], merge branch to main, in-game scan all 5 vendors to backfill costs/coords/scanConfirmed, run pipeline regeneration.
- **Open:** Illusionary Coin currency ID, Rae'ana currency type, Decor Duel Vendor coords, Lush Garden Window itemID, Gamesmaster Fleurian data.
- **Initial research (2026-03-25):**
  - **Decor Duels** — new 5v5 prop hunt in Silvermoon. New vendor (Disguised Decor Duel Vendor), new currency (Illusionary Coin), Sin'dorei-themed decor rewards. Needs new vendor entry + currency support.
  - **317 new decor items datamined** — full pipeline run needed when live.
  - **Catalog UI restructuring** — dyed variants consolidated onto single cards, Shift+Click linking, new filters. **Highest risk: CatalogOverlay may break if card `.entryInfo` structure changed.**
  - **Endeavor tooltip changes** — now shows House XP + Community Coupons earned. Check tooltip hook conflict.
  - **Community Coupons cap** increased 500 → 2000.
  - **Artisanal House** — new house type.
  - **Voidlight Marl repricing** — already live via March 24 hotfix, broader than HS-006 corrections.
  - **New already-live decor sources:** Artistic Aid Endeavor (8 paintings), Cuddly Void Grrgle (Twitch drop Mar 26), London Treasure Hunt (3 items), Roofus Charity Pack.
- **PTR testing plan:**
  1. Run `/hsdev catalogspike` — verify `HousingDashboardFrame` exists and `.entryInfo` structure on dye-consolidated cards
  2. Run `/hstest api` — check for new/changed `C_HousingCatalog` functions
  3. Run `/hsdev discover start` — fresh recordID scan for item count delta
  4. Run `/hstest currency <illusionary_coin_id>` — probe new Decor Duels currency
  5. Visit Decor Duels vendor, run `/hsdev suggest` — generate DB entry
  6. Check `GetAllFilterTagGroups` for new filter structure
  7. Verify existing safe API calls still return same structure
- **Dev addon updates needed before PTR:**
  - `SourceValidator.lua` — update `DATA_REVIEWED_BUILD` and build number after review
  - `DevCommands.lua` — verify `MAX_DECOR_ID = 19500` still sufficient
  - Consider new catalogspike subcommand to inspect dye variant data on entry frames
  - Add Decor Duels test item to `ApiTest.lua TEST_ITEMS` after PTR scan
- **Notes:** Research at `BawrLabs/projects/` (no dedicated doc yet). Blizzard Watch, Wowhead, MMO-Champion, and official PTR notes all reviewed.

## Awaiting Gate 2

*(None.)*

## Awaiting Release

*(None.)*
