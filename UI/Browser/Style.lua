-- Shared private table: the decor browser's colours, fonts, sizes and texture paths.
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
    title = "Fancy24Font",
    header = "GameFontNormalLarge",
    subheader = "GameFontNormalMed3",
    body = "GameFontHighlight",
    bodyLarge = "GameFontHighlightLarge",
    bodyGold = "GameFontNormal",
    meta = "GameFontHighlightSmall",
    metaGold = "GameFontNormalSmall",
    metaMuted = "GameFontDisableSmall",
    number = "Number12Font",
    numberLarge = "NumberFontNormal",
}

function S.Text(parent, role, layer)
    return parent:CreateFontString(nil, layer or "ARTWORK", S.font[role])
end

function S.Colored(c, text)
    local f = math.floor
    return ("|cff%02x%02x%02x%s|r"):format(f(c[1] * 255), f(c[2] * 255), f(c[3] * 255), text)
end

function S.Muted(text)
    return S.Colored(S.color.muted, text)
end

S.space = { xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32 }
local SP = S.space

S.window = { width = 860, height = 580 }

-- Side tabs outside the right edge, as on the Housing Dashboard; the portrait overhangs the top-left
-- corner by pad.left and pad.top.
S.tab = { top = 60, gap = 12, minWidth = 64, height = 55, wordPad = 12 }
S.pad = { left = 5, top = 7 }

S.layout = {
    -- content rect {left, top, right, bottom}
    rect = { 2, 21, 2, 2 }, titleBar = 21,
    headerBand = 34, insetTop = 58,
    insetLeft = 4, insetRight = 6, insetBottom = 6,
    titleLeft = 68, panePad = SP.xs,
    wellPad = 6,
    pagePad = SP.m, scrollBarGap = 14,
    headerHeight = 28,
    listRowHeight = 56, rowGap = SP.xs,
    iconRim = 42,
}

S.tex = {
    placeholderIcon = [[Interface\Icons\INV_Misc_QuestionMark]],
    vendorPlaceholder = [[Interface\Icons\INV_Misc_QuestionMark]],
    plainWhite = [[Interface\Buttons\WHITE8X8]],
    iconBorder = [[Interface\Common\WhiteIconFrame]],
    marble = [[Interface\FrameGeneral\UI-Background-Marble]],
    circleMask = [[Interface\CharacterFrame\TempPortraitAlphaMask]],
}

S.art = {
    portrait = HA.Constants.TEXTURE_ROOT .. "HomesteadPortrait_64",
}

S.atlas = {
    check = "common-icon-checkmark",
    coin = "coin-gold",
    lock = "Padlock",
    lockBadge = "ui-journeys-greatvault-lock",
    lockBadgeFallback = "Bags-padlock-authenticator",
    waypointOff = "Waypoint-MapPin-Untracked",
    waypointOn = "Waypoint-MapPin-Tracked",
    expand = "common-icon-plus",
    collapse = "common-icon-minus",
    divider = "Options_HorizontalDivider",
    vendorPin = "housing-decor-vendor_32",
}

-- texcoords {l, r, t, b}
S.coord = {
    icon = { 0.08, 0.92, 0.08, 0.92 },
    wareIcon = { 0.07, 0.93, 0.07, 0.93 },
}

S.material = {
    shadow = { 0, 0, 0 },
    stone = { 0.11, 0.10, 0.09 },
    gilt = { 1.00, 0.82, 0.00 },
}

-- Housing dashboard art behind the pane, under a neutral scrim; without the atlas the pane goes opaque.
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
    wood = {
        TL = "housing-dashboard-filigree-wood-small-tl",
        TR = "housing-dashboard-filigree-wood-small-tr",
        BL = "housing-dashboard-filigree-wood-small-bl",
        BR = "housing-dashboard-filigree-wood-small-br",
    },
    woodSize = 23,
    divider = "housing-dashboard-divider-horz-tile",
    dividerAlpha = 1,
}

S.color = {
    card = { 0.19, 0.17, 0.15, 1 },
    hoverRow = { 1, 1, 1, 0.10 },
    iconPlateTop = { 0.80, 0.69, 0.50, 1 },
    iconPlateBottom = { 0.56, 0.46, 0.32, 1 },
    owned = { 0.2, 0.7, 0.2, 1 },
    locked = { 0.7, 0.15, 0.15, 1 },
    available = { 0.78, 0.62, 0.15, 1 },
    unknown = { 0.45, 0.45, 0.45, 1 },
    neutral = { 0.55, 0.47, 0.25, 1 },
    stateText = {
        owned = { 0.35, 0.85, 0.35 },
        unlocked = { 1.00, 0.82, 0.00 },
        locked = { 1.00, 0.42, 0.35 },
        unknown = { 0.67, 0.67, 0.67 },
    },
    body = { 1, 1, 1 },
    muted = { 0.70, 0.70, 0.70 },
    -- Text on an unusable control: darker than muted.
    disabled = { 0.50, 0.50, 0.50 },
}

S.chrome = { linePad = SP.s, shadowHeight = SP.m, wellShadowHeight = SP.l, wellShade = 0.55 }

S.lockBadge = {
    row = { size = 18, point = { "BOTTOMRIGHT", 3, -3 } },
}

S.stateLabel = {
    owned = L["Owned"],
    unlocked = L["Unlocked to buy"],
    locked = L["Locked"],
    unknown = L["Unknown"],
}

S.model = {
    itemW = 268, itemH = 250,
    thumb = 44,
}

S.plate = {
    windowTitle = L["Homestead Decor"],
}
