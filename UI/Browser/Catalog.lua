-- Catalog tab: every decor item in a virtual list with filters and sorts, the item detail beside it.
local _, HA = ...

local B, L = HA.DecorBrowser, HA.L
local S, W, D, CG = B.Style, B.Widgets, B.Data, B.CanGet
local SP, K = S.space, S.color

local KEYS = CG.SOURCE_KEYS
local NAV = { "all", 1, 2, 3, 4, "other" }
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

local Tab, ui, orders = {}, {}, {}
local cat, recs, counts, walk, version, hideFor, bare
local shown = {}
local shownSel, silent = false, false

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

-- Before the collection is ready there is no walk: the same domain rule gives entries to name and sort.
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
    local list = {}
    for i, id in ipairs(bare) do
        local info = D.CatalogInfo(id, B.State.catalogMemo)
        list[i] = { itemID = id, info = info, name = D.ItemName(id, info), src = {} }
    end
    return list
end

local function Rebuild()
    version, hideFor = D.MemoVersion(), B.State.hideNA
    wipe(orders)
    counts, recs = {}, {}
    for i, e in ipairs(walk and walk.list or BareEntries()) do
        local r = { kind = "item", id = e.itemID, e = e, lname = e.name and e.name:lower() or "",
            hasName = e.name ~= nil, cat = KindOf(e.info), bonus = e.bonus,
            done = e.own == "owned", hid = hideFor and (walk and (e.own == "owned" and "collected" or e.factionOnly and "faction" or nil) or not walk and CG.HiddenBy(e.itemID)) or nil }
        r.g = walk and Group(e) or 1
        recs[i] = r
        counts[r.cat] = (counts[r.cat] or 0) + 1
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

-- A sorted copy of the records; kept until the data, the names or (Best) the zone change.
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

-- The matching records in order, their count, whether the selection is among them, and the Hide counts.
local function Filter()
    local c, out, n, hc, hf, sel, subset, seen = cat, {}, 0, 0, 0, false, false, {}
    for _, k in ipairs(KEYS) do
        if not c.types[k] then subset = true end
    end
    for _, r in ipairs(Order(c.sort)) do
        local pinned = r.id == c.pin
        if pinned or Passes(r, c, c.coll and c.notColl, subset) then
            if r.hid and not pinned then
                if r.hid == "collected" then hc = hc + 1
                else
                    hf = hf + 1
                    r.fl = r.fl or CG.FactionLabel(r.id) or ""
                    seen[r.fl] = (seen[r.fl] or 0) + 1
                end
            else
                n = n + 1
                out[n] = r
                sel = sel or r.id == c.sel
            end
        end
    end
    return out, n, sel, hc, hf, seen
end

local Apply, ShowDetail

local function Reset()
    local v = NewView(cat.sort)
    v.kind, v.sel = cat.kind, cat.sel
    cat = v
    silent = true
    ui.search:SetText("")
    silent = false
    Apply(false)
end

local Pick

local function Describe(r)
    local d, e, id = r.d, r.e, r.id
    if not d then
        local sources = D.ItemSources(id)
        local p = CG.Primary(id, sources)
        local v = p and p.type == "vendor" and p.npcID and HA.VendorData:GetVendor(p.npcID)
        local active, state, arg = nil, B.ItemState(id)
        for _, o in pairs(e.canBy or {}) do active = active or o.event end
        d = { itemID = id, name = e.name or L["Item %d"]:format(id),
            quality = e.info and e.info.quality or C_Item.GetItemQualityByID(id),
            icon = e.info and e.info.iconTexture or D.ItemIcon(id), active = active, bonus = r.bonus,
            right = p and p.price, line2 = D.SourceLine(id, { p }) .. (#sources > 1 and " " .. L["(+%d more)"]:format(#sources - 1) or ""),
            unconfirmed = v and not B.Facts.Confirmed(v) or nil, state = state, arg = arg,
            onClick = function() Pick(id) end }
        r.d = d
    end
    d.selected = cat.sel == id
    return d
end

function Pick(id)
    cat.sel = id
    ui.list.box:ForEachFrame(function(f)
        if f.rec then f:Set(Describe(f.rec)) end
    end)
    ShowDetail()
end

local ITEM = { frameType = W.rowKind.frameType, build = W.rowKind.build,
    init = function(f, r) f.rec = r f:Set(Describe(r)) end }

function ShowDetail()
    shownSel = cat.sel
    if cat.sel then B.ItemDetail.Show(cat.sel) else B.ItemDetail.Clear() end
end

local function PaintNav()
    local h, y = W.TextHeight("body") + 2 * SP.s, 0
    for _, b in ipairs(ui.nav) do
        local n = b.key == "all" and #recs or counts[b.key] or 0
        local on = cat.kind == b.key
        b:SetShown(n > 0 or b.key == "all")
        b:SetHeight(h)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", ui.cols.nav, "TOPLEFT", 0, -y)
        b:SetPoint("TOPRIGHT", ui.cols.nav, "TOPRIGHT", 0, -y)
        y = y + (b:IsShown() and h or 0)
        b.count:SetText(n)
        b.bg:SetShown(on)
        b.label:SetTextColor(unpack(on and K.gold or K.body))
    end
end

local function PaintLine(words)
    ui.fl:SetShown(words ~= "")
    ui.fl:SetHeight(words ~= "" and W.TextHeight("body") + SP.s or 1)
    ui.fl.text:SetText(L["Filtered: %s"]:format(words) .. " \194\183 " .. S.Colored(K.gold, L["Reset filters"]))
end

local function Empty(status, n, hidden, words)
    local c, kind, d = cat, "noResults", { onReset = Reset }
    if status ~= "ready" and (words ~= "" or (status == "counting" and c.sort == "best" and not c.pin)) then
        kind = status == "counting" and "counting" or "notReadFilters"
        if kind == "counting" and c.sort == "best" then
            kind, d.onSort = "countingSort", function() ui.sort.Set("name") Apply(false) end
        end
    elseif n == 0 and not hidden then
        d.onAll = c.kind ~= "all" and function() c.kind, c.pin = "all", nil Apply(false) end or nil
    else
        ui.empty:Hide()
        return false
    end
    ui.empty:Set(kind, d)
    return true
end

-- Filters the cached records into the list. keep holds the scroll position; force refills the detail.
function Apply(keep, force)
    local out, n, sel, hc, hf, seen = Filter()
    local words = Words(cat)
    -- A landed id with no record (not decor, or unmapped) keeps its detail; no row is selected.
    if not sel then cat.sel = cat.pin or n > 0 and out[1].id or nil end
    if hc + hf > 0 then
        out[n + 1] = { kind = "footer", hidden = hc + hf, collected = hc, faction = hf, parts = B.Facts.FactionParts(seen),
            onShow = function() B.SetHideNA(false) B.Window.hideNA:SetChecked(false) end }
    end
    local empty = Empty(D.CollectionState(), n, hc + hf > 0, words)
    ui.list:SetShown(not empty)
    if empty then
        cat.sel = nil
    else
        shown = out
        ui.list:SetData(out, keep)
    end
    PaintNav()
    PaintLine(words)
    B.SetLocation(cat.kind == "all" and L["All decor"] or KIND[cat.kind])
    if force or cat.sel ~= shownSel then ShowDetail() end
end

local function Changed()
    cat.pin = nil
    Apply(false)
end

local function BuildNav(parent)
    ui.nav = {}
    for i, key in ipairs(NAV) do
        local b = CreateFrame("Button", nil, parent)
        b.key = key
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(unpack(K.selected))
        b.count = S.Text(b, "meta", "OVERLAY")
        b.count:SetPoint("RIGHT", -SP.s, 0)
        b.label = S.Text(b, "body", "OVERLAY")
        b.label:SetPoint("LEFT", SP.s, 0)
        b.label:SetPoint("RIGHT", b.count, "LEFT", -SP.xs, 0)
        b.label:SetJustifyH("LEFT")
        b.label:SetWordWrap(false)
        b.label:SetText(key == "all" and L["All decor"] or KIND[key])
        b:SetScript("OnClick", function()
            cat.kind = key
            Changed()
        end)
        ui.nav[i] = b
    end
end

local function BuildToolbar(bar)
    local filters = CreateFrame("DropdownButton", nil, bar, "WowStyle1FilterDropdownTemplate")
    local sort = CreateFrame("DropdownButton", nil, bar, "WowStyle1DropdownTemplate")
    ui.sort = sort
    sort:SetPoint("RIGHT")
    sort:SetWidth(150)
    filters:SetPoint("RIGHT", sort, "LEFT", -SP.xs, 0)
    filters:SetWidth(100)
    filters:SetDefaultText(L["Filters"])
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
    sort:SetupMenu(function(_, root)
        for _, k in ipairs({ "best", "name", "price" }) do
            root:CreateRadio(SORT[k], function() return cat.sort == k end, function()
                sort.Set(k)
                Apply(false)
            end, k)
        end
    end)
    sort:SetSelectionTranslator(function(sel) return L["Sort: %s"]:format(SORT[sel.data]) end)
    function sort.Set(k)
        cat.sort = k
        sort:GenerateMenu()
    end
    ui.search = W.NewSearchBox(bar, L["Search decor by name"], function(text)
        local q = text:lower():match("^%s*(.-)%s*$")
        if silent or not cat or q == cat.q then return end
        cat.q, cat.pin = q, nil
        Apply(false)
    end)
    ui.search:SetPoint("LEFT", SP.xs, 0)
    ui.search:SetPoint("RIGHT", filters, "LEFT", -SP.s, 0)
end

function Tab.Build(parent)
    local c = W.NewColumns(parent)
    ui.cols = c
    BuildNav(c.nav)
    BuildToolbar(c.toolbar)
    local fl = CreateFrame("Button", nil, c.body)
    ui.fl = fl
    fl:SetPoint("TOPLEFT", SP.s, -SP.xs)
    fl:SetPoint("TOPRIGHT", -SP.s, -SP.xs)
    fl:SetScript("OnClick", Reset)
    fl.text = S.Text(fl, "bodyMuted", "OVERLAY")
    fl.text:SetAllPoints()
    fl.text:SetJustifyH("LEFT")
    fl.text:SetWordWrap(false)
    local holder = CreateFrame("Frame", nil, c.body)
    holder:SetPoint("TOPLEFT", fl, "BOTTOMLEFT", -SP.s, 0)
    holder:SetPoint("BOTTOMRIGHT", -SP.xs, SP.xs)
    ui.list = W.NewList(holder, {
        kinds = { item = ITEM, footer = W.footerKind },
        extent = function(d)
            return d.kind == "footer" and W.FooterHeight(d, ui.list.box:GetWidth()) or W.RowHeight()
        end,
    })
    ui.empty = W.NewEmptyState(holder)
    B.ItemDetail.Build(c.detail)
end

-- nil keeps the view. A table resets search, kind and filters (sort stays), applies opts, then lands on itemID.
function Tab.Show(opts)
    local f = opts and opts.filters or {}
    if opts or not cat then
        cat = NewView(opts and opts.sort or cat and cat.sort)
        if opts then
            cat.q = (opts.search or ""):lower():match("^%s*(.-)%s*$")
            cat.kind = KIND[opts.kind] and opts.kind or "all"
            if f.collected or f.notCollected then cat.coll, cat.notColl = f.collected == true, f.notCollected == true end
            cat.canGet, cat.bonus = f.canGet == true, f.bonus == true
            for k in pairs(cat.types) do cat.types[k] = f.sources == nil or f.sources[k] == true end
            cat.sel = opts.itemID
            cat.pin = opts.itemID
            silent = true
            ui.search:SetText(opts.search or "")
            silent = false
        end
        ui.sort.Set(cat.sort)
    end
    if not recs or version ~= D.MemoVersion() or hideFor ~= B.State.hideNA then
        walk = B.Walk()
        Rebuild()
    end
    Apply(not opts, true)
    local id = opts and opts.itemID
    local at = id and ui.list.box:FindElementDataIndexByPredicate(function(d) return d.id == id end)
    if at then ui.list.box:ScrollToElementDataIndex(at) end
end

function Tab.Hide()
    shownSel = false
    B.ItemDetail.Clear()
end

-- Only "data" reads the walk. The rest reuse the cached records, and may follow Hide without a Show.
function Tab.Refresh(reason)
    if not cat then return end
    if reason == "layout" or reason == "paint" then
        if reason == "layout" then
            ui.cols:Fit()
            ui.search:SetHeight(W.TextHeight("body") + SP.s)
            PaintNav()
            PaintLine(Words(cat))
            ui.list:SetData(shown, true)
        end
        W.RepaintRows(ui.list)
        ShowDetail()
    elseif reason == "zone" or reason == "stats" then
        if reason == "zone" then orders.best = nil end
        if reason == "zone" and cat.sort == "best" then Apply(true, shownSel == false)
        elseif shownSel == false then ShowDetail() end
    else
        if reason == "data" then walk = B.Walk() end
        Rebuild()
        Apply(true, true)
    end
end

function Tab.SetCombat(inCombat)
    B.ItemDetail.SetCombat(inCombat)
end

B.RegisterTab("catalog", Tab)
