--[[
    Homestead - DreamsurgeTracker
    Where Celestine of the Harvest stands right now

    Celestine sells at the Dreamsurge hub, which moves between the Dragon
    Isles zones on a timer. The active hub is an Area POI with the
    dreamsurge_hub-icon atlas on exactly one zone; a sweep of the Dragon
    Isles zone maps finds it. Her pin goes on her standing spot in that zone.

    Order: this session's detection (kept after it expires, until the next
    one) -> the account-wide saved detection while unexpired -> nil, meaning
    her shipped row. The resolved location changes only at a sweep or timer
    point, never per read, and DREAMSURGE_LOCATION_CHANGED fires exactly then.

    Saved: db.global.dreamsurgeHub = { mapID, x, y, poiID, expiresAt } (the
    raw detection, GetServerTime clock). A character without the Dreamsurge
    unlock sees no hub POI at all, so it relies on another character's entry.

    Data queries only.

    Public API:
      DreamsurgeTracker.NPC_ID
      DreamsurgeTracker:GetEffectiveLocation(npcID)  -> mapID, x, y | nil
]]

local _, HA = ...

local DreamsurgeTracker = {}
HA.DreamsurgeTracker = DreamsurgeTracker

local NPC_ID = 210608
DreamsurgeTracker.NPC_ID = NPC_ID

local CONTINENT_MAP = 1978
local EMERALD_DREAM_MAP = 2200
local HUB_ATLAS = "dreamsurge_hub-icon"

-- Her standing spot per hub zone (from the zone's Dreamsurge point data).
-- Keyed by zone: the other Dreamsurge POIs share the atlas, so a POI key
-- could miss.
local SPOTS = {
    [2022] = { 0.584, 0.678 },  -- The Waking Shores
    [2023] = { 0.642, 0.417 },  -- Ohn'ahran Plains
    [2024] = { 0.456, 0.398 },  -- The Azure Span
    [2025] = { 0.512, 0.434 },  -- Thaldraszus
}

-- The zone each known Dreamsurge POI belongs to, whichever map returned it
-- (Valdrakken counts as a Dragon Isles zone and can return a Thaldraszus POI).
local HUB_POI_ZONE = { [7587] = 2022, [7586] = 2023, [7585] = 2024, [7588] = 2025 }
local POINT_POI_ZONE = {
    [7556] = 2022, [7603] = 2022,
    [7555] = 2023, [7604] = 2023,
    [7554] = 2024, [7605] = 2024,
    [7553] = 2025, [7602] = 2025,
}

local EXPIRY_SLACK = 5                     -- seconds after a POI expires before re-sweeping
local RETRY_DELAYS = { 15, 30, 60 }        -- then RETRY_INTERVAL
local RETRY_INTERVAL = 120
local RETRY_WINDOW = 30 * 60               -- empty sweeps stop after this long
local UNKNOWN_EXPIRY_INTERVAL = 300
local EVENT_THROTTLE = 30
local SAVE_EXPIRY_TOLERANCE = 60
local MAX_SAVED_LIFETIME = 14 * 24 * 60 * 60

-- State
local sweepMaps            -- zone mapIDs, built on the first sweep that sees children
local live                 -- { mapID, x, y, poiID, expiresAt } from this session
local resolved             -- { mapID, x, y } or nil (shipped row)
local heldUntil            -- resolved source's expiry; math.huge for an unknown expiry
local timer
local lastSweepAt
local emptySince, emptyCount = nil, 0
local stopped = false

-------------------------------------------------------------------------------
-- Sweep
-------------------------------------------------------------------------------

local function GetSweepMaps()
    if sweepMaps then return sweepMaps end
    local children = C_Map.GetMapChildrenInfo(CONTINENT_MAP, Enum.UIMapType.Zone, true)
    if not children or #children == 0 then return nil end
    local maps, seen = {}, { [CONTINENT_MAP] = true }
    for _, child in ipairs(children) do
        if child.mapID and not seen[child.mapID] then
            seen[child.mapID] = true
            maps[#maps + 1] = child.mapID
        end
    end
    if not seen[EMERALD_DREAM_MAP] then
        maps[#maps + 1] = EMERALD_DREAM_MAP
    end
    sweepMaps = maps
    return maps
end

-- One candidate per hub POI found: { poiID, zone, isHub, x, y }. A known POI
-- belongs to its own zone and takes its position from that zone's map when
-- that map returned it. An unknown POI counts on a map that returned it,
-- preferring a zone with a known spot.
local function CollectHubPOIs(maps)
    local found, order = {}, {}
    for _, mapID in ipairs(maps) do
        local poiIDs = C_AreaPoiInfo.GetAreaPOIForMap(mapID)
        for _, poiID in ipairs(poiIDs or {}) do
            local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, poiID)
            if info and info.atlasName == HUB_ATLAS then
                local zone = HUB_POI_ZONE[poiID] or POINT_POI_ZONE[poiID]
                local entry = found[poiID]
                if not entry then
                    entry = { poiID = poiID, zone = zone or mapID, known = zone ~= nil,
                        isHub = HUB_POI_ZONE[poiID] ~= nil }
                    found[poiID] = entry
                    order[#order + 1] = entry
                elseif not entry.known and not SPOTS[entry.zone] and SPOTS[mapID] then
                    entry.zone = mapID
                    entry.x, entry.y = nil, nil
                end
                local pos = info.position
                if pos and (entry.x == nil or mapID == entry.zone) then
                    entry.x, entry.y = pos.x, pos.y
                end
            end
        end
    end
    return order
end

local function SecondsLeft(poiID)
    local secs = C_AreaPoiInfo.GetAreaPOISecondsLeft(poiID)
    if type(secs) == "number" and secs > 0 then return secs end
    return nil
end

-- Picks the hub zone: one zone outright; else the zone holding a hub-set POI;
-- else the largest SecondsLeft; else none. Known POIs outrank unknown ones.
local function PickDetection(candidates)
    local anyKnown = false
    for _, c in ipairs(candidates) do
        if c.known then anyKnown = true; break end
    end
    local zones, zoneList = {}, {}
    for _, c in ipairs(candidates) do
        if c.known == anyKnown then
            local z = zones[c.zone]
            if not z then
                z = { zone = c.zone, pois = {} }
                zones[c.zone] = z
                zoneList[#zoneList + 1] = z
            end
            z.pois[#z.pois + 1] = c
            z.hasHub = z.hasHub or c.isHub
            c.secs = SecondsLeft(c.poiID)
            if c.secs and (z.secs == nil or c.secs > z.secs) then z.secs = c.secs end
        end
    end
    if #zoneList == 0 then return nil end

    local pick
    if #zoneList == 1 then
        pick = zoneList[1]
    else
        local hubZones = {}
        for _, z in ipairs(zoneList) do
            if z.hasHub then hubZones[#hubZones + 1] = z end
        end
        if #hubZones == 1 then
            pick = hubZones[1]
        else
            local pool = #hubZones > 1 and hubZones or zoneList
            local best, tie
            for _, z in ipairs(pool) do
                if z.secs and (best == nil or z.secs > best.secs) then
                    best, tie = z, false
                elseif z.secs and z.secs == best.secs then
                    tie = true
                end
            end
            if best and not tie then pick = best end
        end
    end
    if not pick then return nil end

    -- The hub POI stands for its zone; else the one lasting longest.
    local chosen
    for _, c in ipairs(pick.pois) do
        if not chosen or (c.isHub and not chosen.isHub)
                or (c.isHub == chosen.isHub and (c.secs or 0) > (chosen.secs or 0)) then
            chosen = c
        end
    end
    local x, y = chosen.x, chosen.y
    if not x then
        local spot = SPOTS[pick.zone]
        if not spot then return nil end
        x, y = spot[1], spot[2]
    end
    return { mapID = pick.zone, x = x, y = y, poiID = chosen.poiID, secs = chosen.secs }
end

local function Sweep(maps)
    return PickDetection(CollectHubPOIs(maps))
end

-------------------------------------------------------------------------------
-- Saved entry
-------------------------------------------------------------------------------

local function GetGlobalDB()
    local db = HA.Addon and HA.Addon.db
    return db and db.global
end

local function IsUnit(v)
    return type(v) == "number" and v >= 0 and v <= 1
end

local function ReadSaved(now)
    local global = GetGlobalDB()
    local saved = global and global.dreamsurgeHub
    if type(saved) ~= "table" then return nil end
    if type(saved.mapID) ~= "number" or type(saved.poiID) ~= "number"
            or type(saved.expiresAt) ~= "number" then
        return nil
    end
    if HA.Constants.ZoneToContinentMap[saved.mapID] ~= CONTINENT_MAP then return nil end
    if not IsUnit(saved.x) or not IsUnit(saved.y) then return nil end
    if saved.expiresAt <= now or saved.expiresAt - now > MAX_SAVED_LIFETIME then return nil end
    return saved
end

local function WriteSaved(detection)
    local global = GetGlobalDB()
    if not global then return end
    local saved = global.dreamsurgeHub
    if type(saved) == "table" and saved.mapID == detection.mapID and saved.poiID == detection.poiID
            and saved.x == detection.x and saved.y == detection.y
            and type(saved.expiresAt) == "number"
            and math.abs(saved.expiresAt - detection.expiresAt) <= SAVE_EXPIRY_TOLERANCE then
        return
    end
    global.dreamsurgeHub = {
        mapID = detection.mapID, x = detection.x, y = detection.y,
        poiID = detection.poiID, expiresAt = detection.expiresAt,
    }
end

-------------------------------------------------------------------------------
-- Resolve
-------------------------------------------------------------------------------

local Arm

-- Recomputes the resolved location; fires on a change of the output.
local function Resolve(now)
    local source, saved = live, nil
    if not source then
        saved = ReadSaved(now)
        source = saved
    end

    local mapID, x, y
    if source then
        local spot = SPOTS[source.mapID]
        mapID = source.mapID
        if spot then
            x, y = spot[1], spot[2]
        else
            x, y = source.x, source.y
        end
        heldUntil = source.expiresAt or math.huge
    else
        heldUntil = nil
    end

    if saved and not timer then
        Arm(saved.expiresAt - now + EXPIRY_SLACK, false)
    end

    local old = resolved
    if (old and old.mapID) == mapID and (old and old.x) == x and (old and old.y) == y then
        return
    end
    resolved = mapID and { mapID = mapID, x = x, y = y } or nil
    if HA.Addon then
        HA.Addon:Debug("DreamsurgeTracker: Celestine at", tostring(mapID), tostring(x), tostring(y))
    end
    if HA.Events then
        HA.Events:Fire("DREAMSURGE_LOCATION_CHANGED")
    end
end

-------------------------------------------------------------------------------
-- Sweep scheduling
-------------------------------------------------------------------------------

local function RetryDelay(n)
    return RETRY_DELAYS[n] or RETRY_INTERVAL
end

-- fromTimer: an expiry, retry or unknown-expiry timer. Its empty sweep arms
-- the next retry; an AREA_POIS_UPDATED sweep leaves the next one to events.
local function RunSweep(fromTimer)
    local now = GetServerTime()
    lastSweepAt = now
    local maps = GetSweepMaps()
    local detection = maps and HA.PerformanceTrace:Measure("dreamsurge_sweep", #maps, Sweep, maps)

    if detection then
        emptySince, emptyCount, stopped = nil, 0, false
        detection.expiresAt = detection.secs and now + detection.secs or nil
        live = detection
        if detection.expiresAt then
            WriteSaved(detection)
            Arm(detection.secs + EXPIRY_SLACK, false)
        else
            Arm(UNKNOWN_EXPIRY_INTERVAL, false)
        end
    else
        emptyCount = emptyCount + 1
        emptySince = emptySince or now
        if now - emptySince >= RETRY_WINDOW then
            stopped = true
        elseif fromTimer then
            Arm(RetryDelay(emptyCount), false, true)
        end
    end

    Resolve(now)
end

-- isRetry keeps the empty-sweep series running; any other timer starts a new one.
function Arm(delay, eventPath, isRetry)
    if timer then timer:Cancel() end
    timer = C_Timer.NewTimer(math.max(delay, 0), function()
        timer = nil
        if not eventPath and not isRetry then
            emptySince, emptyCount, stopped = nil, 0, false
        end
        RunSweep(not eventPath)
    end)
end

local function OnAreaPOIsUpdated()
    local now = GetServerTime()
    if heldUntil and now < heldUntil then return end
    if timer or stopped then return end
    local gap = EVENT_THROTTLE
    if emptyCount > 0 then gap = math.max(gap, RetryDelay(emptyCount)) end
    local wait = lastSweepAt and (lastSweepAt + gap - now) or 0
    if wait <= 0 then
        RunSweep(false)
    else
        Arm(wait, true)
    end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function DreamsurgeTracker:GetEffectiveLocation(npcID)
    if npcID ~= NPC_ID or not resolved then return nil end
    return resolved.mapID, resolved.x, resolved.y
end

function DreamsurgeTracker:Initialize()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("AREA_POIS_UPDATED")
    eventFrame:SetScript("OnEvent", OnAreaPOIsUpdated)

    Resolve(GetServerTime())
    RunSweep(false)
end
