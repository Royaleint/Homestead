-- luacheck: globals assert loadfile print _G C_Calendar C_DateAndTime CreateFrame

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-- HS-532: the live client reports Hallow's End as eventID 324 (HOLIDAY, ONGOING).
-- Loads the REAL Modules/CalendarDetector.lua and drives it the way the game does:
-- Initialize registers a frame, CALENDAR_UPDATE_EVENT_LIST triggers the scan.

local TODAY = { month = 10, year = 2026, monthDay = 20 }
local dayEvents = {}

_G.C_DateAndTime = { GetCurrentCalendarTime = function() return TODAY end }
_G.C_Calendar = {
    GetMonthInfo = function() return { month = TODAY.month, year = TODAY.year } end,
    GetNumDayEvents = function(_, day)
        assert(day == TODAY.monthDay, "scan must read today's day")
        return #dayEvents
    end,
    GetDayEvent = function(_, day, i)
        assert(day == TODAY.monthDay, "scan must read today's day")
        return dayEvents[i]
    end,
}

local onEvent
_G.CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, fn) onEvent = fn end,
    }
end

-- Fresh module instance per scenario (scan state is module-local).
local function hallowsEndActive(events)
    dayEvents = events
    local HA = {}
    assert(loadfile(root .. "/Modules/CalendarDetector.lua"))("Homestead", HA)
    HA.CalendarDetector:Initialize()
    onEvent(nil, "CALENDAR_UPDATE_EVENT_LIST")
    return HA.CalendarDetector:IsHolidayActive("Hallow's End")
end

local function ev(id, seq)
    return { eventID = id, calendarType = "HOLIDAY", sequenceType = seq }
end

-- Field data 2026-10-20: Hallow's End among other bonus events.
assert(hallowsEndActive({ ev(1559, "ONGOING"), ev(324, "ONGOING"), ev(1240, "ONGOING") }) == true,
    "eventID 324 ONGOING must activate Hallow's End")
assert(hallowsEndActive({ ev(324, "START") }) == true, "324 START is active")
assert(hallowsEndActive({ ev(12, "ONGOING") }) == false, "eventID 12 must not activate Hallow's End")
assert(hallowsEndActive({ ev(324, "END") }) == false, "324 on its END day is inactive")
assert(hallowsEndActive({ ev(1559, "ONGOING") }) == false, "unrelated events leave it inactive")

print("hs532_calendar_hallows_end_id: ok")
