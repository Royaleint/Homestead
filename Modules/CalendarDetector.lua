--[[
    Homestead - CalendarDetector
    Detects active seasonal holidays via C_Calendar API

    Uses CALENDAR_UPDATE_EVENT_LIST as primary reactive detection,
    with a periodic re-check as safety net for missed events.

    Holiday matching uses stable eventID from C_Calendar.GetDayEvent()
    (locale-independent) rather than title strings.

    Public API:
      CalendarDetector:IsHolidayActive(eventName)  → true/false/nil
      CalendarDetector:GetActiveHolidays()          → { [name] = true, ... }
      CalendarDetector:IsAnyEventVendorActive()     → bool
]]

local _, HA = ...

local CalendarDetector = {}
HA.CalendarDetector = CalendarDetector

-- State
local activeHolidays = nil  -- nil = not yet scanned, {} = scanned but none active
local calendarReady = false
local refreshTimer = nil
local REFRESH_INTERVAL = 14400  -- 4 hours (safety net only)

-------------------------------------------------------------------------------
-- Holiday ID Mapping
-- Maps our internal event names to C_Calendar eventID values.
-- These are stable IDs from WoW's DB/Holidays table (locale-independent).
-- eventID is returned as a string by GetDayEvent() in retail 10.0.7+.
-------------------------------------------------------------------------------

local holidayIDToEvent = {
    ["7"]  = "Lunar Festival",
    ["9"]  = "Noblegarden",
    ["24"] = "Brewfest",
    ["8"]  = "Love is in the Air",
    ["1"]  = "Midsummer Fire Festival",
    ["2"]  = "Feast of Winter Veil",
    ["12"] = "Hallow's End",
    ["26"] = "Pilgrim's Bounty",
    ["10"] = "Children's Week",
    ["50"] = "Pirates' Day",
    ["51"] = "Day of the Dead",
}


-------------------------------------------------------------------------------
-- Calendar Scanning
-------------------------------------------------------------------------------

local function ScanTodaysHolidays()
    if not C_Calendar or not C_Calendar.GetNumDayEvents or not C_Calendar.GetDayEvent then
        return nil
    end

    local today = C_DateInfo and C_DateInfo.GetCurrentCalendarTime and C_DateInfo.GetCurrentCalendarTime()
    if not today then return nil end

    local numEvents = C_Calendar.GetNumDayEvents(0, today.monthDay)
    if not numEvents then return nil end

    local found = {}

    for i = 1, numEvents do
        local event = C_Calendar.GetDayEvent(0, today.monthDay, i)
        if event and event.calendarType == "HOLIDAY" and event.sequenceType ~= "END" then
            local eventIDStr = tostring(event.eventID)

            -- Match by stable eventID first
            local eventName = holidayIDToEvent[eventIDStr]
            if eventName then
                found[eventName] = true
            end
        end
    end

    return found
end

local function RefreshHolidays()
    local result = ScanTodaysHolidays()
    if result == nil then
        -- Calendar data not available yet
        return
    end

    local changed = false

    if activeHolidays == nil then
        -- First scan
        changed = true
    else
        -- Compare old vs new
        for name in pairs(result) do
            if not activeHolidays[name] then changed = true; break end
        end
        if not changed then
            for name in pairs(activeHolidays) do
                if not result[name] then changed = true; break end
            end
        end
    end

    activeHolidays = result
    calendarReady = true

    if changed and HA.Events then
        HA.Events:Fire("ACTIVE_HOLIDAYS_CHANGED")
    end

    -- Debug output
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug then
        local names = {}
        for name in pairs(activeHolidays) do
            names[#names + 1] = name
        end
        if #names > 0 then
            HA.Addon:Debug("CalendarDetector: active holidays:", table.concat(names, ", "))
        else
            HA.Addon:Debug("CalendarDetector: no active holidays")
        end
    end
end

-------------------------------------------------------------------------------
-- Periodic Re-check (safety net)
-------------------------------------------------------------------------------

local function SchedulePeriodicCheck()
    if refreshTimer then return end
    refreshTimer = C_Timer.NewTicker(REFRESH_INTERVAL, function()
        RefreshHolidays()
    end)
end


-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

-- Returns true if holiday is active, false if not active, nil if unknown
function CalendarDetector:IsHolidayActive(eventName)
    if not eventName then return nil end
    if activeHolidays == nil then return nil end  -- Calendar data not loaded
    return activeHolidays[eventName] == true
end

-- Returns table of active holiday names, or empty table, or nil if unknown
function CalendarDetector:GetActiveHolidays()
    return activeHolidays
end

-- Returns true if any event vendor from EventSources has an active holiday
function CalendarDetector:IsAnyEventVendorActive()
    if activeHolidays == nil then return false end
    if not HA.EventSources or not HA.EventSources.EventVendors then return false end

    for _, vendor in pairs(HA.EventSources.EventVendors) do
        if vendor.event and activeHolidays[vendor.event] then
            return true
        end
    end
    return false
end

-- Check if calendar data has been loaded
function CalendarDetector:IsReady()
    return calendarReady
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function CalendarDetector:Initialize()
    local eventFrame = CreateFrame("Frame")

    -- Listen for calendar data updates (primary reactive detection)
    eventFrame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")

    -- Also listen for PEW to trigger calendar open
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Request calendar data (required before GetDayEvent works)
            if C_Calendar and C_Calendar.OpenCalendar then
                C_Calendar.OpenCalendar()
            end
            -- Try an initial scan after a short delay (calendar may need time)
            C_Timer.After(2, function()
                RefreshHolidays()
                SchedulePeriodicCheck()
            end)
        elseif event == "CALENDAR_UPDATE_EVENT_LIST" then
            -- Calendar data arrived or changed — scan immediately
            RefreshHolidays()
        end
    end)

    if HA.Addon then
        HA.Addon:Debug("CalendarDetector initialized")
    end
end
