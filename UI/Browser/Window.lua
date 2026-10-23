-- Browser window: frame, header, tree, crumb bar, scale-to-fit, Escape and motion. Built on first open.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local S = B.Style
local Vis = B.Vis
local W = B.Widgets
local LO = S.layout
local K = S.color
local SP = S.space
local PAD = S.pad
local WIN_W, WIN_H = S.window.width, S.window.height

local Win = {}
B.Window = Win

local OPEN_TIME, CLOSE_TIME, TRAVEL = 0.15, 0.1, 8
local SEARCH_W = 150
local DEFAULT_HINT = L["Search decor"]
local CRUMB_SEP = " \226\128\186 "

local hooks
local laidOutTextScale
local searchBoxes = {}
local restoring

function Win.AddSearchBox(box)
    searchBoxes[#searchBoxes + 1] = box
end

local function CropBackdrop(tex, info, w, h)
    if not (info and w and h and w > 0 and h > 0) then return end
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    local ratio = (w / h) / (info.width / info.height)
    local padX, padY = 0, 0
    if ratio > 1 then
        padY = (1 - 1 / ratio) / 2
    else
        padX = (1 - ratio) / 2
    end
    local dw, dh = r - l, b - t
    tex:SetTexCoord(l + dw * padX, r - dw * padX, t + dh * padY, b - dh * padY)
end

local CORNER_POINT = { TL = "TOPLEFT", TR = "TOPRIGHT", BL = "BOTTOMLEFT", BR = "BOTTOMRIGHT" }

-- Tree rows: a group's label opens its page and its +/- only folds. Folds last the session.
local function Row(key, label, route, kids)
    return { kind = "row", key = key, label = label, route = route, kids = kids }
end

local function CatalogKids()
    local kids = { Row("catalog:all", L["All decor"], { kind = "catalog", key = "all" }) }
    for _, k in ipairs({ 1, 2, 3, 4, "other" }) do
        kids[#kids + 1] = Row("catalog:" .. k, S.kind[k], { kind = "catalog", key = k })
    end
    return kids
end

local function VendorKids()
    local kids = {}
    for _, e in ipairs(B.Data.Expansions()) do
        kids[#kids + 1] = Row("vendors:" .. e, B.Data.ExpansionLabel(e), { kind = "vendors", key = e })
    end
    return kids
end

local TREE = {
    Row("overview", L["Overview"], { kind = "overview" }),
    Row("catalog", L["Catalog"], { kind = "catalog", key = "all" }, CatalogKids),
    Row("vendors", L["Vendors"], { kind = "allVendors" }, VendorKids),
}
for _, t in ipairs({ "achievements", "quests", "professions", "drops", "events", "shop" }) do
    TREE[#TREE + 1] = Row(t, S.sourceLabel[t], { kind = "sources", key = t })
end

local expanded, list, selected, selGroup, rowH, crumbH, backShown, lastSegs = {}, nil, "overview", nil, 0, 0, false

local function NavData()
    local data = {}
    for _, row in ipairs(TREE) do
        data[#data + 1] = row
        if row.kids and expanded[row.key] then
            for _, kid in ipairs(row.kids()) do
                kid.child = true
                data[#data + 1] = kid
            end
        end
    end
    return data
end

local function ReloadNav(data)
    list:SetData(data or NavData(), true)
end

local function ShowTruncated(self, fs)
    if fs:IsTruncated() then W.TextTip(self, "ANCHOR_RIGHT", fs:GetText()) end
end

local function BuildRow(f)
    f.hl = f:CreateTexture(nil, "HIGHLIGHT")
    f.hl:SetColorTexture(unpack(K.hoverRow))
    f.sel = f:CreateTexture(nil, "BACKGROUND")
    Vis.Chrome.VGradient(f.sel, K.gold, 0.04, 0.22)
    f.bar = f:CreateTexture(nil, "ARTWORK")
    f.bar:SetColorTexture(K.gold[1], K.gold[2], K.gold[3], 1)
    PixelUtil.SetWidth(f.bar, 3)
    f.fold = CreateFrame("Button", nil, f)
    f.fold:SetSize(16, 16)
    f.fold:SetScript("OnClick", function()
        expanded[f.data.key] = not expanded[f.data.key]
        ReloadNav()
    end)
    f.label = S.Text(f, "bodyGold", "OVERLAY")
    f.label:SetJustifyH("LEFT")
    f.label:SetWordWrap(false)
    f:RegisterForClicks("LeftButtonUp")
    f:SetScript("OnClick", function(self) B.Go(self.data.route) end)
    f:SetScript("OnEnter", function(self) ShowTruncated(self, self.label) end)
    f:SetScript("OnLeave", B.HideTooltip)
end

local function InitRow(f, d)
    f.data = d
    local indent = d.child and S.nav.indent or 0
    for _, region in ipairs({ f.hl, f.sel }) do
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", indent, 0)
        region:SetPoint("BOTTOMRIGHT")
    end
    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPLEFT", indent, 0)
    f.bar:SetPoint("BOTTOMLEFT", indent, 0)
    local on = d.key == selected or d.key == selGroup and not expanded[selGroup]
    f.sel:SetShown(on)
    f.bar:SetShown(on)
    f.fold:ClearAllPoints()
    f.fold:SetPoint("LEFT", indent + SP.xs, 0)
    f.fold:SetShown(d.kids ~= nil)
    if d.kids then f.fold:SetNormalAtlas(expanded[d.key] and S.atlas.collapse or S.atlas.expand) end
    f.label:ClearAllPoints()
    f.label:SetPoint("LEFT", indent + 2 * SP.xs + 16, 0)
    f.label:SetPoint("RIGHT", -SP.s, 0)
    f.label:SetFontObject(S.font[d.child and (on and "metaGold" or "meta") or "bodyGold"])
    f.label:SetText(d.label)
end

local function BuildTree(page)
    local tree = CreateFrame("Frame", nil, page)
    tree:SetPoint("TOPLEFT", LO.pagePad, -LO.pagePad)
    tree:SetPoint("BOTTOMLEFT", LO.pagePad, LO.pagePad)
    tree:SetWidth(S.nav.width)
    list = W.NewList(tree, {
        spacing = S.nav.gap,
        reclaim = true,
        extent = function() return rowH end,
        kinds = { row = { frameType = "Button", build = BuildRow, init = InitRow } },
    })
    return tree
end

-- A crumb segment's tree row, the group the row lives in, and its label.
local function Describe(r, last)
    local k, key = r.kind, r.key
    if k == "overview" then return k, nil, L["Overview"] end
    if k == "catalog" then
        return "catalog:" .. tostring(key), "catalog", key == "all" and (last and L["All decor"] or L["Catalog"]) or S.kind[key]
    end
    if k == "vendors" then return "vendors:" .. tostring(key), "vendors", B.Data.ExpansionLabel(key) end
    if k == "allVendors" then return "vendors", "vendors", L["Vendors"] end
    if k == "sources" then return key, nil, S.sourceLabel[key] end
    if k == "vendor" then
        local v = B.Data.Vendor(r.id)
        return nil, nil, v and v.name or L["Unknown"]
    end
    if k == "item" then return nil, nil, B.Data.ItemName(r.id) or L["Item %d"]:format(r.id) end
    if k == "source" then return nil, nil, B.SourceTitle(r.key, r.id) end
    return nil, nil, tostring(r.id)
end

-- Lights the deepest crumb segment that has a row, else its group row; the page's group opens. A folded
-- group lights itself while it hides the lit row.
function Win.SelectNav(route)
    local segs = B.Home(route)
    for _, seg in ipairs(segs) do
        local _, group = Describe(seg)
        if group then expanded[group] = true end
    end
    local data, has = NavData(), {}
    for _, d in ipairs(data) do has[d.key] = true end
    selected, selGroup = "overview", nil
    for i = #segs, 1, -1 do
        local row, group = Describe(segs[i])
        local pick = has[row] and row or has[group] and group
        if pick then
            selected, selGroup = pick, group
            break
        end
    end
    ReloadNav(data)
end

local crumbs = {}
Win.crumbs = crumbs

local function PlaceCrumb(c, prev)
    local b = c.btn
    b:ClearAllPoints()
    if prev then
        b:SetPoint("LEFT", prev.sep, "RIGHT")
    elseif backShown then
        b:SetPoint("LEFT", Win.back, "RIGHT", SP.m, 0)
    else
        b:SetPoint("LEFT", Win.bar, "LEFT", SP.s, 0)
    end
    if c.last then b:SetPoint("RIGHT", Win.bar, "RIGHT", -SP.m, 0) end
end

local function NewCrumb()
    local c = {}
    c.btn = CreateFrame("Button", nil, Win.bar)
    c.btn:SetHeight(crumbH)
    c.text = S.Text(c.btn, "body", "OVERLAY")
    c.text:SetAllPoints()
    c.text:SetJustifyH("LEFT")
    c.text:SetWordWrap(false)
    c.sep = S.Text(Win.bar, "body", "OVERLAY")
    c.sep:SetTextColor(K.muted[1], K.muted[2], K.muted[3])
    c.sep:SetText(CRUMB_SEP)
    c.btn:SetScript("OnClick", function() if c.route then B.Go(c.route) end end)
    return c
end

-- The page's home in the tree: earlier segments link, the last is plain text.
function Win.SetCrumb(segs)
    local prev
    lastSegs = segs
    for i, route in ipairs(segs) do
        local c = crumbs[i] or NewCrumb()
        crumbs[i] = c
        c.last = i == #segs
        c.route = not c.last and route or nil
        c.btn:EnableMouse(not c.last)
        c.text:SetText(select(3, Describe(route, c.last)))
        local col = c.last and K.body or K.muted
        c.text:SetTextColor(col[1], col[2], col[3])
        c.btn:SetWidth(c.last and 0 or c.text:GetStringWidth() + 1)
        PlaceCrumb(c, prev)
        c.sep:ClearAllPoints()
        c.sep:SetPoint("LEFT", c.btn, "RIGHT")
        c.btn:Show()
        c.sep:SetShown(not c.last)
        prev = c
    end
    for i = #segs + 1, #crumbs do
        crumbs[i].btn:Hide()
        crumbs[i].sep:Hide()
    end
end

function Win.SetBack(on)
    backShown = on
    Win.back:SetShown(on)
    if crumbs[1] then PlaceCrumb(crumbs[1]) end
end

local function BuildBar(page, tree)
    local bar = CreateFrame("Frame", nil, page)
    bar:SetPoint("TOPLEFT", tree, "TOPRIGHT", SP.xs, 0)
    bar:SetPoint("TOPRIGHT", -LO.pagePad, -LO.pagePad)
    Win.bar = bar
    local back = CreateFrame("Button", nil, bar)
    back.arrow = back:CreateTexture(nil, "ARTWORK")
    back.arrow:SetAtlas(S.atlas.backArrow)
    back.arrow:SetSize(14, 14)
    back.arrow:SetPoint("LEFT")
    local hover = back:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAtlas(S.atlas.backArrow)
    hover:SetAllPoints(back.arrow)
    hover:SetBlendMode("ADD")
    back.text = S.Text(back, "bodyGold", "OVERLAY")
    back.text:SetPoint("LEFT", back.arrow, "RIGHT", SP.xs, 0)
    back.text:SetText(L["Back"])
    back:SetWidth(14 + SP.xs + back.text:GetStringWidth() + 1)
    back:RegisterForClicks("LeftButtonUp")
    back:SetScript("OnClick", function() B.Back() end)
    back:SetPoint("LEFT", bar, "LEFT", SP.s, 0)
    back:Hide()
    Win.back = back
    return bar
end

local function BuildWell(f)
    local well = f.Inset
    well:ClearAllPoints()
    well:SetPoint("TOPLEFT", LO.insetLeft, -LO.insetTop)
    well:SetPoint("BOTTOMRIGHT", -LO.insetRight, LO.insetBottom)
    Vis.Chrome.ShadeInset(well, well.Bg)

    local pageWell = W.Pane(well)
    pageWell:SetPoint("TOPLEFT", LO.panePad, -LO.panePad)
    pageWell:SetPoint("BOTTOMRIGHT", -LO.panePad, LO.panePad)

    local info = C_Texture.GetAtlasInfo(S.backdrop.atlas)
    if info then
        local bd = well:CreateTexture(nil, "BACKGROUND", nil, -4)
        bd:SetAllPoints()
        bd:SetAtlas(S.backdrop.atlas, false)
        well:HookScript("OnSizeChanged", function(_, w, h) CropBackdrop(bd, info, w, h) end)
        CropBackdrop(bd, info, well:GetSize())

        local trim = CreateFrame("Frame", nil, well)
        trim:SetAllPoints()
        trim:SetFrameLevel(pageWell:GetFrameLevel() + 50)
        trim:EnableMouse(false)
        for key, c in pairs(S.filigree.corner) do
            local t = trim:CreateTexture(nil, "BORDER")
            t:SetAtlas(c.atlas, true)
            local x = c.x < 0 and math.max(c.x, -LO.insetLeft) or math.min(c.x, LO.insetRight)
            t:SetPoint(CORNER_POINT[key], well, CORNER_POINT[key], x, c.y)
        end
    else
        W.OpaquePanes(true)
    end

    local page = CreateFrame("Frame", nil, pageWell)
    page:SetPoint("TOPLEFT", LO.wellPad, -LO.wellPad)
    page:SetPoint("BOTTOMRIGHT", -LO.wellPad, LO.wellPad)
    local bar = BuildBar(page, BuildTree(page))

    local host = CreateFrame("Frame", nil, page)
    host:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -SP.xs)
    host:SetPoint("BOTTOMRIGHT", -LO.pagePad, LO.pagePad)
    Win.host = host
end

local function BuildHeader(f)
    local r, bandH = LO.rect, LO.headerBand
    local band = CreateFrame("Frame", nil, f)
    band:SetPoint("TOPLEFT", r[1], -r[2])
    band:SetPoint("TOPRIGHT", -r[3], -r[2])
    band:SetHeight(bandH)
    band:SetFrameLevel(f:GetFrameLevel() + 2)
    local fill = band:CreateTexture(nil, "BACKGROUND", nil, -6)
    fill:SetAllPoints()
    local sc = S.backdrop.scrim
    fill:SetColorTexture(sc[1], sc[2], sc[3], S.backdrop.pageAlpha)
    Vis.Chrome.Header(f, r, bandH)

    local help = CreateFrame("Button", nil, band, "UIPanelButtonTemplate")
    help:SetText(L["Help"])
    help:SetSize(help:GetTextWidth() + SP.xl, 22)
    help:SetPoint("RIGHT", -SP.m, 0)
    help:SetScript("OnClick", function() hooks.Help() end)

    local hide = CreateFrame("CheckButton", nil, band, "UICheckButtonTemplate")
    hide:SetSize(24, 24)
    hide.Text:SetFontObject("UserScaledFontGameHighlightSmall")
    hide.Text:SetText(L["Hide what doesn't apply to me"])
    hide:SetScript("OnClick", function(self) hooks.HideNA(self:GetChecked() and true or false) end)

    local search = W.NewSearchBox(band, DEFAULT_HINT, function(text)
        if not restoring then hooks.Filter(text) end
    end)
    search:SetWidth(SEARCH_W)
    search:SetPoint("RIGHT", help, "LEFT", -SP.m, 0)
    search:HookScript("OnEnterPressed", function(self) hooks.Search(self:GetText():match("^%s*(.-)%s*$")) end)
    Win.hideNA, Win.help, Win.search = hide, help, search

    local count = S.Text(band, "header", "OVERLAY")
    count:SetPoint("LEFT", LO.titleLeft - r[1], 0)
    count:SetPoint("RIGHT", hide, "LEFT", -SP.m, 0)
    count:SetJustifyH("LEFT")
    count:SetWordWrap(false)
    Win.count = count
    local hit = CreateFrame("Frame", nil, band)
    hit:SetAllPoints(count)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", function(self) ShowTruncated(self, count) end)
    hit:SetScript("OnLeave", B.HideTooltip)
end

-- The box shows the seed's search; a Go without one clears it, and a page restoring its own may set it after.
-- Neither counts as typing: the page is not asked to filter. The clear button does, because it only SetTexts.
function Win.SetSearch(text)
    restoring = true
    Win.search:SetText(text or "")
    restoring = false
end

-- A page's hint for the box; nil is the default.
function Win.SetPlaceholder(text)
    Win.search.Instructions:SetText(text or DEFAULT_HINT)
end

function Win.UpdateCount()
    local walk = B.Walk()
    Win.count:SetText(walk and L["%d of %d decor collected"]:format(walk.progress.owned, walk.progress.total)
        or L["Counting…"])
end

-- Row and bar heights follow the text size; the clamp rect keeps the portrait on screen.
function Win.Measure()
    W.ResetMeasure()
    local hide = Win.hideNA
    Win.search:SetHeight(W.TextHeight("body") + SP.s)
    hide:SetPoint("RIGHT", Win.search, "LEFT", -(hide.Text:GetStringWidth() + SP.l), 0)
    Win.frame:SetClampRectInsets(-PAD.left, 0, PAD.top, 0)
    rowH = W.TextHeight("bodyGold") + SP.s
    crumbH = W.TextHeight("body") + SP.s
    Win.bar:SetHeight(crumbH)
    Win.back:SetHeight(crumbH)
    for _, c in ipairs(crumbs) do c.btn:SetHeight(crumbH) end
    Win.back:SetWidth(14 + SP.xs + Win.back.text:GetStringWidth() + 1)
    if lastSegs then Win.SetCrumb(lastSegs) end
    ReloadNav()
    laidOutTextScale = TextSizeManager:GetScale()
end

-- Positions are kept in UIParent units: L, T = the frame's top-left corner times its scale.
local function ReadCorner(f)
    local s = f:GetScale()
    local left, top = f:GetLeft(), f:GetTop()
    if left and top then return left * s, top * s end
    local point, _, _, x, y = f:GetPoint(1)
    if point == "TOPLEFT" then return x * s, y * s + UIParent:GetHeight() end
end

local function Place(f, l, t)
    local s = f:GetScale()
    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
    l = math.max(PAD.left * s, math.min(l, pw - WIN_W * s))
    t = math.min(ph - PAD.top * s, math.max(t, WIN_H * s))
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", l / s, (t - ph) / s)
    return l, t, ph
end

local function SavedCorner()
    local pos = B.Saved() and B.Saved().position
    if type(pos) == "table" and pos[1] == "TOPLEFT" and type(pos[2]) == "number" and type(pos[3]) == "number" then
        return pos[2], pos[3] + UIParent:GetHeight()
    end
end

function Win.Fit(fromSaved)
    local f = Win.frame
    local l, t
    if fromSaved then l, t = SavedCorner() else l, t = ReadCorner(f) end
    FrameUtil.UpdateScaleForFitSpecific(f, PAD.left + WIN_W, PAD.top + WIN_H)
    if l then Place(f, l, t) end
end

function Win.OnTextScale()
    Win.Measure()
    Win.Fit()
end

function Win.CheckTextScale()
    if TextSizeManager:GetScale() ~= laidOutTextScale then Win.OnTextScale() end
end

local function DropSave(f)
    f:StopMovingOrSizing()
    local l, t = ReadCorner(f)
    if not l then return end
    local ph
    l, t, ph = Place(f, l, t)
    B.Save("position", { "TOPLEFT", l, t - ph })
end

-- No propagation change in combat: Escape closes the window and also reaches the game.
local function SetPropagate(f, on)
    if not InCombatLockdown() then f:SetPropagateKeyboardInput(on) end
end

-- Keyboard input is on only while propagation is, so the window never holds keys it cannot pass on;
-- in combat a stale false turns it off until combat ends.
function Win.AssertPropagation()
    local f = Win.frame
    if InCombatLockdown() then
        if not f:GetPropagateKeyboardInput() then f:EnableKeyboard(false) end
        return
    end
    f:SetPropagateKeyboardInput(true)
    f:EnableKeyboard(true)
end

local function FocusedSearch()
    for _, box in ipairs(searchBoxes) do
        if box:HasFocus() then return box end
    end
end

-- Escape: an open menu closes, else a focused search box lets go (its text stays), else the window closes.
-- A search box's own Escape handler usually gets there first.
local function OnKeyDown(self, key)
    if key ~= "ESCAPE" then
        SetPropagate(self, true)
        return
    end
    SetPropagate(self, false)
    local menus = Menu.GetManager()
    local box = FocusedSearch()
    if menus:IsAnyMenuOpen() then
        menus:CloseMenus()
    elseif box then
        box:ClearFocus()
    else
        hooks.Close()
    end
    C_Timer.After(0, Win.AssertPropagation)
end

local function BuildMotion(f)
    local open = f:CreateAnimationGroup()
    open:SetToFinalAlpha(true)
    local drop = open:CreateAnimation("Translation")
    drop:SetOffset(0, -TRAVEL)
    drop:SetDuration(0)
    drop:SetOrder(1)
    local rise = open:CreateAnimation("Translation")
    rise:SetOffset(0, TRAVEL)
    rise:SetDuration(OPEN_TIME)
    rise:SetOrder(2)
    local fadeIn = open:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(OPEN_TIME)
    fadeIn:SetOrder(2)
    Win.openAnim = open

    local close = f:CreateAnimationGroup()
    close:SetToFinalAlpha(true)
    local fadeOut = close:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(CLOSE_TIME)
    close:SetScript("OnFinished", function()
        f:Hide()
        f:SetAlpha(1)
    end)
    Win.closeAnim = close
end

function Win.PlayOpen()
    local f = Win.frame
    Win.closeAnim:Stop()
    Win.closing = false
    f:SetAlpha(0)
    f:Show()
    Win.openAnim:Play()
end

function Win.PlayClose()
    if Win.closing or not Win.frame:IsShown() then return end
    Win.openAnim:Stop()
    Win.closing = true
    Win.closeAnim:Play()
end

local glowing = {}
function Win.Glow(region)
    local g = region.browserGlow
    if not g then
        g = region:CreateAnimationGroup()
        local a = g:CreateAnimation("Alpha")
        a:SetFromAlpha(0.3)
        a:SetToAlpha(1)
        a:SetDuration(OPEN_TIME)
        region.browserGlow = g
    end
    glowing[region] = g
    g:Restart()
end

function Win.StopGlow()
    for region, g in pairs(glowing) do
        g:Stop()
        glowing[region] = nil
    end
end

function Win.Build(h)
    if Win.frame then return Win.frame end
    hooks = h
    local f = CreateFrame("Frame", nil, UIParent, "ButtonFrameTemplate")
    Win.frame = f
    f:Hide()
    f:SetTitle(S.plate.windowTitle)
    f:SetPortraitToAsset(S.art.portrait)
    f:SetSize(WIN_W, WIN_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)

    local grab = CreateFrame("Frame", nil, f)
    grab:SetPoint("TOPLEFT", PAD.left + LO.titleLeft - LO.rect[1], 0)
    grab:SetPoint("TOPRIGHT", -LO.titleBar - SP.xs, 0)
    grab:SetHeight(LO.titleBar)
    grab:EnableMouse(true)
    grab:RegisterForDrag("LeftButton")
    grab:SetScript("OnDragStart", function() f:StartMoving() end)
    grab:SetScript("OnDragStop", function() DropSave(f) end)

    f.CloseButton:SetScript("OnClick", function() hooks.Close() end)
    Win.AssertPropagation()
    f:SetScript("OnKeyDown", OnKeyDown)

    BuildHeader(f)
    BuildWell(f)
    BuildMotion(f)
    Win.Measure()
    Win.Fit(true)

    f:SetScript("OnShow", hooks.OnShow)
    f:SetScript("OnHide", hooks.OnHide)
    return f
end
