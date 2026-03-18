--[[
    Homestead - Locale: Spanish (MX / Latin America)
    Machine-translated — contributions welcome
]]

local addonName, HA = ...

if GetLocale() ~= "esMX" then return end

-- Initialize localization table
local L = {}
HA.L = L

-------------------------------------------------------------------------------
-- Collection Status
-------------------------------------------------------------------------------
L["Collected"] = "Recolectado"
L["Collected (Placed)"] = "Recolectado (Colocado)"
L["Not Collected"] = "No recolectado"
L["Unknown"] = "Desconocido"

-------------------------------------------------------------------------------
-- Source Descriptions
-------------------------------------------------------------------------------
L["Available from vendor"] = "Disponible con el vendedor"
L["Can be crafted"] = "Se puede fabricar"
L["Achievement reward"] = "Recompensa de logro"
L["World drop"] = "Botín del mundo"
L["Quest reward"] = "Recompensa de misión"
L["Reputation reward"] = "Recompensa de reputación"
L["Event reward"] = "Recompensa de evento"
L["Promotional item"] = "Objeto promocional"

-------------------------------------------------------------------------------
-- Decor Properties
-------------------------------------------------------------------------------
L["Can be dyed"] = "Se puede teñir"
L["Colorable"] = "Coloreable"
L["Warbound"] = "Ligado a la banda"
L["Indoor only"] = "Solo interior"
L["Outdoor only"] = "Solo exterior"
L["Quantity owned: %d"] = "Cantidad poseída: %d"
L["Currently placed: %d"] = "Colocados actualmente: %d"

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["[Housing Addon]"] = "|cFF00FF00[Homestead]|r"
L["Source:"] = "Fuente:"
L["Vendor:"] = "Vendedor:"
L["Location:"] = "Ubicación:"
L["Click to set waypoint"] = "Clic para establecer punto de ruta"

-------------------------------------------------------------------------------
-- UI Labels
-------------------------------------------------------------------------------
L["Housing Addon"] = "Homestead"
L["Decor Browser"] = "Explorador de decoración"
L["Vendor Tracer"] = "Buscador de vendedores"
L["Color Tracker"] = "Seguimiento de tintes"
L["Export Data"] = "Exportar datos"
L["Options"] = "Opciones"
L["Search"] = "Buscar"
L["Filter"] = "Filtrar"
L["Close"] = "Cerrar"

-------------------------------------------------------------------------------
-- Vendor Tracer
-------------------------------------------------------------------------------
L["Set Waypoint"] = "Establecer punto de ruta"
L["Show on Map"] = "Mostrar en el mapa"
L["Vendor sells %d decor items"] = "El vendedor ofrece %d objetos de decoración"
L["You own %d/%d items"] = "Posees %d/%d objetos"
L["Missing items:"] = "Objetos faltantes:"
L["No vendors found"] = "No se encontraron vendedores"

-------------------------------------------------------------------------------
-- Color/Dye Tracker
-------------------------------------------------------------------------------
L["Dye Collection"] = "Colección de tintes"
L["Owned Dyes"] = "Tintes poseídos"
L["Known Recipes"] = "Recetas conocidas"
L["Dye Slots"] = "Ranuras de tinte"
L["Apply Dye"] = "Aplicar tinte"
L["Preview"] = "Vista previa"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["General"] = "General"
L["Overlays"] = "Superposiciones"
L["Tooltips"] = "Descripciones emergentes"
L["Vendor Tracer"] = "Buscador de vendedores"
L["Export"] = "Exportar"

L["Enable addon"] = "Activar addon"
L["Show minimap button"] = "Mostrar botón del minimapa"
L["Enable overlays"] = "Activar superposiciones"
L["Show on bags"] = "Mostrar en bolsas"
L["Show on bank"] = "Mostrar en el banco"
L["Show on merchant"] = "Mostrar con el vendedor"
L["Show on auction house"] = "Mostrar en la casa de subastas"
L["Show on housing catalog"] = "Mostrar en el catálogo de vivienda"
L["Icon size"] = "Tamaño del icono"
L["Icon position"] = "Posición del icono"

L["Enable tooltip additions"] = "Activar información adicional"
L["Show source information"] = "Mostrar información de fuente"
L["Show quantity owned"] = "Mostrar cantidad poseída"
L["Show dye slot information"] = "Mostrar información de ranuras de tinte"

L["Show map pins"] = "Mostrar marcadores en el mapa"
L["Show minimap pins"] = "Mostrar marcadores en el minimapa"
L["Use TomTom for waypoints"] = "Usar TomTom para puntos de ruta"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Housing Addon Commands:"] = "Comandos de Homestead:"
L["/ha - Toggle main window"] = "/ha — Abrir/cerrar ventana principal"
L["/ha options - Open options panel"] = "/ha options — Abrir panel de opciones"
L["/ha export - Export collection data"] = "/ha export — Exportar datos de colección"
L["/ha vendor [search] - Open vendor panel"] = "/ha vendor [búsqueda] — Abrir panel de vendedores"
L["/ha debug - Toggle debug mode"] = "/ha debug — Alternar modo de depuración"
L["/ha help - Show this help"] = "/ha help — Mostrar esta ayuda"

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "Modo de depuración: %s"
L["ON"] = "ACTIVADO"
L["OFF"] = "DESACTIVADO"
L["Unknown command: %s"] = "Comando desconocido: %s"
L["Not yet implemented"] = "Aún no implementado"

-------------------------------------------------------------------------------
-- Statistics
-------------------------------------------------------------------------------
L["Statistics"] = "Estadísticas"
L["Total Decor:"] = "Decoración total:"
L["Collected:"] = "Recolectado:"
L["Placed:"] = "Colocado:"
L["Remaining:"] = "Restante:"
L["Collection Progress: %d%%"] = "Progreso de colección: %d%%"
