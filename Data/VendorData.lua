--[[
    Homestead - VendorData
    Unified vendor data access layer

    This module provides:
    - Unified access to static (VendorDatabase) and scanned vendor data
    - Query functions for finding vendors by item, location, or name
    - Merging of scanned vendor data with static database
]]

local _, HA = ...

-- Create VendorData module
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

    -- Format gold (stored in copper) using GetCoinTextureString for coin icons
    if cost.gold and cost.gold > 0 then
        if GetCoinTextureString then
            parts[#parts + 1] = GetCoinTextureString(cost.gold)
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

-- Get cost for an item from scanned vendor data
-- Returns cost in static format {gold = ..., currencies = {...}} or nil
function VendorData:GetScannedItemCost(itemID, npcID)
    local db = HA.Addon and HA.Addon.db
    if not db or not db.global or not db.global.scannedVendors then
        return nil
    end

    -- If npcID given, check that vendor specifically
    if npcID then
        local vendor = db.global.scannedVendors[npcID]
        if vendor and vendor.items then
            for _, item in ipairs(vendor.items) do
                if item.itemID == itemID then
                    return self:NormalizeScannedCost(item)
                end
            end
        end
    end

    -- Otherwise search all scanned vendors via index
    if self.ScannedByItemID and self.ScannedByItemID[itemID] then
        for _, scanNpcID in ipairs(self.ScannedByItemID[itemID]) do
            local vendor = db.global.scannedVendors[scanNpcID]
            if vendor and vendor.items then
                for _, item in ipairs(vendor.items) do
                    if item.itemID == itemID then
                        return self:NormalizeScannedCost(item)
                    end
                end
            end
        end
    end

    return nil
end

-------------------------------------------------------------------------------
-- Shared Item Merge Helpers
-------------------------------------------------------------------------------

-- Merge static vendor items + scanned vendor items into a deduplicated itemID set.
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

    -- Static items from vendor database/endeavors data
    if vendor.items and #vendor.items > 0 then
        for _, item in ipairs(vendor.items) do
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
-- Query Functions (delegate to VendorDatabase)
-------------------------------------------------------------------------------

-- Resolve an alias NPC ID to its canonical ID.
-- Returns the canonical ID if an alias exists, nil otherwise.
-- Checks both VendorDatabase.Aliases and EndeavorsData.Aliases.
function VendorData:ResolveAlias(npcID)
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

-- Get vendor info by NPC ID (resolves aliases)
function VendorData:GetVendor(npcID)
    if HA.VendorDatabase then
        local vendor = HA.VendorDatabase:GetVendor(npcID)
        if vendor then return vendor end
    end
    if HA.EndeavorsData and HA.EndeavorsData.Vendors then
        local vendor = HA.EndeavorsData.Vendors[npcID]
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
    if HA.VendorDatabase and HA.VendorDatabase:HasVendor(npcID) then
        return true
    end
    if HA.EndeavorsData and HA.EndeavorsData.Vendors then
        if HA.EndeavorsData.Vendors[npcID] then return true end
    end
    -- Resolve alias and retry (cycle guard: canonicalID must differ)
    local canonicalID = self:ResolveAlias(npcID)
    if canonicalID and canonicalID ~= npcID then
        return self:HasVendor(canonicalID)
    end
    return false
end

-- Get all vendors in a specific map/zone
-- Includes active event vendors from EventSources
function VendorData:GetVendorsInMap(mapID)
    local result = {}
    local addedNPCs = {}

    -- Static database vendors
    if HA.VendorDatabase then
        local dbVendors = HA.VendorDatabase:GetVendorsByMapID(mapID)
        if dbVendors then
            for _, vendor in ipairs(dbVendors) do
                result[#result + 1] = vendor
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
                if vendor.npcID and not addedNPCs[vendor.npcID] then
                    result[#result + 1] = vendor
                    addedNPCs[vendor.npcID] = true
                end
            end
        end
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

    -- VendorDatabase vendors
    if HA.VendorDatabase then
        for npcID, vendor in pairs(HA.VendorDatabase.Vendors) do
            local vendorFaction = vendor.faction or "Neutral"
            if vendorFaction == faction or vendorFaction == "Neutral" then
                table.insert(result, vendor)
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

    -- Priority 1: Static VendorDatabase (curated, authoritative)
    if HA.VendorDatabase then
        if HA.VendorDatabase.ByItemID and HA.VendorDatabase.ByItemID[itemID] then
            for _, npcID in ipairs(HA.VendorDatabase.ByItemID[itemID]) do
                local vendor = HA.VendorDatabase.Vendors[npcID]
                if vendor then
                    table.insert(result, vendor)
                    seenNPCs[npcID] = true
                end
            end
        else
            -- Fallback: iterate all vendors (if index not built yet)
            if HA.DevAddon and HA.Addon then
                HA.Addon:Debug("WARNING: ByItemID index not built — possible init ordering issue")
            end
            for npcID, vendor in pairs(HA.VendorDatabase.Vendors) do
                if vendor.items then
                    for _, item in ipairs(vendor.items) do
                        local vendorItemID = self:GetItemID(item)
                        if vendorItemID == itemID then
                            table.insert(result, vendor)
                            seenNPCs[npcID] = true
                            break
                        end
                    end
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

    -- Search static database
    if HA.VendorDatabase then
        for npcID, vendor in pairs(HA.VendorDatabase.Vendors) do
            local matched = false
            if vendor.name and vendor.name:lower():find(lowerSearch, 1, true) then
                matched = true
            elseif vendor.zone and vendor.zone:lower():find(lowerSearch, 1, true) then
                matched = true
            elseif vendor.subzone and vendor.subzone:lower():find(lowerSearch, 1, true) then
                matched = true
            end
            if matched then
                result[#result + 1] = vendor
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
                if matched then
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

    -- Static database vendors
    if HA.VendorDatabase then
        local dbVendors = HA.VendorDatabase:GetAllVendors()
        if dbVendors then
            for _, vendor in ipairs(dbVendors) do
                result[#result + 1] = vendor
                if vendor.npcID then
                    addedNPCs[vendor.npcID] = true
                end
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
    if HA.VendorDatabase then
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
    if HA.VendorDatabase then
        local dbVendors = HA.VendorDatabase:GetVendorsByExpansion(expansion)
        for _, vendor in ipairs(dbVendors) do
            result[#result + 1] = vendor
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

    -- Auto-populate VendorNameToNPC from VendorDatabase for any vendors
    -- not already in the manual table (preserves manual multi-NPC entries)
    if HA.VendorDatabase and HA.VendorDatabase.Vendors then
        -- Add any vendor from the database not already covered
        for npcID, vendor in pairs(HA.VendorDatabase.Vendors) do
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

-- Incrementally update scanned index when a vendor is scanned
function VendorData:OnVendorScanned(vendorRecord)
    if not vendorRecord or not vendorRecord.items then return end
    if not self.ScannedByItemID then
        self.ScannedByItemID = {}
    end

    local npcID = vendorRecord.npcID
    for _, item in ipairs(vendorRecord.items) do
        local itemID = item.itemID
        if itemID then
            if not self.ScannedByItemID[itemID] then
                self.ScannedByItemID[itemID] = {}
            end
            -- Avoid duplicate npcID entries
            local found = false
            for _, existingNPC in ipairs(self.ScannedByItemID[itemID]) do
                if existingNPC == npcID then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(self.ScannedByItemID[itemID], npcID)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function VendorData:Initialize()
    -- Build indexes in VendorDatabase
    if HA.VendorDatabase and HA.VendorDatabase.BuildIndexes then
        HA.VendorDatabase:BuildIndexes()
    end

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
-- Module Registration
-------------------------------------------------------------------------------

-- Register with main addon when it's ready
if HA.Addon then
    HA.Addon:RegisterModule("VendorData", VendorData)
end
