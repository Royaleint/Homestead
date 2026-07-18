-- luacheck: globals assert loadfile print

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-204(b): BuildOfferIndexes correctness after removing the per-npcID
-- GetOffers() merge + per-item tombstone string build. The old version ran
-- the full ManualOverrides > GeneratedBase > StagedAdditions precedence
-- merge (via GetOffers) just to throw away everything but itemID keys, and
-- built a "npcID:itemID" string per item to check a Tombstones table that,
-- in production, currently holds exactly 2 entries (HS-176, HS-182). This
-- pins that the new direct-from-raw-tables build produces the SAME itemID
-- membership per npcID, INCLUDING both tombstone forms (bare itemID and
-- "npcID:itemID" pair-specific) still being honored — losing that would
-- silently resurrect the exact wrong vendor/item pairings HS-176 and HS-182
-- fixed.
-------------------------------------------------------------------------------

local HA = {
    VendorOffers = {
        GeneratedBase = {
            [100] = { [1] = { price = 1 }, [2] = { price = 2 }, [3] = { price = 3 } },
            [200] = { [3] = { price = 3 } }, -- item 3 also sold by npc 200
        },
        ManualOverrides = {
            [100] = { [4] = { price = 4 } }, -- additional item, same npc
        },
        StagedAdditions = {
            [300] = { [5] = { price = 5 } },
        },
        -- Bare-itemID tombstone: item 2 suppressed everywhere.
        -- Pair-specific tombstone: item 3 suppressed only for npc 100 (npc
        -- 200 still legitimately sells it).
        Tombstones = {
            [2] = true,
            ["100:3"] = true,
        },
    },
    Addon = { RegisterModule = function() end },
}

assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)
HA.VendorData:BuildOfferIndexes()

local index = HA.VendorData.OfferByItemID

-- Item 1: npc 100 only, not tombstoned.
assert(index[1] ~= nil and #index[1] == 1 and index[1][1] == 100)

-- Item 2: bare-itemID tombstone — must not appear for ANY npc.
assert(index[2] == nil)

-- Item 3: pair-tombstoned for npc 100 (excluded) but still legitimately sold
-- by npc 200 (must remain).
assert(index[3] ~= nil and #index[3] == 1 and index[3][1] == 200)

-- Item 4: ManualOverrides-only entry for npc 100, not tombstoned.
assert(index[4] ~= nil and #index[4] == 1 and index[4][1] == 100)

-- Item 5: StagedAdditions-only entry for npc 300, not tombstoned.
assert(index[5] ~= nil and #index[5] == 1 and index[5][1] == 300)

print("hs204b_vendor_offer_index: ok")
