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

-- Vendor cost: joins alternative ways to pay ("30 coupons or 500 gold")
L["or"] = "or"

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
L["Collection Markers"] = "Collection Markers"
L["Tooltips"] = "Tooltips" -- untranslated

L["Show Minimap Button"] = "Show Minimap Button"
L["Show Collection Markers"] = "Show Collection Markers"
L["Show on Bags"] = "Show on Bags"
L["Show on Bank"] = "Show on Bank"
L["Show on Vendors"] = "Show on Vendors"
L["Show on Housing Catalog"] = "Show on Housing Catalog"
L["Marker Size"] = "Marker Size"
L["Marker Position"] = "Marker Position"
L["Show Opposite Faction Vendors"] = "Show Opposite Faction Vendors"

L["Enable Tooltip Additions"] = "Enable Tooltip Additions"
L["Show Source Information"] = "Show Source Information"
L["Show Vendor Details"] = "Show Vendor Details"

L["Show Map Pins"] = "Show Map Pins"
L["Show Minimap Pins"] = "Show Minimap Pins"
L["Use TomTom for Waypoints"] = "Use TomTom for Waypoints"
L["Use Built-In Waypoints"] = "Use Built-In Waypoints"
L["Auto-Create Waypoints"] = "Auto-Create Waypoints"
L["Waypoint Key"] = "Waypoint Key"

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d/%d"] = "Collection: %d/%d"
L["Vendors nearby: %d"] = "Vendors nearby: %d"
L["Vendors scanned: %d"] = "Vendors scanned: %d"
L["Left-Click: Toggle Homestead Hub"] = "|cFFFFFFFFLeft-Click:|r Toggle Homestead Hub"
L["Toggle options"] = "Toggle options"
L["Left-Click: Toggle options"] = "|cFFFFFFFFLeft-Click:|r Toggle options"
L["Right-Click: Toggle Homestead Panel in Own Window"] = "|cFFFFFFFFRight-Click:|r Toggle Homestead Panel in Own Window"
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
L["Show Pin Decor Details"] = "Show Pin Decor Details"

L["Auto-Scan Vendors"] = "Auto-Scan Vendors"
L["Vendor Visibility"] = "Vendor Visibility"
L["Show Holiday Vendors"] = "Show Holiday Vendors"
-- World map filter menu checkbox (SHOW semantics, inverse of the panel row above)
L["Show Fully-Collected Vendors"] = "Show Fully-Collected Vendors"
L["desc_map_filter_completed_vendors"] = "Shows pins for vendors whose decor you have fully collected. If you turn it off, those pins are hidden on the world map and minimap. The Homestead Panel still lists them."
L["Pin Appearance"] = "Pin Appearance"
L["Pin Color"] = "Pin Color"
L["Custom Color"] = "Custom Color"
L["Show Accessibility Glow"] = "Show Accessibility Glow"
L["Collected Decor Style"] = "Collected Decor Style"
L["Show Collection Status"] = "Show Collection Status"
L["Show Requirements"] = "Show Requirements"
L["Show All Sources"] = "Show All Sources"
L["Map Pins"] = "Map Pins"
L["World Map"] = WORLDMAP_BUTTON or "World Map"
L["Show Homestead Panel"] = "Show Homestead Panel"
L["Decor Source Filter"] = "Decor Source Filter"
L["Join Panel to Map"] = "Join Panel to Map"
L["World Map Zone Badges"] = "World Map Zone Badges"
L["World Map Pin Size"] = "World Map Pin Size"
L["Show Collection Counts"] = "Show Collection Counts"
L["Minimap"] = MINIMAP_LABEL or "Minimap"
L["Show Elevation Arrows"] = "Show Elevation Arrows"
L["Minimap Nearby-Zone Pins"] = "Minimap Nearby-Zone Pins"
L["Minimap Pin Size"] = "Minimap Pin Size"
L["Waypoints"] = "Waypoints"
L["Endeavors"] = HOUSING_DASHBOARD_ENDEAVOR or "Endeavors"
L["Show Milestone Progress"] = "Show Milestone Progress"
L["Inventory"] = "Inventory"
L["Housing Catalog"] = "Housing Catalog"

-------------------------------------------------------------------------------
-- Options - Descriptions
-------------------------------------------------------------------------------
L["desc_minimap_button"] = "Shows the Homestead button on your minimap. If you hide it, type /hs to open Homestead."
L["desc_auto_scan_vendors"] = "Scans a vendor's wares for housing decor when you open their window, so prices and stock stay current. Turning it off may slightly speed up opening vendor windows."
L["desc_options_general"] = "Core addon behavior, minimap access, vendor scanning, and map pin appearance."
L["desc_options_overlays"] = "Collection markers shown on bags, the bank, vendors, and the Housing Catalog."
L["desc_options_tooltips"] = "Extra collection, source, requirement, and vendor details added to item and map-pin tooltips."
L["desc_options_world_map"] = "World map vendor pins, zone badges, the Homestead Panel, and map pin display."
L["desc_options_minimap"] = "Nearby vendor pins, elevation arrows, and waypoint behavior on the minimap."
L["desc_options_endeavors"] = "Housing Endeavor progress shown on Blizzard's Housing Dashboard."
L["desc_vendor_visibility_section"] = "Choose which vendor groups appear on maps and in collection totals."
L["desc_pin_appearance_section"] = "Adjust the color and preview for Homestead vendor pins."
L["desc_overlay_inventory_section"] = "Show collection markers on item slots outside the Housing Catalog."
L["desc_overlay_merchant_section"] = "Mark collected decor in vendor windows."
L["desc_overlay_catalog_section"] = "Choose how markers, highlights, and collected decor look in the Housing Catalog."
L["desc_tooltip_map_pins_section"] = "Choose how much vendor detail appears on map-pin tooltips."
L["desc_minimap_waypoints_section"] = "Choose how Homestead sets a waypoint when you click a vendor pin."
L["desc_opposite_faction"] = "Shows vendors that sell only to the opposite faction, marked with that faction's emblem, on your maps and in the Homestead Panel."
L["desc_event_vendors"] = "Shows holiday vendors on your maps and in the Homestead Panel."
L["desc_pin_color"] = "Sets the color of Homestead pins on the world map and minimap."
L["desc_custom_color"] = "Sets your own color for Homestead pins. Only shown while Pin Color is Custom."
L["desc_enable_overlays"] = "Adds small markers and highlights to decor throughout the game so you can tell which ones you have collected. If you turn it off, markers on bags, the bank, vendors, and the Housing Catalog are hidden."
L["desc_icon_size"] = "Sets how large collection markers appear on item slots. Lower is smaller; higher is larger. Housing Catalog markers do not change."
L["desc_icon_position"] = "Sets where on the item slot the collection marker sits. Housing Catalog markers do not change."
L["desc_show_on_bags"] = "Adds a |A:homestone-minimap-icon:16:16|a to decor in your bags, colored to show whether you have collected it. Works with the default bags, Baganator, and BetterBags. Only works while Show Collection Markers is on."
L["desc_show_on_bank"] = "Marks decor in your bank so you can see which ones you have collected. Only works while Show Collection Markers is on."
L["desc_show_on_merchant"] = "Adds a |A:homestone-minimap-icon:16:16|a to decor in vendor windows, colored to show whether you have collected it. Only works while Show Collection Markers is on."
L["desc_show_on_housing_catalog"] = "Marks decor in the Housing Catalog with a marker showing where it comes from. Only works while Show Collection Markers is on.\n\n"
    .. "|A:auctionhouse-icon-coin-gold:16:16|a Vendor\n"
    .. "|A:QuestNormal:16:16|a Quest\n"
    .. "|A:UI-Achievement-Shield-NoPoints:16:16|a Achievement\n"
    .. "|A:UI-HUD-MicroMenu-Professions-Mouseover:16:16|a Profession\n"
    .. "|A:UI-HUD-Calendar-1-Up:16:16|a Event\n"
    .. "|A:Crosshair_lootall_64:16:16|a Drop\n"
    .. "|A:hearthsteel-icon-32x32:16:16|a In-Game Shop"
L["desc_accessibility_glow"] = "Adds a border glow to Housing Catalog decor: green for collected, yellow for decor you can get, red for locked. Only works while Show Collection Markers is on."
L["desc_owned_item_style"] = "Sets how collected decor looks in the Housing Catalog. Green Highlight keeps the green glow, Dimmed fades the decor, Checkmark adds a green check, and None leaves it plain."
L["desc_enable_tooltips"] = "Adds Homestead details to decor tooltips. If you turn it off, Homestead adds nothing to item tooltips."
L["desc_show_ownership"] = "Adds a Status line to decor tooltips showing whether you have collected it and whether you can get it. Only works while Enable Tooltip Additions is on."
L["desc_show_source"] = "Shows where decor comes from: vendors, quests, achievements, professions, events, and drops. Only works while Enable Tooltip Additions is on."
L["desc_show_requirements"] = "Shows what you need before you can buy decor, such as a reputation, a quest, or an achievement. Only works while Enable Tooltip Additions is on."
L["desc_show_all_sources"] = "Lists every known way to get decor instead of only the best one. Only works while Enable Tooltip Additions is on."
L["desc_vendor_details"] = "Show a vendor's full inventory and your collection progress when hovering over their map pin. Disable for a simpler tooltip with just the vendor name."
L["desc_vendor_pin_item_details"] = "Shows each decor's other-source icons and price on vendor pin tooltips. If you turn it off, the tooltip lists names only."
L["desc_show_map_pins"] = "Shows vendor locations on the world map."
L["desc_show_map_side_panel"] = "Shows the Homestead Panel beside the world map, listing vendors and your collection progress for the zone you are viewing."
L["desc_source_filter"] = "Sets which sources of decor the Homestead Panel counts and lists. World map pins and zone badges follow the same choice. Minimap pins do not change."
L["desc_integrate_map_border"] = "Joins the top edge of the Homestead Panel to the world map's border. Turn it off if another interface addon changes the map and the two overlap."
L["desc_zone_badges"] = "Shows a vendor count for each zone on the world map view. If you turn it off, each continent shows one total."
L["desc_world_pin_size"] = "Sets the size of vendor pins on the world map. Lower is smaller; higher is larger."
L["desc_show_pin_counts"] = "Shows collected and total decor on each vendor pin, such as 3/12. Turn it off for a less crowded map."
L["desc_show_minimap_pins"] = "Shows vendor locations on the minimap."
L["desc_elevation_arrows"] = "Shows an arrow on a minimap pin when the vendor is above or below you. Only works while Show Minimap Pins is on."
L["desc_cross_zone_mode"] = "Sets whether the minimap also shows vendors from nearby zones. Auto shows them except indoors and in crowded zones, Current Zone Only never shows them, and Nearby Zones always shows them."
L["desc_minimap_pin_size"] = "Sets the size of vendor pins on the minimap. Lower is smaller; higher is larger."
L["desc_waypoint_info"] = "TomTom shows a directional arrow and needs the TomTom addon installed. Built-in waypoints add a destination pin to the world map. Both can be on at the same time."
L["desc_use_tomtom"] = "Sets a TomTom arrow when Homestead creates a waypoint. Only works while the TomTom addon is installed."
L["desc_use_native_waypoints"] = "Sets the game's own waypoint and adds a destination pin to the world map when Homestead creates a waypoint."
L["desc_auto_waypoint"] = "Automatically create a waypoint when clicking on a vendor in the list or map."
L["desc_navigate_modifier"] = "Hold this key when clicking to create a waypoint (if auto-waypoint is off)."
L["desc_milestone_xp"] = "Shows your next Endeavor milestone and the vendor's collection progress on the Endeavors tab of Blizzard's Housing Dashboard. Turn it off if another addon already shows this."

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
L["Green Highlight"] = "Green Highlight"
L["None"] = "None"
L["Dimmed"] = "Dimmed"
L["Checkmark"] = "Checkmark"

-- Source filter
L["All Sources"] = "All Sources"

-- Minimap cross-zone mode
L["Auto"] = "Auto"
L["Current Zone Only"] = "Current Zone Only"
L["Nearby Zones"] = "Nearby Zones"

-- Navigate modifier
L["Shift"] = SHIFT_KEY_TEXT or "SHIFT"
L["Control"] = CTRL_KEY_TEXT or "CTRL"
L["Alt"] = ALT_KEY_TEXT or "ALT"
L["None (always)"] = "None (always)"

-- Misc
L["Approximate Map Appearance"] = "Approximate Map Appearance"
L["Catalog scan is on cooldown. Try again in a few seconds."] = "Catalog scan is on cooldown. Try again in a few seconds."
L["A catalog scan is already in progress."] = "A catalog scan is already in progress."

-------------------------------------------------------------------------------
-- Decor Browser: data adapter
-------------------------------------------------------------------------------
L["Alliance"] = FACTION_ALLIANCE or "Alliance"
L["Horde"] = FACTION_HORDE or "Horde"
L["Unknown"] = "Unknown"
L["A vendor"] = "A vendor"
L["Required"] = "Required"
L["Unknown faction"] = "Unknown faction"
L["This Character"] = "This Character"
L["Account"] = ACCOUNT_QUEST_LABEL or "Warband"
L["Completed"] = CRITERIA_COMPLETED or "Completed"
L["Incomplete"] = INCOMPLETE or "Incomplete"
L["Not Your Profession"] = "Not Your Profession"
L["Skill Too Low"] = "Skill Too Low"
L["Recipe Known"] = "Recipe Known"
L["Recipe Unknown"] = "Recipe Unknown"
L["Other requirement"] = "Other requirement"
L["Source unknown"] = "Source unknown"
L["Item %d"] = "Item %d" -- untranslated
L["%s %s"] = "%s %s" -- untranslated
L["%s, %s"] = "%s, %s" -- untranslated
L["%s: %s"] = "%s: %s" -- untranslated
L["%s with %s"] = "%s with %s"
L["Renown Rank %d with %s"] = "Renown Rank %d with %s"
L["Level %s"] = "Level %s"
L["Achievement: %s"] = "Achievement: %s"
L["Quest: %s"] = "Quest: %s" -- untranslated
L["Promotion: %s"] = "Promotion: %s"
L["Profession: %s"] = "Profession: %s"
L["Profession: %s rank %s"] = "Profession: %s rank %s"
L["Profession requirement"] = "Profession requirement"
L["Profession rank requirement"] = "Profession rank requirement"
L["Purchase gated"] = "Purchase gated"
L["Vendor: %s"] = "Vendor: %s"
L["Vendor: %s, %s"] = "Vendor: %s, %s"
L["Crafted: %s - %s"] = "Crafted: %s - %s"
L["Drops from %s"] = "Drops from %s"
L["Drops from %s (%s)"] = "Drops from %s (%s)"
L["Event: %s"] = "Event: %s"
L["Event: %s - %s"] = "Event: %s - %s"
L["Other source"] = "Other source"
L["%s / %s"] = "%s / %s" -- untranslated
L["Requires %s"] = "Requires %s"
L["%s (%s)"] = "%s (%s)" -- untranslated
L["%s (until %s)"] = "%s (until %s)"
L["Shop: %s"] = "Shop: %s"
L["Twitch Drop"] = "Twitch Drop"
L["Charity Pack"] = "Charity Pack"
L["Promotion"] = "Promotion" -- untranslated
L["Not currently sold"] = "Not currently sold" -- untranslated

-------------------------------------------------------------------------------
-- Tooltip: shared Homestead block
-------------------------------------------------------------------------------
L["Zone:"] = ZONE_COLON or "Zone:"
L["Location:"] = LOCATION_COLON or "Location:"
L["Source:"] = "Source:"
L["Faction:"] = "Faction:"
L["Status:"] = "Status:" -- untranslated
L["Available"] = "Available"
L["Locked"] = "Locked"
L["Not Collected"] = "Not Collected"
L["Opposite faction only"] = "Opposite faction only"
L["Vendor Price:"] = "Vendor Price:"
L["Shop Price:"] = "Shop Price:"
L["Pack:"] = "Pack:"
L["Currency:"] = "Currency:"
L["Available until:"] = "Available until:"
L["In-Game Shop"] = "In-Game Shop"
L["N/A"] = "N/A"
L["Unknown Vendor"] = "Unknown Vendor"
L["Unknown Location"] = "Unknown Location"
L["Unknown Quest"] = "Unknown Quest"
L["Unknown Achievement"] = "Unknown Achievement"
L["Unknown Recipe"] = "Unknown Recipe"
L["Unknown Event"] = "Unknown Event"
L["Holiday Vendor"] = "Holiday Vendor"
L["Unknown Promotion"] = "Unknown Promotion"
L["Active Now"] = "Active Now"
L["Not Active"] = "Not Active"
L["Your renown: %s / %s"] = "Your renown: %s / %s"
L["Your standing: %s / %s"] = "Your standing: %s / %s"
L["Your %s: %s"] = "Your %s: %s"
L["Completing this grants one copy; price applies to additional copies"] = "Completing this grants one copy; price applies to additional copies"
L["No longer obtainable"] = "No longer obtainable"
L["Promotion reward: %s"] = "Promotion reward: %s"
L["Promotion reward: %s, through %s"] = "Promotion reward: %s, through %s"
L["Vendor access: Opposite-faction vendor on this character"] = "Vendor access: Opposite-faction vendor on this character"
L["Hold Shift for details"] = "Hold Shift for details"
L["Not yet mapped by Homestead"] = "Not yet mapped by Homestead"

-------------------------------------------------------------------------------
-- Decor Browser: visuals and widgets
-------------------------------------------------------------------------------
L["Set waypoint"] = "Set waypoint"

-------------------------------------------------------------------------------
-- Decor Browser: window and navigation
-------------------------------------------------------------------------------
L["Homestead Hub"] = "Homestead Hub" -- untranslated
L["Overview"] = "Overview"
L["Decor"] = "Decor"
L["Back"] = "Back"
L["Other Vendors"] = "Other Vendors"
L["Collected: %d/%d"] = "Collected: %d/%d"
L["Completed: %d/%d"] = "Completed: %d/%d"
L["Reagents"] = "Reagents"
L["%d needed"] = "%d needed"
L["Help"] = "Help"
L["Hide Collected and Opposite Faction"] = "Hide Collected and Opposite Faction"
L["Hides decor you have collected, vendors with nothing left to collect, and anything only the opposite faction can get."] = "Hides decor you have collected, vendors with nothing left to collect, and anything only the opposite faction can get."
L["Opens a page explaining this window."] = "Opens a page explaining this window."
L["The Homestead Hub opens once Homestead has finished loading."] = "The Homestead Hub opens once Homestead has finished loading."
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
L["Holiday: %s"] = "Holiday: %s"
L["Rotates with the %s Endeavor"] = "Rotates with the %s Endeavor"
L["Rotates with neighborhood Endeavors"] = "Rotates with neighborhood Endeavors"
L["Endeavor"] = "Endeavor"
L["Not available in combat"] = "Not available in combat"
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
L["Toggle Homestead Hub"] = "Toggle Homestead Hub"
L["Open the Homestead Hub, or bind a key under Keybindings > Homestead"] = "Open the Homestead Hub, or bind a key under Keybindings > Homestead"
L["Minimap button"] = "Minimap button"
L["Open options"] = "Open options"
L["Right-click minimap button"] = "Right-click minimap button"
L["Open the Homestead Panel in its own window"] = "Open the Homestead Panel in its own window"
L["Left-click opens the Homestead Hub, right-click opens options"] = "Left-click opens the Homestead Hub, right-click opens options"
L["The Homestead Hub is not available yet."] = "The Homestead Hub is not available yet."

-------------------------------------------------------------------------------
-- Welcome window
-------------------------------------------------------------------------------
L["Find every decor vendor on your map and see what you've collected before you buy."] = "Find every decor vendor on your map and see what you've collected before you buy."
L["What Homestead Does"] = "What Homestead Does"
L["Every decor vendor pinned on your world map and minimap, with badges showing how much decor you still need per zone."] = "Every decor vendor pinned on your world map and minimap, with badges showing how much decor you still need per zone."
L["Homestead Panel"] = "Homestead Panel"
L["Click the Homestead button on the world map to open the Homestead Panel listing that zone's vendors, then click any vendor to browse their wares and see what you still need. Open it in its own window with |cFF00FF00/hs panel|r."] = "Click the Homestead button on the world map to open the Homestead Panel listing that zone's vendors, then click any vendor to browse their wares and see what you still need. Open it in its own window with |cFF00FF00/hs panel|r."
L["Tooltips Expanded"] = "Tooltips Expanded"
L["All decor in the Housing Catalog gets tooltips showing where it comes from (vendor, quest, achievement, profession, or drop), what its price is, and what you need to unlock it, so you never have to leave the game to look something up."] = "All decor in the Housing Catalog gets tooltips showing where it comes from (vendor, quest, achievement, profession, or drop), what its price is, and what you need to unlock it, so you never have to leave the game to look something up."
L["Key Commands"] = "Key Commands"
L["Show all commands"] = "Show all commands"
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
L["Location unknown"] = "Location unknown"
L["Requires"] = "Requires"

-------------------------------------------------------------------------------
-- Decor Browser: states and shared parts
-------------------------------------------------------------------------------
L["Collection Bonus"] = HOUSING_CATALOG_FILTERS_FIRST_ACQUISITION or "Collection Bonus"
L["First-Time Collection Bonus Available"] = HOUSING_DECOR_FIRST_ACQUISITION_AVAILABLE or "First-Time Collection Bonus Available"
L["Collected"] = "Collected"
L["Can get now"] = "Can get now"
L["Requires: %s"] = "Requires: %s"
L["Not enough: %s"] = "Not enough: %s"
L["(%1$s has %2$s)"] = "(%1$s has %2$s)"
L["Price unknown"] = "Price unknown"
L["%s only"] = "%s only"
L["Counting…"] = "Counting…"
L["Best to get now"] = "Best to get now"
L["Search decor"] = "Search decor"
L["More vendors here"] = "More vendors here"
L["Reset filters"] = "Reset filters"
L["Show what's missing"] = "Show what's missing"
L["Sort by name"] = "Sort by name"
L["Show them"] = "Show them"
L["Show vendor"] = "Show vendor"
L["Report a Problem"] = "Report a Problem"
L["Reading your collection. This list fills in when it's ready."] = "Reading your collection. This list fills in when it's ready."
L["Reading your collection. This list fills in when it's ready, because Best to get now depends on what you have collected."] = "Reading your collection. This list fills in when it's ready, because Best to get now depends on what you have collected."
L["Nothing missing"] = "Nothing missing"
L["You've collected all %d decor Homestead knows about."] = "You've collected all %d decor Homestead knows about."
L["Nothing you can get right now"] = "Nothing you can get right now"
L["Everything you're missing needs a reputation, achievement or quest first, is sold only during an event, or is sold only to the %s."] = "Everything you're missing needs a reputation, achievement or quest first, is sold only during an event, or is sold only to the %s."
L["Everything you're missing needs a reputation, achievement or quest first, or is sold only during an event."] = "Everything you're missing needs a reputation, achievement or quest first, or is sold only during an event."
L["Collection not read yet"] = "Collection not read yet"
L["Collection not refreshed this session"] = "Collection not refreshed this session"
L["Homestead hasn't read this character's decor collection yet, so it can't tell what you're missing. It reads it shortly after you log in. If this message stays, open the Housing Dashboard once."] = "Homestead hasn't read this character's decor collection yet, so it can't tell what you're missing. It reads it shortly after you log in. If this message stays, open the Housing Dashboard once."
L["These filters need your collection, which Homestead hasn't read yet. If this stays, open the Housing Dashboard once."] = "These filters need your collection, which Homestead hasn't read yet. If this stays, open the Housing Dashboard once."
L["No results"] = "No results"
L["%d hidden by '%s' (%d collected, %d %s only)."] = "%d hidden by '%s' (%d collected, %d %s only)."
L["%d hidden by '%s' (%d collected, %d %s only, %d %s only)."] = "%d hidden by '%s' (%d collected, %d %s only, %d %s only)."
L["%d hidden by '%s' (%d collected)."] = "%d hidden by '%s' (%d collected)."
L["%s or the %s"] = "%s or the %s"

-------------------------------------------------------------------------------
-- Decor Browser: Summary
-------------------------------------------------------------------------------
L["What can I get now?"] = "What can I get now?"
L["Decor this character can buy or earn today, best first."] = "Decor this character can buy or earn today, best first."
L["Can get now means this character can get it today: the right faction, no requirement left to meet, and enough gold or currency to pay. Gold-only and cheaper items come first. Use See all for the full list."] = "Can get now means this character can get it today: the right faction, no requirement left to meet, and enough gold or currency to pay. Gold-only and cheaper items come first. Use See all for the full list."
L["Show"] = "Show"
L["%s and %d more"] = "%s and %d more"
L["See all you can get now (%d)"] = "See all you can get now (%d)"
L["Sold here in %s"] = "Sold here in %s"
L["Sold on %s"] = "Sold on %s"
L["%s: Active Now"] = "%s: Active Now"
L["Gold"] = "Gold" -- untranslated
L["Gold only"] = "Gold only"
L["Gold only, no requirements left"] = "Gold only, no requirements left"
L["No requirements left"] = "No requirements left"
L["Reading your collection"] = "Reading your collection"
L["Your Collection Status"] = "Your Collection Status"
-- end: Summary

-------------------------------------------------------------------------------
-- Decor Browser: Catalog
-------------------------------------------------------------------------------
L["All decor"] = "All decor"
L["Filters"] = "Filters"
L["Name"] = "Name" -- untranslated
L["Sort: %s"] = "Sort: %s"
L["Furnishings"] = "Furnishings"
L["Structural"] = "Structural"
L["Accents"] = "Accents" -- untranslated
L["Lighting"] = "Lighting"
L["Neither collected nor not collected"] = "Neither collected nor not collected"
L["Sources: %s"] = "Sources: %s"
L["Filtered: %s"] = "Filtered: %s"
L["(+%d more)"] = "(+%d more)"
-- end: Catalog

-------------------------------------------------------------------------------
-- Decor Browser: Sources
-------------------------------------------------------------------------------
L["%d decor"] = "%d decor"
L["No decor"] = "No decor"
L["%d can get now"] = "%d can get now"
L["Holiday event"] = "Holiday event"
L["%s only: can't buy on this character"] = "%s only: can't buy on this character"
L["Confirmed by a scan on %s"] = "Confirmed by a scan on %s"
L["Decor from this source"] = "Decor from this source"
L["No decor is recorded here. If this source gives decor, report it below."] = "No decor is recorded here. If this source gives decor, report it below."
L["Dig site in %s"] = "Dig site in %s"
L["No events active right now. Event decor is sold only while its event runs."] = "No events active right now. Event decor is sold only while its event runs."
L["Nothing matches your search."] = "Nothing matches your search."
L["%d match, %s"] = "%d match, %s"
L["%d matches, %s"] = "%d matches, %s"
L["Nothing to show here."] = "Nothing to show here."
L["Collapse all"] = "Collapse all"
L["Expand all"] = "Expand all"
L["Currency"] = "Currency"
L["Wares"] = "Wares"
L["Corners: state top right, bonus top left, event bottom left, copies bottom right."] = "Corners: state top right, bonus top left, event bottom left, copies bottom right."
L["Collection unknown"] = "Collection unknown"
L["Greyed: promotion item, or collection status unknown. Not counted in totals."] = "Greyed: promotion item, or collection status unknown. Not counted in totals."
L["Tile markers"] = "Tile markers"
L["Top right"] = "Top right"
L["Top left"] = "Top left"
L["Bottom left"] = "Bottom left"
L["Bottom right"] = "Bottom right"
L["Collected: it's in your collection"] = "Collected: it's in your collection"
L["Can get now: this character can get it today"] = "Can get now: this character can get it today"
L["Not enough: this character can't pay for it yet"] = "Not enough: this character can't pay for it yet"
L["Locked: a requirement isn't met yet"] = "Locked: a requirement isn't met yet"
L["Opposite faction only: this character's faction can't get it"] = "Opposite faction only: this character's faction can't get it"
L["Event only: available while its event runs"] = "Event only: available while its event runs"
L["Its event is active now"] = "Its event is active now"
L["How many you have collected, placed and stored"] = "How many you have collected, placed and stored"
L["Left-click: details"] = "Left-click: details"
L["Right-click: open in the Housing Dashboard"] = "Right-click: open in the Housing Dashboard"
L["Right-click: Housing Dashboard unavailable in combat"] = "Right-click: Housing Dashboard unavailable in combat"
L["%s; %s"] = "%s; %s" -- untranslated
L["%s · %s"] = "%s · %s" -- untranslated
L["Map"] = WORLD_MAP or "Map"
L["Start:"] = "Start:" -- untranslated
L["Use %s"] = "Use %s"
-- end: Sources

-------------------------------------------------------------------------------
-- Decor Browser: Item
-------------------------------------------------------------------------------
L["Vendor:"] = "Vendor:"
L["Achievement:"] = "Achievement:"
L["Quest:"] = "Quest:" -- untranslated
L["Recipe:"] = "Recipe:"
L["Drop:"] = "Drop:"
L["Event:"] = "Event:"
L["Starts in %s"] = "Starts in %s"
L["Daily from The Last Architect"] = "Daily from The Last Architect"
L["Can get now here"] = "Can get now here"
L["Where to get it"] = "Where to get it"
L["Show achievement"] = "Show achievement"
L["Show quest"] = "Show quest"
L["Show recipe"] = "Show recipe"
L["Show drop"] = "Show drop"
L["Show event"] = "Show event"
L["%s (done)"] = "%s (done)"
L["%s (not yet)"] = "%s (not yet)"
L["Can't check this requirement yet"] = "Can't check this requirement yet"
L["Active Now: %s"] = "Active Now: %s"
L["Show 3D Preview"] = "Show 3D Preview"
L["desc_browser_model3d"] = "Shows a 3D model of the decor on its page in the Homestead Hub."
-- end: Item
