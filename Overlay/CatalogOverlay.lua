--[[
    Homestead - Catalog Source Intelligence
    Adds source type badge icons to Housing Catalog grid items so players
    can see at a glance where unowned items come from without hovering.

    Badge shows the primary source type (vendor > quest > achievement >
    profession > event > drop) using SourceManager priority order.
    Owned items are skipped — Blizzard already marks those.

    Frame structure (confirmed via in-game spike):
    HousingDashboardFrame > ... > depth-5 unnamed Buttons with .entryInfo
    15 frames in a fixed pool, recycled/virtualized on scroll.
    OnShow fires ~9,700 times per scroll session but only ~15 have actual
    itemID changes — cache lastItemID and bail early.
]]

local _, HA = ...

local Constants = HA.Constants
local SourceBadgeAtlas = Constants.SourceBadgeAtlas

-- Badge configuration
local BADGE_SIZE = 14
local BADGE_PADDING = 2

-- Per-frame cache: entryFrame → last processed itemID
local lastItemID = {}

-- Per-frame badge texture references
local badgeTextures = {}

-- Whether entry frames have been discovered and hooked
local entryFramesHooked = false

-------------------------------------------------------------------------------
-- Frame Discovery
-------------------------------------------------------------------------------

-- Find the 15 entry Button frames inside HousingDashboardFrame.
-- Entry frames are unnamed Buttons at depth 5 with .entryInfo field.
local function FindEntryFrames()
    local dashboard = _G["HousingDashboardFrame"]
    if not dashboard then return nil end

    local entries = {}
    local function SearchChildren(frame, depth)
        if depth > 6 then return end
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            if child.entryInfo and child:GetObjectType() == "Button" then
                entries[#entries + 1] = child
            else
                SearchChildren(child, depth + 1)
            end
        end
    end

    SearchChildren(dashboard, 1)
    return #entries > 0 and entries or nil
end

-------------------------------------------------------------------------------
-- Badge Logic
-------------------------------------------------------------------------------

-- Get the atlas name for the primary source of an item.
-- Returns atlas string or nil if no source is known.
local function GetSourceBadgeAtlas(itemID)
    if not HA.SourceManager then return nil end

    local source = HA.SourceManager:GetSource(itemID)
    if not source then return nil end

    local sourceType = HA.SourceManager:NormalizeSourceType(source.type)
    return sourceType and SourceBadgeAtlas[sourceType]
end

-- Create or retrieve the badge texture for an entry frame.
local function GetBadgeTexture(entryFrame)
    local badge = badgeTextures[entryFrame]
    if badge then return badge end

    badge = entryFrame:CreateTexture(nil, "OVERLAY")
    badge:SetSize(BADGE_SIZE, BADGE_SIZE)
    badge:SetPoint("BOTTOMRIGHT", entryFrame, "BOTTOMRIGHT",
        -BADGE_PADDING, BADGE_PADDING)
    badgeTextures[entryFrame] = badge
    return badge
end

-- Hide a badge texture if it exists for this frame.
local function HideBadge(entryFrame)
    local badge = badgeTextures[entryFrame]
    if badge then badge:Hide() end
end

-- Update the source badge on an entry frame.
-- Called from OnShow hook — must be fast.
local function UpdateEntryBadge(entryFrame)
    local entryInfo = entryFrame.entryInfo
    if not entryInfo then return HideBadge(entryFrame) end

    local itemID = entryInfo.itemID
    if not itemID then return HideBadge(entryFrame) end

    -- Settings check before cache guard so toggling takes effect immediately
    if HA.Addon and HA.Addon.db
        and HA.Addon.db.profile.overlay
        and not HA.Addon.db.profile.overlay.showOnHousingCatalog then
        return HideBadge(entryFrame)
    end

    -- Performance guard: bail if itemID hasn't changed
    if lastItemID[entryFrame] == itemID then
        return
    end
    lastItemID[entryFrame] = itemID

    -- Skip owned items — Blizzard already marks these.
    -- firstAcquisitionBonus == 0 means owned (confirmed in spike).
    if entryInfo.firstAcquisitionBonus == 0 then return HideBadge(entryFrame) end

    -- Also check CatalogStore for items owned but not yet reflected
    -- in entryInfo (e.g. mid-session purchases before catalog refresh)
    if HA.CatalogStore and HA.CatalogStore:IsOwned(itemID) then
        return HideBadge(entryFrame)
    end

    -- Look up the source badge atlas
    local atlas = GetSourceBadgeAtlas(itemID)
    if not atlas then return HideBadge(entryFrame) end

    -- Show the badge
    local badge = GetBadgeTexture(entryFrame)
    badge:SetAtlas(atlas, false)
    badge:Show()
end

-------------------------------------------------------------------------------
-- Cache Invalidation
-------------------------------------------------------------------------------

-- Force all entry frames to re-evaluate on next OnShow.
-- Called when ownership or source data changes.
local function InvalidateAllBadges()
    wipe(lastItemID)
end

-- Re-badge all currently visible entry frames (after invalidation).
local function RefreshVisibleBadges()
    InvalidateAllBadges()
    for entryFrame in pairs(badgeTextures) do
        if entryFrame:IsShown() then
            UpdateEntryBadge(entryFrame)
        end
    end
end

-------------------------------------------------------------------------------
-- Hook Registration
-------------------------------------------------------------------------------

local function HookEntryFrames()
    if entryFramesHooked then return end

    local entries = FindEntryFrames()
    if not entries then return end

    for _, entryFrame in ipairs(entries) do
        entryFrame:HookScript("OnShow", function(self)
            UpdateEntryBadge(self)
        end)

        -- Initial badge for frames already shown
        if entryFrame:IsShown() then
            UpdateEntryBadge(entryFrame)
        end
    end

    entryFramesHooked = true
end

local function OnHousingDashboardLoaded()
    -- HousingDashboardFrame exists now, but entry frames may not be
    -- populated until the catalog tab is actually opened.
    -- Hook OnShow on the dashboard itself to catch first open.
    local dashboard = _G["HousingDashboardFrame"]
    if not dashboard then return end

    dashboard:HookScript("OnShow", function()
        -- Entry frames are created by the time the dashboard shows.
        -- Use a short delay to let Blizzard finish populating the pool.
        C_Timer.After(0, function()
            HookEntryFrames()
        end)
    end)

    -- If already shown (player opened catalog before addon loaded),
    -- hook immediately.
    if dashboard:IsShown() then
        C_Timer.After(0, function()
            HookEntryFrames()
        end)
    end
end

-------------------------------------------------------------------------------
-- Event-Driven Cache Invalidation
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ACHIEVEMENT_EARNED")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("NEW_RECIPE_LEARNED")
eventFrame:SetScript("OnEvent", function()
    RefreshVisibleBadges()
end)

-- Inter-module ownership change
if HA.Events then
    HA.Events:RegisterCallback("OWNERSHIP_UPDATED", RefreshVisibleBadges)
end

-- Register external refresher so Overlay:RefreshAll() also updates catalog badges
if HA.Overlay then
    HA.Overlay:RegisterExternalRefresher("catalogBadges", RefreshVisibleBadges)
end

-------------------------------------------------------------------------------
-- Deferred Initialization
-------------------------------------------------------------------------------

if C_AddOns.IsAddOnLoaded("Blizzard_HousingDashboard") then
    OnHousingDashboardLoaded()
else
    EventUtil.ContinueOnAddOnLoaded("Blizzard_HousingDashboard", OnHousingDashboardLoaded)
end
