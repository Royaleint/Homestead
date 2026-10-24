-- Sources: the vendor lists (all vendors, one expansion), the six other source lists, the vendor card and the
-- page of one other source. One page serves the sources, vendors, allVendors and vendor routes: the vendor
-- route is a card over its list, beside it in a narrowed list or, when the page is too narrow for both, over it.
-- Rows are keyed by Facts.SourceKey.
local _, HA = ...

local B = HA.DecorBrowser
local L, S, W = HA.L, B.Style, B.Widgets
local D, CG, Facts = B.Data, B.CanGet, B.Facts
local SP, K, LO = S.space, S.color, S.layout
local Vis = B.Vis

local function MapName(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name
end

local KIND = {
    vendors = { L["Vendor"], L["Search vendors and zones"] },
    achievements = { L["Achievement"], L["Search achievements"], "AchievementSources", function(d)
        return { title = d.achievementName, sub = d.category or L["Achievement"], group = d.category or L["Other"],
            achievementID = d.achievementID }
    end },
    quests = { L["Quest"], L["Search quests"], "QuestSources", function(d)
        local at = Facts.TreasureSpot(d.questID) or Facts.QuestStart(d.questID)
        return { title = d.questName, sub = MapName(at and at.mapID) or L["Location not recorded"], questID = d.questID }
    end },
    professions = { L["Profession"], L["Search recipes and professions"], "ProfessionSources",
        function(d) return { title = d.recipeName, sub = d.skillTier or d.profession, group = d.profession } end },
    drops = { L["Drop"], L["Search drops and zones"], "DropSources",
        function(d) return { title = d.mobName, sub = d.zone, drop = d } end },
    events = { L["Event"], L["Search events"], "EventSources",
        function(d) return { title = d.event, sub = L["Holiday event"], namesKind = true } end },
    shop = { L["Shop"], L["Search the Shop"], "ShopSources", function() return { sub = L["Shop"] } end },
}
local TYPES = CG.SOURCE_KEYS
local LINK = Facts.LINK

local Page = {}
local st = { type = "achievements" }
local now, query, wide = nil, "", false
local head, list, empty, torn, asked, cs, static, vend, vendVer
local well, shown, vid
local Vend, V = {}, {}
local P, colNow, slide
local colW, cover = S.nav.width, false
local PORTRAIT, DOT, FRAME = S.card.portrait, S.card.mark, S.card.frame
local FLOOR, GAP, LIFT = 2 * S.ware.size + S.ware.gap, SP.s, 20
-- The card's text and scroll frame sit INSET in from its well. The close button sits XPAD in from the well's
-- corner; the head leaves XRES for the part of it that is over the text, and the card's scroll bar starts below it.
local INSET, XSIZE, XPAD, XRES = LO.wellPad, S.card.close, S.card.closePad, S.card.reserve

-- Beside an open card the list is narrowed to its names and what can be got now; under a covering card it keeps its rows.
local function Narrow()
    return vid ~= nil and not cover
end

local function Live(event)
    local CD = HA.CalendarDetector
    return CD ~= nil and CD:IsHolidayActive(event) == true
end

local conts = {}
local function Continent(mapID)
    local id = mapID and Facts.ContinentOf(mapID)
    if id and conts[id] == nil then conts[id] = MapName(id) or false end
    return id and conts[id] or nil
end

local function Statics()
    if static then return static end
    static = {}
    for _, t in ipairs(TYPES) do
        local bucket, kind = { by = {} }, KIND[t]
        static[t] = bucket
        for itemID, d in pairs(kind[3] and HA[kind[3]] or {}) do
            local key = type(d) == "table" and type(itemID) == "number" and Facts.SourceKey(t, d, itemID)
            if key then
                local s = bucket.by[key]
                if not s then
                    s = kind[4](d)
                    s.key, s.type, s.items, s.title = key, t, {}, s.title or L["Unknown"]
                    bucket.by[key], bucket[#bucket + 1] = s, s
                end
                s.items[#s.items + 1] = itemID
            end
        end
    end
    return static
end

-- One entry per listed vendor, for all vendors or one expansion. Wares are read only for these.
local function VendorList(home)
    local version = D.MemoVersion()
    if vendVer ~= version then vend, vendVer = {}, version end
    local out = {}
    for _, v in ipairs(D.ListedVendors()) do
        if not home or D.VendorHome(v) == home then
            local key = Facts.SourceKey("vendors", v)
            local s = vend[key]
            if not s then
                s = {
                    key = key, type = "vendors", vendor = v, title = v.name or L["Unknown"], items = D.VendorWares(v),
                    sub = Facts.Where(v) or "",
                }
                vend[key] = s
            end
            out[#out + 1] = s
        end
    end
    return out
end

-- A shop source is named after its item, which may not have loaded yet.
local function ShopTitle(s)
    s.title = D.ItemName(s.items[1]) or L["Item %d"]:format(s.items[1])
end

-- Total decor, owned (nil until known) and can get now (nil until known).
local function Stats(s)
    local total = #s.items
    if cs ~= "ready" then return total end
    local v, can, got = s.vendor, 0
    if v then
        local n
        got, n = D.VendorCounts(v, asked)
        if n == nil then asked = true else total = n end
        can = CG.VendorCanCount(v)
    else
        got = 0
        for _, id in ipairs(s.items) do
            local e = CG.Entry(id)
            if e and e.own == "owned" then got = got + 1 elseif e and e.verdict == "can" then can = can + 1 end
        end
    end
    return total, got, can
end

local function Head(t)
    local w = cs == "ready" and CG.Walk()
    local p = w and w.progress.src[t]
    return p and L["%d of %d collected"]:format(p.owned, p.total) or L["Counting…"]
end

-- An expansion's head counts each ware once, however many of its vendors sell it.
local function ExpansionHead(vendors)
    if cs ~= "ready" then return L["Counting…"] end
    local seen, owned, total = {}, 0, 0
    for _, s in ipairs(vendors) do
        for _, id in ipairs(s.items) do
            if not seen[id] then
                local e = CG.Entry(id)
                seen[id] = true
                total = total + 1
                if e and e.own == "owned" then owned = owned + 1 end
            end
        end
    end
    return L["%d of %d collected"]:format(owned, total)
end

local function RowData(s)
    local total, got, can = Stats(s)
    local v, state, arg = s.vendor
    if v and D.IsOppositeFaction(v) then state, arg = "faction", D.VendorFactionLabel(v)
    elseif s.type == "events" and not Live(s.key) then state = "idle"
    elseif cs == "counting" then state = "counting"
    elseif CG.HiddenBy(v and { vendor = v } or { items = s.items }) == "collected" then state = "allDone"
    elseif can and can > 0 then state, arg = "some", can
    elseif s.type == "events" or (v and D.HolidayActive(v)) then state = "live" end
    return {
        kind = "row", key = s.key, name = s.title, line2 = s.sub, noTile = true, state = state, arg = arg,
        selected = vid ~= nil and s.key == vid or nil, narrow = Narrow() or nil,
        right = total == 0 and L["No decor"] or got and L["%d of %d"]:format(got, total) or L["%d decor"]:format(total),
        unconfirmed = v and not Facts.Confirmed(v) or nil,
        onClick = function()
            if not v then B.Go({ kind = "source", key = s.type, id = s.key })
            elseif vid == s.key then Page:CloseCard()
            else B.Go({ kind = "vendor", id = s.key, list = { kind = now.kind, key = now.key } }) end
        end,
        onEnter = LINK[s.type] and function(self) B.ShowLinkTooltip(self, LINK[s.type](s)) end or nil,
    }
end

-- Vendors group by expansion (all vendors only) and zone, a vendor with no zone last; events by whether they run.
local function Place(s, order)
    s.o, s.g, s.late = 0, s.group, nil
    local v = s.vendor
    if v then
        s.e, s.g, s.late = D.VendorHome(v), v.zone or L["Location not recorded"], v.zone == nil
        s.o = order and order[s.e] or 0
    elseif s.type == "events" then
        s.o = Live(s.key) and 0 or 1
    end
end

local function Before(a, b)
    if a.o ~= b.o then return a.o < b.o end
    if a.late ~= b.late then return b.late == true end
    local ga, gb = a.g or "", b.g or ""
    if ga ~= gb then return ga < gb end
    if a.title ~= b.title then return a.title < b.title end
    return tostring(a.key) < tostring(b.key)
end

local function Extent(d)
    if d.kind == "header" then return W.HeaderExtent(d, list.box:GetWidth()) end
    if d.kind == "foot" then
        local w = list.box:GetWidth()
        return d.text and W.TextHeight("bodyMuted", d.text, w - 2 * SP.s) + W.TextHeight("body") + 3 * SP.s
            or W.FooterHeight(d, w)
    end
    return W.RowHeight()
end

local footKind = {
    frameType = "HomesteadDecorBrowserFooter",
    build = W.footerKind.build,
    init = function(f, d)
        f.link:SetShown(not d.text)
        if d.text then f.text:SetText(d.text) else W.footerKind.init(f, d) end
    end,
}

local function ShowHidden()
    B.Window.hideNA:SetChecked(false)
    B.SetHideNA(false)
end

local function ResetSearch()
    B.Window.SetSearch("")
    Page:Filter("")
end

-- Returns the index of the header of the zone (a map id) when given and the list has a vendor in it, then
-- the index of the open card's row.
local function BuildList(keep, zone)
    asked, cs = false, D.CollectionState()
    local t, hide = wide and "vendors" or st.type, B.State.hideNA
    -- In the player's own zone the seed means everything the Overview "Here" line counts: the zone and its child maps.
    local here = zone and Facts.Here()
    local nearby = here and here.zone == zone and here.maps or nil
    local q = query:lower()
    local entries, order
    if wide then
        entries = VendorList(now.kind == "vendors" and now.key or nil)
        if now.kind == "allVendors" then
            order = {}
            for i, e in ipairs(D.Expansions()) do order[e] = i end
        end
    else
        entries = Statics()[t]
    end
    local out, live = {}, false
    local hidden, seen = { kind = "foot", hidden = 0, collected = 0, faction = 0, onShow = ShowHidden }, {}
    for _, s in ipairs(entries) do
        if t == "shop" then ShopTitle(s) end
        live = live or (t == "events" and Live(s.key))
        local v = s.vendor
        if q == "" or (s.title .. " " .. (s.sub or "") .. " " .. (s.group or "") .. " " .. (v and v.zone or "")):lower():find(q, 1, true) then
            local why = hide and CG.HiddenBy(v and { vendor = v } or { items = s.items })
            if why then
                hidden.hidden = hidden.hidden + 1
                hidden[why] = hidden[why] + 1
                if why == "faction" then
                    local label = v and D.VendorFactionLabel(v) or ""
                    seen[label] = (seen[label] or 0) + 1
                end
            else
                out[#out + 1] = s
                Place(s, order)
            end
        end
    end
    hidden.parts = Facts.FactionParts(seen)
    table.sort(out, Before)
    local data, group, expansion, headAt, zoneAt, openAt = {}, nil, nil, nil, nil, nil
    if t == "events" and not live then
        data[1] = { kind = "foot", text = L["No events active right now. Event decor is sold only while its event runs."] }
    end
    for _, s in ipairs(out) do
        if order and s.e ~= expansion then
            expansion, group = s.e, nil
            data[#data + 1] = { kind = "header", text = D.ExpansionLabel(expansion) }
        end
        if s.g and s.g ~= group then
            group = s.g
            data[#data + 1] = { kind = "header", text = group, nested = order and true or nil }
            headAt = #data
        end
        local v = s.vendor
        if zone and not zoneAt and v and v.mapID and (nearby and nearby[v.mapID] or Facts.ZoneOf(v.mapID) == zone) then
            zoneAt = headAt
        end
        data[#data + 1] = RowData(s)
        if vid and s.key == vid then openAt = #data end
    end
    local note = hidden.hidden > 0 and hidden or nil
    if note and #out > 0 then data[#data + 1] = note end
    shown = data
    list:SetShown(#out > 0)
    if #out > 0 then
        empty:Hide()
        list:SetData(data, keep)
    else
        local text = q ~= "" and L["Nothing matches your search."] or L["Nothing to show here."]
        empty:Set("noResults", {
            title = L["No results"], text = note and text .. " " .. W.FooterText(note) or text,
            onShow = note and ShowHidden,
            onReset = q ~= "" and ResetSearch or nil,
        })
    end
    head:SetHeight(W.TextHeight("bodyMuted") + SP.s)
    head:SetText(wide and now.kind == "vendors" and ExpansionHead(entries) or Head(t))
    return zoneAt, openAt
end

-- Lights the open card's row, or none, and narrows or widens the rows for the mode, without rebuilding the list.
local function Mark()
    local narrow = Narrow()
    for _, d in ipairs(shown) do
        if d.kind == "row" then d.selected, d.narrow = vid ~= nil and d.key == vid or nil, narrow or nil end
    end
    W.RepaintRows(list)
end

-- The width the card's text takes: the page less the list beside it and the card's own well and gutter.
local function BodyWidth()
    return P:GetWidth() - (cover and 0 or colW + SP.xs) - FRAME
end

-- The card's own width: the page less the narrowed list and the gap beside it.
local function CardWidth()
    return P:GetWidth() - (colNow > 0 and colNow + SP.xs or 0)
end

-- Reads the mode from the page's width; false while the page has none, when the draw is owed.
local function Layout()
    local room = P:GetWidth()
    if room <= 0 then return false end
    colW, cover = W.Split(room)
    return true
end

-- Places the list and the card for the mode: the list narrowed with the card beside it, or the card over the page.
local function Arrange()
    local narrow = Narrow()
    colNow = narrow and colW or 0
    well:ClearAllPoints()
    well:SetPoint("TOPLEFT")
    if narrow then
        well:SetPoint("BOTTOMLEFT")
        well:SetWidth(colW)
    else
        well:SetPoint("BOTTOMRIGHT")
    end
    V.clip:ClearAllPoints()
    if narrow then V.clip:SetPoint("TOPLEFT", well, "TOPRIGHT", SP.xs, 0) else V.clip:SetPoint("TOPLEFT") end
    V.clip:SetPoint("BOTTOMRIGHT", 0, -1)
    V.clip:SetShown(vid ~= nil)
    if vid == nil then
        slide = false
        B.Window.StopSlide(V.well)
    end
end

-- Arranges an already-built list for the mode. Header and footer heights follow the width, and frames on screen
-- keep their old extent until their initializers run again, so a width change rebuilds the box in place, keeping
-- the scroll position. Rebuild raises on a box that was never given data.
local function Fit()
    local was = colNow
    Arrange()
    Mark()
    if colNow ~= was and list.box:HasDataProvider() then list.box:Rebuild(ScrollBoxConstants.RetainScrollPosition) end
end

local function Para(fs, role, text)
    fs:SetShown(text and true or false)
    if text then
        fs:SetFontObject(S.font[role])
        fs:SetText(text)
    end
end

local function Line(fs, role, text, w)
    Para(fs, role, text)
    if text then fs:SetSize(w, W.TextHeight(role, text, w)) end
end

-- The requirement type that names a source of each page type.
local OWN = { achievements = "achievement", quests = "quest" }

-- A locked item reads "Not collected" on the page of its own requirement: at the vendor it would be bought from,
-- at least one requirement is unmet and every unmet one is this source, by id or by the source's name.
local function OwnRequirement(s, itemID, at)
    local SM, kind, unmet = HA.SourceManager, OWN[s.type], 0
    for _, r in ipairs(SM:GetRequirements(itemID, at) or {}) do
        if SM:IsRequirementMet(r) ~= true then
            if not (kind and r.type == kind and (r.id == s.key or r.name == s.title)) then return false end
            unmet = unmet + 1
        end
    end
    return unmet > 0
end

local function Rows(s, cells)
    local v, rows = s.vendor, {}
    for _, itemID in ipairs(s.items) do
        local e = CG.Entry(itemID)
        local info = e and e.info
        local state, arg, at = B.ItemState(itemID, v and v.npcID)
        if state == "locked" and not v and OwnRequirement(s, itemID, at) then state, arg = "notOwned", nil end
        rows[#rows + 1] = {
            kind = "row", name = D.ItemName(itemID, info) or L["Item %d"]:format(itemID),
            rank = state == "can" and 1 or state == "owned" and 3 or 2,
            quality = info and info.quality or C_Item.GetItemQualityByID(itemID), icon = D.ItemIcon(itemID),
            itemID = itemID, npcID = v and v.npcID, state = state, arg = arg, right = v and not cells and D.Price(itemID, v),
            onClick = function() B.Go({ kind = "item", id = itemID }) end,
        }
    end
    table.sort(rows, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.name ~= b.name then return a.name < b.name end
        return a.itemID < b.itemID
    end)
    return rows
end

local function Loc(s)
    local v, d = s.vendor, s.drop
    if v then return D.VendorLocation(v) end
    if d and d.coords and not (d.journalEncounterID or d.journalInstanceID) then return d.mapID, d.coords.x, d.coords.y end
end

local function Report(s)
    if not s then return end
    local v = s.vendor
    local mapID, x, y = Loc(s)
    local where = mapID and L["map %d at %.1f, %.1f"]:format(mapID, x * 100, y * 100) or L["no location"]
    local build, number = GetBuildInfo()
    HA.OutputWindow:Show(L["Report a data error"], table.concat({
        v and L["Vendor %d: %s, %s, %s"]:format(v.npcID, v.name or L["Unknown"], v.zone or L["Unknown"], where)
            or L["%s: %s"]:format(KIND[s.type][1], s.title),
        L["Client: %s (%s)"]:format(build or "?", number or "?"),
        L["Homestead: %s"]:format(HA.Constants.VERSION or "?"),
    }, "\n"))
end

local Text = W.Text

-- Every list is the whole page: a count head over the rows, in one well.
function Page:Build(parent)
    well = W.Well(parent)
    well:SetPoint("TOPLEFT")
    well:SetPoint("BOTTOMRIGHT")
    head = S.Text(well, "bodyMuted", "OVERLAY")
    head:SetPoint("TOPLEFT", LO.wellPad, -LO.wellPad)
    head:SetPoint("TOPRIGHT", -LO.wellPad, -LO.wellPad)
    head:SetJustifyH("LEFT")
    head:SetWordWrap(false)
    local lh = CreateFrame("Frame", nil, well)
    lh:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -SP.xs)
    lh:SetPoint("BOTTOMRIGHT", -LO.wellPad, LO.wellPad)
    list = W.NewList(lh, {
        extent = Extent, reclaim = true,
        kinds = { row = W.rowKind, header = W.headerKind, foot = footKind },
    })
    empty = W.NewEmptyState(lh)
    P = parent
    Vend:Build(parent)
end

-- A source route with no usable key keeps the type the player last had.
local function TypeOf(route)
    local key = route.key
    return key ~= "vendors" and KIND[key] and key or st.type
end

function Page:Placeholder(route)
    return KIND[route.kind == "sources" and TypeOf(route) or "vendors"][2]
end

-- An expansion with no listed vendor left is gone: the router falls back to all vendors. So is a vendor the
-- data no longer has.
function Page:Has(route)
    if route.kind == "vendor" then return D.Vendor(route.id) ~= nil end
    if route.kind ~= "vendors" then return true end
    for _, e in ipairs(D.Expansions()) do
        if e == route.key then return true end
    end
    return false
end

-- The list a card sits over: the route's own, else its vendor's expansion, else all vendors when that is gone.
function Page:ListOf(route)
    if route.kind ~= "vendor" then return nil end
    local over = route.list or { kind = "vendors", key = D.VendorHome(D.Vendor(route.id) or {}) }
    return self:Has(over) and over or { kind = "allVendors" }
end

-- A forward Show starts from the route's seed (search or zone); Back gives saved. A vendor route is a card over
-- its list (route.list): with keep, that list is already up, and opening, swapping and closing the card leave it.
function Page:Show(route, saved, keep)
    local card = route.kind == "vendor"
    local over = card and route.list or route
    -- Only a card the player opens slides: not a swap, a Back restore or a refresh.
    if card and not saved and (not keep or vid == nil) then slide = true end
    if card then Layout() end
    if keep then
        B.HideTooltip()
        vid = card and route.id or nil
        Fit()
    else
        local seed = route.seed
        now, wide, torn, vid = over, over.kind ~= "sources", false, card and route.id or nil
        if not wide then st.type = TypeOf(over) end
        Arrange()
        query = saved and saved.search or seed and seed.search or ""
        B.Window.SetSearch(query)
        local at, openAt = BuildList(false, seed and seed.zone)
        if saved and saved.scroll then
            list.box:ScrollToOffset(saved.scroll, true)
        elseif at then
            list.box:ScrollToElementDataIndex(at, ScrollBoxConstants.AlignBegin)
        elseif openAt then
            list.box:ScrollToElementDataIndex(openAt, ScrollBoxConstants.AlignCenter)
        end
    end
    if card then Vend:Show(saved and saved.card) end
end

function Page:Save()
    return {
        search = query, scroll = list.box:GetDerivedScrollOffset(), card = vid and Vend:Save() or nil,
    }
end

-- Closes the open card onto its list: Escape, and clicking the selected row.
function Page:CloseCard()
    return vid ~= nil and B.CloseOver()
end

function Page:Filter(text)
    if text == query then return end
    query, torn = text, false
    BuildList(false)
end

function Page:Hide()
    torn, slide = true, false
    B.Window.StopSlide(V.well)
    B.HideTooltip()
end

function Page:Refresh(reason)
    if not (list and now) then return end
    if reason == "data" then B.Walk() end
    if reason == "layout" and vid and Layout() then Arrange() end
    local was = torn
    if reason == "paint" and not torn then
        W.RepaintRows(list)
    else
        torn = false
        BuildList(true)
    end
    if vid then Vend:Refresh(reason, was) end
end

-- Only the card has a control that waits for the end of combat.
function Page:SetCombat(inCombat)
    if V.report then V.report:SetEnabled(not inCombat) end
end

-- The card is one scroll, so a large text size scrolls the card instead of clipping the head.
local Draw

-- The "● N can get now" line: a dot and its words.
local function CanLine(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.dot = f:CreateTexture(nil, "OVERLAY")
    f.dot:SetSize(DOT, DOT)
    Vis.Marker.Set(f.dot, S.state.some.glyph, S.state.some.color)
    f.text = Text(f)
    f.text:SetPoint("TOPLEFT", DOT + SP.xs, 0)
    f.text:SetTextColor(unpack(S.state.some.color))
    return f
end

-- Shown only for a count above 0. w, when known, is the line's width and wraps the words; otherwise they run on.
local function SetCan(f, can, w)
    f:SetShown(can > 0)
    if can <= 0 then return end
    local words = W.StateWords("some", can)
    f.text:SetText(words)
    local tw = w and w - DOT - SP.xs or f.text:GetUnboundedStringWidth() + 1
    local h = W.TextHeight("body", words, tw)
    f.text:SetSize(tw, h)
    f.dot:SetPoint("TOPLEFT", 0, -(W.TextHeight("body") - DOT) / 2)
    f:SetHeight(h)
    if w then f:SetWidth(w) end
end

local function SetFace(v)
    local face = Facts.Portrait(v.npcID)
    if face then SetPortraitTextureFromCreatureDisplayID(V.face, face) else V.face:SetTexture(S.tex.placeholderIcon) end
end

-- The card is an opaque well that takes the mouse and the wheel, with a close button that stays still while the
-- card scrolls.
-- The template puts the button at frame level 510, above the window's trim.
-- The clip frame places, shows and clips the card, and reaches 1 px below it for the well's bottom corners.
function Vend:Build(parent)
    local clip = CreateFrame("Frame", nil, parent)
    clip:SetClipsChildren(true)
    clip:Hide()
    local card = W.Well(clip)
    card:SetPoint("TOPLEFT")
    card:SetPoint("BOTTOMRIGHT", 0, 1)
    card:SetFrameLevel(parent:GetFrameLevel() + LIFT)
    card:EnableMouse(true)
    local sf = CreateFrame("ScrollFrame", nil, card, "ScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", INSET, -INSET)
    sf:SetPoint("BOTTOMRIGHT", -(INSET + LO.scrollBarGap), INSET)
    sf.ScrollBar:SetHideIfUnscrollable(true)
    sf.ScrollBar:ClearAllPoints()
    sf.ScrollBar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 6, INSET - XPAD - XSIZE - SP.xs)
    sf.ScrollBar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 6, -2)
    card:EnableMouseWheel(true)
    card:SetScript("OnMouseWheel", function() end)
    V.close = CreateFrame("Button", nil, card, "UIPanelCloseButtonNoScripts")
    V.close:SetPoint("TOPRIGHT", -XPAD, -XPAD)
    V.close:SetScript("OnClick", function() Page:CloseCard() end)
    parent:HookScript("OnSizeChanged", function(_, w)
        if w <= 0 or (w == V.room and not V.wait) or not Layout() then return end
        V.room = w
        if vid and not torn then
            Fit()
            if V.wait or BodyWidth() ~= V.w then Draw(W.Owed(V.wait)) end
        end
    end)
    local body = CreateFrame("Frame", nil, sf)
    sf:SetScrollChild(body)
    V.clip, V.well, V.sf, V.c, V.head = clip, card, sf, body, CreateFrame("Frame", nil, body)
    V.face = V.head:CreateTexture(nil, "ARTWORK")
    V.face:SetSize(PORTRAIT, PORTRAIT)
    V.face:SetPoint("TOPLEFT")
    V.name, V.tag, V.where = Text(V.head, "subheader"), Text(V.head, "meta"), Text(V.head)
    V.name:SetPoint("TOPLEFT", PORTRAIT + SP.m, 0)
    V.tag:SetPoint("TOPLEFT", V.name, "BOTTOMLEFT", 0, -2)
    V.tag:SetTextColor(unpack(S.state.live.color))
    V.tag:SetText(W.StateWords("live"))
    V.wp = W.WaypointButton(V.head)
    V.wp:SetPoint("LEFT", V.where, "RIGHT", SP.xs, 0)
    V.note, V.cur, V.req, V.stop, V.conf = Text(body), Text(body), Text(body), Text(body), Text(body)
    V.conf.tip = Facts.NotConfirmed()
    for _, fs in ipairs({ V.name, V.where, V.conf }) do
        fs:SetWordWrap(false)
        local hit = W.Clip(fs)
        if fs == V.conf then V.hit = hit end
    end
    V.pb, V.can = W.Bar(V.head), CanLine(V.head)
    V.hdr, V.key = Text(body), Text(body)
    V.holder = CreateFrame("Frame", nil, body)
    V.grid = W.NewGrid(V.holder, S.ware.size, S.ware.gap)
    V.empty = W.NewEmptyState(V.holder)
    V.report = W.ReportLink(body, function() Report(V.s) end)
    V.stack = { V.head, V.note, V.cur, V.req, V.stop, V.conf, V.hdr, V.key, V.holder, V.report }
end

function Draw(fresh, saved)
    local v = D.Vendor(vid)
    if not v then return end
    if P:GetWidth() <= 0 then
        V.wait = W.Owe(V.wait, fresh, saved)
        V.clip:Hide()
        return
    end
    local w = BodyWidth()
    V.wait, V.w = nil, w
    local s = { vendor = v, type = "vendors", title = v.name or L["Unknown"], items = D.VendorWares(v) }
    V.s = s
    local rows = Rows(s, true)
    local ready = D.CollectionState() == "ready"
    local act = D.HolidayActive(v) and v.event or nil
    local n, owned = #rows, 0
    for _, r in ipairs(rows) do
        local e = CG.Entry(r.itemID)
        r.bonus, r.active, r.copies = e and e.bonus, act, select(2, D.IconData(r.itemID, true, B.State.catalogMemo))
        if r.state == "owned" then owned = owned + 1 end
    end

    local cw, nh, bh = w - PORTRAIT - SP.m - XRES, W.TextHeight("subheader"), W.TextHeight("body")
    SetFace(v)
    V.name:SetText(s.title)
    V.name:SetSize(cw, nh)
    V.tag:SetShown(act ~= nil)
    local tagH = act and W.TextHeight("meta", V.tag:GetText(), cw) or 0
    V.tag:SetSize(cw, tagH)
    local place = Facts.Where(v) or L["Unknown"]
    local cont = Facts.Nearness(v.mapID, Facts.Here()) == 3 and Continent(v.mapID)
    V.where:SetText(cont and L["%s · %s"]:format(place, cont) or place)
    V.where:SetSize(math.min(V.where:GetUnboundedStringWidth() + 1, cw - V.wp:GetWidth() - SP.xs), bh)
    V.where:ClearAllPoints()
    V.where:SetPoint("TOPLEFT", act and V.tag or V.name, "BOTTOMLEFT", 0, -SP.xs)
    local mapID, mx, my = Loc(s)
    V.wp:SetShown(mapID ~= nil)
    V.wp.wp = { mapID = mapID, x = mx, y = my, title = s.title, data = { type = "vendor", npcID = v.npcID } }
    -- The bar and the can-get line sit under the location, beside the portrait.
    V.pb:SetShown(n > 0)
    V.pb:SetWidth(cw)
    V.pb:Fit()
    V.pb:Set(ready and L["%d of %d collected"]:format(owned, n) or L["Counting…"], ready and n > 0 and owned / n)
    V.pb:ClearAllPoints()
    V.pb:SetPoint("TOPLEFT", V.where, "BOTTOMLEFT", 0, -SP.xs)
    SetCan(V.can, ready and CG.VendorCanCount(v) or 0, cw)
    V.can:ClearAllPoints()
    V.can:SetPoint("TOPLEFT", n > 0 and V.pb or V.where, "BOTTOMLEFT", 0, -SP.xs)
    V.head:SetSize(w, math.max(PORTRAIT, nh + (act and tagH + 2 or 0) + SP.xs + bh
        + (n > 0 and SP.xs + V.pb:GetHeight() or 0) + (V.can:IsShown() and SP.xs + V.can:GetHeight() or 0)))

    Line(V.note, "bodyMuted", (D.VendorNote(v)), w)
    local cur = D.VendorCurrencies(v)
    Line(V.cur, "body", cur[1] and L["%s: %s"]:format(S.Colored(K.gold, L["Currency"]), W.Join(cur, L["%s, %s"])), w)
    local parts, unknown = {}, false
    for _, r in ipairs(D.VendorRequirements(v)) do
        parts[#parts + 1] = r.met == true and L["%s (done)"]:format(r.text) or r.met == false and L["%s (not yet)"]:format(r.text) or r.text
        unknown = unknown or r.met == nil
    end
    Line(V.req, "body", parts[1] and L["%s: %s"]:format(S.Colored(K.gold, L["Requires"]), W.Join(parts, L["%s; %s"]))
        .. (unknown and "\n" .. S.Muted(L["Can't check this requirement yet"]) or ""), w)
    Line(V.stop, "body", D.IsOppositeFaction(v)
        and S.Colored(K.stop, L["%s only: can't buy on this character"]:format(D.VendorFactionLabel(v) or "")), w)
    Line(V.conf, "bodyMuted", not Facts.Confirmed(v) and L["Not confirmed: visit to check."], w)
    V.hit:SetShown(V.conf:IsShown())
    Line(V.hdr, "bodyGold", L["Wares"], w)
    Line(V.key, "bodyMuted", n > 0 and L["Corners: state top right, bonus top left, event bottom left, copies bottom right."], w)
    V.report:Fit()
    V.grid:SetShown(n > 0)
    V.grid:SetData(rows, not fresh, w - LO.scrollBarGap)
    if n > 0 then V.empty:Hide() else
        V.empty:Set("noResults", { title = L["No decor"], text = L["No decor is recorded here. If this source gives decor, report it below."] })
    end

    local h, y = P:GetHeight() - 2 * INSET, 0
    V.c:SetWidth(w)
    for _, el in ipairs(V.stack) do
        if el == V.holder then el:SetSize(w, math.max(FLOOR, h - y - V.report:GetHeight() - GAP)) end
        if el:IsShown() then
            el:ClearAllPoints()
            el:SetPoint("TOPLEFT", 0, -y)
            y = y + el:GetHeight() + GAP
        end
    end
    V.c:SetHeight(y - GAP)
    V.sf:UpdateScrollChildRect()
    if fresh then
        V.sf:SetVerticalScroll(saved and saved.outer or 0)
        if saved and saved.scroll then V.grid.box:ScrollToOffset(saved.scroll, true) end
    end
    V.clip:Show()
    if slide then
        slide = false
        B.Window.Slide(V.well, CardWidth())
    end
end

function Vend:Show(saved)
    V.wait = nil
    Draw(true, saved)
end

function Vend:Save()
    return { scroll = V.grid.box:GetDerivedScrollOffset(), outer = V.sf:GetVerticalScroll() }
end

function Vend:Refresh(reason, wasTorn)
    if not wasTorn and reason == "hide" then return end
    if not wasTorn and reason == "paint" then
        local v = D.Vendor(vid)
        if v then SetFace(v) end
        return W.RepaintRows(V.grid)
    end
    Draw(W.Owed(V.wait))
end

-- The page of one other source: the achievement, quest, recipe, drop, event or shop item. Its elements
-- hang from the one above, so a wrapped line pushes the rest down.
local Src, A = {}, {}
local srcID, srcType, srcTorn

local function PinLine(parent, role)
    local f = CreateFrame("Frame", nil, parent)
    f.role = role
    f.text = S.Text(f, role, "OVERLAY")
    f.text:SetWordWrap(false)
    f.text:SetPoint("LEFT")
    f.wp = W.WaypointButton(f)
    f.wp:SetPoint("LEFT", f.text, "RIGHT", SP.xs, 0)
    return f
end

-- No text hides the line; a spot puts the waypoint icon at the end of the text. The text is one line, cut off
-- where the icon and the page edge leave room.
local function SetPinLine(f, text, spot, title)
    f:SetShown(text ~= nil)
    if not text then return end
    f.text:SetText(text)
    local room = A.page:GetWidth() - f.wp:GetWidth() - SP.xs
    local width = f.text:GetUnboundedStringWidth() + 1
    f.text:SetWidth(math.max(room > 0 and math.min(width, room) or width, 1))
    f:SetHeight(math.max(f.wp:GetHeight(), W.TextHeight(f.role)))
    f.wp:SetShown(spot ~= nil)
    f.wp.wp = spot and { mapID = spot.mapID, x = spot.x, y = spot.y, title = title } or nil
end

-- The source of that type and key, named as the page and the crumb show it; nil when the data has none.
local function Source(sourceType, key)
    local bucket = Statics()[sourceType]
    local s = bucket and bucket.by[key]
    if s and sourceType == "shop" then ShopTitle(s) end
    return s
end

function B.SourceTitle(sourceType, key)
    local s = Source(sourceType, key)
    return s and s.title or L["Unknown"]
end

function Src:Build(parent)
    A.page = parent
    A.head = CreateFrame("Frame", nil, parent)
    A.name = Text(A.head, "subheader")
    A.name:SetWordWrap(false)
    W.Clip(A.name)
    A.name:SetPoint("TOPLEFT")
    A.name:SetPoint("TOPRIGHT")
    A.sub = PinLine(A.head, "metaMuted")
    A.sub:SetPoint("TOPLEFT", A.name, "BOTTOMLEFT", 0, -2)
    A.sub:SetPoint("TOPRIGHT", A.name, "BOTTOMRIGHT", 0, -2)
    A.start, A.dig = PinLine(parent, "body"), PinLine(parent, "body")
    A.event, A.notes, A.hdr = Text(parent), Text(parent), Text(parent)
    A.count = Text(parent)
    A.can = CanLine(parent)
    A.holder = CreateFrame("Frame", nil, parent)
    A.list = W.NewList(A.holder, { extent = W.RowHeight, kinds = { row = W.rowKind }, reclaim = true })
    A.report = W.ReportLink(parent, function() Report(A.s) end)
    A.report:SetPoint("BOTTOMLEFT")
    A.stack = { A.head, A.start, A.dig, A.event, A.notes, A.count, A.can, A.hdr }
end

local function Stack()
    local prev
    for _, el in ipairs(A.stack) do
        if el:IsShown() then
            el:ClearAllPoints()
            local to, left, right, gap = A.page, "TOPLEFT", "TOPRIGHT", 0
            if prev then to, left, right, gap = prev, "BOTTOMLEFT", "BOTTOMRIGHT", -SP.xs end
            el:SetPoint("TOPLEFT", to, left, 0, gap)
            el:SetPoint("TOPRIGHT", to, right, 0, gap)
            prev = el
        end
    end
    A.holder:ClearAllPoints()
    A.holder:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -SP.s)
    A.holder:SetPoint("BOTTOMRIGHT", A.page, "BOTTOMRIGHT", 0, A.report:GetHeight() + SP.s)
end

local function DrawSource(keep)
    local s = Source(srcType, srcID)
    cs, A.s = D.CollectionState(), s
    local kind = KIND[srcType][1]
    A.name:SetText(s.title)
    local mapID, x, y = Loc(s)
    -- The subtitle names the kind once: a sub that is the kind, or already names it, stands alone.
    local sub = s.namesKind and s.sub or s.sub and s.sub ~= kind and L["%s · %s"]:format(kind, s.sub) or kind
    SetPinLine(A.sub, sub, mapID and { mapID = mapID, x = x, y = y }, s.title)
    A.head:SetHeight(W.TextHeight("subheader") + 2 + A.sub:GetHeight())

    local start, dig = s.questID and Facts.QuestStart(s.questID), s.questID and Facts.TreasureSpot(s.questID)
    SetPinLine(A.start, start and L["Starts in %s"]:format(MapName(start.mapID) or L["Unknown"]), start, s.title)
    SetPinLine(A.dig, dig and L["Dig site in %s"]:format(MapName(dig.mapID) or L["Unknown"]), dig, s.title)
    Para(A.event, "body", srcType == "events" and (Live(s.key) and S.Colored(K.badge, L["Active now"]) or L["Not active"]) or nil)
    Para(A.notes, "body", s.drop and s.drop.notes and S.Muted(s.drop.notes))

    local rows = Rows(s)
    local total, got, can = Stats(s)
    Para(A.count, "body", total > 0 and (got and L["%d of %d collected"]:format(got, total) or L["Counting…"]) or nil)
    SetCan(A.can, can or 0)
    Para(A.hdr, #rows > 0 and "bodyGold" or "bodyMuted",
        #rows > 0 and L["Decor from this source"] or L["No decor is recorded here. If this source gives decor, report it below."])
    A.report:Fit()
    A.list:SetShown(#rows > 0)
    if #rows > 0 then A.list:SetData(rows, keep) end
    Stack()
end

function Src:Has(route)
    return Source(route.key, route.id) ~= nil
end

function Src:Show(route, saved)
    srcType, srcID, srcTorn = route.key, route.id, false
    DrawSource(false)
    if saved and saved.scroll then A.list.box:ScrollToOffset(saved.scroll, true) end
end

function Src:Save()
    return { scroll = A.list.box:GetDerivedScrollOffset() }
end

function Src:Hide()
    srcTorn = true
    B.HideTooltip()
end

function Src:Refresh(reason)
    if not (A.list and srcID) then return end
    if reason == "data" then B.Walk() end
    if not srcTorn and reason == "hide" then return end
    if not srcTorn and reason == "paint" then return W.RepaintRows(A.list) end
    srcTorn = false
    DrawSource(true)
end

function Src:SetCombat(inCombat)
    if A.report then A.report:SetEnabled(not inCombat) end
end

B.RegisterPage("sources", Page)
B.RegisterPage("vendors", Page)
B.RegisterPage("allVendors", Page)
B.RegisterPage("vendor", Page)
B.RegisterPage("source", Src)
