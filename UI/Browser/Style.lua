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

-- Text steps: 10, 12, 14 and 16 are Blizzard's user-scaled fonts. None exists at 24, so display is a
-- private font that S.ScaleDisplay resizes with the text size.
S.font = {
    meta = "UserScaledFontGameHighlightSmall",
    metaMuted = "UserScaledFontGameDisableSmall",
    body = "UserScaledFontGameHighlight",
    bodyGold = "UserScaledFontGameNormal",
    bodyMuted = "UserScaledFontGameDisable",
    subheader = "UserScaledFontGameNormalMed2",
    display = "HomesteadBrowserDisplay",
}
local DISPLAY_SIZE = 24

local display
local function DisplayFont()
    if not display then
        display = CreateFont(S.font.display)
        display:CopyFontObject("GameFontNormalHuge2")
        display:SetFontHeight(DISPLAY_SIZE * TextSizeManager:GetScale())
    end
end

function S.ScaleDisplay()
    if display then display:SetFontHeight(DISPLAY_SIZE * TextSizeManager:GetScale()) end
end

function S.FontName(role)
    if role == "display" then DisplayFont() end
    return S.font[role]
end

function S.Text(parent, role, layer)
    return parent:CreateFontString(nil, layer or "ARTWORK", S.FontName(role))
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
}

-- Heights come from measured text (Widgets.TextHeight); these are only the padding around it.
S.row = { pad = 6, gap = 2, tile = 30 }
S.cols = { nav = 172, detail = 252, gap = SP.xs }

S.tex = {
    placeholderIcon = [[Interface\Icons\INV_Misc_QuestionMark]],
    iconBorder = [[Interface\Common\WhiteIconFrame]],
    marble = [[Interface\FrameGeneral\UI-Background-Marble]],
}

S.art = {
    portrait = HA.Constants.TEXTURE_ROOT .. "HomesteadPortrait_64",
}

S.atlas = {
    waypointOff = "Waypoint-MapPin-Untracked",
    waypointOn = "Waypoint-MapPin-Tracked",
}

-- State marks, first atlas the client has wins; Vis.Marker falls back to a colour square.
S.glyph = {
    check = { "common-icon-checkmark" },
    dot = { "common-radiobutton-dot" },
    lock = { "groupfinder-icon-lock", "ui-journeys-greatvault-lock" },
    stop = { "common-icon-redx" },
    clock = { "housing-dashboard-timertag-clock-icon", "worldquest-icon-clock" },
    star = { "tradeskills-star" },
}

-- texcoords {l, r, t, b}
S.coord = {
    wareIcon = { 0.07, 0.93, 0.07, 0.93 },
}

S.material = {
    shadow = { 0, 0, 0 },
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
    divider = "housing-dashboard-divider-horz-tile",
    dividerAlpha = 1,
}

-- Green means only "Can get now"; red only "can't on this character" and errors, never a row's own lock or
-- count.
S.color = {
    card = { 0.09, 0.08, 0.06, 1 },
    hoverRow = { 1, 1, 1, 0.10 },
    selected = { 0.20, 0.16, 0.11, 1 },
    iconPlateTop = { 0.80, 0.69, 0.50, 1 },
    iconPlateBottom = { 0.56, 0.46, 0.32, 1 },
    body = { 1, 1, 1 },
    muted = { 0.55, 0.55, 0.55 },
    gold = { 1.00, 0.82, 0.00 },
    money = { 0.94, 0.79, 0.29 },
    can = { 0.24, 0.88, 0.24 },
    stop = { 1.00, 0.20, 0.20 },
    badge = { 0.90, 0.84, 0.66 },
}
local K = S.color

-- The words and second signal of each row state. Locked and faction/event take their argument; the last
-- four are Sources' list rows.
S.state = {
    owned = { word = L["Collected"], glyph = "check", color = K.muted, dim = true },
    can = { word = L["Can get now"], glyph = "dot", color = K.can },
    locked = { word = L["Requires: %s"], glyph = "lock", color = K.muted },
    faction = { word = L["%s only"], glyph = "stop", color = K.stop },
    event = { word = L["%s only"], glyph = "clock", color = K.muted },
    notOwned = { word = L["Not collected"], color = K.muted },
    counting = { word = L["Counting…"], color = K.muted },
    allDone = { word = L["All collected"], glyph = "check", color = K.muted, dim = true },
    some = { word = L["%d can get now"], glyph = "dot", color = K.can },
    idle = { word = L["Not active"], glyph = "clock", color = K.muted },
    live = { word = L["Active now"], glyph = "clock", color = K.badge },
}

-- Each Sources type's name, on the Sources nav, the Catalog filters and the Summary counts.
S.sourceLabel = {
    vendors = L["Vendors"], achievements = L["Achievements"], quests = L["Quests"], professions = L["Professions"],
    drops = L["Drops"], events = L["Events"], shop = L["Shop"],
}

-- Decor kinds, as on the Catalog nav; categoryIDs may be an array or a set.
S.kind = { [1] = L["Furnishings"], [2] = L["Structural"], [3] = L["Accents"], [4] = L["Lighting"], other = L["Other"] }
function S.KindOf(info)
    for k, v in pairs(info and info.categoryIDs or {}) do
        local id = type(v) == "number" and v or k
        if S.kind[id] then return id end
    end
    return "other"
end

S.chrome = { linePad = SP.s, shadowHeight = SP.m, wellShadowHeight = SP.l, wellShade = 0.55 }

S.model = { thumb = 44 }

S.plate = {
    windowTitle = L["Homestead Decor"],
}
