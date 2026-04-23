--[[
    Homestead - Options Panel
    Configuration UI using AceConfig
]]

local addonName, HA = ...

-- Local references
local L = HA.L or {}

-------------------------------------------------------------------------------
-- Options Table
-------------------------------------------------------------------------------

local function GetOptionsTable()
    local options = {
        type = "group",
        name = "Homestead",
        handler = HA.Addon,
        args = {
            -- General Section
            general = {
                type = "group",
                name = L["General"],
                order = 1,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable addon"],
                        desc = L["desc_enable_addon"],
                        width = "full",
                        order = 1,
                        get = function() return HA.Addon.db.profile.enabled end,
                        set = function(_, value)
                            HA.Addon.db.profile.enabled = value
                            if value then
                                HA.Addon:Enable()
                            else
                                HA.Addon:Disable()
                            end
                        end,
                    },
                    minimapButton = {
                        type = "toggle",
                        name = L["Show minimap button"],
                        desc = L["desc_minimap_button"],
                        width = "full",
                        order = 2,
                        get = function() return not HA.Addon.db.profile.minimap.hide end,
                        set = function(_, value)
                            HA.Addon.db.profile.minimap.hide = not value
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
                    vendorScanning = {
                        type = "toggle",
                        name = L["Auto-scan vendors"],
                        desc = L["desc_auto_scan_vendors"],
                        width = "full",
                        order = 3,
                        get = function() return HA.Addon.db.profile.vendorScanning.enabled end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorScanning.enabled = value
                        end,
                    },

                    -- Vendor Visibility
                    vendorVisibilityHeader = {
                        type = "header",
                        name = L["Vendor Visibility"],
                        order = 10,
                    },
                    showOppositeFaction = {
                        type = "toggle",
                        name = L["Show opposite faction vendors"],
                        desc = L["desc_opposite_faction"],
                        width = "double",
                        order = 11,
                        get = function() return HA.Addon.db.profile.vendorTracer.showOppositeFaction end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showOppositeFaction = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:InvalidateBadgeCache()
                                HA.VendorMapPins:RefreshPins()
                            end
                        end,
                    },
                    showEventVendors = {
                        type = "toggle",
                        name = L["Show event vendors"],
                        desc = L["desc_event_vendors"],
                        width = "double",
                        order = 13,
                        get = function() return HA.Addon.db.profile.vendorTracer.showEventVendors ~= false end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showEventVendors = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:InvalidateBadgeCache()
                                HA.VendorMapPins:RefreshPins()
                                HA.VendorMapPins:RequestMinimapRefresh("option_showEventVendors")
                            end
                        end,
                    },

                    -- Pin Appearance
                    pinAppearanceHeader = {
                        type = "header",
                        name = L["Pin Appearance"],
                        order = 20,
                    },
                    pinColorPreset = {
                        type = "select",
                        name = L["Pin color"],
                        desc = L["desc_pin_color"],
                        order = 21,
                        values = {
                            default   = L["Default (Gold)"],
                            green     = L["Bright Green"],
                            blue      = L["Ice Blue"],
                            lightblue = L["Light Blue"],
                            purple    = L["Purple"],
                            pink      = L["Pink"],
                            red       = L["Red"],
                            cyan      = L["Cyan"],
                            white     = L["White"],
                            yellow    = L["Yellow"],
                            custom    = L["Custom..."],
                        },
                        sorting = { "default", "green", "blue", "lightblue", "cyan", "purple", "pink", "red", "yellow", "white", "custom" },
                        get = function()
                            return HA.Addon.db.profile.vendorTracer.pinColorPreset or "default"
                        end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.pinColorPreset = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:RefreshAllPinColors()
                            end
                        end,
                    },
                    pinColorCustom = {
                        type = "color",
                        name = L["Custom color"],
                        desc = L["desc_custom_color"],
                        order = 22,
                        hidden = function()
                            return (HA.Addon.db.profile.vendorTracer.pinColorPreset or "default") ~= "custom"
                        end,
                        get = function()
                            local c = HA.Addon.db.profile.vendorTracer.pinColorCustom
                            return c.r, c.g, c.b
                        end,
                        set = function(_, r, g, b)
                            HA.Addon.db.profile.vendorTracer.pinColorCustom = { r = r, g = g, b = b }
                            if HA.VendorMapPins then
                                HA.VendorMapPins:RefreshAllPinColors()
                            end
                        end,
                    },
                    pinColorPreview = {
                        type = "description",
                        name = L["Approximate map appearance"],
                        dialogControl = "HomesteadPinColorPreview",
                        order = 23,
                        width = "double",
                    },
                },
            },

            -- Overlays Section
            overlays = {
                type = "group",
                name = L["Overlays"],
                order = 2,
                args = {
                    -- Master toggle
                    enabled = {
                        type = "toggle",
                        name = L["Enable overlays"],
                        desc = L["desc_enable_overlays"],
                        width = "full",
                        order = 1,
                        get = function() return HA.Addon.db.profile.overlay.enabled end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.enabled = value
                            if HA.Overlay then HA.Overlay:RefreshAll() end
                        end,
                    },

                    -- Icon appearance
                    iconSize = {
                        type = "range",
                        name = L["Icon size"],
                        desc = L["desc_icon_size"],
                        min = 8,
                        max = 32,
                        step = 1,
                        order = 2,
                        get = function() return HA.Addon.db.profile.overlay.iconSize end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.iconSize = value
                            if HA.Overlay then HA.Overlay:UpdateConfig() end
                        end,
                    },
                    iconAnchor = {
                        type = "select",
                        name = L["Icon position"],
                        desc = L["desc_icon_position"],
                        values = {
                            TOPLEFT = L["Top Left"],
                            TOPRIGHT = L["Top Right"],
                            BOTTOMLEFT = L["Bottom Left"],
                            BOTTOMRIGHT = L["Bottom Right"],
                            CENTER = L["Center"],
                        },
                        order = 3,
                        get = function() return HA.Addon.db.profile.overlay.iconAnchor end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.iconAnchor = value
                            if HA.Overlay then HA.Overlay:UpdateConfig() end
                        end,
                    },

                    -- Inventory
                    inventoryHeader = {
                        type = "header",
                        name = L["Inventory"],
                        order = 10,
                    },
                    showOnBags = {
                        type = "toggle",
                        name = L["Show on bags"],
                        desc = L["desc_show_on_bags"],
                        order = 11,
                        get = function() return HA.Addon.db.profile.overlay.showOnBags end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.showOnBags = value
                            if HA.Overlay then HA.Overlay:RefreshAll() end
                        end,
                    },
                    showOnBank = {
                        type = "toggle",
                        name = L["Show on bank"],
                        desc = L["desc_show_on_bank"],
                        order = 12,
                        get = function() return HA.Addon.db.profile.overlay.showOnBank end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.showOnBank = value
                            if HA.Overlay then HA.Overlay:RefreshAll() end
                        end,
                    },
                    showOnAuctionHouse = {
                        type = "toggle",
                        name = L["Show on auction house"],
                        desc = L["desc_show_on_auction_house"],
                        width = "double",
                        order = 13,
                        get = function() return HA.Addon.db.profile.overlay.showOnAuctionHouse end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.showOnAuctionHouse = value
                            if HA.Overlay then HA.Overlay:RefreshAll() end
                        end,
                    },

                    -- Merchant
                    merchantHeader = {
                        type = "header",
                        name = L["Merchant"],
                        order = 20,
                    },
                    showOnMerchant = {
                        type = "toggle",
                        name = L["Show on merchant"],
                        desc = L["desc_show_on_merchant"],
                        order = 21,
                        get = function() return HA.Addon.db.profile.overlay.showOnMerchant end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.showOnMerchant = value
                            if HA.Overlay then HA.Overlay:RefreshAll() end
                        end,
                    },

                    -- Housing Catalog
                    housingCatalogHeader = {
                        type = "header",
                        name = L["Housing Catalog"],
                        order = 30,
                    },
                    showOnHousingCatalog = {
                        type = "toggle",
                        name = L["Show on housing catalog"],
                        desc = L["desc_show_on_housing_catalog"],
                        width = "double",
                        order = 31,
                        get = function() return HA.Addon.db.profile.overlay.showOnHousingCatalog end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.showOnHousingCatalog = value
                            if HA.Overlay then HA.Overlay:RefreshAll() end
                        end,
                    },
                    showAccessibilityGlow = {
                        type = "toggle",
                        name = L["Show accessibility glow"],
                        desc = L["desc_accessibility_glow"],
                        width = "double",
                        order = 32,
                        get = function() return HA.Addon.db.profile.overlay.showAccessibilityGlow end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.showAccessibilityGlow = value
                            if HA.Overlay then HA.Overlay:RefreshAll() end
                        end,
                    },
                    ownedItemStyle = {
                        type = "select",
                        name = L["Owned item style"],
                        desc = L["desc_owned_item_style"],
                        width = "double",
                        order = 33,
                        values = {
                            default = L["Green highlight (default)"],
                            none = L["None"],
                            dim = L["Dimmed"],
                            checkmark = L["Checkmark"],
                        },
                        sorting = { "default", "none", "dim", "checkmark" },
                        get = function()
                            return HA.Addon.db.profile.overlay.ownedItemStyle or "default"
                        end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.ownedItemStyle = value
                            if HA.Overlay then HA.Overlay:RefreshAll() end
                        end,
                    },
                },
            },

            -- Tooltips Section
            tooltips = {
                type = "group",
                name = L["Tooltips"],
                order = 3,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable tooltip additions"],
                        desc = L["desc_enable_tooltips"],
                        width = "full",
                        order = 1,
                        get = function() return HA.Addon.db.profile.tooltip.enabled end,
                        set = function(_, value)
                            HA.Addon.db.profile.tooltip.enabled = value
                        end,
                    },
                    showOwned = {
                        type = "toggle",
                        name = L["Show ownership status"],
                        desc = L["desc_show_ownership"],
                        width = "double",
                        order = 2,
                        get = function() return HA.Addon.db.profile.tooltip.showOwned end,
                        set = function(_, value)
                            HA.Addon.db.profile.tooltip.showOwned = value
                        end,
                    },
                    showSource = {
                        type = "toggle",
                        name = L["Show source information"],
                        desc = L["desc_show_source"],
                        width = "double",
                        order = 3,
                        get = function() return HA.Addon.db.profile.tooltip.showSource end,
                        set = function(_, value)
                            HA.Addon.db.profile.tooltip.showSource = value
                        end,
                    },
                    showRequirements = {
                        type = "toggle",
                        name = L["Show requirements"],
                        desc = L["desc_show_requirements"],
                        width = "double",
                        order = 5,
                        get = function() return HA.Addon.db.profile.tooltip.showRequirements end,
                        set = function(_, value)
                            HA.Addon.db.profile.tooltip.showRequirements = value
                        end,
                    },
                    showAllSources = {
                        type = "toggle",
                        name = L["Show all sources"],
                        desc = L["desc_show_all_sources"],
                        width = "double",
                        order = 6,
                        get = function() return HA.Addon.db.profile.tooltip.showAllSources end,
                        set = function(_, value)
                            HA.Addon.db.profile.tooltip.showAllSources = value
                        end,
                    },

                    -- Map Pins
                    mapPinTooltipHeader = {
                        type = "header",
                        name = L["Map Pins"],
                        order = 10,
                    },
                    showVendorDetails = {
                        type = "toggle",
                        name = L["Show vendor details in tooltips"],
                        desc = L["desc_vendor_details"],
                        width = "double",
                        order = 11,
                        get = function() return HA.Addon.db.profile.vendorTracer.showVendorDetails end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showVendorDetails = value
                        end,
                    },
                },
            },

            -- World Map Section
            worldMap = {
                type = "group",
                name = L["World Map"],
                order = 4,
                args = {
                    showMapPins = {
                        type = "toggle",
                        name = L["Show map pins"],
                        desc = L["desc_show_map_pins"],
                        width = "full",
                        order = 1,
                        get = function() return HA.Addon.db.profile.vendorTracer.showMapPins end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showMapPins = value
                            if HA.VendorMapPins then
                                if value then
                                    HA.VendorMapPins:Enable()
                                else
                                    HA.VendorMapPins:Disable()
                                end
                            end
                        end,
                    },
                    showMapSidePanel = {
                        type = "toggle",
                        name = L["Show vendor panel on world map"],
                        desc = L["desc_show_map_side_panel"],
                        width = "full",
                        order = 2,
                        get = function() return HA.Addon.db.profile.vendorTracer.showMapSidePanel end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showMapSidePanel = value
                            if HA.MapSidePanel then
                                if value then
                                    HA.MapSidePanel:Show()
                                else
                                    HA.MapSidePanel:Hide()
                                end
                            end
                        end,
                    },
                    mapSidePanelSourceFilter = {
                        type = "select",
                        name = L["Vendor panel source filter"],
                        desc = L["desc_source_filter"],
                        width = "full",
                        order = 3,
                        values = {
                            all = L["All sources"],
                            vendor = L["Vendor"],
                            quest = L["Quest"],
                            achievement = L["Achievement"],
                            profession = L["Profession"],
                            event = L["Event"],
                            drop = L["Drop"],
                        },
                        sorting = { "all", "vendor", "quest", "achievement", "profession", "event", "drop" },
                        get = function()
                            return HA.Addon.db.profile.vendorTracer.mapSidePanelSourceFilter or "all"
                        end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.mapSidePanelSourceFilter = value
                            if HA.MapSidePanel and HA.MapSidePanel.SetSourceFilter then
                                HA.MapSidePanel:SetSourceFilter(value)
                            elseif HA.VendorMapPins and HA.VendorMapPins.InvalidateAllCaches then
                                -- Keep cache invalidation conservative when panel module isn't available yet.
                                HA.VendorMapPins:InvalidateAllCaches()
                            end
                        end,
                    },
                    integrateMapBorder = {
                        type = "toggle",
                        name = L["Integrate with map frame border"],
                        desc = L["desc_integrate_map_border"],
                        width = "full",
                        order = 4,
                        get = function() return HA.Addon.db.profile.vendorTracer.integrateMapBorder ~= false end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.integrateMapBorder = value
                            if HA.MapSidePanel then
                                HA.MapSidePanel:ResetIntegrationMode()
                                if HA.MapSidePanel:IsShown() then
                                    HA.MapSidePanel:Hide()
                                    HA.MapSidePanel:Show()
                                end
                            end
                        end,
                    },
                    worldMapZoneBadges = {
                        type = "toggle",
                        name = L["Zone badges on world map"],
                        desc = L["desc_zone_badges"],
                        width = "double",
                        order = 5,
                        get = function() return HA.Addon.db.profile.vendorTracer.worldMapZoneBadges end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.worldMapZoneBadges = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:InvalidateBadgeCache()
                                HA.VendorMapPins:RefreshPins()
                            end
                        end,
                    },
                    pinIconSize = {
                        type = "range",
                        name = L["World map pin size"],
                        desc = L["desc_world_pin_size"],
                        order = 6,
                        min = 8,
                        max = 18,
                        step = 2,
                        width = "double",
                        get = function()
                            return HA.PinFrameFactory:GetPinIconSize()
                        end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.pinIconSize = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:RefreshAllPinColors()
                            end
                        end,
                    },
                    showPinCounts = {
                        type = "toggle",
                        name = L["Show collection counts"],
                        desc = L["desc_show_pin_counts"],
                        width = "double",
                        order = 7,
                        get = function() return HA.Addon.db.profile.vendorTracer.showPinCounts ~= false end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showPinCounts = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:RefreshPins()
                            end
                        end,
                    },
                },
            },

            -- Minimap Section (replaces Vendor Tracer)
            minimap = {
                type = "group",
                name = L["Minimap"],
                order = 5,
                args = {
                    showMinimapPins = {
                        type = "toggle",
                        name = L["Show minimap pins"],
                        desc = L["desc_show_minimap_pins"],
                        width = "double",
                        order = 1,
                        get = function() return HA.Addon.db.profile.vendorTracer.showMinimapPins end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showMinimapPins = value
                            if HA.VendorMapPins then
                                if value then
                                    HA.VendorMapPins:EnableMinimapPins()
                                else
                                    HA.VendorMapPins:DisableMinimapPins()
                                end
                            end
                        end,
                    },
                    showElevationArrows = {
                        type = "toggle",
                        name = L["Show elevation arrows"],
                        desc = L["desc_elevation_arrows"],
                        width = "double",
                        order = 2,
                        get = function() return HA.Addon.db.profile.vendorTracer.showElevationArrows ~= false end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showElevationArrows = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:RequestMinimapRefresh("option_showElevationArrows")
                            end
                        end,
                    },
                    minimapCrossZoneMode = {
                        type = "select",
                        name = L["Minimap nearby-zone pins"],
                        desc = L["desc_cross_zone_mode"],
                        width = "double",
                        order = 3,
                        values = {
                            auto = L["Auto (recommended)"],
                            off = L["Current zone only"],
                            on = L["Always show nearby zones"],
                        },
                        get = function()
                            return HA.Addon.db.profile.vendorTracer.minimapCrossZoneMode or "auto"
                        end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.minimapCrossZoneMode = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:RequestMinimapRefresh("option_minimapCrossZoneMode")
                            end
                        end,
                    },
                    minimapIconSize = {
                        type = "range",
                        name = L["Minimap pin size"],
                        desc = L["desc_minimap_pin_size"],
                        order = 4,
                        min = 8,
                        max = 24,
                        step = 1,
                        width = "double",
                        get = function()
                            return HA.Addon.db.profile.vendorTracer.minimapIconSize or 12
                        end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.minimapIconSize = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:RequestMinimapRefresh("option_minimapIconSize")
                            end
                        end,
                    },

                    -- Waypoints
                    waypointHeader = {
                        type = "header",
                        name = L["Waypoints"],
                        order = 10,
                    },
                    waypointDesc = {
                        type = "description",
                        name = L["desc_waypoint_info"],
                        order = 11,
                    },
                    useTomTom = {
                        type = "toggle",
                        name = L["Use TomTom for waypoints"],
                        desc = L["desc_use_tomtom"],
                        width = "double",
                        order = 12,
                        get = function() return HA.Addon.db.profile.vendorTracer.useTomTom end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.useTomTom = value
                            if HA.Waypoints then
                                HA.Waypoints:UpdateConfig()
                            end
                        end,
                    },
                    useNativeWaypoints = {
                        type = "toggle",
                        name = L["Use native waypoints"],
                        desc = L["desc_use_native_waypoints"],
                        width = "double",
                        order = 13,
                        get = function() return HA.Addon.db.profile.vendorTracer.useNativeWaypoints end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.useNativeWaypoints = value
                            if HA.Waypoints then
                                HA.Waypoints:UpdateConfig()
                            end
                        end,
                    },
                    autoWaypoint = {
                        type = "toggle",
                        name = L["Auto-create waypoint on click"],
                        desc = L["desc_auto_waypoint"],
                        width = "double",
                        order = 14,
                        get = function() return HA.Addon.db.profile.vendorTracer.autoWaypoint end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.autoWaypoint = value
                        end,
                    },
                    navigateModifier = {
                        type = "select",
                        name = L["Navigate modifier key"],
                        desc = L["desc_navigate_modifier"],
                        values = {
                            shift = L["Shift"],
                            ctrl = L["Control"],
                            alt = L["Alt"],
                            none = L["None (always)"],
                        },
                        order = 15,
                        get = function() return HA.Addon.db.profile.vendorTracer.navigateModifier end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.navigateModifier = value
                        end,
                    },
                },
            },

            -- Endeavors Section
            endeavors = {
                type = "group",
                name = L["Endeavors"],
                order = 6,
                args = {
                    showMilestoneXP = {
                        type = "toggle",
                        name = L["Show milestone progress on dashboard"],
                        desc = L["desc_milestone_xp"],
                        width = "full",
                        order = 1,
                        get = function() return HA.Addon.db.profile.endeavors.showMilestoneXP end,
                        set = function(_, value)
                            HA.Addon.db.profile.endeavors.showMilestoneXP = value
                        end,
                    },
                },
            },

            -- Export Section
            export = {
                type = "group",
                name = L["Export"],
                order = 7,
                args = {
                    exportDesc = {
                        type = "description",
                        name = L["desc_export"],
                        order = 1,
                    },
                    exportNewButton = {
                        type = "execute",
                        name = L["Export New Scans"],
                        desc = L["desc_export_new"],
                        order = 2,
                        func = function()
                            if HA.ExportImport then
                                HA.ExportImport:ExportScannedVendors(false, false)
                            else
                                HA.Addon:Print(L["ExportImport not available."])
                            end
                        end,
                    },
                    exportAllButton = {
                        type = "execute",
                        name = L["Export All"],
                        desc = L["desc_export_all"],
                        order = 3,
                        func = function()
                            if HA.ExportImport then
                                HA.ExportImport:ExportScannedVendors(true, true)
                            else
                                HA.Addon:Print(L["ExportImport not available."])
                            end
                        end,
                    },
                },
            },
        },
    }

    return options
end

-------------------------------------------------------------------------------
-- Registration
-------------------------------------------------------------------------------

local function RegisterOptions()
    local AceConfig = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")

    -- Register main options
    AceConfig:RegisterOptionsTable(addonName, GetOptionsTable)

    -- Add to Blizzard options
    AceConfigDialog:AddToBlizOptions(addonName, "Homestead")

    HA.Addon:Debug("Options registered")
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

-- Register options when addon loads
if HA.Addon then
    C_Timer.After(0, RegisterOptions)
else
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", RegisterOptions)
end
