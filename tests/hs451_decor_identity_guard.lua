-- luacheck: globals assert loadfile print tonumber wipe C_Item C_HousingCatalog Enum

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-451: a catalogItems record (ci[itemID]) is positive identification for
-- decor only when the item's housing subclass is Decor or unresolved. A
-- record for any other housing subclass -- Dye, Room, RoomCustomization,
-- ExteriorCustomization, ServiceItem -- must not read as decor, or the
-- bag/merchant/tooltip overlays would switch on for an item whose ownership
-- those overlays cannot compute.
-------------------------------------------------------------------------------

wipe = function(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end

Enum = {
    ItemClass = { Housing = 20 },
    ItemHousingSubclass = {
        Decor = 0, Dye = 1, Room = 2, RoomCustomization = 3,
        ExteriorCustomization = 4, ServiceItem = 5,
    },
}

-- itemID -> {classID, subClassID}. 9006 is a resolvable non-housing item
-- (classID 0), so GetHousingSubclass reads it as "not a housing item" (nil)
-- -- gate 1 must then keep the existing positive ci answer, rather than the
-- MayReturnNothing case (a malformed itemID), which is a separate trap.
local itemClassByItemID = {
    [9001] = { Enum.ItemClass.Housing, Enum.ItemHousingSubclass.Decor },
    [9002] = { Enum.ItemClass.Housing, Enum.ItemHousingSubclass.Dye },
    [9003] = { Enum.ItemClass.Housing, Enum.ItemHousingSubclass.Room },
    [9004] = { Enum.ItemClass.Housing, Enum.ItemHousingSubclass.Room },
    [9005] = { Enum.ItemClass.Housing, Enum.ItemHousingSubclass.ExteriorCustomization },
    [9006] = { 0, 0 },
}

C_Item = {
    GetItemInfoInstant = function(x)
        local id = type(x) == "number" and x or tonumber(tostring(x):match("(%d+)"))
        local fixture = itemClassByItemID[id]
        if not fixture then return end -- MayReturnNothing: no values at all
        return id, nil, nil, nil, nil, fixture[1], fixture[2]
    end,
}

C_HousingCatalog = {
    GetCatalogEntryInfoByItem = function() return nil end,
    GetCatalogEntryInfoByRecordID = function(entryType, recordID)
        if entryType == 2 and recordID == 288 then
            return {
                name = "Bel'ameth Meeting Room", totalNumStored = 1, remainingRedeemable = 0,
                totalNumPlaced = 0, sourceText = "Vendor: Test", entryID = { recordID = 288, entryType = 2 },
            }
        end
        if entryType == 1 and recordID == 288 then
            return { totalNumStored = 0, remainingRedeemable = 0, totalNumPlaced = 0 }
        end
        if entryType == 1 and recordID == 500 then
            return { totalNumStored = 1 }
        end
        return nil
    end,
}

local HA = {
    Addon = {
        db = { global = { catalogItems = {}, schemaVersion = 7 } },
        RegisterModule = function() end,
        Debug = function() end,
    },
    Constants = { VERSION = "test" },
    Events = { Fire = function() end },
    DecorMapping = { [500] = 9001 },
}

assert(loadfile(root .. "/Data/CatalogStore.lua"))("Homestead", HA)
HA.CatalogStore:Initialize()

HA.CatalogStore:Save(9001, { name = "d" })
HA.CatalogStore:Save(9002, { name = "y" })
HA.CatalogStore:Save(9003, { name = "r" })
HA.CatalogStore:Save(9006, { name = "n" })

assert(HA.CatalogStore:IsDecorItem("item:9001") == true,
    "a Decor-subclass ci record must still read as decor")
assert(HA.CatalogStore:IsDecorItem("item:9002") == false,
    "a Dye ci record must not read as decor")
assert(HA.CatalogStore:IsDecorItem("item:9003") == false,
    "a Room ci record must not read as decor")
assert(HA.CatalogStore:IsDecorItem("item:9006") == true,
    "a ci record whose subclass cannot be resolved must keep the existing positive answer")

print("hs451_decor_identity_guard: IsDecorItem gate 1 subclass check ok")
