--[[
    Homestead - Locale: Korean (KR)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "koKR" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- UI Labels
-------------------------------------------------------------------------------
L["Close"] = "닫기"

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
L["General"] = "일반"
L["Overlays"] = "오버레이"
L["Tooltips"] = "툴팁"
L["Export"] = "내보내기"

L["Show minimap button"] = "미니맵 버튼 표시"
L["Enable overlays"] = "오버레이 활성화"
L["Show on bags"] = "가방에 표시"
L["Show on bank"] = "은행에 표시"
L["Show on merchant"] = "상인에게 표시"
L["Show on housing catalog"] = "주거 카탈로그에 표시"
L["Icon size"] = "아이콘 크기"
L["Icon position"] = "아이콘 위치"
L["Show opposite faction vendors"] = "적 진영 상인 표시"

L["Enable tooltip additions"] = "툴팁 추가 정보 활성화"
L["Show source information"] = "출처 정보 표시"
L["Show vendor details in tooltips"] = "툴팁에 상인 세부 정보 표시"

L["Show map pins"] = "지도 핀 표시"
L["Show minimap pins"] = "미니맵 핀 표시"
L["Use TomTom for waypoints"] = "경유지에 TomTom 사용"
L["Use native waypoints"] = "기본 경유지 사용"
L["Auto-create waypoint on click"] = "클릭 시 경유지 자동 생성"
L["Navigate modifier key"] = "탐색 보조 키"

-------------------------------------------------------------------------------
-- Minimap Tooltip
-------------------------------------------------------------------------------
L["Collection: %d / %d (%d%%)"] = "수집: %d / %d (%d%%)"
L["Vendors nearby: %d"] = "근처 상인: %d"
L["Vendors scanned: %d"] = "스캔한 상인: %d"
L["Left-Click: Toggle options"] = "|cFFFFFFFF좌클릭:|r 설정 열기"
L["Right-Click: Detach/close vendor panel"] = "|cFFFFFFFF우클릭:|r 상인 패널 분리/닫기"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
L["Homestead Commands:"] = "Homestead 명령어:"

-------------------------------------------------------------------------------
-- Slash Command Feedback
-------------------------------------------------------------------------------
L["Map pins refreshed."] = "지도 핀이 새로고침되었습니다."
L["No active waypoint."] = "활성 경유지가 없습니다."
L["Waypoint cleared."] = "경유지가 삭제되었습니다."
L["Vendor database contains %d vendors."] = "상인 데이터베이스에 %d명의 상인이 있습니다."
L["Use /hs vendor <name or zone> to search."] = "/hs vendor <이름 또는 지역>으로 검색하세요."
L["No vendors found matching: %s"] = "일치하는 상인 없음: %s"
L["Found %d vendor(s) matching: %s"] = "%d명의 상인 발견: %s"
L["... and %d more."] = "... 외 %d명."

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
L["Debug mode: %s"] = "디버그 모드: %s"
L["ON"] = "켜짐"
L["OFF"] = "꺼짐"
L["Unknown command: %s"] = "알 수 없는 명령어: %s"

-------------------------------------------------------------------------------
-- Export Dialog
-------------------------------------------------------------------------------
L["Export Vendor Data"] = "상인 데이터 내보내기"
L["Choose export option:"] = "내보내기 옵션 선택:"
L["Export New Scans"] = "새 스캔 내보내기"
L["Export All"] = "전체 내보내기"

-------------------------------------------------------------------------------
-- Map Side Panel
-------------------------------------------------------------------------------
L["All"] = "전체"
L["Vendor"] = "상인"
L["Quest"] = "퀘스트"
L["Achievement"] = "업적"
L["Profession"] = "전문 기술"
L["Event"] = "이벤트"
L["Drop"] = "드롭"
L["Zone Collection Progress"] = "지역 수집 진행률"
L["Continent Collection Progress"] = "대륙 수집 진행률"
L["Global Collection Progress"] = "전체 수집 진행률"
L["Order Hall"] = "직업 전당"
L["Click to preview"] = "클릭하여 미리보기"

-------------------------------------------------------------------------------
-- Output Window
-------------------------------------------------------------------------------
L["Output"] = "출력"
L["Select All"] = "전체 선택"
L["All text selected. Press Ctrl+C to copy to clipboard."] = "텍스트가 선택되었습니다. Ctrl+C로 복사하세요."

