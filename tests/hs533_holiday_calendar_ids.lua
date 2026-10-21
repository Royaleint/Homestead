-- luacheck: globals assert loadfile print _G

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-- HS-533: C_Calendar.GetDayEvent reports a holiday's eventID as its Holidays
-- DB2 row ID. Loads the REAL Modules/CalendarDetector.lua with a stubbed
-- calendar showing one event today and checks which holiday it detects.

local HA = { Events = { Fire = function() end } }

local onEvent
_G.CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, fn) onEvent = fn end,
    }
end
_G.C_Timer = { After = function() end, NewTicker = function() end }
_G.C_DateAndTime = {
    GetCurrentCalendarTime = function() return { month = 10, year = 2026, monthDay = 20 } end,
}

local todaysEvent
_G.C_Calendar = {
    GetMonthInfo = function() return { month = 10, year = 2026 } end,
    GetNumDayEvents = function() return 1 end,
    GetDayEvent = function() return todaysEvent end,
}

assert(loadfile(root .. "/Modules/CalendarDetector.lua"))("Homestead", HA)
local CD = HA.CalendarDetector
CD:Initialize()
assert(onEvent, "Initialize did not install an event handler")

local function detect(eventID)
    todaysEvent = { eventID = eventID, calendarType = "HOLIDAY", sequenceType = "ONGOING" }
    onEvent(nil, "CALENDAR_UPDATE_EVENT_LIST")
    local names = {}
    for name in pairs(CD:GetActiveHolidays()) do names[#names + 1] = name end
    return names
end

local EXPECTED = {
    { 327, "Lunar Festival" },
    { 181, "Noblegarden" },
    { 372, "Brewfest" },
    { 423, "Love is in the Air" },
    { 341, "Midsummer Fire Festival" },
    { 141, "Feast of Winter Veil" },
    { 404, "Pilgrim's Bounty" },
    { 201, "Children's Week" },
    { 398, "Pirates' Day" },
    { 409, "Day of the Dead" },
}

local failures = 0
local function check(ok, msg)
    if not ok then
        failures = failures + 1
        print("FAIL: " .. msg)
    end
end

for _, row in ipairs(EXPECTED) do
    local id, name = row[1], row[2]
    for _, form in ipairs({ id, tostring(id) }) do
        local names = detect(form)
        check(#names == 1 and names[1] == name,
            ("eventID %s (%s) should detect %s, got {%s}"):format(
                tostring(form), type(form), name, table.concat(names, ", ")))
    end
end

-- IDs the table used before this fix, and a row the calendar never schedules.
for _, id in ipairs({ 7, 9, 24, 8, 1, 2, 26, 10, 50, 51, 335 }) do
    local names = detect(id)
    check(#names == 0, ("eventID %d should detect nothing, got {%s}"):format(
        id, table.concat(names, ", ")))
end

if failures > 0 then
    error(("hs533_holiday_calendar_ids: %d failure(s)"):format(failures))
end
print("hs533_holiday_calendar_ids: OK")
