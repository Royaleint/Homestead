-- The browser window: frame, header band and the content well. Built on first open.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local S = B.Style
local Vis = B.Vis
local W = B.Widgets
local LO = S.layout
local SP = S.space

local Win = {}
B.Window = Win

local SEARCH_DELAY = 0.2

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

    BuildSearch(band)
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

-- The top-left corner pulled back on screen for a window of size w x h; nil, nil when it has no place yet.
function Win.ClampPosition(w, h, left, top, pw, ph)
    if not (left and top) then return nil, nil end
    return math.max(0, math.min(left, pw - w)), math.min(ph, math.max(top, h))
end

-- Pulls the window back on screen.
function Win.Clamp()
    local f = Win.frame
    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
    -- A frame not yet laid out has no edges; a restored anchor still gives its corner.
    local left, top = f:GetLeft(), f:GetTop()
    local point, _, _, x, y = f:GetPoint(1)
    if not left and point == "TOPLEFT" then left, top = x, ph + y end
    left, top = Win.ClampPosition(f:GetWidth(), f:GetHeight(), left, top, pw, ph)
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

local function IsNum(v) return type(v) == "number" end

function Win.Restore(f, s)
    local pos = s and s.position
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

    f:SetScript("OnShow", onShow)
    f:SetScript("OnHide", onHide)
    Win.frame = f
    return f
end
