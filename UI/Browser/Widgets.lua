-- Shared widgets: wells, panes, bars, decor rows, lists and grids. Tooltips come from B at call time.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local S = B.Style
local Vis = B.Vis
local LO = S.layout
local T = S.tex
local C = S.coord
local K = S.color

local W = {}
B.Widgets = W

local panes = {}
local pulsing = {}

local function Coord(tex, c)
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
end
W.Coord = Coord

function W.Well(parent)
    return Vis.Chrome.Inset(parent)
end

local function PaintPane(pane, opaque)
    local sc, bd = S.backdrop.scrim, S.backdrop
    local a = opaque and 1 or (pane.role == "nav" and bd.navAlpha or bd.pageAlpha)
    pane.fill:SetColorTexture(sc[1], sc[2], sc[3], a)
end

function W.Pane(parent, role)
    local pane = CreateFrame("Frame", nil, parent)
    pane.fill = pane:CreateTexture(nil, "BACKGROUND", nil, -1)
    pane.fill:SetAllPoints()
    pane.role = role
    panes[#panes + 1] = pane
    PaintPane(pane)
    return pane
end

function W.OpaquePanes(opaque)
    for _, pane in ipairs(panes) do PaintPane(pane, opaque) end
end

function W.Rule(parent)
    local rule = parent:CreateTexture(nil, "ARTWORK")
    rule:SetAtlas(S.filigree.divider, true)
    rule:SetAlpha(S.filigree.dividerAlpha)
    return rule
end

function W.WoodCorners(box)
    local F = S.filigree
    local holder = CreateFrame("Frame", nil, box)
    holder:SetAllPoints()
    holder:SetFrameLevel(box:GetFrameLevel() + 10)
    for key, atlas in pairs(F.wood) do
        if C_Texture.GetAtlasInfo(atlas) then
            local t = holder:CreateTexture(nil, "OVERLAY")
            t:SetAtlas(atlas, false)
            t:SetSize(F.woodSize, F.woodSize)
            t:SetPoint(({ TL = "TOPLEFT", TR = "TOPRIGHT", BL = "BOTTOMLEFT", BR = "BOTTOMRIGHT" })[key])
        end
    end
    return holder
end

function W.NewSectionHeader(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(LO.headerHeight)
    f.right = S.Text(f, "meta", "OVERLAY")
    f.right:SetPoint("RIGHT", -4, 2)
    f.text = S.Text(f, "subheader", "OVERLAY")
    f.text:SetPoint("LEFT", 4, 2)
    f.text:SetPoint("RIGHT", f.right, "LEFT", -S.space.s, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(false)
    local rule = W.Rule(f)
    rule:SetPoint("LEFT", f, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("RIGHT", f, "BOTTOMRIGHT", 0, 0)
    return f
end

function W.NewBar(parent, wide, onClick)
    local bs = S.bar
    local trackH = wide and bs.trackWide or bs.track
    local bar = CreateFrame("Frame", nil, parent)
    bar.count = S.Text(bar, wide and "numberLarge" or "number", "OVERLAY")
    bar.count:SetPoint("TOPRIGHT")
    bar.count:SetJustifyH("RIGHT")
    bar.count:SetTextColor(K.muted[1], K.muted[2], K.muted[3])
    bar.label = S.Text(bar, wide and "bodyLarge" or "body", "OVERLAY")
    bar.label:SetPoint("TOPLEFT")
    bar.label:SetPoint("RIGHT", bar.count, "LEFT", -S.space.s, 0)
    bar.label:SetJustifyH("LEFT")
    bar.label:SetWordWrap(false)
    bar:SetHeight((wide and 20 or 16) + bs.textGap + trackH)

    local fill = CreateFrame("StatusBar", nil, bar)
    fill:SetPoint("BOTTOMLEFT")
    fill:SetPoint("BOTTOMRIGHT")
    fill:SetHeight(trackH)
    fill:SetStatusBarTexture(T.plainWhite)
    fill:SetMinMaxValues(0, 1)
    fill:SetValue(0)
    fill:GetStatusBarTexture():SetDrawLayer("BORDER")
    local back = fill:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(unpack(bs.trackColor))
    Vis.Chrome.Hairline(fill, bs.edgeColor, bs.edgeColor[4], "BORDER")
    local gloss = fill:CreateTexture(nil, "ARTWORK")
    gloss:SetPoint("TOPLEFT", fill:GetStatusBarTexture(), "TOPLEFT")
    gloss:SetPoint("TOPRIGHT", fill:GetStatusBarTexture(), "TOPRIGHT")
    gloss:SetPoint("BOTTOM", fill, "CENTER")
    gloss:SetColorTexture(1, 1, 1, 1)
    gloss:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, bs.sheenTop))
    bar.fill = fill

    local hl = bar:CreateTexture(nil, "BACKGROUND")
    hl:SetPoint("TOPLEFT", -S.space.xs, S.space.xs)
    hl:SetPoint("BOTTOMRIGHT", S.space.xs, -S.space.xs)
    hl:SetColorTexture(unpack(K.hoverRow))
    hl:Hide()
    if onClick then
        bar:EnableMouse(true)
        bar:SetScript("OnEnter", function() hl:Show() end)
        bar:SetScript("OnLeave", function() hl:Hide() end)
        bar:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then onClick() end
        end)
    end

    function bar:SetProgress(label, owned, total)
        local ratio = 0
        self.label:SetText(label)
        if owned and total and total > 0 then
            ratio = owned / total
            self.count:SetText(L["%s / %s  ·  %d%%"]:format(BreakUpLargeNumbers(owned),
                BreakUpLargeNumbers(total), math.floor(ratio * 100)))
        elseif total == 0 then
            self.count:SetText(L["0 / 0"])
        else
            self.count:SetText(L["? / %s"]:format(total and BreakUpLargeNumbers(total) or "?"))
        end
        self.target = ratio
        local c = Vis.Bar.Color(ratio)
        fill:SetStatusBarColor(c[1], c[2], c[3])
        Vis.Bar.Set(fill, ratio, self:IsVisible())
    end

    function bar:Replay()
        if not self.target then return end
        fill:SetValue(0)
        fill:SetToTargetValue()
        Vis.Bar.Set(fill, self.target, self:IsVisible())
    end
    return bar
end

function W.WaypointButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(26, 26)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(20, 20)
    icon:SetAtlas(S.atlas.waypointOff)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("CENTER")
    hl:SetSize(20, 20)
    hl:SetAtlas(S.atlas.waypointOn)
    b:SetScript("OnClick", function(self)
        local w = self.wp
        if w and w.mapID and w.x and w.y then
            HA.Waypoints:Set(w.mapID, w.x, w.y, { title = w.title, data = w.data })
        end
    end)
    b:SetScript("OnEnter", function(self)
        local tip = B.Tooltip()
        tip:SetOwner(self, "ANCHOR_LEFT")
        tip:SetText(L["Set waypoint"])
        tip:Show()
    end)
    b:SetScript("OnLeave", function() B.HideTooltip() end)
    return b
end

-- Icon treatment on a Vis.Desaturate unit: plate and icon grey with it; border, glow and flash keep colour.
function W.BuildItemIcon(unit)
    local art, over = unit.art, unit.over
    local fx = S.itemFx

    local plate = art:CreateTexture(nil, "ARTWORK", nil, -1)
    plate:SetAllPoints()
    plate:SetColorTexture(1, 1, 1, 1)
    plate:SetGradient("VERTICAL", CreateColor(unpack(K.iconPlateBottom)), CreateColor(unpack(K.iconPlateTop)))

    unit.icon = art:CreateTexture(nil, "ARTWORK")
    unit.icon:SetAllPoints()
    Coord(unit.icon, C.wareIcon)

    unit.border = over:CreateTexture(nil, "OVERLAY", nil, 1)
    unit.border:SetTexture(T.iconBorder)
    unit.border:SetAllPoints(art)

    unit.glow = over:CreateTexture(nil, "OVERLAY", nil, 2)
    unit.glow:SetBlendMode("ADD")
    unit.glow:SetAllPoints(art)
    unit.glow:Hide()
    unit.pulse = unit.glow:CreateAnimationGroup()
    unit.pulse:SetLooping("BOUNCE")
    local breathe = unit.pulse:CreateAnimation("Alpha")
    breathe:SetFromAlpha(1)
    breathe:SetToAlpha(fx.pulseLow)
    breathe:SetDuration(fx.pulseSeconds)
    breathe:SetSmoothing("IN_OUT")
    pulsing[#pulsing + 1] = unit

    unit.flash = over:CreateTexture(nil, "OVERLAY", nil, 3)
    unit.flash:SetAtlas(S.atlas.changeFlash)
    unit.flash:SetBlendMode("ADD")
    unit.flash:SetPoint("TOPLEFT", art, "TOPLEFT", -fx.flashSpill, fx.flashSpill)
    unit.flash:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", fx.flashSpill, -fx.flashSpill)
    unit.flash:SetAlpha(0)
    unit.flashGroup = unit.flash:CreateAnimationGroup()
    unit.flashGroup:SetToFinalAlpha(true)
    local fade = unit.flashGroup:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(fx.flashSeconds)
    fade:SetSmoothing("OUT")
    return unit
end

local function UpdatePulse(unit)
    if unit.glow:IsShown() and Vis.AnimationsOn() then
        if not unit.pulse:IsPlaying() then unit.pulse:Play() end
    else
        unit.pulse:Stop()
    end
end

function W.ResetItemIcon(unit)
    unit.pulse:Stop()
    unit.flashGroup:Stop()
    unit.flash:SetAlpha(0)
    unit.glow:Hide()
end

function W.RefreshPulses()
    for _, unit in ipairs(pulsing) do UpdatePulse(unit) end
end

function W.StopAll()
    for _, unit in ipairs(pulsing) do W.ResetItemIcon(unit) end
end

-- d = { texture or atlas, color, quality, isNew }. Sets every field, so a recycled icon keeps nothing.
function W.SetItemIcon(unit, d)
    unit.flashGroup:Stop()
    unit.flash:SetAlpha(0)
    if d.atlas then unit.icon:SetAtlas(d.atlas) else unit.icon:SetTexture(d.texture) end
    unit.border:SetVertexColor(d.color[1], d.color[2], d.color[3], d.color[4] or 1)
    local atlas = d.quality and NEW_ITEM_ATLAS_BY_QUALITY[d.quality] or S.atlas.newGlowFallback
    unit.glow:SetAtlas(atlas)
    unit.glow:SetShown(d.isNew and true or false)
    UpdatePulse(unit)
end

function W.FlashItemIcon(unit)
    unit.flashGroup:Stop()
    if Vis.AnimationsOn() then unit.flashGroup:Play() end
end

local STATE_RIM = {
    owned = K.owned, unlocked = K.available, locked = K.locked, unknown = K.unknown,
}
W.STATE_RIM = STATE_RIM
local STATE_GLYPH = { owned = S.atlas.check, unlocked = S.atlas.coin, locked = S.atlas.lock }

local TAG_W = 84

function W.SetTag(fs, text, on)
    local c = on and K.stateText.owned or K.stateText.unknown
    fs:SetText(text or "")
    fs:SetTextColor(c[1], c[2], c[3])
end

-- Decor row. row:Set{ icon, name, line2, state, itemID, npcID, onClick, wp, link, tag, tagOn }. A stripe and
-- the icon border show the state; locked and unknown icons grey, locked ones with a lock badge. A nil state is
-- neutral. variant "compact" swaps the state label for a small tag. link = { onClick, tooltipLink, gated } makes
-- the second line a hyperlink; gated ones are off in combat.
function W.NewRow(parent, height, variant)
    local full = variant == nil
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(height)
    row:RegisterForClicks("LeftButtonUp")

    local card = row:CreateTexture(nil, "BACKGROUND")
    card:SetAllPoints()
    card:SetColorTexture(unpack(K.card))
    local stripe = row:CreateTexture(nil, "BORDER")
    stripe:SetPoint("TOPLEFT")
    stripe:SetPoint("BOTTOMLEFT")
    PixelUtil.SetWidth(stripe, 3, 1)
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(unpack(K.hoverRow))

    local lb = S.lockBadge.row
    local grey = Vis.Desaturate.Create(row, lb.size, lb.point)
    grey.art:SetSize(LO.iconRim, LO.iconRim)
    grey.art:SetPoint("LEFT", S.space.m, 0)
    W.BuildItemIcon(grey)

    local rightW = variant == "compact" and 48 or 230
    local name = S.Text(row, "body", "OVERLAY")
    name:SetPoint("TOPLEFT", row, "TOPLEFT", S.space.m + LO.iconRim + S.space.m, -10)
    name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -rightW, -10)
    name:SetHeight(16)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    local line = S.Text(row, "meta", "OVERLAY")
    line:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
    line:SetPoint("TOPRIGHT", name, "BOTTOMRIGHT", 0, -6)
    line:SetHeight(14)
    line:SetTextColor(K.muted[1], K.muted[2], K.muted[3])
    line:SetJustifyH("LEFT")
    line:SetWordWrap(false)

    local wp = W.WaypointButton(row)
    wp:SetPoint("RIGHT", -S.space.m, 0)
    wp:SetFrameLevel(row:GetFrameLevel() + 6)

    local linkBtn = CreateFrame("Button", nil, row)
    linkBtn:SetAllPoints(line)
    linkBtn:SetFrameLevel(row:GetFrameLevel() + 5)
    linkBtn:SetScript("OnClick", function(self)
        if self.onClick then self.onClick() end
    end)
    linkBtn:SetMotionScriptsWhileDisabled(true)
    linkBtn:SetScript("OnEnter", function(self)
        if not self:IsEnabled() then
            local tip = B.Tooltip()
            tip:SetOwner(self, "ANCHOR_RIGHT")
            tip:SetText(L["Not available in combat"])
            tip:Show()
        elseif self.tooltipLink then
            B.ShowLinkTooltip(self, self.tooltipLink)
        end
    end)
    linkBtn:SetScript("OnLeave", function() B.HideTooltip() end)
    linkBtn:Hide()

    local glyph, stateText, tag
    if full then
        glyph = row:CreateTexture(nil, "OVERLAY")
        glyph:SetSize(16, 16)
        stateText = S.Text(row, "body", "OVERLAY")
        stateText:SetJustifyH("RIGHT")
    else
        tag = S.Text(row, "meta", "OVERLAY")
        tag:SetWidth(TAG_W)
        tag:SetJustifyH("RIGHT")
        tag:SetWordWrap(false)
        tag:SetPoint("RIGHT", wp, "LEFT", -S.space.m, 0)
    end

    function row:Reset()
        W.ResetItemIcon(grey)
        linkBtn:Hide()
        if self:IsMouseOver() then B.HideTooltip() end
    end

    -- Alpha, not text colour: the line can hold a hyperlink with its own colour.
    local canGate
    function row:SetLinkGated(inCombat)
        local off = inCombat and canGate
        linkBtn:SetEnabled(not off)
        line:SetAlpha(off and 0.5 or 1)
    end

    function row:Set(d)
        local st = d.state
        local c = STATE_RIM[st] or K.neutral
        stripe:SetColorTexture(c[1], c[2], c[3], 1)
        local quality
        if d.itemID then quality = B.Data.IconData(d.itemID, false) end
        W.SetItemIcon(grey, {
            texture = d.icon or T.placeholderIcon, atlas = d.atlas, color = c, quality = quality,
            isNew = d.itemID ~= nil and B.Data.IsNew(d.itemID),
        })
        Vis.Desaturate.Set(grey, st == "locked" or st == "unknown", st == "locked")
        name:SetText(d.name or "")
        line:SetText(d.line2 or "")
        self.itemID, self.npcID = d.itemID, d.npcID
        self.onClick = d.onClick
        if tag then
            W.SetTag(tag, d.tag, d.tagOn)
            name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(rightW + (d.tag and TAG_W or 0)), -10)
        end

        if d.link then
            linkBtn.onClick = d.link.onClick
            linkBtn.tooltipLink = d.link.tooltipLink
            linkBtn:Show()
        else
            linkBtn:Hide()
        end
        canGate = d.link ~= nil and d.link.gated == true
        self:SetLinkGated(B.InCombat())

        wp.wp = d.wp
        wp:SetShown(d.wp ~= nil)

        if full then
            stateText:ClearAllPoints()
            if d.wp then
                stateText:SetPoint("RIGHT", wp, "LEFT", -S.space.m, 0)
            else
                stateText:SetPoint("RIGHT", row, "RIGHT", -S.space.l, 0)
            end
            glyph:ClearAllPoints()
            glyph:SetPoint("RIGHT", stateText, "LEFT", -S.space.xs, 0)
            if st then
                local tc = K.stateText[st]
                stateText:SetText(S.stateLabel[st] or "")
                stateText:SetTextColor(tc[1], tc[2], tc[3])
                stateText:Show()
                if STATE_GLYPH[st] then
                    glyph:SetAtlas(STATE_GLYPH[st])
                    glyph:Show()
                else
                    glyph:Hide()
                end
            else
                stateText:Hide()
                glyph:Hide()
            end
        end
    end

    row:SetScript("OnClick", function(self)
        if self.onClick then self.onClick() end
    end)
    row:SetScript("OnEnter", function(self)
        if self.itemID then B.ShowItemTooltip(self, self.itemID, self.npcID) end
    end)
    row:SetScript("OnLeave", function() B.HideTooltip() end)
    return row
end

local function ResetPooled(frame)
    if frame.Reset then frame:Reset() end
    local view = frame.view
    if view and view.Reset then view:Reset() end
end

local function ScrollParts(parent)
    local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
    local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    box:SetPoint("TOPLEFT")
    box:SetPoint("BOTTOMRIGHT", -LO.scrollBarGap, 0)
    bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 3, -2)
    bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 3, 2)
    return box, bar
end

-- Frames are built once, pooled by frameType: kinds in one list need distinct values (a template if it repeats).
function W.KindFactory(kinds)
    return function(factory, data)
        local spec = kinds[data.kind]
        factory(spec.frameType, function(frame, d)
            if not frame.built then
                frame.built = true
                spec.build(frame)
            end
            spec.init(frame, d)
        end)
    end
end

-- opts = { spacing, extent = fn(data), kinds = { [kind] = { frameType, build, init } },
--          reclaim = give the scrollbar's gutter back while the bar is hidden }
function W.NewList(parent, opts)
    local list = {}
    local box, bar = ScrollParts(parent)
    local view = CreateScrollBoxListLinearView(0, 0, 0, 0, opts.spacing or 0)
    view:SetElementExtentCalculator(function(_, data)
        return opts.extent(data)
    end)
    view:SetElementFactory(W.KindFactory(opts.kinds))
    view:SetElementResetter(ResetPooled)
    ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
    if opts.reclaim then
        ScrollUtil.AddManagedScrollBarVisibilityBehavior(box, bar, {
            CreateAnchor("TOPLEFT", parent, "TOPLEFT", 0, 0),
            CreateAnchor("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -LO.scrollBarGap, 0),
        }, {
            CreateAnchor("TOPLEFT", parent, "TOPLEFT", 0, 0),
            CreateAnchor("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0),
        })
    else
        ScrollUtil.AddManagedScrollBarVisibilityBehavior(box, bar)
    end
    list.box, list.bar = box, bar
    list.fade = Vis.EdgeFade.Attach(box)
    function list:SetData(tbl, keepPosition)
        box:SetDataProvider(CreateDataProvider(tbl), keepPosition)
        self.fade.Refresh()
    end
    function list:SetShown(shown)
        box:SetShown(shown)
        if not shown then bar:Hide() end
    end
    list.SetGroups, list.ToggleGroup = W.SetGroups, W.ToggleGroup
    return list
end

-- Grid of fixed-size cells; the stride follows the box width. opts = { cell, gap, build = fn(cell) once
-- per pooled frame, init = fn(cell, data) per swap }; a cell may define Reset.
function W.NewGrid(parent, opts)
    local list = {}
    local cell, gap = opts.cell, opts.gap
    local box, bar = ScrollParts(parent)
    local view = CreateScrollBoxListGridView(1, gap, gap, 0, 0, gap, gap)
    view:SetElementInitializer("Button", function(frame, d)
        if not frame.built then
            frame.built = true
            opts.build(frame)
        end
        opts.init(frame, d)
    end)
    view:SetElementResetter(ResetPooled)
    view:SetElementSize(cell, cell)
    ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(box, bar)
    list.box, list.bar, list.view = box, bar, view
    list.fade = Vis.EdgeFade.Attach(box)

    local function restride(width)
        local w = width or box:GetWidth()
        if not w or w < cell then return false end
        local n = math.max(1, math.floor((w + gap) / (cell + gap)))
        if n == view:GetStride() then return false end
        view:SetStride(n)
        return true
    end
    box:RegisterCallback(BaseScrollBoxEvents.OnSizeChanged, function()
        if restride() then box:FullUpdate() end
    end, list)

    function list:SetData(tbl, keepPosition, boxWidth)
        restride(boxWidth)
        box:SetDataProvider(CreateDataProvider(tbl), keepPosition)
        self.fade.Refresh()
    end
    return list
end

-- Empty-list line near the top of parent: names an active search or Hide owned with a clear control, else emptyText.
function W.NewEmptyState(parent, emptyText)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", S.space.l, -30)
    f:SetPoint("TOPRIGHT", -S.space.l, -30)
    f:SetHeight(48)
    local text = S.Text(f, "metaMuted", "OVERLAY")
    text:SetPoint("TOP")
    text:SetPoint("LEFT")
    text:SetPoint("RIGHT")
    local clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clear:SetText(L["Clear filters"])
    clear:SetSize(clear:GetTextWidth() + 32, 22)
    clear:SetPoint("TOP", text, "BOTTOM", 0, -S.space.s)
    clear:SetScript("OnClick", function() B.ClearFilters() end)
    f:Hide()

    function f:Update(isEmpty, noData)
        self:SetShown(isEmpty)
        if not isEmpty then return end
        local st = B.State
        local active = {}
        if not noData then
            if st.search ~= "" then active[#active + 1] = L["Search: %s"]:format(st.search) end
            if st.hideOwned then active[#active + 1] = L["Hide owned"] end
        end
        clear:SetShown(#active > 0)
        if #active > 0 then
            text:SetText(L["Nothing matches %s."]:format(table.concat(active, L[", "])))
        else
            text:SetText(emptyText)
        end
    end
    return f
end

-- Collapsed keys live in B.State.collapsed[setKey] (session only). Drops the rows under collapsed headers.
function W.CollapseGroups(full, set)
    local out, hidden = {}, false
    for _, d in ipairs(full) do
        if d.kind == "header" then
            hidden = set[d.key] == true
            d.collapsed = hidden
            out[#out + 1] = d
        elseif not hidden then
            out[#out + 1] = d
        end
    end
    return out
end

-- List methods; a header's key defaults to its text.
function W.SetGroups(list, full, setKey, keepPosition)
    list.full, list.setKey = full, setKey
    for _, d in ipairs(full) do
        if d.kind == "header" then d.list, d.key = list, d.key or d.text end
    end
    list:SetData(W.CollapseGroups(full, B.State.collapsed[setKey]), keepPosition)
end

function W.ToggleGroup(list, key)
    local set = B.State.collapsed[list.setKey]
    set[key] = not set[key] or nil
    W.SetGroups(list, list.full, list.setKey, true)
end

function W.BuildListHeader(f)
    f:RegisterForClicks("LeftButtonUp")
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(S.material.gilt[1], S.material.gilt[2], S.material.gilt[3], 0.08)
    local hover = f:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(unpack(K.hoverRow))
    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetSize(10, 10)
    f.icon:SetPoint("LEFT", S.space.m, 0)
    f.text = S.Text(f, "body", "OVERLAY")
    f.text:SetPoint("LEFT", f.icon, "RIGHT", S.space.s, 0)
    f.text:SetPoint("RIGHT", -S.space.m, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(false)
    f:SetScript("OnClick", function(self)
        local d = self.d
        if d and d.list then d.list:ToggleGroup(d.key) end
    end)
end

function W.InitListHeader(f, d)
    f.d = d
    f.text:SetText(d.text)
    f.icon:SetAtlas(d.collapsed and S.atlas.expand or S.atlas.collapse)
end

-- The achievement journal is Blizzard's: never opened from addon code in combat.
function W.OpenAchievement(id)
    if InCombatLockdown() then return end
    ShowAchievementFrameForAchievement(id)
end
