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

    -- Initialize minimap button.
    -- HS-221: HA.__collisionStandDown (set by the generated DevBuildGuard.lua,
    -- which loads earlier in the TOC, so the flag is already readable here)
    -- — narrow gate on just this call: a visible minimap button would
    -- otherwise duplicate if this session's DevBuild collision copy and the
    -- live copy both create one. Nothing else in OnInitialize is gated by
    -- this; the OnEnable-level gate elsewhere already stands down the rest
    -- of the chain for the collision case.
    if not HA.__collisionStandDown then
        self:InitializeMinimapButton()
    end

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
    cmd:Register({ name = "debug parsertest",
        help = "Run SourceTextParser's built-in self-test suite.",
        handler = function()
            if HA.SourceTextParser and HA.SourceTextParser.RunTests then
                HA.SourceTextParser:RunTests()
            end
        end })
    cmd:Register({ name = "debug memallsources", args = "[full]",
        help = "Report allSourcesCache size/memory (HS-279). 'full' forces a full-corpus warm to isolate its cost.",
        handler = function(rest) self:DebugMemAllSourcesReport(rest == "full") end })
    cmd:Register({ name = "debug membudget", args = "[full]",
        help = "Per-subsystem memory budget breakdown (HS-282). 'full' additionally isolates allSourcesCache via a forced full-corpus warm.",
        handler = function(rest) self:DebugMemBudgetReport(rest == "full") end })

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

-- HS-279: isolates allSourcesCache's own memory cost via a forced full-corpus
-- warm bracketed by _G.collectgarbage("collect") + GetAddOnMemoryUsage.
-- Extracted from DebugMemAllSourcesReport (below) so HS-282's membudget
-- report can reuse the exact same measurement instead of duplicating it --
-- allSourcesCache is the one subsystem in that report with a proven,
-- session-safe forced-rebuild path; everything else there is walker-
-- estimated (Core/MemoryEstimator.lua) precisely because it lacks one.
-- Returns true, isolatedKB, fullCount, corpusSize, emptyKB, fullKB on
-- success, or false, reason on a missing prerequisite. Leaves the cache
-- fully warmed on success (safe -- it's a pure memo, identical to normal
-- play state after enough vendors have been visited).
function HousingAddon:MeasureAllSourcesCacheIsolatedKB()
    if not (_G.UpdateAddOnMemoryUsage and _G.GetAddOnMemoryUsage) then
        return false, "memory API unavailable on this client"
    end
    if not HA.SourceManager or not HA.SourceManager.GetSourcesMemoEntryCount then
        return false, "SourceManager unavailable"
    end
    if not HA.VendorData or not HA.VendorData.GetAllVendors or not HA.VendorData.GetMergedItemSet then
        return false, "VendorData unavailable -- cannot enumerate the item corpus for a full warm"
    end

    -- Enumerate every distinct itemID GetAllSources' registered providers can
    -- be asked about (Data/SourceManager.lua RegisterDefaultProviders) --
    -- vendor items, plus the six static per-itemID source tables the other
    -- providers read directly (quest/achievement/profession/event/drop/shop).
    -- Argus HS-279 review: a vendor-only corpus understates the memo's true
    -- organic ceiling, since tooltips/badges query GetAllSources for these
    -- non-vendor items too -- the eviction threshold this diagnostic feeds
    -- needs the real ceiling, not a partial one.
    local seen = {}
    local corpus = {}
    local function addToCorpus(itemID)
        if itemID and not seen[itemID] then
            seen[itemID] = true
            corpus[#corpus + 1] = itemID
        end
    end

    local allVendors = HA.VendorData:GetAllVendors()
    for _, vendor in ipairs(allVendors) do
        local _, orderedItemIDs = HA.VendorData:GetMergedItemSet(vendor, true)
        for _, itemID in ipairs(orderedItemIDs or {}) do
            addToCorpus(itemID)
        end
    end

    local staticSourceTables = {
        HA.QuestSources, HA.AchievementSources, HA.ProfessionSources,
        HA.EventSources, HA.DropSources, HA.ShopSources,
    }
    for _, sourceTable in ipairs(staticSourceTables) do
        if sourceTable then
            for itemID in pairs(sourceTable) do
                addToCorpus(itemID)
            end
        end
    end

    -- Not included: parsed sourceText discovery (HA.SourceTextScanner),
    -- which is opt-in (useParsedSources, default false) and has no static
    -- table to enumerate -- HS-273 R7 already documents this as a deferred
    -- edge, not something this diagnostic can cheaply close. The reported
    -- ceiling below is real but not exhaustive when that setting is on.

    -- Isolate the cache's own cost: wipe, measure a clean baseline, force a
    -- full warm, measure again. The delta is this cache's memory alone, not
    -- the addon's whole baseline (which includes everything else Homestead
    -- holds — SavedVariables tables, other caches, UI frames, etc).
    HA.SourceManager:InvalidateSourcesMemo()
    _G.collectgarbage("collect")
    _G.UpdateAddOnMemoryUsage()
    local emptyKB = _G.GetAddOnMemoryUsage(addonName) or 0

    for _, itemID in ipairs(corpus) do
        HA.SourceManager:GetAllSources(itemID)
    end

    _G.collectgarbage("collect")
    _G.UpdateAddOnMemoryUsage()
    local fullCount = HA.SourceManager:GetSourcesMemoEntryCount()
    local fullKB = _G.GetAddOnMemoryUsage(addonName) or 0

    return true, fullKB - emptyKB, fullCount, #corpus, emptyKB, fullKB
end

-- HS-279: dev diagnostic for allSourcesCache's memory footprint. Snapshot-only
-- by default (safe, non-destructive); 'full' additionally forces a
-- full-corpus warm (MeasureAllSourcesCacheIsolatedKB above) so the isolated
-- cost of a fully-populated cache is measurable, not guessed -- this feeds
-- HS-279's eviction threshold, it doesn't implement one itself.
-- addonName (the file-scope TOC vararg) is used instead of a literal
-- "Homestead" so this reads correctly under Homestead_DevBuild, the target
-- this diagnostic is actually run against. (VendorMapPins.lua:218's
-- WorldMapPerf debug log hardcodes "Homestead" instead -- a separate,
-- pre-existing quirk, out of scope here.)
function HousingAddon:DebugMemAllSourcesReport(full)
    if not (_G.UpdateAddOnMemoryUsage and _G.GetAddOnMemoryUsage) then
        self:Print("Memory API unavailable on this client.")
        return
    end
    if not HA.SourceManager or not HA.SourceManager.GetSourcesMemoEntryCount then
        self:Print("SourceManager unavailable.")
        return
    end

    local output = {}
    table.insert(output, "=== Homestead allSourcesCache Diagnostics (HS-279) ===")
    table.insert(output, "")

    _G.collectgarbage("collect")
    _G.UpdateAddOnMemoryUsage()
    local organicCount = HA.SourceManager:GetSourcesMemoEntryCount()
    local organicKB = _G.GetAddOnMemoryUsage(addonName) or 0
    table.insert(output, format("Current (organic) state: %d entries, %.1f KB total addon memory.",
        organicCount, organicKB))

    if not full then
        table.insert(output, "")
        table.insert(output, "Run '/hs debug memallsources full' to force a full-corpus warm and")
        table.insert(output, "isolate this cache's own memory cost. Slower (walks every vendor's")
        table.insert(output, "full item list and forces two full GC passes -- a deliberate one-time")
        table.insert(output, "cost for a dev diagnostic, not something to run casually mid-play) and")
        table.insert(output, "briefly wipes/rebuilds the cache -- safe, it's a pure memo.")
        self:ShowCopyableText(table.concat(output, "\n"))
        return
    end

    -- Argus Gate 1 finding #8: print the helper's OWN returned reason rather
    -- than a message hardcoded here, so this can't silently drift from
    -- MeasureAllSourcesCacheIsolatedKB's actual failure text if that ever
    -- changes.
    local ok, isolatedKB, fullCount, corpusSize, emptyKB, fullKB = self:MeasureAllSourcesCacheIsolatedKB()
    if not ok then
        local reason = isolatedKB
        table.insert(output, "")
        table.insert(output, reason .. ".")
        self:ShowCopyableText(table.concat(output, "\n"))
        return
    end

    local perEntryBytes = fullCount > 0 and (isolatedKB * 1024 / fullCount) or 0

    table.insert(output, "")
    table.insert(output, "Corpus size (distinct itemIDs: vendors + quest/achievement/")
    table.insert(output, format("profession/event/drop/shop sources): %d", corpusSize))
    table.insert(output, format("Fully-warmed cache: %d entries.", fullCount))
    table.insert(output, format("Empty-cache baseline: %.1f KB total addon memory.", emptyKB))
    table.insert(output, format("Fully-warmed: %.1f KB total addon memory.", fullKB))
    table.insert(output, format("Isolated cache cost: %.1f KB (%.0f bytes/entry average).",
        isolatedKB, perEntryBytes))
    table.insert(output, "")
    table.insert(output, "Note: excludes parsed sourceText discovery (off by default via")
    table.insert(output, "useParsedSources) -- the real ceiling is higher than this if that")
    table.insert(output, "setting is enabled. Also: the organic ceiling is bounded by catalog")
    table.insert(output, "size, not this corpus size -- a decor item with no known source still")
    table.insert(output, "caches an empty entry when hovered, so real max entries can run slightly")
    table.insert(output, "above this number (Sage HS-279 review).")
    table.insert(output, "")
    table.insert(output, "Cache has been left fully warmed (safe -- it's a pure memo, identical")
    table.insert(output, "to normal play state after enough vendors have been visited).")

    self:ShowCopyableText(table.concat(output, "\n"))
end

-- HS-282: umbrella per-subsystem memory-budget breakdown, extending the
-- memallsources diagnostic pattern (HS-279) above across every subsystem the
-- master ticket's sub-items (A/B/D/E) need prioritized numbers for. Default
-- mode is fully non-destructive: every subsystem is walker-estimated
-- (Core/MemoryEstimator.lua) from its CURRENT organic state via a narrow
-- read-only debug accessor added to each owning module (mirrors
-- SourceManager:GetSourcesMemoEntryCount's existing pattern). 'full'
-- additionally reuses MeasureAllSourcesCacheIsolatedKB for allSourcesCache
-- ONLY -- the one subsystem with an existing, session-safe forced full-corpus
-- rebuild path. Every other subsystem stays walker-estimated even in 'full'
-- mode: none of them expose a synchronous "rebuild everything now" call
-- (badge/search/identity caches all repopulate lazily off the next player
-- action), so wiping one mid-session would leave it silently empty with no
-- guaranteed re-warm -- not safe to force from a diagnostic command.
function HousingAddon:DebugMemBudgetReport(full)
    local ME = HA.MemoryEstimator
    if not ME then
        self:Print("MemoryEstimator unavailable.")
        return
    end

    local output = {}
    local accounted = 0
    table.insert(output, "=== Homestead Memory Budget Breakdown (HS-282) ===")
    table.insert(output, full
        and "Mode: full (additionally forces a one-time allSourcesCache corpus warm -- other lines are still organic snapshots)"
        or "Mode: default (fully non-destructive -- run '/hs debug membudget full' to also isolate allSourcesCache)")
    table.insert(output, "")

    local function reportKB(name, kb, technique)
        accounted = accounted + kb
        table.insert(output, format("%s: %.1f KB (%s)", name, kb, technique))
    end

    local function reportSkip(name, reason)
        table.insert(output, format("%s: not measurable: %s", name, reason))
    end

    -- SourceManager.allSourcesCache (sub-item A) -- reuses memallsources'
    -- proven wipe-delta measurement rather than the walker, per the ticket's
    -- "reuse, don't duplicate" direction. Only available in 'full' mode: the
    -- measurement forces a full-corpus warm, the same one-time cost
    -- memallsources full already documents.
    if full then
        local ok, kbOrReason = self:MeasureAllSourcesCacheIsolatedKB()
        if ok then
            reportKB("SourceManager.allSourcesCache", kbOrReason, "wiped")
        else
            reportSkip("SourceManager.allSourcesCache", kbOrReason)
        end
    else
        reportSkip("SourceManager.allSourcesCache",
            "run '/hs debug membudget full' (reuses memallsources' isolated wipe-delta measurement)")
    end

    -- SourceManager's other memoization caches.
    if HA.SourceManager and HA.SourceManager.GetDebugCacheTables then
        local caches = HA.SourceManager:GetDebugCacheTables()
        reportKB("SourceManager.completionCache", ME.EstimateTableSizeKB(caches.completionCache), "est")
        reportKB("SourceManager.requirementMetCache", ME.EstimateTableSizeKB(caches.requirementMetCache), "est")
    else
        reportSkip("SourceManager.completionCache", "SourceManager unavailable")
        reportSkip("SourceManager.requirementMetCache", "SourceManager unavailable")
    end

    -- HS-281 vendor-items memo (Data/VendorData.lua:1108-1153), lazily built
    -- on first VendorData:GetVendorItems call per npcID.
    if HA.VendorData then
        local memo = HA.VendorData.VendorItemsMemo
        if memo then
            reportKB("VendorData.VendorItemsMemo", ME.EstimateTableSizeKB(memo), "est")
        else
            reportSkip("VendorData.VendorItemsMemo", "not yet built (open a vendor's window at least once, then re-run)")
        end
    else
        reportSkip("VendorData.VendorItemsMemo", "VendorData unavailable")
    end

    -- BadgeCalculation vendor/drop-group stats + badge count caches. Badge
    -- caches are two separate root tables measured as one line via
    -- EstimateTablesSizeKB so a structure shared between them (unlikely but
    -- not assumed) is charged once, not twice (Argus Gate 1 finding #5).
    if HA.BadgeCalculation and HA.BadgeCalculation.GetDebugCacheTables then
        local caches = HA.BadgeCalculation:GetDebugCacheTables()
        reportKB("BadgeCalculation.vendorStatsCache", ME.EstimateTableSizeKB(caches.vendorStatsCache), "est")
        reportKB("BadgeCalculation.dropGroupStatsCache", ME.EstimateTableSizeKB(caches.dropGroupStatsCache), "est")
        local badgeKB = ME.EstimateTablesSizeKB({ caches.cachedZoneBadges, caches.cachedContinentBadges })
        reportKB("BadgeCalculation.badgeCaches", badgeKB, "est")
    else
        reportSkip("BadgeCalculation.vendorStatsCache", "BadgeCalculation unavailable")
        reportSkip("BadgeCalculation.dropGroupStatsCache", "BadgeCalculation unavailable")
        reportSkip("BadgeCalculation.badgeCaches", "BadgeCalculation unavailable")
    end

    -- SearchProvider's built index (nil until the player's first search or
    -- side-panel open).
    if HA.SearchProvider and HA.SearchProvider.GetDebugIndex then
        local index = HA.SearchProvider:GetDebugIndex()
        if index then
            reportKB("SearchProvider.index", ME.EstimateTableSizeKB(index), "est")
        else
            reportSkip("SearchProvider.index", "index not yet built (open the map side panel or search once, then re-run)")
        end
    else
        reportSkip("SearchProvider.index", "SearchProvider unavailable")
    end

    -- CatalogStore's in-memory identity/subclass caches (persisted
    -- SavedVariables tables are reported separately below). Three root
    -- tables measured as one line via EstimateTablesSizeKB, same
    -- shared-seen reasoning as badgeCaches above.
    if HA.CatalogStore and HA.CatalogStore.GetDebugCacheTables then
        local caches = HA.CatalogStore:GetDebugCacheTables()
        local identityKB = ME.EstimateTablesSizeKB({
            caches.identityNegativeCache, caches.identityPositiveCache, caches.housingSubclassCache,
        })
        reportKB("CatalogStore.identityCaches", identityKB, "est")
    else
        reportSkip("CatalogStore.identityCaches", "CatalogStore unavailable")
    end

    -- CatalogOverlay's per-item verdict cache (Overlay/CatalogOverlay.lua:90).
    if HA.CatalogOverlay and HA.CatalogOverlay.GetDebugCacheTables then
        local caches = HA.CatalogOverlay.GetDebugCacheTables()
        reportKB("CatalogOverlay.itemVerdictCache", ME.EstimateTableSizeKB(caches.itemVerdictCache), "est")
    else
        reportSkip("CatalogOverlay.itemVerdictCache", "CatalogOverlay unavailable")
    end

    -- MapPinProvider's three coordinate/geometry caches (UI/MapPinProvider.lua
    -- :25-27), measured as one line via EstimateTablesSizeKB.
    if HA.MapPinProvider and HA.MapPinProvider.GetDebugCacheTables then
        local caches = HA.MapPinProvider.GetDebugCacheTables()
        local mapCachesKB = ME.EstimateTablesSizeKB({
            caches.projectionRectCache, caches.parentMapCache, caches.childMapIDsCache,
        })
        reportKB("MapPinProvider.mapCaches", mapCachesKB, "est")
    else
        reportSkip("MapPinProvider.mapCaches", "MapPinProvider unavailable")
    end

    -- Static Data/ tables (sub-items B/D) -- every pure-data file the .toc
    -- loads. VendorDatabase.lua is NOT in the .toc (HS-242 corrected premise)
    -- and is deliberately not listed. VendorStagedAdditions.lua attaches its
    -- tables onto HA.VendorOffers/HA.VendorIdentity at load time, so it's
    -- already included in those two walks, not a separate line.
    -- NOTE (Argus Gate 1 finding #1/#6): static:AchievementSources
    -- understates that file's true cost -- its achievementToItems reverse
    -- index is built at load time but reachable only via closure upvalue,
    -- invisible to this walker. See Core/MemoryEstimator.lua error source
    -- #6 and tests/hs282_memory_estimator.lua's calibration section.
    local staticTables = {
        { "static:VendorIdentity", HA.VendorIdentity },
        { "static:VendorOffers", HA.VendorOffers },
        { "static:EndeavorsData", HA.EndeavorsData },
        { "static:DecorMapping", HA.DecorMapping },
        { "static:AchievementSources", HA.AchievementSources },
        { "static:QuestSources", HA.QuestSources },
        { "static:ProfessionSources", HA.ProfessionSources },
        { "static:EventSources", HA.EventSources },
        { "static:DropSources", HA.DropSources },
        { "static:ShopSources", HA.ShopSources },
        { "static:PrerequisiteSources", HA.PrerequisiteSources },
        { "static:SourceTextLocaleProfiles", HA.SourceTextLocaleProfiles },
    }
    for _, entry in ipairs(staticTables) do
        local name, tbl = entry[1], entry[2]
        if tbl then
            reportKB(name, ME.EstimateTableSizeKB(tbl), "est")
        else
            reportSkip(name, "table not loaded")
        end
    end

    -- SavedVariables subtrees (sub-item E + the other large db.global tables
    -- HS-282's session context calls out). Each field is checked for nil
    -- individually (Argus Gate 1 finding #7): self.db.global can exist
    -- while a specific subtree is still nil (e.g. parsedSources before the
    -- first scan), and that must read as "not measurable: not initialized",
    -- not a silent, misleading 0.0 KB.
    local function reportSVField(name, value)
        if value == nil then
            reportSkip(name, "not initialized")
        else
            reportKB(name, ME.EstimateTableSizeKB(value), "est")
        end
    end

    if self.db and self.db.global then
        reportSVField("sv:parsedSources", self.db.global.parsedSources)
        reportSVField("sv:scannedVendors", self.db.global.scannedVendors)
        reportSVField("sv:catalogItems", self.db.global.catalogItems)
    else
        reportSkip("sv:parsedSources", "SavedVariables not initialized")
        reportSkip("sv:scannedVendors", "SavedVariables not initialized")
        reportSkip("sv:catalogItems", "SavedVariables not initialized")
    end

    table.insert(output, format("accounted (sum of lines above): %.1f KB", accounted))

    -- Reconciliation (Argus Gate 1 finding #4): compare the sum of every
    -- measured line against the addon's real, live memory footprint, so
    -- this reads as a budget with a residual, not just a list of numbers.
    -- "unaccounted" is expected to be nonzero -- it covers UI frames, Ace3
    -- library overhead (sub-item C), event-frame state, and anything this
    -- report doesn't have a line for yet, not just estimator error.
    if _G.UpdateAddOnMemoryUsage and _G.GetAddOnMemoryUsage then
        _G.collectgarbage("collect")
        _G.UpdateAddOnMemoryUsage()
        local liveTotalKB = _G.GetAddOnMemoryUsage(addonName) or 0
        table.insert(output, format("addon total (live, GetAddOnMemoryUsage): %.1f KB", liveTotalKB))
        table.insert(output, format("unaccounted: %.1f KB", liveTotalKB - accounted))
    else
        table.insert(output, "addon total (live): not measurable: memory API unavailable on this client")
    end

    table.insert(output, "")
    table.insert(output, "Technique key: (wiped) = isolated via GetAddOnMemoryUsage wipe-delta (exact")
    table.insert(output, "for that line). (est) = MemoryEstimator table walker (approximate -- see")
    table.insert(output, "Core/MemoryEstimator.lua's header for its full error-source list and")
    table.insert(output, "tests/hs282_memory_estimator.lua for its calibrated accuracy band per file")
    table.insert(output, "size range). Two DISTINCT (est) error sources can each push the accounted")
    table.insert(output, "sum in either direction, and neither is assumed to dominate: strings shared")
    table.insert(output, "BETWEEN two separately-measured (est) lines are double-counted (inflates the")
    table.insert(output, "sum), while the per-table/per-entry constants themselves can over- or")
    table.insert(output, "under-estimate a given file depending on its size and shape (see the")
    table.insert(output, "calibration test's documented per-file ratios). 'not measurable' lines are")
    table.insert(output, "excluded from the accounted sum.")

    self:ShowCopyableText(table.concat(output, "\n"))
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
        -- HS-239: this direct RefreshAll fires on every loading screen via
        -- PLAYER_ENTERING_WORLD -- a sibling entry into the same repaint the
        -- Events "all" callback measures. Wrapped so an armed trace can't
        -- miss a plot zone-in repaint and still render the affirmative
        -- "nothing was slow" line (Gate 1 warning).
        if HA.PerformanceTrace then
            HA.PerformanceTrace:Measure("bag_refresh", "entering-world", HA.Overlay.RefreshAll, HA.Overlay)
        else
            HA.Overlay:RefreshAll()
        end
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

-- HS-218: HousingAddon:GetVendorDecor removed — it delegated to
-- HA.VendorTracer:GetVendorDecor, a method that doesn't exist anywhere in
-- VendorTracer.lua (would have errored if ever called). Zero callers of
-- this wrapper anywhere in the codebase; removing beats implementing the
-- dead API it pointed at.

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
