--[[
    Homestead - PinFrameFactory
    Frame creation and color management for vendor map pins

    Extracted from VendorMapPins.lua to reduce file size.
    Creates vendor pins, badge pins, and minimap pin frames.
    Color/size helpers used by Options.lua for preview swatches.
]]

local _, HA = ...

local PinFrameFactory = {}
HA.PinFrameFactory = PinFrameFactory

-------------------------------------------------------------------------------
-- Pin Color Presets
-------------------------------------------------------------------------------

local PIN_COLOR_PRESETS = {
    default   = { 1.0, 1.0, 1.0 },   -- Natural atlas gold (no tint)
    green     = { 0.2, 1.0, 0.2 },   -- Bright Green
    blue      = { 0.3, 0.6, 1.0 },   -- Ice Blue
    lightblue = { 0.6, 0.85, 1.0 },  -- Light Blue
    purple    = { 0.7, 0.3, 1.0 },   -- Purple
    pink      = { 1.0, 0.4, 0.7 },   -- Pink
    red       = { 1.0, 0.2, 0.2 },   -- Red
    cyan      = { 0.2, 1.0, 1.0 },   -- Cyan
    white     = { 1.0, 1.0, 1.0 },   -- White (desaturated icon, no tint)
    yellow    = { 1.0, 0.9, 0.3 },   -- Yellow
}

-- Desaturated atlas base luminance (~82% grey). Used for Options preview swatch
-- when a custom color is active (desaturated icon tints accurately).
local DESAT_LUMINANCE = 0.82

-- Default minimap icon size (HandyNotes standard)
local MINIMAP_ICON_SIZE = 12

-------------------------------------------------------------------------------
-- Pin Color & Size Helpers
-------------------------------------------------------------------------------

function PinFrameFactory:GetPinColor()
    local db = HA.Addon and HA.Addon.db
    if not db then return 1, 1, 1 end
    local preset = db.profile.vendorTracer.pinColorPreset or "default"
    if preset == "custom" then
        local c = db.profile.vendorTracer.pinColorCustom
        return c and c.r or 1, c and c.g or 1, c and c.b or 1
    end
    local colors = PIN_COLOR_PRESETS[preset]
    if colors then return colors[1], colors[2], colors[3] end
    return 1, 1, 1
end

function PinFrameFactory:GetPinIconSize()
    local db = HA.Addon and HA.Addon.db
    if not db then return 20 end
    local size = db.profile.vendorTracer.pinIconSize or 20
    return math.max(12, math.min(32, size))
end

function PinFrameFactory:GetMinimapIconSize()
    local db = HA.Addon and HA.Addon.db
    if not db then return MINIMAP_ICON_SIZE end
    return db.profile.vendorTracer.minimapIconSize or MINIMAP_ICON_SIZE
end

function PinFrameFactory:IsCustomPinColor()
    local db = HA.Addon and HA.Addon.db
    if not db then return false end
    local preset = db.profile.vendorTracer.pinColorPreset or "default"
    return preset ~= "default"
end

function PinFrameFactory:GetPinColorPreviewHex()
    local r, g, b = self:GetPinColor()
    if self:IsCustomPinColor() then
        local cr = math.min(r * DESAT_LUMINANCE, 1.0)
        local cg = math.min(g * DESAT_LUMINANCE, 1.0)
        local cb = math.min(b * DESAT_LUMINANCE, 1.0)
        return string.format("%02x%02x%02x", cr * 255, cg * 255, cb * 255)
    end
    return "f2d173"
end

-------------------------------------------------------------------------------
-- Frame Creation Helpers
-------------------------------------------------------------------------------

local function CreateCircularBackplate(frame, size)
    local backplate = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    backplate:SetPoint("CENTER")
    backplate:SetSize(size, size)
    backplate:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    backplate:SetBlendMode("BLEND")
    return backplate
end

-------------------------------------------------------------------------------
-- Vendor Pin Frame (zone-level individual vendor pins)
-------------------------------------------------------------------------------

function PinFrameFactory:CreateVendorPinFrame(vendor, isOppositeFaction, isUnverified)
    local frame = CreateFrame("Frame", nil, UIParent)

    local baseSize = self:GetPinIconSize()
    frame:SetSize(baseSize, baseSize)
    frame:EnableMouse(true)

    local br, bg, bb = self:GetPinColor()
    local isCustomColor = self:IsCustomPinColor()

    -- Dark circular background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetPoint("CENTER")
    frame.bg:SetSize(baseSize + 4, baseSize + 4)
    frame.bg:SetAtlas("auctionhouse-itemicon-border-white", false)
    frame.bg:SetVertexColor(0.1, 0.08, 0.02, 1)

    -- Colored backplate for depth (only for non-default)
    if isCustomColor then
        frame.backplate = CreateCircularBackplate(frame, baseSize + 2)
        if isUnverified then
            frame.backplate:SetVertexColor(0.3, 0.18, 0.06, 0.5)
        elseif isOppositeFaction then
            frame.backplate:SetVertexColor(0.15, 0.15, 0.15, 0.4)
        else
            frame.backplate:SetVertexColor(br * 0.3, bg * 0.3, bb * 0.3, 0.5)
        end
    end

    -- Ring border
    frame.ring = frame:CreateTexture(nil, "BORDER")
    frame.ring:SetPoint("CENTER")
    frame.ring:SetSize(baseSize + 4, baseSize + 4)
    frame.ring:SetAtlas("auctionhouse-itemicon-border-artifact", false)
    if isUnverified then
        frame.ring:SetVertexColor(0.7, 0.42, 0.14, 0.7)
    elseif isOppositeFaction then
        if isCustomColor then
            frame.ring:SetVertexColor(br * 0.35, bg * 0.35, bb * 0.35, 0.6)
        else
            frame.ring:SetVertexColor(0.35, 0.35, 0.35, 0.6)
        end
    elseif isCustomColor then
        frame.ring:SetVertexColor(br * 0.7, bg * 0.7, bb * 0.7, 0.7)
    end

    -- Housing icon
    local iconSize = baseSize
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("CENTER")
    frame.icon:SetSize(iconSize, iconSize)
    frame.icon:SetAtlas("housing-decor-vendor_32", false)
    if isUnverified then
        frame.icon:SetVertexColor(1.0, 0.6, 0.2, 0.9)
    elseif isOppositeFaction then
        frame.icon:SetDesaturated(true)
        frame.icon:SetVertexColor(0.6, 0.6, 0.6, 0.9)
    elseif isCustomColor then
        frame.icon:SetDesaturated(true)
        frame.icon:SetVertexColor(br, bg, bb, 0.95)
    end

    -- Question mark for unverified vendors
    if isUnverified then
        frame.unverifiedIcon = frame:CreateTexture(nil, "OVERLAY", nil, 3)
        frame.unverifiedIcon:SetSize(10, 10)
        frame.unverifiedIcon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
        frame.unverifiedIcon:SetAtlas("QuestRepeatableTurnin", true)
    end

    -- Faction emblem for opposite faction vendors
    if isOppositeFaction and vendor.faction then
        frame.factionEmblem = frame:CreateTexture(nil, "ARTWORK", nil, 2)
        frame.factionEmblem:SetSize(10, 10)
        frame.factionEmblem:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, 3)

        if vendor.faction == "Alliance" then
            frame.factionEmblem:SetAtlas("ui-frame-alliancecrest-portrait", true)
        elseif vendor.faction == "Horde" then
            frame.factionEmblem:SetAtlas("ui-frame-hordecrest-portrait", true)
        end
    end

    -- Collection ratio text (e.g., "3/12")
    local showCounts = HA.Addon and HA.Addon.db and HA.Addon.db.profile.vendorTracer.showPinCounts ~= false
    local collected, total = 0, 0
    if showCounts and HA.VendorMapPins then
        collected, total = HA.VendorMapPins:GetVendorCollectionCounts(vendor)
    end
    if total > 0 then
        local fontSize = math.max(8, math.floor(baseSize * 0.4))
        frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal", 2)
        frame.count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)
        local fontPath = frame.count:GetFont()
        frame.count:SetFont(fontPath, fontSize, "OUTLINE")
        frame.count:SetShadowColor(0, 0, 0, 0.8)
        frame.count:SetShadowOffset(1, -1)
        frame.count:SetText(collected .. "/" .. total)
        if collected == total then
            frame.count:SetTextColor(0.2, 1, 0.2)
        elseif collected > 0 then
            frame.count:SetTextColor(1, 1, 1)
        else
            frame.count:SetTextColor(1, 0.2, 0.2)
        end
    end

    -- Store vendor data and status
    frame.vendor = vendor
    frame.isOppositeFaction = isOppositeFaction
    frame.isUnverified = isUnverified

    -- Tooltip/click handlers (delegate to VendorMapPins at runtime)
    frame:SetScript("OnEnter", function(self) -- luacheck: ignore 432
        if HA.VendorMapPins then
            HA.VendorMapPins:ShowVendorTooltip(self, self.vendor)
        end
    end)
    frame:SetScript("OnLeave", function(self) -- luacheck: ignore 432
        if HA.VendorMapPins then
            HA.VendorMapPins:OnPinLeave()
        end
        GameTooltip:Hide()
    end)
    frame:SetScript("OnMouseUp", function(self, button) -- luacheck: ignore 432
        if button == "LeftButton" and HA.VendorMapPins then
            HA.VendorMapPins:SetWaypointToVendor(self.vendor)
        end
    end)

    return frame
end

-------------------------------------------------------------------------------
-- Badge Pin Frame (continent/world-level zone summary pins)
-------------------------------------------------------------------------------

function PinFrameFactory:CreateBadgePinFrame(badgeData)
    local frame = CreateFrame("Frame", nil, UIParent)

    local baseSize = self:GetPinIconSize()
    frame:SetSize(baseSize, baseSize)
    frame:EnableMouse(true)

    local isOppositeFactionOnly = badgeData.oppositeFactionCount and badgeData.oppositeFactionCount > 0
        and badgeData.oppositeFactionCount == badgeData.vendorCount

    local br, bg, bb = self:GetPinColor()
    local isCustomColor = self:IsCustomPinColor()

    -- Dark circular background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetPoint("CENTER")
    frame.bg:SetSize(baseSize + 4, baseSize + 4)
    frame.bg:SetAtlas("auctionhouse-itemicon-border-white", false)
    frame.bg:SetVertexColor(0.1, 0.08, 0.02, 1)

    -- Colored backplate for depth (only for non-default)
    if isCustomColor then
        frame.backplate = CreateCircularBackplate(frame, baseSize + 2)
        if isOppositeFactionOnly then
            frame.backplate:SetVertexColor(0.15, 0.15, 0.15, 0.4)
        else
            frame.backplate:SetVertexColor(br * 0.3, bg * 0.3, bb * 0.3, 0.5)
        end
    end

    -- Ring border
    frame.ring = frame:CreateTexture(nil, "BORDER")
    frame.ring:SetPoint("CENTER")
    frame.ring:SetSize(baseSize + 4, baseSize + 4)
    frame.ring:SetAtlas("auctionhouse-itemicon-border-artifact", false)
    if isOppositeFactionOnly then
        if isCustomColor then
            frame.ring:SetVertexColor(br * 0.35, bg * 0.35, bb * 0.35, 0.6)
        else
            frame.ring:SetVertexColor(0.35, 0.35, 0.35, 0.6)
        end
    elseif isCustomColor then
        frame.ring:SetVertexColor(br * 0.7, bg * 0.7, bb * 0.7, 0.7)
    end

    -- Housing icon
    local iconSize = baseSize
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("CENTER")
    frame.icon:SetSize(iconSize, iconSize)
    frame.icon:SetAtlas("housing-decor-vendor_32", false)
    if isOppositeFactionOnly then
        frame.icon:SetDesaturated(true)
        frame.icon:SetVertexColor(0.6, 0.6, 0.6, 0.9)
    elseif isCustomColor then
        frame.icon:SetDesaturated(true)
        frame.icon:SetVertexColor(br, bg, bb, 0.95)
    end

    -- Faction emblem
    if badgeData.dominantFaction or (badgeData.oppositeFactionCount and badgeData.oppositeFactionCount > 0) then
        frame.factionEmblem = frame:CreateTexture(nil, "ARTWORK", nil, 2)
        frame.factionEmblem:SetSize(10, 10)
        frame.factionEmblem:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)

        local factionToShow = badgeData.dominantFaction
        if not factionToShow then
            local playerFaction = UnitFactionGroup("player")
            factionToShow = playerFaction == "Alliance" and "Horde" or "Alliance"
        end

        if factionToShow == "Alliance" then
            frame.factionEmblem:SetAtlas("ui-frame-alliancecrest-portrait", true)
        elseif factionToShow == "Horde" then
            frame.factionEmblem:SetAtlas("ui-frame-hordecrest-portrait", true)
        else
            frame.factionEmblem:Hide()
        end
    end

    -- Count text
    local fontSize = math.max(8, math.floor(baseSize * 0.4))
    frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal", 2)
    frame.count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)
    local fontPath = frame.count:GetFont()
    frame.count:SetFont(fontPath, fontSize, "OUTLINE")
    frame.count:SetShadowColor(0, 0, 0, 0.8)
    frame.count:SetShadowOffset(1, -1)

    -- Store badge data
    frame.badgeData = badgeData

    -- Update appearance
    frame.count:SetText(tostring(badgeData.vendorCount or 0))
    if isOppositeFactionOnly then
        local factionColor = badgeData.dominantFaction == "Alliance" and {0.2, 0.4, 0.8} or {0.8, 0.2, 0.2}
        frame.count:SetTextColor(factionColor[1], factionColor[2], factionColor[3])
    elseif (badgeData.uncollectedCount or 0) == 0 then
        frame.count:SetTextColor(0.2, 1, 0.2)
    elseif badgeData.uncollectedCount < badgeData.vendorCount then
        frame.count:SetTextColor(1, 1, 1)
    else
        frame.count:SetTextColor(1, 0.2, 0.2)
    end

    -- Tooltip/click handlers
    frame:SetScript("OnEnter", function(self) -- luacheck: ignore 432
        if HA.VendorMapPins then
            HA.VendorMapPins:ShowZoneBadgeTooltip(self, self.badgeData)
        end
    end)
    frame:SetScript("OnLeave", function(self) -- luacheck: ignore 432
        GameTooltip:Hide()
    end)
    frame:SetScript("OnMouseUp", function(self, button) -- luacheck: ignore 432
        if button == "LeftButton" and self.badgeData and self.badgeData.mapID then
            WorldMapFrame:SetMapID(self.badgeData.mapID)
        end
    end)

    return frame
end

-------------------------------------------------------------------------------
-- Portal Badge Pin Frame (Order Hall entrance markers)
-------------------------------------------------------------------------------

-- Creates a portal badge pin for an Order Hall entrance in Dalaran.
-- portalData: { vendor = <vendor table> }
-- Pin is placed at vendor.portal.{mapID,x,y}; click navigates to vendor.mapID.
function PinFrameFactory:CreatePortalBadgePinFrame(portalData)
    local baseSize = self:GetPinIconSize()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(baseSize, baseSize)
    frame:EnableMouse(true)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetAtlas("auctionhouse-itemicon-border-white", false)
    bg:SetVertexColor(0.45, 0.2, 0.9, 0.85)  -- purple, distinct from vendor pins

    local ring = frame:CreateTexture(nil, "OVERLAY")
    ring:SetAllPoints()
    ring:SetAtlas("auctionhouse-itemicon-border-artifact", false)
    ring:SetVertexColor(0.6, 0.3, 1.0)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(baseSize * 0.65, baseSize * 0.65)
    icon:SetPoint("CENTER")
    icon:SetAtlas("housing-decor-vendor_32", false)
    icon:SetVertexColor(0.85, 0.65, 1.0)

    frame.portalData = portalData

    frame:SetScript("OnMouseUp", function(self, button) -- luacheck: ignore 432
        if button == "LeftButton" then
            local vendor = self.portalData and self.portalData.vendor
            if vendor and vendor.mapID then
                WorldMapFrame:SetMapID(vendor.mapID)
            end
        end
    end)

    frame:SetScript("OnEnter", function(self) -- luacheck: ignore 432
        local vendor = self.portalData and self.portalData.vendor
        if not vendor then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(vendor.name, 1, 1, 1)
        GameTooltip:AddLine("Order Hall Portal", 0.7, 0.5, 1.0)
        if vendor.notes then
            GameTooltip:AddLine(vendor.notes, 1, 0.82, 0, true)
        end
        GameTooltip:AddLine("Click to view vendor location", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function() -- luacheck: ignore 432
        GameTooltip:Hide()
    end)

    return frame
end

-------------------------------------------------------------------------------
-- Minimap Pin Frame
-------------------------------------------------------------------------------

function PinFrameFactory:CreateMinimapPinFrame(vendor, isOppositeFaction, isUnverified, elevation)
    local frame = CreateFrame("Frame", nil, UIParent)

    local mmSize = self:GetMinimapIconSize()
    frame:SetSize(mmSize, mmSize)
    frame:EnableMouse(true)

    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(1)

    local br, bg, bb = self:GetPinColor()
    local isCustomColor = self:IsCustomPinColor()

    -- Colored backplate behind icon (only for non-default)
    if isCustomColor then
        frame.backplate = CreateCircularBackplate(frame, mmSize + 2)
        if isUnverified then
            frame.backplate:SetVertexColor(1.0, 0.6, 0.2, 0.9)
        elseif isOppositeFaction then
            frame.backplate:SetVertexColor(br * 0.5, bg * 0.5, bb * 0.5, 0.9)
        else
            frame.backplate:SetVertexColor(br, bg, bb, 0.9)
        end
    end

    -- Housing icon
    local iconSize = isCustomColor and (mmSize - 2) or mmSize
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("CENTER")
    frame.icon:SetSize(iconSize, iconSize)
    frame.icon:SetAtlas("housing-decor-vendor_32", false)
    if isUnverified then
        frame.icon:SetVertexColor(1.0, 0.6, 0.2, 0.9)
    elseif isOppositeFaction then
        frame.icon:SetDesaturated(true)
        frame.icon:SetVertexColor(0.6, 0.6, 0.6, 0.9)
    elseif isCustomColor then
        frame.icon:SetDesaturated(true)
        frame.icon:SetVertexColor(br, bg, bb, 0.95)
    end

    -- Elevation arrow for cross-floor vendors
    if elevation then
        frame.elevation = elevation
        local arrowDim = math.max(math.floor(mmSize * 1.75), 20)
        local arrow = frame:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(arrowDim, arrowDim)
        arrow:SetAtlas("Rotating-MinimapGuideArrow")
        arrow:SetDesaturated(true)
        if isCustomColor then
            arrow:SetVertexColor(br, bg, bb, 1.0)
        else
            arrow:SetVertexColor(1, 0.82, 0, 1.0)
        end
        if elevation == "above" then
            arrow:SetPoint("CENTER", frame, "TOP", 0, 3)
        else
            arrow:SetTexCoord(0, 1, 1, 0)
            arrow:SetPoint("CENTER", frame, "BOTTOM", 0, -3)
        end
        frame.elevationArrow = arrow
    end

    -- Store vendor data
    frame.vendor = vendor
    frame.isOppositeFaction = isOppositeFaction
    frame.isUnverified = isUnverified

    -- Simple tooltip on hover
    frame:SetScript("OnEnter", function(self) -- luacheck: ignore 432
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(self.vendor.name, 1, 1, 1)
        if self.vendor.zone then
            GameTooltip:AddLine(self.vendor.zone, 0.7, 0.7, 0.7)
        end
        if self.isUnverified then
            GameTooltip:AddLine("Unverified location", 1.0, 0.6, 0.2)
        end
        if self.isOppositeFaction then
            GameTooltip:AddLine("Opposite faction", 0.8, 0.3, 0.3)
        end
        if self.elevation == "above" then
            GameTooltip:AddLine("|A:Rotating-MinimapGuideArrow:0:0|a Above you", 0.6, 0.8, 1.0)
        elseif self.elevation == "below" then
            GameTooltip:AddLine("v Below you", 0.6, 0.8, 1.0)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self) -- luacheck: ignore 432
        GameTooltip:Hide()
    end)

    return frame
end
