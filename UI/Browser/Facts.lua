-- Static facts the browser reads: which vendors it lists, confirmation dates, portraits and spots,
-- the player's zone and the keys that name a source.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L

local F = {}
B.Facts = F

local function EventVendors()
    return HA.EventSources and HA.EventSources.EventVendors or {}
end

-- Whether the browser lists a vendor at all. Unlike the map pins it ignores display settings, and a
-- holiday or Endeavor vendor counts only while its event or theme is known to be on.
function F.BrowserListed(vendor)
    if not vendor or vendor.removed then return false end
    if vendor.unreleased and not HA.VendorFilter.ShouldRevealUnreleasedVendors() then return false end
    local ev = EventVendors()[vendor.npcID]
    if ev or vendor._isEventVendor then
        local event = ev and ev.event or vendor.event
        local CD = HA.CalendarDetector
        if not (event and CD and CD:IsHolidayActive(event) == true) then return false end
    end
    if vendor.endeavor then
        local ED = HA.EndeavorsData
        if not (ED and ED:IsThemeActive(ED:GetThemeForVendor(vendor)) == true) then return false end
    end
    return true
end

-- Holiday vendors selling an item, in or out of season; nil when none.
local eventIndex
function F.EventVendorsFor(itemID)
    if not eventIndex then
        eventIndex = {}
        for npcID, v in pairs(EventVendors()) do
            for _, id in ipairs(v.items or HA.VendorData:GetVendorItems(npcID) or {}) do
                local list = eventIndex[id] or {}
                list[#list + 1] = npcID
                eventIndex[id] = list
            end
        end
    end
    return eventIndex[itemID]
end

function F.EventVendor(npcID)
    return EventVendors()[npcID]
end

-- The newer of the shipped confirmation and the player's own scan, as "YYYY-MM-DD"; nil when neither.
function F.Confirmed(vendor)
    local shipped = vendor.scanConfirmed
    local record = HA.VendorData:GetScannedVendorRecord(vendor)
    local mine = record and record.lastScanned and date("%Y-%m-%d", record.lastScanned)
    if mine and (not shipped or mine > shipped) then return mine end
    return shipped
end

function F.Portrait(npcID)
    return HA.VendorPortraits and HA.VendorPortraits[npcID]
end

function F.QuestStart(questID)
    return HA.QuestStarts and HA.QuestStarts[questID]
end

function F.TreasureSpot(questID)
    return HA.TreasureHuntSpots and HA.TreasureHuntSpots[questID]
end

-- The zone-level map at or above mapID: a building or dungeon map walks up to its zone.
function F.ZoneOf(mapID)
    local zoneType = Enum.UIMapType.Zone
    while mapID do
        local info = C_Map.GetMapInfo(mapID)
        if not info then return nil end
        if info.mapType <= zoneType or not info.parentMapID or info.parentMapID == 0 then return mapID end
        mapID = info.parentMapID
    end
    return nil
end

local continentOf = {}
function F.ContinentOf(mapID)
    if not mapID then return nil end
    local known = continentOf[mapID]
    if known ~= nil then return known or nil end
    local continentType, id = Enum.UIMapType.Continent, mapID
    local found = false
    while id and id ~= 0 do
        local info = C_Map.GetMapInfo(id)
        if not info then break end
        if info.mapType == continentType then found = id break end
        id = info.parentMapID
    end
    continentOf[mapID] = found
    return found or nil
end

-- The player's zone: { zone, name, continent, maps = set of the zone and its child maps }; nil when unknown.
local here
function F.Here()
    local zone = F.ZoneOf(C_Map.GetBestMapForUnit("player"))
    if not zone then return nil end
    if here and here.zone == zone then return here end
    local info = C_Map.GetMapInfo(zone)
    here = { zone = zone, name = info and info.name, continent = F.ContinentOf(zone), maps = { [zone] = true } }
    for _, kid in ipairs(C_Map.GetMapChildrenInfo(zone, nil, true) or {}) do here.maps[kid.mapID] = true end
    return here
end

-- 1 here, 2 on this continent, 3 elsewhere.
function F.Nearness(mapID, where)
    if not (where and mapID) then return 3 end
    if where.maps[mapID] then return 1 end
    local c = F.ContinentOf(mapID)
    return (c and c == where.continent) and 2 or 3
end

-- The factions a faction stop names, as { { count, label } }: the other one, with total, for a faction
-- character; for a Neutral one, only the factions in seen (label -> count).
function F.FactionParts(seen, total)
    local mine = UnitFactionGroup("player")
    if mine == "Alliance" then return { { total, L["Horde"] } } end
    if mine == "Horde" then return { { total, L["Alliance"] } } end
    local out = {}
    for _, label in ipairs({ L["Alliance"], L["Horde"] }) do
        if seen and seen[label] then out[#out + 1] = { seen[label], label } end
    end
    return out
end

-- The same, for a sentence; nil for a Neutral character with none seen.
function F.OtherFaction(seen)
    local p = F.FactionParts(seen, 0)
    if p[2] then return L["%s or the %s"]:format(p[1][2], p[2][2]) end
    return p[1] and p[1][2]
end

-- A source's data type to its Sources type.
F.SOURCE_TYPE = {
    vendor = "vendors", achievement = "achievements", quest = "quests", profession = "professions",
    drop = "drops", event = "events", shop = "shop",
}

-- The only builder of Sources row keys and onward-link keys. nil draws no "Show" button.
function F.SourceKey(sourceType, data, itemID)
    if not data then return nil end
    if sourceType == "vendors" then
        local npcID = data.npcID
        return (npcID and HA.VendorData:GetVendor(npcID)) and npcID or nil
    elseif sourceType == "achievements" then
        return data.achievementID
    elseif sourceType == "quests" then
        return data.questID
    elseif sourceType == "professions" then
        return data.spellID
    elseif sourceType == "drops" then
        return (data.mobName and data.zone) and (data.mobName .. "|" .. data.zone) or nil
    elseif sourceType == "events" then
        return data.event
    elseif sourceType == "shop" then
        return itemID
    end
    return nil
end
