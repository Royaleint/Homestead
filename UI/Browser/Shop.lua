-- One shop: creature model, details, a map card at the vendor's spot, and a virtualized wares grid.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local S = B.Style
local W = B.Widgets
local Vis = B.Vis
local LO = S.layout
local K = S.color
local SP = S.space

-- The map card is display-only: opening the world map from addon code is not known taint-free.
local MAP_CARD_CLICK = false

local MODEL_W, MODEL_H = S.model.vendorW, S.model.vendorH
local MAP_W, MAP_H = S.model.mapW, S.model.mapH
local MODEL_CHECK_DELAY = 1.5

local Page = { topLevel = false, searchable = true, usesCounts = true }
local memo

local function BuildCell(t)
    local WC = S.wareCell
    local slot = t:CreateTexture(nil, "BACKGROUND")
    slot:SetAtlas(C_Texture.GetAtlasInfo(S.atlas.wareSlot) and S.atlas.wareSlot or S.atlas.wareSlotFallback)
    slot:SetAllPoints()
    local lb = S.lockBadge.tile
    t.grey = Vis.Desaturate.Create(t, lb.size, lb.point)
    local art, over = t.grey.art, t.grey.over
    art:SetPoint("TOPLEFT", WC.inset, -WC.inset)
    art:SetPoint("BOTTOMRIGHT", -WC.inset, WC.inset)
    W.BuildItemIcon(t.grey)

    -- Keeps the copies number readable over bright icons.
    local shade = over:CreateTexture(nil, "OVERLAY", nil, 0)
    shade:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT")
    shade:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT")
    PixelUtil.SetHeight(shade, WC.shade)
    shade:SetColorTexture(1, 1, 1, 1)
    shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, WC.shadeAlpha), CreateColor(0, 0, 0, 0))

    t.check = over:CreateTexture(nil, "OVERLAY", nil, 4)
    t.check:SetSize(WC.check.size, WC.check.size)
    t.check:SetPoint(WC.check.point[1], art, WC.check.point[1], WC.check.point[2], WC.check.point[3])
    t.check:SetAtlas(S.atlas.check)

    t.count = S.Text(over, "number", "OVERLAY")
    t.count:SetPoint(WC.count.point[1], art, WC.count.point[1], WC.count.point[2], WC.count.point[3])
    t.count:SetJustifyH("RIGHT")

    local hl = over:CreateTexture(nil, "OVERLAY", nil, 5)
    hl:SetAllPoints(art)
    hl:SetColorTexture(unpack(K.wareHover))
    hl:SetBlendMode("ADD")
    hl:Hide()
    t.hover = hl

    function t:Reset()
        W.ResetItemIcon(self.grey)
        if self:IsMouseOver() then B.HideTooltip() end
    end
    t:SetScript("OnEnter", function(self)
        hl:Show()
        if self.itemID then B.ShowItemTooltip(self, self.itemID, self.npcID) end
    end)
    t:SetScript("OnLeave", function()
        hl:Hide()
        B.HideTooltip()
    end)
    t:SetScript("OnClick", function(self)
        if self.itemID then B.Go({ page = "item", itemID = self.itemID, npcID = self.npcID }) end
    end)
end

local function InitCell(t, d)
    local D = B.Data
    local st = D.ItemStatus(d.itemID, d.npcID)
    -- Same ware, same shop, new state: refreshed while on screen. A recycle changes the key.
    local key = d.itemID .. ":" .. d.npcID
    local flash = t.key == key and t.state ~= nil and t.state ~= st.state
    t.key, t.state = key, st.state

    t.itemID, t.npcID = d.itemID, d.npcID
    local quality, copies = D.IconData(d.itemID, true, B.State.catalogMemo)
    W.SetItemIcon(t.grey, {
        texture = D.ItemIcon(d.itemID), color = W.STATE_RIM[st.state],
        quality = quality, isNew = D.IsNew(d.itemID),
    })
    t.hover:Hide()
    t.check:SetShown(st.state == "owned")
    t.count:SetText(copies or "")
    t.count:SetShown(copies ~= nil)
    Vis.Desaturate.Set(t.grey, st.state == "locked" or st.state == "unknown", st.state == "locked")
    if flash then W.FlashItemIcon(t.grey) end
end

local function BuildMapCard(f)
    local C = S.mapCard
    local card = W.Well(f)
    card:SetSize(MAP_W, MAP_H)
    card:SetPoint("TOPRIGHT")

    local view = CreateFrame("Frame", nil, card)
    view:SetSize(MAP_W - 2 * LO.wellPad, MAP_H - 2 * LO.wellPad)
    view:SetPoint("CENTER")
    view:SetClipsChildren(true)
    view:EnableMouse(false)
    local fill = view:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    local stone = S.material.stone
    fill:SetColorTexture(stone[1], stone[2], stone[3], 1)

    local canvas = CreateFrame("Frame", nil, view)
    view.canvas = canvas
    view.tiles = CreateTexturePool(canvas, "BACKGROUND", 0)
    view.pin = canvas:CreateTexture(nil, "OVERLAY")
    view.pin:SetSize(C.pin, C.pin)
    view.pin:SetAtlas(S.atlas.vendorPin, false)

    local over = CreateFrame("Frame", nil, view)
    over:SetAllPoints()
    over:SetFrameLevel(canvas:GetFrameLevel() + 2)
    local shade = over:CreateTexture(nil, "ARTWORK")
    shade:SetPoint("BOTTOMLEFT")
    shade:SetPoint("BOTTOMRIGHT")
    shade:SetHeight(C.captionHeight)
    shade:SetColorTexture(1, 1, 1, 1)
    shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, C.captionShade), CreateColor(0, 0, 0, 0))
    view.shade = shade
    view.caption = S.Text(over, "meta", "OVERLAY")
    view.caption:SetPoint("BOTTOMLEFT", SP.s, SP.s)
    view.caption:SetPoint("BOTTOMRIGHT", -SP.s, SP.s)
    view.caption:SetJustifyH("LEFT")
    view.caption:SetWordWrap(false)

    local emptyIcon = over:CreateTexture(nil, "ARTWORK")
    emptyIcon:SetSize(C.emptyIcon, C.emptyIcon)
    emptyIcon:SetPoint("CENTER", 0, 10)
    emptyIcon:SetAtlas(S.atlas.vendorPin, false)
    emptyIcon:SetDesaturated(true)
    emptyIcon:SetAlpha(0.35)
    local emptyText = S.Text(over, "metaMuted", "OVERLAY")
    emptyText:SetPoint("TOP", emptyIcon, "BOTTOM", 0, -SP.s)
    emptyText:SetPoint("LEFT", SP.s, 0)
    emptyText:SetPoint("RIGHT", -SP.s, 0)
    view.emptyIcon, view.emptyText = emptyIcon, emptyText

    if MAP_CARD_CLICK then
        view:EnableMouse(true)
        view:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" and self.mapID and not InCombatLockdown() then
                C_Map.OpenWorldMap(self.mapID)
            end
        end)
    end
    return view
end

local function MapEmpty(view, text)
    view.tiles:ReleaseAll()
    view.pin:Hide()
    view.shade:SetShown(view.mapID ~= nil)
    view.emptyIcon:Show()
    view.emptyText:SetText(text)
    view.emptyText:Show()
end

-- Draws once per spot; a refresh keeps its tiles. Only tiles inside the card load.
local function RenderMap(view, vendor, mapID, x, y)
    local key = mapID and (vendor.npcID .. ":" .. mapID .. ":" .. x .. ":" .. y) or "none"
    if view.key == key then return end
    view.key = key
    view.mapID = mapID
    if not mapID then
        view.caption:SetText("")
        MapEmpty(view, L["Location not recorded"])
        return
    end
    local info = C_Map.GetMapInfo(mapID)
    view.caption:SetText(info and info.name or vendor.zone or L["Unknown"])

    local layers = C_Map.GetMapArtLayers(mapID)
    local layer = layers and layers[1]
    local textures = layer and C_Map.GetMapArtLayerTextures(mapID, 1)
    if not (textures and #textures > 0) then
        MapEmpty(view, L["Map preview unavailable"])
        return
    end
    view.emptyIcon:Hide()
    view.emptyText:Hide()
    view.shade:Show()

    local vw, vh = view:GetSize()
    local lw, lh = layer.layerWidth, layer.layerHeight
    local s = math.max(math.max(vw / lw, vh / lh), math.min(vw / lw, vh / lh) * S.mapCard.zoom)
    local cw, ch = lw * s, lh * s
    local ox = math.min(0, math.max(vw - cw, vw / 2 - x * cw))
    local oy = math.min(0, math.max(vh - ch, vh / 2 - y * ch))
    local canvas = view.canvas
    canvas:SetSize(cw, ch)
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", view, "TOPLEFT", ox, -oy)

    local tw, th = layer.tileWidth * s, layer.tileHeight * s
    local cols = math.ceil(lw / layer.tileWidth)
    local rows = math.ceil(lh / layer.tileHeight)
    view.tiles:ReleaseAll()
    for row = 1, rows do
        local top = (row - 1) * th
        if top + oy < vh and top + th + oy > 0 then
            for col = 1, cols do
                local left = (col - 1) * tw
                if left + ox < vw and left + tw + ox > 0 then
                    local tile = view.tiles:Acquire()
                    tile:SetTexture(textures[(row - 1) * cols + col], nil, nil, "TRILINEAR")
                    tile:SetSize(tw, th)
                    tile:SetPoint("TOPLEFT", canvas, "TOPLEFT", left, -top)
                    tile:Show()
                end
            end
        end
    end

    local pin = view.pin
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", canvas, "TOPLEFT", x * cw, -y * ch)
    local opposite = B.Data.IsOppositeFaction(vendor)
    pin:SetDesaturated(opposite)
    pin:SetAlpha(opposite and 0.8 or 1)
    pin:Show()
end

-- Model: an uncached creature may never load, so the placeholder stays until the model reports in.
-- Work landing after the page or window changed does nothing.
local function ModelCurrent(model)
    return model.npcID ~= nil and model.npcID == Page.npcID and model.gen == B.Generation()
end

local function ShowModel(npcID)
    local model = Page.model
    model.gen, model.npcID = B.Generation(), npcID
    Page.placeholder:Show()
    model:ClearModel()
    model:SetCreature(npcID)
    model:SetPortraitZoom(0.7)
    C_Timer.After(MODEL_CHECK_DELAY, function()
        if model.npcID == npcID and ModelCurrent(model) and model:GetModelFileID() then
            Page.placeholder:Hide()
        end
    end)
end

local function ClearModel()
    local model = Page.model
    model.gen, model.npcID = nil, nil
    model:ClearModel()
    Page.placeholder:Show()
end

function Page.Build(host)
    local f = CreateFrame("Frame", nil, host)
    f:SetAllPoints()

    local box = W.Well(f)
    box:SetSize(MODEL_W, MODEL_H)
    box:SetPoint("TOPLEFT")

    local model = CreateFrame("PlayerModel", nil, box)
    model:SetPoint("TOPLEFT", LO.wellPad, -LO.wellPad)
    model:SetPoint("BOTTOMRIGHT", -LO.wellPad, LO.wellPad)
    model:SetScript("OnModelLoaded", function(self)
        if ModelCurrent(self) then Page.placeholder:Hide() end
    end)
    Page.model = model

    local ph = CreateFrame("Frame", nil, box)
    ph:SetAllPoints(model)
    ph:SetFrameLevel(model:GetFrameLevel() + 1)
    local phIcon = ph:CreateTexture(nil, "ARTWORK")
    phIcon:SetSize(72, 72)
    phIcon:SetPoint("CENTER", 0, 12)
    phIcon:SetTexture(S.tex.vendorPlaceholder)
    W.Coord(phIcon, S.coord.icon)
    local phText = S.Text(ph, "metaMuted", "OVERLAY")
    phText:SetPoint("TOP", phIcon, "BOTTOM", 0, -SP.s)
    phText:SetText(L["No model shown"])
    Page.placeholder = ph

    Page.map = BuildMapCard(f)

    local col = CreateFrame("Frame", nil, f)
    col:SetPoint("TOPLEFT", box, "TOPRIGHT", SP.l, -SP.xs)
    col:SetPoint("BOTTOMRIGHT", Page.map:GetParent(), "BOTTOMLEFT", -SP.l, 0)
    Page.col = col

    local function Line(role, maxLines)
        local fs = S.Text(col, role, "OVERLAY")
        fs:SetJustifyH("LEFT")
        fs:SetMaxLines(maxLines)
        return fs
    end
    Page.name = Line("header", 2)
    Page.zone = Line("body", 2)
    Page.tag = Line("meta", 1)
    Page.note = Line("meta", 2)
    Page.currency = Line("body", 2)
    Page.requires = Line("body", 3)
    Page.lines = {
        { fs = Page.name, gap = 0 }, { fs = Page.tag, gap = SP.xs }, { fs = Page.zone, gap = SP.s },
        { fs = Page.note, gap = SP.xs }, { fs = Page.currency, gap = SP.m },
        { fs = Page.requires, gap = SP.xs },
    }

    local wp = CreateFrame("Button", nil, col, "UIPanelButtonTemplate")
    wp:SetText(L["Set waypoint"])
    wp:SetSize(math.max(110, wp:GetTextWidth() + 32), 22)
    wp:SetPoint("BOTTOMLEFT", 0, SP.xs)
    wp:SetScript("OnClick", function(self)
        local w = self.target
        if w then
            HA.Waypoints:Set(w.mapID, w.x, w.y, { title = w.title, data = { type = "vendor", npcID = w.npcID } })
        end
    end)
    Page.wp = wp

    local bar = W.NewBar(col, false)
    bar:SetPoint("BOTTOMLEFT", wp, "TOPLEFT", 0, SP.m)
    bar:SetPoint("RIGHT", col, "RIGHT")
    Page.bar = bar
    Page.counts = S.Text(col, "body", "OVERLAY")
    Page.counts:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
    Page.counts:SetTextColor(K.muted[1], K.muted[2], K.muted[3])

    local hdr = W.NewSectionHeader(f)
    hdr:SetPoint("TOPLEFT", 0, -(MODEL_H + 14))
    hdr:SetPoint("TOPRIGHT", 0, -(MODEL_H + 14))
    hdr.text:SetText(L["Wares"])
    Page.wareHeader = hdr

    local holder = CreateFrame("Frame", nil, f)
    holder:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -SP.s)
    holder:SetPoint("BOTTOMRIGHT")
    Page.grid = W.NewGrid(holder, {
        cell = S.wareCell.size, gap = S.wareCell.gap, build = BuildCell, init = InitCell,
    })
    Page.empty = W.NewEmptyState(holder, L["No decor listed"])
    return f
end

local function StackLines()
    local prev
    for _, line in ipairs(Page.lines) do
        local fs = line.fs
        local shown = (fs:GetText() or "") ~= ""
        fs:SetShown(shown)
        if shown then
            fs:ClearAllPoints()
            if prev then
                fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -line.gap)
            else
                fs:SetPoint("TOPLEFT", Page.col, "TOPLEFT")
            end
            fs:SetPoint("RIGHT", Page.col, "RIGHT")
            prev = fs
        end
    end
end

local function ShowMissing()
    ClearModel()
    Page.name:SetText(L["Vendor not found"])
    for i = 2, #Page.lines do Page.lines[i].fs:SetText("") end
    StackLines()
    Page.bar:Hide()
    Page.counts:SetText("")
    Page.wp:Hide()
    Page.wareHeader.right:SetText("")
    RenderMap(Page.map, nil)
    Page.grid:SetData({}, false)
    Page.empty:Update(false)
end

-- Vendor-wide reads: once per open and after data changes; the currency line re-reads while a name loads.
local function VendorMemo(npcID, isRefresh)
    local D = B.Data
    if isRefresh and memo and memo.npcID == npcID and memo.version == D.MemoVersion() then
        return memo
    end
    local vendor = D.Vendor(npcID)
    if not vendor then return nil end
    local wares = D.VendorWares(vendor)
    local mapID, x, y = D.VendorLocation(vendor)
    local requires = D.VendorRequirements(vendor, wares)
    memo = {
        npcID = npcID, version = D.MemoVersion(), vendor = vendor, wares = wares, mapID = mapID, x = x, y = y,
        requires = table.concat(requires, L["; "]), pending = true,
    }
    return memo
end

function Page.Show(route, isRefresh, noPrewarm)
    local D = B.Data
    Page.npcID = route.npcID
    local m = VendorMemo(route.npcID, isRefresh)
    if not m then return ShowMissing() end
    local vendor, wares = m.vendor, m.wares
    if not isRefresh or Page.model.npcID ~= route.npcID then ShowModel(route.npcID) end

    Page.name:SetText(vendor.name or L["Unknown"])
    local place = vendor.zone or L["Unknown"]
    if vendor.subzone then place = L["%s, %s"]:format(vendor.subzone, place) end
    Page.zone:SetText(place)
    local active = D.HolidayActive(vendor)
    W.SetTag(Page.tag, active ~= nil and (active and L["Active"] or L["Not Active"]), active)
    local note, verbatim = D.VendorNote(vendor)
    Page.note:SetText(note or "")
    local nc = verbatim and K.muted or K.body
    Page.note:SetTextColor(nc[1], nc[2], nc[3])
    if m.pending then
        local currencies, pending = D.VendorCurrencies(vendor, wares)
        m.currency, m.pending = table.concat(currencies, L[", "]), pending
    end
    Page.currency:SetText(m.currency ~= "" and S.Muted(L["Currency"]) .. "  " .. m.currency or "")
    Page.requires:SetText(m.requires ~= "" and S.Muted(L["Requires"]) .. "  " .. m.requires or "")
    StackLines()

    RenderMap(Page.map, vendor, m.mapID, m.x, m.y)
    Page.wp.target = m.mapID and { mapID = m.mapID, x = m.x, y = m.y, title = vendor.name, npcID = vendor.npcID }
    Page.wp:SetShown(m.mapID ~= nil)

    local owned, total = D.VendorCounts(vendor, noPrewarm)
    local listed = #wares > 0
    Page.bar:SetShown(listed and total ~= 0)
    Page.counts:SetText(listed and total == 0 and L["None of these wares count toward your collection."] or "")
    if Page.bar:IsShown() then
        Page.bar:SetProgress(L["Owned"], owned, total)
        if not isRefresh then Page.bar:Replay() end
    end
    Page.wareHeader.right:SetText(L["%d items"]:format(#wares))

    local q, hide = B.State.search, B.State.hideOwned
    local data = {}
    for _, itemID in ipairs(wares) do
        local keep = not (hide and D.HidesOwnedItem(itemID))
        if keep and q ~= "" then
            local name = D.ItemName(itemID)
            keep = name ~= nil and name:lower():find(q, 1, true) ~= nil
        end
        if keep then data[#data + 1] = { itemID = itemID, npcID = vendor.npcID } end
    end
    Page.grid:SetData(data, isRefresh, B.Window.HostWidth() - LO.scrollBarGap)
    Page.empty:Update(#data == 0, not listed)
end

function Page.Shown()
    if Page.bar:IsShown() then Page.bar:Replay() end
end

function Page.Hide()
    ClearModel()
    Page.npcID = nil
    memo = nil
end

B.RegisterPage("shop", Page)
