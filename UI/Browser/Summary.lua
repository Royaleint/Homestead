-- Overview page: what can be had now, the zone's best vendor and the first-use tip, from the memoised walk.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local S = B.Style
local W = B.Widgets
local D = B.Data
local CG = B.CanGet
local Facts = B.Facts
local K, SP, R = S.color, S.space, S.row

local TILE, MEASURE_W = 48, 600
local DOT = " \194\183 "

local Page = {}
local main, title, lede, tip, zone, empty, seeAll
local rows = {}
local at, tipForced, glowMap, fill, filledFor

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
    if itemID then B.ShowTab("catalog", { itemID = itemID }) end
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
    local b, r, where = e.best, {}, Facts.Here()
    if b.event then r[#r + 1] = L["%s: active now"]:format(b.event) end
    if e.bonus then r[#r + 1] = L["First-Time Collection Bonus"] end
    local continent = e.near == 2 and C_Map.GetMapInfo(where.continent)
    if e.near == 1 and where.name then
        r[#r + 1] = L["Sold here in %s"]:format(where.name)
    elseif continent and continent.name then
        r[#r + 1] = L["Sold on %s"]:format(continent.name)
    elseif not (b.event or e.bonus) then
        r[#r + 1] = b.gold and L["Gold only, no requirements left"] or L["No requirements left"]
    end
    if #r < 2 and b.gold and (e.near <= 2 or e.bonus or b.event) then r[#r + 1] = L["Gold only"] end
    return table.concat(r, DOT, 1, math.min(#r, 2))
end

local function CanData(e)
    local p = CG.Primary(e.itemID)
    local v, src = D.Vendor(p.npcID), D.SourceLine(e.itemID, { p })
    local price = D.Price(e.itemID, v)
    local d = { itemID = e.itemID, npcID = p.npcID, why = Why(e), src = price and src .. DOT .. price or src, e = e }
    local mapID, x, y
    if v then mapID, x, y = D.VendorLocation(v) end
    if mapID then d.wp = { mapID = mapID, x = x, y = y, title = v.name } end
    return d
end

local function NextData(c)
    local e = c.entry
    local state, arg = B.ItemState(e.itemID)
    return { itemID = e.itemID, why = L["Not yet: next step"], dim = true, e = e, src = state == "event"
        and L["%s only"]:format(arg) or L["Requires: %s"]:format(state == "locked" and arg or L["Other requirement"]) }
end

local function SetRow(r, d)
    local e = d.e
    r.itemID, r.npcID = d.itemID, d.npcID
    local cr, cg, cb = W.QualityRGB(e and D.IconData(e.itemID, true, B.State.catalogMemo))
    W.SetTile(r.tile, { icon = e and D.ItemIcon(e.itemID) }, cr, cg, cb)
    r.name:SetText(e and (e.name or L["Item %d"]:format(e.itemID)) or W.StateWords("counting"))
    r.name:SetTextColor(cr, cg, cb)
    r.why:SetText(d.why)
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
    r.name, r.why, r.src = Text(r, "subheader"), Text(r, "body"), Text(r, "bodyMuted")
    local above
    for _, fs in ipairs({ r.name, r.why, r.src }) do
        local rel, p1, p2, x1, x2, dy = r, "TOPLEFT", "TOPRIGHT", TILE + 2 * SP.m, -SP.xxl * 3, -R.pad
        if above then rel, p1, p2, x1, x2, dy = above, "BOTTOMLEFT", "BOTTOMRIGHT", 0, 0, -R.gap end
        fs:SetPoint("TOPLEFT", rel, p1, x1, dy)
        fs:SetPoint("TOPRIGHT", rel, p2, x2, dy)
        above = fs
    end
    r.wp = W.WaypointButton(r)
    r.show = W.NewButton(r, L["Show"], function() Open(r.itemID) end)
    r.wp:SetPoint("RIGHT", -SP.m, 0)
    r.show:SetPoint("RIGHT", -SP.m, 0)
    r:SetScript("OnClick", function() if not W.Linked(r.itemID) then Open(r.itemID) end end)
    r:SetScript("OnEnter", function() if r.itemID then B.ShowItemTooltip(r, r.itemID, r.npcID) end end)
    r:SetScript("OnLeave", B.HideTooltip)
    return r
end

local function BuildBlocks(parent)
    zone = W.Pane(parent)
    zone.btn = W.NewButton(zone, L["Show vendor"], function(self)
        local key = Facts.SourceKey("vendors", { npcID = self.npcID })
        if key then B.Go({ kind = "vendor", id = key }) end
    end)
    zone.more = W.NewButton(zone, L["More vendors here"], function(self)
        B.Go({ kind = "allVendors", seed = { zone = self.zone } })
    end)
    zone.more:SetPoint("RIGHT", -SP.s, 0)
    zone.btn:SetPoint("RIGHT", zone.more, "LEFT", -SP.s, 0)
    zone.text = Text(zone, "body")
    zone.text:SetPoint("LEFT", SP.s, 0)
    zone.text:SetPoint("RIGHT", zone.btn, "LEFT", -SP.s, 0)
    tip = W.Pane(parent)
    tip.text = Text(tip, "body", L["Can get now means this character can buy or earn it today: the right faction, and no requirement left to meet. The closest ones come first. Use See all for the full list."], true)
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
    main = CreateFrame("Frame", nil, parent)
    main:SetAllPoints()
    title = S.Text(main, "header", "OVERLAY")
    title:SetJustifyH("LEFT")
    title:SetText(L["What can I get now?"])
    lede = Text(main, "bodyMuted", L["Decor this character can buy or earn today, best first."])
    BuildBlocks(main)
end

local function DrawZone()
    local vendors, mapID, name = D.NearYou()
    local best, most = nil, 0
    for _, v in ipairs(vendors) do
        local n = CG.VendorCanCount(v) or 0
        if n > most then best, most = v, n end
    end
    if not best then return end
    zone.btn.npcID, zone.more.zone = best.npcID, mapID
    zone.btn:SetShown(Facts.SourceKey("vendors", best) ~= nil)
    zone.btn:Fit()
    zone.more:Fit()
    zone.text:SetText(L["Here in %s: %s sells %d decor you can get now."]:format(name or "", best.name or "", most))
    Put(zone, zone.btn:GetHeight() + SP.s)
    if glowMap ~= mapID then
        glowMap = mapID
        local gen = B.Generation()
        C_Timer.After(0, function()
            if gen == B.Generation() and zone:IsVisible() then B.Window.Glow(zone) end
        end)
    end
end

local function DrawEmpty(kind, d, button)
    empty:Set(kind, d)
    local h = W.TextHeight("subheader") + SP.xs + W.TextHeight("body", empty.text:GetText(), MEASURE_W)
    Put(empty, button and h + W.TextHeight("body") + 2 * SP.s or h)
end

function Page.Draw()
    if not main then return end
    for _, f in ipairs({ tip, zone, empty, seeAll, rows[1], rows[2], rows[3] }) do f:Hide() end
    at = 0
    Put(title, W.TextHeight("header"))
    Put(lede, W.TextHeight("bodyMuted"))
    local saved = B.Saved()
    if tipForced or (saved and not saved.tipSeen) then
        Put(tip, W.TextHeight("body", tip.text:GetText(), MEASURE_W - SP.xxl) + 2 * SP.s)
    end
    local ranked = CG.Rank()
    if ranked ~= filledFor then fill, filledFor = ranked and CG.Fill(), ranked end
    local state = fill and "ready" or D.CollectionState()
    local list = {}
    if fill then
        DrawZone()
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
    local height = math.max(TILE + 2 * R.pad, 2 * R.pad + 2 * R.gap + W.TextHeight("subheader") + 2 * W.TextHeight("body"))
    for i, d in ipairs(list) do
        SetRow(rows[i], d)
        Put(rows[i], height)
    end
    if fill and fill.count > 0 then
        seeAll:SetText(L["See all you can get now (%d)"]:format(fill.count))
        seeAll:Fit()
        Put(seeAll, nil, true)
    end
end

function Page:Show(route)
    if route.seed and route.seed.showTip then tipForced = true end
    Page.Draw()
end

function Page:Save() end

function Page:Hide()
    for _, r in ipairs(rows) do B.HideTooltipFor(r) end
end

Page.Refresh = Page.Draw

function Page:SetCombat() end

B.RegisterPage("overview", Page)
