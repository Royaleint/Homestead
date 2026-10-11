--[[
    Homestead - Locale: Spanish (ES)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "esES" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["Used in %d known recipe for decor you haven't collected"] = "Se usa en %d receta conocida de adornos que no has conseguido"
L["Used in %d known recipes for decor you haven't collected"] = "Se usa en %d recetas conocidas de adornos que no has conseguido"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["Homestead"] = "Homestead"
L["Homestead Options"] = "Opciones de Homestead"
L["Overlays"] = "Indicadores"
L["Tooltips"] = "Descripciones"
L["Export"] = "Exportar"

L["Show minimap button"] = "Mostrar botón del minimapa"
L["Enable overlays"] = "Activar indicadores"
L["Show on bags"] = "Mostrar en bolsas"
L["Show on bank"] = "Mostrar en el banco"
L["Show on merchant"] = "Mostrar en mercaderes"
L["Show on housing catalog"] = "Mostrar en el catálogo de hogares"
L["Icon size"] = "Tamaño de los iconos"
L["Icon position"] = "Posición del icono"
L["Show opposite faction vendors"] = "Mostrar vendedores de la facción contraria"

L["Enable tooltip additions"] = "Activar información en descripciones"
L["Show source information"] = "Mostrar información de origen"
L["Show vendor details in tooltips"] = "Mostrar detalles del vendedor en descripciones"

L["Show map pins"] = "Mostrar marcadores en el mapa"
L["Show minimap pins"] = "Mostrar marcadores en el minimapa"
L["Use TomTom for waypoints"] = "Usar TomTom para puntos de ruta"
L["Use native waypoints"] = "Usar puntos de ruta del juego"
L["Auto-create waypoint on click"] = "Crear punto de ruta al hacer clic"
L["Navigate modifier key"] = "Tecla modificadora de navegación"

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d / %d (%d%%)"] = "Colección: %d / %d (%d%%)"
L["Vendors nearby: %d"] = "Vendedores cercanos: %d"
L["Vendors scanned: %d"] = "Vendedores escaneados: %d"
L["Left-Click: Toggle options"] = "|cFFFFFFFFClic izquierdo:|r Mostrar/ocultar opciones"
L["Right-Click: Detach/close vendor panel"] = "|cFFFFFFFFClic derecho:|r Separar/cerrar panel de vendedores"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Comandos de Homestead:"

-------------------------------------------------------------------------------
-- Slash Command Feedback
-------------------------------------------------------------------------------
L["Map pins refreshed."] = "Marcadores del mapa actualizados."
L["No active waypoint."] = "No hay ningún punto de ruta activo."
L["Waypoint cleared."] = "Punto de ruta eliminado."
L["Vendor database contains %d vendors."] = "La base de datos de vendedores contiene %d vendedores."
L["Use /hs vendor <name or zone> to search."] = "Usa /hs vendor <nombre o zona> para buscar."
L["No vendors found matching: %s"] = "No se han encontrado vendedores que coincidan con: %s"
L["Found %d vendor(s) matching: %s"] = "Vendedores encontrados (%d) que coinciden con: %s"
L["... and %d more."] = "... y %d más."

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "Modo de depuración: %s"
L["ON"] = "Activado"
L["OFF"] = "Desactivado"
L["Unknown command: %s"] = "Comando desconocido: %s"
L["Type /hs help for a list of commands."] = "Escribe /hs help para ver una lista de comandos."

-------------------------------------------------------------------------------
-- Version Check
-------------------------------------------------------------------------------
L["Your Homestead version is out-of-date."] = "Tu versión de Homestead está desactualizada."
L["Version %s (%s) can be downloaded at CurseForge, Wago, or GitHub Releases."] = "La versión %s (%s) se puede descargar en CurseForge, Wago o GitHub Releases."
L["Homestead version: %s (%s)"] = "Versión de Homestead: %s (%s)"
L["Newest version seen this session: %s (%s)"] = "Versión más reciente vista en esta sesión: %s (%s)"
L["No newer version seen this session."] = "No se ha visto ninguna versión más reciente en esta sesión."
L["Version-check notifications: %s"] = "Avisos de comprobación de versión: %s"

-------------------------------------------------------------------------------
-- Export Dialog
-------------------------------------------------------------------------------
L["Export Vendor Data"] = "Exportar datos de vendedores"
L["Choose export option:"] = "Elige una opción de exportación:"
L["Export New Scans"] = "Exportar escaneos nuevos"
L["Export All"] = "Exportar todo"

-------------------------------------------------------------------------------
-- Map Side Panel
-------------------------------------------------------------------------------
L["All"] = "Todos"
L["Vendor"] = "Vendedor"
L["Vendors"] = "Vendedores"
L["Quest"] = "Misión"
L["Achievement"] = "Logro"
L["Profession"] = "Profesión"
L["Event"] = "Evento"
L["Drop"] = "Botín"
L["Treasure"] = "Tesoro"
L["Zone Collection Progress"] = "Progreso de colección de la zona"
L["Continent Collection Progress"] = "Progreso de colección del continente"
L["Global Collection Progress"] = "Progreso de colección global"
L["Order Hall"] = "Sede de clase"
L["Click to preview"] = "Haz clic para ver la vista previa"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "Resultado"
L["Select All"] = "Seleccionar todo"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "Todo el texto seleccionado. Pulsa Ctrl+C para copiarlo al portapapeles."

-------------------------------------------------------------------------------
-- Options - Names
-------------------------------------------------------------------------------
L["Vendor pin item details"] = "Detalles de objetos en marcadores de vendedor"

L["Auto-scan vendors"] = "Escanear vendedores automáticamente"
L["Vendor Visibility"] = "Visibilidad de vendedores"
L["Show event vendors"] = "Mostrar vendedores de evento"
L["Hide fully-collected vendor pins"] = "No marcar vendedores con todo conseguido"
L["Fully-collected vendors"] = "Vendedores con todo conseguido"
L["desc_map_filter_completed_vendors"] = "Desmarca para ocultar los marcadores de los vendedores de los que ya has conseguido todos los adornos."
L["Pin Appearance"] = "Apariencia de marcadores"
L["Pin color"] = "Color de marcadores"
L["Custom color"] = "Color personalizado"
L["Show accessibility glow"] = "Mostrar brillo de accesibilidad"
L["Owned item style"] = "Estilo de objetos poseídos"
L["Show ownership status"] = "Mostrar estado de posesión"
L["Show requirements"] = "Mostrar requisitos"
L["Show all sources"] = "Mostrar todos los orígenes"
L["Map Pins"] = "Marcadores del mapa"
L["Show vendor panel on world map"] = "Panel de vendedores en el mapa del mundo"
L["Vendor panel source filter"] = "Filtro de origen del panel de vendedores"
L["Integrate with map frame border"] = "Integrar con el borde del marco del mapa"
L["Zone badges on world map"] = "Insignias de zona en el mapa del mundo"
L["World map pin size"] = "Tamaño de marcadores en el mapa del mundo"
L["Show collection counts"] = "Mostrar recuentos de colección"
L["Show elevation arrows"] = "Mostrar flechas de altura"
L["Minimap nearby-zone pins"] = "Marcadores de zonas cercanas en el minimapa"
L["Minimap pin size"] = "Tamaño de marcadores en el minimapa"
L["Waypoints"] = "Puntos de ruta"
L["Show milestone progress on dashboard"] = "Progreso de hitos en el Panel de hogares"
L["Inventory"] = "Inventario"
L["Merchant"] = "Mercader"
L["Housing Catalog"] = "Catálogo de hogares"

-------------------------------------------------------------------------------
-- Options - Descriptions
-------------------------------------------------------------------------------
L["desc_minimap_button"] = "Muestra u oculta el botón del minimapa"
L["desc_auto_scan_vendors"] = "Escanea automáticamente el inventario de los mercaderes en busca de datos de adornos de hogares al visitar vendedores. Desactivarlo puede mejorar ligeramente el rendimiento al abrir mercaderes."
L["desc_options_general"] = "Comportamiento básico del addon, acceso desde el minimapa, escaneo de vendedores y apariencia de los marcadores del mapa."
L["desc_options_overlays"] = "Indicadores de colección mostrados en las bolsas, el banco, los mercaderes y el catálogo de hogares."
L["desc_options_tooltips"] = "Detalles adicionales de posesión, origen, requisitos y vendedores añadidos a las descripciones de objetos y de marcadores del mapa."
L["desc_options_world_map"] = "Marcadores de vendedores en el mapa del mundo, insignias de zona, comportamiento del panel lateral y visualización de marcadores."
L["desc_options_minimap"] = "Marcadores de vendedores cercanos, flechas de altura y comportamiento de los puntos de ruta en el minimapa."
L["desc_options_endeavors"] = "Progreso de los proyectos de hogares mostrado en el Panel de hogares de Blizzard."
L["desc_options_export"] = "Exportación de los datos de vendedores escaneados para revisarlos o como copia de seguridad."
L["desc_vendor_visibility_section"] = "Elige qué grupos de vendedores aparecen en los mapas y en los totales de colección."
L["desc_pin_appearance_section"] = "Ajusta el color y la vista previa de los marcadores de vendedores de Homestead."
L["desc_overlay_inventory_section"] = "Muestra indicadores de colección en las casillas de objetos fuera del catálogo de hogares."
L["desc_overlay_merchant_section"] = "Marca los adornos conseguidos al ver los objetos de los vendedores."
L["desc_overlay_catalog_section"] = "Controla los indicadores, los resaltados y el estilo de los objetos conseguidos en el catálogo de hogares."
L["desc_tooltip_map_pins_section"] = "Elige cuántos detalles del vendedor aparecen en las descripciones de los marcadores del mapa."
L["desc_minimap_waypoints_section"] = "Configura el comportamiento de los puntos de ruta de TomTom y del juego al hacer clic en el mapa y en vendedores."
L["desc_opposite_faction"] = "Muestra los vendedores de la facción contraria con su emblema de facción. Útil para completistas que quieran ver todos los vendedores disponibles."
L["desc_event_vendors"] = "Muestra en el mapa los marcadores de vendedores de festividades de temporada cuando su evento está activo (p. ej., Festival Lunar)"
L["desc_hide_completed_vendor_pins"] = "Oculta los marcadores del mapa y del minimapa de los vendedores de los que ya has conseguido todos los adornos de hogares. La lista del panel de vendedores no se ve afectada."
L["desc_pin_color"] = "Elige un color para los marcadores del mapa y del minimapa."
L["desc_custom_color"] = "Elige un color base personalizado para los marcadores del mapa"
L["desc_enable_overlays"] = "Añade pequeños iconos y resaltados a los adornos en todo el juego para que veas de un vistazo cuáles has conseguido. Al desactivarlo se ocultan todos los indicadores de Homestead en todas partes."
L["desc_icon_size"] = "Controla el tamaño de los iconos de colección en las casillas de objetos."
L["desc_icon_position"] = "En qué esquina de la casilla del objeto se sitúa el icono de colección."
L["desc_show_on_bags"] = "Añade un |A:homestone-minimap-icon:16:16|a a los adornos de tus bolsas, coloreado para indicar si has conseguido cada uno. Funciona con las bolsas predeterminadas, Baganator y BetterBags."
L["desc_show_on_bank"] = "Marca los adornos de tu banco para que veas cuáles ya has conseguido."
L["desc_show_on_merchant"] = "Añade un |A:homestone-minimap-icon:16:16|a a los adornos de los vendedores, coloreado para indicar si has conseguido cada uno."
L["desc_show_on_housing_catalog"] = "Marca los objetos del catálogo de hogares con iconos de colección que indican de dónde procede cada objeto.\n\n|A:auctionhouse-icon-coin-gold:16:16|a Vendedor\n|A:QuestNormal:16:16|a Misión\n|A:UI-Achievement-Shield-NoPoints:16:16|a Logro\n|A:UI-HUD-MicroMenu-Professions-Mouseover:16:16|a Profesión\n|A:UI-HUD-Calendar-1-Up:16:16|a Evento\n|A:Crosshair_lootall_64:16:16|a Botín\n|A:hearthsteel-icon-32x32:16:16|a Tienda de Battle.net"
L["desc_accessibility_glow"] = "Añade un brillo de color al borde de los objetos del catálogo de hogares: verde para los que posees, amarillo para los que puedes conseguir y rojo para los bloqueados por requisitos que aún no cumples."
L["desc_owned_item_style"] = "Elige cómo se ven los objetos conseguidos en el catálogo de hogares. Resaltado verde muestra el brillo predeterminado, Atenuado los difumina y Marca de verificación añade una pequeña marca verde. Elige Ninguno para dejarlos sin cambios."
L["desc_enable_tooltips"] = "Añade información de Homestead a las descripciones de los objetos al pasar el cursor sobre adornos. Al desactivarlo se elimina toda la información añadida a las descripciones."
L["desc_show_ownership"] = "Añade una línea a las descripciones que indica si ya has conseguido un adorno."
L["desc_show_source"] = "Muestra cómo obtener un adorno: vendedores, misiones, logros, profesiones, eventos y botín."
L["desc_show_requirements"] = "Muestra los requisitos de compra, como reputación, misiones completadas o logros necesarios para comprar un objeto."
L["desc_show_all_sources"] = "Muestra todas las formas conocidas de obtener un objeto en lugar de solo el mejor origen disponible. Útil cuando un objeto se puede conseguir de varios vendedores, misiones u otros orígenes."
L["desc_vendor_details"] = "Muestra el inventario completo de un vendedor y tu progreso de colección al pasar el cursor sobre su marcador del mapa. Desactívalo para una descripción más simple con solo el nombre del vendedor."
L["desc_vendor_pin_item_details"] = "Muestra los iconos de orígenes alternativos y el coste en el vendedor de cada objeto, además de un recuento de objetos exclusivos de vendedor, en las descripciones de los marcadores del mapa. Desactívalo para una descripción más simple que solo enumere los nombres de los objetos."
L["desc_show_map_pins"] = "Muestra la ubicación de los vendedores en el mapa del mundo"
L["desc_show_map_side_panel"] = "Muestra un panel lateral en el mapa del mundo con los vendedores y el progreso de colección de la zona actual"
L["desc_source_filter"] = "Filtra por origen de obtención los recuentos de objetos del panel lateral y las cuadrículas ampliadas. La visibilidad de los vendedores en el mapa no cambia."
L["desc_integrate_map_border"] = "Une el borde superior del panel con el borde del mapa del mundo para un aspecto continuo. Desactívalo si usas una interfaz personalizada (ElvUI, GW2, etc.) que entre en conflicto."
L["desc_zone_badges"] = "Muestra el recuento de vendedores de cada zona repartido por los continentes en el mapa del mundo, en lugar de un único total por continente."
L["desc_world_pin_size"] = "Ajusta el tamaño de los marcadores de vendedores en el mapa del mundo. El valor predeterminado (20) coincide con los iconos de puntos de interés de Blizzard."
L["desc_show_pin_counts"] = "Muestra el recuento de objetos conseguidos/totales en los marcadores de vendedores (p. ej., 3/12). Desactívalo para despejar el mapa."
L["desc_show_minimap_pins"] = "Muestra la ubicación de los vendedores en el minimapa con flechas de altura"
L["desc_elevation_arrows"] = "Muestra flechas de dirección en los marcadores del minimapa cuando un vendedor está por encima o por debajo de ti"
L["desc_cross_zone_mode"] = "Controla los marcadores de otras zonas en el minimapa. Automático reduce los marcadores adicionales en zonas urbanas concurridas para un movimiento más fluido."
L["desc_minimap_pin_size"] = "Ajusta el tamaño de los marcadores de vendedores en el minimapa. Auméntalo si cuesta ver los marcadores o redúcelo para despejar el minimapa."
L["desc_waypoint_info"] = "TomTom muestra una flecha de dirección superpuesta y requiere tener instalado el addon TomTom. El sistema del juego añade un marcador de destino al mapa del mundo. Ambos pueden estar activos a la vez."
L["desc_use_tomtom"] = "Usa el addon TomTom para las flechas de los puntos de ruta (si está instalado)"
L["desc_use_native_waypoints"] = "Usa el sistema de puntos de ruta integrado de WoW con una marca de mapa"
L["desc_auto_waypoint"] = "Crea automáticamente un punto de ruta al hacer clic en un vendedor de la lista o del mapa"
L["desc_navigate_modifier"] = "Mantén pulsada esta tecla al hacer clic para crear un punto de ruta (si el punto de ruta automático está desactivado)"
L["desc_milestone_xp"] = "Muestra el progreso de PE hasta el siguiente hito en la pestaña Proyectos del Panel de hogares de Blizzard. Desactívalo si usas otro addon para esto (p. ej., Endeavor Simple Progress Tracker)."
L["desc_export"] = "Exporta los datos de vendedores escaneados como copia de seguridad."
L["desc_export_new"] = "Exporta los vendedores escaneados desde tu última exportación. Incluye precio, monedas, facción e información del catálogo."
L["desc_export_all"] = "Exporta todos los vendedores escaneados, sin aplicar el filtro de fecha."

-------------------------------------------------------------------------------
-- Options - Select Values
-------------------------------------------------------------------------------
-- Pin colors
L["Default (Gold)"] = "Predeterminado (dorado)"
L["Bright Green"] = "Verde intenso"
L["Ice Blue"] = "Azul hielo"
L["Light Blue"] = "Azul claro"
L["Purple"] = "Morado"
L["Pink"] = "Rosa"
L["Red"] = "Rojo"
L["Cyan"] = "Cian"
L["White"] = "Blanco"
L["Yellow"] = "Amarillo"
L["Custom..."] = "Personalizado..."

-- Icon anchor positions
L["Top Left"] = "Arriba a la izquierda"
L["Top Right"] = "Arriba a la derecha"
L["Bottom Left"] = "Abajo a la izquierda"
L["Bottom Right"] = "Abajo a la derecha"
L["Center"] = "Centro"

-- Owned item styles
L["Green highlight (default)"] = "Resaltado verde (predeterminado)"
L["None"] = "Ninguno"
L["Dimmed"] = "Atenuado"
L["Checkmark"] = "Marca de verificación"

-- Source filter
L["All sources"] = "Todos los orígenes"

-- Minimap cross-zone mode
L["Auto (recommended)"] = "Automático (recomendado)"
L["Current zone only"] = "Solo la zona actual"
L["Always show nearby zones"] = "Mostrar siempre zonas cercanas"

-- Navigate modifier
L["None (always)"] = "Ninguno (siempre)"

-- Misc
L["Approximate map appearance"] = "Apariencia aproximada en el mapa"
L["ExportImport not available."] = "ExportImport no está disponible."
