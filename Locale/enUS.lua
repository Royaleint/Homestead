--[[
    Homestead - Locale: English (US)
    Default localization strings
]]

local _, HA = ...

-- Initialize localization table
local L = {}
HA.L = L

-------------------------------------------------------------------------------
-- Collection Status
-------------------------------------------------------------------------------
L["Collected"] = "Collected"
L["Collected (Placed)"] = "Collected (Placed)"
L["Not Collected"] = "Not Collected"
L["Unknown"] = "Unknown"

-------------------------------------------------------------------------------
-- Source Descriptions
-------------------------------------------------------------------------------
L["Available from vendor"] = "Available from vendor"
L["Can be crafted"] = "Can be crafted"
L["Achievement reward"] = "Achievement reward"
L["World drop"] = "World drop"
L["Quest reward"] = "Quest reward"
L["Reputation reward"] = "Reputation reward"
L["Event reward"] = "Event reward"
L["Promotional item"] = "Promotional item"

-------------------------------------------------------------------------------
-- Decor Properties
-------------------------------------------------------------------------------
L["Can be dyed"] = "Can be dyed"
L["Colorable"] = "Colorable"
L["Warbound"] = "Warbound"
L["Indoor only"] = "Indoor only"
L["Outdoor only"] = "Outdoor only"
L["Quantity owned: %d"] = "Quantity owned: %d"
L["Currently placed: %d"] = "Currently placed: %d"

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["[Housing Addon]"] = "|cFF00FF00[Housing Addon]|r"
L["Source:"] = "Source:"
L["Vendor:"] = "Vendor:"
L["Location:"] = "Location:"
L["Click to set waypoint"] = "Click to set waypoint"

-------------------------------------------------------------------------------
-- UI Labels
-------------------------------------------------------------------------------
L["Housing Addon"] = "Housing Addon"
L["Decor Browser"] = "Decor Browser"
L["Vendor Tracer"] = "Vendor Tracer"
L["Color Tracker"] = "Color Tracker"
L["Export Data"] = "Export Data"
L["Options"] = "Options"
L["Search"] = "Search"
L["Filter"] = "Filter"
L["Close"] = "Close"

-------------------------------------------------------------------------------
-- Vendor Tracer
-------------------------------------------------------------------------------
L["Set Waypoint"] = "Set Waypoint"
L["Show on Map"] = "Show on Map"
L["Vendor sells %d decor items"] = "Vendor sells %d decor items"
L["You own %d/%d items"] = "You own %d/%d items"
L["Missing items:"] = "Missing items:"
L["No vendors found"] = "No vendors found"

-------------------------------------------------------------------------------
-- Color/Dye Tracker
-------------------------------------------------------------------------------
L["Dye Collection"] = "Dye Collection"
L["Owned Dyes"] = "Owned Dyes"
L["Known Recipes"] = "Known Recipes"
L["Dye Slots"] = "Dye Slots"
L["Apply Dye"] = "Apply Dye"
L["Preview"] = "Preview"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["General"] = "General"
L["Overlays"] = "Overlays"
L["Tooltips"] = "Tooltips"
L["Export"] = "Export"

L["Enable addon"] = "Enable addon"
L["Show minimap button"] = "Show minimap button"
L["Enable overlays"] = "Enable overlays"
L["Show on bags"] = "Show on bags"
L["Show on bank"] = "Show on bank"
L["Show on merchant"] = "Show on merchant"
L["Show on auction house"] = "Show on auction house"
L["Show on housing catalog"] = "Show on housing catalog"
L["Icon size"] = "Icon size"
L["Icon position"] = "Icon position"
L["Show opposite faction vendors"] = "Show opposite faction vendors"
L["Show unverified vendors"] = "Show unverified vendors"

L["Enable tooltip additions"] = "Enable tooltip additions"
L["Show source information"] = "Show source information"
L["Show quantity owned"] = "Show quantity owned"
L["Show dye slot information"] = "Show dye slot information"
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
L["Left-Click: Toggle options"] = "|cFFFFFFFFLeft-Click:|r Toggle options"
L["Right-Click: Detach/close vendor panel"] = "|cFFFFFFFFRight-Click:|r Detach/close vendor panel"
L["Middle-Click: Scan collection"] = "|cFFFFFFFFMiddle-Click:|r Scan collection"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Homestead Commands:"
L["/hs - Open options panel"] = "/hs — Open options panel"
L["/hs scan - Scan catalog"] = "/hs scan — Scan catalog for owned items"
L["/hs vendor [search] - Search vendors"] = "/hs vendor [search] — Search for decor vendors"
L["/hs export - Show export dialog"] = "/hs export — Show export dialog"
L["/hs debug - Toggle debug mode"] = "/hs debug — Toggle debug mode"
L["/hs help - Show this help"] = "/hs help — Show this help"

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
L["Not yet implemented"] = "Not yet implemented"

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
L["Quest"] = "Quest"
L["Achievement"] = "Achievement"
L["Profession"] = "Profession"
L["Event"] = "Event"
L["Drop"] = "Drop"
L["Shop"] = "Shop"
L["Zone Collection Progress"] = "Zone Collection Progress"
L["Continent Collection Progress"] = "Continent Collection Progress"
L["Global Collection Progress"] = "Global Collection Progress"
L["Order Hall"] = "Order Hall"
L["Click to preview"] = "Click to preview"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "Output"
L["Select All"] = "Select All"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "All text selected. Press Ctrl+C to copy to clipboard."

-------------------------------------------------------------------------------
-- Statistics
-------------------------------------------------------------------------------
L["Statistics"] = "Statistics"
L["Total Decor:"] = "Total Decor:"
L["Collected:"] = "Collected:"
L["Placed:"] = "Placed:"
L["Remaining:"] = "Remaining:"
L["Collection Progress: %d%%"] = "Collection Progress: %d%%"

-------------------------------------------------------------------------------
-- Options - Names
-------------------------------------------------------------------------------
L["Show opposite faction vendors"] = "Show opposite faction vendors"
L["Show unverified vendors"] = "Show unverified vendors"
L["Show vendor details in tooltips"] = "Show vendor details in tooltips"
L["Use native waypoints"] = "Use native waypoints"
L["Auto-create waypoint on click"] = "Auto-create waypoint on click"
L["Navigate modifier key"] = "Navigate modifier key"

L["Auto-scan vendors"] = "Auto-scan vendors"
L["Vendor Visibility"] = "Vendor Visibility"
L["Show event vendors"] = "Show event vendors"
L["Pin Appearance"] = "Pin Appearance"
L["Pin color"] = "Pin color"
L["Custom color"] = "Custom color"
L["Show accessibility glow"] = "Show accessibility glow"
L["Owned item style"] = "Owned item style"
L["Show ownership status"] = "Show ownership status"
L["Show requirements"] = "Show requirements"
L["Show all sources"] = "Show all sources"
L["Map Pins"] = "Map Pins"
L["World Map"] = "World Map"
L["Show vendor panel on world map"] = "Show vendor panel on world map"
L["Vendor panel source filter"] = "Vendor panel source filter"
L["Integrate with map frame border"] = "Integrate with map frame border"
L["Zone badges on world map"] = "Zone badges on world map"
L["World map pin size"] = "World map pin size"
L["Show collection counts"] = "Show collection counts"
L["Minimap"] = "Minimap"
L["Show elevation arrows"] = "Show elevation arrows"
L["Minimap nearby-zone pins"] = "Minimap nearby-zone pins"
L["Minimap pin size"] = "Minimap pin size"
L["Waypoints"] = "Waypoints"
L["Endeavors"] = "Endeavors"
L["Show milestone progress on dashboard"] = "Show milestone progress on dashboard"
L["Export New Scans"] = "Export New Scans"
L["Export All"] = "Export All"
L["Inventory"] = "Inventory"
L["Merchant"] = "Merchant"
L["Housing Catalog"] = "Housing Catalog"

-------------------------------------------------------------------------------
-- Options - Descriptions
-------------------------------------------------------------------------------
L["desc_enable_addon"] = "Enable or disable Homestead"
L["desc_minimap_button"] = "Show or hide the minimap button"
L["desc_auto_scan_vendors"] = "Automatically scan merchant inventory for housing decor data when visiting vendors. Community data helps improve the addon's vendor database. Disabling may slightly improve performance when opening merchants."
L["desc_options_general"] = "Core addon behavior, minimap access, vendor scanning, and map pin appearance."
L["desc_options_overlays"] = "Collection markers shown on bags, merchants, the auction house, and the Housing Catalog."
L["desc_options_tooltips"] = "Extra ownership, source, requirement, and vendor details added to item and map-pin tooltips."
L["desc_options_world_map"] = "World map vendor pins, zone badges, side-panel behavior, and map pin display."
L["desc_options_minimap"] = "Nearby vendor pins, elevation arrows, and waypoint behavior on the minimap."
L["desc_options_endeavors"] = "Housing Endeavor progress shown on Blizzard's Housing Dashboard."
L["desc_options_export"] = "Scanned vendor data export for review, backup, or community sharing."
L["desc_vendor_visibility_section"] = "Choose which vendor groups appear on maps and in collection totals."
L["desc_pin_appearance_section"] = "Adjust the color and preview for Homestead vendor pins."
L["desc_overlay_inventory_section"] = "Show collection markers on item slots outside the Housing Catalog."
L["desc_overlay_merchant_section"] = "Mark collected decor while browsing vendor items."
L["desc_overlay_catalog_section"] = "Control Housing Catalog markers, highlights, and collected-item styling."
L["desc_tooltip_map_pins_section"] = "Choose how much vendor detail appears on map-pin tooltips."
L["desc_minimap_waypoints_section"] = "Configure TomTom and native waypoint behavior from map and vendor clicks."
L["desc_opposite_faction"] = "Show vendors for the opposite faction with their faction emblem. Useful for completionists to see all available vendors."
L["desc_unverified_vendors"] = "Show vendors with unverified locations (orange pins). These are imported from external sources and may have incorrect coordinates. Visit these vendors in-game to verify their location."
L["desc_event_vendors"] = "Show seasonal holiday vendor pins on the map when their event is active (e.g., Lunar Festival)"
L["desc_pin_color"] = "Choose a color for map and minimap pins. Unverified pins always show orange."
L["desc_custom_color"] = "Pick a custom base color for map pins"
L["desc_enable_overlays"] = "Add small icons and highlights to decor items throughout the game so you can tell at a glance which ones you've collected. Turning this off hides all Homestead overlays everywhere."
L["desc_icon_size"] = "Controls how large the collection icons appear on item slots."
L["desc_icon_position"] = "Which corner of the item slot the collection icon sits in."
L["desc_show_on_bags"] = "Adds a |TInterface\\RaidFrame\\ReadyCheck-Ready:16|t to decor items in your bags that you've already collected. Works with default bags, Baganator, and BetterBags."
L["desc_show_on_bank"] = "Mark decor items in your bank so you can see which ones you've already collected."
L["desc_show_on_auction_house"] = "Mark decor items on the auction house so you can avoid buying duplicates."
L["desc_show_on_merchant"] = "Adds a |TInterface\\RaidFrame\\ReadyCheck-Ready:16|t to decor items at vendors that you've already collected."
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
L["desc_show_quantity"] = "Display how many copies of a decor item you currently own."
L["desc_show_requirements"] = "Display purchase requirements like reputation, quest completion, or achievements needed to buy an item."
L["desc_show_all_sources"] = "List every known way to obtain an item instead of just the best available source. Helpful when an item can be acquired from multiple vendors, quests, or other sources."
L["desc_vendor_details"] = "Show a vendor's full inventory and your collection progress when hovering over their map pin. Disable for a simpler tooltip with just the vendor name."
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
L["desc_export"] = "Export scanned vendor data for community sharing or backup."
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
L["Vendor"] = "Vendor"
L["Quest"] = "Quest"
L["Achievement"] = "Achievement"
L["Profession"] = "Profession"
L["Event"] = "Event"
L["Shop"] = "Shop"
L["Drop"] = "Drop"

-- Minimap cross-zone mode
L["Auto (recommended)"] = "Auto (recommended)"
L["Current zone only"] = "Current zone only"
L["Always show nearby zones"] = "Always show nearby zones"

-- Navigate modifier
L["Shift"] = "Shift"
L["Control"] = "Control"
L["Alt"] = "Alt"
L["None (always)"] = "None (always)"

-- Misc
L["Approximate map appearance"] = "Approximate map appearance"
L["ExportImport not available."] = "ExportImport not available."
