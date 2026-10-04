--[[
    Homestead - Locale: French (FR)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "frFR" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- UI Labels
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["Overlays"] = "Superpositions"
L["Tooltips"] = "Infobulles"
L["Export"] = "Exporter"

L["Show minimap button"] = "Afficher le bouton de minicarte"
L["Enable overlays"] = "Activer les superpositions"
L["Show on bags"] = "Afficher dans les sacs"
L["Show on bank"] = "Afficher dans la banque"
L["Show on merchant"] = "Afficher chez le marchand"
L["Show on housing catalog"] = "Afficher dans le catalogue de logement"
L["Icon size"] = "Taille de l'icône"
L["Icon position"] = "Position de l'icône"
L["Show opposite faction vendors"] = "Afficher les vendeurs de la faction opposée"

L["Enable tooltip additions"] = "Activer les ajouts aux infobulles"
L["Show source information"] = "Afficher les informations de source"
L["Show vendor details in tooltips"] = "Afficher les détails du vendeur dans les infobulles"

L["Show map pins"] = "Afficher les repères sur la carte"
L["Show minimap pins"] = "Afficher les repères sur la minicarte"
L["Use TomTom for waypoints"] = "Utiliser TomTom pour les points de passage"
L["Use native waypoints"] = "Utiliser les points de passage natifs"
L["Auto-create waypoint on click"] = "Créer automatiquement un point de passage au clic"
L["Navigate modifier key"] = "Touche de modification de navigation"

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d / %d (%d%%)"] = "Collection : %d / %d (%d%%)"
L["Vendors nearby: %d"] = "Vendeurs à proximité : %d"
L["Vendors scanned: %d"] = "Vendeurs scannés : %d"
L["Left-Click: Toggle options"] = "|cFFFFFFFFClic gauche :|r Ouvrir les options"
L["Right-Click: Detach/close vendor panel"] = "|cFFFFFFFFClic droit :|r Détacher/fermer le panneau vendeurs"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Commandes de Homestead :"

-------------------------------------------------------------------------------
-- Slash Command Feedback
-------------------------------------------------------------------------------
L["Map pins refreshed."] = "Repères de carte actualisés."
L["No active waypoint."] = "Aucun point de passage actif."
L["Waypoint cleared."] = "Point de passage supprimé."
L["Vendor database contains %d vendors."] = "La base de données contient %d vendeurs."
L["Use /hs vendor <name or zone> to search."] = "Utilisez /hs vendor <nom ou zone> pour rechercher."
L["No vendors found matching: %s"] = "Aucun vendeur trouvé pour : %s"
L["Found %d vendor(s) matching: %s"] = "%d vendeur(s) trouvé(s) pour : %s"
L["... and %d more."] = "... et %d de plus."

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "Mode débogage : %s"
L["ON"] = "ACTIVÉ"
L["OFF"] = "DÉSACTIVÉ"
L["Unknown command: %s"] = "Commande inconnue : %s"

-------------------------------------------------------------------------------
-- Export Dialog
-------------------------------------------------------------------------------
L["Export Vendor Data"] = "Exporter les données vendeurs"
L["Choose export option:"] = "Choisir une option d'exportation :"
L["Export New Scans"] = "Exporter les nouveaux scans"
L["Export All"] = "Tout exporter"

-------------------------------------------------------------------------------
-- Map Side Panel
-------------------------------------------------------------------------------
L["Vendor"] = "Vendeur"
L["Quest"] = "Quête"
L["Achievement"] = "Haut fait"
L["Profession"] = "Métier"
L["Event"] = "Événement"
L["Drop"] = "Butin"
L["Zone Collection Progress"] = "Progression de la collection de zone"
L["Continent Collection Progress"] = "Progression de la collection du continent"
L["Global Collection Progress"] = "Progression globale de la collection"
L["Order Hall"] = "Domaine de classe"
L["Click to preview"] = "Cliquer pour aperçu"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "Résultat"
L["Select All"] = "Tout sélectionner"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "Texte sélectionné. Ctrl+C pour copier."

