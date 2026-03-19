--[[
    Homestead - Locale: Spanish (ES)
    Machine-translated — contributions welcome
]]

local addonName, HA = ...

if GetLocale() ~= "esES" then return end

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
L["Available from vendor"] = "Disponible en vendedor"
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
L["Filter"] = "Filtro"
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
L["Export"] = "Exportar"

L["Enable addon"] = "Activar addon"
L["Show minimap button"] = "Mostrar botón del minimapa"
L["Enable overlays"] = "Activar superposiciones"
L["Show on bags"] = "Mostrar en bolsas"
L["Show on bank"] = "Mostrar en el banco"
L["Show on merchant"] = "Mostrar en el vendedor"
L["Show on auction house"] = "Mostrar en la casa de subastas"
L["Show on housing catalog"] = "Mostrar en el catálogo de vivienda"
L["Icon size"] = "Tamaño del icono"
L["Icon position"] = "Posición del icono"
L["Show opposite faction vendors"] = "Mostrar vendedores de la facción opuesta"
L["Show unverified vendors"] = "Mostrar vendedores no verificados"

L["Enable tooltip additions"] = "Activar información adicional"
L["Show source information"] = "Mostrar información de fuente"
L["Show quantity owned"] = "Mostrar cantidad poseída"
L["Show dye slot information"] = "Mostrar información de ranuras de tinte"
L["Show vendor details in tooltips"] = "Mostrar detalles del vendedor en descripciones"

L["Show map pins"] = "Mostrar marcadores en el mapa"
L["Show minimap pins"] = "Mostrar marcadores en el minimapa"
L["Use TomTom for waypoints"] = "Usar TomTom para puntos de ruta"
L["Use native waypoints"] = "Usar puntos de ruta nativos"
L["Auto-create waypoint on click"] = "Crear punto de ruta automáticamente al hacer clic"
L["Navigate modifier key"] = "Tecla modificadora de navegación"

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d / %d (%d%%)"] = "Colección: %d / %d (%d%%)"
L["Vendors nearby: %d"] = "Vendedores cercanos: %d"
L["Vendors scanned: %d"] = "Vendedores escaneados: %d"
L["Left-Click: Toggle options"] = "|cFFFFFFFFClic izquierdo:|r Abrir opciones"
L["Right-Click: Detach/close vendor panel"] = "|cFFFFFFFFClic derecho:|r Separar/cerrar panel de vendedores"
L["Middle-Click: Scan collection"] = "|cFFFFFFFFClic central:|r Escanear colección"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Comandos de Homestead:"
L["/hs - Open options panel"] = "/hs — Abrir opciones"
L["/hs scan - Scan catalog"] = "/hs scan — Escanear catálogo"
L["/hs vendor [search] - Search vendors"] = "/hs vendor [búsqueda] — Buscar vendedores de decoración"
L["/hs export - Show export dialog"] = "/hs export — Mostrar diálogo de exportación"
L["/hs debug - Toggle debug mode"] = "/hs debug — Alternar modo de depuración"
L["/hs help - Show this help"] = "/hs help — Mostrar esta ayuda"

-------------------------------------------------------------------------------
-- Slash Command Feedback
-------------------------------------------------------------------------------
L["Map pins refreshed."] = "Marcadores del mapa actualizados."
L["No active waypoint."] = "No hay punto de ruta activo."
L["Waypoint cleared."] = "Punto de ruta eliminado."
L["Vendor database contains %d vendors."] = "La base de datos contiene %d vendedores."
L["Use /hs vendor <name or zone> to search."] = "Usa /hs vendor <nombre o zona> para buscar."
L["No vendors found matching: %s"] = "No se encontraron vendedores para: %s"
L["Found %d vendor(s) matching: %s"] = "%d vendedor(es) encontrado(s) para: %s"
L["... and %d more."] = "... y %d más."

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "Modo de depuración: %s"
L["ON"] = "ACTIVADO"
L["OFF"] = "DESACTIVADO"
L["Unknown command: %s"] = "Comando desconocido: %s"
L["Not yet implemented"] = "Aún no implementado"

-------------------------------------------------------------------------------
-- Export Dialog
-------------------------------------------------------------------------------
L["Export Vendor Data"] = "Exportar datos de vendedores"
L["Choose export option:"] = "Elige una opción de exportación:"
L["Export New Scans"] = "Exportar nuevos escaneos"
L["Export All"] = "Exportar todo"

-------------------------------------------------------------------------------
-- Map Side Panel
-------------------------------------------------------------------------------
L["All"] = "Todos"
L["Vendor"] = "Vendedor"
L["Quest"] = "Misión"
L["Achievement"] = "Logro"
L["Profession"] = "Profesión"
L["Event"] = "Evento"
L["Drop"] = "Botín"
L["Zone Collection Progress"] = "Progreso de colección de zona"
L["Continent Collection Progress"] = "Progreso de colección del continente"
L["Global Collection Progress"] = "Progreso global de colección"
L["Order Hall"] = "Sede de la orden"
L["Click to preview"] = "Clic para vista previa"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "Resultado"
L["Select All"] = "Seleccionar todo"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "Texto seleccionado. Presiona Ctrl+C para copiar."

-------------------------------------------------------------------------------
-- Statistics
-------------------------------------------------------------------------------
L["Statistics"] = "Estadísticas"
L["Total Decor:"] = "Decoración total:"
L["Collected:"] = "Recolectado:"
L["Placed:"] = "Colocado:"
L["Remaining:"] = "Restante:"
L["Collection Progress: %d%%"] = "Progreso de colección: %d%%"
