--[[
    Homestead - Overlay System
    Core framework for displaying collection status icons on item frames

    IMPORTANT: This is an original implementation built from scratch.
    It does not copy or derive from any other addon's overlay system.
]]

local _, HA = ...

-- Create Overlay module
local Overlay = {}
HA.Overlay = Overlay

-- Local references
local Constants = HA.Constants
local Events = HA.Events
local DecorTracker = HA.DecorTracker

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

    -- Try to get from pool
    local overlay = table.remove(overlayPool)

    if not overlay then
        -- Create new overlay frame
        overlayCount = overlayCount + 1

        -- Use unnamed frames/textures to avoid polluting the global namespace.
        overlay = CreateFrame("Frame", nil, parentFrame)
        overlay:SetFrameStrata(OVERLAY_CONFIG.STRATA)

        -- Create icon texture
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
    overlay.icon:SetTexture(nil)
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

-- Set the icon on an overlay based on item status
function Overlay:SetIcon(overlay, itemLink)
    if not overlay or not overlay.icon then return end

    -- Check if overlays are enabled
    if not HA.Addon or not HA.Addon.db or not HA.Addon.db.profile.overlay.enabled then
        overlay.icon:Hide()
        return
    end

    -- Check if item is a decor item
    if not DecorTracker then
        overlay.icon:Hide()
        return
    end

    if not itemLink then
        overlay.icon:Hide()
        return
    end

    -- Check if this is a decor item
    if not DecorTracker:IsDecorItem(itemLink) then
        overlay.icon:Hide()
        return
    end

    -- Get status icon
    local iconTexture = DecorTracker:GetStatusIcon(itemLink)
    if not iconTexture then
        overlay.icon:Hide()
        return
    end

    -- Set the icon texture
    overlay.icon:SetTexture(iconTexture)
    overlay.icon:Show()

    -- Apply color tint if needed
    local color = DecorTracker:GetStatusColor(itemLink)
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
        -- Initial update
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
