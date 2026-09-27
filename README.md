# Homestead

A World of Warcraft housing addon for collectors who want answers, not interfaces.

I wanted one simple thing: open the map and see where to get the decor I'm missing. No giant windows, no setup. Homestead puts that information on the map, the minimap, and the tooltips you already use.

Built for Retail (Midnight).

## What It Does

**On the map**

- Decor vendors are pinned on your world map and minimap, including the alternate minimap some zones switch to.
- Each vendor pin shows how many of their items you've collected (like "3/12"). Hover it to see every item they sell, colored by whether you own it, can buy it now, or it's still locked.
- Decor that drops from a dungeon or raid boss gets its own pin next to that boss on the instance map, and at the dungeon entrance on the zone map.
- Zone and continent badges show your progress across a whole region.
- Holiday vendors show up while their event is running. Legion Order Hall vendors also get a pin at the Dalaran portal so you can find the way in.
- The world map's filter menu has a Homestead section for turning each kind of pin on or off, and for hiding vendors you've fully collected.
- Click a vendor pin to set a waypoint. Works with the game's own waypoints and with TomTom if you have it.
- Opposite-faction vendors are shown with their faction emblem so you know before you travel. You can hide them in options.

**The vendor panel**

Click the Homestead button on the world map to open a panel listing every decor vendor in the zone you're looking at. Click a vendor to browse their stock, see what you still need, and preview any item in 3D.

- Search for any decor item and see all of its sources: vendors, quests, achievements, professions, drops, and events.
- Filter by source type.
- A progress bar shows what you own (green), what you can buy right now (gold), and what's locked (red).
- Locked items tell you exactly what's blocking them: the reputation, quest, achievement, or profession level you still need.
- Use `/hs panel` or right-click the minimap button to pop the panel out into its own window that stays open without the map.

**Tooltips and icons**

- Decor tooltips show where an item comes from, what it costs, and what you need to unlock it.
- Decor in your bags, bank, and at merchants gets a small housing icon: green if you've collected it, yellow in your bags if you haven't learned it yet, and red at merchants if you don't own it. Works with the default bags, Baganator, and BetterBags.
- The Housing Catalog marks every item with its source type. A colored glow shows at a glance whether you own it, can get it now, or it's locked. Owned items can be highlighted, dimmed, checkmarked, or left alone.
- Uncollected decor that comes from a treasure shows a treasure badge in the catalog.
- In your profession window, recipes you know and can craft right now get a Homestead badge if you haven't collected that decor yet.
- The Endeavors tab of the Housing Dashboard shows how much XP you need for the next milestone, and how much of the current Endeavor vendor's stock you've collected.

**Your collection**

Homestead reads ownership from the game's own housing catalog, so an item counts as collected no matter where you got it: a vendor, a quest, an achievement, a drop, or a craft. If two vendors sell the same item, buying it from either one marks it owned on both.

The database covers vendors from Classic through Midnight, plus quest rewards, achievements, profession recipes, drops, treasures, holiday events, and in-game shop items.

## Vendor Scanning

When you open a vendor that sells housing items, Homestead records what they sell, including prices and requirements. Your map pins and tooltips then show that vendor's current stock and prices.

Don't want it? Turn off **Auto-scan vendors** in the General tab of the options.

## Installation

1. Install from [CurseForge](https://www.curseforge.com/wow/addons/homestead-wow) or [Wago](https://addons.wago.io/addons/homestead).
2. Or download a release and extract it to `World of Warcraft/_retail_/Interface/AddOns/Homestead`.
3. Enable it in your addon list and `/reload`.

## Commands

`/hs` and `/homestead` both work.

| Command | What it does |
|---------|-------------|
| `/hs` | Open the options panel |
| `/hs help` | List every command |
| `/hs panel` | Toggle the detached vendor panel |
| `/hs vendor [name]` | Search for a decor vendor by name or zone |
| `/hs waypoint` | Clear the current map waypoint (also `/hs wp`) |
| `/hs scan` | Rescan the housing catalog for items you own |
| `/hs refreshmap` | Refresh the world map pins |
| `/hs export` | Open the export window for your scanned vendor data |
| `/hs exportall` | Export all your scanned vendor data as text |
| `/hs clearscans` | Clear your scanned vendor data |
| `/hs welcome` | Reopen the welcome screen |
| `/hs whatsnew` | Reopen the What's New screen |
| `/hs version` | Show your version. Add `on` or `off` to toggle update notices |
| `/hs debug` | Toggle debug mode (handy for bug reports) |

## Options

Type `/hs` or left-click the minimap button. Settings are split into General, Overlays, Tooltips, World Map, Minimap, Endeavors, and Export tabs.

A few worth knowing about:

- **Pin color**: 10 presets or a custom color picker.
- **Pin size**: separate sliders for world map and minimap pins.
- **Show opposite faction vendors**: on by default.
- **Hide fully-collected vendor pins**: off by default.
- **Owned item style**: how collected items look in the Housing Catalog.

## Translations

Homestead ships with German, French, Spanish (Spain and Mexico), Brazilian Portuguese, Korean, Simplified Chinese, and Russian. Russian is a complete community translation. The others are machine-translated, and anything untranslated shows in English. Corrections are welcome on GitHub.

## Reporting Bugs

Found a bug or a wrong vendor? Open a [GitHub issue](https://github.com/Royaleint/Homestead/issues) with the vendor name, zone, your faction, and what you expected versus what Homestead showed. If it's an error or a performance problem, turn on `/hs debug` first and include what it prints.

## Acknowledgments

Special thanks to Azro, author of [HomeDecor](https://www.curseforge.com/wow/addons/homedecor), for being open to sharing ideas and suggestions for improvements.

### Libraries

- [Foundry](https://github.com/Royaleint/Foundry)
- [CallbackHandler](https://www.wowace.com/projects/callbackhandler)
- [LibDataBroker](https://www.wowace.com/projects/libdatabroker-1-1)
- [LibStub](https://www.wowace.com/projects/libstub)
- [WagoAnalytics](https://addons.wago.io/addons/wago-analytics)

## License

[GPL-3.0](LICENSE)
