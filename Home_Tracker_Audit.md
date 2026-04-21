# Homestead — Tracker Audit (2026-04-20)

Code-vs-tracker audit of open tickets in `Home_Tracker.md`. Each section
classifies items by implementation status and effort, with file:line
evidence from the current `main` and recommendations on how to approach
each.

**Verification pass (2026-04-20):** All file:line citations re-checked
against the current `main`. File-path prefixes normalized to their actual
locations (`Modules/`, `Overlay/`, `UI/`, `Data/`). Corrections and new
findings inline below, flagged with **[Verified]**, **[Corrected]**, or
**[New finding]**.

---

## Features Audit

### Quick Wins (<1 day) — Knock these out first

| Ticket | Status | Notes |
|---|---|---|
| **HS-019** Search scroll/highlight | Partial | Row click-to-expand logic in `UI/MapSidePanel.lua:930–1007`; just add a `ScrollFrame` anchor call on match. **[Verified]** |
| **HS-022** Hide completed vendors | Not Started | Add a setting + visibility filter in pin rendering. |
| **HS-026** Housing API exploration | Partial | `C_AreaPoiInfo` probes already exist in `UI/HomesteadWorldMapProvider.lua:277–299` (POI + events loops); just extend. **[Corrected]** (was 274–293) |
| **HS-030** EndeavorsData validation | Not Started | Add an EndeavorsData loop to `Modules/Validation.lua:ValidateVendorDatabase` (existing VendorDatabase loop at line 144). **[Corrected]** (prior `Validation.lua:391` was inside `ShowDetails`, not the validator loop) |
| **HS-031** Import decorID | Partial | Export already writes field 9 (`Modules/ExportImport.lua:282, 396`); just wire the import parser. **[Verified]** |
| **HS-040** Wago vendor counters | Partial | Analytics registered, `OnMerchantShow` hook exists (`Core/core.lua:758`); add `Counter("vendor:"..npcID, 1)`. **[Verified]** |

### Medium (1–3 days)

| Ticket | Status | Notes |
|---|---|---|
| **HS-017** Currency requirements display | Not Started | Per-item cost already modeled (`Data/VendorData.lua:116` returns `item.cost`); needs per-item surface in panel rows + tooltip. Current tooltip currency line is source-level only (`Overlay/Tooltips.lua:584`, inside `RenderEventSourceLines`). **[Corrected]** |
| **HS-021** Continent pin placement | Not Started | Data-driven coordinate tweaks. |
| **HS-025** House dashboard tooltips | Not Started | Tooltip hook + DecorMapping surfacing. |
| **HS-044** Dynamic event pin positioning | Not Started | `GetEventsForMap` already called in `UI/HomesteadWorldMapProvider.lua:290`; needs Dreamsurge/Abundance/Chel dispatch (no existing handlers found in code). **[Verified]** |
| **HS-051** Wago meaningful switches/counters | Not Started | 5+ new instrumentation points. |
| **HS-053** Shift-expand pin tooltips | Not Started | Blocked on HS-023 Phase 1. |
| **HS-038** FloorHints *(in progress)* | Worktree stale | Completion + in-game verify. |

### Longer Investments (>3 days, plan doc needed)

| Ticket | Status | Notes |
|---|---|---|
| **HS-018** Source-aware map filtering | Partial | Panel filter works (`MapSidePanel.lua:1515, 2632` pass `panelSourceFilter`). **[New finding]** `BadgeCalculation:GetZoneVendorCounts` and `:GetContinentVendorCounts` both **accept** a `sourceFilter` arg (lines 363, 450), but these callers ignore it: `MapSidePanel.lua:2511` (zone view), and all `UI/VendorMapPins.lua` calls (517, 518, 521, 522, 1380, 1403, 1430, 1453, 1479, 1508). Tracker's `BadgeCalculation.lua:314` line-ref is stale. Map-level dropdown + non-vendor pins still required. |
| **HS-024** Ambient Profession Awareness | Partial | `ProfessionSources` + tooltip line already exist (`Overlay/Tooltips.lua:537–552` `RenderProfessionSourceLines`); profession window overlay + catalog badge remain; depends HS-014. **[Verified]** |
| **HS-029** Data pipeline reports | Not Started | Dev-addon work. |
| **HS-050** Ownership in discovery scanner | Not Started | Cross-cuts scanner, schema, dev commands, Python pipeline. |
| **HS-058** 12.0.5 housing *(in progress)* | Blocked | Awaiting April 21 PTR live; Rae'ana `[255495]` worktree-only, Disguised Decor Duel Vendor `[264056]` absent from main. |

### Already Partially Done (cheap to finish)

Six features have scaffolding already in place (HS-018, HS-019, HS-024,
HS-026, HS-031, HS-040). Of those, **HS-019, HS-026, HS-031, HS-040**
are quick wins — recommend batching them as a single "plumbing" PR
before tackling anything medium-sized.

### Recommended next sprint

1. Ship the 6 quick wins as one or two PRs.
2. Unstick **HS-038** (already on worktree, just needs verification) or
   close it.
3. Start a plan doc for **HS-018** or **HS-024** — both have the most
   user-visible payoff among the longer items.

Note: HS-032 and parts of HS-029/HS-050 touch a separate dev addon that
isn't in this repo, so the audit couldn't verify those directly.

---

## Maintenance Items Audit

### Quick Wins (<1 day)

| Ticket | Status | Notes |
|---|---|---|
| **HS-036** VendorMapPins runtime QA | Code robust — needs in-game testing | Event registration + ticker lifecycle already defensive (`UI/VendorMapPins.lua:327–407`, indoor check at line 235). Not code work — just a QA session across toggle/zone-transition states. **[Verified]** |
| ~~**HS-061** Migration 1→2 decorID via `_save`~~ | **Already complete (2026-04-15, commit `fbba0bb`)** | **[Corrected]** Not an audit finding. HS-061 was completed by commit `fbba0bb` on 2026-04-15 (Argus Gate 1 + Rawb Gate 2 both passed) and moved to `Home_Completed.md` via reconciliation commit `123fae8` on 2026-04-19. The current code at `Data/CatalogStore.lua:494–496` reflects that fix. Row left in place for traceability; no further action. |

### Medium (1–3 days)

| Ticket | Status | Notes |
|---|---|---|
| **HS-042** Slim Scanner refactor | Not Started | No prune logic in `Modules/ScanPersistence.lua`; no `ScanPersistence:Initialize()` call in `Core/core.lua:125`. Plan validated but implementation untouched — needs the worktree protocol. |
| **HS-060** Catalog byItem / ownership parity audit | Partial | byRecordID fallback added to `IsOwnedFresh` (`Data/CatalogStore.lua:305–316`) and `ProbeByDecorID` (450–469). **[Verified]** `CatalogScanner.ScanItem` (`Modules/CatalogScanner.lua:139–174`) calls only `GetCatalogEntryInfoByItem` at line 147; on nil it returns nil at line 151 — no byRecordID fallback. Ownership predicates diverge: probe path uses 1 signal (`firstAcquisitionBonus == 0`), scanner `IsOwned` uses 6 (`Modules/CatalogScanner.lua:38–77`: quantity, numPlaced, remainingRedeemable, firstAcquisitionBonus, entrySubtype, isOwned). Needs prevalence count + scanner patch + docs. **Still the highest-impact gap.** |

### Recommended order

1. **HS-060 first** — CatalogScanner missing the byItem-nil fallback
   could mean players see "0 owned" on items they own. That's the kind
   of bug HS-059 just fixed in one path but left in others. Highest
   user-visible risk.
2. **HS-036** — cheap QA session, catches regressions before they reach
   users.
3. ~~**HS-061**~~ — **Already complete** (2026-04-15, commit `fbba0bb`).
   Not an open item; listed above for traceability only.
4. **HS-042** — only after creating the worktree per refactor protocol.

---

## Bugs Audit

### Quick Wins (<1 day)

| Ticket | Code state | Notes |
|---|---|---|
| **HS-054** Continent summary scope | **Likely already fixed** | `UI/BadgeCalculation.lua:450` iterates globally, but `UI/MapSidePanel.lua:2637–2645` filters by `contInfo.parentMapID == mapID` (explicit `mapID == 946` cosmic-map bypass). Azeroth/Draenor views scope correctly; only true cosmic view (946) shows all. Verify with reporter before closing. **[Verified]** |
| **HS-056** Dalaran class hall icons | Suspect code present | `UI/PinFrameFactory.lua:344–355` uses Legion `legionmission-landingbutton-<class>-up` atlases with a housing fallback. Swap to real ClassHallFrames atlas. Pure polish. **[Verified]** |
| **HS-052** World map taint | Suspect code present, **partially mitigated** | `ShiftMapRight` at `UI/MapSidePanel.lua:3120`, SetParent calls at 3217/3240/3278, still mutate protected frames; now gated by `InCombatLockdown()` + `PLAYER_REGEN_ENABLED` (combat frame at 3581–3601; ShowPanel/HidePanel defer via `pendingDockedAction` at 3618, 3645). 0.1s ticker (`UI/HomesteadWorldMapProvider.lua:562`) polls `GetWidth` / `GetEffectiveScale` on the canvas container — reads only, non-tainting. Likely low residual risk — reproduce under current build first. **[Verified]** |

### Medium (1–3 days)

| Ticket | Code state | Notes |
|---|---|---|
| **HS-062** PerformEmote taint in PvP | All suspect hooks/SetParent still present | Hooks at `UI/MapSidePanel.lua:4019` (SetMapID), `4074` (HandleUserActionMaximizeSelf), `4093` (HandleUserActionMinimizeSelf); SetParent on portraitContainer/navBar/tutorial at 3217, 3240, 3278; plus `hooksecurefunc(WorldMapFrame, "RefreshOverlayFrames", ...)` at 2208. Same combat guards as HS-052. Taint cascade originates in Blizzard's secure TOGGLEWORLDMAP path, so the fix is investigative — follow ticket's Gate 0 plan (standalone mode test with `integrateMapBorder=false` first). No patch until root cause is pinned. **[Verified]** |

### Recommended order

1. **HS-054** — 30-minute verification, likely just needs the reporter
   to retest.
2. **HS-056** — atlas swap, trivial.
3. **HS-052** — confirm the combat gating actually resolved the
   2026-03-28 report; if still reproducing, rework docking to avoid
   `SetPoint`/`GetTop`/`GetBottom` on protected children entirely
   (longer).
4. **HS-062** — don't touch until investigation identifies which hook
   or reparent is the cascade source. This is the
   "plausible-fix-that-doesn't-address-root-cause" class of bug the
   ticket warns about.

Key finding: HS-052 and HS-062 both picked up combat-lockdown
mitigations since the tickets were written — worth re-reproducing both
before committing to fix work.

---

## Categories not audited

These sections remain as-is in `Home_Tracker.md`:

### Data (6) — mostly in-game scanning / pipeline work, not code

- **HS-007** In-game vendor verification queue — Medium
- **HS-012** Source data gaps — Medium
- **HS-014** ProfessionSources skillTier backfill — Medium (blocks HS-024)
- **HS-016** Pre-Midnight faction IDs in VendorDatabase — Medium
- **HS-039** Side panel data gaps — Low
- **HS-046** Audit `altCurrency` vendors for stale gold costs — Low

### Stale (2)

- **HS-006** Apply pipeline data corrections — High, needs full pipeline rerun
- **HS-015** Collect Hearthsteel itemIDs — consolidated into HS-049

### Empty sections

Next Release, Awaiting Gate 2, Awaiting Release.

---

## Cross-cutting recommendations

1. **Batch the 6 feature quick wins** (HS-019, HS-022, HS-026, HS-030,
   HS-031, HS-040) into a single "plumbing" PR — minimal risk,
   noticeable surface-area improvement.
2. **Prioritize HS-060** among maintenance — highest risk of silent
   user-visible ownership bugs.
3. **Re-reproduce HS-052 and HS-062** before any code work — combat
   lockdown guards landed after the tickets were filed and may have
   already mitigated them.
4. **Unstick HS-038** — either complete the worktree or close the
   ticket; staleness costs nothing to resolve.
5. **HS-014 before HS-024** — profession skillTier backfill is a hard
   prerequisite for the Ambient Profession Awareness suite.
6. ~~**Close or re-scope HS-061**~~ — already complete (2026-04-15,
   commit `fbba0bb`). Removed from the open recommendations list.

---

## Verification notes (2026-04-20)

Checked every file:line citation in the audit against current `main`.

**Confirmed as written** — HS-019, HS-031, HS-040, HS-036, HS-060
(CatalogScanner gap real), HS-052, HS-054, HS-056, HS-062, HS-024,
HS-044.

**Corrected** — file paths normalized across the board (`Modules/`,
`Overlay/`, `UI/`, `Data/` prefixes). Specific line drifts:
- HS-026: `HomesteadWorldMapProvider.lua` POI loop is 277–299, not 274–293.
- HS-030: cited `Validation.lua:391` is inside `ShowDetails`; the
  actual validator loop is `ValidateVendorDatabase` at line 144.
- HS-017: cited `Tooltips.lua:584` is event-source currency
  rendering (inside `RenderEventSourceLines`), not vendor-level. The
  conceptual gap (no per-item currency) is still real; per-item cost
  is already modeled in `VendorData.lua:116`.

**Reclassified** —
- **HS-061**: **Already complete** — not an audit finding. Fixed by
  commit `fbba0bb` on 2026-04-15 and already in `Home_Completed.md`.
  The audit's original "already fixed, no action needed" framing was
  misleading because it read like a discovery; this version corrects
  that. The code the audit verified at `CatalogStore.lua:494–496` is
  the result of `fbba0bb`, not pre-existing.
- **HS-018**: stronger finding than originally written. Badge
  functions already accept `sourceFilter`; the gap is that specific
  callers (zone view at `MapSidePanel.lua:2511`, every `VendorMapPins`
  caller) ignore it. Tracker's `BadgeCalculation.lua:314` ref is
  stale — that line is now a validity check inside `AddSummaryLine`.
  Fix is per-caller, not deep.

**Process lesson —** the audit was written without checking
`Home_Completed.md` or the `Home_Dev/plans/active/` directory first.
HS-061 was already completed (2026-04-15) and HS-062 already had an
investigation brief (2026-04-15) with Tests 1+2 prepped for Rawb.
Future audits should cross-reference the completed log and active
plan docs before classifying items as "not started" or "already fine."
