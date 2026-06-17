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
local CatalogStore = HA.CatalogStore
local SourceManager = HA.SourceManager

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

-- Track all created overlays
local activeOverlays = {}
local overlayPool = {}
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

    local overlay = table.remove(overlayPool)

    if not overlay then
        -- Create new overlay frame
        overlayCount = overlayCount + 1

        -- Use unnamed frames/textures to avoid polluting the global namespace.
        overlay = CreateFrame("Frame", nil, parentFrame)
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

        -- Store update function reference
        overlay.updateFunc = nil
    end

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

-- Release an overlay back to the pool
function Overlay:ReleaseOverlay(overlay)
    if not overlay then return end

    -- Hide and clear
    overlay:Hide()
    overlay:ClearAllPoints()
    self:ClearIcon(overlay)
    overlay.updateFunc = nil

    -- Remove from parent
    if overlay:GetParent() then
        overlay:GetParent().HousingAddonOverlay = nil
    end

    -- Remove from active tracking
    activeOverlays[overlay] = nil

    -- Return to pool
    table.insert(overlayPool, overlay)
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
    opts = opts or {}

    local size = opts.size or (settings and settings.iconSize) or OVERLAY_CONFIG.ICON_SIZE
    local anchor = opts.anchor or (settings and settings.iconAnchor) or OVERLAY_CONFIG.DEFAULT_ANCHOR
    local offsetX, offsetY = GetAnchorOffsets(anchor, opts.offsetX, opts.offsetY)

    parent.HomestoneState = state
    parent.HomestoneOptions = {
        size = size,
        anchor = anchor,
        offsetX = opts.offsetX,
        offsetY = opts.offsetY,
    }

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

-- Set the icon on an overlay based on item status
function Overlay:SetIcon(overlay, itemLink)
    if not overlay or not overlay.icon then return end

    -- Check if overlays are enabled
    if not HA.Addon or not HA.Addon.db or not HA.Addon.db.profile.overlay.enabled then
        overlay.icon:Hide()
        self:ClearHomestoneTextures(overlay)
        return
    end

    -- Check if item is a decor item
    if not CatalogStore or not SourceManager then
        overlay.icon:Hide()
        self:ClearHomestoneTextures(overlay)
        return
    end

    if not itemLink then
        overlay.icon:Hide()
        self:ClearHomestoneTextures(overlay)
        return
    end

    -- Check if this is a decor item
    local itemID = C_Item.GetItemInfoInstant(itemLink)
    if not itemID or not CatalogStore:IsDecorItem(itemLink) then
        overlay.icon:Hide()
        self:ClearHomestoneTextures(overlay)
        return
    end

    -- Get status icon
    local iconTexture = SourceManager:GetItemStatusIcon(itemID)
    if not iconTexture then
        overlay.icon:Hide()
        self:ClearHomestoneTextures(overlay)
        return
    end

    self:ClearHomestoneTextures(overlay)

    -- Set the icon texture
    overlay.icon:SetTexture(iconTexture)
    overlay.icon:Show()

    -- Apply color tint if needed
    local color = SourceManager:GetItemStatusColor(itemID)
    if color then
        overlay.icon:SetVertexColor(color.r, color.g, color.b, color.a or 1)
    else
        overlay.icon:SetVertexColor(1, 1, 1, 1)
    end
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

-- Refresh all active overlays
function Overlay:RefreshAll()
    for overlay in pairs(activeOverlays) do
        if overlay.updateFunc then
            local success, err = pcall(overlay.updateFunc, overlay)
            if not success then
                HA.Addon:Debug("Error updating overlay:", err)
            end
        end
    end

    for key, refreshFunc in pairs(externalRefreshers) do
        local success, err = pcall(refreshFunc)
        if not success then
            HA.Addon:Debug("Error refreshing external overlays:", key, err)
        end
    end
end

-- Update a single overlay
function Overlay:UpdateOverlay(overlay, itemLink)
    if not overlay then return end
    self:SetIcon(overlay, itemLink)
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

-- Remove overlay from a frame
function Overlay:RemoveFromFrame(frame)
    if not frame then return end

    local overlay = frame.HousingAddonOverlay
    if overlay then
        self:ReleaseOverlay(overlay)
    end
end

-- Hook a frame's OnShow to add overlay
function Overlay:HookFrameOnShow(frame, getItemLinkFunc)
    if not frame or frame.HousingAddonHooked then return end

    frame:HookScript("OnShow", function(self) -- luacheck: ignore 432
        Overlay:AddToFrame(self, function(o)
            local itemLink = getItemLinkFunc(self)
            Overlay:SetIcon(o, itemLink)
        end)
    end)

    frame.HousingAddonHooked = true
end

-- Hook a frame's OnHide to release overlay
function Overlay:HookFrameOnHide(frame)
    if not frame or frame.HousingAddonOnHideHooked then return end

    frame:HookScript("OnHide", function(self) -- luacheck: ignore 432
        Overlay:RemoveFromFrame(self)
    end)

    frame.HousingAddonOnHideHooked = true
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

    for key, refreshFunc in pairs(externalRefreshers) do
        local success, err = pcall(refreshFunc)
        if not success then
            HA.Addon:Debug("Error refreshing external overlays:", key, err)
        end
    end
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

function Overlay:Initialize()
    -- Register for update callbacks
    Events:RegisterCallback("bags", function()
        Overlay:RefreshAll()
    end)

    Events:RegisterCallback("merchant", function()
        Overlay:RefreshAll()
    end)

    Events:RegisterCallback("all", function()
        Overlay:RefreshAll()
    end)

    HA.Addon:Debug("Overlay system initialized")
end

-------------------------------------------------------------------------------
-- Statistics
-------------------------------------------------------------------------------

function Overlay:GetStats()
    local activeCount = 0
    for _ in pairs(activeOverlays) do
        activeCount = activeCount + 1
    end

    return {
        active = activeCount,
        pooled = #overlayPool,
        total = overlayCount,
    }
end
