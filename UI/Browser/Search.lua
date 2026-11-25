-- Search: the header box's words, looked up in the side panel's search engine (HA.SearchProvider), as one list:
-- vendors, then decor by source, in the engine's order. No page matches text itself. Typing searches DELAY after
-- the last key and Enter at once; the first search is one history step, more typing searches in place, and
-- clearing the box goes Back. A Browser that searched gives the engine's index back when it hides.
local _, HA = ...

local B, L = HA.DecorBrowser, HA.L
local S, W, D, CG, Facts = B.Style, B.Widgets, B.Data, B.CanGet, B.Facts
local LO = S.layout

local DELAY = 0.3
local OPTIONS = { includeItemResults = true, anyFaction = true }

local Page = {}
local host, list, empty, results, rev, timer
local query, active, searched, fill = "", false, false, false

local function Engine()
    local E = HA.SearchProvider
    E:Initialize()
    return E
end

local function Run()
    local E = Engine()
    results, rev, searched = E:Search(query, OPTIONS), E:GetRevision(), true
end

local function Stop()
    if timer then timer:Cancel() end
    timer = nil
end

local function ItemRow(r)
    local id = r.itemID
    local e = CG.Entry(id)
    local info = e and e.info
    local state, arg = B.ItemState(id)
    return { kind = "row", itemID = id, name = r.itemName, quality = info and info.quality or C_Item.GetItemQualityByID(id),
        icon = D.ItemIcon(id), state = state, arg = arg,
        line2 = HA.FormatSourceLine({ type = r.sourceType, data = r.sourceData }),
        onClick = function(button)
            if button == "RightButton" and B.OpenInCatalog(id) then return end
            B.Go({ kind = "item", id = id })
        end }
end

-- The first vendor row a draw describes may ask for the vendor counts again, as a list's first build does.
local function VendorRow(r)
    local d = B.VendorRow(r.vendor, fill)
    fill = false
    if r.matchType == "item" then
        local text = r.matchCount == 1 and L["%d match, %s"] or L["%d matches, %s"]
        d.right = text:format(r.matchCount, d.right)
    end
    return d
end

-- A row is described when it first draws, so a search asks the client nothing for the rows off screen. An item
-- row's right-click opens the Housing Dashboard, as a Catalog tile's does.
local rowKind = {
    frameType = "Button",
    build = W.BuildRow,
    init = function(f, d)
        local r = d.r
        d.d = d.d or r.vendor and VendorRow(r) or ItemRow(r)
        if r.vendor then f:RegisterForClicks("LeftButtonUp") else f:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        f:Set(d.d)
    end,
}

local function Extent(d)
    if d.kind == "header" then return W.HeaderExtent(d, list.box:GetWidth()) end
    if d.kind == "foot" then return W.FooterHeight(d, list.box:GetWidth()) end
    return W.RowHeight()
end

-- Every result is listed or, under the Hide toggle, counted in the footer.
local function Draw(keep)
    local data, group, seen = {}, nil, {}
    fill = true
    local hidden = { kind = "foot", hidden = 0, collected = 0, faction = 0, onShow = B.ShowHidden }
    for _, r in ipairs(results) do
        local v = r.vendor
        local why = B.State.hideNA and CG.HiddenBy(v and { vendor = v } or r.itemID)
        if why then
            hidden.hidden = hidden.hidden + 1
            hidden[why] = hidden[why] + 1
            if why == "faction" then
                local label = v and HA.BadgeCalculation:FactionLabel(v) or not v and CG.FactionLabel(r.itemID) or ""
                seen[label] = (seen[label] or 0) + 1
            end
        else
            local t = v and "vendor" or r.sourceType
            if t ~= group then
                group = t
                data[#data + 1] = { kind = "header", text = S.sourceLabel[t .. "s"] or S.sourceLabel[t] }
            end
            data[#data + 1] = { kind = "row", r = r }
        end
    end
    hidden.parts = Facts.FactionParts(seen)
    local note = hidden.hidden > 0 and hidden or nil
    list:SetShown(data[1] ~= nil)
    if data[1] then
        if note then data[#data + 1] = note end
        empty:Hide()
        list:SetData(data, keep)
    else
        local text = L["Nothing matches your search."]
        empty:Set("noResults", { title = L["No results"], text = note and text .. " " .. W.FooterText(note) or text,
            onShow = note and B.ShowHidden })
    end
end

-- Back to where the search was started from; the Overview when there is nowhere to go back to.
local function Leave()
    if not B.Back() then B.GoTop({ kind = "overview" }) end
end

-- Enter, and the typing delay's end.
function B.SearchNow(text)
    Stop()
    if not text:match("%S") then return end
    if not active then
        B.Go({ kind = "search", seed = { search = text } })
        return
    end
    query = text
    Run()
    Draw(false)
end

function B.SearchTyped(text)
    Stop()
    if text:match("%S") then
        timer = C_Timer.NewTimer(DELAY, function()
            timer = nil
            B.SearchNow(B.Window.search:GetText())
        end)
    elseif active then
        Leave()
    end
end

function B.SearchFocus()
    Engine():PreWarm()
end

function Page:Closed()
    Stop()
    if searched then
        searched = false
        HA.SearchProvider:Invalidate()
    end
end

-- The list is built the first time the page shows: a Browser that never searches builds none of it.
function Page:Build(parent)
    host = parent
end

local function BuildList()
    local well = W.Well(host)
    well:SetPoint("TOPLEFT")
    well:SetPoint("BOTTOMRIGHT")
    local holder = CreateFrame("Frame", nil, well)
    holder:SetPoint("TOPLEFT", LO.wellPad, -LO.wellPad)
    holder:SetPoint("BOTTOMRIGHT", -LO.wellPad, LO.wellPad)
    list = W.NewList(holder, {
        extent = Extent, reclaim = true, kinds = { row = rowKind, header = W.headerKind, foot = W.footerKind },
    })
    empty = W.NewEmptyState(holder)
end

-- A forward Show searches the seed, which the box already holds; Back gives saved, and the box its words again.
function Page:Show(route, saved)
    if not list then BuildList() end
    active = true
    query = saved and saved.query or route.seed.search
    if saved then B.Window.SetSearch(query) end
    Run()
    Draw(false)
    if saved then list.box:ScrollToOffset(saved.scroll, true) end
end

function Page:Save()
    return { query = query, scroll = list.box:GetDerivedScrollOffset() }
end

function Page:Hide()
    active = false
    B.HideTooltip()
end

-- Any refresh but a repaint searches again: a name that arrived or a moved index can change the results.
function Page:Refresh(reason)
    if not results then return end
    active = true
    if reason == "paint" and rev == Engine():GetRevision() then
        W.RepaintRows(list)
        return
    end
    Run()
    Draw(true)
end

-- Nothing on the list waits for the end of combat.
function Page:SetCombat() end

B.RegisterPage("search", Page)
