--[[
    Homestead - Locale: Italian (itIT)
    Machine-translated, contributions welcome.
]]

local _, HA = ...

if GetLocale() ~= "itIT" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["Used in %d known recipe for decor you haven't collected"] = "Usato in %d ricetta nota per decorazioni non ancora ottenute"
L["Used in %d known recipes for decor you haven't collected"] = "Usato in %d ricette note per decorazioni non ancora ottenute"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["Homestead"] = "Homestead"
L["Homestead Options"] = "Opzioni di Homestead"
L["Overlays"] = "Indicatori"
L["Tooltips"] = "Descrizioni"
L["Export"] = "Esportazione"

L["Show minimap button"] = "Mostra pulsante sulla minimappa"
L["Enable overlays"] = "Attiva indicatori"
L["Show on bags"] = "Mostra nelle sacche"
L["Show on bank"] = "Mostra in banca"
L["Show on merchant"] = "Mostra presso i mercanti"
L["Show on housing catalog"] = "Mostra nel Catalogo degli Alloggi"
L["Icon size"] = "Dimensioni icona"
L["Icon position"] = "Posizione icona"
L["Show opposite faction vendors"] = "Mostra mercanti della fazione opposta"

L["Enable tooltip additions"] = "Attiva aggiunte alle descrizioni"
L["Show source information"] = "Mostra informazioni sull'origine"
L["Show vendor details in tooltips"] = "Mostra dettagli mercante nelle descrizioni"

L["Show map pins"] = "Mostra segnalini sulla mappa"
L["Show minimap pins"] = "Mostra segnalini sulla minimappa"
L["Use TomTom for waypoints"] = "Usa TomTom per le tappe"
L["Use native waypoints"] = "Usa le tappe del gioco"
L["Auto-create waypoint on click"] = "Crea tappa automaticamente al clic"
L["Navigate modifier key"] = "Tasto modificatore per la navigazione"

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d / %d (%d%%)"] = "Raccolta: %d / %d (%d%%)"
L["Vendors nearby: %d"] = "Mercanti nelle vicinanze: %d"
L["Vendors scanned: %d"] = "Mercanti scansionati: %d"
L["Left-Click: Toggle options"] = "|cFFFFFFFFClic sinistro:|r Mostra/nascondi opzioni"
L["Right-Click: Detach/close vendor panel"] = "|cFFFFFFFFClic destro:|r Stacca/chiudi pannello mercanti"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Comandi di Homestead:"

-------------------------------------------------------------------------------
-- Slash Command Feedback
-------------------------------------------------------------------------------
L["Map pins refreshed."] = "Segnalini sulla mappa aggiornati."
L["No active waypoint."] = "Nessuna tappa attiva."
L["Waypoint cleared."] = "Tappa rimossa."
L["Vendor database contains %d vendors."] = "Il database dei mercanti contiene %d mercanti."
L["Use /hs vendor <name or zone> to search."] = "Usa /hs vendor <nome o zona> per cercare."
L["No vendors found matching: %s"] = "Nessun mercante trovato per: %s"
L["Found %d vendor(s) matching: %s"] = "Mercanti trovati (%d) per: %s"
L["... and %d more."] = "... e altri %d."

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "Modalità debug: %s"
L["ON"] = "Attivato"
L["OFF"] = "Disattivato"
L["Unknown command: %s"] = "Comando sconosciuto: %s"
L["Type /hs help for a list of commands."] = "Digita /hs help per l'elenco dei comandi."

-------------------------------------------------------------------------------
-- Version Check
-------------------------------------------------------------------------------
L["Your Homestead version is out-of-date."] = "La tua versione di Homestead non è aggiornata."
L["Version %s (%s) can be downloaded at CurseForge, Wago, or GitHub Releases."] = "La versione %s (%s) può essere scaricata da CurseForge, Wago o GitHub Releases."
L["Homestead version: %s (%s)"] = "Versione di Homestead: %s (%s)"
L["Newest version seen this session: %s (%s)"] = "Versione più recente vista in questa sessione: %s (%s)"
L["No newer version seen this session."] = "Nessuna versione più recente vista in questa sessione."
L["Version-check notifications: %s"] = "Notifiche di controllo versione: %s"

-------------------------------------------------------------------------------
-- Export Dialog
-------------------------------------------------------------------------------
L["Export Vendor Data"] = "Esporta dati dei mercanti"
L["Choose export option:"] = "Scegli un'opzione di esportazione:"
L["Export New Scans"] = "Esporta nuove scansioni"
L["Export All"] = "Esporta tutto"

-------------------------------------------------------------------------------
-- Map Side Panel
-------------------------------------------------------------------------------
L["All"] = "Tutti"
L["Vendor"] = "Mercanti"
L["Vendors"] = "Mercanti"
L["Quest"] = "Missioni"
L["Achievement"] = "Imprese"
L["Profession"] = "Professioni"
L["Event"] = "Evento"
L["Drop"] = "Bottino"
L["Treasure"] = "Tesori"
L["Zone Collection Progress"] = "Progresso raccolta della zona"
L["Continent Collection Progress"] = "Progresso raccolta del continente"
L["Global Collection Progress"] = "Progresso raccolta globale"
L["Order Hall"] = "Enclave di Classe"
L["Click to preview"] = "Clicca per l'anteprima"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "Risultato"
L["Select All"] = "Seleziona tutto"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "Tutto il testo è selezionato. Premi Ctrl+C per copiarlo negli appunti."

-------------------------------------------------------------------------------
-- Options - Names
-------------------------------------------------------------------------------
L["Vendor pin item details"] = "Dettagli oggetti nei segnalini mercante"

L["Auto-scan vendors"] = "Scansione automatica dei mercanti"
L["Vendor Visibility"] = "Visibilità dei mercanti"
L["Show event vendors"] = "Mostra mercanti degli eventi"
L["Hide fully-collected vendor pins"] = "Nascondi segnalini mercanti con tutto ottenuto"
L["Fully-collected vendors"] = "Mercanti con tutto ottenuto"
L["desc_map_filter_completed_vendors"] = "Deseleziona per nascondere i segnalini dei mercanti di cui hai ottenuto tutte le decorazioni."
L["Pin Appearance"] = "Aspetto dei segnalini"
L["Pin color"] = "Colore segnalini"
L["Custom color"] = "Colore personalizzato"
L["Show accessibility glow"] = "Mostra bagliore di accessibilità"
L["Owned item style"] = "Stile oggetti posseduti"
L["Show ownership status"] = "Mostra stato di possesso"
L["Show requirements"] = "Mostra requisiti"
L["Show all sources"] = "Mostra tutte le origini"
L["Map Pins"] = "Segnalini sulla mappa"
L["Show vendor panel on world map"] = "Mostra pannello mercanti sulla mappa"
L["Vendor panel source filter"] = "Filtro origine del pannello mercanti"
L["Integrate with map frame border"] = "Integra con il bordo della mappa"
L["Zone badges on world map"] = "Contrassegni delle zone sulla mappa"
L["World map pin size"] = "Dimensioni segnalini sulla mappa"
L["Show collection counts"] = "Mostra conteggi della raccolta"
L["Show elevation arrows"] = "Mostra frecce di altitudine"
L["Minimap nearby-zone pins"] = "Segnalini zone vicine sulla minimappa"
L["Minimap pin size"] = "Dimensioni segnalini sulla minimappa"
L["Waypoints"] = "Tappe"
L["Show milestone progress on dashboard"] = "Mostra traguardi nel Pannello dell'Alloggio"
L["Inventory"] = "Inventario"
L["Merchant"] = "Mercante"
L["Housing Catalog"] = "Catalogo degli Alloggi"

-------------------------------------------------------------------------------
-- Options - Descriptions
-------------------------------------------------------------------------------
L["desc_minimap_button"] = "Mostra o nasconde il pulsante sulla minimappa"
L["desc_auto_scan_vendors"] = "Scansiona automaticamente la merce dei mercanti che visiti per raccogliere dati sulle decorazioni degli alloggi. Disattivare l'opzione può migliorare leggermente le prestazioni quando apri la finestra di un mercante."
L["desc_options_general"] = "Comportamento principale dell'addon, accesso dalla minimappa, scansione dei mercanti e aspetto dei segnalini sulla mappa."
L["desc_options_overlays"] = "Indicatori di raccolta mostrati nelle sacche, in banca, presso i mercanti e nel Catalogo degli Alloggi."
L["desc_options_tooltips"] = "Dettagli aggiuntivi su possesso, origine, requisiti e mercanti nelle descrizioni degli oggetti e dei segnalini sulla mappa."
L["desc_options_world_map"] = "Segnalini dei mercanti sulla mappa, contrassegni delle zone, comportamento del pannello laterale e visualizzazione dei segnalini."
L["desc_options_minimap"] = "Segnalini dei mercanti vicini, frecce di altitudine e comportamento delle tappe sulla minimappa."
L["desc_options_endeavors"] = "Progresso delle Iniziative degli alloggi mostrato nel Pannello dell'Alloggio di Blizzard."
L["desc_options_export"] = "Esportazione dei dati dei mercanti scansionati per revisione o backup."
L["desc_vendor_visibility_section"] = "Scegli quali gruppi di mercanti compaiono sulle mappe e nei totali della raccolta."
L["desc_pin_appearance_section"] = "Regola il colore e l'anteprima dei segnalini dei mercanti di Homestead."
L["desc_overlay_inventory_section"] = "Mostra gli indicatori di raccolta sugli spazi degli oggetti al di fuori del Catalogo degli Alloggi."
L["desc_overlay_merchant_section"] = "Segna le decorazioni ottenute mentre sfogli la merce dei mercanti."
L["desc_overlay_catalog_section"] = "Gestisci indicatori, evidenziazioni e stile degli oggetti ottenuti nel Catalogo degli Alloggi."
L["desc_tooltip_map_pins_section"] = "Scegli quanti dettagli sui mercanti compaiono nelle descrizioni dei segnalini sulla mappa."
L["desc_minimap_waypoints_section"] = "Configura TomTom e il comportamento delle tappe native quando clicchi sulla mappa o su un mercante."
L["desc_opposite_faction"] = "Mostra i mercanti della fazione opposta con il loro emblema di fazione. Utile ai collezionisti più accaniti per vedere tutti i mercanti disponibili."
L["desc_event_vendors"] = "Mostra sulla mappa i segnalini dei mercanti delle festività stagionali quando il loro evento è attivo (es. Festa della Luna)"
L["desc_hide_completed_vendor_pins"] = "Nasconde i segnalini sulla mappa e sulla minimappa dei mercanti di cui hai ottenuto tutte le decorazioni degli alloggi. L'elenco del pannello mercanti non cambia."
L["desc_pin_color"] = "Scegli un colore per i segnalini sulla mappa e sulla minimappa."
L["desc_custom_color"] = "Scegli un colore di base personalizzato per i segnalini sulla mappa"
L["desc_enable_overlays"] = "Aggiunge piccole icone ed evidenziazioni alle decorazioni in tutto il gioco, così puoi capire a colpo d'occhio quali hai già ottenuto. Disattivando l'opzione nascondi ovunque tutti gli indicatori di Homestead."
L["desc_icon_size"] = "Regola la grandezza delle icone di raccolta sugli spazi degli oggetti."
L["desc_icon_position"] = "L'angolo dello spazio dell'oggetto in cui si trova l'icona di raccolta."
L["desc_show_on_bags"] = "Aggiunge l'icona |A:homestone-minimap-icon:16:16|a alle decorazioni nelle tue sacche, colorata per indicare se hai già ottenuto ciascuna di esse. Funziona con le sacche predefinite, Baganator e BetterBags."
L["desc_show_on_bank"] = "Segna le decorazioni nella tua banca, così puoi vedere quali hai già ottenuto."
L["desc_show_on_merchant"] = "Aggiunge l'icona |A:homestone-minimap-icon:16:16|a alle decorazioni presso i mercanti, colorata per indicare se hai già ottenuto ciascuna di esse."
L["desc_show_on_housing_catalog"] = "Segna gli oggetti nel Catalogo degli Alloggi con icone di raccolta che indicano da dove proviene ciascun oggetto.\n\n|A:auctionhouse-icon-coin-gold:16:16|a Mercanti\n|A:QuestNormal:16:16|a Missioni\n|A:UI-Achievement-Shield-NoPoints:16:16|a Imprese\n|A:UI-HUD-MicroMenu-Professions-Mouseover:16:16|a Professioni\n|A:UI-HUD-Calendar-1-Up:16:16|a Evento\n|A:Crosshair_lootall_64:16:16|a Bottino\n|A:hearthsteel-icon-32x32:16:16|a Negozio di Battle.net"
L["desc_accessibility_glow"] = "Aggiunge un bagliore colorato al bordo degli oggetti del Catalogo degli Alloggi: verde per quelli posseduti, giallo per quelli che puoi ottenere e rosso per quelli bloccati da requisiti che non hai ancora soddisfatto."
L["desc_owned_item_style"] = "Scegli come appaiono gli oggetti ottenuti nel Catalogo degli Alloggi. Evidenziazione verde mostra il bagliore predefinito, Attenuati li rende sbiaditi e Segno di spunta aggiunge un piccolo segno verde. Scegli Nessuno per lasciarli invariati."
L["desc_enable_tooltips"] = "Aggiunge informazioni di Homestead alle descrizioni degli oggetti quando passi il puntatore sulle decorazioni. Disattivando l'opzione rimuovi tutte le aggiunte alle descrizioni."
L["desc_show_ownership"] = "Aggiunge una riga alle descrizioni che indica se hai già ottenuto una decorazione."
L["desc_show_source"] = "Mostra come ottenere una decorazione: mercanti, missioni, imprese, professioni, eventi e bottino."
L["desc_show_requirements"] = "Mostra i requisiti d'acquisto, come reputazione, completamento di missioni o imprese, necessari per comprare un oggetto."
L["desc_show_all_sources"] = "Elenca tutti i modi noti per ottenere un oggetto invece della sola origine migliore disponibile. Utile quando un oggetto può essere ottenuto da più mercanti, missioni o altre origini."
L["desc_vendor_details"] = "Mostra l'intera merce di un mercante e il tuo progresso di raccolta quando passi il puntatore sul suo segnalino. Disattiva l'opzione per una descrizione più semplice con il solo nome del mercante."
L["desc_vendor_pin_item_details"] = "Nelle descrizioni dei segnalini mostra per ogni oggetto le icone delle origini alternative e il costo presso il mercante, oltre al numero di oggetti venduti solo dai mercanti. Disattiva l'opzione per una descrizione più semplice con i soli nomi degli oggetti."
L["desc_show_map_pins"] = "Mostra le posizioni dei mercanti sulla mappa"
L["desc_show_map_side_panel"] = "Mostra un pannello laterale sulla mappa con l'elenco dei mercanti e il progresso di raccolta della zona attuale"
L["desc_source_filter"] = "Filtra per origine i conteggi degli oggetti e le griglie espanse del pannello laterale. La visibilità dei mercanti sulla mappa non cambia."
L["desc_integrate_map_border"] = "Unisce il bordo superiore del pannello al bordo della mappa per un aspetto uniforme. Disattiva l'opzione se usi un'interfaccia personalizzata (ElvUI, GW2, ecc.) che crea conflitti."
L["desc_zone_badges"] = "Mostra sulla mappa il numero di mercanti di ogni zona distribuito sui continenti, invece di un unico totale per continente."
L["desc_world_pin_size"] = "Regola le dimensioni dei segnalini dei mercanti sulla mappa. Il valore predefinito (20) corrisponde alle icone dei punti d'interesse di Blizzard."
L["desc_show_pin_counts"] = "Mostra il conteggio degli oggetti ottenuti/totali sui segnalini dei mercanti (es. 3/12). Disattiva l'opzione per ridurre l'ingombro sulla mappa."
L["desc_show_minimap_pins"] = "Mostra le posizioni dei mercanti sulla minimappa con frecce di altitudine"
L["desc_elevation_arrows"] = "Mostra frecce direzionali sui segnalini della minimappa quando un mercante si trova sopra o sotto di te"
L["desc_cross_zone_mode"] = "Gestisce i segnalini della minimappa provenienti da altre zone. Automatico riduce i segnalini extra nelle zone cittadine affollate per un movimento più fluido."
L["desc_minimap_pin_size"] = "Regola le dimensioni dei segnalini dei mercanti sulla minimappa. Aumentale se i segnalini sono difficili da vedere o riducile per diminuire l'ingombro sulla minimappa."
L["desc_waypoint_info"] = "TomTom mostra una freccia direzionale in sovrimpressione e richiede l'installazione dell'addon TomTom. Le tappe native aggiungono un segnalino di destinazione sulla mappa. Entrambi i metodi possono essere attivi contemporaneamente."
L["desc_use_tomtom"] = "Usa l'addon TomTom per le frecce delle tappe (se installato)"
L["desc_use_native_waypoints"] = "Usa il sistema di tappe integrato di WoW con un punto sulla mappa"
L["desc_auto_waypoint"] = "Crea automaticamente una tappa quando clicchi su un mercante nell'elenco o sulla mappa"
L["desc_navigate_modifier"] = "Tieni premuto questo tasto mentre clicchi per creare una tappa (se la tappa automatica è disattivata)"
L["desc_milestone_xp"] = "Mostra il progresso in PE verso il prossimo traguardo nella scheda Iniziative del Pannello dell'Alloggio di Blizzard. Disattiva l'opzione se usi un altro addon per questo (es. Endeavor Simple Progress Tracker)."
L["desc_export"] = "Esporta i dati dei mercanti scansionati per backup."
L["desc_export_new"] = "Esporta i mercanti scansionati dall'ultima esportazione. Include prezzo, valute, fazione e informazioni del catalogo."
L["desc_export_all"] = "Esporta tutti i mercanti scansionati, ignorando il filtro per data."

-------------------------------------------------------------------------------
-- Options - Select Values
-------------------------------------------------------------------------------
-- Pin colors
L["Default (Gold)"] = "Predefinito (oro)"
L["Bright Green"] = "Verde brillante"
L["Ice Blue"] = "Blu ghiaccio"
L["Light Blue"] = "Azzurro"
L["Purple"] = "Viola"
L["Pink"] = "Rosa"
L["Red"] = "Rosso"
L["Cyan"] = "Ciano"
L["White"] = "Bianco"
L["Yellow"] = "Giallo"
L["Custom..."] = "Personalizzato..."

-- Icon anchor positions
L["Top Left"] = "In alto a sinistra"
L["Top Right"] = "In alto a destra"
L["Bottom Left"] = "In basso a sinistra"
L["Bottom Right"] = "In basso a destra"
L["Center"] = "Al centro"

-- Owned item styles
L["Green highlight (default)"] = "Evidenziazione verde (predefinito)"
L["None"] = "Nessuno"
L["Dimmed"] = "Attenuati"
L["Checkmark"] = "Segno di spunta"

-- Source filter
L["All sources"] = "Tutte le origini"

-- Minimap cross-zone mode
L["Auto (recommended)"] = "Automatico (consigliato)"
L["Current zone only"] = "Solo zona attuale"
L["Always show nearby zones"] = "Mostra sempre le zone vicine"

-- Navigate modifier
L["None (always)"] = "Nessuno (sempre)"

-- Misc
L["Approximate map appearance"] = "Aspetto approssimativo sulla mappa"
L["ExportImport not available."] = "ExportImport non disponibile."
