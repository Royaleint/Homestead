-- Visual helpers: frame chrome and icon greying.
local _, HA = ...

local B = HA.DecorBrowser
local S = B.Style
local M = S.material

local Vis = {}
B.Vis = Vis

local Chrome = {}
Vis.Chrome = Chrome

function Chrome.VGradient(tex, tone, bottomAlpha, topAlpha)
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetGradient("VERTICAL", CreateColor(tone[1], tone[2], tone[3], bottomAlpha),
        CreateColor(tone[1], tone[2], tone[3], topAlpha))
end

function Chrome.ShadeInset(well, bg)
    local c = S.chrome
    if bg then bg:SetVertexColor(c.wellShade, c.wellShade, c.wellShade) end
    local dim = well:CreateTexture(nil, "BACKGROUND", nil, -3)
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, 0.25)
    local shadow = well:CreateTexture(nil, "BACKGROUND", nil, -2)
    shadow:SetPoint("TOPLEFT")
    shadow:SetPoint("TOPRIGHT")
    PixelUtil.SetHeight(shadow, c.wellShadowHeight)
    Chrome.VGradient(shadow, M.shadow, 0, 0.45)
end

function Chrome.Inset(parent)
    local well = CreateFrame("Frame", nil, parent)
    local bg = well:CreateTexture(nil, "BACKGROUND", nil, -5)
    bg:SetTexture(S.tex.marble, "REPEAT", "REPEAT")
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    bg:SetAllPoints()
    Chrome.ShadeInset(well, bg)
    NineSliceUtil.ApplyLayoutByName(well, "InsetFrameTemplate")
    return well
end

function Chrome.Hairline(frame, tone, alpha, layer)
    for i, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = frame:CreateTexture(nil, layer or "BORDER")
        t:SetColorTexture(tone[1], tone[2], tone[3], alpha)
        if i <= 2 then
            t:SetPoint(edge .. "LEFT")
            t:SetPoint(edge .. "RIGHT")
            PixelUtil.SetHeight(t, 1, 1)
        else
            t:SetPoint("TOP" .. edge)
            t:SetPoint("BOTTOM" .. edge)
            PixelUtil.SetWidth(t, 1, 1)
        end
    end
end

function Chrome.Header(frame, rect, height)
    local c, f = S.chrome, S.filigree
    local bottom = rect[2] + height
    local line = frame:CreateTexture(nil, "BORDER", nil, 1)
    line:SetAtlas(f.divider, true)
    line:SetAlpha(f.dividerAlpha)
    line:SetPoint("LEFT", frame, "TOPLEFT", rect[1] + c.linePad, -bottom)
    line:SetPoint("RIGHT", frame, "TOPRIGHT", -rect[3] - c.linePad, -bottom)
    local shadow = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    shadow:SetPoint("TOPLEFT", frame, "TOPLEFT", rect[1], -bottom)
    shadow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -rect[3], -bottom)
    PixelUtil.SetHeight(shadow, c.shadowHeight)
    Chrome.VGradient(shadow, M.shadow, 0, 0.30)
    return { line = line, shadow = shadow }
end

local Desaturate = {}
Vis.Desaturate = Desaturate

-- What greys lives under unit.art; unit.over holds badges and hover, so rims and the lock keep colour.
function Desaturate.Create(parent, lockSize, lockPoint)
    local art = CreateFrame("Frame", nil, parent)
    local over = CreateFrame("Frame", nil, parent)
    over:SetAllPoints(art)
    over:SetFrameLevel(art:GetFrameLevel() + 2)

    local a = S.atlas
    local lock = over:CreateTexture(nil, "OVERLAY")
    lock:SetAtlas(C_Texture.GetAtlasInfo(a.lockBadge) and a.lockBadge or a.lockBadgeFallback)
    lock:SetSize(lockSize, lockSize)
    lock:SetPoint(lockPoint[1], art, lockPoint[1], lockPoint[2], lockPoint[3])
    lock:Hide()
    return { art = art, over = over, lock = lock }
end

function Desaturate.Set(unit, grey, badge)
    unit.art:DesaturateHierarchy(grey and 1.0 or 0)
    unit.lock:SetShown(badge and true or false)
end
