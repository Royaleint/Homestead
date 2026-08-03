--[[
    Homestead - DecorClassifier
    Item classification for vendor scanning

    Extracted from VendorScanner.lua to reduce file size.
    Pure classification logic — no scan state, no persistence.

    Reusable by VendorScanner and any future module needing housing-item
    classification.
]]

local _, HA = ...

local DecorClassifier = {}
HA.DecorClassifier = DecorClassifier

-------------------------------------------------------------------------------
-- Housing Item Classification
-------------------------------------------------------------------------------

-- Classify an item as housing (any subclass) or not. Decor (subclass 0) is
-- further enriched against the Housing Catalog, since that is the only
-- subclass the catalog resolves an entry for.
-- Returns: isHousing (boolean), subclassID (number or nil), decorInfo (table or nil)
function DecorClassifier.ClassifyHousingItem(itemLink)
    if not itemLink then
        return false, nil, nil
    end

    -- GetItemInfoInstant is documented MayReturnNothing: an invalid link
    -- returns nothing at all, not nils, so a multi-assign here can yield
    -- fewer than seven values. classID then arrives nil and fails the
    -- comparison below — fail closed rather than assume the full shape.
    local itemID, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemLink)
    if classID ~= Enum.ItemClass.Housing then
        return false, nil, nil
    end

    local decorInfo = nil
    if subClassID == Enum.ItemHousingSubclass.Decor then
        local CHC = _G.C_HousingCatalog
        if CHC and CHC.GetCatalogEntryInfoByItem then
            local ok, catalogInfo = pcall(CHC.GetCatalogEntryInfoByItem, itemLink, true)
            if ok and catalogInfo then
                -- itemID comes from the classification call above; this runs
                -- per merchant slot, so a second GetItemInfoInstant on the
                -- same link would be pure waste on the scan path.
                -- HS-218: isOwned/quantityOwned removed — they don't exist on
                -- HousingCatalogEntryInfo. Ownership must only ever come from
                -- CatalogStore:ComputeOwnedFromInfo (the canonical count-contract
                -- read); no individual field here is an ownership signal, and
                -- firstAcquisitionBonus in particular is display-only (settled
                -- HS-123 ruling). These two always read nil; the one caller here never
                -- consulted them, but a future reader would have silently seen
                -- "unowned" from a field that was never real (the HS-123 silent-
                -- shape class) instead of an obvious missing-field signal.
                decorInfo = {
                    itemID = itemID,
                    entryID = catalogInfo.entryID,
                    name = catalogInfo.name,
                }
            end
        end
    end

    return true, subClassID, decorInfo
end
