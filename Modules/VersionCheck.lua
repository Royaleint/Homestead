--[[
    Homestead - VersionCheck
    HS-086: peer-broadcast out-of-date notification.

    On login (and on group/raid/instance join) we send a hello over the
    appropriate channel. Peers reply with their version + release date.
    If we see a version newer than our own, we print a one-shot notice
    via DEFAULT_CHAT_FRAME:AddMessage. State is Lua-only (resets on
    /reload), so once-per-session IS the throttle.

    Wire protocol (keep the wire locale-neutral and sortable):
        Prefix  : "HmstdVC"
        Hello   : "1\tH"
        Version : "1\tV\t<displayVersion>\t<releaseDate ISO YYYY-MM-DD>"

    Anti-spam guards (all stacked):
      1. Single-sender threshold (no 2-sender corroboration)
      2. Channel-as-roster filter (GUILD/PARTY/RAID/INSTANCE_CHAT only)
      3. Strict regex validation on version + date
      4. Session-flag print throttle (printedThisSession)
      5. No re-trigger on combat/instance enter
      6. No force-disable
      7. No fake-handshake

    Public API:
      VersionCheck:Initialize()        registers events; called from core.lua OnEnable
      VersionCheck:HandleSlash(args)   /hs version | /hs version on|off
]]

local _, HA = ...

local VersionCheck = {}
HA.VersionCheck = VersionCheck

-- Stdlib upvalues (safe at file scope)
local format = string.format
local strmatch = string.match

-------------------------------------------------------------------------------
-- Protocol constants
-------------------------------------------------------------------------------
local PREFIX           = "HmstdVC"
local PROTOCOL         = 1
local PROTOCOL_STR     = tostring(PROTOCOL)
local CMD_HELLO        = "H"
local CMD_VERSION      = "V"
local REPLY_DELAY      = 3
local VERSION_RE       = "^%d+%.%d+%.%d+$"
local DATE_RE          = "^%d%d%d%d%-%d%d%-%d%d$"
local PREFIX_COLORED   = "|cFF00FF00<Homestead>|r"

-- Channels that count as roster context. Anything else (WHISPER, BN, etc.)
-- is dropped silently on receive.
local GROUP_CHANNELS = {
    GUILD          = true,
    PARTY          = true,
    RAID           = true,
    INSTANCE_CHAT  = true,
}

-------------------------------------------------------------------------------
-- State (Lua-only; resets on /reload)
-------------------------------------------------------------------------------
local printedThisSession = false
local replyScheduled     = {}    -- [channel] = true while a 3s reply is pending
local newestSeenVersion  = nil
local newestSeenDate     = nil   -- ISO
local wasInGroup         = false

-------------------------------------------------------------------------------
-- Parsing / validation
-------------------------------------------------------------------------------

-- Returns protocol, command, arg1, arg2, ... as strings, or nil on malformed.
local function ParsePayload(message)
    if type(message) ~= "string" then return nil end
    local parts = { strsplit("\t", message) }
    if #parts < 2 then return nil end
    return parts[1], parts[2], parts[3], parts[4]
end

local function IsValidVersion(s)
    return type(s) == "string" and strmatch(s, VERSION_RE) ~= nil
end

local function IsValidDate(s)
    return type(s) == "string" and strmatch(s, DATE_RE) ~= nil
end

-- Compare "M.N.P" strings. Returns -1 / 0 / 1.
-- Assumes both inputs already passed IsValidVersion.
local function CompareVersions(a, b)
    local a1, a2, a3 = strmatch(a, "^(%d+)%.(%d+)%.(%d+)$")
    local b1, b2, b3 = strmatch(b, "^(%d+)%.(%d+)%.(%d+)$")
    a1, a2, a3 = tonumber(a1), tonumber(a2), tonumber(a3)
    b1, b2, b3 = tonumber(b1), tonumber(b2), tonumber(b3)
    if a1 ~= b1 then return a1 < b1 and -1 or 1 end
    if a2 ~= b2 then return a2 < b2 and -1 or 1 end
    if a3 ~= b3 then return a3 < b3 and -1 or 1 end
    return 0
end

-- "2026-05-18" -> "05/18/2026". Returns the input unchanged if it doesn't parse.
local function FormatDateMDY(isoDate)
    if type(isoDate) ~= "string" then return tostring(isoDate) end
    local y, m, d = strmatch(isoDate, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not y then return isoDate end
    return format("%s/%s/%s", m, d, y)
end

-------------------------------------------------------------------------------
-- Send helpers
-------------------------------------------------------------------------------

local function SendHello(channel)
    if not channel then return end
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return end
    C_ChatInfo.SendAddonMessage(PREFIX, format("%d\t%s", PROTOCOL, CMD_HELLO), channel)
end

local function SendVersion(channel)
    if not channel then return end
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return end
    local C = HA.Constants
    if not C or not C.VERSION or not C.RELEASE_DATE then return end
    local payload = format("%d\t%s\t%s\t%s", PROTOCOL, CMD_VERSION, C.VERSION, C.RELEASE_DATE)
    C_ChatInfo.SendAddonMessage(PREFIX, payload, channel)
end

-------------------------------------------------------------------------------
-- Group-channel resolution
-------------------------------------------------------------------------------

local function SelectGroupChannel()
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid"
        or instanceType == "pvp" or instanceType == "arena" or instanceType == "scenario") then
        return "INSTANCE_CHAT"
    end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

-------------------------------------------------------------------------------
-- Message printing
-------------------------------------------------------------------------------

local function ChatPrint(line)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX_COLORED .. " " .. line)
    end
end

local function PrintOutdatedNotice(version, isoDate)
    local L = HA.L or {}
    local header = L["Your Homestead version is out-of-date."]
        or "Your Homestead version is out-of-date."
    local bodyFmt = L["Version %s (%s) can be downloaded at CurseForge, Wago, or GitHub Releases."]
        or "Version %s (%s) can be downloaded at CurseForge, Wago, or GitHub Releases."
    ChatPrint(header)
    ChatPrint(format(bodyFmt, version, FormatDateMDY(isoDate)))
end

-------------------------------------------------------------------------------
-- Command handlers
-------------------------------------------------------------------------------

local function OnHello(_, channel)
    if not GROUP_CHANNELS[channel] then return end
    if replyScheduled[channel] then return end
    replyScheduled[channel] = true
    C_Timer.After(REPLY_DELAY, function()
        replyScheduled[channel] = nil
        SendVersion(channel)
    end)
end

local function OnVersion(_, channel, peerVersion, peerDate)
    -- Channel-as-roster filter. Drop WHISPER and anything unexpected silently.
    if not GROUP_CHANNELS[channel] then return end
    if not IsValidVersion(peerVersion) then return end
    if not IsValidDate(peerDate) then return end

    local C = HA.Constants
    if not C or not C.VERSION then return end

    local cmp = CompareVersions(peerVersion, C.VERSION)
    if cmp <= 0 then return end  -- peer is same or older; nothing to do

    -- Track newest-seen for /hs version reporting
    if not newestSeenVersion or CompareVersions(peerVersion, newestSeenVersion) > 0 then
        newestSeenVersion = peerVersion
        newestSeenDate    = peerDate
    end

    -- Print once per session if notifications are on
    if printedThisSession then return end
    local db = HA.Addon and HA.Addon.db
    if not db or not db.profile.versionCheck or db.profile.versionCheck.notify == false then return end

    PrintOutdatedNotice(peerVersion, peerDate)
    printedThisSession = true
end

-------------------------------------------------------------------------------
-- Roster transition
-------------------------------------------------------------------------------

local function OnGroupRosterUpdate()
    local nowInGroup = IsInGroup() or IsInRaid()
    if nowInGroup and not wasInGroup then
        SendHello(SelectGroupChannel())
    end
    wasInGroup = nowInGroup
end

-------------------------------------------------------------------------------
-- Slash subcommand
-------------------------------------------------------------------------------

function VersionCheck:HandleSlash(args)
    local L = HA.L or {}
    args = args and args:trim():lower() or ""
    local db = HA.Addon and HA.Addon.db

    if args == "on" or args == "off" then
        if db and db.profile.versionCheck then
            db.profile.versionCheck.notify = (args == "on")
        end
        local state = (args == "on") and (L["ON"] or "ON") or (L["OFF"] or "OFF")
        ChatPrint(format(L["Version-check notifications: %s"]
            or "Version-check notifications: %s", state))
        return
    end

    -- No args: report current state
    local C = HA.Constants or {}
    local localVersion = C.VERSION or "?"
    local localDate    = C.RELEASE_DATE or "?"
    ChatPrint(format(L["Homestead version: %s (%s)"] or "Homestead version: %s (%s)",
        localVersion, FormatDateMDY(localDate)))

    if newestSeenVersion then
        ChatPrint(format(L["Newest version seen this session: %s (%s)"]
            or "Newest version seen this session: %s (%s)",
            newestSeenVersion, FormatDateMDY(newestSeenDate or "")))
    else
        ChatPrint(L["No newer version seen this session."]
            or "No newer version seen this session.")
    end

    local notifyOn = true
    if db and db.profile.versionCheck and db.profile.versionCheck.notify == false then
        notifyOn = false
    end
    local state = notifyOn and (L["ON"] or "ON") or (L["OFF"] or "OFF")
    ChatPrint(format(L["Version-check notifications: %s"]
        or "Version-check notifications: %s", state))
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function VersionCheck:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("CHAT_MSG_ADDON")

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Idempotent prefix registration. Safe to call repeatedly.
            if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
                C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
            end
            -- Seed roster transition state so we don't double-send on the
            -- first GROUP_ROSTER_UPDATE after a /reload mid-group.
            wasInGroup = IsInGroup() or IsInRaid()
        elseif event == "PLAYER_LOGIN" then
            if IsInGuild and IsInGuild() then
                SendHello("GUILD")
            end
        elseif event == "GROUP_ROSTER_UPDATE" then
            OnGroupRosterUpdate()
        elseif event == "CHAT_MSG_ADDON" then
            local prefix, message, channel, sender = ...
            if prefix ~= PREFIX then return end
            local proto, cmd, a, b = ParsePayload(message)
            if proto ~= PROTOCOL_STR then return end
            if cmd == CMD_HELLO then
                OnHello(sender, channel)
            elseif cmd == CMD_VERSION then
                OnVersion(sender, channel, a, b)
            end
        end
    end)

    if HA.Addon then
        HA.Addon:Debug("VersionCheck initialized")
    end
end
