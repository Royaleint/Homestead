-- Sources tab: seven kinds of source, each a grouped list with a detail pane. Rows are keyed by Facts.SourceKey.
local _, HA = ...

local B = HA.DecorBrowser
local L, S, W = HA.L, B.Style, B.Widgets
local D, CG, Facts = B.Data, B.CanGet, B.Facts
local SP, K = S.space, S.color

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
local c, box, list, empty, torn, asked, cs, static, vend, vendVer, model
local navs, U = {}, {}

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
        unconfirmed = v and not Facts.Confirmed(v) or nil, onClick = function() Tab.Select(s.key) end,
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
    local h = W.TextHeight("body") + SP.m
    for i, k in ipairs(TYPES) do
        local b = navs[k]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", c.nav, "TOPLEFT", 0, -(i - 1) * h)
        b:SetPoint("TOPRIGHT", c.nav, "TOPRIGHT", 0, -(i - 1) * h)
        b:SetHeight(h)
        b.bg:SetShown(k == t)
        b.count:SetText(tostring(#Src(k)))
    end
end

local function ShowModel(npcID)
    if not model then
        model = CreateFrame("PlayerModel", nil, U.mb)
        model:SetPoint("TOPLEFT", 6, -6)
        model:SetPoint("BOTTOMRIGHT", -6, 6)
        model:SetScript("OnModelLoaded", function(self)
            if self.npcID and self.gen == B.Generation() then U.ph:Hide() end
        end)
    end
    if model.npcID == npcID and model.gen == B.Generation() and model:IsShown() then return end
    model.gen, model.npcID = B.Generation(), npcID
    U.ph:Show()
    model:Show()
    model:ClearModel()
    model:SetCreature(npcID)
    model:SetPortraitZoom(0.7)
    C_Timer.After(1, function()
        if model.npcID == npcID and model.gen == B.Generation() and model:GetModelFileID() then U.ph:Hide() end
    end)
end

local function ClearModel()
    if not model then return end
    model.gen, model.npcID = nil, nil
    model:ClearModel()
    model:Hide()
    U.ph:Show()
end

local function Line(fs, role, text)
    fs:SetShown(text ~= nil)
    if text then
        fs:SetFontObject(S.font[role])
        fs:SetText(text)
        fs:SetHeight(W.TextHeight(role, text, IW))
    end
end

local function Rows(s)
    local v, rows = s.vendor, {}
    for _, itemID in ipairs(s.items) do
        local e = CG.Entry(itemID)
        local info = e and e.info
        local state, arg = B.ItemState(itemID, v and v.npcID)
        rows[#rows + 1] = {
            kind = "row", name = D.ItemName(itemID, info) or L["Item %d"]:format(itemID),
            rank = state == "can" and 1 or state == "owned" and 3 or 2,
            quality = info and info.quality or C_Item.GetItemQualityByID(itemID), icon = D.ItemIcon(itemID),
            itemID = itemID, npcID = v and v.npcID, state = state, arg = arg, right = v and D.Price(itemID, v),
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
    local v = s.vendor
    local face = v and Facts.Portrait(v.npcID)
    U.face:SetShown(v ~= nil)
    if face then SetPortraitTextureFromCreatureDisplayID(U.face, face) elseif v then U.face:SetTexture(S.tex.placeholderIcon) end
    local x = v and 44 or 0
    U.name:ClearAllPoints()
    U.name:SetPoint("TOPLEFT", U.head, "TOPLEFT", x, 0)
    U.name:SetWidth(IW - x)
    U.name:SetText(s.title)
    local h = W.TextHeight("subheader", s.title, IW - x)
    U.name:SetHeight(h)
    U.meta:SetText(KIND[s.type][1])
    U.head:SetSize(IW, math.max(x, h + W.TextHeight("meta") + 2))
end

local function Lines(s, total, got, can)
    local v, out = s.vendor, {}
    if v then
        local label = D.VendorFactionLabel(v)
        local note, conf = D.VendorNote(v), Facts.Confirmed(v)
        local cont = Continent(v.mapID)
        out[1] = (Where(v) or L["Unknown"]) .. (cont and ("\n" .. S.Muted(cont)) or "")
        if D.IsOppositeFaction(v) then out[2] = S.Colored(K.stop, L["%s only: can't buy on this character"]:format(label or ""))
        elseif label and label ~= "Neutral" then out[2] = S.Muted(L["%s vendor"]:format(label)) end
        out[3] = note and ((D.HolidayActive(v) and (L["Active now"] .. ". ") or "") .. note)
        out[4] = conf and S.Muted(L["Confirmed by a scan on %s"]:format(conf))
            or Facts.NotConfirmed()
    elseif s.type == "events" then
        out[1] = Live(s.key) and S.Colored(K.badge, L["Active now"]) or L["Not active"]
    elseif s.type ~= "shop" then
        out[1] = s.sub and S.Muted(s.sub)
        out[2] = s.drop and s.drop.notes and S.Muted(s.drop.notes)
    end
    if total > 0 then
        local text = (v and L["Sells %d decor."] or L["Gives %d decor."]):format(total)
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
    local els = { U.head, U.mb, U.i1, U.i2, U.i3, U.i4, U.i5, U.q1, U.q2, U.go, U.hdr }
    for _, el in ipairs(els) do el:Hide() end
    local rows = s and Rows(s) or {}
    U.report:SetShown(s ~= nil)
    if not s then
        ClearModel()
        Line(U.hdr, "bodyMuted", L["Pick a source to see its decor."])
    else
        local v = s.vendor
        SetHead(s)
        U.head:Show()
        U.mb:SetShown(v ~= nil)
        if v then ShowModel(v.npcID) else ClearModel() end
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
        Line(U.hdr, #rows > 0 and "bodyGold" or "bodyMuted", #rows > 0 and (v and L["Decor sold here"] or L["Decor from this source"])
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
    U.lh:ClearAllPoints()
    U.lh:SetPoint("TOPLEFT", c.detail, "TOPLEFT", SP.m, -top)
    U.lh:SetPoint("BOTTOMRIGHT", c.detail, "BOTTOMRIGHT", -SP.m, U.report:GetHeight() + 2 * SP.s)
    U.list:SetShown(#rows > 0)
    if #rows > 0 then U.list:SetData(rows) end
end

local function Report()
    local s = Current()
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

local function BuildDetail(pane)
    local function Text(parent, role)
        local fs = S.Text(parent, role or "body", "OVERLAY")
        fs:SetWidth(IW)
        fs:SetJustifyH("LEFT")
        return fs
    end
    U.head = CreateFrame("Frame", nil, pane)
    U.face = U.head:CreateTexture(nil, "ARTWORK")
    U.face:SetSize(36, 36)
    U.face:SetPoint("TOPLEFT")
    U.name, U.meta = Text(U.head, "subheader"), Text(U.head, "metaMuted")
    U.meta:SetPoint("TOPLEFT", U.name, "BOTTOMLEFT", 0, -2)
    U.mb = W.Well(pane)
    U.mb:SetSize(IW, 100)
    U.ph = CreateFrame("Frame", nil, U.mb)
    U.ph:SetAllPoints()
    U.ph:SetFrameLevel(U.mb:GetFrameLevel() + 2)
    local none = S.Text(U.ph, "metaMuted", "OVERLAY")
    none:SetPoint("CENTER")
    none:SetText(L["No model shown"])
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
    U.report = W.NewButton(pane, L["Report a problem"], Report)
    U.report:SetPoint("BOTTOMLEFT", SP.m, SP.s)
    U.report:SetMotionScriptsWhileDisabled(true)
    U.report:SetScript("OnEnter", function(self)
        if not B.InCombat() then return end
        local tip = B.Tooltip()
        tip:SetOwner(self, "ANCHOR_RIGHT")
        tip:SetText(L["Not available in combat"])
        tip:Show()
    end)
    U.report:SetScript("OnLeave", B.HideTooltip)
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
    for _, t in ipairs(TYPES) do
        local b = CreateFrame("Button", nil, c.nav)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(unpack(K.selected))
        b:CreateTexture(nil, "HIGHLIGHT"):SetAllPoints()
        b.label = S.Text(b, "body", "OVERLAY")
        b.label:SetPoint("LEFT", SP.s, 0)
        b.label:SetText(S.sourceLabel[t])
        b.count = S.Text(b, "metaMuted", "OVERLAY")
        b.count:SetPoint("RIGHT", -SP.s, 0)
        b:SetScript("OnClick", function()
            st.pin = nil
            SetType(t)
            Rebuild(false)
        end)
        navs[t] = b
    end
    box = W.NewSearchBox(c.toolbar, KIND.vendors[2], function(text)
        if text == (st.q[st.type] or "") then return end
        st.q[st.type] = text
        Rebuild(false)
    end)
    box:SetPoint("TOPLEFT", c.toolbar, "TOPLEFT", SP.s, -SP.xs)
    box:SetPoint("TOPRIGHT", c.toolbar, "TOPRIGHT", -SP.xs, -SP.xs)
    local lh = CreateFrame("Frame", nil, c.body)
    lh:SetPoint("TOPLEFT", S.layout.wellPad, -S.layout.wellPad)
    lh:SetPoint("BOTTOMRIGHT", -S.layout.wellPad, S.layout.wellPad)
    list = W.NewList(lh, {
        extent = Extent, reclaim = true,
        kinds = { row = W.rowKind, header = W.headerKind, foot = footKind },
    })
    empty = W.NewEmptyState(c.body)
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
    ClearModel()
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

B.RegisterTab("sources", Tab)
