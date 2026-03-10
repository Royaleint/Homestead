--[[
    Homestead - Housing Dashboard Overlay
    Adds milestone XP progress and vendor ownership to the Endeavors tab
    of Blizzard's Housing Dashboard UI.
]]

local _, HA = ...

local EventUtil = _G.EventUtil
local initiativesFrame = nil

-------------------------------------------------------------------------------
-- Frame Discovery
-------------------------------------------------------------------------------

local function GetInitiativesFrame()
    -- Re-probe if cached frame is no longer valid
    if initiativesFrame and not initiativesFrame:GetParent() then
        initiativesFrame = nil
    end
    if initiativesFrame then return initiativesFrame end
    local dashboard = _G.HousingDashboardFrame
    if not dashboard then return nil end
    local houseInfo = dashboard.HouseInfoContent
    if not houseInfo then return nil end
    local content = houseInfo.ContentFrame
    if not content then return nil end
    initiativesFrame = content.InitiativesFrame
    return initiativesFrame
end

-------------------------------------------------------------------------------
-- FontString Creation
-------------------------------------------------------------------------------

local function CreateBarMilestoneText(progressBar)
    -- Combined milestone text centered on the progress bar
    local fs = progressBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER", progressBar, "CENTER", 0, 0)
    fs:SetJustifyH("CENTER")
    -- Subtle embossed style matching Blizzard's "Endeavor Progress" bar text
    fs:SetTextColor(1, 1, 1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    fs:SetShadowOffset(1, -1)
    return fs
end

local function CreateOwnershipText(parent)
    -- Vendor ownership line below the "Earn bonus..." text
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local anchor = parent.NeighborhoodGroupText or parent.ProgressBar
    fs:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
    fs:SetJustifyH("CENTER")
    fs:SetTextColor(0.8, 0.8, 0.8)
    return fs
end

-------------------------------------------------------------------------------
-- Update Logic
-------------------------------------------------------------------------------

local barMilestoneText = nil
local ownershipText = nil

local function HideOverlayTexts()
    if barMilestoneText then barMilestoneText:Hide() end
    if ownershipText then ownershipText:Hide() end
end

local function UpdateMilestoneDisplay()
    if not HA.Addon or not HA.Addon.db then return end
    if not HA.Addon.db.profile.endeavors or not HA.Addon.db.profile.endeavors.showMilestoneXP then
        HideOverlayTexts()
        return
    end

    local frame = GetInitiativesFrame()
    if not frame or not frame.InitiativeSetFrame then return end
    if not frame.InitiativeSetFrame:IsShown() then return end

    local progress = HA.EndeavorsData and HA.EndeavorsData:GetMilestoneProgress()
    if not progress then
        HideOverlayTexts()
        return
    end

    local setFrame = frame.InitiativeSetFrame

    -- Create FontStrings on first use
    if not barMilestoneText and setFrame.ProgressBar and setFrame.ProgressBar.TextContainer then
        barMilestoneText = CreateBarMilestoneText(setFrame.ProgressBar)
    end
    if not ownershipText then
        ownershipText = CreateOwnershipText(setFrame)
    end

    -- Bar overlay: combined milestone text
    if barMilestoneText then
        if progress.allMilestonesComplete then
            barMilestoneText:SetText("All Milestones Complete!")
        else
            barMilestoneText:SetFormattedText("Next Milestone: %.0f / %d (%d needed)",
                progress.currentProgress,
                progress.nextMilestoneAmount,
                progress.remaining
            )
        end
        barMilestoneText:Show()
    end

    -- Vendor ownership line
    local activeTheme = HA.EndeavorsData and HA.EndeavorsData:GetActiveTheme()
    local themeData = activeTheme and HA.EndeavorsData.Endeavors[activeTheme]
    local vendorNPC = themeData and themeData.vendorNPC
    local vendor = vendorNPC and HA.EndeavorsData.Vendors[vendorNPC]
    if vendor and vendor.items and HA.VendorData and HA.CatalogStore then
        local total = #vendor.items
        local owned = 0
        for _, item in ipairs(vendor.items) do
            local itemID = HA.VendorData:GetItemID(item)
            local isOwned = HA.CatalogStore:IsOwnedFresh(itemID)
            if isOwned then owned = owned + 1 end
        end
        ownershipText:SetFormattedText("%s: %d / %d items owned", vendor.name, owned, total)
        ownershipText:Show()
    else
        if ownershipText then ownershipText:Hide() end
    end
end

-------------------------------------------------------------------------------
-- Hook Registration (deferred to Blizzard_HousingDashboard load)
-------------------------------------------------------------------------------

-- WoW engine event listener for real-time progress updates.
-- EndeavorsData's own event frame refreshes the cache first; this handler
-- only needs to update the display with the already-fresh data.
local progressFrame = CreateFrame("Frame")
progressFrame:RegisterEvent("NEIGHBORHOOD_INITIATIVE_UPDATED")
progressFrame:SetScript("OnEvent", function()
    UpdateMilestoneDisplay()
end)

local function OnHousingDashboardLoaded()
    local frame = GetInitiativesFrame()
    if frame and frame.InitiativeSetFrame then
        hooksecurefunc(frame.InitiativeSetFrame, "Show", UpdateMilestoneDisplay)
    end

    if HA.Events then
        HA.Events:RegisterCallback("ACTIVE_ENDEAVOR_CHANGED", UpdateMilestoneDisplay)
    end
end

-- Deferred registration — Blizzard_HousingDashboard is demand-loaded
if C_AddOns.IsAddOnLoaded("Blizzard_HousingDashboard") then
    OnHousingDashboardLoaded()
else
    EventUtil.ContinueOnAddOnLoaded("Blizzard_HousingDashboard", OnHousingDashboardLoaded)
end
