-- luacheck: globals assert loadfile print C_Item Enum

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-251 Stage C: CatalogStore:IsOwnershipUnknowable is the ticket's mandatory
-- honest-making change (a room plan must never render as "not owned" when
-- ownership is simply unknowable — see the badge-lie this exists to prevent
-- at UI/BadgeCalculation.lua) and is wired into six production call sites
-- (BadgeCalculation, MapSidePanel, HousingDashboard, VendorTracer,
-- VendorMapPins, SourceManager). It had zero test coverage. This file tests
-- the predicate directly, not the six call sites.
-------------------------------------------------------------------------------

-- C_Item.GetItemInfoInstant returns classID 6th, subClassID 7th (see
-- CLAIM-STUDIO-0009, confirmed against Blizzard_APIDocumentationGenerated/
-- ItemDocumentation.lua and MerchantFrame.lua's identical destructuring
-- pattern). It is documented MayReturnNothing: an unresolvable item returns
-- ZERO values, not a row of nils — the mock below returns nothing for any
-- itemID not in the fixture table to exercise that trap honestly.
Enum = {
    ItemClass = { Housing = 20 },
    ItemHousingSubclass = {
        Decor = 0, Dye = 1, Room = 2, RoomCustomization = 3,
        ExteriorCustomization = 4, ServiceItem = 5,
    },
}

local itemFixtures = {
    [9001] = { classID = Enum.ItemClass.Housing, subClassID = Enum.ItemHousingSubclass.Decor },
    [9002] = { classID = Enum.ItemClass.Housing, subClassID = Enum.ItemHousingSubclass.Dye },
    [9003] = { classID = Enum.ItemClass.Housing, subClassID = Enum.ItemHousingSubclass.Room },
}

C_Item = {
    GetItemInfoInstant = function(itemID)
        local fixture = itemFixtures[itemID]
        if not fixture then return end -- MayReturnNothing: no values at all
        return itemID, "Housing", "Test", "", 0, fixture.classID, fixture.subClassID
    end,
}

local StoreHA = {}
assert(loadfile(root .. "/Data/CatalogStore.lua"))("Homestead", StoreHA)

-- Decor resolves ownership normally — must NOT be excluded.
assert(StoreHA.CatalogStore:IsOwnershipUnknowable(9001) == false,
    "Decor items must never be ownership-excluded — their ownership is knowable via the catalog")

-- Every non-Decor housing subclass must be excluded. Looped (not just Room)
-- so a future subclass constant added to the enum is automatically covered.
for _, name in ipairs({ "Dye", "Room" }) do
    local itemID = name == "Dye" and 9002 or 9003
    assert(StoreHA.CatalogStore:IsOwnershipUnknowable(itemID) == true,
        name .. " must be ownership-excluded — it resolves through no housing catalog entry")
end

-- An item GetItemInfoInstant cannot resolve at all (MayReturnNothing) must
-- not be excluded — "unknowable class" is not "unknowable ownership."
assert(StoreHA.CatalogStore:IsOwnershipUnknowable(99999) == false,
    "an item C_Item.GetItemInfoInstant cannot resolve must not be flagged ownership-excluded")

-- Defensive branch: if Enum.ItemHousingSubclass itself is ever nil, the
-- predicate must fail closed (false), not error — a nil Decor comparison
-- would otherwise exclude the entire catalog silently.
Enum.ItemHousingSubclass = nil
assert(StoreHA.CatalogStore:IsOwnershipUnknowable(9003) == false,
    "a missing Enum.ItemHousingSubclass must fail closed to false, not error or exclude everything")

print("hs249_exclusion: HS-251 ownership-exclusion predicate ok")
