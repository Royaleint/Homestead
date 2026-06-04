--[[
    Homestead - Locale: Simplified Chinese (zhCN)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "zhCN" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
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
L["Filter"] = "过滤器"
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
-- Options
-------------------------------------------------------------------------------
L["General"] = "综合"
L["Overlays"] = "覆盖层"
L["Tooltips"] = "提示信息"
L["Export"] = "导出"

L["Show minimap button"] = "显示小地图按钮"
L["Enable overlays"] = "启用覆盖层"
L["Show on bags"] = "在背包中显示"
L["Show on bank"] = "在银行中显示"
L["Show on merchant"] = "在商人处显示"
L["Show on auction house"] = "在拍卖行中显示"
L["Show on housing catalog"] = "在家园目录中显示"
L["Icon size"] = "图标大小"
L["Icon position"] = "图标位置"
L["Show opposite faction vendors"] = "显示对立阵营商人"
L["Show unverified vendors"] = "显示未验证商人"

L["Enable tooltip additions"] = "启用提示信息增强"
L["Show source information"] = "显示来源信息"
L["Show quantity owned"] = "显示拥有数量"
L["Show dye slot information"] = "显示染色槽信息"
L["Show vendor details in tooltips"] = "在提示信息中显示商人详情"

L["Show map pins"] = "显示地图标记"
L["Show minimap pins"] = "显示小地图标记"
L["Use TomTom for waypoints"] = "使用TomTom导航"
L["Use native waypoints"] = "使用原生导航点"
L["Auto-create waypoint on click"] = "点击时自动创建导航点"
L["Navigate modifier key"] = "导航修饰键"

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d / %d (%d%%)"] = "收藏: %d / %d (%d%%)"
L["Vendors nearby: %d"] = "附近商人: %d"
L["Vendors scanned: %d"] = "已扫描商人: %d"
L["Left-Click: Toggle options"] = "|cFFFFFFFF左键点击:|r 打开选项"
L["Right-Click: Detach/close vendor panel"] = "|cFFFFFFFF右键点击:|r 分离/关闭商人面板"
L["Middle-Click: Scan collection"] = "|cFFFFFFFF中键点击:|r 扫描收藏"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "家园助手命令:"
L["/hs - Open options panel"] = "/hs — 打开选项面板"
L["/hs scan - Scan catalog"] = "/hs scan — 扫描目录"
L["/hs vendor [search] - Search vendors"] = "/hs vendor [搜索] — 搜索装饰商人"
L["/hs export - Show export dialog"] = "/hs export — 显示导出对话框"
L["/hs debug - Toggle debug mode"] = "/hs debug — 切换调试模式"
L["/hs help - Show this help"] = "/hs help — 显示此帮助"

-------------------------------------------------------------------------------
-- Slash Command Feedback
-------------------------------------------------------------------------------
L["Map pins refreshed."] = "地图标记已刷新。"
L["No active waypoint."] = "没有活动的导航点。"
L["Waypoint cleared."] = "导航点已清除。"
L["Vendor database contains %d vendors."] = "商人数据库包含 %d 个商人。"
L["Use /hs vendor <name or zone> to search."] = "使用 /hs vendor <名称或区域> 来搜索。"
L["No vendors found matching: %s"] = "未找到匹配的商人: %s"
L["Found %d vendor(s) matching: %s"] = "找到 %d 个匹配的商人: %s"
L["... and %d more."] = "... 还有 %d 个。"

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "调试模式: %s"
L["ON"] = "开"
L["OFF"] = "关"
L["Unknown command: %s"] = "未知命令: %s"
L["Not yet implemented"] = "尚未实现"

-------------------------------------------------------------------------------
-- Export Dialog
-------------------------------------------------------------------------------
L["Export Vendor Data"] = "导出商人数据"
L["Choose export option:"] = "选择导出选项:"
L["Export New Scans"] = "导出新扫描"
L["Export All"] = "导出全部"

-------------------------------------------------------------------------------
-- Map Side Panel
-------------------------------------------------------------------------------
L["All"] = "全部"
L["Vendor"] = "商人"
L["Quest"] = "任务"
L["Achievement"] = "成就"
L["Profession"] = "专业"
L["Event"] = "活动"
L["Drop"] = "掉落"
L["Zone Collection Progress"] = "区域收集进度"
L["Continent Collection Progress"] = "大陆收集进度"
L["Global Collection Progress"] = "全局收集进度"
L["Order Hall"] = "职业大厅"
L["Click to preview"] = "点击预览"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "输出"
L["Select All"] = "全选"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "已选中全部文本。按 Ctrl+C 复制到剪贴板。"

-------------------------------------------------------------------------------
-- Statistics
-------------------------------------------------------------------------------
L["Statistics"] = "统计"
L["Total Decor:"] = "装饰总数:"
L["Collected:"] = "已收集:"
L["Placed:"] = "已放置:"
L["Remaining:"] = "剩余:"
L["Collection Progress: %d%%"] = "收集进度: %d%%"
