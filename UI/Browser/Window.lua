-- The browser window: frame, header band, navigation column, Back control and breadcrumb. Built on first open.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local S = B.Style
local Vis = B.Vis
local W = B.Widgets
local LO = S.layout
local K = S.color
local SP = S.space

local Win = {}
B.Window = Win

local SEARCH_DELAY = 0.2

local NAV = {
    { key = "overview", label = L["Overview"], route = { page = "overview" } },
    { key = "nearyou", label = L["Near You"], route = { page = "shops", nearYou = true } },
    { key = "vendors", label = L["Vendors"] },
    { key = "achievements", label = L["Achievements"], route = { page = "sources", source = "achievements" } },
    { key = "quests", label = L["Quests"], route = { page = "sources", source = "quests" } },
    { key = "professions", label = L["Professions"], route = { page = "sources", source = "professions" } },
    { key = "drops", label = L["Drops"], route = { page = "sources", source = "drops" } },
    { key = "events", label = L["Events"], route = { page = "sources", source = "events" } },
}
local NAV_LABEL = {}
for _, c in ipairs(NAV) do NAV_LABEL[c.key] = c.label end

local navList
local selectedKey = "overview"
local expanded = false

function Win.NavLabel(key)
    return NAV_LABEL[key]
end

local function ExpansionRoute(exp)
    return { page = "shops", expansion = exp, nav = "vendors:" .. exp }
end

function Win.FirstExpansionRoute()
    local first = B.Data.Expansions()[1]
    return first and ExpansionRoute(first) or nil
end

local function NavData()
    local data = {}
    for _, c in ipairs(NAV) do
        data[#data + 1] = { kind = "cat", key = c.key, label = c.label, level = 1, cat = c }
        if c.key == "vendors" and expanded then
            for _, exp in ipairs(B.Data.Expansions()) do
                data[#data + 1] = { kind = "cat", key = "vendors:" .. exp, level = 2, expansion = exp,
                    label = B.Data.ExpansionLabel(exp) }
            end
        end
    end
    return data
end

local function ReloadNav(keepPosition)
    navList:SetData(NavData(), keepPosition)
end

local function NavClick(d)
    if d.level == 2 then
        B.Go(ExpansionRoute(d.expansion))
    elseif d.key == "vendors" then
        expanded = not expanded
        local route = expanded and Win.FirstExpansionRoute()
        if route then
            B.Go(route)
        else
            ReloadNav(true)
        end
    else
        local route = { nav = d.key }
        for k, v in pairs(d.cat.route) do route[k] = v end
        B.Go(route)
    end
end

local function BuildNavRow(f)
    local hl = f:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(unpack(K.hoverRow))
    f.hl = hl
    local sel = f:CreateTexture(nil, "BACKGROUND")
    Vis.Chrome.VGradient(sel, S.material.gilt, 0.04, 0.22)
    f.sel = sel
    local bar = f:CreateTexture(nil, "ARTWORK")
    local g = S.material.gilt
    bar:SetColorTexture(g[1], g[2], g[3], 1)
    PixelUtil.SetWidth(bar, 3, 1)
    f.bar = bar
    f.label = S.Text(f, "bodyGold", "OVERLAY")
    f.label:SetJustifyH("LEFT")
    f.label:SetWordWrap(false)
    f:RegisterForClicks("LeftButtonUp")
    f:SetScript("OnClick", function(self)
        if self.data then NavClick(self.data) end
    end)
    f:SetScript("OnEnter", function(self)
        if not self.fullName then return end
        local tip = B.Tooltip()
        tip:SetOwner(self, "ANCHOR_RIGHT")
        tip:SetText(self.fullName)
        tip:Show()
    end)
    f:SetScript("OnLeave", function() B.HideTooltip() end)
end

-- The box width, or the column's design width while it is unmeasured (built hidden).
local function NavRowWidth()
    local w = navList.box:GetWidth()
    if not w or w < 50 then w = LO.catWidth - 2 * (LO.wellPad + 2) - LO.scrollBarGap end
    return w
end

local function InitNavRow(f, d)
    f.data = d
    local sub = d.level == 2
    local indent = sub and LO.navSubIndent or 0
    for _, region in ipairs({ f.hl, f.sel }) do
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", indent, 0)
        region:SetPoint("BOTTOMRIGHT")
    end
    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPLEFT", indent, 0)
    f.bar:SetPoint("BOTTOMLEFT", indent, 0)
    f.label:ClearAllPoints()
    f.label:SetPoint("LEFT", indent + SP.m, 0)
    f.label:SetPoint("RIGHT", -SP.s, 0)
    local isSel = d.key == selectedKey
    f.sel:SetShown(isSel)
    f.bar:SetShown(isSel)
    local role = "bodyGold"
    if sub then role = isSel and "metaGold" or "meta" end
    f.label:SetFontObject(_G[S.font[role]])
    f.label:SetText(d.label)
    f.fullName = nil
    if sub then
        local avail = NavRowWidth() - indent - SP.m - SP.s
        if f.label:GetStringWidth() > avail then
            local short = S.expansionShort[d.expansion]
            if short then f.label:SetText(short) end
            f.fullName = d.label
        end
    end
end

local function BuildNav(holder)
    navList = W.NewList(holder, {
        spacing = LO.navGap,
        reclaim = true,
        extent = function(d) return d.level == 2 and LO.navSubHeight or LO.navRowHeight end,
        kinds = { cat = { frameType = "Button", build = BuildNavRow, init = InitNavRow } },
    })
    -- A scrollbar change alters the row width, and so which names fit.
    navList.box:RegisterCallback(BaseScrollBoxEvents.OnSizeChanged, function()
        navList.box:ForEachFrame(function(f)
            if f.data then InitNavRow(f, f.data) end
        end)
    end, navList)
    ReloadNav(false)
end

-- navKey is "overview", "nearyou", "vendors:<expansion>", "achievements", ...
function Win.SelectNav(navKey)
    selectedKey = navKey or "overview"
    if selectedKey:find("^vendors:") then expanded = true end
    ReloadNav(true)
end

local searchTimer, suppressSearch

function Win.CancelSearch()
    if searchTimer then
        searchTimer:Cancel()
        searchTimer = nil
    end
end

function Win.ResetSearch(enabled)
    Win.CancelSearch()
    local box = Win.search
    suppressSearch = true
    box:SetText("")
    suppressSearch = false
    box:ClearFocus()
    box:SetEnabled(enabled)
    box:SetAlpha(enabled and 1 or 0.5)
    Win.searchBlock:SetShown(not enabled)
end

function Win.SetHideOwnedChecked(on)
    Win.hideOwned:SetChecked(on)
end

local function BuildSearch(band)
    local box = CreateFrame("EditBox", nil, band, "SearchBoxTemplate")
    box:SetSize(160, 22)
    box:SetPoint("RIGHT", -SP.m, 0)
    box:HookScript("OnTextChanged", function(self)
        if suppressSearch then return end
        Win.CancelSearch()
        local text = (self:GetText() or ""):lower()
        if text == B.State.search then return end
        searchTimer = C_Timer.NewTimer(SEARCH_DELAY, function()
            searchTimer = nil
            if Win.frame:IsShown() then B.SetSearch(text) end
        end)
    end)
    Win.search = box

    -- A disabled edit box gets no mouse-over; a cover carries the reason.
    local block = CreateFrame("Frame", nil, band)
    block:SetAllPoints(box)
    block:SetFrameLevel(box:GetFrameLevel() + 5)
    block:EnableMouse(true)
    block:SetScript("OnEnter", function(self)
        local tip = B.Tooltip()
        tip:SetOwner(self, "ANCHOR_BOTTOM")
        tip:SetText(L["Open a list to search"])
        tip:Show()
    end)
    block:SetScript("OnLeave", function() B.HideTooltip() end)
    Win.searchBlock = block
    return box
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

    local title = S.Text(band, "title", "OVERLAY")
    title:SetPoint("LEFT", band, "LEFT", LO.titleLeft - r[1], 0)
    title:SetText(S.plate.title)

    local search = BuildSearch(band)

    local hide = CreateFrame("CheckButton", nil, band, "UICheckButtonTemplate")
    hide:SetSize(24, 24)
    hide.Text:SetFontObject(_G[S.font.body])
    hide.Text:SetText(L["Hide owned"])
    hide:SetPoint("RIGHT", search, "LEFT", -(hide.Text:GetStringWidth() + SP.l), 0)
    hide:SetScript("OnClick", function(self)
        B.SetHideOwned(self:GetChecked() and true or false)
    end)
    Win.hideOwned = hide

    local progress = S.Text(band, "body", "OVERLAY")
    progress:SetPoint("RIGHT", hide, "LEFT", -SP.l, 0)
    progress:SetJustifyH("RIGHT")
    Win.progress = progress

    Win.sheen = Vis.Sheen.Create(band, {
        width = S.window.width - r[1] - r[3], height = bandH,
        drawLayer = "BORDER", subLevel = -1,
    })
end

function Win.UpdateProgress()
    local prog = B.Data.Progress()
    if not prog then
        Win.progress:SetText("")
        return
    end
    local owned = prog.known and BreakUpLargeNumbers(prog.owned) or "?"
    Win.progress:SetText(L["%s of %s decor collected"]:format(owned, BreakUpLargeNumbers(prog.total)))
end

local CRUMB_MAX = 5
local CRUMB_SEP = " \226\128\186 "
local crumbs = {}

local function RouteLabel(route)
    if route.label then return route.label end
    if route.page == "shop" then
        local v = route.npcID and B.Data.Vendor(route.npcID)
        return v and v.name or "?"
    elseif route.page == "item" and route.itemID then
        return B.Data.ItemName(route.itemID) or L["Item %d"]:format(route.itemID)
    end
    return NAV_LABEL[route.nav] or "?"
end

-- The path walked: from the latest top-level page in history through every page since.
local function CrumbSegments(route)
    local chain = {}
    for _, r in ipairs(B.State.history) do chain[#chain + 1] = r end
    chain[#chain + 1] = route
    local root = 1
    for i = #chain, 1, -1 do
        if B.IsTopLevel(chain[i]) then
            root = i
            break
        end
    end
    local segs = {}
    local r = chain[root]
    if r.page == "shops" and r.expansion then
        segs[1] = { label = L["Vendors"], idx = root, route = Win.FirstExpansionRoute() }
        segs[2] = { label = B.Data.ExpansionLabel(r.expansion), idx = root }
    else
        segs[1] = { label = RouteLabel(r), idx = root }
    end
    for i = root + 1, #chain do
        segs[#segs + 1] = { label = RouteLabel(chain[i]), idx = i }
    end
    if #segs > CRUMB_MAX then
        local kept = { { label = "...", gap = true } }
        for i = #segs - CRUMB_MAX + 2, #segs do kept[#kept + 1] = segs[i] end
        segs = kept
    end
    return segs
end

local function NewCrumb(tb)
    local c = {}
    c.btn = CreateFrame("Button", nil, tb)
    c.btn:SetHeight(20)
    c.text = S.Text(c.btn, "body", "OVERLAY")
    c.text:SetPoint("LEFT")
    c.text:SetPoint("RIGHT")
    c.text:SetJustifyH("LEFT")
    c.text:SetWordWrap(false)
    c.sep = S.Text(tb, "body", "OVERLAY")
    c.sep:SetTextColor(K.muted[1], K.muted[2], K.muted[3])
    c.sep:SetText(CRUMB_SEP)
    c.btn:SetScript("OnEnter", function(self)
        if self.seg then c.text:SetTextColor(K.body[1], K.body[2], K.body[3]) end
    end)
    c.btn:SetScript("OnLeave", function(self)
        if self.seg then c.text:SetTextColor(K.muted[1], K.muted[2], K.muted[3]) end
    end)
    c.btn:SetScript("OnClick", function(self)
        if self.seg then B.GoCrumb(self.seg.idx, self.seg.route) end
    end)
    return c
end

local function BuildBack(tb)
    local b = CreateFrame("Button", nil, tb)
    b:SetHeight(20)
    b.arrow = b:CreateTexture(nil, "ARTWORK")
    b.arrow:SetAtlas(S.atlas.backArrow)
    b.arrow:SetSize(14, 14)
    b.arrow:SetPoint("LEFT")
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAtlas(S.atlas.backArrow)
    hover:SetAllPoints(b.arrow)
    hover:SetBlendMode("ADD")
    hover:SetAlpha(0.5)
    b.text = S.Text(b, "bodyGold", "OVERLAY")
    b.text:SetPoint("LEFT", b.arrow, "RIGHT", SP.xs, 0)
    b.text:SetText(L["Back"])
    b:SetWidth(14 + SP.xs + b.text:GetStringWidth() + 1)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function() B.Back() end)
    b:SetPoint("LEFT", tb, "LEFT", SP.s, 0)
    b:Hide()
    return b
end

-- Back shows with history. Top-level pages show no path but keep the row height. Earlier segments are
-- muted links, the last inert; a pooled crumb is fully restyled.
function Win.UpdateCrumbs(route)
    local tb, back = Win.toolbar, Win.back
    local hasBack = #B.State.history > 0
    back:SetShown(hasBack)
    local segs = B.IsTopLevel(route) and {} or CrumbSegments(route)
    local prev
    for i, seg in ipairs(segs) do
        local c = crumbs[i] or NewCrumb(tb)
        crumbs[i] = c
        local last = i == #segs
        local link = not last and not seg.gap
        c.btn.seg = link and seg or nil
        c.btn:EnableMouse(link)
        c.text:SetText(seg.label)
        local col = last and K.body or K.muted
        c.text:SetTextColor(col[1], col[2], col[3])
        c.btn:ClearAllPoints()
        if prev then
            c.btn:SetPoint("LEFT", prev.sep, "RIGHT", 0, 0)
        elseif hasBack then
            c.btn:SetPoint("LEFT", back, "RIGHT", SP.m, 0)
        else
            c.btn:SetPoint("LEFT", tb, "LEFT", SP.s, 0)
        end
        if last then
            c.btn:SetWidth(0)
            c.btn:SetPoint("RIGHT", tb, "RIGHT", -SP.m, 0)
        else
            c.btn:SetWidth(c.text:GetStringWidth() + 1)
            c.sep:ClearAllPoints()
            c.sep:SetPoint("LEFT", c.btn, "RIGHT", 0, 0)
        end
        c.btn:Show()
        c.sep:SetShown(not last)
        prev = c
    end
    for i = #segs + 1, #crumbs do
        crumbs[i].btn:Hide()
        crumbs[i].sep:Hide()
    end
end

local function BuildToolbar(page)
    local tb = CreateFrame("Frame", nil, page)
    tb:SetPoint("TOPLEFT")
    tb:SetPoint("TOPRIGHT")
    tb:SetHeight(LO.toolbarHeight)
    Win.toolbar = tb
    Win.back = BuildBack(tb)
    local rule = W.Rule(tb)
    rule:SetPoint("LEFT", tb, "BOTTOMLEFT", SP.s, 0)
    rule:SetPoint("RIGHT", tb, "BOTTOMRIGHT", -SP.s, 0)
end

-- Aspect-correct cover crop in the atlas's texcoords; run after SetAtlas and on resize.
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

local function BuildWell(f)
    local well = f.Inset
    well:ClearAllPoints()
    well:SetPoint("TOPLEFT", LO.insetLeft, -LO.insetTop)
    well:SetPoint("BOTTOMRIGHT", -LO.insetRight, LO.insetBottom)
    Vis.Chrome.ShadeInset(well, well.Bg)

    local nav = W.Pane(well, "nav")
    nav:SetPoint("TOPLEFT", LO.panePad, -LO.panePad)
    nav:SetPoint("BOTTOMLEFT", LO.panePad, LO.panePad)
    nav:SetWidth(LO.catWidth)
    local navHolder = CreateFrame("Frame", nil, nav)
    navHolder:SetPoint("TOPLEFT", LO.wellPad + 2, -(LO.wellPad + 2))
    navHolder:SetPoint("BOTTOMRIGHT", -(LO.wellPad + 2), LO.wellPad + 2)

    local pageWell = W.Pane(well, "page")
    pageWell:SetPoint("TOPLEFT", nav, "TOPRIGHT", LO.columnGap, 0)
    pageWell:SetPoint("BOTTOMRIGHT", -LO.panePad, LO.panePad)

    local info = C_Texture.GetAtlasInfo(S.backdrop.atlas)
    if info then
        navHolder:SetPoint("TOPLEFT", LO.wellPad + 2, -(LO.wellPad + 2 + LO.navTopNudge))
        local bd = well:CreateTexture(nil, "BACKGROUND", nil, -4)
        bd:SetAllPoints()
        bd:SetAtlas(S.backdrop.atlas, false)
        well:HookScript("OnSizeChanged", function(_, w, h) CropBackdrop(bd, info, w, h) end)
        CropBackdrop(bd, info, well:GetSize())

        -- Above both panes, mouse-transparent.
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

        local div = well:CreateTexture(nil, "ARTWORK")
        local dc = S.backdrop.divider
        div:SetColorTexture(dc[1], dc[2], dc[3], dc[4])
        div:SetWidth(1)
        div:SetPoint("TOP", nav, "TOPRIGHT", LO.columnGap / 2, 0)
        div:SetPoint("BOTTOM", nav, "BOTTOMRIGHT", LO.columnGap / 2, 0)
    else
        W.OpaquePanes(true)
    end

    local page = CreateFrame("Frame", nil, pageWell)
    page:SetPoint("TOPLEFT", LO.wellPad, -LO.wellPad)
    page:SetPoint("BOTTOMRIGHT", -LO.wellPad, LO.wellPad)
    BuildToolbar(page)

    local host = CreateFrame("Frame", nil, page)
    host:SetPoint("TOPLEFT", LO.pagePad, -(LO.toolbarHeight + SP.s))
    host:SetPoint("BOTTOMRIGHT", -LO.pagePad, LO.pagePad)
    Win.host = host
    BuildNav(navHolder)
end

function Win.HostWidth(w)
    w = w or Win.frame:GetWidth()
    return w - LO.insetLeft - LO.insetRight - 2 * LO.panePad - LO.catWidth - LO.columnGap
        - 2 * LO.wellPad - 2 * LO.pagePad
end

-- No propagation change in combat: Escape closes the window and also reaches the game.
local function SetPropagate(f, on)
    if not InCombatLockdown() then f:SetPropagateKeyboardInput(on) end
end

-- Keyboard input is on only while propagation is, so the window never holds keys it cannot pass on;
-- in combat a stale false turns it off until combat ends.
local function AssertKeys(f)
    if InCombatLockdown() then
        if not f:GetPropagateKeyboardInput() then f:EnableKeyboard(false) end
        return
    end
    f:SetPropagateKeyboardInput(true)
    f:EnableKeyboard(true)
end

function Win.AssertPropagation()
    AssertKeys(Win.frame)
end

local function EnableEscapeClose(f)
    AssertKeys(f)
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            SetPropagate(self, false)
            self:Hide()
            C_Timer.After(0, Win.AssertPropagation)
        else
            SetPropagate(self, true)
        end
    end)
end

function Win.ClampRect(w, h, left, top, pw, ph, minW, minH)
    w = math.max(minW, math.min(w, pw))
    h = math.max(minH, math.min(h, ph))
    if left and top then
        left = math.max(0, math.min(left, pw - w))
        top = math.min(ph, math.max(top, h))
    end
    return w, h, left, top
end

-- Minimum 930 x 620 (or the screen), maximum the screen; pulls size and position back on screen.
function Win.Clamp()
    local f, grip = Win.frame, Win.grip
    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
    local minW, minH = math.min(S.window.width, pw), math.min(S.window.height, ph)
    f:SetResizeBounds(minW, minH, pw, ph)
    grip:SetMinWidth(minW)
    grip:SetMinHeight(minH)
    grip:SetMaxWidth(pw)
    grip:SetMaxHeight(ph)
    -- A frame not yet laid out has no edges; a restored anchor still gives its corner.
    local left, top = f:GetLeft(), f:GetTop()
    local point, _, _, x, y = f:GetPoint(1)
    if not left and point == "TOPLEFT" then left, top = x, ph + y end
    local w, h
    w, h, left, top = Win.ClampRect(f:GetWidth(), f:GetHeight(), left, top, pw, ph, minW, minH)
    f:SetSize(w, h)
    if left then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, top - ph)
    end
end

-- Saved as the top-left corner's offset from the screen's top-left: { "TOPLEFT", x, y }.
function Win.SavePosition()
    local left, top = Win.frame:GetLeft(), Win.frame:GetTop()
    if left and top then B.Save("position", { "TOPLEFT", left, top - UIParent:GetHeight() }) end
end

function Win.SaveSize()
    B.Save("size", { Win.frame:GetWidth(), Win.frame:GetHeight() })
    Win.SavePosition()
end

local function IsNum(v) return type(v) == "number" end

function Win.Restore(f, s)
    local size, pos = s and s.size, s and s.position
    if type(size) == "table" and IsNum(size[1]) and IsNum(size[2]) then f:SetSize(size[1], size[2]) end
    if type(pos) == "table" and pos[1] == "TOPLEFT" and IsNum(pos[2]) and IsNum(pos[3]) then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", pos[2], pos[3])
    end
end

function Win.Build(onShow, onHide)
    if Win.frame then return Win.frame end
    local f = CreateFrame("Frame", nil, UIParent, "ButtonFrameTemplate")
    f:Hide()
    f:SetTitle(S.plate.windowTitle)
    f:SetPortraitToAsset(S.art.portrait)
    f:SetSize(S.window.width, S.window.height)
    f:SetPoint("CENTER")
    Win.Restore(f, B.Saved())
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Win.SavePosition()
    end)
    -- A plain hide; the template's own close path goes through the panel manager.
    f.CloseButton:SetScript("OnClick", function() f:Hide() end)
    EnableEscapeClose(f)

    BuildHeader(f)
    BuildWell(f)

    local grip = CreateFrame("Button", nil, f, "PanelResizeButtonTemplate")
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(f:GetFrameLevel() + 60)
    grip:Init(f, S.window.width, S.window.height)
    grip:SetOnResizeStoppedCallback(Win.SaveSize)
    Win.grip = grip

    f:SetScript("OnShow", onShow)
    f:SetScript("OnHide", onHide)
    Win.frame = f
    return f
end
