--[[
    Homestead - Dev Memory Diagnostics (HS-282)

    Dev-only home for the /hs debug memallsources and /hs debug membudget
    commands and the measurement functions behind them. Moved out of
    Core/core.lua per Rawb's ruling (2026-08-14): memory diagnostics are dev
    tooling, not a player-facing feature, so they must not ship in the
    player addon. This file is never listed in Homestead.toc and is excluded
    from the packaged zip (.pkgmeta); Home_Dev/scripts/generate-devbuild-toc
    .mjs appends it (after Core/MemoryEstimator.lua, its dependency) to the
    generated Homestead_DevBuild.toc so both still load under the DevBuild.

    Command registration: self.commands (Foundry.Commands, set up in
    Core/core.lua) is only assigned inside OnInitialize, which core.lua's
    Lifecycle adoption fires off ADDON_LOADED -- before this file's own
    top-level code runs. Rather than have any shipped module reach into this
    dev-only file to register on its behalf (which would put a reference to
    it back in shipped code), this file waits for PLAYER_LOGIN -- which
    always fires after ADDON_LOADED/OnInitialize -- and registers itself.
]]

local addonName, HA = ...

local HousingAddon = HA.Addon
local format = string.format

-- HS-279: isolates allSourcesCache's own memory cost via a forced full-corpus
-- warm bracketed by _G.collectgarbage("collect") + GetAddOnMemoryUsage.
-- Extracted from DebugMemAllSourcesReport (below) so HS-282's membudget
-- report can reuse the exact same measurement instead of duplicating it --
-- allSourcesCache is the one subsystem in that report with a proven,
-- session-safe forced-rebuild path; everything else there is walker-
-- estimated (Core/MemoryEstimator.lua) precisely because it lacks one.
-- Returns true, isolatedKB, fullCount, corpusSize, emptyKB, fullKB on
-- success, or false, reason on a missing prerequisite. HS-282: the forced
-- warm now cycles SourceManager's SOURCES_MEMO_MAX_ENTRIES (512) eviction
-- cap, so it leaves the cache cap-full on success (safe -- it's a pure memo,
-- identical to normal play state once that cap has been reached), not
-- fully warmed with the whole corpus resident.
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
-- cost of a cap-full cache (HS-282: SOURCES_MEMO_MAX_ENTRIES, 512 entries) is
-- measurable, not guessed -- this fed HS-279's original eviction-threshold
-- work and HS-282's own cap sizing.
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
    table.insert(output, format(
        "Cap-full cache: %d entries (HS-282 SOURCES_MEMO_MAX_ENTRIES = 512 -- <= 512 against the "
            .. "larger corpusSize above is expected, not a bug).", fullCount))
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
    table.insert(output, "Cache has been left cap-full (safe -- it's a pure memo, identical to")
    table.insert(output, "normal play state once the 512-entry eviction cap has been reached).")

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
        and "Mode: full (additionally forces a one-time allSourcesCache corpus warm -- other lines are still organic snapshots; also runs the client-wide GC pause described below)"
        or "Mode: default (non-destructive to addon state -- run '/hs debug membudget full' to also isolate allSourcesCache; still runs one client-wide collectgarbage(\"collect\") for the live-total reconciliation below)")
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
    --
    -- Argus Gate 1 (re-review) blocker #2: the ordering inversion that made
    -- the original calibration finding Critical -- AchievementSources is
    -- really the bigger subsystem, but its walker estimate can print BELOW
    -- DecorMapping's -- was still only explained in source comments, invisible
    -- to whoever reads the live /hs debug membudget output. UPVALUE_GAP_LINES
    -- below marks every subsystem KNOWN to have this gap (Core/MemoryEstimator
    -- .lua error source #6: data reachable only through a closure upvalue,
    -- never a table field, is invisible to this walker) with an "est*"
    -- technique suffix directly in the printed line, and the footer spells
    -- out what the asterisk means and names the affected lines.
    local UPVALUE_GAP_LINES = {
        ["static:AchievementSources"] = true,
        ["static:EndeavorsData"] = true,
    }

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
            reportKB(name, ME.EstimateTableSizeKB(tbl), UPVALUE_GAP_LINES[name] and "est*" or "est")
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
    table.insert(output, "under-estimate a given file depending on its size and shape -- an")
    table.insert(output, "over-estimate on the LARGEST line (VendorOffers) is not simply \"safe\": it")
    table.insert(output, "inflates accounted and understates unaccounted by the same amount, and")
    table.insert(output, "makes that one subsystem look relatively even bigger next to every other")
    table.insert(output, "line than it truly is (see the calibration test's documented per-file")
    table.insert(output, "ratios for which lines this affects and by how much).")
    table.insert(output, "(est*) = same as (est), but this subsystem ALSO holds data reachable only")
    table.insert(output, "through a closure upvalue -- never a table field -- which is structurally")
    table.insert(output, "invisible to the walker, so the true size is LARGER than shown (not just")
    table.insert(output, "imprecise the way a plain (est) line is). Known affected lines:")
    table.insert(output, "static:AchievementSources (~1/3 of its real footprint is the hidden")
    table.insert(output, "achievementToItems index) and static:EndeavorsData (lowerVendorNameToNpcID,")
    table.insert(output, "same pattern, smaller share). See Core/MemoryEstimator.lua error source #6.")
    table.insert(output, "'not measurable' lines are excluded from the accounted sum.")

    self:ShowCopyableText(table.concat(output, "\n"))
end

-- HS-300: dev-gated restore for the keys the v6 migration dropped. Thin
-- wrapper around CatalogStore:RestoreV5Backup() -- that function holds the
-- actual restore logic so it can be exercised without loading this dev-only
-- file. This layer is just the player-facing print.
function HousingAddon:DebugRestoreV5Backup()
    local ok, restoredCountOrReason, savedAt, addonVersion = HA.CatalogStore:RestoreV5Backup()
    if not ok then
        print("|cff00ccff[Homestead]|r No v5 backup found (" .. tostring(restoredCountOrReason) .. ").")
        return
    end

    local savedAtText = savedAt and date("%Y-%m-%d %H:%M", savedAt) or tostring(savedAt)
    print(format("|cff00ccff[Homestead]|r restored %d keys from backup taken %s by %s -- /reload to re-run migrations.",
        restoredCountOrReason, savedAtText, tostring(addonVersion)))
end

-- HS-282 sub-item I: itemizes /hs debug membudget's "unaccounted" remainder by
-- walking the addon's ENTIRE reachable table graph from a fixed, ordered list
-- of owned/shared roots (Core/MemoryEstimator.lua's sweep engine), instead of
-- membudget's curated per-subsystem list above. Building the line for one
-- root: nil roots (e.g. sv:HomesteadDB before first save) read as "not
-- measurable: not initialized" rather than a misleading 0.0 KB, mirroring
-- DebugMemBudgetReport's reportSVField above.
local function FormatSweepLine(name, kb, tables, functions, widgets, shared)
    local descriptor = format("%d tables, %d fn, %d widgets", tables, functions, widgets)
    if tables > 0 and functions > 0.25 * tables then
        descriptor = descriptor .. ", fn-heavy"
    end
    return format("%s: %.1f KB (sweep; %s)%s", name, kb, descriptor, shared and " (shared)" or "")
end

-- Builds the full report as an array of lines (not yet concatenated), so
-- DebugMemFloorReport can wrap the whole build in one pcall (design §5
-- reentrancy: an error here must clear the running flag, not wedge the
-- command). Returns the output array on success; errors propagate to the
-- caller's pcall.
local function BuildMemFloorReport(self, ME, deep)
    local output = {}
    table.insert(output, "=== Homestead Memory Floor Sweep (HS-282 sub-item I) ===")
    table.insert(output, deep
        and "Mode: deep (also walks widget tables -- runs one client-wide collectgarbage(\"collect\") for the live-total reconciliation below, exactly like membudget)"
        or "Mode: default (widget tables are counted, not walked -- run '/hs debug memfloor deep' to also walk them; still runs one client-wide collectgarbage(\"collect\") for the live-total reconciliation below, exactly like membudget)")
    table.insert(output, "")

    -- Foundry-1.0 bootstrap gate (Libs/Foundry-1.0/Foundry.lua:100-128): the
    -- first copy to load wins the runtime symbol and serves everyone; when a
    -- standalone Foundry-1.0/Foundry-1.0_DevBuild install wins instead of
    -- this DevBuild's embed, its bytes belong to that addon, not to us.
    local foundryEmbedded = not C_AddOns.IsAddOnLoaded("Foundry-1.0")
        and not C_AddOns.IsAddOnLoaded("Foundry-1.0_DevBuild")
    table.insert(output, foundryEmbedded
        and "Foundry-1.0: this build's embedded copy is serving (walked below as lib:Foundry-1.0)."
        or "Foundry-1.0: a standalone copy is serving; this build's embed loaded nothing (skipped below).")
    table.insert(output, "")

    local ctx = ME.NewSweepContext({ walkWidgets = deep })
    ME.SeedForeignRoots(ctx, foundryEmbedded)

    local ownedTotal, sharedTotal, ownerLines = 0, 0, 0
    local aborted = false

    local function sweepOwned(name, root)
        if aborted then return end
        if root == nil then
            table.insert(output, format("%s: not measurable: not initialized", name))
            return
        end
        local bytes, tables, functions, widgets = ME.SweepRoot(ctx, root)
        if ctx.aborted then
            aborted = true
            return
        end
        local kb = bytes / 1024
        ownedTotal = ownedTotal + kb
        ownerLines = ownerLines + 1
        table.insert(output, FormatSweepLine(name, kb, tables, functions, widgets, false))
    end

    local function sweepShared(name, root, skipMessage)
        if aborted then return end
        if root == nil then
            table.insert(output, skipMessage or format("%s: skipped (unavailable)", name))
            return
        end
        local bytes, tables, functions, widgets = ME.SweepRoot(ctx, root)
        if ctx.aborted then
            aborted = true
            return
        end
        local kb = bytes / 1024
        sharedTotal = sharedTotal + kb
        table.insert(output, FormatSweepLine(name, kb, tables, functions, widgets, true))
    end

    -- GetTimePreciseSec brackets ONLY the table walk below -- the final
    -- reconciliation GC pass further down is excluded on purpose (design §5).
    -- (Not debugprofilestop: any addon's debugprofilestart() call between our
    -- two reads would reset it and falsify the cost; GetTimePreciseSec is
    -- monotonic and matches this repo's convention.)
    local sweepStartSec = _G.GetTimePreciseSec()

    table.insert(output, "-- Owned --")
    -- Root order is load-bearing (design §1a/§2): first-owner-wins
    -- attribution means each later root's KB is only what's new at that
    -- point, so this order can never be replaced with pairs() order.
    sweepOwned("sv:HomesteadDB", _G.HomesteadDB)
    sweepOwned("addon:db", self.db)
    sweepOwned("addon:core", self)

    local haKeys = {}
    for k in pairs(HA) do
        if k ~= "Addon" then
            haKeys[#haKeys + 1] = k
        end
    end
    table.sort(haKeys)

    local nonTableCount = 0
    for _, k in ipairs(haKeys) do
        if aborted then
            break
        end
        local v = HA[k]
        if type(v) == "table" then
            sweepOwned(k, v)
        else
            nonTableCount = nonTableCount + 1
        end
    end
    if not aborted then
        table.insert(output, format("HA (non-table keys): %d", nonTableCount))
    end

    if not aborted then
        table.insert(output, format("owned total: %.1f KB", ownedTotal))
        table.insert(output, "")

        table.insert(output, "-- Shared (never folded into owned total) --")
        sweepShared("lib:Foundry-1.0", foundryEmbedded and _G.Foundry_1_0 or nil,
            not foundryEmbedded
                and "lib:Foundry-1.0: skipped (standalone Foundry-1.0 is loaded; its bytes are billed to that addon)"
                or nil)
        sweepShared("lib:LibStub", _G.LibStub)
    end

    if aborted then
        table.insert(output, "")
        table.insert(output, format("SWEEP ABORTED at the %d-node cap -- the ownership boundary leaked; these numbers are not usable.", ctx.nodeCap))
        return output
    end

    local sweepCostMs = (_G.GetTimePreciseSec() - sweepStartSec) * 1000

    table.insert(output, format("shared total: %.1f KB", sharedTotal))
    table.insert(output, "")

    -- Reconciliation: exactly membudget's GC behavior (DebugMemBudgetReport
    -- above) -- one collectgarbage("collect") right before the live read, in
    -- every mode. 'deep' adds no extra GC.
    local addonTotalKB = 0
    if _G.UpdateAddOnMemoryUsage and _G.GetAddOnMemoryUsage then
        _G.collectgarbage("collect")
        _G.UpdateAddOnMemoryUsage()
        addonTotalKB = _G.GetAddOnMemoryUsage(addonName) or 0
        table.insert(output, format("addon total (live, GetAddOnMemoryUsage): %.1f KB", addonTotalKB))

        local containedKB = ownedTotal + sharedTotal
        if containedKB <= addonTotalKB then
            table.insert(output, "CONTAINMENT: ok")
        else
            table.insert(output, format("CONTAINMENT: VIOLATED by %.1f KB", containedKB - addonTotalKB))
        end
    else
        table.insert(output, "addon total (live): not measurable: memory API unavailable on this client")
    end
    table.insert(output, "")

    table.insert(output, format("remainder (shared libs billed to Homestead):  total - owned - shared = %.1f KB",
        addonTotalKB - ownedTotal - sharedTotal))
    table.insert(output, format("remainder (shared libs billed elsewhere):     total - owned          = %.1f KB",
        addonTotalKB - ownedTotal))
    table.insert(output, "")
    table.insert(output, "Remainder composition (none of it measurable from Lua): compiled function bytecode for every file")
    table.insert(output, "in the TOC, closure objects and their upvalue arrays, data reachable only through a closure upvalue")
    table.insert(output, "(MemoryEstimator error source #6), widget Lua-field storage not walked in this mode, Lua VM")
    table.insert(output, "internals (string-intern table, GC bookkeeping), and this walker's own estimation error. The")
    table.insert(output, "closure share arrives by subtraction and is not separable from the rest.")
    table.insert(output, "")

    table.insert(output, format("functions counted across the sweep: %d", ctx.functions))
    table.insert(output, format("owner lines: %d", ownerLines))
    table.insert(output, format("sweep cost: %.1f ms (GetTimePreciseSec bracket, excludes the GC pass)", sweepCostMs))
    table.insert(output, "")

    table.insert(output, "Technique key: (sweep) = full-reachability walk sharing one visited set, same byte")
    table.insert(output, "model and same documented error sources as membudget's (est) (see")
    table.insert(output, "Core/MemoryEstimator.lua). Strings dedup across ALL lines in this report (not just")
    table.insert(output, "within one line's own walk), so membudget's error source #2 (cross-line string")
    table.insert(output, "double-counting) does not apply here. Attribution is first-owner-wins by the fixed")
    table.insert(output, "owned-root order printed above, never pairs() order (nondeterministic between runs,")
    table.insert(output, "which would make two captures non-comparable) -- an earlier owner absorbs every")
    table.insert(output, "structure it shares with a later one, so a later owner's KB reads as \"bytes it owns")
    table.insert(output, "exclusively, given everything earlier in this list,\" never an independent total.")
    table.insert(output, "This is a relative-magnitude ranking, not an accurate byte count: the three")
    table.insert(output, "constants were jointly fit against pure-data Data/ files (integer/string keys, few")
    table.insert(output, "function values); a module table's function values are each charged")
    table.insert(output, "HASH_ENTRY_BYTES + OTHER_VALUE_BYTES, and that OTHER_VALUE_BYTES figure is an")
    table.insert(output, "UNCALIBRATED placeholder (error source #5), never fitted against real function-heavy")
    table.insert(output, "tables. No per-owner KB may be quoted as an accurate size, only as a rank.")
    table.insert(output, "fn is a COUNT of distinct function objects reached, never a size -- a Lua function")
    table.insert(output, "object and its upvalue array cannot be sized from Lua code. widgets is a count of")
    table.insert(output, "distinct widget tables reached (rawget(t, 0) ~= nil, or a GetObjectType method); by")
    table.insert(output, "default charged HEADER_BYTES only and not descended into (see design §1d) --")
    table.insert(output, "'deep' mode walks them too. (shared) marks a line whose bytes are never folded into")
    table.insert(output, "the owned total -- which addon a shared library's bytes are truly billed to depends")
    table.insert(output, "on load order and isn't knowable from Lua. fn-heavy marks a line where functions")
    table.insert(output, "exceed 25% of its table count -- those lines carry the largest unquantified error")
    table.insert(output, "above, since a function-heavy table's real size is systematically understated here.")

    return output
end

-- Entry point for '/hs debug memfloor [deep]'. Reentrancy guard lives on
-- MemoryEstimator itself (ME._sweepRunning) since the sweep engine is the
-- shared resource being protected; wrapping the build in pcall means a Lua
-- error mid-sweep clears the flag and re-raises instead of wedging the
-- command for the rest of the session (design §5).
function HousingAddon:DebugMemFloorReport(deep)
    local ME = HA.MemoryEstimator
    if not ME then
        self:Print("MemoryEstimator unavailable.")
        return
    end
    if ME._sweepRunning then
        self:Print("A memory floor sweep is already running.")
        return
    end

    ME._sweepRunning = true
    local ok, outputOrErr = pcall(BuildMemFloorReport, self, ME, deep)
    ME._sweepRunning = false
    if not ok then
        error(outputOrErr, 0)
    end

    self:ShowCopyableText(table.concat(outputOrErr, "\n"))
end

-- Command registration (see file header): waits for PLAYER_LOGIN, by which
-- point core.lua's OnInitialize (ADDON_LOADED-triggered) has always already
-- run, so self.commands is guaranteed to exist. This is the ONLY hook this
-- file needs -- no shipped module calls into it, so shipped code carries no
-- reference back to this file.
local devDiagFrame = CreateFrame("Frame")
devDiagFrame:RegisterEvent("PLAYER_LOGIN")
devDiagFrame:SetScript("OnEvent", function()
    HousingAddon.commands:Register({ name = "debug memallsources", args = "[full]",
        help = "Report allSourcesCache size/memory (HS-279). 'full' forces a full-corpus warm to isolate its cost.",
        handler = function(rest) HousingAddon:DebugMemAllSourcesReport(rest == "full") end })
    HousingAddon.commands:Register({ name = "debug membudget", args = "[full]",
        help = "Per-subsystem memory budget breakdown (HS-282). 'full' additionally isolates allSourcesCache via a forced full-corpus warm.",
        handler = function(rest) HousingAddon:DebugMemBudgetReport(rest == "full") end })
    HousingAddon.commands:Register({ name = "debug restorev5", args = "",
        help = "HS-300: restore the keys the v6 migration dropped from db.global.__v5Backup, stamp schemaVersion 5, then /reload.",
        handler = function() HousingAddon:DebugRestoreV5Backup() end })
    HousingAddon.commands:Register({ name = "debug memfloor", args = "[deep]",
        help = "Full-reachability per-owner memory sweep (HS-282 sub-item I). 'deep' also walks widget tables.",
        handler = function(rest) HousingAddon:DebugMemFloorReport(rest == "deep") end })
end)
