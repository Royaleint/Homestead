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
L["Left-Click: Toggle Decor Browser"] = "|cFFFFFFFFLinksklick:|r Dekorationsbrowser ein-/ausblenden"
L["Right-Click: Open options"] = "|cFFFFFFFFRechtsklick:|r Optionen öffnen"

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
L["Catalog scan is on cooldown. Try again in a few seconds."] = "Der Katalogscan ist noch in Abklingzeit. Versucht es in wenigen Sekunden erneut."
L["A catalog scan is already in progress."] = "Ein Katalogscan läuft bereits."

-------------------------------------------------------------------------------
-- Decor Browser: data adapter
-------------------------------------------------------------------------------
L["Unknown"] = "Unbekannt"
L["A vendor"] = "Ein Händler"
L["Required"] = "Erforderlich"
L["Unknown faction"] = "Unbekannte Fraktion"
L["Other requirement"] = "Sonstige Voraussetzung"
L["Source unknown"] = "Herkunft unbekannt"
L["Item %d"] = "Gegenstand %d"
L["%s %s"] = "%s %s"
L["%s, %s"] = "%s, %s"
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
L["Set waypoint"] = "Wegpunkt setzen"

-- Decor Browser: window and navigation
L["Homestead Decor"] = "Homestead-Dekor"
L["Overview"] = "Übersicht"
L["Catalog"] = "Katalog"
L["Back"] = "Zurück"
L["Other Vendors"] = "Andere Händler"
L["%d of %d decor collected"] = "%d von %d Dekorationen gesammelt"
L["%d of %d collected"] = "%d von %d gesammelt"
L["Help"] = "Hilfe"
L["Hide collected and other-faction"] = "Gesammeltes und gegnerische Fraktion ausblenden"
L["Hides decor you have collected, vendors with nothing left to collect, and anything only the other faction can get."] = "Blendet gesammelte Dekoration, Händler ohne noch zu sammelnde Waren und alles aus, was nur die gegnerische Fraktion erhalten kann."
L["Opens a page explaining this window."] = "Öffnet eine Seite, die dieses Fenster erklärt."
L["The Decor Browser opens once Homestead has finished loading."] = "Der Dekorationsbrowser öffnet sich, sobald Homestead fertig geladen hat."
L["Collection"] = "Sammlung"
L["Placed"] = "Platziert"
L["In storage"] = "Im Lager"
L["Not yet redeemed"] = "Noch nicht eingelöst"
L["Counts not loaded yet"] = "Anzahlen noch nicht geladen"
L["Source"] = "Herkunft"
L["Price"] = "Preis"

-- Decor Browser: shop and item pages
L["Seasonal: %s"] = "Saisonal: %s"
L["Rotates with the %s Endeavor"] = "Wechselt mit dem Unterfangen %s"
L["Rotates with neighborhood Endeavors"] = "Wechselt mit den Unterfangen der Nachbarschaft"
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
L["The Decor Browser is not available yet."] = "Der Dekorationsbrowser ist noch nicht verfügbar."

-- Welcome window
L["Find every decor vendor on your map and see what you own before you buy."] = "Findet jeden Dekorationshändler auf Eurer Karte und seht, was Ihr besitzt, bevor Ihr kauft."
L["What Homestead Does"] = "Was Homestead kann"
L["Every decor vendor pinned on your world map and minimap, with badges showing how many items you still need per zone."] = "Jeder Dekorationshändler wird auf Eurer Weltkarte und Minikarte markiert, mit Abzeichen, die zeigen, wie viele Gegenstände Euch pro Zone noch fehlen."
L["Map Side Panel"] = "Kartenseitenleiste"
L["Click the Homestead button on the world map to open the side panel listing that zone's vendors, then click any vendor to browse their wares and see what you still need. Pop it out as a standalone window with |cFF00FF00/hs panel|r."] = "Klickt auf der Weltkarte auf den Homestead-Knopf, um die Seitenleiste mit den Händlern der Zone zu öffnen. Klickt dann auf einen Händler, um sein Angebot zu durchsuchen und zu sehen, was Euch noch fehlt. Mit |cFF00FF00/hs panel|r löst Ihr sie als eigenes Fenster ab."
L["Tooltips Expanded"] = "Erweiterte Tooltips"
L["Every item in the Housing Catalog gets tooltips showing where it comes from (vendor, quest, achievement, profession, or drop), what it costs, and what you need to unlock it, so you never have to leave the game to look something up."] = "Jeder Gegenstand im Behausungskatalog erhält Tooltips, die zeigen, woher er stammt (Händler, Quest, Erfolg, Beruf oder Beute), was er kostet und was Ihr zum Freischalten braucht – so müsst Ihr das Spiel nie verlassen, um etwas nachzuschlagen."
L["Key Commands"] = "Wichtige Befehle"
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
-- Decor Browser: states and shared parts
-------------------------------------------------------------------------------
L["Collected"] = "Gesammelt"
L["Can get now"] = "Jetzt erhältlich"
L["Requires: %s"] = "Benötigt: %s"
L["Not enough: %s"] = "Nicht genug: %s"
L["(%1$s has %2$s)"] = "(%1$s hat %2$s)"
L["Price not recorded"] = "Preis nicht erfasst"
L["%s only"] = "Nur %s"
L["Not collected"] = "Nicht gesammelt"
L["Counting…"] = "Zähle …"
L["Not confirmed"] = "Nicht bestätigt"
L["Active now"] = "Jetzt aktiv"
L["Best to get now"] = "Jetzt am besten erhältlich"
L["Search decor"] = "Dekoration suchen"
L["More vendors here"] = "Weitere Händler hier"
L["Reset filters"] = "Filter zurücksetzen"
L["Search all decor"] = "Gesamte Dekoration durchsuchen"
L["Show what's missing"] = "Fehlendes anzeigen"
L["Sort by name"] = "Nach Namen sortieren"
L["Show them"] = "Anzeigen"
L["Show vendor"] = "Händler anzeigen"
L["Report a problem"] = "Problem melden"
L["Reading your collection. This list fills in when it's ready."] = "Eure Sammlung wird gelesen. Diese Liste füllt sich, sobald sie bereit ist."
L["Reading your collection. This list fills in when it's ready, because Best to get now depends on what you own."] = "Eure Sammlung wird gelesen. Diese Liste füllt sich, sobald sie bereit ist, weil die Sortierung Jetzt am besten erhältlich davon abhängt, was Ihr besitzt."
L["Nothing missing"] = "Nichts fehlt"
L["You've collected all %d decor Homestead knows about."] = "Ihr habt alle %d Dekorationen gesammelt, die Homestead kennt."
L["Nothing you can get right now"] = "Gerade nichts erhältlich"
L["Everything you're missing needs a reputation, achievement or quest first, is sold only during an event, or is sold only to the %s."] = "Alles, was Euch fehlt, erfordert zuerst einen Ruf, einen Erfolg oder eine Quest, wird nur während eines Ereignisses verkauft oder nur an die %s."
L["Everything you're missing needs a reputation, achievement or quest first, or is sold only during an event."] = "Alles, was Euch fehlt, erfordert zuerst einen Ruf, einen Erfolg oder eine Quest oder wird nur während eines Ereignisses verkauft."
L["Collection not read yet"] = "Sammlung noch nicht gelesen"
L["Homestead hasn't read this character's decor collection yet, so it can't tell what you're missing. It reads it shortly after you log in. If this message stays, open the Housing Dashboard once."] = "Homestead hat die Dekorationssammlung dieses Charakters noch nicht gelesen und kann daher nicht sagen, was Euch fehlt. Sie wird kurz nach dem Einloggen gelesen. Bleibt diese Meldung bestehen, öffnet einmal die Behausungsübersicht."
L["These filters need your collection, which Homestead hasn't read yet. If this stays, open the Housing Dashboard once."] = "Diese Filter benötigen Eure Sammlung, die Homestead noch nicht gelesen hat. Bleibt dies so, öffnet einmal die Behausungsübersicht."
L["No results"] = "Keine Ergebnisse"
L["No decor matches these words and filters. Search looks at item names only."] = "Keine Dekoration passt zu diesen Wörtern und Filtern. Die Suche betrachtet nur Gegenstandsnamen."
L["%d hidden by '%s' (%d collected, %d %s only)."] = "%d ausgeblendet durch '%s' (%d gesammelt, %d nur %s)."
L["%d hidden by '%s' (%d collected, %d %s only, %d %s only)."] = "%d ausgeblendet durch '%s' (%d gesammelt, %d nur %s, %d nur %s)."
L["%d hidden by '%s' (%d collected)."] = "%d ausgeblendet durch '%s' (%d gesammelt)."
L["%s or the %s"] = "%s oder die %s"

-------------------------------------------------------------------------------
-- Decor Browser: Summary
-------------------------------------------------------------------------------
L["What can I get now?"] = "Was kann ich jetzt bekommen?"
L["Decor this character can buy or earn today, best first."] = "Dekoration, die dieser Charakter heute kaufen oder verdienen kann, die beste zuerst."
L["Can get now means this character can get it today: the right faction, no requirement left to meet, and enough gold or currency to pay. Gold-only and cheaper items come first. Use See all for the full list."] = "Jetzt erhältlich heißt: Dieser Charakter kann es heute bekommen, mit der richtigen Fraktion, ohne offene Voraussetzung und mit genug Gold oder Währung zum Bezahlen. Reine Goldpreise und günstigere Gegenstände stehen zuerst. „Alles anzeigen“ zeigt die ganze Liste."
L["Show"] = "Anzeigen"
L["%s and %d more"] = "%s und %d weitere"
L["See all you can get now (%d)"] = "Alles anzeigen, was jetzt erhältlich ist (%d)"
L["Here in %s: %s sells %d decor you can get now."] = "Hier in %s: %s verkauft %d Dekorationen, die jetzt erhältlich sind."
L["Sold here in %s"] = "Hier verkauft in %s"
L["Sold on %s"] = "Verkauft auf %s"
L["%s: active now"] = "%s: jetzt aktiv"
L["Gold"] = "Gold"
L["Gold only"] = "Nur Gold"
L["Gold only, no requirements left"] = "Nur Gold, keine Voraussetzungen mehr"
L["No requirements left"] = "Keine Voraussetzungen mehr"
L["%d of %d"] = "%d von %d"
L["Reading your collection"] = "Die Sammlung wird gelesen"
-- end: Summary

-------------------------------------------------------------------------------
-- Decor Browser: Catalog
-------------------------------------------------------------------------------
L["All decor"] = "Alle Dekoration"
L["Filters"] = "Filter"
L["Name"] = "Name"
L["Sort: %s"] = "Sortierung: %s"
L["Furnishings"] = "Möbel"
L["Structural"] = "Strukturen"
L["Accents"] = "Akzente"
L["Lighting"] = "Beleuchtung"
L["Neither collected nor not collected"] = "Weder gesammelt noch nicht gesammelt"
L["Sources: %s"] = "Quellen: %s"
L["Filtered: %s"] = "Gefiltert: %s"
L["(+%d more)"] = "(+%d weitere)"
-- end: Catalog

-------------------------------------------------------------------------------
-- Decor Browser: Sources
-------------------------------------------------------------------------------
L["Search vendors and zones"] = "Händler und Gebiete suchen"
L["Search achievements"] = "Erfolge suchen"
L["Search quests"] = "Quests suchen"
L["Search recipes and professions"] = "Rezepte und Berufe suchen"
L["Search drops and zones"] = "Beute und Gebiete suchen"
L["Search events"] = "Ereignisse suchen"
L["Search the Shop"] = "Im Shop suchen"
L["%d decor"] = "%d Dekorationen"
L["No decor"] = "Keine Dekoration"
L["Not active"] = "Nicht aktiv"
L["All collected"] = "Alles gesammelt"
L["%d can get now"] = "%d jetzt erhältlich"
L["Holiday event"] = "Feiertagsereignis"
L["%s only: can't buy on this character"] = "Nur %s: Auf diesem Charakter nicht kaufbar"
L["Confirmed by a scan on %s"] = "Durch einen Scan bestätigt am %s"
L["No scan has confirmed this vendor yet. Visit the vendor to check."] = "Noch kein Scan hat diesen Händler bestätigt. Besucht den Händler, um ihn zu prüfen."
L["Decor from this source"] = "Dekoration aus dieser Quelle"
L["No decor is recorded here. If this source gives decor, report it below."] = "Hier ist keine Dekoration verzeichnet. Wenn diese Quelle Dekoration gibt, meldet es unten."
L["Dig site in %s"] = "Grabungsstelle in %s"
L["No events active right now. Event decor is sold only while its event runs."] = "Gerade sind keine Ereignisse aktiv. Ereignis-Dekoration gibt es nur, solange das Ereignis läuft."
L["Nothing matches your search."] = "Nichts entspricht Eurer Suche."
L["Nothing to show here."] = "Hier gibt es nichts anzuzeigen."
L["Currency"] = "Währung"
L["Wares"] = "Waren"
L["Not confirmed: visit to check."] = "Nicht bestätigt: Besuch zur Prüfung nötig."
L["Corners: state top right, bonus top left, event bottom left, copies bottom right."] = "Ecken: Status oben rechts, Bonus oben links, Ereignis unten links, Exemplare unten rechts."
L["%s; %s"] = "%s; %s"
L["%s · %s"] = "%s · %s"
-- end: Sources

-------------------------------------------------------------------------------
-- Decor Browser: Item
-------------------------------------------------------------------------------
L["Vendor:"] = "Händler:"
L["Achievement:"] = "Erfolg:"
L["Quest:"] = "Quest:"
L["Recipe:"] = "Rezept:"
L["Drop:"] = "Beute:"
L["Event:"] = "Ereignis:"
L["Starts in %s"] = "Beginnt in %s"
L["Daily from The Last Architect"] = "Täglich von The Last Architect"
L["Can get now here"] = "Hier jetzt erhältlich"
L["Where to get it"] = "Wo man es bekommt"
L["Show achievement"] = "Erfolg zeigen"
L["Show quest"] = "Quest zeigen"
L["Show recipe"] = "Rezept zeigen"
L["Show drop"] = "Beute zeigen"
L["Show event"] = "Ereignis zeigen"
L["%s (done)"] = "%s (erledigt)"
L["%s (not yet)"] = "%s (noch nicht)"
L["Can't check this requirement yet"] = "Diese Voraussetzung kann noch nicht geprüft werden"
L["Active now: %s"] = "Jetzt aktiv: %s"
L["Decor Browser"] = "Dekorationsbrowser"
L["Show 3D preview"] = "3D-Vorschau anzeigen"
L["desc_browser_model3d"] = "Zeigt auf der Seite eines Gegenstands im Dekorationsbrowser ein 3D-Modell."
-- end: Item
