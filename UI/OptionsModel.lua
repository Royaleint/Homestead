--[[
    Homestead - Options Model
    Data-only settings descriptors for the native Blizzard options UI.
]]

local addonName, HA = ...

local L = HA.L or {}

local OptionsModel = {}
HA.OptionsModel = OptionsModel

local function GetAddon()
    return HA.Addon
end

local function GetProfile()
    local addon = GetAddon()
    return addon and addon.db and addon.db.profile
end

local function GetVendorTracer()
    local profile = GetProfile()
    return profile and profile.vendorTracer
end

local function GetOverlay()
    local profile = GetProfile()
    return profile and profile.overlay
end

local function GetTooltip()
    local profile = GetProfile()
    return profile and profile.tooltip
end

local function GetEndeavors()
    local profile = GetProfile()
    return profile and profile.endeavors
end

local function GetVendorScanning()
    local profile = GetProfile()
    return profile and profile.vendorScanning
end

local function GetMinimap()
    local profile = GetProfile()
    return profile and profile.minimap
end

local function CallMethod(target, methodName, ...)
    local method = target and target[methodName]
    if method then
        return method(target, ...)
    end
end

local function CallAddon(methodName, ...)
    return CallMethod(GetAddon(), methodName, ...)
end

local function CallVendorMapPins(methodName, ...)
    return CallMethod(HA.VendorMapPins, methodName, ...)
end

local function CallOverlay(methodName, ...)
    return CallMethod(HA.Overlay, methodName, ...)
end

local function CallMapSidePanel(methodName, ...)
    return CallMethod(HA.MapSidePanel, methodName, ...)
end

local function CallWaypoints(methodName, ...)
    return CallMethod(HA.Waypoints, methodName, ...)
end

local function IsPinColorCustomHidden()
    local vendorTracer = GetVendorTracer()
    return ((vendorTracer and vendorTracer.pinColorPreset) or "default") ~= "custom"
end

local function RefreshPinsAndBadges()
    CallVendorMapPins("InvalidateBadgeCache")
    CallVendorMapPins("RefreshPins")
end

local function RefreshAllPinColors()
    CallVendorMapPins("RefreshAllPinColors")
end

local function RequestMinimapRefresh(reason)
    CallVendorMapPins("RequestMinimapRefresh", reason)
end

local function NotifyOptionsChanged()
    if HA.OptionsFrame and HA.OptionsFrame.Refresh then
        HA.OptionsFrame:Refresh()
    end
end

function OptionsModel:GetPinPreviewColor()
    if HA.PinFrameFactory and HA.PinFrameFactory.GetPinColor then
        return HA.PinFrameFactory:GetPinColor()
    end

    local vendorTracer = GetVendorTracer()
    if not vendorTracer then return 1, 1, 1 end

    local preset = vendorTracer.pinColorPreset or "default"
    if preset == "custom" then
        local c = vendorTracer.pinColorCustom
        return c and c.r or 1, c and c.g or 1, c and c.b or 1
    end

    return 1, 1, 1
end

function OptionsModel:IsCustomPinColor()
    if HA.PinFrameFactory and HA.PinFrameFactory.IsCustomPinColor then
        return HA.PinFrameFactory:IsCustomPinColor()
    end

    local vendorTracer = GetVendorTracer()
    return ((vendorTracer and vendorTracer.pinColorPreset) or "default") ~= "default"
end

function OptionsModel:GetPinPreviewAlpha()
    if HA.PinFrameFactory and HA.PinFrameFactory.DESAT_ALPHA then
        return HA.PinFrameFactory.DESAT_ALPHA
    end

    return 0.95
end

local pinColorValues = {
    { key = "default", label = L["Default (Gold)"] },
    { key = "green", label = L["Bright Green"] },
    { key = "blue", label = L["Ice Blue"] },
    { key = "lightblue", label = L["Light Blue"] },
    { key = "cyan", label = L["Cyan"] },
    { key = "purple", label = L["Purple"] },
    { key = "pink", label = L["Pink"] },
    { key = "red", label = L["Red"] },
    { key = "yellow", label = L["Yellow"] },
    { key = "white", label = L["White"] },
    { key = "custom", label = L["Custom..."] },
}

local iconAnchorValues = {
    { key = "TOPLEFT", label = L["Top Left"] },
    { key = "TOPRIGHT", label = L["Top Right"] },
    { key = "BOTTOMLEFT", label = L["Bottom Left"] },
    { key = "BOTTOMRIGHT", label = L["Bottom Right"] },
    { key = "CENTER", label = L["Center"] },
}

local ownedItemStyleValues = {
    { key = "default", label = L["Green highlight (default)"] },
    { key = "none", label = L["None"] },
    { key = "dim", label = L["Dimmed"] },
    { key = "checkmark", label = L["Checkmark"] },
}

local mapSidePanelSourceFilterValues = {
    { key = "all", label = L["All sources"] },
    { key = "vendor", label = L["Vendor"] },
    { key = "quest", label = L["Quest"] },
    { key = "achievement", label = L["Achievement"] },
    { key = "profession", label = L["Profession"] },
    { key = "event", label = L["Event"] },
    { key = "drop", label = L["Drop"] },
}

local minimapCrossZoneModeValues = {
    { key = "auto", label = L["Auto (recommended)"] },
    { key = "off", label = L["Current zone only"] },
    { key = "on", label = L["Always show nearby zones"] },
}

local navigateModifierValues = {
    { key = "shift", label = L["Shift"] },
    { key = "ctrl", label = L["Control"] },
    { key = "alt", label = L["Alt"] },
    { key = "none", label = L["None (always)"] },
}

OptionsModel.sections = {
    {
        key = "general",
        label = L["General"],
        description = L["desc_options_general"],
        rows = {
            {
                key = "enabled",
                type = "checkbox",
                label = L["Enable addon"],
                tooltip = L["desc_enable_addon"],
                get = function()
                    local profile = GetProfile()
                    return profile and profile.enabled
                end,
                set = function(value)
                    local profile = GetProfile()
                    if not profile then return end
                    profile.enabled = value
                    if value then
                        CallAddon("Enable")
                    else
                        CallAddon("Disable")
                    end
                end,
            },
            {
                key = "minimapButton",
                type = "checkbox",
                label = L["Show minimap button"],
                tooltip = L["desc_minimap_button"],
                get = function()
                    local minimap = GetMinimap()
                    return minimap and not minimap.hide
                end,
                set = function(value)
                    local minimap = GetMinimap()
                    if not minimap then return end
                    minimap.hide = not value

                    local LDBIcon = LibStub("LibDBIcon-1.0", true)
                    if LDBIcon then
                        if value then
                            LDBIcon:Show(addonName)
                        else
                            LDBIcon:Hide(addonName)
                        end
                    end
                end,
            },
            {
                key = "vendorScanning",
                type = "checkbox",
                label = L["Auto-scan vendors"],
                tooltip = L["desc_auto_scan_vendors"],
                get = function()
                    local vendorScanning = GetVendorScanning()
                    return vendorScanning and vendorScanning.enabled
                end,
                set = function(value)
                    local vendorScanning = GetVendorScanning()
                    if vendorScanning then
                        vendorScanning.enabled = value
                    end
                end,
            },
            {
                key = "vendorVisibilityHeader",
                type = "header",
                label = L["Vendor Visibility"],
            },
            {
                key = "showOppositeFaction",
                type = "checkbox",
                label = L["Show opposite faction vendors"],
                tooltip = L["desc_opposite_faction"],
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return vendorTracer and vendorTracer.showOppositeFaction
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.showOppositeFaction = value
                    RefreshPinsAndBadges()
                end,
            },
            {
                key = "showEventVendors",
                type = "checkbox",
                label = L["Show event vendors"],
                tooltip = L["desc_event_vendors"],
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return not vendorTracer or vendorTracer.showEventVendors ~= false
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.showEventVendors = value
                    RefreshPinsAndBadges()
                    RequestMinimapRefresh("option_showEventVendors")
                end,
            },
            {
                key = "pinAppearanceHeader",
                type = "header",
                label = L["Pin Appearance"],
            },
            {
                key = "pinColorPreset",
                type = "dropdown",
                label = L["Pin color"],
                tooltip = L["desc_pin_color"],
                values = pinColorValues,
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return (vendorTracer and vendorTracer.pinColorPreset) or "default"
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.pinColorPreset = value
                    RefreshAllPinColors()
                end,
            },
            {
                key = "pinColorCustom",
                type = "color",
                label = L["Custom color"],
                tooltip = L["desc_custom_color"],
                hidden = IsPinColorCustomHidden,
                get = function()
                    local vendorTracer = GetVendorTracer()
                    local c = vendorTracer and vendorTracer.pinColorCustom
                    return c and c.r or 1, c and c.g or 1, c and c.b or 1
                end,
                set = function(r, g, b)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.pinColorCustom = { r = r, g = g, b = b }
                    RefreshAllPinColors()
                    NotifyOptionsChanged()
                end,
            },
            {
                key = "pinColorPreview",
                type = "pinPreview",
                label = L["Approximate map appearance"],
            },
        },
    },
    {
        key = "overlays",
        label = L["Overlays"],
        description = L["desc_options_overlays"],
        rows = {
            {
                key = "enabled",
                type = "checkbox",
                label = L["Enable overlays"],
                tooltip = L["desc_enable_overlays"],
                get = function()
                    local overlay = GetOverlay()
                    return overlay and overlay.enabled
                end,
                set = function(value)
                    local overlay = GetOverlay()
                    if not overlay then return end
                    overlay.enabled = value
                    CallOverlay("RefreshAll")
                end,
            },
            {
                key = "iconSize",
                type = "slider",
                label = L["Icon size"],
                tooltip = L["desc_icon_size"],
                min = 8,
                max = 32,
                step = 1,
                get = function()
                    local overlay = GetOverlay()
                    return overlay and overlay.iconSize
                end,
                set = function(value)
                    local overlay = GetOverlay()
                    if not overlay then return end
                    overlay.iconSize = value
                    CallOverlay("UpdateConfig")
                end,
            },
            {
                key = "iconAnchor",
                type = "dropdown",
                label = L["Icon position"],
                tooltip = L["desc_icon_position"],
                values = iconAnchorValues,
                get = function()
                    local overlay = GetOverlay()
                    return overlay and overlay.iconAnchor
                end,
                set = function(value)
                    local overlay = GetOverlay()
                    if not overlay then return end
                    overlay.iconAnchor = value
                    CallOverlay("UpdateConfig")
                end,
            },
            {
                key = "inventoryHeader",
                type = "header",
                label = L["Inventory"],
            },
            {
                key = "showOnBags",
                type = "checkbox",
                label = L["Show on bags"],
                tooltip = L["desc_show_on_bags"],
                get = function()
                    local overlay = GetOverlay()
                    return overlay and overlay.showOnBags
                end,
                set = function(value)
                    local overlay = GetOverlay()
                    if not overlay then return end
                    overlay.showOnBags = value
                    CallOverlay("RefreshAll")
                end,
            },
            {
                key = "showOnBank",
                type = "checkbox",
                label = L["Show on bank"],
                tooltip = L["desc_show_on_bank"],
                get = function()
                    local overlay = GetOverlay()
                    return overlay and overlay.showOnBank
                end,
                set = function(value)
                    local overlay = GetOverlay()
                    if not overlay then return end
                    overlay.showOnBank = value
                    CallOverlay("RefreshAll")
                end,
            },
            {
                key = "showOnAuctionHouse",
                type = "checkbox",
                label = L["Show on auction house"],
                tooltip = L["desc_show_on_auction_house"],
                get = function()
                    local overlay = GetOverlay()
                    return overlay and overlay.showOnAuctionHouse
                end,
                set = function(value)
                    local overlay = GetOverlay()
                    if not overlay then return end
                    overlay.showOnAuctionHouse = value
                    CallOverlay("RefreshAll")
                end,
            },
            {
                key = "merchantHeader",
                type = "header",
                label = L["Merchant"],
            },
            {
                key = "showOnMerchant",
                type = "checkbox",
                label = L["Show on merchant"],
                tooltip = L["desc_show_on_merchant"],
                get = function()
                    local overlay = GetOverlay()
                    return overlay and overlay.showOnMerchant
                end,
                set = function(value)
                    local overlay = GetOverlay()
                    if not overlay then return end
                    overlay.showOnMerchant = value
                    CallOverlay("RefreshAll")
                end,
            },
            {
                key = "housingCatalogHeader",
                type = "header",
                label = L["Housing Catalog"],
            },
            {
                key = "showOnHousingCatalog",
                type = "checkbox",
                label = L["Show on housing catalog"],
                tooltip = L["desc_show_on_housing_catalog"],
                get = function()
                    local overlay = GetOverlay()
                    return overlay and overlay.showOnHousingCatalog
                end,
                set = function(value)
                    local overlay = GetOverlay()
                    if not overlay then return end
                    overlay.showOnHousingCatalog = value
                    CallOverlay("RefreshAll")
                end,
            },
            {
                key = "showAccessibilityGlow",
                type = "checkbox",
                label = L["Show accessibility glow"],
                tooltip = L["desc_accessibility_glow"],
                get = function()
                    local overlay = GetOverlay()
                    return overlay and overlay.showAccessibilityGlow
                end,
                set = function(value)
                    local overlay = GetOverlay()
                    if not overlay then return end
                    overlay.showAccessibilityGlow = value
                    CallOverlay("RefreshAll")
                end,
            },
            {
                key = "ownedItemStyle",
                type = "dropdown",
                label = L["Owned item style"],
                tooltip = L["desc_owned_item_style"],
                values = ownedItemStyleValues,
                get = function()
                    local overlay = GetOverlay()
                    return (overlay and overlay.ownedItemStyle) or "default"
                end,
                set = function(value)
                    local overlay = GetOverlay()
                    if not overlay then return end
                    overlay.ownedItemStyle = value
                    CallOverlay("RefreshAll")
                end,
            },
        },
    },
    {
        key = "tooltips",
        label = L["Tooltips"],
        description = L["desc_options_tooltips"],
        rows = {
            {
                key = "enabled",
                type = "checkbox",
                label = L["Enable tooltip additions"],
                tooltip = L["desc_enable_tooltips"],
                get = function()
                    local tooltip = GetTooltip()
                    return tooltip and tooltip.enabled
                end,
                set = function(value)
                    local tooltip = GetTooltip()
                    if tooltip then
                        tooltip.enabled = value
                    end
                end,
            },
            {
                key = "showOwned",
                type = "checkbox",
                label = L["Show ownership status"],
                tooltip = L["desc_show_ownership"],
                get = function()
                    local tooltip = GetTooltip()
                    return tooltip and tooltip.showOwned
                end,
                set = function(value)
                    local tooltip = GetTooltip()
                    if tooltip then
                        tooltip.showOwned = value
                    end
                end,
            },
            {
                key = "showSource",
                type = "checkbox",
                label = L["Show source information"],
                tooltip = L["desc_show_source"],
                get = function()
                    local tooltip = GetTooltip()
                    return tooltip and tooltip.showSource
                end,
                set = function(value)
                    local tooltip = GetTooltip()
                    if tooltip then
                        tooltip.showSource = value
                    end
                end,
            },
            {
                key = "showRequirements",
                type = "checkbox",
                label = L["Show requirements"],
                tooltip = L["desc_show_requirements"],
                get = function()
                    local tooltip = GetTooltip()
                    return tooltip and tooltip.showRequirements
                end,
                set = function(value)
                    local tooltip = GetTooltip()
                    if tooltip then
                        tooltip.showRequirements = value
                    end
                end,
            },
            {
                key = "showAllSources",
                type = "checkbox",
                label = L["Show all sources"],
                tooltip = L["desc_show_all_sources"],
                get = function()
                    local tooltip = GetTooltip()
                    return tooltip and tooltip.showAllSources
                end,
                set = function(value)
                    local tooltip = GetTooltip()
                    if tooltip then
                        tooltip.showAllSources = value
                    end
                end,
            },
            {
                key = "mapPinTooltipHeader",
                type = "header",
                label = L["Map Pins"],
            },
            {
                key = "showVendorDetails",
                type = "checkbox",
                label = L["Show vendor details in tooltips"],
                tooltip = L["desc_vendor_details"],
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return vendorTracer and vendorTracer.showVendorDetails
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if vendorTracer then
                        vendorTracer.showVendorDetails = value
                    end
                end,
            },
        },
    },
    {
        key = "worldMap",
        label = L["World Map"],
        description = L["desc_options_world_map"],
        rows = {
            {
                key = "showMapPins",
                type = "checkbox",
                label = L["Show map pins"],
                tooltip = L["desc_show_map_pins"],
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return vendorTracer and vendorTracer.showMapPins
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.showMapPins = value
                    if value then
                        CallVendorMapPins("Enable")
                    else
                        CallVendorMapPins("Disable")
                    end
                end,
            },
            {
                key = "showMapSidePanel",
                type = "checkbox",
                label = L["Show vendor panel on world map"],
                tooltip = L["desc_show_map_side_panel"],
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return vendorTracer and vendorTracer.showMapSidePanel
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.showMapSidePanel = value
                    if value then
                        CallMapSidePanel("Show")
                    else
                        CallMapSidePanel("Hide")
                    end
                end,
            },
            {
                key = "mapSidePanelSourceFilter",
                type = "dropdown",
                label = L["Vendor panel source filter"],
                tooltip = L["desc_source_filter"],
                values = mapSidePanelSourceFilterValues,
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return (vendorTracer and vendorTracer.mapSidePanelSourceFilter) or "all"
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.mapSidePanelSourceFilter = value
                    if HA.MapSidePanel and HA.MapSidePanel.SetSourceFilter then
                        HA.MapSidePanel:SetSourceFilter(value)
                    else
                        CallVendorMapPins("InvalidateAllCaches")
                    end
                end,
            },
            {
                key = "integrateMapBorder",
                type = "checkbox",
                label = L["Integrate with map frame border"],
                tooltip = L["desc_integrate_map_border"],
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return not vendorTracer or vendorTracer.integrateMapBorder ~= false
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.integrateMapBorder = value
                    if HA.MapSidePanel then
                        CallMapSidePanel("ResetIntegrationMode")
                        if HA.MapSidePanel.IsShown and HA.MapSidePanel:IsShown() then
                            HA.MapSidePanel:Hide()
                            HA.MapSidePanel:Show()
                        end
                    end
                end,
            },
            {
                key = "worldMapZoneBadges",
                type = "checkbox",
                label = L["Zone badges on world map"],
                tooltip = L["desc_zone_badges"],
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return vendorTracer and vendorTracer.worldMapZoneBadges
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.worldMapZoneBadges = value
                    RefreshPinsAndBadges()
                end,
            },
            {
                key = "pinIconSize",
                type = "slider",
                label = L["World map pin size"],
                tooltip = L["desc_world_pin_size"],
                min = 8,
                max = 18,
                step = 2,
                get = function()
                    if HA.PinFrameFactory and HA.PinFrameFactory.GetPinIconSize then
                        return HA.PinFrameFactory:GetPinIconSize()
                    end
                    local vendorTracer = GetVendorTracer()
                    return (vendorTracer and vendorTracer.pinIconSize) or 10
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.pinIconSize = value
                    RefreshAllPinColors()
                end,
            },
            {
                key = "showPinCounts",
                type = "checkbox",
                label = L["Show collection counts"],
                tooltip = L["desc_show_pin_counts"],
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return not vendorTracer or vendorTracer.showPinCounts ~= false
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.showPinCounts = value
                    CallVendorMapPins("RefreshPins")
                end,
            },
        },
    },
    {
        key = "minimap",
        label = L["Minimap"],
        description = L["desc_options_minimap"],
        rows = {
            {
                key = "showMinimapPins",
                type = "checkbox",
                label = L["Show minimap pins"],
                tooltip = L["desc_show_minimap_pins"],
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return vendorTracer and vendorTracer.showMinimapPins
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.showMinimapPins = value
                    if value then
                        CallVendorMapPins("EnableMinimapPins")
                    else
                        CallVendorMapPins("DisableMinimapPins")
                    end
                end,
            },
            {
                key = "showElevationArrows",
                type = "checkbox",
                label = L["Show elevation arrows"],
                tooltip = L["desc_elevation_arrows"],
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return not vendorTracer or vendorTracer.showElevationArrows ~= false
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.showElevationArrows = value
                    RequestMinimapRefresh("option_showElevationArrows")
                end,
            },
            {
                key = "minimapCrossZoneMode",
                type = "dropdown",
                label = L["Minimap nearby-zone pins"],
                tooltip = L["desc_cross_zone_mode"],
                values = minimapCrossZoneModeValues,
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return (vendorTracer and vendorTracer.minimapCrossZoneMode) or "auto"
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.minimapCrossZoneMode = value
                    RequestMinimapRefresh("option_minimapCrossZoneMode")
                end,
            },
            {
                key = "minimapIconSize",
                type = "slider",
                label = L["Minimap pin size"],
                tooltip = L["desc_minimap_pin_size"],
                min = 8,
                max = 24,
                step = 1,
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return (vendorTracer and vendorTracer.minimapIconSize) or 12
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.minimapIconSize = value
                    RequestMinimapRefresh("option_minimapIconSize")
                end,
            },
            {
                key = "waypointHeader",
                type = "header",
                label = L["Waypoints"],
            },
            {
                key = "waypointDesc",
                type = "description",
                label = L["desc_waypoint_info"],
            },
            {
                key = "useTomTom",
                type = "checkbox",
                label = L["Use TomTom for waypoints"],
                tooltip = L["desc_use_tomtom"],
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return vendorTracer and vendorTracer.useTomTom
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.useTomTom = value
                    CallWaypoints("UpdateConfig")
                end,
            },
            {
                key = "useNativeWaypoints",
                type = "checkbox",
                label = L["Use native waypoints"],
                tooltip = L["desc_use_native_waypoints"],
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return vendorTracer and vendorTracer.useNativeWaypoints
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if not vendorTracer then return end
                    vendorTracer.useNativeWaypoints = value
                    CallWaypoints("UpdateConfig")
                end,
            },
            {
                key = "autoWaypoint",
                type = "checkbox",
                label = L["Auto-create waypoint on click"],
                tooltip = L["desc_auto_waypoint"],
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return vendorTracer and vendorTracer.autoWaypoint
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if vendorTracer then
                        vendorTracer.autoWaypoint = value
                    end
                end,
            },
            {
                key = "navigateModifier",
                type = "dropdown",
                label = L["Navigate modifier key"],
                tooltip = L["desc_navigate_modifier"],
                values = navigateModifierValues,
                get = function()
                    local vendorTracer = GetVendorTracer()
                    return vendorTracer and vendorTracer.navigateModifier
                end,
                set = function(value)
                    local vendorTracer = GetVendorTracer()
                    if vendorTracer then
                        vendorTracer.navigateModifier = value
                    end
                end,
            },
        },
    },
    {
        key = "endeavors",
        label = L["Endeavors"],
        description = L["desc_options_endeavors"],
        rows = {
            {
                key = "showMilestoneXP",
                type = "checkbox",
                label = L["Show milestone progress on dashboard"],
                tooltip = L["desc_milestone_xp"],
                get = function()
                    local endeavors = GetEndeavors()
                    return endeavors and endeavors.showMilestoneXP
                end,
                set = function(value)
                    local endeavors = GetEndeavors()
                    if endeavors then
                        endeavors.showMilestoneXP = value
                    end
                end,
            },
        },
    },
    {
        key = "export",
        label = L["Export"],
        description = L["desc_options_export"],
        rows = {
            {
                key = "exportDesc",
                type = "description",
                label = L["desc_export"],
            },
            {
                key = "exportNewButton",
                type = "button",
                label = L["Export New Scans"],
                tooltip = L["desc_export_new"],
                run = function()
                    if HA.ExportImport then
                        HA.ExportImport:ExportScannedVendors(false, false)
                    else
                        CallAddon("Print", L["ExportImport not available."])
                    end
                end,
            },
            {
                key = "exportAllButton",
                type = "button",
                label = L["Export All"],
                tooltip = L["desc_export_all"],
                run = function()
                    if HA.ExportImport then
                        HA.ExportImport:ExportScannedVendors(true, true)
                    else
                        CallAddon("Print", L["ExportImport not available."])
                    end
                end,
            },
        },
    },
}

function OptionsModel:GetSections()
    return self.sections
end

function OptionsModel:GetSection(sectionKey)
    for _, section in ipairs(self.sections) do
        if section.key == sectionKey then
            return section
        end
    end
    return self.sections[1]
end

return OptionsModel
