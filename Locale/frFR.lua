--[[
    Homestead - Locale: French (FR)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "frFR" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- Collection Status
-------------------------------------------------------------------------------
L["Collected"] = "Collecté"
L["Collected (Placed)"] = "Collecté (Placé)"
L["Not Collected"] = "Non collecté"
L["Unknown"] = "Inconnu"

-------------------------------------------------------------------------------
-- Source Descriptions
-------------------------------------------------------------------------------
L["Available from vendor"] = "Disponible chez un vendeur"
L["Can be crafted"] = "Peut être fabriqué"
L["Achievement reward"] = "Récompense de haut fait"
L["World drop"] = "Butin mondial"
L["Quest reward"] = "Récompense de quête"
L["Reputation reward"] = "Récompense de réputation"
L["Event reward"] = "Récompense d'événement"
L["Promotional item"] = "Objet promotionnel"

-------------------------------------------------------------------------------
-- Decor Properties
-------------------------------------------------------------------------------
L["Can be dyed"] = "Peut être teint"
L["Colorable"] = "Colorable"
L["Warbound"] = "Lié au bataillon"
L["Indoor only"] = "Intérieur uniquement"
L["Outdoor only"] = "Extérieur uniquement"
L["Quantity owned: %d"] = "Quantité possédée : %d"
L["Currently placed: %d"] = "Actuellement placé : %d"

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["[Housing Addon]"] = "|cFF00FF00[Homestead]|r"
L["Source:"] = "Source :"
L["Vendor:"] = "Vendeur :"
L["Location:"] = "Emplacement :"
L["Click to set waypoint"] = "Cliquez pour définir un point de passage"

-------------------------------------------------------------------------------
-- UI Labels
-------------------------------------------------------------------------------
L["Housing Addon"] = "Homestead"
L["Decor Browser"] = "Navigateur de décor"
L["Vendor Tracer"] = "Recherche de vendeurs"
L["Color Tracker"] = "Suivi des teintures"
L["Export Data"] = "Exporter les données"
L["Options"] = "Options"
L["Search"] = "Recherche"
L["Filter"] = "Filtrer"
L["Close"] = "Fermer"

-------------------------------------------------------------------------------
-- Vendor Tracer
-------------------------------------------------------------------------------
L["Set Waypoint"] = "Définir un point de passage"
L["Show on Map"] = "Afficher sur la carte"
L["Vendor sells %d decor items"] = "Le vendeur propose %d objets de décor"
L["You own %d/%d items"] = "Vous possédez %d/%d objets"
L["Missing items:"] = "Objets manquants :"
L["No vendors found"] = "Aucun vendeur trouvé"

-------------------------------------------------------------------------------
-- Color/Dye Tracker
-------------------------------------------------------------------------------
L["Dye Collection"] = "Collection de teintures"
L["Owned Dyes"] = "Teintures possédées"
L["Known Recipes"] = "Recettes connues"
L["Dye Slots"] = "Emplacements de teinture"
L["Apply Dye"] = "Appliquer la teinture"
L["Preview"] = "Aperçu"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["General"] = "Général"
L["Overlays"] = "Superpositions"
L["Tooltips"] = "Infobulles"
L["Export"] = "Exporter"

L["Enable addon"] = "Activer l'addon"
L["Show minimap button"] = "Afficher le bouton de minicarte"
L["Enable overlays"] = "Activer les superpositions"
L["Show on bags"] = "Afficher dans les sacs"
L["Show on bank"] = "Afficher dans la banque"
L["Show on merchant"] = "Afficher chez le marchand"
L["Show on auction house"] = "Afficher à l'hôtel des ventes"
L["Show on housing catalog"] = "Afficher dans le catalogue de logement"
L["Icon size"] = "Taille de l'icône"
L["Icon position"] = "Position de l'icône"
L["Show opposite faction vendors"] = "Afficher les vendeurs de la faction opposée"
L["Show unverified vendors"] = "Afficher les vendeurs non vérifiés"

L["Enable tooltip additions"] = "Activer les ajouts aux infobulles"
L["Show source information"] = "Afficher les informations de source"
L["Show quantity owned"] = "Afficher la quantité possédée"
L["Show dye slot information"] = "Afficher les informations de teinture"
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
L["Middle-Click: Scan collection"] = "|cFFFFFFFFClic milieu :|r Scanner la collection"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Commandes de Homestead :"
L["/hs - Open options panel"] = "/hs — Ouvrir le panneau d'options"
L["/hs scan - Scan catalog"] = "/hs scan — Scanner le catalogue"
L["/hs vendor [search] - Search vendors"] = "/hs vendor [recherche] — Rechercher des vendeurs"
L["/hs export - Show export dialog"] = "/hs export — Afficher le dialogue d'exportation"
L["/hs debug - Toggle debug mode"] = "/hs debug — Activer/désactiver le mode débogage"
L["/hs help - Show this help"] = "/hs help — Afficher cette aide"

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
L["Not yet implemented"] = "Pas encore implémenté"

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
L["All"] = "Tous"
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

-------------------------------------------------------------------------------
-- Statistics
-------------------------------------------------------------------------------
L["Statistics"] = "Statistiques"
L["Total Decor:"] = "Décor total :"
L["Collected:"] = "Collecté :"
L["Placed:"] = "Placé :"
L["Remaining:"] = "Restant :"
L["Collection Progress: %d%%"] = "Progression de la collection : %d%%"
