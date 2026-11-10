-- Overview page: what can be had now, the zone's best vendor and the first-use tip, from the memoised walk.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local S = B.Style
local W = B.Widgets
local D = B.Data
local CG = B.CanGet
local Facts = B.Facts
local K, SP, R, LO = S.color, S.space, S.row, S.layout

local TILE, MEASURE_W = 48, 600
local DOT = " \194\183 "

local Page = {}
local scroll, main, title, lede, tip, zone, empty, seeAll, strip, cards
local rows, bars = {}, {}
local at, tipForced, fill, filledFor

local function Text(parent, role, text, wrap)
    local fs = S.Text(parent, role, "OVERLAY")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(wrap == true)
    fs:SetText(text or "")
    return fs
end

local function CloseTip()
    tipForced = false
    local saved = B.Saved()
    if saved and not saved.tipSeen then B.Save("tipSeen", true) end
end

local function Open(itemID)
    if itemID then B.Go({ kind = "item", id = itemID }) end
end

local function Put(f, h, narrow)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", main, "TOPLEFT", 0, -at)
    if not narrow then f:SetPoint("TOPRIGHT", main, "TOPRIGHT", 0, -at) end
    if h then f:SetHeight(h) end
    f:Show()
    at = at + (h or f:GetHeight()) + SP.s
end

local function Why(e)
    local b, r, where = CG.Best(e), {}, Facts.Here()
    local near = Facts.Nearness(b.mapID, where)
    if b.event then r[#r + 1] = L["%s: active now"]:format(b.event) end
    if e.bonus then r[#r + 1] = L["First-Time Collection Bonus"] end
    local continent = near == 2 and C_Map.GetMapInfo(where.continent)
    if near == 1 and where.name then
        r[#r + 1] = L["Sold here in %s"]:format(where.name)
    elseif continent and continent.name then
        r[#r + 1] = L["Sold on %s"]:format(continent.name)
    elseif not (b.event or e.bonus) then
        r[#r + 1] = b.gold and L["Gold only, no requirements left"] or L["No requirements left"]
    end
    if #r < 2 and b.gold and (near <= 2 or e.bonus or b.event) then r[#r + 1] = L["Gold only"] end
    return table.concat(r, DOT, 1, math.min(#r, 2))
end

-- The source line and price of the vendor "Get it" names, or the state's vendor.
local function RowData(e, why, color)
    local p = CG.Primary(e.itemID)
    local v = p and p.npcID and D.Vendor(p.npcID)
    return { itemID = e.itemID, why = why, color = color, src = HA.FormatSourceLine(p and p.source),
        price = D.Price(e.itemID, v), e = e }, p, v
end

local function CanData(e)
    local d, p, v = RowData(e, Why(e))
    d.npcID = p.npcID
    local mapID, x, y
    if v then mapID, x, y = D.VendorLocation(v) end
    if mapID then d.wp = { mapID = mapID, x = x, y = y, title = v.name } end
    return d
end

local function NextData(c)
    local state, arg = B.ItemState(c.entry.itemID)
    local d = RowData(c.entry, W.StateWords(state, arg), S.state[state].color)
    d.dim = true
    return d
end

local function SetRow(r, d)
    local e = d.e
    r.itemID, r.npcID = d.itemID, d.npcID
    local cr, cg, cb = W.QualityRGB(e and D.IconData(e.itemID, true, B.State.catalogMemo))
    W.SetTile(r.tile, { icon = e and D.ItemIcon(e.itemID) }, cr, cg, cb)
    r.name:SetText(e and (e.name or L["Item %d"]:format(e.itemID)) or W.StateWords("counting"))
    r.name:SetTextColor(cr, cg, cb)
    r.why:SetText(d.why)
    r.why:SetTextColor(unpack(d.color or K.body))
    r.price:SetText(d.price or "")
    r.price:SetHeight(W.TextHeight("subheader"))
    r.src:SetText(d.src or "")
    r:SetAlpha(d.dim and 0.6 or 1)
    r.wp.wp = d.wp
    r.wp:SetShown(d.wp ~= nil)
    r.show:SetShown(d.npcID ~= nil and d.wp == nil)
end

local function BuildRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:RegisterForClicks("LeftButtonUp")
    local bg = r:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(K.card))
    local hover = r:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(unpack(K.hoverRow))
    r.tile = W.NewTile(r, TILE)
    r.tile.icon:SetPoint("LEFT", SP.m, 0)
    r.name, r.why, r.src, r.price = Text(r, "subheader"), Text(r, "body"), Text(r, "body"), Text(r, "subheader")
    r.price:SetJustifyH("RIGHT")
    r.price:SetTextColor(unpack(K.money))
    r.price:SetPoint("TOPRIGHT", r, "TOPRIGHT", -SP.xxl * 3, -R.pad)
    r.name:SetPoint("TOPLEFT", r, "TOPLEFT", TILE + 2 * SP.m, -R.pad)
    r.name:SetPoint("TOPRIGHT", r.price, "TOPLEFT", -SP.s, 0)
    r.why:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -R.gap)
    r.why:SetPoint("TOPRIGHT", r.price, "BOTTOMRIGHT", 0, -R.gap)
    r.src:SetPoint("TOPLEFT", r.why, "BOTTOMLEFT", 0, -R.gap)
    r.src:SetPoint("TOPRIGHT", r.why, "BOTTOMRIGHT", 0, -R.gap)
    r.wp = W.WaypointButton(r)
    r.show = W.NewButton(r, L["Show"], function() Open(r.itemID) end)
    r.wp:SetPoint("RIGHT", -SP.m, 0)
    r.show:SetPoint("RIGHT", -SP.m, 0)
    r:SetScript("OnClick", function() if not W.Linked(r.itemID) then Open(r.itemID) end end)
    r:SetScript("OnEnter", function() if r.itemID then B.ShowItemTooltip(r, r.itemID, r.npcID) end end)
    r:SetScript("OnLeave", B.HideTooltip)
    return r
end

-- A progress bar on the Endeavor bar's fill, drained of its own colour so each takes its tint. The collection's
-- bar also wears the Endeavor bar's frame, which overhangs it as it does in the Dashboard.
local function NewTrack(b, framed)
    local track = CreateFrame("StatusBar", nil, b)
    local art = C_Texture.GetAtlasInfo(S.atlas.fill) ~= nil
    track:SetStatusBarTexture(art and S.atlas.fill or S.tex.bar)
    track:GetStatusBarTexture():SetDesaturated(true)
    local back = track:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(unpack(K.barTrack))
    if framed and art and C_Texture.GetAtlasInfo(S.atlas.fillFrame) then
        local frame = track:CreateTexture(nil, "BACKGROUND", nil, 1)
        frame:SetAtlas(S.atlas.fillFrame)
        frame:SetPoint("TOPLEFT", -5, 5)
        frame:SetPoint("BOTTOMRIGHT", 8, -5)
    end
    return track
end

local function NewCard(parent)
    local b = CreateFrame("Button", nil, parent)
    b:RegisterForClicks("LeftButtonUp")
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(unpack(K.hoverRow))
    b:SetScript("OnClick", function(self) B.Go(self.route) end)
    return b
end

-- The whole collection: its name over the wide bar with its count inside.
local function BuildOverall(parent)
    local b = NewCard(parent)
    b.label = Text(b, "subheader")
    b.label:SetJustifyH("CENTER")
    b.label:SetPoint("TOP", 0, -SP.xs)
    b.track = NewTrack(b, true)
    b.track:SetPoint("BOTTOMLEFT", SP.s, SP.s)
    b.track:SetPoint("BOTTOMRIGHT", -SP.s, SP.s)
    b.track:SetHeight(S.bar.big)
    b.count = Text(b.track, "body")
    b.count:SetJustifyH("CENTER")
    b.count:SetPoint("CENTER")
    return b
end

-- A source type: its icon in the Dashboard's round well, its name and share, and a slim bar with the count under it.
local function BuildSource(parent)
    local b = NewCard(parent)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(S.bar.icon, S.bar.icon)
    if C_Texture.GetAtlasInfo(S.atlas.iconWell) then
        b.well = b:CreateTexture(nil, "BACKGROUND", nil, 1)
        b.well:SetAtlas(S.atlas.iconWell)
        b.well:SetPoint("CENTER", b.icon)
    end
    if C_Texture.GetAtlasInfo(S.atlas.iconRing) then
        b.ring = b:CreateTexture(nil, "OVERLAY")
        b.ring:SetAtlas(S.atlas.iconRing)
        b.ring:SetPoint("CENTER", b.icon)
    end
    b.pct = Text(b, "body")
    b.pct:SetJustifyH("RIGHT")
    b.label = Text(b, "bodyGold")
    b.label:SetPoint("RIGHT", b.pct, "LEFT", -SP.xs, 0)
    b.track = NewTrack(b)
    b.track:SetHeight(S.bar.track)
    b.count = Text(b, "meta")
    return b
end

local function BuildBlocks(parent)
    -- The best vendor here and the rest of this zone's, at the right of the title.
    zone = {}
    zone.btn = W.NewButton(parent, L["Show vendor"], function(self)
        local key = Facts.SourceKey("vendors", { npcID = self.npcID })
        if key then B.Go({ kind = "vendor", id = key }) end
    end)
    zone.more = W.NewButton(parent, L["More vendors here"], function(self)
        B.Go({ kind = "allVendors", seed = { zone = self.zone } })
    end)
    zone.btn:SetPoint("RIGHT", zone.more, "LEFT", -SP.s, 0)
    tip = W.Pane(parent)
    tip.text = Text(tip, "body", L["Can get now means this character can get it today: the right faction, no requirement left to meet, and enough gold or currency to pay. Gold-only and cheaper items come first. Use See all for the full list."], true)
    tip.text:SetPoint("TOPLEFT", SP.m, -SP.s)
    tip.text:SetPoint("TOPRIGHT", -(SP.xl + SP.s), -SP.s)
    local close = CreateFrame("Button", nil, tip, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() CloseTip() Page.Draw() end)
    empty = W.NewEmptyState(parent)
    seeAll = W.NewButton(parent, "", function()
        CloseTip()
        B.Go({ kind = "catalog", key = "all", seed = { filters = { canGet = true }, sort = "best" } })
    end)
    for i = 1, 3 do rows[i] = BuildRow(parent) end
end

function Page:Build(parent)
    scroll = CreateFrame("ScrollFrame", nil, parent, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -LO.scrollBarGap, 0)
    scroll.ScrollBar:SetHideIfUnscrollable(true)
    scroll.ScrollBar:ClearAllPoints()
    scroll.ScrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 3, -2)
    scroll.ScrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 3, 2)
    main = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(main)
    -- The rows that fit follow the height, and the strip under the page changes it.
    scroll:HookScript("OnSizeChanged", function(_, w, h)
        if (math.abs(w - main:GetWidth()) > 0.5 or math.abs(h - (scroll.drawnH or 0)) > 0.5) and scroll:IsVisible() then
            Page.Draw()
        end
    end)
    title = S.Text(main, "header", "OVERLAY")
    title:SetJustifyH("LEFT")
    title:SetText(L["What can I get now?"])
    lede = Text(main, "body", L["Decor this character can buy or earn today, best first."], true)
    BuildBlocks(main)
    -- The cards run the whole window's width under the tree and this page, in their own scroll when too tall.
    local area = B.Window.area
    strip = CreateFrame("ScrollFrame", nil, parent, "ScrollFrameTemplate")
    strip:SetPoint("BOTTOMLEFT", area, "BOTTOMLEFT", LO.pagePad, LO.pagePad)
    strip:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -LO.pagePad, LO.pagePad)
    strip.ScrollBar:SetHideIfUnscrollable(true)
    strip.ScrollBar:ClearAllPoints()
    strip.ScrollBar:SetPoint("TOPRIGHT", 0, -2)
    strip.ScrollBar:SetPoint("BOTTOMRIGHT", 0, 2)
    cards = CreateFrame("Frame", nil, strip)
    strip:SetScrollChild(cards)
    area:HookScript("OnSizeChanged", function()
        if strip:IsVisible() then Page.Draw() end
    end)
end

-- The buttons for the vendor here who sells the most this character can get now; none with no such vendor.
local function DrawZone(vendors, mapID)
    local best, most = nil, 0
    for _, v in ipairs(vendors) do
        local n = CG.VendorCanCount(v) or 0
        if n > most then best, most = v, n end
    end
    if not best then return end
    zone.btn.npcID, zone.more.zone = best.npcID, mapID
    zone.btn:SetShown(Facts.SourceKey("vendors", best) ~= nil)
    zone.btn:Fit()
    zone.more:Show()
end

-- The overall card, then one per source type: { label, owned, total, route, icon, colour }. Counts are nil until
-- the walk is ready.
local function BarGroups(walk)
    local p = walk and walk.progress
    local out = { { L["Your Collection Status"], p and p.owned, p and p.total, { kind = "catalog", key = "all" } } }
    for _, key in ipairs(CG.SOURCE_KEYS) do
        local c = p and p.src[key]
        out[#out + 1] = { S.sourceLabel[key], c and c.owned, c and c.total,
            key == "vendors" and { kind = "allVendors" } or { kind = "sources", key = key },
            HA.Constants.SourceBadgeAtlas[key:gsub("s$", "")], K.source[key] }
    end
    return out
end

local function SetCount(b, bar, tint)
    local ready = bar[2] ~= nil
    b.label:SetText(bar[1])
    b.count:SetText(ready and ("%d / %d"):format(bar[2], bar[3]) or W.StateWords("counting"))
    b.track:SetStatusBarColor(unpack(tint))
    b.track:SetMinMaxValues(0, math.max(bar[3] or 1, 1))
    b.track:SetValue(bar[2] or 0)
    b.route = bar[4]
    return ready
end

local function Place(b, x, y, w, h)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", cards, "TOPLEFT", x, -y)
    b:SetSize(w, h)
    b:Show()
end

-- The size of the icon well or ring as Blizzard draws it round its 44-wide reward icon, scaled to ours.
local function Ring(atlas)
    local info = C_Texture.GetAtlasInfo(atlas)
    local scale = (S.bar.icon + 2 * SP.xs) / 44
    return info and info.width * scale or 0, info and info.height * scale or 0
end

-- The collection's bar heads the strip, centred and as wide as a page column. The source types follow in even,
-- centred lines of cards at their own width, as many to a line as fit and spread evenly over as few lines as
-- that allows. Returns the height they take.
local function DrawBars(w)
    local walk = CG.Walk()
    local list = {}
    for i, bar in ipairs(BarGroups(walk)) do
        if i == 1 or not (walk and bar[3] == 0) then list[#list + 1] = bar end
    end
    bars[1] = bars[1] or BuildOverall(cards)
    for i = 2, #list do bars[i] = bars[i] or BuildSource(cards) end

    local all = bars[1]
    SetCount(all, list[1], K.gold)
    local overallW, overallH = math.min(w, MEASURE_W), W.TextHeight("subheader") + S.bar.big + SP.xs + 2 * SP.s
    Place(all, (w - overallW) / 2, 0, overallW, overallH)

    local wellW, wellH = Ring(S.atlas.iconWell)
    local ringW, ringH = Ring(S.atlas.iconRing)
    local slot = math.max(S.bar.icon, wellW, wellH, ringW, ringH)
    local textH = W.TextHeight("body") + S.bar.track + W.TextHeight("meta") + 2 * S.bar.gap
    local cardH = math.max(slot, textH) + 2 * SP.xs
    local k = #list - 1
    local n = math.max(1, math.min(k, math.floor((w + SP.s) / (S.bar.card + SP.s))))
    local lines = math.max(1, math.ceil(k / n))
    n = math.max(1, math.ceil(k / lines))
    local cw = math.min(S.bar.card, (w - (n - 1) * SP.s) / n)
    local top = overallH + SP.m
    for i = 2, #list do
        local b, bar = bars[i], list[i]
        local col, line = (i - 2) % n, math.floor((i - 2) / n)
        local inLine = math.min(n, k - line * n)
        local x0 = (w - inLine * cw - (inLine - 1) * SP.s) / 2
        Place(b, x0 + col * (cw + SP.s), top + line * (cardH + SP.s), cw, cardH)
        local ready = SetCount(b, bar, bar[6] or K.barFill)
        if b.well then b.well:SetSize(wellW, wellH) end
        if b.ring then b.ring:SetSize(ringW, ringH) end
        b.icon:SetAtlas(bar[5])
        b.icon:SetPoint("LEFT", SP.xs + (slot - S.bar.icon) / 2, 0)
        local textX = SP.xs + slot + SP.s
        local textTop = (cardH - textH) / 2
        b.pct:SetPoint("TOPRIGHT", -SP.xs, -textTop)
        b.pct:SetText(ready and ("%d%%"):format(math.floor(100 * bar[2] / math.max(bar[3], 1))) or "")
        b.label:SetPoint("TOPLEFT", textX, -textTop)
        local trackY = -(textTop + W.TextHeight("body") + S.bar.gap)
        b.track:SetPoint("TOPLEFT", textX, trackY)
        b.track:SetPoint("TOPRIGHT", -SP.xs, trackY)
        b.count:SetPoint("TOPLEFT", b.track, "BOTTOMLEFT", 0, -S.bar.gap)
    end
    return top + lines * cardH + (lines - 1) * SP.s
end

-- The strip takes the cards' height, up to half the page area; past that the cards scroll, narrowed for the bar.
local function DrawStrip()
    local w = B.Window.area:GetWidth() - 2 * LO.pagePad
    local cap = (B.Window.area:GetHeight() - 2 * LO.pagePad) / 2
    local h = DrawBars(w)
    if h > cap then
        w = w - LO.scrollBarGap
        h = DrawBars(w)
    end
    cards:SetSize(w, h)
    strip:SetHeight(math.min(h, cap))
    if strip:GetParent():IsShown() then B.Window.SetStrip(math.min(h, cap)) end
end

local function DrawEmpty(kind, d, button)
    empty:Set(kind, d)
    local h = W.TextHeight("subheader") + SP.xs + W.TextHeight("body", empty.text:GetText(), MEASURE_W)
    Put(empty, button and h + W.TextHeight("body") + 2 * SP.s or h)
end

function Page.Draw()
    if not main then return end
    if scroll:GetWidth() > 0 then main:SetWidth(scroll:GetWidth()) end
    for _, f in ipairs({ tip, zone.btn, zone.more, empty, seeAll, rows[1], rows[2], rows[3] }) do f:Hide() end
    for _, f in ipairs(bars) do f:Hide() end
    DrawStrip()
    local ranked = CG.Rank()
    if ranked ~= filledFor then fill, filledFor = ranked and CG.Fill(), ranked end
    local state = fill and "ready" or HA.CatalogScanner:GetReadState()
    at = 0
    -- The title with the vendor buttons at its right, its row as tall as they are even when hidden so the rows
    -- never move with the zone; then the lede with See all at its right.
    if fill then DrawZone(D.NearYou()) end
    zone.more:Fit()
    local titleH = math.max(W.TextHeight("header"), zone.more:GetHeight())
    Put(title, titleH, true)
    zone.more:SetPoint("TOPRIGHT", main, "TOPRIGHT", 0, -(titleH - zone.more:GetHeight()) / 2)
    local seeW = 0
    if fill and fill.count > 0 then
        seeAll:SetText(L["See all you can get now (%d)"]:format(fill.count))
        seeAll:Fit()
        seeAll:Show()
        seeW = seeAll:GetWidth() + SP.m
    end
    local ledeText = L["Decor this character can buy or earn today, best first."]
    if select(2, HA.CatalogScanner:GetReadState()) then ledeText = ledeText .. DOT .. L["Collection not refreshed this session"] end
    lede:SetText(ledeText)
    local ledeW = (main:GetWidth() > 0 and math.min(MEASURE_W, main:GetWidth()) or MEASURE_W) - seeW
    lede:SetWidth(ledeW)
    local ledeH = math.max(W.TextHeight("body", ledeText, ledeW), seeW > 0 and seeAll:GetHeight() or 0)
    seeAll:SetPoint("TOPRIGHT", main, "TOPRIGHT", 0, -at)
    Put(lede, ledeH, true)
    local saved = B.Saved()
    if tipForced or (saved and not saved.tipSeen) then
        Put(tip, W.TextHeight("body", tip.text:GetText(), MEASURE_W - SP.xxl) + 2 * SP.s)
    end
    local list = {}
    if fill then
        if fill.allCollected then
            DrawEmpty("nothingMissing", { arg = CG.Walk().progress.total })
        elseif fill.count == 0 then
            local who = Facts.OtherFaction(CG.MissingFactions())
            DrawEmpty("nothingNow", { arg = who, text = not who
                    and L["Everything you're missing needs a reputation, achievement or quest first, or is sold only during an event."] or nil,
                onMissing = function() B.Go({ kind = "catalog", key = "all", seed = { filters = { notCollected = true } } }) end }, true)
        end
        for i, e in ipairs(fill.rows) do list[i] = CanData(e) end
        for _, c in ipairs(fill.notYet) do list[#list + 1] = NextData(c) end
    elseif state == "notRead" then
        DrawEmpty("notRead")
    else
        for i = 1, 3 do list[i] = { why = L["Reading your collection"] } end
    end
    -- Only the rows that fit above the strip: the page never scrolls for them.
    local height = math.max(TILE + 2 * R.pad, 2 * R.pad + 2 * R.gap + W.TextHeight("subheader") + 2 * W.TextHeight("body"))
    scroll.drawnH = scroll:GetHeight()
    local fit = math.floor((scroll.drawnH + SP.s - at) / (height + SP.s))
    for i = 1, math.min(#list, fit) do
        SetRow(rows[i], list[i])
        Put(rows[i], height)
    end
    main:SetHeight(math.max(at - SP.s, 1))
end

function Page:Show(route)
    if route.seed and route.seed.showTip then tipForced = true end
    Page.Draw()
end

function Page:Save() end

function Page:Hide()
    B.Window.SetStrip(nil)
    for _, r in ipairs(rows) do B.HideTooltipFor(r) end
end

Page.Refresh = Page.Draw

function Page:SetCombat() end

B.RegisterPage("overview", Page)
