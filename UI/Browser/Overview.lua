-- Overview: the latest decor you collected as toast cards, then collection progress.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local S = B.Style
local W = B.Widgets
local K = S.color
local SP = S.space

local Page = { topLevel = true, searchable = false }

local RECENT_ROWS = 3
local BARS = {
    { key = "vendors", label = L["Vendors"] },
    { key = "achievements", label = L["Achievements"] },
    { key = "quests", label = L["Quests"] },
    { key = "professions", label = L["Professions"] },
    { key = "drops", label = L["Drops"] },
    { key = "events", label = L["Events"] },
}

local function Noon(t)
    local d = date("*t", t)
    return time({ year = d.year, month = d.month, day = d.day, hour = 12 })
end

-- Calendar days, not 24-hour spans: today, yesterday, N days ago, then a short date.
function Page.RelativeDate(t, now)
    local days = math.floor((Noon(now or time()) - Noon(t)) / 86400 + 0.5)
    if days <= 0 then return L["today"] end
    if days == 1 then return L["yesterday"] end
    if days <= S.relativeDateDays then return L["%d days ago"]:format(days) end
    return date("%b %d", t)
end

local function BuildCard(parent)
    local T = S.toast
    local card = CreateFrame("Button", nil, parent)
    card:SetSize(T.width, T.height)
    card:RegisterForClicks("LeftButtonUp")

    local mask = card:CreateMaskTexture()
    mask:SetTexture(S.art.toastPlate, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints()
    local shadow = card:CreateTexture(nil, "BACKGROUND", nil, -8)
    shadow:SetTexture(S.art.toastShadow)
    shadow:SetSize(T.width + 2 * T.shadowPad, T.height + 2 * T.shadowPad)
    shadow:SetPoint("CENTER", 0, -SP.xs)
    shadow:SetVertexColor(0, 0, 0, 0.75)
    local base = card:CreateTexture(nil, "BACKGROUND", nil, -7)
    base:SetTexture(S.art.toastPlate)
    base:SetAllPoints()
    local sc = S.backdrop.scrim
    base:SetVertexColor(sc[1], sc[2], sc[3], S.backdrop.toastAlpha)
    local rays = card:CreateTexture(nil, "BACKGROUND", nil, -2)
    rays:SetTexture(S.art.toastRays)
    rays:AddMaskTexture(mask)
    rays:SetBlendMode("ADD")
    rays:SetVertexColor(unpack(S.material.lamp))
    rays:SetSize(T.raysSize[1], T.raysSize[2])
    rays:SetPoint("CENTER", card, "LEFT", T.iconCenter, 0)
    rays:SetAlpha(T.raysAlpha)

    local lo, hi = CreateColor(unpack(T.rim)), CreateColor(unpack(T.rimLit))
    local trim = card:CreateTexture(nil, "BORDER")
    trim:SetTexture(S.art.toastTrim)
    trim:SetAllPoints()
    trim:SetGradient("VERTICAL", lo, hi)
    local hover = card:CreateTexture(nil, "HIGHLIGHT")
    hover:SetTexture(S.art.toastPlate)
    hover:SetAllPoints()
    hover:SetBlendMode("ADD")
    hover:SetVertexColor(1, 1, 1, 0.10)

    local function round(layer, size)
        local tex = card:CreateTexture(nil, "ARTWORK", nil, layer)
        tex:SetSize(size, size)
        tex:SetPoint("CENTER", card, "LEFT", T.iconCenter, 0)
        local m = card:CreateMaskTexture()
        m:SetTexture(S.tex.circleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(tex)
        tex:AddMaskTexture(m)
        return tex
    end
    round(0, T.seat):SetColorTexture(0, 0, 0, 0.7)
    card.icon = round(1, T.icon)
    local ring = card:CreateTexture(nil, "ARTWORK", nil, 2)
    ring:SetTexture(S.art.toastRing)
    ring:SetSize(T.ring, T.ring)
    ring:SetPoint("CENTER", card, "LEFT", T.iconCenter, 0)
    ring:SetGradient("VERTICAL", lo, hi)

    local textRight = -(T.rightColumn + T.rightPad)
    local kicker = S.Text(card, "metaGold", "OVERLAY")
    kicker:SetPoint("TOPLEFT", T.textLeft, T.labelY)
    kicker:SetText(T.kicker)
    local rule = card:CreateTexture(nil, "ARTWORK")
    rule:SetAtlas(S.atlas.divider, true)
    rule:SetPoint("TOPLEFT", T.dividerLeft, T.dividerY)
    rule:SetWidth(T.width - T.dividerLeft + textRight)
    rule:SetAlpha(0.9)

    local function line(role, y)
        local fs = S.Text(card, role, "OVERLAY")
        fs:SetPoint("TOPLEFT", T.textLeft, y)
        fs:SetPoint("RIGHT", card, "RIGHT", textRight, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        return fs
    end
    card.name = line("header", T.nameY)
    card.source = line("meta", T.sourceY)
    card.source:SetTextColor(K.muted[1], K.muted[2], K.muted[3])
    card.value = S.Text(card, "numberLarge", "OVERLAY")
    card.value:SetPoint("TOPRIGHT", -T.rightPad, T.countY)
    card.value:SetJustifyH("RIGHT")
    local caption = S.Text(card, "metaMuted", "OVERLAY")
    caption:SetPoint("TOPRIGHT", -T.rightPad, T.captionY)
    caption:SetJustifyH("RIGHT")
    caption:SetText(T.caption)

    card:SetScript("OnClick", function(self)
        if self.itemID then B.Go({ page = "item", itemID = self.itemID }) end
    end)
    card:SetScript("OnEnter", function(self)
        if self.itemID then B.ShowItemTooltip(self, self.itemID) end
    end)
    card:SetScript("OnLeave", B.HideTooltip)
    return card
end

local function OpenCategory(key)
    if key == "vendors" then
        local route = B.Window.FirstExpansionRoute()
        if route then B.Go(route) end
    else
        B.Go({ page = "sources", source = key, nav = key })
    end
end

function Page.Build(host)
    local f = CreateFrame("Frame", nil, host)
    f:SetAllPoints()

    local h1 = W.NewSectionHeader(f)
    h1:SetPoint("TOPLEFT")
    h1:SetPoint("TOPRIGHT")
    h1.text:SetText(L["Recently acquired"])

    local T = S.toast
    local strip = CreateFrame("Frame", nil, f)
    strip:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -SP.s)
    strip:SetPoint("TOPRIGHT", h1, "BOTTOMRIGHT", 0, -SP.s)
    strip:SetHeight(RECENT_ROWS * T.height + (RECENT_ROWS - 1) * T.gap)
    Page.cards = {}
    for i = 1, RECENT_ROWS do
        local card = BuildCard(strip)
        if i > 1 then
            card:SetPoint("TOPLEFT", Page.cards[i - 1], "BOTTOMLEFT", 0, -T.gap)
        else
            card:SetPoint("TOPLEFT")
        end
        Page.cards[i] = card
    end
    Page.empty = S.Text(f, "body", "OVERLAY")
    Page.empty:SetPoint("TOP", h1, "BOTTOM", 0, -SP.xl)

    local h2 = W.NewSectionHeader(f)
    h2:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, -SP.l)
    h2:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT", 0, -SP.l)
    h2.text:SetText(L["Collection progress"])

    Page.total = W.NewBar(f, true)
    Page.total:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 0, -SP.m)
    Page.total:SetPoint("TOPRIGHT", h2, "BOTTOMRIGHT", 0, -SP.m)

    Page.bars = {}
    for i, def in ipairs(BARS) do
        local bar = W.NewBar(f, false, function() OpenCategory(def.key) end)
        local y = -SP.l - math.floor((i - 1) / 2) * (bar:GetHeight() + S.bar.rowGap)
        if i % 2 == 1 then
            bar:SetPoint("TOPLEFT", Page.total, "BOTTOMLEFT", 0, y)
            bar:SetPoint("TOPRIGHT", Page.total, "BOTTOM", -SP.s, y)
        else
            bar:SetPoint("TOPLEFT", Page.total, "BOTTOM", SP.s, y)
            bar:SetPoint("TOPRIGHT", Page.total, "BOTTOMRIGHT", 0, y)
        end
        Page.bars[i] = bar
    end
    return f
end

function Page.Shown()
    Page.total:Replay()
    for _, bar in ipairs(Page.bars) do bar:Replay() end
end

function Page.Show(_, isRefresh)
    local D = B.Data
    local recent = D.RecentlyAcquired(RECENT_ROWS)
    for i, card in ipairs(Page.cards) do
        local r = recent[i]
        card.itemID = r and r.itemID
        card:SetShown(r ~= nil)
        if r then
            local cr, cg, cb = 1, 1, 1
            local quality = D.IconData(r.itemID, false)
            if quality then cr, cg, cb = C_Item.GetItemQualityColor(quality) end
            card.icon:SetTexture(D.ItemIcon(r.itemID))
            card.name:SetText(D.ItemName(r.itemID) or L["Item %d"]:format(r.itemID))
            card.name:SetTextColor(cr, cg, cb)
            card.source:SetText(D.SourceLine(r.itemID))
            card.value:SetText(Page.RelativeDate(r.acquired))
        end
    end
    Page.empty:SetShown(#recent == 0)
    Page.empty:SetText(D.OwnershipKnown() and L["Nothing acquired yet."] or L["Ownership is not known yet."])

    local prog = D.Progress()
    local known = prog ~= nil and prog.known
    Page.total:SetProgress(L["Decor collected"], known and prog.owned or nil, prog and prog.total)
    for i, def in ipairs(BARS) do
        local s = prog and prog.src[def.key]
        Page.bars[i]:SetProgress(def.label, known and s.owned or nil, s and s.total)
    end
    if not isRefresh then Page.Shown() end
end

B.RegisterPage("overview", Page)
