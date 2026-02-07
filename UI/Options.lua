--[[
    Homestead - Options Panel
    Configuration UI using AceConfig
]]

local addonName, HA = ...

-- Local references
local Constants = HA.Constants
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
                },
            },

            -- Vendor Tracer Section
            vendorTracer = {
                type = "group",
                name = L["Vendor Tracer"] or "Vendor Tracer",
                order = 4,
                args = {
                    -- Map Pins Group
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
                    showMinimapPins = {
                        type = "toggle",
                        name = L["Show minimap pins"] or "Show minimap pins",
                        desc = "Show vendor locations on the minimap with elevation arrows",
                        width = "double",
                        order = 3,
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
                    showVendorDetails = {
                        type = "toggle",
                        name = L["Show vendor details in tooltips"] or "Show vendor details in tooltips",
                        desc = "Show items sold and collection status when hovering over map pins",
                        width = "double",
                        order = 4,
                        get = function() return HA.Addon.db.profile.vendorTracer.showVendorDetails end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showVendorDetails = value
                        end,
                    },
                    showOppositeFaction = {
                        type = "toggle",
                        name = L["Show opposite faction vendors"] or "Show opposite faction vendors",
                        desc = "Show vendors for the opposite faction with their faction emblem. Useful for completionists to see all available vendors.",
                        width = "double",
                        order = 5,
                        get = function() return HA.Addon.db.profile.vendorTracer.showOppositeFaction end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showOppositeFaction = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:RefreshPins()
                            end
                        end,
                    },
                    showUnverifiedVendors = {
                        type = "toggle",
                        name = L["Show unverified vendors"] or "Show unverified vendors",
                        desc = "Show vendors with unverified locations (orange pins). These are imported from external sources and may have incorrect coordinates. Visit these vendors in-game to verify their location.",
                        width = "double",
                        order = 6,
                        get = function() return HA.Addon.db.profile.vendorTracer.showUnverifiedVendors == true end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showUnverifiedVendors = value
                            if HA.VendorMapPins then
                                HA.VendorMapPins:RefreshPins()
                                HA.VendorMapPins:RefreshMinimapPins()
                            end
                        end,
                    },

                    -- Waypoint Group
                    waypointHeader = {
                        type = "header",
                        name = "Waypoints",
                        order = 10,
                    },
                    useTomTom = {
                        type = "toggle",
                        name = L["Use TomTom for waypoints"] or "Use TomTom for waypoints",
                        desc = "Use TomTom addon for waypoint arrows (if installed)",
                        width = "double",
                        order = 11,
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
                        order = 12,
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
                        order = 13,
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
                        order = 14,
                        get = function() return HA.Addon.db.profile.vendorTracer.navigateModifier end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.navigateModifier = value
                        end,
                    },

                    -- Vendor Popup Group
                    popupHeader = {
                        type = "header",
                        name = "Vendor Arrival",
                        order = 20,
                    },
                    showMissingAtVendor = {
                        type = "toggle",
                        name = L["Show missing items at vendor"] or "Show missing items at vendor",
                        desc = "Show a popup when visiting a vendor listing decor items you haven't collected",
                        width = "full",
                        order = 21,
                        get = function() return HA.Addon.db.profile.vendorTracer.showMissingAtVendor end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showMissingAtVendor = value
                        end,
                    },
                },
            },

            -- Endeavours Section
            endeavours = {
                type = "group",
                name = L["Endeavours"] or "Endeavours",
                order = 5,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Enable endeavour tracking",
                        desc = "Track housing endeavour progress",
                        width = "full",
                        order = 1,
                        get = function() return HA.Addon.db.profile.endeavourTracker.enabled end,
                        set = function(_, value)
                            HA.Addon.db.profile.endeavourTracker.enabled = value
                        end,
                    },
                    showProgress = {
                        type = "toggle",
                        name = "Show progress indicators",
                        desc = "Show endeavour progress on UI",
                        order = 2,
                        get = function() return HA.Addon.db.profile.endeavourTracker.showProgress end,
                        set = function(_, value)
                            HA.Addon.db.profile.endeavourTracker.showProgress = value
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
                    desc = {
                        type = "description",
                        name = "Configure what data to include when exporting collection data.",
                        order = 1,
                    },
                    includeCharacterInfo = {
                        type = "toggle",
                        name = L["Character Info"] or "Character Info",
                        desc = "Include character name, realm, faction, class",
                        order = 2,
                        get = function() return HA.Addon.db.profile.export.includeCharacterInfo end,
                        set = function(_, value)
                            HA.Addon.db.profile.export.includeCharacterInfo = value
                        end,
                    },
                    includeDecorList = {
                        type = "toggle",
                        name = L["Decor Collection"] or "Decor Collection",
                        desc = "Include list of collected decor items",
                        order = 3,
                        get = function() return HA.Addon.db.profile.export.includeDecorList end,
                        set = function(_, value)
                            HA.Addon.db.profile.export.includeDecorList = value
                        end,
                    },
                    includeDyeList = {
                        type = "toggle",
                        name = L["Dye Collection"] or "Dye Collection",
                        desc = "Include list of owned dyes and known recipes",
                        order = 4,
                        get = function() return HA.Addon.db.profile.export.includeDyeList end,
                        set = function(_, value)
                            HA.Addon.db.profile.export.includeDyeList = value
                        end,
                    },
                    includeEndeavours = {
                        type = "toggle",
                        name = L["Endeavour Progress"] or "Endeavour Progress",
                        desc = "Include endeavour completion status",
                        order = 5,
                        get = function() return HA.Addon.db.profile.export.includeEndeavours end,
                        set = function(_, value)
                            HA.Addon.db.profile.export.includeEndeavours = value
                        end,
                    },
                    includeVendorsVisited = {
                        type = "toggle",
                        name = L["Vendors Visited"] or "Vendors Visited",
                        desc = "Include list of visited decor vendors",
                        order = 6,
                        get = function() return HA.Addon.db.profile.export.includeVendorsVisited end,
                        set = function(_, value)
                            HA.Addon.db.profile.export.includeVendorsVisited = value
                        end,
                    },
                    spacer = {
                        type = "description",
                        name = " ",
                        order = 7,
                    },
                    exportButton = {
                        type = "execute",
                        name = L["Export Collection Data"] or "Export Collection Data",
                        desc = "Export your collection data to clipboard",
                        order = 8,
                        func = function()
                            if HA.Addon.ExportData then
                                HA.Addon:ExportData()
                            else
                                HA.Addon:Print("Export feature not yet implemented")
                            end
                        end,
                    },
                },
            },

            -- Actions Section (quick access to common operations)
            actions = {
                type = "group",
                name = L["Actions"] or "Actions",
                order = 7,
                args = {
                    actionsDesc = {
                        type = "description",
                        name = "Quick access to common addon operations.",
                        order = 1,
                    },
                    spacer1 = {
                        type = "description",
                        name = " ",
                        order = 2,
                    },
                    scanCollectionButton = {
                        type = "execute",
                        name = "Scan Collection",
                        desc = "Scan your housing catalog for owned items and update the ownership cache",
                        order = 3,
                        func = function()
                            if HA.CatalogScanner and HA.CatalogScanner.ManualScan then
                                HA.CatalogScanner:ManualScan()
                            else
                                HA.Addon:Print("CatalogScanner not available.")
                            end
                        end,
                    },
                    refreshMapButton = {
                        type = "execute",
                        name = "Refresh Map Pins",
                        desc = "Refresh all world map and minimap vendor pins",
                        order = 4,
                        func = function()
                            if HA.VendorMapPins then
                                HA.VendorMapPins:RefreshPins()
                                HA.VendorMapPins:RefreshMinimapPins()
                                HA.Addon:Print("Map pins refreshed.")
                            else
                                HA.Addon:Print("VendorMapPins not available.")
                            end
                        end,
                    },
                    spacer2 = {
                        type = "description",
                        name = " ",
                        order = 5,
                    },
                    dataHeader = {
                        type = "header",
                        name = "Data Management",
                        order = 6,
                    },
                    exportDataButton = {
                        type = "execute",
                        name = "Export Vendor Data",
                        desc = "Export scanned vendor data for sharing or backup",
                        order = 7,
                        func = function()
                            if HA.ExportImport and HA.ExportImport.ExportScannedVendors then
                                HA.ExportImport:ExportScannedVendors()
                            else
                                HA.Addon:Print("ExportImport not available.")
                            end
                        end,
                    },
                    importDataButton = {
                        type = "execute",
                        name = "Import Vendor Data",
                        desc = "Import vendor data from another source",
                        order = 8,
                        func = function()
                            if HA.ExportImport and HA.ExportImport.ShowImportDialog then
                                HA.ExportImport:ShowImportDialog()
                            else
                                HA.Addon:Print("ExportImport not available.")
                            end
                        end,
                    },
                    validateDbButton = {
                        type = "execute",
                        name = "Validate Database",
                        desc = "Run validation checks on the vendor database",
                        order = 9,
                        func = function()
                            if HA.Validation and HA.Validation.RunFullValidation then
                                HA.Validation:RunFullValidation()
                            else
                                HA.Addon:Print("Validation not available.")
                            end
                        end,
                    },
                    spacer3 = {
                        type = "description",
                        name = " ",
                        order = 10,
                    },
                    cacheHeader = {
                        type = "header",
                        name = "Cache Management",
                        order = 11,
                    },
                    showCacheButton = {
                        type = "execute",
                        name = "Show Ownership Cache",
                        desc = "Display the ownership cache contents",
                        order = 12,
                        func = function()
                            if HA.Addon.ShowCacheInfo then
                                HA.Addon:ShowCacheInfo()
                            end
                        end,
                    },
                    clearCacheButton = {
                        type = "execute",
                        name = "|cffff9900Clear Ownership Cache|r",
                        desc = "Clear the cached ownership data (will be rebuilt on next scan)",
                        order = 13,
                        confirm = true,
                        confirmText = "Are you sure you want to clear the ownership cache?",
                        func = function()
                            if HA.Addon.ClearOwnershipCache then
                                HA.Addon:ClearOwnershipCache()
                            end
                        end,
                    },
                },
            },

            -- Developer Tools Section (temporary - remove after vendor data is confirmed)
            devTools = {
                type = "group",
                name = "Developer Tools",
                order = 99,
                args = {
                    devNote = {
                        type = "description",
                        name = "|cffff9900Note:|r This section is temporary and will be removed once all vendor data is verified. Use these tools to help correct the vendor database.",
                        order = 1,
                        fontSize = "medium",
                    },
                    spacer1 = {
                        type = "description",
                        name = " ",
                        order = 2,
                    },
                    npcCorrectionsHeader = {
                        type = "header",
                        name = "NPC ID Corrections",
                        order = 3,
                    },
                    npcCorrectionsDesc = {
                        type = "description",
                        name = "When you visit vendors, the addon detects if the in-game NPC ID differs from the database entry. These corrections are stored so you can export them to update VendorDatabase.lua.",
                        order = 4,
                    },
                    spacer2 = {
                        type = "description",
                        name = " ",
                        order = 5,
                    },
                    exportCorrectionsButton = {
                        type = "execute",
                        name = "Export NPC ID Corrections",
                        desc = "Show all detected NPC ID mismatches in a copyable window",
                        order = 6,
                        func = function()
                            if HA.Addon.ShowNPCIDCorrections then
                                HA.Addon:ShowNPCIDCorrections()
                            else
                                HA.Addon:Print("ShowNPCIDCorrections not available")
                            end
                        end,
                    },
                    spacer3 = {
                        type = "description",
                        name = " ",
                        order = 7,
                    },
                    scannedVendorsHeader = {
                        type = "header",
                        name = "Scanned Vendor Data",
                        order = 10,
                    },
                    scannedVendorsDesc = {
                        type = "description",
                        name = "View data collected from visiting vendors. This includes items sold and can be used to populate the VendorDatabase.",
                        order = 11,
                    },
                    spacer4 = {
                        type = "description",
                        name = " ",
                        order = 12,
                    },
                    showScannedButton = {
                        type = "execute",
                        name = "Show Scanned Vendors",
                        desc = "Display list of all scanned vendors in chat",
                        order = 13,
                        func = function()
                            if HA.Addon.ShowScannedVendors then
                                HA.Addon:ShowScannedVendors()
                            else
                                HA.Addon:Print("ShowScannedVendors not available")
                            end
                        end,
                    },
                    exportScannedButton = {
                        type = "execute",
                        name = "Export Scanned Data",
                        desc = "Export scanned vendor data in Lua format for adding to VendorDatabase.lua",
                        order = 14,
                        func = function()
                            if HA.VendorScanner and HA.VendorScanner.ExportScannedData then
                                local output = HA.VendorScanner:ExportScannedData()
                                if output and output ~= "" then
                                    HA.Addon:ShowCopyableText(output)
                                end
                            else
                                HA.Addon:Print("VendorScanner not available")
                            end
                        end,
                    },
                    spacer5 = {
                        type = "description",
                        name = " ",
                        order = 15,
                    },
                    clearScannedButton = {
                        type = "execute",
                        name = "|cffff0000Clear All Scanned Data|r",
                        desc = "Remove all scanned vendor data (use with caution!)",
                        order = 16,
                        confirm = true,
                        confirmText = "Are you sure you want to clear all scanned vendor data? This cannot be undone.",
                        func = function()
                            if HA.VendorScanner and HA.VendorScanner.ClearScannedData then
                                HA.VendorScanner:ClearScannedData()
                                HA.Addon:Print("Scanned vendor data cleared.")
                            else
                                HA.Addon:Print("VendorScanner not available")
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
