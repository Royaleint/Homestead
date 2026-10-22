-- Shared private table: the decor browser's colours, fonts, sizes and texture paths.
local _, HA = ...

local B = {}
HA.DecorBrowser = B

B.pages = {}

function B.RegisterPage(key, page)
    B.pages[key] = page
end

-- profile.browser, the only saved table the browser writes; nil until the database has one.
function B.Saved()
    local profile = HA.Addon and HA.Addon.db and HA.Addon.db.profile
    local s = profile and profile.browser
    return type(s) == "table" and s or nil
end

local S = {}
B.Style = S

local L = HA.L
local ART = HA.Constants.TEXTURE_ROOT .. "Browser\\"

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

S.space = { xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32, edgeFade = 24 }
local SP = S.space

S.window = { width = 930, height = 620 }

S.layout = {
    -- content rect {left, top, right, bottom}
    rect = { 2, 21, 2, 2 }, titleBar = 21,
    headerBand = 34, insetTop = 58,
    insetLeft = 4, insetRight = 6, insetBottom = 6,
    titleLeft = 68, panePad = SP.xs,
    catWidth = 200, columnGap = SP.xs,
    wellPad = 6,
    toolbarHeight = 36, pagePad = SP.m, scrollBarGap = 14,
    navTopNudge = 6,
    navRowHeight = 28, navSubHeight = 24, navSubIndent = 16, navGap = 2,
    headerHeight = 28,
    toastHeight = 72, listRowHeight = 56, vendorRowHeight = 56, rowGap = SP.xs,
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
    sheenStrip = ART .. "sheen_strip.png",
    portrait = HA.Constants.TEXTURE_ROOT .. "HomesteadPortrait_64",
    toastPlate = ART .. "toast_plate.png",
    toastTrim = ART .. "toast_trim.png",
    toastShadow = ART .. "toast_shadow.png",
    toastRays = ART .. "toast_rays.png",
    toastRing = ART .. "toast_ring.png",
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
    backArrow = "common-icon-backarrow",
    wareSlot = "house-chest-list-item-default",
    wareSlotFallback = "bags-item-slot64",
    newGlowFallback = "bags-glow-white",
    changeFlash = "bags-glow-flash",
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
    lamp = { 1.00, 0.86, 0.60 },
    gilt = { 1.00, 0.82, 0.00 },
}
local M = S.material

-- Housing dashboard art behind both panes, under neutral scrims; without the atlas the panes go opaque.
S.backdrop = {
    atlas = "housing-dashboard-bg-welcome",
    scrim = { 0.04, 0.045, 0.05 },
    navAlpha = 0.45,
    pageAlpha = 0.60,
    toastAlpha = 0.74,
    divider = { 1, 1, 1, 0.14 },
    edgeAlpha = 0.70,
    edgeLength = 16,
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
    wareHover = { 1, 1, 1, 0.18 },
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

S.progress = {
    { upTo = 0.25, color = { 0.59, 0.31, 0.21 } },
    { upTo = 0.50, color = { 0.87, 0.59, 0.19 } },
    { upTo = 0.75, color = { 0.96, 0.82, 0.14 } },
    { upTo = 1.00, color = { 0.67, 0.81, 0.30 } },
    complete = { 0.28, 0.82, 0.37 },
}

S.bar = {
    track = 6, trackWide = 8, textGap = SP.xs, rowGap = SP.m,
    trackColor = { 1, 1, 1, 0.07 }, edgeColor = { 1, 1, 1, 0.10 },
    sheenTop = 0.22,
}

S.chrome = { linePad = SP.s, shadowHeight = SP.m, wellShadowHeight = SP.l, wellShade = 0.55 }

S.mapCard = { zoom = 2.2, pin = 22, captionHeight = 30, captionShade = 0.85, emptyIcon = 40 }

S.lockBadge = {
    row = { size = 18, point = { "BOTTOMRIGHT", 3, -3 } },
    tile = { size = 16, point = { "TOPRIGHT", 3, 3 } },
}

S.wareCell = {
    size = 56, gap = SP.s,
    inset = SP.xs, shade = SP.l, shadeAlpha = 0.7,
    check = { size = 16, point = { "TOPRIGHT", 3, 3 } },
    count = { point = { "BOTTOMRIGHT", -SP.xs, SP.xs } },
}

-- A glow reads as new when the item is among the newTop latest acquisitions, first seen within newWindowDays.
S.itemFx = {
    newWindowDays = 7, newTop = 3,
    pulseLow = 0.35, pulseSeconds = 1.1,
    flashSeconds = 0.6, flashSpill = SP.xs,
}

-- The plate art is drawn for 352 x 88; the card is 72 tall.
S.toast = {
    width = 380, height = 72, gap = SP.s, shadowPad = 12,
    iconCenter = 48, ring = 52, seat = 44, icon = 36,
    textLeft = 88, dividerLeft = 84, rightPad = 24, rightColumn = 80,
    labelY = -14, dividerY = -25, nameY = -30, sourceY = -50, countY = -30, captionY = -50,
    rim = { 0.62, 0.46, 0.16 }, rimLit = { 1.00, 0.88, 0.52 },
    raysAlpha = 0.30, raysSize = { 256, 128 },
    kicker = L["New decor collected"], caption = L["first seen"],
}

S.expansionShort = {
    ["Wrath of the Lich King"] = L["Wrath"],
    ["Warlords of Draenor"] = L["Warlords"],
    ["The Burning Crusade"] = L["Burning Crusade"],
    ["Battle for Azeroth"] = L["BfA"],
    ["Mists of Pandaria"] = L["Pandaria"],
}

S.relativeDateDays = 14

S.stateLabel = {
    owned = L["Owned"],
    unlocked = L["Unlocked to buy"],
    locked = L["Locked"],
    unknown = L["Unknown"],
}

S.model = {
    defaultSceneID = 1317,
    actorTag = "decor",
    vendorW = 220, vendorH = 250,
    mapW = 220, mapH = 250,
    itemW = 268, itemH = 250,
    thumb = 44,
}

S.plate = {
    windowTitle = L["Homestead"],
    title = L["Decor Browser"],
    edge = SP.xs,
    sheenLayers = {
        { tone = M.lamp, alpha = 0.22, uSpan = 1.2, slope = 1.3, flip = false,
          template = "HomesteadDecorBrowserSheenA" },
        { tone = M.gilt, alpha = 0.14, uSpan = 0.8, slope = 1.0, flip = true,
          template = "HomesteadDecorBrowserSheenB" },
    },
}
