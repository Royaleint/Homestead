-- Data adapter: every browser read of Homestead data goes through B.Data. Cache-only (no SavedVariables
-- writes, scans or ownership probes); catalog entries and ownership come from CatalogStore's shared read.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L

local D = {}
B.Data = D

local FACTION_LABELS = {
    ["Alliance"] = L["Alliance"],
    ["Horde"] = L["Horde"],
}

-- Moves whenever an asked-for name arrives, so a page that sorted or searched by name can tell.
local nameGen = 0

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
    return (HA.GetItemName(itemID, info and info.name))
end

function D.NameArrived(itemID, success)
    if not HA.ItemNameArrived(itemID, success) then return false end
    nameGen = nameGen + 1
    return true
end

function D.NameGen()
    return nameGen
end

function D.ItemIcon(itemID)
    return C_Item.GetItemIconByID(itemID) or B.Style.tex.placeholderIcon
end

-- The browser's vendor lists: its listing rule, ignoring the map pin settings.
function D.IsListedVendor(vendor)
    return B.Facts.BrowserListed(vendor)
end

-- Expansion name to its LE_EXPANSION_ token, from the shared newest-first order, built on first use.
local TOKEN
local function Tokens()
    if not TOKEN then
        TOKEN = {}
        for _, e in ipairs(HA.Constants.EXPANSION_ORDER) do TOKEN[e[1]] = e[2] end
    end
    return TOKEN
end

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
    return Tokens()[vendor.expansion] and vendor.expansion or "other"
end

function D.Expansions()
    local vendors = D.ListedVendors()
    if homes then return homes end
    local has = {}
    for _, v in ipairs(vendors) do has[D.VendorHome(v)] = true end
    homes = {}
    for _, e in ipairs(HA.Constants.EXPANSION_ORDER) do
        if has[e[1]] then homes[#homes + 1] = e[1] end
    end
    if has.other then homes[#homes + 1] = "other" end
    return homes
end

-- The expansion's place in the newest-first order, or nil.
function D.ExpansionRank(key)
    for i, e in ipairs(HA.Constants.EXPANSION_ORDER) do
        if e[1] == key then return i end
    end
end

function D.ExpansionLabel(key)
    if key == "other" then return L["Other Vendors"] end
    local token = Tokens()[key]
    return token and _G["EXPANSION_NAME" .. tostring(_G["LE_EXPANSION_" .. token])] or key
end

function D.HolidayActive(vendor)
    local event = vendor and HA.VendorData:GetHolidayEvent(vendor.npcID)
    if not event then return nil end
    local CD = HA.CalendarDetector
    return CD ~= nil and CD:IsHolidayActive(event) == true
end

-- True when this character can use the vendor at none of its positions.
function D.IsOppositeFaction(vendor)
    return not HA.VendorFilter.CanUseVendor(vendor)
end

-- The faction (or two) that can use a vendor this character can't; nil when it can.
function D.VendorFactionLabel(vendor)
    local usable, a, b = HA.VendorFilter.CanUseVendor(vendor)
    if usable then return nil end
    a = FACTION_LABELS[a] or a
    return b and L["%s, %s"]:format(a, FACTION_LABELS[b] or b) or a
end

-- An out-of-season holiday vendor still resolves here (GetVendor gives nil); vendor lists never use it.
function D.Vendor(npcID)
    return HA.VendorData:GetVendorAnySeason(npcID)
end

local function Memo(npcID)
    local k = npcID or 0
    perVendor[k] = perVendor[k] or {}
    return perVendor[k]
end

-- What the map pins count: knowable ownership, less unowned wares it can never sell (promotions).
function D.VendorWares(vendor)
    return HA.BadgeCalculation:GetCountedItemIDs(vendor)
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
    local coords, mapID = HA.VendorFilter.GetUsableVendorCoordinates(vendor)
    if not (coords and mapID) then return nil end
    return mapID, coords.x, coords.y
end

function D.NearYou()
    local where = B.Facts.Here()
    if not where then return {}, nil, nil end
    local mapID = where.zone

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    local VF = HA.VendorFilter
    local seen, out = {}, {}
    for m in pairs(where.maps) do
        for _, vendor in ipairs(HA.VendorData:GetVendorsInMap(m)) do
            local id = vendor.npcID
            if id and not seen[id] and B.Facts.OnSale(vendor) and VF.CanAccessVendor(vendor) then
                seen[id] = true
                local dist = math.huge
                local coords, vmap = VF.GetBestVendorCoordinates(vendor)
                if pos and coords and vmap then
                    dist = HA.VendorData:GetWorldDistance(mapID, pos, vmap, CreateVector2D(coords.x, coords.y)) or dist
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

-- A vendor source's cost: its own, else the resolver's. Read for a listed vendor's shown price and sort.
function D.SourceCost(itemID, data)
    return data.cost or data.vendor and (HA.SourceManager:GetVendorItemCost(itemID, data.vendor))
end

-- A room plan's catalog entry is a room, found by the room index; its record ID is not a decor ID.
function D.RoomID(itemID)
    local store = HA.CatalogStore
    return store.GetRoomIDFromItemID and store:GetRoomIDFromItemID(itemID)
end

function D.RecordID(itemID, info)
    local entry = info and info.entryID
    if type(entry) == "table" and entry.recordID and not D.RoomID(itemID) then return entry.recordID end
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

-- list of { text, met } where met is true / false / nil (cannot tell)
function D.Requirements(itemID, npcID)
    local SM = HA.SourceManager
    local out = {}
    for _, req in ipairs(SM:GetRequirements(itemID, npcID) or {}) do
        out[#out + 1] = { text = SM:GetRequirementText(req), met = SM:IsRequirementMet(req) }
    end
    return out
end

-- Pending (and not memoised) while an item currency's name loads.
function D.VendorCurrencies(vendor)
    local m = Memo(vendor.npcID)
    if m.cur then return m.cur, false end
    local out, pending = HA.VendorData:GetVendorCurrencies(vendor, D.VendorWares(vendor))
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

-- A vendor as a source-manager source, for the shared source line: its name and both positions.
function D.VendorSource(npcID)
    local v = D.Vendor(npcID) or {}
    local altMapID, _, _, altZone, altSubzone = HA.VendorData:GetOtherPosition(v)
    return { type = "vendor", data = {
        vendor = v, name = v.name, mapID = v.mapID, zone = v.zone, subzone = v.subzone,
        altMapID = altMapID, altZone = altZone, altSubzone = altSubzone,
    } }
end

function D.ItemSources(itemID)
    local out = {}
    for _, src in ipairs(HA.SourceManager:GetAllSources(itemID) or {}) do
        local d = src.data or {}
        local e = { type = src.type, source = src }
        if src.type == "vendor" then
            e.npcID = d.npcID
            e.name = d.name
            e.zone, e.subzone = select(2, B.Facts.Place(d.vendor or d))
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

-- The shared ownership read: state ("owned", "notOwned", "unknown") and the catalog entry behind it. Take
-- ownership from the state, never the entry's counts. "unknown" without an entry is asked again, so late
-- catalog data still arrives.
function D.Ownership(itemID, catalogMemo)
    local m = catalogMemo and catalogMemo[itemID]
    if m then return m.state, m.info end
    local state, info = HA.CatalogStore:ReadOwnershipEntry(itemID)
    if catalogMemo and (info or state ~= "unknown") then catalogMemo[itemID] = { state = state, info = info } end
    return state, info
end

function D.CatalogInfo(itemID, catalogMemo)
    return (select(2, D.Ownership(itemID, catalogMemo)))
end

function D.IconData(itemID, wantCopies, catalogMemo)
    local quality, copies
    if wantCopies then
        local info = D.CatalogInfo(itemID, catalogMemo)
        quality = info and info.quality
        if info and D.CountsLive() then
            local n = (info.totalNumPlaced or 0) + (info.totalNumStored or 0)
            if n > 0 then copies = n end
        end
    end
    return quality or C_Item.GetItemQualityByID(itemID), copies
end

-- Everything the item tooltip shows. counts is nil until this session's counts and the catalog entry are
-- known; before storage loads they read 0 for owned items.
function D.TooltipData(itemID, npcID, catalogMemo)
    local info = D.CatalogInfo(itemID, catalogMemo)
    local out = {
        name = D.ItemName(itemID) or (info and info.name) or L["Item %d"]:format(itemID),
        quality = info and info.quality or C_Item.GetItemQualityByID(itemID),
    }
    if info and D.CountsLive() then
        out.counts = {
            placed = info.totalNumPlaced or 0,
            stored = info.totalNumStored or 0,
            redeemable = info.remainingRedeemable or 0,
        }
    end
    local p = npcID and { type = "vendor", npcID = npcID, source = D.VendorSource(npcID) } or B.CanGet.Primary(itemID)
    local v = p and p.type == "vendor" and p.npcID and D.Vendor(p.npcID)
    out.price = npcID and D.Price(itemID, v) or p and p.price
    out.source = p and p.source
    out.active = v and D.HolidayActive(v) and v.event or nil
    local e = B.CanGet.Entry(itemID)
    out.bonus = e and e.bonus or nil
    return out
end
