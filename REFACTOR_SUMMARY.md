# Refactor Contract — Development Summary for Claude Code

## What This Is

This document summarizes how the attached `REFACTOR_CONTRACT.md` was developed,
what it's designed to prevent, and what Claude Code's role is in reviewing it.

## How It Was Built

The contract was developed across multiple review rounds between three parties:

1. **Rawb** — addon author, project owner, final decision-maker
2. **Claude (Opus)** — drafted the contract, incorporating Homestead-specific
   knowledge from past development sessions
3. **ChatGPT 5.2** — independent reviewer, pressure-tested each version for gaps

The process went through four revision cycles:

### Round 1: Initial Draft
Claude drafted a three-layer refactor contract based on a methodology document
that Rawb had developed with Codex. The three layers:
- **Layer 0:** Pre-refactor baseline capture
- **Layer 1:** Scope guardrails (what may change)
- **Layer 2:** Mechanics guardrails (how changes are produced)
- **Layer 3:** Verification guardrails (how you prove nothing broke)

Added on top of the methodology: a tiered risk system (Tier 1/2/3), a sectional
refactor plan sequenced by risk, a rollback protocol, and a prompt template.

### Round 2: GPT Review — Three Gaps Found
GPT identified three real failure modes:
1. **Non-reproducible baselines** — pin count and memory measurements can vary
   depending on when/how you check them
2. **Unenforced policy** — telling an agent "don't do X" without making it prove
   compliance is a suggestion, not a gate
3. **Tier 3 approval timing** — the contract didn't explicitly require the agent
   to stop before writing code for high-risk changes

Claude agreed with all three and added:
- A standardized capture protocol (same character, zone, /reload, GC, open map)
- Automated verification gates (luacheck, global scan, SV schema check, diff audit)
- A Tier 3 HARD GATE requiring approval before any code is written
- A return-value semantics invariant (nil vs false vs empty table)

### Round 3: GPT Review — Two Refinements
GPT pushed on two points:
1. **SavedVariables check was too shallow** — checking for new keys isn't enough;
   need to check full structure (nesting, value types)
2. **Memory as a hard reject is too noisy** — memory fluctuates for non-behavioral
   reasons; should only be a hard reject for Section 4 (Pin Rendering) where it
   correlates with the known FPS stutter bug

Claude agreed and updated both.

### Round 4: GPT Final Review — Two Polish Items
GPT's final suggestions:
1. **SV fingerprint needs a minimum definition** — "deterministic, order-independent
   representation of key paths and value types" to prevent an agent from substituting
   a weak check
2. **Evidence log should be the single source of truth** — baseline numbers and gate
   results in one place, not scattered across commit messages and session notes

Claude agreed and consolidated everything into `refactor_logs/<date>-<section>.md`.

## What the Contract Is Designed to Prevent

The contract targets specific failure patterns known to occur when AI coding agents
perform refactoring:

- **Scope creep:** "Helpful" rewrites that change behavior while claiming to refactor
- **Drive-by formatting:** Reindenting or reflowing lines the agent didn't need to touch
- **Silent semantic changes:** Altering nil/false return behavior, event timing, or
  table shapes in ways that pass functional tests but break callers
- **SavedVariables corruption:** Schema changes that surface only after logout/reload
- **Global pollution:** Accidental new globals from missing `local` declarations
- **Performance regression:** Especially in pin rendering (Section 4) where users
  have already reported FPS stuttering

## What Claude Code Should Do With This

1. **Read `REFACTOR_CONTRACT.md` against the actual codebase.** Validate that:
   - The file list in each section matches reality (files may have been added/renamed)
   - The module boundaries make sense given current coupling
   - The risk tier assignments are accurate for each section
   - The Tier 3 smoke test checklist covers the real interaction paths

2. **Flag anything that doesn't match.** The contract was written based on code
   from past conversation history, not the live repo. If the codebase has evolved
   (new modules, renamed files, changed architecture), the contract needs updating.

3. **Propose any additional section-specific watch items.** Claude Code has full
   context on every file. If there are fragile patterns, implicit dependencies, or
   known gotchas in specific modules that the contract doesn't call out, add them.

4. **Do not begin refactoring.** This review is a validation pass only. Refactoring
   starts after the contract is approved and a specific section is selected.

## Key Design Decisions

- **Standalone document** — not inlined into CLAUDE.md or AGENTS.md. Both agent
  files reference it. This avoids duplication and keeps project rules focused.
- **Sectional approach** — refactor by module group, not whole-addon. Sequence is
  data layer → utilities → scanning → pin rendering → overlay/UI → core.
- **Tiered verification** — match testing effort to risk level. Renames get lint.
  Event handler changes get full smoke testing.
- **Evidence logging** — the agent must produce a written record of gate results,
  not just claim compliance.
- **Codex runs the refactor, Claude Code runs new features** — parallel workflow
  on separate branches to avoid merge conflicts.

## Files Referenced

- `REFACTOR_CONTRACT.md` — the contract itself (attach alongside this summary)
- `AGENTS.md` — Codex project rules (should reference the contract)
- `CLAUDE.md` — Claude Code project rules (should reference the contract)
- `AUDIT_REPORT.md` — global allowlist (referenced by the contract)
- `TODO.md` — current task state
- `CHANGELOG.md` — version history
