--[[
    Homestead - BadgeCalculation
    Zone/continent badge counts and collection status calculation

    Extracted from VendorMapPins.lua to reduce file size.
    Collection caches and badge counts. Geography tables and coordinate
    projection delegated to MapPinProvider. All data flows through VendorFilter.

    External callers should use VendorMapPins delegation wrappers
    (InvalidateAllCaches, InvalidateBadgeCache, GetVendorCollectionCounts)
    to ensure dedup guards are also reset.
]]

local _, HA = ...

local BadgeCalculation = {}
HA.BadgeCalculation = BadgeCalculation

-- VendorFilter reference (loaded before this file per TOC order)
local VF = HA.VendorFilter
local Constants = HA.Constants
local MPP = HA.MapPinProvider

-------------------------------------------------------------------------------
-- Zone to Parent Map Mapping (delegated to MapPinProvider)
-------------------------------------------------------------------------------
BadgeCalculation.continentToZones = MPP.continentToZones

function BadgeCalculation.GetContinentForZone(zoneMapID)
    return MPP.GetContinentForZone(zoneMapID)
end

-- Resolve vertically-sibling zones to a canonical mapID.
-- The "above" sibling is canonical (e.g., Dalaran 627 absorbs Underbelly 628).
-- Returns input mapID unchanged if it has no siblings or is already canonical.
function BadgeCalculation.GetCanonicalZoneMapID(zoneMapID)
    if not Constants or not Constants.VerticalSiblings then
        return zoneMapID
    end
    local siblings = Constants.VerticalSiblings[zoneMapID]
    if not siblings then
        return zoneMapID
    end
    for siblingMapID, direction in pairs(siblings) do
        if direction == "above" then
            return siblingMapID
        end
    end
    return zoneMapID
end

-------------------------------------------------------------------------------
-- Caches
-------------------------------------------------------------------------------

-- Cached per-vendor stats keyed by "npcID|sourceFilter".
-- hasUncollectedState stores true / false / "unknown".
local vendorStatsCache = {}

-- HS-278: bumped on every vendorStatsCache wipe/invalidation so the sliced
-- prewarm item loop (below) can detect a mid-vendor invalidation and discard
-- its in-progress accumulator instead of blending pre/post-invalidation item
-- state into one cached result.
local vendorStatsCacheGeneration = 0

-- Cached badge counts (invalidated on ownership/scan/settings changes)
-- Keyed by "continentMapID|sourceFilter" for zone badges, sourceFilter for continent badges.
local cachedZoneBadges = {}
local cachedContinentBadges = {}

-- HS-234: forward-declared here (ahead of InvalidateAllCaches below, which
-- calls it) — the real function body is assigned much further down, after
-- StartPrewarmPass exists for it to reference. Lua locals must be declared
-- before any reference to them, even though the call only ever happens
-- after the whole file — and this assignment — has finished loading.
local RequestVendorStatsPrewarm

local function ShouldIncludeVendorInBadgeCounts(vendor)
    if not vendor or not vendor.endeavor then
        return true
    end

    if HA.EndeavorsData and HA.EndeavorsData.IsVendorActive then
        return HA.EndeavorsData:IsVendorActive(vendor)
    end

    return true
end

-- Normalize source filter token used in cache keys and filtering checks.
local function NormalizeSourceFilter(sourceFilter)
    local SM = HA.SourceManager
    if SM and SM.NormalizeSourceFilter then
        return SM:NormalizeSourceFilter(sourceFilter)
    end

    if type(sourceFilter) ~= "string" or sourceFilter == "" then
        return "all"
    end

    local lower = sourceFilter:lower()
    if lower == "all" then
        return "all"
    end

    return lower
end

-- HS-158/160 §1/H3: availability (promotion expiry) is day-stamped at the
-- SourceManager layer, but these caches are otherwise only invalidated by
-- ownership/scan/settings EVENTS — a vendor's stats computed before midnight
-- would keep reading the stale unobtainable classification until an
-- unrelated event fired. Folding the server date into every availability-
-- derived cache key here makes them expire naturally at server midnight,
-- no timers required. Falls back to a stable placeholder if the API is
-- unavailable so caching still works (just without the day-of-month split).
local function GetAvailabilityDateStamp()
    local SM = HA.SourceManager
    if SM and SM.GetServerDateStamp then
        return SM:GetServerDateStamp() or "unknown"
    end
    return "unknown"
end

local function BuildVendorFilterCacheKey(vendor, sourceFilter)
    return tostring(vendor.npcID) .. "|" .. NormalizeSourceFilter(sourceFilter) .. "|" .. GetAvailabilityDateStamp()
end

local function ItemMatchesSourceFilter(itemID, sourceFilter)
    local normalizedFilter = NormalizeSourceFilter(sourceFilter)
    if normalizedFilter == "all" then
        return true
    end

    local SM = HA.SourceManager
    if SM and SM.ItemMatchesSourceFilter then
        -- Vendor-scoped context: all vendor inventory items are vendor-eligible.
        return SM:ItemMatchesSourceFilter(itemID, normalizedFilter, true)
    end

    return false
end

-------------------------------------------------------------------------------
-- Collection Status
-------------------------------------------------------------------------------

local UNKNOWN_VENDOR_STATS = {
    hasUncollectedState = "unknown",
    collected = 0,
    purchasable = 0,
    locked = 0,
    unverified = 0,
    unobtainable = 0,
    excluded = 0,
    blockers = nil,
    total = 0,
    vendorOnly = 0,
}

-- HS-249: is this item's ownership knowable at all? Every housing subclass
-- except Decor resolves to no catalog entry, so its ownership reads as a hard
-- false that says nothing about the player. Mirrors the isOwned resolution
-- below, including the cache-only no-presentation fallback.
local function IsOwnershipExcluded(itemID, presentation)
    if presentation then
        return presentation.isOwnershipExcluded == true
    end
    if HA.CatalogStore and HA.CatalogStore.IsOwnershipUnknowable then
        return HA.CatalogStore:IsOwnershipUnknowable(itemID) == true
    end
    return false
end

-- HS-074: true when the item has no source types other than vendor-like
-- (vendor/event/shop). Approximation of "this vendor-NPC is the only path."
-- Moved here from VendorMapPins.lua (Argus review) so BuildVendorStats' item
-- loop can produce the "Vendor-only" count from the same population as
-- collected/total/locked, instead of a second differently-filtered pass over
-- the tooltip's hand-rolled item list. Optional `sources` lets a caller that
-- already has GetAllSources' result (e.g. AccumulateVendorItem's
-- presentation.allSources) pass them in and skip the second lookup;
-- GetAllSources is memoized regardless (HS-273/281/282). src.type runs
-- through NormalizeSourceType, matching every other source.type consumer.
local function IsItemVendorOnly(itemID, sources)
    local SM = HA.SourceManager
    if not itemID or not SM then return false end
    if not sources and SM.GetAllSources then
        sources = SM:GetAllSources(itemID)
    end
    if not sources or #sources == 0 then return true end
    for _, src in ipairs(sources) do
        local normalizedType = SM.NormalizeSourceType and SM:NormalizeSourceType(src.type) or src.type
        if normalizedType ~= "vendor" and normalizedType ~= "event" and normalizedType ~= "shop" then
            return false
        end
    end
    return true
end

-- HS-278: per-vendor accumulator state, extracted out of BuildVendorStats so
-- the prewarm pass's item loop (below) can resume it across ticks instead of
-- running one vendor's whole item list in a single unbreakable call.
local function NewVendorStatsAccum()
    return {
        hasMatchingItems = false,
        total = 0,
        collected = 0,
        purchasable = 0,
        locked = 0,
        unobtainable = 0,
        excluded = 0,
        vendorOnly = 0,
        provisionalUnverified = 0,
        hasAnyVerifiableRequirements = false,
        lockedBlockerCounts = {},
    }
end

-- One item's worth of BuildVendorStats' loop body, mutating accum fields
-- instead of closure locals so it can be called once per tick when sliced.
local function AccumulateVendorItem(accum, itemID, vendor, sourceFilter)
    local SM = HA.SourceManager
    local presentation = nil
    if SM and SM.GetItemPresentation then
        presentation = SM:GetItemPresentation(itemID, {
            context = "badge",
            npcID = vendor.npcID,
            sourceFilter = sourceFilter,
            isVendorContext = true,
        })
    end

    local matchesSourceFilter = presentation and presentation.matchesSourceFilter
        or (not presentation and ItemMatchesSourceFilter(itemID, sourceFilter))

    -- HS-249: tested ahead of everything else in the branch, unlike the
    -- `unobtainable` divert below — that one comes after isOwned because
    -- ownership is knowable and wins, whereas here it is unknowable and
    -- consulting it is the thing being ruled out. hasMatchingItems stays
    -- false too: a housing-only vendor that claimed matching items would
    -- read "known, empty, all collected" instead of unknown.
    if matchesSourceFilter and IsOwnershipExcluded(itemID, presentation) then
        accum.excluded = accum.excluded + 1
    elseif matchesSourceFilter then
        accum.hasMatchingItems = true

        local state = presentation and presentation.availabilityState or "purchasable"
        local isUnverified = presentation and presentation.isUnverified or false
        local hasVerifiableRequirement = presentation and presentation.hasVerifiableRequirement or false
        local blockerLabels = presentation and presentation.blockerLabels or nil
        -- HS-074: same population as total (owned + locked/purchasable below,
        -- not the unobtainable branch) so the tooltip's "Vendor-only: N" line
        -- never contradicts the collected/total numbers next to it.
        local isVendorOnlyItem = IsItemVendorOnly(itemID, presentation and presentation.allSources)

        -- HS-200: badge recounts are an aggregate per-vendor-item loop —
        -- this no-presentation fallback must stay cache-only the same way
        -- the primary presentation.isOwned path is (SourceManager's
        -- "badge" context), or it reintroduces the per-item API burst.
        local isOwned = presentation and presentation.isOwned
        if not presentation and HA.CatalogStore and HA.CatalogStore.IsOwned then
            isOwned = HA.CatalogStore:IsOwned(itemID) == true
        end

        if isOwned then
            -- Owned items always count toward collected/total, even if
            -- the underlying requirement (e.g. a promotion) is also
            -- unobtainable for other players — the player already has it.
            accum.collected = accum.collected + 1
            accum.total = accum.total + 1
            if isVendorOnlyItem then
                accum.vendorOnly = accum.vendorOnly + 1
            end
        elseif state == "unobtainable" then
            -- HS-158/160 §3/decision 4: unowned unobtainable items
            -- (promotion-gated, live or expired) are EXCLUDED from total
            -- so collected/total can reach completion. This must be
            -- checked before the locked/purchasable split below.
            accum.unobtainable = accum.unobtainable + 1
        else
            accum.total = accum.total + 1
            if isVendorOnlyItem then
                accum.vendorOnly = accum.vendorOnly + 1
            end

            if isUnverified then
                accum.provisionalUnverified = accum.provisionalUnverified + 1
            elseif hasVerifiableRequirement then
                accum.hasAnyVerifiableRequirements = true
            end

            if state == "locked" then
                accum.locked = accum.locked + 1
                if blockerLabels then
                    for _, blockerLabel in ipairs(blockerLabels) do
                        accum.lockedBlockerCounts[blockerLabel] = (accum.lockedBlockerCounts[blockerLabel] or 0) + 1
                    end
                end
            else
                accum.purchasable = accum.purchasable + 1
            end
        end
    end
end

-- Trailing logic from BuildVendorStats: the "no matching items" early-exit
-- shape and the blocker-sort + final table build.
local function FinalizeVendorStatsAccum(accum)
    -- No matching items under this filter is a known empty result, not unknown.
    -- HS-249: unless the only things this vendor sells under the filter are
    -- items whose ownership we cannot compute — that is genuinely unknown, and
    -- reporting `false` here would render it as "you own everything on this
    -- vendor". With no excluded items this is the pre-HS-249 value exactly.
    if not accum.hasMatchingItems then
        return {
            hasUncollectedState = accum.excluded > 0 and "unknown" or false,
            collected = 0,
            purchasable = 0,
            locked = 0,
            unverified = 0,
            unobtainable = 0,
            excluded = accum.excluded,
            blockers = nil,
            total = 0,
            vendorOnly = 0,
        }
    end

    -- Sort blockers by count descending, then alphabetically for stability.
    local blockers = nil
    if next(accum.lockedBlockerCounts) ~= nil then
        blockers = {}
        for label, count in pairs(accum.lockedBlockerCounts) do
            blockers[#blockers + 1] = {
                label = label,
                count = count,
            }
        end
        table.sort(blockers, function(a, b)
            if a.count ~= b.count then
                return a.count > b.count
            end
            return a.label < b.label
        end)
    end

    return {
        hasUncollectedState = (accum.purchasable + accum.locked) > 0,
        collected = accum.collected,
        purchasable = accum.purchasable,
        locked = accum.locked,
        -- Only report unverified when the vendor has at least some verifiable data.
        -- Pure no-data vendors stay optimistic with zero unverified.
        unverified = accum.hasAnyVerifiableRequirements and accum.provisionalUnverified or 0,
        unobtainable = accum.unobtainable,
        excluded = accum.excluded,
        blockers = blockers,
        total = accum.total,
        vendorOnly = accum.vendorOnly,
    }
end

local function BuildVendorStats(vendor, sourceFilter)
    -- Keep a defensive guard here because badge hot paths read stats directly.
    if not vendor or not vendor.npcID then
        return UNKNOWN_VENDOR_STATS
    end

    -- Merge static + scanned items from shared VendorData helper, using its
    -- stable ordered array so this loop and the sliced prewarm loop below
    -- see the exact same iteration order.
    local orderedItemIDs
    if HA.VendorData and HA.VendorData.GetMergedItemSet then
        local _, ids = HA.VendorData:GetMergedItemSet(vendor, true)
        orderedItemIDs = ids
    end

    -- If we have no item data at all, status is "unknown" and counts are zero.
    if not orderedItemIDs or #orderedItemIDs == 0 then
        return UNKNOWN_VENDOR_STATS
    end

    local accum = NewVendorStatsAccum()
    for _, itemID in ipairs(orderedItemIDs) do
        AccumulateVendorItem(accum, itemID, vendor, sourceFilter)
    end

    return FinalizeVendorStatsAccum(accum)
end

-- Public vendor stats accessor with caching. All UI consumers should use
-- this instead of re-deriving counts independently.
function BadgeCalculation:GetVendorStats(vendor, sourceFilter)
    if not vendor or not vendor.npcID then
        return UNKNOWN_VENDOR_STATS
    end

    local cacheKey = BuildVendorFilterCacheKey(vendor, sourceFilter)
    local cached = vendorStatsCache[cacheKey]
    if cached then
        return cached
    end

    local stats = BuildVendorStats(vendor, sourceFilter)
    vendorStatsCache[cacheKey] = stats
    return stats
end

-- HS-271 item 2: cache-only peek, same cache-key derivation as GetVendorStats
-- above but NEVER computes on a miss. Cold-pin count text uses this so a
-- pin's frame-acquire never pays BuildVendorStats' per-item
-- GetItemPresentation loop -- the exact cost the background prewarm pass
-- already exists to move off the render path.
function BadgeCalculation:PeekVendorStats(vendor, sourceFilter)
    if not vendor or not vendor.npcID then
        return nil
    end

    local cacheKey = BuildVendorFilterCacheKey(vendor, sourceFilter)
    return vendorStatsCache[cacheKey]
end

-- Local alias for internal callers (aggregate builders) that need
-- the same caching without going through the colon-method dispatch.
local function GetVendorStats(vendor, sourceFilter)
    return BadgeCalculation:GetVendorStats(vendor, sourceFilter)
end

-------------------------------------------------------------------------------
-- HS-229: Drop Pin Group Stats
--
-- Mirrors BuildVendorStats/GetVendorStats for a grouped drop pin's records
-- (one or more {itemID, drop} pairs — an EJ entrance pin can group several
-- different bosses' rows). No source-filter matching is needed the way
-- vendor stats needs it: every record in a drop pin's group is already
-- drop-sourced by construction, there's no mixed-source item list to filter.
-- Same collected/locked/purchasable semantics as BuildVendorStats so the
-- pin badges read identically, and the SAME per-item presentation call
-- AddPinTooltipItemLine already uses for drop-pin tooltips (context =
-- "dropMapPin") — cache-only, HS-203/HS-200's no-live-API-on-hot-path rule.
-------------------------------------------------------------------------------

local UNKNOWN_DROP_GROUP_STATS = {
    collected = 0,
    purchasable = 0,
    locked = 0,
    unobtainable = 0,
    excluded = 0,
    total = 0,
}

-- Cached per-group stats keyed by the group's sorted itemID list + date stamp.
local dropGroupStatsCache = {}

local function BuildDropGroupCacheKey(records)
    local ids = {}
    for i, itemRecord in ipairs(records) do
        ids[i] = itemRecord.itemID
    end
    -- VendorMapPins.lua sorts group.records by itemID before this is ever
    -- called, so the join is already stable/order-independent.
    return table.concat(ids, ",") .. "|" .. GetAvailabilityDateStamp()
end

local function BuildDropGroupStats(records)
    local SM = HA.SourceManager
    local total, collected, purchasable, locked, unobtainable = 0, 0, 0, 0, 0
    local excluded = 0

    for _, itemRecord in ipairs(records) do
        local itemID = itemRecord.itemID
        local presentation = nil
        if SM and SM.GetItemPresentation then
            presentation = SM:GetItemPresentation(itemID, {
                context = "dropMapPin",
                sourceFilter = "drop",
                isVendorContext = false,
            })
        end

        local state = presentation and presentation.availabilityState or "purchasable"
        -- HS-200: cache-only fallback, matching AddPinTooltipItemLine's own
        -- no-presentation path — never a live API call on this render path.
        local isOwned = presentation and presentation.isOwned
        if not presentation and HA.CatalogStore and HA.CatalogStore.IsOwned then
            isOwned = HA.CatalogStore:IsOwned(itemID) == true
        end

        -- HS-249: same ordering as BuildVendorStats — the exclusion is tested
        -- before ownership, not after it like `unobtainable`.
        if IsOwnershipExcluded(itemID, presentation) then
            excluded = excluded + 1
        elseif isOwned then
            collected = collected + 1
            total = total + 1
        elseif state == "unobtainable" then
            unobtainable = unobtainable + 1
        else
            total = total + 1
            if state == "locked" then
                locked = locked + 1
            else
                purchasable = purchasable + 1
            end
        end
    end

    return {
        collected = collected,
        purchasable = purchasable,
        locked = locked,
        unobtainable = unobtainable,
        excluded = excluded,
        total = total,
    }
end

-- Public drop-group stats accessor with caching, mirroring GetVendorStats.
function BadgeCalculation:GetDropGroupStats(records)
    if not records or #records == 0 then
        return UNKNOWN_DROP_GROUP_STATS
    end

    local cacheKey = BuildDropGroupCacheKey(records)
    local cached = dropGroupStatsCache[cacheKey]
    if cached then
        return cached
    end

    local stats = BuildDropGroupStats(records)
    dropGroupStatsCache[cacheKey] = stats
    return stats
end

function BadgeCalculation:VendorHasUncollectedItems(vendor, sourceFilter)
    if not vendor or not vendor.npcID then return nil end

    local stats = GetVendorStats(vendor, sourceFilter)
    if stats.hasUncollectedState == "unknown" then
        return nil
    end

    return stats.hasUncollectedState == true
end

-- Backward-compatible wrapper: returns collected, total only.
function BadgeCalculation:GetVendorCollectionCounts(vendor, sourceFilter)
    if not vendor or not vendor.npcID then return 0, 0 end

    local stats = self:GetVendorStats(vendor, sourceFilter)
    return stats.collected or 0, stats.total or 0
end

-- Format count text with inline color escapes: green collected / white total / red locked.
-- Falls back to collected/total when locked == 0.
-- Shared by PinFrameFactory and MapSidePanel.
function BadgeCalculation.FormatCountText(collected, total, locked)
    local ownedText = string.format("|cFF00FF00%d|r", collected or 0)
    local totalText = string.format("|cFFFFFFFF%d|r", total or 0)

    if locked and locked > 0 then
        return ownedText .. "/" .. totalText .. "/" .. string.format("|cFFFF4040%d|r", locked)
    end

    return ownedText .. "/" .. totalText
end

-- Format the tooltip summary line: "Collected: X/Y | Locked: Z".
-- Adds the line directly to the given tooltip. Shared by all vendor/zone tooltips.
-- Optional unverified count shown on a second line when > 0.
function BadgeCalculation.AddSummaryLine(tooltip, collected, total, locked, unverified)
    collected = collected or 0
    total = total or 0
    locked = locked or 0
    unverified = unverified or 0

    if total == 0 then return end

    if locked > 0 then
        tooltip:AddLine(string.format(
            "|cFF00FF00Collected|r: %d/%d | |cFFFF4040Locked|r: %d",
            collected, total, locked
        ), 1, 1, 1)
    else
        tooltip:AddLine(string.format(
            "|cFF00FF00Collected|r: %d/%d",
            collected, total
        ), 1, 1, 1)
    end

    if unverified > 0 then
        tooltip:AddLine(string.format("(%d unverified)", unverified), 1.0, 0.82, 0.0)
    end
end

-------------------------------------------------------------------------------
-- Cache Invalidation
-------------------------------------------------------------------------------

function BadgeCalculation:InvalidateBadgeCache()
    wipe(cachedZoneBadges)
    wipe(cachedContinentBadges)
end

-- HS-278 accepted tradeoff: an ownership-update invalidation storm arriving
-- faster than one large vendor's total slice time will restart that vendor's
-- prewarm accumulator repeatedly for as long as the storm lasts. Each
-- restart is correct (the cache really was invalidated), live callers still
-- get synchronous fresh data throughout, and the slice completes once the
-- storm settles. This is a liveness delay, not a correctness bug, and is
-- intentionally not solved further.
function BadgeCalculation:InvalidateAllCaches()
    vendorStatsCacheGeneration = vendorStatsCacheGeneration + 1
    wipe(vendorStatsCache)
    wipe(dropGroupStatsCache)
    self:InvalidateBadgeCache()
    -- HS-234 cycle 1 ADOPTED WARNING: this is the chokepoint every wipe path
    -- routes through (OWNERSHIP_UPDATED, VendorMapPins direct calls,
    -- MapSidePanel, OptionsModel, SOURCE_CACHES_INVALIDATED) — re-warming
    -- here covers all of them uniformly instead of one special-cased event
    -- hook. RequestVendorStatsPrewarm's own debounce (below) makes this
    -- safe to call unconditionally at this chokepoint's call frequency.
    if RequestVendorStatsPrewarm then
        RequestVendorStatsPrewarm("invalidate_all_caches")
    end
end

-- Invalidate all cached vendor stats entries for a specific NPC ID.
function BadgeCalculation:InvalidateVendorCache(npcID)
    if npcID then
        vendorStatsCacheGeneration = vendorStatsCacheGeneration + 1
        local prefix = tostring(npcID) .. "|"
        for key in pairs(vendorStatsCache) do
            if type(key) == "string" and key:sub(1, #prefix) == prefix then
                vendorStatsCache[key] = nil
            end
        end
    end
end

-- HS-282: dev-only debug accessor exposing this module's caches to the
-- /hs debug membudget walker. Read-only references, never mutated by the
-- caller. cachedZoneBadges/cachedContinentBadges are reported together as
-- "badge caches" by the caller -- kept as separate table references here
-- so InvalidateBadgeCache's existing wipe-both shape isn't disturbed.
function BadgeCalculation:GetDebugCacheTables()
    return {
        vendorStatsCache = vendorStatsCache,
        dropGroupStatsCache = dropGroupStatsCache,
        cachedZoneBadges = cachedZoneBadges,
        cachedContinentBadges = cachedContinentBadges,
    }
end

-------------------------------------------------------------------------------
-- Badge Count Computation
-------------------------------------------------------------------------------

function BadgeCalculation:GetZoneVendorCounts(continentMapID, sourceFilter)
    sourceFilter = NormalizeSourceFilter(sourceFilter)
    local cacheKey = tostring(continentMapID) .. "|" .. sourceFilter .. "|" .. GetAvailabilityDateStamp()
    if cachedZoneBadges[cacheKey] then return cachedZoneBadges[cacheKey] end

    local zoneCounts = {}
    if not HA.VendorData then return zoneCounts end

    local allVendors = HA.VendorData:GetAllVendors()
    local showOpposite = VF.ShouldShowOppositeFaction()

    for _, vendor in ipairs(allVendors) do
        if ShouldIncludeVendorInBadgeCounts(vendor)
                and not VF.ShouldHideVendor(vendor) then
            -- Get best coordinates (scanned preferred over static)
            local coords, zoneMapID = VF.GetBestVendorCoordinates(vendor)

            -- Badge zone override: count vendor under its accessible map (e.g. Dalaran portal)
            -- rather than its inaccessible instance zone. Decoupled from vendor.portal so this
            -- works independently if the portal pin feature is absent or reverted.
            if vendor.badgeMapID then
                zoneMapID = vendor.badgeMapID
            end

            -- Only count vendors with valid coordinates
            if coords and zoneMapID then
                -- Merge vertically-stacked sibling zones into one summary row.
                zoneMapID = BadgeCalculation.GetCanonicalZoneMapID(zoneMapID)
                local continent = BadgeCalculation.GetContinentForZone(zoneMapID)

                if continent == continentMapID then
                    local canAccess = VF.CanAccessVendor(vendor)
                    local isOpposite = VF.IsOppositeFaction(vendor)

                    -- Include vendor if accessible OR if opposite faction and setting enabled
                    if canAccess or (isOpposite and showOpposite) then
                        if not zoneCounts[zoneMapID] then
                            local mapInfo = C_Map.GetMapInfo(zoneMapID)
                            zoneCounts[zoneMapID] = {
                                zoneName = mapInfo and mapInfo.name or "Unknown",
                                vendorCount = 0,
                                uncollectedCount = 0,
                                unknownCount = 0,
                                oppositeFactionCount = 0,
                                dominantFaction = nil,  -- Will be set to "Alliance", "Horde", or nil (mixed/neutral)
                                collectedItems = 0,
                                totalItems = 0,
                                lockedItems = 0,
                                unverifiedItems = 0,
                                unobtainableItems = 0,
                                excludedItems = 0,
                            }
                        end

                        -- Direct stats lookup is intentional in this hot path.
                        -- Vendor validity is already gated above in this loop.
                        local stats = GetVendorStats(vendor, sourceFilter)

                        -- HS-018: gate vendor-context counters on the vendor actually
                        -- contributing at least one item that passes the filter. Prevents
                        -- "N vendors / 0 items" degenerate badges under non-vendor filters.
                        -- For filter == "all" or "vendor" every accessible vendor contributes
                        -- >= 1 item, so this is a no-op vs. prior behavior.
                        if (stats.total or 0) > 0 then
                            zoneCounts[zoneMapID].vendorCount = zoneCounts[zoneMapID].vendorCount + 1

                            if isOpposite then
                                zoneCounts[zoneMapID].oppositeFactionCount = zoneCounts[zoneMapID].oppositeFactionCount + 1
                                -- Track the opposite faction for this zone
                                if vendor.faction then
                                    zoneCounts[zoneMapID].dominantFaction = vendor.faction
                                end
                            end

                            local hasUncollectedState = stats.hasUncollectedState
                            if hasUncollectedState == true then
                                zoneCounts[zoneMapID].uncollectedCount = zoneCounts[zoneMapID].uncollectedCount + 1
                            elseif hasUncollectedState == "unknown" then
                                zoneCounts[zoneMapID].unknownCount = zoneCounts[zoneMapID].unknownCount + 1
                            end
                            -- false means all collected, don't increment uncollected/unknown.

                            zoneCounts[zoneMapID].collectedItems = zoneCounts[zoneMapID].collectedItems + (stats.collected or 0)
                            zoneCounts[zoneMapID].totalItems = zoneCounts[zoneMapID].totalItems + (stats.total or 0)
                            zoneCounts[zoneMapID].lockedItems = zoneCounts[zoneMapID].lockedItems + (stats.locked or 0)
                            zoneCounts[zoneMapID].unverifiedItems = zoneCounts[zoneMapID].unverifiedItems + (stats.unverified or 0)
                            zoneCounts[zoneMapID].unobtainableItems = zoneCounts[zoneMapID].unobtainableItems + (stats.unobtainable or 0)
                            -- HS-249: tracked alongside the other exclusions,
                            -- deliberately outside collectedItems/totalItems —
                            -- a zone badge that summed these into its fraction
                            -- would re-introduce the defect one level up.
                            zoneCounts[zoneMapID].excludedItems = zoneCounts[zoneMapID].excludedItems + (stats.excluded or 0)
                        end
                    end
                end
            end
        end
    end

    cachedZoneBadges[cacheKey] = zoneCounts
    return zoneCounts
end

function BadgeCalculation:GetContinentVendorCounts(sourceFilter)
    sourceFilter = NormalizeSourceFilter(sourceFilter)
    local cacheKey = sourceFilter .. "|" .. GetAvailabilityDateStamp()
    if cachedContinentBadges[cacheKey] then return cachedContinentBadges[cacheKey] end

    local continentCounts = {}
    if not HA.VendorData then return continentCounts end

    local allVendors = HA.VendorData:GetAllVendors()
    local showOpposite = VF.ShouldShowOppositeFaction()

    for _, vendor in ipairs(allVendors) do
        if ShouldIncludeVendorInBadgeCounts(vendor)
                and not VF.ShouldHideVendor(vendor) then
            -- Get best coordinates (scanned preferred over static)
            local coords, zoneMapID = VF.GetBestVendorCoordinates(vendor)

            -- Only count vendors with valid coordinates
            if coords and zoneMapID then
                local continentMapID = BadgeCalculation.GetContinentForZone(zoneMapID)

                if continentMapID then
                    local canAccess = VF.CanAccessVendor(vendor)
                    local isOpposite = VF.IsOppositeFaction(vendor)

                    -- Include vendor if accessible OR if opposite faction and setting enabled
                    if canAccess or (isOpposite and showOpposite) then
                        if not continentCounts[continentMapID] then
                            local mapInfo = C_Map.GetMapInfo(continentMapID)
                            continentCounts[continentMapID] = {
                                continentName = mapInfo and mapInfo.name or "Unknown",
                                vendorCount = 0,
                                uncollectedCount = 0,
                                unknownCount = 0,
                                oppositeFactionCount = 0,
                                collectedItems = 0,
                                totalItems = 0,
                                lockedItems = 0,
                                unverifiedItems = 0,
                                unobtainableItems = 0,
                                excludedItems = 0,
                            }
                        end

                        -- Direct stats lookup is intentional in this hot path.
                        -- Vendor validity is already gated above in this loop.
                        local stats = GetVendorStats(vendor, sourceFilter)

                        -- HS-018: gate vendor-context counters on filter contribution
                        -- (see GetZoneVendorCounts for rationale; same behavior at
                        -- continent scope).
                        if (stats.total or 0) > 0 then
                            continentCounts[continentMapID].vendorCount = continentCounts[continentMapID].vendorCount + 1

                            if isOpposite then
                                continentCounts[continentMapID].oppositeFactionCount = continentCounts[continentMapID].oppositeFactionCount + 1
                            end

                            local hasUncollectedState = stats.hasUncollectedState
                            if hasUncollectedState == true then
                                continentCounts[continentMapID].uncollectedCount = continentCounts[continentMapID].uncollectedCount + 1
                            elseif hasUncollectedState == "unknown" then
                                continentCounts[continentMapID].unknownCount = continentCounts[continentMapID].unknownCount + 1
                            end
                            -- false means all collected, don't increment uncollected/unknown.

                            continentCounts[continentMapID].collectedItems = continentCounts[continentMapID].collectedItems + (stats.collected or 0)
                            continentCounts[continentMapID].totalItems = continentCounts[continentMapID].totalItems + (stats.total or 0)
                            continentCounts[continentMapID].lockedItems = continentCounts[continentMapID].lockedItems + (stats.locked or 0)
                            continentCounts[continentMapID].unverifiedItems = continentCounts[continentMapID].unverifiedItems + (stats.unverified or 0)
                            continentCounts[continentMapID].unobtainableItems = continentCounts[continentMapID].unobtainableItems + (stats.unobtainable or 0)
                            continentCounts[continentMapID].excludedItems = continentCounts[continentMapID].excludedItems + (stats.excluded or 0)
                        end
                    end
                end
            end
        end
    end

    -- Roll child continent counts into their parent (e.g. Argus → Broken Isles)
    for srcID, destID in pairs(BadgeCalculation.continentMergesInto) do
        local src = continentCounts[srcID]
        if src then
            if not continentCounts[destID] then
                local mapInfo = C_Map.GetMapInfo(destID)
                continentCounts[destID] = {
                    continentName = mapInfo and mapInfo.name or "Unknown",
                    vendorCount = 0, uncollectedCount = 0, unknownCount = 0,
                    oppositeFactionCount = 0, collectedItems = 0, totalItems = 0,
                    lockedItems = 0, unverifiedItems = 0, unobtainableItems = 0,
                    excludedItems = 0,
                }
            end
            local dest = continentCounts[destID]
            dest.vendorCount          = dest.vendorCount          + src.vendorCount
            dest.uncollectedCount     = dest.uncollectedCount     + src.uncollectedCount
            dest.unknownCount         = dest.unknownCount         + src.unknownCount
            dest.oppositeFactionCount = dest.oppositeFactionCount + src.oppositeFactionCount
            dest.collectedItems       = dest.collectedItems       + src.collectedItems
            dest.totalItems           = dest.totalItems           + src.totalItems
            dest.lockedItems          = dest.lockedItems          + src.lockedItems
            dest.unverifiedItems      = dest.unverifiedItems      + src.unverifiedItems
            dest.unobtainableItems    = dest.unobtainableItems    + (src.unobtainableItems or 0)
            dest.excludedItems        = dest.excludedItems        + (src.excludedItems or 0)
            continentCounts[srcID] = nil
        end
    end

    cachedContinentBadges[cacheKey] = continentCounts
    return continentCounts
end

-------------------------------------------------------------------------------
-- Map Center Helpers (delegated to MapPinProvider)
-------------------------------------------------------------------------------

BadgeCalculation.excludedContinents = MPP.excludedContinents
BadgeCalculation.continentMergesInto = MPP.continentMergesInto
BadgeCalculation.continentZoneBadgesOnParent = MPP.continentZoneBadgesOnParent
BadgeCalculation.continentZoneBadgeExclusionsOnParent = MPP.continentZoneBadgeExclusionsOnParent
BadgeCalculation.offWorldContinentPositions = MPP.offWorldContinentPositions
BadgeCalculation.manualZoneCenters = MPP.manualZoneCenters
BadgeCalculation.zoneNotes = MPP.zoneNotes

function BadgeCalculation:GetContinentCenterOnWorldMap(continentMapID)
    return MPP:GetContinentCenterOnWorldMap(continentMapID)
end

function BadgeCalculation:GetZoneCenterOnMap(zoneMapID, parentMapID)
    return MPP:GetZoneCenterOnMap(zoneMapID, parentMapID)
end

-------------------------------------------------------------------------------
-- HS-234: Background Vendor-Stats Pre-Warm
--
-- GetContinentVendorCounts/GetZoneVendorCounts (below) each iterate the FULL
-- vendor DB (~220 vendors) through GetVendorStats. That accessor is cached
-- per (npcID|sourceFilter|dateStamp), but normal zone-level play only ever
-- warms the vendors in the CURRENTLY VIEWED zone — so a player's first
-- World/Continent map visit pays every OTHER vendor's cold GetVendorStats
-- (and its per-item GetItemPresentation calls underneath) synchronously, in
-- one frame. That's the diagnosed >500ms freeze. Cache wipes (UPDATE_FACTION
-- -> SOURCE_CACHES_INVALIDATED -> InvalidateAllCaches) make this recur
-- through a session, not just pay once.
--
-- Fix: proactively rebuild vendorStatsCache in the background, batched so
-- it never lands on one user-facing frame — the same idiom CatalogScanner
-- uses for its own full-catalog scan (ITEMS_PER_BATCH slice + C_Timer.After
-- between batches, Modules/CatalogScanner.lua:ScanFullCatalog). By the time
-- a player actually opens World/Continent, the cache is already warm and
-- GetContinentVendorCounts/GetZoneVendorCounts pay only cache hits. This
-- calls the exact same GetVendorStats accessor every other consumer already
-- uses — zone-level browsing (the hot normal-play path) is untouched, it
-- doesn't go anywhere near this code.
--
-- HS-216 lesson applies here, and matters MORE than it did for CatalogScanner:
-- warming with cold ownership/requirement data wouldn't just waste API calls
-- like a cold scan does, it would CACHE wrong (understated) collected/locked
-- counts that then persist until the next invalidation. But that lesson is
-- about the SCANNER's own live C_HousingCatalog reads going out cold — badge
-- computation itself is cache-only (HS-200/HS-203: GetItemPresentation's
-- badge context sets cacheOnlyOwnership/skipBestSourceProbe, zero live calls).
-- So this gates on HA.CatalogStore:HasPersistedData() (HS-273 R3) instead of
-- HA.CatalogScanner:IsWarm() — HasPersistedData is true as soon as the
-- persistent ownership cache is bound AND non-empty, which is all a
-- cache-only computation needs; IsWarm additionally promises a live scan
-- happened THIS session, which this pass was blocking on for no reason a
-- cold player could ever satisfy (HS-271 regression: never warm behind an
-- unlatchable gate). A fresh install (bound but empty) still fails this
-- gate on purpose — honest "..." beats a confident wrong 0/N.
-------------------------------------------------------------------------------

-- HS-271 item 3c: time-boxed, not count-boxed. A fixed vendor-per-batch
-- count (the old WARMUP_VENDORS_PER_BATCH = 10) spiked to 228.91ms on its
-- own (HS-270 capture E) because some vendors cost far more than others
-- (per-item GetItemPresentation loops of very different sizes) -- a FIXED
-- COUNT has no relationship to how long that count actually takes. Checked
-- via GetTimePreciseSec() (never debugprofilestop -- absent from this repo)
-- inside the batch loop below.
local WARMUP_BATCH_TIME_MS = 4
local WARMUP_BATCH_DELAY = 0.02
-- HS-238: while the player is in combat, batches don't run — they reschedule
-- at this interval until combat drops. Cheap poll (one timer + one C call
-- per second) versus cold requirement evaluation landing on combat frames.
local WARMUP_COMBAT_RETRY_DELAY = 1.0

local warmupInProgress = false
-- HS-234 cycle 1 CRITICAL fix: a wipe arriving mid-pass must not be
-- silently dropped by the reentrancy guard — that left vendors already
-- wiped-but-not-yet-reprocessed permanently missing from vendorStatsCache
-- until the NEXT invalidation, so a future World/Continent open paid
-- roughly half the freeze again, silently. This flag makes the guard
-- COALESCE the dropped request into "run one more full pass when the
-- current one finishes" instead of discarding it. Argus verified writes
-- are never stale (GetVendorStats recomputes live at call time) — this
-- fixes coverage, not staleness; the rerun keeps it that way by always
-- being a full pass, never a partial resume from a stale index.
local warmupPendingRerun = false

-- RequestVendorStatsPrewarm is forward-declared near vendorStatsCache above
-- (BadgeCalculation:InvalidateAllCaches, defined further up the file, calls
-- it) — assigned below, after StartPrewarmPass exists for it to reference.

-- HS-271 item 3a: partitions the vendor list current-zone-first /
-- current-continent-next / everything else last, so the pass warms whatever
-- the player can actually open first. One VF.GetBestVendorCoordinates +
-- GetContinentForZone per vendor -- the same per-vendor cost
-- GetZoneVendorCounts/GetContinentVendorCounts already pay, just run once
-- here to establish order instead of the arbitrary VendorData table order.
-- Called from inside the first ProcessBatch tick only (see below) — never
-- from StartPrewarmPass's own caller frame (orchestrator review flag 2).
local function BuildZoneFirstVendorOrder(allVendors)
    local playerMapID = C_Map.GetBestMapForUnit("player")
    local playerContinent = playerMapID and BadgeCalculation.GetContinentForZone(playerMapID)

    local zoneFirst, continentFirst, rest = {}, {}, {}
    for _, vendor in ipairs(allVendors) do
        local _, zoneMapID = VF.GetBestVendorCoordinates(vendor)
        if playerMapID and zoneMapID == playerMapID then
            zoneFirst[#zoneFirst + 1] = vendor
        elseif playerContinent and zoneMapID
                and BadgeCalculation.GetContinentForZone(zoneMapID) == playerContinent then
            continentFirst[#continentFirst + 1] = vendor
        else
            rest[#rest + 1] = vendor
        end
    end

    local ordered = {}
    for _, list in ipairs({ zoneFirst, continentFirst, rest }) do
        for _, vendor in ipairs(list) do
            ordered[#ordered + 1] = vendor
        end
    end
    return ordered
end

local function StartPrewarmPass()
    if not HA.CatalogStore or not HA.CatalogStore.HasPersistedData or not HA.CatalogStore:HasPersistedData() then
        return
    end

    if not HA.VendorData or not HA.VendorData.GetAllVendors then return end
    local allVendors = HA.VendorData:GetAllVendors()
    local totalVendors = #allVendors
    if totalVendors == 0 then return end

    warmupInProgress = true
    -- The generation this pass' warmed vendors belong to (see the aggregate
    -- gate below). Read once here, never updated mid-pass: a pass that no
    -- longer matches the live generation is a pass whose work has been wiped
    -- out from under it, and it restarts rather than catching up.
    local passGeneration = vendorStatsCacheGeneration
    local currentIndex = 1
    -- Built lazily on the FIRST batch tick below (orchestrator review flag 2).
    local orderedVendors = nil

    -- HS-278: resumable per-vendor item slice state, so a single vendor's
    -- item list can be interrupted mid-vendor by the same time-box that
    -- already interrupts the loop between vendors. All nil when not
    -- currently mid-vendor.
    local itemCursor, itemAccum, itemOrderedIDs = nil, nil, nil
    local itemVendorNpcID, itemVendorKey, itemGeneration = nil, nil, nil

    -- HS-271 item 3b: after the vendor-stats loop below finishes, the SAME
    -- pass (never ahead of it — HS-216/HS-234) warms the badge-aggregate
    -- caches the vendor loop never touches. GetZoneVendorCounts/
    -- GetContinentVendorCounts are what the zoom-sweep capture (HS-270
    -- capture C) found cold at up to 188.64ms.
    local continentList = nil
    local continentIndex = 1
    local continentTotalsWarmed = false

    local function ProcessBatch()
        -- HS-238: never run a warm-up batch during combat — whatever event
        -- triggered this pass (a verified reputation flip, a decor drop
        -- firing OWNERSHIP_UPDATED, a scan), cold requirement evaluation
        -- must not land on combat frames. Reschedule until combat drops;
        -- the player can't consume badge stats mid-fight anyway.
        if _G.InCombatLockdown() then
            C_Timer.After(WARMUP_COMBAT_RETRY_DELAY, ProcessBatch)
            return
        end

        if currentIndex <= totalVendors then
            -- HS-239: batchStartIndex (not a vendor count) is the Measure
            -- workload — under time-boxing, how many vendors this tick will
            -- process isn't knowable before the loop runs (that's the whole
            -- point of time-boxing over count-boxing), but the starting
            -- position already known here costs nothing extra to report.
            -- Measure's callback is pcall itself (not a wrapper closure
            -- around it), so this stays the original `ok = pcall(fn)` shape.
            local batchStartIndex = currentIndex
            -- Perf: how many vendors THIS tick actually finished (finalized
            -- into vendorStatsCache, or marked UNKNOWN_VENDOR_STATS) -- not
            -- how many the loop merely stepped past (already-warm skips) or
            -- accumulated an item into mid-vendor. Gates the fire below so a
            -- tick that made zero new-completion progress (e.g. a mid-vendor
            -- time-box break, or a run of already-warmed skips) doesn't make
            -- PinFrameFactory's listener walk every rendered pin for nothing.
            local completedThisTick = 0
            -- pcall so a mid-batch error degrades to "this pass aborted" — an
            -- unguarded error would kill the timer chain with warmupInProgress
            -- stuck true, silently disabling prewarm for the rest of the
            -- session (every future trigger would coalesce into a rerun that
            -- never comes).
            local ok = HA.PerformanceTrace:Measure("badge_prewarm", batchStartIndex, pcall, function()
                if not orderedVendors then
                    -- HS-271 Gate 1 cycle 1: moved inside this Measure/pcall
                    -- boundary (previously unmeasured and unguarded) so a
                    -- slow or erroring partition shows up in the SAME
                    -- badge_prewarm record class and degrades the pass the
                    -- same way a bad vendor batch does, instead of running
                    -- outside pcall's protection. NOT split across ticks:
                    -- doing so would mean carrying zoneFirst/continentFirst/
                    -- rest accumulators plus their own cursor alongside the
                    -- vendor-loop's currentIndex across ticks — a second
                    -- parallel state machine for a step that runs exactly
                    -- ONCE per pass and costs one VF.GetBestVendorCoordinates
                    -- + GetContinentForZone call per vendor, the same
                    -- per-vendor cost the aggregate builders below already
                    -- pay unmeasured. Kept whole; still inside the boundary
                    -- so it is measured and pcall-protected either way.
                    orderedVendors = BuildZoneFirstVendorOrder(allVendors)
                end

                -- HS-278: "all" — GetVendorStats'/BuildVendorStats' internal
                -- per-item presentation loop runs unconditionally regardless
                -- of sourceFilter (filtering only affects downstream
                -- aggregation, not which items get a presentation lookup) —
                -- warming "all" already populates the expensive per-item
                -- requirement-eval cache for every source-filter value, not
                -- just "all" itself. One pass covers every filter a badge
                -- consumer might later request.
                local budgetStart = _G.GetTimePreciseSec()
                while currentIndex <= totalVendors do
                    local vendor = orderedVendors[currentIndex]
                    local vendorNpcID = vendor and vendor.npcID

                    if itemVendorNpcID ~= vendorNpcID then
                        -- Moved to a different vendor slot than whatever slice state (if
                        -- any) was tracking -- rebuild the cache key once for it instead
                        -- of on every item (BuildVendorFilterCacheKey is a string concat +
                        -- a date-stamp lookup; npcID doesn't change while mid-vendor, so
                        -- paying that cost per-item was wasted work in the first draft).
                        -- This also self-cleans stale slice state left over from a vendor
                        -- a live caller warmed out from under the slicer (see below).
                        itemVendorNpcID = vendorNpcID
                        itemVendorKey = vendorNpcID and BuildVendorFilterCacheKey(vendor, "all")
                        itemCursor, itemAccum, itemOrderedIDs = nil, nil, nil
                    end

                    if not itemVendorKey or vendorStatsCache[itemVendorKey] then
                        -- Invalid vendor, or already warmed (by a live caller, or a prior
                        -- resumed slice) -- nothing to do, advance.
                        currentIndex = currentIndex + 1
                    else
                        if not itemCursor or itemGeneration ~= vendorStatsCacheGeneration then
                            -- (Re)start this vendor's item slice fresh. Also catches
                            -- mid-slice invalidation: a generation mismatch discards
                            -- whatever was accumulated and restarts from item 1, so a
                            -- partial never blends pre/post-invalidation item state.
                            local orderedItemIDs
                            if HA.VendorData and HA.VendorData.GetMergedItemSet then
                                local _, ids = HA.VendorData:GetMergedItemSet(vendor, true)
                                orderedItemIDs = ids
                            end
                            itemOrderedIDs = orderedItemIDs or {}
                            itemAccum = NewVendorStatsAccum()
                            itemCursor = 1
                            itemGeneration = vendorStatsCacheGeneration
                        end

                        if #itemOrderedIDs == 0 then
                            vendorStatsCache[itemVendorKey] = UNKNOWN_VENDOR_STATS
                            currentIndex = currentIndex + 1
                            completedThisTick = completedThisTick + 1
                        else
                            AccumulateVendorItem(itemAccum, itemOrderedIDs[itemCursor], vendor, "all")
                            itemCursor = itemCursor + 1
                            if itemCursor > #itemOrderedIDs then
                                -- Finished every item for this vendor -- finalize, cache, advance.
                                vendorStatsCache[itemVendorKey] = FinalizeVendorStatsAccum(itemAccum)
                                currentIndex = currentIndex + 1
                                completedThisTick = completedThisTick + 1
                            end
                            -- else: still mid-vendor -- currentIndex stays put, itemCursor
                            -- carries forward; the while loop's own re-entry picks up this
                            -- same vendor next iteration and re-checks the generation
                            -- guard above.
                        end
                    end
                    if (_G.GetTimePreciseSec() - budgetStart) * 1000 >= WARMUP_BATCH_TIME_MS then
                        break
                    end
                end
            end)
            if not ok then
                warmupInProgress = false
                warmupPendingRerun = false
                return
            end
            -- HS-271 item 2: batch-level fire (not per-vendor, not once per
            -- whole pass) — PinFrameFactory's listener walks currently
            -- rendered vendor pins and re-runs RefreshVendorPinCount on
            -- whichever are still flagged hsStatsPending.
            --
            -- Perf: mid-loop ticks only fire when they actually finished at
            -- least one vendor -- a tick that made zero new-completion
            -- progress has nothing new for the listener to find.
            --
            -- Argus cycle 1 CRITICAL: the tick that ENDS the vendor loop
            -- (currentIndex crosses past the last vendor) must fire
            -- unconditionally, even if it completed nothing itself. A pass
            -- can end on pure skips -- e.g. the pending pin's own self-heal
            -- requests this exact pass, and inside the debounce window a
            -- live caller (a side-panel query, any GetVendorStats call)
            -- warms that same vendor first; every vendor this pass then
            -- touches is already cached, so completedThisTick stays 0 for
            -- the whole loop. HS_VENDOR_STATS_WARMED is the pending pin's
            -- only non-render wake-up, so a pass that never fires leaves its
            -- own "..." placeholder stuck forever. By loop end every
            -- vendor a live caller warmed mid-pass is warm in the cache, so
            -- the end-of-loop fire still heals every such pin -- this costs
            -- exactly one extra fire per pass, not one per tick.
            local vendorLoopEnded = currentIndex > totalVendors
            if HA.Events and (completedThisTick > 0 or vendorLoopEnded) then
                HA.Events:Fire("HS_VENDOR_STATS_WARMED")
            end
            C_Timer.After(WARMUP_BATCH_DELAY, ProcessBatch)
            return
        end

        -- Vendor-stats loop is done. Orchestrator review flag 1: each
        -- aggregate call below is an ATOMIC batch unit — the time-box is
        -- BETWEEN calls (one call per tick), never inside one.

        -- ...which is exactly why they must not run against a cache that was
        -- wiped mid-pass. The vendor loop above never revisits vendors behind
        -- its cursor, so after a wipe every vendor it already warmed is cold
        -- again — and an aggregate re-walks ALL of them inside one atomic,
        -- un-timeboxed call, recomputing that whole cold prefix in a single
        -- frame. Skip the remaining aggregate ticks instead and let the rerun
        -- below redo the pass from a consistent cache. Re-evaluated on every
        -- post-loop tick (ProcessBatch re-enters here per tick), so this
        -- guards EACH aggregate tick, not just the first.
        local staleMidPass = warmupPendingRerun or vendorStatsCacheGeneration ~= passGeneration

        if not staleMidPass then
            if not continentList then
                continentList = {}
                for continentMapID in pairs(Constants.ContinentNames) do
                    if not MPP.excludedContinents[continentMapID] then
                        continentList[#continentList + 1] = continentMapID
                    end
                end
            end

            if not continentTotalsWarmed then
                continentTotalsWarmed = true
                local ok = HA.PerformanceTrace:Measure("badge_prewarm", "continent_totals", pcall, function()
                    BadgeCalculation:GetContinentVendorCounts("all")
                end)
                if not ok then
                    warmupInProgress = false
                    warmupPendingRerun = false
                    return
                end
                C_Timer.After(WARMUP_BATCH_DELAY, ProcessBatch)
                return
            end

            if continentIndex <= #continentList then
                local continentMapID = continentList[continentIndex]
                continentIndex = continentIndex + 1
                local ok = HA.PerformanceTrace:Measure("badge_prewarm", continentMapID, pcall, function()
                    BadgeCalculation:GetZoneVendorCounts(continentMapID, "all")
                end)
                if not ok then
                    warmupInProgress = false
                    warmupPendingRerun = false
                    return
                end
                if continentIndex <= #continentList then
                    C_Timer.After(WARMUP_BATCH_DELAY, ProcessBatch)
                    return
                end
            end
        end

        warmupInProgress = false
        -- staleMidPass reruns even when warmupPendingRerun is still false:
        -- the generation moves the instant a wipe lands, but the flag is only
        -- set a debounce interval later (and InvalidateVendorCache bumps the
        -- generation without requesting a prewarm at all). Without this the
        -- skipped aggregates would simply never be warmed by this pass.
        if staleMidPass or warmupPendingRerun then
            -- A wipe landed while this pass was running — rerun a FULL
            -- fresh pass (not a resume) so nothing processed before
            -- that wipe is left stale-cached, and nothing after it is
            -- left missing. Full pass includes re-partitioning vendors and
            -- re-warming aggregates, same as the first run.
            warmupPendingRerun = false
            StartPrewarmPass()
        else
            -- HS-282: a clean, nothing-pending pass end is the one reliable
            -- point where every vendor's source/vendor-item lookups have run
            -- -- flush the two eviction-capped memos here so a session that
            -- never organically hits the 512/64 caps still gets relief.
            if HA.SourceManager and HA.SourceManager.InvalidateSourcesMemo then
                HA.SourceManager:InvalidateSourcesMemo()
            end
            if HA.VendorData and HA.VendorData.InvalidateVendorItemsMemo then
                HA.VendorData:InvalidateVendorItemsMemo()
            end
        end
    end

    -- HS-234 cycle 1 CRITICAL fix: batch 1 must not run synchronously in
    -- the caller's frame either (it was — ~45ms of cold requirement evals
    -- injected directly into the SOURCE_CACHES_INVALIDATED dispatch frame
    -- and the login ticker's tick). Defer it exactly like batches 2+ so
    -- NO batch ever runs inline with a trigger.
    C_Timer.After(WARMUP_BATCH_DELAY, ProcessBatch)
end

local function TryStartPrewarmPass()
    if warmupInProgress then
        -- Reentrancy: coalesce into a rerun rather than dropping the
        -- request — see warmupPendingRerun above.
        warmupPendingRerun = true
        return
    end
    StartPrewarmPass()
end

-- HS-234 cycle 1 CRITICAL fix: trigger-level cancel-and-restart debounce,
-- same discipline as HomesteadWorldMapProvider's RequestSettledRefresh —
-- a burst of calls (rapid rep ticks each invalidating, multiple wipe paths
-- firing close together) now schedules exactly ONE prewarm attempt after
-- the burst settles, instead of one attempt per call.
local WARMUP_TRIGGER_DEBOUNCE = 1.0
local warmupTriggerTimer = nil

RequestVendorStatsPrewarm = function(_reason)
    if warmupTriggerTimer then
        warmupTriggerTimer:Cancel()
    end
    warmupTriggerTimer = C_Timer.NewTimer(WARMUP_TRIGGER_DEBOUNCE, function()
        warmupTriggerTimer = nil
        TryStartPrewarmPass()
    end)
end

-- HS-271 Gate 1 cycle 1: public self-heal entry point for the deferred-fill
-- path (PinFrameFactory:RefreshVendorPinCount, on a double cache miss) —
-- thin wrapper over the same debounced trigger every other caller already
-- uses, nothing else. Safe to call from a render-path double miss because
-- RequestVendorStatsPrewarm's own 1s debounce (above) absorbs repeats.
function BadgeCalculation:RequestPrewarm(reason)
    RequestVendorStatsPrewarm(reason)
end

-- Login trigger: poll HA.CatalogStore:HasPersistedData() (HS-273 R3 — a
-- cheap boolean read, not a new event registration) once a second until it
-- flips true, request the pre-warm pass (through the same debounced entry
-- point as every other trigger), then cancel — self-terminating, no leaked
-- ticker. Bounded at 60 polls (~60s) so a session where the persistent cache
-- genuinely never has anything in it doesn't poll forever.
local loginWarmupTicker = nil
local loginWarmupPolls = 0
local LOGIN_WARMUP_MAX_POLLS = 60

loginWarmupTicker = C_Timer.NewTicker(1, function()
    loginWarmupPolls = loginWarmupPolls + 1
    if HA.CatalogStore and HA.CatalogStore.HasPersistedData and HA.CatalogStore:HasPersistedData() then
        loginWarmupTicker:Cancel()
        RequestVendorStatsPrewarm("login")
    elseif loginWarmupPolls >= LOGIN_WARMUP_MAX_POLLS then
        loginWarmupTicker:Cancel()
    end
end)

-------------------------------------------------------------------------------
-- Event-Driven Cache Invalidation
-------------------------------------------------------------------------------

if HA.Events then
    HA.Events:RegisterCallback("SOURCE_CACHES_INVALIDATED", function()
        BadgeCalculation:InvalidateAllCaches()
    end)

    -- HS-273 R7: listens for CatalogScanner's two true-warm one-shots
    -- (Gate 0 finding 2 — no existing chain reliably re-fires on that exact
    -- edge). This FILLS the gap on the cold->warm transition specifically;
    -- it does not replace SOURCE_CACHES_INVALIDATED above as the source of
    -- ongoing freshness — later ownership changes still flow through that
    -- chain's own OWNERSHIP_UPDATED-driven invalidation, same as before
    -- HS-273. Runs the same debounced trigger every other caller uses.
    HA.Events:RegisterCallback("HS_CATALOG_TRUE_WARM", function()
        RequestVendorStatsPrewarm("true_warm_latch")
    end)
end
