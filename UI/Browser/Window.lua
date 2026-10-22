-- The browser window: frame, header band, side tabs, scale-to-fit, Escape and motion. Built on first open.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local S = B.Style
local Vis = B.Vis
local W = B.Widgets
local LO = S.layout
local SP = S.space
local TAB = S.tab
local PAD = S.pad
local WIN_W, WIN_H = S.window.width, S.window.height

local Win = {}
B.Window = Win

local OPEN_TIME, CLOSE_TIME, TRAVEL = 0.15, 0.1, 8

local TABS = {
    { key = "summary", word = L["Summary"], on = "housing-icon-dashboard", off = "housing-icon-dashboard-dis" },
    { key = "catalog", word = L["Catalog"], on = "housing-icon-catalog", off = "housing-icon-catalog-dis" },
    { key = "sources", word = L["Sources"], on = S.atlas.waypointOn, off = S.atlas.waypointOff },
}
Win.TABS = TABS

local hooks
local tabWidth = TAB.minWidth
local laidOutTextScale
local searchBoxes = {}

function Win.TabWidth()
    return tabWidth
end

-- Search boxes a tab owns; Escape takes focus from them before it closes the window.
function Win.AddSearchBox(box)
    searchBoxes[#searchBoxes + 1] = box
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

        -- Above the pane, mouse-transparent.
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

    local host = CreateFrame("Frame", nil, page)
    host:SetPoint("TOPLEFT", LO.pagePad, -LO.pagePad)
    host:SetPoint("BOTTOMRIGHT", -LO.pagePad, LO.pagePad)
    Win.host = host
end

-- Header band: where you are on the left; the Hide toggle and Help on the right.
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
    Win.hideNA, Win.help = hide, help

    local where = band:CreateFontString(nil, "OVERLAY", "UserScaledFontGameNormal")
    where:SetPoint("LEFT", LO.titleLeft - r[1], 0)
    where:SetPoint("RIGHT", hide, "LEFT", -SP.m, 0)
    where:SetJustifyH("LEFT")
    where:SetWordWrap(false)
    Win.location = where
end

function Win.SetLocation(text)
    Win.location:SetText(text or "")
end

local function BuildTabs(f)
    local prev
    for _, t in ipairs(TABS) do
        local tab = CreateFrame("Frame", nil, f, "LargeSideTabButtonTemplate")
        tab.activeAtlas, tab.inactiveAtlas = t.on, t.off
        if prev then
            tab:SetPoint("TOP", prev, "BOTTOM", 0, -TAB.gap)
        else
            tab:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, -TAB.top)
        end
        tab.Icon:ClearAllPoints()
        tab.Icon:SetPoint("TOP", 0, -SP.s)
        tab.word = tab:CreateFontString(nil, "OVERLAY", "UserScaledFontGameHighlightSmall")
        tab.word:SetPoint("TOP", tab.Icon, "BOTTOM", 0, -SP.xs)
        tab.word:SetText(t.word)
        -- The word is on the tab; no tooltip repeats it (the template's would use the shared one).
        tab:SetScript("OnEnter", nil)
        tab:SetScript("OnLeave", nil)
        local key = t.key
        tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
            if button == "LeftButton" and upInside then hooks.SelectTab(key) end
        end)
        tab:SetChecked(false)
        t.frame = tab
        prev = tab
    end
end

function Win.SetSelectedTab(key)
    for _, t in ipairs(TABS) do t.frame:SetChecked(t.key == key) end
end

-- Width and height of the tabs from their measured words; the clamp rect grows to keep them on screen.
function Win.MeasureTabs()
    local widest, tall = 0, 0
    for _, t in ipairs(TABS) do
        widest = math.max(widest, t.frame.word:GetUnboundedStringWidth())
        tall = math.max(tall, t.frame.word:GetStringHeight())
    end
    tabWidth = math.max(TAB.minWidth, widest + TAB.wordPad)
    for _, t in ipairs(TABS) do t.frame:SetSize(tabWidth, TAB.height + tall) end
    local hide = Win.hideNA
    hide:SetPoint("RIGHT", Win.help, "LEFT", -(hide.Text:GetStringWidth() + SP.l), 0)
    Win.frame:SetClampRectInsets(-PAD.left, tabWidth, PAD.top, 0)
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

-- Clamps the corner on screen (portrait and tabs included), anchors it and returns it.
local function Place(f, l, t)
    local s = f:GetScale()
    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
    l = math.max(PAD.left * s, math.min(l, pw - (WIN_W + tabWidth) * s))
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

-- Read, fit, re-anchor, clamp. Never saves: only a drop does.
function Win.Fit(fromSaved)
    local f = Win.frame
    local l, t
    if fromSaved then l, t = SavedCorner() else l, t = ReadCorner(f) end
    FrameUtil.UpdateScaleForFitSpecific(f, PAD.left + WIN_W + tabWidth, PAD.top + WIN_H)
    if l then Place(f, l, t) end
end

-- A text-size change re-measures the tabs, then fits.
function Win.OnTextScale()
    Win.MeasureTabs()
    Win.Fit()
end

-- The text size can change while the window is hidden and not listening.
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

-- Shows the window and fades it in; a close still fading is cancelled.
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

-- One short glow on a region, never looping; Hide stops it.
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

-- h = { OnShow, OnHide, Close, Help, HideNA(on), SelectTab(key) }.
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

    -- Dragged by the title bar only.
    local grab = CreateFrame("Frame", nil, f)
    grab:SetPoint("TOPLEFT", PAD.left + LO.titleLeft - LO.rect[1], 0)
    grab:SetPoint("TOPRIGHT", -LO.titleBar - SP.xs, 0)
    grab:SetHeight(LO.titleBar)
    grab:EnableMouse(true)
    grab:RegisterForDrag("LeftButton")
    grab:SetScript("OnDragStart", function() f:StartMoving() end)
    grab:SetScript("OnDragStop", function() DropSave(f) end)

    -- A plain close; the template's own path goes through the panel manager.
    f.CloseButton:SetScript("OnClick", function() hooks.Close() end)
    Win.AssertPropagation()
    f:SetScript("OnKeyDown", OnKeyDown)

    BuildHeader(f)
    BuildWell(f)
    BuildTabs(f)
    BuildMotion(f)
    Win.MeasureTabs()
    Win.Fit(true)

    f:SetScript("OnShow", hooks.OnShow)
    f:SetScript("OnHide", hooks.OnHide)
    return f
end
