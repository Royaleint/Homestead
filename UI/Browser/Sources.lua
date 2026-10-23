-- Sources: seven source lists with a detail pane, and the vendor page. Rows are keyed by Facts.SourceKey.
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
    achievements = { L["Achievement"], L["Search achievements"], "AchievementSources",
        function(d) return { title = d.achievementName, sub = d.category or L["Achievement"], group = d.category or L["Other"] } end },
    quests = { L["Quest"], L["Search quests"], "QuestSources", function(d)
        local at = Facts.TreasureSpot(d.questID) or Facts.QuestStart(d.questID)
        return { title = d.questName, sub = MapName(at and at.mapID) or L["Quest"], questID = d.questID }
    end },
    professions = { L["Profession"], L["Search recipes and professions"], "ProfessionSources",
        function(d) return { title = d.recipeName, sub = d.skillTier or d.profession, group = d.profession } end },
    drops = { L["Drop"], L["Search drops and zones"], "DropSources",
        function(d) return { title = d.mobName, sub = d.zone, drop = d } end },
    events = { L["Event"], L["Search events"], "EventSources",
        function(d) return { title = d.event, sub = L["Holiday event"] } end },
    shop = { L["Shop"], L["Search the Shop"], "ShopSources", function() return { sub = L["Shop"] } end },
}
local TYPES = CG.SOURCE_KEYS
local IW = S.cols.detail - 2 * SP.m

local Tab = {}
local st = { type = "vendors", q = {}, sel = {} }
local c, box, head, list, empty, torn, asked, cs, static, vend, vendVer
local U = {}

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

local function Vendors()
    local version = D.MemoVersion()
    if vend and vendVer == version then return vend end
    vend, vendVer = { by = {} }, version
    for _, v in ipairs(D.ListedVendors()) do
        local key = Facts.SourceKey("vendors", v)
        local s = {
            key = key, type = "vendors", vendor = v, title = v.name or L["Unknown"], items = D.VendorWares(v),
            sub = Where(v) or "",
        }
        vend.by[key], vend[#vend + 1] = s, s
    end
    return vend
end

local function Src(t)
    return t == "vendors" and Vendors() or Statics()[t]
end

local function Current()
    return Src(st.type).by[st.sel[st.type]]
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
        onClick = function() if v then B.Go({ kind = "vendor", id = s.key }) else Tab.Select(s.key) end end,
    }
end

local function Place(s, where)
    s.o, s.g, s.z = 0, s.group, ""
    if s.type == "vendors" then
        local v = s.vendor
        local near = v.mapID and Facts.Nearness(v.mapID, where) or 4
        s.z = v.zone or ""
        if near == 1 then
            s.g = L["Here in %s"]:format(where.name or s.z)
        else
            local name = Continent(v.mapID)
            s.g = name or L["Location not recorded"]
            s.o = not name and 4 or near == 2 and 1 or 2
        end
    elseif s.type == "events" then
        s.o = Live(s.key) and 0 or 1
    end
end

local function Before(a, b)
    if a.o ~= b.o then return a.o < b.o end
    local ga, gb = a.g or "", b.g or ""
    if ga ~= gb then return ga < gb end
    if a.z ~= b.z then return a.z < b.z end
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

local function BuildList(keep)
    asked, cs = false, D.CollectionState()
    local t, hide = st.type, B.State.hideNA
    local q = (st.q[t] or ""):lower()
    local where = t == "vendors" and Facts.Here() or nil
    local out, live = {}, false
    local hidden, seen = { kind = "foot", hidden = 0, collected = 0, faction = 0, onShow = ShowHidden }, {}
    for _, s in ipairs(Src(t)) do
        if t == "shop" then s.title = D.ItemName(s.items[1]) or L["Item %d"]:format(s.items[1]) end
        live = live or (t == "events" and Live(s.key))
        local v = s.vendor
        if q == "" or (s.title .. " " .. (s.sub or "") .. " " .. (s.group or "") .. " " .. (v and v.zone or "")):lower():find(q, 1, true) then
            local why = hide and s.key ~= st.pin and CG.HiddenBy(v and { vendor = v } or { items = s.items })
            if why then
                hidden.hidden = hidden.hidden + 1
                hidden[why] = hidden[why] + 1
                if why == "faction" then
                    local label = v and D.VendorFactionLabel(v) or ""
                    seen[label] = (seen[label] or 0) + 1
                end
            else
                out[#out + 1] = s
                Place(s, where)
            end
        end
    end
    hidden.parts = Facts.FactionParts(seen)
    table.sort(out, Before)
    local sel, found = st.sel[t], false
    for _, s in ipairs(out) do found = found or s.key == sel end
    sel = found and sel or out[1] and out[1].key
    st.sel[t] = sel
    local data, group = {}, nil
    if t == "events" and not live then
        data[1] = { kind = "foot", text = L["No events active right now. Event decor is sold only while its event runs."] }
    end
    for _, s in ipairs(out) do
        if s.g and s.g ~= group then
            group = s.g
            data[#data + 1] = { kind = "header", text = group }
        end
        local d = RowData(s)
        d.selected = s.key == sel
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
            onReset = q ~= "" and function() box:SetText("") end or nil,
        })
    end
    head:SetHeight(W.TextHeight("bodyMuted") + SP.s)
    head:SetText(Head(t))
end

local function Line(fs, role, text, w)
    fs:SetShown(text and true or false)
    if text then
        fs:SetFontObject(S.font[role])
        fs:SetText(text)
        fs:SetSize(w or IW, W.TextHeight(role, text, w or IW))
    end
end

local function Rows(s, cells)
    local v, rows = s.vendor, {}
    for _, itemID in ipairs(s.items) do
        local e = CG.Entry(itemID)
        local info = e and e.info
        local state, arg = B.ItemState(itemID, v and v.npcID)
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

local function SetHead(s)
    U.name:SetText(s.title)
    local h = W.TextHeight("subheader", s.title, IW)
    U.name:SetHeight(h)
    U.meta:SetText(KIND[s.type][1])
    U.head:SetSize(IW, h + W.TextHeight("meta") + 2)
end

local function Lines(s, total, got, can)
    local out = {}
    if s.type == "events" then
        out[1] = Live(s.key) and S.Colored(K.badge, L["Active now"]) or L["Not active"]
    elseif s.type ~= "shop" then
        out[1] = s.sub and S.Muted(s.sub)
        out[2] = s.drop and s.drop.notes and S.Muted(s.drop.notes)
    end
    if total > 0 then
        local text = L["Gives %d decor."]:format(total)
        if got then text = text .. " " .. L["You have %d."]:format(got) end
        if can and can > 0 then text = text .. " " .. S.Colored(K.can, L["%d you can get now."]:format(can))
        elseif cs == "counting" then text = text .. " " .. L["Counting…"] end
        out[5] = text
    end
    return out
end

local function Loc(s)
    local v, d = s.vendor, s.drop
    if v then return D.VendorLocation(v) end
    if d and d.coords and not (d.journalEncounterID or d.journalInstanceID) then return d.mapID, d.coords.x, d.coords.y end
end

local function Fill(s)
    local els = { U.head, U.i1, U.i2, U.i3, U.i4, U.i5, U.q1, U.q2, U.go, U.hdr }
    for _, el in ipairs(els) do el:Hide() end
    local rows = s and Rows(s) or {}
    U.report:SetShown(s ~= nil)
    if not s then
        Line(U.hdr, "bodyMuted", L["Pick a source to see its decor."])
    else
        local v = s.vendor
        SetHead(s)
        U.head:Show()
        local lines = Lines(s, Stats(s))
        for i = 1, 5 do Line(U["i" .. i], "body", lines[i]) end
        local qs, ts = s.questID and Facts.QuestStart(s.questID), s.questID and Facts.TreasureSpot(s.questID)
        for i = 1, 2 do
            local spot, f = (i == 1 and qs) or (i == 2 and ts) or nil, U["q" .. i]
            f:SetShown(spot ~= nil)
            if spot then
                local text = (i == 1 and L["Starts in %s"] or L["Dig site in %s"]):format(MapName(spot.mapID) or L["Unknown"])
                f.text:SetText(text)
                f:SetHeight(math.max(26, W.TextHeight("body", text, IW - 30)))
                f.wp.wp = { mapID = spot.mapID, x = spot.x, y = spot.y, title = s.title }
            end
        end
        local mapID, x, y = Loc(s)
        U.go:SetShown(mapID ~= nil)
        U.go.target = { mapID = mapID, x = x, y = y, title = s.title, data = v and { type = "vendor", npcID = v.npcID } or nil }
        Line(U.hdr, #rows > 0 and "bodyGold" or "bodyMuted", #rows > 0 and L["Decor from this source"]
            or L["No decor is recorded here. If this source gives decor, report it below."])
    end
    local top = SP.m
    for _, el in ipairs(els) do
        if el:IsShown() then
            el:ClearAllPoints()
            el:SetPoint("TOPLEFT", c.detail, "TOPLEFT", SP.m, -top)
            top = top + el:GetHeight() + SP.xs
        end
    end
    U.report:Fit()
    U.lh:ClearAllPoints()
    U.lh:SetPoint("TOPLEFT", c.detail, "TOPLEFT", SP.m, -top)
    U.lh:SetPoint("BOTTOMRIGHT", c.detail, "BOTTOMRIGHT", -SP.m, U.report:GetHeight() + 2 * SP.s)
    U.list:SetShown(#rows > 0)
    if #rows > 0 then U.list:SetData(rows) end
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
    fs:SetWidth(IW)
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

local function BuildDetail(pane)
    U.head = CreateFrame("Frame", nil, pane)
    U.name, U.meta = Text(U.head, "subheader"), Text(U.head, "metaMuted")
    U.name:SetPoint("TOPLEFT")
    U.meta:SetPoint("TOPLEFT", U.name, "BOTTOMLEFT", 0, -2)
    for i = 1, 5 do U["i" .. i] = Text(pane) end
    U.hdr = Text(pane)
    for i = 1, 2 do
        local f = CreateFrame("Frame", nil, pane)
        f:SetSize(IW, 26)
        f.text = S.Text(f, "body", "OVERLAY")
        f.text:SetPoint("LEFT")
        f.text:SetWidth(IW - 30)
        f.text:SetJustifyH("LEFT")
        f.wp = W.WaypointButton(f)
        f.wp:SetPoint("RIGHT")
        U["q" .. i] = f
    end
    U.go = W.NewButton(pane, L["Set waypoint"], function(self)
        local w = self.target
        if w then HA.Waypoints:Set(w.mapID, w.x, w.y, { title = w.title, data = w.data }) end
    end)
    U.lh = CreateFrame("Frame", nil, pane)
    U.list = W.NewList(U.lh, { extent = W.RowHeight, kinds = { row = W.rowKind }, reclaim = true })
    U.report = ReportButton(pane, Current)
    U.report:SetPoint("BOTTOMLEFT", SP.m, SP.s)
end

local function Rebuild(keep)
    BuildList(keep)
    Fill(Current())
end

function Tab.Select(key)
    st.sel[st.type] = key
    Rebuild(true)
end

local function SetType(t)
    st.type = t
    box.Instructions:SetText(KIND[t][2])
    box:SetText(st.q[t] or "")
end

function Tab.Build(parent)
    c = W.NewColumns(parent)
    box = W.NewSearchBox(c.toolbar, KIND.vendors[2], function(text)
        if text == (st.q[st.type] or "") then return end
        st.q[st.type] = text
        Rebuild(false)
    end)
    box:SetPoint("TOPLEFT", c.toolbar, "TOPLEFT", SP.s, -SP.xs)
    box:SetPoint("TOPRIGHT", c.toolbar, "TOPRIGHT", -SP.xs, -SP.xs)
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
    BuildDetail(c.detail)
end

-- A table is a landing: sets the type, its search and maybe a row.
function Tab.Show(opts)
    local key = opts and opts.select and opts.select.key
    if opts then
        if KIND[opts.type] then st.type = opts.type end
        st.q[st.type] = not key and opts.search or ""
        st.sel[st.type], st.pin = key, key
        SetType(st.type)
    end
    torn = false
    c:Fit()
    Rebuild(opts == nil)
    if key then
        local idx = list.box:FindElementDataIndexByPredicate(function(d) return d.key == st.sel[st.type] end)
        if idx then list.box:ScrollToElementDataIndex(idx) end
    end
end

function Tab.Hide()
    torn = true
end

function Tab.Refresh(reason)
    if not c then return end
    if reason == "data" then B.Walk() end
    if reason == "paint" and not torn then
        W.RepaintRows(list)
        W.RepaintRows(U.list)
        if Current() then SetHead(Current()) end
        return
    end
    if reason == "layout" then c:Fit() end
    torn = false
    Rebuild(true)
end

function Tab.SetCombat(inCombat)
    if U.report then U.report:SetEnabled(not inCombat) end
end

-- The vendor page is one scroll, so a large text size scrolls the page instead of clipping the head.
local Vend, V = {}, {}
local vid, vtorn
local PORTRAIT, FLOOR, GAP = 88, 2 * S.ware.size + S.ware.gap, SP.s
local Draw

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
            V.wait = nil
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
    V.can = CreateFrame("Frame", nil, body)
    V.dot = V.can:CreateTexture(nil, "OVERLAY")
    V.dot:SetSize(12, 12)
    V.dot:SetPoint("LEFT")
    Vis.Marker.Set(V.dot, S.state.some.glyph, S.state.some.color)
    V.canText = Text(V.can)
    V.canText:SetPoint("LEFT", 16, 0)
    V.canText:SetTextColor(unpack(S.state.some.color))
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
    V.w = w
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
    local can = ready and CG.VendorCanCount(v) or 0
    V.can:SetShown(can > 0)
    V.can:SetSize(w, bh)
    V.canText:SetText(W.StateWords("some", can))
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

B.RegisterTab("sources", Tab)
B.RegisterPage("vendor", Vend)
