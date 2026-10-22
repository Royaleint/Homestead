-- What this character owns and can get now. Ownership is derived from the catalog entries the browser
-- already reads and lives only in this walk's memo: nothing here writes to CatalogStore.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local D = B.Data
local Facts = B.Facts

local CG = {}
B.CanGet = CG

-- "counting" until this session's first collection read, then "ready", or "notRead" when it failed.
function D.CollectionState()
    local scanner, store = HA.CatalogScanner, HA.CatalogStore
    if not (scanner and store and scanner.HasFirstReadCompleted) then return "counting" end
    if scanner:HasFirstReadCompleted() then
        -- "IsWarm or" is safe here, though HasPersistedData warns against it: the first read latches only
        -- once a warm-started scan has recorded ownership, so the mid-scan zero is past.
        if scanner:IsWarm() or store:HasPersistedData() then return "ready" end
        return "notRead"
    end
    return scanner:HasFirstReadAttempted() and "notRead" or "counting"
end

-- A stored "owned" always wins: an entry can read 0 in the cold window after a reload.
local function Own(store, itemID, info)
    if store:IsOwnershipUnknowable(itemID) then return nil end
    if store:IsOwned(itemID) then return "owned" end
    if info == nil then return nil end
    return store:ComputeOwnedFromInfo(info) and "owned" or "notOwned"
end

-- "owned", "notOwned", or nil when unknown (always nil before the collection is ready).
function D.OwnState(itemID, info)
    if D.CollectionState() ~= "ready" then return nil end
    return Own(HA.CatalogStore, itemID, info)
end

local function Memo()
    return B.State and B.State.catalogMemo
end

-- One offer's verdict for an item whose ownership is own. vendor is nil when its identity is unknown.
local function Verdict(SM, itemID, npcID, vendor, own)
    if own ~= "notOwned" then return own == "owned" and "owned" or "unknown" end
    if not (npcID and vendor) then return "unknown" end
    if not Facts.BrowserListed(vendor) then return "unlisted" end
    if not HA.VendorFilter.CanAccessVendor(vendor) then return "faction" end
    local state = SM:GetVendorItemAvailabilityState(itemID, npcID, true)
    if state == "purchasable" then return "can" end
    return state == "unobtainable" and "unobtainable" or "locked"
end

-- "can", "locked", "unobtainable", "faction", "unlisted", "owned" or "unknown". info defaults to the
-- memoised catalog entry. The single verdict every surface uses.
function CG.Offer(itemID, npcID, info)
    if D.CollectionState() ~= "ready" then return "unknown" end
    info = info or D.CatalogInfo(itemID, Memo())
    local vendor = npcID and (HA.VendorData:GetVendor(npcID) or Facts.EventVendor(npcID))
    return Verdict(HA.SourceManager, itemID, npcID, vendor, Own(HA.CatalogStore, itemID, info))
end

-- Lower is better when an item's offers disagree.
local PRIORITY = { can = 1, locked = 2, unlisted = 3, faction = 4, unobtainable = 5, unknown = 6 }

local SOURCE_TABLES = {
    achievements = "AchievementSources", quests = "QuestSources", professions = "ProfessionSources",
    drops = "DropSources", events = "EventSources", shop = "ShopSources",
}
local SOURCE_KEYS = { "vendors", "achievements", "quests", "professions", "drops", "events", "shop" }
CG.SOURCE_KEYS = SOURCE_KEYS
CG.SOURCE_TABLES = SOURCE_TABLES

local function GoldOnly(cost)
    return cost ~= nil and (cost.gold or 0) > 0 and not (cost.currencies and cost.currencies[1])
        and not (cost.items and cost.items[1])
end

-- true when every source is an other-faction vendor. Kept per item; the router resets it on show, on
-- SOURCE_CACHES_INVALIDATED and on a decor vendor scan.
local factionOnly = {}
function CG.ResetFactionOnly()
    wipe(factionOnly)
end

local function FactionOnly(itemID)
    local only = factionOnly[itemID]
    if only == nil then
        only = false
        for _, s in ipairs(HA.SourceManager:GetAllSources(itemID) or {}) do
            local v = s.type == "vendor" and s.data and s.data.vendor
            only = v and HA.VendorFilter.IsOppositeFaction(v) or false
            if not only then break end
        end
        factionOnly[itemID] = only
    end
    return only
end

-- Records one vendor offer on an uncollected item's entry; returns the better of its verdict and best.
local function Consider(e, SM, npcID, vendor, cost, best)
    local verdict = Verdict(SM, e.itemID, npcID, vendor, "notOwned")
    local ev = Facts.EventVendor(npcID)
    local event = ev and (ev.event or vendor.event)
    if verdict == "can" then
        e.canBy = e.canBy or {}
        e.canBy[npcID] = { npcID = npcID, mapID = vendor.mapID, event = event, gold = GoldOnly(cost) }
    elseif verdict == "locked" then
        e.locked = e.locked or {}
        e.locked[#e.locked + 1] = npcID
    elseif verdict == "unlisted" and event then
        e.event = event
    end
    if not best or PRIORITY[verdict] < PRIORITY[best] then return verdict end
    return best
end

local entries, walk, version = {}, nil, nil

local function Fresh()
    local v = D.MemoVersion()
    if v ~= version then
        version, walk = v, nil
        wipe(entries)
    end
end

-- Offers are evaluated only for uncollected items; collected and unknown items never reach a vendor check.
local function Evaluate(itemID, store, SM, VD, memo)
    local info = D.CatalogInfo(itemID, memo)
    local own = Own(store, itemID, info)
    local e = { itemID = itemID, info = info, own = own, name = D.ItemName(itemID, info), src = {} }
    e.bonus = own == "notOwned" and info ~= nil and (info.firstAcquisitionBonus or 0) > 0
    e.src.vendors = VD:HasOfferForItem(itemID) or nil
    for key, tbl in pairs(SOURCE_TABLES) do
        local t = HA[tbl]
        if t and t[itemID] then e.src[key] = true end
    end
    e.factionOnly = FactionOnly(itemID)
    if own ~= "notOwned" then
        e.verdict = own == "owned" and "owned" or "unknown"
        return e
    end
    local best, seen = nil, {}
    for _, s in ipairs(SM:GetAllSources(itemID) or {}) do
        if s.type == "vendor" then
            local d = s.data or {}
            if d.npcID then seen[d.npcID] = true end
            best = Consider(e, SM, d.npcID, d.vendor, d.cost, best)
        end
    end
    for _, npcID in ipairs(Facts.EventVendorsFor(itemID) or {}) do
        if not seen[npcID] then best = Consider(e, SM, npcID, Facts.EventVendor(npcID), nil, best) end
    end
    e.verdict = best
    return e
end

-- The walk's record for one item, decor or a vendor ware outside the decor list; nil before ready.
-- Fields: itemID, info, own, name, bonus, src (Sources type set), factionOnly, verdict (nil without a
-- vendor offer), canBy (npcID to offer), locked (npcIDs), event (an off-season holiday that sells it).
function CG.Entry(itemID)
    if D.CollectionState() ~= "ready" then return nil end
    Fresh()
    local e = entries[itemID]
    if not e then
        e = Evaluate(itemID, HA.CatalogStore, HA.SourceManager, HA.VendorData, Memo())
        entries[itemID] = e
    end
    return e
end

local domain
local function Domain()
    if not domain then
        domain = {}
        local seen = {}
        for _, itemID in pairs(HA.DecorMapping or {}) do
            if not seen[itemID] then
                seen[itemID] = true
                domain[#domain + 1] = itemID
            end
        end
        table.sort(domain)
    end
    return domain
end

local function RunWalk(items)
    local store, SM, VD, memo = HA.CatalogStore, HA.SourceManager, HA.VendorData, Memo()
    local list = {}
    local progress = { known = true, total = 0, owned = 0, src = {} }
    local src = progress.src
    for _, key in ipairs(SOURCE_KEYS) do src[key] = { total = 0, owned = 0 } end
    for i = 1, #items do
        local itemID = items[i]
        local e = entries[itemID]
        if not e then
            e = Evaluate(itemID, store, SM, VD, memo)
            entries[itemID] = e
        end
        list[i] = e
        local owned = e.own == "owned"
        progress.total = progress.total + 1
        if owned then progress.owned = progress.owned + 1 end
        for key in pairs(e.src) do
            local s = src[key]
            s.total = s.total + 1
            if owned then s.owned = s.owned + 1 end
        end
    end
    return { list = list, progress = progress, vendorCan = {} }
end

-- One memoised walk over every decor item per refresh; nil until the collection is ready.
function CG.Walk()
    if D.CollectionState() ~= "ready" then return nil end
    Fresh()
    if not walk then
        local items = Domain()
        walk = HA.PerformanceTrace:Measure("browser_walk", #items, RunWalk, items)
    end
    return walk
end

-- Item names that load after the walk: fills them in and drops the ranking so it sorts again.
-- Returns true when any arrived.
function CG.RefreshNames()
    Fresh()
    if not walk then return false end
    local arrived = false
    for itemID, e in pairs(entries) do
        if not e.name then
            e.name = D.ItemName(itemID, e.info)
            arrived = arrived or e.name ~= nil
        end
    end
    if arrived then walk.ranked = nil end
    return arrived
end

-- How many of a vendor's wares this character can get now from it.
function CG.VendorCanCount(vendor)
    local w = CG.Walk()
    if not (w and vendor and vendor.npcID) then return nil end
    local npcID = vendor.npcID
    local n = w.vendorCan[npcID]
    if not n then
        n = 0
        for _, itemID in ipairs(D.VendorWares(vendor)) do
            local e = CG.Entry(itemID)
            if e.canBy and e.canBy[npcID] then n = n + 1 end
        end
        w.vendorCan[npcID] = n
    end
    return n
end

-- Picks each item's best offer (time-limited, then nearest, then gold only) for where the player is.
local function BestOffer(e, where)
    local best, bestKey
    for _, o in pairs(e.canBy) do
        local key = (o.event and 0 or 4) + Facts.Nearness(o.mapID, where) - (o.gold and 0.5 or 0)
        if not bestKey or key < bestKey or (key == bestKey and o.npcID < best.npcID) then
            best, bestKey = o, key
        end
    end
    return best
end

local function Before(a, b)
    local ta, tb = a.best.event ~= nil, b.best.event ~= nil
    if ta ~= tb then return ta end
    if a.bonus ~= b.bonus then return a.bonus end
    if a.near ~= b.near then return a.near < b.near end
    if a.best.gold ~= b.best.gold then return a.best.gold end
    if (a.name ~= nil) ~= (b.name ~= nil) then return a.name ~= nil end
    if a.name and a.name ~= b.name then return a.name < b.name end
    return a.itemID < b.itemID
end

-- The source an item is shown by on the row, Summary and the tooltip: its best open offer, else a vendor
-- this character can use, else the first vendor on record, else the first source.
function CG.Primary(itemID, sources)
    sources = sources or D.ItemSources(itemID)
    local e = CG.Entry(itemID)
    local best = e and e.canBy and (e.best or BestOffer(e, Facts.Here()))
    local own, first
    for _, s in ipairs(sources) do
        local v = s.type == "vendor" and s.npcID and D.Vendor(s.npcID)
        if v and best and s.npcID == best.npcID then return s end
        if v then
            own = own or not D.IsOppositeFaction(v) and s or nil
            first = first or s
        end
    end
    if best then
        local v = D.Vendor(best.npcID) or {}
        return { type = "vendor", npcID = best.npcID, name = v.name, zone = v.zone, subzone = v.subzone, price = D.Price(itemID, v) }
    end
    return own or first or sources[1]
end

-- Can-get-now entries in ranked order. Sets each entry's best (offer) and near (1-3). A zone change
-- re-ranks the saved walk without walking again.
function CG.Rank()
    local w = CG.Walk()
    if not w then return nil end
    local where = Facts.Here()
    local zone = where and where.zone or 0
    if w.ranked and w.rankedFor == zone then return w.ranked end
    local out = {}
    for _, e in ipairs(w.list) do
        if e.verdict == "can" then
            e.best = BestOffer(e, where)
            e.near = Facts.Nearness(e.best.mapID, where)
            out[#out + 1] = e
        end
    end
    table.sort(out, Before)
    w.ranked, w.rankedFor = out, zone
    return out
end

-- The unmet requirement texts at the easiest of these locked vendors (fewest unmet, ties in source
-- order; a vendor with none unmet doesn't count), and that vendor.
local function Easiest(itemID, npcIDs)
    local best, at
    for _, npcID in ipairs(npcIDs or {}) do
        local unmet = {}
        for _, r in ipairs(D.Requirements(itemID, npcID)) do
            if r.met ~= true then unmet[#unmet + 1] = r.text end
        end
        if unmet[1] and not (best and #best <= #unmet) then best, at = unmet, npcID end
    end
    return best, at
end

-- The Summary's rows: up to three can-get-now entries, then dimmed "not yet" rows so three slots fill
-- when enough candidates exist. Returns { rows, notYet = { { entry, unmet } }, count, allCollected }.
function CG.Fill()
    local ranked = CG.Rank()
    if not ranked then return nil end
    local w = CG.Walk()
    local out = { rows = {}, notYet = {}, count = #ranked }
    out.allCollected = w.progress.total > 0 and w.progress.owned == w.progress.total
    for i = 1, math.min(3, #ranked) do out.rows[i] = ranked[i] end
    local room = 3 - #out.rows
    if room == 0 or out.allCollected then return out end
    local candidates = {}
    for _, e in ipairs(w.list) do
        if e.own == "notOwned" and e.name and (e.verdict == "locked" or (e.verdict == "unlisted" and e.event)) then
            local unmet = Easiest(e.itemID, e.locked)
            candidates[#candidates + 1] = { entry = e, unmet = unmet and #unmet or 1 }
        end
    end
    table.sort(candidates, function(a, b)
        if a.unmet ~= b.unmet then return a.unmet < b.unmet end
        if a.entry.name ~= b.entry.name then return a.entry.name < b.entry.name end
        return a.entry.itemID < b.entry.itemID
    end)
    for i = 1, math.min(room, #candidates) do out.notYet[i] = candidates[i] end
    return out
end

-- Why the Hide toggle hides something: nil, "collected" or "faction". what is an itemID, or a source
-- as { vendor = v } or { items = { itemIDs } }. Unknown ownership never hides as collected.
function CG.HiddenBy(what)
    if type(what) == "number" then
        local e = CG.Entry(what)
        if e and e.own == "owned" then return "collected" end
        if FactionOnly(what) then return "faction" end
        return nil
    end
    local vendor, items = what.vendor, what.items
    if vendor then
        if HA.VendorFilter.IsOppositeFaction(vendor) then return "faction" end
        items = D.VendorWares(vendor)
    end
    if not (items and items[1]) then return nil end
    for _, itemID in ipairs(items) do
        local e = CG.Entry(itemID)
        if not (e and e.own == "owned") then return nil end
    end
    return "collected"
end

local function FactionLabel(itemID, npcID)
    if npcID then return D.VendorFactionLabel(D.Vendor(npcID) or {}) end
    for _, src in ipairs(D.ItemSources(itemID)) do
        local v = src.type == "vendor" and src.npcID and D.Vendor(src.npcID)
        local label = v and D.IsOppositeFaction(v) and D.VendorFactionLabel(v)
        if label then return label end
    end
end

CG.FactionLabel = FactionLabel

-- How many missing items only the other faction's vendors sell, by vendor faction label.
function CG.MissingFactions()
    local seen = {}
    for itemID, e in pairs(entries) do
        if e.own == "notOwned" and e.factionOnly then
            local label = FactionLabel(itemID) or ""
            seen[label] = (seen[label] or 0) + 1
        end
    end
    return seen
end

local function Judge(e, itemID, npcID)
    local offer = npcID and CG.Offer(itemID, npcID, e.info) or e.verdict
    if offer == "can" then return "can" end
    if npcID and offer == "faction" or not npcID and e.factionOnly then
        local label = FactionLabel(itemID, npcID)
        if label then return "faction", label end
    end
    local unmet, at = Easiest(itemID, not npcID and e.locked or offer == "locked" and { npcID })
    if unmet then return "locked", unmet[2] and L["%s and %d more"]:format(unmet[1], #unmet - 1) or unmet[1], at end
    local ev = npcID and Facts.EventVendor(npcID)
    local event = offer == "unlisted" and (npcID and ev and (ev.event or (D.Vendor(npcID) or {}).event) or not npcID and e.event)
    return event and "event" or "notOwned", event or nil
end

-- The item-state rule for every surface: an S.state key, its argument, and the vendor a locked state names.
-- npcID judges that vendor's offer; without it, the item's easiest locked vendor.
function B.ItemState(itemID, npcID)
    local phase = D.CollectionState()
    if phase ~= "ready" then return phase == "counting" and "counting" or nil end
    local e = CG.Entry(itemID)
    if not e then return end
    if e.own ~= "notOwned" then return e.own == "owned" and "owned" or nil end
    if npcID then return Judge(e, itemID, npcID) end
    e.st = e.st or { Judge(e, itemID) }
    return e.st[1], e.st[2], e.st[3]
end
