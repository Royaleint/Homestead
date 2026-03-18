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
L["Search"] = "Buscar"
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
L["Preview"] = "Visualizar"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["General"] = "Geral"
L["Overlays"] = "Sobreposições"
L["Tooltips"] = "Dicas"
L["Vendor Tracer"] = "Buscador de vendedores"
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

L["Enable tooltip additions"] = "Ativar informações adicionais"
L["Show source information"] = "Mostrar informações de fonte"
L["Show quantity owned"] = "Mostrar quantidade possuída"
L["Show dye slot information"] = "Mostrar informações de espaços de tinta"

L["Show map pins"] = "Mostrar marcadores no mapa"
L["Show minimap pins"] = "Mostrar marcadores no minimapa"
L["Use TomTom for waypoints"] = "Usar TomTom para pontos de rota"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Housing Addon Commands:"] = "Comandos do Homestead:"
L["/ha - Toggle main window"] = "/ha — Abrir/fechar janela principal"
L["/ha options - Open options panel"] = "/ha options — Abrir painel de opções"
L["/ha export - Export collection data"] = "/ha export — Exportar dados da coleção"
L["/ha vendor [search] - Open vendor panel"] = "/ha vendor [busca] — Abrir painel de vendedores"
L["/ha debug - Toggle debug mode"] = "/ha debug — Alternar modo de depuração"
L["/ha help - Show this help"] = "/ha help — Mostrar esta ajuda"

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "Modo de depuração: %s"
L["ON"] = "ATIVADO"
L["OFF"] = "DESATIVADO"
L["Unknown command: %s"] = "Comando desconhecido: %s"
L["Not yet implemented"] = "Ainda não implementado"

-------------------------------------------------------------------------------
-- Statistics
-------------------------------------------------------------------------------
L["Statistics"] = "Estatísticas"
L["Total Decor:"] = "Decoração total:"
L["Collected:"] = "Coletado:"
L["Placed:"] = "Posicionado:"
L["Remaining:"] = "Restante:"
L["Collection Progress: %d%%"] = "Progresso da coleção: %d%%"
