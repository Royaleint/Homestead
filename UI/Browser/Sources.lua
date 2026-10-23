-- Sources: the vendor lists (all vendors, one expansion), the six other source lists, the vendor page and the
-- page of one other source. One page serves the sources, vendors and allVendors routes. Rows are keyed by
-- Facts.SourceKey.
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

-- The game's own tooltip for the sources it describes.
local LINK = {
    achievements = function(s) return GetAchievementLink(s.achievementID) end,
    quests = function(s) return GetQuestLink(s.questID) or ("quest:" .. s.questID) end,
}

local Page = {}
local st = { type = "achievements" }
local now, query, wide = nil, "", false
local c, head, list, empty, torn, asked, cs, static, vend, vendVer

local function Live(event)
    local CD = HA.CalendarDetector
    return CD ~= nil and CD:IsHolidayActive(event) == true
end

local function Where(v)
    return v.zone and v.subzone and L["%s, %s"]:format(v.subzone, v.zone) or v.zone
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

-- One entry per listed vendor of the list, all of them or one expansion's. Wares are read only for these, so
-- opening one expansion never reads the others; each vendor's entry lasts one memo version.
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
                    sub = Where(v) or "",
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
        right = total == 0 and L["No decor"] or got and L["%d of %d"]:format(got, total) or L["%d decor"]:format(total),
        unconfirmed = v and not Facts.Confirmed(v) or nil,
        onClick = function() B.Go(v and { kind = "vendor", id = s.key } or { kind = "source", key = s.type, id = s.key }) end,
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
    if d.kind == "header" then return W.HeaderHeight() end
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

-- Returns the index of the header of the zone (a map id) when given and the list has a vendor in it.
local function BuildList(keep, zone)
    asked, cs = false, D.CollectionState()
    local t, hide = wide and "vendors" or st.type, B.State.hideNA
    local landed = not wide and st.pin and st.pin.type == t and st.pin.key or nil
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
            local why = hide and landed ~= s.key and CG.HiddenBy(v and { vendor = v } or { items = s.items })
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
    local data, group, expansion, headAt, zoneAt = {}, nil, nil, nil, nil
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
        local d = RowData(s)
        d.selected = landed == s.key
        data[#data + 1] = d
    end
    local note = hidden.hidden > 0 and hidden or nil
    if note and #out > 0 then data[#data + 1] = note end
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
    return zoneAt
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
            onClick = function() B.ShowTab("catalog", { itemID = itemID }) end,
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

local function Text(parent, role)
    local fs = S.Text(parent, role or "body", "OVERLAY")
    fs:SetJustifyH("LEFT")
    return fs
end

local function ReportButton(parent, current)
    local b = W.NewLink(parent, L["Report a problem"], function() Report(current()) end, function(self)
        if not B.InCombat() then return end
        local tip = B.Tooltip()
        tip:SetOwner(self, "ANCHOR_RIGHT")
        tip:SetText(L["Not available in combat"])
        tip:Show()
    end)
    b:SetMotionScriptsWhileDisabled(true)
    return b
end

-- A source list keeps the detail column (empty until the lists take the whole page); a vendor list has none.
local function Layout()
    c.detail:SetShown(not wide)
    c.list:ClearAllPoints()
    c.list:SetPoint("TOPLEFT")
    if wide then
        c.list:SetPoint("BOTTOMRIGHT")
    else
        c.list:SetPoint("BOTTOMRIGHT", c.detail, "BOTTOMLEFT", -S.cols.gap, 0)
    end
end

function Page:Build(parent)
    c = W.NewColumns(parent)
    c.toolbar:Hide()
    c.body:ClearAllPoints()
    c.body:SetPoint("TOPLEFT")
    c.body:SetPoint("BOTTOMRIGHT")
    head = S.Text(c.body, "bodyMuted", "OVERLAY")
    head:SetPoint("TOPLEFT", S.layout.wellPad, -S.layout.wellPad)
    head:SetPoint("TOPRIGHT", -S.layout.wellPad, -S.layout.wellPad)
    head:SetJustifyH("LEFT")
    head:SetWordWrap(false)
    local lh = CreateFrame("Frame", nil, c.body)
    lh:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -SP.xs)
    lh:SetPoint("BOTTOMRIGHT", -S.layout.wellPad, S.layout.wellPad)
    list = W.NewList(lh, {
        extent = Extent, reclaim = true,
        kinds = { row = W.rowKind, header = W.headerKind, foot = footKind },
    })
    empty = W.NewEmptyState(lh)
end

-- A source route with no usable key keeps the type the player last had.
local function TypeOf(route)
    local key = route.key
    return key ~= "vendors" and KIND[key] and key or st.type
end

function Page:Placeholder(route)
    return KIND[route.kind == "sources" and TypeOf(route) or "vendors"][2]
end

-- An expansion with no listed vendor left is gone: the router falls back to all vendors.
function Page:Has(route)
    if route.kind ~= "vendors" then return true end
    for _, e in ipairs(D.Expansions()) do
        if e == route.key then return true end
    end
    return false
end

-- A forward Show starts from the route's seed (search, zone, or the legacy type and select); Back gives saved.
function Page:Show(route, saved)
    local seed = route.seed
    now, wide, torn = route, route.kind ~= "sources", false
    local pick
    if not wide then
        st.type = TypeOf(route)
        pick = seed and seed.select and seed.select.key
        -- The landed row is lit and exempt from Hide for this one landing; every later Show of a list drops it.
        st.pin = pick and { type = st.type, key = pick } or nil
    end
    query = saved and saved.search or not pick and seed and seed.search or ""
    B.Window.SetSearch(query)
    Layout()
    c:Fit()
    local at = BuildList(false, seed and seed.zone)
    if saved and saved.scroll then
        list.box:ScrollToOffset(saved.scroll, true)
    elseif at then
        list.box:ScrollToElementDataIndex(at, ScrollBoxConstants.AlignBegin)
    elseif pick then
        local idx = list.box:FindElementDataIndexByPredicate(function(d) return d.key == pick end)
        if idx then list.box:ScrollToElementDataIndex(idx) end
    end
end

function Page:Save()
    return { search = query, scroll = list.box:GetDerivedScrollOffset() }
end

function Page:Filter(text)
    if text == query then return end
    query, torn = text, false
    BuildList(false)
end

function Page:Hide()
    torn = true
    B.HideTooltip()
end

function Page:Refresh(reason)
    if not (c and now) then return end
    if reason == "data" then B.Walk() end
    if reason == "paint" and not torn then
        return W.RepaintRows(list)
    end
    if reason == "layout" then c:Fit() end
    torn = false
    BuildList(true)
end

-- The lists have no control that waits for the end of combat.
function Page:SetCombat() end

-- The vendor page is one scroll, so a large text size scrolls the page instead of clipping the head.
local Vend, V = {}, {}
local vid, vtorn
local PORTRAIT, FLOOR, GAP, DOT = 88, 2 * S.ware.size + S.ware.gap, SP.s, 12
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

-- A tooltip for a one-line text that is cut off, or always when fs.tip is set. Returns the mouse frame.
local function Clip(fs)
    local hit = CreateFrame("Frame", nil, fs:GetParent())
    hit:SetAllPoints(fs)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", function(self)
        local text = fs.tip or fs:IsTruncated() and fs:GetText()
        if text then
            local tip = B.Tooltip()
            tip:SetOwner(self, "ANCHOR_RIGHT")
            tip:SetText(text, nil, nil, nil, nil, true)
            tip:Show()
        end
    end)
    hit:SetScript("OnLeave", B.HideTooltip)
    return hit
end

local function Joined(items, format)
    local out = items[1]
    for i = 2, #items do out = format:format(out, items[i]) end
    return out
end

local function SetFace(v)
    local face = Facts.Portrait(v.npcID)
    if face then SetPortraitTextureFromCreatureDisplayID(V.face, face) else V.face:SetTexture(S.tex.placeholderIcon) end
end

function Vend:Build(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent, "ScrollFrameTemplate")
    sf:SetPoint("TOPLEFT")
    sf:SetPoint("BOTTOMRIGHT", -LO.scrollBarGap, 0)
    sf.ScrollBar:SetHideIfUnscrollable(true)
    sf:HookScript("OnSizeChanged", function(_, w)
        if vid and not vtorn and w > 0 and (V.wait or w ~= V.w) then
            local again = V.wait
            Draw(again and again[1] or false, again and again[2])
        end
    end)
    local body = CreateFrame("Frame", nil, sf)
    sf:SetScrollChild(body)
    V.sf, V.c, V.head = sf, body, CreateFrame("Frame", nil, body)
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
        local hit = Clip(fs)
        if fs == V.conf then V.hit = hit end
    end
    V.pb, V.hdr, V.key = W.Bar(body), Text(body), Text(body)
    V.can = CanLine(body)
    V.holder = CreateFrame("Frame", nil, body)
    V.grid = W.NewGrid(V.holder, S.ware.size, S.ware.gap)
    V.empty = W.NewEmptyState(V.holder)
    V.report = ReportButton(body, function() return V.s end)
    V.stack = { V.head, V.note, V.cur, V.req, V.stop, V.conf, V.pb, V.can, V.hdr, V.key, V.holder, V.report }
end

function Draw(fresh, saved)
    local v, w = D.Vendor(vid), V.sf:GetWidth()
    if not v then return end
    if w <= 0 then
        V.wait = { fresh, saved }
        return
    end
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

    local cw, nh, bh = w - PORTRAIT - SP.m, W.TextHeight("subheader"), W.TextHeight("body")
    SetFace(v)
    V.name:SetText(s.title)
    V.name:SetSize(cw, nh)
    V.tag:SetShown(act ~= nil)
    local tagH = act and W.TextHeight("meta", V.tag:GetText(), cw) or 0
    V.tag:SetSize(cw, tagH)
    local place = Where(v) or L["Unknown"]
    local cont = Facts.Nearness(v.mapID, Facts.Here()) == 3 and Continent(v.mapID)
    V.where:SetText(cont and L["%s · %s"]:format(place, cont) or place)
    V.where:SetSize(math.min(V.where:GetUnboundedStringWidth() + 1, cw - V.wp:GetWidth() - SP.xs), bh)
    V.where:ClearAllPoints()
    V.where:SetPoint("TOPLEFT", act and V.tag or V.name, "BOTTOMLEFT", 0, -SP.xs)
    local mapID, mx, my = Loc(s)
    V.wp:SetShown(mapID ~= nil)
    V.wp.wp = { mapID = mapID, x = mx, y = my, title = s.title, data = { type = "vendor", npcID = v.npcID } }
    V.head:SetSize(w, math.max(PORTRAIT, nh + (act and tagH + 2 or 0) + SP.xs + bh))

    Line(V.note, "bodyMuted", (D.VendorNote(v)), w)
    local cur = D.VendorCurrencies(v)
    Line(V.cur, "body", cur[1] and L["%s: %s"]:format(S.Colored(K.gold, L["Currency"]), Joined(cur, L["%s, %s"])), w)
    local parts, unknown = {}, false
    for _, r in ipairs(D.VendorRequirements(v)) do
        parts[#parts + 1] = r.met == true and L["%s (done)"]:format(r.text) or r.met == false and L["%s (not yet)"]:format(r.text) or r.text
        unknown = unknown or r.met == nil
    end
    Line(V.req, "body", parts[1] and L["%s: %s"]:format(S.Colored(K.gold, L["Requires"]), Joined(parts, L["%s; %s"]))
        .. (unknown and "\n" .. S.Muted(L["Can't check this requirement yet"]) or ""), w)
    Line(V.stop, "body", D.IsOppositeFaction(v)
        and S.Colored(K.stop, L["%s only: can't buy on this character"]:format(D.VendorFactionLabel(v) or "")), w)
    Line(V.conf, "bodyMuted", not Facts.Confirmed(v) and L["Not confirmed: visit to check."], w)
    V.hit:SetShown(V.conf:IsShown())
    V.pb:SetShown(n > 0)
    V.pb:SetWidth(w)
    V.pb:Fit()
    V.pb:Set(ready and L["%d of %d collected"]:format(owned, n) or L["Counting…"], ready and n > 0 and owned / n)
    SetCan(V.can, ready and CG.VendorCanCount(v) or 0, w)
    Line(V.hdr, "bodyGold", L["Wares"], w)
    Line(V.key, "bodyMuted", n > 0 and L["Corners: state top right, bonus top left, event bottom left, copies bottom right."], w)
    V.report:Fit()
    V.grid:SetShown(n > 0)
    V.grid:SetData(rows, not fresh, w - LO.scrollBarGap)
    if n > 0 then V.empty:Hide() else
        V.empty:Set("noResults", { title = L["No decor"], text = L["No decor is recorded here. If this source gives decor, report it below."] })
    end

    local h, y = V.sf:GetHeight(), 0
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
end

function Vend:Has(route)
    return D.Vendor(route.id) ~= nil
end

function Vend:Show(route, saved)
    vid, vtorn = route.id, false
    Draw(true, saved)
end

function Vend:Save()
    return { scroll = V.grid.box:GetDerivedScrollOffset(), outer = V.sf:GetVerticalScroll() }
end

function Vend:Hide()
    vtorn = true
    B.HideTooltip()
end

function Vend:Refresh(reason)
    if not (V.c and vid) then return end
    if reason == "data" then B.Walk() end
    if not vtorn and reason == "hide" then return end
    if not vtorn and reason == "paint" then
        local v = D.Vendor(vid)
        if v then SetFace(v) end
        return W.RepaintRows(V.grid)
    end
    vtorn = false
    Draw(false)
end

function Vend:SetCombat(inCombat)
    if V.report then V.report:SetEnabled(not inCombat) end
end

-- The page of one other source: the achievement, quest, recipe, drop, event or shop item. Its elements stack
-- from the top, each hanging from the one above, so a wrapped line pushes the rest down; the decor list takes
-- what is left above the report link.
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
    Clip(A.name)
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
    A.report = ReportButton(parent, function() return A.s end)
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
B.RegisterPage("vendor", Vend)
B.RegisterPage("source", Src)
