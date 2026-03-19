--[[
    Homestead - Locale: Portuguese (BR)
    Machine-translated — contributions welcome
]]

local addonName, HA = ...

if GetLocale() ~= "ptBR" then return end

-- Initialize localization table
local L = {}
HA.L = L

-------------------------------------------------------------------------------
-- Collection Status
-------------------------------------------------------------------------------
L["Collected"] = "Coletado"
L["Collected (Placed)"] = "Coletado (Posicionado)"
L["Not Collected"] = "Não coletado"
L["Unknown"] = "Desconhecido"

-------------------------------------------------------------------------------
-- Source Descriptions
-------------------------------------------------------------------------------
L["Available from vendor"] = "Disponível no vendedor"
L["Can be crafted"] = "Pode ser fabricado"
L["Achievement reward"] = "Recompensa de conquista"
L["World drop"] = "Saque no mundo"
L["Quest reward"] = "Recompensa de missão"
L["Reputation reward"] = "Recompensa de reputação"
L["Event reward"] = "Recompensa de evento"
L["Promotional item"] = "Item promocional"

-------------------------------------------------------------------------------
-- Decor Properties
-------------------------------------------------------------------------------
L["Can be dyed"] = "Pode ser tingido"
L["Colorable"] = "Tingível"
L["Warbound"] = "Vinculado à tropa"
L["Indoor only"] = "Apenas interior"
L["Outdoor only"] = "Apenas exterior"
L["Quantity owned: %d"] = "Quantidade possuída: %d"
L["Currently placed: %d"] = "Atualmente posicionados: %d"

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["[Housing Addon]"] = "|cFF00FF00[Homestead]|r"
L["Source:"] = "Fonte:"
L["Vendor:"] = "Vendedor:"
L["Location:"] = "Localização:"
L["Click to set waypoint"] = "Clique para definir ponto de rota"

-------------------------------------------------------------------------------
-- UI Labels
-------------------------------------------------------------------------------
L["Housing Addon"] = "Homestead"
L["Decor Browser"] = "Explorador de decoração"
L["Vendor Tracer"] = "Buscador de vendedores"
L["Color Tracker"] = "Rastreador de tintas"
L["Export Data"] = "Exportar dados"
L["Options"] = "Opções"
L["Search"] = "Procurar"
L["Filter"] = "Filtrar"
L["Close"] = "Fechar"

-------------------------------------------------------------------------------
-- Vendor Tracer
-------------------------------------------------------------------------------
L["Set Waypoint"] = "Definir ponto de rota"
L["Show on Map"] = "Mostrar no mapa"
L["Vendor sells %d decor items"] = "O vendedor oferece %d itens de decoração"
L["You own %d/%d items"] = "Você possui %d/%d itens"
L["Missing items:"] = "Itens faltando:"
L["No vendors found"] = "Nenhum vendedor encontrado"

-------------------------------------------------------------------------------
-- Color/Dye Tracker
-------------------------------------------------------------------------------
L["Dye Collection"] = "Coleção de tintas"
L["Owned Dyes"] = "Tintas possuídas"
L["Known Recipes"] = "Receitas conhecidas"
L["Dye Slots"] = "Espaços de tinta"
L["Apply Dye"] = "Aplicar tinta"
L["Preview"] = "Prévia"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["General"] = "Geral"
L["Overlays"] = "Sobreposições"
L["Tooltips"] = "Dicas"
L["Export"] = "Exportar"

L["Enable addon"] = "Ativar addon"
L["Show minimap button"] = "Mostrar botão do minimapa"
L["Enable overlays"] = "Ativar sobreposições"
L["Show on bags"] = "Mostrar nas bolsas"
L["Show on bank"] = "Mostrar no banco"
L["Show on merchant"] = "Mostrar no vendedor"
L["Show on auction house"] = "Mostrar na casa de leilões"
L["Show on housing catalog"] = "Mostrar no catálogo de moradia"
L["Icon size"] = "Tamanho do ícone"
L["Icon position"] = "Posição do ícone"
L["Show opposite faction vendors"] = "Mostrar vendedores da facção oposta"
L["Show unverified vendors"] = "Mostrar vendedores não verificados"

L["Enable tooltip additions"] = "Ativar informações adicionais"
L["Show source information"] = "Mostrar informações de fonte"
L["Show quantity owned"] = "Mostrar quantidade possuída"
L["Show dye slot information"] = "Mostrar informações de espaços de tinta"
L["Show vendor details in tooltips"] = "Mostrar detalhes do vendedor nas dicas"

L["Show map pins"] = "Mostrar marcadores no mapa"
L["Show minimap pins"] = "Mostrar marcadores no minimapa"
L["Use TomTom for waypoints"] = "Usar TomTom para pontos de rota"
L["Use native waypoints"] = "Usar pontos de rota nativos"
L["Auto-create waypoint on click"] = "Criar ponto de rota automaticamente ao clicar"
L["Navigate modifier key"] = "Tecla modificadora de navegação"

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d / %d (%d%%)"] = "Coleção: %d / %d (%d%%)"
L["Vendors nearby: %d"] = "Vendedores próximos: %d"
L["Vendors scanned: %d"] = "Vendedores escaneados: %d"
L["Left-Click: Toggle options"] = "|cFFFFFFFFClique esquerdo:|r Abrir opções"
L["Right-Click: Detach/close vendor panel"] = "|cFFFFFFFFClique direito:|r Separar/fechar painel de vendedores"
L["Middle-Click: Scan collection"] = "|cFFFFFFFFClique do meio:|r Escanear coleção"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Comandos do Homestead:"
L["/hs - Open options panel"] = "/hs — Abrir opções"
L["/hs scan - Scan catalog"] = "/hs scan — Escanear catálogo"
L["/hs vendor [search] - Search vendors"] = "/hs vendor [busca] — Buscar vendedores de decoração"
L["/hs export - Show export dialog"] = "/hs export — Mostrar diálogo de exportação"
L["/hs debug - Toggle debug mode"] = "/hs debug — Alternar modo de depuração"
L["/hs help - Show this help"] = "/hs help — Mostrar esta ajuda"

-------------------------------------------------------------------------------
-- Slash Command Feedback
-------------------------------------------------------------------------------
L["Map pins refreshed."] = "Marcadores do mapa atualizados."
L["No active waypoint."] = "Nenhum ponto de rota ativo."
L["Waypoint cleared."] = "Ponto de rota removido."
L["Vendor database contains %d vendors."] = "O banco de dados contém %d vendedores."
L["Use /hs vendor <name or zone> to search."] = "Use /hs vendor <nome ou zona> para buscar."
L["No vendors found matching: %s"] = "Nenhum vendedor encontrado para: %s"
L["Found %d vendor(s) matching: %s"] = "%d vendedor(es) encontrado(s) para: %s"
L["... and %d more."] = "... e mais %d."

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "Modo de depuração: %s"
L["ON"] = "ATIVADO"
L["OFF"] = "DESATIVADO"
L["Unknown command: %s"] = "Comando desconhecido: %s"
L["Not yet implemented"] = "Ainda não implementado"

-------------------------------------------------------------------------------
-- Export Dialog
-------------------------------------------------------------------------------
L["Export Vendor Data"] = "Exportar dados de vendedores"
L["Choose export option:"] = "Escolha uma opção de exportação:"
L["Export New Scans"] = "Exportar novos escaneamentos"
L["Export All"] = "Exportar tudo"

-------------------------------------------------------------------------------
-- Map Side Panel
-------------------------------------------------------------------------------
L["All"] = "Todos"
L["Vendor"] = "Vendedor"
L["Quest"] = "Missão"
L["Achievement"] = "Conquista"
L["Profession"] = "Profissão"
L["Event"] = "Evento"
L["Drop"] = "Saque"
L["Zone Collection Progress"] = "Progresso da coleção da zona"
L["Continent Collection Progress"] = "Progresso da coleção do continente"
L["Global Collection Progress"] = "Progresso global da coleção"
L["Order Hall"] = "Sede da ordem"
L["Click to preview"] = "Clique para visualizar"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "Resultado"
L["Select All"] = "Selecionar tudo"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "Texto selecionado. Pressione Ctrl+C para copiar."

-------------------------------------------------------------------------------
-- Statistics
-------------------------------------------------------------------------------
L["Statistics"] = "Estatísticas"
L["Total Decor:"] = "Decoração total:"
L["Collected:"] = "Coletado:"
L["Placed:"] = "Posicionado:"
L["Remaining:"] = "Restante:"
L["Collection Progress: %d%%"] = "Progresso da coleção: %d%%"
