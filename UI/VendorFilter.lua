--[[
    Homestead - VendorFilter
    Vendor filtering and coordinate helpers for map pins

    Extracted from VendorMapPins.lua to reduce file size.
    Stateless utility functions for vendor visibility, faction checks,
    coordinate resolution, and settings queries.

    Reusable by VendorMapPins, VendorTracer, etc.
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

            -- Use scanned coords if they're valid and mapID matches.
            -- For endeavor vendors, skip scan data from a different mapID — it may
            -- be stale from a previous neighborhood rotation. Vendors with a second
            -- position stand in two maps, so a scan on one never moves the other.
            local scanMapMismatch = (vendor.endeavor or vendor.altMapID) and scannedMapID ~= vendor.mapID
            if VendorFilter.AreValidCoordinates(scannedX, scannedY) and scannedMapID
                    and not scanMapMismatch then
                -- Debug output
                if HA.DevAddon and HA.Addon.db.profile.debug then
                    -- Compare with epsilon matched to %.2f display precision so
                    -- the log only fires when the formatted output would differ.
                    local sx, sy = VendorFilter.GetVendorXY(vendor)
                    if not sx or not sy
                            or math.abs(sx - scannedX) > 0.005
                            or math.abs(sy - scannedY) > 0.005 then
                        HA.Addon:Debug(string.format("Vendor %s (%d): using SCANNED coords (%.2f, %.2f) instead of static (%.2f, %.2f)",
                            vendor.name or "Unknown", vendor.npcID,
                            scannedX, scannedY,
                            sx or 0, sy or 0))
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

-- the client build that ships the vendors currently flagged
-- `unreleased`. This serves ONE batch at a time — it is a floor, not a match,
-- so raising it for a later patch would stop revealing today's rows rather than
-- adding to them. A second batch targeting a different build needs the per-row
-- target field, not a bump here. When 12.1 ships, clear the data flags.
local UNRELEASED_CONTENT_INTERFACE = 120100  -- 12.1

-- The build cannot change mid-session, so read it once.
local CLIENT_INTERFACE = select(4, GetBuildInfo())

-- Whether to show vendors flagged `unreleased` in this session. Both conditions
-- fail closed, so the rows appear only on a dev build of a client that actually
-- has the content.
--
-- Note on Foundry: F.IS_DEV_BUILD does NOT work here. The generated DevBuild TOC
-- sets a real `## Version: dev`, and Foundry's test is for a nil or unsubstituted
-- version token, so it reads a DevBuild as a release. HA.__isDevBuild comes from
-- the generated DevBuildGuard.lua, which exists only in a dev checkout.
--
-- The flag is nil in a packaged release at load. It is not tamper-proof —
-- `_G.Homestead` is public, so anything in-process can set it — but the build
-- gate keeps the reveal inert until the content has shipped anyway.
function VendorFilter.ShouldRevealUnreleasedVendors()
    if not HA.__isDevBuild then return false end
    return type(CLIENT_INTERFACE) == "number"
        and CLIENT_INTERFACE >= UNRELEASED_CONTENT_INTERFACE
end

-- True when the vendor is retired, or not out yet and not being revealed this
-- session. Shared by the pin filter and by every list that names vendors (search,
-- item sources, closest-vendor picks), so a hidden vendor shows up nowhere.
function VendorFilter.IsHiddenOnThisBuild(vendor)
    if not vendor then return false end
    if vendor.removed then return true end
    if vendor.unreleased and not VendorFilter.ShouldRevealUnreleasedVendors() then
        return true
    end
    return false
end

-- A scan confirmed the vendor sells no decor. Static vendors are never dropped (a noDecorVendors entry for
-- a known vendor is a false positive), and holiday vendors skip this.
function VendorFilter.IsConfirmedNoDecor(vendor)
    if not vendor or vendor._isEventVendor or not vendor.npcID then return false end
    local db = HA.Addon and HA.Addon.db and HA.Addon.db.global
    local entry = db and db.noDecorVendors and db.noDecorVendors[vendor.npcID]
    -- Only trust confirmed entries (guards against corrupted SVs)
    if not (entry and entry.scanConfidence == "confirmed") then return false end
    return not (HA.VendorData and HA.VendorData:HasVendor(vendor.npcID))
end

-- Check if a vendor should be hidden from all pin displays
-- Returns true if vendor should be hidden (removed, unreleased, or scanned with no decor)
function VendorFilter.ShouldHideVendor(vendor)
    if not vendor then return true end

    -- Retired vendors are hidden on every build, forever. This is deliberately
    -- checked before the event-vendor branch: a removed vendor may still carry
    -- expansion = "Events" (Dershway [151941] does), and must not escape through it.
    if vendor.removed then return true end

    -- Event vendors: only hidden when setting is off (bypass unreleased/noDecor checks)
    if vendor._isEventVendor then
        return not VendorFilter.ShouldShowEventVendors()
    end

    if VendorFilter.IsHiddenOnThisBuild(vendor) then
        return true
    end

    -- Persistent no-decor list (survives ClearScannedData)
    return VendorFilter.IsConfirmedNoDecor(vendor)
end

-------------------------------------------------------------------------------
-- Faction Checks
-------------------------------------------------------------------------------

-- The faction a vendor serves at a position on mapID: its own faction, or for a
-- Neutral vendor the faction of the zone it stands in. nil serves everyone.
local function PositionFaction(vendor, mapID)
    local f = vendor.faction
    if f and f ~= "Neutral" then return f end
    if mapID then
        return HA.Constants.ZoneToFactionMap[mapID]
    end
end

-- Resolve effective faction for a vendor: explicit field first, then zone map fallback.
local function GetEffectiveFaction(vendor)
    return PositionFaction(vendor, vendor.mapID)
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

-- CanAccessVendor and IsOppositeFaction judge the one position a map pin stands
-- for. This judges the vendor as a whole: whether this character can use it at
-- any of its positions, its own and VendorData:GetOtherPosition's. When it
-- can't, it also returns the faction each position serves (the second only
-- when it differs from the first). For a vendor with one position the verdict
-- is CanAccessVendor's.
function VendorFilter.CanUseVendor(vendor)
    local playerFaction = UnitFactionGroup("player")
    local faction = PositionFaction(vendor, vendor.mapID)
    if not faction or faction == playerFaction then return true end
    local otherMapID = HA.VendorData:GetOtherPosition(vendor)
    if not otherMapID then return false, faction end
    local other = PositionFaction(vendor, otherMapID)
    if not other or other == playerFaction then return true end
    return false, faction, other ~= faction and other or nil
end

-- Where this character should go for the vendor, in GetBestVendorCoordinates'
-- shape: a position it can use, the nearer one when it can use both, and the
-- vendor's own position when it can use neither.
function VendorFilter.GetUsableVendorCoordinates(vendor)
    local coords, mapID, source = VendorFilter.GetBestVendorCoordinates(vendor)
    local VD = HA.VendorData
    local otherMapID, otherX, otherY = VD:GetOtherPosition(vendor)
    if not (otherMapID and VendorFilter.AreValidCoordinates(otherX, otherY)) then
        return coords, mapID, source
    end
    local playerFaction = UnitFactionGroup("player")
    local other = PositionFaction(vendor, otherMapID)
    if other and other ~= playerFaction then return coords, mapID, source end
    local own = PositionFaction(vendor, vendor.mapID)
    if coords and (not own or own == playerFaction)
            and not VD:IsSecondPositionNearer(mapID, coords.x, coords.y, otherMapID, otherX, otherY) then
        return coords, mapID, source
    end
    return { x = otherX, y = otherY }, otherMapID, "static"
end

-- The map, zone, subzone and area ID of the position GetUsableVendorCoordinates
-- picks. A vendor with one position answers with its own fields.
function VendorFilter.GetUsableVendorPlace(vendor)
    local otherMapID, _, _, zone, subzone, areaID = HA.VendorData:GetOtherPosition(vendor)
    if otherMapID and select(2, VendorFilter.GetUsableVendorCoordinates(vendor)) == otherMapID then
        return otherMapID, zone, subzone, areaID
    end
    return vendor.mapID, vendor.zone, vendor.subzone, vendor.areaID
end

-- The client's names for the position GetUsableVendorPlace picks, in the
-- player's language: mapID, zone (the map's name) and subzone (the area's
-- name). Each falls back to the shipped text when the client has no name or the
-- position has no area ID; an area name that only repeats the zone is the zone-level
-- area row, so the shipped subzone stays.
local mapNames, areaNames = {}, {}

-- The client's name for a map, or nil when it has none.
function VendorFilter.GetMapName(mapID)
    local name = mapNames[mapID]
    if name == nil then
        local info = C_Map.GetMapInfo(mapID)
        name = info and info.name or false
        mapNames[mapID] = name
    end
    return name or nil
end

-- The client's name for an area, or nil when it has none.
function VendorFilter.GetAreaName(areaID)
    local name = areaNames[areaID]
    if name == nil then
        name = C_Map.GetAreaInfo(areaID) or false
        areaNames[areaID] = name
    end
    return name or nil
end

function VendorFilter.GetVendorPlaceNames(vendor)
    local mapID, zone, subzone, areaID = VendorFilter.GetUsableVendorPlace(vendor)
    if mapID then
        zone = VendorFilter.GetMapName(mapID) or zone
    end
    if areaID then
        local name = VendorFilter.GetAreaName(areaID)
        if name and name ~= zone then subzone = name end
    end
    return mapID, zone, subzone
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


-- Get the setting for showing event vendors
function VendorFilter.ShouldShowEventVendors()
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.vendorTracer then
        return HA.Addon.db.profile.vendorTracer.showEventVendors ~= false
    end
    return true  -- Default to showing
end

-- Get the setting for hiding fully-collected vendor pins
function VendorFilter.ShouldHideCompletedVendorPins()
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.vendorTracer then
        return HA.Addon.db.profile.vendorTracer.hideCompletedVendorPins == true
    end
    return false  -- Default to showing
end

-- Check if a vendor is an event vendor
function VendorFilter.IsEventVendor(vendor)
    return vendor and vendor._isEventVendor == true
end

-------------------------------------------------------------------------------
-- Map Pin Completion Gate
-------------------------------------------------------------------------------

-- Map-pin-only completion gate: true only when the setting is on AND the
-- vendor is confirmed fully collected. Unknown/nil completion always shows
-- (same fail-direction discipline as the endeavour gate) so a vendor
-- never disappears because its collection state couldn't be determined.
--
-- Deliberately separate from ShouldHideVendor: that gate is reused by
-- non-map callers (VendorTracer) which must not inherit
-- completion-hiding.
function VendorFilter.ShouldHideCompletedVendorPin(vendor, sourceFilter)
    if not VendorFilter.ShouldHideCompletedVendorPins() then return false end
    local BC = HA.BadgeCalculation
    if not BC then return false end
    return BC:VendorHasUncollectedItems(vendor, sourceFilter) == false
end
