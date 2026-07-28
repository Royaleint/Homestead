--[[
    Homestead - World Map Provider
    Self-managed world-map renderer using plain canvas-child frames.

    Does NOT use AddDataProvider or MapCanvasPinMixin — those enter Blizzard's
    managed pin lifecycle which calls protected SetPassThroughButtons in combat.
    Instead, a lightweight watcher frame detects map state changes and triggers
    refresh/reposition after Blizzard's secure path completes.
]]

local _, HA = ...

local Provider = {}
HA.HomesteadWorldMapProvider = Provider

local MPP = HA.MapPinProvider
local PinFrameFactory = HA.PinFrameFactory
local FPU = HA.FramePoolUtils

local ipairs = ipairs
local format = string.format

local BoolToKey = FPU.BoolToKey
local AcquirePooledFrame = FPU.AcquirePooledFrame

local renderState = nil
local isRegistered = false
local activeEntries = {}
local activeVendorFrames = {}
local refreshPending = false
local renderedState = nil
local renderedMapID = nil
-- HS-234: settle-debounce timer for map-transition-triggered refreshes
-- (watcher_map_changed, watcher_zoom) — see RequestSettledRefresh below.
-- Separate from refreshPending above, which stays the same-frame coalesce
-- for watcher_opened (a single deliberate action, not a spam vector).
local settleTimer = nil
-- HS-223a: external consumers (currently MapSidePanel) of the shared 0.1s
-- map watcher below, keyed by caller-chosen string so multiple registrants
-- can't clobber each other. Each callback receives (isShown, mapID,
-- maximized) every tick -- the raw state MapSidePanel's own watch logic
-- needs, read from this ONE poll instead of running a second independent
-- 0.1s ticker against the same WorldMapFrame state.
local mapWatchCallbacks = {}
local debugStats = {
    refreshCalls = 0,
    renderedPasses = 0,
    skippedUnchanged = 0,
    skippedHidden = 0,
    skippedMapMismatch = 0,
    lastRenderedTotal = 0,
    lastLogTime = 0,
    lastLoggedRefreshCalls = 0,
    lastLoggedRenderedPasses = 0,
    lastLoggedSkippedUnchanged = 0,
    lastLoggedSkippedHidden = 0,
    lastLoggedSkippedMapMismatch = 0,
}
local watcherStats = {
    opened = 0,
    closed = 0,
    mapChanged = 0,
    resized = 0,
    zoomChanged = 0,
    deferredRefreshes = 0,
    -- HS-234 cycle 1 SUGGESTION: settled refreshes get their own counter
    -- rather than sharing deferredRefreshes, so Gate 2 can read how many
    -- transition-triggered refreshes actually happened post-settle
    -- (distinct from watcher_opened's same-frame deferredRefreshes) when
    -- tuning WATCHER_SETTLE_DELAY.
    settledRefreshes = 0,
}
local placementDebugMaps = {
    [2393] = true,
    [2395] = true,
    [2437] = true,
}
-- POI dodge: nudge vendor pins away from nearby Blizzard area/event POIs.
-- Uses C_AreaPoiInfo API (data query) instead of ExecuteOnAllPins (taint vector).
local DODGE_DIRECTIONS = {
    { 1.0, 0.0 },
    { 0.7071, 0.7071 },
    { 0.0, 1.0 },
    { -0.7071, 0.7071 },
    { -1.0, 0.0 },
    { -0.7071, -0.7071 },
    { 0.0, -1.0 },
    { 0.7071, -0.7071 },
}
local cachedPoiPositions = nil
local cachedPoiMapID = nil

local vendorFramePool = {}
local badgeFramePool = {}
local portalFramePool = {}
-- HS-018: pool for non-vendor source pins (drop, future profession etc.)
local sourceFramePool = {}
-- Frame level constant no longer needed — plain frames use direct SetFrameLevel

local function IsDebugModeEnabled()
    return HA.DevAddon and HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug
end

local function GetRenderStateTotal()
    if not renderState then
        return 0
    end

    return #(renderState.vendorPins or {})
        + #(renderState.sourcePins or {})
        + #(renderState.zoneBadges or {})
        + #(renderState.portalBadges or {})
        + #(renderState.continentBadges or {})
end

local function MaybeLogProviderPerf(reason)
    if not IsDebugModeEnabled() then
        return
    end

    local now = (_G.GetTimePreciseSec and _G.GetTimePreciseSec()) or _G.GetTime()
    local previousLogTime = debugStats.lastLogTime or 0
    if previousLogTime > 0 and (now - previousLogTime) < 1 then
        return
    end

    local totalRefreshCalls = debugStats.refreshCalls
    local totalRenderedPasses = debugStats.renderedPasses
    local totalSkippedUnchanged = debugStats.skippedUnchanged
    local totalSkippedHidden = debugStats.skippedHidden
    local totalSkippedMapMismatch = debugStats.skippedMapMismatch
    local deltaRefreshCalls = totalRefreshCalls - (debugStats.lastLoggedRefreshCalls or 0)
    local deltaRenderedPasses = totalRenderedPasses - (debugStats.lastLoggedRenderedPasses or 0)
    local deltaSkippedUnchanged = totalSkippedUnchanged - (debugStats.lastLoggedSkippedUnchanged or 0)
    local deltaSkippedHidden = totalSkippedHidden - (debugStats.lastLoggedSkippedHidden or 0)
    local deltaSkippedMapMismatch = totalSkippedMapMismatch - (debugStats.lastLoggedSkippedMapMismatch or 0)
    local currentMapID = Provider.mapCanvas and Provider.mapCanvas.GetMapID and Provider.mapCanvas:GetMapID() or nil
    local elapsed = previousLogTime > 0 and (now - previousLogTime) or 0

    HA.Addon:Debug(format(
        "WorldMapProviderPerf: reason=%s canvasMap=%s renderMap=%s calls=%d(+%d) renders=%d(+%d) noop=%d(+%d) hidden=%d(+%d) mismatch=%d(+%d) active=%d renderEntries=%d dt=%.2fs",
        tostring(reason),
        tostring(currentMapID),
        tostring(renderState and renderState.mapID or nil),
        totalRefreshCalls,
        deltaRefreshCalls,
        totalRenderedPasses,
        deltaRenderedPasses,
        totalSkippedUnchanged,
        deltaSkippedUnchanged,
        totalSkippedHidden,
        deltaSkippedHidden,
        totalSkippedMapMismatch,
        deltaSkippedMapMismatch,
        #activeEntries,
        GetRenderStateTotal(),
        elapsed
    ))

    debugStats.lastLogTime = now
    debugStats.lastLoggedRefreshCalls = totalRefreshCalls
    debugStats.lastLoggedRenderedPasses = totalRenderedPasses
    debugStats.lastLoggedSkippedUnchanged = totalSkippedUnchanged
    debugStats.lastLoggedSkippedHidden = totalSkippedHidden
    debugStats.lastLoggedSkippedMapMismatch = totalSkippedMapMismatch
end

local function MaybeLogPlacementProbe(entry, wrapper, kind, index)
    if not (HA.DevAddon and IsDebugModeEnabled()) then
        return
    end
    if kind ~= "vendor" or index > 2 then
        return
    end
    if not renderState or not placementDebugMaps[renderState.mapID] then
        return
    end

    local canvas = wrapper and wrapper:GetParent() or nil
    local container = WorldMapFrame and WorldMapFrame.GetCanvasContainer and WorldMapFrame:GetCanvasContainer() or nil
    local centerX, centerY = nil, nil
    if wrapper and wrapper.GetCenter then
        centerX, centerY = wrapper:GetCenter()
    end
    local left = wrapper and wrapper:GetLeft() or nil
    local top = wrapper and wrapper:GetTop() or nil
    local width = wrapper and wrapper:GetWidth() or nil
    local height = wrapper and wrapper:GetHeight() or nil
    local scale = wrapper and wrapper:GetScale() or nil
    local canvasW = canvas and canvas:GetWidth() or nil
    local canvasH = canvas and canvas:GetHeight() or nil
    local containerW = container and container:GetWidth() or nil
    local containerH = container and container:GetHeight() or nil

    HA.Addon:Debug(format(
        "WorldMapPlacementProbe: map=%s idx=%d vendorMap=%s reason=%s norm=%.4f,%.4f center=%.2f,%.2f left=%.2f top=%.2f size=%.2fx%.2f scale=%.4f canvas=%.2fx%.2f container=%.2fx%.2f shown=%s",
        tostring(renderState.mapID),
        index,
        tostring(entry and entry.mapID),
        tostring(entry and entry.reason),
        entry and entry.x or -1,
        entry and entry.y or -1,
        centerX or -1,
        centerY or -1,
        left or -1,
        top or -1,
        width or -1,
        height or -1,
        scale or -1,
        canvasW or -1,
        canvasH or -1,
        containerW or -1,
        containerH or -1,
        tostring(wrapper and wrapper:IsShown())
    ))
end

local function MaybeLogSizeProbe(frame, wrapper, kind, index)
    if not (HA.DevAddon and IsDebugModeEnabled()) then
        return
    end
    if kind ~= "vendor" or index ~= 1 then
        return
    end
    if not renderState or renderState.mapType == Enum.UIMapType.World or renderState.mapType == Enum.UIMapType.Continent then
        return
    end
    if not frame or not wrapper then
        return
    end

    local uiScale = UIParent:GetEffectiveScale() or 1
    local wrapperEffectiveScale = wrapper:GetEffectiveScale() or 1
    local frameEffectiveScale = frame:GetEffectiveScale() or 1
    local icon = frame.icon
    local iconWidth = icon and icon:GetWidth() or 0
    local iconHeight = icon and icon:GetHeight() or 0
    local frameWidth = frame:GetWidth() or 0
    local frameHeight = frame:GetHeight() or 0
    local wrapperWidth = wrapper:GetWidth() or 0
    local wrapperHeight = wrapper:GetHeight() or 0
    local wrapperUiWidth = wrapperWidth * (wrapperEffectiveScale / uiScale)
    local wrapperUiHeight = wrapperHeight * (wrapperEffectiveScale / uiScale)
    local frameUiWidth = frameWidth * (frameEffectiveScale / uiScale)
    local frameUiHeight = frameHeight * (frameEffectiveScale / uiScale)
    local iconUiWidth = iconWidth * (frameEffectiveScale / uiScale)
    local iconUiHeight = iconHeight * (frameEffectiveScale / uiScale)
    local countFontSize = 0
    local countUiSize = 0
    if frame.count and frame.count.GetFont then
        local _, fontSize = frame.count:GetFont()
        countFontSize = fontSize or 0
        countUiSize = countFontSize * (frameEffectiveScale / uiScale)
    end

    HA.Addon:Debug(format(
        "WorldMapSizeProbe: map=%s slider=%d wrapper=%.2fx%.2f ui=%.2fx%.2f frame=%.2fx%.2f ui=%.2fx%.2f icon=%.2fx%.2f ui=%.2fx%.2f count=%.2f ui=%.2f wrapperScale=%.4f frameScale=%.4f",
        tostring(renderState.mapID),
        PinFrameFactory:GetPinIconSize(),
        wrapperWidth,
        wrapperHeight,
        wrapperUiWidth,
        wrapperUiHeight,
        frameWidth,
        frameHeight,
        frameUiWidth,
        frameUiHeight,
        iconWidth,
        iconHeight,
        iconUiWidth,
        iconUiHeight,
        countFontSize,
        countUiSize,
        wrapperEffectiveScale,
        frameEffectiveScale
    ))
end

local function Clamp01(value)
    if value < 0.01 then
        return 0.01
    elseif value > 0.99 then
        return 0.99
    end
    return value
end

local function GetEntryDodgeSeed(entry)
    if entry and entry.vendor and entry.vendor.npcID then
        return entry.vendor.npcID
    end
    return 1
end

local function GetPoiPositionsForMap(mapID)
    if cachedPoiMapID == mapID and cachedPoiPositions then
        return cachedPoiPositions
    end
    cachedPoiPositions = {}
    cachedPoiMapID = mapID

    -- Query BOTH regular POIs and event POIs — they use separate APIs.
    -- Regular: C_AreaPoiInfo.GetAreaPOIForMap (quest hubs, portals, etc.)
    -- Events: C_AreaPoiInfo.GetEventsForMap (Saltheril's Soiree, Abundance, etc.)
    -- Both are data API calls — taint-safe.
    local poiIDs = C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap and C_AreaPoiInfo.GetAreaPOIForMap(mapID)
    if poiIDs then
        for _, poiID in ipairs(poiIDs) do
            local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, poiID)
            if info and info.position then
                cachedPoiPositions[#cachedPoiPositions + 1] = {
                    x = info.position.x,
                    y = info.position.y,
                }
            end
        end
    end

    local eventIDs = C_AreaPoiInfo and C_AreaPoiInfo.GetEventsForMap and C_AreaPoiInfo.GetEventsForMap(mapID)
    if eventIDs then
        for _, eventID in ipairs(eventIDs) do
            local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, eventID)
            if info and info.position then
                cachedPoiPositions[#cachedPoiPositions + 1] = {
                    x = info.position.x,
                    y = info.position.y,
                }
            end
        end
    end

    return cachedPoiPositions
end

local function ApplyAreaPoiDodge(entry, x, y)
    if not renderState or renderState.mapType == Enum.UIMapType.World or renderState.mapType == Enum.UIMapType.Continent then
        return x, y
    end
    if not entry then
        return x, y
    end

    local poiPositions = GetPoiPositionsForMap(renderState.mapID)
    if #poiPositions == 0 then
        return x, y
    end

    local container = WorldMapFrame and WorldMapFrame.GetCanvasContainer and WorldMapFrame:GetCanvasContainer() or nil
    if not container then
        return x, y
    end

    local width = container:GetWidth()
    local height = container:GetHeight()
    if not width or not height or width <= 0 or height <= 0 then
        return x, y
    end

    -- Find closest POI to this pin
    local closestDist = nil
    for _, poi in ipairs(poiPositions) do
        local dx = (x - poi.x) * width
        local dy = (y - poi.y) * height
        local dist = math.sqrt(dx * dx + dy * dy)
        if not closestDist or dist < closestDist then
            closestDist = dist
        end
    end

    local collisionThreshold = 18
    if not closestDist or closestDist > collisionThreshold then
        return x, y
    end

    -- Scale nudge by zoom: POI icons stay the same screen size at all zoom
    -- levels, but at high zoom the geographic spread gives more room.
    -- Default zoom (~0.18): full 12px nudge.
    -- High zoom: drift back but keep minimum 5px so a corner stays visible
    -- for hover/click.
    local canvas = WorldMapFrame and WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas()
    local canvasScale = canvas and canvas:GetEffectiveScale() or 0
    local uiScale = UIParent and UIParent:GetEffectiveScale() or 1
    local zoomFactor = (uiScale > 0 and canvasScale > 0) and (canvasScale / uiScale) or 1
    local zoomDamping = math.max(0, 1 - ((zoomFactor - 0.18) / 0.30))
    local nudgePixels = math.max(5, math.floor(12 * zoomDamping + 0.5))

    local direction = DODGE_DIRECTIONS[(GetEntryDodgeSeed(entry) % #DODGE_DIRECTIONS) + 1]
    return Clamp01(x + (direction[1] * nudgePixels) / width),
           Clamp01(y + (direction[2] * nudgePixels) / height)
end

-- Pixel offset (not a normalized map-coordinate one — see
-- MapPinProvider.PlaceNativePin's comment for why) that keeps EJ-anchored
-- drop pins (boss position and dungeon-entrance groups) a constant screen
-- distance from Blizzard's own pin at the same coordinate, toward the
-- bottom-right, at every zoom level.
local EJ_DROP_PIN_OFFSET_PIXELS = 10

local function GetEjDropPinIconOffset(entry)
    if entry.sourceType == "drop"
            and (entry.dropGroupKind == "enc" or entry.dropGroupKind == "ent") then
        return EJ_DROP_PIN_OFFSET_PIXELS, -EJ_DROP_PIN_OFFSET_PIXELS
    end
    return nil, nil
end

local function CleanupWorldMapFrame(frame)
    frame:Hide()
    if frame.glowAnim and frame.glowAnim.Stop then
        frame.glowAnim:Stop()
    end
    if frame.glowFrame then
        frame.glowFrame:Hide()
    end
    frame:SetScale(1)
    if frame.SetIgnoreParentScale then
        frame:SetIgnoreParentScale(false)
    end
end

local function ReleasePooledFrame(poolByKey, frame)
    FPU.ReleasePooledFrame(poolByKey, frame, CleanupWorldMapFrame)
end

local function GetEntryDisplayScale(kind, mapType)
    if mapType == Enum.UIMapType.World then
        if kind == "badge" then
            return 1.00
        elseif kind == "vendor" then
            return 1.20
        elseif kind == "portal" then
            return 1.30
        end
    elseif mapType == Enum.UIMapType.Continent then
        if kind == "badge" then
            return 1.00
        elseif kind == "vendor" then
            return 1.10
        elseif kind == "portal" then
            return 1.15
        end
    end

    return 1
end

local function RequestDeferredRefresh(reason)
    if refreshPending then
        return
    end

    watcherStats.deferredRefreshes = watcherStats.deferredRefreshes + 1
    if IsDebugModeEnabled() and reason then
        HA.Addon:Debug("WorldMapWatcher: " .. reason)
    end

    refreshPending = true
    C_Timer.After(0, function()
        refreshPending = false
        -- Drive the full refresh chain: build render state + render.
        -- VendorMapPins:RefreshPins builds the render state and calls
        -- Provider:SetRenderState + Provider:Refresh internally.
        local VMP = HA.VendorMapPins
        if VMP and VMP.RefreshPins then
            VMP:RefreshPins(true)
        elseif isRegistered and Provider and Provider.RefreshAllData then
            Provider:RefreshAllData()
        end
    end)
end

-- HS-234: settle-debounce for map-transition refreshes. Each full refresh is
-- a teardown+rebuild (Provider:RefreshAllData -> RemoveAllData then
-- RenderEntries for every pin kind) — rapid right-click-through-levels
-- (World -> Continent -> Zone -> sub-zone) fires a NEW mapID/zoom-scale
-- change on nearly every 0.1s watcher tick, and RequestDeferredRefresh's
-- same-frame coalesce only absorbs triggers that land in the SAME tick, not
-- across several. Each transited level was therefore paying its own full
-- rebuild (the diagnosed "4 brief spikes"). This cancels-and-restarts a
-- timer on every call instead, so a rebuild only actually fires once the
-- transitions stop arriving for a full settleDelay — click-spam through 4
-- levels builds ONCE, at the resting map. RefreshPins reads the CURRENT
-- WorldMapFrame:GetMapID() when it fires, not whatever mapID triggered the
-- call, so the eventual single build is always for the map the player
-- actually stopped on, not a stale one from mid-spam.
--
-- 0.25s chosen over the spec's 0.15s floor: no in-game click-cadence data
-- to justify tuning down without evidence, and this delay is invisible to
-- the player (a background pin-render refresh, not something gating any
-- user action) — the extra ~100ms of margin against real click cadences
-- costs nothing perceptible for the single-deliberate-transition case,
-- where it's still well under human-perceptible "did that lag" territory.
-- Gate 2 can tune this down if 0.15s is shown to settle spam reliably.
local WATCHER_SETTLE_DELAY = 0.25

local function RequestSettledRefresh(reason)
    watcherStats.settledRefreshes = watcherStats.settledRefreshes + 1
    if IsDebugModeEnabled() and reason then
        HA.Addon:Debug("WorldMapWatcher: " .. reason .. " (settling)")
    end

    if settleTimer then
        settleTimer:Cancel()
    end

    settleTimer = C_Timer.NewTimer(WATCHER_SETTLE_DELAY, function()
        settleTimer = nil
        local VMP = HA.VendorMapPins
        if VMP and VMP.RefreshPins then
            VMP:RefreshPins(true)
        elseif isRegistered and Provider and Provider.RefreshAllData then
            Provider:RefreshAllData()
        end
    end)
end

local function BuildWorldPinStyleKey()
    local size = PinFrameFactory:GetPinIconSize()
    local isCustom = PinFrameFactory:IsCustomPinColor()
    local r, g, b = PinFrameFactory:GetPinColor()
    return format("ws%d|c%s|%.3f|%.3f|%.3f", size, BoolToKey(isCustom), r, g, b)
end

local function GetVendorFramePoolKey(entry)
    local factionKey = "neutral"
    if entry.isOppositeFaction and entry.vendor and entry.vendor.faction then
        factionKey = entry.vendor.faction
    end

    -- HS-158/160 §5: vendorType affects the icon set at frame-create time
    -- (PinFrameFactory:CreateVendorPinFrame), so it must join the pool key —
    -- same class of fix as GetPortalFramePoolKey's `class` component below.
    -- Without this, a pooled default-art frame could serve a professionShop
    -- vendor non-deterministically.
    local vendorTypeKey = (entry.vendor and entry.vendor.vendorType) or "none"

    return format("%s|o%s|f%s|vt%s",
        BuildWorldPinStyleKey(),
        BoolToKey(entry.isOppositeFaction),
        factionKey,
        vendorTypeKey)
end

local function GetBadgeDisplayFactionKey(badgeData)
    if badgeData and badgeData.dominantFaction then
        return badgeData.dominantFaction
    end
    if badgeData and (badgeData.oppositeFactionCount or 0) > 0 then
        local playerFaction = UnitFactionGroup("player")
        if playerFaction == "Alliance" then
            return "Horde"
        end
        return "Alliance"
    end
    return "none"
end

-- HS-222: the pool key used to bake vendorCount/uncollectedCount/
-- oppositeFactionCount straight into the string. Those are live ownership
-- counts, not stable pin identity — every distinct combination minted its own
-- permanent bucket in badgeFramePool that never got reused again (the churn
-- compounds with other addons' shared-canvas refreshes). Style and faction
-- classification ARE stable per bucket (GetBadgeDisplayFactionKey resolves to
-- one of a small fixed set of values, and a reused frame's dominantFaction/
-- emblem needs are invariant for everything sharing this key) — only the raw
-- counts are dropped. See PinFrameFactory:RefreshBadgePinVisuals for the
-- count-driven visuals this key no longer disambiguates by pin identity.
local function GetBadgeFramePoolKey(badgeData)
    return format("%s|f%s",
        BuildWorldPinStyleKey(),
        GetBadgeDisplayFactionKey(badgeData))
end

local function GetPortalFramePoolKey(portalData)
    local vendor = portalData and portalData.vendor
    local classKey = vendor and vendor.class or "NONE"
    return format("ps%d|class%s", PinFrameFactory:GetPinIconSize(), classKey)
end

local function AcquireVendorFrame(entry)
    local poolKey = GetVendorFramePoolKey(entry)
    local frame = AcquirePooledFrame(vendorFramePool, poolKey, function()
        return PinFrameFactory:CreateVendorPinFrame(entry.vendor, entry.isOppositeFaction)
    end)
    frame.vendor = entry.vendor
    frame.isOppositeFaction = entry.isOppositeFaction
    if PinFrameFactory.RefreshVendorPinCount then
        PinFrameFactory:RefreshVendorPinCount(frame, entry.vendor)
    end
    return frame
end

local function AcquireBadgeFrame(entry)
    local poolKey = GetBadgeFramePoolKey(entry.badgeData)
    local frame = AcquirePooledFrame(badgeFramePool, poolKey, function()
        return PinFrameFactory:CreateBadgePinFrame(entry.badgeData)
    end)
    frame.badgeData = entry.badgeData
    if PinFrameFactory.RefreshBadgePinVisuals then
        PinFrameFactory:RefreshBadgePinVisuals(frame, entry.badgeData)
    end
    return frame
end

local function AcquirePortalFrame(entry)
    local poolKey = GetPortalFramePoolKey(entry.portalData)
    local frame = AcquirePooledFrame(portalFramePool, poolKey, function()
        return PinFrameFactory:CreatePortalBadgePinFrame(entry.portalData)
    end)
    frame.portalData = entry.portalData
    if frame.glowFrame then
        frame.glowFrame:Show()
    end
    if frame.glowAnim and frame.glowAnim.Play then
        frame.glowAnim:Play()
    end
    return frame
end

-- HS-018: source pins (drop today; profession/quest/achievement/shop later).
-- Pool key is keyed on size + sourceType so each source type has its own bucket
-- inside the source pool — required because CreateSourcePinFrame dispatches by
-- sourceType.
local function GetSourceFramePoolKey(entry)
    local sourceType = entry and entry.sourceType or "unknown"
    return format("ss%d|t%s", PinFrameFactory:GetPinIconSize(), sourceType)
end

local function AcquireSourceFrame(entry)
    local poolKey = GetSourceFramePoolKey(entry)
    local sourceType = entry.sourceType
    -- PinFrameFactory:CreateSourcePinFrame returns nil for unsupported source
    -- types. Check the pool first so a recycled frame is reused without
    -- invoking the factory (and tripping the nil branch). If the pool is empty
    -- and the factory returns nil, propagate nil — RenderEntries skips it.
    local bucket = sourceFramePool[poolKey]
    if bucket and #bucket > 0 then
        local frame = AcquirePooledFrame(sourceFramePool, poolKey, function()
            return PinFrameFactory:CreateSourcePinFrame(sourceType, entry)
        end)
        frame.record = entry
        -- HS-229: a reused frame's badge still reflects whatever record it
        -- last showed — refresh it for the new one, same as
        -- AcquireVendorFrame does for vendor pins. Fresh creates are already
        -- covered inside CreateDropPinFrame itself.
        if sourceType == "drop" and PinFrameFactory.RefreshDropPinCount then
            PinFrameFactory:RefreshDropPinCount(frame, entry)
        end
        return frame
    end

    local newFrame = PinFrameFactory:CreateSourcePinFrame(sourceType, entry)
    if not newFrame then
        return nil
    end
    newFrame.__hsInPool = false
    newFrame.__hsPoolKey = poolKey
    newFrame.record = entry
    return newFrame
end

local function ReleaseEntryFrame(entry)
    if entry.kind == "vendor" then
        ReleasePooledFrame(vendorFramePool, entry.frame)
    elseif entry.kind == "badge" then
        ReleasePooledFrame(badgeFramePool, entry.frame)
    elseif entry.kind == "portal" then
        ReleasePooledFrame(portalFramePool, entry.frame)
    elseif entry.kind == "source" then
        ReleasePooledFrame(sourceFramePool, entry.frame)
    end
end

local function FlushWorldMapFrame(frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(UIParent)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(1)
    if frame.glowAnim and frame.glowAnim.Stop then
        frame.glowAnim:Stop()
    end
    if frame.glowFrame then
        frame.glowFrame:Hide()
    end
end

local function FlushPoolBuckets(poolByKey)
    FPU.FlushPoolBuckets(poolByKey, FlushWorldMapFrame)
end

function Provider:EnsureRegistered()
    if isRegistered then
        return
    end

    if not WorldMapFrame or not WorldMapFrame.GetCanvasContainer then
        return
    end

    self.mapCanvas = WorldMapFrame:GetCanvasContainer()
    isRegistered = true

    local lastMapID = nil
    local lastCanvasWidth = nil
    local lastCanvasHeight = nil
    local lastCanvasEffectiveScale = nil
    -- Passive polling watcher — no WorldMapFrame hooks at all.
    -- HookScript and hooksecurefunc on WorldMapFrame run during Blizzard's
    -- secure map-open path, tainting the execution context. A ticker that
    -- polls map state is the only taint-safe detection mechanism.
    local wasShown = false

    C_Timer.NewTicker(0.1, function()
        local isShown = WorldMapFrame and WorldMapFrame:IsShown()
        -- HS-223a: mapID/maximized are read here (not just inside the old
        -- "still open" branch) so they're available below for the shared
        -- external-callback dispatch on every tick, not only Provider's own
        -- branches.
        local mapID = isShown and WorldMapFrame:GetMapID() or nil
        local maximized = isShown and (WorldMapFrame.isMaximized and true or false) or false

        if isShown and not wasShown then
            -- Map just opened — force refresh after secure path completes
            wasShown = true
            watcherStats.opened = watcherStats.opened + 1
            lastMapID = nil
            -- POI-dodge cache is keyed on mapID and never busts within a map,
            -- so event POIs that appeared/disappeared while the map was closed
            -- (Saltheril's Soiree, Abundance, ...) would keep dodging against
            -- stale positions on re-show. Bust it on every map re-show.
            cachedPoiMapID = nil
            cachedPoiPositions = nil
            C_Timer.After(0, function()
                RequestDeferredRefresh("watcher_opened")
            end)
        elseif not isShown and wasShown then
            -- Map just closed — cleanup
            wasShown = false
            watcherStats.closed = watcherStats.closed + 1
            lastMapID = nil
            lastCanvasWidth = nil
            lastCanvasHeight = nil
            lastCanvasEffectiveScale = nil
            -- HS-234: a pending settle-debounce from a transition made just
            -- before closing the map would otherwise fire uselessly ~0.25s
            -- later against a closed map — cancel it now, same discipline
            -- VendorMapPins:ClearAllPins already applies to its own
            -- worldMapRefreshTimer.
            if settleTimer then
                settleTimer:Cancel()
                settleTimer = nil
            end
            self:RemoveAllData()
        elseif isShown then
            -- Map still open — check for mapID, canvas size, or zoom-scale changes
            local container = WorldMapFrame:GetCanvasContainer()
            local canvas = WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas()
            local canvasWidth = container and container:GetWidth() or 0
            local canvasHeight = container and container:GetHeight() or 0
            local canvasEffectiveScale = canvas and canvas:GetEffectiveScale() or 0

            if mapID ~= lastMapID then
                lastMapID = mapID
                watcherStats.mapChanged = watcherStats.mapChanged + 1
                RequestSettledRefresh("watcher_map_changed")
            elseif (canvasWidth > 0 and canvasWidth ~= lastCanvasWidth)
                    or (canvasHeight > 0 and canvasHeight ~= lastCanvasHeight) then
                lastCanvasWidth = canvasWidth
                lastCanvasHeight = canvasHeight
                lastCanvasEffectiveScale = canvasEffectiveScale
                watcherStats.resized = watcherStats.resized + 1
                if IsDebugModeEnabled() then
                    HA.Addon:Debug("WorldMapWatcher: watcher_resize")
                end
                MPP.RepositionWorldMapPins()
            elseif canvasEffectiveScale > 0 and (not lastCanvasEffectiveScale or math.abs(canvasEffectiveScale - lastCanvasEffectiveScale) > 0.0001) then
                lastCanvasEffectiveScale = canvasEffectiveScale
                watcherStats.zoomChanged = watcherStats.zoomChanged + 1
                -- Full refresh on zoom change so POI dodge recalculates
                -- with the new zoom factor (pins drift back at high zoom).
                RequestSettledRefresh("watcher_zoom")
            end
        end

        -- HS-223a: feed every registered external consumer (MapSidePanel)
        -- from this SAME poll instead of each running its own 0.1s ticker
        -- against the same WorldMapFrame state. pcall per callback (Argus
        -- cycle 1 WARNING) so one registrant's error can't kill every other
        -- registrant's tick — matches Overlay:RefreshExternalOverlays'
        -- externalRefreshers dispatch pattern (Overlay/overlay.lua).
        for key, cb in pairs(mapWatchCallbacks) do
            local success, err = pcall(cb, isShown, mapID, maximized)
            if not success and HA.Addon then
                HA.Addon:Debug("Error in map watch callback:", key, err)
            end
        end
    end)
end

-- HS-223a: register to be driven by the shared 0.1s map watcher above instead
-- of starting a second independent ticker. Called every tick with
-- (isShown, mapID, maximized) -- the exact raw state MapSidePanel's watch
-- logic was reading from its own separate poll.
function Provider:RegisterMapWatchCallback(key, callback)
    if not key or type(callback) ~= "function" then return end
    mapWatchCallbacks[key] = callback
end

function Provider:UnregisterMapWatchCallback(key)
    if not key then return end
    mapWatchCallbacks[key] = nil
end

function Provider:SetRenderState(nextRenderState)
    renderState = nextRenderState
    renderedState = nil
    renderedMapID = nil
end

function Provider:GetRenderState()
    return renderState
end

function Provider:GetActiveVendorFrames()
    return activeVendorFrames
end

function Provider:GetDebugStats()
    return debugStats
end

function Provider:GetWatcherStats()
    return watcherStats
end

function Provider:Refresh()
    self:RefreshAllData()
end

function Provider:RemoveAllData()
    MPP.ClearWorldMapPins("HomesteadVendors")

    for i = #activeEntries, 1, -1 do
        ReleaseEntryFrame(activeEntries[i])
        activeEntries[i] = nil
    end

    wipe(activeVendorFrames)
    renderedState = nil
    renderedMapID = nil
end

function Provider:FlushPools()
    self:RemoveAllData()
    FlushPoolBuckets(vendorFramePool)
    FlushPoolBuckets(badgeFramePool)
    FlushPoolBuckets(portalFramePool)
    FlushPoolBuckets(sourceFramePool)
end

function Provider:RenderEntries(entries, kind)
    local viewMapType = renderState and renderState.mapType

    for index, entry in ipairs(entries) do
        local frame
        if kind == "vendor" then
            frame = AcquireVendorFrame(entry)
            activeVendorFrames[#activeVendorFrames + 1] = frame
        elseif kind == "badge" then
            frame = AcquireBadgeFrame(entry)
        elseif kind == "source" then
            frame = AcquireSourceFrame(entry)
        else
            frame = AcquirePortalFrame(entry)
        end

        -- HS-018: source-pin factory may return nil for unsupported source
        -- types (registry has slots reserved for profession/quest/etc with no
        -- factory branch yet). Skip rendering rather than erroring.
        if frame then
            if frame.SetIgnoreParentScale then
                frame:SetIgnoreParentScale(false)
            end
            frame:SetScale(GetEntryDisplayScale(kind, viewMapType))

            entry.kind = kind
            local x, y = entry.x, entry.y
            x, y = ApplyAreaPoiDodge(entry, x, y)
            local iconOffsetX, iconOffsetY = GetEjDropPinIconOffset(entry)
            local wrapper = MPP.PlaceNativePin(frame, x, y, iconOffsetX, iconOffsetY)
            MaybeLogPlacementProbe(entry, wrapper, kind, index)
            MaybeLogSizeProbe(frame, wrapper, kind, index)

            activeEntries[#activeEntries + 1] = {
                kind = kind,
                frame = frame,
            }
        end
    end
end

function Provider:RefreshAllData()
    debugStats.refreshCalls = debugStats.refreshCalls + 1

    if not renderState or not WorldMapFrame or not WorldMapFrame:IsShown() then
        debugStats.skippedHidden = debugStats.skippedHidden + 1
        MaybeLogProviderPerf("hidden")
        self:RemoveAllData()
        return
    end

    local currentMapID = WorldMapFrame:GetMapID()
    if not currentMapID or renderState.mapID ~= currentMapID then
        debugStats.skippedMapMismatch = debugStats.skippedMapMismatch + 1
        MaybeLogProviderPerf("mismatch")
        self:RemoveAllData()
        return
    end

    if renderedState == renderState and renderedMapID == currentMapID and #activeEntries > 0 then
        debugStats.skippedUnchanged = debugStats.skippedUnchanged + 1
        MaybeLogProviderPerf("noop")
        return
    end

    -- HS-239: workload is currentMapID, already computed above for the
    -- mismatch check — no new scan added to feed this call.
    HA.PerformanceTrace:Measure("world_map_refresh", currentMapID, function()
        self:RemoveAllData()

        self:RenderEntries(renderState.vendorPins or {}, "vendor")
        self:RenderEntries(renderState.sourcePins or {}, "source")
        self:RenderEntries(renderState.zoneBadges or {}, "badge")
        self:RenderEntries(renderState.portalBadges or {}, "portal")
        self:RenderEntries(renderState.continentBadges or {}, "badge")
        renderedState = renderState
        renderedMapID = currentMapID
        debugStats.renderedPasses = debugStats.renderedPasses + 1
        debugStats.lastRenderedTotal = #activeEntries
        MaybeLogProviderPerf("render")
    end)
end
