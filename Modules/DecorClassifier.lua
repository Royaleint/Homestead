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
        return true, {
            itemID = itemID,
            entryID = catalogInfo.entryID,
            name = catalogInfo.name,
            isOwned = catalogInfo.isOwned,
            quantityOwned = catalogInfo.quantityOwned,
        }
    end

    return false, nil
end
