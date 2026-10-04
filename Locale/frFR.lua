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
L["Left-Click: Toggle options"] = "|cFFFFFFFFClic gauche :|r Afficher/masquer les options"
L["Right-Click: Detach/close vendor panel"] = "|cFFFFFFFFClic droit :|r Détacher/fermer le panneau des vendeurs"

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
