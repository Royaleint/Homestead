# Homestead Changelog

---

## Unreleased (v1.6.1)

### Improved
- **Zone Progress Bar** — The collection progress bar now smoothly animates to its new value instead of jumping instantly.
- **Faction Filtering** — Vendors in faction-locked zones (WoD garrisons, Ashran, Boralus, Dazar'alor, housing neighborhoods) are now automatically filtered correctly even if no explicit faction tag is set. Prevents misclassified vendors from showing up on the wrong faction's map.

---

## v1.6.0 (2026-02-26)

### New

- **Homestead Panel Search** — Type anything into the search bar and instantly find matching items, vendors, or zones. Matching vendors show your collection progress, and clicking one drops you straight onto their map with their inventory open and your matches highlighted.
- **Zone Collection Progress Bar** — A color-coded bar under the panel header gives you an instant read on how complete your collection is in the current zone — red when you're just starting out, yellow when you're getting there, green when you've cleaned it out. Hover it for a full breakdown.
- **Source Filter** — A new dropdown in the panel header lets you filter by source type: Vendor, Quest, Achievement, Profession, Event, or Drop. Item counts and grids update on the fly. It stays in sync with Options so your preference is always saved.
- **Order Hall Portal Pins** — Legion Order Hall vendors now show two pins: one at the vendor inside the hall, and a class-icon pin at the Dalaran portal so you always know where to enter. No more alt-tabbing to a guide just to find the door.
- **Multi-Source Tooltips** — Tooltips now show every known source for an item, not just the first one. If something drops, sells, and comes from an achievement, you'll see all three.
- **Context-Aware Tooltips** — Tooltips know where you are. Compact and clean at merchants and in your bags, full detail in the Homestead panel. Hold Shift anywhere to flip between modes on the fly.
- **Per-Block Completion** — Housing Catalog tooltips now show completion status for each source separately — so if an item comes from an achievement and a quest, you'll know which one you've done and which you haven't.
- **Active Endeavor Vendors** — The panel now only shows endeavor vendors when their initiative is actually running in your neighborhood. No more phantom vendors for initiatives you can't access.
- **Tooltip Settings** — Two new toggles in Options let you control whether tooltips show ownership status and whether they show all sources or just the primary one.

### Improved

- **Currency Icons** — Costs in tooltips now show Blizzard's actual currency icons instead of plain text. Looks the way it always should have.
- **Vendor Pin Icon** — Map pins now use the game's own housing decor vendor icon, so they fit right in alongside Blizzard's native POIs.
- **Cleaner Merchant Tooltips** — When you're standing at a vendor, Homestead no longer repeats information Blizzard already shows you. Only the stuff that's actually new.
- **Faster Map Loading** — Pin loading on zone transitions is noticeably snappier, and the minimap no longer hammers the server with requests when you cross a zone boundary.

### Fixed

- **Order Hall Vendor Locations** — Death Knight, Paladin, Rogue, Monk, Mage, Warrior, Shaman, Priest, and Demon Hunter Order Hall vendors all had wrong or missing map locations. All corrected with verified in-game coordinates.
- Fixed the Homestead button landing in the wrong spot on certain world map layouts.
- Fixed vendor row hovers not consistently lighting up the matching map pin.
- Fixed stacked vendor pins overlapping each other on the map.
- Fixed requirement text showing twice in the Homestead panel.

### Vendor Database

**Midnight**

Midnight vendors are in with confirmed item lists, accurate locations, and real costs from in-game scans.

New vendors:
- **Tajaka Sawtusk** — Amani'Zar Village, Zul'Aman
- **Chel the Chip** — Zul'Aman
- **Sathren Azuredawn** — Saltheril's Haven, Eversong Woods
- **Apprentice Diell** — Saltheril's Haven
- **Armorer Goldcrest** — Saltheril's Haven
- **Hesta Forlath** — The Bazaar, Silvermoon City

Updated from launch scans: **Magovu**, **Caeris Fairdawn**, **Neriv**, **Ranger Allorn**, **Dennia Silvertongue**, **Thraxadar**, **Telemancer Astrandis**, **Void Researcher Aemely**, **Void Researcher Anomander**, **Maku**.

**Other Corrections**
- Removed crafted items that were incorrectly listed as vendor stock on several Frostwall garrison vendors.
- Corrected costs and locations for **Falara Nightsong**, **Joruh**, **Flamesmith Lanying**, and **Caydori Brightstar**.
- Restored **Eadric the Pure** to the Sanctum of Light with a corrected item list.
- Various cost and item corrections from community scan exports.

---

## v1.5.0 (2026-02-21)

### New
- **Enhanced Tooltips** — Tooltips now show acquisition sources, unlock requirements, and completion status.
- **Event Vendor Pins** — Holiday vendors appear on the map automatically when their event is active.
- **Indoor Vendor Pins** — Vendor pins now work in indoor maps like Dalaran Underbelly and Thunder Totem.
- **What's New Popup** — See what changed after each update.

### Improved
- **Homestead Panel** — Now detachable, with item ownership, requirement info, and 3D previews. Right-click the minimap button to toggle.
- **Options** — Reorganized for a cleaner layout.
- Refreshed the **Welcome panel**.

### Fixes
- Fixed the panel shifting off-screen when maximizing or minimizing the world map.
- Fixed a combat taint error from the side panel.
- Fixed a rare scanner error in instanced content.
- Non-decor vendors no longer clutter saved scan data.
- Corrected several vendor locations, item data, and tooltip sources.

---

## v1.4.0

### New

**Homestead Panel**
A vendor panel now docks to the left side of your world map. Open the map in any zone and see every decor vendor there alongside your collection progress. Click any vendor to browse their full inventory: what you own, what's available, and what you still need.

- Click any item in the Homestead Panel to open a 3D model preview using the in-game viewer. The preview window is draggable and scaled for easy browsing.
- Locked items show a red border in the vendor inventory. Hover over any locked item to see exactly what's required to unlock it, whether it's rep, achievements, quests, or renown.
- Pop the Homestead Panel into its own floating window that stays open after you close the map. Detach it with the arrow button in the panel header or by right-clicking the minimap button.
- Toggle the Homestead Panel from the world map's tracking dropdown without closing it.
- Panel position and size are saved between sessions.

**Indoor Vendor Pins**
Vendor pins now display correctly in indoor maps like Dalaran Underbelly, Thunder Totem, Suramar City, and other interior zones that use their own map layer.

**Minimap Elevation Arrows**
Minimap pins now show directional arrows when a vendor is on a different floor above or below you.

### Changed

**Minimap Button**
Left-click opens and closes the options panel. Right-click opens and closes the Homestead Panel. Middle-click still triggers a collection scan.

### Fixed

- Fixed an error when opening certain vendors in instanced content, such as mount merchants after holiday bosses. (Thanks kittywulfe!)

---

## v1.3.3 (2026-02-14)

### Fixed
- **Hotfix**: Fixed minimap pins showing for distant vendors when the player is indoors.

---

## v1.3.2 (2026-02-14)

### New
- **Zone Badges on World Map** — New toggle in Options to show per-zone vendor counts spread across continents on the world map, instead of a single total per continent. Requested by u/melaspike666 from r/wowaddons.
- **Requirement Tooltips** — Item and housing catalog tooltips now show reputation, profession, and achievement requirements so you know what's gating an item before you travel there.
- **Scanner Toggle** — You can now disable automatic vendor scanning in Options under General settings.
- **Badge Tooltips** — Zone badges on the continent map now show helpful context like "Paladin Order Hall — Portal from Dalaran" so you know how to get there.

### Changed
- **Import Removed** — The import feature has been removed. Community data is now submitted via exports only.
- **Argus Map Pins** — Argus zone pins now display correctly on the Argus continent map. Zones are properly grouped under Argus instead of Broken Isles. An Argus badge also appears on the Broken Isles map.

### Fixed
- Fixed ownership detection being unreliable after certain login scenarios.
- Fixed Argus zone badges not appearing on the continent map.
- Fixed class hall vendor badges not showing on the Broken Isles map.
- Fixed sub-zone vendor pins not rendering on some Legion maps.
- Fixed several scan and debug messages appearing in chat during normal gameplay.
- Fixed zone badges not appearing for some vendor locations including Eversong Woods, Arcantina, and Harandar.
- Fixed "sold by" tooltips sometimes showing a faraway vendor instead of the closest one.

### Vendor Database

**Corrections**
- **Mrgrgrl**: Fixed coordinates and item cost data.
- **Halenthos**: Corrected faction.
- **Harlowe Marl**: Moved to Events expansion (was incorrectly tagged).
- **"High Tides" Ren**: Smuggler's Coast version now correctly links to the Founder's Point vendor with full inventory.

**Removed**
- Removed 17 vendors that were not confirmed as housing decor sellers, including 3 Orgrimmar PvP quartermasters and 14 unverified TWW vendors with no items.

**New and Updated**
- 15 vendors restored to active status after verification, including 8 new Midnight vendors.
- Missing items added and decor costs corrected across many existing vendors.
- **Chert**: Expanded from 1 to 4 items with full costs.
- **Waxmonger Squick**: Added 1 item (was empty).
- **Paul North**: Added 3 Brawler's Guild items (Horde counterpart to Quackenbush).
- **Krixel Pinchwhistle**: Added 4 items. Now appears in both Horde and Alliance garrison Trading Posts.
- **Ribchewer**: Added 4 items for the Horde garrison Trading Post.
- **Thripps**: +1 item, currency corrected to Kej, subzone fixed.
- **Lars Bronsmaelt**: Corrected from 33 items to 1 confirmed item (32 were misattributed from nearby vendors).

### Internal
- Major changes under the hood to help with future features and performance.

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
