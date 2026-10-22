--[[
    Homestead - Locale: German (DE)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "deDE" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["Used in %d known recipe for decor you haven't collected"] = "In %d bekanntem Rezept für noch nicht gesammelte Dekoration verwendet"
L["Used in %d known recipes for decor you haven't collected"] = "In %d bekannten Rezepten für noch nicht gesammelte Dekoration verwendet"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["Homestead"] = "Homestead"
L["Homestead Options"] = "Homestead-Optionen"
L["Overlays"] = "Einblendungen"
L["Tooltips"] = "Tooltips"
L["Export"] = "Exportieren"

L["Show minimap button"] = "Minikartenknopf anzeigen"
L["Enable overlays"] = "Einblendungen aktivieren"
L["Show on bags"] = "In Taschen anzeigen"
L["Show on bank"] = "In der Bank anzeigen"
L["Show on merchant"] = "Beim Händler anzeigen"
L["Show on housing catalog"] = "Im Behausungskatalog anzeigen"
L["Icon size"] = "Symbolgröße"
L["Icon position"] = "Symbolposition"
L["Show opposite faction vendors"] = "Händler der gegnerischen Fraktion anzeigen"

L["Enable tooltip additions"] = "Tooltip-Ergänzungen aktivieren"
L["Show source information"] = "Herkunftsinformationen anzeigen"
L["Show vendor details in tooltips"] = "Händlerdetails in Tooltips anzeigen"

L["Show map pins"] = "Kartenmarkierungen anzeigen"
L["Show minimap pins"] = "Minikartenmarkierungen anzeigen"
L["Use TomTom for waypoints"] = "TomTom für Wegpunkte verwenden"
L["Use native waypoints"] = "Spieleigene Wegpunkte verwenden"
L["Auto-create waypoint on click"] = "Wegpunkt bei Klick automatisch setzen"
L["Navigate modifier key"] = "Zusatztaste für Navigation"

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d / %d (%d%%)"] = "Sammlung: %d / %d (%d%%)"
L["Vendors nearby: %d"] = "Händler in der Nähe: %d"
L["Vendors scanned: %d"] = "Gescannte Händler: %d"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Homestead-Befehle:"

-------------------------------------------------------------------------------
-- Slash Command Feedback
-------------------------------------------------------------------------------
L["Map pins refreshed."] = "Kartenmarkierungen aktualisiert."
L["No active waypoint."] = "Kein aktiver Wegpunkt."
L["Waypoint cleared."] = "Wegpunkt entfernt."
L["Vendor database contains %d vendors."] = "Die Händlerdatenbank enthält %d Händler."
L["Use /hs vendor <name or zone> to search."] = "Verwendet /hs vendor <Name oder Zone> zum Suchen."
L["No vendors found matching: %s"] = "Keine passenden Händler gefunden für: %s"
L["Found %d vendor(s) matching: %s"] = "Gefundene Händler (%d) für: %s"
L["... and %d more."] = "... und %d weitere."

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "Debugmodus: %s"
L["ON"] = "An"
L["OFF"] = "Aus"
L["Unknown command: %s"] = "Unbekannter Befehl: %s"
L["Type /hs help for a list of commands."] = "Gebt /hs help ein, um eine Liste der Befehle zu sehen."

-------------------------------------------------------------------------------
-- Version Check
-------------------------------------------------------------------------------
L["Your Homestead version is out-of-date."] = "Eure Homestead-Version ist veraltet."
L["Version %s (%s) can be downloaded at CurseForge, Wago, or GitHub Releases."] = "Version %s (%s) kann bei CurseForge, Wago oder GitHub Releases heruntergeladen werden."
L["Homestead version: %s (%s)"] = "Homestead-Version: %s (%s)"
L["Newest version seen this session: %s (%s)"] = "Neueste in dieser Sitzung gesehene Version: %s (%s)"
L["No newer version seen this session."] = "In dieser Sitzung wurde keine neuere Version gesehen."
L["Version-check notifications: %s"] = "Benachrichtigungen zur Versionsprüfung: %s"

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
L["Vendors"] = "Händler"
L["Quest"] = "Quest"
L["Achievement"] = "Erfolg"
L["Profession"] = "Beruf"
L["Event"] = "Ereignis"
L["Drop"] = "Beute"
L["Treasure"] = "Schatz"
L["Zone Collection Progress"] = "Sammlungsfortschritt der Zone"
L["Continent Collection Progress"] = "Sammlungsfortschritt des Kontinents"
L["Global Collection Progress"] = "Globaler Sammlungsfortschritt"
L["Order Hall"] = "Ordenshalle"
L["Click to preview"] = "Klicken für Vorschau"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "Ausgabe"
L["Select All"] = "Alles markieren"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "Gesamter Text markiert. Drückt Strg+C, um ihn in die Zwischenablage zu kopieren."

-------------------------------------------------------------------------------
-- Options - Names
-------------------------------------------------------------------------------
L["Vendor pin item details"] = "Gegenstandsdetails in Händlermarkierungen"

L["Auto-scan vendors"] = "Händler automatisch scannen"
L["Vendor Visibility"] = "Händlersichtbarkeit"
L["Show event vendors"] = "Ereignishändler anzeigen"
L["Hide fully-collected vendor pins"] = "Komplett gesammelte Händler nicht markieren"
L["Fully-collected vendors"] = "Vollständig gesammelte Händler"
L["desc_map_filter_completed_vendors"] = "Abwählen, um Markierungen von Händlern auszublenden, deren Dekoration Ihr vollständig gesammelt habt."
L["Pin Appearance"] = "Aussehen der Markierungen"
L["Pin color"] = "Markierungsfarbe"
L["Custom color"] = "Eigene Farbe"
L["Show accessibility glow"] = "Leuchten zur Barrierefreiheit anzeigen"
L["Owned item style"] = "Stil gesammelter Gegenstände"
L["Show ownership status"] = "Besitzstatus anzeigen"
L["Show requirements"] = "Voraussetzungen anzeigen"
L["Show all sources"] = "Alle Herkunftsquellen anzeigen"
L["Map Pins"] = "Kartenmarkierungen"
L["Show vendor panel on world map"] = "Händlerleiste auf der Weltkarte anzeigen"
L["Vendor panel source filter"] = "Herkunftsfilter der Händlerleiste"
L["Integrate with map frame border"] = "In den Kartenrahmen integrieren"
L["Zone badges on world map"] = "Zonenabzeichen auf der Weltkarte"
L["World map pin size"] = "Markierungsgröße auf der Weltkarte"
L["Show collection counts"] = "Sammlungszahlen anzeigen"
L["Show elevation arrows"] = "Höhenpfeile anzeigen"
L["Minimap nearby-zone pins"] = "Minikartenmarkierungen benachbarter Zonen"
L["Minimap pin size"] = "Markierungsgröße auf der Minikarte"
L["Waypoints"] = "Wegpunkte"
L["Show milestone progress on dashboard"] = "Meilensteine in Behausungsübersicht zeigen"
L["Inventory"] = "Inventar"
L["Merchant"] = "Händler"
L["Housing Catalog"] = "Behausungskatalog"

-------------------------------------------------------------------------------
-- Options - Descriptions
-------------------------------------------------------------------------------
L["desc_minimap_button"] = "Den Minikartenknopf anzeigen oder ausblenden"
L["desc_auto_scan_vendors"] = "Scannt beim Besuch von Händlern automatisch deren Angebot nach Daten zu Behausungsdekorationen. Das Deaktivieren kann die Leistung beim Öffnen von Händlerfenstern leicht verbessern."
L["desc_options_general"] = "Grundlegendes Addon-Verhalten, Zugriff über die Minikarte, Händlerscans und Aussehen der Kartenmarkierungen."
L["desc_options_overlays"] = "Sammlungsmarkierungen in Taschen, in der Bank, bei Händlern und im Behausungskatalog."
L["desc_options_tooltips"] = "Zusätzliche Angaben zu Besitz, Herkunft, Voraussetzungen und Händlern in Tooltips von Gegenständen und Kartenmarkierungen."
L["desc_options_world_map"] = "Händlermarkierungen auf der Weltkarte, Zonenabzeichen, Verhalten der Seitenleiste und Anzeige der Kartenmarkierungen."
L["desc_options_minimap"] = "Händlermarkierungen in der Nähe, Höhenpfeile und Wegpunktverhalten auf der Minikarte."
L["desc_options_endeavors"] = "Fortschritt der Behausungsunterfangen in Blizzards Behausungsübersicht."
L["desc_options_export"] = "Export gescannter Händlerdaten zur Überprüfung oder Sicherung."
L["desc_vendor_visibility_section"] = "Wählt, welche Händlergruppen auf Karten und in den Sammlungssummen erscheinen."
L["desc_pin_appearance_section"] = "Farbe und Vorschau der Homestead-Händlermarkierungen anpassen."
L["desc_overlay_inventory_section"] = "Sammlungsmarkierungen auf Gegenstandsplätzen außerhalb des Behausungskatalogs anzeigen."
L["desc_overlay_merchant_section"] = "Gesammelte Dekoration beim Durchsehen von Händlerwaren markieren."
L["desc_overlay_catalog_section"] = "Markierungen, Hervorhebungen und Darstellung gesammelter Gegenstände im Behausungskatalog steuern."
L["desc_tooltip_map_pins_section"] = "Wählt, wie viele Händlerdetails in Tooltips von Kartenmarkierungen erscheinen."
L["desc_minimap_waypoints_section"] = "TomTom und spieleigene Wegpunkte für Klicks auf Karte und Händler einrichten."
L["desc_opposite_faction"] = "Zeigt Händler der gegnerischen Fraktion mit ihrem Fraktionswappen an. Nützlich für Komplettisten, die alle verfügbaren Händler sehen möchten."
L["desc_event_vendors"] = "Zeigt Markierungen von Feiertagshändlern auf der Karte an, während ihr Ereignis aktiv ist (z. B. Mondfest)"
L["desc_hide_completed_vendor_pins"] = "Blendet Karten- und Minikartenmarkierungen von Händlern aus, deren Behausungsdekoration Ihr vollständig gesammelt habt. Die Liste in der Händlerleiste bleibt unverändert."
L["desc_pin_color"] = "Wählt eine Farbe für Markierungen auf der Karte und der Minikarte."
L["desc_custom_color"] = "Eine eigene Grundfarbe für Kartenmarkierungen wählen"
L["desc_enable_overlays"] = "Fügt Dekorationsgegenständen im ganzen Spiel kleine Symbole und Hervorhebungen hinzu, damit Ihr auf einen Blick seht, welche Ihr bereits gesammelt habt. Beim Ausschalten werden alle Homestead-Einblendungen überall ausgeblendet."
L["desc_icon_size"] = "Legt fest, wie groß die Sammlungssymbole auf Gegenstandsplätzen erscheinen."
L["desc_icon_position"] = "In welcher Ecke des Gegenstandsplatzes das Sammlungssymbol sitzt."
L["desc_show_on_bags"] = "Fügt Dekorationsgegenständen in Euren Taschen ein |A:homestone-minimap-icon:16:16|a hinzu, dessen Farbe zeigt, ob Ihr den jeweiligen Gegenstand gesammelt habt. Funktioniert mit den Standardtaschen, Baganator und BetterBags."
L["desc_show_on_bank"] = "Markiert Dekorationsgegenstände in Eurer Bank, damit Ihr seht, welche Ihr bereits gesammelt habt."
L["desc_show_on_merchant"] = "Fügt Dekorationsgegenständen bei Händlern ein |A:homestone-minimap-icon:16:16|a hinzu, dessen Farbe zeigt, ob Ihr den jeweiligen Gegenstand gesammelt habt."
L["desc_show_on_housing_catalog"] = "Markiert Gegenstände im Behausungskatalog mit Sammlungssymbolen, die zeigen, woher jeder Gegenstand stammt.\n\n|A:auctionhouse-icon-coin-gold:16:16|a Händler\n|A:QuestNormal:16:16|a Quest\n|A:UI-Achievement-Shield-NoPoints:16:16|a Erfolg\n|A:UI-HUD-MicroMenu-Professions-Mouseover:16:16|a Beruf\n|A:UI-HUD-Calendar-1-Up:16:16|a Ereignis\n|A:Crosshair_lootall_64:16:16|a Beute\n|A:hearthsteel-icon-32x32:16:16|a Battle.net-Shop"
L["desc_accessibility_glow"] = "Fügt Gegenständen im Behausungskatalog einen farbigen Leuchtrand hinzu: grün für Gegenstände in Eurem Besitz, gelb für erhältliche Gegenstände und rot für Gegenstände, deren Voraussetzungen Ihr noch nicht erfüllt habt."
L["desc_owned_item_style"] = "Wählt, wie gesammelte Gegenstände im Behausungskatalog aussehen. Grüne Hervorhebung zeigt das Standardleuchten, Abgedunkelt blendet sie ab und Häkchen fügt ein kleines grünes Häkchen hinzu. Wählt Keine, um sie unverändert zu lassen."
L["desc_enable_tooltips"] = "Fügt Gegenstands-Tooltips Homestead-Informationen hinzu, wenn Ihr mit der Maus über Dekorationsgegenstände fahrt. Beim Ausschalten werden alle Tooltip-Ergänzungen entfernt."
L["desc_show_ownership"] = "Fügt Tooltips eine Zeile hinzu, die zeigt, ob Ihr einen Dekorationsgegenstand bereits gesammelt habt."
L["desc_show_source"] = "Zeigt, wie man einen Dekorationsgegenstand erhält – Händler, Quests, Erfolge, Berufe, Ereignisse und Beute."
L["desc_show_requirements"] = "Zeigt Kaufvoraussetzungen wie Ruf, abgeschlossene Quests oder Erfolge an, die zum Kauf eines Gegenstands nötig sind."
L["desc_show_all_sources"] = "Listet jede bekannte Herkunft eines Gegenstands auf statt nur der besten verfügbaren. Hilfreich, wenn ein Gegenstand bei mehreren Händlern, durch Quests oder aus anderen Quellen erhältlich ist."
L["desc_vendor_details"] = "Zeigt beim Überfahren der Kartenmarkierung eines Händlers dessen gesamtes Angebot und Euren Sammlungsfortschritt. Deaktivieren für einen einfacheren Tooltip nur mit dem Händlernamen."
L["desc_vendor_pin_item_details"] = "Zeigt in Tooltips von Kartenmarkierungen für jeden Gegenstand Symbole alternativer Herkunft und die Händlerkosten sowie die Anzahl der nur beim Händler erhältlichen Gegenstände. Deaktivieren für einen einfacheren Tooltip, der nur Gegenstandsnamen auflistet."
L["desc_show_map_pins"] = "Händlerstandorte auf der Weltkarte anzeigen"
L["desc_show_map_side_panel"] = "Zeigt auf der Weltkarte eine Seitenleiste mit Händlern und dem Sammlungsfortschritt der aktuellen Zone"
L["desc_source_filter"] = "Filtert die Gegenstandszahlen der Seitenleiste und die erweiterten Raster nach Herkunft. Die Sichtbarkeit der Händler auf der Karte bleibt unverändert."
L["desc_integrate_map_border"] = "Verbindet den oberen Rand der Leiste nahtlos mit dem Rahmen der Weltkarte. Deaktivieren, wenn Ihr eine eigene Oberfläche (ElvUI, GW2 usw.) nutzt, die damit kollidiert."
L["desc_zone_badges"] = "Zeigt auf der Weltkarte Händlerzahlen pro Zone verteilt über die Kontinente statt einer einzigen Summe pro Kontinent."
L["desc_world_pin_size"] = "Passt die Größe der Händlermarkierungen auf der Weltkarte an. Der Standard (20) entspricht Blizzards POI-Symbolen."
L["desc_show_pin_counts"] = "Zeigt gesammelte/gesamte Gegenstandszahlen auf Händlermarkierungen an (z. B. 3/12). Deaktivieren, um die Karte übersichtlicher zu halten."
L["desc_show_minimap_pins"] = "Händlerstandorte mit Höhenpfeilen auf der Minikarte anzeigen"
L["desc_elevation_arrows"] = "Zeigt Richtungspfeile an Minikartenmarkierungen, wenn sich ein Händler über oder unter Euch befindet"
L["desc_cross_zone_mode"] = "Steuert zonenübergreifende Minikartenmarkierungen. Bei „Automatisch“ werden zusätzliche Markierungen in belebten Stadtzonen reduziert, für flüssigere Bewegung."
L["desc_minimap_pin_size"] = "Passt die Größe der Händlermarkierungen auf der Minikarte an. Erhöhen, wenn Markierungen schwer zu erkennen sind, oder verringern, um die Minikarte übersichtlicher zu halten."
L["desc_waypoint_info"] = "TomTom zeigt einen Richtungspfeil an und setzt voraus, dass das Addon TomTom installiert ist. Die spieleigene Variante fügt der Weltkarte eine Zielmarkierung hinzu. Beide können gleichzeitig aktiv sein."
L["desc_use_tomtom"] = "Das Addon TomTom für Wegpunktpfeile verwenden (falls installiert)"
L["desc_use_native_waypoints"] = "Das in WoW integrierte Wegpunktsystem mit Kartenmarkierung verwenden"
L["desc_auto_waypoint"] = "Beim Klick auf einen Händler in der Liste oder auf der Karte automatisch einen Wegpunkt setzen"
L["desc_navigate_modifier"] = "Haltet diese Taste beim Klicken gedrückt, um einen Wegpunkt zu setzen (wenn der automatische Wegpunkt aus ist)"
L["desc_milestone_xp"] = "Zeigt den EP-Fortschritt zum nächsten Meilenstein im Reiter „Unterfangen“ von Blizzards Behausungsübersicht an. Deaktivieren, wenn Ihr dafür ein anderes Addon nutzt (z. B. Endeavor Simple Progress Tracker)."
L["desc_export"] = "Gescannte Händlerdaten zur Sicherung exportieren."
L["desc_export_new"] = "Exportiert Händler, die seit Eurem letzten Export gescannt wurden. Enthält Preis, Währungen, Fraktion und Kataloginfos."
L["desc_export_all"] = "Exportiert alle gescannten Händler und umgeht dabei den Zeitstempelfilter."

-------------------------------------------------------------------------------
-- Options - Select Values
-------------------------------------------------------------------------------
-- Pin colors
L["Default (Gold)"] = "Standard (Gold)"
L["Bright Green"] = "Leuchtendes Grün"
L["Ice Blue"] = "Eisblau"
L["Light Blue"] = "Hellblau"
L["Purple"] = "Violett"
L["Pink"] = "Rosa"
L["Red"] = "Rot"
L["Cyan"] = "Türkis"
L["White"] = "Weiß"
L["Yellow"] = "Gelb"
L["Custom..."] = "Eigene..."

-- Icon anchor positions
L["Top Left"] = "Oben links"
L["Top Right"] = "Oben rechts"
L["Bottom Left"] = "Unten links"
L["Bottom Right"] = "Unten rechts"
L["Center"] = "Mitte"

-- Owned item styles
L["Green highlight (default)"] = "Grüne Hervorhebung (Standard)"
L["None"] = "Keine"
L["Dimmed"] = "Abgedunkelt"
L["Checkmark"] = "Häkchen"

-- Source filter
L["All sources"] = "Alle Herkunftsquellen"

-- Minimap cross-zone mode
L["Auto (recommended)"] = "Automatisch (empfohlen)"
L["Current zone only"] = "Nur aktuelle Zone"
L["Always show nearby zones"] = "Benachbarte Zonen immer anzeigen"

-- Navigate modifier
L["None (always)"] = "Keine (immer)"

-- Misc
L["Approximate map appearance"] = "Ungefähres Aussehen auf der Karte"
L["ExportImport not available."] = "ExportImport nicht verfügbar."

-------------------------------------------------------------------------------
-- Decor Browser
-------------------------------------------------------------------------------
-- Decor Browser: minimap tooltip
L["Left-Click: Toggle Decor Browser"] = "|cFFFFFFFFLinksklick:|r Dekorationsbrowser ein-/ausblenden"
L["Right-Click: Open options"] = "|cFFFFFFFFRechtsklick:|r Optionen öffnen"

-- Decor Browser: data adapter
L["Gold"] = "Gold"
L["Unknown"] = "Unbekannt"
L["Required"] = "Erforderlich"
L["Unknown faction"] = "Unbekannte Fraktion"
L["Other requirement"] = "Sonstige Voraussetzung"
L["Source unknown"] = "Herkunft unbekannt"
L["Item %d"] = "Gegenstand %d"
L["%s %s"] = "%s %s"
L["%s, %s"] = "%s, %s"
L["%s - %s"] = "%s - %s"
L["%s (%s)"] = "%s (%s)"
L["%s: %s"] = "%s: %s"
L["%s with %s"] = "%s bei %s"
L["Level %s"] = "Stufe %s"
L["Achievement: %s"] = "Erfolg: %s"
L["Quest: %s"] = "Quest: %s"
L["Promotion: %s"] = "Aktion: %s"
L["Profession: %s"] = "Beruf: %s"
L["Profession: %s rank %s"] = "Beruf: %s, Rang %s"
L["Vendor: %s"] = "Händler: %s"
L["Vendor: %s, %s"] = "Händler: %s, %s"
L["Crafted: %s - %s"] = "Hergestellt: %s - %s"
L["Drops from %s"] = "Beute von %s"
L["Drops from %s (%s)"] = "Beute von %s (%s)"
L["Event: %s"] = "Ereignis: %s"
L["Event: %s - %s"] = "Ereignis: %s - %s"
L["Other source"] = "Sonstige Herkunft"

-- Decor Browser: visuals and widgets
L["Decor Browser"] = "Dekorationsbrowser"
L["Owned"] = "Im Besitz"
L["Unlocked to buy"] = "Zum Kauf freigeschaltet"
L["Locked"] = "Gesperrt"
L["Set waypoint"] = "Wegpunkt setzen"
L["%s / %s  ·  %d%%"] = "%s / %s  ·  %d%%"
L["0 / 0"] = "0 / 0"
L["? / %s"] = "? / %s"

-- Decor Browser: window and navigation
L["Open a list to search"] = "Liste öffnen, um zu suchen"
L["Homestead Decor"] = "Homestead-Dekor"
L["Summary"] = "Übersicht"
L["Catalog"] = "Katalog"
L["Sources"] = "Quellen"
L["Help"] = "Hilfe"
L["Hide what doesn't apply to me"] = "Ausblenden, was mich nicht betrifft"
L["The Decor Browser opens once Homestead has finished loading."] = "Der Dekorationsbrowser öffnet sich, sobald Homestead fertig geladen hat."
L["Collection"] = "Sammlung"
L["Placed"] = "Platziert"
L["In storage"] = "Im Lager"
L["Not yet redeemed"] = "Noch nicht eingelöst"
L["Counts not loaded yet"] = "Anzahlen noch nicht geladen"
L["Source"] = "Herkunft"
L["Price"] = "Preis"

-- Decor Browser: shop and item pages
L[", "] = ", "
L["Clear filters"] = "Filter zurücksetzen"
L["Search: %s"] = "Suche: %s"
L["Nothing matches %s."] = "Keine Treffer für %s."
L["Seasonal: %s"] = "Saisonal: %s"
L["Rotates with the %s Endeavor"] = "Wechselt mit dem Unterfangen %s"
L["Rotates with neighborhood Endeavors"] = "Wechselt mit den Unterfangen der Nachbarschaft"
L["You own this."] = "Ihr besitzt dies."
L["You can buy it now. Not collected yet."] = "Ihr könnt dies jetzt kaufen. Noch nicht gesammelt."
L["Not available to you yet."] = "Für Euch noch nicht verfügbar."
L["Ownership cannot be read for this kind of item."] = "Der Besitz kann für diese Art von Gegenstand nicht ermittelt werden."
L["Ownership is not known yet."] = "Der Besitz ist noch nicht bekannt."
L["Met: %s"] = "Erfüllt: %s"
L["Needs: %s"] = "Benötigt: %s"
L["Unknown: %s"] = "Unbekannt: %s"
L["Status"] = "Status"
L["Requirement"] = "Voraussetzung"
L["Sold by"] = "Verkauft von"
L["Not listed"] = "Nicht aufgeführt"
L["Not sold by a vendor"] = "Wird von keinem Händler verkauft"
L["+%d more vendors"] = "+%d weitere Händler"
L["+%d more sources"] = "+%d weitere Herkunftsquellen"
L["Also available from"] = "Außerdem erhältlich bei"
L["No other sources on record."] = "Keine weiteren Herkunftsquellen bekannt."
L["Not available in combat"] = "Im Kampf nicht verfügbar"
L["Report a data error"] = "Datenfehler melden"
L["Item: %s (%d)"] = "Gegenstand: %s (%d)"
L["Record ID: %s"] = "Datensatz-ID: %s"
L["none"] = "keine"
L["no location"] = "kein Standort"
L["map %d at %.1f, %.1f"] = "Karte %d bei %.1f, %.1f"
L["Vendor %d: %s, %s, %s"] = "Händler %d: %s, %s, %s"
L["Client: %s (%s)"] = "Client: %s (%s)"
L["Homestead: %s"] = "Homestead: %s"

-- Decor Browser: entry points
L["Toggle Decor Browser"] = "Dekorationsbrowser ein-/ausblenden"
L["Open the Decor Browser, or bind a key under Keybindings > Homestead"] = "Öffnet den Dekorationsbrowser. Unter Tastaturbelegung > Homestead könnt Ihr auch eine Taste zuweisen."
L["Minimap button"] = "Minikartenknopf"
L["Left-click opens the Decor Browser, right-click opens options"] = "Linksklick öffnet den Dekorationsbrowser, Rechtsklick die Optionen"

-- Welcome window
L["Find every decor vendor on your map and see what you own before you buy."] = "Findet jeden Dekorationshändler auf Eurer Karte und seht, was Ihr besitzt, bevor Ihr kauft."
L["What Homestead Does"] = "Was Homestead kann"
L["Every decor vendor pinned on your world map and minimap, with badges showing how many items you still need per zone."] = "Jeder Dekorationshändler wird auf Eurer Weltkarte und Minikarte markiert, mit Abzeichen, die zeigen, wie viele Gegenstände Euch pro Zone noch fehlen."
L["Map Side Panel"] = "Kartenseitenleiste"
L["Click the Homestead button on the world map to open the side panel listing that zone's vendors, then click any vendor to browse their wares and see what you still need. Pop it out as a standalone window with |cFF00FF00/hs panel|r."] = "Klickt auf der Weltkarte auf den Homestead-Knopf, um die Seitenleiste mit den Händlern der Zone zu öffnen. Klickt dann auf einen Händler, um sein Angebot zu durchsuchen und zu sehen, was Euch noch fehlt. Mit |cFF00FF00/hs panel|r löst Ihr sie als eigenes Fenster ab."
L["Tooltips Expanded"] = "Erweiterte Tooltips"
L["Every item in the Housing Catalog gets tooltips showing where it comes from (vendor, quest, achievement, profession, or drop), what it costs, and what you need to unlock it, so you never have to leave the game to look something up."] = "Jeder Gegenstand im Behausungskatalog erhält Tooltips, die zeigen, woher er stammt (Händler, Quest, Erfolg, Beruf oder Beute), was er kostet und was Ihr zum Freischalten braucht – so müsst Ihr das Spiel nie verlassen, um etwas nachzuschlagen."
L["Key Commands"] = "Wichtige Befehle"
L["Export everything you've scanned"] = "Alles Gescannte exportieren"
L["Show all commands"] = "Alle Befehle anzeigen"
L["Found a Problem?"] = "Ein Problem gefunden?"
L["Report bugs or wrong vendor info on GitHub using the link below."] = "Meldet Fehler oder falsche Händlerdaten über den Link unten auf GitHub."
L["Report issues (GitHub):"] = "Probleme melden (GitHub):"
L["CurseForge:"] = "CurseForge:"
L["Don't show this again"] = "Nicht mehr anzeigen"
L["Let's Decorate!"] = "Los geht's!"

-------------------------------------------------------------------------------
-- Decor Browser: source and vendor labels
-------------------------------------------------------------------------------
L["Achievements"] = "Erfolge"
L["Quests"] = "Quests"
L["Professions"] = "Berufe"
L["Drops"] = "Beute"
L["Events"] = "Ereignisse"
L["Other"] = "Sonstiges"
L["Location not recorded"] = "Standort nicht erfasst"
L["Requires"] = "Benötigt"

-------------------------------------------------------------------------------
-- Decor Browser: holiday vendors
-------------------------------------------------------------------------------
L["The Decor Browser is not available yet."] = "Der Dekorationsbrowser ist noch nicht verfügbar."
