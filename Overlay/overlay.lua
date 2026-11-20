--[[
    Homestead - Overlay System
    Core framework for displaying collection status icons on item frames

    IMPORTANT: This is an original implementation built from scratch.
    It does not copy or derive from any other addon's overlay system.
]]

local _, HA = ...

local Overlay = {}
HA.Overlay = Overlay

-- Local references
local Constants = HA.Constants
local Events = HA.Events

-- Configuration
local OVERLAY_CONFIG = Constants.Overlay or {
    ICON_SIZE = 14,
    DEFAULT_ANCHOR = "TOPLEFT",
    OFFSET_X = 2,
    OFFSET_Y = -2,
    UPDATE_THROTTLE = 0.1,
    STRATA = "HIGH",
    LEVEL_OFFSET = 10,
}

-- guards Initialize() against double registration now that it's
-- actually wired into core.lua's OnEnable — matches the isInitialized
-- pattern other modules (e.g. Modules/CatalogScanner.lua) already use.
local isInitialized = false

-- Track all created overlays
local activeOverlays = {}

-- Read-only fallback for nil-opts SetHomestoneState callers (see its comment).
local EMPTY_OPTS = {}
local overlayCount = 0
local externalRefreshers = {}

local function GetProfileOverlaySettings()
    return HA.Addon and HA.Addon.db and HA.Addon.db.profile and HA.Addon.db.profile.overlay
end

local function GetAnchorOffsets(anchor, offsetX, offsetY)
    offsetX = offsetX or OVERLAY_CONFIG.OFFSET_X
    offsetY = offsetY or OVERLAY_CONFIG.OFFSET_Y

    if anchor == "TOPRIGHT" then
        offsetX = -offsetX
    elseif anchor == "BOTTOMLEFT" then
        offsetY = -offsetY
    elseif anchor == "BOTTOMRIGHT" then
        offsetX = -offsetX
        offsetY = -offsetY
    elseif anchor == "CENTER" then
        offsetX = 0
        offsetY = 0
    end

    return offsetX, offsetY
end

local function ApplyIconDefinition(texture, definition)
    if not texture or not definition then return end

    if type(definition) == "table" and definition.atlas and texture.SetAtlas then
        texture:SetAtlas(definition.atlas, false)
    else
        texture:SetTexture(definition)
    end
end

local function GetHomestoneColor(state)
    local colors = Constants and Constants.Colors
    if not colors then return nil end

    if state == "owned" then
        return colors.COLLECTED
    elseif state == "in_bags_unlearned" then
        return colors.IN_BAGS_UNLEARNED
    elseif state == "unowned" then
        return colors.NOT_COLLECTED
    end

    return nil
end

local function GetHomestoneBaseColor(state)
    local color = GetHomestoneColor(state)
    if not color then return nil end

    return {
        r = 0.55 + (color.r * 0.45),
        g = 0.55 + (color.g * 0.45),
        b = 0.55 + (color.b * 0.45),
        a = color.a or 1,
    }
end

local function PositionHomestoneTexture(parent, texture, size, anchor, offsetX, offsetY)
    if not texture then return end

    texture:ClearAllPoints()
    texture:SetPoint(anchor, parent, anchor, offsetX, offsetY)
    texture:SetSize(size, size)
end

local function PositionHomestoneGlow(base, glow, size)
    if not base or not glow then return end

    glow:ClearAllPoints()
    glow:SetPoint("CENTER", base, "CENTER", 0, 0)
    glow:SetSize(size, size)
end

-------------------------------------------------------------------------------
-- Overlay Creation
-------------------------------------------------------------------------------

-- Create a new overlay frame for an item button
function Overlay:CreateOverlay(parentFrame, updateFunc)
    if not parentFrame then return nil end

    -- Check if overlay already exists
    local existingOverlay = parentFrame.HousingAddonOverlay
    if existingOverlay then
        return existingOverlay
    end

    overlayCount = overlayCount + 1

    -- Use unnamed frames/textures to avoid polluting the global namespace.
    local overlay = CreateFrame("Frame", nil, parentFrame)
    overlay:SetFrameStrata(OVERLAY_CONFIG.STRATA)

    local icon = overlay:CreateTexture(nil, "OVERLAY")
    icon:SetSize(OVERLAY_CONFIG.ICON_SIZE, OVERLAY_CONFIG.ICON_SIZE)
    icon:SetPoint(
        OVERLAY_CONFIG.DEFAULT_ANCHOR,
        overlay,
        OVERLAY_CONFIG.DEFAULT_ANCHOR,
        OVERLAY_CONFIG.OFFSET_X,
        OVERLAY_CONFIG.OFFSET_Y
    )
    overlay.icon = icon

    -- Configure overlay for this parent
    overlay:SetParent(parentFrame)
    overlay:SetAllPoints(parentFrame)
    overlay:SetFrameLevel(parentFrame:GetFrameLevel() + OVERLAY_CONFIG.LEVEL_OFFSET)
    overlay:Show()

    -- Store update function
    overlay.updateFunc = updateFunc

    -- Store reference on parent
    parentFrame.HousingAddonOverlay = overlay

    -- Track active overlay
    activeOverlays[overlay] = true

    return overlay
end

-------------------------------------------------------------------------------
-- Icon Display
-------------------------------------------------------------------------------

function Overlay:EnsureHomestoneTextures(parent)
    if not parent then return nil, nil end

    if parent.HomestoneBase and parent.HomestoneGlow then
        return parent.HomestoneBase, parent.HomestoneGlow
    end

    local base = parent.HomestoneBase or parent:CreateTexture(nil, "OVERLAY")
    local glow = parent.HomestoneGlow or parent:CreateTexture(nil, "OVERLAY")

    parent.HomestoneBase = base
    parent.HomestoneGlow = glow

    return base, glow
end

function Overlay:SetHomestoneState(parent, state, opts)
    if not parent then return end

    local base, glow = self:EnsureHomestoneTextures(parent)
    if not base or not glow then return end

    if state == nil then
        self:ClearHomestoneTextures(parent)
        return
    end

    local settings = GetProfileOverlaySettings()
    -- Shared empty fallback: nil-opts callers (Containers, Merchant) sit on the
    -- hottest refresh path, and this function only ever reads opts. Never write
    -- into EMPTY_OPTS.
    opts = opts or EMPTY_OPTS

    local size = opts.size or (settings and settings.iconSize) or OVERLAY_CONFIG.ICON_SIZE
    local anchor = opts.anchor or (settings and settings.iconAnchor) or OVERLAY_CONFIG.DEFAULT_ANCHOR
    local offsetX, offsetY = GetAnchorOffsets(anchor, opts.offsetX, opts.offsetY)

    parent.HomestoneState = state

    -- Reuse the per-overlay options table in place instead of
    -- allocating a new 4-field table on every call (CatalogOverlay
    -- pattern). All four fields are always overwritten below, so no field can
    -- carry a stale value from a previous slot/state.
    local homestoneOptions = parent.HomestoneOptions
    if not homestoneOptions then
        homestoneOptions = {}
        parent.HomestoneOptions = homestoneOptions
    end
    homestoneOptions.size = size
    homestoneOptions.anchor = anchor
    homestoneOptions.offsetX = opts.offsetX
    homestoneOptions.offsetY = opts.offsetY

    PositionHomestoneTexture(parent, base, size, anchor, offsetX, offsetY)
    PositionHomestoneGlow(base, glow, size * 1.12)

    local icons = Constants and Constants.Icons
    ApplyIconDefinition(base, icons and icons.HOMESTONE_BASE)
    ApplyIconDefinition(glow, icons and icons.HOMESTONE_INNERGLOW)

    local color = GetHomestoneColor(state)
    local baseColor = GetHomestoneBaseColor(state)
    if color then
        base:SetVertexColor(baseColor.r, baseColor.g, baseColor.b, baseColor.a or 1)
        glow:SetVertexColor(color.r, color.g, color.b, color.a or 1)
    else
        base:SetVertexColor(1, 1, 1, 1)
        glow:SetVertexColor(1, 1, 1, 1)
    end

    base:Show()
    glow:Show()
end

function Overlay:ClearHomestoneTextures(parent)
    if not parent then return end

    if parent.HomestoneBase then
        parent.HomestoneBase:Hide()
        parent.HomestoneBase:SetTexture(nil)
    end
    if parent.HomestoneGlow then
        parent.HomestoneGlow:Hide()
        parent.HomestoneGlow:SetTexture(nil)
    end

    parent.HomestoneState = nil
    parent.HomestoneOptions = nil
end

-- Clear the icon on an overlay
function Overlay:ClearIcon(overlay)
    if overlay and overlay.icon then
        overlay.icon:Hide()
        overlay.icon:SetTexture(nil)
    end
    self:ClearHomestoneTextures(overlay)
end

-------------------------------------------------------------------------------
-- Update Functions
-------------------------------------------------------------------------------

-- Request update for a specific overlay type
function Overlay:RequestUpdate(updateType)
    Events:RequestUpdate(updateType)
end

-- Refresh all active overlays.
-- runExternal (default true): whether to also run the externalRefreshers pass
-- (Baganator/BetterBags/etc). The "bags" event fires on every bag
-- change and each external bag addon already refreshes itself via its own
-- hook, so the high-frequency bags path passes false to skip the redundant
-- external pass; other call sites are unaffected by the default.
function Overlay:RefreshAll(runExternal)
    for overlay in pairs(activeOverlays) do
        if overlay.updateFunc then
            local success, err = pcall(overlay.updateFunc, overlay)
            if not success then
                HA.Addon:Debug("Error updating overlay:", err)
            end
        end
    end

    if runExternal ~= false then
        self:RefreshExternalOverlays()
    end
end

-- Refresh addon-owned external bag UI overlays (Baganator, BetterBags, etc).
function Overlay:RefreshExternalOverlays()
    for key, refreshFunc in pairs(externalRefreshers) do
        local success, err = pcall(refreshFunc)
        if not success then
            HA.Addon:Debug("Error refreshing external overlays:", key, err)
        end
    end
end

-------------------------------------------------------------------------------
-- Frame Hooking Utilities
-------------------------------------------------------------------------------

-- Add overlay to a frame with a custom update function
function Overlay:AddToFrame(frame, updateFunc)
    if not frame then return nil end

    local overlay = self:CreateOverlay(frame, updateFunc)
    if overlay and updateFunc then
        updateFunc(overlay)
    end

    return overlay
end

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

-- Update overlay configuration
function Overlay:UpdateConfig()
    local db = HA.Addon and HA.Addon.db and HA.Addon.db.profile.overlay
    if not db then return end

    -- Update icon size for all active overlays
    for overlay in pairs(activeOverlays) do
        if overlay.icon then
            overlay.icon:SetSize(db.iconSize or OVERLAY_CONFIG.ICON_SIZE,
                                  db.iconSize or OVERLAY_CONFIG.ICON_SIZE)
        end
        if overlay.HomestoneState then
            local prev = overlay.HomestoneOptions
            self:SetHomestoneState(overlay, overlay.HomestoneState, {
                size    = db.iconSize or OVERLAY_CONFIG.ICON_SIZE,
                anchor  = db.iconAnchor or OVERLAY_CONFIG.DEFAULT_ANCHOR,
                offsetX = prev and prev.offsetX,
                offsetY = prev and prev.offsetY,
            })
        end
    end

    self:RefreshExternalOverlays()
end

-- Set icon position for an overlay
function Overlay:SetIconPosition(overlay, anchor)
    if not overlay or not overlay.icon then return end

    anchor = anchor or OVERLAY_CONFIG.DEFAULT_ANCHOR

    overlay.icon:ClearAllPoints()

    local offsetX = OVERLAY_CONFIG.OFFSET_X
    local offsetY = OVERLAY_CONFIG.OFFSET_Y

    -- Adjust offsets based on anchor
    if anchor == "TOPRIGHT" then
        offsetX = -offsetX
    elseif anchor == "BOTTOMLEFT" then
        offsetY = -offsetY
    elseif anchor == "BOTTOMRIGHT" then
        offsetX = -offsetX
        offsetY = -offsetY
    elseif anchor == "CENTER" then
        offsetX = 0
        offsetY = 0
    end

    overlay.icon:SetPoint(anchor, overlay, anchor, offsetX, offsetY)
    if overlay.HomestoneState then
        self:SetHomestoneState(overlay, overlay.HomestoneState, { anchor = anchor })
    end
end

-- Register an external refresher for addon-owned bag UIs
function Overlay:RegisterExternalRefresher(key, refreshFunc)
    if not key or type(refreshFunc) ~= "function" then return end
    externalRefreshers[key] = refreshFunc
end

-- Unregister a previously registered external refresher
function Overlay:UnregisterExternalRefresher(key)
    if not key then return end
    externalRefreshers[key] = nil
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

-- Overlay:Initialize() had zero call sites for a while, so its
-- RegisterCallback wiring never ran — now wired from core.lua's OnEnable
-- (guarded above against double registration if OnEnable is ever re-entered).
-- Ownership rule for what gets registered HERE: per-surface refreshes belong
-- to the surface modules that already own them (Overlay/Containers.lua owns
-- "bags", Overlay/Merchant.lua owns "merchant" — both were the wiring that
-- actually ran in production the whole time Initialize() was dead). Registering "bags"/
-- "merchant" here too would run a second, parallel full-pool sweep
-- (Overlay:RefreshAll walks the SAME activeOverlays that Containers'/
-- Merchant's own per-surface refresh already walks via their overlay
-- updateFuncs) — pure duplicate work, traced and confirmed when
-- Initialize() was wired in. Overlay:Initialize() therefore registers ONLY genuinely
-- cross-surface triggers: OWNERSHIP_UPDATED (no surface module owns "every
-- overlay, everywhere" repaint on an ownership change) and "all" (the one
-- RequestUpdate("all") requester is OWNERSHIP_UPDATED's own handler below,
-- which has no separate direct-call path — Core/core.lua's one direct
-- Overlay:RefreshAll() caller, HousingAddon:RefreshAllOverlays(), fires once
-- on PLAYER_ENTERING_WORLD, an unrelated one-time login trigger, not a
-- competing path to the same event).
function Overlay:Initialize()
    if isInitialized then return end
    isInitialized = true

    -- the "all" callback is the only path into Overlay:RefreshAll()
    -- that OWNERSHIP_UPDATED reaches (confirmed: no other RequestUpdate("all")
    -- or Fire("all") caller exists anywhere in the addon), so this is where
    -- the actual bag-overlay repaint work happens. Workload is overlayCount
    -- (the overlay-count local this file already tracks) — no new scan added to
    -- compute it.
    Events:RegisterCallback("all", function()
        HA.PerformanceTrace:Measure("bag_refresh", overlayCount, Overlay.RefreshAll, Overlay)
    end)

    -- Routed through RequestUpdate rather than calling RefreshAll directly:
    -- Events:Fire is synchronous, and a refresh can itself fire
    -- OWNERSHIP_UPDATED (e.g. IsOwnedFresh in write mode discovering new
    -- ownership mid-refresh), so a direct call would recurse inside the
    -- outer refresh. RequestUpdate defers to the next timer tick and
    -- coalesces repeat fires into one repaint via the "all" registration
    -- above — every trigger into RefreshAll here goes through exactly this
    -- one deferred, coalesced route.
    --
    -- measured separately from the "all" callback above (not
    -- nested — this handler only schedules the deferred repaint via
    -- RequestUpdate; the actual RefreshAll measurement above runs later, on
    -- its own timer pump). Workload is the update type it requests, already
    -- a literal in this line.
    Events:RegisterCallback("OWNERSHIP_UPDATED", function()
        HA.PerformanceTrace:Measure("ownership_update", "all", Events.RequestUpdate, Events, "all")
    end)

    HA.Addon:Debug("Overlay system initialized")
end
