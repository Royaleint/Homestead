# Homestead

A lightweight World of Warcraft housing addon for collectors who want answers, not interfaces. Open your map and see exactly where to find the decor you're missing — no massive windows, no menus, no setup.

## Features

- **Map Pins** — housing decor vendors pinned to your world map with full inventory tooltips on hover
- **Collection Tracking** — items tracked globally by item ID, so ownership is accurate regardless of source (vendor purchase, quest reward, achievement unlock)
- **Multi-Source Database** — vendors, quest rewards, and achievement unlocks tracked across all expansions from Classic through Midnight
- **Faction Filtering** — opposite-faction vendors hidden by default, toggle on to see everything
- **Minimap Button** — quick access to options and settings
- **Community Data Sharing** — export your scanned vendor data and import community contributions to fill gaps
- **Data Validation** — built-in integrity checks for the vendor database

## Installation

1. Download from [CurseForge](https://www.curseforge.com/wow/addons/homestead-wow) or extract manually to `World of Warcraft/_retail_/Interface/AddOns/`
2. Ensure the folder is named `Homestead` (not `Homestead-main`)
3. Enable in your addon list and `/reload`

## Commands

| Command | Description |
|---------|-------------|
| `/hs` | Show help |
| `/hs scan` | Scan targeted vendor |
| `/hs validate` | Check data integrity |
| `/hs export` | Export scanned data |
| `/hs import` | Import community data |

## How It Works

Homestead tracks ownership in a global table keyed by item ID. When you acquire a decor item from any source — buying from a vendor, completing a quest, earning an achievement — it's recorded once and reflected everywhere. If two vendors sell the same item, buying from either one marks it as owned on both.

Detection checks three sources in order: persistent cache (instant, survives reloads), Blizzard's Housing Catalog API, and bag inventory. Any positive result marks the item as owned globally.

## Known Limitations

- **Catalog Initialization** — ownership tracking requires opening the Housing Catalog UI once per session (Blizzard API limitation)
- **Mixed Currency** — some vendors accept multiple currencies (e.g., Gold + Garrison Resources); per-item currency breakdowns are not yet displayed
- **Data Gaps** — some vendors are confirmed but awaiting in-game scans to populate complete item lists
- **Placeholder Coordinates** — a small number of vendors have approximate map positions pending verification

## Contributing

Community-scanned vendor data is welcome — use `/hs export` and submit via [GitHub Issues](https://github.com/Royaleint/Homestead/issues).

When reporting bugs, include the vendor name, zone, what you expected vs. what the addon showed, and your character's faction.

## Acknowledgments

Vendor and item data verified against [WoW Housing Hub](https://housing.wowdb.com) — an invaluable community resource for housing decor tracking. In-game data collection and verification performed manually where Hub coverage is incomplete.

### Libraries

- [Ace3](https://www.wowace.com/projects/ace3) (AceAddon, AceConfig, AceConsole, AceDB, AceEvent, AceGUI)
- [CallbackHandler](https://www.wowace.com/projects/callbackhandler)
- [HereBeDragons](https://www.curseforge.com/wow/addons/herebedragons)
- [LibDataBroker](https://www.wowace.com/projects/libdatabroker-1-1)
- [LibDBIcon](https://www.wowace.com/projects/libdbicon-1-0)
- [LibStub](https://www.wowace.com/projects/libstub)
- [WagoAnalytics](https://addons.wago.io/addons/wago-analytics)

## License

[GPL-3.0](LICENSE)
