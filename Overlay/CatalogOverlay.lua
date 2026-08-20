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
    entry frames — it repositions them and swaps .entryInfo directly. We
    drive overlay updates off ScrollBoxListViewMixin.Event.OnInitializedFrame,
    registered on every ScrollBox view discovered under the dashboard
    (scrollBoxFrame:GetView():RegisterCallback(...)). Blizzard fires this
    exactly when a pooled entry frame is (re)bound to elementData, which
    covers both scroll-driven recycling and initial per-tab population —
    verified in-game 2026-08-06 (0 fires idle, proportional counts on
    partial scrolls, 1742 on a full fast scroll, exactly 15 on initial
    catalog open, no BugSack taint). This replaced a throttled 5Hz OnUpdate
    poll that walked the tree every tick.

    Caching is two-level, because the poll's tick rate was also an implicit
    cap on evaluations and OnInitializedFrame has none — a fast full scroll
    fires it 1742 times. overlayCache is keyed by entry FRAME, so it misses on
    every pooled-frame rebind, which is exactly what scrolling does. Behind it,
    itemVerdictCache is keyed by itemID and holds the expensive verdict
    (badge atlas + glow state, resolved through the catalog API, SourceManager
    and the sourceText parser), so a frame rebinding to an already-seen item
    costs one table lookup instead of a full re-resolve. Both are wiped
    together in InvalidateAllOverlays, which every invalidation this file
    subscribes to routes through.

    "Subscribes to" is the load-bearing part: a cache keyed by item outlives
    frame rebinding, so it is exactly as fresh as its wiring and no fresher,
    where the old recompute-per-bind behaviour self-healed from anything.
    Vendor-scan source discovery is the case that proves it — a merchant scan
    wipes SourceManager's source memo directly (ScanPersistence's
    InvalidateSourcesMemo) and deliberately broadcasts nothing, so it reaches
    this file only through VENDOR_SCANNED. All four subscriptions are wired
    together at the bottom of this file.
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
    owned        = { 0.0, 0.8, 0.0, 0.6 },  -- green: you have at least 1
    available    = { 1.0, 0.8, 0.0, 0.6 },  -- yellow: unowned, source reqs met
    blocked      = { 1.0, 0.15, 0.15, 0.9 }, -- red: unowned, all sources blocked
    unobtainable = { 0.5, 0.5, 0.5, 0.6 },  -- gray: promotion-gated (HS-158/160), not a normal "blocked" state
}

-- Per-frame result cache: entryFrame → {itemID, atlas or false, glowState or false}
-- Stores resolved badge + glow so we skip GetSource on repeat evaluations.
local overlayCache = setmetatable({}, { __mode = "k" })

-- Per-ITEM verdict cache: itemID → {atlas or false, glowState or false}.
-- Sits behind overlayCache, which is frame-keyed and therefore misses every
-- time the ScrollBox rebinds a pooled frame to a different item — the common
-- case while scrolling. This one survives rebinding, so the expensive
-- resolve (GetCatalogEntryInfoByItem, SourceManager:GetItemPresentation,
-- SourceTextParser:ParseSourceText) runs once per item per invalidation
-- cycle instead of once per bind. Not weak-keyed: itemIDs are numbers, and
-- the catalog is ~1,600 items, so the whole table is bounded and small;
-- InvalidateAllOverlays wipes it.
local itemVerdictCache = {}

-- HS-282: read-only debug accessor for the /hs debug membudget walker. This
-- file has no module table of its own (top-level hook-installing script) --
-- HA.CatalogOverlay exists purely to carry this diagnostic accessor,
-- nothing else attaches to it. overlayCache above is intentionally NOT
-- exposed: it's frame-keyed (weak-keyed, `__mode = "k"`), and a memory
-- walker has no meaningful way to size or interpret frame-object keys.
HA.CatalogOverlay = HA.CatalogOverlay or {}
function HA.CatalogOverlay.GetDebugCacheTables()
    return { itemVerdictCache = itemVerdictCache }
end

-- HS-223b: per-frame LAST-APPLIED-TO-THE-FRAME signature: entryFrame →
-- {itemID, effectiveAtlas or false, effectiveGlowState or false, ownedStyle,
-- isOwned}. Distinct from overlayCache above, which tracks the raw computed
-- verdict (itemID/atlas/glowState) to skip re-running GetSource; this tracks
-- what the frame's Show*/Hide*/ApplyOwnedStyle calls last actually rendered,
-- INCLUDING the settings-driven effective outcome (showBadges/showGlow/
-- ownedStyle can change the rendered result independent of the verdict). The
-- settings-driven repaint path (RefreshVisibleOverlays) re-evaluates every
-- visible entry on every invalidation even when nothing changed; comparing
-- against this signature lets it skip the Show*/Hide*/SetVertexColor calls
-- entirely when the outcome is identical.
local appliedState = setmetatable({}, { __mode = "k" })

-- Per-frame badge texture references
local badgeTextures = setmetatable({}, { __mode = "k" })

-- Per-frame glow texture references
local glowTextures = setmetatable({}, { __mode = "k" })

-- Per-frame checkmark texture references
local checkmarkTextures = setmetatable({}, { __mode = "k" })

-- Set of catalog entry Button frames whose ScrollBox view has fired
-- OnInitializedFrame for them at least once. The settings-driven repaint
-- path (RefreshVisibleOverlays, wired to Overlay:RefreshAll) re-evaluates
-- every frame in this set without re-walking the frame tree.
local hookedFrames = setmetatable({}, { __mode = "k" })

local dashboardVisible = false

-- Forward declaration for UpdateEntryOverlay (referenced by the ScrollBox
-- OnInitializedFrame handler below; defined later in Badge Display).
local UpdateEntryOverlay

-------------------------------------------------------------------------------
-- Frame Discovery
-------------------------------------------------------------------------------

-- Owner token for ScrollBox callback registrations. CallbackRegistryMixin
-- keys registrations by (event, func, owner); identity is all that matters
-- here, there is no per-owner state to carry.
local ScrollBoxCallbackOwner = {}

-- Set of ScrollBox view objects (scrollBoxFrame:GetView()) we've already
-- registered OnInitializedFrame on. Guards against double registration if
-- the dashboard is shown more than once in a session.
local registeredViews = setmetatable({}, { __mode = "k" })

-- Fired by Blizzard's ScrollBoxListViewMixin whenever a pooled entry frame
-- is (re)bound to elementData -- covers scroll-driven recycling AND initial
-- per-tab population in one event. See the file header for the in-game
-- verification that grounds this as the poll replacement.
local function OnScrollBoxFrameInitialized(_owner, frame, _elementData)
    if not frame then return end
    hookedFrames[frame] = true
    UpdateEntryOverlay(frame)
end

-- Recursively search for ScrollBox-like widgets (anything exposing
-- :GetView()) and register the OnInitializedFrame callback on each view
-- exactly once. Registers generically across every discovered ScrollBox
-- (decor/room/bundle tabs, or whatever else Blizzard shows under the
-- dashboard) rather than hardcoding to the decor grid.
local function ProcessChildren(depth, ...)
    if depth > 6 then return end
    for i = 1, select("#", ...) do
        local child = select(i, ...)
        if type(child.GetView) == "function" then
            local ok, view = pcall(child.GetView, child)
            if ok and view and not registeredViews[view] then
                registeredViews[view] = true
                view:RegisterCallback(ScrollBoxListViewMixin.Event.OnInitializedFrame,
                    OnScrollBoxFrameInitialized, ScrollBoxCallbackOwner)
            end
        end
        ProcessChildren(depth + 1, child:GetChildren())
    end
end

local function SearchChildren(frame, depth)
    ProcessChildren(depth, frame:GetChildren())
end

-- Scan for ScrollBox views under the dashboard and register any we haven't
-- seen yet. Idempotent -- safe to call every time the dashboard is shown,
-- which covers Blizzard lazily creating tab content between shows.
local function DiscoverScrollBoxes()
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
local function GetCatalogPresentation(itemID)
    if not HA.SourceManager or not HA.SourceManager.GetItemPresentation then return nil end
    return HA.SourceManager:GetItemPresentation(itemID, "catalog")
end

local function GetSourceBadgeAtlas(itemID, presentation)
    presentation = presentation or GetCatalogPresentation(itemID)
    if not presentation then return nil end
    return presentation.primarySourceBadgeAtlas or presentation.sourceBadgeAtlas
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
    badge:SetPoint("TOPLEFT", entryFrame, "TOPLEFT",
        BADGE_PADDING, -BADGE_PADDING)
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

-- Determine the accessibility state for an item. SourceManager owns the
-- ownership/source decision; sourceText is only a fallback for catalog-only data.
local function GetAccessibilityState(itemID, sourceText, presentation)
    presentation = presentation or GetCatalogPresentation(itemID)
    if presentation and presentation.catalogGlowState then
        return presentation.catalogGlowState
    end

    -- Fallback: if Blizzard provides sourceText, the item has a known source
    -- even though it's not in our static data tables. Default to "available"
    -- since we can't determine requirements from sourceText alone.
    if sourceText and sourceText ~= "" then
        return "available"
    end

    return nil
end

-- Hide both badge and glow for an entry frame (used by early-return paths).
-- HS-223b (CRITICAL): must also clear appliedState. A recycled
-- entry frame passes through here with a nil itemID (or settings disabled)
-- before rebinding to its next item — if the signature memo survived that,
-- a frame recycled back to the SAME item with an unchanged verdict would
-- match the stale signature and skip every Show* call, leaving badge/glow/
-- owned-style visually missing until the next global invalidation. Clearing
-- here (the one shared hider all four early-return paths funnel through)
-- also makes the master overlay toggle self-healing off→on.
local function HideAllOverlays(entryFrame)
    HideBadge(entryFrame)
    HideGlow(entryFrame)
    HideCheckmark(entryFrame)
    entryFrame:SetAlpha(1.0)
    appliedState[entryFrame] = nil
end

-------------------------------------------------------------------------------
-- Badge Display
-------------------------------------------------------------------------------

-- Apply badge atlas to a frame, with per-atlas size override.
-- Oversized atlases get a negative anchor offset so the visible artwork
-- stays flush with the top-left corner like the default-sized badges.
local function ShowBadgeAtlas(entryFrame, atlas)
    local badge = GetBadgeTexture(entryFrame)
    local size = ATLAS_SIZE_OVERRIDE[atlas] or BADGE_SIZE
    badge:SetSize(size, size)
    badge:SetAtlas(atlas, false)

    -- Re-anchor: pull oversized icons toward the corner by half the excess
    local offset = (size - BADGE_SIZE) / 2
    badge:ClearAllPoints()
    badge:SetPoint("TOPLEFT", entryFrame, "TOPLEFT",
        BADGE_PADDING - offset, -(BADGE_PADDING - offset))

    badge:Show()
end

-- HS-223b: applies the settings-aware badge/glow/owned-style outcome to an
-- entry frame, skipping the Show*/Hide*/ApplyOwnedStyle calls entirely when
-- the outcome is identical to what's already applied (appliedState above).
-- Shared by both the cache-hit and cache-miss paths in UpdateEntryOverlay so
-- there is exactly one place that decides "did anything actually change".
local function ApplyResolvedOverlay(entryFrame, itemID, atlas, glowState, showBadges, showGlow, ownedStyle)
    local effectiveBadgeAtlas = (showBadges and atlas) or false
    local isOwned = glowState == "owned"
    local effectiveGlowState = false
    if showGlow and glowState and not (isOwned and ownedStyle ~= "default") then
        effectiveGlowState = glowState
    end

    local applied = appliedState[entryFrame]
    if applied
        and applied[1] == itemID
        and applied[2] == effectiveBadgeAtlas
        and applied[3] == effectiveGlowState
        and applied[4] == ownedStyle
        and applied[5] == isOwned then
        return
    end

    if effectiveBadgeAtlas then
        ShowBadgeAtlas(entryFrame, effectiveBadgeAtlas)
    else
        HideBadge(entryFrame)
    end

    if effectiveGlowState then
        ShowGlow(entryFrame, effectiveGlowState)
    else
        HideGlow(entryFrame)
    end

    ApplyOwnedStyle(entryFrame, ownedStyle, isOwned)

    if applied then
        applied[1] = itemID
        applied[2] = effectiveBadgeAtlas
        applied[3] = effectiveGlowState
        applied[4] = ownedStyle
        applied[5] = isOwned
    else
        appliedState[entryFrame] = { itemID, effectiveBadgeAtlas, effectiveGlowState, ownedStyle, isOwned }
    end
end

-- Update source badge and accessibility glow on an entry frame.
-- Called from the ScrollBox OnInitializedFrame handler and from the
-- settings-driven repaint path — must be fast on cache hit.
UpdateEntryOverlay = function(entryFrame)
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

    -- Cache hit: re-apply visual state without calling GetSource. (HS-223b:
    -- ApplyResolvedOverlay itself skips the actual Show*/Hide* calls when
    -- nothing has changed since the last tick.)
    local cached = overlayCache[entryFrame]
    if cached and cached[1] == itemID then
        ApplyResolvedOverlay(entryFrame, itemID, cached[2], cached[3], showBadges, showGlow, ownedStyle)
        return
    end

    -- Frame-cache miss: the frame is bound to an item it wasn't showing
    -- before. Resolve the item's verdict, itself memoized by itemID so a
    -- rebind to an already-seen item costs a lookup, not a re-resolve.
    local verdict = itemVerdictCache[itemID]
    if not verdict then
        -- Resolve sourceText once (frame entryInfo → API fallback) for badge + glow
        local sourceText = ResolveSourceText(entryInfo, itemID)

        -- Badge: look up source atlas (static data first, then sourceText)
        local presentation = GetCatalogPresentation(itemID)
        local atlas = GetSourceBadgeAtlas(itemID, presentation)
        if not atlas then
            atlas = GetSourceBadgeFromSourceText(sourceText)
        end

        -- Glow: determine accessibility state
        local glowState = GetAccessibilityState(itemID, sourceText, presentation)

        verdict = {atlas or false, glowState or false}
        itemVerdictCache[itemID] = verdict
    end

    ApplyResolvedOverlay(entryFrame, itemID, verdict[1], verdict[2], showBadges, showGlow, ownedStyle)

    -- Cache both results (reuse existing table to avoid allocation)
    local cache = overlayCache[entryFrame]
    if cache then
        cache[1] = itemID
        cache[2] = verdict[1]
        cache[3] = verdict[2]
    else
        overlayCache[entryFrame] = {itemID, verdict[1], verdict[2]}
    end
end

-------------------------------------------------------------------------------
-- Cache Invalidation
-------------------------------------------------------------------------------

-- Force all entry frames to re-evaluate on next repaint.
-- Called when ownership or source data changes. HS-223b: also wipes
-- appliedState — belt-and-braces so a real change is never suppressed by a
-- stale last-applied signature. (In practice appliedState's comparison is
-- itself value-based and already includes itemID, so a genuine change would
-- be caught even without this; wiping it here means that guarantee never
-- depends on that reasoning holding for every future field added to the
-- signature. When in doubt, repaint.) All four invalidation entry points —
-- OWNERSHIP_UPDATED, SOURCE_CACHES_INVALIDATED (via RefreshAvailabilityOverlays),
-- VENDOR_SCANNED, and the "catalogBadges" external refresher — funnel through
-- this one function, so wiping the caches here covers all of them.
--
-- itemVerdictCache MUST be wiped alongside the others: it outlives frame
-- rebinding by design, so anything it holds past an ownership or source
-- change is a permanently stale badge/glow, not a one-frame flicker.
local function InvalidateAllOverlays()
    wipe(overlayCache)
    wipe(appliedState)
    wipe(itemVerdictCache)
end

-- Re-apply overlay state to every entry frame we've seen, skipping hidden
-- ones. Shared by the invalidation path below (which wipes the caches
-- first) and the dashboard OnShow catch-up pass (which doesn't need to —
-- InvalidateAllOverlays already ran when the underlying change happened,
-- even if the catalog was closed at the time; a frame that was never
-- rebound by the ScrollBox while closed otherwise never repaints).
local function RepaintKnownFrames()
    for entryFrame in pairs(hookedFrames) do
        if entryFrame:IsShown() then
            UpdateEntryOverlay(entryFrame)
        end
    end
end

-- Re-evaluate all currently visible entry frames (after invalidation).
-- Skips the repaint pass when the dashboard is not visible — OnShow's
-- RepaintKnownFrames call covers catching up once the player reopens it.
local function RefreshVisibleOverlays()
    InvalidateAllOverlays()
    if not dashboardVisible then return end
    RepaintKnownFrames()
end

local function RefreshAvailabilityOverlays()
    RefreshVisibleOverlays()
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

local function OnHousingDashboardLoaded()
    local dashboard = _G["HousingDashboardFrame"]
    if not dashboard then return end

    -- Track visibility so the settings-driven repaint path (RefreshVisible-
    -- Overlays) skips work while the catalog is closed, and rescan for
    -- ScrollBox views on every open — idempotent (registeredViews dedups),
    -- covers Blizzard lazily creating tab content between shows.
    dashboard:HookScript("OnShow", function()
        dashboardVisible = true
        DiscoverScrollBoxes()
        RepaintKnownFrames()
    end)
    dashboard:HookScript("OnHide", function()
        dashboardVisible = false
    end)

    -- Guard the case where Blizzard_HousingDashboard finishes loading while
    -- the dashboard is already shown (OnShow would otherwise never fire).
    if dashboard:IsShown() then
        dashboardVisible = true
        DiscoverScrollBoxes()
        RepaintKnownFrames()
    end
end

-------------------------------------------------------------------------------
-- Event-Driven Cache Invalidation
-------------------------------------------------------------------------------

-- Inter-module ownership and availability change.
-- SourceManager owns the single WoW event frame for achievement/quest/reputation/
-- profession/holiday invalidation and fires SOURCE_CACHES_INVALIDATED.
-- CatalogOverlay only repaints — no duplicate WoW event registrations.
--
-- The invariant these subscriptions exist to hold: itemVerdictCache outlives
-- frame rebinding, so any code that changes what an item's sources ARE has to
-- reach InvalidateAllOverlays through one of the announcements below, or the
-- catalog serves the old verdict until something unrelated clears it. Code
-- that wipes a source cache without announcing it therefore bypasses this
-- file silently. Two such paths are known, and both are covered:
--
--   * A merchant scan discovering a new source wipes SourceManager's memo
--     through InvalidateSourcesMemo, which is deliberately broadcast-free (the
--     broadcasting version would restart the badge prewarm on every vendor
--     visit — the HS-238 over-invalidation). It announces VENDOR_SCANNED
--     instead, which is why that is wired below.
--   * The /hs clear* commands wipe the memo through ScanPersistence's
--     RefreshMapPins. That one now uses the broadcasting variant, so it
--     arrives as SOURCE_CACHES_INVALIDATED and needs no separate wiring here.
--
-- "Known" is doing real work in that sentence: a third such path would be
-- invisible from this file, so it is worth grepping the memo accessors when
-- badges go stale for no apparent reason.
--
-- Deliberately NOT gated on the scan having found decor (vendorRecord.hasDecor)
-- or requirements: those are ScanPersistence's own signals for wiping its own
-- memo, and gating on them would couple this file's correctness to that
-- module's internals to save three table wipes on a path where the catalog is
-- almost always closed (RefreshVisibleOverlays skips the repaint entirely
-- then). Getting such a gate wrong reintroduces precisely the staleness above.
if HA.Events then
    HA.Events:RegisterCallback("OWNERSHIP_UPDATED", RefreshVisibleOverlays)
    HA.Events:RegisterCallback("SOURCE_CACHES_INVALIDATED", RefreshAvailabilityOverlays)
    HA.Events:RegisterCallback("VENDOR_SCANNED", RefreshVisibleOverlays)
end

-- Not wired, and not an oversight: CatalogStore:SetSources (the sourceText
-- parse pipeline) fires CATALOG_ITEM_UPDATED rather than any of the above, so
-- a fresh parse can lag this cache. That lag is pre-existing and deferred with
-- rationale in SourceManager.lua's allSourcesCache note (HS-273 R7) — the memo
-- there has the same gap — and useParsedSources defaults false.

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
