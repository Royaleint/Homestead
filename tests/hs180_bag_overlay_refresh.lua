-- luacheck: globals assert loadfile print io tonumber C_Item C_HousingCatalog wipe

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-- WoW-provided global (table.wipe equivalent); stub it for the plain lua5.1
-- test harness the same way C_Item/C_HousingCatalog are stubbed below.
wipe = function(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end

local freshOwnershipReads = 0
local cachedOwnershipReads = 0

local HA = {
    Constants = { Icons = {}, SourceBadgeAtlas = {}, Colors = {
        COLLECTED = { r = 0, g = 1, b = 0 },
        COLLECTED_PLACED = { r = 0, g = 0.8, b = 0 },
        NOT_COLLECTED = { r = 1, g = 0, b = 0 },
    } },
    Addon = { db = { profile = {}, global = { parsedSources = {} } }, RegisterModule = function() end },
    CatalogStore = {
        IsOwned = function(_, itemID)
            cachedOwnershipReads = cachedOwnershipReads + 1
            return itemID == 1001
        end,
        IsOwnedFresh = function()
            freshOwnershipReads = freshOwnershipReads + 1
            error("inventory rendering must not make a fresh ownership probe")
        end,
        GetRequirements = function() return nil end,
    },
}

assert(loadfile(root .. "/Data/SourceManager.lua"))("Homestead", HA)

assert(HA.SourceManager:GetInventoryItemStatus(1001) == "owned")
assert(HA.SourceManager:GetInventoryItemStatus(1002) == "in_bags_unlearned")
assert(cachedOwnershipReads == 2)
assert(freshOwnershipReads == 0)

local overlaySource = assert(io.open(root .. "/Overlay/overlay.lua", "r")):read("*a")

-- HS-209 decision (supersedes the HS-180 cycle-1 assertion this replaces):
-- per-surface refreshes belong to the surface modules that already own them
-- (Overlay/Containers.lua owns "bags", Overlay/Merchant.lua owns
-- "merchant") — those were the wiring that actually ran in production the
-- whole time Overlay:Initialize() was dead (HS-209 H1). Registering "bags"/
-- "merchant" here too, now that Initialize() actually runs, would walk the
-- SAME activeOverlays pool those surface modules already walk via their own
-- overlay updateFuncs — traced and confirmed as real duplicate per-slot work
-- during the H1 rollout. Overlay:Initialize() must register ONLY genuinely
-- cross-surface triggers.
assert(overlaySource:find('Events:RegisterCallback%("bags"', 1) == nil,
    'Overlay/overlay.lua must not register its own "bags" callback — Containers.lua owns that surface')
assert(overlaySource:find('Events:RegisterCallback%("merchant"', 1) == nil,
    'Overlay/overlay.lua must not register its own "merchant" callback — Merchant.lua owns that surface')

assert(overlaySource:find('function Overlay:RefreshExternalOverlays%(', 1) ~= nil)

-- HS-180 Gate 1 cycle 1 (WARNING): the bags path above skips the external-
-- refresher pass, so something else must repaint external bag UIs
-- (Baganator/BetterBags) when ownership catches up mid-session, or a
-- consumed item's remaining copy lingers as "in bags, unlearned".
-- Cycle 2 (CRITICAL): the repaint must be DEFERRED (RequestUpdate), never a
-- direct RefreshAll — Events:Fire is synchronous and a refresh can itself
-- fire OWNERSHIP_UPDATED (merchant SetOwned), so a direct call recurses.
-- HS-239: the handler wraps its RequestUpdate("all") call through the
-- PerformanceTrace facade (Measure), so the literal adjacency check below
-- spans that wrapper with a lazy `.-` instead of requiring the two calls
-- back-to-back — the underlying contract (defer via RequestUpdate, never a
-- direct RefreshAll) is unchanged.
-- Perf cleanup: Measure is now called with a named function reference
-- (Events.RequestUpdate, Events, "all") instead of a wrapping closure that
-- calls Events:RequestUpdate("all") -- same contract, mechanical call-shape
-- change per Measure's varargs facade.
assert(overlaySource:find(
    'Events:RegisterCallback%("OWNERSHIP_UPDATED", function%(%).-Events%.RequestUpdate, Events, "all"', 1) ~= nil)
assert(overlaySource:find(
    'Events:RegisterCallback%("OWNERSHIP_UPDATED", function%(%).-Overlay:RefreshAll%(', 1) == nil)

-------------------------------------------------------------------------------
-- CatalogStore:IsDecorItem cache-first contract (HS-180 Gate 1 cycle 1 CRITICAL fix)
-------------------------------------------------------------------------------

local catalogProbeCalls = 0

-- Mocks: a non-decor item (99999) with no ci record and no static
-- DecorMapping entry. A warm, live probe correctly reports it has no catalog
-- entry (info == nil). The contract under test: repeated IsDecorItem calls
-- for this same non-decor item must hit the live API at most once per warm
-- session — everything after the first miss comes from the session-only
-- negative cache.
C_Item = {
    GetItemInfoInstant = function(itemLink)
        return tonumber(itemLink:match("(%d+)"))
    end,
}

C_HousingCatalog = {
    GetCatalogEntryInfoByItem = function()
        catalogProbeCalls = catalogProbeCalls + 1
        return nil
    end,
}

local CatalogHA = {
    Addon = {
        db = { global = { catalogItems = {}, schemaVersion = 4 } },
        RegisterModule = function() end,
        Debug = function() end,
    },
    -- Warm session: a nil probe result is authoritative and may be
    -- session-negative-cached (see the HS-060 cold/nil hazard in CatalogStore).
    CatalogScanner = {
        IsWarm = function() return true end,
    },
}

assert(loadfile(root .. "/Data/CatalogStore.lua"))("Homestead", CatalogHA)
CatalogHA.CatalogStore:Initialize()

assert(CatalogHA.CatalogStore:IsDecorItem("item:99999") == false)
assert(CatalogHA.CatalogStore:IsDecorItem("item:99999") == false)
assert(CatalogHA.CatalogStore:IsDecorItem("item:99999") == false)
assert(catalogProbeCalls == 1)

-- Cycle 2 (WARNING fix): a decor item found only by live probe (not in ci or
-- the static index — e.g. a new-patch item before DecorMapping regenerates)
-- must be positively memoized for the session: repeat calls hit the API once.
C_HousingCatalog.GetCatalogEntryInfoByItem = function()
    catalogProbeCalls = catalogProbeCalls + 1
    return {}
end
assert(CatalogHA.CatalogStore:IsDecorItem("item:88888") == true)
assert(CatalogHA.CatalogStore:IsDecorItem("item:88888") == true)
assert(CatalogHA.CatalogStore:IsDecorItem("item:88888") == true)
assert(catalogProbeCalls == 2)

print("hs180_bag_overlay_refresh: ok")
