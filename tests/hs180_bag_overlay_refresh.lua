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
assert(overlaySource:find('Events:RegisterCallback%("bags", function%(%)%s+Overlay:RefreshAll%(false%)', 1) ~= nil)
assert(overlaySource:find('function Overlay:RefreshExternalOverlays%(', 1) ~= nil)

-- HS-180 Gate 1 cycle 1 (WARNING): the bags path above skips the external-
-- refresher pass, so something else must repaint external bag UIs
-- (Baganator/BetterBags) when ownership catches up mid-session, or a
-- consumed item's remaining copy lingers as "in bags, unlearned".
-- Cycle 2 (CRITICAL): the repaint must be DEFERRED (RequestUpdate), never a
-- direct RefreshAll — Events:Fire is synchronous and a refresh can itself
-- fire OWNERSHIP_UPDATED (merchant SetOwned), so a direct call recurses.
assert(overlaySource:find(
    'Events:RegisterCallback%("OWNERSHIP_UPDATED", function%(%)%s+Events:RequestUpdate%("all"%)', 1) ~= nil)
assert(overlaySource:find(
    'Events:RegisterCallback%("OWNERSHIP_UPDATED", function%(%)%s+Overlay:RefreshAll%(', 1) == nil)

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
