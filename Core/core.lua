--[[
    Homestead - Core
    Main addon initialization and Ace3 setup

    A complete housing collection, vendor, and progress tracker for WoW
]]

local addonName, HA = ...

-- Create the main addon object using Ace3
local Homestead = LibStub("AceAddon-3.0"):NewAddon(
    addonName,
    "AceConsole-3.0",
    "AceEvent-3.0"
)

-- Store reference in namespace
HA.Addon = Homestead

-- Expose globally for debugging (allows /dump Homestead commands)
-- Intentional global: addon interop, WeakAura detection, /dump access
_G.Homestead = HA

-- WagoAnalytics: silent load, graceful fallback for local dev
local WagoAnalytics = LibStub("WagoAnalytics", true)
if WagoAnalytics then
    HA.Analytics = WagoAnalytics:Register("aNDMQ86o")
end

-- Backwards compatibility alias
local HousingAddon = Homestead

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
    self.db = LibStub("AceDB-3.0"):New("HomesteadDB", Constants.Defaults, true)

    -- Set up profile callbacks
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")

    -- Initialize minimap button
    self:InitializeMinimapButton()

    -- Register slash commands
    self:RegisterChatCommand("hs", "SlashCommandHandler")
    self:RegisterChatCommand("homestead", "SlashCommandHandler")

    -- Initialize modules (will be called when modules are created)
    -- self:InitializeModules()

    self:Debug("Homestead initialized")
end

function HousingAddon:OnEnable()
    -- Register for events
    self:RegisterEvents()

    -- Initialize cache
    if HA.Cache then
        HA.Cache:Initialize()
    end

    -- Initialize CatalogStore (must be before CatalogScanner)
    if HA.CatalogStore then
        HA.CatalogStore:Initialize()
    end

    -- Initialize CatalogScanner for bulk ownership scanning
    if HA.CatalogScanner then
        HA.CatalogScanner:Initialize()
    end

    -- Initialize VendorScanner for automatic vendor discovery
    if HA.VendorScanner then
        HA.VendorScanner:Initialize()
    end

    -- Initialize SourceTextScanner for parsed source data
    if HA.SourceTextScanner then
        HA.SourceTextScanner:Initialize()
    end

    -- Initialize Waypoints utility
    if HA.Waypoints then
        HA.Waypoints:Initialize()
    end

    -- Initialize VendorTracer module
    if HA.VendorTracer then
        HA.VendorTracer:Initialize()
    end

    -- Initialize MapSidePanel (before VendorMapPins, shares same hooks)
    if HA.MapSidePanel then
        HA.MapSidePanel:Initialize()
    end

    -- Initialize VendorMapPins for world map integration
    if HA.VendorMapPins then
        HA.VendorMapPins:Initialize()
    end

    -- Initialize WelcomeFrame for first-run onboarding
    if HA.WelcomeFrame then
        HA.WelcomeFrame:Initialize()
    end

    self:Debug("Homestead enabled")
end

function HousingAddon:OnDisable()
    -- Unregister all events
    self:UnregisterAllEvents()

    self:Debug("Homestead disabled")
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
        text = "Homestead",
        icon = Constants.Icons.MINIMAP,
        OnClick = function(_, button)
            if button == "LeftButton" then
                self:ToggleMainFrame()
            elseif button == "RightButton" then
                if IsShiftKeyDown() then
                    if HA.ExportImport and HA.ExportImport.ShowExportDialog then
                        HA.ExportImport:ShowExportDialog()
                    end
                else
                    self:OpenOptions()
                end
            elseif button == "MiddleButton" then
                if HA.CatalogScanner and HA.CatalogScanner.ManualScan then
                    HA.CatalogScanner:ManualScan()
                else
                    self:Print("CatalogScanner not available for middle-click scan")
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cFFFFD700Homestead|r")

            -- Collection progress
            if C_HousingCatalog and C_HousingCatalog.GetDecorTotalOwnedCount and C_HousingCatalog.GetDecorMaxOwnedCount then
                local owned = C_HousingCatalog.GetDecorTotalOwnedCount()
                local total = C_HousingCatalog.GetDecorMaxOwnedCount()
                if owned and total and total > 0 then
                    local percent = math.floor((owned / total) * 100)
                    tooltip:AddLine(format("Collection: %d / %d (%d%%)", owned, total, percent), 1, 1, 1)
                end
            end

            -- Vendors in current zone
            if HA.VendorData and HA.VendorData.GetVendorsInMap then
                local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
                if mapID then
                    local vendors = HA.VendorData:GetVendorsInMap(mapID)
                    if vendors then
                        tooltip:AddLine(format("Vendors nearby: %d", #vendors), 1, 1, 1)
                    end
                end
            end

            -- Scanned vendors count
            if self.db and self.db.global and self.db.global.scannedVendors then
                local count = 0
                for _ in pairs(self.db.global.scannedVendors) do
                    count = count + 1
                end
                tooltip:AddLine(format("Vendors scanned: %d", count), 1, 1, 1)
            end

            tooltip:AddLine(" ")
            tooltip:AddLine("|cFFFFFFFFLeft-Click:|r Toggle main window")
            tooltip:AddLine("|cFFFFFFFFMiddle-Click:|r Scan collection")
            tooltip:AddLine("|cFFFFFFFFShift+Right-Click:|r Export data")
            tooltip:AddLine("|cFFFFFFFFRight-Click:|r Open options")
        end,
    })

    -- Store reference
    self.LDB = dataObj

    -- Register with LibDBIcon
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
    elseif input == "vendor" or input:match("^vendor%s+") then
        local search = input:match("^vendor%s+(.+)$")
        self:SearchVendors(search)
    elseif input == "waypoint" or input == "wp" then
        self:ClearWaypoint()
    elseif input == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        self:Print("Debug mode:", self.db.profile.debug and "ON" or "OFF")
    elseif input == "cache" then
        self:ShowCacheInfo()
    elseif input == "clearcache" then
        self:ClearOwnershipCache()
    elseif input == "scan" then
        self:ScanCatalog()
    elseif input == "vendors" then
        self:ShowScannedVendors()
    elseif input == "refreshmap" then
        self:RefreshMapPins()
    elseif input == "corrections" or input == "npcfixes" then
        self:ShowNPCIDCorrections()
    elseif input == "help" then
        self:PrintHelp()
    elseif input == "export" then
        if HA.ExportImport then
            HA.ExportImport:ShowExportDialog()
        end
    elseif input == "export full" then
        if HA.ExportImport then
            HA.ExportImport:ExportScannedVendors(true, false)
        end
    elseif input == "exportall" then
        if HA.ExportImport then
            HA.ExportImport:ExportScannedVendors(true, true)
        end
    elseif input == "clearscans" then
        if HA.ExportImport then
            HA.ExportImport:ClearScannedData()
        end
    elseif input == "validate" then
        if HA.Validation then
            HA.Validation:RunFullValidation()
        end
    elseif input == "validate details" then
        if HA.Validation then
            HA.Validation:ShowDetails()
        end
    elseif input == "welcome" then
        if HA.WelcomeFrame then
            HA.WelcomeFrame:Show()
        end
    else
        self:Print("Unknown command:", input)
        self:PrintHelp()
    end
end

function HousingAddon:PrintHelp()
    self:Print("Homestead Commands:")
    self:Print("  /hs - Toggle main window")
    self:Print("  /hs options - Open options panel")
    self:Print("  /hs scan - Scan catalog for owned items")
    self:Print("  /hs vendor [search] - Search for decor vendors")
    self:Print("  /hs vendors - Show scanned vendor data")
    self:Print("  /hs waypoint - Clear current waypoint")
    self:Print("  /hs cache - Show ownership cache info")
    self:Print("  /hs clearcache - Clear ownership cache")
    self:Print("  /hs refreshmap - Refresh world map pins")
    self:Print("  /hs corrections - Show NPC ID corrections found")
    self:Print("  /hs export - Show export dialog")
    self:Print("  /hs export full - Export all scanned vendors")
    self:Print("  /hs exportall - Export ALL, bypass timestamp filter")
    self:Print("  /hs clearscans - Clear all scanned vendor data")
    self:Print("  /hs validate - Validate vendor database")
    self:Print("  /hs welcome - Show welcome/onboarding screen")
    self:Print("  /hs debug - Toggle debug mode")
    self:Print("  /hs help - Show this help")
end

-- Refresh map pins manually
function HousingAddon:RefreshMapPins()
    if HA.VendorMapPins then
        HA.VendorMapPins:RefreshPins()
        self:Print("Map pins refreshed.")
    else
        self:Print("VendorMapPins module not available.")
    end
end

-- Scan the housing catalog for owned items
function HousingAddon:ScanCatalog()
    if HA.CatalogScanner then
        HA.CatalogScanner:ManualScan()
    else
        self:Print("CatalogScanner module not available.")
    end
end

-- Search for vendors
function HousingAddon:SearchVendors(searchText)
    if not HA.VendorData then
        self:Print("VendorData module not available.")
        return
    end

    if not searchText or searchText == "" then
        -- Show vendor count
        local count = HA.VendorData:GetVendorCount()
        self:Print("Vendor database contains", count, "vendors.")
        self:Print("Use /hs vendor <name or zone> to search.")
        return
    end

    local results = HA.VendorData:SearchVendors(searchText)
    if #results == 0 then
        self:Print("No vendors found matching:", searchText)
        return
    end

    self:Print("Found", #results, "vendor(s) matching:", searchText)
    for i, vendor in ipairs(results) do
        if i <= 5 then -- Limit to 5 results in chat
            local locationStr = vendor.zone or "Unknown"
            self:Print("  " .. vendor.name .. " - " .. locationStr)
        end
    end
    if #results > 5 then
        self:Print("  ... and", #results - 5, "more.")
    end
end

-- Clear current waypoint
function HousingAddon:ClearWaypoint()
    if HA.Waypoints then
        if HA.Waypoints:HasWaypoint() then
            HA.Waypoints:Clear()
            self:Print("Waypoint cleared.")
        else
            self:Print("No active waypoint.")
        end
    elseif HA.VendorTracer then
        HA.VendorTracer:ClearWaypoint()
        self:Print("Waypoint cleared.")
    else
        self:Print("Waypoint system not available.")
    end
end

-------------------------------------------------------------------------------
-- Testing/Debugging
-------------------------------------------------------------------------------

-- Show ownership cache information
function HousingAddon:ShowCacheInfo()
    local output = {}
    table.insert(output, "=== Homestead Ownership Cache ===")
    table.insert(output, "")

    -- Use CatalogStore as primary data source
    local count = HA.CatalogStore and HA.CatalogStore:GetOwnedCount() or 0
    local items = {}

    if HA.CatalogStore and self.db and self.db.global and self.db.global.catalogItems then
        for itemID, record in pairs(self.db.global.catalogItems) do
            if record.isOwned then
                local name = record.name or ("ItemID: " .. itemID)
                local lastSeen = record.lastSeen and date("%Y-%m-%d %H:%M", record.lastSeen) or "unknown"
                table.insert(items, "  " .. name .. " (ID: " .. itemID .. ") - Last seen: " .. lastSeen)
            end
        end
    elseif self.db and self.db.global and self.db.global.ownedDecor then
        -- Fallback to legacy ownedDecor
        for itemID, data in pairs(self.db.global.ownedDecor) do
            count = count + 1
            local name = data.name or ("ItemID: " .. itemID)
            local lastSeen = data.lastSeen and date("%Y-%m-%d %H:%M", data.lastSeen) or "unknown"
            table.insert(items, "  " .. name .. " (ID: " .. itemID .. ") - Last seen: " .. lastSeen)
        end
    end

    if count == 0 and #items == 0 then
        table.insert(output, "No ownership cache data found.")
        self:ShowCopyableText(table.concat(output, "\n"))
        return
    end

    table.insert(output, "Total cached items: " .. count)
    table.insert(output, "")
    table.insert(output, "This cache persists across reloads as a backup for")
    table.insert(output, "ownership detection via the Housing Catalog API.")
    table.insert(output, "")

    if #items > 0 then
        table.insert(output, "Cached items:")
        table.sort(items)
        for _, item in ipairs(items) do
            table.insert(output, item)
        end
    end

    self:ShowCopyableText(table.concat(output, "\n"))
end

-- Clear the ownership cache (delegates to CatalogStore which clears both tables)
function HousingAddon:ClearOwnershipCache()
    if HA.CatalogStore then
        local count = HA.CatalogStore:GetOwnedCount()
        HA.CatalogStore:ClearAll()
        self:Print("Cleared ownership cache. Removed " .. count .. " cached items.")
        self:Print("Use /hs scan to rebuild the cache.")
    elseif self.db and self.db.global then
        -- Fallback if CatalogStore not yet loaded
        local count = 0
        if self.db.global.ownedDecor then
            for _ in pairs(self.db.global.ownedDecor) do
                count = count + 1
            end
        end
        self.db.global.ownedDecor = {}
        self:Print("Cleared ownership cache. Removed " .. count .. " cached items.")
        self:Print("Use /hs scan to rebuild the cache.")
    end
end

-- Show scanned vendor data
function HousingAddon:ShowScannedVendors()
    if not self.db or not self.db.global then
        self:Print("SavedVariables not initialized.")
        return
    end

    local scannedVendors = self.db.global.scannedVendors
    if not scannedVendors then
        self:Print("No vendors have been scanned yet.")
        self:Print("Visit vendors to automatically scan their decor items.")
        return
    end

    local count = 0
    local totalItems = 0
    for npcID, vendorData in pairs(scannedVendors) do
        count = count + 1
        local items = vendorData.items
        local itemCount = items and #items or 0
        totalItems = totalItems + itemCount
        self:Print(string.format("  %s (NPC %d): %d decor items",
            vendorData.name or "Unknown", npcID, itemCount))
    end

    if count == 0 then
        self:Print("No vendors have been scanned yet.")
        self:Print("Visit vendors to automatically scan their decor items.")
    else
        self:Print(string.format("Total: %d vendors scanned, %d decor items found.", count, totalItems))
    end
end

-- Show NPC ID corrections that were detected during vendor scans
function HousingAddon:ShowNPCIDCorrections()
    if not self.db or not self.db.global then
        self:Print("SavedVariables not initialized.")
        return
    end

    local output = {}
    local hasContent = false

    -- Section 1: Confirmed NPC ID Corrections (detected during scans)
    local corrections = self.db.global.npcIDCorrections
    if corrections and next(corrections) then
        hasContent = true
        table.insert(output, "=== Confirmed NPC ID Corrections ===")
        table.insert(output, "")
        table.insert(output, "These corrections were detected when visiting vendors.")
        table.insert(output, "The database NPC ID did not match the actual in-game ID.")
        table.insert(output, "")

        local count = 0
        for vendorName, correction in pairs(corrections) do
            count = count + 1
            local correctedDate = correction.correctedAt and date("%Y-%m-%d", correction.correctedAt) or "unknown"
            table.insert(output, string.format("  %s", vendorName))
            table.insert(output, string.format("    Old NPC ID: %d -> New NPC ID: %d (found %s)",
                correction.oldID, correction.newID, correctedDate))
            table.insert(output, string.format("    Action: npcID = %d,", correction.newID))
            table.insert(output, "")
        end
        table.insert(output, string.format("Total: %d confirmed correction(s).", count))
        table.insert(output, "")
    end

    -- Section 2: Possible NPC ID Mismatches (name match, ID mismatch)
    local scannedVendors = self.db.global.scannedVendors
    if scannedVendors and HA.VendorData then
        -- Build lookup of static vendor names -> npcID
        local staticNameToNPC = {}
        local allVendors = HA.VendorData:GetAllVendors()
        for _, vendor in ipairs(allVendors) do
            if vendor.name then
                -- Normalize name for comparison (lowercase, trim whitespace)
                local normalizedName = vendor.name:lower():gsub("^%s+", ""):gsub("%s+$", "")
                staticNameToNPC[normalizedName] = {
                    npcID = vendor.npcID,
                    name = vendor.name,
                    mapID = vendor.mapID,
                    zone = vendor.zone,
                }
            end
        end

        -- Check each scanned vendor for name matches with different NPC IDs
        local mismatches = {}
        for scannedNpcID, scannedData in pairs(scannedVendors) do
            if scannedData.name then
                local normalizedScannedName = scannedData.name:lower():gsub("^%s+", ""):gsub("%s+$", "")
                local staticEntry = staticNameToNPC[normalizedScannedName]

                -- If name matches but NPC ID differs, it's a potential mismatch
                if staticEntry and staticEntry.npcID ~= scannedNpcID then
                    -- Check if the scanned NPC ID exists in static DB
                    local scannedInStatic = HA.VendorData:GetVendor(scannedNpcID)

                    table.insert(mismatches, {
                        scannedName = scannedData.name,
                        scannedNpcID = scannedNpcID,
                        scannedHasDecor = scannedData.hasDecor,
                        scannedMapID = scannedData.mapID,
                        staticName = staticEntry.name,
                        staticNpcID = staticEntry.npcID,
                        staticZone = staticEntry.zone,
                        scannedExistsInStatic = scannedInStatic ~= nil,
                    })
                end
            end
        end

        if #mismatches > 0 then
            hasContent = true
            if #output > 0 then
                table.insert(output, "")
            end
            table.insert(output, "=== Possible NPC ID Mismatches ===")
            table.insert(output, "")
            table.insert(output, "Scanned vendor names match static DB names but NPC IDs differ.")
            table.insert(output, "This may indicate data entry errors in VendorDatabase.lua.")
            table.insert(output, "")

            for _, mismatch in ipairs(mismatches) do
                table.insert(output, string.format("  %s", mismatch.scannedName))
                table.insert(output, string.format("    Scanned: NPC %d (hasDecor: %s, mapID: %s)",
                    mismatch.scannedNpcID,
                    tostring(mismatch.scannedHasDecor),
                    tostring(mismatch.scannedMapID)))
                table.insert(output, string.format("    Static:  NPC %d (%s)",
                    mismatch.staticNpcID,
                    mismatch.staticZone or "unknown zone"))

                if mismatch.scannedExistsInStatic then
                    table.insert(output, "    Note: Scanned NPC ID also exists in static DB (different vendor?)")
                else
                    table.insert(output, string.format("    Action: Update static DB to use NPC %d", mismatch.scannedNpcID))
                end
                table.insert(output, "")
            end
            table.insert(output, string.format("Total: %d possible mismatch(es).", #mismatches))
        end
    end

    if not hasContent then
        self:Print("No NPC ID corrections or mismatches found.")
        self:Print("Visit vendors to automatically detect issues.")
        return
    end

    -- Show in output window
    if HA.OutputWindow then
        HA.OutputWindow:Show("NPC ID Corrections", table.concat(output, "\n"))
    else
        -- Fallback to old method
        self:ShowCopyableText(table.concat(output, "\n"))
    end
end

-- Show text in a copyable popup window
function HousingAddon:ShowCopyableText(text)
    -- Create frame if it doesn't exist
    if not self.copyFrame then
        local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        frame:SetSize(500, 400)
        frame:SetPoint("CENTER")
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 }
        })
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetFrameStrata("DIALOG")

        -- Title
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        title:SetText("Homestead - Output")

        -- Close button
        local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -5, -5)

        -- Scroll frame
        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 16, -40)
        scrollFrame:SetPoint("BOTTOMRIGHT", -36, 50)

        -- Edit box
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFontObject(GameFontHighlight)
        editBox:SetWidth(440)
        editBox:SetAutoFocus(false)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scrollFrame:SetScrollChild(editBox)

        -- Select all button
        local selectBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        selectBtn:SetSize(100, 22)
        selectBtn:SetPoint("BOTTOMLEFT", 16, 16)
        selectBtn:SetText("Select All")
        selectBtn:SetScript("OnClick", function()
            editBox:HighlightText()
            editBox:SetFocus()
        end)

        -- Copy hint
        local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("BOTTOM", 0, 20)
        hint:SetText("Press Ctrl+C to copy after selecting")

        frame.editBox = editBox
        self.copyFrame = frame
    end

    self.copyFrame.editBox:SetText(text)
    self.copyFrame:Show()
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

    -- Try to request housing market info refresh to initialize the API
    -- This may help with the Blizzard bug where data is stale after reload
    if C_HousingCatalog and C_HousingCatalog.RequestHousingMarketInfoRefresh then
        local success, err = pcall(function()
            C_HousingCatalog.RequestHousingMarketInfoRefresh()
        end)
        if success then
            self:Debug("Requested housing market info refresh")
        else
            self:Debug("Housing market refresh failed:", err)
        end
    end

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
    if HA.MainFrame then
        HA.MainFrame:Toggle()
    else
        self:Print("Main frame not available")
    end
end

function HousingAddon:OpenOptions()
    -- Open Blizzard options panel
    -- In modern WoW, we need to use the category ID returned by AceConfigDialog
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    if AceConfigDialog then
        -- Use AceConfigDialog's Open method which handles the panel correctly
        AceConfigDialog:Open(addonName)
    else
        -- Fallback: Try to open via Settings API with proper error handling
        local success = pcall(function()
            -- Try to find our category in the settings
            if Settings and Settings.OpenToCategory then
                Settings.OpenToCategory("Housing Addon")
            end
        end)
        if not success then
            self:Print("Could not open options panel. Use /ha config in chat.")
        end
    end
end

-- ExportData and OpenVendorPanel stubs removed: not yet implemented

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
    local args = {...}
    local parts = {}
    for i = 1, #args do
        parts[i] = tostring(args[i])
    end
    local msg = format("|cFF00FF00[Homestead]|r %s", table.concat(parts, " "))
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
