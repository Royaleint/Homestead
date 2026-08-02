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

-- Alpha applied when vertex-tinting a desaturated vendor pin atlas.
-- Exposed as a module-level constant so the Options preview widget can match
-- the in-game render exactly (single source of truth for the tint alpha).
PinFrameFactory.DESAT_ALPHA = 0.95

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
    if not db then return 10 end
    local size = db.profile.vendorTracer.pinIconSize or 10
    return math.max(8, math.min(18, size))
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

local function GetWorldPinVisualSizes(baseSize)
    -- The world-map wrapper uses a counter-scale tied to effective scale,
    -- which can reduce apparent size at high resolutions. Compensate by
    -- sizing the frame and icon relative to the UIParent effective scale
    -- so the slider value matches perceived on-screen size.
    local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local scaleCompensation = (uiScale > 0) and (1 / uiScale) or 1
    local adjustedSize = math.floor((baseSize * scaleCompensation) + 0.5)
    local iconSize = math.floor((adjustedSize * 1.15) + 0.5)
    return adjustedSize, 0, iconSize
end

local function GetVendorCountTextMetrics(baseSize)
    local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local scaleCompensation = (uiScale > 0) and (1 / uiScale) or 1
    local adjusted = baseSize * scaleCompensation
    local fontSize = math.max(8, math.floor(adjusted * 0.50))
    local offset = math.max(2, math.floor(adjusted * 0.18))
    return fontSize, offset
end

local function GetBadgeCountTextMetrics(baseSize)
    local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local scaleCompensation = (uiScale > 0) and (1 / uiScale) or 1
    local adjusted = baseSize * scaleCompensation
    local fontSize = math.max(8, math.floor(adjusted * 0.46))
    local offset = math.max(1, math.floor(adjusted * 0.12))
    return fontSize, offset
end

-------------------------------------------------------------------------------
-- Vendor Pin Frame (zone-level individual vendor pins)
-------------------------------------------------------------------------------

function PinFrameFactory:CreateVendorPinFrame(vendor, isOppositeFaction)
    local frame = CreateFrame("Frame", nil, UIParent)

    local baseSize = self:GetPinIconSize()
    local _, _, iconSize = GetWorldPinVisualSizes(baseSize)
    frame:SetSize(baseSize, baseSize)
    frame:EnableMouse(true)

    local br, bg, bb = self:GetPinColor()
    local isCustomColor = self:IsCustomPinColor()

    -- Housing icon
    -- HS-158/160 §5: profession-shop vendors get a distinct pin treatment.
    -- No confirmed compact (32px map-pin-sized) "profession sign" atlas was
    -- found in the local Blizzard UI source checkout (Blizzard_Professions
    -- atlases are all large-panel textures, not pin icons) — shipping an
    -- unverified atlas string risks a silently blank icon. Default: reuse
    -- the housing-vendor atlas with a gold/amber tint (guaranteed to render).
    -- CANDIDATE ATLASES for Rawb's Gate 2 visual pass (UNVERIFIED — none
    -- confirmed to exist; probe in-game first with e.g.
    -- /run print(C_Texture.GetAtlasInfo("professions-icon-crafting") ~= nil)
    -- for each candidate before wiring one in):
    --   "professions-icon-crafting"
    --   "poi-traveldeliveries-icon"
    --   "worldquest-icon-profession"
    local isProfessionShop = vendor and vendor.vendorType == "professionShop"

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("CENTER")
    frame.icon:SetSize(iconSize, iconSize)
    frame.icon:SetAtlas("housing-decor-vendor_32", false)
    if isOppositeFaction then
        frame.icon:SetDesaturated(true)
        frame.icon:SetVertexColor(0.6, 0.6, 0.6, 0.9)
    elseif isCustomColor then
        frame.icon:SetDesaturated(true)
        frame.icon:SetVertexColor(br, bg, bb, PinFrameFactory.DESAT_ALPHA)
    elseif isProfessionShop then
        frame.icon:SetDesaturated(true)
        frame.icon:SetVertexColor(1.0, 0.82, 0.0, 1.0)
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

    self:RefreshVendorPinCount(frame, vendor)

    -- Store vendor data and status
    frame.vendor = vendor
    frame.isOppositeFaction = isOppositeFaction

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
    end)
    frame:SetScript("OnMouseUp", function(self, button) -- luacheck: ignore 432
        if button == "LeftButton" and HA.VendorMapPins then
            HA.VendorMapPins:SetWaypointToVendor(self.vendor)
        end
    end)

    return frame
end

-------------------------------------------------------------------------------
-- HS-018: Source-typed pin factory
--
-- Dispatch entry for the pin source provider registry. Returns a frame for a
-- pin record of the given source type. Commit 2 wires the "vendor" path
-- (delegates to CreateVendorPinFrame) and stubs "drop" (filled in by commit 3).
-- Future source types (profession, quest, achievement, shop) plug in here
-- without modifying the registry iterator in VendorMapPins.
-------------------------------------------------------------------------------

function PinFrameFactory:CreateSourcePinFrame(sourceType, record)
    if not record then return nil end

    if sourceType == "vendor" then
        return self:CreateVendorPinFrame(record.vendor, record.isOppositeFaction)
    elseif sourceType == "drop" then
        return self:CreateDropPinFrame(record)
    end

    -- Other source types (profession, quest, achievement, shop) are reserved
    -- registry slots awaiting their own tickets.
    return nil
end

-------------------------------------------------------------------------------
-- HS-018: Drop Pin Frame
--
-- Visually distinct from vendor pins so filter = "Drop" reads at a glance.
-- Same base size as vendor pins for consistency. Click does nothing (no
-- waypoint target for a mob drop); hover surfaces mob/zone/notes via
-- VendorMapPins:ShowDropPinTooltip.
-------------------------------------------------------------------------------

function PinFrameFactory:CreateDropPinFrame(record)
    local frame = CreateFrame("Frame", nil, UIParent)

    local baseSize = self:GetPinIconSize()
    local _, _, iconSize = GetWorldPinVisualSizes(baseSize)
    frame:SetSize(baseSize, baseSize)
    frame:EnableMouse(true)

    -- Homestead decor-drop art: housing vendor bag with a dungeon skull.
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("CENTER")
    frame.icon:SetSize(iconSize, iconSize)
    frame.icon:SetTexture(HA.Constants.TEXTURE_ROOT .. "HomesteadDropIcon_32")

    frame.record = record

    frame:SetScript("OnEnter", function(self) -- luacheck: ignore 432
        if HA.VendorMapPins then
            HA.VendorMapPins:ShowDropPinTooltip(self, self.record)
        end
    end)
    frame:SetScript("OnLeave", function() -- luacheck: ignore 432
        if HA.VendorMapPins then
            HA.VendorMapPins:OnPinLeave()
        end
    end)

    self:RefreshDropPinCount(frame, record)

    return frame
end

-- Refreshes vendor count text on an existing vendor pin frame.
-- Used by frame pooling so reused frames always show current collection counts.
function PinFrameFactory:RefreshVendorPinCount(frame, vendor)
    if not frame then return end

    local showCounts = HA.Addon and HA.Addon.db and HA.Addon.db.profile.vendorTracer.showPinCounts ~= false
    if not showCounts then
        if frame.count then
            frame.count:Hide()
        end
        return
    end

    local stats
    if vendor and HA.VendorMapPins and HA.VendorMapPins.GetVendorStats then
        -- HS-018: respect the active source filter so pin counts match the
        -- side-panel filter. Defensive fallback to "all" if MapSidePanel isn't
        -- loaded yet (early init order).
        local sourceFilter = "all"
        if HA.MapSidePanel and HA.MapSidePanel.GetSourceFilter then
            sourceFilter = HA.MapSidePanel:GetSourceFilter() or "all"
        end
        stats = HA.VendorMapPins:GetVendorStats(vendor, sourceFilter)
    end
    if not stats or (stats.total or 0) <= 0 then
        if frame.count then
            frame.count:Hide()
        end
        return
    end

    local baseSize = frame:GetWidth() or self:GetPinIconSize()
    local fontSize = GetVendorCountTextMetrics(baseSize)

    if not frame.count then
        frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal", 2)
        frame.count:SetDrawLayer("OVERLAY", 7)
        frame.count:SetShadowColor(0, 0, 0, 0)
        frame.count:SetShadowOffset(0, 0)
    end

    frame.count:ClearAllPoints()
    frame.count:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    local fontPath = frame.count:GetFont()
    frame.count:SetFont(fontPath, fontSize, "OUTLINE")
    local BC = HA.BadgeCalculation
    frame.count:SetText(BC and BC.FormatCountText(stats.collected, stats.total, stats.locked) or "")
    -- Use white as base color; inline escapes handle segment coloring.
    frame.count:SetTextColor(1, 1, 1)
    frame.count:Show()
end

-- HS-229: refreshes the collected/total counter on a drop pin frame, mirroring
-- RefreshVendorPinCount so the two pin families read identically. `record` is
-- the sourcePins entry (record.records is the pin's grouped {itemID, drop}
-- list — one entry for a legacy/enc pin, several for a multi-boss ent pin).
-- Used both at frame creation and by frame pooling so reused frames always
-- show current counts.
function PinFrameFactory:RefreshDropPinCount(frame, record)
    if not frame then return end

    local showCounts = HA.Addon and HA.Addon.db and HA.Addon.db.profile.vendorTracer.showPinCounts ~= false
    if not showCounts then
        if frame.count then
            frame.count:Hide()
        end
        return
    end

    local BC = HA.BadgeCalculation
    local stats = BC and record and record.records and BC:GetDropGroupStats(record.records)
    if not stats or (stats.total or 0) <= 0 then
        if frame.count then
            frame.count:Hide()
        end
        return
    end

    local baseSize = frame:GetWidth() or self:GetPinIconSize()
    local fontSize = GetVendorCountTextMetrics(baseSize)

    if not frame.count then
        frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal", 2)
        frame.count:SetDrawLayer("OVERLAY", 7)
        frame.count:SetShadowColor(0, 0, 0, 0)
        frame.count:SetShadowOffset(0, 0)
    end

    frame.count:ClearAllPoints()
    frame.count:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    local fontPath = frame.count:GetFont()
    frame.count:SetFont(fontPath, fontSize, "OUTLINE")
    frame.count:SetText(BC.FormatCountText(stats.collected, stats.total, stats.locked))
    frame.count:SetTextColor(1, 1, 1)
    frame.count:Show()
end

-------------------------------------------------------------------------------
-- Badge Pin Frame (continent/world-level zone summary pins)
-------------------------------------------------------------------------------

-- HS-222: single source of truth for the count-driven badge visuals (icon
-- tint, count text/color). Called both by CreateBadgePinFrame below (fresh
-- frame) and by HomesteadWorldMapProvider.lua's AcquireBadgeFrame after every
-- pool acquire (reused frame) — the world-map badge pool key deliberately
-- drops the raw vendor/uncollected/opposite-faction counts (they used to
-- mint a permanent pool bucket per distinct combination), so two badges
-- sharing a pool key can still have different counts and therefore a
-- different isOppositeFactionOnly verdict. A reused frame's PREVIOUS
-- tint/color must be explicitly reset here, not just re-applied when a
-- condition matches, or a frame last shown desaturated/red would stay that
-- way forever once recycled into a bucket that no longer produces that
-- state. Mirrors RefreshVendorPinCount's role for vendor pins (HS-208).
function PinFrameFactory:RefreshBadgePinVisuals(frame, badgeData)
    if not frame or not badgeData then return end

    local isOppositeFactionOnly = badgeData.oppositeFactionCount and badgeData.oppositeFactionCount > 0
        and badgeData.oppositeFactionCount == badgeData.vendorCount

    local br, bg, bb = self:GetPinColor()
    local isCustomColor = self:IsCustomPinColor()

    if frame.icon then
        if isOppositeFactionOnly then
            frame.icon:SetDesaturated(true)
            frame.icon:SetVertexColor(0.6, 0.6, 0.6, 0.9)
        elseif isCustomColor then
            frame.icon:SetDesaturated(true)
            frame.icon:SetVertexColor(br, bg, bb, PinFrameFactory.DESAT_ALPHA)
        else
            frame.icon:SetDesaturated(false)
            frame.icon:SetVertexColor(1, 1, 1, 1)
        end
    end

    if frame.count then
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
    end
end

function PinFrameFactory:CreateBadgePinFrame(badgeData)
    local frame = CreateFrame("Frame", nil, UIParent)

    local baseSize = self:GetPinIconSize()
    local _, _, iconSize = GetWorldPinVisualSizes(baseSize)
    frame:SetSize(baseSize, baseSize)
    frame:EnableMouse(true)

    -- Housing icon (tint is count-driven — set by RefreshBadgePinVisuals below)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("CENTER")
    frame.icon:SetSize(iconSize, iconSize)
    frame.icon:SetAtlas("housing-decor-vendor_32", false)

    -- Faction emblem. dominantFaction/oppositeFactionCount>0 resolve to the
    -- SAME faction classification for every badgeData sharing this frame's
    -- pool key (GetBadgeFramePoolKey bakes that classification into the key
    -- itself), so — unlike the icon tint and count text above — this is
    -- bucket-invariant and does not need a post-acquire refresh.
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

    -- Count text (font/anchor are structural/style; text + color are
    -- count-driven — set by RefreshBadgePinVisuals below)
    local fontSize = GetBadgeCountTextMetrics(baseSize)
    frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal", 2)
    frame.count:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    local fontPath = frame.count:GetFont()
    frame.count:SetFont(fontPath, fontSize, "OUTLINE")
    frame.count:SetShadowColor(0, 0, 0, 0)
    frame.count:SetShadowOffset(0, 0)

    -- Store badge data
    frame.badgeData = badgeData

    self:RefreshBadgePinVisuals(frame, badgeData)

    -- Tooltip/click handlers
    frame:SetScript("OnEnter", function(self) -- luacheck: ignore 432
        if HA.VendorMapPins then
            HA.VendorMapPins:ShowZoneBadgeTooltip(self, self.badgeData)
        end
    end)
    frame:SetScript("OnLeave", function(self) -- luacheck: ignore 432
        if HA.VendorMapPins then
            HA.VendorMapPins:HidePinTooltip()
        end
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

-- Legion Order Hall class atlas icons (legionmission-landingbutton-<class>-up)
local PORTAL_CLASS_ATLAS = {
    PALADIN     = "legionmission-landingbutton-paladin-up",
    SHAMAN      = "legionmission-landingbutton-shaman-up",
    WARRIOR     = "legionmission-landingbutton-warrior-up",
    PRIEST      = "legionmission-landingbutton-priest-up",
    DEMONHUNTER = "legionmission-landingbutton-demonhunter-up",
    MONK        = "legionmission-landingbutton-monk-up",
    MAGE        = "legionmission-landingbutton-mage-up",
    ROGUE       = "legionmission-landingbutton-rogue-up",
    HUNTER      = "legionmission-landingbutton-hunter-up",
    WARLOCK     = "legionmission-landingbutton-warlock-up",
}

-- Creates a portal badge pin for an Order Hall entrance.
-- portalData: { vendor = <vendor table> }
-- Pin is placed at vendor.portal.{mapID,x,y}; click navigates to vendor.mapID.
function PinFrameFactory:CreatePortalBadgePinFrame(portalData)
    local baseSize = self:GetPinIconSize()
    local adjustedSize, _, iconSize = GetWorldPinVisualSizes(baseSize)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(adjustedSize, adjustedSize)
    frame:EnableMouse(true)

    local vendor = portalData and portalData.vendor
    local classAtlas = vendor and vendor.class and PORTAL_CLASS_ATLAS[vendor.class]
    local classColor = vendor and vendor.class and _G.C_ClassColor
        and _G.C_ClassColor.GetClassColor(vendor.class)
    local cr = classColor and classColor.r or 0.7
    local cg = classColor and classColor.g or 0.3
    local cb = classColor and classColor.b or 1.0

    -- Dark circular background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetAtlas("auctionhouse-itemicon-border-white", false)
    bg:SetVertexColor(0.08, 0.04, 0.15, 1.0)

    if classAtlas then
        -- Class icon fills the pin — the atlas includes its own border and emblem
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(iconSize, iconSize)
        icon:SetPoint("CENTER")
        icon:SetAtlas(classAtlas, false)
    else
        -- Fallback: tinted ring + housing icon (Warlock and future classes)
        local ring = frame:CreateTexture(nil, "BORDER")
        ring:SetAllPoints()
        ring:SetAtlas("auctionhouse-itemicon-border-artifact", false)
        ring:SetVertexColor(cr, cg, cb)

        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(iconSize * 0.65, iconSize * 0.65)
        icon:SetPoint("CENTER")
        icon:SetAtlas("housing-decor-vendor_32", false)
        icon:SetDesaturated(true)
        icon:SetVertexColor(cr, cg, cb, 1.0)
    end

    -- Pulsing outer glow ring (class-colored, extends beyond pin edges)
    local glowFrame = CreateFrame("Frame", nil, frame)
    glowFrame:SetSize(adjustedSize * 2.2, adjustedSize * 2.2)
    glowFrame:SetPoint("CENTER")
    local glowTex = glowFrame:CreateTexture(nil, "BACKGROUND")
    glowTex:SetAllPoints()
    glowTex:SetAtlas("auctionhouse-itemicon-border-artifact", false)
    glowTex:SetVertexColor(cr, cg, cb)
    local ag = glowFrame:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local anim = ag:CreateAnimation("ALPHA")
    anim:SetFromAlpha(0.1)
    anim:SetToAlpha(0.7)
    anim:SetDuration(1.2)
    ag:Play()
    frame.glowFrame = glowFrame
    frame.glowAnim = ag

    frame.portalData = portalData

    frame:SetScript("OnMouseUp", function(self, button) -- luacheck: ignore 432
        if button == "LeftButton" then
            local v = self.portalData and self.portalData.vendor
            if v and v.mapID then
                WorldMapFrame:SetMapID(v.mapID)
            end
        end
    end)

    frame:SetScript("OnEnter", function(self) -- luacheck: ignore 432
        local v = self.portalData and self.portalData.vendor
        if HA.VendorMapPins and v then
            HA.VendorMapPins:ShowPortalTooltip(self, v)
        end
    end)

    frame:SetScript("OnLeave", function() -- luacheck: ignore 432
        if HA.VendorMapPins then
            HA.VendorMapPins:HidePinTooltip()
        end
    end)

    return frame
end

-------------------------------------------------------------------------------
-- Minimap Pin Frame
-------------------------------------------------------------------------------

function PinFrameFactory:CreateMinimapPinFrame(vendor, isOppositeFaction, elevation)
    local frame = CreateFrame("Frame", nil, UIParent)

    local mmSize = self:GetMinimapIconSize()
    frame:SetSize(mmSize, mmSize)
    frame:EnableMouse(true)

    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(1)

    local br, bg, bb = self:GetPinColor()
    local isCustomColor = self:IsCustomPinColor()

    -- Housing icon
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("CENTER")
    frame.icon:SetSize(mmSize, mmSize)
    frame.icon:SetAtlas("housing-decor-vendor_32", false)
    if isOppositeFaction then
        frame.icon:SetDesaturated(true)
        frame.icon:SetVertexColor(0.6, 0.6, 0.6, 0.9)
    elseif isCustomColor then
        frame.icon:SetDesaturated(true)
        frame.icon:SetVertexColor(br, bg, bb, PinFrameFactory.DESAT_ALPHA)
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

    -- Simple tooltip on hover
    frame:SetScript("OnEnter", function(self) -- luacheck: ignore 432
        if HA.VendorMapPins then
            HA.VendorMapPins:ShowMinimapTooltip(
                self,
                self.vendor,
                self.isOppositeFaction,
                self.elevation
            )
        end
    end)
    frame:SetScript("OnLeave", function(self) -- luacheck: ignore 432
        if HA.VendorMapPins then
            HA.VendorMapPins:HidePinTooltip()
        end
    end)

    return frame
end
