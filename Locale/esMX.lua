--[[
    Homestead - Locale: Spanish (MX / Latin America)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "esMX" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["Used in %d known recipe for decor you haven't collected"] = "Se usa en %d receta conocida de decoración que no has obtenido"
L["Used in %d known recipes for decor you haven't collected"] = "Se usa en %d recetas conocidas de decoración que no has obtenido"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["Homestead"] = "Homestead"
L["Homestead Options"] = "Opciones de Homestead"
L["Overlays"] = "Indicadores"
L["Tooltips"] = "Descripciones emergentes"
L["Export"] = "Exportar"

L["Show minimap button"] = "Mostrar botón del minimapa"
L["Enable overlays"] = "Activar indicadores"
L["Show on bags"] = "Mostrar en bolsas"
L["Show on bank"] = "Mostrar en el banco"
L["Show on merchant"] = "Mostrar en comerciantes"
L["Show on housing catalog"] = "Mostrar en el catálogo de viviendas"
L["Icon size"] = "Tamaño de ícono"
L["Icon position"] = "Posición del ícono"
L["Show opposite faction vendors"] = "Mostrar vendedores de la facción contraria"

L["Enable tooltip additions"] = "Activar añadidos en descripciones"
L["Show source information"] = "Mostrar información de procedencia"
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
L["No vendors found matching: %s"] = "No se encontraron vendedores que coincidan con: %s"
L["Found %d vendor(s) matching: %s"] = "Vendedores encontrados: %d para la búsqueda: %s"
L["... and %d more."] = "... y %d más."

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "Modo de depuración: %s"
L["ON"] = "Activado"
L["OFF"] = "Desactivado"
L["Unknown command: %s"] = "Comando desconocido: %s"
L["Type /hs help for a list of commands."] = "Escribe /hs help para ver la lista de comandos."

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
L["All"] = "Todas"
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
L["Click to preview"] = "Clic para vista previa"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "Resultado"
L["Select All"] = "Seleccionar todo"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "Todo el texto está seleccionado. Presiona Ctrl+C para copiarlo al portapapeles."

-------------------------------------------------------------------------------
-- Options - Names
-------------------------------------------------------------------------------
L["Vendor pin item details"] = "Detalles de objetos en marcadores de vendedor"

L["Auto-scan vendors"] = "Escanear vendedores automáticamente"
L["Vendor Visibility"] = "Visibilidad de vendedores"
L["Show event vendors"] = "Mostrar vendedores de evento"
L["Hide fully-collected vendor pins"] = "No marcar vendedores con todo obtenido"
L["Fully-collected vendors"] = "Vendedores con todo obtenido"
L["desc_map_filter_completed_vendors"] = "Desmarca esta opción para ocultar los marcadores de los vendedores cuya decoración ya hayas obtenido por completo."
L["Pin Appearance"] = "Apariencia de marcadores"
L["Pin color"] = "Color de marcadores"
L["Custom color"] = "Color personalizado"
L["Show accessibility glow"] = "Mostrar brillo de accesibilidad"
L["Owned item style"] = "Estilo de objetos poseídos"
L["Show ownership status"] = "Mostrar estado de posesión"
L["Show requirements"] = "Mostrar requisitos"
L["Show all sources"] = "Mostrar todas las procedencias"
L["Map Pins"] = "Marcadores del mapa"
L["Show vendor panel on world map"] = "Panel de vendedores en el mapa del mundo"
L["Vendor panel source filter"] = "Filtro de procedencia del panel de vendedores"
L["Integrate with map frame border"] = "Integrar con el borde del marco del mapa"
L["Zone badges on world map"] = "Insignias de zona en el mapa del mundo"
L["World map pin size"] = "Tamaño de marcadores en el mapa del mundo"
L["Show collection counts"] = "Mostrar recuentos de colección"
L["Show elevation arrows"] = "Mostrar flechas de altura"
L["Minimap nearby-zone pins"] = "Marcadores de zonas cercanas en el minimapa"
L["Minimap pin size"] = "Tamaño de marcadores en el minimapa"
L["Waypoints"] = "Puntos de ruta"
L["Show milestone progress on dashboard"] = "Progreso de hitos en el Panel de viviendas"
L["Inventory"] = "Inventario"
L["Merchant"] = "Comerciante"
L["Housing Catalog"] = "Catálogo de viviendas"

-------------------------------------------------------------------------------
-- Options - Descriptions
-------------------------------------------------------------------------------
L["desc_minimap_button"] = "Muestra u oculta el botón del minimapa"
L["desc_auto_scan_vendors"] = "Escanea automáticamente el inventario de los comerciantes en busca de datos de decoración de viviendas al visitar vendedores. Desactivarlo puede mejorar ligeramente el rendimiento al abrir comerciantes."
L["desc_options_general"] = "Comportamiento básico del addon, acceso desde el minimapa, escaneo de vendedores y apariencia de los marcadores del mapa."
L["desc_options_overlays"] = "Indicadores de colección en las bolsas, el banco, los comerciantes y el Catálogo de viviendas."
L["desc_options_tooltips"] = "Detalles adicionales de posesión, procedencia, requisitos y vendedores en las descripciones emergentes de objetos y de marcadores del mapa."
L["desc_options_world_map"] = "Marcadores de vendedores en el mapa del mundo, insignias de zona, comportamiento del panel lateral y visualización de marcadores."
L["desc_options_minimap"] = "Marcadores de vendedores cercanos, flechas de altura y comportamiento de los puntos de ruta en el minimapa."
L["desc_options_endeavors"] = "Progreso de los Retos de viviendas en el Panel de viviendas de Blizzard."
L["desc_options_export"] = "Exportación de los datos de vendedores escaneados para revisión o copia de seguridad."
L["desc_vendor_visibility_section"] = "Elige qué grupos de vendedores aparecen en los mapas y en los totales de colección."
L["desc_pin_appearance_section"] = "Ajusta el color y la vista previa de los marcadores de vendedores de Homestead."
L["desc_overlay_inventory_section"] = "Muestra indicadores de colección en las casillas de objetos fuera del Catálogo de viviendas."
L["desc_overlay_merchant_section"] = "Marca la decoración obtenida mientras ves los objetos de los vendedores."
L["desc_overlay_catalog_section"] = "Controla los indicadores, los resaltados y el estilo de los objetos obtenidos en el Catálogo de viviendas."
L["desc_tooltip_map_pins_section"] = "Elige cuántos detalles del vendedor aparecen en las descripciones emergentes de los marcadores del mapa."
L["desc_minimap_waypoints_section"] = "Configura el comportamiento de los puntos de ruta de TomTom y del juego al hacer clic en el mapa y en los vendedores."
L["desc_opposite_faction"] = "Muestra los vendedores de la facción contraria con su emblema de facción. Útil para completistas que quieren ver todos los vendedores disponibles."
L["desc_event_vendors"] = "Muestra en el mapa los marcadores de vendedores de fiestas de temporada cuando su evento está activo (p. ej., Festival Lunar)"
L["desc_hide_completed_vendor_pins"] = "Oculta los marcadores del mapa y del minimapa de los vendedores cuya decoración de viviendas ya hayas obtenido por completo. La lista del panel de vendedores no cambia."
L["desc_pin_color"] = "Elige un color para los marcadores del mapa y del minimapa."
L["desc_custom_color"] = "Elige un color base personalizado para los marcadores del mapa"
L["desc_enable_overlays"] = "Agrega pequeños íconos y resaltados a los objetos de decoración en todo el juego para que veas de un vistazo cuáles ya obtuviste. Al desactivarlo se ocultan todos los indicadores de Homestead en todas partes."
L["desc_icon_size"] = "Controla el tamaño de los íconos de colección en las casillas de objetos."
L["desc_icon_position"] = "En qué esquina de la casilla del objeto se coloca el ícono de colección."
L["desc_show_on_bags"] = "Agrega un |A:homestone-minimap-icon:16:16|a a los objetos de decoración de tus bolsas, con un color que indica si ya obtuviste cada uno. Funciona con las bolsas predeterminadas, Baganator y BetterBags."
L["desc_show_on_bank"] = "Marca los objetos de decoración de tu banco para que veas cuáles ya obtuviste."
L["desc_show_on_merchant"] = "Agrega un |A:homestone-minimap-icon:16:16|a a los objetos de decoración de los vendedores, con un color que indica si ya obtuviste cada uno."
L["desc_show_on_housing_catalog"] = "Marca los objetos del Catálogo de viviendas con íconos de colección que indican la procedencia de cada objeto.\n\n|A:auctionhouse-icon-coin-gold:16:16|a Vendedor\n|A:QuestNormal:16:16|a Misión\n|A:UI-Achievement-Shield-NoPoints:16:16|a Logro\n|A:UI-HUD-MicroMenu-Professions-Mouseover:16:16|a Profesión\n|A:UI-HUD-Calendar-1-Up:16:16|a Evento\n|A:Crosshair_lootall_64:16:16|a Botín\n|A:hearthsteel-icon-32x32:16:16|a Tienda de Battle.net"
L["desc_accessibility_glow"] = "Agrega un brillo de color en el borde de los objetos del Catálogo de viviendas: verde para los que tienes, amarillo para los que puedes conseguir y rojo para los bloqueados por requisitos que aún no cumples."
L["desc_owned_item_style"] = "Elige cómo se ven los objetos obtenidos en el Catálogo de viviendas. Resaltado verde muestra el brillo predeterminado, Atenuado los desvanece y Marca de verificación agrega una pequeña marca verde. Elige Ninguno para dejarlos sin cambios."
L["desc_enable_tooltips"] = "Agrega información de Homestead a las descripciones emergentes de los objetos al pasar el cursor sobre objetos de decoración. Al desactivarlo se eliminan todos los añadidos a las descripciones."
L["desc_show_ownership"] = "Agrega una línea a las descripciones emergentes que indica si ya obtuviste un objeto de decoración."
L["desc_show_source"] = "Muestra cómo conseguir un objeto de decoración: vendedores, misiones, logros, profesiones, eventos y botín."
L["desc_show_requirements"] = "Muestra los requisitos de compra, como reputación, misiones completadas o logros necesarios para comprar un objeto."
L["desc_show_all_sources"] = "Muestra todas las formas conocidas de conseguir un objeto en lugar de solo la mejor procedencia disponible. Útil cuando un objeto se puede conseguir de varios vendedores, misiones u otras procedencias."
L["desc_vendor_details"] = "Muestra el inventario completo de un vendedor y tu progreso de colección al pasar el cursor sobre su marcador en el mapa. Desactívalo para una descripción más simple con solo el nombre del vendedor."
L["desc_vendor_pin_item_details"] = "Muestra los íconos de procedencia alternativa y el costo de vendedor de cada objeto, además del recuento de objetos exclusivos de vendedor, en las descripciones emergentes de los marcadores del mapa. Desactívalo para una descripción más simple que solo lista los nombres de los objetos."
L["desc_show_map_pins"] = "Muestra la ubicación de los vendedores en el mapa del mundo"
L["desc_show_map_side_panel"] = "Muestra un panel lateral en el mapa del mundo con los vendedores y el progreso de colección de la zona actual"
L["desc_source_filter"] = "Filtra por procedencia los recuentos de objetos del panel lateral y las cuadrículas expandidas. La visibilidad de los vendedores en el mapa no cambia."
L["desc_integrate_map_border"] = "Une el borde superior del panel con el borde del mapa del mundo para un aspecto continuo. Desactívalo si usas una interfaz personalizada (ElvUI, GW2, etc.) que cause conflictos."
L["desc_zone_badges"] = "Muestra el número de vendedores por zona repartido por los continentes en el mapa del mundo, en lugar de un único total por continente."
L["desc_world_pin_size"] = "Ajusta el tamaño de los marcadores de vendedores en el mapa del mundo. El valor predeterminado (20) coincide con los íconos de puntos de interés de Blizzard."
L["desc_show_pin_counts"] = "Muestra el recuento de objetos obtenidos/totales en los marcadores de vendedores (p. ej., 3/12). Desactívalo para despejar el mapa."
L["desc_show_minimap_pins"] = "Muestra la ubicación de los vendedores en el minimapa con flechas de altura"
L["desc_elevation_arrows"] = "Muestra flechas de dirección en los marcadores del minimapa cuando un vendedor está por encima o por debajo de ti"
L["desc_cross_zone_mode"] = "Controla los marcadores del minimapa de otras zonas. Automático reduce los marcadores adicionales en zonas de ciudades concurridas para un movimiento más fluido."
L["desc_minimap_pin_size"] = "Ajusta el tamaño de los marcadores de vendedores en el minimapa. Auméntalo si los marcadores se ven con dificultad, o redúcelo para despejar el minimapa."
L["desc_waypoint_info"] = "TomTom muestra una flecha de dirección superpuesta y requiere tener instalado el addon TomTom. El sistema del juego agrega un marcador de destino al mapa del mundo. Ambos pueden estar activos a la vez."
L["desc_use_tomtom"] = "Usa el addon TomTom para las flechas de los puntos de ruta (si está instalado)"
L["desc_use_native_waypoints"] = "Usa el sistema de puntos de ruta integrado de WoW con marcador de mapa"
L["desc_auto_waypoint"] = "Crea automáticamente un punto de ruta al hacer clic en un vendedor de la lista o del mapa"
L["desc_navigate_modifier"] = "Mantén presionada esta tecla al hacer clic para crear un punto de ruta (si el punto de ruta automático está desactivado)"
L["desc_milestone_xp"] = "Muestra el progreso de PE hacia el siguiente hito en la pestaña Retos del Panel de viviendas de Blizzard. Desactívalo si usas otro addon para esto (p. ej., Endeavor Simple Progress Tracker)."
L["desc_export"] = "Exporta los datos de vendedores escaneados como copia de seguridad."
L["desc_export_new"] = "Exporta los vendedores escaneados desde tu última exportación. Incluye precio, monedas, facción e información del catálogo."
L["desc_export_all"] = "Exporta todos los vendedores escaneados, sin aplicar el filtro de fecha."

-------------------------------------------------------------------------------
-- Options - Select Values
-------------------------------------------------------------------------------
-- Pin colors
L["Default (Gold)"] = "Predeterminado (dorado)"
L["Bright Green"] = "Verde brillante"
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
L["All sources"] = "Todas las procedencias"

-- Minimap cross-zone mode
L["Auto (recommended)"] = "Automático (recomendado)"
L["Current zone only"] = "Solo la zona actual"
L["Always show nearby zones"] = "Mostrar siempre zonas cercanas"

-- Navigate modifier
L["None (always)"] = "Ninguno (siempre)"

-- Misc
L["Approximate map appearance"] = "Apariencia aproximada en el mapa"
L["ExportImport not available."] = "ExportImport no está disponible."

-------------------------------------------------------------------------------
-- Decor Browser
-------------------------------------------------------------------------------
-- Decor Browser: minimap tooltip
L["Left-Click: Toggle Decor Browser"] = "|cFFFFFFFFClic izquierdo:|r Mostrar/ocultar el explorador de decoración"
L["Right-Click: Open options"] = "|cFFFFFFFFClic derecho:|r Abrir opciones"

-- Decor Browser: data adapter
L["Gold"] = "Oro"
L["Unknown"] = "Desconocido"
L["Required"] = "Obligatorio"
L["Unknown faction"] = "Facción desconocida"
L["Other requirement"] = "Otro requisito"
L["Source unknown"] = "Procedencia desconocida"
L["Item %d"] = "Artículo %d"
L["%s %s"] = "%s %s"
L["%s, %s"] = "%s, %s"
L["%s - %s"] = "%s - %s"
L["%s (%s)"] = "%s (%s)"
L["%s: %s"] = "%s: %s"
L["%s with %s"] = "%s con %s"
L["Level %s"] = "Nivel %s"
L["Achievement: %s"] = "Logro: %s"
L["Quest: %s"] = "Misión: %s"
L["Promotion: %s"] = "Promoción: %s"
L["Profession: %s"] = "Profesión: %s"
L["Profession: %s rank %s"] = "Profesión: %s, rango %s"
L["Vendor: %s"] = "Vendedor: %s"
L["Vendor: %s, %s"] = "Vendedor: %s, %s"
L["Crafted: %s - %s"] = "Fabricado: %s - %s"
L["Drops from %s"] = "Botín de %s"
L["Drops from %s (%s)"] = "Botín de %s (%s)"
L["Event: %s"] = "Evento: %s"
L["Event: %s - %s"] = "Evento: %s - %s"
L["Other source"] = "Otra procedencia"

-- Decor Browser: visuals and widgets
L["Owned"] = "En tu poder"
L["Unlocked to buy"] = "Desbloqueado para comprar"
L["Locked"] = "Bloqueado"
L["Set waypoint"] = "Marcar punto de ruta"

-- Decor Browser: window and navigation
L["Homestead Decor"] = "Decoración de Homestead"
L["Summary"] = "Resumen"
L["Catalog"] = "Catálogo"
L["Sources"] = "Fuentes"
L["Help"] = "Ayuda"
L["Hide what doesn't apply to me"] = "Ocultar lo que no me aplica"
L["The Decor Browser opens once Homestead has finished loading."] = "El explorador de decoración se abrirá cuando Homestead termine de cargar."
L["Collection"] = "Colección"
L["Placed"] = "Colocadas"
L["In storage"] = "En almacenamiento"
L["Not yet redeemed"] = "Aún sin canjear"
L["Counts not loaded yet"] = "Conteos aún sin cargar"
L["Source"] = "Procedencia"
L["Price"] = "Precio"

-- Decor Browser: shop and item pages
L[", "] = ", "
L["Seasonal: %s"] = "De temporada: %s"
L["Rotates with the %s Endeavor"] = "Rota con el reto %s"
L["Rotates with neighborhood Endeavors"] = "Rota con los retos del vecindario"
L["You own this."] = "Ya tienes esto."
L["Not available to you yet."] = "Todavía no está disponible para ti."
L["Ownership cannot be read for this kind of item."] = "No se puede consultar la propiedad de este tipo de artículo."
L["Ownership is not known yet."] = "Aún no se sabe si lo tienes."
L["Met: %s"] = "Cumplido: %s"
L["Needs: %s"] = "Necesitas: %s"
L["Unknown: %s"] = "Desconocido: %s"
L["Status"] = "Estado"
L["Requirement"] = "Requisito"
L["Sold by"] = "Lo vende"
L["Not listed"] = "Sin listar"
L["Not sold by a vendor"] = "No lo vende ningún vendedor"
L["+%d more vendors"] = "+%d vendedores más"
L["+%d more sources"] = "+%d procedencias más"
L["Also available from"] = "También disponible con"
L["No other sources on record."] = "No hay otras procedencias registradas."
L["Not available in combat"] = "No disponible en combate"
L["Report a data error"] = "Reportar un error en los datos"
L["Item: %s (%d)"] = "Artículo: %s (%d)"
L["Record ID: %s"] = "ID de registro: %s"
L["none"] = "ninguno"
L["no location"] = "sin ubicación"
L["map %d at %.1f, %.1f"] = "mapa %d en %.1f, %.1f"
L["Vendor %d: %s, %s, %s"] = "Vendedor %d: %s, %s, %s"
L["Client: %s (%s)"] = "Cliente: %s (%s)"
L["Homestead: %s"] = "Homestead: %s"

-- Decor Browser: entry points
L["Toggle Decor Browser"] = "Mostrar/ocultar el explorador de decoración"
L["Open the Decor Browser, or bind a key under Keybindings > Homestead"] = "Abre el explorador de decoración, o asigna una tecla en Asignación de teclas > Homestead"
L["Minimap button"] = "Botón del minimapa"
L["Left-click opens the Decor Browser, right-click opens options"] = "El clic izquierdo abre el explorador de decoración y el derecho abre las opciones"

-- Welcome window
L["Find every decor vendor on your map and see what you own before you buy."] = "Encuentra todos los vendedores de decoración en tu mapa y revisa lo que ya tienes antes de comprar."
L["What Homestead Does"] = "Qué hace Homestead"
L["Every decor vendor pinned on your world map and minimap, with badges showing how many items you still need per zone."] = "Todos los vendedores de decoración marcados en tu mapa del mundo y en el minimapa, con insignias que indican cuántos artículos te faltan en cada zona."
L["Map Side Panel"] = "Panel lateral del mapa"
L["Click the Homestead button on the world map to open the side panel listing that zone's vendors, then click any vendor to browse their wares and see what you still need. Pop it out as a standalone window with |cFF00FF00/hs panel|r."] = "Haz clic en el botón de Homestead del mapa del mundo para abrir el panel lateral con los vendedores de esa zona y luego haz clic en cualquiera para ver su mercancía y lo que aún te falta. Sepáralo como ventana independiente con |cFF00FF00/hs panel|r."
L["Tooltips Expanded"] = "Descripciones emergentes ampliadas"
L["Every item in the Housing Catalog gets tooltips showing where it comes from (vendor, quest, achievement, profession, or drop), what it costs, and what you need to unlock it, so you never have to leave the game to look something up."] = "Todos los artículos del catálogo de viviendas muestran descripciones emergentes con su procedencia (vendedor, misión, logro, profesión o botín), su costo y lo que necesitas para desbloquearlos, para que nunca tengas que salir del juego a consultar nada."
L["Key Commands"] = "Comandos principales"
L["Export everything you've scanned"] = "Exportar todo lo que has escaneado"
L["Show all commands"] = "Mostrar todos los comandos"
L["Found a Problem?"] = "¿Encontraste un problema?"
L["Report bugs or wrong vendor info on GitHub using the link below."] = "Reporta errores o datos incorrectos de vendedores en GitHub con el enlace de abajo."
L["Report issues (GitHub):"] = "Reportar problemas (GitHub):"
L["CurseForge:"] = "CurseForge:"
L["Don't show this again"] = "No volver a mostrar"
L["Let's Decorate!"] = "¡A decorar!"

-------------------------------------------------------------------------------
-- Decor Browser: source and vendor labels
-------------------------------------------------------------------------------
L["Achievements"] = "Logros"
L["Quests"] = "Misiones"
L["Professions"] = "Profesiones"
L["Drops"] = "Botín"
L["Events"] = "Eventos"
L["Other"] = "Otro"
L["Location not recorded"] = "Ubicación no registrada"
L["Requires"] = "Requiere"

-------------------------------------------------------------------------------
-- Decor Browser: holiday vendors
-------------------------------------------------------------------------------
L["The Decor Browser is not available yet."] = "El explorador de decoración aún no está disponible."

-------------------------------------------------------------------------------
-- Decor Browser: states and shared parts
-------------------------------------------------------------------------------
L["Collected"] = "Coleccionado"
L["Can get now"] = "Disponible ahora"
L["Requires: %s"] = "Requiere: %s"
L["%s only"] = "Solo %s"
L["Not collected"] = "Sin coleccionar"
L["Counting…"] = "Contando…"
L["Not confirmed"] = "Sin confirmar"
L["Active now"] = "Activo ahora"
L["Best to get now"] = "Lo mejor para conseguir ahora"
L["Search decor by name"] = "Buscar decoración por nombre"
L["Reset filters"] = "Restablecer filtros"
L["Search all decor"] = "Buscar en toda la decoración"
L["Show what's missing"] = "Mostrar lo que falta"
L["Sort by name"] = "Ordenar por nombre"
L["Show them"] = "Mostrarlos"
L["Show vendor"] = "Mostrar vendedor"
L["Report a problem"] = "Reportar un problema"
L["Reading your collection. This list fills in when it's ready."] = "Leyendo tu colección. Esta lista se llena cuando termina."
L["Reading your collection. This list fills in when it's ready, because Best to get now depends on what you own."] = "Leyendo tu colección. Esta lista se llena cuando termina, porque Lo mejor para conseguir ahora depende de lo que tienes."
L["Nothing missing"] = "No falta nada"
L["You've collected all %d decor Homestead knows about."] = "Ya coleccionaste las %d piezas de decoración que conoce Homestead."
L["Nothing you can get right now"] = "Nada disponible por ahora"
L["Everything you're missing needs a reputation, achievement or quest first, is sold only during an event, or is sold only to the %s."] = "Todo lo que te falta requiere antes una reputación, un logro o una misión, se vende solo durante un evento o se vende solo a la %s."
L["Collection not read yet"] = "Colección sin leer"
L["Homestead hasn't read this character's decor collection yet, so it can't tell what you're missing. It reads it shortly after you log in. If this message stays, open the Housing Dashboard once."] = "Homestead todavía no ha leído la colección de decoración de este personaje, así que no puede saber qué te falta. La lee poco después de iniciar sesión. Si este mensaje no desaparece, abre el panel de vivienda una vez."
L["These filters need your collection, which Homestead hasn't read yet. If this stays, open the Housing Dashboard once."] = "Estos filtros necesitan tu colección, que Homestead todavía no ha leído. Si esto continúa, abre el panel de vivienda una vez."
L["No results"] = "Sin resultados"
L["No decor matches these words and filters. Search looks at item names only."] = "Ninguna decoración coincide con estas palabras y filtros. La búsqueda solo revisa los nombres de los objetos."
L["%d hidden by '%s' (%d collected, %d %s only)."] = "%d ocultos por '%s' (%d coleccionados, %d solo %s)."

-------------------------------------------------------------------------------
-- Decor Browser: Summary
-------------------------------------------------------------------------------
L["What can I get now?"] = "¿Qué puedo conseguir ahora?"
L["Decor this character can buy or earn today, best first."] = "Decoración que este personaje puede comprar u obtener hoy, la mejor primero."
L["Can get now means this character can buy or earn it today: the right faction, and no requirement left to meet. The closest ones come first. Use See all for the full list."] = "Disponible ahora significa que este personaje puede comprarlo u obtenerlo hoy: con la facción correcta y sin ningún requisito pendiente. Los más cercanos van primero. Usa Ver todo para ver la lista completa."
L["Search"] = "Buscar"
L["Show"] = "Mostrar"
L["Not yet: next step"] = "Todavía no: siguiente paso"
L["and %d more"] = "y %d más"
L["See all you can get now (%d)"] = "Ver todo lo que puedes conseguir ahora (%d)"
L["Here in %s: %s sells %d decor you can get now."] = "Aquí en %s: %s vende %d piezas de decoración que puedes conseguir ahora."
L["Sold here in %s"] = "Se vende aquí en %s"
L["Sold on %s"] = "Se vende en %s"
L["%s: active now"] = "%s: activo ahora"
L["Gold only"] = "Solo oro"
L["Gold only, no requirements left"] = "Solo oro, sin requisitos pendientes"
L["No requirements left"] = "Sin requisitos pendientes"
L["By source"] = "Por procedencia"
L["%d of %d"] = "%d de %d"
L["Not read yet"] = "Todavía sin leer"
L["Decor collected, by where it comes from. Pick one to see each source."] = "Decoración coleccionada, según su procedencia. Elige una para ver cada fuente."
L["Reading your collection"] = "Leyendo tu colección"
-- end: Summary

-------------------------------------------------------------------------------
-- Decor Browser: Catalog
-------------------------------------------------------------------------------
L["All decor"] = "Toda la decoración"
L["Filters"] = "Filtros"
L["Name"] = "Nombre"
L["Sort: %s"] = "Orden: %s"
L["Furnishings"] = "Mobiliario"
L["Structural"] = "Estructuras"
L["Accents"] = "Acentos"
L["Lighting"] = "Iluminación"
L["Neither collected nor not collected"] = "Ni coleccionado ni sin coleccionar"
L["Sources: %s"] = "Fuentes: %s"
L["Filtered: %s"] = "Filtrado: %s"
L["(+%d more)"] = "(+%d más)"
-- end: Catalog

-------------------------------------------------------------------------------
-- Decor Browser: Sources
-------------------------------------------------------------------------------
L["Search vendors and zones"] = "Buscar vendedores y zonas"
L["Search achievements"] = "Buscar logros"
L["Search quests"] = "Buscar misiones"
L["Search recipes and professions"] = "Buscar recetas y profesiones"
L["Search drops and zones"] = "Buscar botín y zonas"
L["Search events"] = "Buscar eventos"
L["Search the Shop"] = "Buscar en la tienda"
L["Here in %s"] = "Aquí en %s"
L["%d decor"] = "%d decoraciones"
L["No decor"] = "Sin decoraciones"
L["Not active"] = "No activo"
L["All collected"] = "Todo recopilado"
L["%d can get now"] = "%d disponibles ahora"
L["Holiday event"] = "Evento festivo"
L["%s only: can't buy on this character"] = "Solo %s: no se puede comprar con este personaje"
L["%s vendor"] = "Vendedor de %s"
L["Confirmed by a scan on %s"] = "Confirmado por un escaneo el %s"
L["No scan has confirmed this vendor yet. Visit the vendor to check."] = "Ningún escaneo ha confirmado aún a este vendedor. Visita al vendedor para comprobarlo."
L["Sells %d decor."] = "Vende %d decoraciones."
L["Gives %d decor."] = "Da %d decoraciones."
L["You have %d."] = "Tienes %d."
L["%d you can get now."] = "Puedes conseguir %d ahora."
L["Decor sold here"] = "Decoración a la venta aquí"
L["Decor from this source"] = "Decoración de esta fuente"
L["No decor is recorded here. If this source gives decor, report it below."] = "No hay decoración registrada aquí. Si esta fuente da decoración, infórmalo abajo."
L["Pick a source to see its decor."] = "Elige una fuente para ver su decoración."
L["Quest starts in %s"] = "La misión empieza en %s"
L["Dig site in %s"] = "Zona de excavación en %s"
L["No model shown"] = "Sin modelo"
L["No events active right now. Event decor is sold only while its event runs."] = "No hay eventos activos ahora mismo. La decoración de evento solo se vende mientras dura el evento."
L["Nothing matches your search."] = "Nada coincide con tu búsqueda."
L["Nothing to show here."] = "No hay nada que mostrar aquí."
-- end: Sources

-------------------------------------------------------------------------------
-- Decor Browser: Item
-------------------------------------------------------------------------------
L["Vendor:"] = "Vendedor:"
L["Zone:"] = "Zona:"
L["Cost:"] = "Costo:"
L["Achievement:"] = "Logro:"
L["Quest:"] = "Misión:"
L["Recipe:"] = "Receta:"
L["Profession:"] = "Profesión:"
L["Drop:"] = "Botín:"
L["Event:"] = "Evento:"
L["Starts in %s"] = "Comienza en %s"
L["Daily from The Last Architect"] = "Diaria de The Last Architect"
L["Set dig site waypoint"] = "Marcar punto de ruta del sitio de excavación"
L["Can get now here"] = "Disponible ahora aquí"
L["Where to get it"] = "Dónde obtenerlo"
L["Show achievement"] = "Mostrar logro"
L["Show quest"] = "Mostrar misión"
L["Show recipe"] = "Mostrar receta"
L["Show drop"] = "Mostrar botín"
L["Show event"] = "Mostrar evento"
L["%s (done)"] = "%s (hecho)"
L["%s (not yet)"] = "%s (aún no)"
L["Active now: %s"] = "Activo ahora: %s"
-- end: Item
