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

local SOURCE_TYPE_LABELS = {
    ["shop"] = L["Shop"],
    ["treasure"] = L["Treasure"],
}

local nameLoads = {}

local memoVersion = 0

local listed, homes, perVendor = nil, nil, {}

function D.InvalidateMemos()
    memoVersion, listed, homes, perVendor = memoVersion + 1, nil, nil, {}
end

function D.MemoVersion()
    return memoVersion
end

function D.IsReady()
    return (HA.VendorData and HA.VendorIdentity and HA.CatalogStore and HA.SourceManager) and true or false
end

function D.ItemName(itemID, info)
    local name = C_Item.GetItemNameByID(itemID) or (info and info.name)
    if name then return name end
    if nameLoads[itemID] == nil then
        nameLoads[itemID] = true
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return nil
end

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

-- Newest first, each with its LE_EXPANSION_ name.
local EXPANSIONS = {
    { "Midnight", "MIDNIGHT" }, { "The War Within", "WAR_WITHIN" }, { "Dragonflight", "DRAGONFLIGHT" },
    { "Shadowlands", "SHADOWLANDS" }, { "Battle for Azeroth", "BATTLE_FOR_AZEROTH" }, { "Legion", "LEGION" },
    { "Warlords of Draenor", "WARLORDS_OF_DRAENOR" }, { "Mists of Pandaria", "MISTS_OF_PANDARIA" },
    { "Cataclysm", "CATACLYSM" }, { "Wrath of the Lich King", "WRATH_OF_THE_LICH_KING" },
    { "The Burning Crusade", "BURNING_CRUSADE" }, { "Classic", "CLASSIC" },
}
local TOKEN = {}
for _, e in ipairs(EXPANSIONS) do TOKEN[e[1]] = e[2] end

-- Vendor tables only, one per vendor key, rebuilt after each InvalidateMemos.
function D.ListedVendors()
    if listed then return listed end
    listed = {}
    local seen = {}
    for _, v in ipairs(HA.VendorData:GetAllVendors()) do
        local key = D.IsListedVendor(v) and B.Facts.SourceKey("vendors", v)
        if key and not seen[key] then
            seen[key] = true
            listed[#listed + 1] = v
        end
    end
    return listed
end

function D.VendorHome(vendor)
    return TOKEN[vendor.expansion] and vendor.expansion or "other"
end

function D.Expansions()
    local vendors = D.ListedVendors()
    if homes then return homes end
    local has = {}
    for _, v in ipairs(vendors) do has[D.VendorHome(v)] = true end
    homes = {}
    for _, e in ipairs(EXPANSIONS) do
        if has[e[1]] then homes[#homes + 1] = e[1] end
    end
    if has.other then homes[#homes + 1] = "other" end
    return homes
end

function D.ExpansionLabel(key)
    if key == "other" then return L["Other Vendors"] end
    local token = TOKEN[key]
    return token and _G["EXPANSION_NAME" .. tostring(_G["LE_EXPANSION_" .. token])] or key
end

local function HolidayEntries()
    return HA.EventSources and HA.EventSources.EventVendors or {}
end

function D.HolidayActive(vendor)
    local entry = vendor and HolidayEntries()[vendor.npcID]
    if not entry then return nil end
    local CD = HA.CalendarDetector
    return entry.event ~= nil and CD ~= nil and CD:IsHolidayActive(entry.event) == true
end

function D.HolidayVendor(npcID)
    local entry = HolidayEntries()[npcID]
    if not entry then return nil end
    local vendor = {}
    for key, value in pairs(entry) do vendor[key] = value end
    vendor.items = entry.items or HA.VendorData:GetVendorItems(npcID)
    return vendor
end

function D.IsOppositeFaction(vendor)
    return HA.VendorFilter.IsOppositeFaction(vendor)
end

function D.VendorFactionLabel(vendor)
    local faction = HA.VendorFilter.GetEffectiveFaction(vendor)
    return faction and (FACTION_LABELS[faction] or faction) or nil
end

-- An out-of-season holiday vendor still resolves here (GetVendor gives nil); vendor lists never use it.
function D.Vendor(npcID)
    return HA.VendorData:GetVendor(npcID) or D.HolidayVendor(npcID)
end

local function Memo(npcID)
    local k = npcID or 0
    perVendor[k] = perVendor[k] or {}
    return perVendor[k]
end

local function Knowable(npcID, ids)
    local store, SM, out = HA.CatalogStore, HA.SourceManager, {}
    for _, id in ipairs(ids) do
        if not store:IsOwnershipUnknowable(id) and (store:IsOwned(id) == true
                or SM:GetVendorItemAvailabilityState(id, npcID, true) ~= "unobtainable") then
            out[#out + 1] = id
        end
    end
    return out
end

-- What the map pins count: knowable ownership, less unowned wares it can never sell (promotions).
function D.VendorWares(vendor)
    local m = Memo(vendor.npcID)
    if not m.wares then
        local ids = HA.VendorData:GetMergedItemIDs(vendor) or {}
        m.wares = HA.PerformanceTrace:Measure("browser_vendor_wares", #ids, Knowable, vendor.npcID, ids)
    end
    return m.wares
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
-- for the background fill unless noPrewarm or the browser's refresh says not to (a fill-triggered refresh
-- must not ask again).
function D.VendorCounts(vendor, noPrewarm)
    local BC = HA.BadgeCalculation
    if not (BC and vendor and vendor.npcID) or D.CollectionState() ~= "ready" then return nil end
    local stats = BC:PeekVendorStats(vendor, "all")
    if not stats then
        if D.HolidayActive(vendor) ~= nil then WarmHoliday(vendor)
        elseif not (noPrewarm or (B.State and B.State.noPrewarm)) then BC:RequestPrewarm("browser_vendor_list") end
        return nil
    end
    return stats.collected, stats.total
end

function D.VendorLocation(vendor)
    local coords, mapID = HA.VendorFilter.GetBestVendorCoordinates(vendor)
    if not (coords and mapID) then return nil end
    return mapID, coords.x, coords.y
end

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

-- A cost as text. Each part this character can't pay is red, judged by CanGet's wallet.
local NO_PARTS = {}
local function AddPart(parts, part)
    local text = HA.VendorData:FormatCost(part)
    if not text then return end
    local S = B.Style
    parts[#parts + 1] = B.CanGet.IsShort(part) and S.Colored(S.color.stop, text) or text
end

function D.PriceOf(cost)
    if not cost then return nil end
    if not B.CanGet.IsShort(cost) then return HA.VendorData:FormatCost(cost) end
    local parts = {}
    if (cost.gold or 0) > 0 then AddPart(parts, { gold = cost.gold }) end
    for _, c in ipairs(cost.currencies or NO_PARTS) do AddPart(parts, { currencies = { c } }) end
    for _, c in ipairs(cost.items or NO_PARTS) do AddPart(parts, { items = { c } }) end
    return parts[1] and table.concat(parts, " + ")
end

function D.Price(itemID, vendor)
    if not vendor then return nil end
    return D.PriceOf(HA.SourceManager:GetVendorItemCost(itemID, vendor))
end

-- A vendor source's cost: its own, else the resolver's. The shown price and the Price sort both read it.
function D.SourceCost(itemID, data)
    return data.cost or data.vendor and (HA.SourceManager:GetVendorItemCost(itemID, data.vendor))
end

-- Another character's biggest holding of a currency, from account data already received: its name (the full
-- name when two results share one) and amount. Nothing when the data is not ready or no one else holds any.
function D.OtherHolder(currencyID)
    if not C_CurrencyInfo.IsAccountCharacterCurrencyDataReady() then return nil end
    local rows = C_CurrencyInfo.FetchCurrencyDataFromAccountCharacters(currencyID) or NO_PARTS
    local me, best = UnitGUID("player"), nil
    for _, r in ipairs(rows) do
        if r.characterGUID ~= me and r.quantity > 0 and (not best or r.quantity > best.quantity) then best = r end
    end
    if not best then return nil end
    for _, r in ipairs(rows) do
        if r ~= best and r.characterName == best.characterName then return best.fullCharacterName, best.quantity end
    end
    return best.characterName, best.quantity
end

function D.RecordID(itemID, info)
    local entry = info and info.entryID
    if type(entry) == "table" and entry.recordID then return entry.recordID end
    local store = HA.CatalogStore
    return store.GetDecorIDFromItemID and store:GetDecorIDFromItemID(itemID) or nil
end

-- Data-error report text. r = { itemID, name, recordID, build, buildNumber, version,
-- vendors = { { npcID, name, zone, mapID, x, y } } }.
function D.ReportText(r)
    local out = {
        L["Item: %s (%d)"]:format(r.name or "?", r.itemID),
        L["Record ID: %s"]:format(r.recordID and tostring(r.recordID) or L["none"]),
    }
    for _, v in ipairs(r.vendors) do
        local where = L["no location"]
        if v.mapID and v.x and v.y then
            where = L["map %d at %.1f, %.1f"]:format(v.mapID, v.x * 100, v.y * 100)
        end
        out[#out + 1] = L["Vendor %d: %s, %s, %s"]:format(v.npcID, v.name or L["Unknown"],
            v.zone or L["Unknown"], where)
    end
    out[#out + 1] = L["Client: %s (%s)"]:format(r.build or "?", r.buildNumber or "?")
    out[#out + 1] = L["Homestead: %s"]:format(r.version or "?")
    return table.concat(out, "\n")
end

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

-- Pending (and not memoised) while an item currency's name loads.
function D.VendorCurrencies(vendor)
    local m = Memo(vendor.npcID)
    if m.cur then return m.cur, false end
    local out, seen, pending = {}, {}, false
    local function add(icon, name)
        if name and not seen[name] then
            seen[name] = true
            out[#out + 1] = (icon and "|T" .. icon .. ":0|t " or "") .. name
        end
    end
    for _, id in ipairs(D.VendorWares(vendor)) do
        local cost = HA.SourceManager:GetVendorItemCost(id, vendor) or {}
        if (cost.gold or 0) > 0 then add(nil, L["Gold"]) end
        for _, c in ipairs(cost.currencies or {}) do
            local info = c.id and C_CurrencyInfo.GetCurrencyInfo(c.id) or c
            add(info.iconFileID, info.name or c.name)
        end
        for _, it in ipairs(cost.items or {}) do
            local name = it.id and D.ItemName(it.id) or it.name
            if name then add(it.id and C_Item.GetItemIconByID(it.id), name)
            elseif it.id and nameLoads[it.id] ~= "failed" then pending = true end
        end
    end
    if not pending then m.cur = out end
    return out, pending
end

function D.VendorRequirements(vendor)
    local m = Memo(vendor.npcID)
    if m.reqs then return m.reqs end
    local out
    for _, id in ipairs(D.VendorWares(vendor)) do
        local reqs, here = D.Requirements(id, vendor.npcID), {}
        if not out then out = reqs end
        for _, r in ipairs(reqs) do here[r.text] = true end
        for i = #out, 1, -1 do
            if not here[out[i].text] then table.remove(out, i) end
        end
        if not out[1] then break end
    end
    m.reqs = out or {}
    return m.reqs
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
            e.price = D.PriceOf(D.SourceCost(itemID, d))
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

function D.SourceLine(itemID, sources)
    local src = (sources or D.ItemSources(itemID))[1]
    if not src then return L["Source unknown"] end
    local t = src.type
    if t == "vendor" and not src.name then src = src.npcID and D.Vendor(src.npcID) or {} end
    local name = src.name or L["Unknown"]
    if t == "vendor" then
        if not src.name then return L["A vendor"] end
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
    local out = {
        name = D.ItemName(itemID) or (info and info.name) or L["Item %d"]:format(itemID),
        quality = info and info.quality or C_Item.GetItemQualityByID(itemID),
    }
    if info and D.CollectionState() == "ready" then
        out.counts = {
            placed = info.totalNumPlaced or 0,
            stored = info.totalNumStored or 0,
            redeemable = info.remainingRedeemable or 0,
        }
    end
    local p = npcID and { type = "vendor", npcID = npcID } or B.CanGet.Primary(itemID)
    local v = p and p.type == "vendor" and p.npcID and D.Vendor(p.npcID)
    out.price = npcID and D.Price(itemID, v) or p and p.price
    out.source = D.SourceLine(itemID, { p })
    out.unconfirmed = v and not B.Facts.Confirmed(v) or nil
    out.active = v and D.HolidayActive(v) and v.event or nil
    local e = B.CanGet.Entry(itemID)
    out.bonus = e and e.bonus or nil
    return out
end
