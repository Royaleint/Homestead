# Homestead — Tracker

Active and queued work for the Homestead addon. Completed items live in
`Home_Completed.md`. Cross-project status rollup lives in
`BawrLabs/INDEX.md`.

## Open Decisions (2026-04-20 — from audit review)

Three structural decisions are pending before the next-sprint work kicks off.
Each affects ticket sequencing or scope. Resolve at the start of the next
session.

1. **Sprint restructure** — the original plumbing-PR (6 items bundled) no
   longer fits. With scope expansions, HS-022, HS-030, and HS-040 each
   need their own plan doc + worktree. Proposed revised order:
   **6** (done) → **4** (done) → **1a** HS-019 quick win →
   **3** HS-018 wire-up → **1b** HS-022 plan + build →
   **1c** HS-030 plan + build → **1d** HS-040 plan + build →
   **2** HS-060 plan + build. Alternative: power through as one mega-PR
   (not recommended — harder review, useless bisect, regression risk).
   *Decision owner:* Rawb.

2. **HS-051 consolidation timing** — HS-040's expanded scope fully absorbs
   HS-051. Close HS-051 as consolidated-into-HS-040 before HS-040 plan
   work begins, or retroactively after HS-040 ships. Same pattern as
   HS-015 → HS-049. *Decision owner:* Rawb.

3. **HS-022+3 dependency on HS-018** — the per-source-type hide scope
   (sub-item 3 in HS-022's expanded AC) requires the `sourceFilter`
   plumbing that HS-018 delivers. Options: (a) sequence HS-018 before
   HS-022 so the plumbing is ready, (b) ship HS-022 sub-items 1+2 as a
   standalone PR and layer 3 on after HS-018, (c) merge the two plans
   into one worktree. *Decision owner:* Rawb (shapes plan-doc boundaries).

Two tickets have pending state changes noted in their entries:

- **HS-026** — umbrella split into HS-063 (catalog tag filter), HS-064
  (HousingPlot supertrack probe), HS-065 (interaction context detection
  — likely skip). Queued as a separate `docs(tracker):` commit.
- **HS-031** — closure pending. Investigation confirmed interpretation
  (a): Python pipeline already parses decorID (`export_review.py:352`).
  Rawb to confirm intent, then move to `Home_Completed.md`.

## Backlog

### Next Release

*(None — populated by Rawb as scope decisions are made.)*

### Bugs

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

### HS-067 Remove dead GetPinColorPreviewHex helpers
- **Type:** Chore (cleanup)
- **Priority:** Low
- **Status:** Backlog — post-HS-066 follow-up
- **Acceptance criteria:** Delete `PinFrameFactory:GetPinColorPreviewHex` (`UI/PinFrameFactory.lua:76-85`) and `VendorMapPins:GetPinColorPreviewHex` (`UI/VendorMapPins.lua:429-430`). Grep-verify no other callers before deletion. Luacheck clean.
- **Session context:** Both helpers became dead after HS-066 landed — the only caller was the pre-refactor `pinColorPreview.name` closure at `UI/Options.lua:166-180`, which no longer exists. Removal was deliberately deferred per Rawb's Gate-2-first rule and kept out of HS-066 scope to keep that commit focused.
- **Notes:** Single small commit, worktree optional (micro-chore). Argus Gate 1 trivial — verify no callers before delete.

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
- **Status:** Backlog — **spec approved 2026-04-20, queued for implementation**
- **Acceptance criteria (expanded 2026-04-20):**
  1. Selecting a search result scrolls the matched item into view in the expanded vendor grid.
  2. **Persistent highlight** — matched item stays visually distinct until search is cleared (no 3-pulse flash). Highlight style TBD during plan (border color shift or subtle glow).
  3. **Match cycling** — clicking the same search result repeatedly cycles through multiple matches for that item (different vendors, item-first rows). Wraps at end.
- **Session context (2026-04-20):** Verified during audit that row click-to-expand logic is at `UI/MapSidePanel.lua:930–1007`. `ScrollFrame` is the anchor point for scroll calls. No auto-scroll behavior exists today; currently dims non-matches. Item-first rows have separate expansion via v2.0 vendor-as-peer Phase 8 — cycling must handle both vendor-row and item-first-row cases. Still quick-win scope after expansion.
- **Notes:** Single worktree with HS-018 plumbing or standalone — decide at plan time. Argus Gate 1 before merge.

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
- **Status:** Backlog — **spec approved 2026-04-20, plan doc required (promoted from quick win)**
- **Acceptance criteria (expanded 2026-04-20):**
  1. **Three-state setting** replacing the current binary: "Always show" / "Color change only" (current default) / "Hide completely" (new).
  2. **Badge hiding** — when "Hide completely" is selected, fully-collected continent and zone summary badges are also suppressed on the world map, not just per-vendor pins.
  3. **Per-source-type scope** — allow hiding completed **vendor** pins while leaving completed **quest-source** / **achievement-source** / **profession-source** / etc. pins visible. Scope selector is checkbox list, not radio.
- **Session context (2026-04-20):** Original quick-win framing was binary on/off; Rawb expanded scope during audit review. Per-source-type hide requires the `sourceFilter` plumbing that HS-018 wire-up delivers — this ticket is now **dependent on HS-018** landing first. Badge-hide logic needs `UI/BadgeCalculation.lua` extension so `GetZoneVendorCounts` / `GetContinentVendorCounts` can exclude fully-collected vendors from counts.
- **Open question (2026-04-20):** Does "Color change only" mode for the mid-state preserve today's exact behaviour, or is this the chance to revisit what "completed" color means (fully dim vs current pastel)? Leaving for plan doc.
- **Notes:** Needs PLAN_TEMPLATE.md. **Blocked on HS-018 wire-up** for sub-item 3. Could ship sub-items 1+2 first as a standalone PR and add 3 after HS-018 — decision at plan time.

### HS-024 Ambient Profession Awareness suite
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** (1) Profession window overlay annotates craftable housing decor recipes. (2) Tooltips show "Craftable: [Profession] ([Skill Tier])" for ProfessionSources items. (3) Catalog overlay shows profession badge for craftable items.
- **Session context:** ProfessionSources is a registered v2.0 provider. `GetAllSources()` and `GetSourceTypeIcon("profession")` handle it. Existing `CatalogOverlay.lua` can be extended. Current tooltip code in `Overlay/Tooltips.lua` may partially surface this — audit first. Needs reverse mapping from spellID/recipeID to identify recipe rows in profession frame. Design constraint: overlay only, no new windows.
- **Research context (2026-05-05):** `Home_Dev/reference/FINDINGS-decor-crafting.md` was updated with wow-api MCP follow-up notes. Current MCP confirms `C_TradeSkillUI.GetRecipeOutputItemData(...) -> CraftingRecipeOutputInfo` and `C_TradeSkillUI.GetRecipeSchematic(...) -> CraftingRecipeSchematic`, plus the `ProfessionsRecipeListMixin.Event.OnRecipeSelected` trigger in `ProfessionsUtil.lua:91`. Caveat: the local registered Retail Blizzard UI source tree lacks the `Blizzard_Professions*` directories, so recipe row mixin/template names remain unverified through wow-api. Dye research also confirms 8 current `C_DyeColor` functions, but `GetAllDyeColors` / `IsDyeColorOwned` still need empirical addon-context testing for taint and ownership scope.
- **Potential expansion candidates (2026-05-05 market-gap pass):**
  1. **Material intent tooltips** - annotate reagents, recipes, and crafted decor with housing relevance so players can see whether an item contributes to known or missing decor outcomes before vendoring, banking, mailing, or crafting.
  2. **Crafting opportunity prompts** - surface currently actionable decor crafts only at natural decision points such as profession windows, vendors, auction workflows, bank, or warband bank, based on known recipes and visible materials.
  3. **Account recipe gap map** - show which character or profession can craft each decor item, which recipes are still missing, and where an account has coverage gaps across alts.
- **Scope note:** These are candidate Homestead inclusions, not approved HS-024 scope. Account Recipe Gap Map is the strongest candidate from the market-gap pass, but all three depend on mature profession-source data, recipe-to-decor/reagent mapping, and validated account-wide visibility.
- **Notes:** Depends on HS-014 (ProfessionSources skillTier backfill). Requires plan. Three sub-features can be phased.

### HS-025 House dashboard tooltip updates
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Acceptance criteria:** House dashboard tooltips show prerequisite and DecorMapping data.
- **Session context:** None.
- **Notes:** None.

### HS-026 Housing API exploration
- **Type:** Investigation (umbrella)
- **Priority:** Low
- **Status:** Backlog — **split pending (2026-04-20)**
- **Investigation summary (2026-04-20):** All three sub-items investigated via wow-api MCP + code grep. None clears the bar for a quick-win commit. Recommend splitting the umbrella into three independent items:
  - **HS-063 (new) — Catalog tag-based filtering.** `GetAllFilterTagGroups()` works, returns 6 groups / 82 tags. Real user value (filter by theme/culture/style/expansion). **Not a quick win** — needs pipeline work to export `dataTagsByID` per item, VendorDatabase schema addition, panel UI for multi-facet filtering. Must sequence after HS-018 (source-aware filtering) to avoid shipping two incomplete filter systems.
  - **HS-064 (new) — SuperTrackingMapPinType.HousingPlot probe.** `Enum.SuperTrackingMapPinType.HousingPlot = 4` confirmed. Value unknown without in-game testing — needs `/hsdev` probe to determine what this supertracks and whether it's useful for vendor navigation. Research, not implementation.
  - **HS-065 (new or skip) — PLAYER_INTERACTION_MANAGER_FRAME_SHOW context detection.** Types 70–79 in `Enum.PlayerInteractionType` are housing-related (Cornerstone, BulletinBoard, Pedestal, etc.). Pure infrastructure — no standalone value, no consumer. Recommend skip until a feature actually needs it.
- **Acceptance criteria (updated 2026-04-20):** HS-026 umbrella closed. HS-063 and HS-064 created as separate tickets. HS-065 skipped unless a feature consumer emerges.
- **Notes:** Tracker split queued as a separate `docs(tracker):` commit so it doesn't tangle with active plumbing-PR work. Consolidated from HS-026 + HS-027 + HS-028 originally.

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
- **Status:** Backlog — **spec approved 2026-04-20, plan doc required (promoted from quick win)**
- **Acceptance criteria (expanded 2026-04-20):**
  1. Validator loop extended from VendorDatabase-only to cover **all 7 source tables**: VendorDatabase, EndeavorsData.Vendors, QuestSources, AchievementSources, ProfessionSources, EventSources, DropSources, ShopSources.
  2. Eliminates ~60 false-positive NEW_VENDOR rows for endeavor vendors (original HS-030 scope) plus similar false positives from the other source tables.
  3. **Summary line** added to the report: "Validated N vendors across M source tables, K false-positive NEW_VENDOR rows suppressed."
  4. **Cross-source consistency check** — new error class that flags items appearing in multiple source tables with inconsistent metadata (e.g. same itemID with different `decorID`, different `skillTier`, conflicting rewards).
- **Session context (2026-04-20):** Original scope was EndeavorsData only; Rawb expanded to full source-table coverage + cross-source consistency during audit review. Cross-source check is a meaningfully new feature, not a loop extension — warrants plan doc. Original validator loop at `Modules/Validation.lua:132` (`ValidateVendorDatabase` at line 144).
- **Notes:** Needs PLAN_TEMPLATE.md. Plan should define the conflict taxonomy (what counts as "inconsistent metadata") before implementation.

### HS-031 ExportImport.lua import side — parse decorID
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog — **closure pending (2026-04-20)**
- **Acceptance criteria:** Import parses new `decorID` field from I: lines (field 9, 0-indexed). Currently export-only.
- **Session context (2026-04-20):** Investigated during audit review. The "import" referenced here is the **Python pipeline's** ingestion of scanner exports, not an in-game import feature (no in-game import exists). Original scope already complete:
  - Commit `fb230a0` (2026-03-01) added `decorID` to scanner I: lines with explicit note "Future-facing: the Python pipeline currently ingests only the TSV export, not the scanner export. **This prepares for scanner ingestion.**"
  - `Home_Dev/scripts/export_review.py:352` parses `parts[9]` as decorID from I: lines.
  - `Home_Dev/scripts/tests/test_export_review.py:30` asserts `item["decorID"] == 12345` — test coverage exists.
  - Landed via session 25-28 commit `a44948f` ("parse-export hardening").
- **Open question (2026-04-20):** Rawb to confirm intent was Python-pipeline parsing (interpretation (a), already done) vs in-game import feature (interpretation (b), would be a medium feature). Leaning (a) based on code + commit history. If (a), move to `Home_Completed.md` referencing `fb230a0` + `a44948f` + `export_review.py:352`. If (b), needs PLAN_TEMPLATE.md.
- **Notes:** No code work required if interpretation (a). Audit review traced both interpretations; commit history supports (a).

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
- **Status:** Backlog — **consolidation into HS-040 pending (2026-04-20)**
- **Acceptance criteria:** (1) Replace always-true switches with behavior-differentiating ones. (2) Add counters that track real usage patterns. (3) Dashboard shows actionable development priority data.
- **Session context (2026-04-20):** Rawb expanded HS-040 scope to fold in all of HS-051's switches and counters. Pending decision: close HS-051 as consolidated-into-HS-040 before HS-040 plan work begins, or wait until HS-040 ships and close retroactively. Same pattern as HS-015 → HS-049.
- **Original context:** Current switches (WelcomeScreenSeen, MapPinsEnabled, MinimapPinsEnabled) are all 100% — no signal. Region/locale overview data is useful (EU+RU > Americas). Class distribution is not actionable for a housing addon.
- **Switches to add:** Panel mode (docked vs floating), source filter usage, custom pin color usage.
- **Counters to add:** Pin hover frequency, waypoints set, panel search usage, vendors scanned per session.
- **Notes:** Existing Wago integration is via WagoAnalytics module. Keep counters lightweight — no per-frame tracking. Session-level aggregates preferred.

### HS-040 Wago Analytics — comprehensive instrumentation
- **Type:** Feature
- **Priority:** Medium (upgraded from Low 2026-04-20 after scope expansion)
- **Status:** Backlog — **spec approved 2026-04-20, plan doc required (promoted from quick win)**
- **Philosophy (2026-04-20):** Rawb's direction — "use Wago analytics to the fullest possible ability to enhance and validate our database where possible." This ticket is the omnibus Wago instrumentation pass.
- **Acceptance criteria (expanded 2026-04-20):**
  1. **Vendor visit counters** (original HS-040 scope):
     - `Counter("vendor:" .. npcID, 1)` on MERCHANT_SHOW — vendor visit frequency.
     - `Counter("vendor:{npcID}:{mapID}:{x}:{y}", 1)` on vendor visit — crowdsourced coordinate verification.
  2. **HS-051 scope folded in** (switches):
     - Panel mode (docked vs floating) — Switch
     - Source filter usage — Switch
     - Custom pin color usage — Switch
  3. **HS-051 scope folded in** (counters):
     - Pin hover frequency — Counter
     - Waypoints set — Counter
     - Panel search usage — Counter
     - Vendors scanned per session — Counter
  4. **Session deduplication** — fire the vendor-visit counter once per session per vendor (not per MERCHANT_SHOW). Prevents a player repeatedly opening the same vendor from skewing the dashboard.
  5. **NPC discovery analytics** — emit a counter for newly-discovered NPC IDs (`Counter("newnpc:{npcID}", 1)`) the first time a player scans a vendor we don't have in VendorDatabase. Crowdsources unknown vendors.
- **Session context (2026-04-20):** `HA.Analytics` already integrated (registered as `aNDMQ86o`). Current counters: VendorScans, Exports, WelcomeScreenClosed, WhatsNewClosed. Wago constraints: 128-char name limit, 512 counter limit per addon, no item data allowed. Key infrastructure: `Core/core.lua:758` (OnMerchantShow hook), `HA.Analytics:IncrementCounter(...)` / `HA.Analytics:Switch(...)` API. Session-aware dedup needs a `seenVendorsThisSession` table cleared on PLAYER_LOGIN / PLAYER_ENTERING_WORLD.
- **Open questions (2026-04-20):**
  1. Counter budget — 7 new counters + per-vendor counters (one per unique NPC) + per-coord counters (one per unique scan location) + newnpc counters. Need to estimate worst case against the 512-counter ceiling and decide if coord counters should be coarser (2 decimal → 1 decimal) or sampled.
  2. Timing for HS-051 closure as consolidated-into-HS-040: before plan work starts, or retroactively after ship.
- **Notes:** Needs PLAN_TEMPLATE.md. Consolidated from HS-040 + HS-041. HS-051 absorption pending — decide closure timing during plan. Original ticket was a quick-win two-counter addition; expansion promoted it to a medium omnibus instrumentation feature.

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

### HS-069 Housing social / neighborhood operations research
- **Type:** Investigation / Feature
- **Priority:** Low
- **Status:** Backlog
- **Acceptance criteria:**
  1. Validate whether Midnight exposes enough addon-safe API state for neighborhood tasks, Endeavor contribution progress, pinned houses, recent visits, or house ownership/social metadata.
  2. Validate player demand from current housing communities rather than assuming Discord coordination should move into the addon.
  3. Compare overlap with HomeDecor's Endeavor dashboard, roleplay/social addons, and out-of-game community tooling before proposing any Homestead scope.
  4. Decide whether the ideas should split into concrete Homestead tickets or be closed as outside the product philosophy.
- **Session context (2026-05-05 market-gap pass):**
  - **Endeavor Contribution Planner** - help players understand which furniture or resources can satisfy active neighborhood goals and what they already own or can craft.
  - **Neighborhood Activity Awareness** - surface lightweight awareness around active neighborhood activity, public house updates, and group-relevant housing state if the API exposes reliable signals.
  - **House Visit / Social Trail** - preserve useful context around visited or pinned homes, such as creator, style, notes, and why the player saved the house.
- **Notes:** Research only. Do not implement until API feasibility and organic demand are validated.

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
- **Added 2026-04-22 (v2.3.2 prep):** 12 additional orphaned items in DecorMapping with no current vendor source. Mappings retained — `decorID ↔ itemID` is factual independent of vendor source.
  - **8 Paw Pal items** (259044 Water Dish, 259045 Bed and Blanket, 259046 Bed, 259093 Dog House Frame, 259094 Elwynn Roof, 264275 Durotar Roof, 264276 Eversong Roof, 264277 Shadowglen Roof). Speculatively staged onto Dennia Silvertongue, Tuuran, and Gabbi in the v2.3.2 prep commit; stripped after a 2026-04-22 live scan of Dennia confirmed they are not on her vendor list. Tuuran and Gabbi unscanned but stripped on the same precaution.
  - **4 Decor Duel guesses** (272443 Suramar Arcfruit Bowl, 272444 Small Decorative Dornogal Opal, 272445 Decorative Dornogal Opal, 272446 Large Decorative Dornogal Opal). Speculatively added with Disguised Decor Duel Vendor; live scan confirmed only 8 of the originally-listed 12 items.
- **Added 2026-05-05:** Mothkeeper Wew'tam (251259, Harandar) — 3 decor items (265943 Firm Haranir Pillow, 265945 Warm Haranir Blanket, 265946 Haranir Reclined Bed) absent from `C_HousingCatalog`; live `C_HousingCatalog.GetCatalogEntryInfoByItem` returns nil, scanner classifies them as non-decor. Manually entered into VendorDatabase with merchant-slot-confirmed IDs (`/run for i=1,GetMerchantNumItems()...`) and Wowhead costs (10 Luminous Dust each, currency 3385). Re-probe after each patch — backfill should restore catalog visibility and unblock ownership/badge UX.
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

  2026-04-19 — Flagged by Rawb as growing stale. Decision needed: complete the in-progress work on `feature/dynamic-floor-detection` worktree or close the item.
- **Notes:** Not merged to main. Needs in-game verification before merge.

## Awaiting Gate 2

### HS-072 Vendor coord debug log fires for matching coords (precision bug)
- **Type:** Bug
- **Priority:** Low
- **Status:** Awaiting Gate 2 (worktree `fix/hs-072-debug-coord-precision`, Tier 0 — Argus skipped per CLAUDE.md)
- **Summary:** `VendorFilter.GetBestVendorCoordinates` (`UI/VendorFilter.lua:84-94`) compared static and scanned coords with exact float `~=` while the debug message formatted both with `%.2f`. Scanned coords come from `C_Map.GetPlayerMapPosition()` at full precision (e.g. `0.32478…`) and static DB entries are hand-entered 2-decimal literals (`0.32`), so the comparison was true but the rendered strings were identical. Result: any minimap pin refresh logged "using SCANNED coords (X, Y) instead of static (X, Y)" for every persisted scan record in pin range, even when nothing differed at display resolution. Fix gates the log on `math.abs(sx - scannedX) > 0.005` (half of one `%.2f` unit) and preserves the missing-static path with an explicit `not sx or not sy` clause.
- **Acceptance criteria:** With debug mode on, opening a merchant or triggering a minimap refresh prints "using SCANNED coords" only for vendors whose stored static coords differ from the scanned coords at 2-decimal precision (or whose static coords are missing). Maku's `0.62/0.35` vs `0.63/0.34` case still logs; the other ~23 false positives in the original report do not.
- **Surfaces affected:** Dev-only debug output. No player-visible impact, no DB writes, no scan-vs-static decision change (`return {x = scannedX, y = scannedY}, …` at line 95 is outside the modified block).
- **Notes:** Dev-only debug-log path; no luacheck warnings introduced.

## Awaiting Release

### HS-071 Homestone overlay icon — poke outside the corner
- **Type:** Feature (UI polish)
- **Priority:** Low
- **Status:** Awaiting Release (Gate 2 passed 2026-05-09, on main)
- **Commit:** `bad1b93`
- **Summary:** Moved the homestone overlay icon from inset (2, -2) to outset (-2, 2) in `Constants.Overlay` so it reads as a corner badge instead of a glyph pasted inside the icon, matching Blizzard's crafting quality gem placement. Baganator's `RegisterCornerWidget` API applies its own (2, -2) inset that cancelled the outset, so `Overlay/Baganator.lua` now sets `frame.padding = 0` on the corner widget to opt out of that inset and drops the `CENTER, 0, 0` override so it follows the same offset path as Containers, Merchant, and BetterBags.
- **Surfaces verified:** Baganator confirmed in-game by Rawb. Default Blizzard containers, BetterBags, and merchant frame inherit the change via the shared `OFFSET_X/Y` constants.
