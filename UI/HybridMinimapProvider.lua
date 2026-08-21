--[[
    Homestead - HybridMinimap Provider
    Renders vendor pins onto Blizzard's HybridMinimap canvas, the same
    coverage Homestead already gives the round minimap and the world map.

    HS-368: registers a pin-less data provider on HybridMinimap.MapCanvas
    (AddDataProvider) purely to receive Blizzard's map-state notifications
    (OnShow/OnHide/OnMapChanged/OnCanvasSizeChanged/OnCanvasScaleChanged).
    Never enters Blizzard's managed pin lifecycle -- that lifecycle is the
    taint vector HS-081 hit (a chain reaching a protected passthrough-button
    setter). Vendor pins here are plain, self-managed frames positioned with
    manual math, the exact technique UI/MapPinProvider.lua and
    UI/HomesteadWorldMapProvider.lua already ship for the world map. This
    module never hooks or posthooks any Blizzard-owned frame of any kind --
    all reactivity comes from the data-provider dispatch protocol plus two
    explicit pokes from UI/VendorMapPins.lua.

    Blizzard_HybridMinimap is load-on-demand: the HybridMinimap global does
    not exist until the client decides to use it. Every touch of it below is
    gated behind EventUtil.ContinueOnAddOnLoaded so a session where it never
    loads (the large majority) costs nothing beyond that one deferred check.
]]

local _, HA = ...

local Provider = {}
HA.HybridMinimapProvider = Provider

local PinFrameFactory = HA.PinFrameFactory
local FPU = HA.FramePoolUtils

local ipairs = ipairs
local math_max = math.max
local format = string.format

local BoolToKey = FPU.BoolToKey

local AcquirePooledFrame = FPU.AcquirePooledFrame
local ReleasePooledFrame = FPU.ReleasePooledFrame

-------------------------------------------------------------------------------
-- Registration state
-------------------------------------------------------------------------------

local isRegistered = false
local refreshPending = false

-------------------------------------------------------------------------------
-- Plain-frame HybridMinimap wrappers.
-- Mirrors UI/MapPinProvider.lua's proven world-map technique (own tables --
-- never shared with MapPinProvider's, since the world map and HybridMinimap
-- can both be showing at the same time and must not fight over pooled
-- frames).
-------------------------------------------------------------------------------

local nativePins = {}      -- active wrapper frames
local nativePinPool = {}   -- recycled wrapper frames
local vendorFramePool = {} -- HA.FramePoolUtils bucket table, keyed by faction
local activeVendorFrames = {}

-- Registration target (HybridMinimap.MapCanvas, the MapCanvasFrameTemplate
-- instance) and placement target (that frame's own GetCanvas(), the pannable
-- inner scroll-child -- MapCanvasMixin:GetCanvas() returns
-- self.ScrollContainer.Child, Blizzard_MapCanvas.lua:718) are two different
-- frames. HybridMinimap.MapCanvas itself is live-resized/repositioned every
-- OnUpdate to keep the player centered under the mask
-- (Blizzard_HybridMinimap.lua:109-123) -- anchoring wrapper frames there
-- instead of to GetCanvas() would track the wrong geometry.
local function GetCanvasAndContainer()
    local hybridMinimap = _G.HybridMinimap
    if not hybridMinimap or not hybridMinimap.MapCanvas then
        return nil, nil
    end
    local mapCanvas = hybridMinimap.MapCanvas
    local canvas = mapCanvas.GetCanvas and mapCanvas:GetCanvas() or nil
    local container = mapCanvas.GetCanvasContainer and mapCanvas:GetCanvasContainer() or nil
    return canvas, container
end

local function AcquireNativePin()
    local canvas, container = GetCanvasAndContainer()
    if not canvas or not container then return nil end

    local wrapper = table.remove(nativePinPool)
    if not wrapper then
        wrapper = CreateFrame("Frame", nil, canvas)
    end
    wrapper:SetParent(canvas)
    if wrapper.SetIgnoreParentScale then
        wrapper:SetIgnoreParentScale(false)
    end
    local canvasEffectiveScale = canvas:GetEffectiveScale() or 1
    local uiEffectiveScale = UIParent:GetEffectiveScale() or 1
    if canvasEffectiveScale > 0 then
        wrapper:SetScale(uiEffectiveScale / canvasEffectiveScale)
    else
        wrapper:SetScale(1)
    end

    -- Strata/level: inherit the canvas's own strata (no explicit
    -- SetFrameStrata call -- CreateFrame's default child behavior) and set
    -- the level relative to the canvas's own live level, re-read on every
    -- acquire since wrapper frames are pooled/reparented. HybridMinimap is
    -- frameStrata="BACKGROUND"/fixedFrameStrata="true" and MapCanvas is
    -- useParentLevel="true" (Blizzard_HybridMinimap.xml:5,25) -- Blizzard
    -- deliberately keeps this whole cluster under the minimap's own UI, so
    -- copying MapPinProvider's world-map-tuned MEDIUM/2023 constant here
    -- would put pins above border art and cluster elements it has no
    -- business outranking. HybridMinimap has no comparable native pin
    -- content at the plain-frame layer to outrank either way (its own
    -- content goes through the separate, managed
    -- GetPinFrameLevelsManager() system this module never touches).
    local canvasLevel = canvas:GetFrameLevel() or 0
    wrapper:SetFrameLevel(canvasLevel + 1)

    wrapper:Show()
    nativePins[#nativePins + 1] = wrapper
    return wrapper
end

local function PositionWrapper(wrapper, normX, normY)
    local canvas = wrapper:GetParent()
    if not canvas then
        wrapper:Hide()
        return false
    end
    local width = canvas:GetWidth()
    local height = canvas:GetHeight()
    if not width or not height or width <= 0 or height <= 0 then
        wrapper:Hide()
        return false
    end
    local pinScale = wrapper:GetScale()
    if not pinScale or pinScale <= 0 then pinScale = 1 end
    wrapper:ClearAllPoints()
    wrapper:SetPoint("CENTER", canvas, "TOPLEFT",
        (width * normX) / pinScale,
        -(height * normY) / pinScale)
    wrapper:Show()
    return true
end

local function ReleaseAllNativePins()
    for i = #nativePins, 1, -1 do
        local wrapper = nativePins[i]
        if wrapper.icon then
            wrapper.icon:Hide()
            wrapper.icon:SetParent(UIParent)
            wrapper.icon:ClearAllPoints()
            wrapper.icon = nil
        end
        wrapper:Hide()
        wrapper:ClearAllPoints()
        wrapper:SetParent(UIParent)
        nativePinPool[#nativePinPool + 1] = wrapper
        nativePins[i] = nil
    end
end

-- Place a plain-frame HybridMinimap pin. Same technique as
-- MapPinProvider.PlaceNativePin (verbatim math): the wrapper is the thing
-- anchored to the canvas's (x, y) via normalized coordinates and scale
-- counter-normalized to real screen pixels; the content frame (the vendor
-- icon) is reparented onto it so hover/click hit-rects track the icon.
local function PlaceNativePin(frame, x, y)
    local wrapper = AcquireNativePin()
    if not wrapper then return nil end

    local iconW = frame and frame.GetWidth and frame:GetWidth() or 1
    local iconH = frame and frame.GetHeight and frame:GetHeight() or 1
    local iconScale = frame and frame.GetScale and frame:GetScale() or 1
    wrapper:SetSize(math_max(1, iconW * iconScale), math_max(1, iconH * iconScale))

    wrapper.icon = frame
    frame:SetParent(wrapper)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", wrapper, "CENTER", 0, 0)
    if frame.SetFrameStrata then frame:SetFrameStrata(wrapper:GetFrameStrata()) end
    if frame.SetFrameLevel then frame:SetFrameLevel(wrapper:GetFrameLevel() + 1) end
    frame:Show()

    PositionWrapper(wrapper, x, y)
    return wrapper
end

-------------------------------------------------------------------------------
-- Vendor pin frame pool
-------------------------------------------------------------------------------

-- Mirrors HomesteadWorldMapProvider.lua's GetVendorFramePoolKey exactly (same
-- shape, same fix history): PinFrameFactory:CreateVendorPinFrame bakes icon
-- size, color, and the professionShop gold tint into the frame permanently
-- at creation time, and this module does a full release-then-reacquire pass
-- every refresh (DoRefresh), never an in-place restyle -- so any of those
-- properties left out of the key means a style change (or a vendorType
-- mismatch on frame reuse) sticks on already-live frames until /reload,
-- with nothing to flush the stale ones. Faction/vendorType join the key for
-- the same reason PinFrameFactory bakes them in.
local function BuildVendorPinStyleKey()
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

    local vendorTypeKey = (entry.vendor and entry.vendor.vendorType) or "none"

    return format("%s|o%s|f%s|vt%s",
        BuildVendorPinStyleKey(),
        BoolToKey(entry.isOppositeFaction),
        factionKey,
        vendorTypeKey)
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

local function FlushVendorFrame(frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(UIParent)
end

-------------------------------------------------------------------------------
-- Render pass
-------------------------------------------------------------------------------

function Provider:RenderEntries(vendorPins)
    for _, entry in ipairs(vendorPins) do
        local frame = AcquireVendorFrame(entry)
        if frame then
            PlaceNativePin(frame, entry.x, entry.y)
            activeVendorFrames[#activeVendorFrames + 1] = frame
        end
    end
end

function Provider:RemoveAllData()
    ReleaseAllNativePins()
    for i = #activeVendorFrames, 1, -1 do
        ReleasePooledFrame(vendorFramePool, activeVendorFrames[i], FlushVendorFrame)
        activeVendorFrames[i] = nil
    end
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

-- Deferred fire: re-checks every gate fresh (not whatever triggered the
-- request) since state can change between the poke and the next frame --
-- e.g. HybridMinimapMixin:OnHide nils self.mapID. Same discipline
-- HomesteadWorldMapProvider's RequestDeferredRefresh uses reading
-- WorldMapFrame:GetMapID() at fire time (HomesteadWorldMapProvider.lua,
-- HS-234 comment), not a captured value.
local function DoRefresh()
    refreshPending = false

    if not isRegistered then return end

    local hybridMinimap = _G.HybridMinimap
    if not hybridMinimap then
        Provider:RemoveAllData()
        return
    end

    -- HybridMinimapMixin:CheckMap can leave self.mapID set while the frame
    -- itself stays hidden (SetMapID returning false calls SetShown(false),
    -- and no OnHide fires if it was already hidden) -- without this check
    -- every poke would still do a full render pass onto a canvas nobody can
    -- see.
    if not hybridMinimap:IsShown() then
        Provider:RemoveAllData()
        return
    end

    local VMP = HA.VendorMapPins
    if not VMP or not VMP.IsMinimapPinsEnabled or not VMP:IsMinimapPinsEnabled() then
        Provider:RemoveAllData()
        return
    end

    local mapID = hybridMinimap:GetMapID()
    if not mapID then
        Provider:RemoveAllData()
        return
    end

    local renderState = VMP:BuildWorldMapRenderState(mapID)
    Provider:RemoveAllData()
    if renderState and renderState.vendorPins then
        Provider:RenderEntries(renderState.vendorPins)
    end
end

-- Public entry point. Every VendorMapPins-side poke and every canvas-dispatch
-- handler below funnels through this one same-frame-coalesced path.
--
-- Gate order matters: this function itself never touches GetMapID() (that
-- call lives only in DoRefresh's fire handler) and returns before doing
-- anything else if _G.HybridMinimap is nil. The caller-side nil-guard
-- (`if HA.HybridMinimapProvider then ...`, VendorMapPins.lua) only proves
-- this module's own table exists -- it exists in every session
-- unconditionally (regular .toc load), whether or not Blizzard_HybridMinimap
-- ever loads. Without this function's own guard, the common (never-loads)
-- session would nil-index _G.HybridMinimap the first time any zone-change or
-- ownership-scan poke fired.
function Provider:RequestRefresh(reason)
    if not isRegistered then return end
    if _G.HybridMinimap == nil then return end
    if refreshPending then return end

    if reason and HA.DevAddon and HA.Addon and HA.Addon.db and HA.Addon.db.profile.debug then
        HA.Addon:Debug("HybridMinimap refresh requested: " .. reason)
    end

    refreshPending = true
    C_Timer.After(0, DoRefresh)
end

-- Immediate clear, no debounce -- used for the disable-while-active case
-- where pins must disappear on the spot, not on the next coalesced tick.
function Provider:Clear()
    self:RemoveAllData()
end

-------------------------------------------------------------------------------
-- Canvas dispatch (mixed onto a CreateFromMixins(MapCanvasDataProviderMixin)
-- delegate in EnsureRegistered, not onto Provider itself -- same isolation
-- HomesteadWorldMapProvider uses so a missing method name from a future
-- Blizzard dispatch can't raise mid-loop inside Provider's own render path).
-------------------------------------------------------------------------------

local providerMethods = {}

function providerMethods:OnShow()
    Provider:RequestRefresh("hybrid_canvas_shown")
end

function providerMethods:OnHide()
    Provider:RemoveAllData()
end

function providerMethods:OnMapChanged()
    Provider:RequestRefresh("hybrid_canvas_map_changed")
end

-- HybridMinimap zooms instantly (SetShouldZoomInstantly(true),
-- Blizzard_HybridMinimap.lua:8) rather than animating continuously like the
-- world map's pinch/scroll zoom, so a full debounced refresh on size/scale
-- change is sufficient here -- no per-tick reposition loop to mirror from
-- MapPinProvider.RepositionWorldMapPins is needed for this commit.
function providerMethods:OnCanvasSizeChanged()
    Provider:RequestRefresh("hybrid_canvas_size_changed")
end

function providerMethods:OnCanvasScaleChanged()
    Provider:RequestRefresh("hybrid_canvas_scale_changed")
end

function providerMethods:RefreshAllData()
    Provider:RequestRefresh("hybrid_canvas_refresh_all")
end

function providerMethods:RemoveAllData()
    -- Required by MapCanvasMixin:RemoveDataProvider, which calls this before
    -- clearing the provider table key. The inherited MapCanvasDataProvider-
    -- Mixin stub is a no-op and would strand rendered pins on a future
    -- unregister.
    Provider:RemoveAllData()
end

-------------------------------------------------------------------------------
-- Registration
-------------------------------------------------------------------------------

function Provider:EnsureRegistered()
    if isRegistered then return end

    local hybridMinimap = _G.HybridMinimap
    if not hybridMinimap or not hybridMinimap.MapCanvas then return end

    -- Fail-loud, not a silent return and not a Debug line -- duck-typed
    -- dispatch means a Blizzard rename of this callback would otherwise
    -- produce no error at all, just pins that quietly never render. Same
    -- guard, same rationale, as HomesteadWorldMapProvider:EnsureRegistered.
    if MapCanvasDataProviderMixin == nil
            or MapCanvasDataProviderMixin.OnCanvasScaleChanged == nil then
        error("Homestead: MapCanvasDataProviderMixin.OnCanvasScaleChanged is missing. "
            .. "The HybridMinimap vendor pin provider has detached -- Blizzard renamed or "
            .. "removed the canvas data-provider callback this addon depends on.")
    end

    isRegistered = true

    local delegate = CreateFromMixins(MapCanvasDataProviderMixin)
    Mixin(delegate, providerMethods)
    hybridMinimap.MapCanvas:AddDataProvider(delegate)
end

-------------------------------------------------------------------------------
-- Blizzard_HybridMinimap is load-on-demand; this is Blizzard's own idiom for
-- reacting to it loading (calls back immediately if already loaded, else a
-- one-shot ADDON_LOADED listener). Never assume the HybridMinimap global
-- exists without this gate.
-------------------------------------------------------------------------------

EventUtil.ContinueOnAddOnLoaded("Blizzard_HybridMinimap", function()
    Provider:EnsureRegistered()
end)
