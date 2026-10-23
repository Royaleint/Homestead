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
L["Left-Click: Toggle Decor Browser"] = "|cFFFFFFFF左键点击：|r打开/关闭装饰浏览器"
L["Right-Click: Open options"] = "|cFFFFFFFF右键点击：|r打开选项"

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

-------------------------------------------------------------------------------
-- Decor Browser: data adapter
-------------------------------------------------------------------------------
L["Unknown"] = "未知"
L["A vendor"] = "某个商人"
L["Required"] = "必需"
L["Unknown faction"] = "未知阵营"
L["Other requirement"] = "其他要求"
L["Source unknown"] = "来源未知"
L["Item %d"] = "物品%d"
L["%s %s"] = "%s %s"
L["%s, %s"] = "%s, %s"
L["%s: %s"] = "%s: %s"
L["%s with %s"] = "%s（%s声望）"
L["Level %s"] = "等级%s"
L["Achievement: %s"] = "成就：%s"
L["Quest: %s"] = "任务：%s"
L["Promotion: %s"] = "促销活动：%s"
L["Profession: %s"] = "专业技能：%s"
L["Profession: %s rank %s"] = "专业技能：%s，等级%s"
L["Vendor: %s"] = "商人：%s"
L["Vendor: %s, %s"] = "商人：%s，%s"
L["Crafted: %s - %s"] = "制作：%s - %s"
L["Drops from %s"] = "掉落自%s"
L["Drops from %s (%s)"] = "掉落自%s（%s）"
L["Event: %s"] = "事件：%s"
L["Event: %s - %s"] = "事件：%s - %s"
L["Other source"] = "其他来源"

-- Decor Browser: visuals and widgets
L["Set waypoint"] = "设置导航点"

-- Decor Browser: window and navigation
L["Homestead Decor"] = "Homestead 装饰"
L["Overview"] = "概览"
L["Catalog"] = "目录"
L["Back"] = "返回"
L["Other Vendors"] = "其他商人"
L["%d of %d decor collected"] = "已收集装饰 %d/%d"
L["%d of %d collected"] = "已收集 %d/%d"
L["Help"] = "帮助"
L["Hide what doesn't apply to me"] = "隐藏与我无关的内容"
L["The Decor Browser opens once Homestead has finished loading."] = "装饰浏览器将在Homestead加载完成后打开。"
L["Collection"] = "收藏"
L["Placed"] = "已摆放"
L["In storage"] = "储存中"
L["Not yet redeemed"] = "尚未领取"
L["Counts not loaded yet"] = "数量尚未加载"
L["Source"] = "来源"
L["Price"] = "价格"

-- Decor Browser: shop and item pages
L["Seasonal: %s"] = "季节限定：%s"
L["Rotates with the %s Endeavor"] = "随%s文化节轮换"
L["Rotates with neighborhood Endeavors"] = "随社区文化节轮换"
L["Not available in combat"] = "战斗中不可用"
L["Report a data error"] = "报告数据错误"
L["Item: %s (%d)"] = "物品：%s（%d）"
L["Record ID: %s"] = "记录ID：%s"
L["none"] = "无"
L["no location"] = "无位置"
L["map %d at %.1f, %.1f"] = "地图%d，%.1f, %.1f"
L["Vendor %d: %s, %s, %s"] = "商人%d：%s，%s，%s"
L["Client: %s (%s)"] = "客户端：%s（%s）"
L["Homestead: %s"] = "Homestead: %s"

-- Decor Browser: entry points
L["Toggle Decor Browser"] = "打开/关闭装饰浏览器"
L["Open the Decor Browser, or bind a key under Keybindings > Homestead"] = "打开装饰浏览器，也可以在“按键设置” > Homestead 中绑定按键"
L["Minimap button"] = "微缩地图按钮"
L["Left-click opens the Decor Browser, right-click opens options"] = "左键点击打开装饰浏览器，右键点击打开选项"
L["The Decor Browser is not available yet."] = "装饰浏览器尚不可用。"

-- Welcome window
L["Find every decor vendor on your map and see what you own before you buy."] = "在地图上找到每一位装饰商人，购买前先看看你已经拥有什么。"
L["What Homestead Does"] = "Homestead 的功能"
L["Every decor vendor pinned on your world map and minimap, with badges showing how many items you still need per zone."] = "每位装饰商人都会标记在你的世界地图和微缩地图上，并用徽章显示每个区域你还缺少多少件物品。"
L["Map Side Panel"] = "地图侧边面板"
L["Click the Homestead button on the world map to open the side panel listing that zone's vendors, then click any vendor to browse their wares and see what you still need. Pop it out as a standalone window with |cFF00FF00/hs panel|r."] = "点击世界地图上的 Homestead 按钮，打开列出该区域商人的侧边面板，再点击任意商人即可浏览其商品，并查看你还缺少什么。使用 |cFF00FF00/hs panel|r 可将其弹出为独立窗口。"
L["Tooltips Expanded"] = "增强说明条"
L["Every item in the Housing Catalog gets tooltips showing where it comes from (vendor, quest, achievement, profession, or drop), what it costs, and what you need to unlock it, so you never have to leave the game to look something up."] = "住宅装饰类别中的每件物品都会显示说明条，列出它的来源（商人、任务、成就、专业技能或掉落）、价格以及解锁所需条件，让你无需离开游戏去查询。"
L["Key Commands"] = "常用命令"
L["Export everything you've scanned"] = "导出你扫描到的全部内容"
L["Show all commands"] = "显示所有命令"
L["Found a Problem?"] = "发现问题？"
L["Report bugs or wrong vendor info on GitHub using the link below."] = "请通过下方链接在 GitHub 上报告错误或有误的商人信息。"
L["Report issues (GitHub):"] = "报告问题（GitHub）："
L["CurseForge:"] = "CurseForge:"
L["Don't show this again"] = "不再显示"
L["Let's Decorate!"] = "开始装饰吧！"

-------------------------------------------------------------------------------
-- Decor Browser: source and vendor labels
-------------------------------------------------------------------------------
L["Achievements"] = "成就"
L["Quests"] = "任务"
L["Professions"] = "专业技能"
L["Drops"] = "掉落"
L["Events"] = "事件"
L["Other"] = "其他"
L["Location not recorded"] = "未记录位置"
L["Requires"] = "需要"

-------------------------------------------------------------------------------
-- Decor Browser: states and shared parts
-------------------------------------------------------------------------------
L["Collected"] = "已收集"
L["Can get now"] = "现在可获得"
L["Requires: %s"] = "需要：%s"
L["%s only"] = "仅限%s"
L["Not collected"] = "未收集"
L["Counting…"] = "统计中…"
L["Not confirmed"] = "未确认"
L["Active now"] = "当前开放"
L["Best to get now"] = "现在最易获得"
L["Search decor"] = "搜索装饰"
L["More vendors here"] = "此处更多商人"
L["Reset filters"] = "重置筛选"
L["Search all decor"] = "搜索全部装饰"
L["Show what's missing"] = "显示缺少的"
L["Sort by name"] = "按名称排序"
L["Show them"] = "显示"
L["Show vendor"] = "显示商人"
L["Report a problem"] = "报告问题"
L["Reading your collection. This list fills in when it's ready."] = "正在读取你的收藏。准备好后，此列表会自动填充。"
L["Reading your collection. This list fills in when it's ready, because Best to get now depends on what you own."] = "正在读取你的收藏。准备好后，此列表会自动填充，因为现在最易获得的排序取决于你已拥有的物品。"
L["Nothing missing"] = "没有缺少的"
L["You've collected all %d decor Homestead knows about."] = "你已收集 Homestead 所知的全部 %d 件装饰。"
L["Nothing you can get right now"] = "目前没有可获得的"
L["Everything you're missing needs a reputation, achievement or quest first, is sold only during an event, or is sold only to the %s."] = "你缺少的物品都需要先满足声望、成就或任务要求，或只在活动期间出售，或只出售给%s。"
L["Everything you're missing needs a reputation, achievement or quest first, or is sold only during an event."] = "你缺少的物品都需要先满足声望、成就或任务要求，或只在活动期间出售。"
L["Collection not read yet"] = "尚未读取收藏"
L["Homestead hasn't read this character's decor collection yet, so it can't tell what you're missing. It reads it shortly after you log in. If this message stays, open the Housing Dashboard once."] = "Homestead 尚未读取此角色的装饰收藏，因此无法得知你缺少什么。它会在你登录后不久读取。若此消息一直存在，请打开一次住宅面板。"
L["These filters need your collection, which Homestead hasn't read yet. If this stays, open the Housing Dashboard once."] = "这些筛选需要你的收藏，但 Homestead 尚未读取。若一直如此，请打开一次住宅面板。"
L["No results"] = "没有结果"
L["No decor matches these words and filters. Search looks at item names only."] = "没有符合这些词语和筛选的装饰。搜索只查看物品名称。"
L["%d hidden by '%s' (%d collected, %d %s only)."] = "已隐藏 %d 项（'%s'）：已收集 %d 项，另有 %d 项仅限%s。"
L["%d hidden by '%s' (%d collected, %d %s only, %d %s only)."] = "已隐藏 %d 项（'%s'）：已收集 %d 项，另有 %d 项仅限%s，%d 项仅限%s。"
L["%d hidden by '%s' (%d collected)."] = "已隐藏 %d 项（'%s'）：已收集 %d 项。"
L["%s or the %s"] = "%s或%s"

-------------------------------------------------------------------------------
-- Decor Browser: Summary
-------------------------------------------------------------------------------
L["What can I get now?"] = "现在能获得什么？"
L["Decor this character can buy or earn today, best first."] = "此角色今天可以购买或赚取的装饰，最好的排在前面。"
L["Can get now means this character can buy or earn it today: the right faction, and no requirement left to meet. The closest ones come first. Use See all for the full list."] = "“现在可获得”表示此角色今天就能购买或赚取：阵营符合，且没有未满足的条件。最近的排在前面。使用“查看全部”可看完整列表。"
L["Show"] = "显示"
L["Not yet: next step"] = "尚不可得：下一步"
L["%s and %d more"] = "%s 等另外 %d 项"
L["See all you can get now (%d)"] = "查看现在可获得的全部装饰 (%d)"
L["Here in %s: %s sells %d decor you can get now."] = "此处 %s：%s 出售 %d 件现在可获得的装饰。"
L["Sold here in %s"] = "在 %s 出售"
L["Sold on %s"] = "在 %s 大陆出售"
L["%s: active now"] = "%s：当前开放"
L["Gold"] = "金币"
L["Gold only"] = "仅需金币"
L["Gold only, no requirements left"] = "仅需金币，已无其他条件"
L["No requirements left"] = "已无其他条件"
L["%d of %d"] = "%d / %d"
L["Reading your collection"] = "正在读取你的收藏"
-- end: Summary

-------------------------------------------------------------------------------
-- Decor Browser: Catalog
-------------------------------------------------------------------------------
L["All decor"] = "全部装饰"
L["Filters"] = "筛选"
L["Name"] = "名称"
L["Sort: %s"] = "排序：%s"
L["Furnishings"] = "家具"
L["Structural"] = "结构"
L["Accents"] = "点缀"
L["Lighting"] = "照明"
L["Neither collected nor not collected"] = "既非已收集也非未收集"
L["Sources: %s"] = "来源：%s"
L["Filtered: %s"] = "已筛选：%s"
L["(+%d more)"] = "(另外 %d 项)"
-- end: Catalog

-------------------------------------------------------------------------------
-- Decor Browser: Sources
-------------------------------------------------------------------------------
L["Search vendors and zones"] = "搜索商人和区域"
L["Search achievements"] = "搜索成就"
L["Search quests"] = "搜索任务"
L["Search recipes and professions"] = "搜索配方和专业技能"
L["Search drops and zones"] = "搜索掉落和区域"
L["Search events"] = "搜索事件"
L["Search the Shop"] = "搜索商城"
L["%d decor"] = "%d 件装饰"
L["No decor"] = "无装饰"
L["Not active"] = "未激活"
L["All collected"] = "已全部收集"
L["%d can get now"] = "现在可获得 %d 件"
L["Holiday event"] = "节日活动"
L["%s only: can't buy on this character"] = "仅限%s：此角色无法购买"
L["Confirmed by a scan on %s"] = "已于 %s 通过扫描确认"
L["No scan has confirmed this vendor yet. Visit the vendor to check."] = "尚无扫描确认过此商人。请前往拜访该商人进行确认。"
L["Decor from this source"] = "此来源的装饰"
L["No decor is recorded here. If this source gives decor, report it below."] = "此处没有已记录的装饰。如果此来源提供装饰，请在下方报告。"
L["Dig site in %s"] = "%s 的挖掘点"
L["No events active right now. Event decor is sold only while its event runs."] = "目前没有进行中的事件。事件装饰仅在事件期间出售。"
L["Nothing matches your search."] = "没有符合搜索的结果。"
L["Nothing to show here."] = "此处没有可显示的内容。"
L["Currency"] = "货币"
L["Wares"] = "商品"
L["Not confirmed: visit to check."] = "未确认：请前往查看。"
L["Corners: state top right, bonus top left, event bottom left, copies bottom right."] = "角标：右上为状态，左上为奖励，左下为活动，右下为拥有数量。"
L["%s; %s"] = "%s；%s"
L["%s · %s"] = "%s · %s"
-- end: Sources

-------------------------------------------------------------------------------
-- Decor Browser: Item
-------------------------------------------------------------------------------
L["Vendor:"] = "商人："
L["Achievement:"] = "成就："
L["Quest:"] = "任务："
L["Recipe:"] = "配方："
L["Drop:"] = "掉落："
L["Event:"] = "事件："
L["Starts in %s"] = "在%s开始"
L["Daily from The Last Architect"] = "来自The Last Architect的每日任务"
L["Can get now here"] = "现在可在此获得"
L["Where to get it"] = "获取方式"
L["Show achievement"] = "显示成就"
L["Show quest"] = "显示任务"
L["Show recipe"] = "显示配方"
L["Show drop"] = "显示掉落"
L["Show event"] = "显示事件"
L["%s (done)"] = "%s（已完成）"
L["%s (not yet)"] = "%s（尚未）"
L["Can't check this requirement yet"] = "暂时无法检查此要求"
L["Active now: %s"] = "当前活跃：%s"
L["Decor Browser"] = "装饰浏览器"
L["Show 3D preview"] = "显示3D预览"
L["desc_browser_model3d"] = "在装饰浏览器的物品页面上显示物品的3D模型。"
-- end: Item
