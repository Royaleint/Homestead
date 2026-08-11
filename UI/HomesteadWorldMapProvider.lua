--[[
    Homestead - World Map Provider
    Self-managed world-map renderer using plain canvas-child frames.

    HS-275: registers a PIN-LESS data provider (WorldMapFrame:AddDataProvider)
    purely to receive Blizzard's map-state notifications (OnShow/OnHide/
    OnMapChanged/OnCanvasSizeChanged/OnCanvasScaleChanged). Still does NOT use
    MapCanvasPinMixin or enter Blizzard's managed pin lifecycle or pin-frame
    pooling — that lifecycle calls protected SetPassThroughButtons in combat
    and is the taint vector HS-081 hit. Vendor/badge/portal/source pins keep
    the existing plain-frame path (MPP.PlaceNativePin) untouched.
]]

local _, HA = ...

local Provider = {}
HA.HomesteadWorldMapProvider = Provider

local MPP = HA.MapPinProvider
local PinFrameFactory = HA.PinFrameFactory
local FPU = HA.FramePoolUtils

local ipairs = ipairs
local format = string.format
local Lerp = Lerp
local Saturate = Saturate

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
-- HS-223a: external consumers (currently MapSidePanel) of the shared map
-- watch dispatch below, keyed by caller-chosen string so multiple registrants
-- can't clobber each other. Each callback receives (isShown, mapID,
-- maximized) on every dispatch -- the raw state MapSidePanel's own watch
-- logic needs, read from this ONE dispatch instead of running an independent
-- watcher against the same WorldMapFrame state. HS-275: dispatch is now
-- driven by DispatchMapWatch() (on-change, push-driven) instead of a 0.1s
-- poll -- see DispatchMapWatch below.
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

-- HS-274: pins hold GetEntryDisplayScale's base size at min zoom and grow
-- toward PIN_ZOOM_GROWTH_MAX as the canvas zooms in, matching Blizzard's own
-- pin growth feel (MapCanvasPinMixin:ApplyCurrentScale's Lerp shape) instead
-- of a flat size. Both constants are a Gate-2-tunable design choice, not a
-- mechanism -- safe to retune without re-review.
local PIN_ZOOM_GROWTH_MAX = 1.5
local PIN_ZOOM_SCALE_FACTOR = 1.0

-- Perf: split out so a caller rescaling many pins in the same tick (the
-- OnCanvasScaleChanged loop below) can query WorldMapFrame once and pass the
-- result to GetEntryZoomedScale for every pin, instead of paying
-- HasZoomLevels()/GetCanvasZoomPercent() again per pin.
local function GetZoomScaleMultiplier()
    if not WorldMapFrame or not WorldMapFrame:HasZoomLevels() then
        return 1.0
    end

    local zoomPct = WorldMapFrame:GetCanvasZoomPercent()
    return Lerp(1.0, PIN_ZOOM_GROWTH_MAX, Saturate(PIN_ZOOM_SCALE_FACTOR * zoomPct))
end

local function GetEntryZoomedScale(kind, mapType, zoomScaleMultiplier)
    local base = GetEntryDisplayScale(kind, mapType)
    return base * (zoomScaleMultiplier or GetZoomScaleMultiplier())
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

-- Perf: hoisted out of RequestSettledRefresh so re-scheduling (Cancel +
-- NewTimer on every zoom tick, dozens/sec while zooming) reuses this one
-- function value instead of allocating a fresh closure per tick.
local function OnSettleTimerFire()
    settleTimer = nil
    local VMP = HA.VendorMapPins
    if VMP and VMP.RefreshPins then
        VMP:RefreshPins(true)
    elseif isRegistered and Provider and Provider.RefreshAllData then
        Provider:RefreshAllData()
    end
end

local function RequestSettledRefresh(reason)
    watcherStats.settledRefreshes = watcherStats.settledRefreshes + 1
    if IsDebugModeEnabled() and reason then
        HA.Addon:Debug("WorldMapWatcher: " .. reason .. " (settling)")
    end

    if settleTimer then
        settleTimer:Cancel()
    end

    settleTimer = C_Timer.NewTimer(WATCHER_SETTLE_DELAY, OnSettleTimerFire)
end

-- HS-275: identity kept so a future RemoveDataProvider call has a stable
-- reference to match on (CLAIM-PINS-0011 -- MapCanvasMixin:RemoveDataProvider
-- clears its dataProviders table by instance identity).
local mapDataProvider = nil

local mapWatchPending = false

local function DispatchMapWatch()
    if mapWatchPending then return end
    mapWatchPending = true
    C_Timer.After(0, function()
        mapWatchPending = false
        local isShown = WorldMapFrame and WorldMapFrame:IsShown() or false
        local mapID = isShown and WorldMapFrame:GetMapID() or nil
        local maximized = isShown and (WorldMapFrame.isMaximized and true or false) or false
        for key, cb in pairs(mapWatchCallbacks) do
            local success, err = pcall(cb, isShown, mapID, maximized)
            if not success and HA.Addon then
                HA.Addon:Debug("Error in map watch callback:", key, err)
            end
        end
    end)
end

-- HS-275: handlers dispatched by Blizzard's MapCanvasMixin data-provider
-- protocol (WorldMapFrame:CallMethodOnDataProviders / CallMethodOnPinsAnd
-- DataProviders), armored by secureexecuterange on every dispatch. Mixed
-- onto a CreateFromMixins(MapCanvasDataProviderMixin) delegate in
-- EnsureRegistered -- not onto Provider itself, so a missing method name
-- from a future Blizzard dispatch can't raise mid-loop inside Provider's
-- own render path, and so RefreshAllData here can mean "kick the deferred
-- refresh" without colliding with Provider:RefreshAllData's real
-- synchronous teardown-and-rebuild.
local mapDataProviderMethods = {}

function mapDataProviderMethods:OnShow()
    watcherStats.opened = watcherStats.opened + 1
    -- POI-dodge cache is keyed on mapID and never busts within a map,
    -- so event POIs that appeared/disappeared while the map was closed
    -- (Saltheril's Soiree, Abundance, ...) would keep dodging against
    -- stale positions on re-show. Bust it on every map re-show.
    cachedPoiMapID = nil
    cachedPoiPositions = nil
    C_Timer.After(0, function()
        RequestDeferredRefresh("watcher_opened")
    end)
    DispatchMapWatch()
end

function mapDataProviderMethods:OnHide()
    watcherStats.closed = watcherStats.closed + 1
    -- HS-234: a pending settle-debounce from a transition made just
    -- before closing the map would otherwise fire uselessly ~0.25s
    -- later against a closed map — cancel it now, same discipline
    -- VendorMapPins:ClearAllPins already applies to its own
    -- worldMapRefreshTimer.
    if settleTimer then
        settleTimer:Cancel()
        settleTimer = nil
    end
    Provider:RemoveAllData()
    DispatchMapWatch()
end

function mapDataProviderMethods:OnMapChanged()
    watcherStats.mapChanged = watcherStats.mapChanged + 1
    RequestSettledRefresh("watcher_map_changed")
    DispatchMapWatch()
end

function mapDataProviderMethods:OnCanvasSizeChanged()
    watcherStats.resized = watcherStats.resized + 1
    if IsDebugModeEnabled() then
        HA.Addon:Debug("WorldMapWatcher: watcher_resize")
    end
    MPP.RepositionWorldMapPins()
    DispatchMapWatch()
end

function mapDataProviderMethods:OnCanvasScaleChanged()
    watcherStats.zoomChanged = watcherStats.zoomChanged + 1

    -- HS-274: per-tick, in-place rescale so pins track zoom continuously
    -- instead of only snapping to the right size once the settled refresh
    -- below lands. RepositionWorldMapPins refreshes the wrapper counter-scale
    -- (uiScale/canvasScale) that holds pins at their intended screen size;
    -- the loop then re-applies each pin's own zoomed content scale on top.
    -- renderState can be nil between map close and the next open -- nothing
    -- to rescale yet, so skip rather than walk a stale activeEntries.
    if renderState then
        MPP.RepositionWorldMapPins()
        -- Perf: query WorldMapFrame's zoom state once per tick instead of
        -- once per pin -- GetEntryZoomedScale would otherwise re-derive the
        -- same HasZoomLevels()/GetCanvasZoomPercent() result for every entry.
        local zoomScaleMultiplier = GetZoomScaleMultiplier()
        for _, active in ipairs(activeEntries) do
            active.frame:SetScale(GetEntryZoomedScale(active.kind, renderState.mapType, zoomScaleMultiplier))
        end
    end

    -- Full refresh on zoom change so POI dodge recalculates
    -- with the new zoom factor (pins drift back at high zoom).
    RequestSettledRefresh("watcher_zoom")
    DispatchMapWatch()
end

function mapDataProviderMethods:RefreshAllData()
    -- MapCanvasMixin:RefreshAllDataProviders (Blizzard_MapCanvas.lua) closes
    -- over a free `fromOnShow` that never resolves to the caller's argument
    -- -- providers always receive nil here. Do not read it.
    RequestDeferredRefresh("provider_refresh_all")
    DispatchMapWatch()
end

function mapDataProviderMethods:RemoveAllData()
    -- Required by MapCanvasMixin:RemoveDataProvider, which calls this
    -- before clearing the provider table key by instance identity. The
    -- inherited MapCanvasDataProviderMixin stub is a no-op and would strand
    -- rendered pins on a future unregister.
    Provider:RemoveAllData()
    DispatchMapWatch()
end

-- HS-275: canvas *effective* scale also moves when UIParent scale changes
-- (uiScale CVar, resolution change), and no MapCanvasMixin callback fires
-- for that -- it isn't a canvas-size or canvas-scale event, it's a
-- UIParent-wide rescale. Own event frame, same idiom as
-- HomesteadMinimapOverlay.lua's cvarFrame -- these are WoW engine events,
-- not provider dispatch, so they go through CreateFrame+RegisterEvent, not
-- MapCanvasDataProviderMixin:RegisterEvent.
local scaleEventFrame = CreateFrame("Frame")
scaleEventFrame:RegisterEvent("UI_SCALE_CHANGED")
scaleEventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
scaleEventFrame:SetScript("OnEvent", function()
    if isRegistered and WorldMapFrame and WorldMapFrame:IsShown() then
        RequestSettledRefresh("ui_scale_changed")
    end
end)

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

    -- HS-275: fail-loud, not a silent return and not a Debug line. Duck-typed
    -- dispatch means a Blizzard rename of this callback produces no error at
    -- all otherwise — just pins that quietly stop repositioning. Blizzard_
    -- MapCanvas is LoadOnDemand, so MapCanvasDataProviderMixin can be nil at
    -- Homestead file-scope load; the WorldMapFrame guard just above is the
    -- proof the addon is loaded by the time we get here.
    if MapCanvasDataProviderMixin == nil
            or MapCanvasDataProviderMixin.OnCanvasScaleChanged == nil then
        error("Homestead: MapCanvasDataProviderMixin.OnCanvasScaleChanged is missing. "
            .. "The world-map pin refresh mechanism has detached -- Blizzard renamed or "
            .. "removed the canvas data-provider callback this addon depends on.")
    end

    self.mapCanvas = WorldMapFrame:GetCanvasContainer()
    isRegistered = true

    -- HS-275: every read of WorldMapFrame.dataProviders inside Blizzard's
    -- dispatch (Blizzard_MapCanvas.lua: AddDataProvider, RemoveDataProvider,
    -- CallMethodOnDataProviders, CallMethodOnPinsAndDataProviders) goes
    -- through secureexecuterange -- Blizzard's own containment primitive for
    -- addon-writable registries. That is what replaces the old polling
    -- ticker as the taint-safe detection mechanism. No WorldMapFrame
    -- HookScript/hooksecurefunc is used here or anywhere else -- those still
    -- run inside Blizzard's secure map-open path and remain forbidden
    -- (HS-081).
    mapDataProvider = CreateFromMixins(MapCanvasDataProviderMixin)
    Mixin(mapDataProvider, mapDataProviderMethods)
    WorldMapFrame:AddDataProvider(mapDataProvider)
end

-- HS-223a: register to be driven by DispatchMapWatch above instead of
-- starting a second independent watcher. Called on-change with
-- (isShown, mapID, maximized) -- the exact raw state MapSidePanel's watch
-- logic was reading from its own separate poll. HS-275: dispatch is now
-- push-driven off the map data provider's callbacks instead of a 10Hz poll.
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
            frame:SetScale(GetEntryZoomedScale(kind, viewMapType))

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

-------------------------------------------------------------------------------
-- HS-271 item 1: Pool Floor Pre-Build
--
-- Cold first pin-frame acquire on a dense map pays CreateFrame for every
-- distinct pool bucket the render touches (PinFrameFactory:Create*Frame),
-- landing inside the world_map_refresh render pass diagnosed at 558-651ms
-- (HS-270 captures A/D). Pre-building a floor of frames into each pool at
-- login moves that CreateFrame cost off the render path for the common
-- case: the default style/faction/source-type bucket every kind resolves
-- to before any player style customization.
--
-- Floor sizes are density-derived (HS-271 Gate 0): 16 vendor (Razorwind
-- Shores, the densest zone), 10 badge (continent zone-badge view), 6 source
-- (drop pins -- the only populated non-vendor source type today). Only the
-- DEFAULT bucket is pre-built -- a mid-session pin-style change before first
-- open still pays its own CreateFrame cost for that combination (accepted
-- scope boundary, Plan Gate 1 item 1: the floor is a floor, not a guarantee
-- for every style combination).
--
-- No portal floor (Gate 1 cycle 1: removed entirely, not sized to 0 as a
-- count — GetPortalFramePoolKey's synthetic empty portalData never matches
-- a REAL portal acquire's key (class-keyed off vendor.class), and portal
-- pins don't appear on the freeze-class dense maps this item targets — a
-- floor that can never be drawn from is dead weight, not a floor.
--
-- Frames are pushed straight into the pool via ReleasePooledFrame (never
-- rendered) -- this reuses the SAME pool-key functions and CreateFrame
-- factories the render path already calls, just run ahead of any
-- player-triggered map open.
-------------------------------------------------------------------------------

local POOL_FLOOR_COUNTS = {
    vendor = 16,
    badge = 10,
    source = 6,
}
local POOL_FLOOR_KIND_ORDER = { "vendor", "badge", "source" }

-- Small per-tick batch: this runs once at login, off the render path, but
-- still shouldn't land 32 CreateFrame calls on one frame during the busy
-- login/loading-screen window.
local POOL_FLOOR_BATCH_SIZE = 4
local POOL_FLOOR_BATCH_DELAY = 0.05
-- HS-238: same combat-retry idiom as HS-234's ProcessBatch -- this pre-build
-- has no urgency, so it costs nothing to defer it off combat frames.
local POOL_FLOOR_COMBAT_RETRY_DELAY = 1.0

local function BuildPoolFloorQueue()
    local queue = {}
    for _, kind in ipairs(POOL_FLOOR_KIND_ORDER) do
        for _ = 1, POOL_FLOOR_COUNTS[kind] do
            queue[#queue + 1] = kind
        end
    end
    return queue
end

-- Default-bucket synthetic job for one kind: pool key derived from the
-- player's CURRENT live pin-style settings (Get*FramePoolKey functions read
-- PinFrameFactory's style getters directly), with neutral/empty source data
-- so every Get*FramePoolKey resolves to its default/neutral/"none" bucket --
-- the same bucket a fresh pin resolves to before any per-vendor/per-badge
-- customization.
local function BuildPoolFloorJob(kind)
    if kind == "vendor" then
        local vendor, isOppositeFaction = {}, false
        local poolKey = GetVendorFramePoolKey({ vendor = vendor, isOppositeFaction = isOppositeFaction })
        return poolKey, vendorFramePool, function()
            return PinFrameFactory:CreateVendorPinFrame(vendor, isOppositeFaction)
        end
    elseif kind == "badge" then
        local badgeData = {}
        local poolKey = GetBadgeFramePoolKey(badgeData)
        return poolKey, badgeFramePool, function()
            return PinFrameFactory:CreateBadgePinFrame(badgeData)
        end
    elseif kind == "source" then
        local record = { sourceType = "drop" }
        local poolKey = GetSourceFramePoolKey(record)
        return poolKey, sourceFramePool, function()
            return PinFrameFactory:CreateSourcePinFrame(record.sourceType, record)
        end
    end
end

function Provider:PrewarmPoolFloor()
    local queue = BuildPoolFloorQueue()
    local index = 1

    local function ProcessBatch()
        if _G.InCombatLockdown() then
            C_Timer.After(POOL_FLOOR_COMBAT_RETRY_DELAY, ProcessBatch)
            return
        end

        local batchEnd = math.min(index + POOL_FLOOR_BATCH_SIZE - 1, #queue)
        for i = index, batchEnd do
            local kind = queue[i]
            local poolKey, pool, createFunc = BuildPoolFloorJob(kind)
            local frame = createFunc()
            if kind == "vendor" then
                -- HS-271 Gate 1 cycle 1 nit: CreateVendorPinFrame's own
                -- RefreshVendorPinCount call (for the synthetic {} vendor
                -- above) is a double miss by construction (no npcID) and
                -- sets hsStatsPending=true — harmless (RequestPrewarm is
                -- debounced) but leaves the pooled frame flagged pending for
                -- a vendor that was never real. Reset explicitly so a later
                -- real AcquireVendorFrame always starts this flag from a
                -- known-false baseline, never a leftover from pool-floor's
                -- own synthetic creation.
                frame.hsStatsPending = false
            end
            frame.__hsPoolKey = poolKey
            ReleasePooledFrame(pool, frame)
        end
        index = batchEnd + 1

        if index <= #queue then
            C_Timer.After(POOL_FLOOR_BATCH_DELAY, ProcessBatch)
        end
    end

    C_Timer.After(POOL_FLOOR_BATCH_DELAY, ProcessBatch)
end

-- Login trigger: same self-terminating polling idiom as BadgeCalculation.lua's
-- login warmup ticker (HS-234) -- bounded so a session where OnInitialize
-- somehow never completes doesn't poll forever. Polls addon-init completion
-- (HA.Addon._initialized, set at the end of Core/core.lua's OnInitialize)
-- rather than IsWarm(): frame creation needs no catalog data, only
-- PinFrameFactory's style-key readers (HA.Addon.db).
local POOL_FLOOR_LOGIN_POLL_INTERVAL = 0.5
local POOL_FLOOR_LOGIN_MAX_POLLS = 40
local poolFloorLoginPolls = 0
local poolFloorLoginTicker = nil

poolFloorLoginTicker = C_Timer.NewTicker(POOL_FLOOR_LOGIN_POLL_INTERVAL, function()
    poolFloorLoginPolls = poolFloorLoginPolls + 1
    if HA.Addon and HA.Addon._initialized then
        poolFloorLoginTicker:Cancel()
        Provider:PrewarmPoolFloor()
    elseif poolFloorLoginPolls >= POOL_FLOOR_LOGIN_MAX_POLLS then
        poolFloorLoginTicker:Cancel()
    end
end)
