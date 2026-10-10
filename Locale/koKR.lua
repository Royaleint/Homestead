--[[
    Homestead - Locale: Korean (KR)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "koKR" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["Used in %d known recipe for decor you haven't collected"] = "획득하지 않은 하우징 장식의 알려진 제조법 %d개에 사용됨"
L["Used in %d known recipes for decor you haven't collected"] = "획득하지 않은 하우징 장식의 알려진 제조법 %d개에 사용됨"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["Homestead"] = "Homestead"
L["Homestead Options"] = "Homestead 설정"
L["Overlays"] = "오버레이"
L["Tooltips"] = "툴팁"
L["Export"] = "내보내기"

L["Show minimap button"] = "미니맵 버튼 표시"
L["Enable overlays"] = "오버레이 사용"
L["Show on bags"] = "가방에 표시"
L["Show on bank"] = "은행에 표시"
L["Show on merchant"] = "상인 창에 표시"
L["Show on housing catalog"] = "하우징 분류 목록에 표시"
L["Icon size"] = "아이콘 크기"
L["Icon position"] = "아이콘 위치"
L["Show opposite faction vendors"] = "상대 진영 상인 표시"

L["Enable tooltip additions"] = "툴팁 추가 정보 사용"
L["Show source information"] = "획득 방법 정보 표시"
L["Show vendor details in tooltips"] = "툴팁에 상인 세부 정보 표시"

L["Show map pins"] = "지도 핀 표시"
L["Show minimap pins"] = "미니맵 핀 표시"
L["Use TomTom for waypoints"] = "웨이포인트에 TomTom 사용"
L["Use native waypoints"] = "기본 웨이포인트 사용"
L["Auto-create waypoint on click"] = "클릭 시 웨이포인트 자동 생성"
L["Navigate modifier key"] = "길 안내 보조 키"

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d / %d (%d%%)"] = "수집품: %d / %d (%d%%)"
L["Vendors nearby: %d"] = "근처 상인: %d"
L["Vendors scanned: %d"] = "스캔한 상인: %d"
L["Left-Click: Toggle options"] = "|cFFFFFFFF왼쪽 클릭:|r 설정 창 열기/닫기"
L["Right-Click: Detach/close vendor panel"] = "|cFFFFFFFF오른쪽 클릭:|r 상인 패널 분리/닫기"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Homestead 명령어:"

-------------------------------------------------------------------------------
-- Slash Command Feedback
-------------------------------------------------------------------------------
L["Map pins refreshed."] = "지도 핀을 새로 고쳤습니다."
L["No active waypoint."] = "활성화된 웨이포인트가 없습니다."
L["Waypoint cleared."] = "웨이포인트를 삭제했습니다."
L["Vendor database contains %d vendors."] = "상인 데이터베이스에 상인이 %d명 있습니다."
L["Use /hs vendor <name or zone> to search."] = "검색하려면 /hs vendor <이름 또는 지역>을 입력하십시오."
L["No vendors found matching: %s"] = "일치하는 상인이 없습니다: %s"
L["Found %d vendor(s) matching: %s"] = "일치하는 상인 %d명: %s"
L["... and %d more."] = "... 외 %d명."

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "디버그 모드: %s"
L["ON"] = "켜짐"
L["OFF"] = "꺼짐"
L["Unknown command: %s"] = "알 수 없는 명령어: %s"
L["Type /hs help for a list of commands."] = "명령어 목록을 보려면 /hs help를 입력하십시오."

-------------------------------------------------------------------------------
-- Version Check
-------------------------------------------------------------------------------
L["Your Homestead version is out-of-date."] = "사용 중인 Homestead가 구버전입니다."
L["Version %s (%s) can be downloaded at CurseForge, Wago, or GitHub Releases."] = "%s (%s) 버전은 CurseForge, Wago 또는 GitHub Releases에서 내려받을 수 있습니다."
L["Homestead version: %s (%s)"] = "Homestead 버전: %s (%s)"
L["Newest version seen this session: %s (%s)"] = "이번 접속 중 확인된 최신 버전: %s (%s)"
L["No newer version seen this session."] = "이번 접속 중 확인된 새 버전이 없습니다."
L["Version-check notifications: %s"] = "버전 확인 알림: %s"

-------------------------------------------------------------------------------
-- Export Dialog
-------------------------------------------------------------------------------
L["Export Vendor Data"] = "상인 데이터 내보내기"
L["Choose export option:"] = "내보내기 방식 선택:"
L["Export New Scans"] = "새 스캔 내보내기"
L["Export All"] = "모두 내보내기"

-------------------------------------------------------------------------------
-- Map Side Panel
-------------------------------------------------------------------------------
L["All"] = "전체"
L["Vendor"] = "상인"
L["Vendors"] = "상인"
L["Quest"] = "퀘스트"
L["Achievement"] = "업적"
L["Profession"] = "전문 기술"
L["Event"] = "이벤트"
L["Drop"] = "전리품"
L["Treasure"] = "보물"
L["Zone Collection Progress"] = "지역 수집품 진행도"
L["Continent Collection Progress"] = "대륙 수집품 진행도"
L["Global Collection Progress"] = "전체 수집품 진행도"
L["Order Hall"] = "직업 전당"
L["Click to preview"] = "클릭하여 미리 보기"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "출력"
L["Select All"] = "모두 선택"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "모든 텍스트를 선택했습니다. Ctrl+C를 눌러 클립보드에 복사하십시오."

-------------------------------------------------------------------------------
-- Options - Names
-------------------------------------------------------------------------------
L["Vendor pin item details"] = "상인 핀 아이템 세부 정보"

L["Auto-scan vendors"] = "상인 자동 스캔"
L["Vendor Visibility"] = "상인 표시"
L["Show event vendors"] = "이벤트 상인 표시"
L["Hide fully-collected vendor pins"] = "모두 획득한 상인 핀 숨기기"
L["Fully-collected vendors"] = "모두 획득한 상인"
L["desc_map_filter_completed_vendors"] = "선택을 해제하면 하우징 장식을 모두 획득한 상인의 핀을 숨깁니다."
L["Pin Appearance"] = "핀 모양"
L["Pin color"] = "핀 색상"
L["Custom color"] = "사용자 지정 색상"
L["Show accessibility glow"] = "접근성 강조 효과 표시"
L["Owned item style"] = "보유 아이템 스타일"
L["Show ownership status"] = "보유 상태 표시"
L["Show requirements"] = "요구 사항 표시"
L["Show all sources"] = "모든 획득 방법 표시"
L["Map Pins"] = "지도 핀"
L["Show vendor panel on world map"] = "세계 지도에 상인 패널 표시"
L["Vendor panel source filter"] = "상인 패널 획득 방법 필터"
L["Integrate with map frame border"] = "지도 창 테두리와 통합"
L["Zone badges on world map"] = "세계 지도에 지역 배지 표시"
L["World map pin size"] = "세계 지도 핀 크기"
L["Show collection counts"] = "수집품 개수 표시"
L["Show elevation arrows"] = "높이 화살표 표시"
L["Minimap nearby-zone pins"] = "미니맵 인접 지역 핀"
L["Minimap pin size"] = "미니맵 핀 크기"
L["Waypoints"] = "웨이포인트"
L["Show milestone progress on dashboard"] = "하우징 대시보드에 이정표 진행도 표시"
L["Inventory"] = "소지품"
L["Merchant"] = "상인 창"
L["Housing Catalog"] = "하우징 분류 목록"

-------------------------------------------------------------------------------
-- Options - Descriptions
-------------------------------------------------------------------------------
L["desc_minimap_button"] = "미니맵 버튼을 표시하거나 숨깁니다."
L["desc_auto_scan_vendors"] = "상인을 방문하면 상품 목록에서 하우징 장식 정보를 자동으로 스캔합니다. 끄면 상인 창을 열 때 성능이 약간 향상될 수 있습니다."
L["desc_options_general"] = "애드온 기본 동작, 미니맵 버튼, 상인 스캔, 지도 핀 모양 설정입니다."
L["desc_options_overlays"] = "가방, 은행, 상인 창, 하우징 분류 목록에 나타나는 수집품 표식입니다."
L["desc_options_tooltips"] = "아이템 및 지도 핀 툴팁에 추가되는 보유 상태, 획득 방법, 요구 사항, 상인 세부 정보입니다."
L["desc_options_world_map"] = "세계 지도의 상인 핀, 지역 배지, 측면 패널 동작, 지도 핀 표시 방식입니다."
L["desc_options_minimap"] = "미니맵의 근처 상인 핀, 높이 화살표, 웨이포인트 동작입니다."
L["desc_options_endeavors"] = "블리자드 하우징 대시보드에 표시되는 하우징 교류회 진행도입니다."
L["desc_options_export"] = "검토나 백업을 위해 스캔한 상인 데이터를 내보냅니다."
L["desc_vendor_visibility_section"] = "지도와 수집품 합계에 포함할 상인 그룹을 선택합니다."
L["desc_pin_appearance_section"] = "Homestead 상인 핀의 색상과 미리 보기를 조정합니다."
L["desc_overlay_inventory_section"] = "하우징 분류 목록 밖의 아이템 칸에 수집품 표식을 표시합니다."
L["desc_overlay_merchant_section"] = "상인의 아이템을 둘러볼 때 획득한 하우징 장식을 표시합니다."
L["desc_overlay_catalog_section"] = "하우징 분류 목록의 표식, 강조 효과, 획득한 아이템 스타일을 설정합니다."
L["desc_tooltip_map_pins_section"] = "지도 핀 툴팁에 표시할 상인 정보의 양을 선택합니다."
L["desc_minimap_waypoints_section"] = "지도와 상인 클릭 시의 TomTom 및 기본 웨이포인트 동작을 설정합니다."
L["desc_opposite_faction"] = "상대 진영의 상인을 진영 문장과 함께 표시합니다. 이용 가능한 모든 상인을 확인하려는 수집가에게 유용합니다."
L["desc_event_vendors"] = "축제 이벤트가 진행 중일 때 해당 축제 상인 핀을 지도에 표시합니다 (예: 달의 축제)"
L["desc_hide_completed_vendor_pins"] = "하우징 장식을 모두 획득한 상인의 지도 및 미니맵 핀을 숨깁니다. 상인 패널 목록에는 영향을 주지 않습니다."
L["desc_pin_color"] = "지도 및 미니맵 핀의 색상을 선택합니다."
L["desc_custom_color"] = "지도 핀의 기본 색상을 직접 선택합니다"
L["desc_enable_overlays"] = "게임 곳곳의 하우징 장식 아이템에 작은 아이콘과 강조 효과를 추가하여 어떤 아이템을 획득했는지 한눈에 알 수 있게 합니다. 끄면 모든 Homestead 오버레이가 숨겨집니다."
L["desc_icon_size"] = "아이템 칸에 표시되는 수집품 아이콘의 크기를 조절합니다."
L["desc_icon_position"] = "수집품 아이콘이 놓일 아이템 칸의 모서리를 선택합니다."
L["desc_show_on_bags"] = "가방 속 하우징 장식 아이템에 |A:homestone-minimap-icon:16:16|a 아이콘을 추가하며, 색상으로 각 아이템의 획득 여부를 보여 줍니다. 기본 가방, Baganator, BetterBags와 호환됩니다."
L["desc_show_on_bank"] = "은행에 있는 하우징 장식 아이템을 표시하여 이미 획득한 아이템을 확인할 수 있게 합니다."
L["desc_show_on_merchant"] = "상인이 판매하는 하우징 장식 아이템에 |A:homestone-minimap-icon:16:16|a 아이콘을 추가하며, 색상으로 각 아이템의 획득 여부를 보여 줍니다."
L["desc_show_on_housing_catalog"] = "하우징 분류 목록의 아이템에 각 아이템을 얻는 방법을 알려 주는 수집품 아이콘을 표시합니다.\n\n|A:auctionhouse-icon-coin-gold:16:16|a 상인\n|A:QuestNormal:16:16|a 퀘스트\n|A:UI-Achievement-Shield-NoPoints:16:16|a 업적\n|A:UI-HUD-MicroMenu-Professions-Mouseover:16:16|a 전문 기술\n|A:UI-HUD-Calendar-1-Up:16:16|a 이벤트\n|A:Crosshair_lootall_64:16:16|a 전리품\n|A:hearthsteel-icon-32x32:16:16|a 블리자드 샵"
L["desc_accessibility_glow"] = "하우징 분류 목록 아이템에 색깔 테두리 빛을 추가합니다. 보유한 아이템은 녹색, 얻을 수 있는 아이템은 노란색, 아직 충족하지 못한 요구 사항 때문에 잠긴 아이템은 빨간색입니다."
L["desc_owned_item_style"] = "하우징 분류 목록에서 획득한 아이템의 모양을 선택합니다. '녹색 강조'는 기본 빛 효과를 표시하고, '흐리게'는 아이템을 흐리게 만들며, '확인 표시'는 작은 녹색 확인 표시를 추가합니다. 그대로 두려면 '없음'을 선택하십시오."
L["desc_enable_tooltips"] = "하우징 장식 아이템에 마우스를 올리면 아이템 툴팁에 Homestead 정보를 추가합니다. 끄면 모든 툴팁 추가 정보가 제거됩니다."
L["desc_show_ownership"] = "하우징 장식 아이템을 이미 획득했는지 알려 주는 줄을 툴팁에 추가합니다."
L["desc_show_source"] = "하우징 장식 아이템을 얻는 방법을 표시합니다: 상인, 퀘스트, 업적, 전문 기술, 이벤트, 전리품."
L["desc_show_requirements"] = "아이템 구매에 필요한 평판, 퀘스트 완료, 업적 등의 구매 요구 사항을 표시합니다."
L["desc_show_all_sources"] = "가장 좋은 획득 방법 하나만이 아니라 알려진 모든 획득 방법을 나열합니다. 여러 상인, 퀘스트 또는 기타 방법으로 얻을 수 있는 아이템에 유용합니다."
L["desc_vendor_details"] = "상인의 지도 핀에 마우스를 올리면 전체 상품 목록과 수집품 진행도를 표시합니다. 끄면 상인 이름만 있는 간단한 툴팁이 표시됩니다."
L["desc_vendor_pin_item_details"] = "지도 핀 툴팁에 각 아이템의 다른 획득 방법 아이콘과 상인 판매 가격, 상인 전용 아이템 개수를 표시합니다. 끄면 아이템 이름만 나열하는 간단한 툴팁이 표시됩니다."
L["desc_show_map_pins"] = "세계 지도에 상인 위치를 표시합니다"
L["desc_show_map_side_panel"] = "세계 지도에 현재 지역의 상인 목록과 수집품 진행도를 보여 주는 측면 패널을 표시합니다"
L["desc_source_filter"] = "측면 패널의 아이템 개수와 펼친 목록을 획득 방법별로 필터링합니다. 지도의 상인 표시에는 영향을 주지 않습니다."
L["desc_integrate_map_border"] = "패널 상단 테두리를 세계 지도 테두리와 합쳐 자연스럽게 보이게 합니다. 충돌하는 사용자 UI(ElvUI, GW2 등)를 사용한다면 끄십시오."
L["desc_zone_badges"] = "세계 지도에서 대륙별 합계 하나 대신 대륙 곳곳에 지역별 상인 수를 표시합니다."
L["desc_world_pin_size"] = "세계 지도의 상인 핀 크기를 조정합니다. 기본값(20)은 블리자드 관심 지점 아이콘과 같은 크기입니다."
L["desc_show_pin_counts"] = "상인 핀에 획득한 아이템 수/전체 아이템 수를 표시합니다 (예: 3/12). 끄면 지도가 덜 복잡해집니다."
L["desc_show_minimap_pins"] = "미니맵에 상인 위치를 높이 화살표와 함께 표시합니다"
L["desc_elevation_arrows"] = "상인이 자신보다 위나 아래에 있을 때 미니맵 핀에 방향 화살표를 표시합니다"
L["desc_cross_zone_mode"] = "미니맵의 다른 지역 핀 표시 방식을 설정합니다. 자동은 복잡한 도시 지역에서 추가 핀을 줄여 움직임을 부드럽게 합니다."
L["desc_minimap_pin_size"] = "미니맵의 상인 핀 크기를 조정합니다. 핀이 잘 보이지 않으면 키우고, 미니맵을 덜 복잡하게 하려면 줄이십시오."
L["desc_waypoint_info"] = "TomTom은 화면에 방향 화살표를 표시하며 TomTom 애드온이 설치되어 있어야 합니다. 기본 방식은 세계 지도에 목적지 핀을 추가합니다. 두 방식을 동시에 사용할 수 있습니다."
L["desc_use_tomtom"] = "웨이포인트 화살표에 TomTom 애드온을 사용합니다 (설치된 경우)"
L["desc_use_native_waypoints"] = "WoW 기본 웨이포인트 시스템과 지도 핀을 사용합니다"
L["desc_auto_waypoint"] = "목록이나 지도에서 상인을 클릭하면 자동으로 웨이포인트를 생성합니다"
L["desc_navigate_modifier"] = "이 키를 누른 채 클릭하면 웨이포인트를 생성합니다 (자동 웨이포인트가 꺼져 있을 때)"
L["desc_milestone_xp"] = "블리자드 하우징 대시보드의 교류회 탭에 다음 이정표까지의 경험치 진행도를 표시합니다. 이 기능에 다른 애드온을 사용한다면 끄십시오 (예: Endeavor Simple Progress Tracker)."
L["desc_export"] = "백업용으로 스캔한 상인 데이터를 내보냅니다."
L["desc_export_new"] = "마지막 내보내기 이후 스캔한 상인을 내보냅니다. 가격, 재화, 진영, 분류 목록 정보가 포함됩니다."
L["desc_export_all"] = "시간 기록 필터를 무시하고 스캔한 모든 상인을 내보냅니다."

-------------------------------------------------------------------------------
-- Options - Select Values
-------------------------------------------------------------------------------
-- Pin colors
L["Default (Gold)"] = "기본 (금색)"
L["Bright Green"] = "밝은 녹색"
L["Ice Blue"] = "얼음빛 파란색"
L["Light Blue"] = "하늘색"
L["Purple"] = "보라색"
L["Pink"] = "분홍색"
L["Red"] = "빨간색"
L["Cyan"] = "청록색"
L["White"] = "흰색"
L["Yellow"] = "노란색"
L["Custom..."] = "사용자 지정..."

-- Icon anchor positions
L["Top Left"] = "왼쪽 위"
L["Top Right"] = "오른쪽 위"
L["Bottom Left"] = "왼쪽 아래"
L["Bottom Right"] = "오른쪽 아래"
L["Center"] = "가운데"

-- Owned item styles
L["Green highlight (default)"] = "녹색 강조 (기본)"
L["None"] = "없음"
L["Dimmed"] = "흐리게"
L["Checkmark"] = "확인 표시"

-- Source filter
L["All sources"] = "모든 획득 방법"

-- Minimap cross-zone mode
L["Auto (recommended)"] = "자동 (권장)"
L["Current zone only"] = "현재 지역만"
L["Always show nearby zones"] = "인접 지역 항상 표시"

-- Navigate modifier
L["None (always)"] = "없음 (항상)"

-- Misc
L["Approximate map appearance"] = "지도에서의 대략적인 모양"
L["ExportImport not available."] = "ExportImport를 사용할 수 없습니다."
