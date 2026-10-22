-- Visual helpers: progress bars, frame chrome, icon greying, list edge fades and the header sheen.
local _, HA = ...

local B = HA.DecorBrowser
local S = B.Style
local M = S.material

local Vis = {}
B.Vis = Vis

-- A missing value means on.
function Vis.AnimationsOn()
    local s = B.Saved()
    return not (s and s.animations == false)
end

local Bar = {}
Vis.Bar = Bar

function Bar.Color(ratio)
    for _, tier in ipairs(S.progress) do
        if ratio < tier.upTo then return tier.color end
    end
    return S.progress.complete
end

-- The engine moves the fill. A hidden bar does not ease: animate only while visible.
function Bar.Set(bar, value, animate)
    local mode = _G.Enum and _G.Enum.StatusBarInterpolation
    if mode and animate and Vis.AnimationsOn() then
        bar:SetValue(value, mode.ExponentialEaseOut)
    else
        bar:SetValue(value, mode and mode.Immediate)
        bar:SetToTargetValue()
    end
end

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

local EdgeFade = {}
Vis.EdgeFade = EdgeFade

local function updateFades(fade)
    local box = fade.box
    if not box:HasScrollableExtent() then
        fade.top:SetAlpha(0)
        fade.bottom:SetAlpha(0)
        return
    end
    local range = box:GetDerivedScrollRange()
    local offset = box:GetDerivedScrollOffset()
    local above = box:IsAtBegin() and 0 or offset
    local below = box:IsAtEnd() and 0 or (range - offset)
    fade.top:SetAlpha(math.min(1, math.max(0, above / fade.ramp)))
    fade.bottom:SetAlpha(math.min(1, math.max(0, below / fade.ramp)))
end

-- SetGradient ignores texture alpha, so each gradient sits in its own frame.
local function gradientFrame(parent, point, bottomAlpha, topAlpha)
    local length, c = S.backdrop.edgeLength, S.backdrop.scrim
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint(point .. "LEFT")
    f:SetPoint(point .. "RIGHT")
    PixelUtil.SetHeight(f, length)
    local tex = f:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetGradient("VERTICAL", CreateColor(c[1], c[2], c[3], bottomAlpha),
        CreateColor(c[1], c[2], c[3], topAlpha))
    f:SetAlpha(0)
    return f
end

function EdgeFade.Attach(box)
    local fade = { box = box, ramp = S.backdrop.edgeLength }
    if box.Shadows then box.Shadows:Hide() end

    local fx = CreateFrame("Frame", nil, box:GetParent())
    fx:SetPoint("TOPLEFT", box, "TOPLEFT")
    fx:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT")
    fx:SetFrameLevel(box:GetFrameLevel() + 10)
    fx:SetShown(box:IsShown())
    box:HookScript("OnShow", function() fx:Show() end)
    box:HookScript("OnHide", function() fx:Hide() end)

    local peak = S.backdrop.edgeAlpha
    fade.top = gradientFrame(fx, "TOP", 0, peak)
    fade.bottom = gradientFrame(fx, "BOTTOM", peak, 0)

    local function refresh() updateFades(fade) end
    box:RegisterCallback(BaseScrollBoxEvents.OnScroll, refresh, fade)
    box:RegisterCallback(BaseScrollBoxEvents.OnSizeChanged, refresh, fade)
    box:RegisterCallback(BaseScrollBoxEvents.OnLayout, refresh, fade)
    fade.Refresh = refresh
    return fade
end

local Sheen = {}
Vis.Sheen = Sheen

-- plate is the frame the layers draw on; opts = { width, height, drawLayer, subLevel }.
function Sheen.Create(plate, opts)
    local edge = S.plate.edge
    local w, h = opts.width - 2 * edge, opts.height - 2 * edge
    local layers = {}
    for i, def in ipairs(S.plate.sheenLayers) do
        -- Scaling the v span against the region's aspect sets the band angle.
        local vSpan = def.uSpan * def.slope * h / w
        local tex = plate:CreateTexture(nil, opts.drawLayer, nil, opts.subLevel + i)
        tex:SetPoint("TOPLEFT", plate, "TOPLEFT", edge, -edge)
        tex:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", -edge, edge)
        tex:SetTexture(S.art.sheenStrip, "REPEAT", "REPEAT")
        tex:SetBlendMode("ADD")
        tex:SetVertexColor(def.tone[1], def.tone[2], def.tone[3])
        tex:SetAlpha(def.alpha)
        tex:SetTexCoord(0, def.uSpan, def.flip and vSpan or 0, def.flip and 0 or vSpan)
        tex:Hide()
        local ok, group = pcall(tex.CreateAnimationGroup, tex, nil, def.template)
        local scroll = ok and group:GetAnimations()
        if scroll and scroll.GetOffset then
            layers[#layers + 1] = { tex = tex, group = group }
        end
    end

    local sheen = {}

    function sheen:Play()
        if not Vis.AnimationsOn() then return self:Stop() end
        for _, layer in ipairs(layers) do
            layer.tex:Show()
            if not layer.group:IsPlaying() then layer.group:Play() end
        end
    end

    function sheen:Stop()
        for _, layer in ipairs(layers) do
            layer.group:Stop()
            layer.tex:Hide()
        end
    end

    return sheen
end
