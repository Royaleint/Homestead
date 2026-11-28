-- Catalog: every decor item, with filters and sorts
local _, HA = ...

local B, L = HA.DecorBrowser, HA.L
local S, W, D, CG = B.Style, B.Widgets, B.Data, B.CanGet
local SP, K, LO = S.space, S.color, S.layout

-- The Catalog's own steps are traced inside the page's draw, so the performance report can tell them apart.
local function Trace(operation, workload, fn, ...)
    return HA.PerformanceTrace:Measure(operation, workload, fn, ...)
end

local KEYS = CG.SOURCE_KEYS
local KIND, KindOf = S.kind, S.KindOf
local TYPE = S.sourceLabel
local SORT = { best = L["Best to get now"], name = L["Name"], price = L["Price"] }
-- The best-sort group from the walk alone (can; other; short, unpriced, locked or event; faction; owned); drawn rows judge their words.
local function Group(e)
    if e.own ~= "notOwned" then return e.own == "owned" and 4 or 1 end
    if e.verdict == "can" then return 0 end
    if e.factionOnly then return 3 end
    local v = e.verdict
    return (e.locked or v == "short" or v == "unpriced" or v == "unlisted" and e.event) and 2 or 1
end

local Page, ui = {}, {}
local cat, walk, readGen, readVer, bareList, drawn
-- fromWalk: the tiles on screen were drawn from a published walk.
local hiddenNote, fromWalk
-- A decor item's catalog record, as the last walk or the counting records read it.
local bareInfo = {}
local shown = {}
-- The records drawn from the walk, and the ones drawn while there is none, each kept per item with its sorted
-- orders, so going into a check and out of it again rebuilds and sorts neither. set is the one drawn now.
local sets = { walk = { byId = {}, orders = {}, keys = {} }, bare = { byId = {}, orders = {}, keys = {} } }
local set

local function NewView(sort)
    local types = {}
    for _, k in ipairs(KEYS) do types[k] = true end
    return { kind = "all", coll = true, notColl = true, canGet = false, bonus = false,
        types = types, sort = sort or "best" }
end

local function Words(c)
    local f, on = {}, {}
    if c.coll ~= c.notColl then f[1] = c.coll and L["Collected"] or L["Not Collected"]
    elseif not c.coll then f[1] = L["Neither collected nor not collected"] end
    if c.canGet then f[#f + 1] = L["Can get now"] end
    if c.bonus then f[#f + 1] = L["Collection Bonus"] end
    for _, k in ipairs(KEYS) do
        if c.types[k] then on[#on + 1] = TYPE[k] end
    end
    if #on < #KEYS then f[#f + 1] = L["Sources: %s"]:format(table.concat(on, ", ")) end
    return table.concat(f, ", ")
end

-- The records drawn while there is no walk, one per decor item for the session. Kind and name do not move with
-- ownership, so each record's info is kept from the last walk, or read once; a tile reads its copies when it draws.
local function BareEntries()
    local ids = HA.CatalogStore:GetDecorItemIDs()
    if bareList and bareList.ids == ids and #bareList == #ids then
        -- New data may bring the records not read yet.
        local fresh = bareList.version ~= D.MemoVersion()
        bareList.version = D.MemoVersion()
        for _, e in ipairs(bareList) do
            local id = e.itemID
            e.info = e.info or bareInfo[id] or CG.KeptInfo(id) or fresh and D.CatalogInfo(id, B.State.catalogMemo) or nil
            bareInfo[id] = e.info
            e.name = e.name or D.ItemName(id, e.info)
        end
        return bareList
    end
    bareList = { ids = ids, version = D.MemoVersion() }
    for i, id in ipairs(ids) do
        local info = bareInfo[id] or CG.KeptInfo(id) or D.CatalogInfo(id, B.State.catalogMemo)
        bareInfo[id] = info
        bareList[i] = { itemID = id, info = info, name = D.ItemName(id, info), src = {} }
    end
    return bareList
end

-- The lowest gold-only price at any of the item's vendors, holiday vendors in any season, so the cached value
-- holds until the records rebuild.
local function Gold(itemID)
    local low = math.huge
    for _, s in ipairs(HA.SourceManager:GetAllSources(itemID) or {}) do
        local gold = s.type == "vendor" and s.data and CG.LowGold(D.SourceCost(itemID, s.data))
        if gold then low = math.min(low, gold) end
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

-- Each record's place in the best-first ranking of the walk drawn now.
local function SetRanks(recs)
    local rank = {}
    for i, e in ipairs(walk and CG.Rank() or {}) do rank[e.itemID] = i end
    for _, r in ipairs(recs) do r.rank = rank[r.id] or math.huge end
end

local function Order(sort)
    local o = set.orders[sort]
    if o then return o end
    o = {}
    for i, r in ipairs(set.recs) do o[i] = r end
    if sort == "best" then SetRanks(o) end
    if sort == "price" then
        for _, r in ipairs(o) do r.gold = r.gold or Gold(r.id) end
    end
    Trace("browser_catalog_sort", sort, table.sort, o, SORTERS[sort])
    set.orders[sort] = o
    return o
end

-- More moved records than this and a cached order is sorted afresh instead of mended.
local MEND_MAX = 64

-- Mends a cached order after the moved records' sort keys changed: the rest keep their order, which a pass over
-- neighbours confirms (a ranking that shifted under them fails it, and the order is then dropped to be sorted afresh),
-- and each moved record is put back where the sort puts it.
local function Mend(sort, moved)
    local o = set.orders[sort]
    if #moved > MEND_MAX then set.orders[sort] = nil return end
    local before = SORTERS[sort]
    if sort == "best" then SetRanks(set.recs) end
    local kept, n = {}, 0
    for _, r in ipairs(o) do
        if not r.moving then
            if n > 0 and before(r, kept[n]) then set.orders[sort] = nil return end
            n = n + 1
            kept[n] = r
        end
    end
    for _, r in ipairs(moved) do
        if sort == "price" then r.gold = r.gold or Gold(r.id) end
        local lo, hi = 1, n + 1
        while lo < hi do
            local mid = math.floor((lo + hi) / 2)
            if before(kept[mid], r) then lo = mid + 1 else hi = mid end
        end
        table.insert(kept, lo, r)
        n = n + 1
    end
    set.orders[sort] = kept
end

local function ReadWalk()
    walk, readGen, readVer = B.Walk(), CG.WalkGen(), D.MemoVersion()
end

-- Why Hide hides a record, if it does. With no walk, the other faction's answer already known stands. While a
-- check runs, an item with none known yet is shown: asking every item here would take one frame, and the check asks
-- each in its turn and draws again when it ends. With no check either, an item with none known is asked once; the
-- answer is kept for the session.
local function Hidden(e, done)
    if walk then return done and "collected" or e.factionOnly and "faction" or nil end
    local known = CG.KnownFactionOnly(e.itemID)
    if CG.Checking() then return known and "faction" or nil end
    if known == nil then return CG.HiddenBy(e.itemID) end
    local kept = CG.Entry(e.itemID)
    if kept and kept.own == "owned" then return "collected" end
    return known and "faction" or nil
end

-- Brings the drawn set's records up to the walk last read, names, filter, verdicts and wallet words now. A record whose
-- entry and name are unchanged keeps everything built from it but its tile words; one whose sort keys moved is mended
-- into the cached orders. Unless forced, nothing is done when none of those moved since the last time; returns
-- whether anything was done.
local function Sync(force)
    set = walk and sets.walk or sets.bare
    local k = set.keys
    local now = { B.State.hideNA, walk or false, D.NameGen(), CG.Renamed(), CG.VerdictGen(), CG.SourcesGen(), CG.Gen(),
        B.Generation(), D.MemoVersion() }
    local same = set.recs ~= nil and not force
    for i = 1, #now do same = same and k[i] == now[i] end
    if same then return false end
    local list = walk and walk.list or BareEntries()
    local recs, byId, hide, moved = set.recs, set.byId, now[1], {}
    if not recs or #recs ~= #list then
        recs = {}
        set.recs = recs
        wipe(set.orders)
    end
    -- Prices and faction names come from the sources.
    if k[6] ~= now[6] then
        for _, r in pairs(byId) do r.gold, r.fl = nil, nil end
        set.orders.price = nil
    end
    for i, e in ipairs(list) do
        local id = e.itemID
        local r = byId[id]
        if not r then
            r = { kind = "item", id = id }
            byId[id] = r
        end
        local g, done = walk and Group(e) or 1, e.own == "owned"
        if r.name ~= e.name or not r.e then
            local lname = e.name and HA.NameSortKey(e.name) or ""
            if r.lname ~= lname then r.moving = true end
            r.name, r.lname, r.hasName = e.name, lname, e.name ~= nil
        end
        if r.g ~= g or r.done ~= done then r.moving = true end
        if r.moving then moved[#moved + 1] = r end
        -- A counting record's info can come in after it was built.
        if r.e ~= e or r.info ~= e.info then r.e, r.info, r.cat, r.bonus = e, e.info, KindOf(e.info), e.bonus end
        r.g, r.done, r.d = g, done, nil
        r.hid = hide and Hidden(e, done) or nil
        if walk and e.info then bareInfo[id] = e.info end
        recs[i] = r
    end
    local ranked = k[2] ~= now[2] or k[5] ~= now[5]
    -- Only the order drawn now is mended; another that would need it is dropped, to be sorted if it is chosen.
    for sort in pairs(set.orders) do
        if moved[1] or ranked and sort == "best" then
            if sort == cat.sort then Mend(sort, moved) else set.orders[sort] = nil end
        end
    end
    for _, r in ipairs(moved) do r.moving = nil end
    set.keys = now
    return true
end

local function SameList(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

-- Collected and Not collected match owned and notOwned only; unknown ownership is in neither.
local function Passes(r, c, anyOwn, subset)
    local e = r.e
    if c.kind ~= "all" and r.cat ~= c.kind then return false end
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

-- Clears the filters, keeping the kind and the sort.
local function Reset()
    local kind = cat.kind
    cat = NewView(cat.sort)
    cat.kind = kind
    Apply(false)
end

local function Name(r)
    return r.e.name or L["Item %d"]:format(r.id)
end

-- What a tile draws. Its price, source and confirmation are in the tooltip.
local function Describe(r)
    local d, e, id = r.d, r.e, r.id
    if not d then
        local active, state, arg = nil, B.ItemState(id)
        for _, o in pairs(e.canBy or {}) do active = active or o.event end
        local info = walk and CG.Rec(e)
            or select(3, HA.CatalogScanner:GetReadState()) and D.CatalogInfo(id, B.State.catalogMemo) or e.info or {}
        d = { itemID = id, name = Name(r), quality = info.quality or C_Item.GetItemQualityByID(id),
            icon = info.iconTexture or D.ItemIcon(id), active = active, bonus = r.bonus,
            copies = D.Copies(info), state = state, arg = arg }
        r.d = d
    end
    return d
end

-- Over the grid only when the collection is stale, and then just the note; one pixel otherwise.
local function PaintHead()
    local stale = select(2, D.ReadState())
    ui.head:SetShown(stale)
    ui.head:SetHeight(stale and W.TextHeight("body") + SP.s or 1)
    ui.head:SetText(stale and L["Collection not refreshed this session"] or "")
end

local function PaintLine(words)
    ui.fl:SetShown(words ~= "")
    ui.fl:SetHeight(words ~= "" and W.TextHeight("body") + SP.s or 1)
    ui.fl.text:SetText(L["Filtered: %s"]:format(words) .. " \194\183 " .. S.Colored(K.gold, L["Reset filters"]))
end

-- The hidden-items line sits between the filter line and the grid, as wide as the filter line, or one pixel when it
-- is not shown. Its text is measured at its own width once shown, as one line until it has a width (it is measured
-- again when it gets one), and never as more than two, so the grid below keeps its room.
local function PaintFixed()
    local line = ui.hidden
    line.d = hiddenNote
    line:SetShown(hiddenNote ~= nil)
    line:SetHeight(hiddenNote and W.FooterHeight(hiddenNote, line:GetWidth(), 2) or 1)
    if hiddenNote then W.footerKind.init(line, hiddenNote) end
end

local function Empty(status, n, hidden, words)
    local c, kind, d = cat, "noResults", { onReset = Reset }
    if status ~= "ready" and (words ~= "" or (status == "counting" and c.sort == "best")) then
        kind = status == "counting" and "counting" or "notReadFilters"
        if kind == "counting" and c.sort == "best" then
            kind, d.onSort = "countingSort", function() ui.sort.Set("name") Apply(false) end
        end
    elseif n > 0 or hidden then
        ui.empty:Hide()
        return false
    end
    ui.empty:Set(kind, d)
    return true
end

function Apply(keep, force)
    local words, status = Words(cat), D.ReadState()
    local out, n, hc, hf, seen, synced = {}, 0, 0, 0, {}, false
    -- Counting with a filter on, or best first, draws its words over no tiles: the records wait for a draw that
    -- shows them.
    if status == "ready" or words == "" and not (status == "counting" and cat.sort == "best") then
        synced = Trace("browser_catalog_sync", nil, Sync, force)
        out, n, hc, hf, seen = Filter()
    end
    local empty = Empty(status, n, hc + hf > 0, words)
    fromWalk = walk ~= nil and not empty
    hiddenNote = not empty and hc + hf > 0 and { hidden = hc + hf, collected = hc, faction = hf,
        parts = B.Facts.FactionParts(seen),
        onShow = function() B.SetHideNA(false) B.Window.hideNA:SetChecked(false) end } or nil
    PaintFixed()
    ui.grid:SetShown(not empty)
    -- The same records with nothing rebuilt under them draw the same tiles: the grid keeps them, back at the top
    -- unless the place is kept.
    if not empty and not synced and SameList(out, shown) then
        if not keep then ui.grid.box:ScrollToOffset(0, true) end
    elseif not empty then
        shown = out
        Trace("browser_catalog_grid", n, ui.grid.SetData, ui.grid, out, keep)
    end
    PaintHead()
    PaintLine(words)
end

local function Changed()
    Apply(false)
end

-- What a tile's corners mean, each state with the mark it draws.
local KEY_STATES = {
    { "owned", L["Collected: it's in your collection"] },
    { "can", L["Can get now: this character can get it today"] },
    { "short", L["Not enough: this character can't pay for it yet"] },
    { "locked", L["Locked: a requirement isn't met yet"] },
    { "faction", L["Opposite faction only: this character's faction can't get it"] },
    { "event", L["Event only: available while its event runs"] },
}

local function KeyTip(owner)
    local tip, gold = B.Tooltip(), NORMAL_FONT_COLOR
    local function Line(text, glyph, c)
        local mark = glyph and B.Vis.Marker.Markup(glyph, c, 14)
        tip:AddLine(mark and mark .. " " .. text or text, 1, 1, 1, true)
    end
    local function Corner(text) tip:AddLine(text, gold.r, gold.g, gold.b) end
    tip:SetOwner(owner, "ANCHOR_BOTTOMLEFT")
    tip:SetText(L["Tile markers"], 1, 1, 1)
    Corner(L["Top right"])
    for _, s in ipairs(KEY_STATES) do
        local st = S.state[s[1]]
        Line(s[2], st.glyph, st.color)
    end
    Corner(L["Top left"])
    Line(L["Collection Bonus"], "star", K.gold)
    Corner(L["Bottom left"])
    Line(L["Its event is active now"], "clock", K.badge)
    Corner(L["Bottom right"])
    Line(L["How many you have collected, placed and stored"])
    tip:Show()
end

local function BuildToolbar(bar)
    local filters = CreateFrame("DropdownButton", nil, bar, "WowStyle1FilterDropdownTemplate")
    local sort = CreateFrame("DropdownButton", nil, bar, "WowStyle1DropdownTemplate")
    ui.sort = sort
    sort:SetPoint("RIGHT")
    sort:SetWidth(150)
    filters:SetPoint("RIGHT", sort, "LEFT", -SP.xs, 0)
    filters:SetWidth(100)
    -- Blizzard's hover-help "i", beside the controls it explains.
    local help = CreateFrame("Button", nil, bar)
    help:SetSize(26, 26)
    help:SetPoint("RIGHT", filters, "LEFT", -SP.xs, 0)
    help:SetNormalTexture([[Interface\common\help-i]])
    local glow = help:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetTexture([[Interface\common\help-i]])
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 1, 1, 0.2)
    help:SetScript("OnEnter", KeyTip)
    help:SetScript("OnLeave", B.HideTooltip)
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
        Box(L["Not Collected"], "notColl")
        Box(L["Can get now"], "canGet")
        Box(L["Collection Bonus"], "bonus")
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
    local head = S.Text(body, "body", "OVERLAY")
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
    fl.text = S.Text(fl, "body", "OVERLAY")
    fl.text:SetAllPoints()
    fl.text:SetJustifyH("LEFT")
    fl.text:SetWordWrap(false)
    local hidden = CreateFrame("Frame", nil, body)
    ui.hidden = hidden
    hidden:SetPoint("TOPLEFT", fl, "BOTTOMLEFT")
    hidden:SetPoint("TOPRIGHT", fl, "BOTTOMRIGHT")
    W.footerKind.build(hidden)
    -- Measured by its own size: the filter line is hidden whenever no filter is on.
    hidden:SetScript("OnSizeChanged", PaintFixed)
    local holder = CreateFrame("Frame", nil, body)
    holder:SetPoint("TOPLEFT", hidden, "BOTTOMLEFT", 0, -SP.xs)
    holder:SetPoint("BOTTOMRIGHT", -LO.wellPad, LO.wellPad)
    ui.grid = W.NewTileGrid(holder, Describe)
    ui.empty = W.NewEmptyState(holder)
end

-- A forward Show starts from the route's kind and seed, keeping only the sort; Back gives saved.
function Page:Show(route, saved)
    if saved then
        cat = saved.view
    else
        local seed = route.seed or {}
        local f = seed.filters or {}
        cat = NewView(seed.sort or cat.sort)
        cat.kind = KIND[route.key] and route.key or "all"
        if f.collected or f.notCollected then cat.coll, cat.notColl = f.collected == true, f.notCollected == true end
        cat.canGet, cat.bonus = f.canGet == true, f.bonus == true
        for k in pairs(cat.types) do cat.types[k] = f.sources == nil or f.sources[k] == true end
    end
    ui.sort.Set(cat.sort)
    drawn = true
    -- A check that started or published since the walk was last read changed it.
    if readGen ~= CG.WalkGen() or readVer ~= D.MemoVersion() then ReadWalk() end
    Apply(false)
    if saved then ui.grid.box:ScrollToOffset(saved.scroll, true) end
end

-- A forward Show builds a new view, so the one saved here is never touched again before Back gives it back.
function Page:Save()
    return { view = cat, scroll = ui.grid.box:GetDerivedScrollOffset() }
end

function Page:Hide()
    B.HideTooltip()
end

-- Only Show, "data" and "return" read the walk. Layout and paint draw the shown tiles again; the rest bring the
-- records up to date (only what moved under them; data and names look at every name again), and may follow Hide
-- without a Show.
function Page:Refresh(reason)
    if not drawn then return end
    if reason == "layout" or reason == "paint" then
        if reason == "layout" then
            Fit()
            PaintHead()
            PaintLine(Words(cat))
            PaintFixed()
            ui.grid:SetData(shown, true)
        end
        W.RepaintRows(ui.grid)
    elseif reason ~= "zone" and reason ~= "stats" then
        if reason == "data" or reason == "return" then ReadWalk() end
        -- A check rebuilding the walk leaves the tiles drawn from the last one up, rather than Counting or the
        -- counting records in their place, until its publish draws again. The Hide switch is drawn at once.
        if fromWalk and reason ~= "hide" and CG.Checking() then return end
        Apply(true, reason == "data" or reason == "names")
    end
end

-- Nothing on the list waits for the end of combat.
function Page:SetCombat() end

B.RegisterPage("catalog", Page)
