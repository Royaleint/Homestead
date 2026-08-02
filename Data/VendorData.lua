--[[
    Homestead - VendorData
    Unified vendor data access layer

    This module provides:
    - Unified access to static (VendorDatabase) and scanned vendor data
    - Query functions for finding vendors by item, location, or name
    - Merging of scanned vendor data with static database
]]

local _, HA = ...

local VendorData = {}
HA.VendorData = VendorData

-------------------------------------------------------------------------------
-- Vendor Name to NPC ID Mapping
-- Maps official vendor names (as they appear in C_HousingCatalog source data)
-- to their NPC IDs in VendorDatabase. Some vendors have multiple NPC IDs
-- due to appearing in multiple locations.
-------------------------------------------------------------------------------

VendorData.VendorNameToNPC = {
    -- Housing hub vendors (Razorwind Shores / Founder's Point)
    ["\"High Tides\" Ren"] = {231012, 255222, 255325},
    ["\"Len\" Splinthoof"] = {255228, 255326},
    ["\"Yen\" Malone"] = {255230, 255319},
    ["Argan Hammerfist"] = {255218},
    ["Balen Starfinder"] = {255216},
    ["Botanist Boh'an"] = {255301},
    ["Faarden the Builder"] = {255213},
    ["Gronthul"] = {255278},
    ["Jehzar Starfall"] = {255298},
    ["Klasa"] = {256750},
    ["Lefton Farrer"] = {255299},
    ["Lonomia"] = {240465},
    ["Shon'ja"] = {255297},
    ["Trevor Grenner"] = {255221},
    ["Xiao Dan"] = {255203},

    -- Dornogal
    ["Auditor Balwurz"] = {223728},
    ["Second Chair Pawdo"] = {252312},

    -- Undermine
    ["Lab Assistant Laszly"] = {231408},
    ["Stacks Topskimmer"] = {251911},

    -- Valdrakken
    ["Silvrath"] = {253067},
    ["Unatos"] = {193015},

    -- Amirdrassil / Night Elf
    ["Ellandrieth"] = {207514, 216285},
    ["Mythrin'dir"] = {216284},

    -- Gilneas
    ["Marie Allen"] = {211065},
    ["Samantha Buckley"] = {216888},

    -- Suramar
    ["Jocenna"] = {120897, 252969},
    ["Sileas Duskvine"] = {253434},

    -- Val'sharah
    ["Selfira Ambergrove"] = {120899, 253387},
    ["Sylvia Hartshorn"] = {106887, 106901},

    -- Legion zones
    ["Amurra Thistledew"] = {112323},
    ["Berazus"] = {89939, 116305},
    ["Rasil Fireborne"] = {112716},
    ["Toraan the Revered"] = {125346},

    -- Stormwind / Alliance
    ["Captain Lancy Revshon"] = {45389, 49877},
    ["Lord Candren"] = {50307},
    ["Riica"] = {254603},
    ["Solelo"] = {256071},

    -- Warlords of Draenor
    ["Vindicator Nuurem"] = {85932},

    -- BfA
    ["Provisioner Fray"] = {135808},

    -- Pandaria
    ["San Redscale"] = {58414},

    -- Classic zones
    ["Jaquilina Dramet"] = {2483, 6574},
    ["Purser Boulian"] = {28038, 61911, 72111},

    -- Generic source names (not real NPCs, appear in sourceText as vendor references)
    -- ["Draenor World Vendors"] = {},  -- Placeholder
    -- ["Eastern Kingdoms World Vendors"] = {},  -- Placeholder
}

-- Reverse lookup: NPC ID to vendor name
VendorData.NPCToVendorName = {}

-------------------------------------------------------------------------------
-- Item Format Helpers
-- New format: items can be either:
--   - Plain integer: 245603 (no cost data)
--   - Table: {245603, cost = {gold = 5000000, currencies = {{id = 1220, amount = 100}}}}
-------------------------------------------------------------------------------

-- Extract itemID and cost from an item entry (handles both formats)
local function UnpackItem(item)
    if type(item) == "number" then
        return item, nil
    end
    if type(item) == "table" then
        return item.itemID or item[1], item.cost
    end
    return nil, nil
end

-- Extract the item ID from an item entry (handles both formats)
function VendorData:GetItemID(item)
    local itemID = UnpackItem(item)
    return itemID
end

-- Extract cost data from an item entry (returns nil if no cost data)
function VendorData:GetItemCost(item)
    local _, cost = UnpackItem(item)
    return cost
end

-- Format cost as a display string with icons (e.g., "10|Tgold|t 50|Tsilver|t" or "500 |Tcurrency|t")
function VendorData:FormatCost(cost)
    if not cost then return nil end

    local parts = {}

    -- Format gold (stored in copper) using C_CurrencyInfo.GetCoinTextureString for coin icons
    if cost.gold and cost.gold > 0 then
        if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
            parts[#parts + 1] = C_CurrencyInfo.GetCoinTextureString(cost.gold)
        else
            -- Fallback if API unavailable
            local gold = math.floor(cost.gold / 10000)
            local silver = math.floor((cost.gold % 10000) / 100)
            local copper = cost.gold % 100
            local goldStr = ""
            if gold > 0 then goldStr = gold .. "g" end
            if silver > 0 then goldStr = goldStr .. (goldStr ~= "" and " " or "") .. silver .. "s" end
            if copper > 0 then goldStr = goldStr .. (goldStr ~= "" and " " or "") .. copper .. "c" end
            if goldStr ~= "" then parts[#parts + 1] = goldStr end
        end
    end

    -- Format currencies with icons
    if cost.currencies then
        for _, currency in ipairs(cost.currencies) do
            if currency.amount then
                if currency.id and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
                    local info = C_CurrencyInfo.GetCurrencyInfo(currency.id)
                    if info and info.iconFileID then
                        parts[#parts + 1] = currency.amount .. " |T" .. info.iconFileID .. ":0:0|t"
                    elseif info and info.name then
                        parts[#parts + 1] = currency.amount .. " " .. info.name
                    else
                        parts[#parts + 1] = currency.amount .. " Currency " .. currency.id
                    end
                elseif currency.name then
                    parts[#parts + 1] = currency.amount .. " " .. currency.name
                end
            end
        end
    end

    -- Format item-based currencies (e.g., Spare Parts, Polished Pet Charms)
    if cost.items then
        for _, itemCost in ipairs(cost.items) do
            if itemCost.amount and itemCost.id then
                local itemName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemCost.id)
                local iconID = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemCost.id)
                if iconID then
                    parts[#parts + 1] = itemCost.amount .. " |T" .. iconID .. ":0:0|t"
                elseif itemName then
                    parts[#parts + 1] = itemCost.amount .. " " .. itemName
                else
                    parts[#parts + 1] = itemCost.amount .. " Item " .. itemCost.id
                end
            end
        end
    end

    if #parts == 0 then
        return nil
    end

    return table.concat(parts, " + ")
end

-- Convert scanned item cost format to static item cost format
-- Scanned (legacy): {price = copper, currencies = {{currencyID, amount, name}}, itemCosts = {{itemID, amount, name}}}
-- Scanned (future): {cost = {gold = copper, currencies = {{id, amount}}}}
-- Static:  {gold = copper, currencies = {{id, amount, name}}}
function VendorData:NormalizeScannedCost(scannedItem)
    if not scannedItem then return nil end

    -- If already normalized (cost field present), return it directly
    if scannedItem.cost then
        return scannedItem.cost
    end

    local cost = {}
    local hasCost = false

    -- Convert price (copper) to gold field
    if scannedItem.price and scannedItem.price > 0 then
        cost.gold = scannedItem.price
        hasCost = true
    end

    -- Convert currencies array (currencyID -> id, preserve name as fallback)
    if scannedItem.currencies and #scannedItem.currencies > 0 then
        cost.currencies = {}
        for _, curr in ipairs(scannedItem.currencies) do
            table.insert(cost.currencies, {
                id = curr.currencyID,
                amount = curr.amount,
                name = curr.name,
            })
        end
        hasCost = true
    end

    return hasCost and cost or nil
end

-------------------------------------------------------------------------------
-- Shared Item Merge Helpers
-------------------------------------------------------------------------------

-- Merge static/offer-backed vendor items + scanned vendor items into a deduplicated itemID set.
-- Returns:
--   itemSet                 -- {[itemID] = true}
--   orderedItemIDs (opt-in) -- {itemID1, itemID2, ...} in merge order
-- Merge order matches existing callers: static items first, scanned-only additions second.
function VendorData:GetMergedItemSet(vendor, includeOrderedIDs)
    if not vendor or not vendor.npcID then
        if includeOrderedIDs then
            return {}, {}
        end
        return {}
    end

    local itemSet = {}
    local orderedItemIDs = includeOrderedIDs and {} or nil

    local function AddItem(itemID)
        if itemID and not itemSet[itemID] then
            itemSet[itemID] = true
            if orderedItemIDs then
                orderedItemIDs[#orderedItemIDs + 1] = itemID
            end
        end
    end

    -- Static items from explicit vendor rows or projected VendorOffers data.
    local staticItems = vendor.items
    if (not staticItems or #staticItems == 0) and vendor.npcID then
        staticItems = self:GetVendorItems(vendor.npcID)
    end
    if staticItems and #staticItems > 0 then
        for _, item in ipairs(staticItems) do
            AddItem(self:GetItemID(item))
        end
    end

    -- Scanned items from VendorScanner (including corrected NPC ID fallback)
    local db = HA.Addon and HA.Addon.db
    if db and db.global and db.global.scannedVendors then
        local scannedData = db.global.scannedVendors[vendor.npcID]
        if not scannedData and vendor.name and HA.VendorScanner then
            local correctedID = HA.VendorScanner:GetCorrectedNPCID(vendor.name)
            if correctedID then
                scannedData = db.global.scannedVendors[correctedID]
            end
        end

        local scannedItems = scannedData and scannedData.items
        if scannedItems then
            for _, item in ipairs(scannedItems) do
                AddItem(item.itemID)
            end
        end
    end

    if includeOrderedIDs then
        return itemSet, orderedItemIDs
    end
    return itemSet
end

-- Convenience wrapper: return ordered merged item IDs for a vendor.
function VendorData:GetMergedItemIDs(vendor)
    local _, orderedItemIDs = self:GetMergedItemSet(vendor, true)
    return orderedItemIDs
end

-------------------------------------------------------------------------------
-- Query Functions
-------------------------------------------------------------------------------

-- Resolve an alias NPC ID to its canonical ID.
-- Returns the canonical ID if an alias exists, nil otherwise.
-- Checks VendorIdentity, VendorDatabase, and EndeavorsData aliases.
function VendorData:ResolveAlias(npcID)
    if HA.VendorIdentity and HA.VendorIdentity.Aliases then
        local id = HA.VendorIdentity.Aliases[npcID]
        if id then return id end
    end
    if HA.VendorDatabase and HA.VendorDatabase.Aliases then
        local id = HA.VendorDatabase.Aliases[npcID]
        if id then return id end
    end
    if HA.EndeavorsData and HA.EndeavorsData.Aliases then
        local id = HA.EndeavorsData.Aliases[npcID]
        if id then return id end
    end
    return nil
end

local function ProjectVendorWithItems(self, vendor, npcID)
    if not vendor then return nil end

    local copy = {}
    for key, value in pairs(vendor) do
        copy[key] = value
    end
    copy.items = vendor.items or self:GetVendorItems(npcID or vendor.npcID)
    return copy
end

-- Get vendor info by NPC ID (resolves aliases)
function VendorData:GetVendor(npcID)
    if HA.VendorIdentity then
        local vendor = HA.VendorIdentity:GetVendor(npcID)
        if vendor then return ProjectVendorWithItems(self, vendor, npcID) end
    end
    if HA.EndeavorsData and HA.EndeavorsData.Vendors then
        local vendor = HA.EndeavorsData.Vendors[npcID]
        if vendor then return vendor end
    end
    if HA.VendorDatabase then
        local vendor = HA.VendorDatabase:GetVendor(npcID)
        if vendor then return vendor end
    end
    -- Resolve alias and retry (cycle guard: canonicalID must differ)
    local canonicalID = self:ResolveAlias(npcID)
    if canonicalID and canonicalID ~= npcID then
        return self:GetVendor(canonicalID)
    end
    return nil
end

-- Check if vendor exists (resolves aliases)
function VendorData:HasVendor(npcID)
    if HA.VendorIdentity and HA.VendorIdentity:HasVendor(npcID) then
        return true
    end
    if HA.EndeavorsData and HA.EndeavorsData.Vendors then
        if HA.EndeavorsData.Vendors[npcID] then return true end
    end
    if HA.VendorDatabase and HA.VendorDatabase:HasVendor(npcID) then
        return true
    end
    -- Resolve alias and retry (cycle guard: canonicalID must differ)
    local canonicalID = self:ResolveAlias(npcID)
    if canonicalID and canonicalID ~= npcID then
        return self:HasVendor(canonicalID)
    end
    return false
end

-- Display-layer endeavor filter (fail-open while active theme is unknown)
local function ShouldIncludeEndeavorVendorForDisplay(vendor)
    if not vendor or not vendor.endeavor then
        return true
    end

    if HA.EndeavorsData and HA.EndeavorsData.IsVendorActive then
        return HA.EndeavorsData:IsVendorActive(vendor)
    end

    return true
end

-- Get all vendors in a specific map/zone
-- Includes active event vendors from EventSources
function VendorData:GetVendorsInMap(mapID)
    local result = {}
    local addedNPCs = {}

    -- Static identity vendors
    if HA.VendorIdentity then
        local identityVendors = HA.VendorIdentity:GetVendorsByMapID(mapID)
        if identityVendors then
            for _, vendor in ipairs(identityVendors) do
                result[#result + 1] = ProjectVendorWithItems(self, vendor)
                if vendor.npcID then
                    addedNPCs[vendor.npcID] = true
                end
            end
        end
    elseif HA.VendorDatabase then
        local dbVendors = HA.VendorDatabase:GetVendorsByMapID(mapID)
        if dbVendors then
            for _, vendor in ipairs(dbVendors) do
                result[#result + 1] = ProjectVendorWithItems(self, vendor)
                if vendor.npcID then
                    addedNPCs[vendor.npcID] = true
                end
            end
        end
    end

    -- Append endeavor vendors for this mapID
    if HA.EndeavorsData and HA.EndeavorsData.ByMapID then
        local endeavorVendors = HA.EndeavorsData.ByMapID[mapID]
        if endeavorVendors then
            for _, vendor in ipairs(endeavorVendors) do
                if vendor.npcID and not addedNPCs[vendor.npcID]
                        and ShouldIncludeEndeavorVendorForDisplay(vendor) then
                    result[#result + 1] = vendor
                    addedNPCs[vendor.npcID] = true
                end
            end
        end

        -- Note: alt-location entries are already in ByMapID (indexed at load time
        -- with correct coordinates for each neighborhood). No runtime fallback needed.
    end

    -- Append active event vendors for this mapID
    if HA.EventSources and HA.EventSources.EventVendorsByMapID then
        local eventVendors = HA.EventSources.EventVendorsByMapID[mapID]
        if eventVendors then
            for _, vendor in ipairs(eventVendors) do
                -- Dedup: skip if already added (e.g., vendor was scanned in-game)
                if vendor.npcID and not addedNPCs[vendor.npcID] then
                    -- Only include if holiday is active (nil = unknown → don't inject)
                    if HA.CalendarDetector and HA.CalendarDetector:IsHolidayActive(vendor.event) == true then
                        result[#result + 1] = vendor
                        addedNPCs[vendor.npcID] = true
                    end
                end
            end
        end
    end

    return result
end

-- Get all vendors for a faction (includes Neutral)
function VendorData:GetVendorsForFaction(faction)
    local result = {}

    -- Static identity vendors
    local staticVendors = HA.VendorIdentity and HA.VendorIdentity.Vendors
            or (HA.VendorDatabase and HA.VendorDatabase.Vendors)
    if staticVendors then
        for _, vendor in pairs(staticVendors) do
            local vendorFaction = vendor.faction or "Neutral"
            if vendorFaction == faction or vendorFaction == "Neutral" then
                table.insert(result, ProjectVendorWithItems(self, vendor, vendor.npcID))
            end
        end
    end

    -- EndeavorsData vendors
    if HA.EndeavorsData and HA.EndeavorsData.Vendors then
        for _, vendor in pairs(HA.EndeavorsData.Vendors) do
            local vendorFaction = vendor.faction or "Neutral"
            if vendorFaction == faction or vendorFaction == "Neutral" then
                table.insert(result, vendor)
            end
        end
    end

    return result
end

-- Get all vendors that sell a specific item
function VendorData:GetVendorsForItem(itemID)
    if not itemID then return {} end

    local result = {}
    local seenNPCs = {}  -- Track NPC IDs to avoid duplicates

    -- Priority 1: Static offer index (curated, authoritative)
    if self.OfferByItemID and self.OfferByItemID[itemID] then
        for _, npcID in ipairs(self.OfferByItemID[itemID]) do
            local vendor = self:GetVendor(npcID)
            if vendor then
                table.insert(result, vendor)
                seenNPCs[npcID] = true
            end
        end
    elseif HA.VendorDatabase then
        -- Phase-3 fallback while legacy VendorDatabase still loads.
        if HA.VendorDatabase.ByItemID and HA.VendorDatabase.ByItemID[itemID] then
            for _, npcID in ipairs(HA.VendorDatabase.ByItemID[itemID]) do
                local vendor = self:GetVendor(npcID)
                if vendor then
                    table.insert(result, vendor)
                    seenNPCs[npcID] = true
                end
            end
        end
    end

    -- Priority 1b: EndeavorsData
    if HA.EndeavorsData and HA.EndeavorsData.ByItemID and HA.EndeavorsData.ByItemID[itemID] then
        for _, npcID in ipairs(HA.EndeavorsData.ByItemID[itemID]) do
            if not seenNPCs[npcID] then
                local vendor = HA.EndeavorsData.Vendors[npcID]
                if vendor then
                    table.insert(result, vendor)
                    seenNPCs[npcID] = true
                end
            end
        end
    end

    -- Priority 2: Scanned vendor data (fallback for items not in static DB)
    if self.ScannedByItemID and self.ScannedByItemID[itemID] then
        local db = HA.Addon and HA.Addon.db
        if db and db.global and db.global.scannedVendors then
            for _, npcID in ipairs(self.ScannedByItemID[itemID]) do
                if not seenNPCs[npcID] then
                    local scannedVendor = db.global.scannedVendors[npcID]
                    if scannedVendor then
                        -- Resolve zone name from mapID
                        local zoneName
                        if scannedVendor.mapID and C_Map and C_Map.GetMapInfo then
                            local mapInfo = C_Map.GetMapInfo(scannedVendor.mapID)
                            if mapInfo then
                                zoneName = mapInfo.name
                            end
                        end

                        local vendorObj = {
                            npcID = npcID,
                            name = scannedVendor.name,
                            mapID = scannedVendor.mapID,
                            x = scannedVendor.coords and scannedVendor.coords.x,
                            y = scannedVendor.coords and scannedVendor.coords.y,
                            zone = zoneName or ("Map " .. (scannedVendor.mapID or "?")),
                            faction = scannedVendor.faction,
                            items = scannedVendor.items,
                            _isScanned = true,
                        }
                        table.insert(result, vendorObj)
                        seenNPCs[npcID] = true
                    end
                end
            end
        end
    end

    -- Priority 3: Active event vendors
    if HA.EventSources and HA.EventSources.EventVendors then
        for _, eventVendor in pairs(HA.EventSources.EventVendors) do
            if eventVendor.npcID and not seenNPCs[eventVendor.npcID]
                    and eventVendor.items and HA.CalendarDetector
                    and HA.CalendarDetector:IsHolidayActive(eventVendor.event) == true then
                for _, eventItemID in ipairs(eventVendor.items) do
                    if eventItemID == itemID then
                        result[#result + 1] = eventVendor
                        seenNPCs[eventVendor.npcID] = true
                        break
                    end
                end
            end
        end
    end

    return result
end

-- Get the closest vendor that sells a specific item
function VendorData:GetClosestVendorForItem(itemID)
    local vendorList = self:GetVendorsForItem(itemID)
    if #vendorList == 0 then
        return nil
    end

    -- Get player's current map and position
    local playerMapID = C_Map.GetBestMapForUnit("player")
    local playerPos = playerMapID and C_Map.GetPlayerMapPosition(playerMapID, "player")

    if not playerMapID or not playerPos then
        -- Can't determine position, return first vendor
        return vendorList[1]
    end

    local closestVendor = nil
    local closestDistance = math.huge

    for _, vendor in ipairs(vendorList) do
        if vendor.mapID == playerMapID and vendor.x and vendor.y then
            -- Same map - calculate direct distance
            local dx = vendor.x - playerPos.x
            local dy = vendor.y - playerPos.y
            local distance = math.sqrt(dx*dx + dy*dy)

            if distance < closestDistance then
                closestDistance = distance
                closestVendor = vendor
            end
        end
    end

    -- If no vendor on same map, just return first one
    return closestVendor or vendorList[1]
end

-- Search vendors by name or zone
function VendorData:SearchVendors(searchText)
    if not searchText or searchText == "" then
        return {}
    end

    local lowerSearch = searchText:lower()
    local result = {}
    local addedNPCs = {}

    -- Search static identity data
    local staticVendors = HA.VendorIdentity and HA.VendorIdentity.Vendors
            or (HA.VendorDatabase and HA.VendorDatabase.Vendors)
    if staticVendors then
        for npcID, vendor in pairs(staticVendors) do
            local matched = false
            if vendor.name and vendor.name:lower():find(lowerSearch, 1, true) then
                matched = true
            elseif vendor.zone and vendor.zone:lower():find(lowerSearch, 1, true) then
                matched = true
            elseif vendor.subzone and vendor.subzone:lower():find(lowerSearch, 1, true) then
                matched = true
            end
            if matched then
                result[#result + 1] = ProjectVendorWithItems(self, vendor, npcID)
                addedNPCs[npcID] = true
            end
        end
    end

    -- Search endeavor vendors
    if HA.EndeavorsData and HA.EndeavorsData.Vendors then
        for npcID, vendor in pairs(HA.EndeavorsData.Vendors) do
            if not addedNPCs[npcID] then
                local matched = false
                if vendor.name and vendor.name:lower():find(lowerSearch, 1, true) then
                    matched = true
                elseif vendor.zone and vendor.zone:lower():find(lowerSearch, 1, true) then
                    matched = true
                elseif vendor.subzone and vendor.subzone:lower():find(lowerSearch, 1, true) then
                    matched = true
                elseif vendor.notes and vendor.notes:lower():find(lowerSearch, 1, true) then
                    matched = true
                end
                if matched and ShouldIncludeEndeavorVendorForDisplay(vendor) then
                    result[#result + 1] = vendor
                    addedNPCs[npcID] = true
                end
            end
        end
    end

    -- Search active event vendors
    if HA.EventSources and HA.EventSources.EventVendors then
        for npcID, vendor in pairs(HA.EventSources.EventVendors) do
            if not addedNPCs[npcID] then
                if HA.CalendarDetector and HA.CalendarDetector:IsHolidayActive(vendor.event) == true then
                    local matched = false
                    if vendor.name and vendor.name:lower():find(lowerSearch, 1, true) then
                        matched = true
                    elseif vendor.zone and vendor.zone:lower():find(lowerSearch, 1, true) then
                        matched = true
                    elseif vendor.event and vendor.event:lower():find(lowerSearch, 1, true) then
                        matched = true
                    end
                    if matched then
                        result[#result + 1] = vendor
                        addedNPCs[npcID] = true
                    end
                end
            end
        end
    end

    return result
end

-- Get all vendors (includes active event vendors)
function VendorData:GetAllVendors()
    local result = {}
    local addedNPCs = {}

    -- Static identity vendors
    local staticVendors = HA.VendorIdentity and HA.VendorIdentity:GetAllVendors()
            or (HA.VendorDatabase and HA.VendorDatabase:GetAllVendors())
    if staticVendors then
        for _, vendor in ipairs(staticVendors) do
            result[#result + 1] = ProjectVendorWithItems(self, vendor)
            if vendor.npcID then
                addedNPCs[vendor.npcID] = true
            end
        end
    end

    -- Append endeavor vendors
    if HA.EndeavorsData and HA.EndeavorsData.Vendors then
        for _, vendor in pairs(HA.EndeavorsData.Vendors) do
            if vendor.npcID and not addedNPCs[vendor.npcID] then
                result[#result + 1] = vendor
                addedNPCs[vendor.npcID] = true
            end
        end
    end

    -- Append active event vendors
    if HA.EventSources and HA.EventSources.EventVendors then
        for _, vendor in pairs(HA.EventSources.EventVendors) do
            if vendor.npcID and not addedNPCs[vendor.npcID] then
                if HA.CalendarDetector and HA.CalendarDetector:IsHolidayActive(vendor.event) == true then
                    result[#result + 1] = vendor
                    addedNPCs[vendor.npcID] = true
                end
            end
        end
    end

    return result
end

-- Get vendor count
function VendorData:GetVendorCount()
    local count = 0
    if HA.VendorIdentity then
        count = count + HA.VendorIdentity:GetVendorCount()
    elseif HA.VendorDatabase then
        count = count + HA.VendorDatabase:GetVendorCount()
    end
    if HA.EndeavorsData then
        count = count + (HA.EndeavorsData.VendorCount or 0)
    end
    return count
end

-- Get vendors by expansion
function VendorData:GetVendorsByExpansion(expansion)
    local result = {}
    local staticVendors = HA.VendorIdentity and HA.VendorIdentity:GetVendorsByExpansion(expansion)
            or (HA.VendorDatabase and HA.VendorDatabase:GetVendorsByExpansion(expansion))
    if staticVendors then
        for _, vendor in ipairs(staticVendors) do
            result[#result + 1] = ProjectVendorWithItems(self, vendor)
        end
    end
    if HA.EndeavorsData and HA.EndeavorsData.Vendors then
        for _, vendor in pairs(HA.EndeavorsData.Vendors) do
            if vendor.expansion == expansion then
                result[#result + 1] = vendor
            end
        end
    end
    return result
end

-------------------------------------------------------------------------------
-- Vendor Name Lookup Functions
-- For cross-referencing DecorSources data with VendorDatabase
-------------------------------------------------------------------------------

-- Get NPC IDs for a vendor name (from VendorNameToNPC mapping)
function VendorData:GetNPCsForVendorName(vendorName)
    return self.VendorNameToNPC[vendorName]
end

-- Get vendor name for an NPC ID (reverse lookup)
function VendorData:GetVendorNameForNPC(npcID)
    return self.NPCToVendorName[npcID]
end

-- Check if a vendor name is known in our mapping
function VendorData:HasVendorName(vendorName)
    return self.VendorNameToNPC[vendorName] ~= nil
end

-- Get all vendors from VendorDatabase that match a DecorSources vendor name
function VendorData:GetVendorsByDecorSourceName(vendorName)
    local npcIDs = self:GetNPCsForVendorName(vendorName)
    if not npcIDs then return {} end

    local vendors = {}
    for _, npcID in ipairs(npcIDs) do
        local vendor = self:GetVendor(npcID)
        if vendor then
            table.insert(vendors, vendor)
        end
    end
    return vendors
end

-- Build the reverse lookup table (called during initialization)
function VendorData:BuildNameIndex()
    -- Build set of NPC IDs already covered by manual entries
    local coveredNPCs = {}

    for _, npcIDs in pairs(self.VendorNameToNPC) do
        if type(npcIDs) == "table" then
            for _, id in ipairs(npcIDs) do
                coveredNPCs[id] = true
            end
        else
            coveredNPCs[npcIDs] = true
        end
    end

    -- Auto-populate VendorNameToNPC from static identity data for any vendors
    -- not already in the manual table (preserves manual multi-NPC entries)
    local staticVendors = HA.VendorIdentity and HA.VendorIdentity.Vendors
            or (HA.VendorDatabase and HA.VendorDatabase.Vendors)
    if staticVendors then
        -- Add any vendor from the static authority not already covered
        for npcID, vendor in pairs(staticVendors) do
            if vendor.name and not coveredNPCs[npcID] then
                local existing = self.VendorNameToNPC[vendor.name]
                if existing then
                    -- Name already mapped — append this NPC ID if not present
                    if type(existing) == "table" then
                        local found = false
                        for _, id in ipairs(existing) do
                            if id == npcID then found = true; break end
                        end
                        if not found then
                            table.insert(existing, npcID)
                        end
                    else
                        if existing ~= npcID then
                            self.VendorNameToNPC[vendor.name] = {existing, npcID}
                        end
                    end
                else
                    self.VendorNameToNPC[vendor.name] = {npcID}
                end
            end
        end
    end

    -- Also populate from EndeavorsData vendors
    if HA.EndeavorsData and HA.EndeavorsData.Vendors then
        for npcID, vendor in pairs(HA.EndeavorsData.Vendors) do
            if vendor.name and not coveredNPCs[npcID] then
                local existing = self.VendorNameToNPC[vendor.name]
                if existing then
                    if type(existing) == "table" then
                        local found = false
                        for _, id in ipairs(existing) do
                            if id == npcID then found = true; break end
                        end
                        if not found then
                            table.insert(existing, npcID)
                        end
                    else
                        if existing ~= npcID then
                            self.VendorNameToNPC[vendor.name] = {existing, npcID}
                        end
                    end
                else
                    self.VendorNameToNPC[vendor.name] = {npcID}
                end
            end
        end
    end

    -- Build reverse lookup: NPC ID -> vendor name
    self.NPCToVendorName = {}
    for name, npcIDs in pairs(self.VendorNameToNPC) do
        if type(npcIDs) == "table" then
            for _, npcID in ipairs(npcIDs) do
                self.NPCToVendorName[npcID] = name
            end
        else
            self.NPCToVendorName[npcIDs] = name
        end
    end
end

-------------------------------------------------------------------------------
-- Scanned Vendor Index
-------------------------------------------------------------------------------

-- Build reverse index from scanned vendor data: itemID -> {npcID, ...}
function VendorData:BuildScannedIndex()
    self.ScannedByItemID = {}

    local db = HA.Addon and HA.Addon.db
    if not db or not db.global or not db.global.scannedVendors then
        return
    end

    local itemCount = 0
    for npcID, vendorRecord in pairs(db.global.scannedVendors) do
        local items = vendorRecord.items
        if items then
            for _, item in ipairs(items) do
                local itemID = item.itemID
                if itemID then
                    if not self.ScannedByItemID[itemID] then
                        self.ScannedByItemID[itemID] = {}
                        itemCount = itemCount + 1
                    end
                    table.insert(self.ScannedByItemID[itemID], npcID)
                end
            end
        end
    end

    if HA.Addon then
        HA.Addon:Debug("VendorData scanned index built:", itemCount, "unique items")
    end
end

-- Rebuild the full scanned-index from authoritative SavedVariables.
-- Cheap (~1ms for ~200 vendors) and structurally prevents stale
-- (itemID -> npcID) leakage when a vendor's item set changes between scans.
function VendorData:OnVendorScanned(_)
    self:BuildScannedIndex()
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function VendorData:Initialize()
    -- Build indexes in static vendor authorities.
    if HA.VendorIdentity and HA.VendorIdentity.BuildIndexes then
        HA.VendorIdentity:BuildIndexes()
    end
    if HA.VendorDatabase and HA.VendorDatabase.BuildIndexes then
        HA.VendorDatabase:BuildIndexes()
    end

    self:BuildOfferIndexes()

    -- Build reverse lookup for vendor names
    self:BuildNameIndex()

    -- Build scanned vendor item index
    self:BuildScannedIndex()

    -- Listen for new vendor scans to update index
    if HA.Events then
        HA.Events:RegisterCallback("VENDOR_SCANNED", function(vendorRecord)
            VendorData:OnVendorScanned(vendorRecord)
        end)
    end

    if HA.Addon then
        local nameCount = 0
        for _ in pairs(self.VendorNameToNPC) do
            nameCount = nameCount + 1
        end
        HA.Addon:Debug("VendorData initialized with", self:GetVendorCount(), "vendors")
        HA.Addon:Debug("  VendorNameToNPC mappings:", nameCount)
    end
end

-------------------------------------------------------------------------------
-- Offer Data
-------------------------------------------------------------------------------

-- Get the merged offer table for an NPC from VendorOffers.
-- Returns {[itemID] = offerRecord, ...} with ManualOverrides winning over GeneratedBase,
-- StagedAdditions merging at lowest precedence (reviewed-but-unverified pipeline rows,
-- Data/VendorStagedAdditions.lua), and Tombstones suppressing entries.
-- Returns nil if no offer data exists for npcID.
function VendorData:GetOffers(npcID)
    if not HA.VendorOffers then return nil end
    local base       = HA.VendorOffers.GeneratedBase[npcID]
    local overrides  = HA.VendorOffers.ManualOverrides[npcID]
    local staged     = HA.VendorOffers.StagedAdditions and HA.VendorOffers.StagedAdditions[npcID]
    local tombstones = HA.VendorOffers.Tombstones
    if not base and not overrides and not staged then return nil end
    local result = {}
    if overrides then
        for itemID, offer in pairs(overrides) do
            local key = tostring(npcID) .. ":" .. tostring(itemID)
            if not tombstones[itemID] and not tombstones[key] then
                result[itemID] = offer
            end
        end
    end
    if base then
        for itemID, offer in pairs(base) do
            if not result[itemID] then
                local key = tostring(npcID) .. ":" .. tostring(itemID)
                if not tombstones[itemID] and not tombstones[key] then
                    result[itemID] = offer
                end
            end
        end
    end
    if staged then
        for itemID, offer in pairs(staged) do
            if not result[itemID] then
                local key = tostring(npcID) .. ":" .. tostring(itemID)
                if not tombstones[itemID] and not tombstones[key] then
                    result[itemID] = offer
                end
            end
        end
    end
    return next(result) and result or nil
end

-- Convert a VendorOffers row into the legacy VendorDatabase item shape.
function VendorData:OfferToLegacyItem(itemID, offer)
    local _ = self
    if not offer then return itemID end

    local cost = nil

    if offer.price and offer.price > 0 then
        cost = cost or {}
        cost.gold = offer.price
    end

    if offer.currencies and #offer.currencies > 0 then
        cost = cost or {}
        cost.currencies = {}
        for _, currency in ipairs(offer.currencies) do
            cost.currencies[#cost.currencies + 1] = {
                id = currency.id,
                amount = currency.amount,
                name = currency.name,
            }
        end
    end

    if offer.namedCosts and #offer.namedCosts > 0 then
        cost = cost or {}
        cost.currencies = cost.currencies or {}
        for _, namedCost in ipairs(offer.namedCosts) do
            cost.currencies[#cost.currencies + 1] = {
                name = namedCost.name,
                amount = namedCost.amount,
            }
        end
    end

    if offer.itemCosts and #offer.itemCosts > 0 then
        cost = cost or {}
        cost.items = {}
        for _, itemCost in ipairs(offer.itemCosts) do
            cost.items[#cost.items + 1] = {
                id = itemCost.id or itemCost.itemID,
                amount = itemCost.amount,
                name = itemCost.name,
            }
        end
    end

    if not cost then
        return itemID
    end

    return { itemID, cost = cost }
end

function VendorData:GetVendorItems(npcID)
    local offers = self:GetOffers(npcID)
    if not offers then return {} end

    local ordered = {}
    for itemID, offer in pairs(offers) do
        ordered[#ordered + 1] = {
            itemID = itemID,
            offer = offer,
            displayOrder = offer.displayOrder or 999999,
        }
    end
    table.sort(ordered, function(left, right)
        if left.displayOrder ~= right.displayOrder then
            return left.displayOrder < right.displayOrder
        end
        return left.itemID < right.itemID
    end)

    local items = {}
    for _, row in ipairs(ordered) do
        items[#items + 1] = self:OfferToLegacyItem(row.itemID, row.offer)
    end
    return items
end

function VendorData:GetItemsForVendor(vendorOrNPC)
    if not vendorOrNPC then return {} end

    if type(vendorOrNPC) == "number" then
        return self:GetVendorItems(vendorOrNPC)
    end

    -- Scanned vendor objects carry their own authoritative item rows; a known
    -- vendor scanned selling an item the static offers lack must not have that
    -- row shadowed by offer projection.
    if vendorOrNPC._isScanned then
        return vendorOrNPC.items or {}
    end

    local npcID = vendorOrNPC.npcID
    if npcID then
        local projectedItems = self:GetVendorItems(npcID)
        if projectedItems and #projectedItems > 0 then
            return projectedItems
        end
    end

    return vendorOrNPC.items or {}
end

function VendorData:GetOfferItemCount()
    local count = 0
    if not self.OfferByItemID then return count end
    for _ in pairs(self.OfferByItemID) do
        count = count + 1
    end
    return count
end

function VendorData:HasOfferForItem(itemID)
    return self.OfferByItemID ~= nil and self.OfferByItemID[itemID] ~= nil
end

function VendorData:GetVendorWithItems(npcID)
    return self:GetVendor(npcID)
end

-- HS-204(b): BuildOfferIndexes only needs "does this npcID sell this itemID
-- at all" for the reverse index — it never needed GetOffers()'s full
-- ManualOverrides > GeneratedBase > StagedAdditions precedence merge (which
-- source's offer record wins is irrelevant to itemID membership). The old
-- version ran that full merge per npcID, then discarded everything but the
-- itemID keys. It also built a "npcID:itemID" string per item to check
-- against Tombstones, which currently holds exactly 2 pair-specific entries
-- (HS-176, HS-182) — so building ~2,000 strings to check a 2-entry table was
-- pure waste. This still reads the raw tables directly and still applies
-- both tombstone forms (bare itemID and "npcID:itemID"), so tombstoned
-- pairs are excluded exactly as before; only npcIDs that actually carry a
-- pair-specific tombstone pay for the string build.
function VendorData:BuildOfferIndexes()
    self.OfferByItemID = {}
    if not HA.VendorOffers then return end

    local tombstones = HA.VendorOffers.Tombstones or {}

    local pairTombstoneNPCs = {}
    for key in pairs(tombstones) do
        -- Tombstones keys are either a bare itemID (number) or a
        -- "npcID:itemID" pair-specific string; only strings can match here.
        local npcIDText = type(key) == "string" and key:match("^(%d+):%d+$")
        if npcIDText then
            pairTombstoneNPCs[tonumber(npcIDText)] = true
        end
    end

    local seenNPCs = {}
    local function addNPC(npcID)
        if seenNPCs[npcID] then return end
        seenNPCs[npcID] = true

        local itemsSeenForNPC = {}
        local checkPairTombstone = pairTombstoneNPCs[npcID]

        local function addFromSource(offers)
            if not offers then return end
            for itemID in pairs(offers) do
                if not itemsSeenForNPC[itemID] and not tombstones[itemID] then
                    -- Truthiness, not == true: a future tombstone written as
                    -- ["npc:item"] = "reason" must suppress here exactly as it
                    -- does in GetOffers, or the pair resurrects in this index.
                    local suppressed = checkPairTombstone
                        and tombstones[tostring(npcID) .. ":" .. tostring(itemID)]
                    if not suppressed then
                        itemsSeenForNPC[itemID] = true
                        self.OfferByItemID[itemID] = self.OfferByItemID[itemID] or {}
                        table.insert(self.OfferByItemID[itemID], npcID)
                    end
                end
            end
        end

        addFromSource(HA.VendorOffers.GeneratedBase and HA.VendorOffers.GeneratedBase[npcID])
        addFromSource(HA.VendorOffers.ManualOverrides and HA.VendorOffers.ManualOverrides[npcID])
        addFromSource(HA.VendorOffers.StagedAdditions and HA.VendorOffers.StagedAdditions[npcID])
    end

    for npcID in pairs(HA.VendorOffers.GeneratedBase or {}) do addNPC(npcID) end
    for npcID in pairs(HA.VendorOffers.ManualOverrides or {}) do addNPC(npcID) end
    for npcID in pairs(HA.VendorOffers.StagedAdditions or {}) do addNPC(npcID) end
end

function VendorData:InvalidateVendorCaches()
    if HA.VendorIdentity and HA.VendorIdentity.InvalidateVendorCache then
        HA.VendorIdentity:InvalidateVendorCache()
    end
    self:BuildOfferIndexes()
    self:BuildScannedIndex()
end


-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

-- Register with main addon when it's ready
if HA.Addon then
    HA.Addon:RegisterModule("VendorData", VendorData)
end
