--[[
    Homestead - Locale: German (DE)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "deDE" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- Collection Status
-------------------------------------------------------------------------------
L["Collected"] = "Gesammelt"
L["Collected (Placed)"] = "Gesammelt (Platziert)"
L["Not Collected"] = "Nicht gesammelt"
L["Unknown"] = "Unbekannt"

-------------------------------------------------------------------------------
-- Source Descriptions
-------------------------------------------------------------------------------
L["Available from vendor"] = "Beim Händler erhältlich"
L["Can be crafted"] = "Kann hergestellt werden"
L["Achievement reward"] = "Erfolgsbelohnung"
L["World drop"] = "Weltbeute"
L["Quest reward"] = "Questbelohnung"
L["Reputation reward"] = "Rufbelohnung"
L["Event reward"] = "Eventbelohnung"
L["Promotional item"] = "Werbeartikel"

-------------------------------------------------------------------------------
-- Decor Properties
-------------------------------------------------------------------------------
L["Can be dyed"] = "Kann gefärbt werden"
L["Colorable"] = "Färbbar"
L["Warbound"] = "Kriegsgebunden"
L["Indoor only"] = "Nur drinnen"
L["Outdoor only"] = "Nur draußen"
L["Quantity owned: %d"] = "Im Besitz: %d"
L["Currently placed: %d"] = "Derzeit platziert: %d"

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["[Housing Addon]"] = "|cFF00FF00[Homestead]|r"
L["Source:"] = "Quelle:"
L["Vendor:"] = "Händler:"
L["Location:"] = "Standort:"
L["Click to set waypoint"] = "Klicken, um Wegpunkt zu setzen"

-------------------------------------------------------------------------------
-- UI Labels
-------------------------------------------------------------------------------
L["Housing Addon"] = "Homestead"
L["Decor Browser"] = "Dekor-Browser"
L["Vendor Tracer"] = "Händlersuche"
L["Color Tracker"] = "Farbverfolgung"
L["Export Data"] = "Daten exportieren"
L["Options"] = "Optionen"
L["Search"] = "Suchen"
L["Filter"] = "Filter"
L["Close"] = "Schließen"

-------------------------------------------------------------------------------
-- Vendor Tracer
-------------------------------------------------------------------------------
L["Set Waypoint"] = "Wegpunkt setzen"
L["Show on Map"] = "Auf Karte anzeigen"
L["Vendor sells %d decor items"] = "Händler verkauft %d Dekoartikel"
L["You own %d/%d items"] = "Du besitzt %d/%d Gegenstände"
L["Missing items:"] = "Fehlende Gegenstände:"
L["No vendors found"] = "Keine Händler gefunden"

-------------------------------------------------------------------------------
-- Color/Dye Tracker
-------------------------------------------------------------------------------
L["Dye Collection"] = "Farbkollektion"
L["Owned Dyes"] = "Eigene Farben"
L["Known Recipes"] = "Bekannte Rezepte"
L["Dye Slots"] = "Farbslots"
L["Apply Dye"] = "Farbe anwenden"
L["Preview"] = "Vorschau"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["General"] = "Allgemein"
L["Overlays"] = "Overlays"
L["Tooltips"] = "Tooltips"
L["Export"] = "Exportieren"

L["Show minimap button"] = "Minikartenknopf anzeigen"
L["Enable overlays"] = "Overlays aktivieren"
L["Show on bags"] = "In Taschen anzeigen"
L["Show on bank"] = "In der Bank anzeigen"
L["Show on merchant"] = "Beim Händler anzeigen"
L["Show on auction house"] = "Im Auktionshaus anzeigen"
L["Show on housing catalog"] = "Im Wohnungskatalog anzeigen"
L["Icon size"] = "Symbolgröße"
L["Icon position"] = "Symbolposition"
L["Show opposite faction vendors"] = "Händler der Gegenfraktion anzeigen"
L["Show unverified vendors"] = "Unbestätigte Händler anzeigen"

L["Enable tooltip additions"] = "Tooltip-Ergänzungen aktivieren"
L["Show source information"] = "Quellinformationen anzeigen"
L["Show quantity owned"] = "Besitzmenge anzeigen"
L["Show dye slot information"] = "Farbslot-Informationen anzeigen"
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
L["/hs - Open options panel"] = "/hs — Optionen öffnen"
L["/hs scan - Scan catalog"] = "/hs scan — Katalog nach eigenen Items scannen"
L["/hs vendor [search] - Search vendors"] = "/hs vendor [Suche] — Dekorhändler suchen"
L["/hs export - Show export dialog"] = "/hs export — Exportdialog anzeigen"
L["/hs debug - Toggle debug mode"] = "/hs debug — Debugmodus umschalten"
L["/hs help - Show this help"] = "/hs help — Diese Hilfe anzeigen"

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
L["Not yet implemented"] = "Noch nicht implementiert"

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
L["All"] = "Alle"
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

-------------------------------------------------------------------------------
-- Statistics
-------------------------------------------------------------------------------
L["Statistics"] = "Statistiken"
L["Total Decor:"] = "Dekoration gesamt:"
L["Collected:"] = "Gesammelt:"
L["Placed:"] = "Platziert:"
L["Remaining:"] = "Verbleibend:"
L["Collection Progress: %d%%"] = "Sammlungsfortschritt: %d%%"
