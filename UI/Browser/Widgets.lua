-- Shared widgets. Tooltips come from B at call time.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local S = B.Style
local Vis = B.Vis
local LO = S.layout
local T = S.tex
local C = S.coord
local K = S.color
local SP = S.space
local R = S.row

local W = {}
B.Widgets = W

local panes = {}

local function HideTip() B.HideTooltip() end

local function Coord(tex, c)
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
end

local ruler

function W.TextHeight(role, text, width)
    if not ruler then
        ruler = UIParent:CreateFontString(nil, "ARTWORK")
        ruler:Hide()
    end
    ruler:SetFontObject(S.FontName(role))
    ruler:SetWidth(width or 0)
    ruler:SetText(text or "Ag")
    return ruler:GetStringHeight()
end

-- Read at draw time and never kept, so a colour override shows on the next draw.
function W.QualityRGB(quality)
    if not quality then return K.body[1], K.body[2], K.body[3] end
    local c = C_ColorOverrides.GetColorForQuality(quality)
    if not c then return K.body[1], K.body[2], K.body[3] end
    return c.r, c.g, c.b
end

local measured = {}
local function Measured(key, fn)
    local scale = TextSizeManager:GetScale()
    if measured.scale ~= scale then
        wipe(measured)
        measured.scale = scale
    end
    local h = measured[key]
    if not h then
        h = fn()
        measured[key] = h
    end
    return h
end

function W.ResetMeasure()
    wipe(measured)
end

local function MeasureRow()
    return math.max(2 * R.pad + 2 * W.TextHeight("body") + R.gap, R.tile + 2 * R.pad)
end

function W.RowHeight()
    return Measured("row", MeasureRow)
end

function W.StateWords(state, arg)
    return S.state[state].word:format(arg or "")
end

function W.Well(parent)
    return Vis.Chrome.Inset(parent)
end

local function PaintPane(pane, opaque)
    local sc, bd = S.backdrop.scrim, S.backdrop
    local a = opaque and 1 or bd.pageAlpha
    pane.fill:SetColorTexture(sc[1], sc[2], sc[3], a)
end

function W.Pane(parent)
    local pane = CreateFrame("Frame", nil, parent)
    pane.fill = pane:CreateTexture(nil, "BACKGROUND", nil, -1)
    pane.fill:SetAllPoints()
    panes[#panes + 1] = pane
    PaintPane(pane)
    return pane
end

function W.OpaquePanes(opaque)
    for _, pane in ipairs(panes) do PaintPane(pane, opaque) end
end

function W.NewButton(parent, label, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetNormalFontObject(S.font.bodyGold)
    b:SetHighlightFontObject(S.font.body)
    b:SetDisabledFontObject(S.font.bodyMuted)
    b:SetText(label)
    function b:Fit()
        self:SetSize(self:GetTextWidth() + SP.xl, W.TextHeight("body") + SP.s)
    end
    b:Fit()
    b:SetScript("OnClick", onClick)
    return b
end

-- A text link: muted at rest, white under the mouse, darker while disabled. onEnter runs after the tint, so a
-- caller can add a tooltip. Fit sizes it to the text.
function W.NewLink(parent, label, onClick, onEnter)
    local b = CreateFrame("Button", nil, parent)
    b.text = S.Text(b, "body", "OVERLAY")
    b.text:SetPoint("LEFT")
    b.text:SetText(label)
    local setEnabled, over = b.SetEnabled, false
    local function Tint()
        local c = not b:IsEnabled() and K.disabled or over and K.body or K.muted
        b.text:SetTextColor(c[1], c[2], c[3])
    end
    function b:SetEnabled(on)
        setEnabled(self, on)
        Tint()
    end
    function b:Fit()
        self:SetSize(self.text:GetUnboundedStringWidth(), W.TextHeight("body"))
    end
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        over = true
        Tint()
        if onEnter then onEnter(self) end
    end)
    b:SetScript("OnLeave", function()
        over = false
        Tint()
        B.HideTooltip()
    end)
    b:Fit()
    Tint()
    return b
end

-- A one-text tooltip on owner; wrap lets a long text run to several lines.
function W.TextTip(owner, anchor, text, wrap)
    local tip = B.Tooltip()
    tip:SetOwner(owner, anchor)
    tip:SetText(text, nil, nil, nil, nil, wrap)
    tip:Show()
end

-- The muted "Report a problem" link. It is off in combat and says why under the mouse.
function W.ReportLink(parent, onClick)
    local b = W.NewLink(parent, L["Report a problem"], onClick, function(self)
        if not self:IsEnabled() then W.TextTip(self, "ANCHOR_RIGHT", L["Not available in combat"]) end
    end)
    b:SetMotionScriptsWhileDisabled(true)
    return b
end

-- A tooltip for a one-line text that is cut off, or always when fs.tip is set. Returns the mouse frame.
function W.Clip(fs)
    local hit = CreateFrame("Frame", nil, fs:GetParent())
    hit:SetAllPoints(fs)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", function(self)
        local text = fs.tip or fs:IsTruncated() and fs:GetText()
        if text then W.TextTip(self, "ANCHOR_RIGHT", text, true) end
    end)
    hit:SetScript("OnLeave", HideTip)
    return hit
end

function W.NewSearchBox(parent, placeholder, onChange)
    local box = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
    box:SetFontObject(S.font.body)
    box.Instructions:SetFontObject(S.font.bodyMuted)
    box.Instructions:SetText(placeholder)
    box:SetHeight(W.TextHeight("body") + SP.s)
    box:HookScript("OnTextChanged", function(self, byPlayer) onChange(self:GetText(), byPlayer) end)
    B.Window.AddSearchBox(box)
    return box
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
    b:SetScript("OnEnter", function(self) W.TextTip(self, "ANCHOR_LEFT", L["Set waypoint"]) end)
    b:SetScript("OnLeave", HideTip)
    return b
end

function W.NewTile(parent, size)
    local tile = { icon = parent:CreateTexture(nil, "ARTWORK") }
    tile.icon:SetSize(size, size)
    Coord(tile.icon, C.wareIcon)
    tile.plate = parent:CreateTexture(nil, "ARTWORK", nil, -1)
    tile.plate:SetAllPoints(tile.icon)
    tile.plate:SetColorTexture(1, 1, 1, 1)
    tile.plate:SetGradient("VERTICAL", CreateColor(unpack(K.iconPlateBottom)), CreateColor(unpack(K.iconPlateTop)))
    tile.border = parent:CreateTexture(nil, "OVERLAY")
    tile.border:SetTexture(T.iconBorder)
    tile.border:SetAllPoints(tile.icon)
    return tile
end

-- d = { icon (file) or atlas }; the border takes the colour r, g, b. Sets every field, so a recycled tile
-- keeps nothing.
function W.SetTile(tile, d, r, g, b)
    if d.atlas then tile.icon:SetAtlas(d.atlas) else tile.icon:SetTexture(d.icon or T.placeholderIcon) end
    tile.border:SetVertexColor(r, g, b, 1)
end

local function Natural(el)
    return el.GetUnboundedStringWidth and el:GetUnboundedStringWidth() or el:GetWidth()
end

-- Lays the shown elements right to left in box. The first is a text: with a cap (the most the box may take) it
-- gets what the others leave and truncates there, and without one it gets its natural width back, since a
-- recycled row keeps the last width it was given. A width of 0 would mean unbounded, so it never goes below 1.
local function Pack(box, cap, first, ...)
    local others = 0
    for i = 1, select("#", ...) do
        local el = select(i, ...)
        if el:IsShown() then others = others + Natural(el) + SP.xs end
    end
    local x = 0
    if first:IsShown() then
        local natural = math.max(Natural(first), 1)
        local w = cap and math.max(math.min(natural, cap - others), 1) or natural
        first:SetWidth(w)
        first:ClearAllPoints()
        first:SetPoint("RIGHT", box, "RIGHT", 0, 0)
        x = w + SP.xs
    end
    for i = 1, select("#", ...) do
        local el = select(i, ...)
        if el:IsShown() then
            el:ClearAllPoints()
            el:SetPoint("RIGHT", box, "RIGHT", -x, 0)
            x = x + Natural(el) + SP.xs
        end
    end
    box:SetWidth(math.max(x - SP.xs, 1))
end

function W.Linked(id)
    if id and IsModifiedClick("CHATLINK") then
        local _, link = C_Item.GetItemInfo(id)
        return link and HandleModifiedItemClick(link)
    end
end

-- A page asked to draw before its window has a width owes that draw. Owe merges what is asked with what is
-- already owed, so a refresh arriving first loses neither the fresh flag nor the saved position; Owed unpacks
-- it for the draw that pays it.
function W.Owe(owed, fresh, saved)
    return { fresh or (owed and owed[1]) or false, saved or (owed and owed[2]) }
end

function W.Owed(owed)
    return owed and owed[1] or false, owed and owed[2]
end

-- A left-justified text on the overlay layer.
function W.Text(parent, role)
    local fs = S.Text(parent, role or "body", "OVERLAY")
    fs:SetJustifyH("LEFT")
    return fs
end

-- Items joined one by one through format, a "%s, %s" style string.
function W.Join(items, format)
    local out = items[1]
    for i = 2, #items do out = format:format(out, items[i]) end
    return out
end

local function Redraw(self)
    if self.d then self:Set(self.d) end
end

-- A recycled frame drops its data, and its tooltip if it owns it (the wheel scrolled it away under the mouse).
local function Reset(self)
    self.d, self.itemID, self.npcID, self.onClick, self.onEnter = nil, nil, nil, nil, nil
    B.HideTooltipFor(self)
end

local function ShowTip(self)
    if self.onEnter then self.onEnter(self) elseif self.itemID then B.ShowItemTooltip(self, self.itemID, self.npcID) end
end

local function BuildRight(row)
    local box = CreateFrame("Frame", nil, row)
    box:SetHeight(W.TextHeight("body"))
    return box
end

-- What a line's right box may take once the row's text room is known: all that its left text does not need,
-- the left text keeping at most half.
local function Cap(fs, room)
    return room and room - math.min(math.ceil(fs:GetUnboundedStringWidth()), math.floor(room / 2)) or nil
end

-- Decor row on a pooled Button: row:Set{ name, quality, icon or atlas, noTile, active, bonus, right, line2,
-- unconfirmed, state (an S.state key), arg, selected, itemID, npcID, onClick, onEnter }, Redraw, Reset.
function W.BuildRow(row)
    row:RegisterForClicks("LeftButtonUp")
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    local stripe = row:CreateTexture(nil, "BORDER")
    stripe:SetPoint("TOPLEFT")
    stripe:SetPoint("BOTTOMLEFT")
    PixelUtil.SetWidth(stripe, 2, 1)
    stripe:SetColorTexture(unpack(K.gold))
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(unpack(K.hoverRow))

    local tile = W.NewTile(row, R.tile)
    tile.icon:SetPoint("LEFT", SP.s, 0)

    local top, bottom = BuildRight(row), BuildRight(row)
    top:SetPoint("TOPRIGHT", -SP.s, -R.pad)
    bottom:SetPoint("BOTTOMRIGHT", -SP.s, R.pad)
    local price = S.Text(top, "body", "OVERLAY")
    price:SetWordWrap(false)
    price:SetTextColor(unpack(K.money))
    local badge = S.Text(top, "meta", "OVERLAY")
    badge:SetTextColor(unpack(K.badge))
    badge:SetText(L["Active now"])
    local clock = top:CreateTexture(nil, "OVERLAY")
    clock:SetSize(12, 12)
    local star = top:CreateTexture(nil, "OVERLAY")
    star:SetSize(12, 12)
    local words = S.Text(bottom, "body", "OVERLAY")
    words:SetWordWrap(false)
    local mark = bottom:CreateTexture(nil, "OVERLAY")
    mark:SetSize(12, 12)
    local tag = CreateFrame("Frame", nil, bottom)
    Vis.Chrome.Hairline(tag, K.muted, 0.7)
    tag.text = S.Text(tag, "metaMuted", "OVERLAY")
    tag.text:SetPoint("CENTER")
    tag.text:SetText(L["Not confirmed"])

    local name = S.Text(row, "body", "OVERLAY")
    local line = S.Text(row, "bodyMuted", "OVERLAY")
    for _, fs in ipairs({ name, line }) do
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
    end

    function row:Set(d)
        self.d = d
        local r, g, b = W.QualityRGB(d.quality)
        local st = S.state[d.state]
        local c = st and st.color or K.muted
        self.bg:SetColorTexture(unpack(d.selected and K.selected or K.card))
        stripe:SetShown(d.selected == true)
        tile.icon:SetShown(not d.noTile)
        tile.plate:SetShown(not d.noTile)
        tile.border:SetShown(not d.noTile)
        W.SetTile(tile, d, r, g, b)
        tile.icon:SetDesaturated(d.state == "locked")
        local left = SP.s + (d.noTile and 0 or R.tile + SP.s)
        name:ClearAllPoints()
        name:SetPoint("TOPLEFT", row, "TOPLEFT", left, -R.pad)
        name:SetPoint("TOPRIGHT", top, "TOPLEFT", -SP.s, 0)
        line:ClearAllPoints()
        line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", left, R.pad)
        line:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMLEFT", -SP.s, 0)
        name:SetText(d.name or "")
        name:SetTextColor(r, g, b)
        price:SetText(d.right or "")
        badge:SetShown(d.active and true or false)
        Vis.Marker.Set(clock, d.active and "clock" or nil, K.badge)
        Vis.Marker.Set(star, d.bonus and "star" or nil, K.gold)
        -- The right words truncate first: each line's left text keeps the width it needs, up to half the room.
        local width = self:GetWidth()
        local room = width > 0 and width - left - 2 * SP.s or nil
        Pack(top, Cap(name, room), price, badge, clock, star)

        words:SetShown(st ~= nil)
        words:SetText(st and W.StateWords(d.state, d.arg) or "")
        words:SetTextColor(c[1], c[2], c[3])
        Vis.Marker.Set(mark, st and st.glyph, c)
        tag:SetShown(d.unconfirmed == true)
        tag:SetSize(tag.text:GetUnboundedStringWidth() + SP.s, W.TextHeight("meta") + 2)
        line:SetText(d.line2 or "")
        Pack(bottom, Cap(line, room), words, mark, tag)

        self.itemID, self.npcID = d.itemID, d.npcID
        self.onClick, self.onEnter = d.onClick, d.onEnter
    end

    row.Redraw, row.Reset = Redraw, Reset
    -- The row's width can arrive after its first Set; Set reads it again.
    row:SetScript("OnSizeChanged", Redraw)
    row:SetScript("OnClick", function(self)
        if W.Linked(self.itemID) then return end
        if self.onClick then self.onClick() end
    end)
    row:SetScript("OnEnter", ShowTip)
    row:SetScript("OnLeave", HideTip)
    return row
end

W.rowKind = {
    frameType = "Button",
    build = W.BuildRow,
    init = function(f, d) f:Set(d) end,
}

function W.RepaintRows(list)
    list.box:ForEachFrame(function(frame)
        if frame.Redraw then frame:Redraw() end
    end)
end

local function ResetPooled(frame)
    if frame.Reset then frame:Reset() end
end

local function ScrollParts(parent, view)
    local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
    local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    box:SetPoint("TOPLEFT")
    box:SetPoint("BOTTOMRIGHT", -LO.scrollBarGap, 0)
    bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 3, -2)
    bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 3, 2)
    ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
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

-- opts = { spacing, extent = fn(data) (a row's height by default), kinds = { [kind] = { frameType, build,
--          init } }, reclaim = give the scrollbar's gutter back while the bar is hidden }
function W.NewList(parent, opts)
    local list = {}
    local view = CreateScrollBoxListLinearView(0, 0, 0, 0, opts.spacing or 0)
    local box, bar = ScrollParts(parent, view)
    view:SetElementExtentCalculator(function(_, data)
        return (opts.extent or W.RowHeight)(data)
    end)
    view:SetElementFactory(W.KindFactory(opts.kinds))
    view:SetElementResetter(ResetPooled)
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
    function list:SetData(tbl, keepPosition)
        box:SetDataProvider(CreateDataProvider(tbl), keepPosition)
    end
    function list:SetShown(shown)
        box:SetShown(shown)
        if not shown then bar:Hide() end
    end
    return list
end

function W.Bar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar.text = S.Text(bar, "body", "OVERLAY")
    bar.text:SetPoint("TOPLEFT")
    local fill = CreateFrame("StatusBar", nil, bar)
    fill:SetPoint("BOTTOMLEFT")
    fill:SetPoint("BOTTOMRIGHT")
    fill:SetHeight(6)
    fill:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
    fill:SetStatusBarColor(unpack(K.gold))
    fill:SetMinMaxValues(0, 1)
    local track = fill:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0, 0, 0, 0.45)
    function bar:Set(label, ratio)
        self.text:SetText(label)
        fill:SetValue(ratio or 0)
    end
    function bar:Fit()
        self:SetHeight(W.TextHeight("body") + SP.xs + 6)
    end
    bar:Fit()
    return bar
end

function W.NewWareCell(cell)
    local tile = W.NewTile(cell, S.ware.size)
    tile.icon:SetPoint("CENTER")
    local hover = cell:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(unpack(K.hoverRow))
    cell:RegisterForClicks("LeftButtonUp")
    local function Corner(point, x, y)
        local t = cell:CreateTexture(nil, "OVERLAY", nil, 1)
        t:SetSize(14, 14)
        t:SetPoint(point, x, y)
        return t
    end
    local mark, star, clock = Corner("TOPRIGHT", -2, -2), Corner("TOPLEFT", 2, -2), Corner("BOTTOMLEFT", 2, 2)
    local copies = S.Text(cell, "meta", "OVERLAY")
    copies:SetPoint("BOTTOMRIGHT", -3, 3)

    function cell:Set(d)
        self.d, self.itemID, self.npcID = d, d.itemID, d.npcID
        local st = S.state[d.state]
        W.SetTile(tile, d, W.QualityRGB(d.quality))
        tile.icon:SetDesaturated(d.state == "locked")
        Vis.Marker.Set(mark, st and st.glyph, st and st.color)
        Vis.Marker.Set(star, d.bonus and "star" or nil, K.gold)
        Vis.Marker.Set(clock, d.active and "clock" or nil, K.badge)
        copies:SetShown(d.copies ~= nil)
        copies:SetText(d.copies and d.copies > 99 and "99+" or d.copies or "")
    end
    cell.Redraw, cell.Reset = Redraw, Reset
    cell:SetScript("OnClick", function(self)
        if W.Linked(self.itemID) then return end
        if self.itemID then B.Go({ kind = "item", id = self.itemID }) end
    end)
    cell:SetScript("OnEnter", ShowTip)
    cell:SetScript("OnLeave", HideTip)
    return cell
end

function W.NewGrid(parent, cell, gap)
    local list = {}
    local view = CreateScrollBoxListGridView(1, gap, gap, 0, 0, gap, gap)
    local box, bar = ScrollParts(parent, view)
    view:SetElementInitializer("Button", function(frame, d)
        if not frame.built then
            frame.built = true
            W.NewWareCell(frame)
        end
        frame:Set(d)
    end)
    view:SetElementResetter(ResetPooled)
    view:SetElementSize(cell, cell)
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(box, bar)
    list.box, list.bar, list.view = box, bar, view

    local function Restride(width)
        local w = width or box:GetWidth()
        if w < cell then return false end
        local n = math.floor((w + gap) / (cell + gap))
        if n == view:GetStride() then return false end
        view:SetStride(n)
        return true
    end
    -- A box with nothing to scroll gives the wheel to whatever scrolls behind it.
    local function Wheel()
        box:EnableMouseWheel(box:HasScrollableExtent())
    end
    box:HookScript("OnSizeChanged", function()
        if Restride() then box:FullUpdate() end
        Wheel()
    end)

    function list:SetData(tbl, keepPosition, boxWidth)
        Restride(boxWidth)
        box:SetDataProvider(CreateDataProvider(tbl), keepPosition)
        Wheel()
    end
    function list:SetShown(shown)
        box:SetShown(shown)
        if not shown then bar:Hide() end
    end
    return list
end

-- List kinds for the pieces that sit among rows. Group header: { kind = "header", text, nested }; a nested
-- header sits one step in under its parent header.
-- Footer: { kind = "footer", hidden, collected, parts (Facts.FactionParts) or faction and factionName, onShow }.
W.headerKind = {
    frameType = "HomesteadDecorBrowserHeader",
    build = function(f)
        f.text = S.Text(f, "bodyGold", "OVERLAY")
        f.text:SetPoint("RIGHT", -SP.s, 0)
        f.text:SetJustifyH("LEFT")
        f.text:SetWordWrap(false)
        Vis.Chrome.Hairline(f, K.muted, 0.35)
    end,
    init = function(f, d)
        f.text:SetPoint("LEFT", d.nested and SP.s + SP.m or SP.s, 0)
        f.text:SetText(d.text)
    end,
}

local function MeasureHeader()
    return W.TextHeight("body") + SP.s
end

function W.HeaderHeight()
    return Measured("header", MeasureHeader)
end

function W.FooterText(d)
    local p, hide = d.parts or { { d.faction, d.factionName } }, L["Hide collected and other-faction"]
    if p[2] then
        return L["%d hidden by '%s' (%d collected, %d %s only, %d %s only)."]:format(
            d.hidden, hide, d.collected, p[1][1], p[1][2], p[2][1], p[2][2])
    elseif p[1] then
        return L["%d hidden by '%s' (%d collected, %d %s only)."]:format(d.hidden, hide, d.collected, p[1][1], p[1][2])
    end
    return L["%d hidden by '%s' (%d collected)."]:format(d.hidden, hide, d.collected)
end
local FooterText = W.FooterText

W.footerKind = {
    frameType = "HomesteadDecorBrowserFooter",
    build = function(f)
        f.text = S.Text(f, "bodyMuted", "OVERLAY")
        f.text:SetPoint("TOPLEFT", SP.s, -SP.s)
        f.text:SetPoint("TOPRIGHT", -SP.s, -SP.s)
        f.text:SetJustifyH("LEFT")
        f.link = W.NewLink(f, L["Show them"], function(self)
            local show = self:GetParent().onShow
            if show then show() end
        end)
        f.link:SetPoint("TOPLEFT", f.text, "BOTTOMLEFT", 0, -R.gap)
    end,
    init = function(f, d)
        f.onShow = d.onShow
        f.text:SetText(FooterText(d))
        f.link:Fit()
    end,
}

function W.FooterHeight(d, width)
    return W.TextHeight("bodyMuted", FooterText(d), width - 2 * SP.s) + W.TextHeight("body") + 2 * SP.s + R.gap
end

local EMPTY = {
    counting = { L["Counting…"], L["Reading your collection. This list fills in when it's ready."] },
    countingSort = { L["Counting…"],
        L["Reading your collection. This list fills in when it's ready, because Best to get now depends on what you own."],
        { "onSort", L["Sort by name"] } },
    nothingMissing = { L["Nothing missing"], L["You've collected all %d decor Homestead knows about."] },
    nothingNow = { L["Nothing you can get right now"],
        L["Everything you're missing needs a reputation, achievement or quest first, is sold only during an event, or is sold only to the %s."],
        { "onMissing", L["Show what's missing"] } },
    notRead = { L["Collection not read yet"],
        L["Homestead hasn't read this character's decor collection yet, so it can't tell what you're missing. It reads it shortly after you log in. If this message stays, open the Housing Dashboard once."] },
    notReadFilters = { L["Collection not read yet"],
        L["These filters need your collection, which Homestead hasn't read yet. If this stays, open the Housing Dashboard once."],
        { "onReset", L["Reset filters"] } },
    noResults = { L["No results"], L["No decor matches these words and filters. Search looks at item names only."],
        { "onReset", L["Reset filters"] }, { "onShow", L["Show them"] }, { "onAll", L["Search all decor"] } },
}

local NEEDS_ARG = { nothingMissing = true, nothingNow = true }

-- Empty-list block near the top of parent. f:Set(kind, d): d.arg fills a %d or %s in the text; d.title and
-- d.text replace the kind's words; d's on* fields are the buttons' handlers.
function W.NewEmptyState(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", SP.m, -SP.m)
    f:SetPoint("TOPRIGHT", -SP.m, -SP.m)
    f.title = S.Text(f, "subheader", "OVERLAY")
    f.title:SetPoint("TOPLEFT")
    f.title:SetPoint("TOPRIGHT")
    f.title:SetTextColor(unpack(K.body))
    f.text = S.Text(f, "body", "OVERLAY")
    f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -SP.xs)
    f.text:SetPoint("TOPRIGHT", f.title, "BOTTOMRIGHT", 0, -SP.xs)
    f.text:SetJustifyH("LEFT")
    f.title:SetJustifyH("LEFT")
    f.buttons = {}
    f:Hide()

    function f:Set(kind, d)
        d = d or {}
        local e = EMPTY[kind]
        if NEEDS_ARG[kind] and d.arg == nil and not d.text then error("empty state " .. kind .. " needs d.arg", 2) end
        self.title:SetText(d.title or e[1])
        self.text:SetText(d.text or d.arg ~= nil and e[2]:format(d.arg) or e[2])
        local prev, n = nil, 0
        for i = 3, #e do
            local spec = e[i]
            if d[spec[1]] then
                n = n + 1
                local b = self.buttons[n] or W.NewButton(self, "", nil)
                self.buttons[n] = b
                b:SetText(spec[2])
                b:SetScript("OnClick", d[spec[1]])
                b:Fit()
                b:ClearAllPoints()
                if prev then b:SetPoint("LEFT", prev, "RIGHT", SP.s, 0)
                else b:SetPoint("TOPLEFT", self.text, "BOTTOMLEFT", 0, -SP.s) end
                b:Show()
                prev = b
            end
        end
        for i = n + 1, #self.buttons do self.buttons[i]:Hide() end
        self:Show()
    end
    return f
end
