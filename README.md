# Homestead

A World of Warcraft housing addon for collectors who want answers, not interfaces. Open your map and see exactly where to find the decor you're missing no massive windows, no menus, no setup.

## Features

- **Map Pins** — Housing decor vendors pinned to your world map and minimap with full inventory tooltips on hover.
- **Pin Colors** — Customize your pins with 10 color presets or a full RGB picker. Unverified vendors stay orange so you can spot them at a glance.
- **Collection Progress** — See how many items you've collected from each vendor right on the map (e.g., "3/12"). Zone and continent badges show green for complete, white for partial, red for uncollected.
- **Ownership Tracking** — Items tracked globally, so ownership is accurate regardless of source vendor purchase, quest reward, achievement unlock, or profession craft.
- **Auto-Scanning** — Visit a vendor and Homestead automatically records what they sell, including prices and item requirements. Toggle this off in Options if you prefer.
- **Multi-Source Database** — Vendors, quest rewards, achievement unlocks, profession recipes, and world drops tracked across all expansions from Classic through The War Within.
- **Faction Filtering** — Opposite-faction vendors hidden by default. Toggle visibility in Options.
- **Community Data Sharing** — Export your scanned vendor data and submit it to help fill gaps in the database.[Submit your export here] (https://forms.gle/hap2Mn1GKhweu1vp9)

## Installation

1. Download from [CurseForge](https://www.curseforge.com/wow/addons/homestead-wow) or [Wago](https://addons.wago.io/addons/homestead)
2. Or extract manually to `World of Warcraft/_retail_/Interface/AddOns/Homestead`
3. Enable in your addon list and `/reload`

## Commands

| Command | Description |
|---------|-------------|
| `/hs` | Open options panel |
| `/hs scan` | Refresh your ownership cache |
| `/hs export` | Export scanned vendor data for sharing |
| `/hs refreshmap` | Refresh all map pins |
| `/hs welcome` | Reopen the welcome screen |
| `/hs debug` | Toggle debug mode (useful for bug reports) |

## How It Works

Homestead tracks your housing decor collection across your entire account. When you acquire a decor item from any source like buying from a vendor, completing a quest, or earning an achievement it's recorded and reflected everywhere. If two vendors sell the same item, buying from either one marks it as owned on both.

Visit any decor vendor and Homestead will automatically scan their inventory, recording items, prices, and requirements. This data shows up in map pin tooltips so you always know what a vendor sells before you travel there. This helps us keep the database up-to-date! Not interested in this? Disable vendor scanning in /hs options

## Known Limitations

- **First Login** — Some ownership data may not appear until you open the Housing Catalog UI once per session. After that, everything stays accurate.
- **Data Gaps** — A small number of vendors may have incomplete item lists while we gather scan data. These are marked "unverified" on the map.

## Contributing

Community-scanned vendor data is welcome! Use `/hs export` and submit via [GitHub Issues](https://github.com/Royaleint/Homestead/issues).

When reporting bugs, include the vendor name, zone, what you expected vs. what the addon showed, and your character's faction.

## Acknowledgments

Vendor and item data verified against [WoW Housing Hub](https://housing.wowdb.com) — an invaluable community resource for housing decor tracking.

Special thanks to Azro, author of [HomeDecor](https://www.curseforge.com/wow/addons/homedecor), for being open to sharing ideas and suggestions for improvements.

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
