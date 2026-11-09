-- Catalog: every decor item, with filters and sorts
local _, HA = ...

local B, L = HA.DecorBrowser, HA.L
local S, W, D, CG = B.Style, B.Widgets, B.Data, B.CanGet
local SP, K, LO = S.space, S.color, S.layout

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

local Page, ui, orders = {}, {}, {}
local cat, recs, walk, version, hideFor, judged, named, bare, bareList, bareVer
local hiddenNote
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
    version, hideFor, judged, named = D.MemoVersion(), B.State.hideNA, CG.Gen(), D.NameGen()
    wipe(orders)
    recs = {}
    for i, e in ipairs(walk and walk.list or BareEntries()) do
        local r = { kind = "item", id = e.itemID, e = e, lname = e.name and e.name:lower() or "",
            hasName = e.name ~= nil, cat = KindOf(e.info), bonus = e.bonus,
            done = e.own == "owned", hid = hideFor and (walk and (e.own == "owned" and "collected" or e.factionOnly and "faction" or nil) or not walk and CG.HiddenBy(e.itemID)) or nil }
        r.g = walk and Group(e) or 1
        recs[i] = r
    end
end

-- A re-judge or account data changed the verdicts and words under the records: regroup them and drop what was
-- built from the old ones, without rebuilding the records.
local function Rejudged()
    wipe(orders)
    for _, r in ipairs(recs) do r.g, r.d = walk and Group(r.e) or 1, nil end
    judged = CG.Gen()
end

-- The lowest gold-only price at any of the item's vendors: listed sources, then unlisted holiday vendors. The
-- source list changes with the season, but the two together always cover the same vendors, so the cached
-- value holds until the records rebuild.
local function Gold(itemID)
    local low, seen = math.huge, {}
    local function Take(c)
        if c and CG.GoldOnly(c) then low = math.min(low, c.gold) end
    end
    for _, s in ipairs(HA.SourceManager:GetAllSources(itemID) or {}) do
        if s.type == "vendor" and s.data then
            if s.data.npcID then seen[s.data.npcID] = true end
            Take(D.SourceCost(itemID, s.data))
        end
    end
    for _, npcID in ipairs(HA.VendorData:GetHolidayVendorsForItem(itemID) or {}) do
        if not seen[npcID] then Take(HA.SourceManager:GetVendorItemCost(itemID, HA.VendorData:GetVendorAnySeason(npcID))) end
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

local function Name(r)
    return r.e.name or L["Item %d"]:format(r.id)
end

-- What a tile draws. Its price, source and confirmation are in the tooltip.
local function Describe(r)
    local d, e, id = r.d, r.e, r.id
    if not d then
        local active, state, arg = nil, B.ItemState(id)
        for _, o in pairs(e.canBy or {}) do active = active or o.event end
        local info = e.info
        local copies = info and D.CountsLive() and (info.totalNumPlaced or 0) + (info.totalNumStored or 0) or 0
        d = { itemID = id, name = Name(r), quality = info and info.quality or C_Item.GetItemQualityByID(id),
            icon = info and info.iconTexture or D.ItemIcon(id), active = active, bonus = r.bonus,
            copies = copies > 0 and copies or nil, state = state, arg = arg }
        r.d = d
    end
    return d
end

-- Over the grid only when the collection is stale, and then just the note; one pixel otherwise.
local function PaintHead()
    local stale = D.CollectionStale()
    ui.head:SetShown(stale)
    ui.head:SetHeight(stale and W.TextHeight("body") + SP.s or 1)
    ui.head:SetText(stale and L["Collection not refreshed this session"] or "")
end

local function PaintLine(words)
    ui.fl:SetShown(words ~= "")
    ui.fl:SetHeight(words ~= "" and W.TextHeight("body") + SP.s or 1)
    ui.fl.text:SetText(L["Filtered: %s"]:format(words) .. " \194\183 " .. S.Colored(K.gold, L["Reset filters"]))
end

-- The hidden-items line sits between the filter line and the grid, as wide as the filter line: one line's
-- height, or one pixel when it is not shown.
local function PaintFixed()
    local line = ui.hidden
    line.d = hiddenNote
    line:SetShown(hiddenNote ~= nil)
    line:SetHeight(hiddenNote and W.FooterHeight(hiddenNote, math.max(ui.fl:GetWidth(), 1)) or 1)
    if hiddenNote then W.footerKind.init(line, hiddenNote) end
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
    local empty = Empty(D.CollectionState(), n, hc + hf > 0, words)
    hiddenNote = not empty and hc + hf > 0 and { hidden = hc + hf, collected = hc, faction = hf,
        parts = B.Facts.FactionParts(seen),
        onShow = function() B.SetHideNA(false) B.Window.hideNA:SetChecked(false) end } or nil
    PaintFixed()
    ui.grid:SetShown(not empty)
    if not empty then
        shown = out
        ui.grid:SetData(out, keep)
    end
    PaintHead()
    PaintLine(words)
end

local function Changed()
    Apply(false)
end

-- What a tile's corners mean, each state with the mark it draws.
local KEY_STATES = {
    { "owned", L["Collected: you own it"] },
    { "can", L["Can get now: this character can get it today"] },
    { "short", L["Not enough: this character can't pay for it yet"] },
    { "locked", L["Locked: a requirement isn't met yet"] },
    { "faction", L["Other faction only: this character's faction can't get it"] },
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
    Line(L["First-Time Collection Bonus"], "star", K.gold)
    Corner(L["Bottom left"])
    Line(L["Its event is active now"], "clock", K.badge)
    Corner(L["Bottom right"])
    Line(L["How many you own, placed and stored"])
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
    fl:SetScript("OnSizeChanged", PaintFixed)
    local holder = CreateFrame("Frame", nil, body)
    holder:SetPoint("TOPLEFT", hidden, "BOTTOMLEFT", 0, -SP.xs)
    holder:SetPoint("BOTTOMRIGHT", -LO.wellPad, LO.wellPad)
    ui.grid = W.NewTileGrid(holder, S.tile.min, S.tile.gap, Describe, Name)
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
    if not recs or version ~= D.MemoVersion() or hideFor ~= B.State.hideNA or named ~= D.NameGen() then
        walk = B.Walk()
        Rebuild()
    elseif judged ~= CG.Gen() then
        Rejudged()
    end
    Apply(false)
    if saved then ui.grid.box:ScrollToOffset(saved.scroll, true) end
end

-- A forward Show builds a new view, so the one saved here is never touched again before Back gives it back.
function Page:Save()
    return { view = cat, query = query, scroll = ui.grid.box:GetDerivedScrollOffset() }
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
            PaintFixed()
            ui.grid:SetData(shown, true)
        end
        W.RepaintRows(ui.grid)
    elseif reason == "zone" or reason == "stats" then
        return
    elseif reason == "wallet" then
        Rejudged()
        Apply(true)
    else
        if reason == "data" then walk = B.Walk() end
        Rebuild()
        Apply(true)
    end
end

-- Nothing on the list waits for the end of combat.
function Page:SetCombat() end

B.RegisterPage("catalog", Page)
