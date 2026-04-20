# Homestead — Tracker Audit (2026-04-20)

Code-vs-tracker audit of open tickets in `Home_Tracker.md`. Each section
classifies items by implementation status and effort, with file:line
evidence from the current `main` and recommendations on how to approach
each.

---

## Features Audit

### Quick Wins (<1 day) — Knock these out first

| Ticket | Status | Notes |
|---|---|---|
| **HS-019** Search scroll/highlight | Partial | Dimming/expand already work in `MapSidePanel.lua:930–1007`; just add a `ScrollFrame` anchor call on match. |
| **HS-022** Hide completed vendors | Not Started | Add a setting + visibility filter in pin rendering. |
| **HS-026** Housing API exploration | Partial | `C_AreaPoiInfo` probes already exist in `HomesteadWorldMapProvider.lua:274–293`; just extend. |
| **HS-030** EndeavorsData validation | Not Started | Validator (`Validation.lua:391`) needs an extra loop over `EndeavorsData.lua`. |
| **HS-031** Import decorID | Partial | Export already writes field 9 (`ExportImport.lua:282, 396`); just wire the import parser. |
| **HS-040** Wago vendor counters | Partial | Analytics registered, `OnMerchantShow` hook exists (`core.lua:758`); add `Counter("vendor:"..npcID, 1)`. |

### Medium (1–3 days)

| Ticket | Status | Notes |
|---|---|---|
| **HS-017** Currency requirements display | Not Started | Vendor-level only today (`Tooltips.lua:584`); needs per-item cost parsing in panel + tooltip. |
| **HS-021** Continent pin placement | Not Started | Data-driven coordinate tweaks. |
| **HS-025** House dashboard tooltips | Not Started | Tooltip hook + DecorMapping surfacing. |
| **HS-044** Dynamic event pin positioning | Not Started | `GetEventsForMap` already present; needs Dreamsurge/Abundance/Chel dispatch. |
| **HS-051** Wago meaningful switches/counters | Not Started | 5+ new instrumentation points. |
| **HS-053** Shift-expand pin tooltips | Not Started | Blocked on HS-023 Phase 1. |
| **HS-038** FloorHints *(in progress)* | Worktree stale | Completion + in-game verify. |

### Longer Investments (>3 days, plan doc needed)

| Ticket | Status | Notes |
|---|---|---|
| **HS-018** Source-aware map filtering | Partial | Panel filter works, but map-level dropdown, non-vendor pins, and badge exclusion missing. |
| **HS-024** Ambient Profession Awareness | Partial | `ProfessionSources` + tooltip line already exist; profession window overlay + catalog badge remain; depends HS-014. |
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
| **HS-036** VendorMapPins runtime QA | Code robust — needs in-game testing | Event registration + ticker lifecycle already defensive (`UI/VendorMapPins.lua:327–407`, indoor check at line 235). Not code work — just a QA session across toggle/zone-transition states. |
| **HS-061** Migration 1→2 decorID via `_save` | Partially done | `_save` helper exists and updates both indices (`Data/CatalogStore.lua:47–66`). Migration already routes parsedSources through `_save` (line 494). But the scannedVendors path at line 512 skips decorID — audit/tighten that. Trap, not a bug today. |

### Medium (1–3 days)

| Ticket | Status | Notes |
|---|---|---|
| **HS-042** Slim Scanner refactor | Not Started | No prune logic in `Modules/ScanPersistence.lua`; no `ScanPersistence:Initialize()` call in `Core/core.lua:125`. Plan validated but implementation untouched — needs the worktree protocol. |
| **HS-060** Catalog byItem / ownership parity audit | Partial | byRecordID fallback added to `IsOwnedFresh` (`CatalogStore.lua:305–316`) and `ProbeByDecorID` (450–469), but **CatalogScanner has no byRecordID fallback** — likely the highest-impact gap. Ownership predicates also diverge: probe path uses 1 signal (`firstAcquisitionBonus == 0`), scanner uses 6 (`Modules/CatalogScanner.lua:37–77`). Needs prevalence count + scanner patch + docs. |

### Recommended order

1. **HS-060 first** — CatalogScanner missing the byItem-nil fallback
   could mean players see "0 owned" on items they own. That's the kind
   of bug HS-059 just fixed in one path but left in others. Highest
   user-visible risk.
2. **HS-036** — cheap QA session, catches regressions before they reach
   users.
3. **HS-061** — fold into the next catalog-store touch.
4. **HS-042** — only after creating the worktree per refactor protocol.

---

## Bugs Audit

### Quick Wins (<1 day)

| Ticket | Code state | Notes |
|---|---|---|
| **HS-054** Continent summary scope | **Likely already fixed** | `BadgeCalculation.lua:450–500` iterates globally, but `MapSidePanel.lua:2634–2645` filters by `contInfo.parentMapID == mapID`. Azeroth/Draenor views scope correctly; only true world (mapID 946) shows all. Verify with reporter before closing. |
| **HS-056** Dalaran class hall icons | Suspect code present | `PinFrameFactory.lua:344–354` uses Legion `legionmission-landingbutton-<class>-up` atlases with a housing fallback. Swap to real ClassHallFrames atlas. Pure polish. |
| **HS-052** World map taint | Suspect code present, **partially mitigated** | `ShiftMapRight`/`UnifyTopBorder`/`ApplyContentInset` still mutate protected frames (`MapSidePanel.lua:3120–3556`), but now gated by `InCombatLockdown()` + `PLAYER_REGEN_ENABLED` (lines 3582–3623). 0.1s `GetWidth()` ticker (`HomesteadWorldMapProvider.lua:562–583`) is a read, non-tainting. Likely low residual risk — reproduce under current build first. |

### Medium (1–3 days)

| Ticket | Code state | Notes |
|---|---|---|
| **HS-062** PerformEmote taint in PvP | All suspect hooks/SetParent still present | Hooks at `MapSidePanel.lua:4019, 4074, 4093`; SetParent on portraitContainer/navBar/tutorial at 3217, 3240, 3278. Same combat guards as HS-052. Taint cascade originates in Blizzard's secure TOGGLEWORLDMAP path, so the fix is investigative — follow ticket's Gate 0 plan (standalone mode test with `integrateMapBorder=false` first). No patch until root cause is pinned. |

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
