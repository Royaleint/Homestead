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
end)
