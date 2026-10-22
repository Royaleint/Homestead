-- Achievements, Quests, Professions, Drops and Events: one decor item per row under collapsible headers.
local _, HA = ...

local B = HA.DecorBrowser
local L = HA.L
local S = B.Style
local W = B.Widgets
local LO = S.layout

local Page = { topLevel = true, searchable = true }

local function BuildRow(f)
    f.view = W.NewRow(f, LO.listRowHeight)
    f.view:SetPoint("TOPLEFT")
    f.view:SetPoint("BOTTOMRIGHT")
end

local function InitRow(f, d)
    local D = B.Data
    local link
    if d.achievementID then
        local id = d.achievementID
        link = { gated = true, onClick = function() W.OpenAchievement(id) end,
            tooltipLink = GetAchievementLink(id) }
    elseif d.questID then
        link = { tooltipLink = GetQuestLink(d.questID) or ("quest:" .. d.questID) }
    end
    f.view:Set({
        icon = D.ItemIcon(d.itemID), name = d.name or L["Item %d"]:format(d.itemID), line2 = d.line2,
        state = D.ItemStatus(d.itemID).state, itemID = d.itemID, link = link,
        onClick = function() B.Go({ page = "item", itemID = d.itemID }) end,
        wp = d.wp or (d.wpFromVendor and D.ItemVendorWaypoint(d.itemID)) or nil,
    })
end

function Page.Build(host)
    local f = CreateFrame("Frame", nil, host)
    f:SetAllPoints()
    local shops = B.pages.shops
    Page.list = W.NewList(f, {
        spacing = LO.rowGap,
        extent = function(d) return d.kind == "header" and 24 or d.kind == "vendor" and LO.vendorRowHeight or LO.listRowHeight end,
        kinds = {
            header = { frameType = "HomesteadDecorBrowserHeader", build = W.BuildListHeader, init = W.InitListHeader },
            row = { frameType = "Button", build = BuildRow, init = InitRow },
            vendor = { frameType = "HomesteadDecorBrowserVendorRow", build = shops.BuildVendorRow, init = shops.InitVendorRow },
        },
    })
    Page.empty = W.NewEmptyState(f, L["Nothing to list here."])
    return f
end

function Page.Show(route, isRefresh)
    Page.usesCounts = route.source == "events"
    local data = B.Data.SourceList(route.source, B.State.search, B.State.hideOwned)
    Page.list:SetGroups(data, "sources:" .. route.source, isRefresh and Page.source == route.source)
    Page.source = route.source
    Page.empty:Update(#data == 0)
end

function Page.SetCombatGated(gated)
    Page.list.box:ForEachFrame(function(f)
        if f.view then f.view:SetLinkGated(gated) end
    end)
end

B.RegisterPage("sources", Page)
