--[[
    HousingAddon - Core
    Main addon initialization and Ace3 setup
]]

local addonName, HA = ...

-- Create the main addon object using Ace3
local HousingAddon = LibStub("AceAddon-3.0"):NewAddon(
    addonName,
    "AceConsole-3.0",
    "AceEvent-3.0"
)

-- Store reference in namespace
HA.Addon = HousingAddon

-- Localization reference (will be populated by locale files)
local L = HA.L or {}

-- Local references for performance
local Constants = HA.Constants
local print = print
local format = string.format

-------------------------------------------------------------------------------
-- Addon Lifecycle
-------------------------------------------------------------------------------

function HousingAddon:OnInitialize()
    -- Initialize SavedVariables database
    self.db = LibStub("AceDB-3.0"):New("HousingAddonDB", Constants.Defaults, true)

    -- Set up profile callbacks
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")

    -- Initialize minimap button
    self:InitializeMinimapButton()

    -- Register slash commands
    self:RegisterChatCommand("ha", "SlashCommandHandler")
    self:RegisterChatCommand("housingaddon", "SlashCommandHandler")

    -- Initialize modules (will be called when modules are created)
    -- self:InitializeModules()

    self:Debug("HousingAddon initialized")
end

function HousingAddon:OnEnable()
    -- Register for events
    self:RegisterEvents()

    -- Initialize cache
    if HA.Cache then
        HA.Cache:Initialize()
    end

    self:Debug("HousingAddon enabled")
end

function HousingAddon:OnDisable()
    -- Unregister all events
    self:UnregisterAllEvents()

    self:Debug("HousingAddon disabled")
end

function HousingAddon:OnProfileChanged()
    -- Refresh settings when profile changes
    self:RefreshConfig()
end

-------------------------------------------------------------------------------
-- Minimap Button (LibDataBroker + LibDBIcon)
-------------------------------------------------------------------------------

function HousingAddon:InitializeMinimapButton()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)

    if not LDB or not LDBIcon then
        self:Debug("LibDataBroker or LibDBIcon not available")
        return
    end

    -- Create data broker object
    local dataObj = LDB:NewDataObject(addonName, {
        type = "launcher",
        text = "Housing Addon",
        icon = Constants.Icons.MINIMAP,
        OnClick = function(_, button)
            if button == "LeftButton" then
                self:ToggleMainFrame()
            elseif button == "RightButton" then
                self:OpenOptions()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cFF00FF00Housing Addon|r")
            tooltip:AddLine(" ")
            tooltip:AddLine("|cFFFFFFFFLeft-Click:|r Toggle main window")
            tooltip:AddLine("|cFFFFFFFFRight-Click:|r Open options")
        end,
    })

    -- Store reference
    self.LDB = dataObj

    -- Register minimap icon
    LDBIcon:Register(addonName, dataObj, self.db.profile.minimap)
end

-------------------------------------------------------------------------------
-- Slash Command Handler
-------------------------------------------------------------------------------

function HousingAddon:SlashCommandHandler(input)
    input = input and input:trim():lower() or ""

    if input == "" or input == "toggle" then
        self:ToggleMainFrame()
    elseif input == "config" or input == "options" or input == "settings" then
        self:OpenOptions()
    elseif input == "export" then
        self:ExportData()
    elseif input == "vendor" or input:match("^vendor%s+") then
        local search = input:match("^vendor%s+(.+)$")
        self:OpenVendorPanel(search)
    elseif input == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        self:Print("Debug mode:", self.db.profile.debug and "ON" or "OFF")
    elseif input == "help" then
        self:PrintHelp()
    else
        self:Print("Unknown command:", input)
        self:PrintHelp()
    end
end

function HousingAddon:PrintHelp()
    self:Print("Housing Addon Commands:")
    self:Print("  /ha - Toggle main window")
    self:Print("  /ha options - Open options panel")
    self:Print("  /ha export - Export collection data")
    self:Print("  /ha vendor [search] - Open vendor panel")
    self:Print("  /ha debug - Toggle debug mode")
    self:Print("  /ha help - Show this help")
end

-------------------------------------------------------------------------------
-- Event Registration
-------------------------------------------------------------------------------

function HousingAddon:RegisterEvents()
    -- Register housing events
    self:RegisterEvent("PLAYER_LOGIN", "OnPlayerLogin")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")

    -- Register UI events for overlay updates
    self:RegisterEvent("BAG_UPDATE_DELAYED", "OnBagUpdate")
    self:RegisterEvent("MERCHANT_SHOW", "OnMerchantShow")
    self:RegisterEvent("MERCHANT_CLOSED", "OnMerchantClosed")

    -- Note: Housing-specific events will be registered when those features are implemented
    -- These events may not exist in current WoW API - will be verified on PTR
    -- self:RegisterEvent("HOUSING_CATALOG_UPDATED", "OnHousingCatalogUpdated")
end

-------------------------------------------------------------------------------
-- Event Handlers
-------------------------------------------------------------------------------

function HousingAddon:OnPlayerLogin()
    self:Debug("Player logged in")
    -- Perform any login-specific initialization
end

function HousingAddon:OnPlayerEnteringWorld()
    self:Debug("Player entering world")
    -- Refresh overlays when entering world
    self:RefreshAllOverlays()
end

function HousingAddon:OnBagUpdate()
    -- Throttled bag update handling
    if HA.Overlay then
        HA.Overlay:RequestUpdate("bags")
    end
end

function HousingAddon:OnMerchantShow()
    if HA.Overlay then
        HA.Overlay:RequestUpdate("merchant")
    end
end

function HousingAddon:OnMerchantClosed()
    -- Clean up merchant overlays
end

-------------------------------------------------------------------------------
-- UI Functions (Stubs - will be implemented in UI modules)
-------------------------------------------------------------------------------

function HousingAddon:ToggleMainFrame()
    -- Will be implemented in UI/MainFrame.lua
    self:Print("Main frame toggle - not yet implemented")
end

function HousingAddon:OpenOptions()
    -- Open Blizzard options panel
    Settings.OpenToCategory(addonName)
end

function HousingAddon:ExportData()
    -- Will be implemented in Modules/DataExport.lua
    self:Print("Export - not yet implemented")
end

function HousingAddon:OpenVendorPanel(search)
    -- Will be implemented in UI/VendorPanel.lua
    self:Print("Vendor panel - not yet implemented")
end

-------------------------------------------------------------------------------
-- Refresh Functions
-------------------------------------------------------------------------------

function HousingAddon:RefreshConfig()
    -- Refresh minimap button visibility
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if LDBIcon then
        if self.db.profile.minimap.hide then
            LDBIcon:Hide(addonName)
        else
            LDBIcon:Show(addonName)
        end
    end

    -- Refresh overlays
    self:RefreshAllOverlays()
end

function HousingAddon:RefreshAllOverlays()
    if HA.Overlay then
        HA.Overlay:RefreshAll()
    end
end

-------------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------------

function HousingAddon:Debug(...)
    if self.db and self.db.profile and self.db.profile.debug then
        self:Print("|cFF888888[Debug]|r", ...)
    end
end

function HousingAddon:Print(...)
    local msg = format("|cFF00FF00[Housing Addon]|r %s", table.concat({...}, " "))
    print(msg)
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

-- Check if a decor item is collected
function HousingAddon:IsDecorCollected(itemID)
    if HA.DecorTracker then
        return HA.DecorTracker:IsCollected(itemID)
    end
    return nil
end

-- Get decor info for an item
function HousingAddon:GetDecorInfo(itemLink)
    if HA.DecorTracker then
        return HA.DecorTracker:GetDecorInfo(itemLink)
    end
    return nil
end

-- Get all decor from a vendor
function HousingAddon:GetVendorDecor(npcID)
    if HA.VendorTracer then
        return HA.VendorTracer:GetVendorDecor(npcID)
    end
    return nil
end

-- Navigate to a vendor
function HousingAddon:NavigateToVendor(npcID)
    if HA.VendorTracer then
        return HA.VendorTracer:NavigateToVendor(npcID)
    end
end

-------------------------------------------------------------------------------
-- Module Registration Helper
-------------------------------------------------------------------------------

function HousingAddon:RegisterModule(name, module)
    HA[name] = module
    self:Debug("Module registered:", name)
end
