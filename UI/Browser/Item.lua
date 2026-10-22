-- One decor item: 3D preview, ownership, price, requirements, sources, and a data-error report.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local S = B.Style
local W = B.Widgets
local LO = S.layout
local K = S.color

local LABEL_W = 120
local VENDOR_ROWS = 3
local OTHER_ROWS = 5

local STATE_ATLAS = { owned = S.atlas.check, unlocked = S.atlas.coin, locked = S.atlas.lock }
local STATE_NOTE = {
    owned = L["You own this."],
    unlocked = L["You can buy it now. Not collected yet."],
    locked = L["Not available to you yet."],
}
local REQ_TAG = {
    [true] = { L["Met: %s"], K.stateText.owned },
    [false] = { L["Needs: %s"], K.stateText.locked },
    unknown = { L["Unknown: %s"], K.stateText.unknown },
}

local Page = { topLevel = false, searchable = false }
local memo

-- Data-error report text. r = { itemID, name, recordID, build, buildNumber, version,
-- vendors = { { npcID, name, zone, mapID, x, y } } }.
function Page.ReportText(r)
    local lines = {
        L["Item: %s (%d)"]:format(r.name or "?", r.itemID),
        L["Record ID: %s"]:format(r.recordID and tostring(r.recordID) or L["none"]),
    }
    for _, v in ipairs(r.vendors) do
        local where = L["no location"]
        if v.mapID and v.x and v.y then
            where = L["map %d at %.1f, %.1f"]:format(v.mapID, v.x * 100, v.y * 100)
        end
        lines[#lines + 1] = L["Vendor %d: %s, %s, %s"]:format(v.npcID, v.name or L["Unknown"],
            v.zone or L["Unknown"], where)
    end
    lines[#lines + 1] = L["Client: %s (%s)"]:format(r.build or "?", r.buildNumber or "?")
    lines[#lines + 1] = L["Homestead: %s"]:format(r.version or "?")
    return table.concat(lines, "\n")
end

local function Model3D()
    if B.State.model3D ~= nil then return B.State.model3D end
    local s = B.Saved()
    return not (s and s.model3D == false)
end

local function FactLabel(parent, labelText, prevValue, firstAnchor, firstX, firstY)
    local label = S.Text(parent, "body", "OVERLAY")
    label:SetTextColor(K.muted[1], K.muted[2], K.muted[3])
    label:SetWidth(LABEL_W)
    label:SetJustifyH("LEFT")
    if prevValue then
        label:SetPoint("TOPLEFT", prevValue, "BOTTOMLEFT", -(LABEL_W + 8), -12)
    else
        label:SetPoint("TOPLEFT", firstAnchor, "TOPLEFT", firstX, firstY)
    end
    label:SetText(labelText)
    return label
end

local function Fact(parent, ...)
    local label = FactLabel(parent, ...)
    local value = S.Text(parent, "body", "OVERLAY")
    value:SetPoint("TOPLEFT", label, "TOPRIGHT", 8, 0)
    value:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    value:SetJustifyH("LEFT")
    value:SetJustifyV("TOP")
    return label, value
end

local function TextColor(b, c)
    b.text:SetTextColor(c[1], c[2], c[3])
end

local function RestColor(b)
    TextColor(b, b:IsEnabled() and K.muted or K.disabled)
end

-- Disabled in combat: greyed, tooltip says why.
local function NewTextButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b.text = S.Text(b, "body", "OVERLAY")
    b.text:SetPoint("LEFT")
    b.text:SetPoint("RIGHT")
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    TextColor(b, K.muted)
    b:SetMotionScriptsWhileDisabled(true)
    b:SetScript("OnEnter", function(self)
        if not self:IsEnabled() then
            local tip = B.Tooltip()
            tip:SetOwner(self, "ANCHOR_RIGHT")
            tip:SetText(L["Not available in combat"])
            tip:Show()
            return
        end
        if self.onClick then TextColor(self, K.body) end
        if self.tooltipLink then B.ShowLinkTooltip(self, self.tooltipLink) end
    end)
    b:SetScript("OnLeave", function(self)
        RestColor(self)
        B.HideTooltip()
    end)
    b:SetScript("OnClick", function(self)
        if self.onClick then self.onClick(self) end
    end)
    return b
end

local function OpenAchievement(b)
    W.OpenAchievement(b.achievementID)
end

local function Report()
    if InCombatLockdown() then return end
    local D, itemID = B.Data, Page.itemID
    local info = D.CatalogInfo(itemID, B.State.catalogMemo)
    local vendors, seen = {}, {}
    local function add(npcID)
        if not npcID or seen[npcID] then return end
        seen[npcID] = true
        local v = D.Vendor(npcID)
        local e = { npcID = npcID, name = v and v.name, zone = v and v.zone }
        if v then e.mapID, e.x, e.y = D.VendorLocation(v) end
        vendors[#vendors + 1] = e
    end
    add(Page.npcID)
    for _, src in ipairs(memo.sources) do
        if src.type == "vendor" then add(src.npcID) end
    end
    local build, buildNumber = GetBuildInfo()
    HA.OutputWindow:Show(L["Report a data error"], Page.ReportText({
        itemID = itemID, name = D.ItemName(itemID) or (info and info.name),
        recordID = D.RecordID(itemID, info), vendors = vendors,
        build = build, buildNumber = buildNumber, version = HA.Constants.VERSION,
    }))
end

function Page.Build(host)
    local f = CreateFrame("Frame", nil, host)
    f:SetAllPoints()

    local hdr = W.NewSectionHeader(f)
    hdr:SetPoint("TOPLEFT")
    hdr:SetPoint("TOPRIGHT")
    Page.header = hdr

    local box = W.Well(f)
    box:SetSize(S.model.itemW, S.model.itemH)
    box:SetPoint("TOPLEFT", 0, -36)
    W.WoodCorners(box)
    local scene = CreateFrame("ModelScene", nil, box, "PanningModelSceneMixinTemplate")
    scene:SetPoint("TOPLEFT", LO.wellPad, -LO.wellPad)
    scene:SetPoint("BOTTOMRIGHT", -LO.wellPad, LO.wellPad)
    Page.scene = scene
    local icon = box:CreateTexture(nil, "ARTWORK")
    icon:SetSize(S.model.thumb * 1.5, S.model.thumb * 1.5)
    icon:SetPoint("CENTER", 0, 20)
    W.Coord(icon, S.coord.icon)
    Page.fallbackIcon = icon
    local fallbackText = S.Text(box, "body", "OVERLAY")
    fallbackText:SetPoint("TOP", icon, "BOTTOM", 0, -10)
    fallbackText:SetWidth(S.model.itemW - 30)
    Page.fallbackText = fallbackText

    local toggle = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    toggle:SetSize(24, 24)
    toggle:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -4)
    toggle.Text:SetText(L["Show 3D preview"])
    toggle:SetScript("OnClick", function(self)
        B.State.model3D = self:GetChecked() and true or false
        B.Save("model3D", B.State.model3D)
        Page.RenderModel()
    end)
    Page.toggle = toggle

    local _, status = Fact(f, L["Status"], nil, box, S.model.itemW + 22, 0)
    Page.status = status
    local note = S.Text(f, "meta", "OVERLAY")
    note:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -2)
    note:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    note:SetJustifyH("LEFT")
    note:SetTextColor(K.muted[1], K.muted[2], K.muted[3])
    Page.statusNote = note

    local _, price = Fact(f, L["Price"], note)
    Page.price = price
    local _, req = Fact(f, L["Requirement"], price)
    Page.req = req
    local soldLabel = FactLabel(f, L["Sold by"], req)
    Page.soldRows = {}
    for i = 1, VENDOR_ROWS do
        local row = CreateFrame("Frame", nil, f)
        row:SetHeight(30)
        row:SetPoint("TOPLEFT", soldLabel, "TOPRIGHT", 8, -(i - 1) * 32 + 8)
        row:SetPoint("RIGHT", f, "RIGHT", -10, 0)
        row.wp = W.WaypointButton(row)
        row.wp:SetPoint("RIGHT")
        row.btn = NewTextButton(row)
        row.btn:SetPoint("LEFT")
        row.btn:SetPoint("RIGHT", row.wp, "LEFT", -8, 0)
        row.btn:SetHeight(18)
        Page.soldRows[i] = row
    end
    Page.soldMore = S.Text(f, "meta", "OVERLAY")
    Page.soldMore:SetTextColor(K.muted[1], K.muted[2], K.muted[3])
    Page.soldMore:SetPoint("TOPLEFT", soldLabel, "TOPRIGHT", 8, -VENDOR_ROWS * 32 + 4)

    local otherHdr = S.Text(f, "subheader", "OVERLAY")
    otherHdr:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -40)
    otherHdr:SetText(L["Also available from"])
    Page.otherRows = {}
    for i = 1, OTHER_ROWS do
        local b = NewTextButton(f)
        b:SetPoint("TOPLEFT", otherHdr, "BOTTOMLEFT", 0, -6 - (i - 1) * 20)
        b:SetPoint("RIGHT", f, "RIGHT", -10, 0)
        b:SetHeight(18)
        Page.otherRows[i] = b
    end
    Page.otherMore = S.Text(f, "meta", "OVERLAY")
    Page.otherMore:SetTextColor(K.muted[1], K.muted[2], K.muted[3])
    Page.otherMore:SetPoint("TOPLEFT", otherHdr, "BOTTOMLEFT", 0, -6 - OTHER_ROWS * 20)
    Page.noOther = S.Text(f, "meta", "OVERLAY")
    Page.noOther:SetTextColor(K.muted[1], K.muted[2], K.muted[3])
    Page.noOther:SetPoint("TOPLEFT", otherHdr, "BOTTOMLEFT", 0, -6)
    Page.noOther:SetText(L["No other sources on record."])

    local report = NewTextButton(f)
    report:SetPoint("BOTTOMLEFT", 0, 4)
    report:SetSize(200, 18)
    report.text:SetText(L["Report a data error"])
    report.onClick = Report
    Page.report = report
    return f
end

local function Placeholder(text)
    Page.scene:ClearScene()
    Page.scene:Hide()
    Page.fallbackIcon:SetTexture(B.Data.ItemIcon(Page.itemID))
    Page.fallbackIcon:Show()
    Page.fallbackText:SetText(text)
end

-- The catalog entry behind the preview. Misses are not memoised, so late data fills in on refresh.
local function ModelInfo()
    return B.Data.CatalogInfo(Page.itemID, B.State.catalogMemo)
end

local function ModelKey(on, info)
    return Page.itemID .. ":" .. tostring(on) .. ":" .. tostring(info ~= nil and info.asset ~= nil)
end

function Page.RenderModel(info)
    local on = Model3D()
    info = info or ModelInfo()
    Page.modelKey = ModelKey(on, info)
    if not on then return Placeholder(L["3D preview is off."]) end
    if not (info and info.asset) then return Placeholder(L["Preview unavailable for this item."]) end
    local consts = _G.Constants and _G.Constants.HousingCatalogConsts
    local default = consts and consts.HOUSING_CATALOG_DECOR_MODELSCENEID_DEFAULT or S.model.defaultSceneID
    local own = info.uiModelSceneID
    local scene = Page.scene
    for _, sceneID in ipairs((own and own ~= default) and { own, default } or { default }) do
        scene:ClearScene()
        scene:TransitionToModelSceneID(sceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE,
            CAMERA_MODIFICATION_TYPE_DISCARD, true)
        local actor = scene:GetActorByTag(S.model.actorTag)
        if actor then
            actor:SetPreferModelCollisionBounds(true)
            actor:SetModelByFileID(info.asset)
            Page.fallbackIcon:Hide()
            Page.fallbackText:SetText("")
            scene:Show()
            return
        end
    end
    Placeholder(L["Preview unavailable for this item."])
end

local function ItemMemo(itemID, npcID)
    local D = B.Data
    if memo and memo.itemID == itemID and memo.npcID == npcID and memo.version == D.MemoVersion() then
        return memo
    end
    local m = { itemID = itemID, npcID = npcID, version = D.MemoVersion(),
        sources = D.ItemSources(itemID), sold = {}, others = {} }
    for _, src in ipairs(m.sources) do
        if src.type == "vendor" then
            local v = src.npcID and D.Vendor(src.npcID)
            if v and D.IsListedVendor(v) then m.sold[#m.sold + 1] = { src = src, vendor = v } end
        else
            m.others[#m.others + 1] = src
        end
    end
    if npcID then m.price = D.Price(itemID, D.Vendor(npcID)) end
    for _, src in ipairs(m.sources) do
        if m.price then break end
        if src.type == "vendor" then m.price = src.price end
    end
    memo = m
    return m
end

local function SoldLine(v)
    local D = B.Data
    local place = v.zone or L["Unknown"]
    if v.subzone then place = L["%s, %s"]:format(v.subzone, place) end
    if D.IsOppositeFaction(v) then
        local label = D.VendorFactionLabel(v)
        if label then place = L["%s (%s)"]:format(place, label) end
    end
    return L["%s - %s"]:format(v.name or L["Unknown"], S.Muted(place))
end

local function ShowSold(m)
    for i, row in ipairs(Page.soldRows) do
        local e = m.sold[i]
        local b = row.btn
        if e then
            local v = e.vendor
            b.text:SetText(SoldLine(v))
            b.onClick = function() B.Go({ page = "shop", npcID = v.npcID }) end
            local mapID, x, y = B.Data.VendorLocation(v)
            row.wp.wp = mapID and { mapID = mapID, x = x, y = y, title = v.name,
                data = { type = "vendor", npcID = v.npcID } } or nil
            row.wp:SetShown(mapID ~= nil)
            row:Show()
        else
            row:Hide()
        end
    end
    local extra = #m.sold - VENDOR_ROWS
    Page.soldMore:SetText(extra > 0 and L["+%d more vendors"]:format(extra) or "")
    if #m.sold == 0 then
        local row = Page.soldRows[1]
        row.btn.text:SetText(L["Not sold by a vendor"])
        row.btn.onClick = nil
        row.wp:Hide()
        row:Show()
    end
end

local function ShowOthers(m)
    for i, b in ipairs(Page.otherRows) do
        local src = m.others[i]
        b.onClick, b.tooltipLink, b.achievementID = nil, nil, nil
        if src then
            b.text:SetText(B.Data.SourceLine(Page.itemID, { src }))
            if src.type == "achievement" and src.achievementID then
                b.achievementID = src.achievementID
                b.onClick = OpenAchievement
                b.tooltipLink = GetAchievementLink(src.achievementID)
            elseif src.type == "quest" and src.questID then
                b.tooltipLink = GetQuestLink(src.questID) or ("quest:" .. src.questID)
            end
            b:Show()
        else
            b:Hide()
        end
    end
    local extra = #m.others - OTHER_ROWS
    Page.otherMore:SetText(extra > 0 and L["+%d more sources"]:format(extra) or "")
    Page.noOther:SetShown(#m.others == 0)
end

function Page.Show(route, isRefresh)
    local D = B.Data
    local itemID, npcID = route.itemID, route.npcID
    Page.itemID, Page.npcID = itemID, npcID
    local m = ItemMemo(itemID, npcID)

    Page.header.text:SetText(D.ItemName(itemID) or L["Item %d"]:format(itemID))
    Page.header.right:SetText(L["Item %d"]:format(itemID))
    Page.toggle:SetChecked(Model3D())
    local on = Model3D()
    local info = ModelInfo()
    if not isRefresh or Page.modelKey ~= ModelKey(on, info) then Page.RenderModel(info) end

    local st = D.ItemStatus(itemID, npcID, true)
    local atlas = STATE_ATLAS[st.state]
    local sc = K.stateText[st.state]
    Page.status:SetText((atlas and ("|A:" .. atlas .. ":16:16|a ") or "")
        .. S.Colored(sc, S.stateLabel[st.state]))
    local note = STATE_NOTE[st.state]
    if st.state == "locked" and st.labels and #st.labels > 0 then
        note = L["Needs: %s"]:format(table.concat(st.labels, L[", "]))
    elseif st.state == "unknown" then
        note = st.excluded and L["Ownership cannot be read for this kind of item."]
            or L["Ownership is not known yet."]
    end
    Page.statusNote:SetText(note)
    Page.price:SetText(m.price or L["Not listed"])

    local reqs = D.Requirements(itemID, npcID)
    if #reqs == 0 then
        Page.req:SetText(L["None"])
    else
        local lines = {}
        for i, r in ipairs(reqs) do
            local tag = REQ_TAG[r.met] or REQ_TAG.unknown
            lines[i] = S.Colored(tag[2], tag[1]:format(r.text))
        end
        Page.req:SetText(table.concat(lines, "\n"))
    end

    ShowSold(m)
    ShowOthers(m)
end

function Page.Hide()
    Page.scene:ClearScene()
    Page.modelKey = nil
    memo = nil
end

function Page.SetCombatGated(gated)
    Page.report:SetEnabled(not gated)
    RestColor(Page.report)
    for _, b in ipairs(Page.otherRows) do
        b:SetEnabled(not (gated and b.achievementID))
        RestColor(b)
    end
end

B.RegisterPage("item", Page)
