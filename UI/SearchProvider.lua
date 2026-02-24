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
    local allVendors = VD:GetAllVendors()
    for _, vendor in ipairs(allVendors) do
        local itemIDs = VD:GetMergedItemIDs(vendor)
        if itemIDs then
            for _, itemID in ipairs(itemIDs) do
                if itemID and not seen[itemID] then
                    seen[itemID] = true
                    allItems[#allItems + 1] = itemID
                end
            end
        end
    end

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
    searchIndex = { vendorItems = {}, decorToItem = {} }

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
end

-------------------------------------------------------------------------------
-- Search
-- Matching ignores source filter; consumers apply panelSourceFilter for display.
-------------------------------------------------------------------------------

function SearchProvider:Search(query)
    BuildIndex()
    if not searchIndex then return {} end

    query = query:lower()
    local queryNum = tonumber(query)
    local decorItemID = queryNum and searchIndex.decorToItem[queryNum]

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
    return results
end
