--[[
    Homestead - Locale: English (US)
    Default localization strings
]]

local _, HA = ...

-- Initialize localization table
local L = {}
HA.L = L

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["Used in %d known recipe for decor you haven't collected"] = "Used in %d known recipe for decor you haven't collected"
L["Used in %d known recipes for decor you haven't collected"] = "Used in %d known recipes for decor you haven't collected"

-------------------------------------------------------------------------------
-- UI Labels
-------------------------------------------------------------------------------
L["Close"] = CLOSE or "Close"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["Homestead"] = "Homestead" -- untranslated
L["Homestead Options"] = "Homestead Options"
L["General"] = GENERAL or "General"
L["Overlays"] = "Overlays"
L["Tooltips"] = "Tooltips" -- untranslated
L["Export"] = "Export"

L["Show minimap button"] = "Show minimap button"
L["Enable overlays"] = "Enable overlays"
L["Show on bags"] = "Show on bags"
L["Show on bank"] = "Show on bank"
L["Show on merchant"] = "Show on merchant"
L["Show on housing catalog"] = "Show on housing catalog"
L["Icon size"] = "Icon size"
L["Icon position"] = "Icon position"
L["Show opposite faction vendors"] = "Show opposite faction vendors"

L["Enable tooltip additions"] = "Enable tooltip additions"
L["Show source information"] = "Show source information"
L["Show vendor details in tooltips"] = "Show vendor details in tooltips"

L["Show map pins"] = "Show map pins"
L["Show minimap pins"] = "Show minimap pins"
L["Use TomTom for waypoints"] = "Use TomTom for waypoints"
L["Use native waypoints"] = "Use native waypoints"
L["Auto-create waypoint on click"] = "Auto-create waypoint on click"
L["Navigate modifier key"] = "Navigate modifier key"

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d / %d (%d%%)"] = "Collection: %d / %d (%d%%)"
L["Vendors nearby: %d"] = "Vendors nearby: %d"
L["Vendors scanned: %d"] = "Vendors scanned: %d"
L["Left-Click: Toggle Decor Browser"] = "|cFFFFFFFFLeft-Click:|r Toggle Decor Browser"
L["Right-Click: Open options"] = "|cFFFFFFFFRight-Click:|r Open options"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Homestead Commands:"

-------------------------------------------------------------------------------
-- Slash Command Feedback
-------------------------------------------------------------------------------
L["Map pins refreshed."] = "Map pins refreshed."
L["No active waypoint."] = "No active waypoint."
L["Waypoint cleared."] = "Waypoint cleared."
L["Vendor database contains %d vendors."] = "Vendor database contains %d vendors."
L["Use /hs vendor <name or zone> to search."] = "Use /hs vendor <name or zone> to search."
L["No vendors found matching: %s"] = "No vendors found matching: %s"
L["Found %d vendor(s) matching: %s"] = "Found %d vendor(s) matching: %s"
L["... and %d more."] = "... and %d more."

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "Debug mode: %s"
L["ON"] = "ON"
L["OFF"] = "OFF"
L["Unknown command: %s"] = "Unknown command: %s"
L["Type /hs help for a list of commands."] = "Type /hs help for a list of commands."

-------------------------------------------------------------------------------
-- Version Check
-------------------------------------------------------------------------------
L["Your Homestead version is out-of-date."] = "Your Homestead version is out-of-date."
L["Version %s (%s) can be downloaded at CurseForge, Wago, or GitHub Releases."] = "Version %s (%s) can be downloaded at CurseForge, Wago, or GitHub Releases."
L["Homestead version: %s (%s)"] = "Homestead version: %s (%s)"
L["Newest version seen this session: %s (%s)"] = "Newest version seen this session: %s (%s)"
L["No newer version seen this session."] = "No newer version seen this session."
L["Version-check notifications: %s"] = "Version-check notifications: %s"

-------------------------------------------------------------------------------
-- Export Dialog
-------------------------------------------------------------------------------
L["Export Vendor Data"] = "Export Vendor Data"
L["Choose export option:"] = "Choose export option:"
L["Export New Scans"] = "Export New Scans"
L["Export All"] = "Export All"

-------------------------------------------------------------------------------
-- Map Side Panel
-------------------------------------------------------------------------------
L["All"] = "All"
L["Vendor"] = "Vendor"
L["Vendors"] = "Vendors"
L["Quest"] = "Quest" -- untranslated
L["Achievement"] = "Achievement"
L["Profession"] = "Profession"
L["Event"] = "Event"
L["Drop"] = "Drop"
L["Shop"] = BLIZZARD_STORE or "Shop"
L["Treasure"] = "Treasure"
L["Zone Collection Progress"] = "Zone Collection Progress"
L["Continent Collection Progress"] = "Continent Collection Progress"
L["Global Collection Progress"] = "Global Collection Progress"
L["Order Hall"] = "Order Hall"
L["Click to preview"] = "Click to preview"
L["No items found"] = BROWSE_NO_RESULTS or "No items found"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "Output"
L["Select All"] = "Select All"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "All text selected. Press Ctrl+C to copy to clipboard."

-------------------------------------------------------------------------------
-- Options - Names
-------------------------------------------------------------------------------
L["Vendor pin item details"] = "Vendor pin item details"

L["Auto-scan vendors"] = "Auto-scan vendors"
L["Vendor Visibility"] = "Vendor Visibility"
L["Show event vendors"] = "Show event vendors"
L["Hide fully-collected vendor pins"] = "Hide fully-collected vendor pins"
-- HS-317: world map filter menu checkbox (SHOW semantics, inverse of the panel row above)
L["Fully-collected vendors"] = "Fully-collected vendors"
L["desc_map_filter_completed_vendors"] = "Uncheck to hide pins for vendors whose decor you've fully collected."
L["Pin Appearance"] = "Pin Appearance"
L["Pin color"] = "Pin color"
L["Custom color"] = "Custom color"
L["Show accessibility glow"] = "Show accessibility glow"
L["Owned item style"] = "Owned item style"
L["Show ownership status"] = "Show ownership status"
L["Show requirements"] = "Show requirements"
L["Show all sources"] = "Show all sources"
L["Map Pins"] = "Map Pins"
L["World Map"] = WORLDMAP_BUTTON or "World Map"
L["Show vendor panel on world map"] = "Show vendor panel on world map"
L["Vendor panel source filter"] = "Vendor panel source filter"
L["Integrate with map frame border"] = "Integrate with map frame border"
L["Zone badges on world map"] = "Zone badges on world map"
L["World map pin size"] = "World map pin size"
L["Show collection counts"] = "Show collection counts"
L["Minimap"] = MINIMAP_LABEL or "Minimap"
L["Show elevation arrows"] = "Show elevation arrows"
L["Minimap nearby-zone pins"] = "Minimap nearby-zone pins"
L["Minimap pin size"] = "Minimap pin size"
L["Waypoints"] = "Waypoints"
L["Endeavors"] = HOUSING_DASHBOARD_ENDEAVOR or "Endeavors"
L["Show milestone progress on dashboard"] = "Show milestone progress on dashboard"
L["Inventory"] = "Inventory"
L["Merchant"] = "Merchant"
L["Housing Catalog"] = "Housing Catalog"

-------------------------------------------------------------------------------
-- Options - Descriptions
-------------------------------------------------------------------------------
L["desc_minimap_button"] = "Show or hide the minimap button"
L["desc_auto_scan_vendors"] = "Automatically scan merchant inventory for housing decor data when visiting vendors. Disabling may slightly improve performance when opening merchants."
L["desc_options_general"] = "Core addon behavior, minimap access, vendor scanning, and map pin appearance."
L["desc_options_overlays"] = "Collection markers shown on bags, the bank, merchants, and the Housing Catalog."
L["desc_options_tooltips"] = "Extra ownership, source, requirement, and vendor details added to item and map-pin tooltips."
L["desc_options_world_map"] = "World map vendor pins, zone badges, side-panel behavior, and map pin display."
L["desc_options_minimap"] = "Nearby vendor pins, elevation arrows, and waypoint behavior on the minimap."
L["desc_options_endeavors"] = "Housing Endeavor progress shown on Blizzard's Housing Dashboard."
L["desc_options_export"] = "Scanned vendor data export for review or backup."
L["desc_vendor_visibility_section"] = "Choose which vendor groups appear on maps and in collection totals."
L["desc_pin_appearance_section"] = "Adjust the color and preview for Homestead vendor pins."
L["desc_overlay_inventory_section"] = "Show collection markers on item slots outside the Housing Catalog."
L["desc_overlay_merchant_section"] = "Mark collected decor while browsing vendor items."
L["desc_overlay_catalog_section"] = "Control Housing Catalog markers, highlights, and collected-item styling."
L["desc_tooltip_map_pins_section"] = "Choose how much vendor detail appears on map-pin tooltips."
L["desc_minimap_waypoints_section"] = "Configure TomTom and native waypoint behavior from map and vendor clicks."
L["desc_opposite_faction"] = "Show vendors for the opposite faction with their faction emblem. Useful for completionists to see all available vendors."
L["desc_event_vendors"] = "Show seasonal holiday vendor pins on the map when their event is active (e.g., Lunar Festival)"
L["desc_hide_completed_vendor_pins"] = "Hide map and minimap pins for vendors whose housing decor you've fully collected. The vendor panel list is unaffected."
L["desc_pin_color"] = "Choose a color for map and minimap pins."
L["desc_custom_color"] = "Pick a custom base color for map pins"
L["desc_enable_overlays"] = "Add small icons and highlights to decor items throughout the game so you can tell at a glance which ones you've collected. Turning this off hides all Homestead overlays everywhere."
L["desc_icon_size"] = "Controls how large the collection icons appear on item slots."
L["desc_icon_position"] = "Which corner of the item slot the collection icon sits in."
L["desc_show_on_bags"] = "Adds a |A:homestone-minimap-icon:16:16|a to decor items in your bags, colored to show whether you've collected each one. Works with default bags, Baganator, and BetterBags."
L["desc_show_on_bank"] = "Mark decor items in your bank so you can see which ones you've already collected."
L["desc_show_on_merchant"] = "Adds a |A:homestone-minimap-icon:16:16|a to decor items at vendors, colored to show whether you've collected each one."
L["desc_show_on_housing_catalog"] = "Mark items in the Housing Catalog with collection icons showing where each item comes from.\n\n"
    .. "|A:auctionhouse-icon-coin-gold:16:16|a Vendor\n"
    .. "|A:QuestNormal:16:16|a Quest\n"
    .. "|A:UI-Achievement-Shield-NoPoints:16:16|a Achievement\n"
    .. "|A:UI-HUD-MicroMenu-Professions-Mouseover:16:16|a Profession\n"
    .. "|A:UI-HUD-Calendar-1-Up:16:16|a Event\n"
    .. "|A:Crosshair_lootall_64:16:16|a Drop\n"
    .. "|A:hearthsteel-icon-32x32:16:16|a Battle.net Shop"
L["desc_accessibility_glow"] = "Add a colored border glow to Housing Catalog items: green for owned, yellow for items you can get, and red for items that are locked behind requirements you haven't met yet."
L["desc_owned_item_style"] = "Choose how collected items look in the Housing Catalog. Green highlight shows the default glow, Dimmed fades them out, and Checkmark adds a small green check. Pick None to leave them untouched."
L["desc_enable_tooltips"] = "Add Homestead information to item tooltips when you hover over decor items. Turning this off removes all tooltip additions."
L["desc_show_ownership"] = "Add a line to tooltips showing whether you've already collected a decor item."
L["desc_show_source"] = "Show how to obtain a decor item — vendors, quests, achievements, professions, events, and drops."
L["desc_show_requirements"] = "Display purchase requirements like reputation, quest completion, or achievements needed to buy an item."
L["desc_show_all_sources"] = "List every known way to obtain an item instead of just the best available source. Helpful when an item can be acquired from multiple vendors, quests, or other sources."
L["desc_vendor_details"] = "Show a vendor's full inventory and your collection progress when hovering over their map pin. Disable for a simpler tooltip with just the vendor name."
L["desc_vendor_pin_item_details"] = "Show each item's alternative-source icons and vendor cost, plus a vendor-only item count, on map-pin tooltips. Disable for a simpler tooltip listing just item names."
L["desc_show_map_pins"] = "Show vendor locations on the world map"
L["desc_show_map_side_panel"] = "Show a side panel on the world map listing vendors and collection progress for the current zone"
L["desc_source_filter"] = "Filter side-panel item counts and expanded grids by acquisition source. Vendor visibility on the map is unchanged."
L["desc_integrate_map_border"] = "Merge the panel's top border with the world map border for a seamless look. Disable if you use a custom UI (ElvUI, GW2, etc.) that conflicts."
L["desc_zone_badges"] = "Show per-zone vendor counts spread across continents on the world map, instead of a single total per continent."
L["desc_world_pin_size"] = "Adjust the size of vendor pins on the world map. Default (20) matches Blizzard POI icons."
L["desc_show_pin_counts"] = "Display collected/total item counts on vendor pins (e.g., 3/12). Disable to reduce map clutter."
L["desc_show_minimap_pins"] = "Show vendor locations on the minimap with elevation arrows"
L["desc_elevation_arrows"] = "Show directional arrows on minimap pins when a vendor is above or below you"
L["desc_cross_zone_mode"] = "Controls cross-zone minimap pins. Auto reduces extra pins in dense city zones for smoother movement."
L["desc_minimap_pin_size"] = "Adjust the size of vendor pins on the minimap. Increase if pins are hard to see, or decrease to reduce minimap clutter."
L["desc_waypoint_info"] = "TomTom shows a directional arrow overlay and requires the TomTom addon to be installed. Native adds a destination pin to the world map. Both can be active at the same time."
L["desc_use_tomtom"] = "Use TomTom addon for waypoint arrows (if installed)"
L["desc_use_native_waypoints"] = "Use WoW's built-in waypoint system with map pin"
L["desc_auto_waypoint"] = "Automatically create a waypoint when clicking on a vendor in the list or map"
L["desc_navigate_modifier"] = "Hold this key when clicking to create a waypoint (if auto-waypoint is off)"
L["desc_milestone_xp"] = "Display next milestone XP progress on Blizzard's Housing Dashboard Endeavors tab. Disable if you use another addon for this (e.g., Endeavor Simple Progress Tracker)."
L["desc_export"] = "Export scanned vendor data for backup."
L["desc_export_new"] = "Exports vendors scanned since your last export. Includes price, currencies, faction, and catalog info."
L["desc_export_all"] = "Exports all scanned vendors, bypassing the timestamp filter."

-------------------------------------------------------------------------------
-- Options - Select Values
-------------------------------------------------------------------------------
-- Pin colors
L["Default (Gold)"] = "Default (Gold)"
L["Bright Green"] = "Bright Green"
L["Ice Blue"] = "Ice Blue"
L["Light Blue"] = "Light Blue"
L["Purple"] = "Purple"
L["Pink"] = "Pink"
L["Red"] = "Red"
L["Cyan"] = "Cyan"
L["White"] = "White"
L["Yellow"] = "Yellow"
L["Custom..."] = "Custom..."

-- Icon anchor positions
L["Top Left"] = "Top Left"
L["Top Right"] = "Top Right"
L["Bottom Left"] = "Bottom Left"
L["Bottom Right"] = "Bottom Right"
L["Center"] = "Center"

-- Owned item styles
L["Green highlight (default)"] = "Green highlight (default)"
L["None"] = "None"
L["Dimmed"] = "Dimmed"
L["Checkmark"] = "Checkmark"

-- Source filter
L["All sources"] = "All sources"

-- Minimap cross-zone mode
L["Auto (recommended)"] = "Auto (recommended)"
L["Current zone only"] = "Current zone only"
L["Always show nearby zones"] = "Always show nearby zones"

-- Navigate modifier
L["Shift"] = SHIFT_KEY_TEXT or "SHIFT"
L["Control"] = CTRL_KEY_TEXT or "CTRL"
L["Alt"] = ALT_KEY_TEXT or "ALT"
L["None (always)"] = "None (always)"

-- Misc
L["Approximate map appearance"] = "Approximate map appearance"
L["ExportImport not available."] = "ExportImport not available."

-------------------------------------------------------------------------------
-- Decor Browser: data adapter
-------------------------------------------------------------------------------
L["Alliance"] = FACTION_ALLIANCE or "Alliance"
L["Horde"] = FACTION_HORDE or "Horde"
L["Gold"] = "Gold" -- untranslated
L["Unknown"] = "Unknown"
L["Required"] = "Required"
L["Unknown faction"] = "Unknown faction"
L["Other requirement"] = "Other requirement"
L["Source unknown"] = "Source unknown"
L["Item %d"] = "Item %d" -- untranslated
L["%s %s"] = "%s %s" -- untranslated
L["%s, %s"] = "%s, %s" -- untranslated
L["%s - %s"] = "%s - %s" -- untranslated
L["%s (%s)"] = "%s (%s)" -- untranslated
L["%s: %s"] = "%s: %s" -- untranslated
L["%s with %s"] = "%s with %s"
L["Level %s"] = "Level %s"
L["Achievement: %s"] = "Achievement: %s"
L["Quest: %s"] = "Quest: %s" -- untranslated
L["Promotion: %s"] = "Promotion: %s"
L["Profession: %s"] = "Profession: %s"
L["Profession: %s rank %s"] = "Profession: %s rank %s"
L["Vendor: %s"] = "Vendor: %s"
L["Vendor: %s, %s"] = "Vendor: %s, %s"
L["Crafted: %s - %s"] = "Crafted: %s - %s"
L["Drops from %s"] = "Drops from %s"
L["Drops from %s (%s)"] = "Drops from %s (%s)"
L["Event: %s"] = "Event: %s"
L["Event: %s - %s"] = "Event: %s - %s"
L["Other source"] = "Other source"

-------------------------------------------------------------------------------
-- Decor Browser: visuals and widgets
-------------------------------------------------------------------------------
L["Owned"] = "Owned"
L["Unlocked to buy"] = "Unlocked to buy"
L["Locked"] = "Locked"
L["Set waypoint"] = "Set waypoint"

-------------------------------------------------------------------------------
-- Decor Browser: window and navigation
-------------------------------------------------------------------------------
L["Homestead Decor"] = "Homestead Decor"
L["Summary"] = "Summary"
L["Catalog"] = "Catalog"
L["Sources"] = "Sources"
L["Help"] = "Help"
L["Hide what doesn't apply to me"] = "Hide what doesn't apply to me"
L["The Decor Browser opens once Homestead has finished loading."] = "The Decor Browser opens once Homestead has finished loading."
L["Collection"] = "Collection" -- untranslated
L["Placed"] = "Placed"
L["In storage"] = "In storage"
L["Not yet redeemed"] = "Not yet redeemed"
L["Counts not loaded yet"] = "Counts not loaded yet"
L["Source"] = "Source" -- untranslated
L["Price"] = "Price"

-------------------------------------------------------------------------------
-- Decor Browser: shop and item pages
-------------------------------------------------------------------------------
L[", "] = ", " -- untranslated
L["Seasonal: %s"] = "Seasonal: %s"
L["Rotates with the %s Endeavor"] = "Rotates with the %s Endeavor"
L["Rotates with neighborhood Endeavors"] = "Rotates with neighborhood Endeavors"
L["You own this."] = "You own this."
L["Not available to you yet."] = "Not available to you yet."
L["Ownership cannot be read for this kind of item."] = "Ownership cannot be read for this kind of item."
L["Ownership is not known yet."] = "Ownership is not known yet."
L["Met: %s"] = "Met: %s"
L["Needs: %s"] = "Needs: %s"
L["Unknown: %s"] = "Unknown: %s"
L["Status"] = "Status" -- untranslated
L["Requirement"] = "Requirement"
L["Sold by"] = "Sold by"
L["Not listed"] = "Not listed"
L["Not sold by a vendor"] = "Not sold by a vendor"
L["+%d more vendors"] = "+%d more vendors"
L["+%d more sources"] = "+%d more sources"
L["Also available from"] = "Also available from"
L["No other sources on record."] = "No other sources on record."
L["Not available in combat"] = "Not available in combat"
L["Report a data error"] = "Report a data error"
L["Item: %s (%d)"] = "Item: %s (%d)" -- untranslated
L["Record ID: %s"] = "Record ID: %s"
L["none"] = "none"
L["no location"] = "no location"
L["map %d at %.1f, %.1f"] = "map %d at %.1f, %.1f"
L["Vendor %d: %s, %s, %s"] = "Vendor %d: %s, %s, %s"
L["Client: %s (%s)"] = "Client: %s (%s)" -- untranslated
L["Homestead: %s"] = "Homestead: %s" -- untranslated

-------------------------------------------------------------------------------
-- Decor Browser: entry points
-------------------------------------------------------------------------------
L["Toggle Decor Browser"] = "Toggle Decor Browser"
L["Open the Decor Browser, or bind a key under Keybindings > Homestead"] = "Open the Decor Browser, or bind a key under Keybindings > Homestead"
L["Minimap button"] = "Minimap button"
L["Left-click opens the Decor Browser, right-click opens options"] = "Left-click opens the Decor Browser, right-click opens options"

-------------------------------------------------------------------------------
-- Welcome window
-------------------------------------------------------------------------------
L["Find every decor vendor on your map and see what you own before you buy."] = "Find every decor vendor on your map and see what you own before you buy."
L["What Homestead Does"] = "What Homestead Does"
L["Every decor vendor pinned on your world map and minimap, with badges showing how many items you still need per zone."] = "Every decor vendor pinned on your world map and minimap, with badges showing how many items you still need per zone."
L["Map Side Panel"] = "Map Side Panel"
L["Click the Homestead button on the world map to open the side panel listing that zone's vendors, then click any vendor to browse their wares and see what you still need. Pop it out as a standalone window with |cFF00FF00/hs panel|r."] = "Click the Homestead button on the world map to open the side panel listing that zone's vendors, then click any vendor to browse their wares and see what you still need. Pop it out as a standalone window with |cFF00FF00/hs panel|r."
L["Tooltips Expanded"] = "Tooltips Expanded"
L["Every item in the Housing Catalog gets tooltips showing where it comes from (vendor, quest, achievement, profession, or drop), what it costs, and what you need to unlock it, so you never have to leave the game to look something up."] = "Every item in the Housing Catalog gets tooltips showing where it comes from (vendor, quest, achievement, profession, or drop), what it costs, and what you need to unlock it, so you never have to leave the game to look something up."
L["Key Commands"] = "Key Commands"
L["Export everything you've scanned"] = "Export everything you've scanned"
L["Show all commands"] = "Show all commands"
L["Found a Problem?"] = "Found a Problem?"
L["Report bugs or wrong vendor info on GitHub using the link below."] = "Report bugs or wrong vendor info on GitHub using the link below."
L["Report issues (GitHub):"] = "Report issues (GitHub):"
L["CurseForge:"] = "CurseForge:" -- untranslated
L["Don't show this again"] = "Don't show this again"
L["Let's Decorate!"] = "Let's Decorate!"

-------------------------------------------------------------------------------
-- Decor Browser: source and vendor labels
-------------------------------------------------------------------------------
L["Achievements"] = "Achievements"
L["Quests"] = "Quests" -- untranslated
L["Professions"] = "Professions"
L["Drops"] = "Drops"
L["Events"] = "Events"
L["Other"] = "Other"
L["Location not recorded"] = "Location not recorded"
L["Requires"] = "Requires"

-------------------------------------------------------------------------------
-- Decor Browser: holiday vendors
-------------------------------------------------------------------------------
L["The Decor Browser is not available yet."] = "The Decor Browser is not available yet."

-------------------------------------------------------------------------------
-- Decor Browser: states and shared parts
-------------------------------------------------------------------------------
L["First-Time Collection Bonus"] = HOUSING_CATALOG_FILTERS_FIRST_ACQUISITION or "First-Time Collection Bonus"
L["First-Time Collection Bonus Available"] = HOUSING_DECOR_FIRST_ACQUISITION_AVAILABLE or "First-Time Collection Bonus Available"
L["Collected"] = "Collected"
L["Can get now"] = "Can get now"
L["Requires: %s"] = "Requires: %s"
L["%s only"] = "%s only"
L["Not collected"] = "Not collected"
L["Counting…"] = "Counting…"
L["Not confirmed"] = "Not confirmed"
L["Active now"] = "Active now"
L["Best to get now"] = "Best to get now"
L["Search decor by name"] = "Search decor by name"
L["Reset filters"] = "Reset filters"
L["Search all decor"] = "Search all decor"
L["Show what's missing"] = "Show what's missing"
L["Sort by name"] = "Sort by name"
L["Show them"] = "Show them"
L["Show vendor"] = "Show vendor"
L["Report a problem"] = "Report a problem"
L["Reading your collection. This list fills in when it's ready."] = "Reading your collection. This list fills in when it's ready."
L["Reading your collection. This list fills in when it's ready, because Best to get now depends on what you own."] = "Reading your collection. This list fills in when it's ready, because Best to get now depends on what you own."
L["Nothing missing"] = "Nothing missing"
L["You've collected all %d decor Homestead knows about."] = "You've collected all %d decor Homestead knows about."
L["Nothing you can get right now"] = "Nothing you can get right now"
L["Everything you're missing needs a reputation, achievement or quest first, is sold only during an event, or is sold only to the %s."] = "Everything you're missing needs a reputation, achievement or quest first, is sold only during an event, or is sold only to the %s."
L["Collection not read yet"] = "Collection not read yet"
L["Homestead hasn't read this character's decor collection yet, so it can't tell what you're missing. It reads it shortly after you log in. If this message stays, open the Housing Dashboard once."] = "Homestead hasn't read this character's decor collection yet, so it can't tell what you're missing. It reads it shortly after you log in. If this message stays, open the Housing Dashboard once."
L["These filters need your collection, which Homestead hasn't read yet. If this stays, open the Housing Dashboard once."] = "These filters need your collection, which Homestead hasn't read yet. If this stays, open the Housing Dashboard once."
L["No results"] = "No results"
L["No decor matches these words and filters. Search looks at item names only."] = "No decor matches these words and filters. Search looks at item names only."
L["%d hidden by '%s' (%d collected, %d %s only)."] = "%d hidden by '%s' (%d collected, %d %s only)."

-------------------------------------------------------------------------------
-- Decor Browser: Summary
-------------------------------------------------------------------------------
-- end: Summary

-------------------------------------------------------------------------------
-- Decor Browser: Catalog
-------------------------------------------------------------------------------
-- end: Catalog

-------------------------------------------------------------------------------
-- Decor Browser: Sources
-------------------------------------------------------------------------------
L["Search vendors and zones"] = "Search vendors and zones"
L["Search achievements"] = "Search achievements"
L["Search quests"] = "Search quests"
L["Search recipes and professions"] = "Search recipes and professions"
L["Search drops and zones"] = "Search drops and zones"
L["Search events"] = "Search events"
L["Search the Shop"] = "Search the Shop"
L["Here in %s"] = "Here in %s"
L["%d of %d"] = "%d of %d"
L["%d decor"] = "%d decor"
L["No decor"] = "No decor"
L["Not active"] = "Not active"
L["All collected"] = "All collected"
L["%d can get now"] = "%d can get now"
L["Holiday event"] = "Holiday event"
L["%s only: can't buy on this character"] = "%s only: can't buy on this character"
L["%s vendor"] = "%s vendor"
L["Confirmed by a scan on %s"] = "Confirmed by a scan on %s"
L["No scan has confirmed this vendor yet. Visit the vendor to check."] = "No scan has confirmed this vendor yet. Visit the vendor to check."
L["Sells %d decor."] = "Sells %d decor."
L["Gives %d decor."] = "Gives %d decor."
L["You have %d."] = "You have %d."
L["%d you can get now."] = "%d you can get now."
L["Decor sold here"] = "Decor sold here"
L["Decor from this source"] = "Decor from this source"
L["No decor is recorded here. If this source gives decor, report it below."] = "No decor is recorded here. If this source gives decor, report it below."
L["Pick a source to see its decor."] = "Pick a source to see its decor."
L["Quest starts in %s"] = "Quest starts in %s"
L["Dig site in %s"] = "Dig site in %s"
L["No model shown"] = "No model shown"
L["No events active right now. Event decor is sold only while its event runs."] = "No events active right now. Event decor is sold only while its event runs."
L["Nothing matches your search."] = "Nothing matches your search."
L["Nothing to show here."] = "Nothing to show here."
-- end: Sources

-------------------------------------------------------------------------------
-- Decor Browser: Item
-------------------------------------------------------------------------------
-- end: Item
