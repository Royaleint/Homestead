--[[
    Homestead - VendorData
    Unified vendor data access layer

    This module provides:
    - Unified access to static (VendorDatabase) and scanned vendor data
    - Query functions for finding vendors by item, location, or name
    - Merging of scanned vendor data with static database
]]

local addonName, HA = ...

-- Create VendorData module
local VendorData = {}
HA.VendorData = VendorData

-------------------------------------------------------------------------------
-- Query Functions (delegate to VendorDatabase)
-------------------------------------------------------------------------------

-- Get vendor info by NPC ID
function VendorData:GetVendor(npcID)
    if HA.VendorDatabase then
        return HA.VendorDatabase:GetVendor(npcID)
    end
    return nil
end

-- Check if vendor exists
function VendorData:HasVendor(npcID)
    if HA.VendorDatabase then
        return HA.VendorDatabase:HasVendor(npcID)
    end
    return false
end

-- Get all vendors in a specific map/zone
function VendorData:GetVendorsInMap(mapID)
    if HA.VendorDatabase then
        return HA.VendorDatabase:GetVendorsByMapID(mapID)
    end
    return {}
end

-- Get all vendors for a faction (includes Neutral)
function VendorData:GetVendorsForFaction(faction)
    if not HA.VendorDatabase then return {} end

    local result = {}

    -- Get all vendors and filter by faction
    for npcID, vendor in pairs(HA.VendorDatabase.Vendors) do
        local vendorFaction = vendor.faction or "Neutral"
        if vendorFaction == faction or vendorFaction == "Neutral" then
            vendor.npcID = npcID
            table.insert(result, vendor)
        end
    end

    return result
end

-- Get all vendors that sell a specific item
function VendorData:GetVendorsForItem(itemID)
    if not HA.VendorDatabase then return {} end

    local result = {}

    -- Use ByItemID index if available (O(1) lookup)
    if HA.VendorDatabase.ByItemID and HA.VendorDatabase.ByItemID[itemID] then
        for _, npcID in ipairs(HA.VendorDatabase.ByItemID[itemID]) do
            local vendor = HA.VendorDatabase.Vendors[npcID]
            if vendor then
                vendor.npcID = npcID
                table.insert(result, vendor)
            end
        end
        return result
    end

    -- Fallback: iterate all vendors (if index not built yet)
    for npcID, vendor in pairs(HA.VendorDatabase.Vendors) do
        if vendor.items then
            for _, vendorItemID in ipairs(vendor.items) do
                if vendorItemID == itemID then
                    vendor.npcID = npcID
                    table.insert(result, vendor)
                    break
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
    if not searchText or searchText == "" or not HA.VendorDatabase then
        return {}
    end

    local lowerSearch = searchText:lower()
    local result = {}

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
            vendor.npcID = npcID
            table.insert(result, vendor)
        end
    end

    return result
end

-- Get all vendors
function VendorData:GetAllVendors()
    if HA.VendorDatabase then
        return HA.VendorDatabase:GetAllVendors()
    end
    return {}
end

-- Get vendor count
function VendorData:GetVendorCount()
    if HA.VendorDatabase then
        return HA.VendorDatabase:GetVendorCount()
    end
    return 0
end

-- Get vendors by expansion
function VendorData:GetVendorsByExpansion(expansion)
    if HA.VendorDatabase then
        return HA.VendorDatabase:GetVendorsByExpansion(expansion)
    end
    return {}
end

-- Find vendor by name (exact match, case-insensitive)
function VendorData:FindVendorByName(name)
    if HA.VendorDatabase then
        return HA.VendorDatabase:FindVendorByName(name)
    end
    return nil
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function VendorData:Initialize()
    -- Build indexes in VendorDatabase
    if HA.VendorDatabase and HA.VendorDatabase.BuildIndexes then
        HA.VendorDatabase:BuildIndexes()
    end

    if HA.Addon then
        HA.Addon:Debug("VendorData initialized with", self:GetVendorCount(), "vendors")
    end
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

-- Register with main addon when it's ready
if HA.Addon then
    HA.Addon:RegisterModule("VendorData", VendorData)
end
