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
L["Left-Click: Toggle Decor Browser"] = "|cFFFFFFFF左鍵點擊：|r開啟/關閉裝飾瀏覽器"
L["Right-Click: Open options"] = "|cFFFFFFFF右鍵點擊：|r開啟選項"

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
L["Catalog scan is on cooldown. Try again in a few seconds."] = "目錄掃描尚在冷卻中。請於幾秒後再試。"
L["A catalog scan is already in progress."] = "目錄掃描已在進行中。"

-------------------------------------------------------------------------------
-- Decor Browser: data adapter
-------------------------------------------------------------------------------
L["Unknown"] = "未知"
L["A vendor"] = "某位商人"
L["Required"] = "必要"
L["Unknown faction"] = "未知陣營"
L["Other requirement"] = "其他需求"
L["Source unknown"] = "來源未知"
L["Item %d"] = "物品%d"
L["%s %s"] = "%s %s"
L["%s, %s"] = "%s, %s"
L["%s: %s"] = "%s：%s"
L["%s with %s"] = "%s（%s聲望）"
L["Level %s"] = "等級%s"
L["Achievement: %s"] = "成就：%s"
L["Quest: %s"] = "任務：%s"
L["Promotion: %s"] = "促銷活動：%s"
L["Profession: %s"] = "專業技能：%s"
L["Profession: %s rank %s"] = "專業技能：%s，等級%s"
L["Vendor: %s"] = "商人：%s"
L["Vendor: %s, %s"] = "商人：%s，%s"
L["Crafted: %s - %s"] = "製作：%s - %s"
L["Drops from %s"] = "掉落自%s"
L["Drops from %s (%s)"] = "掉落自%s（%s）"
L["Event: %s"] = "事件：%s"
L["Event: %s - %s"] = "事件：%s - %s"
L["Other source"] = "其他來源"

-- Decor Browser: visuals and widgets
L["Set waypoint"] = "設定導航點"

-- Decor Browser: window and navigation
L["Homestead Decor"] = "Homestead 裝飾"
L["Overview"] = "總覽"
L["Catalog"] = "目錄"
L["Back"] = "返回"
L["Other Vendors"] = "其他商人"
L["%d of %d decor collected"] = "已收集裝飾 %d/%d"
L["%d of %d collected"] = "已收集 %d/%d"
L["Help"] = "說明"
L["Hide collected and other-faction"] = "隱藏已收集和對立陣營內容"
L["Hides decor you have collected, vendors with nothing left to collect, and anything only the other faction can get."] = "隱藏已收集的裝飾、已無可收集物品的商人，以及僅對立陣營可獲得的一切內容。"
L["Opens a page explaining this window."] = "開啟說明此視窗的頁面。"
L["The Decor Browser opens once Homestead has finished loading."] = "裝飾瀏覽器將在Homestead載入完成後開啟。"
L["Collection"] = "收藏"
L["Placed"] = "已擺放"
L["In storage"] = "儲存中"
L["Not yet redeemed"] = "尚未領取"
L["Counts not loaded yet"] = "數量尚未載入"
L["Source"] = "來源"
L["Price"] = "價格"

-- Decor Browser: shop and item pages
L["Seasonal: %s"] = "季節限定：%s"
L["Rotates with the %s Endeavor"] = "隨%s睦鄰活動輪替"
L["Rotates with neighborhood Endeavors"] = "隨社區睦鄰活動輪替"
L["Endeavor"] = "睦鄰活動"
L["Not available in combat"] = "戰鬥中無法使用"
L["Report a data error"] = "回報資料錯誤"
L["Item: %s (%d)"] = "物品：%s（%d）"
L["Record ID: %s"] = "紀錄ID：%s"
L["none"] = "無"
L["no location"] = "無位置"
L["map %d at %.1f, %.1f"] = "地圖%d，%.1f, %.1f"
L["Vendor %d: %s, %s, %s"] = "商人%d：%s，%s，%s"
L["Client: %s (%s)"] = "用戶端：%s（%s）"
L["Homestead: %s"] = "Homestead: %s"

-- Decor Browser: entry points
L["Toggle Decor Browser"] = "開啟/關閉裝飾瀏覽器"
L["Open the Decor Browser, or bind a key under Keybindings > Homestead"] = "開啟裝飾瀏覽器，也可以在「按鍵設定」> Homestead 中綁定按鍵"
L["Minimap button"] = "小地圖按鈕"
L["Left-click opens the Decor Browser, right-click opens options"] = "左鍵點擊開啟裝飾瀏覽器，右鍵點擊開啟選項"
L["The Decor Browser is not available yet."] = "裝飾瀏覽器尚無法使用。"

-- Welcome window
L["Find every decor vendor on your map and see what you own before you buy."] = "在地圖上找到每一位裝飾商人，購買前先看看你已經擁有什麼。"
L["What Homestead Does"] = "Homestead 的功能"
L["Every decor vendor pinned on your world map and minimap, with badges showing how many items you still need per zone."] = "每位裝飾商人都會標記在你的世界地圖和小地圖上，並以徽章顯示每個區域你還缺少多少件物品。"
L["Map Side Panel"] = "地圖側邊面板"
L["Click the Homestead button on the world map to open the side panel listing that zone's vendors, then click any vendor to browse their wares and see what you still need. Pop it out as a standalone window with |cFF00FF00/hs panel|r."] = "點擊世界地圖上的 Homestead 按鈕，開啟列出該區域商人的側邊面板，再點擊任一商人即可瀏覽其商品，並查看你還缺少什麼。使用 |cFF00FF00/hs panel|r 可將其彈出為獨立視窗。"
L["Tooltips Expanded"] = "強化提示資訊"
L["Every item in the Housing Catalog gets tooltips showing where it comes from (vendor, quest, achievement, profession, or drop), what it costs, and what you need to unlock it, so you never have to leave the game to look something up."] = "房屋目錄中的每件物品都會顯示提示資訊，列出它的來源（商人、任務、成就、專業技能或掉落）、價格以及解鎖所需條件，讓你無需離開遊戲去查詢。"
L["Key Commands"] = "常用指令"
L["Show all commands"] = "顯示所有指令"
L["Found a Problem?"] = "發現問題？"
L["Report bugs or wrong vendor info on GitHub using the link below."] = "請透過下方連結在 GitHub 上回報錯誤或有誤的商人資訊。"
L["Report issues (GitHub):"] = "回報問題（GitHub）："
L["CurseForge:"] = "CurseForge:"
L["Don't show this again"] = "不再顯示"
L["Let's Decorate!"] = "開始裝飾吧！"

-------------------------------------------------------------------------------
-- Decor Browser: source and vendor labels
-------------------------------------------------------------------------------
L["Achievements"] = "成就"
L["Quests"] = "任務"
L["Professions"] = "專業技能"
L["Drops"] = "掉落"
L["Events"] = "事件"
L["Other"] = "其他"
L["Location not recorded"] = "未記錄位置"
L["Requires"] = "需要"

-------------------------------------------------------------------------------
-- Decor Browser: states and shared parts
-------------------------------------------------------------------------------
L["Collected"] = "已收集"
L["Can get now"] = "現在可取得"
L["Requires: %s"] = "需要：%s"
L["Not enough: %s"] = "不足：%s"
L["(%1$s has %2$s)"] = "(%1$s 擁有 %2$s)"
L["Price not recorded"] = "未記錄價格"
L["%s only"] = "僅限%s"
L["Not collected"] = "未收集"
L["Counting…"] = "計算中…"
L["Not confirmed"] = "未確認"
L["Active now"] = "目前開放"
L["Best to get now"] = "現在最易取得"
L["Search decor"] = "搜尋裝飾"
L["More vendors here"] = "此處更多商人"
L["Reset filters"] = "重設篩選"
L["Search all decor"] = "搜尋全部裝飾"
L["Show what's missing"] = "顯示缺少的"
L["Sort by name"] = "依名稱排序"
L["Show them"] = "顯示"
L["Show vendor"] = "顯示商人"
L["Report a problem"] = "回報問題"
L["Reading your collection. This list fills in when it's ready."] = "正在讀取你的收藏。準備好後，此清單會自動填入。"
L["Reading your collection. This list fills in when it's ready, because Best to get now depends on what you own."] = "正在讀取你的收藏。準備好後，此清單會自動填入，因為現在最易取得的排序取決於你已擁有的物品。"
L["Nothing missing"] = "沒有缺少的"
L["You've collected all %d decor Homestead knows about."] = "你已收集 Homestead 所知的全部 %d 件裝飾。"
L["Nothing you can get right now"] = "目前沒有可取得的"
L["Everything you're missing needs a reputation, achievement or quest first, is sold only during an event, or is sold only to the %s."] = "你缺少的物品都需要先滿足聲望、成就或任務條件，或只在活動期間販售，或只賣給%s。"
L["Everything you're missing needs a reputation, achievement or quest first, or is sold only during an event."] = "你缺少的物品都需要先滿足聲望、成就或任務條件，或只在活動期間販售。"
L["Collection not read yet"] = "尚未讀取收藏"
L["Homestead hasn't read this character's decor collection yet, so it can't tell what you're missing. It reads it shortly after you log in. If this message stays, open the Housing Dashboard once."] = "Homestead 尚未讀取此角色的裝飾收藏，因此無法得知你缺少什麼。它會在你登入後不久讀取。若此訊息一直存在，請開啟一次房屋面板。"
L["These filters need your collection, which Homestead hasn't read yet. If this stays, open the Housing Dashboard once."] = "這些篩選需要你的收藏，但 Homestead 尚未讀取。若一直如此，請開啟一次房屋面板。"
L["No results"] = "沒有結果"
L["No decor matches these words and filters. Search looks at item names only."] = "沒有符合這些詞語和篩選的裝飾。搜尋只看物品名稱。"
L["%d hidden by '%s' (%d collected, %d %s only)."] = "已隱藏 %d 項（'%s'）：已收集 %d 項，另有 %d 項僅限%s。"
L["%d hidden by '%s' (%d collected, %d %s only, %d %s only)."] = "已隱藏 %d 項（'%s'）：已收集 %d 項，另有 %d 項僅限%s，%d 項僅限%s。"
L["%d hidden by '%s' (%d collected)."] = "已隱藏 %d 項（'%s'）：已收集 %d 項。"
L["%s or the %s"] = "%s或%s"

-------------------------------------------------------------------------------
-- Decor Browser: Summary
-------------------------------------------------------------------------------
L["What can I get now?"] = "現在能取得什麼？"
L["Decor this character can buy or earn today, best first."] = "此角色今天可以購買或賺取的裝飾，最好的排在前面。"
L["Can get now means this character can get it today: the right faction, no requirement left to meet, and enough gold or currency to pay. Gold-only and cheaper items come first. Use See all for the full list."] = "「現在可取得」表示此角色今天就能取得：陣營符合，沒有未滿足的條件，且有足夠的金幣或貨幣支付。僅需金幣和更便宜的排在前面。使用「查看全部」可看完整列表。"
L["Show"] = "顯示"
L["%s and %d more"] = "%s 等另外 %d 項"
L["See all you can get now (%d)"] = "查看現在可取得的全部裝飾 (%d)"
L["Here in %s: %s sells %d decor you can get now."] = "此處 %s：%s 出售 %d 件現在可取得的裝飾。"
L["Sold here in %s"] = "在 %s 出售"
L["Sold on %s"] = "在 %s 大陸出售"
L["%s: active now"] = "%s：目前開放"
L["Gold"] = "金幣"
L["Gold only"] = "僅需金幣"
L["Gold only, no requirements left"] = "僅需金幣，已無其他條件"
L["No requirements left"] = "已無其他條件"
L["%d of %d"] = "%d / %d"
L["Reading your collection"] = "正在讀取你的收藏"
-- end: Summary

-------------------------------------------------------------------------------
-- Decor Browser: Catalog
-------------------------------------------------------------------------------
L["All decor"] = "全部裝飾"
L["Filters"] = "篩選"
L["Name"] = "名稱"
L["Sort: %s"] = "排序：%s"
L["Furnishings"] = "家具"
L["Structural"] = "結構"
L["Accents"] = "點綴"
L["Lighting"] = "照明"
L["Neither collected nor not collected"] = "既非已收集也非未收集"
L["Sources: %s"] = "來源：%s"
L["Filtered: %s"] = "已篩選：%s"
L["(+%d more)"] = "(另外 %d 項)"
-- end: Catalog

-------------------------------------------------------------------------------
-- Decor Browser: Sources
-------------------------------------------------------------------------------
L["Search vendors and zones"] = "搜尋商人和區域"
L["Search achievements"] = "搜尋成就"
L["Search quests"] = "搜尋任務"
L["Search recipes and professions"] = "搜尋配方和專業技能"
L["Search drops and zones"] = "搜尋掉落和區域"
L["Search events"] = "搜尋事件"
L["Search the Shop"] = "搜尋商城"
L["%d decor"] = "%d 件裝飾"
L["No decor"] = "無裝飾"
L["Not active"] = "未啟用"
L["All collected"] = "已全部收集"
L["%d can get now"] = "現在可取得 %d 件"
L["Holiday event"] = "節日活動"
L["%s only: can't buy on this character"] = "僅限%s：此角色無法購買"
L["Confirmed by a scan on %s"] = "已於 %s 透過掃描確認"
L["No scan has confirmed this vendor yet. Visit the vendor to check."] = "尚無掃描確認過此商人。請前往拜訪該商人進行確認。"
L["Decor from this source"] = "此來源的裝飾"
L["No decor is recorded here. If this source gives decor, report it below."] = "此處沒有已記錄的裝飾。如果此來源提供裝飾，請在下方回報。"
L["Dig site in %s"] = "%s 的挖掘點"
L["No events active right now. Event decor is sold only while its event runs."] = "目前沒有進行中的事件。事件裝飾僅在事件期間販售。"
L["Nothing matches your search."] = "沒有符合搜尋的結果。"
L["Nothing to show here."] = "此處沒有可顯示的內容。"
L["Currency"] = "貨幣"
L["Wares"] = "商品"
L["Not confirmed: visit to check."] = "未確認：請前往查看。"
L["Corners: state top right, bonus top left, event bottom left, copies bottom right."] = "角標：右上為狀態，左上為獎勵，左下為活動，右下為擁有數量。"
L["%s; %s"] = "%s；%s"
L["%s · %s"] = "%s · %s"
-- end: Sources

-------------------------------------------------------------------------------
-- Decor Browser: Item
-------------------------------------------------------------------------------
L["Vendor:"] = "商人："
L["Achievement:"] = "成就："
L["Quest:"] = "任務："
L["Recipe:"] = "配方："
L["Drop:"] = "掉落："
L["Event:"] = "事件："
L["Starts in %s"] = "於%s開始"
L["Daily from The Last Architect"] = "來自The Last Architect的每日任務"
L["Can get now here"] = "現在可在此取得"
L["Where to get it"] = "取得方式"
L["Show achievement"] = "顯示成就"
L["Show quest"] = "顯示任務"
L["Show recipe"] = "顯示配方"
L["Show drop"] = "顯示掉落"
L["Show event"] = "顯示事件"
L["%s (done)"] = "%s（已完成）"
L["%s (not yet)"] = "%s（尚未）"
L["Can't check this requirement yet"] = "暫時無法檢查此條件"
L["Active now: %s"] = "目前啟用：%s"
L["Decor Browser"] = "裝飾瀏覽器"
L["Show 3D preview"] = "顯示3D預覽"
L["desc_browser_model3d"] = "在裝飾瀏覽器的物品頁面上顯示物品的3D模型。"
-- end: Item
