-- Shared browser colours, fonts, sizes and textures.
local _, HA = ...

local B = {}
HA.DecorBrowser = B

-- profile.browser, the only saved table the browser writes; nil until the database has one.
function B.Saved()
    local profile = HA.Addon and HA.Addon.db and HA.Addon.db.profile
    local s = profile and profile.browser
    return type(s) == "table" and s or nil
end

local S = {}
B.Style = S

local L = HA.L

S.font = {
    meta = "UserScaledFontGameHighlightSmall",
    body = "UserScaledFontGameHighlight",
    bodyGold = "UserScaledFontGameNormal",
    -- Only a disabled control and an empty search box's placeholder, as Blizzard draws them; never a line that informs.
    disabled = "UserScaledFontGameDisable",
    subheader = "UserScaledFontGameNormalMed2",
    header = "UserScaledFontGameNormalLarge",
}

function S.FontName(role)
    return S.font[role]
end

function S.Text(parent, role, layer)
    return parent:CreateFontString(nil, layer or "ARTWORK", S.FontName(role))
end

function S.Colored(c, text)
    local f = math.floor
    return ("|cff%02x%02x%02x%s|r"):format(f(c[1] * 255), f(c[2] * 255), f(c[3] * 255), text)
end

S.space = { xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32 }
local SP = S.space

S.window = { width = 860, height = 580 }

-- The portrait overhangs the top-left corner by these.
S.pad = { left = 5, top = 7 }
S.nav = { indent = 16, gap = 2, width = 192 }

S.layout = {
    rect = { 2, 21, 2, 2 }, titleBar = 21,
    headerBand = 34, insetTop = 58,
    insetLeft = 4, insetRight = 6, insetBottom = 6,
    titleLeft = 68, panePad = SP.xs,
    wellPad = 6,
    pagePad = SP.m, scrollBarGap = 14,
}

-- A source list's one-line row: the decor icons beside the name, at most maxIcons of them, in a row iconPad tall above and below.
S.row = { pad = 6, gap = 2, tile = 30, icon = 22, iconPad = 4, maxIcons = 14, dim = 0.6,
    flag = 30, check = 11, checkLift = 1 }
S.ware = { size = 48, gap = 4 }
-- The catalog tile: its narrowest width (the columns share out the grid's width), the gap, and the pad round the
-- icon, which fills the tile, and the name under it.
S.tile = { min = 92, gap = 3, pad = 2 }
-- Overview bars: a source's slim track, the gap between a bar's text and its track, the collection bar's height
-- (the Housing Dashboard's Endeavor bar), a source's icon and its card's width.
S.bar = { track = 8, gap = SP.xs, big = 25, icon = 32, card = 184 }
-- The vendor card: its portrait, a state mark, and the well and scroll gutter around its text.
S.card = { portrait = 88, mark = 12, close = 24, closePad = 2, frame = 2 * S.layout.wellPad + S.layout.scrollBarGap }
-- The part of the close button that is over the card's text column, and a gap.
S.card.reserve = S.card.close + S.card.closePad - (S.layout.wellPad + S.layout.scrollBarGap) + S.space.xs

S.tex = {
    placeholderIcon = [[Interface\Icons\INV_Misc_QuestionMark]],
    iconBorder = [[Interface\Common\WhiteIconFrame]],
    marble = [[Interface\FrameGeneral\UI-Background-Marble]],
    bar = [[Interface\Buttons\WHITE8X8]],
}

S.art = {
    portrait = HA.Constants.TEXTURE_ROOT .. "HomesteadPortrait_64",
}

S.atlas = {
    waypointOff = "Waypoint-MapPin-Untracked",
    waypointOn = "Waypoint-MapPin-Tracked",
    expand = "common-icon-plus",
    collapse = "common-icon-minus",
    backArrow = "common-icon-backarrow",
    sign = { "housing-dashboard-woodsign-left", "housing-dashboard-woodsign-center", "housing-dashboard-woodsign-right" },
    -- The Endeavor bar's fill, its frame, and the round well and ring of its reward icon.
    fill = "housing-dashboard-fillbar-fill",
    fillFrame = "housing-dashboard-fillbar-bar-bg",
    iconWell = "housing-dashboard-fillbar-icon-bg",
    iconRing = "housing-dashboard-fillbar-icon-frame",
    -- The Endeavor task list's completed flag and the check centred on it.
    doneFlag = "housing-dashboard-tasks-listitem-flag",
    doneCheck = "housing-dashboard-small-checkmark",
}

S.glyph = {
    check = { "common-icon-checkmark" },
    dot = { "common-radiobutton-dot" },
    lock = { "groupfinder-icon-lock", "ui-journeys-greatvault-lock" },
    stop = { "common-icon-redx" },
    clock = { "housing-dashboard-timertag-clock-icon", "worldquest-icon-clock" },
    star = { "tradeskills-star" },
    -- Drawn in its own colours.
    coin = { "coin-gold", native = true },
}

S.coord = {
    wareIcon = { 0.07, 0.93, 0.07, 0.93 },
}

S.material = {
    shadow = { 0, 0, 0 },
}

S.backdrop = {
    atlas = "housing-dashboard-bg-welcome",
    scrim = { 0.04, 0.045, 0.05 },
    pageAlpha = 0.60,
}

S.filigree = {
    corner = {
        TL = { atlas = "housing-dashboard-filigree-corner-TL", x = -4, y = 2 },
        TR = { atlas = "housing-dashboard-filigree-corner-TR", x = 4, y = 2 },
        BL = { atlas = "housing-dashboard-filigree-corner-bl", x = -6, y = -2 },
        BR = { atlas = "housing-dashboard-filigree-corner-br", x = 5, y = -2 },
    },
    divider = "housing-dashboard-divider-horz-tile",
    dividerAlpha = 1,
}

-- Green means only "Can get now"; red only "can't on this character", a cost this character can't pay, and
-- errors, never a requirement, a row's own lock or a count.
S.color = {
    card = { 0.09, 0.08, 0.06, 1 },
    hoverRow = { 1, 1, 1, 0.10 },
    selected = { 0.20, 0.16, 0.11, 1 },
    iconPlateTop = { 0.80, 0.69, 0.50, 1 },
    iconPlateBottom = { 0.56, 0.46, 0.32, 1 },
    body = { 1, 1, 1 },
    -- Hairlines and the crumb separator only: text that informs is white, and its labels gold.
    rule = { 0.55, 0.55, 0.55 },
    -- A tile's name: white when collected, a light grey that reads on the dark well when not.
    nameOwned = { 1, 1, 1 },
    nameMissing = { 0.68, 0.68, 0.68 },
    disabled = { 0.40, 0.40, 0.40 },
    gold = { 1.00, 0.82, 0.00 },
    money = { 0.94, 0.79, 0.29 },
    can = { 0.24, 0.88, 0.24 },
    stop = { 1.00, 0.20, 0.20 },
    badge = { 0.90, 0.84, 0.66 },
    barFill = { 0.80, 0.69, 0.50 },
    barTrack = { 0.14, 0.12, 0.09 },
    -- The Overview's source-type bars: a tint each, never the can-get green.
    source = {
        vendors = { 0.80, 0.69, 0.50 }, achievements = { 0.90, 0.62, 0.22 }, quests = { 0.95, 0.82, 0.35 },
        professions = { 0.38, 0.58, 0.92 }, drops = { 0.64, 0.42, 0.86 }, events = { 0.88, 0.42, 0.32 },
        shop = { 0.42, 0.72, 0.95 },
    },
}
local K = S.color

-- The words and second signal of each row state. Locked, short and faction/event take their argument; the
-- last four are Sources' list rows.
S.state = {
    owned = { word = L["Collected"], glyph = "check", color = K.body },
    can = { word = L["Can get now"], glyph = "dot", color = K.can },
    short = { word = L["Not enough: %s"], glyph = "coin", color = K.stop },
    unpriced = { word = L["Price not recorded"], color = K.body },
    locked = { word = L["Requires: %s"], glyph = "lock", color = K.body },
    faction = { word = L["%s only"], glyph = "stop", color = K.stop },
    event = { word = L["%s only"], glyph = "clock", color = K.body },
    notOwned = { word = L["Not collected"], color = K.body },
    counting = { word = L["Counting…"], color = K.body },
    allDone = { word = "", glyph = "check", color = K.body },
    some = { word = L["%d can get now"], glyph = "dot", color = K.can },
    idle = { word = L["Not active"], glyph = "clock", color = K.body },
    live = { word = L["Active now"], glyph = "clock", color = K.badge },
}

S.sourceLabel = {
    vendors = L["Vendors"], achievements = L["Achievements"], quests = L["Quests"], professions = L["Professions"],
    drops = L["Drops"], events = L["Events"], shop = L["Shop"],
}

S.kind = { [1] = L["Furnishings"], [2] = L["Structural"], [3] = L["Accents"], [4] = L["Lighting"], other = L["Other"] }
function S.KindOf(info)
    for k, v in pairs(info and info.categoryIDs or {}) do
        local id = type(v) == "number" and v or k
        if S.kind[id] then return id end
    end
    return "other"
end

S.chrome = { linePad = SP.s, shadowHeight = SP.m, wellShadowHeight = SP.l, wellShade = 0.55 }

-- The item page: its head tile, and the 3D preview as width, height.
S.model = { thumb = 44, preview = { 220, 160 } }

S.plate = {
    windowTitle = L["Homestead Decor"],
}
