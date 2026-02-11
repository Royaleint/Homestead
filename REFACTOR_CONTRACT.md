# Homestead — Refactor Contract

This contract governs all refactoring work on the Homestead addon. No refactoring
may begin until this contract has been read and the pre-refactor checklist is complete.
Refactoring means restructuring code without changing behavior. If behavior changes,
it is not a refactor — it is a feature or a fix, and belongs on a separate branch.

---

## Layer 0: Pre-Refactor Baseline

**Prerequisite: Clean working tree.**
Before capturing baselines, confirm the working tree has no uncommitted changes.
Run `git status` — if uncommitted changes exist, commit or stash them first.
A refactor must never be mixed with pre-existing uncommitted work.

Before touching any code, capture and record these numbers in the refactor log
(`refactor_logs/<date>-<section>.md`). These are your "before" snapshot.

**Required baselines:**
- Vendor count from `/hs validate` (or `HA.VendorData` query)
- Pin count per zone (open world map, note pin totals for 2–3 test zones)
- Memory usage: `/script UpdateAddOnMemoryUsage(); print(GetAddOnMemoryUsage("Homestead"))`
- `luacheck` output (warning/error count)
- Any existing BugSack errors (note or screenshot)

**Standardized capture protocol** (ensures reproducible numbers):
1. Log in on the same character, same zone (use Dornogal as canonical test zone)
2. `/reload`
3. Wait 5 seconds for initialization to complete
4. `/script collectgarbage("collect")` (normalize GC state)
5. Open the world map once (triggers pin rendering and resolves lazy-load state)
6. Close the world map
7. Now capture all baselines above

Pin count means **active displayed pins only** — not pooled/hidden frames. If a
debug command to count these doesn't exist yet, add one before starting the refactor.

**Why:** These baselines are how you detect unintended changes. A refactor that shifts
vendor count, pin count, or error count changed behavior. Memory changes require
investigation (see Memory Usage Policy under Tier 3 verification).

---

## Layer 1: Scope Guardrails (What You May Change)

### Invariants — these must remain identical after refactoring:
- All inputs, outputs, and side effects of every function
- Return value semantics (nil vs false vs empty table — do not change what a function
  returns in any case, including edge cases and error paths)
- SavedVariables schema (`db.global` and `db.profile` structure)
- Slash command behavior (`/hs` and all subcommands)
- Event registration and firing (both WoW events and `HA.Events`)
- UI appearance and interaction (pins, tooltips, frames, options panel)
- Public module API (any function called across file boundaries via `HA.*`)

### Prohibited during refactoring:
- No new dependencies (libraries, embedded files)
- No new global variables (8-global allowlist in AUDIT_REPORT.md is frozen)
- No new SavedVariables keys or schema changes
- No deprecated WoW API replacements unless explicitly requested
- No taint/secure code modifications unless the refactor specifically targets that
- No TOC Interface number changes
- No changes to `.toc` file load order unless required by an extract-to-new-file refactor
  (and only with explicit approval)

### If you are unsure whether a change affects behavior: stop and ask. Do not guess.

---

## Layer 2: Mechanics Guardrails (How You Produce Changes)

### Diff discipline:
- Output unified diffs or minimal patches, not full-file rewrites
- One logical change per commit (e.g., "extract helper function" or "rename for clarity"
  — not both in the same commit unless they are in the same function)
- Do not reindent, reflow, or reformat lines you are not logically changing
- Preserve all comments unless they are factually wrong after the refactor

### File boundaries:
- Maximum 3 files modified per commit
- If a refactor requires touching more than 3 files atomically (e.g., extracting a
  shared utility called by 4 modules), document why in the commit message

### Addon metadata:
- Do not change `.toc` ordering or Interface number unless explicitly requested
- Do not modify `embeds.xml` unless adding/removing a file that the refactor created/deleted
- Do not alter `CHANGELOG.md` — the operator updates that manually

### Commit messages:
- Format: `refactor(module): brief description`
- Example: `refactor(VendorMapPins): extract GetNearbyMapIDs helper`
- Include before/after baseline numbers if the refactor touches performance-sensitive code

---

## Layer 3: Verification Guardrails (How You Prove Nothing Broke)

### Tier system — match verification effort to risk level:

**Tier 1 — Safe (lint only)**
- Renames (variables, locals, internal functions)
- Comment updates
- Extracting pure helper functions with no side effects
- Moving local functions within the same file (respecting Lua 5.1 declaration order)

Verification: `luacheck` passes. Warning/error count unchanged or reduced.

**Tier 2 — Moderate (lint + load test)**
- Restructuring control flow (if/else chains → lookup tables, etc.)
- Splitting one file into two (with TOC update)
- Changing iteration patterns (ipairs → pairs, loop restructuring)
- Extracting functions that have side effects into separate functions

Verification: `luacheck` passes + `/reload` with no BugSack errors + affected
slash commands still work.

**Tier 3 — High (full smoke test)**
- Anything touching event registration or handler wiring
- Anything touching frame lifecycle (CreateFrame, OnUpdate, Show/Hide)
- Anything touching SavedVariables read/write timing
- Anything touching OnUpdate handlers or periodic timers
- Anything touching pin creation, placement, or refresh logic

**HARD GATE: If any proposed change classifies as Tier 3, stop and present the
classification with justification BEFORE writing any code. Do not produce diffs
for Tier 3 changes without explicit approval. This is not optional.**

Verification: Full checklist —
1. `luacheck` passes
2. `/reload` — no BugSack errors
3. Open world map — pins render correctly in 2+ zones
4. Minimap pins visible and responsive
5. `/hs scan` completes without error
6. `/hs validate` returns same counts as baseline
7. Memory usage check (see note below)
8. Visit a vendor — tooltip and scanner behave normally
9. `/hs debug` toggle works
10. Logout and re-login — SavedVariables persist correctly

**Memory usage policy:**
- **Section 4 (Pin Rendering):** Memory change >10% from baseline is a hard reject.
  This section has a known user-reported FPS stutter issue — memory is a direct signal.
- **All other sections:** Memory change >10% is a flag for review, not an automatic
  reject. Investigate the cause and document the reason. If the increase comes from
  a legitimate structural change (e.g., new lookup table for faster access), it may
  be acceptable. If the cause is unclear, treat it as a violation.

---

## Automated Verification Gates

These checks must be run by the agent before claiming a refactor is complete.
Policy without enforcement is a suggestion — these turn the contract into gates.

**After every commit, run:**

1. **luacheck** — must pass with same or fewer warnings than baseline
2. **Global pollution scan** — parse modified files for new `_G[...]` writes or
   accidental globals not in the AUDIT_REPORT.md allowlist
3. **SavedVariables schema check** — confirm no changes to `db.global` or `db.profile`
   defaults: no new keys, no removed keys, no changed nesting structure, no changed
   value types (e.g., string → table, number → nil). Compare the full schema shape,
   not just top-level key names. The schema fingerprint must be a deterministic,
   order-independent representation of all key paths and their value types — not a
   visual inspection or subjective comparison.

**After every commit in Tier 2 or Tier 3:**

4. **Diff audit** — review the commit's diff. Flag any line that changes a return
   value, alters nil/false handling, or modifies event registration. These are
   silent behavior changes that pass functional tests but break callers.
   Do not proceed to the next commit until the diff audit is clean.

   **Pattern coverage rule:** When extracting a helper to replace a repeated pattern,
   the diff audit must list ALL instances of that pattern in the codebase — both
   converted and unconverted — with justification for any left unchanged (e.g.,
   out of declared scope, different file, local visibility prevents access).

If any gate fails, the commit is rejected. Fix or revert before proceeding.

**Evidence logging:**
After running gates, append results to `refactor_logs/<date>-<section>.md` with:
- **Layer 0 baselines** (captured under the standardized protocol before any changes):
  vendor count, pin count, memory usage, luacheck count, BugSack errors
- **Post-commit values** for the same metrics
- luacheck warning/error count: before → after
- New globals found: (must be 0)
- SV schema fingerprint: unchanged / changed (detail if changed)
- Diff audit: clean / flagged items (list if any)

This log is the canonical record for the refactor. Do not split evidence across
commit messages, session notes, and separate files — everything goes here.
The agent must show its work, not just claim it passed.

---

## Sectional Refactor Plan

Refactor in sections, not whole-addon. Each section is a group of code that shares
a failure mode — if something breaks, the blast radius stays contained.

### Recommended sequence (lowest risk first):

**Section 1: Data Layer**
Files: `VendorData.lua`, `VendorDatabase.lua`, `Data/AchievementDecor.lua`, `Data/DecorData.lua`
Risk: Tier 1–2 (mostly pure lookups, no frame lifecycle)
Why first: Clean data interfaces make every other section easier to refactor.
Watch for: Cache invalidation timing (`InvalidateAllCaches()`), `ScannedByItemID` index rebuild.

**Section 2: Utility & Validation**
Files: `Utils/`, `Modules/Validation.lua`, `Modules/ExportImport.lua`
Risk: Tier 1–2
Why second: Self-contained, minimal coupling to UI or events.

**Section 3: Scanning**
Files: `Modules/CatalogScanner.lua`, `Modules/VendorScanner.lua`
Risk: Tier 2–3 (event-driven, interacts with Blizzard API)
Watch for: `MERCHANT_SHOW`/`MERCHANT_UPDATE` handler timing, taint boundaries,
alias resolution at scan time.

**Section 4: Pin Rendering**
Files: `UI/VendorMapPins.lua`
Risk: Tier 3 (frames, OnUpdate, HereBeDragons interaction)
Why here: Most complex module, benefits from data layer and scanner being clean first.
Watch for: FPS impact (known user-reported issue at v1.2.0), frame creation/pooling,
`RefreshMinimapPins` and `RefreshWorldMapPins` performance.

**Section 5: Overlay & UI**
Files: `Overlay/`, `UI/MainFrame.lua`, `UI/Options.lua`
Risk: Tier 2–3 (frame lifecycle, user-facing)
Why here: Depends on clean interfaces from all previous sections.

**Section 6: Core & Glue**
Files: `Core/core.lua`, `Core/constants.lua`, `Core/events.lua`, `Core/cache.lua`
Risk: Tier 3 (touches everything)
Why last: Every other module depends on core. Refactoring it benefits the most from
all other modules having clean, stable interfaces first.

### Decision framework for prioritizing within a section:
1. **Coupling** — How many other files call this code? High coupling = later.
2. **Churn** — Where are changes happening most often? High churn = sooner.
3. **Risk tier** — Does it touch events, frames, or SV timing? High risk = schedule
   when you have time to run the full smoke test.

---

## Rollback Protocol

Every refactor commit must be independently revertable via `git revert`.
If a refactor spans multiple commits, they must revert cleanly in reverse order.
If a refactor cannot be reverted without breaking other changes, it was not
properly scoped — break it into smaller pieces.

Before starting any Tier 3 refactor, create a named branch:
`refactor/section-name` (e.g., `refactor/vendor-map-pins`)

---

## Prompt Template for Starting a Refactor Session

Use this when initiating a refactor with any AI coding agent:

```
Read the full project including AGENTS.md (or CLAUDE.md) and REFACTOR_CONTRACT.md.

Target: [Section name] — [specific files]
Goal: [What you want restructured and why]

Before writing any code:
1. Capture pre-refactor baselines (see Layer 0, follow the standardized capture protocol)
2. Classify each proposed change by risk tier
3. If ANY change is Tier 3: stop and present classification with justification. Wait for approval.
4. Present the refactor plan as a numbered list of commits
5. Wait for approval before producing any diffs

Constraints:
- Refactor only. Do not change behavior.
- Output only unified diffs.
- Keep changes minimal (no unrelated formatting).
- No new globals, no new deps, no SV schema changes.
- If unsure whether a change affects behavior, stop and ask.
- Follow the Refactor Contract in REFACTOR_CONTRACT.md.
```

---

## Contract Violations

If any of these occur, the refactor is rejected and must be reverted:
- Baseline numbers changed (vendor count, pin count, error count)
- New BugSack errors after `/reload`
- New `luacheck` warnings introduced
- New global variables detected
- SavedVariables schema modified (keys, nesting, or value types)
- Files modified that were not in the declared scope
- Full-file rewrites instead of minimal diffs
- Memory increase >10% in Section 4 (Pin Rendering)

Flag for review (not automatic reject, but must be investigated and documented):
- Memory increase >10% in any section other than Section 4
