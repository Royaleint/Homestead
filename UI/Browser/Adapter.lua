-- Data adapter: every browser read of Homestead data goes through B.Data. Cache-only (no SavedVariables
-- writes, scans or ownership probes) apart from CatalogInfo's one pure catalog query.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L

local D = {}
B.Data = D

local FACTION_LABELS = {
    ["Alliance"] = L["Alliance"],
    ["Horde"] = L["Horde"],
}

-- Source types with their own format; any other gets a generic label.
local SOURCE_TYPE_LABELS = {
    ["shop"] = L["Shop"],
    ["treasure"] = L["Treasure"],
}

-- Per requested item: true while loading, then "loaded" or "failed".
local nameLoads = {}

local memoVersion = 0

-- Starts a new memo generation: the walk and every memo keyed on MemoVersion rebuild on next read.
function D.InvalidateMemos()
    memoVersion = memoVersion + 1
end

-- Changes with every InvalidateMemos, so callers can drop their own memos too.
function D.MemoVersion()
    return memoVersion
end

function D.IsReady()
    return (HA.VendorData and HA.VendorIdentity and HA.CatalogStore and HA.SourceManager) and true or false
end

function D.IsExcluded(itemID)
    return (HA.CatalogStore and HA.CatalogStore:IsOwnershipUnknowable(itemID)) and true or false
end

-- info, the item's catalog entry when the caller has it, supplies the name while the item loads.
function D.ItemName(itemID, info)
    local name = C_Item.GetItemNameByID(itemID) or (info and info.name)
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

-- A scan confirmed it sells no decor. Static vendors are never dropped, and holiday vendors skip this.
local function ConfirmedNoDecor(vendor)
    if vendor._isEventVendor or not vendor.npcID then return false end
    local db = HA.Addon.db.global
    local entry = db.noDecorVendors and db.noDecorVendors[vendor.npcID]
    return entry ~= nil and entry.scanConfidence == "confirmed" and not HA.VendorData:HasVendor(vendor.npcID)
end

-- The browser's vendor lists: its listing rule, ignoring the map pin settings, less confirmed no-decor vendors.
function D.IsListedVendor(vendor)
    return B.Facts.BrowserListed(vendor) and not ConfirmedNoDecor(vendor)
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

-- Every holiday vendor, in season or not; the pin setting never applies here.
function D.HolidayVendors()
    local VF, out = HA.VendorFilter, {}
    for npcID in pairs(HolidayEntries()) do
        local vendor = D.HolidayVendor(npcID)
        if not vendor.removed and not (vendor.unreleased and not VF.ShouldRevealUnreleasedVendors()) then
            out[#out + 1] = vendor
        end
    end
    return out
end

function D.IsOppositeFaction(vendor)
    return HA.VendorFilter.IsOppositeFaction(vendor)
end

-- The label for the faction that makes this vendor opposite; nil when none resolves.
function D.VendorFactionLabel(vendor)
    local faction = HA.VendorFilter.GetEffectiveFaction(vendor)
    return faction and (FACTION_LABELS[faction] or faction) or nil
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
    if not (BC and vendor and vendor.npcID) or D.CollectionState() ~= "ready" then return nil end
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

-- Nearest-first vendors in the player's zone and its child maps for their faction: vendors, zone, zone name.
function D.NearYou()
    local where = B.Facts.Here()
    if not where then return {}, nil, nil end
    local mapID = where.zone

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    local continent, wx, wy
    if pos then
        local c, world = C_Map.GetWorldPosFromMapPos(mapID, pos)
        if world then continent, wx, wy = c, world:GetXY() end
    end

    local VF = HA.VendorFilter
    local seen, out = {}, {}
    for m in pairs(where.maps) do
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
    return vendors, mapID, where.name
end

function D.Price(itemID, vendor)
    if not vendor then return nil end
    local cost = HA.SourceManager:GetVendorItemCost(itemID, vendor)
    if not cost then return nil end
    return HA.VendorData:FormatCost(cost)
end

-- state: owned | unlocked | locked | unknown. Owned and unknown come from OwnState. fresh also asks the
-- catalog directly (no write), so the open item page sees a purchase made since the last scan.
function D.ItemStatus(itemID, npcID, fresh)
    local out = { state = "unknown" }
    if D.IsExcluded(itemID) then
        out.excluded = true
        return out
    end
    local own = D.OwnState(itemID, D.CatalogInfo(itemID, B.State and B.State.catalogMemo))
    if own ~= "notOwned" then
        if own == "owned" then out.state = "owned" end
        return out
    end
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

-- Collection totals over the shipped decor list, inclusive per source kind (Shop included): the walk's
-- { known, total, owned, src = { [kind] = { total, owned } } }. nil until the collection is ready.
function D.Progress()
    local walk = D.IsReady() and B.CanGet.Walk()
    return walk and walk.progress or nil
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

-- Quality and owned copies (placed + stored) for an icon; copies is nil until known, and at 0.
function D.IconData(itemID, wantCopies, catalogMemo)
    local quality, copies
    if wantCopies then
        local info = D.CatalogInfo(itemID, catalogMemo)
        quality = info and info.quality
        if info and D.CollectionState() == "ready" then
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
    if info and D.CollectionState() == "ready" then
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
