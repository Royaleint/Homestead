# Homestead — Completed Items

Completed work for the Homestead addon, in chronological order by
completion date. Active and queued work lives in `Home_Tracker.md`.

### HS-003 Build offline data validation pipeline
- **Type:** Feature
- **Priority:** High
- **Status:** Complete
- **Completed:** 2026-03-04 (pipeline built incrementally 2026-02-12 through 2026-03-04, GitHub #25 closed)
- **Summary:** 18 Python scripts in `Home_Dev/scripts/` plus in-game `/hs validate`. Full orchestrator (`run_pipeline.py`), Blizzard web API integration, source parity validation, vendor items diff, DecorMapping/PrerequisiteSources/SourceTables generation. All original acceptance criteria met. Exceeds original scope.

### HS-001 Tooltip cleanup pass (post-v2.0)
- **Type:** Bug
- **Priority:** High
- **Status:** Complete
- **Completed:** 2026-03-15 (Gate 2 passed)
- **Summary:** Tooltip audit identified 5 findings — all resolved. MapSidePanel isolated to dedicated tooltip frame (no more GameTooltip taint). VendorMapPins tooltip isolation preserved. Settings descriptions updated to match post-migration behavior. `showAllSources` description aligned with `GetBestAvailableSource` code path. Item-first search rows correctly detected as panel context via `isHomesteadPanelTooltip` flag.

### HS-002 Tooltip semantics fix (post-v2.0)
- **Type:** Bug
- **Priority:** High
- **Status:** Complete
- **Completed:** 2026-03-15 (commit `e02d2eb`)
- **Summary:** Fixed friendship rank evaluation using wrong API (`C_Reputation` reaction index instead of `C_GossipInfo` friendship rank name). Added renown pattern parsing, two-line tooltip format for rep/friendship/renown requirements, cross-path dedup, and removed AchievementSources/QuestSources from `GetRequirements()`. 4 files changed across `Data/SourceManager.lua`, `Overlay/Tooltips.lua`, `UI/Options.lua`, `.luacheckrc`.

### HS-004 Hunter badge only visible for hunters — root cause unknown
- **Type:** Bug
- **Priority:** High
- **Status:** Complete
- **Completed:** 2026-03-16 (resolved by HBD → native pin migration, GitHub #8 closed)
- **Summary:** Badge visibility across classes corrected by native pin system migration. Remaining: Highmountain zone map pin not showing — tracked as HS-047.

### HBD Migration - Plain-Frame Pin System
- **Type:** Refactor (critical fix)
- **Priority:** Critical
- **Status:** Complete
- **Completed:** 2026-03-20 (Gate 2 passed)
- **Summary:** Fully replaced HereBeDragons with native pin system. World map uses plain canvas-child frames via `MapPinProvider.PlaceNativePin`; minimap uses `HomesteadMinimapOverlay` with OnUpdate positioning. Eliminated 4 taint vectors (AddDataProvider, MapCanvasPinMixin, ExecuteOnAllPins, WorldMapFrame hooks). Added POI dodge, zoom-aware damping, HybridMinimap suppression. Post-merge cleanup extracted shared pool utilities into `FramePoolUtils.lua` and deferred VendorFilter upvalue resolution. Argus 5-lens review passed all lenses. Resolved #1 reported user issue (combat taint errors).

### HS-047 Vendor pin missing on Highmountain zone map
- **Type:** Bug
- **Priority:** Medium
- **Status:** Complete
- **Completed:** 2026-03-21
- **Summary:** Resolved by adding Hunter portal badge pin at Talua's location on Dalaran map (72.0, 40.3). Non-hunters couldn't project mapID 739 (Trueshot Lodge); now all classes see the portal badge on the Dalaran surface map. Vendor pin still shows on Trueshot Lodge map for hunters.

### HS-005 Order Hall portal pins — all classes
- **Type:** Feature
- **Priority:** High
- **Status:** Complete
- **Completed:** 2026-03-21
- **Summary:** Added class fields, portal badge pins, and PORTAL_CLASS_ATLAS entries for Warlock (Gigi Gigavoid), Rogue (Kelsey Steelspark), and Hunter (Outfitter Reynolds). Fixed portal pin scale compensation missing after HBD migration. Corrected Shaman portal coords. All 10 Order Hall classes now have portal pins on Dalaran maps.

### HS-033 12.0.1 API taint testing
- **Type:** Maintenance
- **Priority:** Medium
- **Status:** Complete
- **Completed:** 2026-03-22 (audit confirmed — neither `GetNumFloors` nor `BulkRefundDecors` are used anywhere in the codebase)
- **Summary:** Taint-risk APIs were never adopted or have been removed. No action needed.

### HS-034 Fix 5 Codex assumption risks
- **Type:** Maintenance
- **Priority:** Medium
- **Status:** Complete
- **Completed:** 2026-03-22 (audit confirmed all 5 risks have defensive guards)
- **Summary:** `C_DateInfo.GetCurrentCalendarTime` — nil guard in CalendarDetector. `GetMerchantItemCostInfo` — nil-safe with `or 0` in VendorScanner. `info.entrySubtype` — fallback chain in CatalogScanner (top-level → entryID.entrySubtype → pairs iteration). `info.isOwned` — used on internal CatalogStore records, not raw API structs. `entryInfo.entryID.itemID` — fallback chain in Tooltips (itemID → entryID.itemID → entryID).

### HS-035 SavedVariables year encoding bug
- **Type:** Bug
- **Priority:** Medium
- **Status:** Complete
- **Completed:** 2026-03-22
- **Summary:** Data bug, not code bug. 9 vendors in VendorDatabase had `scanConfirmed = "2025-02-25"` — impossible since the addon launched January 2026. Dates were derived from `lastScanned` timestamps during bulk `scanConfirmed` field addition (commit `835d6a8`, March 1 2026). Root cause: WoW beta server clock was off by exactly 365 days, producing epoch timestamps that decoded to 2025. Corrected all 9 entries to "2026-02-25". Code (`time()`) is correct — no risk of recurrence on live servers.

### HS-037 Update data-pipeline-rethink.md
- **Type:** Maintenance
- **Priority:** Low
- **Status:** Complete
- **Completed:** 2026-03-22 (audit confirmed — plan completed 2026-03-10, moved to `completed/`)
- **Summary:** All Path 1 phases (1-6) completed. Path 2 (Part B) explicitly documented as superseded by v2.0 vendor-as-peer migration. No further action needed.

### HS-043 Minimap pin range filtering
- **Type:** Feature
- **Priority:** Medium
- **Status:** Complete
- **Completed:** 2026-03-22 (resolved by HBD → native pin migration, GitHub #19 closed)
- **Summary:** Native minimap renderer (`HomesteadMinimapOverlay.lua`) hides pins outside the minimap radius instead of clamping to edge. The old HBD cross-zone clutter behavior is gone. No dedicated work needed.

### HS-048 Side panel overlaps map during combat
- **Type:** Polish
- **Priority:** Low
- **Status:** Complete
- **Completed:** 2026-03-22 (audit confirmed full combat deferral implemented)
- **Summary:** `ShowPanel()` and `HidePanel()` both check `InCombatLockdown()` and defer `ApplyDockedIntegration()` via `pendingDockedAction` until `PLAYER_REGEN_ENABLED`. Map close during combat also handled. All map mutations (SetPoint, SetParent, ClearAllPoints) gated behind combat checks. Accepted as designed — panel shows immediately but map nudge defers until combat ends.

### HS-049 Shop source type — Hearthsteel, promotions, Twitch drops
- **Type:** Feature
- **Priority:** High
- **Status:** Complete
- **Completed:** 2026-03-22 (Gate 2 passed)
- **Summary:** New `shop` source type registered as a standard SourceManager provider. ShopSources.lua with 17 items (Spring Blossom, Lush Garden, Starter Pack, Zillow promo). Tooltip shows "In-Game Shop" with Zone: N/A, Cost: with inline hearthsteel icon, Pack name. Catalog overlay badge uses hearthsteel atlas. CatalogOverlay fallback preserved for items not in static data. Hearthsteel confirmed as Battle.net virtual currency (code "XVV") via C_CatalogShop, not C_CurrencyInfo. Dev addon gained `/hsdev lookup` and `/hsdev shoptest` commands. Items not yet added: Roofus Charity Pack (no IDs), Cuddly Void Grrgle (not released until Mar 26), 3 Noblegarden eggs (already in EventSources).
- **Notes:** Plan at `Home_Dev/plans/active/shop-source-type.md`. Consolidates HS-015.

### HS-023 Purchasability Awareness — Phase 1
- **Type:** Feature
- **Priority:** High
- **Status:** Complete
- **Completed:** 2026-03-27 (Gate 2 passed)
- **Summary:** Tri-state item classification (collected/available/locked) across all UI surfaces. Traffic light progress bar (blue/gold/red), blocker summaries on vendor pin tooltips, inline count text with locked segment, per-item status colors in pin tooltips (green/white/red). Unified tooltip summary via `BadgeCalculation.AddSummaryLine()` — one formatter shared by 5 surfaces. Labels finalized: "Collected: X/Y | Locked: Z" (summary), "Status: Available" (per-item). 11 commits pushed to main (`f1c569b..de0fce3`). Worktree cleaned up.
- **Notes:** Driven by two CurseForge user requests. 183 items have static prerequisite data; mixed-coverage vendors show an `unverified` note.

### HS-008 Endeavor vendor cost gaps
- **Type:** Data
- **Priority:** Medium
- **Status:** Complete
- **Completed:** 2026-04-10
- **Summary:** All 4 endeavor vendors now have cost data in EndeavorsData.lua. Harlowe Marl [257897] (13 items), Brother Dovetail [249684] (15 items), Aeeshna [252605] (12 items) backfilled from Grummle rotation scan 2026-04-10 (`83a3008`). Hesta Forlath [256202] completed 2026-03-15.

### HS-055 v2.3 UI summary regressions — badge tooltips and progress text
- **Type:** Bug
- **Priority:** Medium
- **Status:** Complete
- **Completed:** 2026-04-11
- **Summary:** Badge tooltips restored — added collectedItems/totalItems/lockedItems/unverifiedItems to BuildBadgeData() and two inline continent badge constructions. Progress bar text fixed — reparented FontString from progressBarLockedFill to a dedicated overlay frame so text stays visible when locked == 0. Merge commit `3af697e`, worktree cleaned up.
- **Notes:** Gate 1 (Argus) passed all 5 lenses. Gate 2 passed all 6 test cases.

### HS-059 Owned housing items rendered as unowned on vendor tooltips
- **Type:** Maintenance (Bug)
- **Priority:** Medium
- **Status:** Complete (2026-04-12)
- **Completed:** Commit `d6e49da`, merge `1eaf32a` to Homestead main, pushed. GitHub #31 auto-closed. Argus Gate 1 PASS; Rawb Gate 2 PASS via `/hsdev hs059gate2` harness on his owned-item character (harness removed in Home_Dev `b3c0990`).
- **GitHub:** [#31](https://github.com/Royaleint/Homestead/issues/31)
- **Reported:** CurseForge comment, 2026-04-12. User saw Sethraliss Priest's Pillow flagged not-collected on "High Tides" Ren at Founder's Point despite owning it.
- **Acceptance criteria:** After `/reload` on a character that owns 244778, hovering Ren (255222 Founder's Point / 255325 Razorwind Shores) renders `Sethraliss Priest's Pillow` as owned. No regression on neighbouring items or map side-panel listings. Fresh-cache case (cleared SavedVars) also resolves owned within one tooltip render.
- **Root cause (confirmed via four diagnostic phases + prevalence sweep):** `C_HousingCatalog.GetCatalogEntryInfoByItem` fails for specific decor items due to **per-item catalog data integrity in Blizzard's backend**, not a systemic API breakage or a client-side timing/hydration issue. Phase 2b confirmed the failure is stable across 30s + catalog UI open. Phase 3 (Prodigy root-cause investigation) ruled out item-data hydration (`IsItemDataCachedByID=true`, `GetItemInfo` returns populated name, byItem still nil) and ruled out link format (MCP docs confirm number/string/link all equivalent). Phase 4 prevalence sweep across 10 items on Ren's 58-item list found **1 nil (244778) / 9 populated (~10% prevalence in sample)** — byItem fundamentally fails for a subset of decor items as a Blizzard data-side quirk. `CatalogStore:IsOwnedFresh` treated nil API response as "unowned" and returned false on the final fallthrough. On machines where the cache short-circuit had `isOwned=true` (Rawb, set by the bag-hit path during purchase), ownership rendered correctly. On fresh/cleared caches (the commenter), the cascade returned false for an actually-owned item. `GetCatalogEntryInfoByRecordID(1, decorID, true)` returns a full populated struct with `firstAcquisitionBonus=0` for the same item — this is the authoritative lookup and is the correct permanent fallback.
- **Fix plan (Shape A+B combined, single commit):** In `Data/CatalogStore.lua`, (1) add `itemIDToDecor` reverse index in `BuildDecorIndex` alongside existing `decorToItemID`; (2) add Stage 4 fallback in `IsOwnedFresh` — when byItem returns nil, reverse-lookup decorID via the new index and call `ProbeByDecorID(decorID)` (which uses the reliable byRecordID signature and writes through `SetOwned` on success). Plus bag-hit-path enrichment at `CatalogStore.lua:277` — write `decorID` into the record when the bag-hit path triggers, so the cache is never left incomplete.
- **Out-of-scope items (tracked separately):**
  - HS-060 / #32 — byItem API coverage audit across all DecorMapping items.
  - Ren/Gronthul data asymmetry at Razorwind Shores (Gronthul's 58-item list omits 244778) — possible Horde-mirror quirk. File separately if mirror parity is desired.
- **Spec:** `Homestead/Home_Dev/plans/active/HS-059-sethraliss-pillow-ownership.md`

### HS-061 Route Migration 1→2 decorID write through `_save`
- **Type:** Maintenance (Hardening)
- **Priority:** Low
- **Status:** Complete (2026-04-15)
- **Completed:** 2026-04-15 — Commit `fbba0bb`, merge `b610766` to Homestead main. Argus Gate 1 PASS on all five lenses. Rawb Gate 2 PASS (smoke test: `/reload` clean, ownership counts unchanged).
- **Discovered:** Argus Gate 1 review of HS-059 (originally proposed as HS-059-FU-4).
- **Acceptance criteria:** In `Data/CatalogStore.lua`, the Migration 1→2 path that writes `record.decorID = data.recordID` directly is refactored to route through `_save` (or an equivalent helper that also updates the `itemIDToDecor` reverse index). Reverse-index invariant is enforced structurally, not by `Initialize` ordering.
- **Session context:** Currently safe by ordering — `BuildDecorIndex` runs after migrations in `Initialize`, so the rebuild captures the migration's writes. If a future code path runs `BuildDecorIndex` before migrations, the reverse index drifts silently.
- **Notes:** A trap, not a current bug. Zero player impact today. Argus Gate 1 strengthened the rejection rationale for alt (b) — `self:Save` would fire `CATALOG_ITEM_UPDATED` mid-migration before subscribers expect a coherent store.

### HS-057 Update Wago.io landing page
- **Reclassified:** Originally logged as HS-051 (duplicate ID). Renumbered to HS-057 in STU-023.
- **Type:** Community
- **Priority:** Medium
- **Status:** Complete
- **Completed:** 2026-04-19
- **Acceptance criteria:** Wago.io addon page updated with compelling description, screenshots, and feature highlights to attract more downloads.
- **Notes:** Current page may be using default/minimal description. Review competitor addon pages for what works.

---
Pre-split history: Royaleint/BawrLabs@2951ea8:BACKLOG.md
Archaeology: `git log -S "<ITEM-ID>" -- BACKLOG.md` at commit 2951ea8^ (the commit before BACKLOG.md was deleted)
