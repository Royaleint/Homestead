--[[
    Homestead - Locale: Simplified Chinese (zhCN)
]]

local addonName, HA = ...

if GetLocale() ~= "zhCN" then return end

-- Reuse the existing L table so untranslated keys fall back to English
local L = HA.L

-------------------------------------------------------------------------------
-- Collection Status
-------------------------------------------------------------------------------
L["Collected"] = "已收集"
L["Collected (Placed)"] = "已收集（已放置）"
L["Not Collected"] = "未收集"
L["Unknown"] = "未知"

-------------------------------------------------------------------------------
-- Source Descriptions
-------------------------------------------------------------------------------
L["Available from vendor"] = "可从商人处购买"
L["Can be crafted"] = "可制作"
L["Achievement reward"] = "成就奖励"
L["World drop"] = "世界掉落"
L["Quest reward"] = "任务奖励"
L["Reputation reward"] = "声望奖励"
L["Event reward"] = "活动奖励"
L["Promotional item"] = "促销物品"

-------------------------------------------------------------------------------
-- Decor Properties
-------------------------------------------------------------------------------
L["Can be dyed"] = "可染色"
L["Colorable"] = "可上色"
L["Warbound"] = "战团绑定"
L["Indoor only"] = "仅限室内"
L["Outdoor only"] = "仅限室外"
L["Quantity owned: %d"] = "拥有数量: %d"
L["Currently placed: %d"] = "当前放置: %d"

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["[Housing Addon]"] = "|cFF00FF00[家园助手]|r"
L["Source:"] = "来源:"
L["Vendor:"] = "商人:"
L["Location:"] = "位置:"
L["Click to set waypoint"] = "点击设置导航点"

-------------------------------------------------------------------------------
-- UI Labels
-------------------------------------------------------------------------------
L["Housing Addon"] = "家园助手"
L["Decor Browser"] = "装饰浏览器"
L["Vendor Tracer"] = "商人追踪"
L["Color Tracker"] = "颜色追踪"
L["Export Data"] = "导出数据"
L["Options"] = "选项"
L["Search"] = "搜索"
L["Filter"] = "筛选"
L["Close"] = "关闭"

-------------------------------------------------------------------------------
-- Vendor Tracer
-------------------------------------------------------------------------------
L["Set Waypoint"] = "设置导航点"
L["Show on Map"] = "在地图上显示"
L["Vendor sells %d decor items"] = "商人出售 %d 件装饰品"
L["You own %d/%d items"] = "你拥有 %d/%d 件物品"
L["Missing items:"] = "缺少的物品:"
L["No vendors found"] = "未找到商人"

-------------------------------------------------------------------------------
-- Color/Dye Tracker
-------------------------------------------------------------------------------
L["Dye Collection"] = "染料收藏"
L["Owned Dyes"] = "已有染料"
L["Known Recipes"] = "已知配方"
L["Dye Slots"] = "染色槽"
L["Apply Dye"] = "使用染料"
L["Preview"] = "预览"

-------------------------------------------------------------------------------
-- Options - Tab Names
-------------------------------------------------------------------------------
L["General"] = "常规"
L["Overlays"] = "覆盖层"
L["Tooltips"] = "提示信息"
L["Export"] = "导出"

-------------------------------------------------------------------------------
-- Options - General
-------------------------------------------------------------------------------
L["Enable addon"] = "启用插件"
L["Show minimap button"] = "显示小地图按钮"
L["Auto-scan vendors"] = "自动扫描商人"
L["Vendor Visibility"] = "商人可见性"
L["Show opposite faction vendors"] = "显示对立阵营商人"
L["Show unverified vendors"] = "显示未验证商人"
L["Show event vendors"] = "显示活动商人"
L["Pin Appearance"] = "标记外观"
L["Pin color"] = "标记颜色"
L["Custom color"] = "自定义颜色"

L["desc_enable_addon"] = "启用或禁用 Homestead"
L["desc_minimap_button"] = "显示或隐藏小地图按钮"
L["desc_auto_scan_vendors"] = "访问商人时自动扫描其库存中的家园装饰数据。社区数据有助于改善插件的商人数据库。禁用此选项可在打开商人界面时略微提升性能。"
L["desc_opposite_faction"] = "显示对立阵营的商人及其阵营徽章。对于想要查看所有可用商人的收集爱好者很有用。"
L["desc_unverified_vendors"] = "显示位置未验证的商人（橙色标记）。这些数据来自外部来源，坐标可能不正确。请在游戏中亲自前往这些商人处以验证其位置。"
L["desc_event_vendors"] = "当活动开启时在地图上显示季节性节日商人标记（例如：春节庆典）"
L["desc_pin_color"] = "选择地图和小地图标记的颜色。未验证的标记始终显示为橙色。"
L["desc_custom_color"] = "为地图标记选择自定义基础颜色"

-------------------------------------------------------------------------------
-- Options - Overlays
-------------------------------------------------------------------------------
L["Enable overlays"] = "启用覆盖层"
L["Icon size"] = "图标大小"
L["Icon position"] = "图标位置"
L["Inventory"] = "背包"
L["Show on bags"] = "在背包中显示"
L["Show on bank"] = "在银行中显示"
L["Show on auction house"] = "在拍卖行中显示"
L["Merchant"] = "商人"
L["Show on merchant"] = "在商人处显示"
L["Housing Catalog"] = "家园目录"
L["Show on housing catalog"] = "在家园目录中显示"
L["Show accessibility glow"] = "显示辅助发光效果"
L["Owned item style"] = "已拥有物品样式"

L["desc_enable_overlays"] = "在游戏中的装饰物品上添加小图标和高亮，让你一目了然地看到哪些已收集。关闭此选项会隐藏所有 Homestead 覆盖层。"
L["desc_icon_size"] = "控制物品栏上收集图标的大小。"
L["desc_icon_position"] = "收集图标在物品栏中的显示位置。"
L["desc_show_on_bags"] = "在背包中已收集的装饰物品上添加 |TInterface\\RaidFrame\\ReadyCheck-Ready:16|t 标记。支持默认背包、Baganator 和 BetterBags。"
L["desc_show_on_bank"] = "标记银行中的装饰物品，以便查看哪些已经收集。"
L["desc_show_on_auction_house"] = "标记拍卖行中的装饰物品，避免购买重复物品。"
L["desc_show_on_merchant"] = "在商人处已收集的装饰物品上添加 |TInterface\\RaidFrame\\ReadyCheck-Ready:16|t 标记。"
L["desc_show_on_housing_catalog"] = "在家园目录中的物品上标注收集图标，显示每件物品的来源。\n\n"
    .. "|A:auctionhouse-icon-coin-gold:16:16|a 商人\n"
    .. "|A:QuestNormal:16:16|a 任务\n"
    .. "|A:UI-Achievement-Shield-NoPoints:16:16|a 成就\n"
    .. "|A:UI-HUD-MicroMenu-Professions-Mouseover:16:16|a 专业\n"
    .. "|A:UI-HUD-Calendar-1-Up:16:16|a 活动\n"
    .. "|A:Crosshair_lootall_64:16:16|a 掉落\n"
    .. "|A:hearthsteel-icon-32x32:16:16|a 战网商城"
L["desc_accessibility_glow"] = "为家园目录物品添加彩色边框发光效果：绿色表示已拥有，黄色表示可获取，红色表示被需求条件锁定。"
L["desc_owned_item_style"] = "选择已收集物品在家园目录中的显示方式。绿色高亮显示默认发光效果，变暗会淡化显示，勾选标记会添加一个小绿勾。选择无则保持原样。"

-------------------------------------------------------------------------------
-- Options - Tooltips
-------------------------------------------------------------------------------
L["Enable tooltip additions"] = "启用提示信息增强"
L["Show ownership status"] = "显示拥有状态"
L["Show source information"] = "显示来源信息"
L["Show quantity owned"] = "显示拥有数量"
L["Show dye slot information"] = "显示染色槽信息"
L["Show requirements"] = "显示需求条件"
L["Show all sources"] = "显示所有来源"
L["Map Pins"] = "地图标记"
L["Show vendor details in tooltips"] = "在提示信息中显示商人详情"

L["desc_enable_tooltips"] = "当鼠标悬停在装饰物品上时，在提示信息中添加 Homestead 信息。关闭此选项会移除所有提示信息增强。"
L["desc_show_ownership"] = "在提示信息中添加一行显示你是否已收集该装饰物品。"
L["desc_show_source"] = "显示获取装饰物品的途径——商人、任务、成就、专业、活动和掉落。"
L["desc_show_quantity"] = "显示你当前拥有该装饰物品的数量。"
L["desc_show_requirements"] = "显示购买条件，如声望、任务完成度或成就等购买物品所需的前置要求。"
L["desc_show_all_sources"] = "列出获取物品的所有已知途径，而不仅仅是最佳来源。当物品可从多个商人、任务或其他来源获取时很有用。"
L["desc_vendor_details"] = "悬停在地图标记上时显示商人的完整库存和你的收集进度。禁用后仅显示商人名称的简要提示。"

-------------------------------------------------------------------------------
-- Options - World Map
-------------------------------------------------------------------------------
L["World Map"] = "世界地图"
L["Show map pins"] = "显示地图标记"
L["Show vendor panel on world map"] = "在世界地图上显示商人面板"
L["Vendor panel source filter"] = "商人面板来源筛选"
L["Integrate with map frame border"] = "与地图边框整合"
L["Zone badges on world map"] = "世界地图区域徽章"
L["World map pin size"] = "世界地图标记大小"
L["Show collection counts"] = "显示收集计数"

L["desc_show_map_pins"] = "在世界地图上显示商人位置"
L["desc_show_map_side_panel"] = "在世界地图上显示侧边面板，列出当前区域的商人和收集进度"
L["desc_source_filter"] = "按获取来源筛选侧边面板的物品计数和展开网格。地图上的商人可见性不受影响。"
L["desc_integrate_map_border"] = "将面板顶部边框与世界地图边框融合，呈现无缝外观。如果你使用自定义UI（ElvUI、GW2等）导致冲突，请禁用此选项。"
L["desc_zone_badges"] = "在世界地图的大陆视图上显示各区域的商人数量，而不是每个大陆的总计数量。"
L["desc_world_pin_size"] = "调整世界地图上商人标记的大小。默认值（20）与暴雪兴趣点图标一致。"
L["desc_show_pin_counts"] = "在商人标记上显示已收集/总数（例如 3/12）。禁用可减少地图杂乱。"

-------------------------------------------------------------------------------
-- Options - Minimap
-------------------------------------------------------------------------------
L["Minimap"] = "小地图"
L["Show minimap pins"] = "显示小地图标记"
L["Show elevation arrows"] = "显示高度箭头"
L["Minimap nearby-zone pins"] = "小地图跨区域标记"
L["Minimap pin size"] = "小地图标记大小"
L["Waypoints"] = "导航点"
L["Use TomTom for waypoints"] = "使用TomTom导航"
L["Use native waypoints"] = "使用原生导航点"
L["Auto-create waypoint on click"] = "点击时自动创建导航点"
L["Navigate modifier key"] = "导航修饰键"

L["desc_show_minimap_pins"] = "在小地图上显示带高度箭头的商人位置"
L["desc_elevation_arrows"] = "当商人在你上方或下方时，在小地图标记上显示方向箭头"
L["desc_cross_zone_mode"] = "控制跨区域小地图标记。自动模式会减少密集城市区域的额外标记，使移动更流畅。"
L["desc_minimap_pin_size"] = "调整小地图上商人标记的大小。增大可使标记更易见，减小可减少小地图杂乱。"
L["desc_waypoint_info"] = "TomTom 会显示方向箭头覆盖层，需要安装 TomTom 插件。原生导航会在世界地图上添加目标标记。两者可以同时启用。"
L["desc_use_tomtom"] = "使用 TomTom 插件的导航箭头（如已安装）"
L["desc_use_native_waypoints"] = "使用魔兽世界内置的导航点系统"
L["desc_auto_waypoint"] = "点击列表或地图中的商人时自动创建导航点"
L["desc_navigate_modifier"] = "按住此键点击以创建导航点（自动导航关闭时）"

-------------------------------------------------------------------------------
-- Options - Endeavors
-------------------------------------------------------------------------------
L["Endeavors"] = "成就进度"
L["Show milestone progress on dashboard"] = "在仪表盘显示里程碑进度"
L["desc_milestone_xp"] = "在暴雪家园仪表盘的成就标签上显示下一个里程碑的经验进度。如果你使用其他插件（如 Endeavor Simple Progress Tracker），请禁用此选项。"

-------------------------------------------------------------------------------
-- Options - Export
-------------------------------------------------------------------------------
L["Export New Scans"] = "导出新扫描"
L["Export All"] = "导出全部"
L["desc_export"] = "导出扫描的商人数据，用于社区共享或备份。"
L["desc_export_new"] = "导出上次导出后扫描的商人。包含价格、货币、阵营和目录信息。"
L["desc_export_all"] = "导出所有已扫描的商人，绕过时间戳筛选。"

-------------------------------------------------------------------------------
-- Options - Select Values
-------------------------------------------------------------------------------
-- Pin colors
L["Default (Gold)"] = "默认（金色）"
L["Bright Green"] = "亮绿色"
L["Ice Blue"] = "冰蓝色"
L["Light Blue"] = "浅蓝色"
L["Purple"] = "紫色"
L["Pink"] = "粉色"
L["Red"] = "红色"
L["Cyan"] = "青色"
L["White"] = "白色"
L["Yellow"] = "黄色"
L["Custom..."] = "自定义..."

-- Icon anchor positions
L["Top Left"] = "左上"
L["Top Right"] = "右上"
L["Bottom Left"] = "左下"
L["Bottom Right"] = "右下"
L["Center"] = "居中"

-- Owned item styles
L["Green highlight (default)"] = "绿色高亮（默认）"
L["None"] = "无"
L["Dimmed"] = "变暗"
L["Checkmark"] = "勾选标记"

-- Source filter
L["All sources"] = "所有来源"
L["Vendor"] = "商人"
L["Quest"] = "任务"
L["Achievement"] = "成就"
L["Profession"] = "专业"
L["Event"] = "活动"
L["Drop"] = "掉落"

-- Minimap cross-zone mode
L["Auto (recommended)"] = "自动（推荐）"
L["Current zone only"] = "仅当前区域"
L["Always show nearby zones"] = "始终显示附近区域"

-- Navigate modifier
L["Shift"] = "Shift"
L["Control"] = "Control"
L["Alt"] = "Alt"
L["None (always)"] = "无（始终）"

-- Misc
L["Approximate map appearance"] = "大致地图外观"
L["ExportImport not available."] = "导出导入功能不可用。"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Housing Addon Commands:"] = "家园助手命令:"
L["/ha - Toggle main window"] = "/ha - 切换主窗口"
L["/ha options - Open options panel"] = "/ha options - 打开选项面板"
L["/ha export - Export collection data"] = "/ha export - 导出收藏数据"
L["/ha vendor [search] - Open vendor panel"] = "/ha vendor [搜索] - 打开商人面板"
L["/ha debug - Toggle debug mode"] = "/ha debug - 切换调试模式"
L["/ha help - Show this help"] = "/ha help - 显示此帮助"

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "调试模式: %s"
L["ON"] = "开"
L["OFF"] = "关"
L["Unknown command: %s"] = "未知命令: %s"
L["Not yet implemented"] = "尚未实现"

-------------------------------------------------------------------------------
-- Statistics
-------------------------------------------------------------------------------
L["Statistics"] = "统计"
L["Total Decor:"] = "装饰总数:"
L["Collected:"] = "已收集:"
L["Placed:"] = "已放置:"
L["Remaining:"] = "剩余:"
L["Collection Progress: %d%%"] = "收集进度: %d%%"
