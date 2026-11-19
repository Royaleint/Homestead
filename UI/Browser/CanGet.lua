-- What this character owns and can get now. Ownership comes from CatalogStore's shared read, kept per memo
-- version: nothing here writes to CatalogStore.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local D = B.Data
local Facts = B.Facts
local NK = HA.NameSortKey

local CG = {}
B.CanGet = CG

local function Memo()
    return B.State and B.State.catalogMemo
end

-- "owned", "notOwned" or nil (unknown), and the catalog entry, from the shared read.
local function Own(itemID, memo)
    local state, info = D.Ownership(itemID, memo)
    return state ~= "unknown" and state or nil, info
end

local VERDICT_OF = { idle = "unlisted", faction = "faction", purchasable = "can", unobtainable = "unobtainable" }

local function Verdict(itemID, npcID, vendor, own)
    if own ~= "notOwned" then return own == "owned" and "owned" or "unknown" end
    if not (npcID and vendor) then return "unknown" end
    return VERDICT_OF[HA.BadgeCalculation:WareState(itemID, vendor)] or "locked"
end

-- Whether this currency (any currency when nil) has been read since the wallet was last reset.
function CG.HasReadCurrency(currencyID)
    return HA.BadgeCalculation:WalletHasRead(currencyID)
end

-- Whether a currency moves between the account's characters, asked once per walk, and whether a reachable offer
-- is short in one: then the browser asks for the other characters' amounts.
local transferable, needAccount = {}, false
local function Transferable(id)
    local t = transferable[id]
    if t == nil then
        t = HA.SourceManager:IsCurrencyTransferable(id)
        transferable[id] = t
    end
    return t
end

-- The holder hint per short currency, kept until account data arrives or the wallet changes.
local holders = {}
local function Hint(id)
    local h = holders[id]
    if h == nil then
        h = false
        if Transferable(id) then
            -- The currency's icon names which one the amount is in.
            local name, n, icon = HA.SourceManager:GetOtherCharacterCurrency(id)
            if name then
                -- White, so it reads as information inside the red shortfall.
                local text = L["(%1$s has %2$s)"]:format(name, (icon and "|T" .. icon .. ":0|t " or "") .. n)
                h = B.Style.Colored(B.Style.color.body, text)
            end
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

local NONE = {}

-- The wallet rule is BadgeCalculation's; a reachable offer's judgment also learns whether a short currency
-- moves between the account's characters.
local function OnShort(id)
    if not needAccount then needAccount = Transferable(id) end
end

local function PayBundle(cost, out, judging)
    return HA.BadgeCalculation:WalletPayBundle(cost, out, judging and OnShort or nil)
end

local function Pay(cost, out, judging)
    return HA.BadgeCalculation:WalletPay(cost, out, judging and OnShort or nil)
end

function CG.IsShort(cost)
    return Pay(cost) == "short"
end

-- A bundle's short parts as words and their count, the shared formatter's shape.
local function ShortParts(bundle)
    local out = {}
    if bundle then PayBundle(bundle, out) end
    local words = HA.VendorData:FormatCost(out)
    local n = (out.gold and 1 or 0) + #(out.currencies or NONE) + #(out.items or NONE)
    for _, c in ipairs(out.currencies or NONE) do
        local hint = Hint(c.id)
        if hint then return words .. " " .. hint, n end
    end
    return words, n
end

function CG.ShortWords(cost)
    if cost and cost.alternatives and cost.alternatives[1] then
        return HA.VendorData:FormatCost(cost, "legacy", ShortParts)
    end
    return (ShortParts(cost))
end

local VERDICT = { paid = "can", short = "short", unknown = "unpriced" }
local PAY = { short = "short", unpriced = "unknown" }

local walk, version, seenGen = nil, nil, 0

local function Fresh()
    local v = D.MemoVersion()
    if v ~= version then
        version, walk, needAccount = v, nil, false
        wipe(entries)
        wipe(holders)
        wipe(transferable)
        HA.BadgeCalculation:WalletReset()
        seenGen = HA.BadgeCalculation:WalletGen()
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
    vendor = vendor or HA.VendorData:GetVendorAnySeason(npcID)
    return vendor and HA.SourceManager:GetVendorItemCost(itemID, vendor)
end

-- One vendor's offer: requirements first, then payment.
function CG.Offer(itemID, npcID)
    if HA.CatalogScanner:GetReadState() ~= "ready" then return "unknown" end
    local vendor = npcID and HA.VendorData:GetVendorAnySeason(npcID)
    local verdict = Verdict(itemID, npcID, vendor, (Own(itemID, Memo())))
    if verdict ~= "can" then return verdict end
    return VERDICT[Pay(OfferCost(itemID, npcID, vendor))]
end

local PRIORITY = { can = 1, short = 2, unpriced = 3, locked = 4, unlisted = 5, faction = 6, unobtainable = 7, unknown = 8 }

local SOURCE_KEYS = { "vendors", "achievements", "quests", "professions", "drops", "events", "shop" }
CG.SOURCE_KEYS = SOURCE_KEYS

local function GoldOnlyBundle(cost)
    return (cost.gold or 0) > 0 and not (cost.currencies and cost.currencies[1])
        and not (cost.items and cost.items[1])
end

-- The smallest gold-only option, or nil. With payable, only options this character can pay count (a single option always counts).
local function LowGold(cost, payable)
    if not cost then return nil end
    if not (cost.alternatives and cost.alternatives[1]) then
        return GoldOnlyBundle(cost) and cost.gold or nil
    end
    local low
    for _, v in ipairs(HA.VendorData:SplitCostOptions(cost) or NONE) do
        if GoldOnlyBundle(v) and (not low or v.gold < low) and (not payable or PayBundle(v) == "paid") then low = v.gold end
    end
    return low
end
CG.LowGold = LowGold

-- The shared other-faction-only answer, kept per item; the router resets it on show, on
-- SOURCE_CACHES_INVALIDATED and on a decor vendor scan.
local factionOnly = {}
function CG.ResetFactionOnly()
    wipe(factionOnly)
end

local function FactionOnly(itemID)
    local only = factionOnly[itemID]
    if only == nil then
        only = HA.SourceManager:IsOtherFactionOnly(itemID)
        factionOnly[itemID] = only
    end
    return only
end

local function Consider(e, SM, npcID, vendor, cost, best)
    local verdict = Verdict(e.itemID, npcID, vendor, "notOwned")
    local event = HA.VendorData:GetHolidayEvent(npcID)
    if verdict == "can" then
        -- A source with no cost, and every event vendor, asks the resolver.
        cost = cost or SM:GetVendorItemCost(e.itemID, vendor)
        e.reach, e.canBy = e.reach or {}, e.canBy or {}
        e.reach[npcID] = { npcID = npcID, mapID = (Facts.Place(vendor)), event = event, cost = cost }
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
            -- Gold only: a gold option this wallet can pay; else, unless paid another way, the cheapest one.
            local low = LowGold(o.cost, true)
            if not low and o.pay ~= "paid" then low = LowGold(o.cost) end
            o.price, o.gold = low, low ~= nil
            local v = VERDICT[o.pay]
            if v == "can" then e.canBy[npcID] = o end
            if not verdict or PRIORITY[v] < PRIORITY[verdict] then verdict = v end
        end
    end
    e.verdict = verdict
end

-- Re-reads every key already in the wallet. Nothing changed since this walk last looked: false, and nothing is
-- touched. A change settles the entries again and drops what was derived from their verdicts; the walk stays.
function CG.Rejudge()
    Fresh()
    local BC = HA.BadgeCalculation
    BC:WalletReread()
    if BC:WalletGen() == seenGen then return false end
    seenGen = BC:WalletGen()
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

-- The shipped item rows of each source type other than vendors, by Sources type.
local function SourceTables()
    local out = {}
    for _, key in ipairs(SOURCE_KEYS) do
        local t = key ~= "vendors" and HA.SourceManager:GetSourceTable(key)
        if t then out[key] = t end
    end
    return out
end

-- Offers are evaluated only for uncollected items; collected and unknown items never reach a vendor check.
local function Evaluate(itemID, SM, memo, tables)
    local own, info = Own(itemID, memo)
    local e = { itemID = itemID, info = info, own = own, name = D.ItemName(itemID, info), src = {} }
    local bonus = info and info.firstAcquisitionBonus or 0
    e.bonus = own == "notOwned" and bonus > 0 and bonus or nil
    e.src.vendors = SM:IsVendorItem(itemID) or nil
    for key, t in pairs(tables) do
        if t[itemID] then e.src[key] = true end
    end
    e.factionOnly = FactionOnly(itemID)
    if own ~= "notOwned" then
        e.verdict = own == "owned" and "owned" or "unknown"
        return e
    end
    local best
    for _, s in ipairs(SM:GetAllSources(itemID) or {}) do
        if s.type == "vendor" then
            local d = s.data or {}
            best = Consider(e, SM, d.npcID, d.vendor, d.cost, best)
        end
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
    if HA.CatalogScanner:GetReadState() ~= "ready" then return nil end
    Fresh()
    local e = entries[itemID]
    if not e then
        e = Evaluate(itemID, HA.SourceManager, Memo(), SourceTables())
        entries[itemID] = e
    end
    return e
end

local function Add(t, n, got)
    t.total, t.owned = t.total + n, t.owned + (got and n or 0)
end

local function RunWalk(items)
    local SM, memo, tables = HA.SourceManager, Memo(), SourceTables()
    local list = {}
    local progress = { known = true, total = 0, owned = 0, src = {} }
    local src = progress.src
    for _, key in ipairs(SOURCE_KEYS) do src[key] = { total = 0, owned = 0 } end
    for i = 1, #items do
        local itemID = items[i]
        local e = entries[itemID]
        if not e then
            e = Evaluate(itemID, SM, memo, tables)
            entries[itemID] = e
        end
        list[i] = e
        local got = e.own == "owned"
        local n = HA.CatalogStore:LeftOutReason(itemID, nil, got) and 0 or 1
        Add(progress, n, got)
        for key in pairs(e.src) do Add(src[key], n, got) end
    end
    return { list = list, progress = progress, vendorCan = {} }
end

function CG.Walk()
    if HA.CatalogScanner:GetReadState() ~= "ready" then return nil end
    Fresh()
    if not walk then
        local items = HA.CatalogStore:GetDecorItemIDs()
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
    local ka, kb = a.name and NK(a.name), b.name and NK(b.name)
    if ka ~= kb then return ka < kb end
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
        local _, zone, subzone = Facts.Place(v)
        return { type = "vendor", npcID = at, name = HA.VendorData:GetVendorName(v), zone = zone, subzone = subzone, price = D.Price(itemID, v),
            source = D.VendorSource(at) }
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
        local ka, kb = NK(a.entry.name), NK(b.entry.name)
        if ka ~= kb then return ka < kb end
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
        if D.IsOppositeFaction(vendor) then return "faction" end
        items = D.VendorWares(vendor)
    end
    if not items then return nil end
    -- A vendor's wares are already the counted ones; other sources leave out what the walk leaves out.
    local any = false
    for _, itemID in ipairs(items) do
        local e = CG.Entry(itemID)
        local own = e and e.own == "owned"
        if vendor or not HA.CatalogStore:LeftOutReason(itemID, nil, own) then
            if not own then return nil end
            any = true
        end
    end
    return any and "collected" or nil
end

local function FactionLabel(itemID, npcID)
    if npcID then return HA.BadgeCalculation:FactionLabel(D.Vendor(npcID) or {}) end
    for _, s in ipairs(HA.SourceManager:GetAllSources(itemID) or {}) do
        local at = s.type == "vendor" and s.data and s.data.npcID
        local v = at and D.Vendor(at)
        local label = v and D.IsOppositeFaction(v) and HA.BadgeCalculation:FactionLabel(v)
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
    local offer = npcID and CG.Offer(itemID, npcID) or e.verdict
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
    local event = offer == "unlisted" and (npcID and HA.VendorData:GetHolidayEvent(npcID) or not npcID and e.event)
    return event and "event" or "notOwned", event or nil, event and (npcID or e.eventAt) or nil
end

-- The item-state rule for every surface: an S.state key, its argument, and the vendor the state names.
-- npcID judges that vendor's offer; without it, the item's best short or unpriced offer, its easiest locked
-- vendor or its holiday vendor.
function B.ItemState(itemID, npcID)
    local phase = HA.CatalogScanner:GetReadState()
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
