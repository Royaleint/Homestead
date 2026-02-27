--[[
    Homestead - VendorFilter
    Vendor filtering and coordinate helpers for map pins

    Extracted from VendorMapPins.lua to reduce file size.
    Stateless utility functions for vendor visibility, faction checks,
    coordinate resolution, and settings queries.

    Reusable by VendorMapPins, VendorTracer, ExportImport, etc.
]]

local _, HA = ...

local VendorFilter = {}
HA.VendorFilter = VendorFilter

-------------------------------------------------------------------------------
-- Coordinate Helpers
-------------------------------------------------------------------------------

-- Check if coordinates are placeholder values (0.5, 0.5 indicates unverified location)
function VendorFilter.AreValidCoordinates(x, y)
    if not x or not y then
        return false
    end
    -- Skip placeholder coordinates (exactly 0.5, 0.5)
    if x == 0.5 and y == 0.5 then
        return false
    end
    -- Also skip coordinates of exactly 0.50 (string comparison edge case)
    if x == 0.50 and y == 0.50 then
        return false
    end
    return true
end

-- Helper to extract coordinates from vendor data (handles both old and new formats)
-- Old format: vendor.coords = {x = 0.5, y = 0.5}
-- New format: vendor.x = 0.5, vendor.y = 0.5
function VendorFilter.GetVendorXY(vendor)
    if not vendor then return nil, nil end
    -- New format: x, y directly on vendor
    if vendor.x and vendor.y then
        return vendor.x, vendor.y
    end
    -- Old format: coords table
    if vendor.coords then
        return vendor.coords.x, vendor.coords.y
    end
    return nil, nil
end

-- Check if a vendor has valid coordinates (static data only - legacy function)
function VendorFilter.HasValidCoordinates(vendor)
    local x, y = VendorFilter.GetVendorXY(vendor)
    if not x or not y then
        return false
    end
    return VendorFilter.AreValidCoordinates(x, y)
end

-- Get the best coordinates for a vendor, preferring scanned data over static data
-- Returns: coords table {x, y}, mapID, source ("scanned" or "static")
function VendorFilter.GetBestVendorCoordinates(vendor)
    if not vendor or not vendor.npcID then
        return nil, nil, nil
    end

    -- First check scanned vendor data (uses old coords format)
    if HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
        local scannedData = HA.Addon.db.global.scannedVendors[vendor.npcID]
        if scannedData and scannedData.coords then
            local scannedX = scannedData.coords.x
            local scannedY = scannedData.coords.y
            local scannedMapID = scannedData.mapID

            -- Use scanned coords if they're valid and mapID matches (or we have a mapID)
            if VendorFilter.AreValidCoordinates(scannedX, scannedY) and scannedMapID then
                -- Debug output
                if HA.DevAddon and HA.Addon.db.profile.debug then
                    local staticX, staticY = VendorFilter.GetVendorXY(vendor)
                    staticX = staticX or "nil"
                    staticY = staticY or "nil"
                    if staticX ~= scannedX or staticY ~= scannedY then
                        HA.Addon:Debug(string.format("Vendor %s (%d): using SCANNED coords (%.2f, %.2f) instead of static (%.2f, %.2f)",
                            vendor.name or "Unknown", vendor.npcID,
                            scannedX, scannedY,
                            tonumber(staticX) or 0, tonumber(staticY) or 0))
                    end
                end
                return {x = scannedX, y = scannedY}, scannedMapID, "scanned"
            end
        end
    end

    -- Fall back to static vendor data (handles both old and new formats)
    local staticX, staticY = VendorFilter.GetVendorXY(vendor)
    if staticX and staticY and VendorFilter.AreValidCoordinates(staticX, staticY) and vendor.mapID then
        return {x = staticX, y = staticY}, vendor.mapID, "static"
    end

    return nil, nil, nil
end

-- Check if vendor has any valid coordinates (scanned or static)
function VendorFilter.VendorHasValidCoordinates(vendor)
    local coords, mapID = VendorFilter.GetBestVendorCoordinates(vendor)
    return coords ~= nil and mapID ~= nil
end

-------------------------------------------------------------------------------
-- Vendor Visibility Filters
-------------------------------------------------------------------------------

-- Check if a vendor's data has been verified (scanned in-game or original data)
-- Returns true if vendor is verified, false if unverified (imported data not yet confirmed)
function VendorFilter.IsVendorVerified(vendor)
    if not vendor then return true end  -- No vendor = don't show warning

    -- If vendor doesn't have the unverified flag, it's original/verified data
    if not vendor.unverified then return true end

    -- Check if vendor has been scanned in-game (scanned data = verified)
    if vendor.npcID and HA.Addon and HA.Addon.db and HA.Addon.db.global.scannedVendors then
        local scannedData = HA.Addon.db.global.scannedVendors[vendor.npcID]
        if scannedData then
            return true  -- Has been scanned in-game = verified
        end
    end

    return false  -- Has unverified flag and hasn't been scanned
end

-- Check if a vendor should be hidden from all pin displays
-- Returns true if vendor should be hidden (unreleased or scanned with no decor)
function VendorFilter.ShouldHideVendor(vendor)
    if not vendor then return true end

    -- Event vendors: only hidden when setting is off (bypass unreleased/noDecor checks)
    if vendor._isEventVendor then
        return not VendorFilter.ShouldShowEventVendors()
    end

    if vendor.unreleased then return true end

    local npcID = vendor.npcID
    if not npcID then return false end

    local db = HA.Addon and HA.Addon.db and HA.Addon.db.global
    if not db then return false end

    -- Persistent no-decor list (survives ClearScannedData)
    if db.noDecorVendors and db.noDecorVendors[npcID] then
        local data = db.noDecorVendors[npcID]
        -- Defensive: only trust confirmed entries (guards against corrupted SVs)
        if data.scanConfidence == "confirmed" then
            return true
        end
    end

    return false
end

-------------------------------------------------------------------------------
-- Faction Checks
-------------------------------------------------------------------------------

-- Resolve effective faction for a vendor: explicit field first, then zone map fallback.
local function GetEffectiveFaction(vendor)
    local f = vendor.faction
    if f and f ~= "Neutral" then return f end
    if vendor.mapID then
        return HA.Constants.ZoneToFactionMap[vendor.mapID]
    end
end

-- Check if vendor is accessible to player's faction
function VendorFilter.CanAccessVendor(vendor)
    local faction = GetEffectiveFaction(vendor)
    if not faction then return true end
    local playerFaction = UnitFactionGroup("player")
    return faction == playerFaction
end

-- Check if vendor is opposite faction (not neutral, not player's faction)
function VendorFilter.IsOppositeFaction(vendor)
    local faction = GetEffectiveFaction(vendor)
    if not faction then return false end
    local playerFaction = UnitFactionGroup("player")
    return faction ~= playerFaction
end

-------------------------------------------------------------------------------
-- Settings Queries
-------------------------------------------------------------------------------

-- Get the setting for showing opposite faction vendors
function VendorFilter.ShouldShowOppositeFaction()
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.vendorTracer then
        return HA.Addon.db.profile.vendorTracer.showOppositeFaction
    end
    return true  -- Default to showing
end

-- Get the setting for showing unverified vendors
function VendorFilter.ShouldShowUnverifiedVendors()
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.vendorTracer then
        return HA.Addon.db.profile.vendorTracer.showUnverifiedVendors == true
    end
    return false  -- Default to hidden (new users shouldn't see unverified data)
end

-- Get the setting for showing event vendors
function VendorFilter.ShouldShowEventVendors()
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.vendorTracer then
        return HA.Addon.db.profile.vendorTracer.showEventVendors ~= false
    end
    return true  -- Default to showing
end

-- Check if a vendor is an event vendor
function VendorFilter.IsEventVendor(vendor)
    return vendor and vendor._isEventVendor == true
end
