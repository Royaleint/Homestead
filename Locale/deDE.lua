--[[
    Homestead - Locale: German (DE)
    Machine-translated — contributions welcome
]]

local addonName, HA = ...

if GetLocale() ~= "deDE" then return end

-- Initialize localization table
local L = {}
HA.L = L

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
L["Search"] = "Suche"
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
L["Vendor Tracer"] = "Händlersuche"
L["Export"] = "Exportieren"

L["Enable addon"] = "Addon aktivieren"
L["Show minimap button"] = "Minikartenknopf anzeigen"
L["Enable overlays"] = "Overlays aktivieren"
L["Show on bags"] = "In Taschen anzeigen"
L["Show on bank"] = "In der Bank anzeigen"
L["Show on merchant"] = "Beim Händler anzeigen"
L["Show on auction house"] = "Im Auktionshaus anzeigen"
L["Show on housing catalog"] = "Im Wohnungskatalog anzeigen"
L["Icon size"] = "Symbolgröße"
L["Icon position"] = "Symbolposition"

L["Enable tooltip additions"] = "Tooltip-Ergänzungen aktivieren"
L["Show source information"] = "Quellinformationen anzeigen"
L["Show quantity owned"] = "Besitzmenge anzeigen"
L["Show dye slot information"] = "Farbslot-Informationen anzeigen"

L["Show map pins"] = "Kartenmarkierungen anzeigen"
L["Show minimap pins"] = "Minikartenmarkierungen anzeigen"
L["Use TomTom for waypoints"] = "TomTom für Wegpunkte verwenden"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Housing Addon Commands:"] = "Homestead-Befehle:"
L["/ha - Toggle main window"] = "/ha — Hauptfenster öffnen/schließen"
L["/ha options - Open options panel"] = "/ha options — Optionen öffnen"
L["/ha export - Export collection data"] = "/ha export — Sammlungsdaten exportieren"
L["/ha vendor [search] - Open vendor panel"] = "/ha vendor [Suche] — Händlerpanel öffnen"
L["/ha debug - Toggle debug mode"] = "/ha debug — Debugmodus umschalten"
L["/ha help - Show this help"] = "/ha help — Diese Hilfe anzeigen"

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "Debugmodus: %s"
L["ON"] = "AN"
L["OFF"] = "AUS"
L["Unknown command: %s"] = "Unbekannter Befehl: %s"
L["Not yet implemented"] = "Noch nicht implementiert"

-------------------------------------------------------------------------------
-- Statistics
-------------------------------------------------------------------------------
L["Statistics"] = "Statistiken"
L["Total Decor:"] = "Dekoration gesamt:"
L["Collected:"] = "Gesammelt:"
L["Placed:"] = "Platziert:"
L["Remaining:"] = "Verbleibend:"
L["Collection Progress: %d%%"] = "Sammlungsfortschritt: %d%%"
