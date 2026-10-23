--[[
    Homestead - Locale: Portuguese (BR)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "ptBR" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["Used in %d known recipe for decor you haven't collected"] = "Usado em %d receita conhecida de decoração que você não coletou"
L["Used in %d known recipes for decor you haven't collected"] = "Usado em %d receitas conhecidas de decorações que você não coletou"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["Homestead"] = "Homestead"
L["Homestead Options"] = "Opções do Homestead"
L["Overlays"] = "Sobreposições"
L["Tooltips"] = "Dicas de Interface"
L["Export"] = "Exportar"

L["Show minimap button"] = "Mostrar botão no minimapa"
L["Enable overlays"] = "Ativar sobreposições"
L["Show on bags"] = "Mostrar nas bolsas"
L["Show on bank"] = "Mostrar no banco"
L["Show on merchant"] = "Mostrar no comerciante"
L["Show on housing catalog"] = "Mostrar no catálogo de moradia"
L["Icon size"] = "Tamanho do ícone"
L["Icon position"] = "Posição do ícone"
L["Show opposite faction vendors"] = "Mostrar comerciantes da facção oposta"

L["Enable tooltip additions"] = "Ativar acréscimos nas dicas"
L["Show source information"] = "Mostrar informações de origem"
L["Show vendor details in tooltips"] = "Detalhes do comerciante nas dicas"

L["Show map pins"] = "Mostrar marcadores no mapa"
L["Show minimap pins"] = "Mostrar marcadores no minimapa"
L["Use TomTom for waypoints"] = "Usar TomTom para pontos de rota"
L["Use native waypoints"] = "Usar pontos de rota nativos"
L["Auto-create waypoint on click"] = "Ponto de rota automático ao clicar"
L["Navigate modifier key"] = "Tecla modificadora de navegação"

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d / %d (%d%%)"] = "Coleção: %d / %d (%d%%)"
L["Vendors nearby: %d"] = "Comerciantes próximos: %d"
L["Vendors scanned: %d"] = "Comerciantes escaneados: %d"
L["Left-Click: Toggle Decor Browser"] = "|cFFFFFFFFClique esquerdo:|r Abrir/fechar o navegador de decoração"
L["Right-Click: Open options"] = "|cFFFFFFFFClique direito:|r Abrir opções"

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
L["Vendor database contains %d vendors."] = "O banco de dados de comerciantes contém %d comerciantes."
L["Use /hs vendor <name or zone> to search."] = "Use /hs vendor <nome ou zona> para buscar."
L["No vendors found matching: %s"] = "Nenhum comerciante encontrado para: %s"
L["Found %d vendor(s) matching: %s"] = "Comerciantes encontrados (%d) para: %s"
L["... and %d more."] = "... e mais %d."

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "Modo de depuração: %s"
L["ON"] = "Ativado"
L["OFF"] = "Desativado"
L["Unknown command: %s"] = "Comando desconhecido: %s"
L["Type /hs help for a list of commands."] = "Digite /hs help para ver a lista de comandos."

-------------------------------------------------------------------------------
-- Version Check
-------------------------------------------------------------------------------
L["Your Homestead version is out-of-date."] = "Sua versão do Homestead está desatualizada."
L["Version %s (%s) can be downloaded at CurseForge, Wago, or GitHub Releases."] = "A versão %s (%s) pode ser baixada no CurseForge, Wago ou GitHub Releases."
L["Homestead version: %s (%s)"] = "Versão do Homestead: %s (%s)"
L["Newest version seen this session: %s (%s)"] = "Versão mais recente vista nesta sessão: %s (%s)"
L["No newer version seen this session."] = "Nenhuma versão mais recente vista nesta sessão."
L["Version-check notifications: %s"] = "Avisos de verificação de versão: %s"

-------------------------------------------------------------------------------
-- Export Dialog
-------------------------------------------------------------------------------
L["Export Vendor Data"] = "Exportar dados de comerciantes"
L["Choose export option:"] = "Escolha uma opção de exportação:"
L["Export New Scans"] = "Exportar novas varreduras"
L["Export All"] = "Exportar tudo"

-------------------------------------------------------------------------------
-- Map Side Panel
-------------------------------------------------------------------------------
L["All"] = "Todos"
L["Vendor"] = "Comerciante"
L["Vendors"] = "Comerciantes"
L["Quest"] = "Missão"
L["Achievement"] = "Conquista"
L["Profession"] = "Profissão"
L["Event"] = "Evento"
L["Drop"] = "Saque"
L["Treasure"] = "Tesouro"
L["Zone Collection Progress"] = "Progresso da coleção na zona"
L["Continent Collection Progress"] = "Progresso da coleção no continente"
L["Global Collection Progress"] = "Progresso global da coleção"
L["Order Hall"] = "Salão de Classe"
L["Click to preview"] = "Clique para ver a prévia"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "Saída"
L["Select All"] = "Selecionar todos"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "Todo o texto foi selecionado. Pressione Ctrl+C para copiar para a área de transferência."

-------------------------------------------------------------------------------
-- Options - Names
-------------------------------------------------------------------------------
L["Vendor pin item details"] = "Itens no marcador de comerciante"

L["Auto-scan vendors"] = "Escanear comerciantes automaticamente"
L["Vendor Visibility"] = "Visibilidade de comerciantes"
L["Show event vendors"] = "Mostrar comerciantes de evento"
L["Hide fully-collected vendor pins"] = "Não marcar comerciantes com tudo coletado"
L["Fully-collected vendors"] = "Comerciantes já coletados"
L["desc_map_filter_completed_vendors"] = "Desmarque para ocultar os marcadores de comerciantes cujas decorações você já coletou por completo."
L["Pin Appearance"] = "Aparência dos marcadores"
L["Pin color"] = "Cor dos marcadores"
L["Custom color"] = "Cor personalizada"
L["Show accessibility glow"] = "Mostrar brilho de acessibilidade"
L["Owned item style"] = "Estilo de itens possuídos"
L["Show ownership status"] = "Mostrar status de posse"
L["Show requirements"] = "Mostrar requisitos"
L["Show all sources"] = "Mostrar todas as origens"
L["Map Pins"] = "Marcadores do mapa"
L["Show vendor panel on world map"] = "Painel de comerciantes no mapa-múndi"
L["Vendor panel source filter"] = "Filtro de origem do painel de comerciantes"
L["Integrate with map frame border"] = "Integrar à borda da janela do mapa"
L["Zone badges on world map"] = "Emblemas de zona no mapa-múndi"
L["World map pin size"] = "Tamanho dos marcadores no mapa-múndi"
L["Show collection counts"] = "Mostrar contagem da coleção"
L["Show elevation arrows"] = "Mostrar setas de elevação"
L["Minimap nearby-zone pins"] = "Marcadores de zonas próximas no minimapa"
L["Minimap pin size"] = "Tamanho dos marcadores no minimapa"
L["Waypoints"] = "Pontos de rota"
L["Show milestone progress on dashboard"] = "Mostrar marcos no Painel de moradia"
L["Inventory"] = "Inventário"
L["Merchant"] = "Comerciante"
L["Housing Catalog"] = "Catálogo de Moradia"

-------------------------------------------------------------------------------
-- Options - Descriptions
-------------------------------------------------------------------------------
L["desc_minimap_button"] = "Mostra ou oculta o botão no minimapa"
L["desc_auto_scan_vendors"] = "Escaneia automaticamente o estoque dos comerciantes em busca de dados de decoração de moradia ao visitá-los. Desativar pode melhorar um pouco o desempenho ao abrir comerciantes."
L["desc_options_general"] = "Comportamento principal do addon, acesso pelo minimapa, escaneamento de comerciantes e aparência dos marcadores do mapa."
L["desc_options_overlays"] = "Marcadores de coleção exibidos nas bolsas, no banco, nos comerciantes e no Catálogo de Moradia."
L["desc_options_tooltips"] = "Detalhes extras de posse, origem, requisitos e comerciante adicionados às dicas de itens e de marcadores do mapa."
L["desc_options_world_map"] = "Marcadores de comerciantes no mapa-múndi, emblemas de zona, comportamento do painel lateral e exibição dos marcadores do mapa."
L["desc_options_minimap"] = "Marcadores de comerciantes próximos, setas de elevação e comportamento dos pontos de rota no minimapa."
L["desc_options_endeavors"] = "Progresso das Empreitadas de moradia exibido no Painel de moradia da Blizzard."
L["desc_options_export"] = "Exportação dos dados de comerciantes escaneados para revisão ou backup."
L["desc_vendor_visibility_section"] = "Escolha quais grupos de comerciantes aparecem nos mapas e nos totais da coleção."
L["desc_pin_appearance_section"] = "Ajuste a cor e a prévia dos marcadores de comerciantes do Homestead."
L["desc_overlay_inventory_section"] = "Mostra marcadores de coleção nos espaços de itens fora do Catálogo de Moradia."
L["desc_overlay_merchant_section"] = "Marca as decorações coletadas ao ver os itens dos comerciantes."
L["desc_overlay_catalog_section"] = "Controla os marcadores, os destaques e o estilo dos itens coletados no Catálogo de Moradia."
L["desc_tooltip_map_pins_section"] = "Escolha quantos detalhes do comerciante aparecem nas dicas dos marcadores do mapa."
L["desc_minimap_waypoints_section"] = "Configure o comportamento dos pontos de rota do TomTom e nativos ao clicar no mapa e nos comerciantes."
L["desc_opposite_faction"] = "Mostra comerciantes da facção oposta com o emblema da facção deles. Útil para completistas verem todos os comerciantes disponíveis."
L["desc_event_vendors"] = "Mostra no mapa os marcadores de comerciantes de feriados sazonais quando o evento estiver ativo (ex.: Festival da Lua)"
L["desc_hide_completed_vendor_pins"] = "Oculta os marcadores no mapa e no minimapa de comerciantes cujas decorações de moradia você já coletou por completo. A lista do painel de comerciantes não é afetada."
L["desc_pin_color"] = "Escolha uma cor para os marcadores do mapa e do minimapa."
L["desc_custom_color"] = "Escolha uma cor base personalizada para os marcadores do mapa"
L["desc_enable_overlays"] = "Adiciona pequenos ícones e destaques aos itens de decoração em todo o jogo para você ver rapidamente quais já coletou. Desativar oculta todas as sobreposições do Homestead em todos os lugares."
L["desc_icon_size"] = "Define o tamanho dos ícones de coleção nos espaços de itens."
L["desc_icon_position"] = "Em qual canto do espaço do item o ícone de coleção fica."
L["desc_show_on_bags"] = "Adiciona um |A:homestone-minimap-icon:16:16|a aos itens de decoração nas suas bolsas, colorido para mostrar se você já coletou cada um. Funciona com as bolsas padrão, Baganator e BetterBags."
L["desc_show_on_bank"] = "Marca os itens de decoração no seu banco para você ver quais já coletou."
L["desc_show_on_merchant"] = "Adiciona um |A:homestone-minimap-icon:16:16|a aos itens de decoração nos comerciantes, colorido para mostrar se você já coletou cada um."
L["desc_show_on_housing_catalog"] = "Marca os itens no Catálogo de Moradia com ícones de coleção que mostram de onde cada item vem.\n\n|A:auctionhouse-icon-coin-gold:16:16|a Comerciante\n|A:QuestNormal:16:16|a Missão\n|A:UI-Achievement-Shield-NoPoints:16:16|a Conquista\n|A:UI-HUD-MicroMenu-Professions-Mouseover:16:16|a Profissão\n|A:UI-HUD-Calendar-1-Up:16:16|a Evento\n|A:Crosshair_lootall_64:16:16|a Saque\n|A:hearthsteel-icon-32x32:16:16|a Loja Battle.net"
L["desc_accessibility_glow"] = "Adiciona um brilho colorido na borda dos itens do Catálogo de Moradia: verde para os possuídos, amarelo para os que você pode obter e vermelho para os bloqueados por requisitos que você ainda não cumpriu."
L["desc_owned_item_style"] = "Escolha a aparência dos itens coletados no Catálogo de Moradia. Destaque verde mostra o brilho padrão, Esmaecido deixa os itens apagados e Marca de seleção adiciona um pequeno visto verde. Escolha Nenhum para deixá-los inalterados."
L["desc_enable_tooltips"] = "Adiciona informações do Homestead às dicas de itens ao passar o cursor sobre itens de decoração. Desativar remove todos os acréscimos nas dicas."
L["desc_show_ownership"] = "Adiciona uma linha às dicas mostrando se você já coletou um item de decoração."
L["desc_show_source"] = "Mostra como obter um item de decoração: comerciantes, missões, conquistas, profissões, eventos e saques."
L["desc_show_requirements"] = "Exibe requisitos de compra, como reputação, conclusão de missões ou conquistas necessárias para comprar um item."
L["desc_show_all_sources"] = "Lista todas as formas conhecidas de obter um item, em vez de apenas a melhor origem disponível. Útil quando um item pode ser obtido de vários comerciantes, missões ou outras origens."
L["desc_vendor_details"] = "Mostra o estoque completo do comerciante e o progresso da sua coleção ao passar o cursor sobre o marcador dele. Desative para uma dica mais simples, só com o nome do comerciante."
L["desc_vendor_pin_item_details"] = "Mostra os ícones de origens alternativas e o custo no comerciante de cada item, além da contagem de itens exclusivos de comerciante, nas dicas dos marcadores do mapa. Desative para uma dica mais simples, listando só os nomes dos itens."
L["desc_show_map_pins"] = "Mostra a localização dos comerciantes no mapa-múndi"
L["desc_show_map_side_panel"] = "Mostra um painel lateral no mapa-múndi com os comerciantes e o progresso da coleção da zona atual"
L["desc_source_filter"] = "Filtra as contagens de itens e as grades expandidas do painel lateral por origem de obtenção. A visibilidade dos comerciantes no mapa não muda."
L["desc_integrate_map_border"] = "Une a borda superior do painel à borda do mapa-múndi para um visual contínuo. Desative se você usa uma interface personalizada (ElvUI, GW2 etc.) que entre em conflito."
L["desc_zone_badges"] = "Mostra a contagem de comerciantes por zona espalhada pelos continentes no mapa-múndi, em vez de um único total por continente."
L["desc_world_pin_size"] = "Ajusta o tamanho dos marcadores de comerciantes no mapa-múndi. O padrão (20) corresponde aos ícones de pontos de interesse da Blizzard."
L["desc_show_pin_counts"] = "Exibe a contagem de itens coletados/total nos marcadores de comerciantes (ex.: 3/12). Desative para deixar o mapa menos poluído."
L["desc_show_minimap_pins"] = "Mostra a localização dos comerciantes no minimapa com setas de elevação"
L["desc_elevation_arrows"] = "Mostra setas direcionais nos marcadores do minimapa quando um comerciante está acima ou abaixo de você"
L["desc_cross_zone_mode"] = "Controla os marcadores de outras zonas no minimapa. Automático reduz os marcadores extras em zonas urbanas movimentadas para uma movimentação mais fluida."
L["desc_minimap_pin_size"] = "Ajusta o tamanho dos marcadores de comerciantes no minimapa. Aumente se os marcadores forem difíceis de ver ou diminua para deixar o minimapa menos poluído."
L["desc_waypoint_info"] = "O TomTom mostra uma seta direcional sobreposta e exige que o addon TomTom esteja instalado. O nativo adiciona um marcador de destino ao mapa-múndi. Os dois podem ficar ativos ao mesmo tempo."
L["desc_use_tomtom"] = "Usa o addon TomTom para setas de pontos de rota (se instalado)"
L["desc_use_native_waypoints"] = "Usa o sistema de pontos de rota nativo do WoW com marcador de mapa"
L["desc_auto_waypoint"] = "Cria um ponto de rota automaticamente ao clicar em um comerciante na lista ou no mapa"
L["desc_navigate_modifier"] = "Segure esta tecla ao clicar para criar um ponto de rota (se o ponto de rota automático estiver desativado)"
L["desc_milestone_xp"] = "Exibe o progresso de EXP do próximo marco na aba Empreitadas do Painel de moradia da Blizzard. Desative se você usa outro addon para isso (ex.: Endeavor Simple Progress Tracker)."
L["desc_export"] = "Exporta os dados de comerciantes escaneados para backup."
L["desc_export_new"] = "Exporta os comerciantes escaneados desde sua última exportação. Inclui preço, moedas, facção e informações do catálogo."
L["desc_export_all"] = "Exporta todos os comerciantes escaneados, ignorando o filtro de data e hora."

-------------------------------------------------------------------------------
-- Options - Select Values
-------------------------------------------------------------------------------
-- Pin colors
L["Default (Gold)"] = "Padrão (Dourado)"
L["Bright Green"] = "Verde vivo"
L["Ice Blue"] = "Azul-gelo"
L["Light Blue"] = "Azul-claro"
L["Purple"] = "Roxo"
L["Pink"] = "Rosa"
L["Red"] = "Vermelho"
L["Cyan"] = "Ciano"
L["White"] = "Branco"
L["Yellow"] = "Amarelo"
L["Custom..."] = "Personalizado..."

-- Icon anchor positions
L["Top Left"] = "Superior esquerdo"
L["Top Right"] = "Superior direito"
L["Bottom Left"] = "Inferior esquerdo"
L["Bottom Right"] = "Inferior direito"
L["Center"] = "Centro"

-- Owned item styles
L["Green highlight (default)"] = "Destaque verde (padrão)"
L["None"] = "Nenhum"
L["Dimmed"] = "Esmaecido"
L["Checkmark"] = "Marca de seleção"

-- Source filter
L["All sources"] = "Todas as origens"

-- Minimap cross-zone mode
L["Auto (recommended)"] = "Automático (recomendado)"
L["Current zone only"] = "Somente a zona atual"
L["Always show nearby zones"] = "Sempre mostrar zonas próximas"

-- Navigate modifier
L["None (always)"] = "Nenhuma (sempre)"

-- Misc
L["Approximate map appearance"] = "Aparência aproximada no mapa"
L["ExportImport not available."] = "ExportImport não está disponível."

-------------------------------------------------------------------------------
-- Decor Browser: data adapter
-------------------------------------------------------------------------------
L["Unknown"] = "Desconhecido"
L["A vendor"] = "Um vendedor"
L["Required"] = "Necessário"
L["Unknown faction"] = "Facção desconhecida"
L["Other requirement"] = "Outro requisito"
L["Source unknown"] = "Origem desconhecida"
L["Item %d"] = "Item %d"
L["%s %s"] = "%s %s"
L["%s, %s"] = "%s, %s"
L["%s - %s"] = "%s - %s"
L["%s: %s"] = "%s: %s"
L["%s with %s"] = "%s com %s"
L["Level %s"] = "Nível %s"
L["Achievement: %s"] = "Conquista: %s"
L["Quest: %s"] = "Missão: %s"
L["Promotion: %s"] = "Promoção: %s"
L["Profession: %s"] = "Profissão: %s"
L["Profession: %s rank %s"] = "Profissão: %s, nível %s"
L["Vendor: %s"] = "Comerciante: %s"
L["Vendor: %s, %s"] = "Comerciante: %s, %s"
L["Crafted: %s - %s"] = "Fabricado: %s - %s"
L["Drops from %s"] = "Saque de %s"
L["Drops from %s (%s)"] = "Saque de %s (%s)"
L["Event: %s"] = "Evento: %s"
L["Event: %s - %s"] = "Evento: %s - %s"
L["Other source"] = "Outra origem"

-- Decor Browser: visuals and widgets
L["Set waypoint"] = "Definir ponto de rota"

-- Decor Browser: window and navigation
L["Homestead Decor"] = "Decoração do Homestead"
L["Overview"] = "Visão geral"
L["Catalog"] = "Catálogo"
L["Back"] = "Voltar"
L["Other Vendors"] = "Outros comerciantes"
L["%d of %d decor collected"] = "%d de %d decorações coletadas"
L["%d of %d collected"] = "%d de %d coletadas"
L["Help"] = "Ajuda"
L["Hide what doesn't apply to me"] = "Ocultar o que não se aplica a mim"
L["The Decor Browser opens once Homestead has finished loading."] = "O navegador de decoração abre assim que o Homestead terminar de carregar."
L["Collection"] = "Coleção"
L["Placed"] = "Colocadas"
L["In storage"] = "No armazenamento"
L["Not yet redeemed"] = "Ainda não resgatado"
L["Counts not loaded yet"] = "Contagens ainda não carregadas"
L["Source"] = "Origem"
L["Price"] = "Preço"

-- Decor Browser: shop and item pages
L["Seasonal: %s"] = "Sazonal: %s"
L["Rotates with the %s Endeavor"] = "Alterna com a Empreitada %s"
L["Rotates with neighborhood Endeavors"] = "Alterna com as Empreitadas da vizinhança"
L["Not available in combat"] = "Indisponível em combate"
L["Report a data error"] = "Relatar um erro nos dados"
L["Item: %s (%d)"] = "Item: %s (%d)"
L["Record ID: %s"] = "ID do registro: %s"
L["none"] = "nenhum"
L["no location"] = "sem local"
L["map %d at %.1f, %.1f"] = "mapa %d em %.1f, %.1f"
L["Vendor %d: %s, %s, %s"] = "Comerciante %d: %s, %s, %s"
L["Client: %s (%s)"] = "Cliente: %s (%s)"
L["Homestead: %s"] = "Homestead: %s"

-- Decor Browser: entry points
L["Toggle Decor Browser"] = "Abrir/fechar o navegador de decoração"
L["Open the Decor Browser, or bind a key under Keybindings > Homestead"] = "Abre o navegador de decoração, ou atribua uma tecla em Atalhos > Homestead"
L["Minimap button"] = "Botão do minimapa"
L["Left-click opens the Decor Browser, right-click opens options"] = "O clique esquerdo abre o navegador de decoração e o clique direito abre as opções"
L["The Decor Browser is not available yet."] = "O navegador de decoração ainda não está disponível."

-- Welcome window
L["Find every decor vendor on your map and see what you own before you buy."] = "Encontre todos os comerciantes de decoração no seu mapa e veja o que você já possui antes de comprar."
L["What Homestead Does"] = "O que o Homestead faz"
L["Every decor vendor pinned on your world map and minimap, with badges showing how many items you still need per zone."] = "Todos os comerciantes de decoração marcados no mapa-múndi e no minimapa, com selos que mostram quantos itens ainda faltam em cada zona."
L["Map Side Panel"] = "Painel lateral do mapa"
L["Click the Homestead button on the world map to open the side panel listing that zone's vendors, then click any vendor to browse their wares and see what you still need. Pop it out as a standalone window with |cFF00FF00/hs panel|r."] = "Clique no botão do Homestead no mapa-múndi para abrir o painel lateral com os comerciantes da zona e depois clique em qualquer um para ver as mercadorias e o que ainda falta. Destaque-o como janela independente com |cFF00FF00/hs panel|r."
L["Tooltips Expanded"] = "Dicas de Interface expandidas"
L["Every item in the Housing Catalog gets tooltips showing where it comes from (vendor, quest, achievement, profession, or drop), what it costs, and what you need to unlock it, so you never have to leave the game to look something up."] = "Todo item do Catálogo de Moradia ganha dicas de interface que mostram de onde ele vem (comerciante, missão, conquista, profissão ou saque), quanto custa e o que é preciso para desbloqueá-lo, para você nunca precisar sair do jogo para consultar algo."
L["Key Commands"] = "Comandos principais"
L["Export everything you've scanned"] = "Exportar tudo o que você escaneou"
L["Show all commands"] = "Mostrar todos os comandos"
L["Found a Problem?"] = "Encontrou um problema?"
L["Report bugs or wrong vendor info on GitHub using the link below."] = "Relate bugs ou dados incorretos de comerciantes no GitHub pelo link abaixo."
L["Report issues (GitHub):"] = "Relatar problemas (GitHub):"
L["CurseForge:"] = "CurseForge:"
L["Don't show this again"] = "Não mostrar novamente"
L["Let's Decorate!"] = "Vamos decorar!"

-------------------------------------------------------------------------------
-- Decor Browser: source and vendor labels
-------------------------------------------------------------------------------
L["Achievements"] = "Conquistas"
L["Quests"] = "Missões"
L["Professions"] = "Profissões"
L["Drops"] = "Saques"
L["Events"] = "Eventos"
L["Other"] = "Outro"
L["Location not recorded"] = "Local não registrado"
L["Requires"] = "Requer"

-------------------------------------------------------------------------------
-- Decor Browser: states and shared parts
-------------------------------------------------------------------------------
L["Collected"] = "Coletado"
L["Can get now"] = "Disponível agora"
L["Requires: %s"] = "Requer: %s"
L["%s only"] = "Somente %s"
L["Not collected"] = "Não coletado"
L["Counting…"] = "Contando…"
L["Not confirmed"] = "Não confirmado"
L["Active now"] = "Ativo agora"
L["Best to get now"] = "Melhor para obter agora"
L["Search decor by name"] = "Buscar decoração por nome"
L["Reset filters"] = "Redefinir filtros"
L["Search all decor"] = "Buscar em toda a decoração"
L["Show what's missing"] = "Mostrar o que falta"
L["Sort by name"] = "Ordenar por nome"
L["Show them"] = "Mostrar"
L["Show vendor"] = "Mostrar vendedor"
L["Report a problem"] = "Relatar um problema"
L["Reading your collection. This list fills in when it's ready."] = "Lendo sua coleção. Esta lista é preenchida quando estiver pronta."
L["Reading your collection. This list fills in when it's ready, because Best to get now depends on what you own."] = "Lendo sua coleção. Esta lista é preenchida quando estiver pronta, porque Melhor para obter agora depende do que você possui."
L["Nothing missing"] = "Nada falta"
L["You've collected all %d decor Homestead knows about."] = "Você coletou todas as %d decorações que o Homestead conhece."
L["Nothing you can get right now"] = "Nada para obter agora"
L["Everything you're missing needs a reputation, achievement or quest first, is sold only during an event, or is sold only to the %s."] = "Tudo o que falta exige antes uma reputação, uma conquista ou uma missão, é vendido apenas durante um evento ou é vendido apenas para a %s."
L["Everything you're missing needs a reputation, achievement or quest first, or is sold only during an event."] = "Tudo o que falta exige antes uma reputação, uma conquista ou uma missão, ou é vendido apenas durante um evento."
L["Collection not read yet"] = "Coleção ainda não lida"
L["Homestead hasn't read this character's decor collection yet, so it can't tell what you're missing. It reads it shortly after you log in. If this message stays, open the Housing Dashboard once."] = "O Homestead ainda não leu a coleção de decoração deste personagem e não consegue dizer o que falta. Ele a lê pouco depois de você entrar. Se esta mensagem continuar, abra o Painel de Moradia uma vez."
L["These filters need your collection, which Homestead hasn't read yet. If this stays, open the Housing Dashboard once."] = "Estes filtros precisam da sua coleção, que o Homestead ainda não leu. Se isso continuar, abra o Painel de Moradia uma vez."
L["No results"] = "Nenhum resultado"
L["No decor matches these words and filters. Search looks at item names only."] = "Nenhuma decoração corresponde a estas palavras e filtros. A busca olha apenas os nomes dos itens."
L["%d hidden by '%s' (%d collected, %d %s only)."] = "%d ocultos por '%s' (%d coletados, %d somente %s)."
L["%d hidden by '%s' (%d collected, %d %s only, %d %s only)."] = "%d ocultos por '%s' (%d coletados, %d somente %s, %d somente %s)."
L["%d hidden by '%s' (%d collected)."] = "%d ocultos por '%s' (%d coletados)."
L["%s or the %s"] = "%s ou a %s"

-------------------------------------------------------------------------------
-- Decor Browser: Summary
-------------------------------------------------------------------------------
L["What can I get now?"] = "O que posso obter agora?"
L["Decor this character can buy or earn today, best first."] = "Decorações que este personagem pode comprar ou conseguir hoje, as melhores primeiro."
L["Can get now means this character can buy or earn it today: the right faction, and no requirement left to meet. The closest ones come first. Use See all for the full list."] = "Disponível agora significa que este personagem pode comprar ou conseguir hoje: facção certa e nenhum requisito restante. Os mais próximos vêm primeiro. Use Ver tudo para a lista completa."
L["Search"] = "Buscar"
L["Show"] = "Mostrar"
L["Not yet: next step"] = "Ainda não: próximo passo"
L["%s and %d more"] = "%s e mais %d"
L["See all you can get now (%d)"] = "Ver tudo o que você pode obter agora (%d)"
L["Here in %s: %s sells %d decor you can get now."] = "Aqui em %s: %s vende %d decorações que você pode obter agora."
L["Sold here in %s"] = "Vendido aqui em %s"
L["Sold on %s"] = "Vendido em %s"
L["%s: active now"] = "%s: ativo agora"
L["Gold only"] = "Somente ouro"
L["Gold only, no requirements left"] = "Somente ouro, sem requisitos restantes"
L["No requirements left"] = "Sem requisitos restantes"
L["By source"] = "Por origem"
L["%d of %d"] = "%d de %d"
L["Not read yet"] = "Ainda não lido"
L["Reading your collection"] = "Lendo sua coleção"
-- end: Summary

-------------------------------------------------------------------------------
-- Decor Browser: Catalog
-------------------------------------------------------------------------------
L["All decor"] = "Toda a decoração"
L["Filters"] = "Filtros"
L["Name"] = "Nome"
L["Sort: %s"] = "Ordenar: %s"
L["Furnishings"] = "Mobília"
L["Structural"] = "Estruturas"
L["Accents"] = "Acentos"
L["Lighting"] = "Iluminação"
L["Neither collected nor not collected"] = "Nem coletado nem não coletado"
L["Sources: %s"] = "Fontes: %s"
L["Filtered: %s"] = "Filtrado: %s"
L["(+%d more)"] = "(+%d mais)"
-- end: Catalog

-------------------------------------------------------------------------------
-- Decor Browser: Sources
-------------------------------------------------------------------------------
L["Search vendors and zones"] = "Buscar vendedores e zonas"
L["Search achievements"] = "Buscar conquistas"
L["Search quests"] = "Buscar missões"
L["Search recipes and professions"] = "Buscar receitas e profissões"
L["Search drops and zones"] = "Buscar saques e zonas"
L["Search events"] = "Buscar eventos"
L["Search the Shop"] = "Buscar na loja"
L["Here in %s"] = "Aqui em %s"
L["%d decor"] = "%d decorações"
L["No decor"] = "Sem decoração"
L["Not active"] = "Inativo"
L["All collected"] = "Tudo coletado"
L["%d can get now"] = "%d disponíveis agora"
L["Holiday event"] = "Evento sazonal"
L["%s only: can't buy on this character"] = "Somente %s: não pode comprar com este personagem"
L["%s vendor"] = "Vendedor (%s)"
L["Confirmed by a scan on %s"] = "Confirmado por uma varredura em %s"
L["No scan has confirmed this vendor yet. Visit the vendor to check."] = "Nenhuma varredura confirmou este vendedor ainda. Visite o vendedor para conferir."
L["Sells %d decor."] = "Vende %d decorações."
L["Gives %d decor."] = "Dá %d decorações."
L["You have %d."] = "Você tem %d."
L["%d you can get now."] = "Você pode obter %d agora."
L["Decor sold here"] = "Decorações vendidas aqui"
L["Decor from this source"] = "Decorações desta fonte"
L["No decor is recorded here. If this source gives decor, report it below."] = "Nenhuma decoração registrada aqui. Se esta fonte dá decorações, reporte abaixo."
L["Pick a source to see its decor."] = "Escolha uma fonte para ver suas decorações."
L["Dig site in %s"] = "Local de escavação em %s"
L["No model shown"] = "Nenhum modelo exibido"
L["No events active right now. Event decor is sold only while its event runs."] = "Nenhum evento ativo agora. As decorações de evento só são vendidas enquanto o evento acontece."
L["Nothing matches your search."] = "Nada corresponde à sua busca."
L["Nothing to show here."] = "Nada para mostrar aqui."
-- end: Sources

-------------------------------------------------------------------------------
-- Decor Browser: Item
-------------------------------------------------------------------------------
L["Vendor:"] = "Vendedor:"
L["Zone:"] = "Zona:"
L["Cost:"] = "Custo:"
L["Achievement:"] = "Conquista:"
L["Quest:"] = "Missão:"
L["Recipe:"] = "Receita:"
L["Profession:"] = "Profissão:"
L["Drop:"] = "Saque:"
L["Event:"] = "Evento:"
L["Starts in %s"] = "Começa em %s"
L["Daily from The Last Architect"] = "Diária de The Last Architect"
L["Set dig site waypoint"] = "Definir ponto de passagem do sítio de escavação"
L["Can get now here"] = "Disponível agora aqui"
L["Where to get it"] = "Onde obter"
L["Show achievement"] = "Mostrar conquista"
L["Show quest"] = "Mostrar missão"
L["Show recipe"] = "Mostrar receita"
L["Show drop"] = "Mostrar saque"
L["Show event"] = "Mostrar evento"
L["%s (done)"] = "%s (feito)"
L["%s (not yet)"] = "%s (ainda não)"
L["Can't check this requirement yet"] = "Ainda não é possível verificar este requisito"
L["Active now: %s"] = "Ativo agora: %s"
-- end: Item
