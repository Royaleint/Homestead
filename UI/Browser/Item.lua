-- The item page: one decor item. A fixed top holds the head (tile, name, kind, state and flags) and, beside the
-- 3D preview, what the item requires and how many the player has; a scroll below holds its sources and the
-- Report link. The preview is never inside the scroll, since a model scene is not clipped by a scroll frame.
-- What does not fit beside the preview, or has no preview to sit beside, leads the scroll instead.
-- luacheck: read globals Constants
local _, HA = ...

local B = HA.DecorBrowser
local L, S, W = HA.L, B.Style, B.Widgets
local F = B.Facts
local K, SP, LO = S.color, S.space, S.layout

local MARK = 12
local THUMB = S.model.thumb
local PREVIEW_W, PREVIEW_H = S.model.preview[1], S.model.preview[2]

local SHOW = {
    vendor = L["Show vendor"], achievement = L["Show achievement"], quest = L["Show quest"],
    profession = L["Show recipe"], drop = L["Show drop"], event = L["Show event"],
}

local Page = {}
local P = {}
local shownID, torn, wait, drawnW
-- The item, model and setting the preview last loaded; nil after Hide, so the next draw loads again.
local modelKey

local function Joined(parts)
    return W.Join(parts, L["%s · %s"])
end

local function Labeled(label, value, extra)
    local text = S.Colored(K.gold, label) .. " " .. value
    return extra and L["%s · %s"]:format(text, extra) or text
end

local function Spot(mapID, x, y, title, data)
    return mapID and x and y and { mapID = mapID, x = x, y = y, title = title, data = data } or nil
end

local function ShowSource(sourceType, key)
    return function()
        if sourceType == "vendors" then B.Go({ kind = "vendor", id = key })
        else B.Go({ kind = "source", key = sourceType, id = key }) end
    end
end

local function Report()
    if InCombatLockdown() then return end
    local D, itemID = B.Data, shownID
    local info = D.CatalogInfo(itemID, B.State.catalogMemo)
    local build, buildNumber = GetBuildInfo()
    HA.OutputWindow:Show(L["Report a data error"], D.ReportText({
        itemID = itemID, name = D.ItemName(itemID, info),
        recordID = D.RecordID(itemID, info), vendors = P.vendors,
        build = build, buildNumber = buildNumber, version = HA.Constants.VERSION,
    }))
end

-- "Get it" first, other open vendors by nearness, then short, unpriced, other vendors, other sources,
-- other-faction vendors.
local SHORT_RANK = { short = 4, unpriced = 4.5 }
local function Rank(b, primary)
    if not b.vendor then return 6 end
    if b.npcID == primary then return 0 end
    if b.offer == "can" then return F.Nearness(b.mapID, F.Here()) end
    if SHORT_RANK[b.offer] then return SHORT_RANK[b.offer] end
    return B.Data.IsOppositeFaction(b.vendor) and 9 or 5
end

-- A part of a source row's second line; the first one with a glyph also marks the row.
local function Status(row, words, glyph, color)
    row.status[#row.status + 1] = color and S.Colored(color, words) or words
    if glyph and not row.glyph then row.glyph, row.color = glyph, color or K.muted end
end

-- An event the head already flags as on is not repeated on the row.
local function EventStatus(row, name, active, flagged)
    if active and flagged[name] then return end
    if active then
        Status(row, L["Active now: %s"]:format(name), "clock", K.badge)
    else
        Status(row, W.StateWords("event", name), "clock")
    end
end

local function VendorRow(itemID, b, flagged)
    local D, v = B.Data, b.vendor
    local row = { status = {}, one = Labeled(L["Vendor:"], v.name or L["Unknown"], D.Price(itemID, v)) }
    Status(row, F.Where(v) or L["Location not recorded"])
    local label = D.IsOppositeFaction(v) and D.VendorFactionLabel(v)
    if label then Status(row, W.StateWords("faction", label), "stop", K.stop) end
    if b.offer == "can" then Status(row, L["Can get now here"], "dot", K.can) end
    if SHORT_RANK[b.offer] then
        local _, words = B.ItemState(itemID, b.npcID)
        local st = S.state[b.offer]
        Status(row, W.StateWords(b.offer, words), st.glyph, st.color)
    end
    local ev = F.EventVendor(b.npcID)
    local event = ev and ev.event or v.event
    if event then EventStatus(row, event, F.BrowserListed(v), flagged) end
    local confirmed = F.Confirmed(v)
    if confirmed then
        Status(row, L["Confirmed by a scan on %s"]:format(confirmed))
    else
        Status(row, L["Not confirmed"])
        row.note = F.NotConfirmed()
    end
    local key = F.SourceKey("vendors", { npcID = b.npcID }, itemID)
    if key then row.show = { SHOW.vendor, ShowSource("vendors", key) } end
    row.wp = Spot(b.mapID, b.x, b.y, v.name, { type = "vendor", npcID = b.npcID })
    return row
end

local function OtherRow(itemID, src, flagged)
    local t = src.type
    local name = src.name or L["Unknown"]
    local row = { status = {} }
    if t == "achievement" then
        row.one = Labeled(L["Achievement:"], name)
    elseif t == "quest" then
        row.one = Labeled(L["Quest:"], name)
        local start, spot = F.QuestStart(src.questID), F.TreasureSpot(src.questID)
        if start then
            local map = C_Map.GetMapInfo(start.mapID)
            Status(row, L["Starts in %s"]:format(map and map.name or L["Unknown"]))
            row.wp = Spot(start.mapID, start.x, start.y, name)
        end
        if spot then
            local map = C_Map.GetMapInfo(spot.mapID)
            Status(row, L["Daily from The Last Architect"])
            Status(row, L["Dig site in %s"]:format(map and map.name or L["Unknown"]))
            row.wp2 = Spot(spot.mapID, spot.x, spot.y, name)
        end
    elseif t == "profession" then
        row.one = Labeled(L["Recipe:"], name)
        if src.profession then Status(row, src.profession) end
    elseif t == "drop" then
        row.one = Labeled(L["Drop:"], name)
        if src.zone then Status(row, src.zone) end
        if src.notes then Status(row, src.notes) end
        row.wp = Spot(src.mapID, src.x, src.y, name)
    elseif t == "event" then
        row.one = Labeled(L["Event:"], name)
        if src.vendorName then Status(row, src.vendorName) end
        if src.zone then Status(row, src.zone) end
        local CD = HA.CalendarDetector
        EventStatus(row, name, CD and CD:IsHolidayActive(name) == true, flagged)
        row.wp = Spot(src.mapID, src.x, src.y, name)
    else
        row.one = B.Data.SourceLine(itemID, { src })
    end
    local sourceType = F.SOURCE_TYPE[t]
    local file = HA[B.CanGet.SOURCE_TABLES[sourceType] or ""]
    local key = sourceType and t ~= "shop" and F.SourceKey(sourceType, file and file[itemID], itemID)
    if key then row.show = { SHOW[t], ShowSource(sourceType, key) } end
    local link = F.LINK[sourceType]
    if link then row.link = function() return link(src) end end
    return row
end

-- The page as data: the head, the facts beside the preview and the source rows.
local function Describe(itemID)
    local D, CG = B.Data, B.CanGet
    local memo = B.State.catalogMemo
    local e = CG.Entry(itemID)
    local info = e and e.info or D.CatalogInfo(itemID, memo)
    local quality = D.IconData(itemID, true, memo)
    local m = {
        info = info, quality = quality, icon = D.ItemIcon(itemID),
        name = D.ItemName(itemID, info) or L["Item %d"]:format(itemID),
        meta = L["%s · %s"]:format(quality and _G["ITEM_QUALITY" .. quality .. "_DESC"] or L["Unknown"],
            S.kind[S.KindOf(info)]),
        flags = {}, facts = {}, rows = {},
    }

    local blocks, seen, vendors = {}, {}, {}
    local function addVendor(npcID)
        local v = npcID and not seen[npcID] and D.Vendor(npcID)
        if not v then return false end
        seen[npcID] = true
        local mapID, x, y = D.VendorLocation(v)
        blocks[#blocks + 1] = { vendor = v, npcID = npcID, mapID = mapID, x = x, y = y,
            offer = CG.Offer(itemID, npcID, e and e.info) }
        vendors[#vendors + 1] = { npcID = npcID, name = v.name, zone = v.zone, mapID = mapID, x = x, y = y }
        return true
    end
    local sources = D.ItemSources(itemID)
    local primary = CG.Primary(itemID, sources)
    for _, src in ipairs(sources) do
        if not (src.type == "vendor" and (addVendor(src.npcID) or seen[src.npcID])) then
            blocks[#blocks + 1] = { src = src }
        end
    end
    for _, npcID in ipairs(F.EventVendorsFor(itemID) or {}) do addVendor(npcID) end
    for i, b in ipairs(blocks) do b.rank = Rank(b, primary and primary.npcID) + i / 1000 end
    table.sort(blocks, function(a, c) return a.rank < c.rank end)
    m.vendors = vendors

    local flags, flagged = m.flags, {}
    local state, arg, at = B.ItemState(itemID)
    if state then
        local st = S.state[state]
        flags[#flags + 1] = { text = W.StateWords(state, arg), glyph = st.glyph, color = st.color }
    end
    local active
    for _, o in pairs(e and e.canBy or {}) do
        if o.event and (not active or o.event < active) then active = o.event end
    end
    if active then
        flagged[active] = true
        flags[#flags + 1] = { text = L["Active now: %s"]:format(active), glyph = "clock", color = K.badge }
    end
    local bonus = e and e.bonus
    if bonus then
        -- As the game's own preview: white words, the amount under the mouse.
        flags[#flags + 1] = { text = HOUSING_DECOR_FIRST_ACQUISITION_AVAILABLE or L["First-Time Collection Bonus Available"], color = K.body, tip = function(tip)
            GameTooltip_AddHighlightLine(tip, HOUSING_DECOR_FIRST_ACQUISITION_FORMAT:format(bonus))
        end }
    end

    local facts = m.facts
    local reqs = D.Requirements(itemID, at or blocks[1] and blocks[1].npcID)
    if #reqs > 0 then
        facts[#facts + 1] = { text = L["Requires"], color = K.gold, role = "bodyGold" }
        for _, r in ipairs(reqs) do
            if r.met == true then
                facts[#facts + 1] = { text = L["%s (done)"]:format(r.text), glyph = "check", color = K.muted }
            elseif r.met == false then
                facts[#facts + 1] = { text = L["%s (not yet)"]:format(r.text), glyph = "lock", color = K.body }
            else
                facts[#facts + 1] = { text = r.text, glyph = "lock", color = K.body }
                facts[#facts + 1] = { text = L["Can't check this requirement yet"], color = K.muted }
            end
        end
    end
    if info and D.CollectionState() == "ready" then
        local n, counts = { info.totalNumPlaced, info.totalNumStored, info.remainingRedeemable }, {}
        for i, label in ipairs({ L["Placed"], L["In storage"], L["Not yet redeemed"] }) do
            if (n[i] or 0) > 0 then counts[#counts + 1] = S.Colored(K.gold, label) .. " " .. n[i] end
        end
        if counts[1] then facts[#facts + 1] = { text = Joined(counts), color = K.body } end
    end

    for _, b in ipairs(blocks) do
        m.rows[#m.rows + 1] = b.vendor and VendorRow(itemID, b, flagged) or OtherRow(itemID, b.src, flagged)
    end
    return m
end

-- The preview -----------------------------------------------------------------

local function Scene()
    if not P.scene then
        local scene = CreateFrame("ModelScene", nil, P.well, "NoZoomModelSceneMixinTemplate")
        scene:SetPoint("TOPLEFT", P.well, "TOPLEFT", LO.panePad, -LO.panePad)
        scene:SetPoint("BOTTOMRIGHT", P.well, "BOTTOMRIGHT", -LO.panePad, LO.panePad)
        -- The wheel scrolls the page; the scene would swallow it.
        scene:EnableMouseWheel(false)
        P.scene = scene
    end
    return P.scene
end

-- The entry's own scene, else the catalog's default, as the game's own preview frames a decor model.
local function Load(info, asset)
    local scene = Scene()
    local default = Constants.HousingCatalogConsts.HOUSING_CATALOG_DECOR_MODELSCENEID_DEFAULT
    local actor
    for _, id in ipairs({ info.uiModelSceneID or default, default }) do
        scene:TransitionToModelSceneID(id, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
        actor = scene:GetActorByTag("decor")
        if actor or id == default then break end
    end
    if not actor then return false end
    actor:SetPreferModelCollisionBounds(true)
    actor:SetModelByFileID(asset)
    return true
end

-- Loads once per item, model and setting; true when the preview shows.
local function Preview(itemID, info)
    local asset = B.Model3D() and info and info.asset or nil
    local key = itemID .. ":" .. tostring(asset)
    if key ~= modelKey then
        modelKey = key
        P.live = asset ~= nil and Load(info, asset)
        if not P.live and P.scene then P.scene:ClearScene() end
    end
    P.well:SetShown(P.live)
    return P.live
end

-- Lines and rows ----------------------------------------------------------------

local function LineTip(self)
    if not self.tip then return end
    local tip = B.Tooltip()
    tip:SetOwner(self, "ANCHOR_LEFT")
    self.tip(tip)
    tip:Show()
end

local function NewLine(box)
    local f = CreateFrame("Frame", nil, box)
    f.mark = f:CreateTexture(nil, "OVERLAY")
    f.mark:SetSize(MARK, MARK)
    f.text = W.Text(f, "body")
    f:SetScript("OnEnter", LineTip)
    f:SetScript("OnLeave", B.HideTooltip)
    box.lines[#box.lines + 1] = f
    return f
end

-- Stacks list's lines in box, each wrapping at w; returns the height they take.
local function Stack(box, list, w)
    local y = 0
    for i, d in ipairs(list) do
        local f = box.lines[i] or NewLine(box)
        local role = d.role or "body"
        local indent = d.glyph and MARK + SP.xs or 0
        local th = W.TextHeight(role)
        f.text:SetFontObject(S.FontName(role))
        f.text:SetText(d.text)
        f.text:SetTextColor(d.color[1], d.color[2], d.color[3])
        local h = W.TextHeight(role, d.text, w - indent)
        f.text:SetSize(w - indent, h)
        f.text:SetPoint("TOPLEFT", f, "TOPLEFT", indent, 0)
        B.Vis.Marker.Set(f.mark, d.glyph, d.color)
        f.mark:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(th - MARK) / 2)
        f.tip = d.tip
        f:EnableMouse(d.tip ~= nil)
        f:SetSize(w, h)
        f:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -y)
        f:Show()
        y = y + h + SP.xs
    end
    for i = #list + 1, #box.lines do box.lines[i]:Hide() end
    box:SetSize(w, math.max(y - SP.xs, 1))
    return #list > 0 and y - SP.xs or 0
end

-- A source row's tooltip: the game's own for an achievement or quest, else the row's words when they are cut
-- off or say less than the whole.
local function RowTip(self)
    local d = self.d
    if d.link then return B.ShowLinkTooltip(self, d.link()) end
    if not (d.note or self.one:IsTruncated() or self.two:IsShown() and self.two:IsTruncated()) then return end
    local tip = B.Tooltip()
    tip:SetOwner(self, "ANCHOR_RIGHT")
    tip:SetText(d.one, 1, 1, 1, 1, true)
    if self.two:IsShown() then tip:AddLine(self.two:GetText(), K.muted[1], K.muted[2], K.muted[3], true) end
    if d.note then tip:AddLine(d.note, K.muted[1], K.muted[2], K.muted[3], true) end
    tip:Show()
end

local function NewRow()
    local f = CreateFrame("Button", nil, P.body)
    f.mark = f:CreateTexture(nil, "OVERLAY")
    f.mark:SetSize(MARK, MARK)
    f.one, f.two = W.Text(f, "body"), W.Text(f, "bodyMuted")
    f.one:SetWordWrap(false)
    f.two:SetWordWrap(false)
    f.show = W.NewButton(f, "", function(self) self.act() end)
    f.wp, f.wp2 = W.WaypointButton(f), W.WaypointButton(f)
    f:SetScript("OnClick", function() W.Linked(shownID) end)
    f:SetScript("OnEnter", RowTip)
    f:SetScript("OnLeave", B.HideTooltip)
    P.rows[#P.rows + 1] = f
    return f
end

-- One line of a row: the text, cut off where the controls after it and the row's edge leave room, then the
-- shown controls. Returns the line's height.
local function RowLine(f, fs, role, text, w, y, ...)
    local th = W.TextHeight(role)
    local room, h = w - MARK - SP.xs, th
    for i = 1, select("#", ...) do
        local c = select(i, ...)
        if c:IsShown() then
            room = room - c:GetWidth() - SP.xs
            h = math.max(h, c:GetHeight())
        end
    end
    fs:SetText(text)
    fs:SetSize(math.max(math.min(fs:GetUnboundedStringWidth() + 1, room), 1), th)
    fs:SetPoint("LEFT", f, "TOPLEFT", MARK + SP.xs, -(y + h / 2))
    local prev = fs
    for i = 1, select("#", ...) do
        local c = select(i, ...)
        if c:IsShown() then
            c:SetPoint("LEFT", prev, "RIGHT", SP.xs, 0)
            prev = c
        end
    end
    return h
end

local function SetSpot(b, spot)
    b:SetShown(spot ~= nil)
    b.wp = spot
end

local function SetRow(f, d, w)
    f.d = d
    f.show:SetShown(d.show ~= nil)
    if d.show then
        f.show.act = d.show[2]
        f.show:SetText(d.show[1])
        f.show:Fit()
    end
    SetSpot(f.wp, d.wp)
    SetSpot(f.wp2, d.wp2)
    local h = RowLine(f, f.one, "body", d.one, w, 0, f.show, f.wp)
    B.Vis.Marker.Set(f.mark, d.glyph, d.color)
    f.mark:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(h - MARK) / 2)
    f.two:SetShown(d.status[1] ~= nil)
    if d.status[1] then h = h + RowLine(f, f.two, "bodyMuted", Joined(d.status), w, h, f.wp2) end
    f:SetSize(w, h)
    f:Show()
    return h
end

-- Drawing -----------------------------------------------------------------------

local function Draw(fresh, saved)
    local w = P.page:GetWidth()
    if w <= 0 then
        wait = W.Owe(wait, fresh, saved)
        return
    end
    wait, drawnW = nil, w
    local m = Describe(shownID)
    P.vendors = m.vendors

    local r, g, b = W.QualityRGB(m.quality)
    W.SetTile(P.tile, { icon = m.icon }, r, g, b)
    local tw = w - THUMB - SP.s
    local nh, mh = W.TextHeight("subheader"), W.TextHeight("bodyMuted")
    P.name:SetText(m.name)
    P.name:SetTextColor(r, g, b)
    P.name:SetSize(tw, nh)
    P.meta:SetText(m.meta)
    P.meta:SetSize(tw, mh)
    local fh = Stack(P.flags, m.flags, tw)
    local headH = math.max(THUMB, nh + SP.xs + mh + (fh > 0 and SP.xs + fh or 0))

    local cw = w - LO.scrollBarGap
    local live = Preview(shownID, m.info)
    local sideW = w - PREVIEW_W - SP.m
    local beside = live and #m.facts > 0 and Stack(P.facts, m.facts, sideW) <= PREVIEW_H
    P.well:SetPoint("TOPLEFT", P.top, "TOPLEFT", 0, -(headH + SP.m))
    P.top:SetHeight(headH + (live and SP.m + PREVIEW_H or 0))

    local y = 0
    if beside then
        P.facts:SetParent(P.top)
        P.facts:SetPoint("TOPLEFT", P.top, "TOPLEFT", PREVIEW_W + SP.m, -(headH + SP.m))
    else
        P.facts:SetParent(P.body)
        local h = Stack(P.facts, m.facts, cw)
        P.facts:SetPoint("TOPLEFT", P.body, "TOPLEFT", 0, 0)
        if h > 0 then y = h + SP.m end
    end
    P.facts:SetShown(#m.facts > 0)

    P.where:SetSize(cw, W.TextHeight("bodyGold"))
    P.where:SetPoint("TOPLEFT", P.body, "TOPLEFT", 0, -y)
    y = y + P.where:GetHeight() + SP.xs
    P.unknown:SetShown(#m.rows == 0)
    if #m.rows == 0 then
        P.unknown:SetSize(cw, W.TextHeight("bodyMuted"))
        P.unknown:SetPoint("TOPLEFT", P.body, "TOPLEFT", 0, -y)
        y = y + P.unknown:GetHeight() + SP.s
    end
    for i, d in ipairs(m.rows) do
        local f = P.rows[i] or NewRow()
        f:SetPoint("TOPLEFT", P.body, "TOPLEFT", 0, -y)
        y = y + SetRow(f, d, cw) + SP.s
    end
    for i = #m.rows + 1, #P.rows do P.rows[i]:Hide() end
    P.report:Fit()
    P.report:SetPoint("TOPLEFT", P.body, "TOPLEFT", 0, -(y + SP.xs))
    P.body:SetSize(cw, y + SP.xs + P.report:GetHeight())
    P.sf:UpdateScrollChildRect()
    if fresh then P.sf:SetVerticalScroll(saved and saved.scroll or 0) end
end

function Page:Build(parent)
    P.page, P.rows = parent, {}
    P.top = CreateFrame("Frame", nil, parent)
    P.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    P.top:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    P.tile = W.NewTile(P.top, THUMB)
    P.tile.icon:SetPoint("TOPLEFT", P.top, "TOPLEFT", 0, 0)
    P.name, P.meta = W.Text(P.top, "subheader"), W.Text(P.top, "bodyMuted")
    P.name:SetWordWrap(false)
    P.meta:SetWordWrap(false)
    W.Clip(P.name)
    P.name:SetPoint("TOPLEFT", P.top, "TOPLEFT", THUMB + SP.s, 0)
    P.meta:SetPoint("TOPLEFT", P.name, "BOTTOMLEFT", 0, -SP.xs)
    P.flags = CreateFrame("Frame", nil, P.top)
    P.flags.lines = {}
    P.flags:SetPoint("TOPLEFT", P.meta, "BOTTOMLEFT", 0, -SP.xs)
    P.well = W.Well(P.top)
    P.well:SetSize(PREVIEW_W, PREVIEW_H)
    P.facts = CreateFrame("Frame", nil, P.top)
    P.facts.lines = {}

    P.sf = CreateFrame("ScrollFrame", nil, parent, "ScrollFrameTemplate")
    P.sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -LO.scrollBarGap, 0)
    P.sf:SetPoint("TOPLEFT", P.top, "BOTTOMLEFT", 0, -SP.m)
    P.sf.ScrollBar:SetHideIfUnscrollable(true)
    P.body = CreateFrame("Frame", nil, P.sf)
    P.sf:SetScrollChild(P.body)
    P.where = W.Text(P.body, "bodyGold")
    P.where:SetText(L["Where to get it"])
    P.unknown = W.Text(P.body, "bodyMuted")
    P.unknown:SetText(L["Source unknown"])
    P.report = W.ReportLink(P.body, Report)

    -- The wheel over the fixed top scrolls the sources below it.
    P.top:EnableMouseWheel(true)
    P.top:SetScript("OnMouseWheel", function(_, delta)
        local scroll = P.sf:GetScript("OnMouseWheel")
        if scroll then scroll(P.sf, delta) end
    end)
    parent:HookScript("OnSizeChanged", function(_, w)
        if shownID and not torn and w > 0 and (wait or w ~= drawnW) then
            Draw(W.Owed(wait))
        end
    end)
end

function Page:Show(route, saved)
    shownID, torn = route.id, false
    Draw(true, saved)
end

function Page:Save()
    return { scroll = P.sf:GetVerticalScroll() }
end

-- The item is kept; the preview is let go and loads again on the next draw.
function Page:Hide()
    torn, modelKey = true, nil
    if P.scene then P.scene:ClearScene() end
    B.HideTooltip()
end

-- A zone change draws again: open vendors are ordered by nearness to the player.
function Page:Refresh(reason)
    if not (P.body and shownID) then return end
    if not torn and (reason == "stats" or reason == "hide") then return end
    torn = false
    Draw(false)
end

function Page:SetCombat(inCombat)
    if P.report then P.report:SetEnabled(not inCombat) end
end

B.RegisterPage("item", Page)
