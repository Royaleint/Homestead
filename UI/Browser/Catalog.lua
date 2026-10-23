-- Catalog: every decor item, with filters and sorts
local _, HA = ...

local B, L = HA.DecorBrowser, HA.L
local S, W, D, CG = B.Style, B.Widgets, B.Data, B.CanGet
local SP, K, LO = S.space, S.color, S.layout

local KEYS = CG.SOURCE_KEYS
local KIND, KindOf = S.kind, S.KindOf
local TYPE = S.sourceLabel
local SORT = { best = L["Best to get now"], name = L["Name"], price = L["Price"] }
-- The best-sort group from the walk alone (can, other, locked or event, faction, owned); drawn rows judge their words.
local function Group(e)
    if e.own ~= "notOwned" then return e.own == "owned" and 4 or 1 end
    if e.verdict == "can" then return 0 end
    if e.factionOnly then return 3 end
    return (e.locked or e.verdict == "unlisted" and e.event) and 2 or 1
end

local Page, ui, orders = {}, {}, {}
local cat, recs, counts, owns, walk, version, hideFor, bare, bareList, bareVer, rankedIn
local shown = {}
-- What the header box holds, as typed; cat.q is the same words trimmed and lowercased.
local query = ""

local function NewView(sort)
    local types = {}
    for _, k in ipairs(KEYS) do types[k] = true end
    return { q = "", kind = "all", coll = true, notColl = true, canGet = false, bonus = false,
        types = types, sort = sort or "best" }
end

local function Words(c)
    local f, on = {}, {}
    if c.coll ~= c.notColl then f[1] = c.coll and L["Collected"] or L["Not collected"]
    elseif not c.coll then f[1] = L["Neither collected nor not collected"] end
    if c.canGet then f[#f + 1] = L["Can get now"] end
    if c.bonus then f[#f + 1] = L["First-Time Collection Bonus"] end
    for _, k in ipairs(KEYS) do
        if c.types[k] then on[#on + 1] = TYPE[k] end
    end
    if #on < #KEYS then f[#f + 1] = L["Sources: %s"]:format(table.concat(on, ", ")) end
    return table.concat(f, ", ")
end

local function BareEntries()
    if not bare then
        local seen = {}
        bare = {}
        for _, id in pairs(HA.DecorMapping or {}) do
            if not seen[id] then
                seen[id] = true
                bare[#bare + 1] = id
            end
        end
        table.sort(bare)
    end
    if bareVer == D.MemoVersion() then
        for _, e in ipairs(bareList) do e.name = e.name or D.ItemName(e.itemID, e.info) end
        return bareList
    end
    bareList, bareVer = {}, D.MemoVersion()
    for i, id in ipairs(bare) do
        local info = D.CatalogInfo(id, B.State.catalogMemo)
        bareList[i] = { itemID = id, info = info, name = D.ItemName(id, info), src = {} }
    end
    return bareList
end

local function Rebuild()
    version, hideFor = D.MemoVersion(), B.State.hideNA
    wipe(orders)
    counts, owns, recs = {}, {}, {}
    for i, e in ipairs(walk and walk.list or BareEntries()) do
        local r = { kind = "item", id = e.itemID, e = e, lname = e.name and e.name:lower() or "",
            hasName = e.name ~= nil, cat = KindOf(e.info), bonus = e.bonus,
            done = e.own == "owned", hid = hideFor and (walk and (e.own == "owned" and "collected" or e.factionOnly and "faction" or nil) or not walk and CG.HiddenBy(e.itemID)) or nil }
        r.g = walk and Group(e) or 1
        recs[i] = r
        counts[r.cat], counts.all = (counts[r.cat] or 0) + 1, (counts.all or 0) + 1
        if r.done then owns[r.cat], owns.all = (owns[r.cat] or 0) + 1, (owns.all or 0) + 1 end
    end
end

local function Gold(itemID)
    local low = math.huge
    for _, s in ipairs(HA.SourceManager:GetAllSources(itemID) or {}) do
        local c = s.type == "vendor" and s.data and s.data.cost
        if c and (c.gold or 0) > 0 and not (c.currencies and c.currencies[1]) and not (c.items and c.items[1]) then
            low = math.min(low, c.gold)
        end
    end
    return low
end

local function ByName(a, b)
    if a.hasName ~= b.hasName then return a.hasName end
    if a.lname ~= b.lname then return a.lname < b.lname end
    return a.id < b.id
end

local SORTERS = {
    best = function(a, b)
        if a.g ~= b.g then return a.g < b.g end
        if a.g == 0 and a.rank ~= b.rank then return a.rank < b.rank end
        return ByName(a, b)
    end,
    name = function(a, b)
        if a.done ~= b.done then return b.done end
        return ByName(a, b)
    end,
    price = function(a, b)
        if a.done ~= b.done then return b.done end
        if a.gold ~= b.gold then return a.gold < b.gold end
        return ByName(a, b)
    end,
}

local function Order(sort)
    local o = orders[sort]
    if o then return o end
    o = {}
    for i, r in ipairs(recs) do o[i] = r end
    local rank = {}
    for i, e in ipairs(sort == "best" and walk and CG.Rank() or {}) do rank[e.itemID] = i end
    for _, r in ipairs(o) do
        r.rank = rank[r.id] or math.huge
        if sort == "price" then r.gold = r.gold or Gold(r.id) end
    end
    table.sort(o, SORTERS[sort])
    orders[sort] = o
    return o
end

-- Best to get now ranks by the player's zone, and only a shown Catalog hears a zone refresh, so Show checks too.
local function Rezone()
    local here = B.Facts.Here()
    local zone = here and here.zone
    if zone == rankedIn then return false end
    orders.best, rankedIn = nil, zone
    return true
end

-- Collected and Not collected match owned and notOwned only; unknown ownership is in neither.
local function Passes(r, c, anyOwn, subset)
    local e = r.e
    if c.kind ~= "all" and r.cat ~= c.kind then return false end
    if c.q ~= "" and not r.lname:find(c.q, 1, true) then return false end
    if not anyOwn and not ((e.own == "owned" and c.coll) or (e.own == "notOwned" and c.notColl)) then return false end
    if (c.canGet and e.verdict ~= "can") or (c.bonus and not r.bonus) then return false end
    if subset then
        for k in pairs(e.src) do
            if c.types[k] then return true end
        end
        return false
    end
    return true
end

local function Filter()
    local c, out, n, hc, hf, subset, seen = cat, {}, 0, 0, 0, false, {}
    for _, k in ipairs(KEYS) do
        if not c.types[k] then subset = true end
    end
    for _, r in ipairs(Order(c.sort)) do
        if Passes(r, c, c.coll and c.notColl, subset) then
            if r.hid then
                if r.hid == "collected" then hc = hc + 1
                else
                    hf = hf + 1
                    r.fl = r.fl or CG.FactionLabel(r.id) or ""
                    seen[r.fl] = (seen[r.fl] or 0) + 1
                end
            else
                n = n + 1
                out[n] = r
            end
        end
    end
    return out, n, hc, hf, seen
end

local Apply

-- Clears the filters and the search, keeping the kind and the sort.
local function Reset()
    local kind = cat.kind
    cat = NewView(cat.sort)
    cat.kind, query = kind, ""
    B.Window.SetSearch("")
    Apply(false)
end

local function Describe(r)
    local d, e, id = r.d, r.e, r.id
    if not d then
        local sources = D.ItemSources(id)
        local p = CG.Primary(id, sources)
        local v = p and p.type == "vendor" and p.npcID and HA.VendorData:GetVendor(p.npcID)
        local active, state, arg = nil, B.ItemState(id)
        local more = #sources
        for _, s in ipairs(sources) do if s == p then more = more - 1 end end
        for _, o in pairs(e.canBy or {}) do active = active or o.event end
        d = { itemID = id, name = e.name or L["Item %d"]:format(id),
            quality = e.info and e.info.quality or C_Item.GetItemQualityByID(id),
            icon = e.info and e.info.iconTexture or D.ItemIcon(id), active = active, bonus = r.bonus,
            right = p and p.price, line2 = D.SourceLine(id, { p }) .. (more > 0 and " " .. L["(+%d more)"]:format(more) or ""),
            unconfirmed = v and not B.Facts.Confirmed(v) or nil, state = state, arg = arg,
            onClick = function() B.Go({ kind = "item", id = id }) end }
        r.d = d
    end
    return d
end

local ITEM = { frameType = W.rowKind.frameType, build = W.rowKind.build,
    init = function(f, r) f.rec = r f:Set(Describe(r)) end }

local function PaintHead()
    local k = cat.kind
    ui.head:SetHeight(W.TextHeight("bodyMuted") + SP.s)
    ui.head:SetText(walk and L["%d of %d collected"]:format(owns[k] or 0, counts[k] or 0) or L["Counting…"])
end

local function PaintLine(words)
    ui.fl:SetShown(words ~= "")
    ui.fl:SetHeight(words ~= "" and W.TextHeight("body") + SP.s or 1)
    ui.fl.text:SetText(L["Filtered: %s"]:format(words) .. " \194\183 " .. S.Colored(K.gold, L["Reset filters"]))
end

local function Empty(status, n, hidden, words)
    local c, kind, d = cat, "noResults", { onReset = Reset }
    if status ~= "ready" and (words ~= "" or (status == "counting" and c.sort == "best")) then
        kind = status == "counting" and "counting" or "notReadFilters"
        if kind == "counting" and c.sort == "best" then
            kind, d.onSort = "countingSort", function() ui.sort.Set("name") Apply(false) end
        end
    elseif n == 0 and not hidden then
        d.onAll = c.kind ~= "all" and function() B.Go({ kind = "catalog", key = "all", seed = { search = query } }) end or nil
    else
        ui.empty:Hide()
        return false
    end
    ui.empty:Set(kind, d)
    return true
end

function Apply(keep)
    local out, n, hc, hf, seen = Filter()
    local words = Words(cat)
    if hc + hf > 0 then
        out[n + 1] = { kind = "footer", hidden = hc + hf, collected = hc, faction = hf, parts = B.Facts.FactionParts(seen),
            onShow = function() B.SetHideNA(false) B.Window.hideNA:SetChecked(false) end }
    end
    local empty = Empty(D.CollectionState(), n, hc + hf > 0, words)
    ui.list:SetShown(not empty)
    if not empty then
        shown = out
        ui.list:SetData(out, keep)
    end
    PaintHead()
    PaintLine(words)
end

local function Changed()
    Apply(false)
end

local function BuildToolbar(bar)
    local filters = CreateFrame("DropdownButton", nil, bar, "WowStyle1FilterDropdownTemplate")
    local sort = CreateFrame("DropdownButton", nil, bar, "WowStyle1DropdownTemplate")
    ui.sort = sort
    sort:SetPoint("RIGHT")
    sort:SetWidth(150)
    filters:SetPoint("RIGHT", sort, "LEFT", -SP.xs, 0)
    filters:SetWidth(100)
    filters.resizeToText = false
    filters:SetText(L["Filters"])
    filters:SetupMenu(function(_, root)
        local function Box(text, key, types)
            root:CreateCheckbox(text, function() return (types and cat.types or cat)[key] end, function()
                local t = types and cat.types or cat
                t[key] = not t[key]
                Changed()
            end)
        end
        Box(L["Collected"], "coll")
        Box(L["Not collected"], "notColl")
        Box(L["Can get now"], "canGet")
        Box(L["First-Time Collection Bonus"], "bonus")
        root:CreateDivider()
        for _, k in ipairs(KEYS) do Box(TYPE[k], k, true) end
        root:CreateDivider()
        root:CreateButton(L["Reset filters"], Reset)
    end)
    sort:SetSelectionTranslator(function(sel) return L["Sort: %s"]:format(SORT[sel.data]) end)
    sort:SetupMenu(function(_, root)
        for _, k in ipairs({ "best", "name", "price" }) do
            root:CreateRadio(SORT[k], function() return cat.sort == k end, function()
                sort.Set(k)
                Apply(false)
            end, k)
        end
    end)
    function sort.Set(k)
        cat.sort = k
        sort:GenerateMenu()
    end
end

local function Fit()
    ui.bar:SetHeight(W.TextHeight("body") + 2 * SP.s)
end

function Page:Build(parent)
    -- The dropdowns build their menus at SetupMenu and again when shown, before Show runs, and read the view.
    cat = NewView()
    local bar = CreateFrame("Frame", nil, parent)
    ui.bar = bar
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    Fit()
    BuildToolbar(bar)
    local body = W.Well(parent)
    body:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -SP.xs)
    body:SetPoint("BOTTOMRIGHT")
    local head = S.Text(body, "bodyMuted", "OVERLAY")
    ui.head = head
    head:SetPoint("TOPLEFT", LO.wellPad, -LO.wellPad)
    head:SetPoint("TOPRIGHT", -LO.wellPad, -LO.wellPad)
    head:SetJustifyH("LEFT")
    head:SetWordWrap(false)
    local fl = CreateFrame("Button", nil, body)
    ui.fl = fl
    fl:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
    fl:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT")
    fl:SetScript("OnClick", Reset)
    fl.text = S.Text(fl, "bodyMuted", "OVERLAY")
    fl.text:SetAllPoints()
    fl.text:SetJustifyH("LEFT")
    fl.text:SetWordWrap(false)
    local holder = CreateFrame("Frame", nil, body)
    holder:SetPoint("TOPLEFT", fl, "BOTTOMLEFT", -LO.wellPad, 0)
    holder:SetPoint("BOTTOMRIGHT", -LO.wellPad, LO.wellPad)
    ui.list = W.NewList(holder, {
        kinds = { item = ITEM, footer = W.footerKind },
        extent = function(d)
            return d.kind == "footer" and W.FooterHeight(d, ui.list.box:GetWidth()) or W.RowHeight()
        end,
    })
    ui.empty = W.NewEmptyState(holder)
end

function Page:Placeholder()
    return L["Search decor"]
end

-- A forward Show starts from the route's kind and seed, keeping only the sort; Back gives saved.
function Page:Show(route, saved)
    if saved then
        cat, query = saved.view, saved.query
    else
        local seed = route.seed or {}
        local f = seed.filters or {}
        cat = NewView(seed.sort or cat.sort)
        query = seed.search or ""
        cat.q = query:lower():match("^%s*(.-)%s*$")
        cat.kind = KIND[route.key] and route.key or "all"
        if f.collected or f.notCollected then cat.coll, cat.notColl = f.collected == true, f.notCollected == true end
        cat.canGet, cat.bonus = f.canGet == true, f.bonus == true
        for k in pairs(cat.types) do cat.types[k] = f.sources == nil or f.sources[k] == true end
    end
    B.Window.SetSearch(query)
    ui.sort.Set(cat.sort)
    if not recs or version ~= D.MemoVersion() or hideFor ~= B.State.hideNA then
        walk = B.Walk()
        Rebuild()
    end
    Rezone()
    Apply(false)
    if saved then ui.list.box:ScrollToOffset(saved.scroll, true) end
end

-- A forward Show builds a new view, so the one saved here is never touched again before Back gives it back.
function Page:Save()
    return { view = cat, query = query, scroll = ui.list.box:GetDerivedScrollOffset() }
end

-- The header box as the player types; a restore or a seed never gets here.
function Page:Filter(text)
    query = text
    local q = text:lower():match("^%s*(.-)%s*$")
    if q == cat.q then return end
    cat.q = q
    Apply(false)
end

function Page:Hide()
    B.HideTooltip()
end

-- Only "data" reads the walk. The rest reuse the cached records, and may follow Hide without a Show.
function Page:Refresh(reason)
    if not recs then return end
    if reason == "layout" or reason == "paint" then
        if reason == "layout" then
            Fit()
            PaintHead()
            PaintLine(Words(cat))
            ui.list:SetData(shown, true)
        end
        W.RepaintRows(ui.list)
    elseif reason == "zone" or reason == "stats" then
        if reason == "zone" then
            if Rezone() and cat.sort == "best" then Apply(true) end
        end
    else
        if reason == "data" then walk = B.Walk() end
        Rebuild()
        Apply(true)
    end
end

-- Nothing on the list waits for the end of combat.
function Page:SetCombat() end

B.RegisterPage("catalog", Page)
