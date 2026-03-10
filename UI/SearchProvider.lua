--[[
    Homestead - SearchProvider
    Search index and query engine for vendor/item discovery

    Builds a lightweight index of vendor metadata + item IDs, resolves item names
    at query time via C_Item.GetItemNameByID. Batched pre-warming populates WoW's
    item cache on first search focus.

    Consumers: MapSidePanel (search bar UI + result rendering)
]]

local _, HA = ...

local SearchProvider = {}
HA.SearchProvider = SearchProvider

local searchIndex = nil
local preWarmed = false
local indexRevision = 0
local initialized = false
local VD  -- VendorData reference, set in Initialize
local NON_VENDOR_SOURCE_DESCRIPTORS = {
    { tableKey = "QuestSources", type = "quest", nameField = "questName" },
    { tableKey = "AchievementSources", type = "achievement", nameField = "achievementName" },
    { tableKey = "ProfessionSources", type = "profession", nameField = "recipeName" },
    { tableKey = "EventSources", type = "event", nameField = "vendorName" },
    { tableKey = "DropSources", type = "drop", nameField = "mobName" },
}

local function ForEachNonVendorSourceItem(callback)
    if type(callback) ~= "function" then return end

    for _, descriptor in ipairs(NON_VENDOR_SOURCE_DESCRIPTORS) do
        local sourceTable = HA[descriptor.tableKey]
        if sourceTable then
            for itemID, data in pairs(sourceTable) do
                if type(itemID) == "number" then
                    callback(itemID, descriptor.type, descriptor.nameField, data)
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

function SearchProvider:Initialize()
    if initialized then return end
    initialized = true

    VD = HA.VendorData

    if HA.Events then
        HA.Events:RegisterCallback("VENDOR_SCANNED", function()
            SearchProvider:Invalidate()
        end)
        HA.Events:RegisterCallback("ACTIVE_HOLIDAYS_CHANGED", function()
            SearchProvider:Invalidate()
        end)
    end
end

function SearchProvider:Invalidate()
    searchIndex = nil
    indexRevision = indexRevision + 1
end

function SearchProvider:GetRevision()
    return indexRevision
end

-------------------------------------------------------------------------------
-- Pre-Warm (batched fire-and-forget GetItemInfo)
-------------------------------------------------------------------------------

function SearchProvider:PreWarm()
    if preWarmed or not VD then return end
    preWarmed = true

    local seen = {}
    local allItems = {}
    local function AddItemID(itemID)
        if itemID and not seen[itemID] then
            seen[itemID] = true
            allItems[#allItems + 1] = itemID
        end
    end

    local allVendors = VD:GetAllVendors()
    for _, vendor in ipairs(allVendors) do
        local itemIDs = VD:GetMergedItemIDs(vendor)
        if itemIDs then
            for _, itemID in ipairs(itemIDs) do
                AddItemID(itemID)
            end
        end
    end

    ForEachNonVendorSourceItem(function(itemID)
        AddItemID(itemID)
    end)

    -- Batch: 100 items per tick to avoid frame hitch
    local idx = 1
    local function ProcessBatch()
        local batchEnd = math.min(idx + 99, #allItems)
        for i = idx, batchEnd do
            GetItemInfo(allItems[i])
        end
        idx = batchEnd + 1
        if idx <= #allItems then
            C_Timer.After(0.01, ProcessBatch)
        end
    end
    ProcessBatch()
end

-------------------------------------------------------------------------------
-- Index (built lazily on first Search)
-------------------------------------------------------------------------------

local function BuildIndex()
    if searchIndex or not VD then return end
    searchIndex = { vendorItems = {}, sourceItems = {}, decorToItem = {} }

    -- DecorMapping reverse lookup (decorID → itemID)
    if HA.DecorMapping then
        for decorID, itemID in pairs(HA.DecorMapping) do
            searchIndex.decorToItem[decorID] = itemID
        end
    end

    -- Vendor → items mapping (names resolved at query time)
    local allVendors = VD:GetAllVendors()
    for _, vendor in ipairs(allVendors) do
        if vendor.npcID then
            local itemIDs = VD:GetMergedItemIDs(vendor)
            local items = {}
            if itemIDs then
                for _, itemID in ipairs(itemIDs) do
                    if itemID then
                        items[#items + 1] = { itemID = itemID, nameLower = nil }
                    end
                end
            end
            searchIndex.vendorItems[vendor.npcID] = {
                vendor = vendor,
                nameLower = (vendor.name or ""):lower(),
                zoneLower = (vendor.zone or ""):lower(),
                subzoneLower = (vendor.subzone or ""):lower(),
                items = items,
            }
        end
    end

    -- Item-first index for non-vendor sources (names resolved lazily at query time)
    ForEachNonVendorSourceItem(function(itemID, sourceType, nameField, data)
        local entry = searchIndex.sourceItems[itemID]
        if not entry then
            entry = {
                itemName = nil,
                itemNameLower = nil,
                sources = {},
            }
            searchIndex.sourceItems[itemID] = entry
        end

        entry.sources[#entry.sources + 1] = {
            type = sourceType,
            searchText = (data[nameField] or ""):lower(),
            data = data,
        }
    end)
end

local function ResolveIndexedItemName(itemID, entry)
    if not entry then return nil, nil end
    if entry.itemNameLower then
        return entry.itemName, entry.itemNameLower
    end

    local itemName = C_Item.GetItemNameByID(itemID)
    if itemName then
        entry.itemName = itemName
        entry.itemNameLower = itemName:lower()
        return itemName, entry.itemNameLower
    end

    return nil, nil
end

-------------------------------------------------------------------------------
-- Search
-- Matching ignores source filter; consumers apply panelSourceFilter for display.
-------------------------------------------------------------------------------

function SearchProvider:Search(query, options)
    BuildIndex()
    if not searchIndex then return {} end

    query = query:lower()
    local queryNum = tonumber(query)
    local decorItemID = queryNum and searchIndex.decorToItem[queryNum]
    local includeItemResults = type(options) == "table" and options.includeItemResults == true

    -- Respect faction filter setting
    local VF = HA.VendorFilter
    local showOpposite = not VF or VF.ShouldShowOppositeFaction()

    local results = {}
    for npcID, entry in pairs(searchIndex.vendorItems) do repeat
        -- Skip opposite-faction vendors when setting is off
        if not showOpposite and VF.IsOppositeFaction(entry.vendor) then break end

        local matchCount = 0
        local matchType = nil
        local matchedItems = nil  -- set of matched itemIDs (item-level matches only)

        -- Vendor / zone / subzone name match
        if entry.nameLower:find(query, 1, true)
            or entry.zoneLower:find(query, 1, true)
            or (entry.subzoneLower ~= "" and entry.subzoneLower:find(query, 1, true)) then
            matchType = "vendor"
            matchCount = #entry.items
        else
            -- Item-level matches
            for _, item in ipairs(entry.items) do
                local matched = false
                if queryNum then
                    if item.itemID == queryNum or npcID == queryNum then
                        matched = true
                    elseif decorItemID and item.itemID == decorItemID then
                        matched = true
                    end
                end
                if not matched then
                    -- Resolve name lazily (may have been nil at index time)
                    if not item.nameLower then
                        local name = C_Item.GetItemNameByID(item.itemID)
                        if name then item.nameLower = name:lower() end
                    end
                    if item.nameLower and item.nameLower:find(query, 1, true) then
                        matched = true
                    end
                end
                if matched then
                    matchCount = matchCount + 1
                    if not matchedItems then matchedItems = {} end
                    matchedItems[item.itemID] = true
                end
            end
            if matchCount > 0 then matchType = "item" end
        end

        if matchType then
            results[#results + 1] = {
                resultType = "vendor",
                vendor = entry.vendor,
                matchCount = matchCount,
                matchType = matchType,
                matchedItems = matchedItems,  -- nil for vendor matches (all items relevant)
            }
        end
    until true end

    -- Vendor-name matches first, then alphabetical
    table.sort(results, function(a, b)
        if a.matchType ~= b.matchType then return a.matchType == "vendor" end
        return (a.vendor.name or "") < (b.vendor.name or "")
    end)

    if not includeItemResults then
        return results
    end

    local itemResults = {}
    local emittedItems = {}
    local vendorCoveredItems = {}

    for _, result in ipairs(results) do
        if result.matchType == "vendor" then
            local vendorItemIDs = VD and VD:GetMergedItemIDs(result.vendor)
            if vendorItemIDs then
                for _, vendorItemID in ipairs(vendorItemIDs) do
                    vendorCoveredItems[vendorItemID] = true
                end
            end
        elseif result.matchedItems then
            for vendorItemID in pairs(result.matchedItems) do
                vendorCoveredItems[vendorItemID] = true
            end
        end
    end

    for itemID, entry in pairs(searchIndex.sourceItems) do
        if not vendorCoveredItems[itemID] and not emittedItems[itemID] then
            local itemName, itemNameLower = ResolveIndexedItemName(itemID, entry)
            local matched = false

            if queryNum and itemName
                    and (itemID == queryNum or (decorItemID and itemID == decorItemID)) then
                local primarySource = entry.sources[1]
                itemResults[#itemResults + 1] = {
                    resultType = "item",
                    itemID = itemID,
                    itemName = itemName,
                    sourceType = primarySource.type,
                    sourceData = primarySource.data,
                    matchType = "item",
                }
                emittedItems[itemID] = true
                matched = true
            end

            if not matched then
                for _, source in ipairs(entry.sources) do
                    if source.searchText ~= "" and source.searchText:find(query, 1, true) then
                        if itemName then
                            itemResults[#itemResults + 1] = {
                                resultType = "item",
                                itemID = itemID,
                                itemName = itemName,
                                sourceType = source.type,
                                sourceData = source.data,
                                matchType = "source",
                            }
                            emittedItems[itemID] = true
                            matched = true
                        end
                        break
                    end
                end
            end

            if not matched and itemNameLower and itemNameLower:find(query, 1, true) then
                local primarySource = entry.sources[1]
                itemResults[#itemResults + 1] = {
                    resultType = "item",
                    itemID = itemID,
                    itemName = itemName,
                    sourceType = primarySource.type,
                    sourceData = primarySource.data,
                    matchType = "item",
                }
                emittedItems[itemID] = true
            end
        end
    end

    table.sort(itemResults, function(a, b)
        if a.matchType ~= b.matchType then
            return a.matchType == "source"
        end
        return (a.itemName or "") < (b.itemName or "")
    end)

    for _, itemResult in ipairs(itemResults) do
        results[#results + 1] = itemResult
    end

    return results
end
