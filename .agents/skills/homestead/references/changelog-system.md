# Changelog System Reference

> **Location**: `.claude/skills/homestead/references/changelog-system.md`
> **Trigger**: Any release, version bump, changelog update, or packaging task

## Overview

Homestead maintains two changelogs per release:

1. **Public** (`CHANGELOG.md` in repo root) — Committed to git, pushed to
   CurseForge and Wago. Written for addon users.
2. **Internal** (`CHANGELOG-internal.md` in gitignored `Home_Dev/` folder) —
   Local dev-only. Full technical detail. Never published.

### Why Two Changelogs

- Users need outcomes, not implementation details.
- Internal notes preserve technical context for future debugging.
- Scanner pipeline, confidence models, cache strategies, and data
  architecture are competitive advantages — never publish these.

### PackageMeta Configuration

`.pkgmeta` must reference the public changelog:
```yaml
manual-changelog:
  filename: CHANGELOG.md
  markup-type: markdown
```

Wago API also accepts the changelog as a markdown string in the release
metadata JSON.

---

## Public Changelog — Rules

### Format

- Markdown (renders on CurseForge, Wago, and git natively)
- `---` horizontal rules between major sections
- Bold sub-headers (`**Pin Colors**`) for short sections within a category
- Bold vendor names in database sections
- Bullets: 1–2 sentences max, no nesting deeper than one level
- Structure modeled after Blizzard WoW patch notes

### Tone

- **Features / new content**: Warm, enthusiastic, player-first. Use "you"
  and "your." Exclamation points fine sparingly. Write like you're telling
  a guildmate what's new.
  - ✅ "You can now color your map pins! Blues and purples no longer look teal."
  - ❌ "Desaturate-before-tint pipeline applied to atlas icon vertex color."

- **Bug fixes**: Brief, outcome-focused. Start with "Fixed." Describe the
  symptom the user experienced, never the code-level root cause.
  - ✅ "Fixed item tooltips sometimes showing 'Unknown Item' on first hover."
  - ❌ "Pre-warm item info cache via GetItemInfo() on pin load."

- **Performance**: Describe the user experience improvement only.
  - ✅ "Zone changes and map transitions feel snappier."
  - ❌ "Minimap dedup guard skips redundant zone-change refreshes."

- **Database updates**: Factual and clear. Vendor name bolded, plain-language
  description.

- **Developer tools**: Acknowledge existence briefly. Do NOT document
  sub-commands, arguments, or output. Dev mode is presence-based
  (Homestead_Dev addon loaded), not a toggle.

### Structure Template

```markdown
# Homestead vX.Y.Z — [Short Feature Headline]

[1-2 sentence summary for the player. Enthusiastic but not over the top.]

---

## [Feature Category]

**[Sub-feature]**

- What changed, written for the player.

---

## Bug Fixes

- Fixed [user-visible symptom].

---

## Vendor Database

**Corrections**

- **Vendor Name**: What was wrong and what's fixed.

**New and Updated Vendors**

- **Vendor Name**: What was added or changed.

**Location Fixes** *(only if notable)*

- Brief grouped summary. No mapIDs.

---

## Performance *(only if notable)*

- What feels faster or smoother for the player.
```

### Never Publish (Public Changelog Blacklist)

These categories NEVER appear in the public changelog:

- WoW event names (`HOUSING_STORAGE_UPDATED`, `GET_ITEM_INFO_RECEIVED`, etc.)
- Function/method names (`InvalidateAllCaches()`, `GetPlayerMapPosition`, etc.)
- Cache strategies, debounce patterns, dedup guards
- Data structure internals (`.items` vs `.decor` keys, positional format)
- Scanner pipeline details (confidence model, scan coalescing, metadata logic)
- Developer command documentation beyond the toggle
- NPC IDs — use vendor names only
- MapID numbers or sub-zone ID corrections
- Encoding/serialization details (`%2C`/`%3B`, `R:` format)
- Dead code removal or infrastructure cleanup
- Nil guard additions, pcall wrapping
- Settings path corrections (`profile.vendorTracer.showVendorDetails`)
- Anything revealing how scanner, data pipeline, or competitive features work

---

## Internal Changelog — Rules

### Format

- Markdown with full technical detail
- Warning header at top:
  `> ⚠️ **This file is local-only. Do not commit or publish.**`
- Code formatting for function names, events, commands, data fields
- Bug fixes in table format: `| User-visible symptom | Root cause |`
- Database entries include NPC IDs in parentheses
- Include enough context that reading this 6 months later makes sense

### Tone

- Neutral-technical but friendly. Write like briefing a teammate who needs
  to understand both what changed and why.

### Content

Everything from the public changelog PLUS:
- Full implementation details and root causes
- Event names, function names, API specifics
- Cache/performance strategy details
- Scanner pipeline changes
- Developer command docs (names, arguments, output)
- NPC IDs, mapIDs, coordinate corrections
- Data structure changes and format migrations
- Dead code removal, infrastructure cleanup
- Settings path corrections

---

## Routing Table — What Goes Where

| Content                            | Public | Internal |
|------------------------------------|:------:|:--------:|
| New user-facing features           |   ✓    |    ✓     |
| Feature implementation details     |        |    ✓     |
| Bug fix (user symptom)             |   ✓    |    ✓     |
| Bug fix (root cause / code)        |        |    ✓     |
| Performance improvement (result)   |   ✓    |    ✓     |
| Performance improvement (method)   |        |    ✓     |
| Scanner pipeline changes           |        |    ✓     |
| Data model / export format changes |        |    ✓     |
| Developer commands (existence)     |   ✓    |    ✓     |
| Developer commands (full docs)     |        |    ✓     |
| Vendor item corrections            |   ✓    |    ✓     |
| Vendor NPC IDs                     |        |    ✓     |
| MapID / coordinate corrections     |        |    ✓     |
| Dead code removal                  |        |    ✓     |
| Chat output / debug routing        |        |    ✓     |
| Event name changes                 |        |    ✓     |
| Settings path fixes                |        |    ✓     |
| Community contributions (credit)   |   ✓    |    ✓     |

---

## Workflow

When generating changelogs for a release:

1. Gather all changes (commits, TODOs, issue closures) since last release.
2. Write the **internal changelog first** — capture everything with full
   technical detail.
3. Derive the **public changelog** from the internal by:
   - Translating implementation details → user-visible outcomes
   - Stripping everything on the "never publish" blacklist
   - Warming the tone for feature sections
   - Condensing bug fixes to symptom-only
   - Grouping minor database fixes where appropriate
4. Append to `CHANGELOG.md` (public, cumulative) in repo root.
5. Append to `CHANGELOG-internal.md` (internal, cumulative) in `Home_Dev/`.

### File Locations

| File                     | Path                  | Git Status |
|--------------------------|-----------------------|------------|
| Public changelog         | `./CHANGELOG.md`      | Committed  |
| Internal changelog       | `./Home_Dev/CHANGELOG-internal.md` | Gitignored |
| This reference           | `./.claude/skills/homestead/references/changelog-system.md` | Per project gitignore policy |
