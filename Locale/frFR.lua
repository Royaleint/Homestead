--[[
    Homestead - Locale: French (FR)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "frFR" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["Used in %d known recipe for decor you haven't collected"] = "Utilisé dans %d recette connue pour un élément de décoration non obtenu"
L["Used in %d known recipes for decor you haven't collected"] = "Utilisé dans %d recettes connues pour des éléments de décoration non obtenus"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["Homestead"] = "Homestead"
L["Homestead Options"] = "Options de Homestead"
L["Overlays"] = "Marqueurs"
L["Tooltips"] = "Encadrés d’aide"
L["Export"] = "Exportation"

L["Show minimap button"] = "Afficher le bouton de la minicarte"
L["Enable overlays"] = "Activer les marqueurs"
L["Show on bags"] = "Afficher dans les sacs"
L["Show on bank"] = "Afficher dans la banque"
L["Show on merchant"] = "Afficher chez les marchands"
L["Show on housing catalog"] = "Afficher dans le catalogue des logis"
L["Icon size"] = "Taille des icônes"
L["Icon position"] = "Position des icônes"
L["Show opposite faction vendors"] = "Afficher les vendeurs de la faction adverse"

L["Enable tooltip additions"] = "Activer les ajouts aux bulles d’aide"
L["Show source information"] = "Afficher les informations sur les sources"
L["Show vendor details in tooltips"] = "Détails des vendeurs (bulles d’aide)"

L["Show map pins"] = "Afficher les repères sur la carte"
L["Show minimap pins"] = "Afficher les repères sur la minicarte"
L["Use TomTom for waypoints"] = "Utiliser TomTom pour les points de passage"
L["Use native waypoints"] = "Utiliser les points de passage du jeu"
L["Auto-create waypoint on click"] = "Créer un point de passage au clic"
L["Navigate modifier key"] = "Touche de modification (navigation)"

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d / %d (%d%%)"] = "Collection : %d / %d (%d%%)"
L["Vendors nearby: %d"] = "Vendeurs à proximité : %d"
L["Vendors scanned: %d"] = "Vendeurs analysés : %d"
L["Left-Click: Toggle Decor Browser"] = "|cFFFFFFFFClic gauche :|r Afficher/masquer le navigateur de décoration"
L["Right-Click: Open options"] = "|cFFFFFFFFClic droit :|r Ouvrir les options"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Commandes de Homestead :"

-------------------------------------------------------------------------------
-- Slash Command Feedback
-------------------------------------------------------------------------------
L["Map pins refreshed."] = "Repères de la carte actualisés."
L["No active waypoint."] = "Aucun point de passage actif."
L["Waypoint cleared."] = "Point de passage supprimé."
L["Vendor database contains %d vendors."] = "La base de données des vendeurs contient %d vendeurs."
L["Use /hs vendor <name or zone> to search."] = "Utilisez /hs vendor <nom ou zone> pour rechercher."
L["No vendors found matching: %s"] = "Aucun vendeur ne correspond à : %s"
L["Found %d vendor(s) matching: %s"] = "%d vendeur(s) trouvé(s) pour : %s"
L["... and %d more."] = "... et %d de plus."

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "Mode débogage : %s"
L["ON"] = "Activé"
L["OFF"] = "Désactivé"
L["Unknown command: %s"] = "Commande inconnue : %s"
L["Type /hs help for a list of commands."] = "Tapez /hs help pour afficher la liste des commandes."

-------------------------------------------------------------------------------
-- Version Check
-------------------------------------------------------------------------------
L["Your Homestead version is out-of-date."] = "Votre version de Homestead est obsolète."
L["Version %s (%s) can be downloaded at CurseForge, Wago, or GitHub Releases."] = "La version %s (%s) peut être téléchargée sur CurseForge, Wago ou GitHub Releases."
L["Homestead version: %s (%s)"] = "Version de Homestead : %s (%s)"
L["Newest version seen this session: %s (%s)"] = "Version la plus récente vue durant cette session : %s (%s)"
L["No newer version seen this session."] = "Aucune version plus récente vue durant cette session."
L["Version-check notifications: %s"] = "Notifications de vérification de version : %s"

-------------------------------------------------------------------------------
-- Export Dialog
-------------------------------------------------------------------------------
L["Export Vendor Data"] = "Exporter les données des vendeurs"
L["Choose export option:"] = "Choisissez une option d’exportation :"
L["Export New Scans"] = "Exporter les nouvelles analyses"
L["Export All"] = "Tout exporter"

-------------------------------------------------------------------------------
-- Map Side Panel
-------------------------------------------------------------------------------
L["All"] = "Tout"
L["Vendor"] = "Vendeur"
L["Vendors"] = "Vendeurs"
L["Quest"] = "Quête"
L["Achievement"] = "Haut fait"
L["Profession"] = "Métier"
L["Event"] = "Évènement"
L["Drop"] = "Butin"
L["Treasure"] = "Trésor"
L["Zone Collection Progress"] = "Progression de la collection de la zone"
L["Continent Collection Progress"] = "Progression de la collection du continent"
L["Global Collection Progress"] = "Progression globale de la collection"
L["Order Hall"] = "Domaine de classe"
L["Click to preview"] = "Cliquez pour afficher un aperçu"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "Résultat"
L["Select All"] = "Tout sélectionner"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "Tout le texte est sélectionné. Appuyez sur Ctrl+C pour le copier dans le presse-papiers."

-------------------------------------------------------------------------------
-- Options - Names
-------------------------------------------------------------------------------
L["Vendor pin item details"] = "Détails des objets (repères de vendeur)"

L["Auto-scan vendors"] = "Analyser automatiquement les vendeurs"
L["Vendor Visibility"] = "Visibilité des vendeurs"
L["Show event vendors"] = "Afficher les vendeurs d’évènement"
L["Hide fully-collected vendor pins"] = "Ne pas marquer un vendeur si tout est obtenu"
L["Fully-collected vendors"] = "Vendeurs dont tout est obtenu"
L["desc_map_filter_completed_vendors"] = "Décochez pour masquer les repères des vendeurs dont vous avez obtenu tous les éléments de décoration."
L["Pin Appearance"] = "Apparence des repères"
L["Pin color"] = "Couleur des repères"
L["Custom color"] = "Couleur personnalisée"
L["Show accessibility glow"] = "Afficher la lueur d’accessibilité"
L["Owned item style"] = "Style des objets possédés"
L["Show ownership status"] = "Afficher le statut de possession"
L["Show requirements"] = "Afficher les prérequis"
L["Show all sources"] = "Afficher toutes les sources"
L["Map Pins"] = "Repères de la carte"
L["Show vendor panel on world map"] = "Panneau des vendeurs sur la carte du monde"
L["Vendor panel source filter"] = "Filtre de sources du panneau des vendeurs"
L["Integrate with map frame border"] = "Intégrer à la bordure de la carte"
L["Zone badges on world map"] = "Badges de zone sur la carte du monde"
L["World map pin size"] = "Taille des repères sur la carte du monde"
L["Show collection counts"] = "Afficher les compteurs de collection"
L["Show elevation arrows"] = "Afficher les flèches d’altitude"
L["Minimap nearby-zone pins"] = "Minicarte : repères des zones voisines"
L["Minimap pin size"] = "Taille des repères sur la minicarte"
L["Waypoints"] = "Points de passage"
L["Show milestone progress on dashboard"] = "Paliers dans le tableau de bord des logis"
L["Inventory"] = "Inventaire"
L["Merchant"] = "Marchand"
L["Housing Catalog"] = "Catalogue des logis"

-------------------------------------------------------------------------------
-- Options - Descriptions
-------------------------------------------------------------------------------
L["desc_minimap_button"] = "Affiche ou masque le bouton de la minicarte"
L["desc_auto_scan_vendors"] = "Analyse automatiquement l’inventaire des marchands pour relever les éléments de décoration de logis lors de vos visites chez les vendeurs. La désactivation peut légèrement améliorer les performances à l’ouverture des marchands."
L["desc_options_general"] = "Comportement général de l’addon, accès par la minicarte, analyse des vendeurs et apparence des repères."
L["desc_options_overlays"] = "Marqueurs de collection affichés sur les sacs, la banque, les marchands et le catalogue des logis."
L["desc_options_tooltips"] = "Détails supplémentaires sur la possession, les sources, les prérequis et les vendeurs, ajoutés aux bulles d’aide des objets et des repères."
L["desc_options_world_map"] = "Repères des vendeurs sur la carte du monde, badges de zone, comportement du panneau latéral et affichage des repères."
L["desc_options_minimap"] = "Repères des vendeurs à proximité, flèches d’altitude et comportement des points de passage sur la minicarte."
L["desc_options_endeavors"] = "Progression des initiatives de logis affichée dans le tableau de bord des logis de Blizzard."
L["desc_options_export"] = "Exportation des données des vendeurs analysés, pour vérification ou sauvegarde."
L["desc_vendor_visibility_section"] = "Choisissez quels groupes de vendeurs apparaissent sur les cartes et dans les totaux de collection."
L["desc_pin_appearance_section"] = "Réglez la couleur et l’aperçu des repères de vendeurs de Homestead."
L["desc_overlay_inventory_section"] = "Affiche les marqueurs de collection sur les emplacements d’objets hors du catalogue des logis."
L["desc_overlay_merchant_section"] = "Marque les éléments de décoration obtenus lorsque vous parcourez les objets des vendeurs."
L["desc_overlay_catalog_section"] = "Gérez les marqueurs, les surbrillances et le style des objets obtenus dans le catalogue des logis."
L["desc_tooltip_map_pins_section"] = "Choisissez le niveau de détail sur les vendeurs dans les bulles d’aide des repères."
L["desc_minimap_waypoints_section"] = "Configurez TomTom et les points de passage du jeu lors des clics sur la carte et sur les vendeurs."
L["desc_opposite_faction"] = "Affiche les vendeurs de la faction adverse avec l’emblème de leur faction. Utile pour les collectionneurs qui veulent voir tous les vendeurs disponibles."
L["desc_event_vendors"] = "Affiche sur la carte les repères des vendeurs des évènements saisonniers lorsque leur évènement est actif (par ex. Fête lunaire)"
L["desc_hide_completed_vendor_pins"] = "Masque les repères sur la carte et la minicarte des vendeurs dont vous avez obtenu tous les éléments de décoration de logis. La liste du panneau des vendeurs n’est pas affectée."
L["desc_pin_color"] = "Choisissez une couleur pour les repères de la carte et de la minicarte."
L["desc_custom_color"] = "Choisissez une couleur de base personnalisée pour les repères de la carte"
L["desc_enable_overlays"] = "Ajoute de petites icônes et des surbrillances aux éléments de décoration partout dans le jeu pour voir d’un coup d’œil ceux que vous avez obtenus. Désactiver cette option masque tous les marqueurs de Homestead."
L["desc_icon_size"] = "Règle la taille des icônes de collection sur les emplacements d’objets."
L["desc_icon_position"] = "Coin de l’emplacement d’objet où se trouve l’icône de collection."
L["desc_show_on_bags"] = "Ajoute une icône |A:homestone-minimap-icon:16:16|a aux éléments de décoration de vos sacs, colorée pour indiquer si vous avez obtenu chacun d’eux. Fonctionne avec les sacs par défaut, Baganator et BetterBags."
L["desc_show_on_bank"] = "Marque les éléments de décoration de votre banque pour voir ceux que vous avez déjà obtenus."
L["desc_show_on_merchant"] = "Ajoute une icône |A:homestone-minimap-icon:16:16|a aux éléments de décoration des vendeurs, colorée pour indiquer si vous avez obtenu chacun d’eux."
L["desc_show_on_housing_catalog"] = "Marque les objets du catalogue des logis avec des icônes de collection indiquant l’origine de chaque objet.\n\n|A:auctionhouse-icon-coin-gold:16:16|a Vendeur\n|A:QuestNormal:16:16|a Quête\n|A:UI-Achievement-Shield-NoPoints:16:16|a Haut fait\n|A:UI-HUD-MicroMenu-Professions-Mouseover:16:16|a Métier\n|A:UI-HUD-Calendar-1-Up:16:16|a Évènement\n|A:Crosshair_lootall_64:16:16|a Butin\n|A:hearthsteel-icon-32x32:16:16|a Boutique Battle.net"
L["desc_accessibility_glow"] = "Ajoute une lueur colorée en bordure des objets du catalogue des logis : vert pour les objets possédés, jaune pour ceux que vous pouvez obtenir et rouge pour ceux bloqués par des prérequis que vous ne remplissez pas encore."
L["desc_owned_item_style"] = "Choisissez l’apparence des objets obtenus dans le catalogue des logis. Surbrillance verte affiche la lueur par défaut, Atténué les estompe et Coche ajoute une petite coche verte. Choisissez Aucun pour les laisser inchangés."
L["desc_enable_tooltips"] = "Ajoute les informations de Homestead aux bulles d’aide des objets lorsque vous survolez des éléments de décoration. Désactiver cette option supprime tous les ajouts aux bulles d’aide."
L["desc_show_ownership"] = "Ajoute une ligne aux bulles d’aide indiquant si vous avez déjà obtenu un élément de décoration."
L["desc_show_source"] = "Indique comment obtenir un élément de décoration : vendeurs, quêtes, hauts faits, métiers, évènements et butin."
L["desc_show_requirements"] = "Affiche les prérequis d’achat, comme la réputation, l’accomplissement de quêtes ou les hauts faits nécessaires pour acheter un objet."
L["desc_show_all_sources"] = "Liste toutes les façons connues d’obtenir un objet au lieu de la seule meilleure source disponible. Utile quand un objet peut s’obtenir auprès de plusieurs vendeurs, quêtes ou autres sources."
L["desc_vendor_details"] = "Affiche l’inventaire complet d’un vendeur et votre progression de collection lorsque vous survolez son repère. Désactivez pour une bulle d’aide plus simple avec le seul nom du vendeur."
L["desc_vendor_pin_item_details"] = "Affiche dans les bulles d’aide des repères les icônes des autres sources de chaque objet et son coût chez le vendeur, ainsi que le nombre d’objets disponibles uniquement chez un vendeur. Désactivez pour une bulle d’aide plus simple listant seulement le nom des objets."
L["desc_show_map_pins"] = "Affiche l’emplacement des vendeurs sur la carte du monde"
L["desc_show_map_side_panel"] = "Affiche à côté de la carte du monde un panneau latéral listant les vendeurs et la progression de collection de la zone actuelle"
L["desc_source_filter"] = "Filtre les nombres d’objets du panneau latéral et les grilles développées selon la source d’obtention. La visibilité des vendeurs sur la carte n’est pas modifiée."
L["desc_integrate_map_border"] = "Fusionne la bordure supérieure du panneau avec celle de la carte du monde pour un rendu homogène. Désactivez si vous utilisez une interface personnalisée (ElvUI, GW2, etc.) qui entre en conflit."
L["desc_zone_badges"] = "Affiche sur la carte du monde le nombre de vendeurs par zone, réparti sur les continents, au lieu d’un total unique par continent."
L["desc_world_pin_size"] = "Règle la taille des repères de vendeurs sur la carte du monde. La valeur par défaut (20) correspond aux icônes de points d’intérêt de Blizzard."
L["desc_show_pin_counts"] = "Affiche le nombre d’objets obtenus/total sur les repères de vendeurs (par ex. 3/12). Désactivez pour alléger la carte."
L["desc_show_minimap_pins"] = "Affiche l’emplacement des vendeurs sur la minicarte avec des flèches d’altitude"
L["desc_elevation_arrows"] = "Affiche des flèches directionnelles sur les repères de la minicarte lorsqu’un vendeur se trouve au-dessus ou en dessous de vous"
L["desc_cross_zone_mode"] = "Gère les repères de la minicarte provenant d’autres zones. Auto réduit les repères supplémentaires dans les zones urbaines denses pour des déplacements plus fluides."
L["desc_minimap_pin_size"] = "Règle la taille des repères de vendeurs sur la minicarte. Augmentez-la si les repères sont difficiles à voir, ou réduisez-la pour alléger la minicarte."
L["desc_waypoint_info"] = "TomTom affiche une flèche directionnelle à l’écran et nécessite l’installation de l’addon TomTom. Le système du jeu ajoute un repère de destination sur la carte du monde. Les deux peuvent être actifs en même temps."
L["desc_use_tomtom"] = "Utilise l’addon TomTom pour les flèches de points de passage (s’il est installé)"
L["desc_use_native_waypoints"] = "Utilise le système de points de passage intégré de WoW avec un repère cartographique"
L["desc_auto_waypoint"] = "Crée automatiquement un point de passage lorsque vous cliquez sur un vendeur dans la liste ou sur la carte"
L["desc_navigate_modifier"] = "Maintenez cette touche en cliquant pour créer un point de passage (si la création automatique est désactivée)"
L["desc_milestone_xp"] = "Affiche la progression en EXP du prochain palier dans l’onglet Initiatives du tableau de bord des logis de Blizzard. Désactivez si vous utilisez un autre addon pour cela (par ex. Endeavor Simple Progress Tracker)."
L["desc_export"] = "Exporte les données des vendeurs analysés pour sauvegarde."
L["desc_export_new"] = "Exporte les vendeurs analysés depuis votre dernière exportation. Inclut le prix, les monnaies, la faction et les infos du catalogue."
L["desc_export_all"] = "Exporte tous les vendeurs analysés, sans tenir compte du filtre d’horodatage."

-------------------------------------------------------------------------------
-- Options - Select Values
-------------------------------------------------------------------------------
-- Pin colors
L["Default (Gold)"] = "Par défaut (or)"
L["Bright Green"] = "Vert vif"
L["Ice Blue"] = "Bleu glacier"
L["Light Blue"] = "Bleu clair"
L["Purple"] = "Violet"
L["Pink"] = "Rose"
L["Red"] = "Rouge"
L["Cyan"] = "Bleu cyan"
L["White"] = "Blanc"
L["Yellow"] = "Jaune"
L["Custom..."] = "Personnalisée..."

-- Icon anchor positions
L["Top Left"] = "En haut à gauche"
L["Top Right"] = "En haut à droite"
L["Bottom Left"] = "En bas à gauche"
L["Bottom Right"] = "En bas à droite"
L["Center"] = "Centre"

-- Owned item styles
L["Green highlight (default)"] = "Surbrillance verte (par défaut)"
L["None"] = "Aucun"
L["Dimmed"] = "Atténué"
L["Checkmark"] = "Coche"

-- Source filter
L["All sources"] = "Toutes les sources"

-- Minimap cross-zone mode
L["Auto (recommended)"] = "Auto (recommandé)"
L["Current zone only"] = "Zone actuelle uniquement"
L["Always show nearby zones"] = "Toujours afficher les zones voisines"

-- Navigate modifier
L["None (always)"] = "Aucune (toujours)"

-- Misc
L["Approximate map appearance"] = "Aperçu approximatif sur la carte"
L["ExportImport not available."] = "ExportImport n’est pas disponible."

-------------------------------------------------------------------------------
-- Decor Browser: data adapter
-------------------------------------------------------------------------------
L["Unknown"] = "Inconnu"
L["A vendor"] = "Un marchand"
L["Required"] = "Requis"
L["Unknown faction"] = "Faction inconnue"
L["Other requirement"] = "Autre prérequis"
L["Source unknown"] = "Source inconnue"
L["Item %d"] = "Objet %d"
L["%s %s"] = "%s %s"
L["%s, %s"] = "%s, %s"
L["%s - %s"] = "%s - %s"
L["%s: %s"] = "%s: %s"
L["%s with %s"] = "%s auprès de %s"
L["Level %s"] = "Niveau %s"
L["Achievement: %s"] = "Haut fait : %s"
L["Quest: %s"] = "Quête : %s"
L["Promotion: %s"] = "Promotion : %s"
L["Profession: %s"] = "Métier : %s"
L["Profession: %s rank %s"] = "Métier : %s, rang %s"
L["Vendor: %s"] = "Vendeur : %s"
L["Vendor: %s, %s"] = "Vendeur : %s, %s"
L["Crafted: %s - %s"] = "Fabriqué : %s - %s"
L["Drops from %s"] = "Butin de %s"
L["Drops from %s (%s)"] = "Butin de %s (%s)"
L["Event: %s"] = "Évènement : %s"
L["Event: %s - %s"] = "Évènement : %s - %s"
L["Other source"] = "Autre source"

-- Decor Browser: visuals and widgets
L["Set waypoint"] = "Placer un point de passage"

-- Decor Browser: window and navigation
L["Homestead Decor"] = "Décor Homestead"
L["Overview"] = "Aperçu"
L["Catalog"] = "Catalogue"
L["Back"] = "Retour"
L["Other Vendors"] = "Autres vendeurs"
L["%d of %d decor collected"] = "%d décors collectés sur %d"
L["%d of %d collected"] = "%d sur %d collectés"
L["Help"] = "Aide"
L["Hide what doesn't apply to me"] = "Masquer ce qui ne me concerne pas"
L["The Decor Browser opens once Homestead has finished loading."] = "Le navigateur de décoration s’ouvrira une fois Homestead entièrement chargé."
L["Collection"] = "Collection"
L["Placed"] = "Posés"
L["In storage"] = "En réserve"
L["Not yet redeemed"] = "Pas encore récupéré"
L["Counts not loaded yet"] = "Totaux pas encore chargés"
L["Source"] = "Source"
L["Price"] = "Prix"

-- Decor Browser: shop and item pages
L["Seasonal: %s"] = "Saisonnier : %s"
L["Rotates with the %s Endeavor"] = "Change avec l’initiative %s"
L["Rotates with neighborhood Endeavors"] = "Change avec les initiatives du quartier"
L["Not available in combat"] = "Indisponible en combat"
L["Report a data error"] = "Signaler une erreur de données"
L["Item: %s (%d)"] = "Objet : %s (%d)"
L["Record ID: %s"] = "ID d’enregistrement : %s"
L["none"] = "aucun"
L["no location"] = "aucun emplacement"
L["map %d at %.1f, %.1f"] = "carte %d en %.1f, %.1f"
L["Vendor %d: %s, %s, %s"] = "Vendeur %d : %s, %s, %s"
L["Client: %s (%s)"] = "Client : %s (%s)"
L["Homestead: %s"] = "Homestead : %s"

-- Decor Browser: entry points
L["Toggle Decor Browser"] = "Afficher/masquer le navigateur de décoration"
L["Open the Decor Browser, or bind a key under Keybindings > Homestead"] = "Ouvre le navigateur de décoration, ou assignez une touche dans Raccourcis > Homestead"
L["Minimap button"] = "Bouton de la minicarte"
L["Left-click opens the Decor Browser, right-click opens options"] = "Le clic gauche ouvre le navigateur de décoration, le clic droit ouvre les options"
L["The Decor Browser is not available yet."] = "Le navigateur de décoration n’est pas encore disponible."

-- Welcome window
L["Find every decor vendor on your map and see what you own before you buy."] = "Trouvez chaque vendeur de décoration sur votre carte et voyez ce que vous possédez avant d’acheter."
L["What Homestead Does"] = "Ce que fait Homestead"
L["Every decor vendor pinned on your world map and minimap, with badges showing how many items you still need per zone."] = "Chaque vendeur de décoration est repéré sur votre carte du monde et votre minicarte, avec des pastilles indiquant combien d’objets il vous reste à obtenir par zone."
L["Map Side Panel"] = "Panneau latéral de la carte"
L["Click the Homestead button on the world map to open the side panel listing that zone's vendors, then click any vendor to browse their wares and see what you still need. Pop it out as a standalone window with |cFF00FF00/hs panel|r."] = "Cliquez sur le bouton Homestead de la carte du monde pour ouvrir le panneau latéral listant les vendeurs de la zone, puis cliquez sur un vendeur pour parcourir ses marchandises et voir ce qu’il vous manque. Détachez-le en fenêtre indépendante avec |cFF00FF00/hs panel|r."
L["Tooltips Expanded"] = "Encadrés d’aide enrichis"
L["Every item in the Housing Catalog gets tooltips showing where it comes from (vendor, quest, achievement, profession, or drop), what it costs, and what you need to unlock it, so you never have to leave the game to look something up."] = "Chaque objet du catalogue des logis affiche un encadré d’aide indiquant son origine (vendeur, quête, haut fait, métier ou butin), son prix et ce qu’il faut pour le débloquer, afin de ne jamais avoir à quitter le jeu pour vous renseigner."
L["Key Commands"] = "Commandes principales"
L["Export everything you've scanned"] = "Exporter tout ce que vous avez analysé"
L["Show all commands"] = "Afficher toutes les commandes"
L["Found a Problem?"] = "Un problème ?"
L["Report bugs or wrong vendor info on GitHub using the link below."] = "Signalez les bugs ou les informations erronées sur les vendeurs sur GitHub via le lien ci-dessous."
L["Report issues (GitHub):"] = "Signaler un problème (GitHub) :"
L["CurseForge:"] = "CurseForge :"
L["Don't show this again"] = "Ne plus afficher"
L["Let's Decorate!"] = "À vos décors !"

-------------------------------------------------------------------------------
-- Decor Browser: source and vendor labels
-------------------------------------------------------------------------------
L["Achievements"] = "Hauts faits"
L["Quests"] = "Quêtes"
L["Professions"] = "Métiers"
L["Drops"] = "Butins"
L["Events"] = "Évènements"
L["Other"] = "Autre"
L["Location not recorded"] = "Emplacement non enregistré"
L["Requires"] = "Nécessite"

-------------------------------------------------------------------------------
-- Decor Browser: states and shared parts
-------------------------------------------------------------------------------
L["Collected"] = "Collecté"
L["Can get now"] = "Obtenable maintenant"
L["Requires: %s"] = "Requiert : %s"
L["%s only"] = "%s uniquement"
L["Not collected"] = "Non collecté"
L["Counting…"] = "Décompte…"
L["Not confirmed"] = "Non confirmé"
L["Active now"] = "Actif maintenant"
L["Best to get now"] = "Meilleur à obtenir maintenant"
L["Search decor by name"] = "Rechercher un décor par nom"
L["Search decor"] = "Rechercher un décor"
L["More vendors here"] = "Plus de vendeurs ici"
L["Reset filters"] = "Réinitialiser les filtres"
L["Search all decor"] = "Rechercher dans tous les décors"
L["Show what's missing"] = "Afficher ce qui manque"
L["Sort by name"] = "Trier par nom"
L["Show them"] = "Les afficher"
L["Show vendor"] = "Afficher le marchand"
L["Report a problem"] = "Signaler un problème"
L["Reading your collection. This list fills in when it's ready."] = "Lecture de votre collection. Cette liste se remplira dès que ce sera prêt."
L["Reading your collection. This list fills in when it's ready, because Best to get now depends on what you own."] = "Lecture de votre collection. Cette liste se remplira dès que ce sera prêt, car Meilleur à obtenir maintenant dépend de ce que vous possédez."
L["Nothing missing"] = "Rien ne manque"
L["You've collected all %d decor Homestead knows about."] = "Vous avez collecté les %d décors que Homestead connaît."
L["Nothing you can get right now"] = "Rien d'obtenable pour le moment"
L["Everything you're missing needs a reputation, achievement or quest first, is sold only during an event, or is sold only to the %s."] = "Tout ce qui vous manque exige d'abord une réputation, un haut fait ou une quête, n'est vendu que pendant un événement, ou n'est vendu qu'à l'autre faction (%s)."
L["Everything you're missing needs a reputation, achievement or quest first, or is sold only during an event."] = "Tout ce qui vous manque exige d'abord une réputation, un haut fait ou une quête, ou n'est vendu que pendant un événement."
L["Collection not read yet"] = "Collection non lue"
L["Homestead hasn't read this character's decor collection yet, so it can't tell what you're missing. It reads it shortly after you log in. If this message stays, open the Housing Dashboard once."] = "Homestead n'a pas encore lu la collection de décors de ce personnage et ne peut donc pas savoir ce qui vous manque. Elle est lue peu après la connexion. Si ce message persiste, ouvrez une fois le tableau de bord de l'habitation."
L["These filters need your collection, which Homestead hasn't read yet. If this stays, open the Housing Dashboard once."] = "Ces filtres ont besoin de votre collection, que Homestead n'a pas encore lue. Si cela persiste, ouvrez une fois le tableau de bord de l'habitation."
L["No results"] = "Aucun résultat"
L["No decor matches these words and filters. Search looks at item names only."] = "Aucun décor ne correspond à ces mots et à ces filtres. La recherche ne porte que sur les noms d'objets."
L["%d hidden by '%s' (%d collected, %d %s only)."] = "%d masqués par '%s' (%d collectés, %d pour %s uniquement)."
L["%d hidden by '%s' (%d collected, %d %s only, %d %s only)."] = "%d masqués par '%s' (%d collectés, %d pour %s uniquement, %d pour %s uniquement)."
L["%d hidden by '%s' (%d collected)."] = "%d masqués par '%s' (%d collectés)."
L["%s or the %s"] = "%s ou %s"

-------------------------------------------------------------------------------
-- Decor Browser: Summary
-------------------------------------------------------------------------------
L["What can I get now?"] = "Que puis-je obtenir maintenant ?"
L["Decor this character can buy or earn today, best first."] = "Les décors que ce personnage peut acheter ou gagner aujourd'hui, les meilleurs d'abord."
L["Can get now means this character can buy or earn it today: the right faction, and no requirement left to meet. The closest ones come first. Use See all for the full list."] = "Obtenable maintenant signifie que ce personnage peut l'acheter ou le gagner aujourd'hui : bonne faction et plus aucune condition à remplir. Les plus proches viennent en premier. Utilisez Tout afficher pour voir la liste complète."
L["Search"] = "Rechercher"
L["Show"] = "Afficher"
L["Not yet: next step"] = "Pas encore : prochaine étape"
L["%s and %d more"] = "%s et %d autre(s)"
L["See all you can get now (%d)"] = "Afficher tout ce que vous pouvez obtenir maintenant (%d)"
L["Here in %s: %s sells %d decor you can get now."] = "Ici, à %s : %s vend %d décors que vous pouvez obtenir maintenant."
L["Sold here in %s"] = "Vendu ici, à %s"
L["Sold on %s"] = "Vendu sur %s"
L["%s: active now"] = "%s : actif maintenant"
L["Gold only"] = "Or uniquement"
L["Gold only, no requirements left"] = "Or uniquement, plus aucune condition"
L["No requirements left"] = "Plus aucune condition"
L["By source"] = "Par source"
L["%d of %d"] = "%d sur %d"
L["Not read yet"] = "Pas encore lu"
L["Reading your collection"] = "Lecture de votre collection"
-- end: Summary

-------------------------------------------------------------------------------
-- Decor Browser: Catalog
-------------------------------------------------------------------------------
L["All decor"] = "Tous les décors"
L["Filters"] = "Filtres"
L["Name"] = "Nom"
L["Sort: %s"] = "Tri : %s"
L["Furnishings"] = "Mobilier"
L["Structural"] = "Structures"
L["Accents"] = "Accents"
L["Lighting"] = "Éclairage"
L["Neither collected nor not collected"] = "Ni collecté ni non collecté"
L["Sources: %s"] = "Provenances : %s"
L["Filtered: %s"] = "Filtré : %s"
L["(+%d more)"] = "(+%d autres)"
-- end: Catalog

-------------------------------------------------------------------------------
-- Decor Browser: Sources
-------------------------------------------------------------------------------
L["Search vendors and zones"] = "Rechercher marchands et zones"
L["Search achievements"] = "Rechercher des hauts faits"
L["Search quests"] = "Rechercher des quêtes"
L["Search recipes and professions"] = "Rechercher recettes et métiers"
L["Search drops and zones"] = "Rechercher butins et zones"
L["Search events"] = "Rechercher des évènements"
L["Search the Shop"] = "Rechercher dans la boutique"
L["Here in %s"] = "Ici, à %s"
L["%d decor"] = "%d décors"
L["No decor"] = "Aucun décor"
L["Not active"] = "Inactif"
L["All collected"] = "Tout collecté"
L["%d can get now"] = "%d obtenables maintenant"
L["Holiday event"] = "Évènement festif"
L["%s only: can't buy on this character"] = "%s uniquement : achat impossible avec ce personnage"
L["%s vendor"] = "Marchand (%s)"
L["Confirmed by a scan on %s"] = "Confirmé par un scan le %s"
L["No scan has confirmed this vendor yet. Visit the vendor to check."] = "Aucun scan n'a encore confirmé ce marchand. Rendez-lui visite pour vérifier."
L["Sells %d decor."] = "Vend %d décors."
L["Gives %d decor."] = "Donne %d décors."
L["You have %d."] = "Vous en avez %d."
L["%d you can get now."] = "Vous pouvez en obtenir %d maintenant."
L["Decor sold here"] = "Décors vendus ici"
L["Decor from this source"] = "Décors de cette source"
L["No decor is recorded here. If this source gives decor, report it below."] = "Aucun décor n'est enregistré ici. Si cette source donne des décors, signalez-le ci-dessous."
L["Pick a source to see its decor."] = "Choisissez une source pour voir ses décors."
L["Dig site in %s"] = "Site de fouille à %s"
L["No model shown"] = "Aucun modèle affiché"
L["No events active right now. Event decor is sold only while its event runs."] = "Aucun évènement actif pour le moment. Les décors d'évènement ne sont vendus que pendant l'évènement."
L["Nothing matches your search."] = "Rien ne correspond à votre recherche."
L["Nothing to show here."] = "Rien à afficher ici."
-- end: Sources

-------------------------------------------------------------------------------
-- Decor Browser: Item
-------------------------------------------------------------------------------
L["Vendor:"] = "Vendeur :"
L["Zone:"] = "Zone :"
L["Cost:"] = "Coût :"
L["Achievement:"] = "Haut fait :"
L["Quest:"] = "Quête :"
L["Recipe:"] = "Recette :"
L["Profession:"] = "Métier :"
L["Drop:"] = "Butin :"
L["Event:"] = "Évènement :"
L["Starts in %s"] = "Commence à %s"
L["Daily from The Last Architect"] = "Quotidienne de The Last Architect"
L["Set dig site waypoint"] = "Placer un point de repère sur le site de fouille"
L["Can get now here"] = "Disponible maintenant ici"
L["Where to get it"] = "Où l'obtenir"
L["Show achievement"] = "Afficher le haut fait"
L["Show quest"] = "Afficher la quête"
L["Show recipe"] = "Afficher la recette"
L["Show drop"] = "Afficher le butin"
L["Show event"] = "Afficher l'évènement"
L["%s (done)"] = "%s (fait)"
L["%s (not yet)"] = "%s (pas encore)"
L["Can't check this requirement yet"] = "Impossible de vérifier ce prérequis pour l'instant"
L["Active now: %s"] = "Actif maintenant : %s"
-- end: Item
