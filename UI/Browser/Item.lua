-- Item detail: one decor item's state, flags, requirements and sources in a scroll pane.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local S = B.Style
local W = B.Widgets
local K = S.color
local SP = S.space

local PAD = SP.m
local MARK = 12
local FALLBACK_W = S.cols.detail - 2 * PAD - S.layout.scrollBarGap

local SHOW = {
    vendor = L["Show vendor"], achievement = L["Show achievement"], quest = L["Show quest"],
    profession = L["Show recipe"], drop = L["Show drop"], event = L["Show event"],
}

local Page = {}
local scroll, content, parts
local lines, buttons = {}, {}
local items, head, flagged

local function Line(text, glyph, color, role)
    items[#items + 1] = { text = text, glyph = glyph, color = color or K.body, role = role }
end

local function Heading(text)
    items[#items + 1] = { gap = true }
    Line(text, nil, K.gold, "subheader")
end

local function Pair(label, value)
    Line(S.Colored(K.gold, label) .. " " .. value)
end

local function Act(label, fn, gated)
    items[#items + 1] = { act = label, fn = fn, gated = gated }
end

local function Waypoint(label, mapID, x, y, title, data)
    if not (mapID and x and y) then return end
    Act(label, function() HA.Waypoints:Set(mapID, x, y, { title = title, data = data }) end)
end

local function ShowSource(sourceType, key)
    return function() B.ShowTab("sources", { type = sourceType, select = { key = key } }) end
end

local function Report()
    if InCombatLockdown() then return end
    local D, itemID = B.Data, Page.itemID
    local info = D.CatalogInfo(itemID, B.State and B.State.catalogMemo)
    local build, buildNumber = GetBuildInfo()
    HA.OutputWindow:Show(L["Report a data error"], D.ReportText({
        itemID = itemID, name = D.ItemName(itemID, info),
        recordID = D.RecordID(itemID, info), vendors = Page.vendors,
        build = build, buildNumber = buildNumber, version = HA.Constants.VERSION,
    }))
end

-- Open vendors by nearness, then other vendors, other sources, other-faction vendors.
local function Rank(b)
    if not b.vendor then return 6 end
    if b.offer == "can" then return B.Facts.Nearness(b.mapID, B.Facts.Here()) end
    return B.Data.IsOppositeFaction(b.vendor) and 9 or 5
end

local function EventLine(name, active)
    if active and flagged[name] then return end
    Line(active and L["Active now: %s"]:format(name) or W.StateWords("event", name), "clock",
        active and K.badge or K.muted)
end

local function VendorBlock(itemID, b)
    local D, F, v = B.Data, B.Facts, b.vendor
    Pair(L["Vendor:"], v.name or L["Unknown"])
    if v.zone then
        Pair(L["Zone:"], v.subzone and L["%s, %s"]:format(v.subzone, v.zone) or v.zone)
    else
        Line(L["Location not recorded"], nil, K.muted)
    end
    local price = D.Price(itemID, v)
    if price then Pair(L["Cost:"], price) end
    local label = D.IsOppositeFaction(v) and D.VendorFactionLabel(v)
    if label then Line(W.StateWords("faction", label), "stop", K.stop) end
    local ev = F.EventVendor(b.npcID)
    local event = ev and ev.event or v.event
    if event then EventLine(event, F.BrowserListed(v)) end
    if b.offer == "can" then Line(L["Can get now here"], "dot", K.can) end
    local confirmed = F.Confirmed(v)
    if confirmed then
        Line(L["Confirmed by a scan on %s"]:format(confirmed), "check", K.muted)
    else
        Line(L["Not confirmed"], nil, K.muted)
    end
    local key = F.SourceKey("vendors", { npcID = b.npcID }, itemID)
    if key then Act(SHOW.vendor, ShowSource("vendors", key)) end
    Waypoint(L["Set waypoint"], b.mapID, b.x, b.y, v.name, { type = "vendor", npcID = b.npcID })
end

local function OtherBlock(itemID, src)
    local F, t = B.Facts, src.type
    local name = src.name or L["Unknown"]
    if t == "achievement" then
        Pair(L["Achievement:"], name)
    elseif t == "quest" then
        Pair(L["Quest:"], name)
        local spot, start = F.TreasureSpot(src.questID), F.QuestStart(src.questID)
        if spot then Line(L["Daily from The Last Architect"], nil, K.muted) end
        if start then
            local map = C_Map.GetMapInfo(start.mapID)
            Line(L["Starts in %s"]:format(map and map.name or L["Unknown"]), nil, K.muted)
            Waypoint(L["Set waypoint"], start.mapID, start.x, start.y, name)
        end
        if spot then Waypoint(L["Set dig site waypoint"], spot.mapID, spot.x, spot.y, name) end
    elseif t == "profession" then
        Pair(L["Recipe:"], name)
        if src.profession then Pair(L["Profession:"], src.profession) end
    elseif t == "drop" then
        Pair(L["Drop:"], name)
        if src.zone then Pair(L["Zone:"], src.zone) end
        if src.notes then Line(src.notes, nil, K.muted) end
        Waypoint(L["Set waypoint"], src.mapID, src.x, src.y, name)
    elseif t == "event" then
        Pair(L["Event:"], name)
        if src.vendorName then Pair(L["Vendor:"], src.vendorName) end
        if src.zone then Pair(L["Zone:"], src.zone) end
        local CD = HA.CalendarDetector
        EventLine(name, CD and CD:IsHolidayActive(name) == true)
        Waypoint(L["Set waypoint"], src.mapID, src.x, src.y, name)
    else
        Line(B.Data.SourceLine(itemID, { src }))
    end
    local sourceType = F.SOURCE_TYPE[t]
    local file = HA[B.CanGet.SOURCE_TABLES[sourceType] or ""]
    local key = sourceType and t ~= "shop" and F.SourceKey(sourceType, file and file[itemID], itemID)
    if key then Act(SHOW[t], ShowSource(sourceType, key)) end
end

-- The page as descriptors: lines, buttons and gaps.
local function Describe(itemID)
    local D, CG, F = B.Data, B.CanGet, B.Facts
    items, flagged = {}, {}
    local memo = B.State and B.State.catalogMemo
    local e = CG.Entry(itemID)
    local info = e and e.info or D.CatalogInfo(itemID, memo)

    local quality = D.IconData(itemID, true, memo)
    local kind = info and info.categoryIDs and info.categoryIDs[1]
    kind = kind and C_HousingCatalog.GetCatalogCategoryInfo(kind)
    head = {
        name = D.ItemName(itemID, info) or L["Item %d"]:format(itemID), quality = quality, icon = D.ItemIcon(itemID),
        meta = L["%s - %s"]:format(quality and _G["ITEM_QUALITY" .. quality .. "_DESC"] or L["Unknown"],
            kind and kind.name or L["Other"]),
    }

    local blocks, seen = {}, {}
    Page.vendors = {}
    local function addVendor(npcID)
        local v = npcID and not seen[npcID] and D.Vendor(npcID)
        if not v then return false end
        seen[npcID] = true
        local mapID, x, y = D.VendorLocation(v)
        blocks[#blocks + 1] = { vendor = v, npcID = npcID, mapID = mapID, x = x, y = y,
            offer = CG.Offer(itemID, npcID, e and e.info) }
        Page.vendors[#Page.vendors + 1] = { npcID = npcID, name = v.name, zone = v.zone, mapID = mapID, x = x, y = y }
        return true
    end
    for _, src in ipairs(D.ItemSources(itemID)) do
        if not (src.type == "vendor" and (addVendor(src.npcID) or seen[src.npcID])) then
            blocks[#blocks + 1] = { src = src }
        end
    end
    for _, npcID in ipairs(F.EventVendorsFor(itemID) or {}) do addVendor(npcID) end
    for i, b in ipairs(blocks) do b.rank = Rank(b) + i / 1000 end
    table.sort(blocks, function(a, c) return a.rank < c.rank end)

    local state, arg, at = B.ItemState(itemID)
    if state then
        local st = S.state[state]
        Line(W.StateWords(state, arg), st.glyph, st.color)
    end
    if info and D.CollectionState() == "ready" then
        local n = { info.totalNumPlaced, info.totalNumStored, info.remainingRedeemable }
        for i, label in ipairs({ L["Placed"], L["In storage"], L["Not yet redeemed"] }) do
            if (n[i] or 0) > 0 then Pair(label, tostring(n[i])) end
        end
    end
    local active
    for _, o in pairs(e and e.canBy or {}) do
        if o.event and (not active or o.event < active) then active = o.event end
    end
    if active then
        flagged[active] = true
        Line(L["Active now: %s"]:format(active), "clock", K.badge)
    end
    if e and e.bonus then
        local blue = _G.BRIGHTBLUE_FONT_COLOR
        Line(L["First-Time Collection Bonus Available"], "star", blue and { blue.r, blue.g, blue.b } or K.gold)
    end

    local reqs = D.Requirements(itemID, at or blocks[1] and blocks[1].npcID)
    if #reqs > 0 then
        Heading(L["Requires"])
        for _, r in ipairs(reqs) do
            if r.met == true then
                Line(L["%s (done)"]:format(r.text), "check", K.muted)
            elseif r.met == false then
                Line(L["%s (not yet)"]:format(r.text), "lock")
            else
                Line(r.text)
            end
        end
    end

    Heading(L["Where to get it"])
    if #blocks == 0 then Line(L["Source unknown"], nil, K.muted) end
    for _, b in ipairs(blocks) do
        items[#items + 1] = { gap = true }
        if b.vendor then
            VendorBlock(itemID, b)
        else
            OtherBlock(itemID, b.src)
        end
    end
    items[#items + 1] = { gap = true }
    Act(L["Report a problem"], Report, true)
end

local function NewLine()
    local f = CreateFrame("Frame", nil, content)
    f.mark = f:CreateTexture(nil, "OVERLAY")
    f.mark:SetSize(MARK, MARK)
    f.mark:SetPoint("TOPLEFT", 0, -1)
    f.text = S.Text(f, "body", "OVERLAY")
    f.text:SetJustifyH("LEFT")
    return f
end

local function NewAct()
    local b = W.NewButton(content, "", function(self)
        if self.act then self.act() end
    end)
    b:SetMotionScriptsWhileDisabled(true)
    b:SetScript("OnEnter", function(self)
        if self.gated and not self:IsEnabled() then
            local tip = B.Tooltip()
            tip:SetOwner(self, "ANCHOR_RIGHT")
            tip:SetText(L["Not available in combat"])
            tip:Show()
        end
    end)
    b:SetScript("OnLeave", function() B.HideTooltip() end)
    return b
end

local function Layout()
    local w = scroll:GetWidth()
    if w < 1 then w = FALLBACK_W end
    content:SetWidth(w)
    local r, g, b = W.QualityRGB(head.quality)
    W.SetTile(parts.tile, { icon = head.icon }, r, g, b)
    local textW = w - S.model.thumb - SP.s
    parts.name:SetWidth(textW)
    parts.name:SetText(head.name)
    parts.name:SetTextColor(r, g, b)
    parts.meta:SetWidth(textW)
    parts.meta:SetText(head.meta)
    local y = math.max(S.model.thumb, parts.name:GetStringHeight() + SP.xs + parts.meta:GetStringHeight()) + SP.m

    local nl, nb = 0, 0
    for _, d in ipairs(items) do
        if d.gap then
            y = y + SP.s
        elseif d.act then
            nb = nb + 1
            buttons[nb] = buttons[nb] or NewAct()
            local btn = buttons[nb]
            btn.act, btn.gated = d.fn, d.gated
            btn:SetText(d.act)
            btn:Fit()
            btn:SetEnabled(not (d.gated and Page.combat))
            btn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            btn:Show()
            y = y + btn:GetHeight() + SP.xs
        else
            nl = nl + 1
            lines[nl] = lines[nl] or NewLine()
            local f = lines[nl]
            local indent = d.glyph and MARK + SP.xs or 0
            f.text:SetFontObject(S.FontName(d.role or "body"))
            f.text:SetPoint("TOPLEFT", indent, 0)
            f.text:SetWidth(w - indent)
            f.text:SetText(d.text)
            f.text:SetTextColor(d.color[1], d.color[2], d.color[3])
            B.Vis.Marker.Set(f.mark, d.glyph, d.color)
            local h = f.text:GetStringHeight()
            f:SetSize(w, h)
            f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            f:Show()
            y = y + h + SP.xs
        end
    end
    for i = nl + 1, #lines do lines[i]:Hide() end
    for i = nb + 1, #buttons do buttons[i]:Hide() end
    content:SetHeight(y)
end

function Page.Build(host)
    scroll = CreateFrame("ScrollFrame", nil, host, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", PAD, -PAD)
    scroll:SetPoint("BOTTOMRIGHT", -(PAD + S.layout.scrollBarGap), PAD)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(FALLBACK_W, 1)
    scroll:SetScrollChild(content)
    scroll:HookScript("OnSizeChanged", function()
        if items then Layout() end
    end)
    local tile = W.NewTile(content, S.model.thumb)
    tile.icon:SetPoint("TOPLEFT")
    parts = { tile = tile, name = S.Text(content, "subheader", "OVERLAY"), meta = S.Text(content, "body", "OVERLAY") }
    parts.name:SetPoint("TOPLEFT", tile.icon, "TOPRIGHT", SP.s, 0)
    parts.meta:SetPoint("TOPLEFT", parts.name, "BOTTOMLEFT", 0, -SP.xs)
    parts.meta:SetTextColor(K.muted[1], K.muted[2], K.muted[3])
    parts.name:SetJustifyH("LEFT")
    parts.meta:SetJustifyH("LEFT")
    return scroll
end

function Page.Show(itemID)
    Page.itemID = itemID
    Page.combat = B.InCombat()
    Describe(itemID)
    Layout()
    scroll:Show()
end

function Page.Clear()
    Page.itemID, items = nil, nil
    if scroll then scroll:Hide() end
    for _, btn in ipairs(buttons) do B.HideTooltipFor(btn) end
end

function Page.SetCombat(inCombat)
    Page.combat = inCombat
    for _, btn in ipairs(buttons) do
        if btn.gated and btn:IsShown() then btn:SetEnabled(not inCombat) end
    end
end

B.ItemDetail = { Build = Page.Build, Show = Page.Show, Clear = Page.Clear, SetCombat = Page.SetCombat }
