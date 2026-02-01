--[[
    HousingAddon - Options Panel
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
        name = "Housing Addon",
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
                        desc = "Enable or disable the Housing Addon",
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
                    showMapPins = {
                        type = "toggle",
                        name = L["Show map pins"] or "Show map pins",
                        desc = "Show vendor locations on the world map",
                        width = "full",
                        order = 1,
                        get = function() return HA.Addon.db.profile.vendorTracer.showMapPins end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showMapPins = value
                        end,
                    },
                    showMinimapPins = {
                        type = "toggle",
                        name = L["Show minimap pins"] or "Show minimap pins",
                        desc = "Show vendor locations on the minimap",
                        order = 2,
                        get = function() return HA.Addon.db.profile.vendorTracer.showMinimapPins end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.showMinimapPins = value
                        end,
                    },
                    useTomTom = {
                        type = "toggle",
                        name = L["Use TomTom for waypoints"] or "Use TomTom for waypoints",
                        desc = "Use TomTom addon for waypoint arrows (if installed)",
                        order = 3,
                        get = function() return HA.Addon.db.profile.vendorTracer.useTomTom end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.useTomTom = value
                        end,
                    },
                    autoWaypoint = {
                        type = "toggle",
                        name = L["Auto-create waypoint on selection"] or "Auto-create waypoint on selection",
                        desc = "Automatically create a waypoint when clicking on a decor item",
                        order = 4,
                        get = function() return HA.Addon.db.profile.vendorTracer.autoWaypoint end,
                        set = function(_, value)
                            HA.Addon.db.profile.vendorTracer.autoWaypoint = value
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
    AceConfigDialog:AddToBlizOptions(addonName, "Housing Addon")

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
