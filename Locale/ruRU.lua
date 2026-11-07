--[[
    Homestead - Locale: Russian (RU)
    Translator ZamestoTV
    License: GPL-3.0 (see LICENSE-GPL-3.0); modified by Royaleint.
    Machine-translated where not marked human-translated.
]]

local _, HA = ...

if GetLocale() ~= "ruRU" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["Used in %d known recipe for decor you haven't collected"] = "Используется в %d известном рецепте для ещё не полученного декора"
L["Used in %d known recipes for decor you haven't collected"] = "Используется в %d известных рецептах для ещё не полученного декора"

-------------------------------------------------------------------------------
-- UI Labels
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["Homestead"] = "Homestead" -- human-translated
L["Homestead Options"] = "Настройки Homestead"
L["Overlays"] = "Оверлеи" -- human-translated
L["Tooltips"] = "Подсказки" -- human-translated

L["Show minimap button"] = "Показывать кнопку у миникарты" -- human-translated
L["Enable overlays"] = "Включить оверлеи" -- human-translated
L["Show on bags"] = "Показывать в сумках" -- human-translated
L["Show on bank"] = "Показывать в банке" -- human-translated
L["Show on merchant"] = "Показывать у торговцев" -- human-translated
L["Show on housing catalog"] = "Показывать в каталоге декора" -- human-translated
L["Icon size"] = "Размер значка" -- human-translated
L["Icon position"] = "Положение значка" -- human-translated

L["Enable tooltip additions"] = "Включить добавление подсказок" -- human-translated
L["Show source information"] = "Показывать источник" -- human-translated

L["Show map pins"] = "Показывать метки на карте" -- human-translated
L["Show minimap pins"] = "Показывать метки на миникарте" -- human-translated
L["Use TomTom for waypoints"] = "Использовать TomTom для путевых точек" -- human-translated

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d / %d (%d%%)"] = "Коллекция: %d / %d (%d%%)" -- human-translated
L["Vendors nearby: %d"] = "Торговцев рядом: %d" -- human-translated
L["Vendors scanned: %d"] = "Просканировано торговцев: %d" -- human-translated
L["Left-Click: Toggle Decor Browser"] = "|cFFFFFFFFЛКМ:|r Открыть/закрыть обозреватель декора"
L["Right-Click: Open options"] = "|cFFFFFFFFПКМ:|r Открыть настройки"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Команды Homestead:" -- human-translated

-------------------------------------------------------------------------------
-- Slash Command Feedback
-------------------------------------------------------------------------------
L["Map pins refreshed."] = "Метки на карте обновлены." -- human-translated
L["No active waypoint."] = "Нет активной путевой точки." -- human-translated
L["Waypoint cleared."] = "Путевая точка удалена." -- human-translated
L["Vendor database contains %d vendors."] = "База данных содержит %d торговцев." -- human-translated
L["Use /hs vendor <name or zone> to search."] = "Используйте /hs vendor <имя или зона> для поиска." -- human-translated
L["No vendors found matching: %s"] = "Торговцы не найдены по запросу: %s" -- human-translated
L["Found %d vendor(s) matching: %s"] = "Найдено %d торговец(ов) по запросу: %s" -- human-translated
L["... and %d more."] = "... и ещё %d." -- human-translated

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "Режим отладки: %s" -- human-translated
L["ON"] = "ВКЛ" -- human-translated
L["OFF"] = "ВЫКЛ" -- human-translated
L["Unknown command: %s"] = "Неизвестная команда: %s" -- human-translated
L["Type /hs help for a list of commands."] = "Введите /hs help для вывода списка команд." -- human-translated

-------------------------------------------------------------------------------
-- Version Check
-------------------------------------------------------------------------------
L["Your Homestead version is out-of-date."] = "Ваша версия Homestead устарела." -- human-translated
L["Version %s (%s) can be downloaded at CurseForge, Wago, or GitHub Releases."] = "Версию %s (%s) можно загрузить на CurseForge, Wago или GitHub Releases." -- human-translated
L["Homestead version: %s (%s)"] = "Версия Homestead: %s (%s)" -- human-translated
L["Newest version seen this session: %s (%s)"] = "Новейшая версия, замеченная в этой сессии: %s (%s)" -- human-translated
L["No newer version seen this session."] = "Более новых версий в этой сессии не обнаружено." -- human-translated
L["Version-check notifications: %s"] = "Уведомления о проверке версии: %s" -- human-translated

-------------------------------------------------------------------------------
-- Map Side Panel
-------------------------------------------------------------------------------
L["All"] = "Все" -- human-translated
L["Vendors"] = "Торговцы" -- human-translated
L["Zone Collection Progress"] = "Прогресс коллекции зоны" -- human-translated
L["Continent Collection Progress"] = "Прогресс коллекции континента" -- human-translated
L["Global Collection Progress"] = "Общий прогресс коллекции" -- human-translated
L["Order Hall"] = "Оплот класса" -- human-translated
L["Click to preview"] = "Нажмите для предпросмотра" -- human-translated

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "Вывод" -- human-translated
L["Select All"] = "Выбрать всё" -- human-translated
L["All text selected. Press Ctrl+C to copy to clipboard."] = "Текст выделен. Нажмите Ctrl+C для копирования." -- human-translated

-------------------------------------------------------------------------------
-- Options - Names
-------------------------------------------------------------------------------
L["Show opposite faction vendors"] = "Показывать торговцев противоположной фракции" -- human-translated
L["Show vendor details in tooltips"] = "Показывать подробности о торговце в подсказках" -- human-translated
L["Vendor pin item details"] = "Подробности о предметах в метке торговца" -- human-translated
L["Use native waypoints"] = "Использовать стандартные точки маршрута" -- human-translated
L["Auto-create waypoint on click"] = "Автоматически создавать точку маршрута при нажатии" -- human-translated
L["Navigate modifier key"] = "Клавиша-модификатор навигации" -- human-translated

L["Auto-scan vendors"] = "Автоматическое сканирование торговцев" -- human-translated
L["Vendor Visibility"] = "Отображение торговцев" -- human-translated
L["Show event vendors"] = "Показывать праздничных торговцев" -- human-translated
L["Hide fully-collected vendor pins"] = "Скрывать метки собранных торговцев" -- human-translated
L["Fully-collected vendors"] = "Торговцы с собранными коллекциями" -- human-translated
L["desc_map_filter_completed_vendors"] = "Снимите галочку, чтобы скрыть метки торговцев, у которых вы полностью получили предметы декора." -- human-translated
L["Pin Appearance"] = "Внешний вид меток" -- human-translated
L["Pin color"] = "Цвет метки" -- human-translated
L["Custom color"] = "Свой цвет" -- human-translated
L["Show accessibility glow"] = "Показывать подсветку доступности" -- human-translated
L["Owned item style"] = "Стиль полученных предметов" -- human-translated
L["Show ownership status"] = "Показывать статус получения" -- human-translated
L["Show requirements"] = "Показывать требования" -- human-translated
L["Show all sources"] = "Показывать все источники" -- human-translated
L["Map Pins"] = "Метки на карте" -- human-translated
L["Show vendor panel on world map"] = "Показывать панель торговцев на карте мира" -- human-translated
L["Vendor panel source filter"] = "Фильтр источников на панели торговцев" -- human-translated
L["Integrate with map frame border"] = "Встроить в рамку окна карты" -- human-translated
L["Zone badges on world map"] = "Значки зон на карте мира" -- human-translated
L["World map pin size"] = "Размер меток на карте мира" -- human-translated
L["Show collection counts"] = "Показывать количество в коллекции" -- human-translated
L["Show elevation arrows"] = "Показывать стрелки высоты" -- human-translated
L["Minimap nearby-zone pins"] = "Метки соседних зон на миникарте" -- human-translated
L["Minimap pin size"] = "Размер меток на миникарте" -- human-translated
L["Waypoints"] = "Точки маршрута" -- human-translated
L["Show milestone progress on dashboard"] = "Показывать прогресс этапов на панели" -- human-translated
L["Inventory"] = "Предметы" -- human-translated
L["Merchant"] = "Торговец" -- human-translated
L["Housing Catalog"] = "Каталог декора" -- human-translated

-------------------------------------------------------------------------------
-- Options - Descriptions
-------------------------------------------------------------------------------
L["desc_minimap_button"] = "Показать или скрыть кнопку у миникарты" -- human-translated
L["desc_auto_scan_vendors"] = "Автоматически сканировать ассортимент торговцев на наличие данных о предметах декора при их посещении. Отключение функции может немного повысить производительность при открытии окон торговцев." -- human-translated
L["desc_options_general"] = "Базовое поведение аддона, доступ к миникарте, сканирование торговцев и внешний вид меток на карте." -- human-translated
L["desc_options_overlays"] = "Индикаторы коллекции, отображаемые в сумках, в банке, у торговцев и в каталоге декора." -- human-translated
L["desc_options_tooltips"] = "Дополнительные сведения о получении, источниках, требованиях и торговцах в подсказках к предметам и меткам на карте." -- human-translated
L["desc_options_world_map"] = "Метки торговцев на карте мира, значки зон, поведение боковой панели и отображение меток на карте." -- human-translated
L["desc_options_minimap"] = "Метки ближайших торговцев, стрелки высоты и поведение точек маршрута на миникарте." -- human-translated
L["desc_options_endeavors"] = "Прогресс предприятия на стандартной панели жилья от Blizzard." -- human-translated
L["desc_vendor_visibility_section"] = "Выберите, какие группы торговцев будут отображаться на картах и учитываться в общем количестве коллекции." -- human-translated
L["desc_pin_appearance_section"] = "Настройка цвета и предварительного просмотра для меток торговцев Homestead." -- human-translated
L["desc_overlay_inventory_section"] = "Показывать индикаторы коллекции на ячейках предметов за пределами каталога декора." -- human-translated
L["desc_overlay_merchant_section"] = "Отмечать полученный декор при просмотре товаров у торговца." -- human-translated
L["desc_overlay_catalog_section"] = "Управление индикаторами, подсветкой и стилем полученных предметов в каталоге декора." -- human-translated
L["desc_tooltip_map_pins_section"] = "Выберите, насколько подробная информация о торговце будет отображаться в подсказках к меткам на карте." -- human-translated
L["desc_minimap_waypoints_section"] = "Настройка поведения TomTom и стандартных точек маршрута при нажатии на карту и торговцев." -- human-translated
L["desc_opposite_faction"] = "Показывать торговцев противоположной фракции с эмблемой их фракции. Полезно для коллекционеров, чтобы видеть всех доступных торговцев." -- human-translated
L["desc_event_vendors"] = "Показывать метки сезонных праздничных торговцев на карте, когда их событие активно (например, Лунный фестиваль)." -- human-translated
L["desc_hide_completed_vendor_pins"] = "Скрывать метки на карте и миникарте для торговцев, у которых вы полностью получили предметы декора для дома. Это не влияет на список на панели торговцев." -- human-translated
L["desc_pin_color"] = "Выберите цвет для меток на карте и миникарте." -- human-translated
L["desc_custom_color"] = "Выбрать свой базовый цвет для меток на карте" -- human-translated
L["desc_enable_overlays"] = "Добавляет небольшие значки и подсветку к предметам декора по всей игре, чтобы вы могли с первого взгляда определить, какие из них уже получены. Отключение этой опции скроет все оверлеи Homestead." -- human-translated
L["desc_icon_size"] = "Управляет размером значков коллекции в ячейках предметов." -- human-translated
L["desc_icon_position"] = "В каком углу ячейки предмета будет располагаться значок коллекции." -- human-translated
L["desc_show_on_bags"] = "Добавляет значок |A:homestone-minimap-icon:16:16|a к предметам декора в ваших сумках. Цвет значка показывает, получен ли предмет. Работает со стандартными сумками, Baganator и BetterBags." -- human-translated
L["desc_show_on_bank"] = "Отмечать предметы декора в банке, чтобы вы могли видеть, какие из них уже получены." -- human-translated
L["desc_show_on_merchant"] = "Добавляет значок |A:homestone-minimap-icon:16:16|a к предметам декора у торговцев. Цвет значка показывает, получен ли предмет." -- human-translated
L["desc_show_on_housing_catalog"] = "Отмечать предметы в каталоге декора значками коллекции, показывающими, откуда получен каждый предмет.\n\n" -- human-translated
    .. "|A:auctionhouse-icon-coin-gold:16:16|a Торговец\n"
    .. "|A:QuestNormal:16:16|a Задание\n"
    .. "|A:UI-Achievement-Shield-NoPoints:16:16|a Достижение\n"
    .. "|A:UI-HUD-MicroMenu-Professions-Mouseover:16:16|a Профессия\n"
    .. "|A:UI-HUD-Calendar-1-Up:16:16|a Событие\n"
    .. "|A:Crosshair_lootall_64:16:16|a Добыча\n"
    .. "|A:hearthsteel-icon-32x32:16:16|a Магазин Battle.net"
L["desc_accessibility_glow"] = "Добавить цветную подсветку рамок для предметов в каталоге декора: зеленую для полученных, желтую для доступных и красную для предметов, заблокированных требованиями, которые вы еще не выполнили." -- human-translated
L["desc_owned_item_style"] = "Выберите, как полученные предметы выглядят в каталоге декора. Зеленая подсветка показывает стандартное свечение, «Затемнение» делает их полупрозрачными, а «Галочка» добавляет небольшую зеленую галочку. Выберите «Нет», чтобы оставить их без изменений." -- human-translated
L["desc_enable_tooltips"] = "Добавлять информацию Homestead в подсказки к предметам при наведении на декор. Отключение этой опции уберет все дополнения в подсказках." -- human-translated
L["desc_show_ownership"] = "Добавить строку в подсказки, показывающую, получен ли уже этот предмет декора." -- human-translated
L["desc_show_source"] = "Показывать способ получения предмета декора - торговцы, задания, достижения, профессии, события и добыча." -- human-translated
L["desc_show_requirements"] = "Отображать требования для покупки, такие как репутация, выполнение заданий или достижения, необходимые для приобретения предмета." -- human-translated
L["desc_show_all_sources"] = "Показывать все известные способы получения предмета, а не только самый лучший. Полезно, если предмет можно приобрести у нескольких торговцев, получить за разные задания или из других источников." -- human-translated
L["desc_vendor_details"] = "Показывать весь ассортимент торговца и ваш прогресс коллекции при наведении на его метку на карте. Отключите для более простой подсказки, содержащей только имя торговца." -- human-translated
L["desc_vendor_pin_item_details"] = "Показывать значки альтернативных источников, стоимость у торговца и количество предметов, доступных только у этого торговца, во всплывающих подсказках меток на карте. Отключите для упрощенного вида только с названиями предметов." -- human-translated
L["desc_show_map_pins"] = "Показывать местоположение торговцев на карте мира" -- human-translated
L["desc_show_map_side_panel"] = "Показывать боковую панель на карте мира со списком торговцев и прогрессом коллекции для текущей зоны" -- human-translated
L["desc_source_filter"] = "Фильтровать количество предметов на боковой панели и развернутые сетки по источнику получения. Отображение торговцев на карте при этом не меняется." -- human-translated
L["desc_integrate_map_border"] = "Объединить верхнюю рамку панели с рамкой карты мира для бесшовного вида. Отключите, если используете сторонний интерфейс (ElvUI, GW2 и т.д.), который вызывает конфликт." -- human-translated
L["desc_zone_badges"] = "Показывать количество торговцев для каждой отдельной зоны на материках карты мира вместо одного общего количества для всего континента." -- human-translated
L["desc_world_pin_size"] = "Настроить размер меток торговцев на карте мира. По умолчанию (20) соответствует стандартным значкам Blizzard для интересных мест." -- human-translated
L["desc_show_pin_counts"] = "Отображать количество полученных/всего предметов прямо на метках торговцев (например, 3/12). Отключите, чтобы уменьшить загромождение карты." -- human-translated
L["desc_show_minimap_pins"] = "Показывать местоположение торговцев на миникарте со стрелками высоты" -- human-translated
L["desc_elevation_arrows"] = "Показывать стрелки направления на метках миникарты, когда торговец находится выше или ниже вас" -- human-translated
L["desc_cross_zone_mode"] = "Управление метками соседних зон на миникарте. Режим «Авто» уменьшает количество лишних меток в густонаселенных городских зонах для более плавного перемещения." -- human-translated
L["desc_minimap_pin_size"] = "Настроить размер меток торговцев на миникарте. Увеличьте, если метки плохо видно, или уменьшите, чтобы разгрузить миникарту." -- human-translated
L["desc_waypoint_info"] = "TomTom отображает стрелку направления на экране и требует наличия установленного аддона TomTom. Стандартная система добавляет метку назначения на карту мира. Обе системы могут работать одновременно." -- human-translated
L["desc_use_tomtom"] = "Использовать аддон TomTom для стрелок маршрута (если установлен)" -- human-translated
L["desc_use_native_waypoints"] = "Использовать встроенную систему точек маршрута WoW с меткой на карте" -- human-translated
L["desc_auto_waypoint"] = "Автоматически создавать точку маршрута при нажатии на торговца в списке или на карте" -- human-translated
L["desc_navigate_modifier"] = "Удерживайте эту клавишу при нажатии, чтобы создать точку маршрута (если автоматическое создание отключено)" -- human-translated
L["desc_milestone_xp"] = "Отображать прогресс опыта до следующего этапа на вкладке «Предприятия» стандартной панели жилья от Blizzard. Отключите, если используете для этого другой аддон (например, Endeavor Simple Progress Tracker)." -- human-translated

-------------------------------------------------------------------------------
-- Options - Select Values
-------------------------------------------------------------------------------
-- Pin colors
L["Default (Gold)"] = "По умолчанию (золотой)" -- human-translated
L["Bright Green"] = "Ярко-зеленый" -- human-translated
L["Ice Blue"] = "Ледяной синий" -- human-translated
L["Light Blue"] = "Голубой" -- human-translated
L["Purple"] = "Фиолетовый" -- human-translated
L["Pink"] = "Розовый" -- human-translated
L["Red"] = "Красный" -- human-translated
L["Cyan"] = "Бирюзовый" -- human-translated
L["White"] = "Белый" -- human-translated
L["Yellow"] = "Желтый" -- human-translated
L["Custom..."] = "Свой..." -- human-translated

-- Icon anchor positions
L["Top Left"] = "Сверху слева" -- human-translated
L["Top Right"] = "Сверху справа" -- human-translated
L["Bottom Left"] = "Снизу слева" -- human-translated
L["Bottom Right"] = "Снизу справа" -- human-translated
L["Center"] = "По центру" -- human-translated

-- Owned item styles
L["Green highlight (default)"] = "Зеленая подсветка (по умолчанию)" -- human-translated
L["None"] = "Нет" -- human-translated
L["Dimmed"] = "Затемнение" -- human-translated
L["Checkmark"] = "Галочка" -- human-translated

-- Source filter
L["All sources"] = "Все источники" -- human-translated
L["Vendor"] = "Торговец" -- human-translated
L["Quest"] = "Задание" -- human-translated
L["Achievement"] = "Достижение" -- human-translated
L["Profession"] = "Профессия" -- human-translated
L["Event"] = "Событие" -- human-translated
L["Drop"] = "Добыча" -- human-translated
L["Treasure"] = "Сокровище"

-- Minimap cross-zone mode
L["Auto (recommended)"] = "Авто (рекомендуется)" -- human-translated
L["Current zone only"] = "Только текущая зона" -- human-translated
L["Always show nearby zones"] = "Всегда показывать соседние зоны" -- human-translated

-- Navigate modifier
L["None (always)"] = "Нет (всегда)" -- human-translated

-- Misc
L["Approximate map appearance"] = "Примерный вид карты" -- human-translated
L["Catalog scan is on cooldown. Try again in a few seconds."] = "Сканирование каталога ещё на перезарядке. Повторите попытку через несколько секунд."
L["A catalog scan is already in progress."] = "Сканирование каталога уже выполняется."

-------------------------------------------------------------------------------
-- Decor Browser: data adapter
-------------------------------------------------------------------------------
L["Unknown"] = "Неизвестно"
L["A vendor"] = "Торговец"
L["Required"] = "Требуется"
L["Unknown faction"] = "Неизвестная фракция"
L["Other requirement"] = "Другое требование"
L["Source unknown"] = "Источник неизвестен"
L["Item %d"] = "Предмет %d"
L["%s %s"] = "%s %s"
L["%s, %s"] = "%s, %s"
L["%s: %s"] = "%s: %s"
L["%s with %s"] = "%s (%s)"
L["Level %s"] = "Уровень %s"
L["Achievement: %s"] = "Достижение: %s"
L["Quest: %s"] = "Задание: %s"
L["Promotion: %s"] = "Акция: %s"
L["Profession: %s"] = "Профессия: %s"
L["Profession: %s rank %s"] = "Профессия: %s, ранг %s"
L["Vendor: %s"] = "Торговец: %s"
L["Vendor: %s, %s"] = "Торговец: %s, %s"
L["Crafted: %s - %s"] = "Изготовление: %s - %s"
L["Drops from %s"] = "Добыча с: %s"
L["Drops from %s (%s)"] = "Добыча с: %s (%s)"
L["Event: %s"] = "Событие: %s"
L["Event: %s - %s"] = "Событие: %s - %s"
L["Other source"] = "Другой источник"

-- Decor Browser: visuals and widgets
L["Set waypoint"] = "Поставить метку"

-- Decor Browser: window and navigation
L["Homestead Decor"] = "Декор Homestead"
L["Overview"] = "Обзор"
L["Catalog"] = "Каталог"
L["Back"] = "Назад"
L["Other Vendors"] = "Прочие торговцы"
L["%d of %d decor collected"] = "Собрано предметов декора: %d из %d"
L["%d of %d collected"] = "Собрано: %d из %d"
L["Help"] = "Справка"
L["Hide collected and other-faction"] = "Без собранного и противоположной фракции"
L["Hides decor you have collected, vendors with nothing left to collect, and anything only the other faction can get."] = "Скрывает собранный декор, торговцев, у которых больше нечего собирать, и всё, что может получить только противоположная фракция."
L["Opens a page explaining this window."] = "Открывает страницу с описанием этого окна."
L["The Decor Browser opens once Homestead has finished loading."] = "Обозреватель декора откроется, когда Homestead закончит загрузку."
L["Collection"] = "Коллекция"
L["Placed"] = "Размещено"
L["In storage"] = "На хранении"
L["Not yet redeemed"] = "Ещё не получено"
L["Counts not loaded yet"] = "Количество ещё не загружено"
L["Source"] = "Источник"
L["Price"] = "Цена"

-- Decor Browser: shop and item pages
L["Seasonal: %s"] = "Сезонное: %s"
L["Rotates with the %s Endeavor"] = "Меняется вместе с предприятием %s"
L["Rotates with neighborhood Endeavors"] = "Меняется вместе с предприятиями района"
L["Endeavor"] = "Предприятие"
L["Not available in combat"] = "Недоступно в бою"
L["Report a data error"] = "Сообщить об ошибке в данных"
L["Item: %s (%d)"] = "Предмет: %s (%d)"
L["Record ID: %s"] = "ID записи: %s"
L["none"] = "нет"
L["no location"] = "нет местоположения"
L["map %d at %.1f, %.1f"] = "карта %d, %.1f, %.1f"
L["Vendor %d: %s, %s, %s"] = "Торговец %d: %s, %s, %s"
L["Client: %s (%s)"] = "Клиент: %s (%s)"
L["Homestead: %s"] = "Homestead: %s"

-- Decor Browser: entry points
L["Toggle Decor Browser"] = "Открыть/закрыть обозреватель декора"
L["Open the Decor Browser, or bind a key under Keybindings > Homestead"] = "Открывает обозреватель декора. Можно также назначить клавишу в разделе «Назначение клавиш» > Homestead"
L["Minimap button"] = "Кнопка у миникарты"
L["Left-click opens the Decor Browser, right-click opens options"] = "ЛКМ открывает обозреватель декора, ПКМ открывает настройки"
L["The Decor Browser is not available yet."] = "Обозреватель декора пока недоступен."

-- Welcome window
L["Find every decor vendor on your map and see what you own before you buy."] = "Находите всех торговцев декором на карте и смотрите, что у вас уже есть, прежде чем покупать."
L["What Homestead Does"] = "Что умеет Homestead"
L["Every decor vendor pinned on your world map and minimap, with badges showing how many items you still need per zone."] = "Все торговцы декором отмечены на карте мира и миникарте, а значки показывают, сколько предметов вам ещё нужно в каждой зоне."
L["Map Side Panel"] = "Боковая панель карты"
L["Click the Homestead button on the world map to open the side panel listing that zone's vendors, then click any vendor to browse their wares and see what you still need. Pop it out as a standalone window with |cFF00FF00/hs panel|r."] = "Нажмите кнопку Homestead на карте мира, чтобы открыть боковую панель со списком торговцев зоны, затем выберите любого торговца, чтобы просмотреть его товары и узнать, чего вам ещё не хватает. Её можно открепить в отдельное окно командой |cFF00FF00/hs panel|r."
L["Tooltips Expanded"] = "Расширенные подсказки"
L["Every item in the Housing Catalog gets tooltips showing where it comes from (vendor, quest, achievement, profession, or drop), what it costs, and what you need to unlock it, so you never have to leave the game to look something up."] = "Каждый предмет каталога жилья получает подсказки: откуда он берётся (торговец, задание, достижение, профессия или добыча), сколько стоит и что нужно для его открытия, так что искать информацию вне игры не придётся."
L["Key Commands"] = "Основные команды"
L["Show all commands"] = "Показать все команды"
L["Found a Problem?"] = "Нашли проблему?"
L["Report bugs or wrong vendor info on GitHub using the link below."] = "Сообщайте об ошибках и неверных данных о торговцах на GitHub по ссылке ниже."
L["Report issues (GitHub):"] = "Сообщить о проблеме (GitHub):"
L["CurseForge:"] = "CurseForge:"
L["Don't show this again"] = "Больше не показывать"
L["Let's Decorate!"] = "Украшаем!"

-------------------------------------------------------------------------------
-- Decor Browser: source and vendor labels
-------------------------------------------------------------------------------
L["Achievements"] = "Достижения"
L["Quests"] = "Задания"
L["Professions"] = "Профессии"
L["Drops"] = "Добыча"
L["Events"] = "События"
L["Other"] = "Другое"
L["Location not recorded"] = "Местоположение не записано"
L["Requires"] = "Требуется"

-------------------------------------------------------------------------------
-- Decor Browser: states and shared parts
-------------------------------------------------------------------------------
L["Collected"] = "Собрано"
L["Can get now"] = "Можно получить сейчас"
L["Requires: %s"] = "Требуется: %s"
L["Not enough: %s"] = "Не хватает: %s"
L["(%1$s has %2$s)"] = "(у %1$s есть %2$s)"
L["Price not recorded"] = "Цена не записана"
L["%s only"] = "Только %s"
L["Not collected"] = "Не собрано"
L["Counting…"] = "Подсчёт…"
L["Not confirmed"] = "Не подтверждено"
L["Active now"] = "Сейчас активно"
L["Best to get now"] = "Лучшее для получения сейчас"
L["Search decor"] = "Поиск декора"
L["More vendors here"] = "Другие торговцы здесь"
L["Reset filters"] = "Сбросить фильтры"
L["Search all decor"] = "Искать по всему декору"
L["Show what's missing"] = "Показать недостающее"
L["Sort by name"] = "Сортировать по названию"
L["Show them"] = "Показать"
L["Show vendor"] = "Показать торговца"
L["Report a problem"] = "Сообщить о проблеме"
L["Reading your collection. This list fills in when it's ready."] = "Чтение вашей коллекции. Этот список заполнится, когда всё будет готово."
L["Reading your collection. This list fills in when it's ready, because Best to get now depends on what you own."] = "Чтение вашей коллекции. Этот список заполнится, когда всё будет готово, потому что порядок Лучшее для получения сейчас зависит от того, что у вас есть."
L["Nothing missing"] = "Всё собрано"
L["You've collected all %d decor Homestead knows about."] = "Вы собрали весь декор, известный Homestead (%d)."
L["Nothing you can get right now"] = "Сейчас ничего нельзя получить"
L["Everything you're missing needs a reputation, achievement or quest first, is sold only during an event, or is sold only to the %s."] = "Всё, чего вам не хватает, сначала требует репутации, достижения или задания, продаётся только во время события или только фракции: %s."
L["Everything you're missing needs a reputation, achievement or quest first, or is sold only during an event."] = "Всё, чего вам не хватает, сначала требует репутации, достижения или задания или продаётся только во время события."
L["Collection not read yet"] = "Коллекция ещё не прочитана"
L["Homestead hasn't read this character's decor collection yet, so it can't tell what you're missing. It reads it shortly after you log in. If this message stays, open the Housing Dashboard once."] = "Homestead ещё не прочитал коллекцию декора этого персонажа, поэтому не знает, чего вам не хватает. Он читает её вскоре после входа в игру. Если это сообщение не исчезает, один раз откройте панель жилья."
L["These filters need your collection, which Homestead hasn't read yet. If this stays, open the Housing Dashboard once."] = "Для этих фильтров нужна ваша коллекция, которую Homestead ещё не прочитал. Если это не проходит, один раз откройте панель жилья."
L["No results"] = "Ничего не найдено"
L["No decor matches these words and filters. Search looks at item names only."] = "Ни один декор не подходит под эти слова и фильтры. Поиск учитывает только названия предметов."
L["%d hidden by '%s' (%d collected, %d %s only)."] = "Скрыто %d по настройке '%s' (собрано: %d; ещё %d только для %s)."
L["%d hidden by '%s' (%d collected, %d %s only, %d %s only)."] = "Скрыто %d по настройке '%s' (собрано: %d; %d только для %s; %d только для %s)."
L["%d hidden by '%s' (%d collected)."] = "Скрыто %d по настройке '%s' (собрано: %d)."
L["%s or the %s"] = "%s или %s"

-------------------------------------------------------------------------------
-- Decor Browser: Summary
-------------------------------------------------------------------------------
L["What can I get now?"] = "Что можно получить сейчас?"
L["Decor this character can buy or earn today, best first."] = "Декор, который этот персонаж может купить или заработать сегодня, лучшее в начале."
L["Can get now means this character can get it today: the right faction, no requirement left to meet, and enough gold or currency to pay. Gold-only and cheaper items come first. Use See all for the full list."] = "«Можно получить сейчас» значит, что этот персонаж может получить это сегодня: подходящая фракция, не осталось невыполненных требований и хватает золота или валюты для оплаты. Сначала идут предметы только за золото и более дешёвые. Весь список открывает «Показать все»."
L["Show"] = "Показать"
L["%s and %d more"] = "%s и ещё %d"
L["See all you can get now (%d)"] = "Показать все, что можно получить сейчас (%d)"
L["Here in %s: %s sells %d decor you can get now."] = "Здесь, в %s: %s продаёт %d ед. декора, доступного сейчас."
L["Sold here in %s"] = "Продаётся здесь, в %s"
L["Sold on %s"] = "Продаётся на %s"
L["%s: active now"] = "%s: сейчас активно"
L["Gold"] = "Золото"
L["Gold only"] = "Только за золото"
L["Gold only, no requirements left"] = "Только за золото, требований не осталось"
L["No requirements left"] = "Требований не осталось"
L["%d of %d"] = "%d из %d"
L["Reading your collection"] = "Чтение коллекции"
-- end: Summary

-------------------------------------------------------------------------------
-- Decor Browser: Catalog
-------------------------------------------------------------------------------
L["All decor"] = "Весь декор"
L["Filters"] = "Фильтры"
L["Name"] = "Название"
L["Sort: %s"] = "Сортировка: %s"
L["Furnishings"] = "Мебель"
L["Structural"] = "Конструкции"
L["Accents"] = "Акценты"
L["Lighting"] = "Освещение"
L["Neither collected nor not collected"] = "Ни собрано, ни не собрано"
L["Sources: %s"] = "Источники: %s"
L["Filtered: %s"] = "Фильтр: %s"
L["(+%d more)"] = "(+%d ещё)"
-- end: Catalog

-------------------------------------------------------------------------------
-- Decor Browser: Sources
-------------------------------------------------------------------------------
L["Search vendors and zones"] = "Поиск торговцев и зон"
L["Search achievements"] = "Поиск достижений"
L["Search quests"] = "Поиск заданий"
L["Search recipes and professions"] = "Поиск рецептов и профессий"
L["Search drops and zones"] = "Поиск добычи и зон"
L["Search events"] = "Поиск событий"
L["Search the Shop"] = "Поиск в магазине"
L["%d decor"] = "Предметов декора: %d"
L["No decor"] = "Нет декора"
L["Not active"] = "Не активно"
L["All collected"] = "Все собрано"
L["%d can get now"] = "Можно получить сейчас: %d"
L["Holiday event"] = "Праздничное событие"
L["%s only: can't buy on this character"] = "Только %s: этим персонажем купить нельзя"
L["Confirmed by a scan on %s"] = "Подтверждено сканированием: %s"
L["No scan has confirmed this vendor yet. Visit the vendor to check."] = "Ни одно сканирование еще не подтвердило этого торговца. Посетите его, чтобы проверить."
L["Decor from this source"] = "Декор из этого источника"
L["No decor is recorded here. If this source gives decor, report it below."] = "Здесь нет записанного декора. Если этот источник дает декор, сообщите об этом ниже."
L["Dig site in %s"] = "Место раскопок: %s"
L["No events active right now. Event decor is sold only while its event runs."] = "Сейчас нет активных событий. Декор событий продается только во время события."
L["Nothing matches your search."] = "По вашему запросу ничего не найдено."
L["Nothing to show here."] = "Здесь нечего показывать."
L["Currency"] = "Валюта"
L["Wares"] = "Товары"
L["Not confirmed: visit to check."] = "Не подтверждено: посетите торговца, чтобы проверить."
L["Corners: state top right, bonus top left, event bottom left, copies bottom right."] = "Углы: состояние справа вверху, бонус слева вверху, событие слева внизу, количество копий справа внизу."
L["%s; %s"] = "%s; %s"
L["%s · %s"] = "%s · %s"
-- end: Sources

-------------------------------------------------------------------------------
-- Decor Browser: Item
-------------------------------------------------------------------------------
L["Vendor:"] = "Торговец:"
L["Achievement:"] = "Достижение:"
L["Quest:"] = "Задание:"
L["Recipe:"] = "Рецепт:"
L["Drop:"] = "Добыча:"
L["Event:"] = "Событие:"
L["Starts in %s"] = "Начинается: %s"
L["Daily from The Last Architect"] = "Ежедневное от The Last Architect"
L["Can get now here"] = "Можно получить здесь сейчас"
L["Where to get it"] = "Где получить"
L["Show achievement"] = "Показать достижение"
L["Show quest"] = "Показать задание"
L["Show recipe"] = "Показать рецепт"
L["Show drop"] = "Показать добычу"
L["Show event"] = "Показать событие"
L["%s (done)"] = "%s (выполнено)"
L["%s (not yet)"] = "%s (ещё нет)"
L["Can't check this requirement yet"] = "Это требование пока нельзя проверить"
L["Active now: %s"] = "Сейчас активно: %s"
L["Decor Browser"] = "Обозреватель декора"
L["Show 3D preview"] = "Показывать 3D-превью"
L["desc_browser_model3d"] = "Показывает 3D-модель предмета на его странице в обозревателе декора."
-- end: Item
