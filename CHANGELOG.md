# Homestead Changelog

---

## Unreleased (post-v1.3.1)

- Internal code improvements and refactoring.

---

## v1.3.1 (2026-02-10) — Patch 12.0.1 Compatibility Update

### Changed
- Updated for WoW patch 12.0.1 (Second Midnight Pre-Expansion Update).

### Fixed
- Fixed vendors confirmed as no-decor not being hidden from the map as intended.
- Fixed some achievement-gated items not being detected as housing decor during scans.
- Fixed the scan tooltip not working correctly in WoW 12.0+.

### Vendor Database

**Corrections**

- **Stacks Topskimmer**: Replaced 46 incorrect items with 13 confirmed Resonance Crystal items.
- **Eadric the Pure**: Trimmed from 16 to 7 confirmed items with proper Order Resources costs.
- **Ransa Greyfeather**: Trimmed from 23 to 8 confirmed items, fixed location.
- **Sylvia Hartshorn**: Replaced 6 wrong items with 5 confirmed items, fixed location and currency.
- **Selfira Ambergrove**: Removed 2 non-decor items, updated costs and coordinates.
- **Sileas Duskvine**: Replaced 5 wrong items with 1 confirmed item, fixed location.
- **Shadow-Sage Brakoss**: Restored after incorrect removal — confirmed 3 Apexis Crystal items.

**New and Updated Vendors**

- **14+ vendors** updated with verified cost data from community scan data.
- Multiple currency corrections across Warlords of Draenor and Legion vendors.

**Removed**

- Removed 4 vendors that were misidentified or don't sell housing decor: Sir Finley Mrrgglton (x2), Captain Lancy Revshon, and Smaks Topskimmer.
- **Domelius**: Marked unverified — Legion Remix vendor, no longer available in game.

---

## v1.3.0 (2026-02-08) — Pin Colors, Collection Tracking, and Vendor Scanner Overhaul

Hello again, there is a LOT in this release. Probably the biggest to me is the ability to change the color of the map icons and change the size of the map and minimap icons. This release overhauls map pin visuals, adds collection progress tracking directly on the map, and delivers a wave of  performance improvements and bug fixes. Pins are now customizable, color-accurate, and show at-a-glance collection status so you always know what you still need.

---

### Map Pins

**Pin Colors**

- You can now color your map and minimap pins! Choose from 10 presets — Default (Gold), Bright Green, Ice Blue, Light Blue, Cyan, Purple, Pink, Red, Yellow, and White — or use the full RGB color picker to make them your own.
- A color preview swatch in Options shows you roughly what the color will look like in-game.
- Unverified pins always stay orange so you can still spot them at a glance.
- Opposite-faction pins are automatically dimmed so they don't compete with yours.
- Colors now render accurately — blues, cyans, and purples no longer all look teal!

**Pin Size**

- New independent size sliders for world map pins (12-32) and minimap pins (8-24).
- Default sizes now match Blizzard's built-in POI icons so everything looks consistent.
- Zoom behavior is back to normal — pins scale naturally as you zoom the map.

**Collection Progress**

- Vendor pins on zone maps now show how many items you've collected out of their total stock (e.g., "3/12").
- Continent and zone maps display color-coded badges: green means you've got everything, white means partial, red means you haven't collected anything yet.
- If you prefer a cleaner look, you can toggle collection counts off in Options.

---

### Vendor Scanner

- Vendors confirmed to sell no housing decor are now tracked and hidden from the map — but only after two separate scans confirm it. A single scan won't accidentally hide anyone anymore.
- The scanner now picks up reputation, profession, and achievement requirements (the red tooltip text), so you'll know what's gating an item before you travel there.
- Rescanning a vendor no longer wipes out their existing zone, expansion, or currency info.
- The output window now has a "Select All" button for easier copying.
- New "Reset Hidden Vendors" button in Options if you ever want to bring back vendors that were flagged as no-decor.

---

### Developer Tools

- A new developer mode is available for addon contributors and data maintainers. Type `/hs devmode` to toggle it on. This gates several maintenance commands for managing scan data and vendor database entries.

---

### Bug Fixes

- Fixed item tooltips sometimes showing "Unknown Item" on first hover.
- Fixed the addon missing certain housing catalog update events.
- Fixed vendor faction tagging — vendors are now correctly identified as Alliance or Horde.
- Fixed waypoint setting failing on certain maps.
- Fixed the scanner not reading items from some vendors.
- Fixed export issues including broken formatting and special characters in requirement text.
- Fixed collection tracking not recognizing some owned items.
- Fixed the map not refreshing immediately after importing or clearing scan data.
- Fixed an issue where closing a merchant mid-scan could save incomplete data. Partial scans are now properly discarded.
- Fixed the "Show Vendor Details" toggle not working.
- Fixed tooltip "sold by" lookups breaking after importing or clearing data.
- Fixed some items being incorrectly flagged during data import.

---

### Vendor Database

**Corrections**

- **Faarden the Builder**: His entire item list was wrong — the 22 items listed actually belonged to a nearby vendor (Xiao Dan). Replaced with 35 verified items.
- **Sage Whiteheart**: Was pointing to a test NPC instead of the real vendor. Fixed with the correct NPC and location.
- Removed 5 vendors that were misidentified or don't actually sell housing decor: Jojo Ironbrow, Mistress Mihi, Chamberlain, and 2 stale aliases.

**New and Updated Vendors**

- **Silvrath**: 6 new items added (Dragon Isles Supplies costs) — now 14 total.
- **Cinnabar**: Now has 3 Resonance Crystal items (was empty before).
- **Cendvin**: Now has 1 item (was empty before).
- **Maaria**: Added Telredor Recliner with updated location.
- **Auditor Balwurz**: Expanded from 1 to 5 items with full Resonance Crystal costs.
- **Garnett**: +1 item from a community-submitted scan — thanks!
- **The Last Architect**: +1 item; currency corrected to Kej with Gold as alternate.
- **Celestine of the Harvest**: Added a note that this vendor moves with the Dreamsurge event — she won't always be in the same spot.

**Location Fixes**

- Updated map positions for Cinnabar, Cendvin, Faarden the Builder, and Maaria based on verified scan data.

---

### Performance

- Collection badge counts are now cached and only recalculated when your collection actually changes — you should notice less lag on zone maps with lots of vendors.
- The minimap and world map now skip redundant refreshes, so zone changes and map transitions feel snappier.

---

## v1.2.1 (2026-02-06)

### Fixed
- Fixed FPS stutter in vendor-dense locations. Zone changes and map transitions should be noticeably smoother now.

---

## v1.2.0 (2026-02-05) — The Great Vendor Audit

Thanks everyone for being patient while we worked out the non-decor vendor issue! Your reports helped us realize the database needed more than a quick fix — it needed a proper audit.

So that's what we did. Every vendor in the database got verified for accuracy. We corrected currencies, fixed coordinates, and cleaned up item lists across all expansions from Classic through The War Within. Vendors we couldn't verify are now hidden by default, so you'll only see pins for confirmed housing decor vendors.

The result: cleaner maps, accurate tooltips, and way fewer "why is this vendor here?" moments.

---

### Vendor Database

**Vendors**

- 17 vendor entries removed (duplicates or unverifiable).
- 12 new aliases added to merge duplicate NPC variants (24 total).
- 275 vendor entries validated across 11 expansions.
- Unverified vendors now hidden by default.

**Currency Corrections**

- 64 currency-related fixes across all expansions: 43 direct corrections, 20 secondary currency additions, and 1 spelling fix.
- New currencies cataloged: Community Coupons, Sizzling Cinderpollen, "Gold" Fish, Brimming Arcana, Voidlight Marl, Twilight's Blade Insignia.

**Location and Metadata**

- 34 empty zone names filled in.
- 24 Housing area vendors assigned to correct Alliance/Horde zones.
- 3 expansion tag corrections, 3 faction corrections, 1 vendor name fix.
- 4 coordinate updates from in-game scan data.
- 9 duplicate items removed from 3 vendor entries.

**Items and Sources**

- 8 items added from in-game scan data.
- 1 misattributed item moved from vendor database to achievement rewards.
- 16 achievement-to-decor mappings added for class hall, Lorewalking, and Nightborne achievements.

---

## v1.1.3 (2026-02-05)

### Fixed
- Fixed several namespace compliance issues.
- Replaced a deprecated container API call.

### Changed
- Updated Welcome screen branding and Quick Start guide.
- Fixed text encoding issues in the Welcome screen.

---

## v1.1.2 (2026-02-03)

### Added
- **WagoAnalytics integration** — Anonymous usage tracking to help improve the addon.
- **17 new vendors added** across Orgrimmar, Dornogal, Hallowfall, Azj-Kahet, and Ringing Deeps.
- **Unreleased vendor filtering** — Datamined Midnight vendors are now hidden until content goes live.

### Fixed
- Fixed missing or misplaced vendor pins for Nalina Ironsong, Thripps, Cinnabar, Shadow-Sage Brakoss, and several others.
- Refined coordinates for Velerd, Jorid, Waxmonger Squick, Cendvin, Lars Bronsmaelt, Chert, and Gabbun.
- Removed non-decor vendors Krinn and Kradan from the database.
- Fixed minimap pins in Outland, Draenor, and Shadowlands zones collapsing onto the player position.
- Added 15 missing zone mappings for proper minimap pin display across older content.

### Improved
- Welcome screen redesigned: larger, easier to read, includes feedback form link.

---

## v1.1.1 (2026-02-03)

### Fixed
- Fixed map pin tooltips not updating after scanning a vendor.

### Vendor Database
- **Balen Starfinder**: Updated with 46 items and full gold pricing, corrected location and faction.
- **Argan Hammerfist**: Updated with 13 items and full gold pricing, corrected location and faction.
- **Ta'sam**: Added 1 Resonance Crystal item.
- **Om'sirik**: Added 12 Resonance Crystal items.

---

## v1.1.0 (2026-02-03) — The "Help Us Build the Database" Update

### Added
- **Welcome Screen** — First-run onboarding popup; re-open with `/hs welcome`.
- **Vendor Export** — Share your scanned vendor data with the community, including full pricing info.
- **Differential Export** — Only exports vendors scanned since your last export.
- **Source Data System** — Quest, achievement, profession, and drop source lookups for decor items.
- **Enhanced Tooltips** — Decor tooltips now show source info and cost when available.
- New commands: `/hs welcome`, `/hs exportall`, `/hs clearscans`.

### Fixed
- Fixed vendor scanning not capturing prices correctly.
- Fixed scan timing issues — scans now wait for the merchant window to fully load before capturing.
- Fixed the Welcome screen not appearing on first install.

### Changed
- Export dialog now offers a single unified export option.
- Major vendor database refresh with populated item lists and corrected coordinates.

### Previous Unreleased
- Item-by-item catalog scanning for more reliable ownership detection.
- Multi-zone minimap pin coverage — you can now see vendors in adjacent zones on the minimap.
- Minimap pins float on the edge when vendors are out of range.
