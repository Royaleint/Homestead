-- luacheck: globals assert loadfile print _G C_Calendar C_DateAndTime CreateFrame CalendarFrame C_Timer

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-- HS-540: before the Blizzard calendar window has ever been shown, the viewed
-- month is the client default (11/2004), so the HS-218 viewed-month guard kept
-- detection nil. With the window closed the detector must move the view to
-- today (as CalendarFrame_OnShow does); with it open it must never touch it.

local TODAY = { month = 10, year = 2026, monthDay = 21 }
local viewed, calls, dayEvents, dataLoaded

local function setup(opts)
    viewed = { month = opts.month, year = opts.year }
    calls = {}
    dayEvents = {}
    dataLoaded = true
    _G.CalendarFrame = opts.frame
    _G.C_DateAndTime = { GetCurrentCalendarTime = function() return TODAY end }
    _G.C_Timer = { After = function() end, NewTicker = function() return {} end }
    _G.C_Calendar = {
        GetMonthInfo = function() return { month = viewed.month, year = viewed.year } end,
        SetAbsMonth = function(month, year)
            calls[#calls + 1] = "SetAbsMonth"
            calls.setArgs = { month, year }
            viewed = { month = month, year = year }
        end,
        OpenCalendar = function() calls[#calls + 1] = "OpenCalendar" end,
        GetNumDayEvents = function(offset, day)
            assert(day == TODAY.monthDay, "scan must read today's day")
            -- Offset 0 is the viewed month; the default month has no events for today.
            if viewed.month ~= TODAY.month or viewed.year ~= TODAY.year or not dataLoaded then return 0 end
            return #dayEvents
        end,
        GetDayEvent = function(_, _, i) return dayEvents[i] end,
    }
end

local onEvent
_G.CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, fn) onEvent = fn end,
    }
end

local function load()
    local HA = {}
    assert(loadfile(root .. "/Modules/CalendarDetector.lua"))("Homestead", HA)
    HA.CalendarDetector:Initialize()
    return HA.CalendarDetector
end

local function count(name)
    local n = 0
    for _, c in ipairs(calls) do if c == name then n = n + 1 end end
    return n
end

local hallows = { { eventID = 324, calendarType = "HOLIDAY", sequenceType = "ONGOING" } }

-- (a) fresh state: default month 11/2004, window never loaded (CalendarFrame nil)
setup({ month = 11, year = 2004, frame = nil })
dayEvents = hallows
local det = load()
onEvent(nil, "CALENDAR_UPDATE_EVENT_LIST")
assert(count("SetAbsMonth") == 1, "(a) scan must set the viewed month once")
assert(calls.setArgs[1] == 10 and calls.setArgs[2] == 2026, "(a) SetAbsMonth must target today's month/year")
assert(det:IsHolidayActive("Hallow's End") == true, "(a) Hallow's End must be active after the month fix")

-- (a2) hidden but loaded window behaves the same
setup({ month = 11, year = 2004, frame = { IsShown = function() return false end } })
dayEvents = hallows
det = load()
onEvent(nil, "CALENDAR_UPDATE_EVENT_LIST")
assert(count("SetAbsMonth") == 1, "(a2) hidden window: scan must set the viewed month")
assert(det:IsHolidayActive("Hallow's End") == true, "(a2) Hallow's End must be active")

-- (b) window shown on another month: never moved, detection stays unknown
setup({ month = 3, year = 2026, frame = { IsShown = function() return true end } })
dayEvents = hallows
det = load()
onEvent(nil, "CALENDAR_UPDATE_EVENT_LIST")
assert(count("SetAbsMonth") == 0, "(b) shown window: SetAbsMonth must not be called")
assert(det:IsHolidayActive("Hallow's End") == nil, "(b) detection must stay nil on a mismatched shown window")
assert(viewed.month == 3 and viewed.year == 2026, "(b) the player's viewed month must be untouched")

-- (c) PLAYER_ENTERING_WORLD: SetAbsMonth strictly before OpenCalendar
setup({ month = 11, year = 2004, frame = nil })
load()
onEvent(nil, "PLAYER_ENTERING_WORLD")
assert(calls[1] == "SetAbsMonth" and calls[2] == "OpenCalendar" and #calls == 2,
    "(c) PEW must call SetAbsMonth then OpenCalendar, got " .. table.concat(calls, ","))

-- (d) PEW with the window shown: OpenCalendar only, view left alone
setup({ month = 3, year = 2026, frame = { IsShown = function() return true end } })
load()
onEvent(nil, "PLAYER_ENTERING_WORLD")
assert(count("SetAbsMonth") == 0 and count("OpenCalendar") == 1, "(d) shown window: no SetAbsMonth on PEW")

-- (e) scan moves the view but event data is not loaded yet: stay unknown
setup({ month = 11, year = 2004, frame = nil })
dayEvents = hallows
dataLoaded = false
det = load()
onEvent(nil, "CALENDAR_UPDATE_EVENT_LIST")
assert(count("SetAbsMonth") == 1, "(e) scan must move the view")
assert(det:IsHolidayActive("Hallow's End") == nil, "(e) unconfirmed empty read must not record 'no holidays'")
assert(det:IsReady() == false, "(e) detector must not be ready after an unconfirmed read")
dataLoaded = true
onEvent(nil, "CALENDAR_UPDATE_EVENT_LIST")
assert(count("SetAbsMonth") == 1, "(e) matching month must not move the view again")
assert(det:IsHolidayActive("Hallow's End") == true, "(e) loaded events must activate Hallow's End")
assert(det:IsReady() == true, "(e) detector ready after confirmed read")

-- (e2) a plain matching month with zero events still records an empty set
setup({ month = 10, year = 2026, frame = nil })
det = load()
onEvent(nil, "CALENDAR_UPDATE_EVENT_LIST")
assert(count("SetAbsMonth") == 0 and det:IsHolidayActive("Hallow's End") == false,
    "(e2) matching month with no events must record not-active")

-- (f) login sequence: view set and calendar opened once in total
setup({ month = 11, year = 2004, frame = nil })
dayEvents = hallows
det = load()
onEvent(nil, "PLAYER_ENTERING_WORLD")
onEvent(nil, "CALENDAR_UPDATE_EVENT_LIST")
onEvent(nil, "PLAYER_ENTERING_WORLD")
assert(count("SetAbsMonth") == 1, "(f) SetAbsMonth exactly once, got " .. count("SetAbsMonth"))
assert(count("OpenCalendar") == 1, "(f) OpenCalendar exactly once, got " .. count("OpenCalendar"))
assert(det:IsHolidayActive("Hallow's End") == true, "(f) Hallow's End active after the login sequence")

print("hs540_calendar_viewed_month: ok")
