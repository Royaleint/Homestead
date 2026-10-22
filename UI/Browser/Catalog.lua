-- Catalog tab: every decor item, with the item detail beside the list. Only the detail pane exists so far.
local _, HA = ...

local B = HA.DecorBrowser

local Tab = {}
local detail, shownItem

function Tab.Build(parent)
    detail = CreateFrame("Frame", nil, parent)
    detail:SetAllPoints()
    detail:Hide()
    B.ItemDetail.Build(detail)
end

-- nil keeps what was shown; a table replaces it.
function Tab.Show(opts)
    if not opts then
        Tab.Refresh()
        return
    end
    shownItem = opts.itemID
    if shownItem then
        B.ItemDetail.Show(shownItem)
        detail:Show()
    else
        B.ItemDetail.Clear()
        detail:Hide()
    end
end

function Tab.Hide()
    B.ItemDetail.Clear()
end

-- Also brings back what Hide cleared.
function Tab.Refresh()
    if shownItem then B.ItemDetail.Show(shownItem) end
end

function Tab.SetCombat(inCombat)
    B.ItemDetail.SetCombat(inCombat)
end

B.RegisterTab("catalog", Tab)
