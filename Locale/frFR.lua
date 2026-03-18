--[[
    Homestead - Locale: French (FR)
    Machine-translated — contributions welcome
]]

local addonName, HA = ...

if GetLocale() ~= "frFR" then return end

-- Initialize localization table
local L = {}
HA.L = L

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
L["Search"] = "Rechercher"
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
L["Vendor Tracer"] = "Recherche de vendeurs"
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

L["Enable tooltip additions"] = "Activer les ajouts aux infobulles"
L["Show source information"] = "Afficher les informations de source"
L["Show quantity owned"] = "Afficher la quantité possédée"
L["Show dye slot information"] = "Afficher les informations de teinture"

L["Show map pins"] = "Afficher les repères sur la carte"
L["Show minimap pins"] = "Afficher les repères sur la minicarte"
L["Use TomTom for waypoints"] = "Utiliser TomTom pour les points de passage"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Housing Addon Commands:"] = "Commandes de Homestead :"
L["/ha - Toggle main window"] = "/ha — Ouvrir/fermer la fenêtre principale"
L["/ha options - Open options panel"] = "/ha options — Ouvrir le panneau d'options"
L["/ha export - Export collection data"] = "/ha export — Exporter les données de collection"
L["/ha vendor [search] - Open vendor panel"] = "/ha vendor [recherche] — Ouvrir le panneau des vendeurs"
L["/ha debug - Toggle debug mode"] = "/ha debug — Activer/désactiver le mode débogage"
L["/ha help - Show this help"] = "/ha help — Afficher cette aide"

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "Mode débogage : %s"
L["ON"] = "ACTIVÉ"
L["OFF"] = "DÉSACTIVÉ"
L["Unknown command: %s"] = "Commande inconnue : %s"
L["Not yet implemented"] = "Pas encore implémenté"

-------------------------------------------------------------------------------
-- Statistics
-------------------------------------------------------------------------------
L["Statistics"] = "Statistiques"
L["Total Decor:"] = "Décor total :"
L["Collected:"] = "Collecté :"
L["Placed:"] = "Placé :"
L["Remaining:"] = "Restant :"
L["Collection Progress: %d%%"] = "Progression de la collection : %d%%"
