-- luacheck: globals assert loadfile print string CreateFrame C_Timer C_ChatInfo
-- luacheck: globals DEFAULT_CHAT_FRAME IsInGuild IsInGroup IsInRaid IsInInstance
-- luacheck: globals LE_PARTY_CATEGORY_HOME LE_PARTY_CATEGORY_INSTANCE math strsplit

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

local frames = {}
local timers = {}
local sent = {}
local printed = {}
local registeredPrefixes = {}
local inGuild = false
local inHome = false
local inRaid = false
local inInstanceGroup = false

LE_PARTY_CATEGORY_HOME = "home"
LE_PARTY_CATEGORY_INSTANCE = "instance"

function string.trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function strsplit(separator, value)
    local result = {}
    local start = 1
    while true do
        local first, last = string.find(value, separator, start, true)
        if not first then
            result[#result + 1] = string.sub(value, start)
            break
        end
        result[#result + 1] = string.sub(value, start, first - 1)
        start = last + 1
    end
    return result[1], result[2], result[3], result[4], result[5]
end

function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event)
        self.events[event] = (self.events[event] or 0) + 1
    end
    function frame:SetScript(kind, handler)
        self.script = handler
    end
    frames[#frames + 1] = frame
    return frame
end

C_Timer = {
    After = function(delay, callback)
        timers[#timers + 1] = { delay = delay, callback = callback }
    end,
}

C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix)
        registeredPrefixes[#registeredPrefixes + 1] = prefix
    end,
    SendAddonMessage = function(prefix, message, channel)
        sent[#sent + 1] = { prefix = prefix, message = message, channel = channel }
    end,
}

DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, message)
        printed[#printed + 1] = message
    end,
}

function IsInGuild() return inGuild end
function IsInRaid() return inRaid end
function IsInGroup(category)
    if category == LE_PARTY_CATEGORY_INSTANCE then return inInstanceGroup end
    return inHome
end
function IsInInstance() return false, "none" end

local function runTimers()
    local pending = timers
    timers = {}
    for _, timer in ipairs(pending) do timer.callback() end
end

local function fire(event, ...)
    assert(#frames == 1, "expected exactly one VersionCheck frame")
    frames[1].script(frames[1], event, ...)
end

local function addonMessage(channel, message)
    fire("CHAT_MSG_ADDON", "HmstdVC", message, channel, "Peer")
end

local function countSent(channel)
    local count = 0
    for _, message in ipairs(sent) do
        if message.channel == channel then count = count + 1 end
    end
    return count
end

local function countHellos(channel)
    local count = 0
    for _, message in ipairs(sent) do
        if message.channel == channel and message.message == "1\tH" then count = count + 1 end
    end
    return count
end

local HA = {
    Constants = { VERSION = "2.4.0", RELEASE_DATE = "2026-09-07" },
    Addon = { db = { profile = { versionCheck = { notify = true } } } },
}
function HA.Addon:Debug() end
HA.L = {}

assert(loadfile(root .. "/Modules/VersionCheck.lua"))("Homestead", HA)
local versionCheck = HA.VersionCheck

local function assertNewest(expected)
    local count = #printed
    versionCheck:HandleSlash("")
    assert(printed[count + 2]:find(expected, 1, true), "expected newest version " .. expected)
    for i = #printed, count + 1, -1 do printed[i] = nil end
end

versionCheck:Initialize()
versionCheck:Initialize()
assert(#frames == 1, "Initialize must keep one event frame")
for event, count in pairs(frames[1].events) do
    assert(count == 1, "Initialize must register each event once: " .. event)
end

-- Cold-login guild information retries, then remains once per session.
fire("PLAYER_ENTERING_WORLD")
assert(countHellos("GUILD") == 0, "cold-login guild false must not consume the hello")
inGuild = true
fire("PLAYER_ENTERING_WORLD")
fire("PLAYER_ENTERING_WORLD")
assert(countHellos("GUILD") == 1, "guild hello must be sent once per session")
assert(#registeredPrefixes == 3, "prefix registration may repeat with the event, but frame registration may not")

-- Exact Gregorian dates are accepted and malformed calendar dates are ignored.
local validDates = { { "2028-02-29", "9.0.0" }, { "2000-02-29", "9.0.1" }, { "2026-09-07", "9.0.2" } }
for _, entry in ipairs(validDates) do
    addonMessage("GUILD", "1\tV\t" .. entry[2] .. "\t" .. entry[1])
    assertNewest(entry[2])
end
assert(#printed == 2, "valid newer version should print one notice (two chat lines)")
for _, date in ipairs({ "2028-02-30", "1900-02-29", "2000-02-30", "2028-04-31", "2028-00-01", "2028-01-00", "0000-01-01" }) do
    addonMessage("GUILD", "1\tV\t9.9.9\t" .. date)
    assertNewest("9.0.2")
end
addonMessage("WHISPER", "1\tV\t9.9.9\t2028-02-29")
assertNewest("9.0.2")
addonMessage("GUILD", "2\tV\t9.9.9\t2028-02-29")
assertNewest("9.0.2")
addonMessage("GUILD", "1\tV\tbroken\t2028-02-29")
assertNewest("9.0.2")
assert(#printed == 2, "invalid Gregorian dates must be ignored")

-- Delayed replies re-check membership at execution time for every supported channel.
local channels = { "GUILD", "PARTY", "RAID", "INSTANCE_CHAT" }
for _, channel in ipairs(channels) do
    inGuild = channel == "GUILD"
    inHome = channel == "PARTY"
    inRaid = channel == "RAID"
    inInstanceGroup = channel == "INSTANCE_CHAT"
    local before = countSent(channel)
    addonMessage(channel, "1\tH")
    addonMessage(channel, "1\tH")
    assert(#timers == 1, "repeated " .. channel .. " hello must coalesce")
    assert(timers[1].delay >= 2 and timers[1].delay <= 5, "reply delay must be jittered between 2 and 5 seconds")
    if channel == "GUILD" then inGuild = false end
    if channel == "PARTY" then inHome = false end
    if channel == "RAID" then inRaid = false end
    if channel == "INSTANCE_CHAT" then inInstanceGroup = false end
    runTimers()
    assert(countSent(channel) == before, "reply must drop after leaving " .. channel)

    if channel == "GUILD" then inGuild = true end
    if channel == "PARTY" then inHome = true end
    if channel == "RAID" then inRaid = true end
    if channel == "INSTANCE_CHAT" then inInstanceGroup = true end
    addonMessage(channel, "1\tH")
    runTimers()
    assert(countSent(channel) == before + 1, "reply must retry after rejoining " .. channel)
end

-- Home and instance group membership can coexist; each channel is independent.
inHome, inInstanceGroup = true, true
local partyBefore, instanceBefore = countSent("PARTY"), countSent("INSTANCE_CHAT")
addonMessage("PARTY", "1\tH")
addonMessage("INSTANCE_CHAT", "1\tH")
assert(#timers == 2, "distinct channels must schedule independent replies")
runTimers()
assert(countSent("PARTY") == partyBefore + 1, "home group reply must remain available in an instance group")
assert(countSent("INSTANCE_CHAT") == instanceBefore + 1, "instance group reply must remain available in a home group")

-- Re-initialization after state exists must not disturb the frame, pending reply, or session flags.
inHome = true
addonMessage("PARTY", "1\tH")
assert(#timers == 1, "expected a pending reply before repeat initialization")
versionCheck:Initialize()
assert(#frames == 1 and #timers == 1, "repeat initialization must preserve frame and pending reply")
assertNewest("9.0.2")
addonMessage("PARTY", "1\tH")
assert(#timers == 1, "repeat initialization must preserve pending coalescing")
inGuild = true
fire("PLAYER_ENTERING_WORLD")
assert(countHellos("GUILD") == 1, "repeat initialization must preserve guild hello state")
local printedBeforeRepeatVersion = #printed
addonMessage("PARTY", "1\tV\t9.0.3\t2028-02-29")
assert(#printed == printedBeforeRepeatVersion, "repeat initialization must preserve once-per-session notice state")
assertNewest("9.0.3")
runTimers()

-- A fresh unprinted session proves notify-off suppresses notices while replies and tracking continue.
frames, timers, sent, printed, registeredPrefixes = {}, {}, {}, {}, {}
inGuild, inHome, inRaid, inInstanceGroup = false, true, false, false
local HA2 = {
    Constants = { VERSION = "2.4.0", RELEASE_DATE = "2026-09-07" },
    Addon = { db = { profile = { versionCheck = { notify = true } } } },
}
function HA2.Addon:Debug() end
HA2.L = {}
assert(loadfile(root .. "/Modules/VersionCheck.lua"))("Homestead", HA2)
versionCheck = HA2.VersionCheck
versionCheck:Initialize()
versionCheck:HandleSlash("off")
addonMessage("PARTY", "1\tV\t9.1.0\t2028-02-29\textra")
assert(#printed == 1 and printed[1]:find("OFF", 1, true), "notify off must suppress a fresh-session notice")
addonMessage("PARTY", "1\tH")
assert(#timers == 1, "notify off must still schedule replies")
runTimers()
assert(countSent("PARTY") == 1, "notify off must still reply")
versionCheck:HandleSlash("")
assert(printed[#printed - 1]:find("9.1.0", 1, true), "notify off must track newest version")
versionCheck:HandleSlash("on")
addonMessage("PARTY", "1\tV\t9.2.0\t2028-02-29")
assert(#printed == 7, "notify on must enable a notice")
addonMessage("PARTY", "1\tV\t9.3.0\t2028-02-29")
assert(#printed == 7, "notice must remain once per session")
versionCheck:HandleSlash("off")
assert(printed[#printed]:find("OFF", 1, true), "slash off must disable notifications")

print("version_check_behavior: all behavior checks passed")
