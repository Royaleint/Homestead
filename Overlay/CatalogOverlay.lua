--[[
    Homestead - Catalog Source Intelligence
    Adds source type badge icons to Housing Catalog grid items so players
    can see at a glance where unowned items come from without hovering.

    Badge shows the primary source type (vendor > quest > achievement >
    profession > event > drop > hearthsteel) using SourceManager priority
    order, with a sourceText fallback for items not in static data.

    Frame structure (confirmed via in-game spike):
    HousingDashboardFrame > ... > depth-5 unnamed Buttons with .entryInfo
    15 frames in a fixed pool, recycled/virtualized on scroll.

    Hooking strategy: Blizzard's catalog scroll does NOT fire OnShow on
    entry frames — it repositions them and swaps .entryInfo directly.
    We use a throttled OnUpdate on the dashboard to re-evaluate badges
    at 5Hz. The badgeCache makes cache hits (same itemID) near-free.
]]

local _, HA = ...

local Constants = HA.Constants
local SourceBadgeAtlas = Constants.SourceBadgeAtlas

-- Badge configuration
local BADGE_SIZE = 20
local BADGE_PADDING = 2

-- Per-atlas size overrides for atlases that render too small at BADGE_SIZE
local ATLAS_SIZE_OVERRIDE = {
    [SourceBadgeAtlas.profession] = 34,
}

-- Throttle: how often (seconds) to refresh badges
local REFRESH_INTERVAL = 0.2

-- Per-frame result cache: entryFrame → {itemID, atlas or false}
-- Stores the resolved atlas so we skip GetSource on repeat evaluations.
local badgeCache = {}

-- Per-frame badge texture references
local badgeTextures = {}

-- Set of discovered entry frames (hooked for OnShow as bonus, but OnUpdate
-- is the primary driver). Keyed by frame reference.
local hookedFrames = {}

-- Discovery counter: run tree walk for the first N ticks after dashboard
-- opens, then stop (all frames should be populated by then).
local DISCOVERY_TICKS = 10
local discoveryTicksRemaining = 0

-- OnUpdate elapsed accumulator
local timeSinceRefresh = 0

-------------------------------------------------------------------------------
-- Frame Discovery
-------------------------------------------------------------------------------

-- Scan for entry Button frames with .entryInfo and hook any we haven't seen.
-- Called periodically during the first ~2 seconds after dashboard opens.
local function DiscoverEntryFrames()
    local dashboard = _G["HousingDashboardFrame"]
    if not dashboard then return end

    local function SearchChildren(frame, depth)
        if depth > 6 then return end
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            if child.entryInfo and child:GetObjectType() == "Button"
                and not hookedFrames[child] then
                hookedFrames[child] = true
            end
            SearchChildren(child, depth + 1)
        end
    end

    SearchChildren(dashboard, 1)
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

-- Fallback: check entryInfo.sourceText for source hints when
-- SourceManager has no static data for this item.
local function GetSourceBadgeFromEntryInfo(entryInfo)
    local sourceText = entryInfo.sourceText
    if not sourceText or sourceText == "" then return nil end

    if sourceText:find("Hearthsteel") or sourceText:find("Battle.net Shop") then
        return SourceBadgeAtlas.hearthsteel
    end

    return nil
end

-- Create or retrieve the badge texture for an entry frame.
local function GetBadgeTexture(entryFrame)
    local badge = badgeTextures[entryFrame]
    if badge then return badge end

    badge = entryFrame:CreateTexture(nil, "OVERLAY")
    badge:SetSize(BADGE_SIZE, BADGE_SIZE)
    badge:SetPoint("BOTTOMLEFT", entryFrame, "BOTTOMLEFT",
        BADGE_PADDING, BADGE_PADDING)
    badgeTextures[entryFrame] = badge
    return badge
end

-- Hide a badge texture if it exists for this frame.
local function HideBadge(entryFrame)
    local badge = badgeTextures[entryFrame]
    if badge then badge:Hide() end
end

-- Apply badge atlas to a frame, with per-atlas size override.
-- Oversized atlases get a negative anchor offset so the visible artwork
-- stays flush with the bottom-left corner like the default-sized badges.
local function ShowBadgeAtlas(entryFrame, atlas)
    local badge = GetBadgeTexture(entryFrame)
    local size = ATLAS_SIZE_OVERRIDE[atlas] or BADGE_SIZE
    badge:SetSize(size, size)
    badge:SetAtlas(atlas, false)

    -- Re-anchor: pull oversized icons toward the corner by half the excess
    local offset = (size - BADGE_SIZE) / 2
    badge:ClearAllPoints()
    badge:SetPoint("BOTTOMLEFT", entryFrame, "BOTTOMLEFT",
        BADGE_PADDING - offset, BADGE_PADDING - offset)

    badge:Show()
end

-- Update the source badge on an entry frame.
-- Called from OnUpdate tick — must be fast on cache hit.
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

    -- Cache hit: re-apply visual state without calling GetSource.
    local cached = badgeCache[entryFrame]
    if cached and cached[1] == itemID then
        if cached[2] then
            ShowBadgeAtlas(entryFrame, cached[2])
        else
            HideBadge(entryFrame)
        end
        return
    end

    -- Cache miss: full evaluation

    -- Look up the source badge atlas (static data first, then sourceText)
    local atlas = GetSourceBadgeAtlas(itemID)
    if not atlas then
        atlas = GetSourceBadgeFromEntryInfo(entryInfo)
    end
    if not atlas then
        badgeCache[entryFrame] = {itemID, false}
        return HideBadge(entryFrame)
    end

    -- Show the badge and cache the result
    badgeCache[entryFrame] = {itemID, atlas}
    ShowBadgeAtlas(entryFrame, atlas)
end

-------------------------------------------------------------------------------
-- Cache Invalidation
-------------------------------------------------------------------------------

-- Force all entry frames to re-evaluate on next tick.
-- Called when ownership or source data changes.
local function InvalidateAllBadges()
    wipe(badgeCache)
end

-- Re-badge all currently visible entry frames (after invalidation).
local function RefreshVisibleBadges()
    InvalidateAllBadges()
    for entryFrame in pairs(hookedFrames) do
        if entryFrame:IsShown() then
            UpdateEntryBadge(entryFrame)
        end
    end
end

-------------------------------------------------------------------------------
-- OnUpdate Driver
-------------------------------------------------------------------------------

-- Throttled update: discover new frames (early ticks only), then refresh
-- all visible badges. Runs at ~5Hz while the dashboard is shown.
local function OnDashboardUpdate(_, elapsed)
    timeSinceRefresh = timeSinceRefresh + elapsed
    if timeSinceRefresh < REFRESH_INTERVAL then return end
    timeSinceRefresh = 0

    -- Discover new entry frames for the first ~2 seconds after open
    if discoveryTicksRemaining > 0 then
        discoveryTicksRemaining = discoveryTicksRemaining - 1
        DiscoverEntryFrames()
    end

    -- Refresh visible badges
    for entryFrame in pairs(hookedFrames) do
        if entryFrame:IsShown() then
            UpdateEntryBadge(entryFrame)
        end
    end
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

local function OnHousingDashboardLoaded()
    local dashboard = _G["HousingDashboardFrame"]
    if not dashboard then return end

    -- Reset discovery on each dashboard open so we catch late-populating frames
    dashboard:HookScript("OnShow", function()
        discoveryTicksRemaining = DISCOVERY_TICKS
        timeSinceRefresh = 0
    end)

    -- OnUpdate drives all badge refreshes — fires every render frame,
    -- throttled internally to REFRESH_INTERVAL.
    dashboard:HookScript("OnUpdate", OnDashboardUpdate)

    -- If dashboard is already shown (opened before addon loaded), start now
    if dashboard:IsShown() then
        discoveryTicksRemaining = DISCOVERY_TICKS
        timeSinceRefresh = 0
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
