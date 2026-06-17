--[[
    Homestead - Catalog Source Intelligence
    Adds source type badge icons and accessibility border glow to Housing
    Catalog grid items so players can see at a glance where unowned items
    come from and whether they can obtain them without hovering.

    Badge shows the primary source type (vendor > quest > achievement >
    profession > event > drop > hearthsteel) using SourceManager priority
    order, with a sourceText fallback for items not in static data.

    Glow shows accessibility state:
    - Green: owned (at least 1 copy)
    - Yellow: unowned but a source has all requirements met
    - Red: unowned and no source has met requirements
    - No glow: no source data available

    Frame structure (confirmed via in-game spike):
    HousingDashboardFrame > ... > depth-5 unnamed Buttons with .entryInfo
    15 frames in a fixed pool, recycled/virtualized on scroll.

    Hooking strategy: Blizzard's catalog scroll does NOT fire OnShow on
    entry frames — it repositions them and swaps .entryInfo directly.
    We use a throttled OnUpdate on the dashboard to re-evaluate overlays
    at 5Hz. The overlayCache makes cache hits (same itemID) near-free.
]]

local _, HA = ...

local Constants = HA.Constants
local SourceBadgeAtlas = Constants.SourceBadgeAtlas

-- Badge configuration
local BADGE_SIZE = 18
local BADGE_PADDING = 2

-- Per-atlas size overrides for atlases that render too small at BADGE_SIZE
local ATLAS_SIZE_OVERRIDE = {
    [SourceBadgeAtlas.profession] = 30,
    [SourceBadgeAtlas.drop] = 30,
}

-- Accessibility glow colors: {r, g, b, alpha}
local GLOW_COLORS = {
    owned     = { 0.0, 0.8, 0.0, 0.6 },  -- green: you have at least 1
    available = { 1.0, 0.8, 0.0, 0.6 },  -- yellow: unowned, source reqs met
    blocked   = { 1.0, 0.15, 0.15, 0.9 }, -- red: unowned, all sources blocked
}

-- Throttle: how often (seconds) to refresh overlays
local REFRESH_INTERVAL = 0.2

-- Per-frame result cache: entryFrame → {itemID, atlas or false, glowState or false}
-- Stores resolved badge + glow so we skip GetSource on repeat evaluations.
local overlayCache = setmetatable({}, { __mode = "k" })

-- Per-frame badge texture references
local badgeTextures = setmetatable({}, { __mode = "k" })

-- Per-frame glow texture references
local glowTextures = setmetatable({}, { __mode = "k" })

-- Per-frame checkmark texture references
local checkmarkTextures = setmetatable({}, { __mode = "k" })

-- Set of discovered entry frames (hooked for OnShow as bonus, but OnUpdate
-- is the primary driver). Keyed by frame reference.
local hookedFrames = setmetatable({}, { __mode = "k" })

-- OnUpdate elapsed accumulator
local timeSinceRefresh = 0
local dashboardVisible = false

-------------------------------------------------------------------------------
-- Frame Discovery
-------------------------------------------------------------------------------

-- Recursively search for entry Button frames with .entryInfo.
-- Hoisted to file scope to avoid closure allocation per tick.
local function ProcessChildren(depth, ...)
    if depth > 6 then return end
    for i = 1, select("#", ...) do
        local child = select(i, ...)
        if child.entryInfo and child:GetObjectType() == "Button"
            and not hookedFrames[child] then
            hookedFrames[child] = true
        end
        ProcessChildren(depth + 1, child:GetChildren())
    end
end

local function SearchChildren(frame, depth)
    ProcessChildren(depth, frame:GetChildren())
end

-- Scan for entry Button frames with .entryInfo and hook any we haven't seen.
-- Called periodically while the dashboard is shown.
local function DiscoverEntryFrames()
    local dashboard = _G["HousingDashboardFrame"]
    if not dashboard then return end
    SearchChildren(dashboard, 1)
end

-------------------------------------------------------------------------------
-- sourceText Resolution
-------------------------------------------------------------------------------

-- Resolve sourceText for a catalog item.  Tries the frame's entryInfo first,
-- falls back to the Blizzard API (safe from addon code per CLAUDE.md).
-- Result is NOT cached here — the overlayCache in UpdateEntryOverlay handles it.
local function ResolveSourceText(entryInfo, itemID)
    local sourceText = entryInfo and entryInfo.sourceText
    if sourceText and sourceText ~= "" then return sourceText end

    -- Frame entryInfo may omit sourceText; fetch via API
    if itemID and C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
        local ok, fullInfo = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, itemID, false)
        if ok and fullInfo and fullInfo.sourceText and fullInfo.sourceText ~= "" then
            return fullInfo.sourceText
        end
    end

    return nil
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

-- Fallback: resolve sourceText through the shared parser so catalog badges stay
-- aligned with the addon's source taxonomy and locale profiles.
local function GetSourceBadgeFromSourceText(sourceText)
    if not sourceText or sourceText == "" then return nil end

    if sourceText:find("Hearthsteel") or sourceText:find("Battle.net Shop") or sourceText:find("In%-Game Shop") then
        return SourceBadgeAtlas.shop
    end

    if not HA.SourceTextParser or not HA.SourceTextParser.ParseSourceText
        or not HA.SourceManager or not HA.SourceManager.NormalizeSourceType then
        return nil
    end

    local locale = GetLocale and GetLocale() or "enUS"
    local parsed = HA.SourceTextParser:ParseSourceText(sourceText, locale)
    local firstSource = parsed and parsed.sources and parsed.sources[1]
    if not firstSource or not firstSource.sourceType then
        return nil
    end

    local normalizedType = HA.SourceManager:NormalizeSourceType(firstSource.sourceType)
    return normalizedType and SourceBadgeAtlas[normalizedType]
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

-------------------------------------------------------------------------------
-- Glow Logic
-------------------------------------------------------------------------------

-- Forward declaration for HideGlow (referenced by ShowGlow fallback)
local HideGlow

-- Forward declaration for HideCheckmark (referenced by HideAllOverlays)
local HideCheckmark

-- Create or retrieve the border glow texture for an entry frame.
-- Atlas is desaturated so SetVertexColor produces exact colors.
local function GetGlowTexture(entryFrame)
    local glow = glowTextures[entryFrame]
    if glow then return glow end

    glow = entryFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
    glow:SetAllPoints(entryFrame)
    glow:SetAtlas("bags-glow-heirloom")
    glow:SetDesaturated(true)
    glow:Hide()
    glowTextures[entryFrame] = glow
    return glow
end

-- Show glow with the color for a given state ("owned", "available", "blocked").
local function ShowGlow(entryFrame, state)
    local color = GLOW_COLORS[state]
    if not color then return HideGlow(entryFrame) end

    local glow = GetGlowTexture(entryFrame)
    glow:SetVertexColor(color[1], color[2], color[3], color[4])
    glow:Show()
end

-- Hide the glow texture if it exists for this frame.
HideGlow = function(entryFrame)
    local glow = glowTextures[entryFrame]
    if glow then glow:Hide() end
end

-------------------------------------------------------------------------------
-- Owned Item Style
-------------------------------------------------------------------------------

-- Create or retrieve checkmark texture for an entry frame.
local function GetCheckmarkTexture(entryFrame)
    local check = checkmarkTextures[entryFrame]
    if check then return check end

    check = entryFrame:CreateTexture(nil, "OVERLAY", nil, 2)
    check:SetSize(20, 20)
    check:SetPoint("TOPRIGHT", entryFrame, "TOPRIGHT", -2, -2)
    check:SetAtlas("common-icon-checkmark")
    check:SetVertexColor(0.0, 0.9, 0.0)
    check:Hide()
    checkmarkTextures[entryFrame] = check
    return check
end

local function ShowCheckmark(entryFrame)
    GetCheckmarkTexture(entryFrame):Show()
end

HideCheckmark = function(entryFrame)
    local check = checkmarkTextures[entryFrame]
    if check then check:Hide() end
end

-- Apply owned item visual style to an entry frame.
-- style: "default", "none", "dim", or "checkmark"
-- isOwned: true if the item is owned
local function ApplyOwnedStyle(entryFrame, style, isOwned)
    if not isOwned then
        entryFrame:SetAlpha(1.0)
        HideCheckmark(entryFrame)
        return
    end

    if style == "dim" then
        entryFrame:SetAlpha(0.5)
        HideCheckmark(entryFrame)
    elseif style == "checkmark" then
        entryFrame:SetAlpha(1.0)
        ShowCheckmark(entryFrame)
    else -- "default" or "none": no additional visual treatment
        entryFrame:SetAlpha(1.0)
        HideCheckmark(entryFrame)
    end
end

-- Determine the accessibility state for an item.
-- Returns "owned", "available", "blocked", or nil (no source data).
-- Ownership uses Blizzard's GetEntryTotalOwned contract via
-- CatalogStore:ComputeOwnedFromInfo (totalNumStored + remainingRedeemable +
-- totalNumPlaced > 0), which matches Blizzard's Collected/Uncollected filter.
-- sourceText is pre-resolved by the caller to avoid redundant API calls.
local function GetAccessibilityState(itemID, entryInfo, sourceText)
    -- Check ownership via the cache-aware path (same as tooltips/merchant badge).
    -- NOT ComputeOwnedFromInfo(entryInfo): the catalog frame's entryInfo carries
    -- firstAcquisitionBonus but NOT the owned-count fields (totalNumStored/…),
    -- so the count formula false-negatived every owned item to "available" (all
    -- yellow — HS-123 Gate-2). IsOwnedFresh serves owned from the persistent cache
    -- plus a fresh tryGetOwnedInfo probe, so it has the counts it needs.
    if HA.CatalogStore and HA.CatalogStore:IsOwnedFresh(itemID, true) then
        return "owned"
    end

    -- Check if any source has requirements met
    if HA.SourceManager then
        local bestSource = HA.SourceManager:GetBestAvailableSource(itemID)
        if bestSource then
            return "available"
        end

        -- Has sources but none available right now
        local primarySource = HA.SourceManager:GetSource(itemID)
        if primarySource then
            return "blocked"
        end
    end

    -- Fallback: if Blizzard provides sourceText, the item has a known source
    -- even though it's not in our static data tables. Default to "available"
    -- since we can't determine requirements from sourceText alone.
    if sourceText and sourceText ~= "" then
        return "available"
    end

    -- No source data at all
    return nil
end

-- Hide both badge and glow for an entry frame (used by early-return paths).
local function HideAllOverlays(entryFrame)
    HideBadge(entryFrame)
    HideGlow(entryFrame)
    HideCheckmark(entryFrame)
    entryFrame:SetAlpha(1.0)
end

-------------------------------------------------------------------------------
-- Badge Display
-------------------------------------------------------------------------------

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

-- Update source badge and accessibility glow on an entry frame.
-- Called from OnUpdate tick — must be fast on cache hit.
local function UpdateEntryOverlay(entryFrame)
    local entryInfo = entryFrame.entryInfo
    if not entryInfo then return HideAllOverlays(entryFrame) end

    local itemID = entryInfo.itemID
    if not itemID then return HideAllOverlays(entryFrame) end

    -- Read settings: check toggles before cache guard so toggling
    -- takes effect immediately
    local settings = HA.Addon and HA.Addon.db
        and HA.Addon.db.profile and HA.Addon.db.profile.overlay

    -- Master overlay toggle gates everything
    if settings and settings.enabled == false then
        return HideAllOverlays(entryFrame)
    end

    local showBadges = not settings or settings.showOnHousingCatalog ~= false
    local showGlow = not settings or settings.showAccessibilityGlow ~= false
    local ownedStyle = settings and settings.ownedItemStyle or "default"

    if not showBadges and not showGlow then
        return HideAllOverlays(entryFrame)
    end

    -- Cache hit: re-apply visual state without calling GetSource.
    local cached = overlayCache[entryFrame]
    if cached and cached[1] == itemID then
        -- Badge
        if showBadges and cached[2] then
            ShowBadgeAtlas(entryFrame, cached[2])
        else
            HideBadge(entryFrame)
        end
        -- Glow: owned glow only shows for "default" style
        if showGlow and cached[3] then
            if cached[3] == "owned" and ownedStyle ~= "default" then
                HideGlow(entryFrame)
            else
                ShowGlow(entryFrame, cached[3])
            end
        else
            HideGlow(entryFrame)
        end
        -- Owned item style
        ApplyOwnedStyle(entryFrame, ownedStyle, cached[3] == "owned")
        return
    end

    -- Cache miss: full evaluation

    -- Resolve sourceText once (frame entryInfo → API fallback) for badge + glow
    local sourceText = ResolveSourceText(entryInfo, itemID)

    -- Badge: look up source atlas (static data first, then sourceText)
    local atlas = GetSourceBadgeAtlas(itemID)
    if not atlas then
        atlas = GetSourceBadgeFromSourceText(sourceText)
    end

    if showBadges and atlas then
        ShowBadgeAtlas(entryFrame, atlas)
    else
        HideBadge(entryFrame)
    end

    -- Glow: determine accessibility state
    local glowState = GetAccessibilityState(itemID, entryInfo, sourceText)

    if showGlow and glowState then
        if glowState == "owned" and ownedStyle ~= "default" then
            HideGlow(entryFrame)
        else
            ShowGlow(entryFrame, glowState)
        end
    else
        HideGlow(entryFrame)
    end

    -- Owned item style
    ApplyOwnedStyle(entryFrame, ownedStyle, glowState == "owned")

    -- Cache both results (reuse existing table to avoid allocation)
    local cache = overlayCache[entryFrame]
    if cache then
        cache[1] = itemID
        cache[2] = atlas or false
        cache[3] = glowState or false
    else
        overlayCache[entryFrame] = {itemID, atlas or false, glowState or false}
    end
end

-------------------------------------------------------------------------------
-- Cache Invalidation
-------------------------------------------------------------------------------

-- Force all entry frames to re-evaluate on next tick.
-- Called when ownership or source data changes.
local function InvalidateAllOverlays()
    wipe(overlayCache)
end

-- Re-evaluate all currently visible entry frames (after invalidation).
-- Skips work when the dashboard is not visible — OnUpdate will pick up
-- changes naturally when the player reopens the catalog.
local function RefreshVisibleOverlays()
    InvalidateAllOverlays()
    if not dashboardVisible then return end
    for entryFrame in pairs(hookedFrames) do
        if entryFrame:IsShown() then
            UpdateEntryOverlay(entryFrame)
        end
    end
end

local function RefreshAvailabilityOverlays()
    RefreshVisibleOverlays()
end

-------------------------------------------------------------------------------
-- OnUpdate Driver
-------------------------------------------------------------------------------

-- Throttled update: discover frames and refresh overlays.
-- Runs at ~5Hz while the dashboard is shown.
-- Discovery runs every tick because Blizzard lazily creates/recycles
-- entry frames on scroll — limiting it to the first N ticks misses frames.
-- The tree walk is cheap (~15 Button children) and skips already-hooked frames.
local function OnDashboardUpdate(_, elapsed)
    timeSinceRefresh = timeSinceRefresh + elapsed
    if timeSinceRefresh < REFRESH_INTERVAL then return end
    timeSinceRefresh = 0

    -- Discover any new entry frames (handles scroll-created frames)
    DiscoverEntryFrames()

    -- Refresh visible overlays (badges + glow)
    for entryFrame in pairs(hookedFrames) do
        if entryFrame:IsShown() then
            UpdateEntryOverlay(entryFrame)
        end
    end
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

local function OnHousingDashboardLoaded()
    local dashboard = _G["HousingDashboardFrame"]
    if not dashboard then return end

    -- Track visibility to skip event-driven refreshes when catalog is closed
    dashboard:HookScript("OnShow", function()
        timeSinceRefresh = 0
        dashboardVisible = true
    end)
    dashboard:HookScript("OnHide", function()
        dashboardVisible = false
    end)

    -- OnUpdate drives all overlay refreshes — fires every render frame,
    -- throttled internally to REFRESH_INTERVAL.
    dashboard:HookScript("OnUpdate", OnDashboardUpdate)
end

-------------------------------------------------------------------------------
-- Event-Driven Cache Invalidation
-------------------------------------------------------------------------------

-- Inter-module ownership and availability change.
-- SourceManager owns the single WoW event frame for achievement/quest/reputation/
-- profession/holiday invalidation and fires SOURCE_CACHES_INVALIDATED.
-- CatalogOverlay only repaints — no duplicate WoW event registrations.
if HA.Events then
    HA.Events:RegisterCallback("OWNERSHIP_UPDATED", RefreshVisibleOverlays)
    HA.Events:RegisterCallback("SOURCE_CACHES_INVALIDATED", RefreshAvailabilityOverlays)
end

-- Register external refresher so Overlay:RefreshAll() also updates catalog overlays
if HA.Overlay then
    HA.Overlay:RegisterExternalRefresher("catalogBadges", RefreshVisibleOverlays)
end

-------------------------------------------------------------------------------
-- Deferred Initialization
-------------------------------------------------------------------------------

if C_AddOns.IsAddOnLoaded("Blizzard_HousingDashboard") then
    OnHousingDashboardLoaded()
else
    local eventUtil = _G and _G.EventUtil
    if eventUtil and eventUtil.ContinueOnAddOnLoaded then
        eventUtil.ContinueOnAddOnLoaded("Blizzard_HousingDashboard", OnHousingDashboardLoaded)
    end
end
