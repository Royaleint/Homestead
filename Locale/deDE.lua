--[[
    Homestead - Locale: German (DE)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "deDE" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- UI Labels
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["Overlays"] = "Overlays"
L["Tooltips"] = "Tooltips"
L["Export"] = "Exportieren"

L["Show minimap button"] = "Minikartenknopf anzeigen"
L["Enable overlays"] = "Overlays aktivieren"
L["Show on bags"] = "In Taschen anzeigen"
L["Show on bank"] = "In der Bank anzeigen"
L["Show on merchant"] = "Beim Händler anzeigen"
L["Show on housing catalog"] = "Im Wohnungskatalog anzeigen"
L["Icon size"] = "Symbolgröße"
L["Icon position"] = "Symbolposition"
L["Show opposite faction vendors"] = "Händler der Gegenfraktion anzeigen"

L["Enable tooltip additions"] = "Tooltip-Ergänzungen aktivieren"
L["Show source information"] = "Quellinformationen anzeigen"
L["Show vendor details in tooltips"] = "Händlerdetails in Tooltips anzeigen"

L["Show map pins"] = "Kartenmarkierungen anzeigen"
L["Show minimap pins"] = "Minikartenmarkierungen anzeigen"
L["Use TomTom for waypoints"] = "TomTom für Wegpunkte verwenden"
L["Use native waypoints"] = "Native Wegpunkte verwenden"
L["Auto-create waypoint on click"] = "Wegpunkt bei Klick automatisch erstellen"
L["Navigate modifier key"] = "Navigationsmodifikatortaste"

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d / %d (%d%%)"] = "Sammlung: %d / %d (%d%%)"
L["Vendors nearby: %d"] = "Händler in der Nähe: %d"
L["Vendors scanned: %d"] = "Gescannte Händler: %d"
L["Left-Click: Toggle options"] = "|cFFFFFFFFLinksklick:|r Optionen umschalten"
L["Right-Click: Detach/close vendor panel"] = "|cFFFFFFFFRechtsklick:|r Händlerpanel lösen/schließen"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Homestead-Befehle:"

-------------------------------------------------------------------------------
-- Slash Command Feedback
-------------------------------------------------------------------------------
L["Map pins refreshed."] = "Kartenmarkierungen aktualisiert."
L["No active waypoint."] = "Kein aktiver Wegpunkt."
L["Waypoint cleared."] = "Wegpunkt gelöscht."
L["Vendor database contains %d vendors."] = "Händlerdatenbank enthält %d Händler."
L["Use /hs vendor <name or zone> to search."] = "Verwende /hs vendor <Name oder Zone> zum Suchen."
L["No vendors found matching: %s"] = "Keine Händler gefunden für: %s"
L["Found %d vendor(s) matching: %s"] = "%d Händler gefunden für: %s"
L["... and %d more."] = "... und %d weitere."

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "Debugmodus: %s"
L["ON"] = "AN"
L["OFF"] = "AUS"
L["Unknown command: %s"] = "Unbekannter Befehl: %s"

-------------------------------------------------------------------------------
-- Export Dialog
-------------------------------------------------------------------------------
L["Export Vendor Data"] = "Händlerdaten exportieren"
L["Choose export option:"] = "Exportoption wählen:"
L["Export New Scans"] = "Neue Scans exportieren"
L["Export All"] = "Alle exportieren"

-------------------------------------------------------------------------------
-- Map Side Panel
-------------------------------------------------------------------------------
L["Vendor"] = "Händler"
L["Quest"] = "Quest"
L["Achievement"] = "Erfolg"
L["Profession"] = "Beruf"
L["Event"] = "Event"
L["Drop"] = "Beute"
L["Zone Collection Progress"] = "Zonensammlungsfortschritt"
L["Continent Collection Progress"] = "Kontinentsammlungsfortschritt"
L["Global Collection Progress"] = "Globaler Sammlungsfortschritt"
L["Order Hall"] = "Ordenshalle"
L["Click to preview"] = "Klicken für Vorschau"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "Ausgabe"
L["Select All"] = "Alles auswählen"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "Text ausgewählt. Strg+C zum Kopieren drücken."

