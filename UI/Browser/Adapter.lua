-- Data adapter: every browser read of Homestead data goes through B.Data. Cache-only (no SavedVariables
-- writes, scans or ownership probes) apart from CatalogInfo's one pure catalog query.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L

local D = {}
B.Data = D

local EXPANSION_ORDER = {
    "Midnight", "The War Within", "Dragonflight", "Shadowlands", "Battle for Azeroth",
    "Legion", "Warlords of Draenor", "Mists of Pandaria", "Cataclysm",
    "Wrath of the Lich King", "The Burning Crusade", "Classic",
}

local EXPANSION_LABELS = {
    ["Midnight"] = L["Midnight"],
    ["The War Within"] = L["The War Within"],
    ["Dragonflight"] = L["Dragonflight"],
    ["Shadowlands"] = L["Shadowlands"],
    ["Battle for Azeroth"] = L["Battle for Azeroth"],
    ["Legion"] = L["Legion"],
    ["Warlords of Draenor"] = L["Warlords of Draenor"],
    ["Mists of Pandaria"] = L["Mists of Pandaria"],
    ["Cataclysm"] = L["Cataclysm"],
    ["Wrath of the Lich King"] = L["Wrath of the Lich King"],
    ["The Burning Crusade"] = L["The Burning Crusade"],
    ["Classic"] = L["Classic"],
    ["Events"] = L["Other Vendors"],
}

local FACTION_LABELS = {
    ["Alliance"] = L["Alliance"],
    ["Horde"] = L["Horde"],
}

-- Source types with their own format; any other gets a generic label.
local SOURCE_TYPE_LABELS = {
    ["shop"] = L["Shop"],
    ["treasure"] = L["Treasure"],
}

-- Recently Acquired: a firstSeen is baseline within this many seconds of the earliest, or when at least
-- BASELINE_CROWD owned records (itself included) fall within this many seconds either side of it.
local BASELINE_WINDOW = 30
local BASELINE_CROWD = 50

local cache = {}
-- Per requested item: true while loading, then "loaded" or "failed".
local nameLoads = {}

local memoVersion = 0

-- Drops the progress and recently-acquired results; the static expansion list stays.
function D.InvalidateMemos()
    cache.progress, cache.recent, cache.newSet = nil, nil, nil
    memoVersion = memoVersion + 1
end

-- Changes with every InvalidateMemos, so pages can drop their own memos too.
function D.MemoVersion()
    return memoVersion
end

function D.IsReady()
    return (HA.VendorData and HA.VendorIdentity and HA.CatalogStore and HA.SourceManager) and true or false
end

function D.OwnershipKnown()
    return (HA.CatalogStore and HA.CatalogStore:HasPersistedData()) and true or false
end

function D.IsOwned(itemID)
    return (HA.CatalogStore and HA.CatalogStore:IsOwned(itemID)) and true or false
end

function D.IsExcluded(itemID)
    return (HA.CatalogStore and HA.CatalogStore:IsOwnershipUnknowable(itemID)) and true or false
end

-- Hide owned removes nothing while ownership is unknown, nor a vendor with no knowable wares.
function D.HidesOwnedItem(itemID)
    return D.OwnershipKnown() and D.IsOwned(itemID)
end

function D.HidesOwnedVendor(owned, total)
    return D.OwnershipKnown() and total ~= nil and owned ~= nil and total > 0 and owned == total
end

function D.ItemName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if name then return name end
    if nameLoads[itemID] == nil then
        nameLoads[itemID] = true
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return nil
end

-- GET_ITEM_INFO_RECEIVED: true when awaited. Requested once, never retried.
function D.NameArrived(itemID, success)
    if nameLoads[itemID] ~= true then return false end
    nameLoads[itemID] = success == false and "failed" or "loaded"
    return true
end

function D.ItemIcon(itemID)
    return C_Item.GetItemIconByID(itemID) or B.Style.tex.placeholderIcon
end

function D.IsListedVendor(vendor)
    if HA.VendorFilter.ShouldHideVendor(vendor) then return false end
    local VD = HA.VendorData
    if VD.IsHolidayVendorHidden and VD:IsHolidayVendorHidden(vendor.npcID) then return false end
    local ED = HA.EndeavorsData
    if vendor.endeavor and ED and ED.IsVendorActive and not ED:IsVendorActive(vendor) then
        return false
    end
    return true
end

-- Holiday vendors show on Events in or out of season; IsListedVendor drops idle ones elsewhere.
local function HolidayEntries()
    return HA.EventSources and HA.EventSources.EventVendors or {}
end

-- true / false for a holiday vendor, nil for any other.
function D.HolidayActive(vendor)
    if not (vendor and HolidayEntries()[vendor.npcID]) then return nil end
    local VD = HA.VendorData
    return not (VD.IsHolidayVendorHidden and VD:IsHolidayVendorHidden(vendor.npcID))
end

function D.HolidayVendor(npcID)
    local entry = HolidayEntries()[npcID]
    if not entry then return nil end
    local vendor = {}
    for key, value in pairs(entry) do vendor[key] = value end
    vendor.items = entry.items or HA.VendorData:GetVendorItems(npcID)
    return vendor
end

function D.HolidayVendors()
    local out = {}
    for npcID in pairs(HolidayEntries()) do
        local vendor = D.HolidayVendor(npcID)
        if not HA.VendorFilter.ShouldHideVendor(vendor) then out[#out + 1] = vendor end
    end
    return out
end

function D.IsOppositeFaction(vendor)
    return HA.VendorFilter.IsOppositeFaction(vendor)
end

-- English data keys: known expansions newest first, then any other key, "Events" last.
function D.Expansions()
    if cache.expansions then return cache.expansions end
    local seen = {}
    for _, vendor in ipairs(HA.VendorIdentity:GetAllVendors()) do
        if vendor.expansion then seen[vendor.expansion] = true end
    end
    local ED = HA.EndeavorsData
    if ED and ED.Vendors then
        for _, vendor in pairs(ED.Vendors) do
            if vendor.expansion then seen[vendor.expansion] = true end
        end
    end
    local list = {}
    for _, exp in ipairs(EXPANSION_ORDER) do
        if seen[exp] then
            list[#list + 1] = exp
            seen[exp] = nil
        end
    end
    local other = {}
    for exp in pairs(seen) do
        if exp ~= "Events" then other[#other + 1] = exp end
    end
    table.sort(other)
    for _, exp in ipairs(other) do list[#list + 1] = exp end
    if seen["Events"] then list[#list + 1] = "Events" end
    cache.expansions = list
    return list
end

function D.ExpansionLabel(expansion)
    return EXPANSION_LABELS[expansion] or expansion
end

-- The label for the faction that makes this vendor opposite; nil when none resolves.
function D.VendorFactionLabel(vendor)
    local faction = HA.VendorFilter.GetEffectiveFaction(vendor)
    return faction and (FACTION_LABELS[faction] or faction) or nil
end

function D.VendorsByExpansion(expansion)
    local out = {}
    for _, vendor in ipairs(HA.VendorData:GetVendorsByExpansion(expansion)) do
        if D.IsListedVendor(vendor) then out[#out + 1] = vendor end
    end
    return out
end

-- An out-of-season holiday vendor still resolves here (GetVendor gives nil); vendor lists never use it.
function D.Vendor(npcID)
    return HA.VendorData:GetVendor(npcID) or D.HolidayVendor(npcID)
end

function D.ItemKnown(itemID)
    return HA.CatalogStore:GetDecorIDFromItemID(itemID) ~= nil
end

function D.VendorWares(vendor)
    return HA.VendorData:GetMergedItemIDs(vendor) or {}
end

-- The fill skips holiday vendors: compute theirs one per tick, then refresh once. Combat,
-- a new page or a closed window drops the queue.
local holidayWarm, holidayQueue, warmGen, draining = {}, {}, nil, false

local function DrainHoliday()
    local vendor = holidayQueue[1]
    if not vendor then
        draining = false
        return B.RequestRefresh(true)
    end
    if InCombatLockdown() or B.Generation() ~= warmGen then
        draining = false
        for i = #holidayQueue, 1, -1 do holidayWarm[table.remove(holidayQueue, i).npcID] = nil end
        return
    end
    table.remove(holidayQueue, 1)
    local BC = HA.BadgeCalculation
    HA.PerformanceTrace:Measure("browser_holiday_counts", nil, BC.GetVendorStats, BC, vendor, "all")
    C_Timer.After(0, DrainHoliday)
end

local function WarmHoliday(vendor)
    if holidayWarm[vendor.npcID] == memoVersion then return end
    holidayWarm[vendor.npcID] = memoVersion
    holidayQueue[#holidayQueue + 1] = vendor
    if not draining then
        draining, warmGen = true, B.Generation()
        C_Timer.After(0, DrainHoliday)
    end
end

-- collected, total over the vendor's knowable wares, from the map pins' cache. nil while cold, which asks
-- for the background fill unless noPrewarm (a fill-triggered refresh must not ask again).
function D.VendorCounts(vendor, noPrewarm)
    local BC = HA.BadgeCalculation
    if not (BC and vendor and vendor.npcID) or not D.OwnershipKnown() then return nil end
    local stats = BC:PeekVendorStats(vendor, "all")
    if not stats then
        if D.HolidayActive(vendor) ~= nil then WarmHoliday(vendor)
        elseif not noPrewarm then BC:RequestPrewarm("browser_vendor_list") end
        return nil
    end
    return stats.collected, stats.total
end

function D.VendorLocation(vendor)
    local coords, mapID = HA.VendorFilter.GetBestVendorCoordinates(vendor)
    if not (coords and mapID) then return nil end
    return mapID, coords.x, coords.y
end

-- Currencies the wares are priced in, as "|T..|t Name" strings; pending while a name loads, failed ones left out.
function D.VendorCurrencies(vendor, itemIDs)
    local SM = HA.SourceManager
    local out, seen, pending = {}, {}, false
    local function add(key, icon, name)
        if seen[key] then return end
        seen[key] = true
        out[#out + 1] = (icon and ("|T" .. icon .. ":0|t ") or "") .. name
    end
    for _, itemID in ipairs(itemIDs) do
        local cost = SM:GetVendorItemCost(itemID, vendor)
        if cost then
            if cost.gold and cost.gold > 0 then add("gold", nil, L["Gold"]) end
            for _, c in ipairs(cost.currencies or {}) do
                if c.id and not seen["c" .. c.id] then
                    local info = C_CurrencyInfo.GetCurrencyInfo(c.id)
                    local name = info and info.name or c.name
                    if name then add("c" .. c.id, info and info.iconFileID, name) end
                end
            end
            for _, it in ipairs(cost.items or {}) do
                if it.id and not seen["i" .. it.id] then
                    local name = D.ItemName(it.id) or it.name
                    if name then
                        add("i" .. it.id, C_Item.GetItemIconByID(it.id), name)
                    elseif nameLoads[it.id] ~= "failed" then
                        pending = true
                    end
                end
            end
        end
    end
    return out, pending
end

function D.VendorRequirements(vendor, itemIDs)
    local out = {}
    local factionLabel = D.VendorFactionLabel(vendor)
    if factionLabel then out[1] = factionLabel end
    if #itemIDs == 0 then return out end
    local common
    for _, itemID in ipairs(itemIDs) do
        local here = {}
        for _, r in ipairs(D.Requirements(itemID, vendor.npcID)) do here[r.text] = true end
        if common then
            for text in pairs(common) do
                if not here[text] then common[text] = nil end
            end
        else
            common = here
        end
        if not next(common) then return out end
    end
    for _, r in ipairs(D.Requirements(itemIDs[1], vendor.npcID)) do
        if common[r.text] then out[#out + 1] = r.text end
    end
    return out
end

-- Nearest-first vendors on this map and its children for the player's faction: vendors, mapID, mapName.
function D.NearYou()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return {}, nil, nil end
    local info = C_Map.GetMapInfo(mapID)
    local maps = { mapID }
    local kids = C_Map.GetMapChildrenInfo(mapID, nil, true)
    if kids then
        for _, kid in ipairs(kids) do maps[#maps + 1] = kid.mapID end
    end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    local continent, wx, wy
    if pos then
        local c, world = C_Map.GetWorldPosFromMapPos(mapID, pos)
        if world then continent, wx, wy = c, world:GetXY() end
    end

    local VF = HA.VendorFilter
    local seen, out = {}, {}
    for _, m in ipairs(maps) do
        for _, vendor in ipairs(HA.VendorData:GetVendorsInMap(m)) do
            local id = vendor.npcID
            if id and not seen[id] and D.IsListedVendor(vendor) and VF.CanAccessVendor(vendor) then
                seen[id] = true
                local dist = math.huge
                local coords, vmap = VF.GetBestVendorCoordinates(vendor)
                if continent and coords and vmap then
                    local vc, vworld = C_Map.GetWorldPosFromMapPos(vmap, CreateVector2D(coords.x, coords.y))
                    if vworld and vc == continent then
                        local vx, vy = vworld:GetXY()
                        dist = (vx - wx) ^ 2 + (vy - wy) ^ 2
                    end
                end
                out[#out + 1] = { vendor = vendor, dist = dist }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.dist ~= b.dist then return a.dist < b.dist end
        return (a.vendor.name or "") < (b.vendor.name or "")
    end)
    local vendors = {}
    for i, e in ipairs(out) do vendors[i] = e.vendor end
    return vendors, mapID, info and info.name
end

function D.Price(itemID, vendor)
    if not vendor then return nil end
    local cost = HA.SourceManager:GetVendorItemCost(itemID, vendor)
    if not cost then return nil end
    return HA.VendorData:FormatCost(cost)
end

-- state: owned | unlocked | locked | unknown. fresh also asks the catalog directly (no write), so the open
-- item page sees a purchase made since the last scan.
function D.ItemStatus(itemID, npcID, fresh)
    local out = { state = "unknown" }
    if D.IsExcluded(itemID) then
        out.excluded = true
        return out
    end
    if not D.OwnershipKnown() then return out end
    local pres = HA.SourceManager:GetItemPresentation(itemID, {
        context = "browser",
        npcID = npcID,
        isVendorContext = npcID ~= nil,
    })
    if not pres then return out end
    out.labels = pres.blockerLabels
    out.excluded = pres.isOwnershipExcluded
    local a = pres.availabilityState
    if pres.isOwnershipExcluded then
        out.state = "unknown"
    elseif pres.isOwned or a == "owned" then
        out.state = "owned"
    elseif a == "purchasable" or a == "available" then
        out.state = "unlocked"
    elseif a == "locked" or a == "blocked" or a == "unobtainable" then
        out.state = "locked"
    end
    if fresh and (out.state == "unlocked" or out.state == "locked")
            and HA.CatalogStore:IsOwnedFresh(itemID, true) then
        out.state = "owned"
    end
    return out
end

function D.RecordID(itemID, info)
    local entry = info and info.entryID
    if type(entry) == "table" and entry.recordID then return entry.recordID end
    local store = HA.CatalogStore
    return store.GetDecorIDFromItemID and store:GetDecorIDFromItemID(itemID) or nil
end

-- Shop note: seasonal and Endeavor vendors from data flags, else the vendor's own note (verbatim = true).
function D.VendorNote(vendor)
    if vendor.event then return L["Seasonal: %s"]:format(vendor.event) end
    if vendor.endeavor then
        local ED = HA.EndeavorsData
        local theme = ED and ED.GetThemeForVendor and ED:GetThemeForVendor(vendor)
        if theme then return L["Rotates with the %s Endeavor"]:format(theme) end
        return L["Rotates with neighborhood Endeavors"]
    end
    return vendor.notes, vendor.notes ~= nil
end

local function ReqText(req)
    local t = req.type
    if t == "reputation" then
        local standing = req.standing or L["Required"]
        local faction = req.faction or L["Unknown faction"]
        if standing:match("^Renown") then return L["%s %s"]:format(standing, faction) end
        return L["%s with %s"]:format(standing, faction)
    elseif t == "achievement" then
        return L["Achievement: %s"]:format(req.name or L["Unknown"])
    elseif t == "quest" then
        return L["Quest: %s"]:format(req.name or L["Unknown"])
    elseif t == "level" then
        return L["Level %s"]:format(tostring(req.level))
    elseif t == "promotion" then
        return L["Promotion: %s"]:format(req.name or L["Unknown"])
    elseif t == "professionRank" then
        return L["Profession: %s rank %s"]:format(tostring(req.profession), tostring(req.rank))
    elseif t == "profession" then
        return L["Profession: %s"]:format(tostring(req.profession))
    end
    return req.text or L["Other requirement"]
end

-- list of { text, met } where met is true / false / nil (cannot tell)
function D.Requirements(itemID, npcID)
    local SM = HA.SourceManager
    local out = {}
    for _, req in ipairs(SM:GetRequirements(itemID, npcID) or {}) do
        out[#out + 1] = { text = ReqText(req), met = SM:IsRequirementMet(req) }
    end
    return out
end

function D.ItemSources(itemID)
    local out = {}
    for _, src in ipairs(HA.SourceManager:GetAllSources(itemID) or {}) do
        local d = src.data or {}
        local e = { type = src.type }
        if src.type == "vendor" then
            e.npcID = d.npcID
            e.name = d.name
            e.zone = d.zone
            e.subzone = d.subzone
            e.faction = d.faction
            e.mapID = d.mapID
            e.x = d.coords and d.coords.x
            e.y = d.coords and d.coords.y
            e.price = d.cost and HA.VendorData:FormatCost(d.cost) or nil
        elseif src.type == "achievement" then
            e.achievementID = d.achievementID
            e.name = d.achievementName
        elseif src.type == "quest" then
            e.questID = d.questID
            e.name = d.questName
        elseif src.type == "profession" then
            e.name = d.recipeName
            e.profession = d.profession
            e.skillTier = d.skillTier
        elseif src.type == "drop" then
            e.name = d.mobName
            e.zone = d.zone
            if not (d.journalEncounterID or d.journalInstanceID) then
                e.mapID = d.mapID
                e.x = d.coords and d.coords.x
                e.y = d.coords and d.coords.y
            end
            e.notes = d.notes
        elseif src.type == "event" then
            e.name = d.event
            e.vendorName = d.vendorName
            e.zone = d.zone
            e.mapID = d.mapID
            e.x = d.x
            e.y = d.y
        else
            e.name = d.name
        end
        out[#out + 1] = e
    end
    return out
end

function D.ItemVendorWaypoint(itemID)
    local src = HA.SourceManager:GetVendorSource(itemID)
    if not (src and src.vendor) then return nil end
    local coords, mapID = HA.VendorFilter.GetBestVendorCoordinates(src.vendor)
    if not (coords and mapID) then return nil end
    return { mapID = mapID, x = coords.x, y = coords.y, title = src.name }
end

-- Housing catalog entry. The router empties catalogMemo on a page show or new data.
function D.CatalogInfo(itemID, catalogMemo)
    if catalogMemo and catalogMemo[itemID] then return catalogMemo[itemID] end
    local info
    local ok, result = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, itemID, true)
    if ok then info = result end
    if not info and HA.CatalogStore.GetDecorIDFromItemID then
        local decorID = HA.CatalogStore:GetDecorIDFromItemID(itemID)
        if decorID then
            local ok2, result2 = pcall(C_HousingCatalog.GetCatalogEntryInfoByRecordID, 1, decorID, true)
            if ok2 then info = result2 end
        end
    end
    if catalogMemo and info then catalogMemo[itemID] = info end
    return info
end

-- Collection totals over the shipped decor list, inclusive per source kind; nil while data is not loaded.
function D.Progress()
    local known = D.OwnershipKnown()
    local cached = cache.progress
    if cached and cached.known == known then return cached end
    local map = HA.DecorMapping
    if not (map and D.IsReady()) then return nil end
    local VD = HA.VendorData
    local keys = { "vendors", "achievements", "quests", "professions", "drops", "events" }
    local r = { known = known, total = 0, owned = 0, src = {} }
    for _, k in ipairs(keys) do r.src[k] = { total = 0, owned = 0 } end
    local function add(k, owned)
        local s = r.src[k]
        s.total = s.total + 1
        if owned then s.owned = s.owned + 1 end
    end
    local seen = {}
    for _, itemID in pairs(map) do
        if not seen[itemID] then
            seen[itemID] = true
            local owned = known and D.IsOwned(itemID)
            r.total = r.total + 1
            if owned then r.owned = r.owned + 1 end
            if VD:HasOfferForItem(itemID) then add("vendors", owned) end
            if HA.AchievementSources and HA.AchievementSources[itemID] then add("achievements", owned) end
            if HA.QuestSources and HA.QuestSources[itemID] then add("quests", owned) end
            if HA.ProfessionSources and HA.ProfessionSources[itemID] then add("professions", owned) end
            if HA.DropSources and HA.DropSources[itemID] then add("drops", owned) end
            if HA.EventSources and HA.EventSources[itemID] then add("events", owned) end
        end
    end
    cache.progress = r
    return r
end

-- Rows: { kind = "row", itemID, name, line2, achievementID, questID, wp, wpFromVendor }; Events adds vendor rows first.
function D.SourceList(kind, search, hideOwned)
    local rows = {}
    local function gather(tbl, build)
        for itemID, d in pairs(tbl or {}) do
            if type(itemID) == "number" then
                local row = build(itemID, d)
                row.kind = "row"
                row.itemID = itemID
                rows[#rows + 1] = row
            end
        end
    end

    if kind == "achievements" then
        gather(HA.AchievementSources, function(_, d)
            return {
                group = d.category or L["Other"], sortName = d.achievementName,
                achievementID = d.achievementID,
                line2 = GetAchievementLink(d.achievementID) or d.achievementName,
            }
        end)
    elseif kind == "quests" then
        gather(HA.QuestSources, function(_, d)
            return {
                sortName = d.questName, questID = d.questID, wpFromVendor = true,
                line2 = GetQuestLink(d.questID) or d.questName,
            }
        end)
    elseif kind == "professions" then
        gather(HA.ProfessionSources, function(_, d)
            local line = L["%s - %s"]:format(d.profession, d.recipeName)
            if d.skillLevel then line = L["%s (%s)"]:format(line, d.skillLevel) end
            return { group = d.profession, sortName = d.recipeName, line2 = line }
        end)
    elseif kind == "drops" then
        gather(HA.DropSources, function(_, d)
            local row = { sortName = d.mobName, line2 = L["%s - %s"]:format(d.mobName, d.zone or L["Unknown"]) }
            -- A journal-anchored drop's mapID is an area ID, not a uiMapID: no waypoint.
            if d.mapID and d.coords and not (d.journalEncounterID or d.journalInstanceID) then
                row.wp = { mapID = d.mapID, x = d.coords.x, y = d.coords.y, title = d.mobName }
            end
            return row
        end)
    elseif kind == "events" then
        gather(HA.EventSources, function(_, d)
            local row = {
                group = d.event, sortName = (d.vendorName or "") .. " " .. d.event,
                line2 = L["%s - %s"]:format(d.vendorName or L["Unknown"], d.zone or L["Unknown"]),
            }
            if d.mapID and d.x and d.y then
                row.wp = { mapID = d.mapID, x = d.x, y = d.y, title = d.vendorName }
            end
            return row
        end)
    end

    local q = search and search ~= "" and search:lower() or nil
    local filtered = {}
    for _, row in ipairs(rows) do
        row.name = D.ItemName(row.itemID)
        local keep = not (hideOwned and D.HidesOwnedItem(row.itemID))
        if keep and q then
            local hay = ((row.name or "") .. " " .. (row.sortName or "")):lower()
            keep = hay:find(q, 1, true) ~= nil
        end
        if keep then filtered[#filtered + 1] = row end
    end
    if kind == "events" then
        for _, vendor in ipairs(D.HolidayVendors()) do
            local hay = ((vendor.name or "") .. " " .. (vendor.zone or "") .. " " .. vendor.event):lower()
            local keep = q == nil or hay:find(q, 1, true) ~= nil
            if keep and hideOwned then keep = not D.HidesOwnedVendor(D.VendorCounts(vendor, true)) end
            if keep then
                filtered[#filtered + 1] = {
                    kind = "vendor", vendor = vendor, active = D.HolidayActive(vendor),
                    group = vendor.event, sortName = vendor.name,
                }
            end
        end
    end
    table.sort(filtered, function(a, b)
        local ga, gb = a.group or "", b.group or ""
        if ga ~= gb then return ga < gb end
        local va, vb = a.kind == "vendor", b.kind == "vendor"
        if va ~= vb then return va end
        local na, nb = a.sortName or "", b.sortName or ""
        if na ~= nb then return na < nb end
        return (a.itemID or a.vendor.npcID) < (b.itemID or b.vendor.npcID)
    end)

    local out, last = {}, nil
    for _, row in ipairs(filtered) do
        if row.group and row.group ~= last then
            last = row.group
            out[#out + 1] = { kind = "header", text = row.group }
        end
        out[#out + 1] = row
    end
    return out
end

function D.SourceLine(itemID, sources)
    local src = (sources or D.ItemSources(itemID))[1]
    if not src then return L["Source unknown"] end
    local t = src.type
    local name = src.name or L["Unknown"]
    if t == "vendor" then
        local place = src.zone
        if src.subzone then place = L["%s, %s"]:format(src.subzone, src.zone or L["Unknown"]) end
        if place then return L["Vendor: %s, %s"]:format(name, place) end
        return L["Vendor: %s"]:format(name)
    elseif t == "achievement" then
        return L["Achievement: %s"]:format(name)
    elseif t == "quest" then
        return L["Quest: %s"]:format(name)
    elseif t == "profession" then
        return L["Crafted: %s - %s"]:format(src.profession or L["Unknown"], name)
    elseif t == "drop" then
        if src.zone then return L["Drops from %s (%s)"]:format(name, src.zone) end
        return L["Drops from %s"]:format(name)
    elseif t == "event" then
        if src.vendorName then return L["Event: %s - %s"]:format(name, src.vendorName) end
        return L["Event: %s"]:format(name)
    end
    return L["%s: %s"]:format(SOURCE_TYPE_LABELS[t] or L["Other source"], name)
end

-- Owned, non-baseline decor, newest first: { itemID, acquired (CatalogStore's firstSeen) }.
local function RecentList()
    if cache.recent then return cache.recent end
    local store, map = HA.CatalogStore, HA.DecorMapping
    if not (store and map and D.OwnershipKnown()) then return {} end

    local recs, seen = {}, {}
    for _, itemID in pairs(map) do
        if type(itemID) == "number" and not seen[itemID] then
            seen[itemID] = true
            local rec = store:Get(itemID)
            local t = rec and rec.isOwned and rec.firstSeen
            if type(t) == "number" then recs[#recs + 1] = { itemID = itemID, acquired = t } end
        end
    end
    table.sort(recs, function(a, b)
        if a.acquired ~= b.acquired then return a.acquired < b.acquired end
        return a.itemID < b.itemID
    end)

    local list = {}
    local n = #recs
    local t0 = n > 0 and recs[1].acquired
    local lo, hi = 1, 1
    for i = 1, n do
        local t = recs[i].acquired
        while recs[lo].acquired < t - BASELINE_WINDOW do lo = lo + 1 end
        if hi < i then hi = i end
        while hi < n and recs[hi + 1].acquired <= t + BASELINE_WINDOW do hi = hi + 1 end
        if t - t0 > BASELINE_WINDOW and hi - lo + 1 < BASELINE_CROWD then
            list[#list + 1] = recs[i]
        end
    end
    for i = 1, math.floor(#list / 2) do
        list[i], list[#list + 1 - i] = list[#list + 1 - i], list[i]
    end
    cache.recent = list
    return list
end

function D.RecentlyAcquired(count)
    local list = RecentList()
    local out = {}
    for i = 1, math.min(count, #list) do out[i] = list[i] end
    return out
end

function D.IsNew(itemID)
    if not cache.newSet then
        local fx = B.Style.itemFx
        local cutoff = time() - fx.newWindowDays * 86400
        local set = {}
        for _, r in ipairs(D.RecentlyAcquired(fx.newTop)) do
            if r.acquired >= cutoff then set[r.itemID] = true end
        end
        cache.newSet = set
    end
    return cache.newSet[itemID] == true
end

-- Quality and owned copies (placed + stored) for an icon's glow and number; copies is nil until known, and at 0.
function D.IconData(itemID, wantCopies, catalogMemo)
    local quality, copies
    if wantCopies then
        local info = D.CatalogInfo(itemID, catalogMemo)
        quality = info and info.quality
        if info and D.OwnershipKnown() then
            local n = (info.totalNumPlaced or 0) + (info.totalNumStored or 0)
            if n > 0 then copies = n end
        end
    end
    return quality or C_Item.GetItemQualityByID(itemID), copies
end

-- Everything the item tooltip shows. counts is nil until ownership and the catalog entry are known;
-- before storage loads they read 0 for owned items.
function D.TooltipData(itemID, npcID, catalogMemo)
    local info = D.CatalogInfo(itemID, catalogMemo)
    local st = D.ItemStatus(itemID, npcID)
    local out = {
        name = D.ItemName(itemID) or (info and info.name) or L["Item %d"]:format(itemID),
        quality = info and info.quality or C_Item.GetItemQualityByID(itemID),
        state = st.state,
    }
    if info and D.OwnershipKnown() then
        out.counts = {
            placed = info.totalNumPlaced or 0,
            stored = info.totalNumStored or 0,
            redeemable = info.remainingRedeemable or 0,
        }
    end
    local sources = D.ItemSources(itemID)
    if npcID then out.price = D.Price(itemID, D.Vendor(npcID)) end
    if not out.price then
        for _, src in ipairs(sources) do
            if src.type == "vendor" and src.price then
                out.price = src.price
                break
            end
        end
    end
    out.source = D.SourceLine(itemID, sources)
    return out
end
