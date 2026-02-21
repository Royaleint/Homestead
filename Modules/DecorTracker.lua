--[[
    Homestead - DecorTracker Module
    Core decor collection tracking logic
]]

local _, HA = ...

-- Create DecorTracker module
local DecorTracker = {}
HA.DecorTracker = DecorTracker

-- Local references
local DecorData = HA.DecorData

-- Local state
local isInitialized = false

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function DecorTracker:Initialize()
    if isInitialized then return end

    isInitialized = true
    HA.Addon:Debug("DecorTracker initialized")
end

-------------------------------------------------------------------------------
-- Core Functions
-------------------------------------------------------------------------------

-- Check if an item is a decor item
function DecorTracker:IsDecorItem(itemLink)
    if not itemLink then return false end

    -- Try to get catalog info
    if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
        local success, info = pcall(function()
            return C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, false)
        end)
        return success and info ~= nil
    end

    return false
end

-- Check if a decor item is collected
function DecorTracker:IsCollected(itemIDOrLink)
    local decorData = self:GetDecorInfo(itemIDOrLink)
    if decorData then
        return decorData.isOwned
    end
    return nil -- Unknown
end

-- Get full decor info for an item
function DecorTracker:GetDecorInfo(itemIDOrLink)
    if not itemIDOrLink then return nil end

    -- Convert item ID to link if needed
    local itemLink
    if type(itemIDOrLink) == "number" then
        itemLink = "item:" .. itemIDOrLink
    else
        itemLink = itemIDOrLink
    end

    -- Create and return DecorData object
    local decorData = DecorData:FromItemLink(itemLink)
    if decorData and decorData:IsValid() then
        return decorData
    end

    return nil
end

-- Get the status text for an item
function DecorTracker:GetStatusText(itemLink)
    local decorData = self:GetDecorInfo(itemLink)
    if not decorData then return nil end

    local L = HA.L or {}
    local status = decorData:GetStatus()

    if status == "COLLECTED" then
        return L["Collected"] or "Collected"
    elseif status == "COLLECTED_PLACED" then
        return L["Collected (Placed)"] or "Collected (Placed)"
    else
        return L["Not Collected"] or "Not Collected"
    end
end

-- Get the status icon for an item
function DecorTracker:GetStatusIcon(itemLink)
    local decorData = self:GetDecorInfo(itemLink)
    if not decorData then return nil end

    return decorData:GetStatusIcon()
end

-- Get the status color for an item
function DecorTracker:GetStatusColor(itemLink)
    local decorData = self:GetDecorInfo(itemLink)
    if not decorData then return nil end

    return decorData:GetStatusColor()
end

-------------------------------------------------------------------------------
-- Collection Statistics
-------------------------------------------------------------------------------

-- Get total collection statistics
function DecorTracker:GetStatistics()
    local stats = {
        totalDecor = 0,
        collected = 0,
        placed = 0,
        remaining = 0,
        percentComplete = 0,
    }

    -- Get totals from housing catalog API
    if C_HousingCatalog then
        if C_HousingCatalog.GetDecorTotalOwnedCount then
            stats.collected = C_HousingCatalog.GetDecorTotalOwnedCount() or 0
        end

        if C_HousingCatalog.GetDecorMaxOwnedCount then
            stats.totalDecor = C_HousingCatalog.GetDecorMaxOwnedCount() or 0
        end
    end

    stats.remaining = stats.totalDecor - stats.collected

    if stats.totalDecor > 0 then
        stats.percentComplete = (stats.collected / stats.totalDecor) * 100
    end

    return stats
end

-------------------------------------------------------------------------------
-- Search and Filtering
-------------------------------------------------------------------------------

-- Search for decor items by name
function DecorTracker:SearchByName(searchText)
    local results = {}

    if not C_HousingCatalog or not C_HousingCatalog.CreateCatalogSearcher then
        return results
    end

    -- Note: Actual implementation depends on specific API behavior
    -- This is a placeholder for the search functionality

    return results
end

-- Get all decor in a category
function DecorTracker:GetDecorByCategory(categoryID)
    local results = {}

    if not C_HousingCatalog or not C_HousingCatalog.GetCatalogCategoryInfo then
        return results
    end

    -- Note: Actual implementation depends on specific API behavior

    return results
end

-- Get all uncollected decor
function DecorTracker:GetUncollectedDecor()
    local results = {}

    -- This would iterate through all catalog entries
    -- and filter for uncollected items

    return results
end

-- Get all decor from a specific vendor
function DecorTracker:GetDecorFromVendor(npcID)
    local results = {}

    -- This would query the vendor database
    -- and return all decor items sold by that vendor

    return results
end

-------------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------------

-- Get item ID from item link
function DecorTracker:GetItemIDFromLink(itemLink)
    if not itemLink then return nil end
    return GetItemInfoInstant(itemLink)
end

-- Create item link from item ID
function DecorTracker:CreateItemLink(itemID)
    if not itemID then return nil end
    return "item:" .. itemID
end

-- Check if housing features are available
function DecorTracker:IsHousingAvailable()
    return C_HousingCatalog ~= nil and C_Housing ~= nil
end

-- Check if player is in their house
function DecorTracker:IsInHouse()
    if C_Housing and C_Housing.IsInsideHouse then
        return C_Housing.IsInsideHouse()
    end
    return false
end

-- Check if player is in their own house
function DecorTracker:IsInOwnHouse()
    if C_Housing and C_Housing.IsInsideOwnHouse then
        return C_Housing.IsInsideOwnHouse()
    end
    return false
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

-- Register with main addon when it's ready
if HA.Addon then
    HA.Addon:RegisterModule("DecorTracker", DecorTracker)
end

