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

                    -- Vendor Visibility
                    vendorVisibilityHeader = {
                        type = "header",
                        name = "Vendor Visibility",
                        order = 10,
                    },
                    showOppositeFaction = {
                        type = "toggle",
                        name = L["Show opposite faction vendors"] or "Show opposite faction vendors",
                        desc = "Show vendors for the opposite faction with their faction emblem. Useful for completionists to see all available vendors.",
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
                    showUnverifiedVendors = {
                        type = "toggle",
                        name = L["Show unverified vendors"] or "Show unverified vendors",
                        desc = "Show vendors with unverified locations (orange pins). These are imported from external sources and may have incorrect coordinates. Visit these vendors in-game to verify their location.",
                        width = "double",
                        order = 12,
                        get = function() return HA.Addon.db.profile.vendorTracer.showUnverifiedVendors == true end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showUnverifiedVendors = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:InvalidateBadgeCache()
                                HA.VendorMapPins:RefreshPins()
                                HA.VendorMapPins:RequestMinimapRefresh("option_showUnverifiedVendors")
                            end
                        end,
                    },
                    showEventVendors = {
                        type = "toggle",
                        name = "Show event vendors",
                        desc = "Show seasonal holiday vendor pins on the map when their event is active (e.g., Lunar Festival)",
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
                        name = "Pin Appearance",
                        order = 20,
                    },
                    pinColorPreset = {
                        type = "select",
                        name = "Pin color",
                        desc = "Choose a color for map and minimap pins. Unverified pins always show orange.",
                        order = 21,
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
                        order = 23,
                        width = "double",
                    },
                },
            },

            -- Overlays Section
            overlays = {
                type = "group",
                name = L["Overlays"] or "Overlays",
                order = 2,
                args = {
                    -- Master toggle
                    enabled = {
                        type = "toggle",
                        name = L["Enable overlays"] or "Enable overlays",
                        desc = "Add small icons and highlights to decor items throughout the game so you can tell at a glance which ones you've collected. Turning this off hides all Homestead overlays everywhere.",
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
                        name = L["Icon size"] or "Icon size",
                        desc = "Controls how large the collection icons appear on item slots.",
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
                        name = L["Icon position"] or "Icon position",
                        desc = "Which corner of the item slot the collection icon sits in.",
                        values = {
                            TOPLEFT = "Top Left",
                            TOPRIGHT = "Top Right",
                            BOTTOMLEFT = "Bottom Left",
                            BOTTOMRIGHT = "Bottom Right",
                            CENTER = "Center",
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
                        name = "Inventory",
                        order = 10,
                    },
                    showOnBags = {
                        type = "toggle",
                        name = L["Show on bags"] or "Show on bags",
                        desc = "Adds a |TInterface\\RaidFrame\\ReadyCheck-Ready:16|t to decor items in your bags that you've already collected. Works with default bags, Baganator, and BetterBags.",
                        order = 11,
                        get = function() return HA.Addon.db.profile.overlay.showOnBags end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.showOnBags = value
                            if HA.Overlay then HA.Overlay:RefreshAll() end
                        end,
                    },
                    showOnBank = {
                        type = "toggle",
                        name = L["Show on bank"] or "Show on bank",
                        desc = "Mark decor items in your bank so you can see which ones you've already collected.",
                        order = 12,
                        get = function() return HA.Addon.db.profile.overlay.showOnBank end,
                        set = function(_, value)
                            HA.Addon.db.profile.overlay.showOnBank = value
                            if HA.Overlay then HA.Overlay:RefreshAll() end
                        end,
                    },
                    showOnAuctionHouse = {
                        type = "toggle",
                        name = L["Show on auction house"] or "Show on auction house",
                        desc = "Mark decor items on the auction house so you can avoid buying duplicates.",
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
                        name = "Merchant",
                        order = 20,
                    },
                    showOnMerchant = {
                        type = "toggle",
                        name = L["Show on merchant"] or "Show on merchant",
                        desc = "Adds a |TInterface\\RaidFrame\\ReadyCheck-Ready:16|t to decor items at vendors that you've already collected.",
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
                        name = "Housing Catalog",
                        order = 30,
                    },
                    showOnHousingCatalog = {
                        type = "toggle",
                        name = L["Show on housing catalog"] or "Show on housing catalog",
                        desc = "Mark items in the Housing Catalog with collection icons showing where each item comes from.\n\n"
                            .. "|A:auctionhouse-icon-coin-gold:16:16|a Vendor\n"
                            .. "|A:QuestNormal:16:16|a Quest\n"
                            .. "|A:UI-Achievement-Shield-NoPoints:16:16|a Achievement\n"
                            .. "|A:UI-HUD-MicroMenu-Professions-Mouseover:16:16|a Profession\n"
                            .. "|A:UI-HUD-Calendar-1-Up:16:16|a Event\n"
                            .. "|A:Crosshair_lootall_64:16:16|a Drop\n"
                            .. "|A:hearthsteel-icon-32x32:16:16|a Battle.net Shop",
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
                        name = "Show accessibility glow",
                        desc = "Add a colored border glow to Housing Catalog items: green for owned, yellow for items you can get, and red for items that are locked behind requirements you haven't met yet.",
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
                        name = "Owned item style",
                        desc = "Choose how collected items look in the Housing Catalog. Green highlight shows the default glow, Dimmed fades them out, and Checkmark adds a small green check. Pick None to leave them untouched.",
                        width = "double",
                        order = 33,
                        values = {
                            default = "Green highlight (default)",
                            none = "None",
                            dim = "Dimmed",
                            checkmark = "Checkmark",
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
                name = L["Tooltips"] or "Tooltips",
                order = 3,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable tooltip additions"] or "Enable tooltip additions",
                        desc = "Add Homestead information to item tooltips when you hover over decor items. Turning this off removes all tooltip additions.",
                        width = "full",
                        order = 1,
                        get = function() return HA.Addon.db.profile.tooltip.enabled end,
                        set = function(_, value)
                            HA.Addon.db.profile.tooltip.enabled = value
                        end,
                    },
                    showOwned = {
                        type = "toggle",
                        name = "Show ownership status",
                        desc = "Add a line to tooltips showing whether you've already collected a decor item.",
                        width = "double",
                        order = 2,
                        get = function() return HA.Addon.db.profile.tooltip.showOwned end,
                        set = function(_, value)
                            HA.Addon.db.profile.tooltip.showOwned = value
                        end,
                    },
                    showSource = {
                        type = "toggle",
                        name = L["Show source information"] or "Show source information",
                        desc = "Show how to obtain a decor item — vendors, quests, achievements, professions, events, and drops.",
                        width = "double",
                        order = 3,
                        get = function() return HA.Addon.db.profile.tooltip.showSource end,
                        set = function(_, value)
                            HA.Addon.db.profile.tooltip.showSource = value
                        end,
                    },
                    showQuantity = {
                        type = "toggle",
                        name = L["Show quantity owned"] or "Show quantity owned",
                        desc = "Display how many copies of a decor item you currently own.",
                        order = 4,
                        get = function() return HA.Addon.db.profile.tooltip.showQuantity end,
                        set = function(_, value)
                            HA.Addon.db.profile.tooltip.showQuantity = value
                        end,
                    },
                    showRequirements = {
                        type = "toggle",
                        name = "Show requirements",
                        desc = "Display purchase requirements like reputation, quest completion, or achievements needed to buy an item.",
                        width = "double",
                        order = 5,
                        get = function() return HA.Addon.db.profile.tooltip.showRequirements end,
                        set = function(_, value)
                            HA.Addon.db.profile.tooltip.showRequirements = value
                        end,
                    },
                    showAllSources = {
                        type = "toggle",
                        name = "Show all sources",
                        desc = "List every known way to obtain an item instead of just the best available source. Helpful when an item can be acquired from multiple vendors, quests, or other sources.",
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
                        name = "Map Pins",
                        order = 10,
                    },
                    showVendorDetails = {
                        type = "toggle",
                        name = L["Show vendor details in tooltips"] or "Show vendor details in tooltips",
                        desc = "Show a vendor's full inventory and your collection progress when hovering over their map pin. Disable for a simpler tooltip with just the vendor name.",
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
                name = "World Map",
                order = 4,
                args = {
                    showMapPins = {
                        type = "toggle",
                        name = L["Show map pins"] or "Show map pins",
                        desc = "Show vendor locations on the world map",
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
                        name = "Show vendor panel on world map",
                        desc = "Show a side panel on the world map listing vendors and collection progress for the current zone",
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
                        name = "Vendor panel source filter",
                        desc = "Filter side-panel item counts and expanded grids by acquisition source. Vendor visibility on the map is unchanged.",
                        width = "full",
                        order = 3,
                        values = {
                            all = "All sources",
                            vendor = "Vendor",
                            quest = "Quest",
                            achievement = "Achievement",
                            profession = "Profession",
                            event = "Event",
                            drop = "Drop",
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
                    pinIconSize = {
                        type = "range",
                        name = "World map pin size",
                        desc = "Adjust the size of vendor pins on the world map. Default is 14.",
                        order = 6,
                        min = 2,
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
                        name = "Show collection counts",
                        desc = "Display collected/total item counts on vendor pins (e.g., 3/12). Disable to reduce map clutter.",
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
                name = "Minimap",
                order = 5,
                args = {
                    showMinimapPins = {
                        type = "toggle",
                        name = L["Show minimap pins"] or "Show minimap pins",
                        desc = "Show vendor locations on the minimap with elevation arrows",
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
                        name = "Show elevation arrows",
                        desc = "Show directional arrows on minimap pins when a vendor is above or below you",
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
                        name = "Minimap nearby-zone pins",
                        desc = "Controls cross-zone minimap pins. Auto reduces extra pins in dense city zones for smoother movement.",
                        width = "double",
                        order = 3,
                        values = {
                            auto = "Auto (recommended)",
                            off = "Current zone only",
                            on = "Always show nearby zones",
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
                        name = "Minimap pin size",
                        desc = "Adjust the size of vendor pins on the minimap. Increase if pins are hard to see, or decrease to reduce minimap clutter.",
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
                        name = "Waypoints",
                        order = 10,
                    },
                    waypointDesc = {
                        type = "description",
                        name = "TomTom shows a directional arrow overlay and requires the TomTom addon to be installed. Native adds a destination pin to the world map. Both can be active at the same time.",
                        order = 11,
                    },
                    useTomTom = {
                        type = "toggle",
                        name = L["Use TomTom for waypoints"] or "Use TomTom for waypoints",
                        desc = "Use TomTom addon for waypoint arrows (if installed)",
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
                        name = L["Use native waypoints"] or "Use native waypoints",
                        desc = "Use WoW's built-in waypoint system with map pin",
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
                        name = L["Auto-create waypoint on click"] or "Auto-create waypoint on click",
                        desc = "Automatically create a waypoint when clicking on a vendor in the list or map",
                        width = "double",
                        order = 14,
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
                name = "Endeavors",
                order = 6,
                args = {
                    showMilestoneXP = {
                        type = "toggle",
                        name = "Show milestone progress on dashboard",
                        desc = "Display next milestone XP progress on Blizzard's Housing Dashboard Endeavors tab. Disable if you use another addon for this (e.g., Endeavor Simple Progress Tracker).",
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
                name = L["Export"] or "Export",
                order = 7,
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
