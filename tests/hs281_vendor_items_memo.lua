-- luacheck: globals assert loadfile print CreateFrame
--
-- HS-281: VendorData:GetVendorItems(npcID) was completely uncached -- every
-- item queried off a vendor rebuilt that vendor's whole item list from
-- scratch, twice (GetVendor's projection AND GetItemsForVendor's independent
-- cost lookup both call it). Confirmed by a controlled experiment against
-- the real files: 50 items on one vendor produced 100 rebuilds, not 50 or 1.
-- This pins the fix (a plain per-npcID memo, no invalidation -- GetOffers'
-- four input tables are static after load) and proves it with a real
-- rebuild-count assertion, not a vacuous one.

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-- VendorData has no Initialize()-time dependencies this test exercises; a
-- minimal HA is enough for it to load standalone.
local function freshHA()
    return {
        Addon = { RegisterModule = function() end },
    }
end

-------------------------------------------------------------------------------
-- Fixture: one 50-item vendor (mirrors the controlled experiment's synthetic
-- "big vendor" case) plus one no-offers vendor and a second small vendor to
-- prove distinct npcIDs don't cross-contaminate.
-------------------------------------------------------------------------------

local NPC_BIG = 999001
local NPC_SMALL = 999002
local NPC_NONE = 999003
local ITEM_COUNT = 50
local BASE_ITEM_ID = 900000

local function buildOffers()
    local generatedBase = {}
    generatedBase[NPC_BIG] = {}
    for i = 1, ITEM_COUNT do
        generatedBase[NPC_BIG][BASE_ITEM_ID + i] = { price = 100 * i }
    end
    generatedBase[NPC_SMALL] = {
        [800001] = { price = 50 },
    }
    return {
        GeneratedBase = generatedBase,
        ManualOverrides = {},
        StagedAdditions = nil,
        Tombstones = {},
    }
end

-------------------------------------------------------------------------------
-- 1. Rebuild-count assertion (the actual fix). GetOffers has exactly one call
-- site in the whole codebase -- inside GetVendorItems itself -- so wrapping
-- it isolates "did the uncached rebuild actually run" from "how many times
-- did a caller ask." Query all 50 items via BOTH of the controlled
-- experiment's two redundant paths (GetVendorItems directly, and
-- GetItemsForVendor -- the two call sites GetVendor's projection and
-- BuildVendorSourceData's cost lookup route through in production).
-------------------------------------------------------------------------------

do
    local HA = freshHA()
    HA.VendorOffers = buildOffers()
    assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)

    local getOffersCalls = 0
    local realGetOffers = HA.VendorData.GetOffers
    HA.VendorData.GetOffers = function(self, npcID)
        getOffersCalls = getOffersCalls + 1
        return realGetOffers(self, npcID)
    end

    -- Production's second call site (BuildVendorSourceData, SourceManager.lua)
    -- passes a vendor OBJECT into GetItemsForVendor, not a bare npcID -- use
    -- the same shape here so this test exercises the real vendor-table
    -- branch (GetItemsForVendor's npcID-number branch is a distinct, less
    -- representative code path).
    local vendorObj = { npcID = NPC_BIG }

    for i = 1, ITEM_COUNT do
        local itemID = BASE_ITEM_ID + i
        local viaGetVendorItems = HA.VendorData:GetVendorItems(NPC_BIG)
        local viaGetItemsForVendor = HA.VendorData:GetItemsForVendor(vendorObj)
        assert(#viaGetVendorItems == ITEM_COUNT, "sanity: full item list expected on every query")
        assert(#viaGetItemsForVendor == ITEM_COUNT, "sanity: full item list expected via GetItemsForVendor too")
        local _ = itemID -- queried per-item in production; the memo is per-npcID, not per-item
    end

    assert(getOffersCalls == 1,
        "GetOffers must be called exactly once for NPC " .. NPC_BIG ..
        " no matter how many items/call-paths query it -- got " .. getOffersCalls ..
        " (pre-fix this would be 100: 2 call sites x 50 items)")

    print("hs281_vendor_items_memo: rebuild-count assertion ok (GetOffers called " .. getOffersCalls .. " time)")
end

-------------------------------------------------------------------------------
-- 2. Identity + parity: same npcID returns the SAME table object, with the
-- correct sorted/cost-built contents.
-------------------------------------------------------------------------------

do
    local HA = freshHA()
    HA.VendorOffers = buildOffers()
    assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)

    local first = HA.VendorData:GetVendorItems(NPC_SMALL)
    local second = HA.VendorData:GetVendorItems(NPC_SMALL)
    assert(first == second, "GetVendorItems must return the SAME cached table on a hit")
    assert(#first == 1, "expected exactly one item for the small vendor")
    -- OfferToLegacyItem returns { itemID, cost = cost } when a cost exists
    -- (this offer has price = 50), bare itemID otherwise.
    local row = first[1]
    local rowItemID = type(row) == "table" and row[1] or row
    assert(rowItemID == 800001, "expected item 800001 present in the small vendor's item list")
    assert(type(row) == "table" and row.cost and row.cost.gold == 50,
        "expected the small vendor's item to carry its price via OfferToLegacyItem")

    print("hs281_vendor_items_memo: identity + parity ok")
end

-------------------------------------------------------------------------------
-- 3. Distinct npcIDs stay distinct: two different vendors produce two
-- different table objects with non-cross-contaminated contents.
-------------------------------------------------------------------------------

do
    local HA = freshHA()
    HA.VendorOffers = buildOffers()
    assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)

    local bigItems = HA.VendorData:GetVendorItems(NPC_BIG)
    local smallItems = HA.VendorData:GetVendorItems(NPC_SMALL)
    assert(bigItems ~= smallItems, "different npcIDs must not share a memo entry")
    assert(#bigItems == ITEM_COUNT, "big vendor's memo entry must be unaffected by querying the small vendor")
    assert(#smallItems == 1, "small vendor's memo entry must be unaffected by querying the big vendor")

    print("hs281_vendor_items_memo: distinct npcIDs stay distinct ok")
end

-------------------------------------------------------------------------------
-- 4. No-offers case: an npcID with no GeneratedBase/ManualOverrides/
-- StagedAdditions entry returns {} both times, same object on the second
-- call, and GetOffers is still exercised only once for it.
-------------------------------------------------------------------------------

do
    local HA = freshHA()
    HA.VendorOffers = buildOffers()
    assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)

    local getOffersCalls = 0
    local realGetOffers = HA.VendorData.GetOffers
    HA.VendorData.GetOffers = function(self, npcID)
        getOffersCalls = getOffersCalls + 1
        return realGetOffers(self, npcID)
    end

    local first = HA.VendorData:GetVendorItems(NPC_NONE)
    local second = HA.VendorData:GetVendorItems(NPC_NONE)
    assert(#first == 0, "no-offers vendor must return an empty item list")
    assert(first == second, "the empty result must still be memoized (same object, not a fresh {} each call)")
    assert(getOffersCalls == 1, "GetOffers must be called exactly once even for the no-offers case")

    print("hs281_vendor_items_memo: no-offers case ok")
end

print("hs281_vendor_items_memo: done")
