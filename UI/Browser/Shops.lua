-- Vendor lists: one expansion's shops grouped by zone, or the shops near you, nearest first.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local S = B.Style
local W = B.Widgets
local LO = S.layout

local Page = { topLevel = true, searchable = true, usesCounts = true }
local memo
local noPrewarm = false
local asked = false

-- A cold count cache is asked to fill once per show, not once per row.
local function Counts(vendor)
    local owned, total = B.Data.VendorCounts(vendor, noPrewarm or asked)
    if total == nil then asked = true end
    return owned, total
end

function Page.Matches(vendor, q)
    if q == "" then return true end
    local hay = ((vendor.name or "") .. " " .. (vendor.zone or "") .. " " .. (vendor.subzone or "")):lower()
    return hay:find(q, 1, true) ~= nil
end

-- Near You keeps its order; an expansion's shops sort by zone, then name, under a zone header.
function Page.Layout(vendors, nearYou)
    local data = {}
    if not nearYou then
        table.sort(vendors, function(a, b)
            local za, zb = a.zone or "", b.zone or ""
            if za ~= zb then return za < zb end
            return (a.name or "") < (b.name or "")
        end)
    end
    local last
    for _, vendor in ipairs(vendors) do
        local zone = vendor.zone or L["Unknown"]
        if not nearYou and zone ~= last then
            last = zone
            data[#data + 1] = { kind = "header", text = zone }
        end
        data[#data + 1] = { kind = "vendor", vendor = vendor }
    end
    return data
end

function Page.CountsText(owned, total)
    if total == nil then return L["Counts not loaded yet"] end
    if total == 0 then return L["No decor listed"] end
    return L["%d of %d owned"]:format(owned, total)
end

function Page.BuildVendorRow(f)
    f.view = W.NewRow(f, LO.vendorRowHeight, "compact")
    f.view:SetPoint("TOPLEFT")
    f.view:SetPoint("BOTTOMRIGHT")
end

function Page.InitVendorRow(f, d)
    local D = B.Data
    local vendor = d.vendor
    local name = vendor.name or L["Unknown"]
    if D.IsOppositeFaction(vendor) then
        local label = D.VendorFactionLabel(vendor)
        if label then name = L["%s (%s)"]:format(name, label) end
    end
    local owned, total = Counts(vendor)
    local line = L["%s - %s"]:format(vendor.subzone or vendor.zone or L["Unknown"], Page.CountsText(owned, total))
    local note = D.VendorNote(vendor)
    if note then line = L["%s (%s)"]:format(line, note) end
    local mapID, x, y = D.VendorLocation(vendor)
    f.view:Set({
        atlas = S.atlas.vendorPin, name = name, line2 = line,
        tag = d.active ~= nil and (d.active and L["Active"] or L["Not Active"]) or nil, tagOn = d.active,
        onClick = function() B.Go({ page = "shop", npcID = vendor.npcID }) end,
        wp = mapID and { mapID = mapID, x = x, y = y, title = vendor.name,
            data = { type = "vendor", npcID = vendor.npcID } } or nil,
    })
end

function Page.Build(host)
    local f = CreateFrame("Frame", nil, host)
    f:SetAllPoints()
    Page.list = W.NewList(f, {
        spacing = LO.rowGap,
        extent = function(d) return d.kind == "header" and 24 or LO.vendorRowHeight end,
        kinds = {
            header = { frameType = "HomesteadDecorBrowserHeader", build = W.BuildListHeader, init = W.InitListHeader },
            vendor = { frameType = "Button", build = Page.BuildVendorRow, init = Page.InitVendorRow },
        },
    })
    Page.emptyNear = W.NewEmptyState(f, L["No vendors found on your current map."])
    Page.emptyExpansion = W.NewEmptyState(f, L["No vendors to show."])
    return f
end

local function Vendors(route, isRefresh)
    local D = B.Data
    local key = route.nearYou and "near" or route.expansion
    if isRefresh and memo and memo.key == key and memo.version == D.MemoVersion() then return memo.vendors end
    local vendors
    if route.nearYou then vendors = D.NearYou() else vendors = D.VendorsByExpansion(route.expansion) end
    memo = { key = key, version = D.MemoVersion(), vendors = vendors }
    return vendors
end

function Page.Show(route, isRefresh, skipPrewarm)
    local D = B.Data
    noPrewarm, asked = skipPrewarm, false
    local vendors = Vendors(route, isRefresh)
    local q, hide = B.State.search, B.State.hideOwned
    local kept = {}
    for _, vendor in ipairs(vendors) do
        local keep = Page.Matches(vendor, q)
        if keep and hide then keep = not D.HidesOwnedVendor(Counts(vendor)) end
        if keep then kept[#kept + 1] = vendor end
    end
    local data = Page.Layout(kept, route.nearYou)
    local near, none, nothing = route.nearYou == true, #data == 0, #vendors == 0
    Page.emptyNear:Update(near and none, nothing)
    Page.emptyExpansion:Update(not near and none, nothing)
    Page.list:SetGroups(data, "shops:" .. (route.nearYou and "near" or route.expansion), isRefresh)
end

function Page.Hide()
    memo = nil
end

B.RegisterPage("shops", Page)
