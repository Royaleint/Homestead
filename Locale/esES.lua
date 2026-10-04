--[[
    Homestead - Locale: Spanish (ES)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "esES" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- UI Labels
-------------------------------------------------------------------------------
L["Close"] = "Cerrar"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["General"] = "General"
L["Overlays"] = "Superposiciones"
L["Tooltips"] = "Descripciones emergentes"
L["Export"] = "Exportar"

L["Show minimap button"] = "Mostrar botón del minimapa"
L["Enable overlays"] = "Activar superposiciones"
L["Show on bags"] = "Mostrar en bolsas"
L["Show on bank"] = "Mostrar en el banco"
L["Show on merchant"] = "Mostrar en el vendedor"
L["Show on housing catalog"] = "Mostrar en el catálogo de vivienda"
L["Icon size"] = "Tamaño del icono"
L["Icon position"] = "Posición del icono"
L["Show opposite faction vendors"] = "Mostrar vendedores de la facción opuesta"

L["Enable tooltip additions"] = "Activar información adicional"
L["Show source information"] = "Mostrar información de fuente"
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

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Comandos de Homestead:"

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

