-- Static facts the browser reads: which vendors it lists, spots, the player's zone and the keys that name a source.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L

local F = {}
B.Facts = F

-- Whether the browser lists a vendor at all. Unlike the map pins it ignores display settings. A holiday
-- vendor is listed in its season, and every Endeavor vendor is listed whichever theme is on.
function F.BrowserListed(vendor)
    if not vendor then return false end
    local VD = HA.VendorData
    return not VD:IsVendorHiddenByNpcID(vendor.npcID) and not VD:IsHolidayVendorHidden(vendor.npcID)
        and not HA.VendorFilter.IsConfirmedNoDecor(vendor)
end

-- For an Endeavor vendor, whether this week's theme is its own: true only when the game has reported the
-- theme, false otherwise. nil for any other vendor.
function F.EndeavorActive(vendor)
    return HA.VendorData:IsEndeavorVendorActive(vendor)
end

-- Whether a listed vendor is selling now: an Endeavor vendor sells only in its theme's week.
function F.OnSale(vendor)
    return F.BrowserListed(vendor) and F.EndeavorActive(vendor) ~= false
end

-- The position the browser points this character to for a vendor, the one its waypoint uses: mapID, and the
-- client's zone and subzone names.
function F.Place(v)
    return HA.VendorFilter.GetVendorPlaceNames(v)
end

-- Where a vendor is: "subzone, zone" when both are known, else the zone; nil when there is none.
function F.Where(v)
    local _, zone, subzone = F.Place(v)
    return zone and subzone and L["%s, %s"]:format(subzone, zone) or zone
end

function F.QuestStart(questID)
    local row = HA.QuestStarts and HA.QuestStarts[questID]
    return row and row.mapID and row or nil
end

-- A quest's giver as { giver = ID, kind = "object" or "item" (an NPC has none), name = English name (not for an item) };
-- the row may have no spot.
function F.QuestGiver(questID)
    local row = HA.QuestStarts and HA.QuestStarts[questID]
    return row and row.giver and row or nil
end

function F.TreasureSpot(questID)
    return HA.TreasureHuntSpots and HA.TreasureHuntSpots[questID]
end

-- A quest's zone with no position, for grouping only: { mapID = zone map, turnIn = continent map, expansion = expansion key }
-- with each part optional. It never feeds a waypoint or a pin.
function F.QuestZone(questID)
    return HA.QuestZones and HA.QuestZones[questID]
end

-- The map a quest is grouped under: where it starts or its dig site, else its recorded zone; nil when unknown.
function F.QuestMap(questID)
    local at = F.TreasureSpot(questID) or F.QuestStart(questID)
    if at and at.mapID then return at.mapID end
    local zone = F.QuestZone(questID)
    return zone and zone.mapID
end

-- The player's zone: { zone, name, continent, maps = set of the zone and its child maps }; nil when unknown.
local here
function F.Here()
    local MPP = HA.MapPinProvider
    local zone = MPP.ZoneOf(C_Map.GetBestMapForUnit("player"))
    if not zone then return nil end
    if here and here.zone == zone then return here end
    local info = C_Map.GetMapInfo(zone)
    here = { zone = zone, name = info and info.name, continent = MPP.ContinentOf(zone), maps = { [zone] = true } }
    for _, kid in ipairs(C_Map.GetMapChildrenInfo(zone, nil, true) or {}) do here.maps[kid.mapID] = true end
    return here
end

-- 1 here, 2 on this continent, 3 elsewhere.
function F.Nearness(mapID, where)
    if not (where and mapID) then return 3 end
    if where.maps[mapID] then return 1 end
    local c = HA.MapPinProvider.ContinentOf(mapID)
    return (c and c == where.continent) and 2 or 3
end

-- The factions a faction stop names, as { { count, label } }: only those in seen (label -> count), the
-- vendor factions of the items it is about.
function F.FactionParts(seen)
    local out = {}
    for _, label in ipairs({ L["Alliance"], L["Horde"] }) do
        if seen and seen[label] then out[#out + 1] = { seen[label], label } end
    end
    return out
end

-- The same, for a sentence; nil with none seen.
function F.OtherFaction(seen)
    local p = F.FactionParts(seen)
    if p[2] then return L["%s or the %s"]:format(p[1][2], p[2][2]) end
    return p[1] and p[1][2]
end

-- A source's data type to its Sources type.
F.SOURCE_TYPE = {
    vendor = "vendors", achievement = "achievements", quest = "quests", profession = "professions",
    drop = "drops", event = "events", shop = "shop",
}

-- The game's own hyperlink for the source types it describes, by Sources type.
F.LINK = {
    achievements = function(d) return GetAchievementLink(d.achievementID) end,
    quests = function(d) return GetQuestLink(d.questID) or ("quest:" .. d.questID) end,
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
