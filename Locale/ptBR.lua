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
L["Left-Click: Toggle options"] = "|cFFFFFFFFClique esquerdo:|r Abrir/fechar opções"
L["Right-Click: Detach/close vendor panel"] = "|cFFFFFFFFClique direito:|r Desacoplar/fechar painel de comerciantes"

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
