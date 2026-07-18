--[[
    Homestead - DecorClassifier
    Item classification for vendor scanning

    Extracted from VendorScanner.lua to reduce file size.
    Pure classification logic — no scan state, no persistence.

    Reusable by VendorScanner and any future module needing decor detection.
]]

local _, HA = ...

local DecorClassifier = {}
HA.DecorClassifier = DecorClassifier

-------------------------------------------------------------------------------
-- Decor Detection
-------------------------------------------------------------------------------

-- Check if an item is a housing decor item using the Housing Catalog API.
-- Returns: isDecor (boolean), decorInfo (table or nil)
function DecorClassifier.CheckIfDecorItem(itemLink)
    local CHC = _G.C_HousingCatalog
    if not itemLink or not CHC or not CHC.GetCatalogEntryInfoByItem then
        return false, nil
    end

    -- Use the Housing Catalog API to check if this item is decor
    local ok, catalogInfo = pcall(CHC.GetCatalogEntryInfoByItem, itemLink, true)
    if ok and catalogInfo then
        -- Extract item ID from link
        local itemID = C_Item.GetItemInfoInstant(itemLink)
        -- HS-218: isOwned/quantityOwned removed — they don't exist on
        -- HousingCatalogEntryInfo. Ownership must only ever come from
        -- CatalogStore:ComputeOwnedFromInfo (the canonical count-contract
        -- read); no individual field here is an ownership signal, and
        -- firstAcquisitionBonus in particular is display-only (settled
        -- HS-123 ruling). These two always read nil; the one caller here never
        -- consulted them, but a future reader would have silently seen
        -- "unowned" from a field that was never real (the HS-123 silent-
        -- shape class) instead of an obvious missing-field signal.
        return true, {
            itemID = itemID,
            entryID = catalogInfo.entryID,
            name = catalogInfo.name,
        }
    end

    return false, nil
end
