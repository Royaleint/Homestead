-- luacheck: globals assert loadfile print io C_QuestLog GetAchievementInfo
--
-- HS-280: SourceManager:GetRequirements' Priority 1 and the local
-- GetScannedVendorItem both did an uncached linear scan over the same
-- scannedVendor.items array -- O(n^2) per vendor render. This pins the fix
-- (a reverse index built once per BuildScannedIndex pass, keyed npcID ->
-- itemID -> {item, ...}) and proves both call sites were migrated to it, not
-- just one.

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

local function readFile(path)
    local f = assert(io.open(path, "r"))
    local content = f:read("*a")
    f:close()
    return content
end

-- VendorData has no Initialize()-time dependencies this test exercises; a
-- minimal HA is enough for it to load standalone.
local function freshHA()
    return {
        Addon = { RegisterModule = function() end, Debug = function() end },
    }
end

-------------------------------------------------------------------------------
-- 1. Index-shape: 2 npcIDs, one itemID repeated twice on one npcID (two
-- merchant slots, distinct requirements each) and also present once on the
-- other npcID.
-------------------------------------------------------------------------------

do
    local NPC_A = 990001
    local NPC_B = 990002
    local ITEM_DUP = 700001

    local HA = freshHA()
    HA.Addon.db = {
        global = {
            scannedVendors = {
                [NPC_A] = {
                    items = {
                        { itemID = ITEM_DUP, requirements = { { type = "reputation", faction = "A" } } },
                        { itemID = ITEM_DUP, requirements = { { type = "quest", id = 1 } } },
                    },
                },
                [NPC_B] = {
                    items = {
                        { itemID = ITEM_DUP, requirements = {} },
                    },
                },
            },
        },
    }

    assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)
    HA.VendorData:BuildScannedIndex()

    local slots = HA.VendorData.ScannedItemsByNPC[NPC_A][ITEM_DUP]
    assert(#slots == 2, "expected both merchant slots for the duplicated itemID, got " .. #slots)
    assert(slots[1].requirements[1].type == "reputation", "original scan-array order must be preserved (slot 1)")
    assert(slots[2].requirements[1].type == "quest", "original scan-array order must be preserved (slot 2)")

    local npcList = HA.VendorData.ScannedByItemID[ITEM_DUP]
    local sawA, sawB = false, false
    for _, npcID in ipairs(npcList) do
        if npcID == NPC_A then sawA = true end
        if npcID == NPC_B then sawB = true end
    end
    assert(sawA and sawB, "ScannedByItemID must still list both npcIDs (regression guard on the pre-existing index)")

    print("hs280_vendor_requirements_index: index-shape ok")
end

-------------------------------------------------------------------------------
-- 2. Revert-sensitive call-count pin: a 50-item vendor, all distinct
-- itemIDs, no duplicate slots. One GetRequirements call must bring the
-- GetScannedVendorItems counter to exactly 1 (a reverted/old-style linear
-- scan never calls this accessor). One GetVendorItemAvailabilityState call
-- on a different, requirement-free item must bring the counter to exactly
-- +2 (Priority 1's call site, plus the local GetScannedVendorItem's call
-- site) -- if only one call site were migrated, the count would be off by
-- exactly one.
-------------------------------------------------------------------------------

do
    local NPC_BIG = 990101
    local ITEM_COUNT = 50
    local BASE_ITEM_ID = 910000

    local HA = freshHA()
    HA.Constants = { Icons = {}, SourceBadgeAtlas = {}, Colors = {} }

    local items = {}
    for i = 1, ITEM_COUNT do
        items[i] = { itemID = BASE_ITEM_ID + i, requirements = {}, isPurchasable = true }
    end
    HA.Addon.db = {
        global = {
            scannedVendors = {
                [NPC_BIG] = { items = items },
            },
        },
    }

    assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)
    HA.VendorData:BuildScannedIndex()
    assert(loadfile(root .. "/Data/SourceManager.lua"))("Homestead", HA)

    local calls = 0
    local realGetScannedVendorItems = HA.VendorData.GetScannedVendorItems
    HA.VendorData.GetScannedVendorItems = function(self, npcID, itemID)
        calls = calls + 1
        return realGetScannedVendorItems(self, npcID, itemID)
    end

    local itemA = BASE_ITEM_ID + 1
    HA.SourceManager:GetRequirements(itemA, NPC_BIG)
    assert(calls == 1,
        "GetRequirements must call GetScannedVendorItems exactly once -- got " .. calls ..
        " (a reverted linear scan never calls this accessor at all)")

    local itemB = BASE_ITEM_ID + 2
    HA.SourceManager:GetVendorItemAvailabilityState(itemB, NPC_BIG)
    assert(calls == 3,
        "GetVendorItemAvailabilityState must add exactly 2 more calls (Priority 1 via its internal " ..
        "GetRequirements, plus the local GetScannedVendorItem) -- got " .. (calls - 1) .. " more, total " .. calls)

    print("hs280_vendor_requirements_index: revert-sensitive call-count pin ok (" .. calls .. " calls)")
end

-------------------------------------------------------------------------------
-- 3. Merge-all + first-match-order semantics: same itemID twice on one
-- vendor, item #1 (isPurchasable=true) carries a quest requirement, item #2
-- (isPurchasable=false) carries an achievement requirement. GetRequirements
-- must return BOTH (merge-all, not first-match-collapsed). GetVendorItem-
-- AvailabilityState must NOT report "locked" purely from the isPurchasable
-- gate -- that would mean the gate picked item #2 instead of the first
-- array-order slot.
-------------------------------------------------------------------------------

do
    local NPC = 990201
    local ITEM = 920001

    C_QuestLog = {
        IsQuestFlaggedCompleted = function(id) return id == 1 end,
    }
    GetAchievementInfo = function(id)
        return nil, nil, nil, id == 2
    end

    local HA = freshHA()
    HA.Constants = { Icons = {}, SourceBadgeAtlas = {}, Colors = {} }
    HA.Addon.db = {
        global = {
            scannedVendors = {
                [NPC] = {
                    items = {
                        { itemID = ITEM, requirements = { { type = "quest", id = 1 } }, isPurchasable = true },
                        { itemID = ITEM, requirements = { { type = "achievement", id = 2 } }, isPurchasable = false },
                    },
                },
            },
        },
    }

    assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)
    HA.VendorData:BuildScannedIndex()
    assert(loadfile(root .. "/Data/SourceManager.lua"))("Homestead", HA)

    local reqs = HA.SourceManager:GetRequirements(ITEM, NPC)
    assert(reqs and #reqs == 2, "GetRequirements must merge requirements from BOTH scanned slots, not just the first")
    local sawQuest, sawAchievement = false, false
    for _, req in ipairs(reqs) do
        if req.type == "quest" then sawQuest = true end
        if req.type == "achievement" then sawAchievement = true end
    end
    assert(sawQuest and sawAchievement, "both requirement types must be present in the merged list")

    local state = HA.SourceManager:GetVendorItemAvailabilityState(ITEM, NPC)
    assert(state ~= "locked",
        "must not report 'locked' from the isPurchasable gate -- the gate must consult the FIRST " ..
        "array-order slot (isPurchasable=true), not the second (isPurchasable=false); got " .. tostring(state))

    print("hs280_vendor_requirements_index: merge-all + first-match-order ok")
end

-------------------------------------------------------------------------------
-- 4. Key-derivation pin: an item shaped so raw item.itemID and
-- self:GetItemID(item) provably diverge (array-shorthand, no .itemID field).
-- The index must still resolve it by itemID.
-------------------------------------------------------------------------------

do
    local NPC = 990301
    local ITEM = 12345

    local HA = freshHA()
    HA.Addon.db = {
        global = {
            scannedVendors = {
                [NPC] = {
                    items = {
                        { [1] = ITEM, requirements = {} },
                    },
                },
            },
        },
    }

    assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)
    HA.VendorData:BuildScannedIndex()

    local items = HA.VendorData:GetScannedVendorItems(NPC, ITEM)
    assert(items and #items == 1, "array-shorthand item (no .itemID field) must still resolve via GetItemID")
    assert(items[1][1] == ITEM, "resolved entry must be the fixture's item")

    print("hs280_vendor_requirements_index: key-derivation pin ok")
end

-------------------------------------------------------------------------------
-- 5. Invalidation trigger points.
-------------------------------------------------------------------------------

do
    local NPC = 990401
    local ITEM_OLD = 930001
    local ITEM_NEW = 930002

    local HA = freshHA()
    HA.Addon.db = {
        global = {
            scannedVendors = {
                [NPC] = { items = { { itemID = ITEM_OLD, requirements = {} } } },
            },
        },
    }

    assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)
    HA.VendorData:BuildScannedIndex()
    assert(HA.VendorData:GetScannedVendorItems(NPC, ITEM_OLD), "sanity: initial item must be indexed")

    -- OnVendorScanned must rebuild the index off a mutated scannedVendors table.
    HA.Addon.db.global.scannedVendors[NPC] = { items = { { itemID = ITEM_NEW, requirements = {} } } }
    HA.VendorData:OnVendorScanned()
    assert(HA.VendorData:GetScannedVendorItems(NPC, ITEM_NEW), "OnVendorScanned must rebuild the index")
    assert(not HA.VendorData:GetScannedVendorItems(NPC, ITEM_OLD),
        "OnVendorScanned's rebuild must drop the stale entry")

    -- InvalidateVendorCaches must also rebuild it.
    HA.Addon.db.global.scannedVendors[NPC] = { items = { { itemID = ITEM_OLD, requirements = {} } } }
    HA.VendorData:InvalidateVendorCaches()
    assert(HA.VendorData:GetScannedVendorItems(NPC, ITEM_OLD), "InvalidateVendorCaches must rebuild the index")
    assert(not HA.VendorData:GetScannedVendorItems(NPC, ITEM_NEW),
        "InvalidateVendorCaches's rebuild must drop the stale entry")

    print("hs280_vendor_requirements_index: functional invalidation trigger points ok")
end

-------------------------------------------------------------------------------
-- 6. Malformed item (no resolvable itemID): a scanned item that is neither
-- a bare number nor has an .itemID/[1] field GetItemID can unpack. Must be
-- silently skipped, not indexed under a nil key -- this pins the `if itemID
-- then` guard in BuildScannedIndex (removing it makes
-- `self.ScannedByItemID[itemID] = {}` a table-index-is-nil write error).
-------------------------------------------------------------------------------

do
    local NPC = 990501
    local ITEM_GOOD = 940001

    local HA = freshHA()
    HA.Addon.db = {
        global = {
            scannedVendors = {
                [NPC] = {
                    items = {
                        { itemID = ITEM_GOOD, requirements = {} },
                        { requirements = {} }, -- no .itemID, no [1] -- GetItemID resolves to nil
                    },
                },
            },
        },
    }

    assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)

    local ok, err = pcall(function() HA.VendorData:BuildScannedIndex() end)
    assert(ok, "BuildScannedIndex must not error on a malformed (no-resolvable-itemID) item: " .. tostring(err))

    local byItem = HA.VendorData.ScannedItemsByNPC[NPC]
    local indexedCount = 0
    for _ in pairs(byItem) do indexedCount = indexedCount + 1 end
    assert(indexedCount == 1, "the malformed item must be skipped, not indexed -- expected 1 entry, got " .. indexedCount)
    assert(byItem[ITEM_GOOD], "the well-formed item must still be indexed")

    local scannedByItemIDCount = 0
    for _ in pairs(HA.VendorData.ScannedByItemID) do scannedByItemIDCount = scannedByItemIDCount + 1 end
    assert(scannedByItemIDCount == 1, "ScannedByItemID must also skip the malformed item, got " .. scannedByItemIDCount)

    print("hs280_vendor_requirements_index: malformed-itemID skip ok")
end

-------------------------------------------------------------------------------
-- 7. Deleted-vendor stale-index coverage: a vendor removed entirely from
-- scannedVendors (not just its item set changed) must not linger in
-- ScannedItemsByNPC after a rebuild -- pins that BuildScannedIndex fully
-- reassigns self.ScannedItemsByNPC = {} rather than merging into the old one.
-------------------------------------------------------------------------------

do
    local NPC_DELETED = 990601
    local ITEM = 950001

    local HA = freshHA()
    HA.Addon.db = {
        global = {
            scannedVendors = {
                [NPC_DELETED] = { items = { { itemID = ITEM, requirements = {} } } },
            },
        },
    }

    assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)
    HA.VendorData:BuildScannedIndex()
    assert(HA.VendorData:GetScannedVendorItems(NPC_DELETED, ITEM), "sanity: vendor must be indexed before deletion")

    -- Vendor removed entirely (not replaced) -- e.g. ScanPersistence's delete branch.
    HA.Addon.db.global.scannedVendors[NPC_DELETED] = nil
    HA.VendorData:BuildScannedIndex()

    assert(HA.VendorData:GetScannedVendorItems(NPC_DELETED, ITEM) == nil,
        "a fully-deleted vendor must not linger in ScannedItemsByNPC after rebuild")

    print("hs280_vendor_requirements_index: deleted-vendor stale-index ok")
end

-- Source-pattern checks on ScanPersistence.lua (too heavy a dependency
-- surface to loadfile-execute -- per hs273's convention).
do
    local scanPersistSource = readFile(root .. "/Modules/ScanPersistence.lua")

    local deletePos = scanPersistSource:find("scannedVendors%[scanData%.npcID%] = nil")
    assert(deletePos, "delete branch not found")
    local buildPosAfterDelete = scanPersistSource:find("BuildScannedIndex%(%)", deletePos)
    assert(buildPosAfterDelete and (buildPosAfterDelete - deletePos) < 1000,
        "delete branch must still call BuildScannedIndex() nearby")

    local refreshMapPinsBody = scanPersistSource:match("local function RefreshMapPins%(%)(.-)\nend")
    assert(refreshMapPinsBody, "RefreshMapPins body not found")
    assert(refreshMapPinsBody:find("BuildScannedIndex%(%)") ~= nil,
        "RefreshMapPins must still call BuildScannedIndex()")

    assert(scanPersistSource:find("fires no VENDOR_SCANNED", 1, true) == nil,
        "the stale 'fires no VENDOR_SCANNED' comment must be gone (HS-280 comment fix)")

    print("hs280_vendor_requirements_index: ScanPersistence source-pattern checks ok")
end

print("hs280_vendor_requirements_index: done")
