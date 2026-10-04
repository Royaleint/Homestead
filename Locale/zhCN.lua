--[[
    Homestead - Locale: Simplified Chinese (zhCN)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "zhCN" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- UI Labels
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["Overlays"] = "覆盖层"
L["Tooltips"] = "提示信息"
L["Export"] = "导出"

L["Show minimap button"] = "显示小地图按钮"
L["Enable overlays"] = "启用覆盖层"
L["Show on bags"] = "在背包中显示"
L["Show on bank"] = "在银行中显示"
L["Show on merchant"] = "在商人处显示"
L["Show on housing catalog"] = "在家园目录中显示"
L["Icon size"] = "图标大小"
L["Icon position"] = "图标位置"
L["Show opposite faction vendors"] = "显示对立阵营商人"

L["Enable tooltip additions"] = "启用提示信息增强"
L["Show source information"] = "显示来源信息"
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

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "家园助手命令:"

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

