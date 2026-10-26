-- What this character owns and can get now. Ownership is derived from the catalog entries the browser
-- already reads and lives only in this walk's memo: nothing here writes to CatalogStore.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local D = B.Data
local Facts = B.Facts

local CG = {}
B.CanGet = CG

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

local function Memo()
    return B.State and B.State.catalogMemo
end

local function Verdict(SM, itemID, npcID, vendor, own)
    if own ~= "notOwned" then return own == "owned" and "owned" or "unknown" end
    if not (npcID and vendor) then return "unknown" end
    if not Facts.BrowserListed(vendor) then return "unlisted" end
    if not HA.VendorFilter.CanAccessVendor(vendor) then return "faction" end
    local state = SM:GetVendorItemAvailabilityState(itemID, npcID, true)
    if state == "purchasable" then return "can" end
    return state == "unobtainable" and "unobtainable" or "locked"
end

-- What this character carries, each key read once per memo version, so the keys are what the offers need:
-- gold in copper, cur[id] (false without currency info), item[id] in bags and reagent bank as the merchant counts.
local wallet = { cur = {}, item = {} }
CG.wallet = wallet

local function Read(kind, id)
    if kind == "cur" then
        local info = C_CurrencyInfo.GetCurrencyInfo(id)
        return info and info.quantity or false
    end
    return C_Item.GetItemCount(id, false, false, true)
end

local function Have(kind, id)
    local n = wallet[kind][id]
    if n == nil then
        n = Read(kind, id)
        wallet[kind][id] = n
    end
    return n
end

-- Whether a currency moves between the account's characters, asked once per walk, and whether a reachable offer
-- is short in one: then the browser asks for the other characters' amounts.
local transferable, needAccount = {}, false
local function Transferable(id)
    local t = transferable[id]
    if t == nil then
        t = C_CurrencyInfo.IsAccountTransferableCurrency(id) and true or false
        transferable[id] = t
    end
    return t
end

-- The muted hint per short currency, kept until account data arrives or the wallet changes.
local holders = {}
local function Hint(id)
    local h = holders[id]
    if h == nil then
        h = false
        if Transferable(id) then
            local name, n = D.OtherHolder(id)
            if name then h = B.Style.Muted(L["(%1$s has %2$s)"]:format(name, n)) end
        end
        holders[id] = h
    end
    return h
end

local entries = {}

-- Moves whenever the verdicts or the words built from the wallet change, so a page that cached them can tell.
local gen = 0
function CG.Gen() return gen end

-- Account data arrived: the hints and the words built from them are stale; nothing is judged again.
function CG.AccountData()
    gen = gen + 1
    wipe(holders)
    for _, e in pairs(entries) do e.st = nil end
end

-- "paid" when every part is checked and covered; "short" when a checked part isn't, which outweighs the rest;
-- else "unknown": no part, or one with no id, no amount or no currency info. out gathers the short parts; judging
-- marks a reachable offer's judgment, the only kind that can need account data.
local NONE, KINDS = {}, { currencies = "cur", items = "item" }

local function Pay(cost, out, judging)
    if not cost then return "unknown" end
    local parts, short, unknown = 0, false, false
    local gold = cost.gold or 0
    if gold > 0 then
        wallet.gold = wallet.gold or GetMoney()
        parts, short = 1, wallet.gold < gold
        if short and out then out.gold = gold end
    end
    for key, kind in pairs(KINDS) do
        for _, c in ipairs(cost[key] or NONE) do
            parts = parts + 1
            local have = c.id and c.amount and Have(kind, c.id)
            if not have then
                unknown = true
            elseif have < c.amount then
                short = true
                if judging and kind == "cur" and not needAccount then needAccount = Transferable(c.id) end
                if out then out[key] = out[key] or {} table.insert(out[key], c) end
            end
        end
    end
    if short then return "short" end
    return (unknown or parts == 0) and "unknown" or "paid"
end

function CG.IsShort(cost)
    return Pay(cost) == "short"
end

function CG.ShortWords(cost)
    local out = {}
    Pay(cost, out)
    local words = HA.VendorData:FormatCost(out)
    for _, c in ipairs(out.currencies or NONE) do
        local hint = Hint(c.id)
        if hint then return words .. " " .. hint end
    end
    return words
end

local VERDICT = { paid = "can", short = "short", unknown = "unpriced" }
local PAY = { short = "short", unpriced = "unknown" }

local walk, version = nil, nil

local function Fresh()
    local v = D.MemoVersion()
    if v ~= version then
        version, walk, needAccount = v, nil, false
        wipe(entries)
        wipe(holders)
        wipe(transferable)
        wallet.gold = nil
        wipe(wallet.cur)
        wipe(wallet.item)
    end
end

function CG.NeedAccount()
    Fresh()
    return needAccount
end

local function OfferCost(itemID, npcID, vendor)
    local e = CG.Entry(itemID)
    local o = e and e.reach and e.reach[npcID]
    if o then return o.cost end
    vendor = vendor or HA.VendorData:GetVendor(npcID) or Facts.EventVendor(npcID)
    return vendor and HA.SourceManager:GetVendorItemCost(itemID, vendor)
end

-- One vendor's offer: requirements first, then payment.
function CG.Offer(itemID, npcID, info)
    if D.CollectionState() ~= "ready" then return "unknown" end
    info = info or D.CatalogInfo(itemID, Memo())
    local vendor = npcID and (HA.VendorData:GetVendor(npcID) or Facts.EventVendor(npcID))
    local verdict = Verdict(HA.SourceManager, itemID, npcID, vendor, Own(HA.CatalogStore, itemID, info))
    if verdict ~= "can" then return verdict end
    return VERDICT[Pay(OfferCost(itemID, npcID, vendor))]
end

local PRIORITY = { can = 1, short = 2, unpriced = 3, locked = 4, unlisted = 5, faction = 6, unobtainable = 7, unknown = 8 }

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
CG.GoldOnly = GoldOnly

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

local function Consider(e, SM, npcID, vendor, cost, best)
    local verdict = Verdict(SM, e.itemID, npcID, vendor, "notOwned")
    local ev = Facts.EventVendor(npcID)
    local event = ev and (ev.event or vendor.event)
    if verdict == "can" then
        -- A source with no cost, and every event vendor, asks the resolver.
        cost = cost or SM:GetVendorItemCost(e.itemID, vendor)
        local gold = GoldOnly(cost)
        e.reach, e.canBy = e.reach or {}, e.canBy or {}
        e.reach[npcID] = { npcID = npcID, mapID = vendor.mapID, event = event, cost = cost, gold = gold,
            price = gold and cost.gold or nil }
        return best
    elseif verdict == "locked" then
        e.locked = e.locked or {}
        e.locked[#e.locked + 1] = npcID
    elseif verdict == "unlisted" and event then
        e.event, e.eventAt = event, npcID
    end
    if not best or PRIORITY[verdict] < PRIORITY[best] then return verdict end
    return best
end

-- Judges each reachable offer against the wallet; the verdict is the best of theirs and the rest's.
local function Settle(e)
    local verdict = e.rest
    if e.reach then
        wipe(e.canBy)
        for npcID, o in pairs(e.reach) do
            o.pay = Pay(o.cost, nil, true)
            local v = VERDICT[o.pay]
            if v == "can" then e.canBy[npcID] = o end
            if not verdict or PRIORITY[v] < PRIORITY[verdict] then verdict = v end
        end
    end
    e.verdict = verdict
end

-- Re-reads every key already in the wallet, in place. Nothing changed: false, and nothing is touched. A
-- change settles the entries again and drops what was derived from their verdicts; the walk stays.
function CG.Rejudge()
    Fresh()
    local changed = false
    local gold = wallet.gold
    if gold then
        wallet.gold = GetMoney()
        changed = changed or wallet.gold ~= gold
    end
    for _, kind in pairs(KINDS) do
        local held = wallet[kind]
        for id, old in pairs(held) do
            local n = Read(kind, id)
            held[id] = n
            changed = changed or n ~= old
        end
    end
    if not changed then return false end
    gen = gen + 1
    wipe(holders)
    for _, e in pairs(entries) do
        e.st = nil
        if e.reach then Settle(e) end
    end
    if walk then
        walk.ranked = nil
        wipe(walk.vendorCan)
    end
    return true
end

-- Offers are evaluated only for uncollected items; collected and unknown items never reach a vendor check.
local function Evaluate(itemID, store, SM, VD, memo)
    local info = D.CatalogInfo(itemID, memo)
    local own = Own(store, itemID, info)
    local e = { itemID = itemID, info = info, own = own, name = D.ItemName(itemID, info), src = {} }
    local bonus = info and info.firstAcquisitionBonus or 0
    e.bonus = own == "notOwned" and bonus > 0 and bonus or nil
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
    e.rest = best
    Settle(e)
    return e
end

-- The walk's record for one item, decor or a vendor ware outside the decor list; nil before ready.
-- Fields: itemID, info, own, name, bonus (the First-Time Collection amount, nil if none), src (Sources type set), factionOnly, verdict (nil without a
-- vendor offer), reach (npcID to each offer with requirements met, with cost and pay), canBy (its paid ones),
-- eventPaid and lowGold (set by Rank: a paid event offer, the lowest paid gold-only price), rest (the others' best verdict), locked (npcIDs), event and eventAt (an off-season holiday that sells it, and its vendor).
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

function CG.Walk()
    if D.CollectionState() ~= "ready" then return nil end
    Fresh()
    if not walk then
        local items = Domain()
        walk = HA.PerformanceTrace:Measure("browser_walk", #items, RunWalk, items)
    end
    return walk
end

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

-- "Get it": event, gold only, lowest gold, nearest to where (none: all alike), lowest npcID.
local function Closer(o, best, where)
    if (o.event ~= nil) ~= (best.event ~= nil) then return o.event ~= nil end
    if o.gold ~= best.gold then return o.gold end
    if o.gold and o.price ~= best.price then return o.price < best.price end
    local near, far = Facts.Nearness(o.mapID, where), Facts.Nearness(best.mapID, where)
    if near ~= far then return near < far end
    return o.npcID < best.npcID
end

local function BestOffer(offers, where, pay)
    local best
    for _, o in pairs(offers) do
        if (not pay or o.pay == pay) and (not best or Closer(o, best, where)) then best = o end
    end
    return best
end

-- "Get it" for a can-get-now entry, for where the player is now; never kept on the entry.
function CG.Best(e)
    return e.verdict == "can" and BestOffer(e.canBy, Facts.Here()) or nil
end

-- Best overall, from no zone; Rank sets e.eventPaid and e.lowGold.
local function Before(a, b)
    if a.eventPaid ~= b.eventPaid then return a.eventPaid end
    if (a.bonus ~= nil) ~= (b.bonus ~= nil) then return a.bonus ~= nil end
    if (a.lowGold ~= nil) ~= (b.lowGold ~= nil) then return a.lowGold ~= nil end
    if a.lowGold ~= b.lowGold then return a.lowGold < b.lowGold end
    if (a.name ~= nil) ~= (b.name ~= nil) then return a.name ~= nil end
    if a.name and a.name ~= b.name then return a.name < b.name end
    return a.itemID < b.itemID
end

-- The best paid offer, else the vendor the item's state names, else the first own-faction vendor.
function CG.Primary(itemID, sources)
    sources = sources or D.ItemSources(itemID)
    local e = CG.Entry(itemID)
    local best = e and CG.Best(e)
    local at = best and best.npcID or e and select(3, B.ItemState(itemID))
    local own, first
    for _, s in ipairs(sources) do
        local v = s.type == "vendor" and s.npcID and D.Vendor(s.npcID)
        if v and at and s.npcID == at then return s end
        if v then
            own = own or not D.IsOppositeFaction(v) and s or nil
            first = first or s
        end
    end
    if at then
        local v = D.Vendor(at) or {}
        return { type = "vendor", npcID = at, name = v.name, zone = v.zone, subzone = v.subzone, price = D.Price(itemID, v) }
    end
    return own or first or sources[1]
end

function CG.Rank()
    local w = CG.Walk()
    if not w then return nil end
    if w.ranked then return w.ranked end
    local out = {}
    for _, e in ipairs(w.list) do
        if e.verdict == "can" then
            e.eventPaid, e.lowGold = false, nil
            for _, o in pairs(e.canBy) do
                if o.event ~= nil then e.eventPaid = true end
                if o.gold and (not e.lowGold or o.price < e.lowGold) then e.lowGold = o.price end
            end
            out[#out + 1] = e
        end
    end
    table.sort(out, Before)
    w.ranked = out
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

-- Which items are locked, and at which vendor, does not depend on the wallet: a re-judge keeps the answer.
local function EasiestOf(e)
    local easy = e.easy
    if not easy then
        easy = { Easiest(e.itemID, e.locked) }
        e.easy = easy
    end
    return easy[1]
end

local STEP = { short = 1, unpriced = 2, locked = 3 }

-- The Summary's rows: up to three can-get-now entries, then dimmed "not yet" rows so three slots fill
-- when enough candidates exist: short, unpriced, then locked or an off-season holiday by fewest unmet.
-- Returns { rows, notYet = { { entry, step, unmet } }, count, allCollected }.
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
        local step = e.own == "notOwned" and e.name and (STEP[e.verdict] or e.verdict == "unlisted" and e.event and 3)
        if step then
            local unmet = step == 3 and EasiestOf(e)
            candidates[#candidates + 1] = { entry = e, step = step, unmet = step < 3 and 0 or unmet and #unmet or 1 }
        end
    end
    table.sort(candidates, function(a, b)
        if a.step ~= b.step then return a.step < b.step end
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
    for _, s in ipairs(HA.SourceManager:GetAllSources(itemID) or {}) do
        local at = s.type == "vendor" and s.data and s.data.npcID
        local v = at and D.Vendor(at)
        local label = v and D.IsOppositeFaction(v) and D.VendorFactionLabel(v)
        if label then return label end
    end
end

CG.FactionLabel = FactionLabel

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
    if PAY[offer] then
        local o = not npcID and BestOffer(e.reach, Facts.Here(), PAY[offer])
        local words = offer == "short" and CG.ShortWords(o and o.cost or OfferCost(itemID, npcID)) or nil
        return offer, words, o and o.npcID or npcID
    end
    if npcID and offer == "faction" or not npcID and e.factionOnly then
        local label = FactionLabel(itemID, npcID)
        if label then return "faction", label end
    end
    local unmet, at = Easiest(itemID, not npcID and e.locked or offer == "locked" and { npcID })
    if unmet then return "locked", unmet[2] and L["%s and %d more"]:format(unmet[1], #unmet - 1) or unmet[1], at end
    local ev = npcID and Facts.EventVendor(npcID)
    local event = offer == "unlisted" and (npcID and ev and (ev.event or (D.Vendor(npcID) or {}).event) or not npcID and e.event)
    return event and "event" or "notOwned", event or nil, event and (npcID or e.eventAt) or nil
end

-- The item-state rule for every surface: an S.state key, its argument, and the vendor the state names.
-- npcID judges that vendor's offer; without it, the item's best short or unpriced offer, its easiest locked
-- vendor or its holiday vendor.
function B.ItemState(itemID, npcID)
    local phase = D.CollectionState()
    if phase ~= "ready" then return phase == "counting" and "counting" or nil end
    local e = CG.Entry(itemID)
    if not e then return end
    if e.own ~= "notOwned" then return e.own == "owned" and "owned" or nil end
    if npcID then return Judge(e, itemID, npcID) end
    local st = e.st
    if st and st.zoned and st.zone ~= (Facts.Here() or NONE).zone then st = nil end
    if not st then
        st = { Judge(e, itemID) }
        -- The nearest-vendor pick of short and unpriced follows the zone: it is judged again when the zone differs.
        if st[1] == "short" or st[1] == "unpriced" then st.zoned, st.zone = true, (Facts.Here() or NONE).zone end
        e.st = st
    end
    return st[1], st[2], st[3]
end
