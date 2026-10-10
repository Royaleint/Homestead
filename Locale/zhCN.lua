--[[
    Homestead - Locale: Simplified Chinese (zhCN)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "zhCN" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["Used in %d known recipe for decor you haven't collected"] = "可用于%d个已知配方，制作你尚未收集的装饰"
L["Used in %d known recipes for decor you haven't collected"] = "可用于%d个已知配方，制作你尚未收集的装饰"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["Homestead"] = "Homestead"
L["Homestead Options"] = "Homestead选项"
L["Overlays"] = "覆盖图标"
L["Tooltips"] = "说明条"
L["Export"] = "导出"

L["Show minimap button"] = "显示微缩地图按钮"
L["Enable overlays"] = "启用覆盖图标"
L["Show on bags"] = "在背包上显示"
L["Show on bank"] = "在银行中显示"
L["Show on merchant"] = "在商人界面显示"
L["Show on housing catalog"] = "在住宅装饰类别中显示"
L["Icon size"] = "图标尺寸"
L["Icon position"] = "图标位置"
L["Show opposite faction vendors"] = "显示对立阵营商人"

L["Enable tooltip additions"] = "启用提示信息附加内容"
L["Show source information"] = "显示来源信息"
L["Show vendor details in tooltips"] = "在提示信息中显示商人详情"

L["Show map pins"] = "显示地图标记"
L["Show minimap pins"] = "显示微缩地图标记"
L["Use TomTom for waypoints"] = "使用TomTom导航点"
L["Use native waypoints"] = "使用游戏内置导航点"
L["Auto-create waypoint on click"] = "点击时自动创建导航点"
L["Navigate modifier key"] = "导航修饰键"

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d / %d (%d%%)"] = "收藏：%d / %d（%d%%）"
L["Vendors nearby: %d"] = "附近商人：%d"
L["Vendors scanned: %d"] = "已扫描商人：%d"
L["Left-Click: Toggle options"] = "|cFFFFFFFF左键点击：|r打开/关闭选项"
L["Right-Click: Detach/close vendor panel"] = "|cFFFFFFFF右键点击：|r分离/关闭商人面板"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Homestead命令："

-------------------------------------------------------------------------------
-- Slash Command Feedback
-------------------------------------------------------------------------------
L["Map pins refreshed."] = "地图标记已刷新。"
L["No active waypoint."] = "当前没有导航点。"
L["Waypoint cleared."] = "导航点已清除。"
L["Vendor database contains %d vendors."] = "商人数据库共有%d个商人。"
L["Use /hs vendor <name or zone> to search."] = "输入 /hs vendor <名称或地区> 进行搜索。"
L["No vendors found matching: %s"] = "未找到匹配的商人：%s"
L["Found %d vendor(s) matching: %s"] = "找到%d个匹配的商人：%s"
L["... and %d more."] = "……另有%d个。"

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "调试模式：%s"
L["ON"] = "已开启"
L["OFF"] = "已关闭"
L["Unknown command: %s"] = "未知命令：%s"
L["Type /hs help for a list of commands."] = "输入 /hs help 查看命令列表。"

-------------------------------------------------------------------------------
-- Version Check
-------------------------------------------------------------------------------
L["Your Homestead version is out-of-date."] = "你的Homestead版本已过期。"
L["Version %s (%s) can be downloaded at CurseForge, Wago, or GitHub Releases."] = "版本%s（%s）可在CurseForge、Wago或GitHub Releases下载。"
L["Homestead version: %s (%s)"] = "Homestead版本：%s（%s）"
L["Newest version seen this session: %s (%s)"] = "本次登录见到的最新版本：%s（%s）"
L["No newer version seen this session."] = "本次登录未发现更新的版本。"
L["Version-check notifications: %s"] = "版本检查通知：%s"

-------------------------------------------------------------------------------
-- Export Dialog
-------------------------------------------------------------------------------
L["Export Vendor Data"] = "导出商人数据"
L["Choose export option:"] = "选择导出方式："
L["Export New Scans"] = "导出新扫描"
L["Export All"] = "导出全部"

-------------------------------------------------------------------------------
-- Map Side Panel
-------------------------------------------------------------------------------
L["All"] = "全部"
L["Vendor"] = "商人"
L["Vendors"] = "商人"
L["Quest"] = "任务"
L["Achievement"] = "成就"
L["Profession"] = "专业技能"
L["Event"] = "事件"
L["Drop"] = "掉落"
L["Treasure"] = "宝藏"
L["Zone Collection Progress"] = "地区收藏进度"
L["Continent Collection Progress"] = "大陆收藏进度"
L["Global Collection Progress"] = "全局收藏进度"
L["Order Hall"] = "职业大厅"
L["Click to preview"] = "点击预览"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "输出"
L["Select All"] = "全选"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "已选中全部文本。按Ctrl+C复制到剪贴板。"

-------------------------------------------------------------------------------
-- Options - Names
-------------------------------------------------------------------------------
L["Vendor pin item details"] = "商人标记物品详情"

L["Auto-scan vendors"] = "自动扫描商人"
L["Vendor Visibility"] = "商人显示"
L["Show event vendors"] = "显示事件商人"
L["Hide fully-collected vendor pins"] = "隐藏已收集完毕的商人标记"
L["Fully-collected vendors"] = "已收集完毕的商人"
L["desc_map_filter_completed_vendors"] = "取消勾选以隐藏装饰已收集完毕的商人标记。"
L["Pin Appearance"] = "标记外观"
L["Pin color"] = "标记颜色"
L["Custom color"] = "自定义颜色"
L["Show accessibility glow"] = "显示辅助功能光晕"
L["Owned item style"] = "已拥有物品样式"
L["Show ownership status"] = "显示拥有状态"
L["Show requirements"] = "显示所需条件"
L["Show all sources"] = "显示全部来源"
L["Map Pins"] = "地图标记"
L["Show vendor panel on world map"] = "在世界地图上显示商人面板"
L["Vendor panel source filter"] = "商人面板来源筛选"
L["Integrate with map frame border"] = "与地图边框融合"
L["Zone badges on world map"] = "世界地图地区徽标"
L["World map pin size"] = "世界地图标记尺寸"
L["Show collection counts"] = "显示收藏数量"
L["Show elevation arrows"] = "显示高度箭头"
L["Minimap nearby-zone pins"] = "微缩地图邻近地区标记"
L["Minimap pin size"] = "微缩地图标记尺寸"
L["Waypoints"] = "导航点"
L["Show milestone progress on dashboard"] = "在住宅信息板上显示里程碑进度"
L["Inventory"] = "物品栏"
L["Merchant"] = "商人界面"
L["Housing Catalog"] = "住宅装饰类别"

-------------------------------------------------------------------------------
-- Options - Descriptions
-------------------------------------------------------------------------------
L["desc_minimap_button"] = "显示或隐藏微缩地图按钮"
L["desc_auto_scan_vendors"] = "拜访商人时自动扫描其货物，收集住宅装饰数据。禁用后打开商人界面时性能可能略有提升。"
L["desc_options_general"] = "插件核心行为、微缩地图入口、商人扫描和地图标记外观。"
L["desc_options_overlays"] = "在背包、银行、商人界面和住宅装饰类别中显示的收藏标记。"
L["desc_options_tooltips"] = "在物品和地图标记提示信息中添加的拥有状态、来源、所需条件和商人详情。"
L["desc_options_world_map"] = "世界地图商人标记、地区徽标、侧边面板行为和地图标记显示。"
L["desc_options_minimap"] = "微缩地图上的附近商人标记、高度箭头和导航点行为。"
L["desc_options_endeavors"] = "在暴雪的住宅信息板上显示住宅文化节进度。"
L["desc_options_export"] = "导出已扫描的商人数据，用于查看或备份。"
L["desc_vendor_visibility_section"] = "选择哪些商人分组显示在地图上并计入收藏总数。"
L["desc_pin_appearance_section"] = "调整Homestead商人标记的颜色和预览。"
L["desc_overlay_inventory_section"] = "在住宅装饰类别以外的物品栏位上显示收藏标记。"
L["desc_overlay_merchant_section"] = "浏览商人物品时标记已收集的装饰。"
L["desc_overlay_catalog_section"] = "设置住宅装饰类别中的标记、高亮和已收集物品的样式。"
L["desc_tooltip_map_pins_section"] = "选择地图标记提示信息中显示多少商人详情。"
L["desc_minimap_waypoints_section"] = "设置点击地图和商人时TomTom与游戏内置导航点的行为。"
L["desc_opposite_faction"] = "显示对立阵营的商人及其阵营徽记。适合想查看所有可用商人的收集爱好者。"
L["desc_event_vendors"] = "节日事件进行期间，在地图上显示节日商人标记（例如春节）"
L["desc_hide_completed_vendor_pins"] = "隐藏住宅装饰已收集完毕的商人在地图和微缩地图上的标记。商人面板列表不受影响。"
L["desc_pin_color"] = "为地图和微缩地图标记选择颜色。"
L["desc_custom_color"] = "为地图标记选择自定义基础颜色"
L["desc_enable_overlays"] = "在游戏中各处的装饰物品上添加小图标和高亮，让你一眼看出哪些已收集。关闭后将隐藏所有Homestead覆盖图标。"
L["desc_icon_size"] = "控制物品栏位上收藏图标的大小。"
L["desc_icon_position"] = "收藏图标位于物品栏位的哪个角落。"
L["desc_show_on_bags"] = "为背包中的装饰物品添加|A:homestone-minimap-icon:16:16|a，用颜色表示每件是否已收集。支持默认背包、Baganator和BetterBags。"
L["desc_show_on_bank"] = "标记银行中的装饰物品，以便查看哪些已收集。"
L["desc_show_on_merchant"] = "为商人处的装饰物品添加|A:homestone-minimap-icon:16:16|a，用颜色表示每件是否已收集。"
L["desc_show_on_housing_catalog"] = "用收藏图标标记住宅装饰类别中的物品，显示每件物品的来源。\n\n|A:auctionhouse-icon-coin-gold:16:16|a 商人\n|A:QuestNormal:16:16|a 任务\n|A:UI-Achievement-Shield-NoPoints:16:16|a 成就\n|A:UI-HUD-MicroMenu-Professions-Mouseover:16:16|a 专业技能\n|A:UI-HUD-Calendar-1-Up:16:16|a 事件\n|A:Crosshair_lootall_64:16:16|a 掉落\n|A:hearthsteel-icon-32x32:16:16|a 战网商城"
L["desc_accessibility_glow"] = "为住宅装饰类别中的物品添加彩色边框光晕：绿色表示已拥有，黄色表示可获得，红色表示因未满足所需条件而锁定。"
L["desc_owned_item_style"] = "选择已收集物品在住宅装饰类别中的外观。“绿色高亮”显示默认光晕，“变暗”使其淡出，“对勾”添加一个绿色小勾。选择“无”则保持原样。"
L["desc_enable_tooltips"] = "鼠标悬停在装饰物品上时，在物品提示信息中添加Homestead信息。关闭后将移除所有提示信息附加内容。"
L["desc_show_ownership"] = "在提示信息中添加一行，显示你是否已收集该装饰物品。"
L["desc_show_source"] = "显示装饰物品的获取方式——商人、任务、成就、专业技能、事件和掉落。"
L["desc_show_requirements"] = "显示购买物品的所需条件，如声望、任务完成或成就。"
L["desc_show_all_sources"] = "列出物品所有已知的获取方式，而不只是最佳来源。物品可从多个商人、任务或其他来源获得时很有用。"
L["desc_vendor_details"] = "鼠标悬停在商人的地图标记上时，显示其全部货物和你的收藏进度。禁用后提示信息只显示商人名称。"
L["desc_vendor_pin_item_details"] = "在地图标记提示信息中显示每件物品的其他来源图标和商人售价，以及仅限商人出售的物品数量。禁用后提示信息只列出物品名称。"
L["desc_show_map_pins"] = "在世界地图上显示商人位置"
L["desc_show_map_side_panel"] = "在世界地图旁显示侧边面板，列出当前地区的商人和收藏进度"
L["desc_source_filter"] = "按获取来源筛选侧边面板的物品数量和展开的物品网格。地图上的商人显示不受影响。"
L["desc_integrate_map_border"] = "将面板顶部边框与世界地图边框融为一体，外观更加无缝。如果你使用的自定义界面（ElvUI、GW2等）与之冲突，请禁用此项。"
L["desc_zone_badges"] = "在世界地图的大陆上分别显示各地区的商人数量，而不是每个大陆只显示一个总数。"
L["desc_world_pin_size"] = "调整世界地图上商人标记的大小。默认值（20）与暴雪的兴趣点图标一致。"
L["desc_show_pin_counts"] = "在商人标记上显示已收集/总计物品数量（例如3/12）。禁用可减少地图杂乱。"
L["desc_show_minimap_pins"] = "在微缩地图上显示商人位置及高度箭头"
L["desc_elevation_arrows"] = "商人位于你上方或下方时，在微缩地图标记上显示方向箭头"
L["desc_cross_zone_mode"] = "控制跨地区的微缩地图标记。“自动”会在密集的城市地区减少额外标记，使移动更流畅。"
L["desc_minimap_pin_size"] = "调整微缩地图上商人标记的大小。标记看不清时可调大，也可调小以减少微缩地图杂乱。"
L["desc_waypoint_info"] = "TomTom会显示方向箭头覆盖层，需要安装TomTom插件。游戏内置导航点会在世界地图上添加目的地标记。两者可以同时启用。"
L["desc_use_tomtom"] = "使用TomTom插件显示导航箭头（如已安装）"
L["desc_use_native_waypoints"] = "使用魔兽世界内置的导航点系统和地图标记"
L["desc_auto_waypoint"] = "点击列表或地图中的商人时自动创建导航点"
L["desc_navigate_modifier"] = "点击时按住此键以创建导航点（自动导航点关闭时）"
L["desc_milestone_xp"] = "在暴雪住宅信息板的文化节标签页上显示下一个里程碑的经验值进度。如果你已使用其他插件实现此功能（例如Endeavor Simple Progress Tracker），请禁用此项。"
L["desc_export"] = "导出已扫描的商人数据用于备份。"
L["desc_export_new"] = "导出自上次导出以来扫描的商人。包括价格、货币、阵营和装饰类别信息。"
L["desc_export_all"] = "导出所有已扫描的商人，忽略时间戳筛选。"

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
L["Checkmark"] = "对勾"

-- Source filter
L["All sources"] = "全部来源"

-- Minimap cross-zone mode
L["Auto (recommended)"] = "自动（推荐）"
L["Current zone only"] = "仅当前地区"
L["Always show nearby zones"] = "始终显示邻近地区"

-- Navigate modifier
L["None (always)"] = "无（始终）"

-- Misc
L["Approximate map appearance"] = "地图上的大致外观"
L["ExportImport not available."] = "ExportImport不可用。"
