-- luacheck: globals assert loadfile print io

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- SourceManager badge/sidePanel cache-only ownership contract (HS-200)
--
-- Badge recounts (UI/BadgeCalculation.lua BuildVendorStats) and the map side
-- panel's item grid/search results (UI/MapSidePanel.lua PopulateItemGrid /
-- PopulateItemResultRow) both call GetItemPresentation once per item, per
-- vendor, in a single synchronous pass. IsOwnedFresh erroring below means any
-- code path that still reaches it — including the internal duplicate-
-- ownership guard inside GetVendorItemAvailabilityState, which used to fire
-- a SECOND fresh probe even after the top-level isOwned check went
-- cache-only — trips this test.
-------------------------------------------------------------------------------

local freshProbeCalls = 0

local BadgeHA = {
    Constants = { Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
    Addon = { db = { profile = {}, global = { parsedSources = {} } }, RegisterModule = function() end },
    CatalogStore = {
        IsOwned = function(_, itemID)
            return itemID == 2001
        end,
        IsOwnedFresh = function()
            freshProbeCalls = freshProbeCalls + 1
            error("badge/sidePanel rendering must not make a fresh ownership probe")
        end,
        GetRequirements = function() return nil end,
    },
}

assert(loadfile(root .. "/Data/SourceManager.lua"))("Homestead", BadgeHA)

-- Owned item, badge context: short-circuits on isOwned before
-- GetVendorItemAvailabilityState even runs.
local ownedBadge = BadgeHA.SourceManager:GetItemPresentation(2001, { context = "badge", npcID = 999 })
assert(ownedBadge.isOwned == true)
assert(ownedBadge.availabilityState == "owned")

-- Unowned item, badge context, WITH a vendor npcID: this is exactly the path
-- that used to reach GetVendorItemAvailabilityState's own IsOwnedFresh call
-- even though isOwned was already resolved (cache-only) moments earlier.
local unownedBadge = BadgeHA.SourceManager:GetItemPresentation(2002, { context = "badge", npcID = 999 })
assert(unownedBadge.isOwned == false)

-- Same shape for the map side panel's "sidePanel" context (item grid + search
-- results both funnel through here).
local unownedSidePanel = BadgeHA.SourceManager:GetItemPresentation(2002, { context = "sidePanel", npcID = 999 })
assert(unownedSidePanel.isOwned == false)

assert(freshProbeCalls == 0)

-------------------------------------------------------------------------------
-- No-presentation fallbacks stay cache-only (HS-200 CRITICAL required change)
-------------------------------------------------------------------------------

local badgeSource = assert(io.open(root .. "/UI/BadgeCalculation.lua", "r")):read("*a")
assert(badgeSource:find(
    'if not presentation and HA%.CatalogStore and HA%.CatalogStore%.IsOwned then', 1) ~= nil)
assert(badgeSource:find(
    'isOwned = HA%.CatalogStore:IsOwned%(itemID%) == true', 1) ~= nil)
-- Must NOT still call the fresh probe in this fallback.
assert(badgeSource:find('HA%.CatalogStore:IsOwnedFresh%(itemID%) == true', 1) == nil)

local mapSidePanelSource = assert(io.open(root .. "/UI/MapSidePanel.lua", "r")):read("*a")
assert(mapSidePanelSource:find(
    'local function IsItemOwned%(itemID%)%s+if not itemID then return false end%s+if HA%.CatalogStore then%s+return HA%.CatalogStore:IsOwned%(itemID%)', 1) ~= nil)

print("hs200_map_badge_probes: ok")
