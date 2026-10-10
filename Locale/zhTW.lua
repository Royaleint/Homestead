--[[
    Homestead - Locale: Traditional Chinese (zhTW)
    Machine-translated, contributions welcome.
]]

local _, HA = ...

if GetLocale() ~= "zhTW" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["Used in %d known recipe for decor you haven't collected"] = "用於%d個已知配方，可製作你尚未收集的裝飾"
L["Used in %d known recipes for decor you haven't collected"] = "用於%d個已知配方，可製作你尚未收集的裝飾"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["Homestead"] = "Homestead"
L["Homestead Options"] = "Homestead 選項"
L["Overlays"] = "物品標記"
L["Tooltips"] = "提示資訊"
L["Export"] = "匯出"

L["Show minimap button"] = "顯示小地圖按鈕"
L["Enable overlays"] = "啟用物品標記"
L["Show on bags"] = "在背包中顯示"
L["Show on bank"] = "在銀行中顯示"
L["Show on merchant"] = "在商人視窗中顯示"
L["Show on housing catalog"] = "在房屋目錄中顯示"
L["Icon size"] = "圖示大小"
L["Icon position"] = "圖示位置"
L["Show opposite faction vendors"] = "顯示對立陣營商人"

L["Enable tooltip additions"] = "啟用提示資訊附加內容"
L["Show source information"] = "顯示來源資訊"
L["Show vendor details in tooltips"] = "在提示資訊中顯示商人詳情"

L["Show map pins"] = "顯示地圖圖示"
L["Show minimap pins"] = "顯示小地圖圖示"
L["Use TomTom for waypoints"] = "使用 TomTom 導航點"
L["Use native waypoints"] = "使用內建導航點"
L["Auto-create waypoint on click"] = "點擊時自動建立導航點"
L["Navigate modifier key"] = "導航組合鍵"

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d / %d (%d%%)"] = "收藏：%d / %d（%d%%）"
L["Vendors nearby: %d"] = "附近商人：%d"
L["Vendors scanned: %d"] = "已掃描商人：%d"
L["Left-Click: Toggle options"] = "|cFFFFFFFF左鍵點擊：|r開啟/關閉選項"
L["Right-Click: Detach/close vendor panel"] = "|cFFFFFFFF右鍵點擊：|r分離/關閉商人面板"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Homestead 指令："

-------------------------------------------------------------------------------
-- Slash Command Feedback
-------------------------------------------------------------------------------
L["Map pins refreshed."] = "地圖圖示已重新整理。"
L["No active waypoint."] = "目前沒有導航點。"
L["Waypoint cleared."] = "導航點已清除。"
L["Vendor database contains %d vendors."] = "商人資料庫共有%d個商人。"
L["Use /hs vendor <name or zone> to search."] = "輸入 /hs vendor <名稱或區域> 進行搜尋。"
L["No vendors found matching: %s"] = "找不到符合的商人：%s"
L["Found %d vendor(s) matching: %s"] = "找到%d個符合的商人：%s"
L["... and %d more."] = "...以及其他%d個。"

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "偵錯模式：%s"
L["ON"] = "已開啟"
L["OFF"] = "已關閉"
L["Unknown command: %s"] = "未知指令：%s"
L["Type /hs help for a list of commands."] = "輸入 /hs help 查看指令列表。"

-------------------------------------------------------------------------------
-- Version Check
-------------------------------------------------------------------------------
L["Your Homestead version is out-of-date."] = "你的 Homestead 版本已過期。"
L["Version %s (%s) can be downloaded at CurseForge, Wago, or GitHub Releases."] = "可在 CurseForge、Wago 或 GitHub Releases 下載版本 %s（%s）。"
L["Homestead version: %s (%s)"] = "Homestead 版本：%s（%s）"
L["Newest version seen this session: %s (%s)"] = "本次登入見到的最新版本：%s（%s）"
L["No newer version seen this session."] = "本次登入未見到更新的版本。"
L["Version-check notifications: %s"] = "版本檢查通知：%s"

-------------------------------------------------------------------------------
-- Export Dialog
-------------------------------------------------------------------------------
L["Export Vendor Data"] = "匯出商人資料"
L["Choose export option:"] = "選擇匯出方式："
L["Export New Scans"] = "匯出新掃描"
L["Export All"] = "全部匯出"

-------------------------------------------------------------------------------
-- Map Side Panel
-------------------------------------------------------------------------------
L["All"] = "全部"
L["Vendor"] = "商人"
L["Vendors"] = "商人"
L["Quest"] = "任務"
L["Achievement"] = "成就"
L["Profession"] = "專業技能"
L["Event"] = "事件"
L["Drop"] = "掉落"
L["Treasure"] = "寶藏"
L["Zone Collection Progress"] = "區域收藏進度"
L["Continent Collection Progress"] = "大陸收藏進度"
L["Global Collection Progress"] = "全世界收藏進度"
L["Order Hall"] = "職業大廳"
L["Click to preview"] = "點擊以預覽"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "輸出"
L["Select All"] = "全選"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "已選取所有文字。按下 Ctrl+C 即可複製到剪貼簿。"

-------------------------------------------------------------------------------
-- Options - Names
-------------------------------------------------------------------------------
L["Vendor pin item details"] = "商人圖示物品詳情"

L["Auto-scan vendors"] = "自動掃描商人"
L["Vendor Visibility"] = "商人顯示"
L["Show event vendors"] = "顯示事件商人"
L["Hide fully-collected vendor pins"] = "隱藏已收集完畢的商人圖示"
L["Fully-collected vendors"] = "已收集完畢的商人"
L["desc_map_filter_completed_vendors"] = "取消勾選即可隱藏你已收集全部裝飾的商人圖示。"
L["Pin Appearance"] = "圖示外觀"
L["Pin color"] = "圖示顏色"
L["Custom color"] = "自訂顏色"
L["Show accessibility glow"] = "顯示輔助辨識光暈"
L["Owned item style"] = "已擁有物品樣式"
L["Show ownership status"] = "顯示擁有狀態"
L["Show requirements"] = "顯示需求"
L["Show all sources"] = "顯示所有來源"
L["Map Pins"] = "地圖圖示"
L["Show vendor panel on world map"] = "在世界地圖上顯示商人面板"
L["Vendor panel source filter"] = "商人面板來源篩選"
L["Integrate with map frame border"] = "與地圖框架邊框整合"
L["Zone badges on world map"] = "世界地圖區域徽章"
L["World map pin size"] = "世界地圖圖示大小"
L["Show collection counts"] = "顯示收藏數量"
L["Show elevation arrows"] = "顯示高度箭頭"
L["Minimap nearby-zone pins"] = "小地圖鄰近區域圖示"
L["Minimap pin size"] = "小地圖圖示大小"
L["Waypoints"] = "導航點"
L["Show milestone progress on dashboard"] = "在房屋資訊看板顯示里程碑進度"
L["Inventory"] = "物品欄"
L["Merchant"] = "商人視窗"
L["Housing Catalog"] = "房屋目錄"

-------------------------------------------------------------------------------
-- Options - Descriptions
-------------------------------------------------------------------------------
L["desc_minimap_button"] = "顯示或隱藏小地圖按鈕"
L["desc_auto_scan_vendors"] = "拜訪商人時，自動掃描商人販售的物品以取得房屋裝飾資料。停用可略微提升開啟商人視窗時的效能。"
L["desc_options_general"] = "插件核心行為、小地圖按鈕、商人掃描與地圖圖示外觀。"
L["desc_options_overlays"] = "顯示在背包、銀行、商人和房屋目錄中的收藏標記。"
L["desc_options_tooltips"] = "在物品與地圖圖示的提示資訊中加入擁有狀態、來源、需求和商人詳情。"
L["desc_options_world_map"] = "世界地圖的商人圖示、區域徽章、側邊面板行為與地圖圖示顯示。"
L["desc_options_minimap"] = "小地圖上的附近商人圖示、高度箭頭與導航點行為。"
L["desc_options_endeavors"] = "在暴雪的房屋資訊看板上顯示房屋睦鄰活動進度。"
L["desc_options_export"] = "匯出已掃描的商人資料，以供檢閱或備份。"
L["desc_vendor_visibility_section"] = "選擇哪些商人群組會出現在地圖上並計入收藏總數。"
L["desc_pin_appearance_section"] = "調整 Homestead 商人圖示的顏色與預覽。"
L["desc_overlay_inventory_section"] = "在房屋目錄以外的物品欄位上顯示收藏標記。"
L["desc_overlay_merchant_section"] = "瀏覽商人物品時標示已收集的裝飾。"
L["desc_overlay_catalog_section"] = "控制房屋目錄的標記、醒目提示與已收集物品樣式。"
L["desc_tooltip_map_pins_section"] = "選擇地圖圖示提示資訊中顯示多少商人詳情。"
L["desc_minimap_waypoints_section"] = "設定點擊地圖與商人時 TomTom 和內建導航點的行為。"
L["desc_opposite_faction"] = "顯示對立陣營的商人並附上其陣營徽記。適合想看到所有可用商人的收集玩家。"
L["desc_event_vendors"] = "節慶事件進行時，在地圖上顯示季節性節慶商人圖示（例如：新年慶典）"
L["desc_hide_completed_vendor_pins"] = "在地圖與小地圖上隱藏你已收集其全部房屋裝飾的商人圖示。商人面板列表不受影響。"
L["desc_pin_color"] = "選擇地圖與小地圖圖示的顏色。"
L["desc_custom_color"] = "為地圖圖示挑選自訂基礎顏色"
L["desc_enable_overlays"] = "在遊戲各處的裝飾物品上加入小圖示與醒目提示，讓你一眼看出哪些已收集。關閉後將隱藏所有 Homestead 標記。"
L["desc_icon_size"] = "控制物品欄位上收藏圖示的大小。"
L["desc_icon_position"] = "收藏圖示位於物品欄位的哪個角落。"
L["desc_show_on_bags"] = "在你背包中的裝飾物品上加入 |A:homestone-minimap-icon:16:16|a，並以顏色顯示每件是否已收集。支援預設背包、Baganator 和 BetterBags。"
L["desc_show_on_bank"] = "標示你銀行中的裝飾物品，讓你看出哪些已收集。"
L["desc_show_on_merchant"] = "在商人販售的裝飾物品上加入 |A:homestone-minimap-icon:16:16|a，並以顏色顯示每件是否已收集。"
L["desc_show_on_housing_catalog"] = "在房屋目錄中以收藏圖示標示物品，顯示每件物品的來源。\n\n|A:auctionhouse-icon-coin-gold:16:16|a 商人\n|A:QuestNormal:16:16|a 任務\n|A:UI-Achievement-Shield-NoPoints:16:16|a 成就\n|A:UI-HUD-MicroMenu-Professions-Mouseover:16:16|a 專業技能\n|A:UI-HUD-Calendar-1-Up:16:16|a 事件\n|A:Crosshair_lootall_64:16:16|a 掉落\n|A:hearthsteel-icon-32x32:16:16|a Battle.net 遊戲商城"
L["desc_accessibility_glow"] = "為房屋目錄物品加上彩色邊框光暈：綠色代表已擁有，黃色代表可以取得，紅色代表因尚未達成需求而鎖定。"
L["desc_owned_item_style"] = "選擇已收集物品在房屋目錄中的外觀。綠色醒目提示會顯示預設光暈，變暗會使其淡化，勾選標記會加上綠色小勾號。選擇無則保持原樣。"
L["desc_enable_tooltips"] = "滑鼠指向裝飾物品時，在物品提示資訊中加入 Homestead 資訊。關閉後將移除所有提示資訊附加內容。"
L["desc_show_ownership"] = "在提示資訊中加入一行，顯示你是否已收集此裝飾物品。"
L["desc_show_source"] = "顯示裝飾物品的取得方式：商人、任務、成就、專業技能、事件和掉落。"
L["desc_show_requirements"] = "顯示購買物品的需求，例如所需的聲望、完成的任務或成就。"
L["desc_show_all_sources"] = "列出物品所有已知的取得方式，而非只顯示最佳來源。適用於可從多個商人、任務或其他來源取得的物品。"
L["desc_vendor_details"] = "滑鼠指向商人的地圖圖示時，顯示其完整販售物品與你的收藏進度。停用則改為只顯示商人名稱的簡易提示資訊。"
L["desc_vendor_pin_item_details"] = "在地圖圖示的提示資訊中顯示每件物品的其他來源圖示與商人售價，以及僅限商人販售的物品數量。停用則改為只列出物品名稱的簡易提示資訊。"
L["desc_show_map_pins"] = "在世界地圖上顯示商人位置"
L["desc_show_map_side_panel"] = "在世界地圖旁顯示側邊面板，列出目前區域的商人與收藏進度"
L["desc_source_filter"] = "依取得來源篩選側邊面板的物品數量與展開的物品格。地圖上的商人顯示不受影響。"
L["desc_integrate_map_border"] = "將面板的上邊框與世界地圖邊框合併，呈現無縫外觀。若你使用會產生衝突的自訂介面（ElvUI、GW2 等），請停用此選項。"
L["desc_zone_badges"] = "在世界地圖的大陸上分別顯示各區域的商人數量，而非每個大陸只顯示單一總數。"
L["desc_world_pin_size"] = "調整世界地圖上商人圖示的大小。預設值（20）與暴雪的地標圖示相同。"
L["desc_show_pin_counts"] = "在商人圖示上顯示已收集/總數的物品數量（例如：3/12）。停用可讓地圖更簡潔。"
L["desc_show_minimap_pins"] = "在小地圖上顯示商人位置並附上高度箭頭"
L["desc_elevation_arrows"] = "當商人位於你的上方或下方時，在小地圖圖示上顯示方向箭頭"
L["desc_cross_zone_mode"] = "控制跨區域的小地圖圖示。自動模式會在擁擠的城市區域減少額外圖示，讓移動更流暢。"
L["desc_minimap_pin_size"] = "調整小地圖上商人圖示的大小。圖示不易看清時可調大，或調小以讓小地圖更簡潔。"
L["desc_waypoint_info"] = "TomTom 會顯示方向箭頭，需安裝 TomTom 插件。內建方式會在世界地圖上加入目的地標記。兩者可同時啟用。"
L["desc_use_tomtom"] = "使用 TomTom 插件顯示導航點箭頭（若已安裝）"
L["desc_use_native_waypoints"] = "使用魔獸世界內建的導航點系統與地圖標記"
L["desc_auto_waypoint"] = "點擊列表或地圖上的商人時，自動建立導航點"
L["desc_navigate_modifier"] = "點擊時按住此鍵以建立導航點（自動導航點關閉時）"
L["desc_milestone_xp"] = "在暴雪房屋資訊看板的睦鄰活動分頁顯示下一個里程碑的經驗值進度。若你使用其他插件處理此功能（例如 Endeavor Simple Progress Tracker），請停用此選項。"
L["desc_export"] = "匯出已掃描的商人資料以供備份。"
L["desc_export_new"] = "匯出自上次匯出後掃描的商人。包含價格、貨幣、陣營與目錄資訊。"
L["desc_export_all"] = "匯出所有已掃描的商人，略過時間戳記篩選。"

-------------------------------------------------------------------------------
-- Options - Select Values
-------------------------------------------------------------------------------
-- Pin colors
L["Default (Gold)"] = "預設（金色）"
L["Bright Green"] = "亮綠色"
L["Ice Blue"] = "冰藍色"
L["Light Blue"] = "淺藍色"
L["Purple"] = "紫色"
L["Pink"] = "粉紅色"
L["Red"] = "紅色"
L["Cyan"] = "青色"
L["White"] = "白色"
L["Yellow"] = "黃色"
L["Custom..."] = "自訂..."

-- Icon anchor positions
L["Top Left"] = "左上"
L["Top Right"] = "右上"
L["Bottom Left"] = "左下"
L["Bottom Right"] = "右下"
L["Center"] = "中央"

-- Owned item styles
L["Green highlight (default)"] = "綠色醒目提示（預設）"
L["None"] = "無"
L["Dimmed"] = "變暗"
L["Checkmark"] = "勾選標記"

-- Source filter
L["All sources"] = "所有來源"

-- Minimap cross-zone mode
L["Auto (recommended)"] = "自動（建議）"
L["Current zone only"] = "僅限目前區域"
L["Always show nearby zones"] = "總是顯示鄰近區域"

-- Navigate modifier
L["None (always)"] = "無（每次點擊）"

-- Misc
L["Approximate map appearance"] = "地圖上的大致外觀"
L["ExportImport not available."] = "ExportImport 無法使用。"
