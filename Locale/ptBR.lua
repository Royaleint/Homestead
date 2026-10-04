--[[
    Homestead - Locale: Portuguese (BR)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "ptBR" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- UI Labels
-------------------------------------------------------------------------------
L["Close"] = "Fechar"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["General"] = "Geral"
L["Overlays"] = "Sobreposições"
L["Tooltips"] = "Dicas"
L["Export"] = "Exportar"

L["Show minimap button"] = "Mostrar botão do minimapa"
L["Enable overlays"] = "Ativar sobreposições"
L["Show on bags"] = "Mostrar nas bolsas"
L["Show on bank"] = "Mostrar no banco"
L["Show on merchant"] = "Mostrar no vendedor"
L["Show on housing catalog"] = "Mostrar no catálogo de moradia"
L["Icon size"] = "Tamanho do ícone"
L["Icon position"] = "Posição do ícone"
L["Show opposite faction vendors"] = "Mostrar vendedores da facção oposta"

L["Enable tooltip additions"] = "Ativar informações adicionais"
L["Show source information"] = "Mostrar informações de fonte"
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

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Comandos do Homestead:"

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

