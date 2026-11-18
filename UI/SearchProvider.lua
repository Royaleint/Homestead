--[[
    Homestead - SearchProvider
    Search index and query engine for vendor/item discovery

    Builds a lightweight index of vendor metadata + item IDs, resolves item names
    at query time via HA.GetItemName, so a name that loads later reaches the
    consumers that listen for it. Batched pre-warming populates WoW's item cache
    on first search focus.

    Consumers: MapSidePanel (search bar UI + result rendering), the Decor Browser's
    result page
]]

local _, HA = ...
local L = HA.L

local SearchProvider = {}
HA.SearchProvider = SearchProvider

local searchIndex = nil
local preWarmed = false
local indexRevision = 0
local initialized = false
local VD  -- VendorData reference, set in Initialize
local NON_VENDOR_SOURCE_DESCRIPTORS = {
    { tableKey = "QuestSources", type = "quest", nameField = "questName" },
    { tableKey = "AchievementSources", type = "achievement", nameField = "achievementName", extraField = "category" },
    { tableKey = "ProfessionSources", type = "profession", nameField = "recipeName", extraField = "profession" },
    { tableKey = "EventSources", type = "event", nameField = "vendorName" },
    { tableKey = "DropSources", type = "drop", nameField = "mobName", extraField = "zone" },
}

local function ForEachNonVendorSourceItem(callback)
    if type(callback) ~= "function" then return end

    for _, descriptor in ipairs(NON_VENDOR_SOURCE_DESCRIPTORS) do
        local sourceTable = HA[descriptor.tableKey]
        if sourceTable then
            for itemID, data in pairs(sourceTable) do
                if type(itemID) == "number" then
                    callback(itemID, descriptor.type, descriptor.nameField, data, descriptor.extraField)
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

-- dev-only debug accessor for the /hs debug membudget walker.
-- Returns nil if the index hasn't been built yet (lazy -- first search or
-- side-panel open) so the caller can report "not measurable" instead of a
-- misleading 0 KB for an index that just hasn't warmed.
function SearchProvider:GetDebugIndex()
    return searchIndex
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

    -- Batch: 100 items per tick to avoid frame hitch.
    -- C_Item.RequestLoadItemDataByID is the modern cache-warm API; the
    -- deprecated global GetItemInfo also did this as a side effect.
    local idx = 1
    local function ProcessBatch()
        local batchEnd = math.min(idx + 99, #allItems)
        for i = idx, batchEnd do
            C_Item.RequestLoadItemDataByID(allItems[i])
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

-- Adds a field to match text on its own line, so a query never matches across two fields. A field already
-- contained in one line adds nothing.
local function AddLine(text, line)
    if not line or line == "" then return text end
    line = line:lower()
    if text == "" then return line end
    if text:find(line, 1, true) then return text end
    return text .. "\n" .. line
end

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
    local VF = HA.VendorFilter
    for _, vendor in ipairs(allVendors) do
        if vendor.npcID and not VF.IsHiddenOnThisBuild(vendor) then
            local itemIDs = VD:GetMergedItemIDs(vendor)
            local items = {}
            if itemIDs then
                for _, itemID in ipairs(itemIDs) do
                    if itemID then
                        items[#items + 1] = { itemID = itemID, nameLower = nil }
                    end
                end
            end
            -- Both positions' shipped zone and subzone, then the client's names for them.
            local otherMapID, _, _, otherZone, otherSubzone = VD:GetOtherPosition(vendor)
            local places = AddLine(AddLine("", vendor.zone), vendor.subzone)
            places = AddLine(AddLine(places, otherZone), otherSubzone)
            places = AddLine(places, vendor.mapID and VF.GetMapName(vendor.mapID))
            places = AddLine(places, vendor.areaID and VF.GetAreaName(vendor.areaID))
            places = AddLine(places, otherMapID and VF.GetMapName(otherMapID))
            searchIndex.vendorItems[vendor.npcID] = {
                vendor = vendor,
                nameLower = (vendor.name or ""):lower(),
                placesLower = places,
                items = items,
            }
        end
    end

    -- Item-first index for non-vendor sources (names resolved lazily at query time)
    local SM = HA.SourceManager
    ForEachNonVendorSourceItem(function(itemID, sourceType, nameField, data, extraField)
        local entry = searchIndex.sourceItems[itemID]
        if not entry then
            entry = {
                itemName = nil,
                itemNameLower = nil,
                sources = {},
            }
            searchIndex.sourceItems[itemID] = entry
        end

        local searchText = (data[nameField] or ""):lower()
        if sourceType == "event" and data.event then
            local eventText = data.event:lower()
            if eventText ~= "" and not searchText:find(eventText, 1, true) then
                searchText = searchText ~= ""
                    and (searchText .. " " .. eventText)
                    or eventText
            end
        end
        if extraField then
            searchText = AddLine(searchText, data[extraField])
        elseif sourceType == "event" then
            searchText = AddLine(searchText, L["Holiday event"])
        elseif sourceType == "quest" and data.questID then
            -- The quest giver's shipped English name, and the client's name for the quest's map.
            local starter = SM:GetQuestStarter(data.questID)
            searchText = AddLine(searchText, starter and starter.name)
            local mapID = SM:GetQuestMap(data.questID)
            searchText = AddLine(searchText, mapID and VF.GetMapName(mapID))
        end

        entry.sources[#entry.sources + 1] = {
            type = sourceType,
            searchText = searchText,
            data = data,
        }
    end)
end

local function ResolveIndexedItemName(itemID, entry)
    if not entry then return nil, nil end
    if entry.itemNameLower then
        return entry.itemName, entry.itemNameLower
    end

    local itemName = HA.GetItemName(itemID)
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

    query = query:match("^%s*(.-)%s*$"):lower()
    local queryNum = tonumber(query)
    local decorItemID = queryNum and searchIndex.decorToItem[queryNum]
    local includeItemResults = type(options) == "table" and options.includeItemResults == true

    -- Respect faction filter setting
    local VF = HA.VendorFilter
    local showOpposite = not VF or VF.ShouldShowOppositeFaction()

    local results = {}
    for npcID, entry in pairs(searchIndex.vendorItems) do repeat
        -- Skip vendors this character can't use at any position when the setting is off
        if not showOpposite and not VF.CanUseVendor(entry.vendor) then break end

        local matchCount = 0
        local matchType = nil
        local matchedItems = nil  -- set of matched itemIDs (item-level matches only)

        -- The client's name for the vendor too, once the client has given it.
        if not entry.clientLower then
            local name = VD:GetVendorName(entry.vendor)
            entry.clientLower = name ~= entry.vendor.name and name and name:lower() or nil
        end

        -- Vendor / zone / subzone name match
        if entry.nameLower:find(query, 1, true) or entry.placesLower:find(query, 1, true)
                or entry.clientLower and entry.clientLower:find(query, 1, true) then
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
                        local name = HA.GetItemName(item.itemID)
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
        return VD:VendorNameBefore(a.vendor, b.vendor)
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

    -- Group item-first results by source type so the panel can emit
    -- section headers (Profession / Quest / Achievement / Event / Drop) on
    -- sourceType transitions. Alphabetical within each group.
    local SOURCE_TYPE_ORDER = {
        profession = 1, quest = 2, achievement = 3, event = 4, drop = 5,
    }
    table.sort(itemResults, function(a, b)
        local ao = SOURCE_TYPE_ORDER[a.sourceType] or 99
        local bo = SOURCE_TYPE_ORDER[b.sourceType] or 99
        if ao ~= bo then return ao < bo end
        local an, bn = a.itemName or "", b.itemName or ""
        local ka, kb = HA.NameSortKey(an), HA.NameSortKey(bn)
        if ka ~= kb then return ka < kb end
        if an ~= bn then return an < bn end
        return a.itemID < b.itemID
    end)

    for _, itemResult in ipairs(itemResults) do
        results[#results + 1] = itemResult
    end

    return results
end
