--[[
    Homestead - Core
    Main addon initialization (SavedVariables, lifecycle, events, and commands via Foundry)

    A complete housing collection, vendor, and progress tracker for WoW
]]

local addonName, HA = ...

-- Foundry-1.0 is a hard dependency (## Dependencies: Foundry-1.0), so it is
-- guaranteed loaded before Homestead. Bind it at file load: the Lifecycle adopt
-- below needs it now, and a missing Foundry is a hard load-time error (it cannot
-- be absent given the TOC dependency line).
local F = _G.Foundry_1_0
if not F then
    error("Homestead requires Foundry-1.0. Please install or enable it.")
end

-- The main addon object: a plain table adopted onto a Foundry.Lifecycle
-- controller (replaces AceAddon-3.0's NewAddon). Lifecycle writes nothing into
-- this table; Foundry.DB backs SavedVariables (self.db, set in OnInitialize).
local Homestead = {}

-- Store reference in namespace
HA.Addon = Homestead

-- Expose globally for debugging (allows /dump Homestead commands)
-- Intentional global: addon interop, WeakAura detection, /dump access
_G.Homestead = HA -- luacheck: ignore 122

-- WagoAnalytics: silent load, graceful fallback for local dev
local WagoAnalytics = LibStub("WagoAnalytics", true)
if WagoAnalytics then
    HA.Analytics = WagoAnalytics:Register("aNDMQ86o")
end

-- Backwards compatibility alias
local HousingAddon = Homestead

-- Adopt the addon object onto a Foundry.Lifecycle controller and subscribe the
-- startup callbacks (replaces AceAddon's NewAddon + OnInitialize/OnEnable
-- dispatch). Wrapper indirection -- not direct method references -- so the
-- late-defined OnInitialize/OnEnable resolve at fire time, exactly as AceAddon's
-- deferred callbacks did (mirrors how RegisterEvents binds Events handlers):
--   addon-loaded -> OnInitialize (post-SavedVariables: Foundry.DB, migrations, slash)
--   login        -> OnEnable     (event registration + module init chain)
-- There is deliberately no OnLogout subscription: Homestead has no load-bearing
-- logout teardown (frame/event cleanup happens on session end).
--
-- F:RequireModule (not F.Lifecycle directly) fails loud with a clear diagnostic
-- if a too-old Foundry without the Lifecycle module is loaded -- the version-skew
-- window before Foundry's Lifecycle release lands -- instead of an opaque
-- nil-index. (Foundry-itself-missing is the guard above.)
local Lifecycle = F:RequireModule("Lifecycle", 1)
-- Fail loud at load if this Foundry build lacks the DB module (HS-117; the
-- BSP-060 guard precedent — RequireModule raises in BOTH builds).
F:RequireModule("DB", 1)
local lifecycle = Lifecycle:New(Homestead, addonName)
-- Subscription ORDER is load-bearing for the load-on-demand catch-up path: if
-- Homestead were ever loaded on demand AFTER login, both hooks catch up
-- synchronously here in registration order, so OnAddonLoaded must precede OnLogin
-- or OnEnable would run before OnInitialize had built self.db.
lifecycle:OnAddonLoaded(function() Homestead:OnInitialize() end)
lifecycle:OnLogin(function() Homestead:OnEnable() end)

-- Local references for performance
local Constants = HA.Constants
local L = HA.L or {}
local print = print
local format = string.format

-------------------------------------------------------------------------------
-- Addon Lifecycle
-------------------------------------------------------------------------------

function HousingAddon:OnInitialize()
    -- Initialize SavedVariables database
    -- name must be the real folder name (Homestead or Homestead_DevBuild): Foundry
    -- feeds it to C_AddOns.IsAddOnLoaded for the SV-availability check (STU-073).
    self.db = F.DB:New({ name = addonName, sv = "HomesteadDB", defaults = Constants.Defaults, defaultProfile = true })

    -- Clean up removed setting from SavedVariables (requirement scraping removed)
    self.db.global.enableRequirementScraping = nil

    -- One-time migration: pin size default was too large for native pin system.
    -- Old default was 20, runtime clamped to 18. Reset users at either value to 10.
    local vt = self.db.profile.vendorTracer
    if vt and vt.pinIconSize and vt.pinIconSize >= 18 then
        vt.pinIconSize = 10
    end

    -- Initialize minimap button
    self:InitializeMinimapButton()

    -- Register slash commands via Foundry.Commands (replaces AceConsole-3.0).
    -- F is the file-scope Foundry bind (guarded at load; see top of file).
    local cmd = F.Commands:New({
        name = "Homestead",
        slashes = { "/hs", "/homestead" },
        defaultHandler = function() self:OpenOptions() end,
        description = L["Homestead Commands:"] or "Homestead Commands:",
        unknownMessage = function(input)
            local msg = format(L["Unknown command: %s"] or "Unknown command: %s", input)
            local hint = L["Type /hs help for a list of commands."]
                or "Type /hs help for a list of commands."
            return msg .. " " .. hint
        end,
    })

    cmd:Register({ name = "config",
        help = "Open the options panel.",
        handler = function() self:OpenOptions() end })
    cmd:Register({ name = "vendor", args = "[search]",
        help = "Search for decor vendors.",
        handler = function(rest) self:SearchVendors(rest ~= "" and rest or nil) end })
    cmd:Register({ name = "waypoint", aliases = { "wp" },
        help = "Clear the current map waypoint.",
        handler = function() self:ClearWaypoint() end })
    cmd:Register({ name = "scan",
        help = "Scan the catalog for owned items.",
        handler = function() self:ScanCatalog() end })
    cmd:Register({ name = "vendors",
        help = "Show scanned vendor data.",
        handler = function() self:ShowScannedVendors() end })
    cmd:Register({ name = "cache",
        help = "Show ownership cache info.",
        handler = function() self:ShowCacheInfo() end })
    cmd:Register({ name = "clearcache",
        help = "Clear the ownership cache.",
        handler = function() self:ClearOwnershipCache() end })
    cmd:Register({ name = "panel",
        help = "Toggle the detached vendor panel.",
        handler = function()
            if HA.MapSidePanel then
                HA.MapSidePanel:ToggleDetached()
            end
        end })
    cmd:Register({ name = "refreshmap",
        help = "Refresh world map pins.",
        handler = function() self:RefreshMapPins() end })
    cmd:Register({ name = "corrections", aliases = { "npcfixes" },
        help = "Show detected NPC ID corrections.",
        handler = function() self:ShowNPCIDCorrections() end })
    cmd:Register({ name = "export",
        help = "Show the export dialog.",
        handler = function()
            if HA.ExportImport then
                HA.ExportImport:ShowExportDialog()
            end
        end })
    cmd:Register({ name = "export full",
        help = "Export all scanned vendors.",
        handler = function()
            if HA.ExportImport then
                HA.ExportImport:ExportScannedVendors(true, false)
            end
        end })
    cmd:Register({ name = "exportall",
        help = "Export ALL, bypassing the timestamp filter.",
        handler = function()
            if HA.ExportImport then
                HA.ExportImport:ExportScannedVendors(true, true)
            end
        end })
    cmd:Register({ name = "clearscans",
        help = "Clear all scanned vendor data.",
        handler = function()
            if HA.ExportImport then
                HA.ExportImport:ClearScannedData()
            end
        end })
    cmd:Register({ name = "validate",
        help = "Validate the vendor database.",
        handler = function()
            if HA.Validation then
                HA.Validation:RunFullValidation()
            end
        end })
    cmd:Register({ name = "validate details",
        help = "Show validation details.",
        handler = function()
            if HA.Validation then
                HA.Validation:ShowDetails()
            end
        end })
    cmd:Register({ name = "welcome",
        help = "Show the welcome screen.",
        handler = function()
            if HA.WelcomeFrame then
                HA.WelcomeFrame:Show()
            end
        end })
    cmd:Register({ name = "whatsnew",
        help = "Show the What's New panel.",
        handler = function()
            if HA.WhatsNewFrame then
                HA.WhatsNewFrame:Show(HA.Constants.VERSION)
            end
        end })
    cmd:Register({ name = "version", args = "[on|off]",
        help = "Show version; toggle update notifications.",
        handler = function(rest)
            if HA.VersionCheck then
                HA.VersionCheck:HandleSlash(rest)
            end
        end })
    cmd:Register({ name = "debug",
        help = "Toggle debug mode.",
        handler = function()
            self.db.profile.debug = not self.db.profile.debug
            self:Print(format(L["Debug mode: %s"] or "Debug mode: %s",
                self.db.profile.debug and (L["ON"] or "ON") or (L["OFF"] or "OFF")))
        end })
    cmd:Register({ name = "debug vertical",
        help = "Print vertical-sibling info.",
        handler = function()
            local lines = HA.Constants.GetVerticalSiblingsInfo()
            self:Print("VerticalSiblings (" .. #lines .. " pairs):")
            for _, line in ipairs(lines) do
                self:Print("  " .. line)
            end
        end })
    cmd:Register({ name = "debug geography",
        help = "Audit manual map geography entries.",
        handler = function() self:PrintManualGeographyAuditReport() end })

    self.commands = cmd

    self._initialized = true
    self:Debug("Homestead initialized")
end

function HousingAddon:OnEnable()
    -- HS-217: DevBuild collision poison flag (set by the generated
    -- DevBuildGuard.lua when it detects the live 'Homestead' addon is also
    -- enabled). DisableAddOn only takes effect on the NEXT reload, so this
    -- session's DevBuild copy is still fully loaded and would otherwise run
    -- its whole module-init chain in parallel with the live copy. One gate
    -- here stands the whole chain down for the rest of THIS session instead
    -- of scattering the check through every module Initialize().
    if HA.__collisionStandDown then
        return
    end

    -- Guard: the login hook must not run the enable chain unless the addon-loaded
    -- hook (OnInitialize) completed. If OnInitialize errored, or the two lifecycle
    -- hooks were ever mis-ordered, self.db and module state are absent and the
    -- chain below would cascade into nil-index errors. Fail loud, don't half-enable.
    if not self._initialized then
        F:RaiseDevError("Homestead:OnEnable ran before OnInitialize completed; "
            .. "skipping the enable chain (addon not initialized).")
        return
    end

    -- Register for events
    self:RegisterEvents()

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

    -- Initialize CalendarDetector for seasonal event detection
    if HA.CalendarDetector then
        HA.CalendarDetector:Initialize()
    end

    -- Initialize EndeavorsData for active endeavor detection
    if HA.EndeavorsData and HA.EndeavorsData.Initialize then
        HA.EndeavorsData:Initialize()
    end

    -- Initialize SourceManager after source tables/scanners are available
    if HA.SourceManager and HA.SourceManager.Initialize then
        HA.SourceManager:Initialize()
    end

    -- HS-209 H1: Overlay:Initialize() had zero call sites — its
    -- Events:RegisterCallback("bags"/"merchant"/"all"/"OWNERSHIP_UPDATED")
    -- wiring never ran. Wired here, after CatalogStore/SourceManager (which
    -- its callbacks call into once fired) and before the more UI-specific
    -- modules below. Overlay:Initialize() guards its own double-registration
    -- (see Overlay/overlay.lua) if this chain is ever re-entered.
    if HA.Overlay and HA.Overlay.Initialize then
        HA.Overlay:Initialize()
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

    -- Initialize WelcomeFrame for first-run onboarding (new installs only)
    if HA.WelcomeFrame then
        HA.WelcomeFrame:Initialize()
    end

    -- What's New trigger (version updates, skips for new installs)
    if HA.WhatsNewFrame then
        HA.WhatsNewFrame:Initialize()
    end

    -- Version-check peer broadcast (HS-086)
    if HA.VersionCheck then
        HA.VersionCheck:Initialize()
    end

    self:Debug("Homestead enabled")
end

-- No OnDisable / runtime-disable path. AceAddon-3.0's manual :Enable/:Disable
-- affordance was removed with AceAddon (HS-109): the addon is enabled for the
-- session, and disabling is done via the AddOns list + /reload. No logout
-- teardown is needed -- frame/event cleanup happens on session end.

-------------------------------------------------------------------------------
-- Minimap Button (LibDataBroker broker + custom HA.MinimapButton + Addon Compartment)
-------------------------------------------------------------------------------

function HousingAddon:InitializeMinimapButton()
    local LDB = LibStub("LibDataBroker-1.1", true)

    if not LDB then
        self:Debug("LibDataBroker not available")
        return
    end

    -- Create data broker object
    local dataObj = LDB:NewDataObject(addonName, {
        type = "launcher",
        text = "Homestead",
        icon = Constants.Icons.MINIMAP,
        OnClick = function(_, button)
            if button == "LeftButton" then
                self:ToggleOptions()
            elseif button == "RightButton" then
                if HA.MapSidePanel then
                    HA.MapSidePanel:ToggleDetached()
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
                    tooltip:AddLine(format(L["Collection: %d / %d (%d%%)"] or "Collection: %d / %d (%d%%)", owned, total, percent), 1, 1, 1)
                end
            end

            -- Vendors in current zone
            if HA.VendorData and HA.VendorData.GetVendorsInMap then
                local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
                if mapID then
                    local vendors = HA.VendorData:GetVendorsInMap(mapID)
                    if vendors then
                        tooltip:AddLine(format(L["Vendors nearby: %d"] or "Vendors nearby: %d", #vendors), 1, 1, 1)
                    end
                end
            end

            -- Scanned vendors count
            if self.db and self.db.global and self.db.global.scannedVendors then
                local count = 0
                for _ in pairs(self.db.global.scannedVendors) do
                    count = count + 1
                end
                tooltip:AddLine(format(L["Vendors scanned: %d"] or "Vendors scanned: %d", count), 1, 1, 1)
            end

            tooltip:AddLine(" ")
            tooltip:AddLine(L["Left-Click: Toggle options"] or "|cFFFFFFFFLeft-Click:|r Toggle options")
            tooltip:AddLine(L["Right-Click: Detach/close vendor panel"] or "|cFFFFFFFFRight-Click:|r Detach/close vendor panel")
        end,
    })

    -- Store reference
    self.LDB = dataObj

    -- Custom minimap button (replaces LibDBIcon)
    if HA.MinimapButton then
        HA.MinimapButton:Initialize(dataObj, self.db.profile.minimap)
    end

    -- Blizzard Addon Compartment (native surface; reuses the same behavior)
    local AddonCompartmentFrame = _G.AddonCompartmentFrame
    if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
        AddonCompartmentFrame:RegisterAddon({
            text = "Homestead",
            icon = Constants.Icons.MINIMAP,
            func = function() self:ToggleOptions() end,
            funcOnEnter = function(btn)
                GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
                dataObj.OnTooltipShow(GameTooltip)
                GameTooltip:Show()
            end,
            funcOnLeave = function() GameTooltip:Hide() end,
        })
    end
end

-------------------------------------------------------------------------------
-- Slash Command Helpers
-------------------------------------------------------------------------------

function HousingAddon:PrintManualGeographyAuditReport()
    local MPP = HA.MapPinProvider
    if not MPP or not MPP.GetManualGeographyAuditReport then
        self:Print("MapPinProvider audit is not available.")
        return
    end

    local report = MPP:GetManualGeographyAuditReport()
    local summary = report and report.summary or {}
    self:Print(format(
        "Manual geography audit: %d checked, %d required, %d redundant candidates",
        summary.checked or 0,
        summary.manualRequired or 0,
        summary.redundantCandidates or 0
    ))

    if not report or not report.rows or #report.rows == 0 then
        return
    end

    for _, row in ipairs(report.rows) do
        self:Print(format(
            "  %s %s->%s: %s (%s; native=%s)",
            row.tableName or "?",
            tostring(row.sourceMapID),
            tostring(row.viewMapID),
            row.status or "?",
            row.manualReason or "?",
            row.nativeReason or "unknown"
        ))
    end
end

-- Refresh map pins manually
function HousingAddon:RefreshMapPins()
    if HA.VendorMapPins then
        HA.VendorMapPins:RefreshPins()
        self:Print(L["Map pins refreshed."] or "Map pins refreshed.")
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
        self:Print(format(L["Vendor database contains %d vendors."] or "Vendor database contains %d vendors.", count))
        self:Print(L["Use /hs vendor <name or zone> to search."] or "Use /hs vendor <name or zone> to search.")
        return
    end

    local results = HA.VendorData:SearchVendors(searchText)
    if #results == 0 then
        self:Print(format(L["No vendors found matching: %s"] or "No vendors found matching: %s", searchText))
        return
    end

    self:Print(format(L["Found %d vendor(s) matching: %s"] or "Found %d vendor(s) matching: %s", #results, searchText))
    for i, vendor in ipairs(results) do
        if i <= 5 then -- Limit to 5 results in chat
            local locationStr = vendor.zone or "Unknown"
            self:Print("  " .. vendor.name .. " - " .. locationStr)
        end
    end
    if #results > 5 then
        self:Print("  " .. format(L["... and %d more."] or "... and %d more.", #results - 5))
    end
end

-- Clear current waypoint
function HousingAddon:ClearWaypoint()
    if HA.Waypoints then
        if HA.Waypoints:HasWaypoint() then
            HA.Waypoints:Clear()
            self:Print(L["Waypoint cleared."] or "Waypoint cleared.")
        else
            self:Print(L["No active waypoint."] or "No active waypoint.")
        end
    elseif HA.VendorTracer then
        HA.VendorTracer:ClearWaypoint()
        self:Print(L["Waypoint cleared."] or "Waypoint cleared.")
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
    else
        table.insert(output, "CatalogStore unavailable — ownership data cannot be displayed.")
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
    else
        self:Print("CatalogStore unavailable — cannot clear ownership cache.")
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
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end) -- luacheck: ignore 432
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
    -- Event handling via Foundry.Events controller (replaces AceEvent-3.0).
    -- F is the file-scope Foundry bind (see top of file).
    local events = F.Events:New("Homestead.Core")
    self.events = events

    -- Register housing events. The closure binds the addon `self` and absorbs
    -- the dropped native frame `self` (Foundry handlers are `(event, ...)`).
    events:Register("PLAYER_LOGIN",          function(event, ...) self:OnPlayerLogin(...) end)
    events:Register("PLAYER_ENTERING_WORLD", function(event, ...) self:OnPlayerEnteringWorld(...) end)

    -- Register UI events for overlay updates
    events:Register("BAG_UPDATE_DELAYED",    function(event, ...) self:OnBagUpdate(...) end)
    events:Register("MERCHANT_CLOSED",       function(event, ...) self:OnMerchantClosed(...) end)

    -- MERCHANT_SHOW is intentionally NOT registered here. Under AceEvent the core
    -- "OnMerchantShow" registration was silently clobbered by VendorTracer's later
    -- registration on the same object (last-write-wins), so it never fired. The
    -- live MERCHANT_SHOW handler is VendorTracer's own controller. Not registering
    -- it here preserves that behavior exactly.

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

-- Note: a core HousingAddon:OnMerchantShow handler previously existed here but
-- was dead under AceEvent (its MERCHANT_SHOW registration was clobbered by
-- VendorTracer's, last-write-wins) and had no other caller. The merchant overlay
-- still refreshes through Overlay/Merchant.lua's own standalone frame. Removed as
-- part of HS-097 to resolve the registration ambiguity (see RegisterEvents).

function HousingAddon:OnMerchantClosed()
    -- Clean up merchant overlays
end

-------------------------------------------------------------------------------
-- UI Functions (Stubs - will be implemented in UI modules)
-------------------------------------------------------------------------------

function HousingAddon:OpenOptions()
    if HA.OptionsFrame and HA.OptionsFrame.Open then
        HA.OptionsFrame:Open()
    else
        self:Print("Options are not available yet.")
    end
end

function HousingAddon:ToggleOptions()
    if HA.OptionsFrame and HA.OptionsFrame.Toggle then
        HA.OptionsFrame:Toggle()
    else
        self:Print("Options are not available yet.")
    end
end

-- ExportData and OpenVendorPanel stubs removed: not yet implemented

-------------------------------------------------------------------------------
-- Refresh Functions
-------------------------------------------------------------------------------

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

local DecorInfoCompat = {}
local DecorInfoCompatMT = { __index = DecorInfoCompat }

function DecorInfoCompat:GetStatus()
    if self.isOwned then
        return self.numPlaced > 0 and "COLLECTED_PLACED" or "COLLECTED"
    end
    return "NOT_COLLECTED"
end

function DecorInfoCompat:GetStatusIcon()
    local sourceManager = HA.SourceManager
    return sourceManager and sourceManager.GetItemStatusIcon
        and sourceManager:GetItemStatusIcon(self.itemID) or nil
end

function DecorInfoCompat:GetStatusColor()
    local sourceManager = HA.SourceManager
    return sourceManager and sourceManager.GetItemStatusColor
        and sourceManager:GetItemStatusColor(self.itemID) or nil
end

function DecorInfoCompat:GetSourceIcon()
    local sourceManager = HA.SourceManager
    return sourceManager and sourceManager.GetSourceTypeIcon
        and sourceManager:GetSourceTypeIcon(self.sourceType) or nil
end

function DecorInfoCompat:IsValid()
    return self.itemID ~= nil
end

-- Check if a decor item is collected
function HousingAddon:IsDecorCollected(itemID)
    if HA.CatalogStore then
        return HA.CatalogStore:IsOwnedFresh(itemID)
    end
    return nil
end

-- Get decor info for an item
function HousingAddon:GetDecorInfo(itemLink)
    if not itemLink then return nil end

    local itemID = C_Item.GetItemInfoInstant(itemLink)
    if not itemID then return nil end

    local catalogStore = HA.CatalogStore
    local sourceManager = HA.SourceManager
    if not catalogStore or not catalogStore:IsDecorItem(itemLink) then
        return nil
    end

    local record = catalogStore:Get(itemID)
    local source = sourceManager and sourceManager.GetSource and sourceManager:GetSource(itemID) or nil
    local sourceType = source and sourceManager and sourceManager.NormalizeSourceType
        and sourceManager:NormalizeSourceType(source.type) or "unknown"
    local numPlaced = sourceManager and sourceManager.GetPlacedCountForItem
        and sourceManager:GetPlacedCountForItem(itemID) or 0
    local itemName = (record and record.name)
        or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID))

    local info = {
        itemID = itemID,
        itemLink = itemLink,
        name = itemName,
        isOwned = catalogStore:IsOwnedFresh(itemID),
        numPlaced = numPlaced,
        sourceType = sourceType,
    }

    return setmetatable(info, DecorInfoCompatMT)
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
