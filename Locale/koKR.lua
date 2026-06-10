--[[
    Homestead - Locale: Korean (KR)
    Machine-translated — contributions welcome
]]

local _, HA = ...

if GetLocale() ~= "koKR" then return end

-- Override translated keys; enUS fallbacks remain for missing entries
local L = HA.L

-------------------------------------------------------------------------------
-- Collection Status
-------------------------------------------------------------------------------
L["Collected"] = "수집됨"
L["Collected (Placed)"] = "수집됨 (배치됨)"
L["Not Collected"] = "미수집"
L["Unknown"] = "알 수 없음"

-------------------------------------------------------------------------------
-- Source Descriptions
-------------------------------------------------------------------------------
L["Available from vendor"] = "상인에게 구매 가능"
L["Can be crafted"] = "제작 가능"
L["Achievement reward"] = "업적 보상"
L["World drop"] = "월드 드롭"
L["Quest reward"] = "퀘스트 보상"
L["Reputation reward"] = "평판 보상"
L["Event reward"] = "이벤트 보상"
L["Promotional item"] = "프로모션 아이템"

-------------------------------------------------------------------------------
-- Decor Properties
-------------------------------------------------------------------------------
L["Can be dyed"] = "염색 가능"
L["Colorable"] = "색상 변경 가능"
L["Warbound"] = "전쟁결속"
L["Indoor only"] = "실내 전용"
L["Outdoor only"] = "실외 전용"
L["Quantity owned: %d"] = "보유 수량: %d"
L["Currently placed: %d"] = "현재 배치: %d"

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------
L["[Housing Addon]"] = "|cFF00FF00[Homestead]|r"
L["Source:"] = "출처:"
L["Vendor:"] = "상인:"
L["Location:"] = "위치:"
L["Click to set waypoint"] = "클릭하여 경유지 설정"

-------------------------------------------------------------------------------
-- UI Labels
-------------------------------------------------------------------------------
L["Housing Addon"] = "Homestead"
L["Decor Browser"] = "장식 브라우저"
L["Vendor Tracer"] = "상인 추적기"
L["Color Tracker"] = "염료 추적기"
L["Export Data"] = "데이터 내보내기"
L["Options"] = "설정"
L["Search"] = "검색"
L["Filter"] = "필터"
L["Close"] = "닫기"

-------------------------------------------------------------------------------
-- Vendor Tracer
-------------------------------------------------------------------------------
L["Set Waypoint"] = "경유지 설정"
L["Show on Map"] = "지도에 표시"
L["Vendor sells %d decor items"] = "상인이 장식 아이템 %d개 판매"
L["You own %d/%d items"] = "%d/%d개 보유 중"
L["Missing items:"] = "미보유 아이템:"
L["No vendors found"] = "상인을 찾을 수 없음"

-------------------------------------------------------------------------------
-- Color/Dye Tracker
-------------------------------------------------------------------------------
L["Dye Collection"] = "염료 컬렉션"
L["Owned Dyes"] = "보유 염료"
L["Known Recipes"] = "알려진 제작법"
L["Dye Slots"] = "염료 슬롯"
L["Apply Dye"] = "염료 적용"
L["Preview"] = "미리 보기"

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
L["Show on auction house"] = "경매장에 표시"
L["Show on housing catalog"] = "주거 카탈로그에 표시"
L["Icon size"] = "아이콘 크기"
L["Icon position"] = "아이콘 위치"
L["Show opposite faction vendors"] = "적 진영 상인 표시"
L["Show unverified vendors"] = "미확인 상인 표시"

L["Enable tooltip additions"] = "툴팁 추가 정보 활성화"
L["Show source information"] = "출처 정보 표시"
L["Show quantity owned"] = "보유 수량 표시"
L["Show dye slot information"] = "염료 슬롯 정보 표시"
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
L["/hs - Open options panel"] = "/hs — 설정 패널 열기"
L["/hs scan - Scan catalog"] = "/hs scan — 카탈로그 스캔"
L["/hs vendor [search] - Search vendors"] = "/hs vendor [검색] — 장식 상인 검색"
L["/hs export - Show export dialog"] = "/hs export — 내보내기 대화상자 표시"
L["/hs debug - Toggle debug mode"] = "/hs debug — 디버그 모드 전환"
L["/hs help - Show this help"] = "/hs help — 이 도움말 표시"

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
L["Not yet implemented"] = "아직 구현되지 않음"

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

-------------------------------------------------------------------------------
-- Statistics
-------------------------------------------------------------------------------
L["Statistics"] = "통계"
L["Total Decor:"] = "총 장식:"
L["Collected:"] = "수집됨:"
L["Placed:"] = "배치됨:"
L["Remaining:"] = "남음:"
L["Collection Progress: %d%%"] = "컬렉션 진행률: %d%%"
