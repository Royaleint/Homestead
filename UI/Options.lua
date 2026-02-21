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
                name = L["General"] or "General",
                order = 1,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable addon"] or "Enable addon",
                        desc = "Enable or disable Homestead",
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
                        name = L["Show minimap button"] or "Show minimap button",
                        desc = "Show or hide the minimap button",
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
                        name = "Auto-scan vendors",
                        desc = "Automatically scan merchant inventory for housing decor data when visiting vendors. Community data helps improve the addon's vendor database. Disabling may slightly improve performance when opening merchants.",
                        width = "full",
                        order = 3,
                        get = function() return HA.Addon.db.profile.vendorScanning.enabled end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorScanning.enabled = value
                        end,
                    },
                },
            },

            -- Overlays Section
            overlays = {
                type = "group",
                name = L["Overlays"] or "Overlays",
                order = 2,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable overlays"] or "Enable overlays",
                        desc = "Show collection status icons on items",
                        width = "full",
                        order = 1,
                        get = function() return HA.Addon.db.profile.overlay.enabled end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.enabled = value
                            if HA.Overlay then HA.Overlay:RefreshAll() end
                        end,
                    },
                    spacer1 = {
                        type = "description",
                        name = " ",
                        order = 2,
                    },
                    showOnBags = {
                        type = "toggle",
                        name = L["Show on bags"] or "Show on bags",
                        desc = "Show overlay icons on bag items",
                        order = 3,
                        get = function() return HA.Addon.db.profile.overlay.showOnBags end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.showOnBags = value
                            if HA.Overlay then HA.Overlay:RefreshAll() end
                        end,
                    },
                    showOnBank = {
                        type = "toggle",
                        name = L["Show on bank"] or "Show on bank",
                        desc = "Show overlay icons on bank items",
                        order = 4,
                        get = function() return HA.Addon.db.profile.overlay.showOnBank end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.showOnBank = value
                            if HA.Overlay then HA.Overlay:RefreshAll() end
                        end,
                    },
                    showOnMerchant = {
                        type = "toggle",
                        name = L["Show on merchant"] or "Show on merchant",
                        desc = "Show overlay icons on vendor items",
                        order = 5,
                        get = function() return HA.Addon.db.profile.overlay.showOnMerchant end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.showOnMerchant = value
                            if HA.Overlay then HA.Overlay:RefreshAll() end
                        end,
                    },
                    showOnAuctionHouse = {
                        type = "toggle",
                        name = L["Show on auction house"] or "Show on auction house",
                        desc = "Show overlay icons on auction house items",
                        width = "double",
                        order = 6,
                        get = function() return HA.Addon.db.profile.overlay.showOnAuctionHouse end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.showOnAuctionHouse = value
                            if HA.Overlay then HA.Overlay:RefreshAll() end
                        end,
                    },
                    showOnHousingCatalog = {
                        type = "toggle",
                        name = L["Show on housing catalog"] or "Show on housing catalog",
                        desc = "Show overlay icons on housing catalog items",
                        width = "double",
                        order = 7,
                        get = function() return HA.Addon.db.profile.overlay.showOnHousingCatalog end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.showOnHousingCatalog = value
                            if HA.Overlay then HA.Overlay:RefreshAll() end
                        end,
                    },
                    spacer2 = {
                        type = "description",
                        name = " ",
                        order = 8,
                    },
                    iconSize = {
                        type = "range",
                        name = L["Icon size"] or "Icon size",
                        desc = "Size of the overlay icons",
                        min = 8,
                        max = 32,
                        step = 1,
                        order = 9,
                        get = function() return HA.Addon.db.profile.overlay.iconSize end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.iconSize = value
                            if HA.Overlay then HA.Overlay:UpdateConfig() end
                        end,
                    },
                    iconAnchor = {
                        type = "select",
                        name = L["Icon position"] or "Icon position",
                        desc = "Position of the overlay icon on items",
                        values = {
                            TOPLEFT = "Top Left",
                            TOPRIGHT = "Top Right",
                            BOTTOMLEFT = "Bottom Left",
                            BOTTOMRIGHT = "Bottom Right",
                            CENTER = "Center",
                        },
                        order = 10,
                        get = function() return HA.Addon.db.profile.overlay.iconAnchor end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.iconAnchor = value
                            if HA.Overlay then HA.Overlay:UpdateConfig() end
                        end,
                    },
                },
            },

            -- Tooltips Section
            tooltips = {
                type = "group",
                name = L["Tooltips"] or "Tooltips",
                order = 3,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable tooltip additions"] or "Enable tooltip additions",
                        desc = "Add collection status to item tooltips",
                        width = "full",
                        order = 1,
                        get = function() return HA.Addon.db.profile.tooltip.enabled end,
                        set = function(_, value)
                            HA.Addon.db.profile.tooltip.enabled = value
                        end,
                    },
                    showSource = {
                        type = "toggle",
                        name = L["Show source information"] or "Show source information",
                        desc = "Show where to obtain uncollected items",
                        width = "double",
                        order = 2,
                        get = function() return HA.Addon.db.profile.tooltip.showSource end,
                        set = function(_, value)
                            HA.Addon.db.profile.tooltip.showSource = value
                        end,
                    },
                    showQuantity = {
                        type = "toggle",
                        name = L["Show quantity owned"] or "Show quantity owned",
                        desc = "Show how many of this item you own",
                        order = 3,
                        get = function() return HA.Addon.db.profile.tooltip.showQuantity end,
                        set = function(_, value)
                            HA.Addon.db.profile.tooltip.showQuantity = value
                        end,
                    },
                    showDyeSlots = {
                        type = "toggle",
                        name = L["Show dye slot information"] or "Show dye slot information",
                        desc = "Show if item can be dyed and how many dye slots",
                        width = "double",
                        order = 4,
                        get = function() return HA.Addon.db.profile.tooltip.showDyeSlots end,
                        set = function(_, value)
                            HA.Addon.db.profile.tooltip.showDyeSlots = value
                        end,
                    },
                    showRequirements = {
                        type = "toggle",
                        name = "Show requirements",
                        desc = "Show acquisition requirements (reputation, quest, etc.) in tooltips",
                        width = "double",
                        order = 5,
                        get = function() return HA.Addon.db.profile.tooltip.showRequirements end,
                        set = function(_, value)
                            HA.Addon.db.profile.tooltip.showRequirements = value
                        end,
                    },
                },
            },

            -- World Map Section
            worldMap = {
                type = "group",
                name = "World Map",
                order = 4,
                args = {
                    -- World Map Pins
                    mapPinsHeader = {
                        type = "header",
                        name = "World Map Pins",
                        order = 1,
                    },
                    showMapPins = {
                        type = "toggle",
                        name = L["Show map pins"] or "Show map pins",
                        desc = "Show vendor locations on the world map",
                        width = "full",
                        order = 2,
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
                        name = "Show vendor panel on world map",
                        desc = "Show a side panel on the world map listing vendors and collection progress for the current zone",
                        width = "full",
                        order = 3,
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
                    integrateMapBorder = {
                        type = "toggle",
                        name = "Integrate with map frame border",
                        desc = "Merge the panel's top border with the world map border for a seamless look. Disable if you use a custom UI (ElvUI, GW2, etc.) that conflicts.",
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
                        name = "Zone badges on world map",
                        desc = "Show per-zone vendor counts spread across continents on the world map, instead of a single total per continent.",
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

                    -- Minimap
                    minimapHeader = {
                        type = "header",
                        name = "Minimap",
                        order = 6,
                    },
                    showMinimapPins = {
                        type = "toggle",
                        name = L["Show minimap pins"] or "Show minimap pins",
                        desc = "Show vendor locations on the minimap with elevation arrows",
                        width = "double",
                        order = 7,
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
                        name = "Show elevation arrows",
                        desc = "Show directional arrows on minimap pins when a vendor is above or below you",
                        width = "double",
                        order = 8,
                        get = function() return HA.Addon.db.profile.vendorTracer.showElevationArrows ~= false end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showElevationArrows = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:RefreshMinimapPins()
                            end
                        end,
                    },

                    -- Vendor Visibility
                    vendorVisibilityHeader = {
                        type = "header",
                        name = "Vendor Visibility",
                        order = 9,
                    },
                    showOppositeFaction = {
                        type = "toggle",
                        name = L["Show opposite faction vendors"] or "Show opposite faction vendors",
                        desc = "Show vendors for the opposite faction with their faction emblem. Useful for completionists to see all available vendors.",
                        width = "double",
                        order = 10,
                        get = function() return HA.Addon.db.profile.vendorTracer.showOppositeFaction end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showOppositeFaction = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:InvalidateBadgeCache()
                                HA.VendorMapPins:RefreshPins()
                            end
                        end,
                    },
                    showUnverifiedVendors = {
                        type = "toggle",
                        name = L["Show unverified vendors"] or "Show unverified vendors",
                        desc = "Show vendors with unverified locations (orange pins). These are imported from external sources and may have incorrect coordinates. Visit these vendors in-game to verify their location.",
                        width = "double",
                        order = 11,
                        get = function() return HA.Addon.db.profile.vendorTracer.showUnverifiedVendors == true end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showUnverifiedVendors = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:InvalidateBadgeCache()
                                HA.VendorMapPins:RefreshPins()
                                HA.VendorMapPins:RefreshMinimapPins()
                            end
                        end,
                    },
                    showEventVendors = {
                        type = "toggle",
                        name = "Show event vendors",
                        desc = "Show seasonal holiday vendor pins on the map when their event is active (e.g., Lunar Festival)",
                        width = "double",
                        order = 12,
                        get = function() return HA.Addon.db.profile.vendorTracer.showEventVendors ~= false end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showEventVendors = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:InvalidateBadgeCache()
                                HA.VendorMapPins:RefreshPins()
                                HA.VendorMapPins:RefreshMinimapPins()
                            end
                        end,
                    },

                    -- Pin Appearance
                    pinAppearanceHeader = {
                        type = "header",
                        name = "Pin Appearance",
                        order = 13,
                    },
                    pinColorPreset = {
                        type = "select",
                        name = "Pin color",
                        desc = "Choose a color for map and minimap pins. Unverified pins always show orange.",
                        order = 14,
                        values = {
                            default   = "Default (Gold)",
                            green     = "Bright Green",
                            blue      = "Ice Blue",
                            lightblue = "Light Blue",
                            purple    = "Purple",
                            pink      = "Pink",
                            red       = "Red",
                            cyan      = "Cyan",
                            white     = "White",
                            yellow    = "Yellow",
                            custom    = "Custom...",
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
                        name = "Custom color",
                        desc = "Pick a custom base color for map pins",
                        order = 15,
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
                        name = function()
                            local hex = "f2d173" -- fallback gold
                            if HA.VendorMapPins and HA.VendorMapPins.GetPinColorPreviewHex then
                                hex = HA.VendorMapPins:GetPinColorPreviewHex()
                            end
                            return string.format(
                                "|cff%s\226\150\136\226\150\136\226\150\136\226\150\136\226\150\136\226\150\136\226\150\136\226\150\136|r  Approximate map appearance",
                                hex
                            )
                        end,
                        order = 16,
                        width = "double",
                    },
                    pinIconSize = {
                        type = "range",
                        name = "World map pin size",
                        desc = "Adjust the size of vendor pins on the world map. Default (20) matches Blizzard POI icons.",
                        order = 17,
                        min = 12,
                        max = 32,
                        step = 2,
                        width = "double",
                        get = function()
                            return HA.Addon.db.profile.vendorTracer.pinIconSize or 20
                        end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.pinIconSize = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:RefreshAllPinColors()
                            end
                        end,
                    },
                    minimapIconSize = {
                        type = "range",
                        name = "Minimap pin size",
                        desc = "Adjust the size of vendor pins on the minimap. Increase if pins are hard to see, or decrease to reduce minimap clutter.",
                        order = 18,
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
                                HA.VendorMapPins:RefreshMinimapPins()
                            end
                        end,
                    },
                    showPinCounts = {
                        type = "toggle",
                        name = "Show collection counts",
                        desc = "Display collected/total item counts on vendor pins (e.g., 3/12). Disable to reduce map clutter.",
                        width = "double",
                        order = 19,
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

            -- Vendor Tracer Section
            vendorTracer = {
                type = "group",
                name = L["Vendor Tracer"] or "Vendor Tracer",
                order = 5,
                args = {
                    -- Vendor Details
                    vendorDetailsHeader = {
                        type = "header",
                        name = "Vendor Details",
                        order = 1,
                    },
                    showVendorDetails = {
                        type = "toggle",
                        name = L["Show vendor details in tooltips"] or "Show vendor details in tooltips",
                        desc = "Show items sold and collection status when hovering over map pins",
                        width = "double",
                        order = 2,
                        get = function() return HA.Addon.db.profile.vendorTracer.showVendorDetails end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showVendorDetails = value
                        end,
                    },

                    -- Waypoints
                    waypointHeader = {
                        type = "header",
                        name = "Waypoints",
                        order = 3,
                    },
                    waypointDesc = {
                        type = "description",
                        name = "TomTom shows a directional arrow overlay and requires the TomTom addon to be installed. Native adds a destination pin to the world map. Both can be active at the same time.",
                        order = 4,
                    },
                    useTomTom = {
                        type = "toggle",
                        name = L["Use TomTom for waypoints"] or "Use TomTom for waypoints",
                        desc = "Use TomTom addon for waypoint arrows (if installed)",
                        width = "double",
                        order = 5,
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
                        name = L["Use native waypoints"] or "Use native waypoints",
                        desc = "Use WoW's built-in waypoint system with map pin",
                        width = "double",
                        order = 6,
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
                        name = L["Auto-create waypoint on click"] or "Auto-create waypoint on click",
                        desc = "Automatically create a waypoint when clicking on a vendor in the list or map",
                        width = "double",
                        order = 7,
                        get = function() return HA.Addon.db.profile.vendorTracer.autoWaypoint end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.autoWaypoint = value
                        end,
                    },
                    navigateModifier = {
                        type = "select",
                        name = L["Navigate modifier key"] or "Navigate modifier key",
                        desc = "Hold this key when clicking to create a waypoint (if auto-waypoint is off)",
                        values = {
                            shift = "Shift",
                            ctrl = "Control",
                            alt = "Alt",
                            none = "None (always)",
                        },
                        order = 8,
                        get = function() return HA.Addon.db.profile.vendorTracer.navigateModifier end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.navigateModifier = value
                        end,
                    },

                    -- Vendor Arrival
                    popupHeader = {
                        type = "header",
                        name = "Vendor Arrival",
                        order = 9,
                    },
                    showMissingAtVendor = {
                        type = "toggle",
                        name = L["Show missing items at vendor"] or "Show missing items at vendor",
                        desc = "Show a popup when visiting a vendor listing decor items you haven't collected",
                        width = "full",
                        order = 10,
                        get = function() return HA.Addon.db.profile.vendorTracer.showMissingAtVendor end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showMissingAtVendor = value
                        end,
                    },
                },
            },

            -- Export Section
            export = {
                type = "group",
                name = L["Export"] or "Export",
                order = 6,
                args = {
                    exportDesc = {
                        type = "description",
                        name = "Export scanned vendor data for community sharing or backup.",
                        order = 1,
                    },
                    exportNewButton = {
                        type = "execute",
                        name = "Export New Scans",
                        desc = "Exports vendors scanned since your last export. Includes price, currencies, faction, and catalog info.",
                        order = 2,
                        func = function()
                            if HA.ExportImport then
                                HA.ExportImport:ExportScannedVendors(false, false)
                            else
                                HA.Addon:Print("ExportImport not available.")
                            end
                        end,
                    },
                    exportAllButton = {
                        type = "execute",
                        name = "Export All",
                        desc = "Exports all scanned vendors, bypassing the timestamp filter.",
                        order = 3,
                        func = function()
                            if HA.ExportImport then
                                HA.ExportImport:ExportScannedVendors(true, true)
                            else
                                HA.Addon:Print("ExportImport not available.")
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
